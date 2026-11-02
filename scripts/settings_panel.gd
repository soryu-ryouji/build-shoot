extends Control

## 主界面与游戏内共用的设置面板。游戏内由 Main 负责暂停和恢复场景。

signal closed
signal restart_requested
signal menu_requested

const Palette = preload("res://scripts/palette.gd")
const ORIGIN := Vector2(140, 160)
const PANEL_SIZE := Vector2(440, 640)
const OPTION_LABELS := {
	"fullscreen": "settings.fullscreen",
	"animate_monsters": "settings.monster_animation",
	"show_grid": "settings.show_grid",
	"show_aim": "settings.show_aim",
}

var in_game := false
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
	_refresh_texts()


func _build() -> void:
	title_label = _make_label(ORIGIN + Vector2(28, 24), Vector2(330, 42), 30, Palette.INK)
	subtitle_label = _make_label(ORIGIN + Vector2(30, 68), Vector2(350, 22), 11, Palette.INK_MUTED)

	close_button = _make_button(ORIGIN + Vector2(380, 24), Vector2(34, 34), false)
	close_button.text = "×"
	close_button.pressed.connect(close_panel)

	var index := 0
	for option in OPTION_LABELS:
		var button := _make_button(ORIGIN + Vector2(28, 132 + index * 52), Vector2(384, 42), false)
		button.toggle_mode = true
		button.toggled.connect(_on_option_toggled.bind(option))
		option_buttons[option] = button
		index += 1

	language_button = _make_button(ORIGIN + Vector2(28, 348), Vector2(384, 46), false)
	language_button.pressed.connect(_on_language_pressed)

	saved_label = _make_label(ORIGIN + Vector2(30, 404), Vector2(380, 24), 10, Palette.INK_MUTED)

	resume_button = _make_button(ORIGIN + Vector2(28, 458), Vector2(384, 48), true)
	resume_button.pressed.connect(close_panel)
	restart_button = _make_button(ORIGIN + Vector2(28, 516), Vector2(184, 44), false)
	restart_button.pressed.connect(_on_restart)
	menu_button = _make_button(ORIGIN + Vector2(228, 516), Vector2(184, 44), false)
	menu_button.pressed.connect(_on_menu)


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


func _make_button(pos: Vector2, button_size: Vector2, primary: bool) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Palette.INK)
	button.add_theme_color_override("font_hover_color", Palette.INK)
	button.add_theme_color_override("font_pressed_color", Palette.INK)
	var border := Palette.ACCENT if primary else Color(0.20, 0.23, 0.24, 0.28)
	var fill := Color(Palette.ACCENT, 0.95) if primary else Color(1.0, 1.0, 0.98, 0.58)
	button.add_theme_stylebox_override("normal", _button_style(fill, border, primary))
	button.add_theme_stylebox_override("hover", _button_style(Color(1.0, 0.94, 0.80, 0.95), Palette.ACCENT, true))
	button.add_theme_stylebox_override("pressed", _button_style(Palette.ACCENT, Palette.ACCENT, true))
	add_child(button)
	return button


func _button_style(fill: Color, border: Color, accent: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.border_width_left = 4 if accent else 1
	style.content_margin_left = 16
	style.content_margin_right = 16
	return style


func open_panel(as_game: bool) -> void:
	in_game = as_game
	resume_button.visible = in_game
	restart_button.visible = in_game
	menu_button.visible = in_game
	visible = true
	_refresh_texts()
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
	queue_redraw()


func _on_locale_changed(_locale: String) -> void:
	_refresh_texts()


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
	var cut := 18.0
	var p := ORIGIN
	var s := PANEL_SIZE if in_game else Vector2(440, 470)
	var polygon := PackedVector2Array([
		p + Vector2(0, 0), p + Vector2(s.x - cut, 0), p + Vector2(s.x, cut),
		p + Vector2(s.x, s.y), p + Vector2(cut, s.y), p + Vector2(0, s.y - cut),
	])
	draw_colored_polygon(polygon, Color(Palette.PAPER, 0.98))
	var outline := polygon.duplicate()
	outline.append(polygon[0])
	draw_polyline(outline, Color(1.0, 1.0, 0.98, 0.80), 1.0, true)
	draw_rect(Rect2(p + Vector2(0, 24), Vector2(5, 66)), Palette.ACCENT)
	draw_line(p + Vector2(28, 108), p + Vector2(s.x - 28, 108), Color(0.10, 0.12, 0.13, 0.16), 1.0)
	if in_game:
		draw_line(p + Vector2(28, 438), p + Vector2(s.x - 28, 438), Color(0.10, 0.12, 0.13, 0.12), 1.0)
