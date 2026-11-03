extends Node

## 截图工具：先让方块流铺满场地，再布置炮塔、快进到开火瞬间，保存为 image.png。
## 用法：
##   Godot_v4.7.2-stable_win64.exe --path . res://tools/screenshot.tscn
##   -- --size=1000x2000        指定尺寸，按 image_<宽>x<高>.png 保存
##   -- --settings              截取游戏内设置面板
##   -- --focus                 截取炮塔聚焦面板

const ItemDefs = preload("res://scripts/item_defs.gd")

const DEFAULT_SIZE := Vector2i(1080, 2400)
const SHOT_PATH := "res://image.png"
const FILL_SECONDS := 20.0
const FILL_SPEED := 6.0

var main: Node


func _ready() -> void:
	var target_size := _requested_size()
	get_window().size = target_size
	_apply_locale_argument()

	var packed: PackedScene = load("res://scenes/main.tscn")
	main = packed.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	# 第一阶段：没有炮塔，快进让方块流铺满场地，顺便经过前几波
	main.coins = 0
	main.prep_timer = 0.0
	await get_tree().process_frame
	Engine.time_scale = FILL_SPEED
	await get_tree().create_timer(FILL_SECONDS).timeout
	Engine.time_scale = 1.0

	# 第二阶段：摆出炮塔阵型，正常速度跑一小段，拍到开火和命中
	main.coins = 340
	_place("turret", Vector2(160, 700))
	_place("turret", Vector2(330, 736))
	_place("turret", Vector2(560, 692))
	_place("turret", Vector2(470, 520))
	_place("heavy_turret", Vector2(250, 584))
	main.placed_turrets[1].apply_upgrade(15)
	main.placed_turrets[1].apply_upgrade(22)
	main.coins = 118

	await get_tree().create_timer(5.0).timeout
	var show_settings := "--settings" in OS.get_cmdline_user_args()
	var show_focus := "--focus" in OS.get_cmdline_user_args()
	if show_settings:
		main.open_settings()
	elif show_focus:
		main.select_turret(main.placed_turrets[4])
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var suffix := "_settings" if show_settings else ("_focus" if show_focus else "")
	var path := ""
	if _has_size_arg():
		path = "res://image_%dx%d%s.png" % [target_size.x, target_size.y, suffix]
	elif show_focus:
		path = "res://focus_preview.png"
	elif show_settings:
		path = "res://game_settings_preview.png"
	else:
		path = SHOT_PATH
	img.save_png(ProjectSettings.globalize_path(path))
	get_tree().quit()


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


func _place(item_id: String, target: Vector2) -> void:
	var item: Dictionary = ItemDefs.get_item(item_id)
	if item.is_empty():
		return
	main._place_turret(item, main.snap_to_grid(target))
