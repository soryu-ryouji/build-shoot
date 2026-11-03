extends Node2D

## 拖拽道具时跟随指针的放置预览。

const Palette = preload("res://scripts/palette.gd")
const ItemDefs = preload("res://scripts/item_defs.gd")
const BasicBaseTexture = preload("res://assets/ui/turret_base_field.png")
const BasicHeadTexture = preload("res://assets/ui/turret_head_field.png")
const HeavyBaseTexture = preload("res://assets/ui/heavy_turret_base_field.png")
const HeavyHeadTexture = preload("res://assets/ui/heavy_turret_head_field.png")
const SandbagTexture = preload("res://assets/ui/sandbag_field.png")
const SolarTexture = preload("res://assets/ui/solar_field.png")

const BASE_TEXTURE_SIZE := Vector2(320.0, 320.0)
const HEAD_TEXTURE_SIZE := Vector2(320.0, 384.0)
const HEAD_TEXTURE_PIVOT := Vector2(160.0, 320.0)

const CELL_SIZE := 64.0

var active := false
var valid := false
var color := Palette.CYAN
var preview_range := 0.0
var base_radius := 24.0
var sprite_scale := 1.0
var item_id := "turret"
var category := ItemDefs.CATEGORY_FIREPOWER


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

	var mark := Palette.CYAN.darkened(0.25) if valid else Palette.DANGER

	# 网格单元高亮
	var cell := Rect2(Vector2(-CELL_SIZE * 0.5, -CELL_SIZE * 0.5), Vector2(CELL_SIZE, CELL_SIZE))
	draw_rect(cell, Color(mark.r, mark.g, mark.b, 0.04))
	draw_rect(cell, Color(mark.r, mark.g, mark.b, 0.35), false, 1.0)

	if category == ItemDefs.CATEGORY_FIREPOWER:
		draw_arc(Vector2.ZERO, preview_range, 0.0, TAU, 64, Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.22), 1.5)

	draw_circle(Vector2.ZERO, base_radius + 6.0, Color(mark.r, mark.g, mark.b, 0.08))
	draw_circle(Vector2.ZERO, base_radius, Color(mark.r, mark.g, mark.b, 0.16))
	draw_arc(Vector2.ZERO, base_radius + 2.0, 0.0, TAU, 36, mark, 2.0)

	var tint := Color(1.0, 1.0, 1.0, 0.62) if valid else Color(1.0, 0.30, 0.36, 0.58)
	if item_id == "turret" or item_id == "heavy_turret":
		_draw_turret_preview(tint)
	elif item_id == "sandbag":
		_draw_static_preview(SandbagTexture, tint)
	elif item_id == "solar":
		_draw_static_preview(SolarTexture, tint)
	else:
		_draw_generic_preview(tint)

	draw_line(Vector2(-9.0, 0.0), Vector2(9.0, 0.0), mark, 1.5)
	draw_line(Vector2(0.0, -9.0), Vector2(0.0, 9.0), mark, 1.5)


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


func _draw_static_preview(texture: Texture2D, tint: Color) -> void:
	var side := base_radius * 2.0 * sprite_scale
	draw_texture_rect(texture, Rect2(Vector2(-side * 0.5, -side * 0.5), Vector2(side, side)), false, tint)


func _draw_generic_preview(tint: Color) -> void:
	draw_circle(Vector2.ZERO, base_radius * 0.8, Color(tint.r, tint.g, tint.b, tint.a * 0.45))
