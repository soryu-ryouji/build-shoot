extends Control

## 类别上方的道具列表项：点击切换该类别当前选中的建筑。

const Palette = preload("res://scripts/palette.gd")
const ItemDefs = preload("res://scripts/item_defs.gd")
const UiMetrics = preload("res://scripts/ui_metrics.gd")

signal pressed(item_id: String)

var game: Node
var item: Dictionary = {}
var active := false

var name_label: Label
var cost_label: Label
var _icon_texture: Texture2D
var _hovered := false
var _style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(_layout)
	_style = StyleBoxFlat.new()
	_style.set_border_width_all(1)
	_style.set_corner_radius_all(2)
	_load_icon()
	name_label = _make_label(13, Palette.INK)
	cost_label = _make_label(UiMetrics.FONT_MICRO, Palette.ACCENT)
	I18n.locale_changed.connect(_refresh_texts)
	_refresh_texts()
	_layout()


func _load_icon() -> void:
	_icon_texture = null
	var path := String(item.get("icon", ""))
	if not path.is_empty():
		_icon_texture = load(path)


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _layout() -> void:
	if name_label == null:
		return
	var icon := _icon_rect()
	name_label.position = Vector2(icon.end.x + 6.0, 2.0)
	name_label.size = Vector2(maxf(20.0, size.x - name_label.position.x - 6.0), 18.0)
	cost_label.position = Vector2(icon.end.x + 6.0, 20.0)
	cost_label.size = Vector2(maxf(20.0, size.x - cost_label.position.x - 6.0), 16.0)
	queue_redraw()


func _icon_rect() -> Rect2:
	var side := minf(26.0, size.y - 8.0)
	return Rect2(Vector2(6.0, (size.y - side) * 0.5), Vector2(side, side))


func _refresh_texts(_locale: String = "") -> void:
	if item.is_empty():
		return
	name_label.text = I18n.t(String(item.name_key))
	cost_label.text = I18n.t("shop.cost", [int(item.cost)])
	queue_redraw()


func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var pressed_now := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed_now = event.pressed
	elif event is InputEventScreenTouch:
		pressed_now = event.pressed
	if pressed_now:
		pressed.emit(String(item.id))
		accept_event()


func _draw() -> void:
	var accent := ItemDefs.category_color(String(item.category))
	var fill := Color(1.0, 0.98, 0.90, 1.0) if active else Color(Palette.PAPER, 0.92)
	if _hovered and not active:
		fill = Color(1.0, 0.98, 0.94, 1.0)
	_style.bg_color = fill
	_style.border_color = Color(accent.r, accent.g, accent.b, 0.95 if active else 0.28)
	_style.set_border_width_all(2 if active else 1)
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	var icon := _icon_rect()
	if _icon_texture != null:
		draw_texture_rect(_icon_texture, icon, false, Color.WHITE)
	else:
		draw_circle(icon.get_center(), icon.size.x * 0.38, Color(accent.r, accent.g, accent.b, 0.25))
