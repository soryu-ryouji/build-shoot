extends Node2D

## 战斗区域：背景、网格、封闭边框。方块流从上方滚入，球在框内反弹。

const Palette = preload("res://scripts/palette.gd")

const PLAY_RECT := Rect2(64.0, 112.0, 592.0, 688.0)
const FRAME_RECT := Rect2(48.0, 96.0, 624.0, 720.0)


func get_play_rect() -> Rect2:
	return PLAY_RECT


func _draw() -> void:
	draw_rect(FRAME_RECT, Palette.ARENA_BG)
	draw_rect(FRAME_RECT.grow(-4.0), Palette.PANEL, false, 1.0)

	# 网格
	var x := PLAY_RECT.position.x
	while x <= PLAY_RECT.end.x:
		draw_line(Vector2(x, PLAY_RECT.position.y), Vector2(x, PLAY_RECT.end.y), Palette.GRID, 1.0)
		x += 32.0
	var y := PLAY_RECT.position.y
	while y <= PLAY_RECT.end.y:
		draw_line(Vector2(PLAY_RECT.position.x, y), Vector2(PLAY_RECT.end.x, y), Palette.GRID, 1.0)
		y += 32.0

	# 四边封闭，球只会在框内反弹
	draw_rect(FRAME_RECT, Palette.BORDER_GLOW, false, 6.0)
	draw_rect(FRAME_RECT, Palette.BORDER, false, 2.0)
	draw_line(Vector2(PLAY_RECT.position.x, PLAY_RECT.end.y), Vector2(PLAY_RECT.end.x, PLAY_RECT.end.y), Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.16), 1.5)
