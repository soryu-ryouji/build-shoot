extends Node2D

## 拖拽道具时跟随指针的放置预览；落下后再显示朝向选择。
## 火力显示 180° 扇形射界，压缩塔显示沿朝向的直线覆盖范围。

const Palette = preload("res://scripts/palette.gd")
const ItemDefs = preload("res://scripts/item_defs.gd")
const BasicBaseTexture = preload("res://assets/ui/turret_base_field.png")
const BasicHeadTexture = preload("res://assets/ui/turret_head_field.png")
const HeavyBaseTexture = preload("res://assets/ui/heavy_turret_base_field.png")
const HeavyHeadTexture = preload("res://assets/ui/heavy_turret_head_field.png")
const LaserBaseTexture = preload("res://assets/ui/laser_tower_base_field.png")
const LaserHeadTexture = preload("res://assets/ui/laser_tower_head_field.png")
const SandbagTexture = preload("res://assets/ui/sandbag_field.png")
const CompressionTexture = preload("res://assets/ui/compression_tower_field.png")
const SolarTexture = preload("res://assets/ui/solar_field.png")
const FusionTexture = preload("res://assets/ui/fusion_tower_field.png")

const BASE_TEXTURE_SIZE := Vector2(320.0, 320.0)
const HEAD_TEXTURE_SIZE := Vector2(320.0, 384.0)
const HEAD_TEXTURE_PIVOT := Vector2(160.0, 320.0)

const CELL_SIZE := 64.0

var active := false
var orienting := false
var valid := false
var color := Palette.CYAN
var base_radius := 24.0
var sprite_scale := 1.0
var item_id := "turret"
var category := ItemDefs.CATEGORY_FIREPOWER
var facing := -PI / 2.0
var play_rect := Rect2()
var range_cells: Array = []
var hint: Label

const RANGE_FILL := Color(0.42, 0.86, 0.52, 0.10)
const RANGE_LINE := Color(0.42, 0.86, 0.52, 0.42)


func _ready() -> void:
	z_index = 8
	hint = Label.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Palette.INK)
	hint.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 0.98, 0.88))
	hint.add_theme_constant_override("outline_size", 3)
	hint.size = Vector2(220, 22)
	hint.visible = false
	add_child(hint)


func begin(item: Dictionary) -> void:
	active = true
	color = item.color
	base_radius = float(item.get("base", 24.0))
	sprite_scale = float(item.get("sprite_scale", 1.0))
	item_id = String(item.id)
	category = String(item.category)
	orienting = false
	facing = -PI / 2.0
	range_cells.clear()
	if hint != null:
		hint.visible = false
	queue_redraw()


func update_preview(pos: Vector2, is_valid: bool) -> void:
	position = pos
	valid = is_valid
	queue_redraw()


func begin_orientation(pos: Vector2, item: Dictionary, angle: float, rect: Rect2) -> void:
	begin(item)
	orienting = true
	valid = true
	position = pos
	facing = angle
	play_rect = rect
	if hint != null:
		hint.text = I18n.t("placement.confirm_hint")
		hint.visible = true
		_layout_hint()
	queue_redraw()


func set_facing(angle: float) -> void:
	facing = angle
	queue_redraw()


func set_range_cells(cells: Array) -> void:
	range_cells = cells
	queue_redraw()


func end() -> void:
	active = false
	orienting = false
	range_cells.clear()
	if hint != null:
		hint.visible = false
	queue_redraw()


func _layout_hint() -> void:
	if hint == null:
		return
	var below := play_rect.size.y > 0.0 and position.y < play_rect.position.y + 110.0
	hint.position = Vector2(-hint.size.x * 0.5, CELL_SIZE * 0.5 + 8.0) if below else Vector2(-hint.size.x * 0.5, -CELL_SIZE * 0.5 - 100.0)


func _draw() -> void:
	if not active:
		return
	if orienting:
		_draw_orientation()
	else:
		_draw_placement()


func _draw_placement() -> void:
	var mark := Palette.ACCENT if valid else Palette.DANGER

	_draw_range_cells()

	# 当前格
	var cell := Rect2(Vector2(-CELL_SIZE * 0.5, -CELL_SIZE * 0.5), Vector2(CELL_SIZE, CELL_SIZE))
	draw_rect(cell, Color(mark.r, mark.g, mark.b, 0.08))
	draw_rect(cell, Color(mark.r, mark.g, mark.b, 0.65), false, 1.5)

	draw_circle(Vector2.ZERO, base_radius + 6.0, Color(mark.r, mark.g, mark.b, 0.08))
	draw_circle(Vector2.ZERO, base_radius, Color(mark.r, mark.g, mark.b, 0.16))
	draw_arc(Vector2.ZERO, base_radius + 2.0, 0.0, TAU, 36, mark, 2.0)

	var tint := Color(1.0, 1.0, 1.0, 0.62) if valid else Color(1.0, 0.30, 0.36, 0.58)
	_draw_body(tint)

	draw_line(Vector2(-9.0, 0.0), Vector2(9.0, 0.0), mark, 1.5)
	draw_line(Vector2(0.0, -9.0), Vector2(0.0, 9.0), mark, 1.5)


func _draw_orientation() -> void:
	var mark := Palette.ACCENT
	_draw_range_cells()
	var cell := Rect2(Vector2(-CELL_SIZE * 0.5, -CELL_SIZE * 0.5), Vector2(CELL_SIZE, CELL_SIZE))
	draw_rect(cell, Color(mark.r, mark.g, mark.b, 0.08))
	draw_rect(cell, Color(mark.r, mark.g, mark.b, 0.75), false, 2.0)
	draw_circle(Vector2.ZERO, base_radius + 6.0, Color(mark.r, mark.g, mark.b, 0.08))
	draw_circle(Vector2.ZERO, base_radius, Color(mark.r, mark.g, mark.b, 0.12))
	draw_arc(Vector2.ZERO, base_radius + 2.0, 0.0, TAU, 36, mark, 2.0)

	_draw_body(Color(1.0, 1.0, 1.0, 0.82), facing)

	# 朝向箭头
	var direction := Vector2.from_angle(facing)
	var tip := direction * 82.0
	draw_line(direction * 18.0, tip, Color(mark.r, mark.g, mark.b, 0.95), 4.0)
	var left := direction.rotated(0.42)
	var right := direction.rotated(-0.42)
	draw_line(tip, tip - left * 18.0, Color(mark.r, mark.g, mark.b, 0.95), 4.0)
	draw_line(tip, tip - right * 18.0, Color(mark.r, mark.g, mark.b, 0.95), 4.0)
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 1.0, 1.0, 0.9))


func _draw_range_cells() -> void:
	var side := CELL_SIZE - 4.0
	for point in range_cells:
		var local: Vector2 = point - global_position
		var cell := Rect2(local - Vector2.ONE * side * 0.5, Vector2(side, side))
		draw_rect(cell, RANGE_FILL)
		draw_rect(cell, RANGE_LINE, false, 1.0)


func _draw_body(tint: Color, angle := -PI / 2.0) -> void:
	if item_id == "turret" or item_id == "heavy_turret":
		draw_set_transform(Vector2.ZERO, angle + PI / 2.0, Vector2.ONE)
		_draw_turret_preview(tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif item_id == "laser_tower":
		draw_set_transform(Vector2.ZERO, angle + PI / 2.0, Vector2.ONE)
		_draw_laser_preview(tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif item_id == "sandbag":
		_draw_static_preview(SandbagTexture, tint)
	elif item_id == "compression_tower":
		_draw_static_preview(CompressionTexture, tint)
	elif item_id == "solar":
		_draw_static_preview(SolarTexture, tint)
	elif item_id == "fusion_tower":
		_draw_static_preview(FusionTexture, tint)
	else:
		_draw_generic_preview(tint)


func _draw_turret_preview(tint: Color) -> void:
	var heavy := item_id == "heavy_turret"
	var base_texture := HeavyBaseTexture if heavy else BasicBaseTexture
	var head_texture := HeavyHeadTexture if heavy else BasicHeadTexture
	var scale := base_radius * (4.8 if heavy else 6.0) / BASE_TEXTURE_SIZE.x
	var side := BASE_TEXTURE_SIZE.x * scale
	draw_texture_rect(
		base_texture,
		Rect2(Vector2(-side * 0.5, -side * 0.5), Vector2(side, side)),
		false,
		tint
	)
	draw_texture_rect(
		head_texture,
		Rect2(
			Vector2(-HEAD_TEXTURE_PIVOT.x * scale, -HEAD_TEXTURE_PIVOT.y * scale),
			HEAD_TEXTURE_SIZE * scale
		),
		false,
		tint
	)


func _draw_laser_preview(tint: Color) -> void:
	var scale := base_radius * 6.0 / BASE_TEXTURE_SIZE.x
	var side := BASE_TEXTURE_SIZE.x * scale
	draw_texture_rect(
		LaserBaseTexture,
		Rect2(Vector2(-side * 0.5, -side * 0.5), Vector2(side, side)),
		false,
		tint
	)
	draw_texture_rect(
		LaserHeadTexture,
		Rect2(
			Vector2(-HEAD_TEXTURE_PIVOT.x * scale, -HEAD_TEXTURE_PIVOT.y * scale),
			HEAD_TEXTURE_SIZE * scale
		),
		false,
		tint
	)


func _draw_static_preview(texture: Texture2D, tint: Color) -> void:
	var side := base_radius * 2.0 * sprite_scale
	draw_texture_rect(texture, Rect2(Vector2(-side * 0.5, -side * 0.5), Vector2(side, side)), false, tint)


func _draw_generic_preview(tint: Color) -> void:
	draw_circle(Vector2.ZERO, base_radius * 0.8, Color(tint.r, tint.g, tint.b, tint.a * 0.45))
