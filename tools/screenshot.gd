extends Node

## 基地防守截图：围绕中央基地布防，展示巢穴、敌人和自动攻击。
## 附加 -- --place / --orient / --focus / --power / --settings。

const ItemDefs = preload("res://scripts/item_defs.gd")
const DEFAULT_SIZE := Vector2i(1080, 2400)

var main: Node


func _ready() -> void:
	var target_size := _requested_size()
	get_window().size = target_size
	_apply_locale_argument()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	main.coins = 5000
	_place("fusion_tower", Vector2i(-3, 2))
	_place("fusion_tower", Vector2i(3, 2))
	_place("solar", Vector2i(0, 4))
	_place("solar", Vector2i(-2, -4))
	var turret_a: Node = _place("turret", Vector2i(-4, 0))
	_place("turret", Vector2i(4, 0))
	_place("heavy_turret", Vector2i(-4, -4))
	_place("laser_tower", Vector2i(4, -4))
	_place("compression_tower", Vector2i(-3, 1), -PI / 2.0)
	_place("sandbag", Vector2i(0, -3))
	_place("sandbag", Vector2i(0, 3))
	main.refresh_power()

	main._end_prep()
	Engine.time_scale = 3.0
	await get_tree().create_timer(7.0).timeout
	Engine.time_scale = 1.0
	main.coins = 168

	var show_power := "--power" in OS.get_cmdline_user_args()
	if show_power:
		_place("turret", Vector2i(-5, 1))
		_place("turret", Vector2i(5, 1))
		main.refresh_power()
	var show_orientation := "--orient" in OS.get_cmdline_user_args()
	if show_orientation:
		# 兼容旧参数名：现在展示压缩塔直接放置时的两格圆形范围。
		main.coins = maxi(int(main.coins), 100)
		main.begin_placement("compression_tower")
		main.update_placement(_world(Vector2i(2, 4)))
	var show_place := "--place" in OS.get_cmdline_user_args()
	if show_place:
		main.coins = maxi(int(main.coins), 100)
		main.begin_placement("turret")
		main.update_placement(_world(Vector2i(2, -4)))
	await get_tree().create_timer(1.0, true, false, true).timeout

	var show_settings := "--settings" in OS.get_cmdline_user_args()
	var show_focus := "--focus" in OS.get_cmdline_user_args()
	if show_settings:
		main.open_settings()
	elif show_focus:
		main.select_building(turret_a)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var suffix := "_settings" if show_settings else ("_focus" if show_focus else ("_power" if show_power else ("_orient" if show_orientation else ("_place" if show_place else ""))))
	var path := ""
	if _has_size_arg():
		path = "res://image_%dx%d%s.png" % [target_size.x, target_size.y, suffix]
	elif show_focus:
		path = "res://focus_preview.png"
	elif show_settings:
		path = "res://game_settings_preview.png"
	elif show_power:
		path = "res://power_preview.png"
	elif show_orientation:
		path = "res://orientation_preview.png"
	elif show_place:
		path = "res://range_preview.png"
	else:
		path = "res://image.png"
	image.save_png(ProjectSettings.globalize_path(path))
	get_tree().quit()


func _world(cell: Vector2i) -> Vector2:
	return main.arena.map_loader.cell_to_world(cell)


func _place(item_id: String, cell: Vector2i, facing := -PI / 2.0) -> Node:
	var item: Dictionary = ItemDefs.get_item(item_id)
	if item.is_empty():
		return null
	return main._place_building(item, _world(cell), facing)


func _has_size_arg() -> bool:
	return _requested_size_argument() != Vector2i.ZERO


func _apply_locale_argument() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--locale="):
			I18n.set_locale(arg.trim_prefix("--locale="))


func _requested_size() -> Vector2i:
	var requested := _requested_size_argument()
	return DEFAULT_SIZE if requested == Vector2i.ZERO else requested


func _requested_size_argument() -> Vector2i:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
				return Vector2i(maxi(320, int(parts[0])), maxi(480, int(parts[1])))
	return Vector2i.ZERO
