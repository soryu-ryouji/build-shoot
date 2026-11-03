extends Node2D

## 2.5D 战场：整张地图（地面、通路、缺口、核心）由 Blender 正交渲染成一张贴图，
## 这里只负责贴图、核心血条和受击脉冲。路线与格子坐标仍由 battle_map.gd 提供。

const Palette = preload("res://scripts/palette.gd")
const BattleMap = preload("res://scripts/battle_map.gd")

## 贴图范围：576×476 的瓦片区左右各留 24 像素外框
const FRAME_RECT := Rect2(48.0, 96.0, 624.0, 524.0)

## 核心血量比例，由 main 在掉血时同步过来
var core_ratio := 1.0
## 核心刚被撞时的红色脉冲
var core_flash := 0.0

var _map_texture: Texture2D


func get_play_rect() -> Rect2:
	return BattleMap.field_rect()


func _ready() -> void:
	_map_texture = _load_texture(BattleMap.art_path())


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func set_core_ratio(value: float) -> void:
	core_ratio = clampf(value, 0.0, 1.0)
	queue_redraw()


func flash_core() -> void:
	core_flash = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if core_flash > 0.0:
		core_flash = maxf(0.0, core_flash - delta * 2.5)
		queue_redraw()


func _draw() -> void:
	# 2.5D 地图之外是深色背景，避免和浅色地板连成一片
	draw_rect(Rect2(Vector2(-600.0, -600.0), Vector2(1920.0, 2100.0)), Palette.BG)
	if _map_texture != null:
		draw_texture_rect(_map_texture, FRAME_RECT, false)
	_draw_core_overlay()


## 核心血条与受击脉冲画在贴图之上，位置来自 battle_map 的核心坐标
func _draw_core_overlay() -> void:
	var center := BattleMap.core_center()
	var radius := BattleMap.TILE * 0.62
	if core_flash > 0.0:
		draw_circle(center, radius + 10.0, Color(Palette.DANGER, 0.28 * core_flash))
	var bar := Rect2(center + Vector2(-radius, -radius - 6.0), Vector2(radius * 2.0, 5.0))
	draw_rect(bar, Color(0.02, 0.04, 0.05, 0.8))
	if core_ratio > 0.0:
		draw_rect(
			Rect2(bar.position, Vector2(bar.size.x * core_ratio, bar.size.y)),
			Palette.CYAN if core_ratio > 0.3 else Palette.DANGER,
		)
	draw_rect(bar, Color(1.0, 1.0, 1.0, 0.25), false, 1.0)
