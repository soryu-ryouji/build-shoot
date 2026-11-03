extends Node

## 截图工具：先让方块流铺满场地，再布置炮塔、快进到开火瞬间，保存为 image.png。
## 用法：
##   Godot_v4.7.2-stable_win64.exe --path . res://tools/screenshot.tscn
##   -- --size=1000x2000        指定尺寸，按 image_<宽>x<高>.png 保存
##   -- --settings              截取游戏内设置面板
##   -- --focus                 截取炮塔聚焦面板
##   -- --power                 截取能源不足、建筑置灰的状态
##   -- --orient                截取拖放后的朝向选择状态
##   -- --place                 截取拖拽中的圆形射程格子预览

const ItemDefs = preload("res://scripts/item_defs.gd")
const BattleMap = preload("res://scripts/battle_map.gd")

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

	# 第二阶段：摆出三类建筑，正常速度跑一小段，拍到开火、增益和能源线
	main.coins = 1000
	_place("fusion_tower", _tile(1, 12))
	_place("fusion_tower", _tile(7, 12))
	_place("solar", _tile(5, 12))

	var turret_a: Node = _place("turret", _tile(2, 10))
	_place("heavy_turret", _tile(7, 11))
	_place("laser_tower", _tile(7, 9))

	_place("compression_tower", _tile(4, 10), PI)
	_place("sandbag", _tile(5, 10))
	_place("turret", _tile(2, 8))
	main.refresh_power()
	main.coins = 118

	var show_power := "--power" in OS.get_cmdline_user_args()
	if show_power:
		# 产能刚好覆盖既有建筑，再追加两座炮塔，让新建筑离线
		_place("turret", _tile(6, 10))
		_place("turret", _tile(6, 12))
		main.refresh_power()

	var show_orientation := "--orient" in OS.get_cmdline_user_args()
	if show_orientation:
		main.coins = maxi(int(main.coins), 100)
		main.begin_placement("compression_tower")
		main.finish_placement("compression_tower", _tile(6, 7))
		main._update_orientation(_tile(7, 7))

	var show_place := "--place" in OS.get_cmdline_user_args()
	if show_place:
		main.coins = maxi(int(main.coins), 100)
		main.begin_placement("turret")
		main.update_placement(_tile(2, 5))

	await get_tree().create_timer(5.0, true, false, true).timeout
	var show_settings := "--settings" in OS.get_cmdline_user_args()
	var show_focus := "--focus" in OS.get_cmdline_user_args()
	var show_over := "--over" in OS.get_cmdline_user_args()
	if show_settings:
		main.open_settings()
	elif show_focus:
		main.select_building(turret_a)
	elif show_over:
		main.damage_base(999)
		main.hud._process(0.0)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var suffix := "_settings" if show_settings else ("_focus" if show_focus else ("_power" if show_power else ("_orient" if show_orientation else ("_place" if show_place else ("_over" if show_over else "")))))
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
	elif show_over:
		path = "res://game_over_preview.png"
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


func _place(item_id: String, target: Vector2, facing := -PI / 2.0) -> Node:
	var item: Dictionary = ItemDefs.get_item(item_id)
	if item.is_empty():
		return null
	return main._place_building(item, main.snap_to_grid(target), facing)


func _tile(col: int, row: int) -> Vector2:
	return BattleMap.tile_center(Vector2i(col, row))
