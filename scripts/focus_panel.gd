extends Control

## 点击已放置炮塔后弹出的聚焦面板：属性、射程、发射数、拆除按钮。

const Palette = preload("res://scripts/palette.gd")

var game: Node
var turret: Node = null

var title_label: Label
var desc_label: Label
var close_button: Button
var dismantle_button: Button
var stat_names: Array[Label] = []
var stat_values: Array[Label] = []

var _accent := Palette.CYAN
var _panel_style: StyleBoxFlat


func _ready() -> void:
	position = Vector2(452, 208)
	size = Vector2(228, 330)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(0.035, 0.065, 0.12, 0.97)
	_panel_style.border_color = _accent
	_panel_style.set_border_width_all(1)
	_panel_style.set_corner_radius_all(12)

	title_label = _make_label(Vector2(16, 12), Vector2(168, 26), 18, Palette.TEXT)
	desc_label = _make_label(Vector2(16, 42), Vector2(196, 44), 10, Palette.MUTED)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	close_button = Button.new()
	close_button.text = "×"
	close_button.position = Vector2(194, 8)
	close_button.size = Vector2(26, 26)
	close_button.flat = true
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.add_theme_color_override("font_color", Palette.MUTED)
	close_button.add_theme_color_override("font_hover_color", Palette.TEXT)
	close_button.pressed.connect(_on_close)
	add_child(close_button)

	var keys := ["focus.damage", "focus.interval", "focus.range", "focus.pierce", "focus.bounce", "focus.shots"]
	for i in keys.size():
		var y := 102.0 + i * 25.0
		stat_names.append(_make_label(Vector2(16, y), Vector2(96, 22), 11, Palette.MUTED))
		stat_values.append(_make_label(Vector2(100, y), Vector2(112, 22), 13, Palette.TEXT, HORIZONTAL_ALIGNMENT_RIGHT))

	dismantle_button = Button.new()
	dismantle_button.position = Vector2(16, 262)
	dismantle_button.size = Vector2(196, 44)
	dismantle_button.focus_mode = Control.FOCUS_NONE
	dismantle_button.add_theme_font_size_override("font_size", 12)
	dismantle_button.add_theme_color_override("font_color", Palette.DANGER)
	dismantle_button.add_theme_color_override("font_hover_color", Color.WHITE)
	dismantle_button.add_theme_stylebox_override("normal", _button_style(Color(0.24, 0.07, 0.09, 0.95), Palette.DANGER.darkened(0.2)))
	dismantle_button.add_theme_stylebox_override("hover", _button_style(Color(0.38, 0.10, 0.13, 0.98), Palette.DANGER))
	dismantle_button.add_theme_stylebox_override("pressed", _button_style(Color(0.18, 0.05, 0.07, 1.0), Palette.DANGER))
	dismantle_button.pressed.connect(_on_dismantle)
	add_child(dismantle_button)

	I18n.locale_changed.connect(_on_locale_changed)


func _make_label(pos: Vector2, label_size: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	return style


func show_turret(t: Node) -> void:
	turret = t
	_accent = t.color
	position.x = 30.0 if t.global_position.x > 360.0 else 452.0
	visible = true
	_refresh_texts()
	queue_redraw()


func hide_panel() -> void:
	visible = false
	turret = null


func _process(_delta: float) -> void:
	if not visible:
		return
	if turret == null or not is_instance_valid(turret):
		hide_panel()
		return
	_update_values()


func _refresh_texts() -> void:
	if turret == null or not is_instance_valid(turret):
		return
	title_label.text = turret.get_display_name()
	title_label.add_theme_color_override("font_color", _accent)
	desc_label.text = turret.get_display_desc()
	stat_names[0].text = I18n.t("focus.damage")
	stat_names[1].text = I18n.t("focus.interval")
	stat_names[2].text = I18n.t("focus.range")
	stat_names[3].text = I18n.t("focus.pierce")
	stat_names[4].text = I18n.t("focus.bounce")
	stat_names[5].text = I18n.t("focus.shots")
	dismantle_button.text = I18n.t("focus.dismantle", [turret.get_refund()])
	_update_values()


func _update_values() -> void:
	if turret == null or not is_instance_valid(turret):
		return
	stat_values[0].text = str(int(turret.get_effective_damage()))
	stat_values[1].text = I18n.t("focus.interval_value", [String.num(float(turret.interval), 2)])
	stat_values[2].text = str(int(turret.attack_range))
	stat_values[3].text = str(int(turret.get_effective_pierce()))
	stat_values[4].text = str(int(turret.get_effective_bounces()))
	stat_values[5].text = str(int(turret.shots))


func _on_locale_changed(_locale: String) -> void:
	if visible:
		_refresh_texts()
		queue_redraw()


func _on_close() -> void:
	game.clear_selection()


func _on_dismantle() -> void:
	game.dismantle_selected()


func _draw() -> void:
	draw_rect(Rect2(3, 5, size.x, size.y), Color(0.0, 0.0, 0.0, 0.35))
	_panel_style.border_color = _accent
	draw_style_box(_panel_style, Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(0, 0, size.x, 4), _accent)
	draw_line(Vector2(16, 92), Vector2(size.x - 16, 92), Color(1.0, 1.0, 1.0, 0.08), 1.0)
