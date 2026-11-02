extends Node2D

## 拖拽道具时跟随指针的放置预览。

const Palette = preload("res://scripts/palette.gd")

const CELL_SIZE := 64.0

var active := false
var valid := false
var color := Palette.CYAN
var preview_range := 0.0
var base_radius := 24.0
var barrel_length := 48.0


func _ready() -> void:
	z_index = 8


func begin(item: Dictionary) -> void:
	active = true
	color = item.color
	preview_range = float(item.range)
	base_radius = float(item.base)
	barrel_length = float(item.barrel)
	queue_redraw()


func update_preview(pos: Vector2, is_valid: bool) -> void:
	position = pos
	valid = is_valid
	queue_redraw()


func end() -> void:
	active = false
	queue_redraw()


func _draw() -> void:
	if not active:
		return

	var mark := Color(0.30, 0.95, 0.55) if valid else Palette.DANGER

	# 网格单元高亮
	var cell := Rect2(Vector2(-CELL_SIZE * 0.5, -CELL_SIZE * 0.5), Vector2(CELL_SIZE, CELL_SIZE))
	draw_rect(cell, Color(mark.r, mark.g, mark.b, 0.04))
	draw_rect(cell, Color(mark.r, mark.g, mark.b, 0.35), false, 1.0)

	# 射程预览
	draw_arc(Vector2.ZERO, preview_range, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.10), 1.5)

	draw_circle(Vector2.ZERO, base_radius + 6.0, Color(mark.r, mark.g, mark.b, 0.08))
	draw_circle(Vector2.ZERO, base_radius, Color(mark.r, mark.g, mark.b, 0.16))
	draw_arc(Vector2.ZERO, base_radius + 2.0, 0.0, TAU, 36, mark, 2.0)

	# 炮塔轮廓
	draw_rect(Rect2(Vector2(-3.0, -barrel_length - 4.0), Vector2(6.0, barrel_length - 12.0)), color)
	draw_circle(Vector2(0.0, -barrel_length - 4.0), 4.0, color)
	draw_circle(Vector2.ZERO, base_radius * 0.4, Color(color.r, color.g, color.b, 0.55))

	draw_line(Vector2(-9.0, 0.0), Vector2(9.0, 0.0), mark, 1.5)
	draw_line(Vector2(0.0, -9.0), Vector2(0.0, 9.0), mark, 1.5)
