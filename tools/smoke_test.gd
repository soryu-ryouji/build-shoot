extends Node

## 无头冒烟测试：无默认炮塔、网格布置、自动索敌开火、升级生效、无目标隐藏锁定线、i18n。
## 用法：
##   Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 60 --path . res://tools/smoke_test.tscn

var main: Node
var frame := 0
var failures: Array[String] = []
var tracked_id := -1
var tracked_y := 0.0
var heavy: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var packed: PackedScene = load("res://scenes/main.tscn")
	main = packed.instantiate()
	add_child(main)


func _process(_delta: float) -> void:
	frame += 1

	if frame == 2:
		_check(main.blocks.blocks.is_empty(), "no blocks during preparation")
		_check(main.preparing, "preparation phase active")
		_check(float(main.prep_timer) > 4.5, "preparation lasts about 5 seconds")
		_check(int(main.coins) == 30, "starts with 30 coins")
		_check(not main.has_node("Turret"), "no default turret on the map")
		_check(main.placed_turrets.is_empty(), "no placed turret at start")

	if frame == 3:
		_check(I18n.locale == "zh_CN", "default locale is Chinese")
		_check(I18n.t("hud.ready") == "就绪", "Chinese translation loaded")
		_check(I18n.t("hud.coins", [3]) == "金币 3", "coin translation loaded")
		var missing := I18n.missing_keys("en")
		_check(missing.is_empty(), "en locale has all keys: %s" % str(missing))
		I18n.set_locale("en")
		_check(I18n.t("hud.ready") == "READY", "English translation loads")
		I18n.toggle_locale()
		_check(I18n.locale == "zh_CN", "locale toggles back to Chinese")

	if frame == 4:
		# 跳过剩余准备时间，后续用例直接测试战斗
		main.prep_timer = 0.0

	if frame == 6:
		_check(not main.preparing, "preparation ends")
		_check(main.blocks.blocks.size() > 0, "block stream starts after preparation")
		var first: Dictionary = main.blocks.blocks[0]
		var first_rect: Rect2 = first.rect
		_check(first_rect.position.y < 112.0, "first blocks start above the visible area")
		var lowest := _lowest_block()
		tracked_id = int(lowest.id)
		var tracked_rect: Rect2 = lowest.rect
		tracked_y = tracked_rect.position.y

	if frame == 30:
		var tracked = main.blocks.by_id.get(tracked_id)
		_check(tracked != null, "tracked block still on screen")
		if tracked != null:
			var block: Dictionary = tracked
			var rect: Rect2 = block.rect
			_check(rect.position.y > tracked_y + 5.0, "blocks scroll downward")

		# 基础炮塔：30 金币、网格吸附、聚焦面板、拆除退款
		main.begin_placement("turret")
		_check(main.placing, "placement begins")
		main.update_placement(Vector2(400, 400))
		main.finish_placement("turret", Vector2(400, 400))
		_check(main.placed_turrets.size() == 1, "basic turret placed")
		_check(int(main.coins) == 0, "basic turret costs 30")
		var basic: Node = main.placed_turrets[0]
		_check(basic.global_position == main.snap_to_grid(Vector2(400, 400)), "placement snaps to grid")
		_check(int(basic.damage) == 1, "basic turret base damage")
		_check(absf(float(basic.interval) - 0.3) < 0.001, "basic turret interval")

		main.select_turret(basic)
		_check(main.focus_panel.visible, "focus panel opens")
		main.dismantle_selected()
		_check(main.placed_turrets.is_empty(), "basic turret dismantled")
		_check(not main.focus_panel.visible, "focus panel closes")
		_check(int(main.coins) == 15, "dismantle refunds half")

		# 金币不足 / 非法位置
		main.coins = 0
		main.begin_placement("turret")
		_check(not main.placing, "cannot place without coins")
		main.coins = 500
		main.begin_placement("turret")
		main.finish_placement("turret", Vector2(10, 10))
		_check(main.placed_turrets.is_empty(), "invalid placement rejected")
		_check(int(main.coins) == 500, "invalid placement costs nothing")

		# 重型炮塔
		main.begin_placement("heavy_turret")
		main.finish_placement("heavy_turret", Vector2(250, 250))
		_check(main.placed_turrets.size() == 1, "heavy turret placed")
		_check(int(main.coins) == 300, "heavy turret costs 200")
		heavy = main.placed_turrets[0]
		_check(int(heavy.damage) == 3, "heavy turret base damage")
		_check(int(heavy.pierce) == 3, "heavy turret pierces blocks")
		_check(absf(float(heavy.interval) - 2.0) < 0.001, "heavy turret fires slowly")
		_check(int(heavy.attack_range) == 300, "heavy turret range")

	if frame == 120:
		_check(heavy != null and is_instance_valid(heavy), "heavy turret alive")
		if heavy != null:
			_check(int(heavy.shots) > 0, "placed turret fires automatically")
			_check(heavy.has_target(), "placed turret acquires target")
		_check(int(main.blocks.destroyed) > 0, "placed turret destroys blocks")
		_check(int(main.coins) > 300, "placed turret earns coins")

	if frame == 100:
		if heavy != null:
			main.select_turret(heavy)
			_check(main.focus_panel.visible, "heavy focus panel opens")
			main.clear_selection()

	if frame == 140:
		var target := _lowest_block()
		var before_destroyed := int(main.blocks.destroyed)
		var before_coins := int(main.coins)
		var reward := int(target.max_hp)
		var before_particles: int = int(main.effects.count())
		main.hit_block(int(target.id), 999)
		_check(int(main.blocks.destroyed) == before_destroyed + 1, "direct hit destroys a block")
		_check(int(main.coins) >= before_coins + reward, "block destruction awards coins")
		_check(int(main.effects.count()) > before_particles, "hit spawns particles")

		_resolve_all_upgrades()
		var choices: Array = main._pick_upgrades(3)
		_check(not choices.is_empty(), "upgrade choices available")
		var picked := String(choices[0].id)
		var before_upgrade := int(main.upgrades.get(picked, 0))
		main._open_upgrade()
		_check(main.state == 1, "upgrade state entered")
		_check(get_tree().paused, "scene tree paused during upgrade")
		main._on_upgrade_chosen(picked)
		_check(not get_tree().paused, "unpaused after choosing upgrade")
		_check(int(main.upgrades.get(picked, 0)) == before_upgrade + 1, "upgrade applied: %s" % picked)

	if frame == 180:
		for def in main.UPGRADE_DEFS:
			while int(main.upgrades.get(String(def.id), 0)) < int(def.max):
				main._apply_upgrade(String(def.id))
		_check(int(main.stats.bounces) == 8, "bounce upgrades stack")
		_check(float(main.stats.crit) > 0.0, "crit upgrade applied")
		_check(heavy != null and is_instance_valid(heavy), "heavy turret still alive")
		if heavy != null:
			_check(int(heavy.get_effective_damage()) == 3 + 5, "upgrades add turret damage")
			_check(int(heavy.get_effective_pierce()) == 3 + 3, "upgrades add turret pierce")
			_check(int(heavy.get_effective_bounces()) == 0 + 8, "upgrades add turret bounces")
			_check(float(heavy.get_effective_speed()) > 560.0, "upgrades add turret speed")
			_check(float(heavy.get_effective_radius()) > 8.0, "upgrades add turret radius")

	if frame == 200:
		var before_count: int = int(main.active_balls.size())
		main.fire_item_ball(heavy, heavy.get_muzzle(), Vector2.UP, 1, 0, 1, 500.0, 7.0)
		_check(main.active_balls.size() == before_count + 1, "item ball spawned")
		if main.active_balls.size() > 0:
			var ball: Node = main.active_balls[main.active_balls.size() - 1]
			ball.bounces_left = 1
			ball._spend_bounce()
			_check(main.active_balls.size() == before_count, "ball vanishes when bounces run out")

	if frame == 220:
		# 清空所有目标，下一帧检查炮塔不再显示锁定线
		main.blocks._spawn_timer = 999.0
		for b in main.blocks.blocks:
			b.alive = false

	if frame == 221:
		_check(heavy != null and is_instance_valid(heavy), "heavy turret alive at no-target test")
		if heavy != null:
			_check(not heavy.has_target(), "turret clears target when no enemy is lockable")

	if frame == 240:
		main.add_xp(300)
		_resolve_all_upgrades()
		_check(int(main.level) > 1, "level increased from xp")

	if frame >= 280:
		if failures.is_empty():
			print("SMOKE TEST PASS  level=%d destroyed=%d coins=%d" % [
				int(main.level), int(main.blocks.destroyed), int(main.coins)
			])
			get_tree().quit(0)
		else:
			for f in failures:
				printerr("FAIL: " + f)
			get_tree().quit(1)


func _lowest_block() -> Dictionary:
	var lowest: Dictionary = {}
	var best := -INF
	for b in main.blocks.blocks:
		if not bool(b.alive):
			continue
		var rect: Rect2 = b.rect
		if rect.position.y > best:
			best = rect.position.y
			lowest = b
	return lowest


func _resolve_all_upgrades() -> void:
	var guard := 0
	while get_tree().paused and guard < 20:
		guard += 1
		var choices: Array = main._pick_upgrades(3)
		if choices.is_empty():
			main.pending_levels = 0
			main.upgrade_screen.hide_screen()
			main.state = 0
			get_tree().paused = false
			break
		main._on_upgrade_chosen(String(choices[0].id))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
