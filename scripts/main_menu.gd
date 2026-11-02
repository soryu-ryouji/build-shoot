extends Control

## 原创角色与白色战术面板主界面：开始、设置、退出。

const Palette = preload("res://scripts/palette.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const MenuTexture = preload("res://assets/ui/menu_background.png")

var start_button: Button
var settings_button: Button
var quit_button: Button
var settings_panel: Control
var title_label: Label
var subtitle_label: Label
var mode_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	I18n.locale_changed.connect(_refresh_texts)
	_refresh_texts()


func _build() -> void:
	title_label = _make_label(Vector2(52, 68), Vector2(300, 64), 44, Palette.INK)
	subtitle_label = _make_label(Vector2(56, 136), Vector2(300, 28), 14, Palette.INK_MUTED)
	mode_label = _make_label(Vector2(52, 534), Vector2(360, 26), 13, Palette.INK)

	start_button = _make_button(Vector2(48, 592), Vector2(320, 64), 18, true)
	start_button.pressed.connect(start_game)
	settings_button = _make_button(Vector2(48, 672), Vector2(220, 52), 14, false)
	settings_button.pressed.connect(open_settings)
	quit_button = _make_button(Vector2(268, 672), Vector2(100, 52), 14, false)
	quit_button.pressed.connect(_on_quit)

	settings_panel = SettingsPanel.new()
	settings_panel.name = "SettingsPanel"
	add_child(settings_panel)


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


func _make_button(pos: Vector2, button_size: Vector2, font_size: int, primary: bool) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Palette.INK)
	button.add_theme_color_override("font_hover_color", Palette.INK)
	button.add_theme_color_override("font_pressed_color", Palette.INK)
	var border := Palette.ACCENT if primary else Color(0.20, 0.23, 0.24, 0.25)
	var fill := Color(Palette.PAPER, 0.94) if primary else Color(Palette.PAPER, 0.88)
	button.add_theme_stylebox_override("normal", _style(fill, border, primary))
	button.add_theme_stylebox_override("hover", _style(Color(1.0, 0.94, 0.80, 0.98), Palette.ACCENT, true))
	button.add_theme_stylebox_override("pressed", _style(Palette.ACCENT.darkened(0.15), Palette.ACCENT, true))
	add_child(button)
	return button


func _style(fill: Color, border: Color, accent: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.border_width_left = 5 if accent else 1
	style.content_margin_left = 20
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.16)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


func _refresh_texts() -> void:
	if title_label == null:
		return
	title_label.text = I18n.t("menu.title")
	subtitle_label.text = I18n.t("menu.subtitle")
	mode_label.text = I18n.t("menu.mode")
	start_button.text = I18n.t("menu.start")
	settings_button.text = I18n.t("menu.settings")
	quit_button.text = I18n.t("menu.quit")


func start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func open_settings() -> void:
	settings_panel.open_panel(false)


func _on_quit() -> void:
	get_tree().quit()


func _draw() -> void:
	draw_texture_rect(MenuTexture, Rect2(0, 0, 720, 960), false, Color.WHITE)

	# 装饰只服务于标题与操作分区，不再给非交互内容套大面积白底。
	draw_rect(Rect2(38, 76, 4, 88), Palette.ACCENT)
	draw_line(Vector2(52, 180), Vector2(224, 180), Palette.ACCENT, 2.0)
	draw_line(Vector2(52, 522), Vector2(176, 522), Palette.ACCENT, 2.0)
	draw_line(Vector2(48, 756), Vector2(368, 756), Color(0.10, 0.12, 0.13, 0.22), 1.0)
