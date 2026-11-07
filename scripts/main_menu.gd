extends Control

## 主菜单场景树位于 scenes/main_menu.tscn；语言由 Events 驱动。

const Palette = preload("res://scripts/palette.gd")
const ResponsiveLayout = preload("res://scripts/responsive_layout.gd")
const EventBindingScript = preload("res://scripts/event_binding.gd")
const MENU_CHARACTER_RIGHT := 659.0 / 720.0

@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var continue_button: Button = %ContinueButton
@onready var delete_save_button: Button = %DeleteSaveButton
@onready var settings_panel: Control = %SettingsPanel
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var mode_label: Label = %ModeLabel
@onready var title_box: VBoxContainer = %TitleBox
@onready var actions_box: VBoxContainer = %ActionsBox
@onready var background: TextureRect = %Background
@onready var menu_shade: ColorRect = %MenuShade
@onready var character: Control = %Character
@onready var accent_bar: ColorRect = %AccentBar
@onready var title_rule: ColorRect = %TitleRule
@onready var actions_rule: ColorRect = %ActionsRule
var _events := EventBindingScript.new()
var _delete_armed := false
var _delete_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_menu_button(start_button, true)
	_style_menu_button(settings_button, false)
	_style_menu_button(quit_button, false)
	_style_menu_button(continue_button, true)
	_style_menu_button(delete_save_button, false)
	_events.bind(Events.language_changed, _on_language_changed)
	_events.bind(SaveManager.save_changed, _on_save_changed)
	get_viewport().size_changed.connect(_layout)
	_refresh_texts()
	_layout()
	Music.play_track("menu")


func _exit_tree() -> void:
	_events.clear()


func _on_language_changed(_locale: String) -> void:
	_refresh_texts()


func _style_menu_button(button: Button, primary: bool) -> void:
	button.add_theme_color_override("font_color", Palette.INK)
	button.add_theme_color_override("font_hover_color", Palette.INK)
	button.add_theme_color_override("font_pressed_color", Palette.INK)
	var border := Palette.ACCENT if primary else Color(0.20, 0.23, 0.24, 0.25)
	var fill_alpha := 0.97 if primary else 0.93
	button.add_theme_stylebox_override("normal", _style(Color(Palette.PAPER, fill_alpha), border, primary))
	button.add_theme_stylebox_override("hover", _style(Color(1.0, 0.94, 0.80, 0.98), Palette.ACCENT, true))
	button.add_theme_stylebox_override("pressed", _style(Palette.ACCENT.darkened(0.15), Palette.ACCENT, true))


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
	_layout_character()
	var safe := ResponsiveLayout.safe_rect(self)
	var margin := ResponsiveLayout.margin(self)
	var width := minf(400.0, safe.size.x * 0.44)
	title_box.position = safe.position + Vector2(margin + 10.0, margin + 12.0)
	title_box.size = Vector2(width, 120)
	actions_box.reset_size()
	var actions_height := actions_box.get_combined_minimum_size().y
	var actions_width := minf(360.0, safe.size.x * 0.40)
	actions_box.size = Vector2(actions_width, actions_height)
	actions_box.position = Vector2(
		safe.position.x + margin + 10.0,
		safe.end.y - margin - actions_height - 12.0,
	)
	accent_bar.position = title_box.position + Vector2(-8, 4)
	title_rule.position = title_box.position + Vector2(0, 104)
	actions_rule.position = actions_box.position + Vector2(0, -16)
	queue_redraw()

func _layout_character() -> void:
	var view := size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	# 横屏不再沿用背景 cover 的放大比例，人物完整落在右侧操作安全区之外。
	var character_scale := view.y / 960.0 * 1.08
	var drawn := Vector2(720.0, 960.0) * character_scale
	var origin := Vector2(
		view.x - MENU_CHARACTER_RIGHT * drawn.x - 30.0,
		view.y - drawn.y + 30.0,
	)
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
	var available := SaveManager.has_save()
	continue_button.visible = available
	delete_save_button.visible = available
	continue_button.text = I18n.t("menu.continue")
	if not available:
		_delete_armed = false
	delete_save_button.text = I18n.t("menu.delete_confirm") if _delete_armed else I18n.t("menu.delete_save")


func start_game() -> void:
	SaveManager.load_requested = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func continue_game() -> void:
	SaveManager.load_requested = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_save_changed() -> void:
	_delete_armed = false
	_refresh_texts()


func _on_delete_save() -> void:
	if not _delete_armed:
		_delete_armed = true
		_delete_time = 3.0
		delete_save_button.text = I18n.t("menu.delete_confirm")
		return
	SaveManager.delete_save()
	_refresh_texts()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func open_settings() -> void:
	settings_panel.open_panel(false)


func _on_quit() -> void:
	get_tree().quit()


func _process(delta: float) -> void:
	if not _delete_armed:
		return
	_delete_time -= delta
	if _delete_time <= 0.0:
		_delete_armed = false
		delete_save_button.text = I18n.t("menu.delete_save")
