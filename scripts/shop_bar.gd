extends Control

## 底部标签式建造栏预置体。道具卡从 ItemCard.tscn 实例化。

const ItemDefs = preload("res://scripts/item_defs.gd")
const ItemCardScene = preload("res://scenes/ui/item_card.tscn")
const Palette = preload("res://scripts/palette.gd")
const ResponsiveLayout = preload("res://scripts/responsive_layout.gd")
const EventBindingScript = preload("res://scripts/event_binding.gd")
const UiMetrics = preload("res://scripts/ui_metrics.gd")

signal drag_started(item_id: String)
signal drag_moved(pos: Vector2)
signal drag_released(item_id: String, pos: Vector2)
signal drag_cancelled

var game: Node
var cards: Array = []
var tab_buttons: Dictionary = {}
var active_category := ItemDefs.CATEGORY_FIREPOWER

@onready var item_row: HBoxContainer = %ItemRow
@onready var tab_row: VBoxContainer = %TabRow
@onready var resource_row: HBoxContainer = %ResourceRow
@onready var coins_label: Label = %CoinsLabel
@onready var energy_label: Label = %EnergyLabel
@onready var drag_preview: Control = %DragPreview
var _panel_style: StyleBoxFlat
var _events := EventBindingScript.new()

var _dragging := false
var _drag_id := ""
var _pending := false
var _pending_id := ""
var _pending_pos := Vector2.ZERO
var _cancel_hover := false


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _panel_style = StyleBoxFlat.new()
    _panel_style.bg_color = Color(Palette.PAPER, 0.95)
    _panel_style.border_color = Color(1.0, 1.0, 0.98, 0.76)
    _panel_style.set_border_width_all(1)
    _panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.20)
    _panel_style.shadow_size = 6
    _panel_style.shadow_offset = Vector2(0, -3)
    var resource_style := StyleBoxFlat.new()
    resource_style.bg_color = Color(Palette.PAPER, 0.72)
    resource_style.border_color = Color(Palette.INK, 0.10)
    resource_style.set_border_width_all(1)
    %CoinsCell.add_theme_stylebox_override("panel", resource_style)
    %EnergyCell.add_theme_stylebox_override("panel", resource_style)
    tab_buttons = {
        ItemDefs.CATEGORY_FIREPOWER: %FirepowerTab,
        ItemDefs.CATEGORY_FORTIFICATION: %FortificationTab,
        ItemDefs.CATEGORY_ENERGY: %EnergyTab,
    }
    for id in tab_buttons:
        var button: Button = tab_buttons[id]
        button.add_theme_color_override("font_color", Palette.INK_MUTED)
        button.add_theme_color_override("font_hover_color", Palette.INK)
        button.add_theme_color_override("font_pressed_color", Palette.INK)
        button.add_theme_stylebox_override("normal", _tab_style(Color(Palette.INK, 0.035), Color(Palette.INK, 0.10), false))
        button.add_theme_stylebox_override("hover", _tab_style(Color(Palette.ACCENT, 0.12), Palette.ACCENT, false))
        button.add_theme_stylebox_override("pressed", _tab_style(Color(Palette.ACCENT, 0.18), Palette.ACCENT, true))
        button.pressed.connect(_on_tab_pressed.bind(String(id)))
    _refresh_items()
    _events.bind(Events.coins_changed, _on_coins_changed)
    _events.bind(Events.power_changed, _on_power_changed)
    _events.bind(Events.language_changed, _on_locale_changed)
    get_viewport().size_changed.connect(_layout)
    _on_coins_changed(Events.coins, Events.coins)
    _on_power_changed(Events.power_demand, Events.power_supply, Events.power_offline)
    _layout()


func _exit_tree() -> void:
    _events.clear()


func _tab_style(fill: Color, border: Color, active: bool) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(1)
    style.border_width_left = 5 if active else 2
    style.corner_radius_top_left = 4
    style.corner_radius_bottom_left = 4
    style.corner_radius_top_right = 0
    style.corner_radius_bottom_right = 0
    style.content_margin_left = 12
    return style


func _refresh_tabs() -> void:
    for id in tab_buttons:
        var button: Button = tab_buttons[id]
        var selected := String(id) == active_category
        button.text = I18n.t(ItemDefs.category_name_key(String(id)))
        button.set_pressed_no_signal(selected)
        button.modulate = Color.WHITE if selected else Color(0.68, 0.71, 0.72, 1.0)
        button.add_theme_color_override("font_color", Palette.INK if selected else Palette.INK_MUTED)


func _refresh_items() -> void:
    cancel_drag()
    for card in cards:
        if is_instance_valid(card):
            item_row.remove_child(card)
            card.queue_free()
    cards.clear()
    for item in ItemDefs.get_category_items(active_category):
        var card = ItemCardScene.instantiate()
        card.game = game
        card.category = active_category
        card.item = item
        card.custom_minimum_size = Vector2(96, UiMetrics.SHOP_CARD_HEIGHT)
        card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
        card.size_flags_vertical = Control.SIZE_EXPAND_FILL
        card.pressed.connect(_on_card_pressed.bind(String(item.id)))
        item_row.add_child(card)
        cards.append(card)
    _refresh_tabs()


func _on_tab_pressed(category: String) -> void:
    if category == active_category:
        return
    active_category = category
    _refresh_items()


func _on_card_pressed(_category: String, pos: Vector2, item_id: String) -> void:
    _pending = true
    _pending_id = item_id
    _pending_pos = pos


func _on_coins_changed(current: int, _previous: int) -> void:
    coins_label.text = I18n.t("hud.coins", [current])


func _on_power_changed(demand: int, supply: int, offline: int) -> void:
    if offline > 0:
        energy_label.text = I18n.t("hud.energy_offline", [demand, supply, offline])
        energy_label.add_theme_color_override("font_color", Palette.DANGER)
    else:
        energy_label.text = I18n.t("hud.energy", [demand, supply])
        energy_label.add_theme_color_override("font_color", Palette.INK)


func _on_locale_changed(_locale: String = "") -> void:
    _refresh_tabs()
    _on_coins_changed(Events.coins, Events.coins)
    _on_power_changed(Events.power_demand, Events.power_supply, Events.power_offline)


func _input(event: InputEvent) -> void:
    if _pending and not _dragging:
        if event is InputEventMouseMotion or event is InputEventScreenDrag:
            if event.position.distance_to(_pending_pos) > 8.0:
                _begin_drag(event.position)
        elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
            _pending = false
        elif event is InputEventScreenTouch and not event.pressed:
            _pending = false
        return

    if not _dragging:
        return
    if event is InputEventMouseMotion or event is InputEventScreenDrag:
        _update_drag_position(event.position)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
        _finish_drag(event.position)
    elif event is InputEventScreenTouch and not event.pressed:
        _finish_drag(event.position)


func set_camera_zoom(value: float) -> void:
    drag_preview.set_camera_zoom(value)


func _begin_drag(pos: Vector2) -> void:
    _pending = false
    _dragging = true
    _drag_id = _pending_id
    drag_preview.show_item(ItemDefs.get_item(_drag_id), pos)
    drag_started.emit(_drag_id)
    drag_moved.emit(pos)


func _update_drag_position(pos: Vector2) -> void:
    var over_ui := is_ui_position(pos)
    _set_cancel_hover(over_ui)
    drag_preview.visible = true
    drag_preview.follow(pos)
    drag_moved.emit(pos)


func _finish_drag(pos: Vector2) -> void:
    var id := _drag_id
    var cancel := _cancel_hover or is_ui_position(pos)
    drag_preview.hide_preview()
    _dragging = false
    _drag_id = ""
    if cancel:
        drag_cancelled.emit()
    else:
        drag_released.emit(id, pos)
    _set_cancel_hover(false)
    get_viewport().set_input_as_handled()


## 道具框与悬浮资源区都算 UI；额外 10px 容差方便触摸操作。
func is_ui_position(pos: Vector2) -> bool:
    if get_global_rect().grow(10.0).has_point(pos):
        return true
    return resource_row.get_global_rect().grow(10.0).has_point(pos)


func _set_cancel_hover(active: bool) -> void:
    if _cancel_hover == active:
        return
    _cancel_hover = active
    _panel_style.border_color = Palette.DANGER if active else Color(1.0, 1.0, 0.98, 0.76)
    _panel_style.border_width_top = 3 if active else 1
    queue_redraw()


func cancel_drag() -> void:
    _dragging = false
    _drag_id = ""
    _pending = false
    _pending_id = ""
    drag_preview.hide_preview()
    _set_cancel_hover(false)


func _layout() -> void:
    var rect := ResponsiveLayout.shop_rect(self)
    position = rect.position
    size = rect.size
    resource_row.reset_size()
    var resource_size := resource_row.get_combined_minimum_size()
    resource_row.size = resource_size
    resource_row.position = Vector2(size.x - resource_size.x, -resource_size.y - 6.0)
    queue_redraw()


func _draw() -> void:
    draw_style_box(_panel_style, Rect2(Vector2.ZERO, size))
