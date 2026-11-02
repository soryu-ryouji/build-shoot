extends Control

## 底部商店里的单个道具卡片。点击开始时由 ShopBar 接管拖拽。

const Palette = preload("res://scripts/palette.gd")

signal drag_started(item_id: String)

var game: Node
var item: Dictionary = {}

var name_label: Label
var cost_label: Label
var hint_label: Label

var _can_buy := false
var _style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.05, 0.10, 0.18, 0.95)
	_style.set_border_width_all(1)
	_style.set_corner_radius_all(8)

	name_label = _make_label(Vector2(62, 6), Vector2(130, 22), 14, Palette.TEXT)
	cost_label = _make_label(Vector2(62, 28), Vector2(130, 18), 11, Palette.ACCENT)
	hint_label = _make_label(Vector2(62, 48), Vector2(130, 14), 9, Palette.MUTED)

	I18n.locale_changed.connect(_on_locale_changed)
	_refresh_texts()
	_can_buy = int(game.coins) >= int(item.cost)


func _make_label(pos: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _refresh_texts() -> void:
	if item.is_empty():
		return
	name_label.text = I18n.t(String(item.name_key))
	cost_label.text = I18n.t("shop.cost", [int(item.cost)])
	hint_label.text = I18n.t("shop.drag_hint")
	name_label.add_theme_color_override("font_color", Palette.TEXT)


func _on_locale_changed(_locale: String) -> void:
	_refresh_texts()


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

	var color: Color = item.color
	_style.border_color = color if _can_buy else Palette.DANGER.darkened(0.25)
	draw_style_box(_style, Rect2(Vector2.ZERO, size))

	# 炮塔图标
	var center := Vector2(32, 36)
	draw_circle(center, 19.0, Color(color.r, color.g, color.b, 0.10))
	if String(item.id) == "heavy_turret":
		var hex := PackedVector2Array()
		for i in 6:
			hex.append(center + Vector2.from_angle(PI / 6.0 + i * TAU / 6.0) * 13.0)
		draw_colored_polygon(hex, Color("141a24"))
		var outline := hex.duplicate()
		outline.append(hex[0])
		draw_polyline(outline, color, 1.5)
		draw_rect(Rect2(center + Vector2(-4.0, -18.0), Vector2(8.0, 15.0)), color.darkened(0.25))
		draw_rect(Rect2(center + Vector2(-6.0, -20.0), Vector2(12.0, 5.0)), color)
		for i in 3:
			draw_circle(center + Vector2(-5.0 + i * 5.0, 8.0), 1.5, color)
	else:
		draw_circle(center, 13.0, color.darkened(0.35))
		draw_arc(center, 13.0, 0.0, TAU, 24, color, 1.5)
		draw_rect(Rect2(center + Vector2(-3.0, -20.0), Vector2(6.0, 14.0)), color)
		draw_circle(center + Vector2(0.0, -20.0), 3.5, color.lightened(0.35))

	if not _can_buy:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.35))
