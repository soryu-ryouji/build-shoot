extends Control

## 点击已放置炮塔后弹出的聚焦面板：属性、射程、发射数、升级与拆除。
## 移动端改为贴底的宽面板，按钮落在拇指区，字号和点击区域都按手机取值。

const Palette = preload("res://scripts/palette.gd")
const NumberFont = preload("res://theme/number_font.tres")
const ResponsiveLayout = preload("res://scripts/responsive_layout.gd")
const UiMetrics = preload("res://scripts/ui_metrics.gd")

const STAT_KEYS := ["focus.damage", "focus.interval", "focus.range", "focus.pierce", "focus.bounce", "focus.shots"]

var game: Node
var turret: Node = null

var panel: PanelContainer
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
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(Palette.PAPER, 0.985)
	_panel_style.border_color = _accent
	_panel_style.set_border_width_all(1)
	_panel_style.border_width_top = 3
	_panel_style.set_corner_radius_all(3)
	_panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	_panel_style.shadow_size = 10
	_panel_style.shadow_offset = Vector2(0, 5)

	panel = PanelContainer.new()
	panel.name = "Sheet"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style)
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiMetrics.GAP - 2)
	margin.add_child(column)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(64, 3)
	rule.color = Palette.ACCENT
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UiMetrics.GAP)
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	header.add_child(titles)
	title_label = _make_label(titles, 21, Palette.INK)
	desc_label = _make_label(titles, UiMetrics.FONT_SMALL, Palette.INK_MUTED)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.max_lines_visible = 2
	desc_label.custom_minimum_size.y = 30

	close_button = Button.new()
	close_button.text = "×"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(48, 48)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.add_theme_font_size_override("font_size", 22)
	close_button.add_theme_color_override("font_color", Palette.INK_MUTED)
	close_button.add_theme_color_override("font_hover_color", Palette.INK)
	close_button.add_theme_stylebox_override("normal", _button_style(Color(Palette.PAPER, 0.98), Color(Palette.INK, 0.22)))
	close_button.add_theme_stylebox_override("hover", _button_style(Color(Palette.ACCENT, 0.16), Palette.ACCENT))
	close_button.add_theme_stylebox_override("pressed", _button_style(Color(Palette.ACCENT, 0.28), Palette.ACCENT))
	close_button.pressed.connect(_on_close)
	header.add_child(close_button)

	column.add_child(_separator())

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	for i in STAT_KEYS.size():
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		grid.add_child(cell)
		stat_names.append(_make_label(cell, UiMetrics.FONT_MICRO, Palette.INK_MUTED))
		stat_values.append(_make_label(cell, 19, Palette.INK))
		stat_values[i].add_theme_font_override("font", NumberFont)

	column.add_child(_separator())

	upgrade_button = Button.new()
	upgrade_button.focus_mode = Control.FOCUS_NONE
	upgrade_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_button.custom_minimum_size.y = UiMetrics.TOUCH_LARGE
	upgrade_button.add_theme_font_size_override("font_size", UiMetrics.FONT_LABEL)
	upgrade_button.add_theme_color_override("font_color", Palette.INK)
	upgrade_button.add_theme_color_override("font_hover_color", Palette.INK)
	upgrade_button.add_theme_color_override("font_disabled_color", Palette.INK_MUTED)
	upgrade_button.add_theme_stylebox_override("normal", _button_style(Palette.ACCENT, Palette.ACCENT))
	upgrade_button.add_theme_stylebox_override("hover", _button_style(Palette.ACCENT.lightened(0.18), Palette.ACCENT))
	upgrade_button.add_theme_stylebox_override("pressed", _button_style(Palette.ACCENT.darkened(0.15), Palette.ACCENT))
	upgrade_button.add_theme_stylebox_override("disabled", _button_style(Color(0.72, 0.74, 0.72, 0.65), Color(0.30, 0.33, 0.34, 0.25)))
	upgrade_button.pressed.connect(_on_upgrade)
	column.add_child(upgrade_button)

	dismantle_button = Button.new()
	dismantle_button.focus_mode = Control.FOCUS_NONE
	dismantle_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	dismantle_button.custom_minimum_size.y = 50
	dismantle_button.add_theme_font_size_override("font_size", UiMetrics.FONT_BODY)
	dismantle_button.add_theme_color_override("font_color", Palette.DANGER)
	dismantle_button.add_theme_color_override("font_hover_color", Color.WHITE)
	dismantle_button.add_theme_stylebox_override("normal", _button_style(Color(Palette.PAPER, 0.98), Palette.DANGER.darkened(0.1)))
	dismantle_button.add_theme_stylebox_override("hover", _button_style(Palette.DANGER.lightened(0.65), Palette.DANGER))
	dismantle_button.add_theme_stylebox_override("pressed", _button_style(Color(0.18, 0.05, 0.07, 1.0), Palette.DANGER))
	dismantle_button.pressed.connect(_on_dismantle)
	column.add_child(dismantle_button)

	I18n.locale_changed.connect(_on_locale_changed)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _make_label(parent: Node, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _separator() -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size.y = 1
	line.color = Color(0.10, 0.12, 0.13, 0.14)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style


func show_turret(t: Node) -> void:
	turret = t
	_accent = Palette.ACCENT
	_panel_style.border_color = _accent
	visible = true
	_refresh_texts()
	_layout()
	queue_redraw()


func _layout() -> void:
	if panel == null:
		return
	var safe := ResponsiveLayout.safe_rect(self)
	var margin := ResponsiveLayout.margin(self)
	var width := safe.size.x - margin * 2.0
	# 先按目标宽度排版，让说明文字在正确宽度下换行，再收紧高度
	size = Vector2(width, size.y)
	var height := minf(panel.get_combined_minimum_size().y, safe.size.y - margin * 2.0 - 8.0)
	size = Vector2(width, height)
	position = Vector2(
		safe.position.x + (safe.size.x - width) * 0.5,
		safe.end.y - margin - height,
	)
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
	title_label.add_theme_color_override("font_color", Palette.INK)
	desc_label.text = turret.get_display_desc()
	for i in STAT_KEYS.size():
		stat_names[i].text = I18n.t(STAT_KEYS[i])
	_update_values()


func _update_values() -> void:
	if turret == null or not is_instance_valid(turret):
		return
	stat_values[0].text = str(int(turret.get_effective_damage()))
	stat_values[1].text = I18n.t("focus.interval_value", [String.num(float(turret.interval), 2)])
	stat_values[2].text = str(int(turret.attack_range))
	stat_values[3].text = "∞" if int(turret.pierce) < 0 else str(int(turret.pierce))
	stat_values[4].text = str(int(turret.bounces))
	stat_values[5].text = str(int(turret.shots))
	var cost := int(turret.get_upgrade_cost())
	upgrade_button.text = I18n.t("focus.upgrade", [cost])
	upgrade_button.disabled = int(game.coins) < cost
	dismantle_button.text = I18n.t("focus.dismantle", [turret.get_refund()])


func _on_locale_changed(_locale: String) -> void:
	if visible:
		_refresh_texts()
		_layout()
		queue_redraw()


func _on_close() -> void:
	game.clear_selection()


func _on_upgrade() -> void:
	game.upgrade_selected_damage()


func _on_dismantle() -> void:
	game.dismantle_selected()
