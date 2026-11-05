extends RefCounted

## 建筑光环结算：基础属性始终保留，有效攻击由当前在线光环重新计算。
## 同一 stack_group 默认取最高，不同 stack_group 的伤害倍率叠乘。

var game: Node


func _init(owner_game: Node) -> void:
	game = owner_game


func recompute() -> void:
	if game == null:
		return
	for target in game.placed_buildings:
		if not is_instance_valid(target) or not bool(target.alive):
			continue
		if not bool(target.is_firepower()):
			continue
		target.set_buff_damage_multiplier(_multiplier_for(target))


func get_multiplier_at(point: Vector2) -> float:
	return _product(_collect_multipliers(point, null))


func _multiplier_for(target: Node) -> float:
	if not bool(target.powered):
		return 1.0
	return _product(_collect_multipliers(target.global_position, target))


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
	return categories.is_empty() or categories.has(String(target.category))


func _product(groups: Dictionary) -> float:
	var result := 1.0
	for value in groups.values():
		result *= float(value)
	return result
