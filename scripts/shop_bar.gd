extends Control

## 纯竖屏商店：底部横排并随安全区域调整宽度。

const ItemDefs = preload("res://scripts/item_defs.gd")
const ItemCard = preload("res://scripts/item_card.gd")
const Palette = preload("res://scripts/palette.gd")
const ResponsiveLayout = preload("res://scripts/responsive_layout.gd")

signal drag_started(item_id: String)
signal drag_moved(pos: Vector2)
signal drag_released(item_id: String, pos: Vector2)

var game: Node
var cards: Array = []
var card_row: HBoxContainer

var _dragging := false
var _drag_id := ""
var _panel_style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(Palette.PAPER, 0.92)
	_panel_style.border_color = Color(1.0, 1.0, 0.98, 0.65)
	_panel_style.set_border_width_all(1)
	_panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	_panel_style.shadow_size = 5
	_panel_style.shadow_offset = Vector2(0, 3)

	card_row = HBoxContainer.new()
	card_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_row.add_theme_constant_override("separation", 14)
	card_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_row.offset_left = 12
	card_row.offset_top = 6
	card_row.offset_right = -12
	card_row.offset_bottom = -6
	add_child(card_row)
	_build_cards()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _build_cards() -> void:
	for card in cards:
		if is_instance_valid(card):
			card.queue_free()
	cards.clear()

	for item in ItemDefs.ITEMS:
		var card = ItemCard.new()
		card.game = game
		card.item = item
		card.custom_minimum_size = Vector2(180, 72)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.drag_started.connect(_on_card_drag_started)
		card_row.add_child(card)
		cards.append(card)


func _layout() -> void:
	var safe := ResponsiveLayout.safe_rect(self)
	var margin := ResponsiveLayout.margin(self)
	size = Vector2(safe.size.x - margin * 2.0, 90)
	position = Vector2(safe.position.x + margin, safe.end.y - size.y - margin)
	queue_redraw()


func _on_card_drag_started(item_id: String) -> void:
	_dragging = true
	_drag_id = item_id
	drag_started.emit(item_id)


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		drag_moved.emit(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag(event.position)
	elif event is InputEventScreenTouch and not event.pressed:
		_finish_drag(event.position)


func _finish_drag(pos: Vector2) -> void:
	var id := _drag_id
	_dragging = false
	_drag_id = ""
	drag_released.emit(id, pos)
	get_viewport().set_input_as_handled()


func cancel_drag() -> void:
	_dragging = false
	_drag_id = ""


func _draw() -> void:
	draw_style_box(_panel_style, Rect2(Vector2.ZERO, size))
	draw_line(Vector2(16, 0), Vector2(128, 0), Palette.ACCENT, 3.0)
