extends Node

## 截图工具：先让方块流铺满场地，再布置炮塔、快进到开火瞬间，保存为 image.png。
## 用法：
##   Godot_v4.7.2-stable_win64.exe --path . res://tools/screenshot.tscn

const ItemDefs = preload("res://scripts/item_defs.gd")

const SHOT_PATH := "res://image.png"
const FILL_SECONDS := 32.0
const FILL_SPEED := 6.0

var main: Node


func _ready() -> void:
	get_window().content_scale_size = Vector2i(720, 960)
	get_window().size = Vector2i(720, 960)

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
	main.placed_turrets[1].apply_damage_upgrade(15)
	main.placed_turrets[1].apply_damage_upgrade(22)
	main.coins = 118

	await get_tree().create_timer(5.0).timeout
	var show_settings := "--settings" in OS.get_cmdline_user_args()
	if show_settings:
		main.open_settings()
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.get_size() != Vector2i(720, 960):
		img.resize(720, 960, Image.INTERPOLATE_LANCZOS)
	var path := "res://game_settings_preview.png" if show_settings else SHOT_PATH
	img.save_png(ProjectSettings.globalize_path(path))
	get_tree().quit()


func _place(item_id: String, target: Vector2) -> void:
	var item: Dictionary = ItemDefs.get_item(item_id)
	if item.is_empty():
		return
	main._place_turret(item, main.snap_to_grid(target))
