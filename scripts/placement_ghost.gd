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
var preview_range := 0.0
var base_radius := 24.0
var sprite_scale := 1.0
var item_id := "turret"
var category := ItemDefs.CATEGORY_FIREPOWER
var facing := -PI / 2.0
var play_rect := Rect2()


func _ready() -> void:
	z_index = 8


func begin(item: Dictionary) -> void:
	active = true
	color = item.color
	preview_range = float(item.get("range", 0.0))
	base_radius = float(item.get("base", 24.0))
	sprite_scale = float(item.get("sprite_scale", 1.0))
	item_id = String(item.id)
	category = String(item.category)
	orienting = false
	facing = -PI / 2.0
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
	queue_redraw()


func set_facing(angle: float) -> void:
	facing = angle
	queue_redraw()


func end() -> void:
	active = false
	orienting = false
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	if orienting:
		_draw_orientation()
	else:
		_draw_placement()


func _draw_placement() -> void:
	var mark := Palette.CYAN.darkened(0.25) if valid else Palette.DANGER

	# 网格单元高亮
	var cell := Rect2(Vector2(-CELL_SIZE * 0.5, -CELL_SIZE * 0.5), Vector2(CELL_SIZE, CELL_SIZE))
	draw_rect(cell, Color(mark.r, mark.g, mark.b, 0.04))
	draw_rect(cell, Color(mark.r, mark.g, mark.b, 0.35), false, 1.0)

	if category == ItemDefs.CATEGORY_FIREPOWER:
		_draw_range_sector(preview_range)

	draw_circle(Vector2.ZERO, base_radius + 6.0, Color(mark.r, mark.g, mark.b, 0.08))
	draw_circle(Vector2.ZERO, base_radius, Color(mark.r, mark.g, mark.b, 0.16))
	draw_arc(Vector2.ZERO, base_radius + 2.0, 0.0, TAU, 36, mark, 2.0)

	var tint := Color(1.0, 1.0, 1.0, 0.62) if valid else Color(1.0, 0.30, 0.36, 0.58)
	_draw_body(tint)

	draw_line(Vector2(-9.0, 0.0), Vector2(9.0, 0.0), mark, 1.5)
	draw_line(Vector2(0.0, -9.0), Vector2(0.0, 9.0), mark, 1.5)


func _draw_orientation() -> void:
	var mark := Palette.ACCENT
	var cell := Rect2(Vector2(-CELL_SIZE * 0.5, -CELL_SIZE * 0.5), Vector2(CELL_SIZE, CELL_SIZE))
	draw_rect(cell, Color(mark.r, mark.g, mark.b, 0.06))
	draw_rect(cell, Color(mark.r, mark.g, mark.b, 0.55), false, 1.5)
	draw_circle(Vector2.ZERO, base_radius + 6.0, Color(mark.r, mark.g, mark.b, 0.08))
	draw_circle(Vector2.ZERO, base_radius, Color(mark.r, mark.g, mark.b, 0.12))
	draw_arc(Vector2.ZERO, base_radius + 2.0, 0.0, TAU, 36, mark, 2.0)

	_draw_body(Color(1.0, 1.0, 1.0, 0.82), facing)

	if category == ItemDefs.CATEGORY_FIREPOWER:
		_draw_range_sector(preview_range)
	elif int(ItemDefs.get_item(item_id).get("buff_multiplier", 1)) > 1:
		_draw_line_range()

	# 朝向箭头
	var direction := Vector2.from_angle(facing)
	var tip := direction * 82.0
	draw_line(direction * 18.0, tip, Color(mark.r, mark.g, mark.b, 0.95), 4.0)
	var left := direction.rotated(0.42)
	var right := direction.rotated(-0.42)
	draw_line(tip, tip - left * 18.0, Color(mark.r, mark.g, mark.b, 0.95), 4.0)
	draw_line(tip, tip - right * 18.0, Color(mark.r, mark.g, mark.b, 0.95), 4.0)
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 1.0, 1.0, 0.9))


func _draw_range_sector(radius: float) -> void:
	var points := PackedVector2Array([Vector2.ZERO])
	var steps := 24
	for i in steps + 1:
		var angle := facing - PI / 2.0 + PI * float(i) / float(steps)
		points.append(Vector2.from_angle(angle) * radius)
	draw_colored_polygon(points, Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.07))
	draw_arc(Vector2.ZERO, radius, facing - PI / 2.0, facing + PI / 2.0, 48, Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.75), 2.0)
	draw_line(Vector2.ZERO, Vector2.from_angle(facing - PI / 2.0) * radius, Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.45), 1.5)
	draw_line(Vector2.ZERO, Vector2.from_angle(facing + PI / 2.0) * radius, Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.45), 1.5)


func _draw_line_range() -> void:
	var span := _line_rect_span(global_position, Vector2.from_angle(facing), play_rect)
	if span.size() < 2:
		return
	var a: Vector2 = span[0] - global_position
	var b: Vector2 = span[1] - global_position
	draw_line(a, b, Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.10), 12.0)
	draw_line(a, b, Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.75), 3.0)


func _line_rect_span(origin: Vector2, direction: Vector2, rect: Rect2) -> Array:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return []
	var far := 4000.0
	var a := origin - direction * far
	var b := origin + direction * far
	var edges := [
		[rect.position, Vector2(rect.end.x, rect.position.y)],
		[Vector2(rect.end.x, rect.position.y), rect.end],
		[rect.end, Vector2(rect.position.x, rect.end.y)],
		[Vector2(rect.position.x, rect.end.y), rect.position],
	]
	var points: Array[Vector2] = []
	for edge in edges:
		var hit = Geometry2D.segment_intersects_segment(a, b, edge[0], edge[1])
		if hit == null:
			continue
		var point: Vector2 = hit
		var duplicate := false
		for existing in points:
			if point.distance_to(existing) < 0.5:
				duplicate = true
				break
		if not duplicate:
			points.append(point)
	if points.size() < 2:
		return []
	var best: Array[Vector2] = [points[0], points[1]]
	var best_distance := points[0].distance_squared_to(points[1])
	for i in points.size():
		for j in range(i + 1, points.size()):
			var distance := points[i].distance_squared_to(points[j])
			if distance > best_distance:
				best_distance = distance
				best = [points[i], points[j]]
	return best


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
