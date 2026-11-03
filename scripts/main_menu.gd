extends Control

## 自适应主界面：背景等比覆盖，标题在左上，操作按钮落在底部拇指区。

const Palette = preload("res://scripts/palette.gd")
const BattleMap = preload("res://scripts/battle_map.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const ResponsiveLayout = preload("res://scripts/responsive_layout.gd")
const UiMetrics = preload("res://scripts/ui_metrics.gd")
const MenuTexture = preload("res://assets/ui/menu_background.png")
const MenuCharacterRig = preload("res://scripts/menu_character_rig.gd")
# 立绘右边缘在设计稿中的位置（720x960），用于在更长的屏幕上把人整体挪回画面内
const MENU_CHARACTER_RIGHT := 659.0 / 720.0

var start_button: Button
var settings_button: Button
var quit_button: Button
var settings_panel: Control
var map_group: ButtonGroup
var map_buttons: Array = []
var title_label: Label
var subtitle_label: Label
var mode_label: Label
var title_box: VBoxContainer
var actions_box: VBoxContainer
var background: TextureRect
var character: Control
var accent_bar: ColorRect
var title_rule: ColorRect
var actions_rule: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	I18n.locale_changed.connect(_refresh_texts)
	GameSettings.changed.connect(_refresh_texts)
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

	# 人物按背景的 cover 尺寸摆放，由 rig 自己驱动分层待机
	character = MenuCharacterRig.new()
	add_child(character)

	# 装饰线单独成节点，画在背景与立绘之上
	accent_bar = _make_rule(Vector2(4, 84))
	title_rule = _make_rule(Vector2(172, 2))
	actions_rule = _make_rule(Vector2(124, 2))

	title_box = VBoxContainer.new()
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_theme_constant_override("separation", 2)
	add_child(title_box)
	title_label = _make_label(title_box, UiMetrics.FONT_DISPLAY, Palette.INK)
	subtitle_label = _make_label(title_box, UiMetrics.FONT_BODY, Palette.INK_MUTED)

	actions_box = VBoxContainer.new()
	actions_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions_box.add_theme_constant_override("separation", 10)
	add_child(actions_box)
	mode_label = _make_label(actions_box, UiMetrics.FONT_SMALL, Palette.INK)

	# 地图选择：三张一体式地图，点一下切换，选择写进设置
	var map_row := HBoxContainer.new()
	map_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_row.add_theme_constant_override("separation", 6)
	actions_box.add_child(map_row)
	map_group = ButtonGroup.new()
	for index in BattleMap.map_count():
		var map_button := _make_button(map_row, UiMetrics.FONT_SMALL, false)
		map_button.toggle_mode = true
		map_button.button_group = map_group
		map_button.custom_minimum_size.y = 50
		map_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		map_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		map_button.pressed.connect(_on_map_pressed.bind(index))
		map_buttons.append(map_button)

	start_button = _make_button(actions_box, 21, true)
	start_button.custom_minimum_size.y = 62
	start_button.pressed.connect(start_game)

	var secondary := HBoxContainer.new()
	secondary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	secondary.add_theme_constant_override("separation", UiMetrics.GAP)
	actions_box.add_child(secondary)
	settings_button = _make_button(secondary, UiMetrics.FONT_LABEL, false)
	settings_button.custom_minimum_size.y = 56
	settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_button.pressed.connect(open_settings)
	quit_button = _make_button(secondary, UiMetrics.FONT_LABEL, false)
	quit_button.custom_minimum_size = Vector2(100, 56)
	quit_button.pressed.connect(_on_quit)

	settings_panel = SettingsPanel.new()
	settings_panel.name = "SettingsPanel"
	add_child(settings_panel)


func _make_rule(rule_size: Vector2) -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Palette.ACCENT
	rule.custom_minimum_size = rule_size
	rule.size = rule_size
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	return rule


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
	var fill_alpha := 0.97 if primary else 0.93
	button.add_theme_stylebox_override("normal", _style(Color(Palette.PAPER, fill_alpha), border, primary))
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
	var width := minf(330.0, safe.size.x - margin * 2.0)
	title_box.position = safe.position + Vector2(margin, margin + 8.0)
	title_box.size = Vector2(width, 120)

	actions_box.reset_size()
	var actions_height := actions_box.get_combined_minimum_size().y
	actions_box.size = Vector2(width, actions_height)
	# 主菜单按钮贴近底部拇指区，长屏手机上也不用伸到屏幕上半部
	actions_box.position = Vector2(
		safe.position.x + margin,
		safe.end.y - margin - actions_height - 28.0,
	)

	accent_bar.position = title_box.position + Vector2(-8, 4)
	title_rule.position = title_box.position + Vector2(0, 104)
	actions_rule.position = actions_box.position + Vector2(0, -16)
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
	var selected := clampi(int(GameSettings.map_index), 0, maxi(map_buttons.size() - 1, 0))
	for index in map_buttons.size():
		var button: Button = map_buttons[index]
		button.text = I18n.t(String(BattleMap.MAPS[index].name_key))
		button.set_pressed_no_signal(index == selected)


func _on_map_pressed(index: int) -> void:
	GameSettings.set_map_index(index)
	_refresh_texts()


func start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func open_settings() -> void:
	settings_panel.open_panel(false)


func _on_quit() -> void:
	get_tree().quit()
