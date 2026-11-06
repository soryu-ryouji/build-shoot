extends RefCounted

## 建筑光环按 stack_rule 叠乘或取最高。
## propagate 光环在同一连通网络内共享所有成员的基础倍率乘积，不设上限。

var game: Node
var _active_links: Array = []
var _network_components: Dictionary = {}


func _init(owner_game: Node) -> void:
	game = owner_game


func recompute() -> void:
	if game == null:
		return
	_active_links.clear()
	_network_components.clear()
	_recompute_propagation()
	for target in game.placed_buildings:
		if not is_instance_valid(target) or not bool(target.alive):
			continue
		if bool(target.is_firepower()):
			target.set_buff_damage_multiplier(_multiplier_for(target))
	_sync_energy_links()


func get_multiplier_at(point: Vector2) -> float:
	return _product(_collect_multipliers(point, null))


func _multiplier_for(target: Node) -> float:
	if not bool(target.powered):
		return 1.0
	return _product(_collect_multipliers(target.global_position, target))


func _recompute_propagation() -> void:
	var groups: Dictionary = {}
	for building in game.placed_buildings:
		if not is_instance_valid(building) or not bool(building.alive):
			continue
		for aura in building.auras:
			if not bool(aura.get("propagate", false)):
				continue
			building.set_aura_output_multiplier(aura, _base_modifier(aura))
			var group := String(aura.get("stack_group", aura.get("id", "aura")))
			groups[group] = true
	for group in groups:
		_recompute_propagation_group(String(group))


func _recompute_propagation_group(group: String) -> void:
	var nodes: Dictionary = {}
	for building in game.placed_buildings:
		if not is_instance_valid(building) or not bool(building.alive) or not bool(building.powered):
			continue
		for aura in building.auras:
			var aura_group := String(aura.get("stack_group", aura.get("id", "aura")))
			if bool(aura.get("propagate", false)) and aura_group == group:
				nodes[building.get_instance_id()] = {"node": building, "aura": aura}

	var adjacency: Dictionary = {}
	for id in nodes:
		adjacency[id] = []
	for source_id in nodes:
		var source: Node = nodes[source_id].node
		var aura: Dictionary = nodes[source_id].aura
		for target_id in nodes:
			if int(source_id) >= int(target_id):
				continue
			var target: Node = nodes[target_id].node
			var target_aura: Dictionary = nodes[target_id].aura
			var connected: bool = _targets(aura, target) and source.covers_aura_point(target.global_position, aura)
			connected = connected or (_targets(target_aura, source) and target.covers_aura_point(source.global_position, target_aura))
			if connected:
				adjacency[source_id].append(target_id)
				adjacency[target_id].append(source_id)
	_assign_components(group, nodes, adjacency)

	# 每个连通网络的输出是所有在线成员基础倍率的乘积，不依赖建造顺序或目标数量。
	var outputs: Dictionary = {}
	for id in nodes:
		var component: String = _network_components[id]
		if not outputs.has(component):
			outputs[component] = 1.0
		outputs[component] = float(outputs[component]) * _base_modifier(nodes[id].aura)
	for id in nodes:
		var info: Dictionary = nodes[id]
		(info.node as Node).set_aura_output_multiplier(info.aura, float(outputs[_network_components[id]]))

	# 网络倍率没有递归方向；链路的视觉方向由新塔指向旧塔，仅用于表现能量回流。
	for source_id in nodes:
		var info: Dictionary = nodes[source_id]
		if not bool(info.aura.get("show_links", false)):
			continue
		for target_id in adjacency[source_id]:
			if int(source_id) < int(target_id):
				_active_links.append({"source": nodes[target_id].node, "target": info.node})


func _assign_components(group: String, nodes: Dictionary, adjacency: Dictionary) -> void:
	var component := 0
	for id in nodes:
		if _network_components.has(id):
			continue
		var key := "%s:%d" % [group, component]
		var pending: Array[int] = [int(id)]
		_network_components[id] = key
		while not pending.is_empty():
			var current: int = pending.pop_back()
			for neighbor in adjacency[current]:
				if not _network_components.has(neighbor):
					_network_components[neighbor] = key
					pending.append(int(neighbor))
		component += 1


func get_connected_buildings(building: Node) -> Array:
	var result: Array = []
	if building == null or not is_instance_valid(building):
		return result
	var component = _network_components.get(building.get_instance_id())
	if component == null:
		return result
	for other in game.placed_buildings:
		if other != building and is_instance_valid(other) and _network_components.get(other.get_instance_id()) == component:
			result.append(other)
	return result


func _sync_energy_links() -> void:
	if game.energy_links == null:
		return
	var links: Array = _active_links.duplicate()
	var seen: Dictionary = {}
	for link in links:
		var key := "%d>%d" % [link.source.get_instance_id(), link.target.get_instance_id()]
		seen[key] = true
	for source in game.placed_buildings:
		if not is_instance_valid(source) or not bool(source.alive) or not bool(source.powered):
			continue
		for aura in source.auras:
			if not bool(aura.get("show_links", false)):
				continue
			for target in game.placed_buildings:
				if not is_instance_valid(target) or not bool(target.alive) or not bool(target.powered):
					continue
				if source == target or not bool(target.is_firepower()):
					continue
				if not _targets(aura, target) or not source.covers_aura_point(target.global_position, aura):
					continue
				var key := "%d>%d" % [source.get_instance_id(), target.get_instance_id()]
				if not seen.has(key):
					seen[key] = true
					links.append({"source": source, "target": target})
	game.energy_links.set_links(links)


func _base_modifier(aura: Dictionary) -> float:
	for modifier in aura.get("modifiers", []):
		if String(modifier.get("stat", "")) == "damage" and String(modifier.get("op", "mul")) == "mul":
			return float(modifier.get("value", 1.0))
	return 1.0


func _collect_multipliers(point: Vector2, target: Node) -> Dictionary:
	var groups: Dictionary = {}
	var network_values: Dictionary = {}
	var network_groups: Dictionary = {}
	if game == null:
		return groups
	for source in game.placed_buildings:
		if not is_instance_valid(source) or not bool(source.alive) or not bool(source.powered):
			continue
		if source == target:
			continue
		for aura in source.auras:
			if not _targets(aura, target):
				continue
			if not source.covers_aura_point(point, aura):
				continue
			for modifier in aura.get("modifiers", []):
				if String(modifier.get("stat", "")) != "damage":
					continue
				if String(modifier.get("op", "mul")) != "mul":
					continue
				var value := float(modifier.get("value", 1.0))
				var group := String(aura.get("stack_group", aura.get("id", "aura")))
				if bool(aura.get("propagate", false)):
					var component := String(_network_components.get(source.get_instance_id(), group + ":none"))
					# 同一网络只应用一次共享倍率，独立网络之间继续乘算。
					network_values[component] = source.get_aura_output_multiplier(aura)
					network_groups[component] = group
					continue
				if value <= 0.0:
					continue
				var rule := String(aura.get("stack_rule", "max"))
				if rule == "stack":
					groups[group] = float(groups.get(group, 1.0)) * value
				elif not groups.has(group) or value > float(groups[group]):
					groups[group] = value
	for component in network_values:
		var group: String = network_groups[component]
		groups[group] = float(groups.get(group, 1.0)) * float(network_values[component])
	return groups


func _targets(aura: Dictionary, target: Node) -> bool:
	if target == null:
		return true
	var categories: Array = aura.get("target_categories", [])
	var items: Array = aura.get("target_items", [])
	if categories.is_empty() and items.is_empty():
		return true
	return categories.has(String(target.category)) or items.has(String(target.item_id))


func _product(groups: Dictionary) -> float:
	var result := 1.0
	for value in groups.values():
		result *= float(value)
	return result
