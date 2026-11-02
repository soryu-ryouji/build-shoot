extends Control

## 自适应主界面：背景等比覆盖，标题与操作容器随安全区域布局。

const Palette = preload("res://scripts/palette.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const ResponsiveLayout = preload("res://scripts/responsive_layout.gd")
const MenuTexture = preload("res://assets/ui/menu_background.png")
const MenuCharacterTexture = preload("res://assets/ui/menu_character.png")
const MenuCharacterShader = preload("res://shaders/menu_character.gdshader")
# 立绘右边缘在设计稿中的位置（720x960），用于在更长的屏幕上把人整体挪回画面内
const MENU_CHARACTER_RIGHT := 659.0 / 720.0

var start_button: Button
var settings_button: Button
var quit_button: Button
var settings_panel: Control
var title_label: Label
var subtitle_label: Label
var mode_label: Label
var title_box: VBoxContainer
var actions_box: VBoxContainer
var background: TextureRect
var character: TextureRect
var character_material: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	I18n.locale_changed.connect(_refresh_texts)
	get_viewport().size_changed.connect(_layout)
	_refresh_texts()
	_layout()


func _build() -> void:
	background = TextureRect.new()
	background.texture = MenuTexture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# 人物单独一层，尺寸跟背景的 cover 缩放一致，着色器负责待机动效
	character = TextureRect.new()
	character.texture = MenuCharacterTexture
	character.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	character.stretch_mode = TextureRect.STRETCH_SCALE
	character.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character.set_anchors_preset(Control.PRESET_TOP_LEFT)
	character_material = ShaderMaterial.new()
	character_material.shader = MenuCharacterShader
	character.material = character_material
	add_child(character)

	title_box = VBoxContainer.new()
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_theme_constant_override("separation", 2)
	add_child(title_box)
	title_label = _make_label(title_box, 44, Palette.INK)
	subtitle_label = _make_label(title_box, 14, Palette.INK_MUTED)

	actions_box = VBoxContainer.new()
	actions_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions_box.add_theme_constant_override("separation", 14)
	add_child(actions_box)
	mode_label = _make_label(actions_box, 13, Palette.INK)
	start_button = _make_button(actions_box, 18, true)
	start_button.custom_minimum_size.y = 62
	start_button.pressed.connect(start_game)

	var secondary := HBoxContainer.new()
	secondary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	secondary.add_theme_constant_override("separation", 10)
	actions_box.add_child(secondary)
	settings_button = _make_button(secondary, 14, false)
	settings_button.custom_minimum_size.y = 50
	settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_button.pressed.connect(open_settings)
	quit_button = _make_button(secondary, 14, false)
	quit_button.custom_minimum_size = Vector2(92, 50)
	quit_button.pressed.connect(_on_quit)

	settings_panel = SettingsPanel.new()
	settings_panel.name = "SettingsPanel"
	add_child(settings_panel)


func _make_label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _make_button(parent: Node, font_size: int, primary: bool) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Palette.INK)
	button.add_theme_color_override("font_hover_color", Palette.INK)
	button.add_theme_color_override("font_pressed_color", Palette.INK)
	var border := Palette.ACCENT if primary else Color(0.20, 0.23, 0.24, 0.25)
	button.add_theme_stylebox_override("normal", _style(Color(Palette.PAPER, 0.94), border, primary))
	button.add_theme_stylebox_override("hover", _style(Color(1.0, 0.94, 0.80, 0.98), Palette.ACCENT, true))
	button.add_theme_stylebox_override("pressed", _style(Palette.ACCENT.darkened(0.15), Palette.ACCENT, true))
	parent.add_child(button)
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


func _layout() -> void:
	background.texture = MenuTexture
	_layout_character()
	var safe := ResponsiveLayout.safe_rect(self)
	var margin := ResponsiveLayout.margin(self)
	var width := minf(clampf(safe.size.x * 0.46, 260.0, 360.0), safe.size.x - margin * 2.0)
	title_box.position = safe.position + Vector2(margin, margin * 2.0)
	title_box.size = Vector2(width, 142)
	actions_box.size = Vector2(width, 164)
	# 功能菜单位于左侧中部，避免长屏设备上落到拇指难以触及的底部。
	actions_box.position = Vector2(safe.position.x + margin, safe.position.y + safe.size.y * 0.46)
	queue_redraw()


func _layout_character() -> void:
	var view := size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	# 人物层固定按设计稿比例缩放，和背景 cover 映射重合；长屏时整体左移，避免右侧被裁
	var cover := maxf(view.x / 720.0, view.y / 960.0)
	var drawn := Vector2(720.0, 960.0) * cover
	var origin := (view - drawn) * 0.5
	var right := origin.x + MENU_CHARACTER_RIGHT * drawn.x
	origin.x -= maxf(0.0, right - (view.x - 14.0))
	character.size = drawn
	character.position = origin


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
	if title_box != null:
		var p := title_box.position
		draw_rect(Rect2(p + Vector2(-14, 4), Vector2(4, 92)), Palette.ACCENT)
		draw_line(p + Vector2(0, 116), p + Vector2(172, 116), Palette.ACCENT, 2.0)
	if actions_box != null:
		var p := actions_box.position
		draw_line(p + Vector2(0, -18), p + Vector2(124, -18), Palette.ACCENT, 2.0)
