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
var power_test_blocks: Array[Dictionary] = []
var power_destroyed_baseline := 0


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
		for kind in ["normal", "swift", "armored", "elite"]:
			var atlas: Texture2D = main.blocks.MONSTER_ANIMATIONS[kind]
			_check(atlas.get_width() == 1024 and atlas.get_height() == 256, "%s animation atlas has four frames" % kind)
		var first: Dictionary = main.blocks.blocks[0]
		var first_rect: Rect2 = first.rect
		_check(first_rect.position.y < 112.0, "first blocks start above the visible area")
		_check(int(first.max_hp) == 3, "first wave enemies have low health")
		_check(main.blocks.blocks.size() >= 3 and main.blocks.blocks.size() <= 4, "first wave has low enemy density")
		_check(String(first.kind) == "normal", "first row uses normal enemies")
		_check(main.blocks._enemy_count_for_wave(1) == 3, "wave one spawns three enemies")
		_check(main.blocks._rows_for_wave(1) == 1, "wave one is a single row")
		_check(int(main.blocks.wave) == 1, "opening wave is wave one")
		_check(float(main.blocks.next_wave_in) > 10.0, "opening phase has a long calm window")
		_check(main.blocks._rows_for_wave(2) == 3, "wave two floods three rows")
		_check(main.blocks._rows_for_wave(2) * main.blocks._enemy_count_for_wave(2) >= 30, "wave two brings at least thirty enemies")
		_check(main.blocks._rows_for_wave(6) > main.blocks._rows_for_wave(2), "later waves add rows")
		_check(main.blocks._calm_for_wave(2) >= 24.0, "calm window leaves room to clear")
		_check(main.blocks._calm_for_wave(6) > main.blocks._calm_for_wave(2), "bigger waves get more breathing room")
		_check(main.blocks._enemy_count_for_wave(4) > main.blocks._enemy_count_for_wave(1), "later waves increase enemy count")
		_check(main.blocks._enemy_count_for_wave(9) == main.blocks.COLS, "enemy count eventually fills a row")
		_check(main.blocks._base_health_for_wave(5) > main.blocks._base_health_for_wave(1) * 2, "enemy health climbs quickly")
		_check(main.blocks._base_health_for_wave(10) > main.blocks._base_health_for_wave(5) * 2, "health growth accelerates")
		_check(main.blocks._health_for_kind("swift", 6) < main.blocks._health_for_kind("normal", 6), "swift enemies have lighter health")
		_check(main.blocks._health_for_kind("armored", 6) > main.blocks._health_for_kind("normal", 6), "armored enemies have heavier health")
		_check(main.blocks._health_for_kind("elite", 6) > main.blocks._health_for_kind("armored", 6), "elite enemies have the thickest health")
		_check(main.blocks._speed_for_kind("swift") > main.blocks._speed_for_kind("normal"), "swift enemies move faster")
		_check(main.blocks._speed_for_kind("armored") < main.blocks._speed_for_kind("normal"), "armored enemies move slower")
		_check(float(main.blocks.HEALTH_BAR_HEIGHT) >= 6.0, "health bars are thicker than health pips")
		_check(float(first.get("hp_bar_time", -1.0)) == 0.0, "health bar hidden before the first hit")
		var hit: Dictionary = main.blocks.damage(int(first.id), 1)
		_check(bool(hit.hit) and not bool(hit.destroyed), "damage registers on a healthy block")
		_check(absf(float(first.hp_bar_time) - float(main.blocks.HEALTH_BAR_DURATION)) < 0.001, "health bar appears on hit")
		_check(is_equal_approx(float(main.blocks.HEALTH_BAR_DURATION), 3.0), "health bar lasts three seconds")
		# 手动推进一帧后再补一刀，确认倒计时被刷新而不是继续递减
		main.blocks._process(1.0)
		_check(float(first.hp_bar_time) < float(main.blocks.HEALTH_BAR_DURATION), "health bar countdown ticks down")
		main.blocks.damage(int(first.id), 1)
		_check(absf(float(first.hp_bar_time) - float(main.blocks.HEALTH_BAR_DURATION)) < 0.001, "repeated hits refresh the health bar timer")
		main.blocks._process(float(main.blocks.HEALTH_BAR_DURATION) + 0.1)
		_check(float(first.hp_bar_time) == 0.0, "health bar disappears after the timer runs out")
		var lowest := _lowest_block()
		tracked_id = int(lowest.id)
		var tracked_rect: Rect2 = lowest.rect
		tracked_y = tracked_rect.position.y

	if frame == 30:
		_check(float(main.blocks._animation_time) > 0.0, "monster animation clock advances")
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
		_check(int(basic.upgrade_damage) == 2 and absf(float(basic.upgrade_rate) - 0.2) < 0.001, "basic turret upgrades +2 damage and +0.2 rate")
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
		_check(int(heavy.damage) == 10, "heavy turret base damage")
		_check(int(heavy.upgrade_damage) == 20, "heavy turret upgrades +20 damage")
		_check(int(heavy.pierce) == -1, "heavy turret pierces while power remains")
		_check(absf(float(heavy.interval) - 2.0) < 0.001, "heavy turret fires slowly")
		_check(int(heavy.attack_range) == 500, "heavy turret long range")

	if frame == 100:
		if heavy != null:
			main.select_turret(heavy)
			_check(main.focus_panel.visible, "heavy focus panel opens")
			_check(main.focus_panel.stat_values[3].text == "∞", "focus panel shows unlimited pierce")
			main.clear_selection()

	if frame == 120:
		_check(heavy != null and is_instance_valid(heavy), "heavy turret alive")
		if heavy != null:
			_check(int(heavy.shots) > 0, "placed turret fires automatically")
			_check(heavy.has_target(), "placed turret acquires target")

	if frame == 140:
		# 点击特定炮塔后用金币升级伤害与攻速
		if heavy != null:
			main.select_turret(heavy)
			var before_coins := int(main.coins)
			var cost := int(heavy.get_upgrade_cost())
			var before_damage := int(heavy.get_effective_damage())
			var before_rate := float(heavy.get_effective_rate())
			main.upgrade_selected()
			_check(int(main.coins) == before_coins - cost, "upgrade costs coins")
			_check(int(heavy.get_effective_damage()) == before_damage + 20, "upgrade adds 20 damage")
			_check(absf(float(heavy.get_effective_rate()) - (before_rate + 0.2)) < 0.001, "upgrade adds 0.2 attack speed")
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
		main.blocks.next_wave_in = 999.0
		for b in main.blocks.blocks:
			b.alive = false

	if frame == 221:
		_check(heavy != null and is_instance_valid(heavy), "heavy turret alive at no-target test")
		if heavy != null:
			_check(not heavy.has_target(), "turret clears target when no enemy is lockable")

	if frame == 222:
		# 重炮按威力预算贯穿：5 点威力打掉 3 个 1 血目标，再用剩余 2 点砍掉 3 血目标的 2 点血
		heavy._cooldown = 999.0
		var origin := Vector2(360.0, 740.0)
		for i in 3:
			power_test_blocks.append(_add_test_block(origin + Vector2(0.0, -50.0 * float(i + 1)), 1))
		power_test_blocks.append(_add_test_block(origin + Vector2(0.0, -200.0), 3))
		power_destroyed_baseline = int(main.blocks.destroyed)
		main.fire_item_ball(heavy, origin, Vector2.UP, 5, -1, 0, 500.0, 7.0)

	if frame == 250:
		_check(int(main.blocks.destroyed) == power_destroyed_baseline + 3, "heavy ball spends power on each kill")
		_check(power_test_blocks.size() == 4, "heavy ball test blocks exist")
		if power_test_blocks.size() == 4:
			var last: Dictionary = power_test_blocks[3]
			_check(bool(last.alive) and int(last.hp) == 1, "heavy ball leaves a three-health target at one health")
		_check(main.active_balls.is_empty(), "heavy ball stops once its power runs out")

	if frame == 230:
		main.open_settings()
		_check(main.settings_panel.visible, "in-game settings panel opens")
		_check(get_tree().paused, "in-game settings pause gameplay")
		GameSettings.set_option("show_grid", false)
		_check(not GameSettings.show_grid, "settings option updates immediately")
		GameSettings.set_option("show_grid", true)

	if frame == 232:
		main.close_settings()
		_check(not main.settings_panel.visible, "in-game settings panel closes")
		_check(not get_tree().paused, "closing settings resumes gameplay")
		var menu_scene: PackedScene = load("res://scenes/main_menu.tscn")
		var menu := menu_scene.instantiate()
		add_child(menu)
		_check(menu.start_button != null and menu.settings_button != null, "main menu builds actions")
		menu.open_settings()
		_check(menu.settings_panel.visible, "main menu settings open")
		_check(not menu.settings_panel.in_game, "main menu hides in-game actions")
		_check(not get_tree().paused, "main menu settings do not pause tree")
		menu.settings_panel.close_panel()
		_check(not menu.settings_panel.visible, "main menu settings close")
		menu.queue_free()

	if frame == 240:
		# 清场倒计时结束后应推进到下一波并批量生成
		var wave_before := int(main.blocks.wave)
		var blocks_before: int = main.blocks.blocks.size()
		main.blocks.next_wave_in = 0.0
		main.blocks._physics_process(0.016)
		_check(int(main.blocks.wave) == wave_before + 1, "wave advances when the calm timer ends")
		_check(float(main.blocks.next_wave_in) > 0.0, "next wave countdown restarts")
		_check(main.blocks.blocks.size() > blocks_before, "new wave spawns a batch")

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


func _add_test_block(center: Vector2, hp: int) -> Dictionary:
	var id := int(main.blocks._next_id)
	main.blocks._next_id += 1
	var block := {
		"id": id,
		"kind": "normal",
		"rect": Rect2(center - Vector2(24.0, 15.0), Vector2(48.0, 30.0)),
		"hp": hp,
		"max_hp": hp,
		"speed_scale": 0.0,
		"color": Color.WHITE,
		"flash": 0.0,
		"hp_bar_time": 0.0,
		"alive": true,
	}
	main.blocks.blocks.append(block)
	main.blocks.by_id[id] = block
	return block


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
