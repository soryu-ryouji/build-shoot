extends Control

## 点击已放置炮塔后弹出的聚焦面板：属性、射程、发射数、拆除按钮。

const Palette = preload("res://scripts/palette.gd")
const ResponsiveLayout = preload("res://scripts/responsive_layout.gd")

var game: Node
var turret: Node = null

var title_label: Label
var desc_label: Label
var close_button: Button
var upgrade_button: Button
var dismantle_button: Button
var stat_names: Array[Label] = []
var stat_values: Array[Label] = []

var _accent := Palette.CYAN
var _panel_style: StyleBoxFlat


func _ready() -> void:
	position = Vector2(426, 208)
	size = Vector2(264, 408)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(Palette.PAPER, 0.98)
	_panel_style.border_color = _accent
	_panel_style.set_border_width_all(1)
	_panel_style.set_corner_radius_all(2)
	_panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	_panel_style.shadow_size = 8
	_panel_style.shadow_offset = Vector2(0, 4)

	title_label = _make_label(Vector2(18, 14), Vector2(202, 28), 21, Palette.INK)
	desc_label = _make_label(Vector2(18, 48), Vector2(228, 40), 11, Palette.INK_MUTED)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	close_button = Button.new()
	close_button.text = "×"
	close_button.position = Vector2(226, 12)
	close_button.size = Vector2(26, 26)
	close_button.flat = true
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.add_theme_color_override("font_color", Palette.INK_MUTED)
	close_button.add_theme_color_override("font_hover_color", Palette.INK)
	close_button.pressed.connect(_on_close)
	add_child(close_button)

	var keys := ["focus.damage", "focus.interval", "focus.range", "focus.pierce", "focus.bounce", "focus.shots"]
	for i in keys.size():
		var y := 112.0 + i * 28.0
		stat_names.append(_make_label(Vector2(18, y), Vector2(108, 24), 12, Palette.INK_MUTED))
		stat_values.append(_make_label(Vector2(126, y), Vector2(120, 24), 14, Palette.INK, HORIZONTAL_ALIGNMENT_RIGHT))

	upgrade_button = Button.new()
	upgrade_button.position = Vector2(18, 292)
	upgrade_button.size = Vector2(228, 44)
	upgrade_button.focus_mode = Control.FOCUS_NONE
	upgrade_button.add_theme_font_size_override("font_size", 12)
	upgrade_button.add_theme_color_override("font_color", Palette.INK)
	upgrade_button.add_theme_color_override("font_hover_color", Palette.INK)
	upgrade_button.add_theme_stylebox_override("normal", _button_style(Palette.ACCENT, Palette.ACCENT))
	upgrade_button.add_theme_stylebox_override("hover", _button_style(Palette.ACCENT.lightened(0.18), Palette.ACCENT))
	upgrade_button.add_theme_stylebox_override("pressed", _button_style(Palette.ACCENT.darkened(0.15), Palette.ACCENT))
	upgrade_button.add_theme_stylebox_override("disabled", _button_style(Color(0.72, 0.74, 0.72, 0.65), Color(0.30, 0.33, 0.34, 0.25)))
	upgrade_button.add_theme_color_override("font_disabled_color", Palette.INK_MUTED)
	upgrade_button.pressed.connect(_on_upgrade)
	add_child(upgrade_button)

	dismantle_button = Button.new()
	dismantle_button.position = Vector2(18, 346)
	dismantle_button.size = Vector2(228, 44)
	dismantle_button.focus_mode = Control.FOCUS_NONE
	dismantle_button.add_theme_font_size_override("font_size", 12)
	dismantle_button.add_theme_color_override("font_color", Palette.DANGER)
	dismantle_button.add_theme_color_override("font_hover_color", Color.WHITE)
	dismantle_button.add_theme_stylebox_override("normal", _button_style(Color(Palette.PAPER, 0.98), Palette.DANGER.darkened(0.1)))
	dismantle_button.add_theme_stylebox_override("hover", _button_style(Palette.DANGER.lightened(0.65), Palette.DANGER))
	dismantle_button.add_theme_stylebox_override("pressed", _button_style(Color(0.18, 0.05, 0.07, 1.0), Palette.DANGER))
	dismantle_button.pressed.connect(_on_dismantle)
	add_child(dismantle_button)

	I18n.locale_changed.connect(_on_locale_changed)
	get_viewport().size_changed.connect(_layout)
	_layout()


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
	style.set_corner_radius_all(1)
	return style


func show_turret(t: Node) -> void:
	turret = t
	_accent = Palette.ACCENT
	visible = true
	_layout()
	_refresh_texts()
	queue_redraw()


func _layout() -> void:
	var view := ResponsiveLayout.viewport_size(self)
	var margin := ResponsiveLayout.margin(self)
	position.y = clampf((view.y - size.y) * 0.5, 92.0, maxf(92.0, view.y - size.y - 24.0))
	if turret != null and is_instance_valid(turret):
		var screen_x: float = game.world_to_screen(turret.global_position).x
		position.x = margin if screen_x > view.x * 0.5 else view.x - size.x - margin
	else:
		position.x = view.x - size.x - margin


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
	title_label.add_theme_color_override("font_color", Palette.INK)
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
	stat_values[3].text = str(int(turret.pierce))
	stat_values[4].text = str(int(turret.bounces))
	stat_values[5].text = str(int(turret.shots))
	var cost := int(turret.get_upgrade_cost())
	upgrade_button.text = I18n.t("focus.upgrade", [cost])
	upgrade_button.disabled = int(game.coins) < cost
	dismantle_button.text = I18n.t("focus.dismantle", [turret.get_refund()])


func _on_locale_changed(_locale: String) -> void:
	if visible:
		_refresh_texts()
		queue_redraw()


func _on_close() -> void:
	game.clear_selection()


func _on_upgrade() -> void:
	game.upgrade_selected_damage()


func _on_dismantle() -> void:
	game.dismantle_selected()


func _draw() -> void:
	_panel_style.border_color = Color(_accent.r, _accent.g, _accent.b, 0.62)
	draw_style_box(_panel_style, Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(12, 0, 104, 4), _accent)
	draw_rect(Rect2(0, 14, 4, 58), _accent)
	draw_line(Vector2(18, 100), Vector2(size.x - 18, 100), Color(0.10, 0.12, 0.13, 0.16), 1.0)
	for i in 5:
		var y := 140.0 + i * 28.0
		draw_line(Vector2(18, y), Vector2(size.x - 18, y), Color(0.10, 0.12, 0.13, 0.07), 1.0)
