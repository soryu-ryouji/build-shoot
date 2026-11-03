extends Control

## 点击已放置建筑后弹出的聚焦面板：按类别显示属性、形态升级与拆除。
## 移动端使用贴底宽面板，升级按钮动态生成，保证 400×800 下仍能放下两个分支。

const Palette = preload("res://scripts/palette.gd")
const NumberFont = preload("res://theme/number_font.tres")
const ResponsiveLayout = preload("res://scripts/responsive_layout.gd")
const UiMetrics = preload("res://scripts/ui_metrics.gd")
const ItemDefs = preload("res://scripts/item_defs.gd")

const FIREPOWER_STATS := ["focus.damage", "focus.rate", "focus.range", "focus.pierce", "focus.bounce", "focus.shots"]
const FORTIFICATION_STATS := ["focus.hp", "focus.block", "focus.buff", "focus.energy", "focus.line", "focus.status"]
const ENERGY_STATS := ["focus.output", "focus.hp", "focus.energy_net", "focus.status"]

var game: Node
var building: Node = null

var panel: PanelContainer
var title_label: Label
var desc_label: Label
var power_label: Label
var close_button: Button
var rule: ColorRect
var upgrade_box: VBoxContainer
var upgrade_buttons: Array[Button] = []
## 第一个升级按钮，供响应式回归检查点击区域
var upgrade_button: Button = null
var dismantle_button: Button
var stat_cells: Array[VBoxContainer] = []
var stat_names: Array[Label] = []
var stat_values: Array[Label] = []

var _accent := Palette.ACCENT
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

	rule = ColorRect.new()
	rule.custom_minimum_size = Vector2(64, 3)
	rule.color = Palette.ACCENT
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UiMetrics.GAP)
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 1)
	header.add_child(titles)
	title_label = _make_label(titles, 21, Palette.INK)
	desc_label = _make_label(titles, UiMetrics.FONT_SMALL, Palette.INK_MUTED)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.max_lines_visible = 2
	desc_label.custom_minimum_size.y = 28
	power_label = _make_label(titles, UiMetrics.FONT_MICRO, Palette.INK_MUTED)

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
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	for i in 6:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		grid.add_child(cell)
		stat_cells.append(cell)
		stat_names.append(_make_label(cell, UiMetrics.FONT_MICRO, Palette.INK_MUTED))
		stat_values.append(_make_label(cell, 19, Palette.INK))
		stat_values[i].add_theme_font_override("font", NumberFont)

	column.add_child(_separator())

	upgrade_box = VBoxContainer.new()
	upgrade_box.add_theme_constant_override("separation", 4)
	column.add_child(upgrade_box)

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


func show_building(t: Node) -> void:
	building = t
	_accent = ItemDefs.category_color(String(t.category))
	_panel_style.border_color = _accent
	rule.color = _accent
	visible = true
	_refresh_texts()
	_layout()
	queue_redraw()


func refresh() -> void:
	if not visible:
		return
	_refresh_texts()
	_layout()


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
	building = null


func _process(_delta: float) -> void:
	if not visible:
		return
	if building == null or not is_instance_valid(building):
		hide_panel()
		return
	_update_values()


func _refresh_texts() -> void:
	if building == null or not is_instance_valid(building):
		return
	title_label.text = building.get_display_name()
	desc_label.text = building.get_display_desc()
	power_label.text = _power_text()
	power_label.add_theme_color_override("font_color", Palette.DANGER if not building.powered else Palette.INK_MUTED)
	_refresh_upgrades()
	_update_values()


func _power_text() -> String:
	if building == null or not is_instance_valid(building):
		return ""
	var text := ""
	if building.is_energy():
		text = I18n.t("focus.output_value", [int(building.energy_output)])
	else:
		text = I18n.t("focus.demand_value", [int(building.energy_demand)])
	if not building.powered:
		text += " · " + I18n.t("focus.paralyzed")
	return text


func _refresh_upgrades() -> void:
	for child in upgrade_box.get_children():
		upgrade_box.remove_child(child)
		child.queue_free()
	upgrade_buttons.clear()
	upgrade_button = null

	if building == null or not is_instance_valid(building):
		return
	var options: Array = building.get_upgrade_options()
	if options.is_empty():
		var maxed := _make_label(upgrade_box, UiMetrics.FONT_SMALL, Palette.INK_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		maxed.text = I18n.t("focus.maxed")
		return

	for option in options:
		var effect := _make_label(upgrade_box, UiMetrics.FONT_MICRO, Palette.INK_MUTED)
		effect.text = I18n.t(String(option.desc_key))
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect.max_lines_visible = 2
		effect.custom_minimum_size.y = 30

		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size.y = 50
		button.add_theme_font_size_override("font_size", UiMetrics.FONT_LABEL)
		button.add_theme_color_override("font_color", Palette.INK)
		button.add_theme_color_override("font_hover_color", Palette.INK)
		button.add_theme_color_override("font_disabled_color", Palette.INK_MUTED)
		button.add_theme_stylebox_override("normal", _button_style(Palette.ACCENT, Palette.ACCENT))
		button.add_theme_stylebox_override("hover", _button_style(Palette.ACCENT.lightened(0.18), Palette.ACCENT))
		button.add_theme_stylebox_override("pressed", _button_style(Palette.ACCENT.darkened(0.15), Palette.ACCENT))
		button.add_theme_stylebox_override("disabled", _button_style(Color(0.72, 0.74, 0.72, 0.65), Color(0.30, 0.33, 0.34, 0.25)))
		var target_id := String(option.id)
		var target_cost := int(option.cost)
		button.text = I18n.t("focus.upgrade_to", [I18n.t(String(option.name_key)), target_cost])
		button.set_meta("cost", target_cost)
		button.pressed.connect(func() -> void: _on_upgrade_to(target_id))
		upgrade_box.add_child(button)
		upgrade_buttons.append(button)

	if not upgrade_buttons.is_empty():
		upgrade_button = upgrade_buttons[0]


func _update_values() -> void:
	if building == null or not is_instance_valid(building):
		return

	var names: Array = []
	var values: Array = []
	match String(building.category):
		ItemDefs.CATEGORY_FIREPOWER:
			names = FIREPOWER_STATS
			values = [
				str(int(building.get_effective_damage())),
				I18n.t("focus.rate_value", [String.num(float(building.get_effective_rate()), 2)]),
				str(int(building.attack_range)),
				"∞" if int(building.pierce) < 0 else str(int(building.pierce)),
				str(int(building.bounces)),
				str(int(building.shots)),
			]
		ItemDefs.CATEGORY_FORTIFICATION:
			names = FORTIFICATION_STATS
			values = [
				"%d/%d" % [int(ceil(float(building.hp))), int(building.max_hp)],
				I18n.t("focus.yes") if bool(building.blocks_enemies) else I18n.t("focus.no"),
				"×%d" % int(building.buff_multiplier) if int(building.buff_multiplier) > 1 else "—",
				str(int(building.energy_demand)),
				I18n.t("focus.line_row") if bool(building.buff_line) else "—",
				I18n.t("focus.powered") if bool(building.powered) else I18n.t("focus.paralyzed"),
			]
		ItemDefs.CATEGORY_ENERGY:
			names = ENERGY_STATS
			values = [
				"+%d" % int(building.energy_output),
				"%d/%d" % [int(ceil(float(building.hp))), int(building.max_hp)],
				"+%d" % (int(building.energy_output) - int(building.energy_demand)),
				I18n.t("focus.powered") if bool(building.powered) else I18n.t("focus.paralyzed"),
			]

	for i in stat_cells.size():
		var used := i < names.size()
		stat_cells[i].visible = used
		if used:
			stat_names[i].text = I18n.t(String(names[i]))
			stat_values[i].text = String(values[i])
			stat_values[i].add_theme_color_override("font_color", Palette.DANGER if values[i] == I18n.t("focus.paralyzed") else Palette.INK)

	power_label.text = _power_text()
	power_label.add_theme_color_override("font_color", Palette.DANGER if not building.powered else Palette.INK_MUTED)

	for button in upgrade_buttons:
		button.disabled = int(game.coins) < int(button.get_meta("cost", 0))
	dismantle_button.text = I18n.t("focus.dismantle", [building.get_refund()])


func _on_locale_changed(_locale: String) -> void:
	if visible:
		_refresh_texts()
		_layout()
		queue_redraw()


func _on_close() -> void:
	game.clear_selection()


func _on_upgrade_to(target_id: String) -> void:
	game.upgrade_selected_to(target_id)


func _on_dismantle() -> void:
	game.dismantle_selected()
