extends Node

## 无头冒烟测试：准备阶段、网格布置、聚焦面板、金币升级攻击力、自动索敌、无目标隐藏锁定线、i18n。
## 用法：
##   Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 60 --path . res://tools/smoke_test.tscn

var main: Node
var frame := 0
var failures: Array[String] = []
var tracked_id := -1
var tracked_y := 0.0
var heavy: Node = null
var auto_coins_baseline := 0
var auto_destroyed_baseline := 0


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
		_check(int(first.max_hp) == 3, "first wave enemies have low health")
		_check(main.blocks.blocks.size() >= 3 and main.blocks.blocks.size() <= 4, "first wave has low enemy density")
		_check(String(first.kind) == "normal", "first row uses normal enemies")
		_check(main.blocks._wave_for_row(0) == 1 and main.blocks._wave_for_row(4) == 1, "first five rows form wave one")
		_check(main.blocks._wave_for_row(5) == 2, "row five starts wave two")
		_check(main.blocks._enemy_count_for_wave(1) == 3, "wave one starts with three enemies per row")
		_check(main.blocks._enemy_count_for_wave(4) > main.blocks._enemy_count_for_wave(1), "later waves increase enemy count")
		_check(main.blocks._enemy_count_for_wave(9) == main.blocks.COLS, "enemy count eventually fills a row")
		_check(main.blocks._base_health_for_wave(4) > main.blocks._base_health_for_wave(1), "later waves increase base health")
		_check(main.blocks._health_for_kind("swift", 6) < main.blocks._health_for_kind("normal", 6), "swift enemies have lighter health")
		_check(main.blocks._health_for_kind("armored", 6) > main.blocks._health_for_kind("normal", 6), "armored enemies have heavier health")
		_check(main.blocks._health_for_kind("elite", 6) > main.blocks._health_for_kind("armored", 6), "elite enemies have the thickest health")
		_check(main.blocks._speed_for_kind("swift") > main.blocks._speed_for_kind("normal"), "swift enemies move faster")
		_check(main.blocks._speed_for_kind("armored") < main.blocks._speed_for_kind("normal"), "armored enemies move slower")
		_check(float(main.blocks.HEALTH_BAR_HEIGHT) >= 6.0, "health bars are thicker than health pips")
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
		_check(int(basic.attack_range) == 300, "basic turret short range")
		var left: Vector2 = main.snap_to_grid(Vector2(65, 400))
		var right: Vector2 = main.snap_to_grid(Vector2(655, 400))
		var top: Vector2 = main.snap_to_grid(Vector2(416, 113))
		var bottom: Vector2 = main.snap_to_grid(Vector2(416, 790))
		var corner: Vector2 = main.snap_to_grid(Vector2(660, 805))
		_check(is_equal_approx(left.x, 96.0), "left edge snaps")
		_check(is_equal_approx(right.x, 624.0), "right edge snaps")
		_check(is_equal_approx(top.y, 144.0), "top edge snaps")
		_check(is_equal_approx(bottom.y, 768.0), "bottom edge snaps")
		_check(is_equal_approx(corner.x, 624.0) and is_equal_approx(corner.y, 768.0), "frame edge clamps")
		_check(main.is_valid_placement(left), "left edge cell is placeable")
		_check(main.is_valid_placement(right), "right edge cell is placeable")
		_check(main.is_valid_placement(top), "top edge cell is placeable")
		_check(main.is_valid_placement(bottom), "bottom edge cell is placeable")
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
		_check(int(heavy.attack_range) == 500, "heavy turret long range")

	if frame == 100:
		if heavy != null:
			main.select_turret(heavy)
			_check(main.focus_panel.visible, "heavy focus panel opens")
			main.clear_selection()

	if frame == 120:
		_check(heavy != null and is_instance_valid(heavy), "heavy turret alive")
		if heavy != null:
			_check(int(heavy.shots) > 0, "placed turret fires automatically")
			_check(heavy.has_target(), "placed turret acquires target")

	if frame == 140:
		# 点击特定炮塔后用金币升级攻击力
		if heavy != null:
			main.select_turret(heavy)
			var before_coins := int(main.coins)
			var cost := int(heavy.get_upgrade_cost())
			var before_damage := int(heavy.get_effective_damage())
			main.upgrade_selected_damage()
			_check(int(main.coins) == before_coins - cost, "upgrade costs coins")
			_check(int(heavy.get_effective_damage()) == before_damage + 1, "upgrade adds damage")
			_check(int(heavy.upgrade_level) == 1, "upgrade level recorded")
			_check(main.focus_panel.visible, "focus panel stays open after upgrade")
			main.clear_selection()

	if frame == 160:
		var target := _lowest_block()
		var before_destroyed := int(main.blocks.destroyed)
		var before_coins := int(main.coins)
		var reward := int(target.max_hp)
		var before_particles: int = int(main.effects.count())
		main.hit_block(int(target.id), 999)
		_check(int(main.blocks.destroyed) == before_destroyed + 1, "direct hit destroys a block")
		_check(int(main.coins) >= before_coins + reward, "block destruction awards coins")
		_check(int(main.effects.count()) > before_particles, "hit spawns particles")

	if frame == 200:
		var before_count: int = int(main.active_balls.size())
		main.fire_item_ball(heavy, heavy.get_muzzle(), Vector2.UP, 1, 0, 1, 500.0, 7.0)
		_check(main.active_balls.size() == before_count + 1, "item ball spawned")
		if main.active_balls.size() > 0:
			var ball: Node = main.active_balls[main.active_balls.size() - 1]
			ball.bounces_left = 1
			ball._spend_bounce()
			_check(main.active_balls.size() == before_count, "ball vanishes when bounces run out")

		# 用近程低血量目标和就绪的炮塔验证自动击杀，避免随机阵型造成时序抖动
		for b in main.blocks.blocks:
			if bool(b.alive):
				b.hp = 1
		if heavy != null:
			heavy._cooldown = 0.0
			var target_rect := Rect2(heavy.global_position + Vector2(-24.0, -115.0), Vector2(48.0, 30.0))
			var target_id := int(main.blocks._next_id)
			main.blocks._next_id += 1
			var target := {
				"id": target_id,
				"kind": "normal",
				"rect": target_rect,
				"hp": 1,
				"max_hp": 1,
				"speed_scale": 0.0,
				"color": Color.WHITE,
				"flash": 0.0,
				"alive": true,
			}
			main.blocks.blocks.append(target)
			main.blocks.by_id[target_id] = target
		auto_destroyed_baseline = int(main.blocks.destroyed)
		auto_coins_baseline = int(main.coins)

	if frame == 219:
		_check(int(main.blocks.destroyed) > auto_destroyed_baseline, "placed turret destroys blocks")
		_check(int(main.coins) > auto_coins_baseline, "placed turret earns coins")

	if frame == 220:
		# 清空所有目标，下一帧检查炮塔不再显示锁定线
		main.blocks._spawn_timer = 999.0
		for b in main.blocks.blocks:
			b.alive = false

	if frame == 221:
		_check(heavy != null and is_instance_valid(heavy), "heavy turret alive at no-target test")
		if heavy != null:
			_check(not heavy.has_target(), "turret clears target when no enemy is lockable")

	if frame >= 260:
		if failures.is_empty():
			print("SMOKE TEST PASS  destroyed=%d coins=%d" % [
				int(main.blocks.destroyed), int(main.coins)
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


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
