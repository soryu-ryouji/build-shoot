extends Node

## 无头冒烟测试：滚动方块、初始节奏、单球替换、弹跳耗尽、升级、经验。
## 用法：
##   Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 60 --path . res://tools/smoke_test.tscn

var main: Node
var frame := 0
var failures: Array[String] = []
var tracked_id := -1
var tracked_y := 0.0
var target_id := -1
var target_hp := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var packed: PackedScene = load("res://scenes/main.tscn")
	main = packed.instantiate()
	add_child(main)


func _process(_delta: float) -> void:
	frame += 1

	if frame == 2:
		_check(main.blocks.blocks.size() > 0, "initial stream populated")
		_check(main.blocks.blocks.size() < 30, "opening block count is low (got %d)" % main.blocks.blocks.size())
		# 关掉自动开火，后面的用例手动控制发射时机
		main.auto_fire = false
		for b in main.active_balls:
			if is_instance_valid(b):
				b.alive = false
				b.queue_free()
		main.active_balls.clear()
		main.fire_timer = 0.0
		_check(main.active_balls.is_empty(), "no ball before manual fire")
		var lowest := _lowest_block()
		tracked_id = int(lowest.id)
		var tracked_rect: Rect2 = lowest.rect
		tracked_y = tracked_rect.position.y

	if frame == 62:
		var b = main.blocks.by_id.get(tracked_id)
		_check(b != null, "tracked block still on screen")
		if b != null:
			var block: Dictionary = b
			var rect: Rect2 = block.rect
			_check(rect.position.y > tracked_y + 10.0, "blocks scroll downward")

		var target := _lowest_block()
		target_id = int(target.id)
		target_hp = int(target.hp)
		_fire_at_lowest()
		_check(main.active_balls.size() == 1, "ball spawned")
		_check(int(main.active_balls[0].bounces_left) == 0, "ball has no bounces at start")

	if frame == 66:
		var before: Node = main.active_balls[0]
		main.request_fire()
		_check(main.active_balls.size() == 1 and main.active_balls[0] == before, "gun cooldown blocks refire")

	if frame == 82:
		_fire_at_lowest()
		_check(main.active_balls.size() == 2, "consecutive shots keep the old ball")
		if main.active_balls.size() == 2:
			_check(main.active_balls[0] != main.active_balls[1], "each shot is a separate ball")
			_check(bool(main.active_balls[0].alive) and bool(main.active_balls[1].alive), "both balls stay alive")

	if frame == 140:
		var b = main.blocks.by_id.get(target_id)
		var hit := false
		if b == null:
			hit = true
		else:
			var block: Dictionary = b
			hit = int(block.hp) < target_hp
		_check(hit, "ball damaged the targeted block")

	if frame == 200:
		_resolve_all_upgrades()
		var choices: Array = main._pick_upgrades(3)
		_check(not choices.is_empty(), "upgrade choices available")
		var picked := String(choices[0].id)
		var before := int(main.upgrades.get(picked, 0))
		main._open_upgrade()
		_check(main.state == 1, "upgrade state entered")
		_check(get_tree().paused, "scene tree paused during upgrade")
		main._on_upgrade_chosen(picked)
		_check(not get_tree().paused, "unpaused after choosing upgrade")
		_check(int(main.upgrades.get(picked, 0)) == before + 1, "upgrade applied: %s" % picked)

	if frame == 220:
		for b in main.active_balls:
			if is_instance_valid(b):
				b.alive = false
				b.queue_free()
		main.active_balls.clear()
		main._spawn_ball(main.turret.get_muzzle(), Vector2.UP)
		var ball: Node = main.active_balls[0]
		ball.bounces_left = 1
		ball._spend_bounce()
		_check(main.active_balls.is_empty(), "ball vanishes when bounces run out")

	if frame == 240:
		var target := _lowest_block()
		var before_destroyed := int(main.blocks.destroyed)
		main.hit_block(int(target.id), 999)
		_check(int(main.blocks.destroyed) == before_destroyed + 1, "direct hit destroys a block")
		_check(int(main.combo) > 0, "combo counted")
		_resolve_all_upgrades()

	if frame == 260:
		for def in main.UPGRADE_DEFS:
			while int(main.upgrades.get(String(def.id), 0)) < int(def.max):
				main._apply_upgrade(String(def.id))
		_check(int(main.stats.bounces) == 8, "bounce upgrades stack (0 + 4x2)")
		_check(float(main.stats.crit) > 0.0, "crit upgrade applied")
		_fire_at_lowest()
		_check(main.active_balls.size() == 1, "can fire after previous ball vanished")
		_check(int(main.active_balls[0].bounces_left) == 8, "new ball receives upgraded bounces")

	if frame == 300:
		main.add_xp(300)
		_resolve_all_upgrades()
		_check(int(main.level) > 1, "level increased from xp")

	if frame == 400:
		main.blocks.scroll_speed = 400.0

	if frame == 500:
		for b in main.active_balls:
			if is_instance_valid(b):
				b.alive = false
				b.queue_free()
		main.active_balls.clear()
		main.auto_fire = true
		main.fire_timer = 0.0

	if frame == 520:
		_check(main.blocks.blocks.size() < 200, "scrolled blocks are culled")
		_check(main.blocks.spawned_rows > 4, "new rows keep spawning")
		_check(main.active_balls.size() > 0, "auto fire spawns balls without input")
		_check(main.active_balls.size() < 40, "live ball count stays bounded")

	if frame >= 540:
		if failures.is_empty():
			print("SMOKE TEST PASS  level=%d destroyed=%d rows=%d" % [
				int(main.level), int(main.blocks.destroyed), int(main.blocks.spawned_rows)
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


func _fire_at_lowest() -> void:
	var target := _lowest_block()
	var rect: Rect2 = target.rect
	var origin: Vector2 = main.turret.get_muzzle()
	main.turret.aim_angle = (rect.get_center() - origin).angle()
	main.request_fire()


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
