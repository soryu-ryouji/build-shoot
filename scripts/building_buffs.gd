extends RefCounted

## 建筑光环按 stack_rule 叠乘或取最高。
## propagate 光环以火力终端分层，从外层向内传播，不设倍率上限。

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
			# 每次从基础倍率重算，避免基于上次结果反复累乘。
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

	# 圆形覆盖按无向连接处理；到火力终端的最短层数决定传播方向。
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

	# 能直接强化在线火力建筑的塔是第 0 层。
	var distances: Dictionary = {}
	var queue: Array[int] = []
	for id in nodes:
		var info: Dictionary = nodes[id]
		for target in game.placed_buildings:
			if not is_instance_valid(target) or not bool(target.alive) or not bool(target.powered) or not bool(target.is_firepower()):
				continue
			if _targets(info.aura, target) and (info.node as Node).covers_aura_point(target.global_position, info.aura):
				distances[id] = 0
				queue.append(int(id))
				break
	var cursor := 0
	while cursor < queue.size():
		var id: int = queue[cursor]
		cursor += 1
		for neighbor in adjacency[id]:
			if not distances.has(neighbor):
				distances[neighbor] = int(distances[id]) + 1
				queue.append(int(neighbor))

	# 从外层向内结算；只读取更远一层的输出，同层和反向不会递归。
	var outputs: Dictionary = {}
	var max_distance := 0
	for id in nodes:
		if not distances.has(id):
			var info: Dictionary = nodes[id]
			(info.node as Node).set_aura_output_multiplier(info.aura, _base_modifier(info.aura))
		else:
			max_distance = maxi(max_distance, int(distances[id]))
	for distance in range(max_distance, -1, -1):
		for id in nodes:
			if int(distances.get(id, -1)) != distance:
				continue
			var info: Dictionary = nodes[id]
			var incoming := 1.0
			for neighbor in adjacency[id]:
				if int(distances.get(neighbor, -1)) == distance + 1:
					incoming = maxf(incoming, float(outputs[neighbor]))
			var output := _base_modifier(info.aura) * incoming
			outputs[id] = output
			(info.node as Node).set_aura_output_multiplier(info.aura, output)

	# 能量链同样从外层流向内层，不绘制同层或反向连接。
	for id in nodes:
		if not distances.has(id):
			continue
		var info: Dictionary = nodes[id]
		if not bool(info.aura.get("show_links", false)):
			continue
		for neighbor in adjacency[id]:
			if int(distances.get(neighbor, -1)) == int(distances[id]) - 1:
				_active_links.append({"source": info.node, "target": nodes[neighbor].node})


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
	var network_bases: Dictionary = {}
	var network_boosts: Dictionary = {}
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
					value = source.get_aura_output_multiplier(aura)
					var component := String(_network_components.get(source.get_instance_id(), group + ":none"))
					if not network_bases.has(component):
						network_bases[component] = 1.0
						network_boosts[component] = 1.0
						network_groups[component] = group
					# 同一网络的直接覆盖者各出基础倍率，公共链条只取一次最大增幅。
					network_bases[component] = float(network_bases[component]) * _base_modifier(aura)
					network_boosts[component] = maxf(float(network_boosts[component]), value / _base_modifier(aura))
					continue
				if value <= 0.0:
					continue
				var rule := String(aura.get("stack_rule", "max"))
				if rule == "stack":
					groups[group] = float(groups.get(group, 1.0)) * value
				elif not groups.has(group) or value > float(groups[group]):
					groups[group] = value
	for component in network_bases:
		var group: String = network_groups[component]
		var value := float(network_bases[component]) * float(network_boosts[component])
		groups[group] = float(groups.get(group, 1.0)) * value
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
