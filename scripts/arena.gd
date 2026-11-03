extends Node2D

## 战场图层：地图本体由 battle_world.gd 的 3D 视口渲染，
## 这里只画贴在世界之上的东西——核心血条与受击脉冲。

const Palette = preload("res://scripts/palette.gd")
const BattleMap = preload("res://scripts/battle_map.gd")

## 相机取景范围：8×13 瓦片区（384×442）四周各留 24 像素
const FRAME_RECT := Rect2(48.0, 96.0, 432.0, 490.0)

var core_ratio := 1.0
var core_flash := 0.0


func get_play_rect() -> Rect2:
	return BattleMap.field_rect()


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
	_draw_core()


func _draw_core() -> void:
	var center := BattleMap.core_center()
	if core_flash > 0.0:
		draw_circle(center, 46.0, Color(Palette.DANGER, 0.30 * core_flash))
	var bar := Rect2(center + Vector2(-36.0, -52.0), Vector2(72.0, 5.0))
	draw_rect(bar, Color(0.02, 0.04, 0.05, 0.8))
	if core_ratio > 0.0:
		draw_rect(
			Rect2(bar.position, Vector2(bar.size.x * core_ratio, bar.size.y)),
			Palette.CYAN if core_ratio > 0.3 else Palette.DANGER,
		)
	draw_rect(bar, Color(1.0, 1.0, 1.0, 0.25), false, 1.0)
