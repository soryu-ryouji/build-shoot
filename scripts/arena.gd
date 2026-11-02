extends Node2D

## 战斗区域：背景、网格、封闭边框。方块流从上方滚入，球在框内反弹。

const Palette = preload("res://scripts/palette.gd")
const ArenaTexture = preload("res://assets/ui/arena.png")

const PLAY_RECT := Rect2(64.0, 112.0, 592.0, 688.0)
const FRAME_RECT := Rect2(48.0, 96.0, 624.0, 720.0)
const TEXTURE_RECT := Rect2(0.0, 0.0, 720.0, 960.0)
const TEXTURE_TILES := Rect2(-1440.0, -1920.0, 3600.0, 4800.0)


func get_play_rect() -> Rect2:
	return PLAY_RECT


func _ready() -> void:
	GameSettings.changed.connect(queue_redraw)


func _draw() -> void:
	draw_rect(TEXTURE_RECT, Palette.ARENA_BG)
	# 长屏与横屏超出原图时延续地图，而不是露出纯色空白。
	draw_texture_rect(ArenaTexture, TEXTURE_TILES, true, Color.WHITE)
	# 中央战斗区只轻微统一明度，四周地图细节保持完整。
	draw_rect(FRAME_RECT, Color(Palette.PAPER, 0.16))

	# 网格保持低对比度，让怪物、炮弹和放置预览始终优先于背景。
	if GameSettings.show_grid:
		var grid_color := Color(Palette.GRID.r, Palette.GRID.g, Palette.GRID.b, 0.13)
		var x := PLAY_RECT.position.x
		while x <= PLAY_RECT.end.x:
			draw_line(Vector2(x, PLAY_RECT.position.y), Vector2(x, PLAY_RECT.end.y), grid_color, 1.0)
			x += 32.0
		var y := PLAY_RECT.position.y
		while y <= PLAY_RECT.end.y:
			draw_line(Vector2(PLAY_RECT.position.x, y), Vector2(PLAY_RECT.end.x, y), grid_color, 1.0)
			y += 32.0

	# 细边框配合四角标记，不再用整圈高亮霓虹压住画面。
	draw_rect(FRAME_RECT, Color(Palette.INK.r, Palette.INK.g, Palette.INK.b, 0.72), false, 2.0)
	draw_rect(FRAME_RECT.grow(-4.0), Color(Palette.PAPER.r, Palette.PAPER.g, Palette.PAPER.b, 0.55), false, 1.0)
	var corner_color := Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.65)
	_draw_corner(FRAME_RECT.position, Vector2(1, 1), corner_color)
	_draw_corner(Vector2(FRAME_RECT.end.x, FRAME_RECT.position.y), Vector2(-1, 1), corner_color)
	_draw_corner(Vector2(FRAME_RECT.position.x, FRAME_RECT.end.y), Vector2(1, -1), corner_color)
	_draw_corner(FRAME_RECT.end, Vector2(-1, -1), corner_color)


func _draw_corner(point: Vector2, direction: Vector2, color: Color) -> void:
	draw_line(point, point + Vector2(direction.x * 30.0, 0.0), color, 2.0)
	draw_line(point, point + Vector2(0.0, direction.y * 30.0), color, 2.0)
