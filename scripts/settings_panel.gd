extends Control

## 可编辑设置预置体。设置和语言通过 Events 响应，按钮只发送用户操作。

signal closed
signal restart_requested
signal menu_requested
signal save_requested

const Palette = preload("res://scripts/palette.gd")
const ResponsiveLayout = preload("res://scripts/responsive_layout.gd")
const EventBindingScript = preload("res://scripts/event_binding.gd")
const OPTION_LABELS := {
    "fullscreen": "settings.fullscreen",
    "animate_monsters": "settings.monster_animation",
    "show_grid": "settings.show_grid",
    "show_aim": "settings.show_aim",
    "sound_enabled": "settings.sound_enabled",
    "music_enabled": "settings.music_enabled",
}

var in_game := false
@onready var panel: PanelContainer = %Panel
@onready var game_actions: VBoxContainer = %GameActions
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var saved_label: Label = %SavedLabel
@onready var language_button: Button = %LanguageButton
@onready var close_button: Button = %CloseButton
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var save_button: Button = %SaveButton
@onready var menu_button: Button = %MenuButton
var option_buttons := {}
var _events := EventBindingScript.new()


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_STOP
    visible = false
    panel.add_theme_stylebox_override("panel", _panel_style())
    option_buttons = {
        "fullscreen": %FullscreenOption,
        "animate_monsters": %MonsterAnimationOption,
        "show_grid": %ShowGridOption,
        "show_aim": %ShowAimOption,
        "sound_enabled": %SoundOption,
        "music_enabled": %MusicOption,
    }
    for option in option_buttons:
        var button: Button = option_buttons[option]
        if option == "fullscreen" and OS.has_feature("web"):
            button.visible = false
            continue
        _style_button(button, false)
        button.toggled.connect(_on_option_toggled.bind(option))
    for button in [language_button, close_button, save_button, restart_button, menu_button]:
        _style_button(button, false)
    _style_button(resume_button, true)
    _events.bind(Events.setting_changed, _on_setting_changed)
    _events.bind(Events.language_changed, _on_locale_changed)
    get_viewport().size_changed.connect(_layout)
    _refresh_texts()
    _layout()


func _exit_tree() -> void:
    _events.clear()


func _style_button(button: Button, primary: bool) -> void:
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT if button != close_button else HORIZONTAL_ALIGNMENT_CENTER
    button.add_theme_color_override("font_color", Palette.INK)
    button.add_theme_color_override("font_hover_color", Palette.INK)
    button.add_theme_color_override("font_pressed_color", Palette.INK)
    var border := Palette.ACCENT if primary else Color(0.20, 0.23, 0.24, 0.28)
    var fill := Color(Palette.ACCENT, 0.96) if primary else Color(1.0, 1.0, 0.98, 0.62)
    button.add_theme_stylebox_override("normal", _button_style(fill, border, primary))
    button.add_theme_stylebox_override("hover", _button_style(Color(1.0, 0.94, 0.80, 0.95), Palette.ACCENT, true))
    button.add_theme_stylebox_override("pressed", _button_style(Palette.ACCENT, Palette.ACCENT, true))


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


func _on_setting_changed(_option: String, _value: bool) -> void:
    _refresh_texts()


func _layout() -> void:
    if panel == null:
        return
    var safe := ResponsiveLayout.safe_rect(self)
    var margin := ResponsiveLayout.margin(self)
    panel.reset_size()
    var minimum := panel.get_combined_minimum_size()
    var available := safe.size.x - margin * 2.0
    var target := Vector2(minf(680.0, available), minf(minimum.y, safe.size.y - margin * 2.0))
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
    save_button.text = I18n.t("settings.save")
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


func _on_save() -> void:
    save_requested.emit()
