extends Node2D

## 瓦片上方、单位下方的统一交互高亮：绿色可放置、红色非法、青色范围。

const Palette = preload("res://scripts/palette.gd")
const PLACE_FILL := Color(0.30, 0.82, 0.48, 0.12)
const PLACE_LINE := Color(0.30, 0.82, 0.48, 0.42)
const RANGE_FILL := Color(0.20, 0.70, 0.92, 0.06)
const RANGE_LINE := Color(0.16, 0.65, 0.90, 0.58)

var map: Node
var placement_cells: Array = []
var range_cells: Array = []
var hover_cell := Vector2i.ZERO
var hover_valid := false
var hover_active := false


func _ready() -> void:
	z_index = 1
	GameSettings.changed.connect(queue_redraw)


func show_placement(cells: Array, hover: Vector2i, valid: bool, show_hover := true) -> void:
	placement_cells = cells
	hover_cell = hover
	hover_valid = valid
	hover_active = show_hover
	queue_redraw()


func clear_placement() -> void:
	placement_cells.clear()
	hover_active = false
	queue_redraw()


func set_range_cells(cells: Array) -> void:
	range_cells = cells
	queue_redraw()


func clear_range() -> void:
	range_cells.clear()
	queue_redraw()


func clear_all() -> void:
	clear_placement()
	clear_range()


func _draw() -> void:
	if map == null:
		return
	_draw_frame()
	if GameSettings.show_grid and map.play_rect.size.x > 0.0:
		_draw_grid()
	for cell in placement_cells:
		_draw_cell(cell, PLACE_FILL, PLACE_LINE, 60.0, 1.0)
	for cell in range_cells:
		_draw_cell(cell, RANGE_FILL, RANGE_LINE, 56.0, 1.5)
	if hover_active and map.is_inside(hover_cell):
		var color: Color = Palette.ACCENT if hover_valid else Palette.DANGER
		if hover_valid:
			color = Color(0.30, 0.90, 0.50, 1.0)
		_draw_cell(hover_cell, Color(color, 0.20), Color(color, 0.95), 62.0, 2.0)


func _draw_frame() -> void:
	var rect: Rect2 = map.frame_rect
	if rect.size == Vector2.ZERO:
		return
	var ink := Color(Palette.INK.r, Palette.INK.g, Palette.INK.b, 0.68)
	var paper := Color(Palette.PAPER.r, Palette.PAPER.g, Palette.PAPER.b, 0.42)
	draw_rect(rect, ink, false, 2.0)
	draw_rect(rect.grow(-4.0), paper, false, 1.0)
	var accent := Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.65)
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		var direction := Vector2(1.0 if corner.x == rect.position.x else -1.0, 1.0 if corner.y == rect.position.y else -1.0)
		draw_line(corner, corner + Vector2(direction.x * 30.0, 0.0), accent, 2.0)
		draw_line(corner, corner + Vector2(0.0, direction.y * 30.0), accent, 2.0)


func _draw_grid() -> void:
	var color := Color(Palette.GRID.r, Palette.GRID.g, Palette.GRID.b, 0.14)
	var rect: Rect2 = map.play_rect
	for x in range(int(map.grid_size.x) + 1):
		var world_x: float = rect.position.x + x * map.cell_size.x
		draw_line(Vector2(world_x, rect.position.y), Vector2(world_x, rect.end.y), color, 1.0)
	for y in range(int(map.grid_size.y) + 1):
		var world_y: float = rect.position.y + y * map.cell_size.y
		draw_line(Vector2(rect.position.x, world_y), Vector2(rect.end.x, world_y), color, 1.0)


func _draw_cell(cell: Vector2i, fill: Color, line: Color, side: float, width: float) -> void:
	var center: Vector2 = map.cell_to_world(cell)
	var rect := Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side)
	draw_rect(rect, fill)
	draw_rect(rect, line, false, width)
