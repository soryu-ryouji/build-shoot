extends Node

## 动态调整窗口，验证 HUD、商店、菜单、设置与战场坐标换算。
## 同时回归移动端可读性：可点击控件不小于 48 逻辑像素，正文不小于 15。

const SIZES := [
	Vector2i(720, 960),
	Vector2i(1000, 2000),
	Vector2i(1080, 1920),
	Vector2i(1080, 2400),
]

var failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
		_check(main.hud.top_panel.size.y >= 88.0, "HUD keeps touch height %s" % target)
		_check_touch(main.hud.settings_button, "HUD settings button %s" % target)
		_check_touch(main.shop_bar.cards[0], "shop card %s" % target)
		_check(main.shop_bar.cards[0].size.y >= 88.0, "shop card height %s" % target)
		_check_font(main.hud.mode_label, 20, "HUD mode font %s" % target)
		_check_font(main.shop_bar.cards[0].name_label, 15, "shop item name font %s" % target)
		var world := Vector2(400, 400)
		var round_trip: Vector2 = main.screen_to_world(main.world_to_screen(world))
		_check(round_trip.distance_to(world) < 0.1, "touch coordinate round trip %s" % target)
		main.coins = 500
		main._on_shop_drag_started("turret")
		main._on_shop_drag_moved(main.world_to_screen(world))
		main._on_shop_drag_released("turret", main.world_to_screen(world))
		_check(not main.orienting, "turret places without orientation %s" % target)
		_check(main.placed_buildings.size() == 1, "touch drag placement %s" % target)
		if main.placed_buildings.size() == 1:
			main.select_building(main.placed_buildings[0])
			await _frames(2)
			_check(main.focus_panel.visible, "focus panel opens %s" % target)
			_check(_inside(main.focus_panel.get_global_rect(), view), "focus panel inside %s" % target)
			_check_touch(main.focus_panel.close_button, "focus close button %s" % target)
			_check_touch(main.focus_panel.dismantle_button, "focus dismantle button %s" % target)
			main.clear_selection()
		for building in main.placed_buildings:
			building.queue_free()
		main.placed_buildings.clear()
		main.refresh_power()
		main.open_settings()
		await _frames(2)
		_check(_inside(main.settings_panel.panel.get_global_rect(), view), "settings inside %s" % target)
		_check_touch(main.settings_panel.close_button, "settings close button %s" % target)
		_check_touch(main.settings_panel.option_buttons["show_grid"], "settings option %s" % target)
		_check_touch(main.settings_panel.resume_button, "settings resume %s" % target)
		_check_font(main.settings_panel.option_buttons["show_grid"], 15, "settings option font %s" % target)
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
		_check(menu.actions_box.position.y > view.y * 0.5, "menu actions in thumb reach %s" % target)
		_check_touch(menu.start_button, "menu start button %s" % target)
		_check_touch(menu.settings_button, "menu settings button %s" % target)
		_check_touch(menu.quit_button, "menu quit button %s" % target)
		_check_font(menu.start_button, 20, "menu start font %s" % target)
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


func _check_touch(control: Control, message: String) -> void:
	var side := minf(control.size.x, control.size.y)
	_check(side >= 48.0, "%s too small: %.1f" % [message, side])


func _check_font(control: Control, minimum: int, message: String) -> void:
	var size := control.get_theme_font_size("font_size")
	_check(size >= minimum, "%s font too small: %d" % [message, size])


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
