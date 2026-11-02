extends Control

## 底部道具栏：显示可购买道具，并统一处理从卡片拖到场地上的手势。

const ItemDefs = preload("res://scripts/item_defs.gd")
const ItemCard = preload("res://scripts/item_card.gd")
const Palette = preload("res://scripts/palette.gd")

signal drag_started(item_id: String)
signal drag_moved(pos: Vector2)
signal drag_released(item_id: String, pos: Vector2)

var game: Node
var cards: Array = []

var _dragging := false
var _drag_id := ""
var _panel_style: StyleBoxFlat


func _ready() -> void:
	position = Vector2(24, 850)
	size = Vector2(672, 82)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(Palette.PAPER, 0.90)
	_panel_style.border_color = Color(1.0, 1.0, 0.98, 0.65)
	_panel_style.set_border_width_all(1)
	_panel_style.set_corner_radius_all(2)
	_panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	_panel_style.shadow_size = 5
	_panel_style.shadow_offset = Vector2(0, 3)

	_build_cards()


func _build_cards() -> void:
	for card in cards:
		if is_instance_valid(card):
			card.queue_free()
	cards.clear()

	var items: Array = ItemDefs.ITEMS
	var card_width := 288.0
	var gap := 16.0
	var total := items.size() * card_width + (items.size() - 1) * gap
	var start := (size.x - total) * 0.5

	for i in items.size():
		var card = ItemCard.new()
		card.game = game
		card.item = items[i]
		card.position = Vector2(start + i * (card_width + gap), 5.0)
		card.size = Vector2(card_width, 72.0)
		card.drag_started.connect(_on_card_drag_started)
		add_child(card)
		cards.append(card)


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
	draw_line(Vector2(18, 0), Vector2(128, 0), Palette.ACCENT, 3.0)
	draw_line(Vector2(size.x - 96, 0), Vector2(size.x - 18, 0), Color(0.85, 0.86, 0.84, 0.36), 1.0)
