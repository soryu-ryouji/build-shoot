extends Control

## 自适应设置面板：内容驱动尺寸，主界面隐藏游戏操作，游戏内由 Main 暂停。

signal closed
signal restart_requested
signal menu_requested

const Palette = preload("res://scripts/palette.gd")
const ResponsiveLayout = preload("res://scripts/responsive_layout.gd")
const UiMetrics = preload("res://scripts/ui_metrics.gd")
const OPTION_LABELS := {
	"fullscreen": "settings.fullscreen",
	"animate_monsters": "settings.monster_animation",
	"show_grid": "settings.show_grid",
	"show_aim": "settings.show_aim",
}

var in_game := false
var panel: PanelContainer
var game_actions: VBoxContainer
var title_label: Label
var subtitle_label: Label
var saved_label: Label
var language_button: Button
var close_button: Button
var resume_button: Button
var restart_button: Button
var menu_button: Button
var option_buttons := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	I18n.locale_changed.connect(_on_locale_changed)
	GameSettings.changed.connect(_refresh_texts)
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
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	header.add_child(titles)
	title_label = _make_label(titles, 26, Palette.INK)
	subtitle_label = _make_label(titles, UiMetrics.FONT_MICRO, Palette.INK_MUTED)
	close_button = _make_button(header, false)
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(50, 50)
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_button.pressed.connect(close_panel)

	for option in OPTION_LABELS:
		var button := _make_button(column, false)
		button.toggle_mode = true
		button.custom_minimum_size.y = 56
		button.toggled.connect(_on_option_toggled.bind(option))
		option_buttons[option] = button

	language_button = _make_button(column, false)
	language_button.custom_minimum_size.y = 56
	language_button.pressed.connect(_on_language_pressed)
	saved_label = _make_label(column, UiMetrics.FONT_MICRO, Palette.INK_MUTED)

	game_actions = VBoxContainer.new()
	game_actions.add_theme_constant_override("separation", 8)
	column.add_child(game_actions)
	resume_button = _make_button(game_actions, true)
	resume_button.custom_minimum_size.y = 60
	resume_button.add_theme_font_size_override("font_size", UiMetrics.FONT_LABEL)
	resume_button.pressed.connect(close_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	game_actions.add_child(row)
	restart_button = _make_button(row, false)
	restart_button.custom_minimum_size.y = 54
	restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_button.pressed.connect(_on_restart)
	menu_button = _make_button(row, false)
	menu_button.custom_minimum_size.y = 54
	menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 16)
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
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	style.shadow_size = 10
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
	var target := Vector2(minf(376.0, available), minf(minimum.y, safe.size.y - margin * 2.0))
	target.x = maxf(target.x, minf(minimum.x, available))
	panel.size = target
	panel.position = safe.position + (safe.size - target) * 0.5


func open_panel(as_game: bool) -> void:
	in_game = as_game
	game_actions.visible = in_game
	visible = true
	_refresh_texts()
	_layout()
	move_to_front()


func close_panel() -> void:
	visible = false
	closed.emit()


func _refresh_texts() -> void:
	if title_label == null:
		return
	title_label.text = I18n.t("settings.title")
	subtitle_label.text = I18n.t("settings.subtitle")
	saved_label.text = I18n.t("settings.saved")
	language_button.text = "%s    /    %s" % [I18n.t("settings.language"), I18n.t("settings.language_name")]
	for option in option_buttons:
		var button: Button = option_buttons[option]
		var enabled := bool(GameSettings.get(option))
		button.set_pressed_no_signal(enabled)
		var state := I18n.t("settings.on") if enabled else I18n.t("settings.off")
		button.text = "%s    /    %s" % [I18n.t(OPTION_LABELS[option]), state]
	resume_button.text = I18n.t("settings.resume")
	restart_button.text = I18n.t("settings.restart")
	menu_button.text = I18n.t("settings.main_menu")


func _on_locale_changed(_locale: String) -> void:
	_refresh_texts()
	_layout()


func _on_option_toggled(pressed: bool, option: String) -> void:
	GameSettings.set_option(option, pressed)
	_refresh_texts()


func _on_language_pressed() -> void:
	I18n.toggle_locale()
	GameSettings.save_settings()


func _on_restart() -> void:
	close_panel()
	restart_requested.emit()


func _on_menu() -> void:
	close_panel()
	menu_requested.emit()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_panel()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.12, 0.13, 0.48))
