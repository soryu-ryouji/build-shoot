extends Control

## 可编辑预置体：scenes/ui/hud.tscn。资源数值通过 Events + EventBinding 更新。

signal settings_requested

const Palette = preload("res://scripts/palette.gd")
const ResponsiveLayout = preload("res://scripts/responsive_layout.gd")
const UiMetrics = preload("res://scripts/ui_metrics.gd")
const EventBindingScript = preload("res://scripts/event_binding.gd")

var game: Node
@onready var top_panel: PanelContainer = %TopPanel
@onready var coins_label: Label = %CoinsLabel
@onready var energy_label: Label = %EnergyLabel
@onready var toast_label: Label = %ToastLabel
@onready var settings_button: Button = %SettingsButton

var _toast_time := 0.0
var _coin_pop := 0.0
var _message_style: StyleBoxFlat
var _events := EventBindingScript.new()


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _message_style = _style(Color(Palette.PAPER, 0.96), Palette.ACCENT, false)
    top_panel.add_theme_stylebox_override("panel", _style(Color(Palette.PAPER, 0.94), Palette.ACCENT, false))
    settings_button.add_theme_color_override("font_color", Palette.INK)
    settings_button.add_theme_color_override("font_hover_color", Palette.ACCENT)
    settings_button.add_theme_stylebox_override("normal", _button_style(Color(Palette.INK, 0.06)))
    settings_button.add_theme_stylebox_override("hover", _button_style(Color(Palette.ACCENT, 0.16)))
    settings_button.add_theme_stylebox_override("pressed", _button_style(Color(Palette.ACCENT, 0.28)))
    settings_button.tooltip_text = I18n.t("settings.open")

    _events.bind(Events.coins_changed, _on_coins_changed)
    _events.bind(Events.power_changed, _on_power_changed)
    _events.bind(Events.language_changed, _on_language_changed)
    _events.bind(Events.toast_requested, toast)
    get_viewport().size_changed.connect(_layout)
    _on_coins_changed(Events.coins, Events.coins)
    _on_power_changed(Events.power_demand, Events.power_supply, Events.power_offline)
    _layout()


func _exit_tree() -> void:
    _events.clear()


func _on_settings_pressed() -> void:
    settings_requested.emit()


func _on_coins_changed(current: int, previous: int) -> void:
    coins_label.text = I18n.t("hud.coins", [current])
    if current > previous:
        _coin_pop = 1.0


func _on_power_changed(demand: int, supply: int, offline: int) -> void:
    if offline > 0:
        energy_label.text = I18n.t("hud.energy_offline", [demand, supply, offline])
        energy_label.add_theme_color_override("font_color", Palette.DANGER)
    else:
        energy_label.text = I18n.t("hud.energy", [demand, supply])
        energy_label.add_theme_color_override("font_color", Palette.INK)


func _on_language_changed(_locale: String) -> void:
    settings_button.tooltip_text = I18n.t("settings.open")
    _on_coins_changed(Events.coins, Events.coins)
    _on_power_changed(Events.power_demand, Events.power_supply, Events.power_offline)


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
    var rect := ResponsiveLayout.hud_rect(self)
    var field := ResponsiveLayout.field_rect(self)
    top_panel.position = rect.position
    top_panel.size = rect.size
    var message_width := minf(420.0, field.size.x - 48.0)
    toast_label.size = Vector2(message_width, UiMetrics.TOAST_HEIGHT)
    toast_label.position = Vector2(field.position.x + (field.size.x - message_width) * 0.5, field.position.y + 12.0)
    queue_redraw()


## 仅驱动短时提示和金币动画，不读取游戏数值。
func _process(delta: float) -> void:
    if _coin_pop > 0.0:
        _coin_pop = maxf(0.0, _coin_pop - delta * 4.0)
        coins_label.pivot_offset = coins_label.size * 0.5
        coins_label.scale = Vector2.ONE * (1.0 + 0.10 * _coin_pop)
    else:
        coins_label.scale = Vector2.ONE
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
    _draw_nest_indicators()


func _draw_nest_indicators() -> void:
    if game == null or game.nests == null:
        return
    var field := ResponsiveLayout.field_rect(self).grow(-24.0)
    var center := field.get_center()
    for nest in game.nests:
        if not is_instance_valid(nest) or not nest.alive:
            continue
        var screen: Vector2 = game.world_to_screen(nest.global_position)
        if field.has_point(screen):
            continue
        var point := Vector2(clampf(screen.x, field.position.x, field.end.x), clampf(screen.y, field.position.y, field.end.y))
        var direction := (screen - center).normalized()
        var side := direction.orthogonal()
        var points := PackedVector2Array([point + direction * 12.0, point - direction * 8.0 + side * 7.0, point - direction * 8.0 - side * 7.0])
        draw_colored_polygon(points, Color(Palette.PINK, 0.88))
        draw_circle(point - direction * 14.0, 3.0, Color(Palette.PAPER, 0.9))
