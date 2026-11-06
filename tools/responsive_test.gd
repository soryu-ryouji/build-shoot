extends Node

## 多分辨率下的无限镜头、HUD、商店、触摸部署和主界面回归。

const SIZES := [
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(1440, 900),
	Vector2i(1920, 800),
	Vector2i(844, 390),
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
		var field: Rect2 = main.ResponsiveLayout.field_rect(main)
		var base_screen: Vector2 = main.world_to_screen(main.base_core.global_position)
		var menu_rect: Rect2 = main.hud.settings_button.get_global_rect()
		var stats_rect: Rect2 = main.hud.stats_box.get_global_rect()
		var shop_rect: Rect2 = main.shop_bar.get_global_rect()
		print("RESPONSIVE GAME ", target, " logical=", view, " zoom=", main.world_camera.zoom.x)
		_check(field.grow(2.0).has_point(base_screen), "base inside field %s" % target)
		_check(not main.arena.map_loader.get_visible_cells().is_empty(), "visible ground generated %s" % target)
		_check(main.world_camera.zoom.x > 0.0, "positive camera zoom %s" % target)
		_check(_inside(menu_rect, view), "menu inside %s" % target)
		_check(_inside(stats_rect, view), "stats inside %s" % target)
		_check(_inside(shop_rect, view), "shop inside %s" % target)
		_check(menu_rect.size.y >= 52.0, "menu touch height %s" % target)
		_check(stats_rect.end.x <= view.x - 8.0, "stats align to screen right %s" % target)
		_check(stats_rect.position.x > menu_rect.end.x, "stats and menu are separate %s" % target)
		_check(main.hud.coins_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "coins text right aligned %s" % target)
		_check(main.hud.energy_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "energy text right aligned %s" % target)
		_check(field.position.y == 0.0, "field extends behind corner HUD %s" % target)
		_check(field.end.y <= shop_rect.position.y, "field avoids bottom shop %s" % target)
		_check_touch(main.hud.settings_button, "settings button %s" % target)
		_check_touch(main.shop_bar.cards[0], "shop card %s" % target)
		_check_font(main.hud.coins_label, 20, "HUD font %s" % target)
		_check_font(main.shop_bar.cards[0].name_label, 15, "shop font %s" % target)
		main.shop_bar._on_tab_pressed("energy")
		await _frames(2)
		_check(main.shop_bar.cards.size() == 2, "energy tab shows two direct items %s" % target)
		_check(main.shop_bar.cards[0].item.id == "solar", "tab cards expose item id %s" % target)
		main.shop_bar._on_tab_pressed("firepower")
		await _frames(2)
		var world := Vector2(256, 192)
		var round_trip: Vector2 = main.screen_to_world(main.world_to_screen(world))
		_check(round_trip.distance_to(world) < 0.1, "camera coordinate round trip %s" % target)
		main.coins = 500
		main._on_shop_drag_started("turret")
		main._on_shop_drag_moved(main.world_to_screen(world))
		main._on_shop_drag_released("turret", main.world_to_screen(world))
		_check(main.placed_buildings.size() == 1, "touch drag placement %s" % target)
		if main.placed_buildings.size() == 1:
			main.select_building(main.placed_buildings[0])
			await _frames(2)
			_check(main.focus_panel.visible, "focus panel opens %s" % target)
			_check(_inside(main.focus_panel.get_global_rect(), view), "focus panel inside %s" % target)
			_check(not main.focus_panel.get_global_rect().intersects(shop_rect), "focus avoids bottom shop %s" % target)
			_check_touch(main.focus_panel.close_button, "focus close %s" % target)
			main.clear_selection()
		for building in main.placed_buildings:
			main.arena.map_loader.clear_occupied(building.cell)
			building.queue_free()
		main.placed_buildings.clear()
		main.refresh_power()
		main._pan_camera(Vector2(50, 20))
		_check(main.camera_center != Vector2.ZERO, "camera pan %s" % target)
		main.center_on_base()
		main.open_settings()
		await _frames(2)
		_check(_inside(main.settings_panel.panel.get_global_rect(), view), "settings inside %s" % target)
		_check_touch(main.settings_panel.close_button, "settings close %s" % target)
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
		_check_touch(menu.start_button, "menu start %s" % target)
		_check_touch(menu.settings_button, "menu settings %s" % target)
		_check_touch(menu.quit_button, "menu quit %s" % target)
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
	_check(minf(control.size.x, control.size.y) >= 48.0, "%s too small" % message)


func _check_font(control: Control, minimum: int, message: String) -> void:
	_check(control.get_theme_font_size("font_size") >= minimum, "%s font too small" % message)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
