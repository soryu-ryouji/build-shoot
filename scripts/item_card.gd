extends Control

## 可编辑道具卡预置体。价格可负担状态由 Events.coins_changed 驱动。

const Palette = preload("res://scripts/palette.gd")
const ItemDefs = preload("res://scripts/item_defs.gd")
const EventBindingScript = preload("res://scripts/event_binding.gd")

signal pressed(category: String, pos: Vector2)

var game: Node
var item: Dictionary = {}
var category := ""
var active := false

@onready var category_label: Label = %CategoryLabel
@onready var name_label: Label = %NameLabel
@onready var cost_label: Label = %CostLabel

var _can_buy := false
var _unlocked := true
var _hovered := false
var _style: StyleBoxFlat
var _icon_texture: Texture2D
var _compact := false
var _events := EventBindingScript.new()


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    resized.connect(_layout)
    _style = StyleBoxFlat.new()
    _style.bg_color = Color(Palette.PAPER, 0.98)
    _style.set_border_width_all(1)
    _style.set_corner_radius_all(2)
    _load_icon()
    _refresh_texts()
    _refresh_state(Events.coins)
    _events.bind(Events.coins_changed, _on_coins_changed)
    _events.bind(Events.language_changed, _on_locale_changed)
    _events.bind(Events.research_changed, _on_research_changed)
    _layout()


func _exit_tree() -> void:
    _events.clear()


func _on_coins_changed(current: int, _previous: int) -> void:
    _refresh_state(current)


func _refresh_state(current_coins: int) -> void:
    if item.is_empty():
        return
    var research := ItemDefs.get_research_cost(String(item.id))
    _unlocked = research <= 0 or bool(Events.unlocked_items.get(String(item.id), false))
    _can_buy = _unlocked and current_coins >= int(item.cost)
    var affordable := current_coins >= (int(item.cost) if _unlocked else research)
    cost_label.add_theme_color_override("font_color", Palette.ACCENT if affordable else Palette.DANGER)
    _refresh_texts()
    queue_redraw()


func _on_research_changed(item_id: String, _unlocked_value: bool) -> void:
    if not item.is_empty() and item_id == String(item.id):
        _refresh_state(Events.coins)


func _load_icon() -> void:
    _icon_texture = null
    var icon_path := String(item.get("icon", ""))
    if not icon_path.is_empty():
        _icon_texture = load(icon_path)


func set_item(new_item: Dictionary) -> void:
    item = new_item
    _load_icon()
    _refresh_texts()
    _refresh_state(Events.coins)
    queue_redraw()


func set_active(value: bool) -> void:
    active = value
    queue_redraw()


func _layout() -> void:
    if name_label == null:
        return
    var compact_now := size.x < 150.0
    var compact_changed := compact_now != _compact
    _compact = compact_now
    if _compact:
        var width := maxf(48.0, size.x - 12.0)
        category_label.position = Vector2(6, 4)
        category_label.size = Vector2(width, 16)
        category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        category_label.add_theme_font_size_override("font_size", 10)
        name_label.position = Vector2(6, 64)
        name_label.size = Vector2(width, 34)
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_label.add_theme_font_size_override("font_size", 13)
        name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        name_label.max_lines_visible = 2
        cost_label.position = Vector2(6, maxf(100.0, size.y - 24.0))
        cost_label.size = Vector2(width, 20)
        cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        cost_label.add_theme_font_size_override("font_size", 12)
    else:
        var text_x := 58.0
        var width := maxf(32.0, size.x - text_x - 12.0)
        category_label.position = Vector2(text_x, 3.0)
        category_label.size = Vector2(width, 17.0)
        category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        category_label.add_theme_font_size_override("font_size", 12)
        name_label.position = Vector2(text_x, 21.0)
        name_label.size = Vector2(width, 24.0)
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        name_label.add_theme_font_size_override("font_size", 15)
        name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
        name_label.max_lines_visible = 1
        cost_label.position = Vector2(text_x, maxf(45.0, size.y - 24.0))
        cost_label.size = Vector2(width, 20.0)
        cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        cost_label.add_theme_font_size_override("font_size", 13)
    if compact_changed:
        _refresh_texts()
    queue_redraw()


func _icon_rect() -> Rect2:
    if _compact:
        var side := 36.0
        return Rect2(Vector2((size.x - side) * 0.5, 27.0), Vector2(side, side))
    var side := minf(42.0, size.y - 24.0)
    return Rect2(Vector2(10.0, (size.y - side) * 0.5), Vector2(side, side))


func _refresh_texts() -> void:
    if item.is_empty():
        return
    var category := String(item.category)
    var energy := int(item.get("energy_output", 0))
    if _compact:
        var demand := int(item.get("energy_demand", 0))
        if energy <= 0 and demand == 0:
            category_label.text = I18n.t("shop.energy_none")
        else:
            category_label.text = I18n.t("shop.energy_output", [energy]) if energy > 0 else I18n.t("shop.energy_demand", [demand])
    elif energy > 0:
        category_label.text = I18n.t(ItemDefs.category_name_key(category)) + " " + I18n.t("shop.energy_output", [energy])
    else:
        category_label.text = I18n.t(ItemDefs.category_name_key(category)) + " " + I18n.t("shop.energy_demand", [int(item.get("energy_demand", 1))])
    category_label.add_theme_color_override("font_color", ItemDefs.category_color(category).darkened(0.15))
    name_label.text = I18n.t(String(item.name_key))
    cost_label.text = I18n.t("shop.cost", [int(item.cost)])
    if not _unlocked:
        category_label.text = I18n.t("shop.locked")
        cost_label.text = I18n.t("shop.research_cost", [ItemDefs.get_research_cost(String(item.id))])


func _on_locale_changed(_locale: String) -> void:
    _refresh_texts()


func _on_mouse_entered() -> void:
    _hovered = true
    queue_redraw()


func _on_mouse_exited() -> void:
    _hovered = false
    queue_redraw()


func _gui_input(event: InputEvent) -> void:
    if game == null or item.is_empty():
        return
    if not game.can_use_shop_item(String(item.id)):
        return
    var pressed_now := false
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        pressed_now = event.pressed
    elif event is InputEventScreenTouch:
        pressed_now = event.pressed
    if not pressed_now:
        return
    if not _unlocked:
        game.research_item(String(item.id))
        accept_event()
        return

    pressed.emit(category, get_global_rect().position + event.position)
    accept_event()



func _draw() -> void:
    if item.is_empty():
        return

    var item_category := String(item.category)
    var accent := ItemDefs.category_color(item_category)
    _style.bg_color = Color(1.0, 0.98, 0.90, 1.0) if (_hovered or active) and _can_buy else Color(Palette.PAPER, 0.98)
    var border_alpha := 1.0 if active else (0.90 if _hovered and _can_buy else 0.30)
    _style.border_color = Color(accent.r, accent.g, accent.b, border_alpha) if _can_buy else Palette.DANGER.darkened(0.30)
    _style.set_border_width_all(2 if active else 1)
    draw_style_box(_style, Rect2(Vector2.ZERO, size))
    draw_rect(Rect2(0, 8, 3, size.y - 16), Color(accent.r, accent.g, accent.b, 0.95 if active or _can_buy else 0.25))

    var icon := _icon_rect()
    var center := icon.get_center()
    var tint := Color(1.0, 1.0, 1.0, 1.0 if _can_buy else 0.42)
    if _icon_texture != null:
        draw_texture_rect(_icon_texture, icon, false, tint)
    else:
        draw_category_icon(String(item.id), icon, tint)

    # 右侧三点握柄提示卡片可拖拽
    for row in 3:
        draw_circle(Vector2(size.x - 6.0, size.y * 0.5 - 8.0 + row * 8.0), 1.4, Color(Palette.INK_MUTED.r, Palette.INK_MUTED.g, Palette.INK_MUTED.b, 0.55))

    if not _can_buy:
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.35))


func draw_category_icon(id: String, icon: Rect2, tint: Color) -> void:
    var center := icon.get_center()
    var scale := icon.size.x / 30.0
    if id == "sandbag":
        var sack := Color(0.74, 0.65, 0.48).lerp(Color.WHITE, 0.15)
        var dark := sack.darkened(0.28)
        for row in 2:
            for col in 3:
                var p := center + Vector2(-7.0 + col * 7.0, -3.0 + row * 6.0) * scale
                draw_circle(p, 4.2 * scale, dark)
                draw_circle(p - Vector2(0.0, 0.5) * scale, 4.0 * scale, sack)
        return
    if id == "solar":
        var panel := PackedVector2Array([
            center + Vector2(-11.0, -3.0) * scale,
            center + Vector2(1.0, -10.0) * scale,
            center + Vector2(11.0, -3.0) * scale,
            center + Vector2(-1.0, 4.0) * scale,
        ])
        draw_colored_polygon(panel, Color(0.16, 0.33, 0.56))
        var outline := panel.duplicate()
        outline.append(panel[0])
        draw_polyline(outline, Color(0.62, 0.86, 0.96, 0.9), 1.2)
        draw_line(center + Vector2(-7.0, 5.0) * scale, center + Vector2(-7.0, 11.0) * scale, Color(0.42, 0.48, 0.50), 2.0)
        draw_line(center + Vector2(7.0, 5.0) * scale, center + Vector2(7.0, 11.0) * scale, Color(0.42, 0.48, 0.50), 2.0)
        return

    # 未知建筑用类别色的简笔图标兜底
    draw_circle(center, 10.0 * scale, Color(tint.r, tint.g, tint.b, 0.25))
    draw_arc(center, 10.0 * scale, 0.0, TAU, 20, tint, 1.5)
