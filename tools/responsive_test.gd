extends Node

## 动态调整窗口，验证 HUD、商店、菜单、设置与战场坐标换算。

const SIZES := [
	Vector2i(720, 960),
	Vector2i(1000, 2000),
	Vector2i(1080, 1920),
	Vector2i(1080, 2400),
]

var failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().content_scale_size = Vector2i(720, 960)
	call_deferred("_run")


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)

	for target in SIZES:
		get_window().size = target
		await _frames(4)
		var view: Vector2 = get_viewport().get_visible_rect().size
		var frame_left: Vector2 = main.world_to_screen(Vector2(48, 96))
		var frame_right: Vector2 = main.world_to_screen(Vector2(672, 816))
		print("RESPONSIVE GAME ", target, " logical=", view, " zoom=", main.world_camera.zoom.x, " frame_width=", frame_right.x - frame_left.x)
		_check(absf((frame_right.x - frame_left.x) - (view.x - 16.0)) < 1.0, "arena fits width %s" % target)
		_check(frame_left.x >= 7.5 and frame_right.x <= view.x - 7.5, "arena edges visible %s" % target)
		_check(_inside(main.hud.top_panel.get_global_rect(), view), "HUD inside %s" % target)
		_check(_inside(main.shop_bar.get_global_rect(), view), "shop inside %s" % target)
		var world := Vector2(400, 400)
		var round_trip: Vector2 = main.screen_to_world(main.world_to_screen(world))
		_check(round_trip.distance_to(world) < 0.1, "touch coordinate round trip %s" % target)
		main.coins = 500
		main._on_shop_drag_started("turret")
		main._on_shop_drag_moved(main.world_to_screen(world))
		main._on_shop_drag_released("turret", main.world_to_screen(world))
		_check(main.placed_turrets.size() == 1, "touch drag placement %s" % target)
		for turret in main.placed_turrets:
			turret.queue_free()
		main.placed_turrets.clear()
		main.open_settings()
		await _frames(2)
		_check(_inside(main.settings_panel.panel.get_global_rect(), view), "settings inside %s" % target)
		main.close_settings()

	main.queue_free()
	await _frames(2)
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await _frames(2)
	for target in SIZES:
		get_window().size = target
		await _frames(4)
		var view: Vector2 = get_viewport().get_visible_rect().size
		_check(_inside(menu.title_box.get_global_rect(), view), "menu title inside %s" % target)
		_check(_inside(menu.actions_box.get_global_rect(), view), "menu actions inside %s" % target)
		_check(menu.actions_box.position.y < view.y * 0.65, "menu actions above bottom %s" % target)
		menu.open_settings()
		await _frames(2)
		_check(_inside(menu.settings_panel.panel.get_global_rect(), view), "menu settings inside %s" % target)
		menu.settings_panel.close_panel()

	if failures.is_empty():
		print("RESPONSIVE TEST PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		get_tree().quit(1)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _inside(rect: Rect2, view: Vector2) -> bool:
	return Rect2(Vector2.ZERO, view).encloses(rect)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
