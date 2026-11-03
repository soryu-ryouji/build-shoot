extends Control

## 纯竖屏商店：上方是当前类别的道具列表，下方是三类建筑卡。
## 点击类别切换列表；选中道具后，拖拽类别卡把该道具放到场上。

const ItemDefs = preload("res://scripts/item_defs.gd")
const ItemCard = preload("res://scripts/item_card.gd")
const ItemChip = preload("res://scripts/item_chip.gd")
const Palette = preload("res://scripts/palette.gd")
const ResponsiveLayout = preload("res://scripts/responsive_layout.gd")
const UiMetrics = preload("res://scripts/ui_metrics.gd")

signal drag_started(item_id: String)
signal drag_moved(pos: Vector2)
signal drag_released(item_id: String, pos: Vector2)

var game: Node
var cards: Array = []
var chips: Array = []
var selected: Dictionary = {}
var active_category := ItemDefs.CATEGORY_FIREPOWER

var item_row: HBoxContainer
var card_row: HBoxContainer
var _panel_style: StyleBoxFlat

var _dragging := false
var _drag_id := ""
var _pending := false
var _pending_id := ""
var _pending_pos := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(Palette.PAPER, 0.92)
	_panel_style.border_color = Color(1.0, 1.0, 0.98, 0.65)
	_panel_style.set_border_width_all(1)
	_panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	_panel_style.shadow_size = 5
	_panel_style.shadow_offset = Vector2(0, 3)

	for category in ItemDefs.CATEGORY_ORDER:
		var default_item: Dictionary = ItemDefs.get_default_item(String(category))
		if not default_item.is_empty():
			selected[category] = String(default_item.id)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 8
	column.offset_top = 8
	column.offset_right = -8
	column.offset_bottom = -8
	add_child(column)

	item_row = HBoxContainer.new()
	item_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_row.custom_minimum_size.y = 46
	item_row.add_theme_constant_override("separation", 6)
	column.add_child(item_row)

	card_row = HBoxContainer.new()
	card_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_row.add_theme_constant_override("separation", 6)
	card_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(card_row)

	_build_cards()
	_refresh_items()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _build_cards() -> void:
	for category in ItemDefs.CATEGORY_ORDER:
		var item: Dictionary = ItemDefs.get_item(String(selected[category]))
		if item.is_empty():
			continue
		var card = ItemCard.new()
		card.game = game
		card.category = String(category)
		card.item = item
		card.custom_minimum_size = Vector2(96, 92)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.pressed.connect(_on_category_pressed)
		card_row.add_child(card)
		cards.append(card)


func _refresh_items() -> void:
	for chip in chips:
		if is_instance_valid(chip):
			item_row.remove_child(chip)
			chip.queue_free()
	chips.clear()
	for item in ItemDefs.get_category_items(active_category):
		var chip = ItemChip.new()
		chip.game = game
		chip.item = item
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size = Vector2(72, 46)
		chip.active = String(selected[active_category]) == String(item.id)
		chip.pressed.connect(_on_item_chip_pressed)
		item_row.add_child(chip)
		chips.append(chip)


func _on_category_pressed(category: String, pos: Vector2) -> void:
	active_category = category
	_refresh_items()
	_refresh_cards()

	_pending = true
	_pending_id = String(selected[category])
	_pending_pos = pos


func _on_item_chip_pressed(item_id: String) -> void:
	_pending = false
	selected[active_category] = item_id
	_refresh_items()
	_refresh_cards()


func _refresh_cards() -> void:
	for card in cards:
		if not is_instance_valid(card):
			continue
		card.set_item(ItemDefs.get_item(String(selected[String(card.category)])))
		card.set_active(String(card.category) == active_category)


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
	var safe := ResponsiveLayout.safe_rect(self)
	var margin := ResponsiveLayout.margin(self)
	size = Vector2(safe.size.x - margin * 2.0, UiMetrics.SHOP_HEIGHT)
	position = Vector2(safe.position.x + margin, safe.end.y - size.y - margin)
	queue_redraw()


func _draw() -> void:
	draw_style_box(_panel_style, Rect2(Vector2.ZERO, size))
