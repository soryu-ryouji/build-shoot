extends Control

## 底部商店里的单个道具卡片。点击开始时由 ShopBar 接管拖拽。
## 尺寸跟随卡片实际宽度，图标、名称和价格在大屏手机上仍然清晰可读。

const Palette = preload("res://scripts/palette.gd")
const UiMetrics = preload("res://scripts/ui_metrics.gd")

signal drag_started(item_id: String)

var game: Node
var item: Dictionary = {}

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

	var icon_path := "res://assets/ui/heavy_turret.png" if String(item.id) == "heavy_turret" else "res://assets/ui/turret.png"
	_icon_texture = load(icon_path)

	name_label = _make_label(16, Palette.INK)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 2
	cost_label = _make_label(UiMetrics.FONT_BODY, Palette.ACCENT)

	I18n.locale_changed.connect(_on_locale_changed)
	_refresh_texts()
	_can_buy = int(game.coins) >= int(item.cost)
	_layout()


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
	var text_x := icon.end.x + 12.0
	var text_width := maxf(48.0, size.x - text_x - 20.0)
	name_label.position = Vector2(text_x, maxf(4.0, (size.y - 70.0) * 0.5))
	name_label.size = Vector2(text_width, 44.0)
	cost_label.position = Vector2(text_x, name_label.position.y + 46.0)
	cost_label.size = Vector2(text_width, 24.0)
	queue_redraw()


func _icon_rect() -> Rect2:
	var side := minf(56.0, size.y - 24.0)
	return Rect2(12.0, (size.y - side) * 0.5, side, side)


func _refresh_texts() -> void:
	if item.is_empty():
		return
	name_label.text = I18n.t(String(item.name_key))
	cost_label.text = I18n.t("shop.cost", [int(item.cost)])
	name_label.add_theme_color_override("font_color", Palette.INK)


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

	var color: Color = item.color
	_style.bg_color = Color(1.0, 0.98, 0.90, 1.0) if _hovered and _can_buy else Color(Palette.PAPER, 0.98)
	var accent := Palette.ACCENT if String(item.id) == "heavy_turret" else Palette.INK
	var border_alpha := 0.90 if _hovered and _can_buy else 0.30
	_style.border_color = Color(accent.r, accent.g, accent.b, border_alpha) if _can_buy else Palette.DANGER.darkened(0.30)
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(0, 16, 4, size.y - 32), Color(accent.r, accent.g, accent.b, 0.85 if _can_buy else 0.25))
	draw_line(Vector2(16, 0), Vector2(76, 0), Palette.ACCENT, 3.0)

	# 商店与场上共用炮塔美术；加载失败时保留矢量后备图标。
	var icon := _icon_rect()
	var center := icon.get_center()
	if _icon_texture != null:
		draw_texture_rect(_icon_texture, icon, false, Color(1.0, 1.0, 1.0, 1.0 if _can_buy else 0.42))
	else:
		draw_circle(center, icon.size.x * 0.42, Color(color.r, color.g, color.b, 0.10))
	if _icon_texture == null and String(item.id) == "heavy_turret":
		var hex := PackedVector2Array()
		for i in 6:
			hex.append(center + Vector2.from_angle(PI / 6.0 + i * TAU / 6.0) * (icon.size.x * 0.23))
		draw_colored_polygon(hex, Color("141a24"))
		var outline := hex.duplicate()
		outline.append(hex[0])
		draw_polyline(outline, color, 1.5)
		draw_rect(Rect2(center + Vector2(-4.0, -18.0), Vector2(8.0, 15.0)), color.darkened(0.25))
		draw_rect(Rect2(center + Vector2(-6.0, -20.0), Vector2(12.0, 5.0)), color)
		for i in 3:
			draw_circle(center + Vector2(-5.0 + i * 5.0, 8.0), 1.5, color)
	elif _icon_texture == null:
		draw_circle(center, 13.0, color.darkened(0.35))
		draw_arc(center, 13.0, 0.0, TAU, 24, color, 1.5)
		draw_rect(Rect2(center + Vector2(-3.0, -20.0), Vector2(6.0, 14.0)), color)
		draw_circle(center + Vector2(0.0, -20.0), 3.5, color.lightened(0.35))

	# 右侧三点握柄提示卡片可拖拽。
	for row in 3:
		draw_circle(Vector2(size.x - 9.0, size.y * 0.5 - 10.0 + row * 10.0), 1.6, Color(Palette.INK_MUTED.r, Palette.INK_MUTED.g, Palette.INK_MUTED.b, 0.55))

	if not _can_buy:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.35))
