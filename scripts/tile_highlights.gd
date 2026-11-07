extends Node2D

## 可见瓦片上的统一交互高亮：绿色可放置、红色非法、青色范围。

const Palette = preload("res://scripts/palette.gd")
const PLACE_FILL := Color(0.30, 0.82, 0.48, 0.12)
const PLACE_LINE := Color(0.30, 0.82, 0.48, 0.42)
const RANGE_FILL := Color(0.20, 0.70, 0.92, 0.06)
const RANGE_LINE := Color(0.16, 0.65, 0.90, 0.58)
const NETWORK_FILL := Color(0.95, 0.56, 0.20, 0.07)
const NETWORK_LINE := Color(0.95, 0.50, 0.16, 0.62)

var map: Node
var placement_cells: Array = []
var range_cells: Array = []
var network_range_cells: Array = []
var hover_cell := Vector2i.ZERO
var hover_valid := false
var hover_active := false
var preview_visible := true
var camera_zoom := 1.0


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
	network_range_cells.clear()
	queue_redraw()


func set_aura_ranges(own_cells: Array, connected_cells: Array) -> void:
	range_cells = own_cells
	network_range_cells = connected_cells
	queue_redraw()


func clear_range() -> void:
	range_cells.clear()
	network_range_cells.clear()
	queue_redraw()


func clear_all() -> void:
	clear_placement()
	clear_range()


func set_preview_visible(value: bool) -> void:
	if preview_visible == value:
		return
	preview_visible = value
	queue_redraw()


func _draw() -> void:
	if map == null:
		return
	if GameSettings.show_grid:
		_draw_grid()
	if not preview_visible:
		return
	for cell in placement_cells:
		_draw_cell(cell, PLACE_FILL, PLACE_LINE, 60.0, 1.0)
	for cell in network_range_cells:
		_draw_cell(cell, NETWORK_FILL, NETWORK_LINE, 52.0, 1.5)
	for cell in range_cells:
		_draw_cell(cell, RANGE_FILL, RANGE_LINE, 56.0, 1.5)
	if hover_active and map.is_cell_visible(hover_cell):
		var color: Color = Palette.ACCENT if hover_valid else Palette.DANGER
		if hover_valid:
			color = Color(0.30, 0.90, 0.50, 1.0)
		_draw_cell(hover_cell, Color(color, 0.20), Color(color, 0.95), 62.0, 2.0)


func _draw_grid() -> void:
	var color := Color(Palette.GRID.r, Palette.GRID.g, Palette.GRID.b, 0.20)
	for cell in map.get_visible_cells():
		var center: Vector2 = map.cell_to_world(cell)
		var rect := Rect2(center - Vector2(map.cell_size) * 0.5, Vector2(map.cell_size))
		draw_rect(rect, color, false, maxf(1.0, 1.0 / maxf(camera_zoom, 0.01)))


func _draw_cell(cell: Vector2i, fill: Color, line: Color, side: float, width: float) -> void:
	var center: Vector2 = map.cell_to_world(cell)
	var rect := Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side)
	draw_rect(rect, fill)
	draw_rect(rect, line, false, width)
