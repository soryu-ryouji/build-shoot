extends Control

## 响应式 HUD：顶部信息面板（金币、能源、波次、击碎数）和中居战斗提示。
## 尺寸按 400×800 移动端基线取，按钮不低于 52 逻辑像素。

signal settings_requested

const Palette = preload("res://scripts/palette.gd")
const NumberFont = preload("res://theme/number_font.tres")
const ResponsiveLayout = preload("res://scripts/responsive_layout.gd")
const UiMetrics = preload("res://scripts/ui_metrics.gd")

var game: Node
var top_panel: PanelContainer
var mode_label: Label
var tag_label: Label
var coins_label: Label
var coins_title_label: Label
var destroyed_label: Label
var energy_label: Label
var toast_label: Label
var settings_button: Button

var _toast_time := 0.0
var _coin_pop := 0.0
var _message_style: StyleBoxFlat


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	I18n.locale_changed.connect(_on_locale_changed)
	get_viewport().size_changed.connect(_layout)
	_refresh_static_texts()
	_layout()


func _build() -> void:
	_message_style = _style(Color(Palette.PAPER, 0.96), Palette.ACCENT, false)

	top_panel = PanelContainer.new()
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_panel.custom_minimum_size.y = UiMetrics.HUD_HEIGHT
	top_panel.add_theme_stylebox_override("panel", _style(Color(Palette.PAPER, 0.94), Palette.ACCENT, true))
	add_child(top_panel)

	var top_margin := MarginContainer.new()
	top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_margin.add_theme_constant_override("margin_left", 12)
	top_margin.add_theme_constant_override("margin_top", 9)
	top_margin.add_theme_constant_override("margin_right", 10)
	top_margin.add_theme_constant_override("margin_bottom", 9)
	top_panel.add_child(top_margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	top_margin.add_child(column)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UiMetrics.GAP)
	column.add_child(row)

	var mode_box := VBoxContainer.new()
	mode_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mode_box.add_theme_constant_override("separation", 0)
	row.add_child(mode_box)
	mode_label = _make_label(mode_box, "", UiMetrics.FONT_TITLE, Palette.INK)

	var coin_panel := PanelContainer.new()
	coin_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_panel.custom_minimum_size.x = 104
	coin_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var coin_style := _style(Color(1.0, 1.0, 0.98, 0.36), Palette.ACCENT, false)
	coin_style.border_width_bottom = 3
	coin_panel.add_theme_stylebox_override("panel", coin_style)
	row.add_child(coin_panel)
	var coin_box := VBoxContainer.new()
	coin_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_box.add_theme_constant_override("separation", -3)
	coin_panel.add_child(coin_box)
	coins_title_label = _make_label(coin_box, "", UiMetrics.FONT_MICRO, Palette.INK_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	coins_label = _make_label(coin_box, "", 30, Palette.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	coins_label.add_theme_font_override("font", NumberFont)
	coins_label.pivot_offset = Vector2(52, 20)

	settings_button = Button.new()
	settings_button.text = "≡"
	settings_button.flat = true
	settings_button.focus_mode = Control.FOCUS_NONE
	settings_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	settings_button.custom_minimum_size = Vector2(UiMetrics.TOUCH, UiMetrics.TOUCH)
	settings_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	settings_button.add_theme_font_size_override("font_size", 27)
	settings_button.add_theme_color_override("font_color", Palette.INK)
	settings_button.add_theme_color_override("font_hover_color", Palette.ACCENT)
	settings_button.add_theme_stylebox_override("normal", _button_style(Color(Palette.INK, 0.06)))
	settings_button.add_theme_stylebox_override("hover", _button_style(Color(Palette.ACCENT, 0.16)))
	settings_button.add_theme_stylebox_override("pressed", _button_style(Color(Palette.ACCENT, 0.28)))
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	row.add_child(settings_button)

	var info := HBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", UiMetrics.GAP)
	column.add_child(info)
	tag_label = _make_label(info, "", UiMetrics.FONT_MICRO, Palette.INK_MUTED)
	tag_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	energy_label = _make_label(info, "", UiMetrics.FONT_SMALL, Palette.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	destroyed_label = _make_label(info, "", UiMetrics.FONT_SMALL, Palette.INK_MUTED, HORIZONTAL_ALIGNMENT_RIGHT)

	toast_label = _make_label(self, "", 21, Palette.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.add_theme_constant_override("outline_size", 4)
	toast_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	toast_label.modulate.a = 0.0


func _make_label(parent: Node, text: String, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _style(fill: Color, border: Color, accent: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.border_width_left = 4 if accent else 1
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.12)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


func _button_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(2)
	return style


func _layout() -> void:
	var view := ResponsiveLayout.viewport_size(self)
	var safe := ResponsiveLayout.safe_rect(self)
	var margin := ResponsiveLayout.margin(self)

	top_panel.position = safe.position + Vector2(margin, margin)
	top_panel.size = Vector2(safe.size.x - margin * 2.0, UiMetrics.HUD_HEIGHT)

	var message_width := minf(360.0, view.x - 32.0)
	toast_label.size = Vector2(message_width, UiMetrics.TOAST_HEIGHT)
	toast_label.position = Vector2((view.x - message_width) * 0.5, view.y * 0.42 - 20.0)
	queue_redraw()


func _refresh_static_texts() -> void:
	mode_label.text = I18n.t("hud.mode")
	tag_label.text = I18n.t("hud.tag")
	coins_title_label.text = I18n.t("hud.coins_label")
	settings_button.tooltip_text = I18n.t("settings.open")


func _on_locale_changed(_locale: String) -> void:
	_refresh_static_texts()


func _process(delta: float) -> void:
	if game == null:
		return

	coins_label.text = I18n.t("hud.coins_value", [int(game.coins)])
	if _coin_pop > 0.0:
		_coin_pop = maxf(0.0, _coin_pop - delta * 4.0)
		coins_label.scale = Vector2.ONE * (1.0 + 0.12 * _coin_pop)
	else:
		coins_label.scale = Vector2.ONE

	destroyed_label.text = I18n.t("hud.destroyed", [int(game.blocks.destroyed)])
	var demand := int(game.power_demand)
	var supply := int(game.power_supply)
	var offline := int(game.power_offline)
	if demand <= 0 and supply <= 0:
		energy_label.text = ""
	elif offline > 0:
		energy_label.text = I18n.t("hud.energy_offline", [demand, supply, offline])
		energy_label.add_theme_color_override("font_color", Palette.DANGER)
	else:
		energy_label.text = I18n.t("hud.energy", [demand, supply])
		energy_label.add_theme_color_override("font_color", Palette.ACCENT)
	var wave := int(game.blocks.wave)
	if wave > 0:
		var next_wave := int(ceil(float(game.blocks.next_wave_in)))
		tag_label.text = I18n.t("hud.wave_next", [wave, next_wave]) if next_wave > 0 else I18n.t("hud.wave", [wave])

	if _toast_time > 0.0:
		_toast_time -= delta
		toast_label.modulate.a = clampf(_toast_time / 0.4, 0.0, 1.0)
	else:
		toast_label.modulate.a = 0.0
	queue_redraw()


func pop_coins() -> void:
	_coin_pop = 1.0


func toast(text: String, color: Color) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	toast_label.modulate.a = 1.0
	_toast_time = 1.5


func _draw() -> void:
	if toast_label != null and toast_label.modulate.a > 0.0:
		_message_style.bg_color.a = 0.96 * toast_label.modulate.a
		_message_style.border_color.a = 0.75 * toast_label.modulate.a
		draw_style_box(_message_style, Rect2(toast_label.position, toast_label.size))
