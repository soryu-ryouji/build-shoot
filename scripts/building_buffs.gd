extends RefCounted

## 建筑光环结算：同组取最高，不同组叠乘。
## propagate 光环按建造顺序由旧塔传向新塔，形成 DAG 后拓扑传播，不设倍率上限。

var game: Node
var _active_links: Array = []


func _init(owner_game: Node) -> void:
	game = owner_game


func recompute() -> void:
	if game == null:
		return
	_active_links.clear()
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
	var build_order: Dictionary = {}
	for i in game.placed_buildings.size():
		var building = game.placed_buildings[i]
		if is_instance_valid(building):
			build_order[building.get_instance_id()] = i
	var nodes: Dictionary = {}
	for building in game.placed_buildings:
		if not is_instance_valid(building) or not bool(building.alive) or not bool(building.powered):
			continue
		for aura in building.auras:
			var aura_group := String(aura.get("stack_group", aura.get("id", "aura")))
			if bool(aura.get("propagate", false)) and aura_group == group:
				nodes[building.get_instance_id()] = {"node": building, "aura": aura}

	var edges: Array = []
	for source_id in nodes:
		var source_info: Dictionary = nodes[source_id]
		var source: Node = source_info.node
		var aura: Dictionary = source_info.aura
		for target_id in nodes:
			if source_id == target_id:
				continue
			# 圆形覆盖天然双向，只保留旧塔到新塔的方向，避免相互递归。
			if int(build_order.get(source_id, 0)) >= int(build_order.get(target_id, 0)):
				continue
			var target: Node = nodes[target_id].node
			if _targets(aura, target) and source.covers_aura_point(target.global_position, aura):
				edges.append({"from": int(source_id), "to": int(target_id)})

	# 建造顺序已保证无环；这里仍过滤异常数据中的循环边。
	var active_edges: Array = []
	for edge in edges:
		if not _path_exists(int(edge.to), int(edge.from), edges):
			active_edges.append(edge)
	for edge in active_edges:
		var info: Dictionary = nodes[int(edge.from)]
		if bool(info.aura.get("show_links", false)):
			_active_links.append({"source": info.node, "target": nodes[int(edge.to)].node})

	var outgoing: Dictionary = {}
	var indegree: Dictionary = {}
	var incoming: Dictionary = {}
	for id in nodes:
		outgoing[id] = []
		indegree[id] = 0
		incoming[id] = 1.0
	for edge in active_edges:
		outgoing[int(edge.from)].append(edge)
		indegree[int(edge.to)] = int(indegree[int(edge.to)]) + 1

	var ready: Array[int] = []
	for id in nodes:
		if int(indegree[id]) == 0:
			ready.append(int(id))
	while not ready.is_empty():
		var id: int = ready.pop_back()
		var info: Dictionary = nodes[id]
		var aura: Dictionary = info.aura
		var output := _base_modifier(aura) * float(incoming[id])
		(info.node as Node).set_aura_output_multiplier(aura, output)
		for edge in outgoing[id]:
			var target_id := int(edge.to)
			incoming[target_id] = maxf(float(incoming[target_id]), output)
			indegree[target_id] = int(indegree[target_id]) - 1
			if int(indegree[target_id]) == 0:
				ready.append(target_id)


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


func _path_exists(start: int, goal: int, edges: Array) -> bool:
	var pending: Array[int] = [start]
	var visited: Dictionary = {}
	while not pending.is_empty():
		var current: int = pending.pop_back()
		if current == goal:
			return true
		if visited.has(current):
			continue
		visited[current] = true
		for edge in edges:
			if int(edge.from) == current:
				var next := int(edge.to)
				if not visited.has(next):
					pending.append(next)
	return false


func _base_modifier(aura: Dictionary) -> float:
	for modifier in aura.get("modifiers", []):
		if String(modifier.get("stat", "")) == "damage" and String(modifier.get("op", "mul")) == "mul":
			return float(modifier.get("value", 1.0))
	return 1.0


func _collect_multipliers(point: Vector2, target: Node) -> Dictionary:
	var groups: Dictionary = {}
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
				if bool(aura.get("propagate", false)):
					value = source.get_aura_output_multiplier(aura)
				if value <= 0.0:
					continue
				var group := String(aura.get("stack_group", aura.get("id", "aura")))
				var rule := String(aura.get("stack_rule", "max"))
				if rule == "stack":
					groups[group] = float(groups.get(group, 1.0)) * value
				elif not groups.has(group) or value > float(groups[group]):
					groups[group] = value
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
