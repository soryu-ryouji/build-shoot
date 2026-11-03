extends Control

## 失败结算：核心被撞光后盖住整个界面，只给重开和回主菜单两个出口。

signal restart_requested
signal menu_requested

const Palette = preload("res://scripts/palette.gd")
const ResponsiveLayout = preload("res://scripts/responsive_layout.gd")
const UiMetrics = preload("res://scripts/ui_metrics.gd")

var panel: PanelContainer
var title_label: Label
var stats_label: Label
var restart_button: Button
var menu_button: Button

var wave_reached := 0
var killed := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	I18n.locale_changed.connect(_refresh_texts)
	get_viewport().size_changed.connect(_layout)
	_refresh_texts()
	_layout()


func _build() -> void:
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	title_label = _make_label(column, 26, Palette.INK)
	stats_label = _make_label(column, UiMetrics.FONT_SMALL, Palette.INK_MUTED)

	restart_button = _make_button(column, true)
	restart_button.custom_minimum_size.y = 60
	restart_button.pressed.connect(_on_restart)
	menu_button = _make_button(column, false)
	menu_button.custom_minimum_size.y = 54
	menu_button.pressed.connect(_on_menu)


func _make_label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _make_button(parent: Node, primary: bool) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", UiMetrics.FONT_LABEL)
	button.add_theme_color_override("font_color", Palette.INK)
	button.add_theme_color_override("font_hover_color", Palette.INK)
	button.add_theme_color_override("font_pressed_color", Palette.INK)
	var border := Palette.ACCENT if primary else Color(0.20, 0.23, 0.24, 0.28)
	var fill := Color(Palette.ACCENT, 0.96) if primary else Color(1.0, 1.0, 0.98, 0.62)
	button.add_theme_stylebox_override("normal", _button_style(fill, border, primary))
	button.add_theme_stylebox_override("hover", _button_style(Color(1.0, 0.94, 0.80, 0.95), Palette.ACCENT, true))
	button.add_theme_stylebox_override("pressed", _button_style(Palette.ACCENT, Palette.ACCENT, true))
	parent.add_child(button)
	return button


func _panel_style() -> StyleBoxFlat:
	var style := _button_style(Color(Palette.PAPER, 0.98), Color(1.0, 1.0, 0.98, 0.85), true)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 5)
	return style


func _button_style(fill: Color, border: Color, accent: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.border_width_left = 4 if accent else 1
	style.content_margin_left = 16
	style.content_margin_right = 16
	return style


func _layout() -> void:
	if panel == null:
		return
	var safe := ResponsiveLayout.safe_rect(self)
	var margin := ResponsiveLayout.margin(self)
	panel.reset_size()
	var minimum := panel.get_combined_minimum_size()
	var available := safe.size.x - margin * 2.0
	var target := Vector2(minf(360.0, available), minf(minimum.y, safe.size.y - margin * 2.0))
	target.x = maxf(target.x, minf(minimum.x, available))
	panel.size = target
	panel.position = safe.position + (safe.size - target) * 0.5


func show_result(wave: int, kills: int) -> void:
	wave_reached = wave
	killed = kills
	visible = true
	_refresh_texts()
	_layout()
	move_to_front()


func _refresh_texts(_locale: String = "") -> void:
	if title_label == null:
		return
	title_label.text = I18n.t("over.title")
	stats_label.text = I18n.t("over.stats", [wave_reached, killed])
	restart_button.text = I18n.t("over.restart")
	menu_button.text = I18n.t("over.menu")


func _on_restart() -> void:
	visible = false
	restart_requested.emit()


func _on_menu() -> void:
	visible = false
	menu_requested.emit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.12, 0.13, 0.72))
