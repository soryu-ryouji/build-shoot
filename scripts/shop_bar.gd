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

var game: Node
var cards: Array = []
var tab_buttons: Dictionary = {}
var active_category := ItemDefs.CATEGORY_FIREPOWER

@onready var item_row: HBoxContainer = %ItemRow
@onready var tab_row: HBoxContainer = %TabRow
var _panel_style: StyleBoxFlat
var _events := EventBindingScript.new()

var _dragging := false
var _drag_id := ""
var _pending := false
var _pending_id := ""
var _pending_pos := Vector2.ZERO


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _panel_style = StyleBoxFlat.new()
    _panel_style.bg_color = Color(Palette.PAPER, 0.95)
    _panel_style.border_color = Color(1.0, 1.0, 0.98, 0.76)
    _panel_style.set_border_width_all(1)
    _panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.20)
    _panel_style.shadow_size = 6
    _panel_style.shadow_offset = Vector2(0, -3)
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
    _events.bind(Events.language_changed, _on_locale_changed)
    get_viewport().size_changed.connect(_layout)
    _layout()


func _exit_tree() -> void:
    _events.clear()


func _tab_style(fill: Color, border: Color, active: bool) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(1)
    style.border_width_bottom = 3 if active else 1
    style.set_corner_radius_all(2)
    return style


func _refresh_tabs() -> void:
    for id in tab_buttons:
        var button: Button = tab_buttons[id]
        button.text = I18n.t(ItemDefs.category_name_key(String(id)))
        button.set_pressed_no_signal(String(id) == active_category)


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
        card.custom_minimum_size = Vector2(168, UiMetrics.SHOP_CARD_HEIGHT)
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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


func _on_locale_changed(_locale: String = "") -> void:
    _refresh_tabs()


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
        drag_moved.emit(event.position)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
        _finish_drag(event.position)
    elif event is InputEventScreenTouch and not event.pressed:
        _finish_drag(event.position)


func _begin_drag(pos: Vector2) -> void:
    _pending = false
    _dragging = true
    _drag_id = _pending_id
    drag_started.emit(_drag_id)
    drag_moved.emit(pos)


func _finish_drag(pos: Vector2) -> void:
    var id := _drag_id
    _dragging = false
    _drag_id = ""
    drag_released.emit(id, pos)
    get_viewport().set_input_as_handled()


func cancel_drag() -> void:
    _dragging = false
    _drag_id = ""
    _pending = false
    _pending_id = ""


func _layout() -> void:
    var rect := ResponsiveLayout.shop_rect(self)
    position = rect.position
    size = rect.size
    queue_redraw()


func _draw() -> void:
    draw_style_box(_panel_style, Rect2(Vector2.ZERO, size))
