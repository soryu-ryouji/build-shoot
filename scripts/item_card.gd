extends Control

## 底部商店里的单个建筑卡片：类别、图标、名称、价格与能源摘要。
## 三张卡并排时宽度较窄，采用「类别 / 图标 / 名称 / 价格」的竖排布局。

const Palette = preload("res://scripts/palette.gd")
const ItemDefs = preload("res://scripts/item_defs.gd")
const UiMetrics = preload("res://scripts/ui_metrics.gd")

signal drag_started(item_id: String)

var game: Node
var item: Dictionary = {}

var category_label: Label
var name_label: Label
var cost_label: Label

var _can_buy := false
var _hovered := false
var _style: StyleBoxFlat
var _icon_texture: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(_layout)

	_style = StyleBoxFlat.new()
	_style.bg_color = Color(Palette.PAPER, 0.98)
	_style.set_border_width_all(1)
	_style.set_corner_radius_all(2)

	var icon_path := String(item.get("icon", ""))
	if not icon_path.is_empty():
		_icon_texture = load(icon_path)

	category_label = _make_label(UiMetrics.FONT_MICRO, Palette.INK_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	name_label = _make_label(15, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.max_lines_visible = 1
	cost_label = _make_label(UiMetrics.FONT_SMALL, Palette.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)

	I18n.locale_changed.connect(_on_locale_changed)
	_refresh_texts()
	_can_buy = int(game.coins) >= int(item.cost)
	_layout()


func _make_label(font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _layout() -> void:
	if name_label == null:
		return
	var width := size.x - 8.0
	category_label.position = Vector2(4.0, 1.0)
	category_label.size = Vector2(width, 13.0)
	var icon := _icon_rect()
	name_label.position = Vector2(4.0, 47.0)
	name_label.size = Vector2(width, 21.0)
	cost_label.position = Vector2(4.0, 69.0)
	cost_label.size = Vector2(width, 18.0)
	queue_redraw()


func _icon_rect() -> Rect2:
	var side := minf(30.0, size.x - 24.0)
	return Rect2(Vector2((size.x - side) * 0.5, 16.0), Vector2(side, side))


func _refresh_texts() -> void:
	if item.is_empty():
		return
	var category := String(item.category)
	var energy := int(item.get("energy_output", 0))
	if energy > 0:
		category_label.text = I18n.t(ItemDefs.category_name_key(category)) + " " + I18n.t("shop.energy_output", [energy])
	else:
		category_label.text = I18n.t(ItemDefs.category_name_key(category)) + " " + I18n.t("shop.energy_demand", [int(item.get("energy_demand", 1))])
	category_label.add_theme_color_override("font_color", ItemDefs.category_color(category).darkened(0.15))
	name_label.text = I18n.t(String(item.name_key))
	cost_label.text = I18n.t("shop.cost", [int(item.cost)])


func _on_locale_changed(_locale: String) -> void:
	_refresh_texts()


func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()


func _process(_delta: float) -> void:
	if game == null or item.is_empty():
		return
	var can_buy: bool = int(game.coins) >= int(item.cost)
	if can_buy != _can_buy:
		_can_buy = can_buy
		queue_redraw()
	cost_label.add_theme_color_override("font_color", Palette.ACCENT if _can_buy else Palette.DANGER)


func _gui_input(event: InputEvent) -> void:
	if game == null or item.is_empty():
		return
	var pressed := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if not pressed:
		return

	if int(game.coins) < int(item.cost):
		game.hud.toast(I18n.t("shop.not_enough"), Palette.DANGER)
		accept_event()
		return

	drag_started.emit(String(item.id))
	accept_event()


func _draw() -> void:
	if item.is_empty():
		return

	var category := String(item.category)
	var accent := ItemDefs.category_color(category)
	_style.bg_color = Color(1.0, 0.98, 0.90, 1.0) if _hovered and _can_buy else Color(Palette.PAPER, 0.98)
	var border_alpha := 0.90 if _hovered and _can_buy else 0.30
	_style.border_color = Color(accent.r, accent.g, accent.b, border_alpha) if _can_buy else Palette.DANGER.darkened(0.30)
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(0, 10, 3, size.y - 20), Color(accent.r, accent.g, accent.b, 0.85 if _can_buy else 0.25))

	var icon := _icon_rect()
	var center := icon.get_center()
	var tint := Color(1.0, 1.0, 1.0, 1.0 if _can_buy else 0.42)
	if _icon_texture != null:
		draw_texture_rect(_icon_texture, icon, false, tint)
	else:
		draw_category_icon(String(item.id), icon, tint)

	# 右侧三点握柄提示卡片可拖拽
	for row in 3:
		draw_circle(Vector2(size.x - 6.0, size.y * 0.5 - 8.0 + row * 8.0), 1.4, Color(Palette.INK_MUTED.r, Palette.INK_MUTED.g, Palette.INK_MUTED.b, 0.55))

	if not _can_buy:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.35))


func draw_category_icon(id: String, icon: Rect2, tint: Color) -> void:
	var center := icon.get_center()
	var scale := icon.size.x / 30.0
	if id == "sandbag":
		var sack := Color(0.74, 0.65, 0.48).lerp(Color.WHITE, 0.15)
		var dark := sack.darkened(0.28)
		for row in 2:
			for col in 3:
				var p := center + Vector2(-7.0 + col * 7.0, -3.0 + row * 6.0) * scale
				draw_circle(p, 4.2 * scale, dark)
				draw_circle(p - Vector2(0.0, 0.5) * scale, 4.0 * scale, sack)
		return
	if id == "solar":
		var panel := PackedVector2Array([
			center + Vector2(-11.0, -3.0) * scale,
			center + Vector2(1.0, -10.0) * scale,
			center + Vector2(11.0, -3.0) * scale,
			center + Vector2(-1.0, 4.0) * scale,
		])
		draw_colored_polygon(panel, Color(0.16, 0.33, 0.56))
		var outline := panel.duplicate()
		outline.append(panel[0])
		draw_polyline(outline, Color(0.62, 0.86, 0.96, 0.9), 1.2)
		draw_line(center + Vector2(-7.0, 5.0) * scale, center + Vector2(-7.0, 11.0) * scale, Color(0.42, 0.48, 0.50), 2.0)
		draw_line(center + Vector2(7.0, 5.0) * scale, center + Vector2(7.0, 11.0) * scale, Color(0.42, 0.48, 0.50), 2.0)
		return

	# 未知建筑用类别色的简笔图标兜底
	draw_circle(center, 10.0 * scale, Color(tint.r, tint.g, tint.b, 0.25))
	draw_arc(center, 10.0 * scale, 0.0, TAU, 20, tint, 1.5)
