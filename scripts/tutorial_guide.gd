extends Control

## 分步教学：说明页锁定战场，操作页只接受当前建筑与推荐格。

signal step_changed(step_id: String)

const Palette = preload("res://scripts/palette.gd")
const ItemDefs = preload("res://scripts/item_defs.gd")
const ResponsiveLayout = preload("res://scripts/responsive_layout.gd")
const EventBindingScript = preload("res://scripts/event_binding.gd")

const STEPS := [
	{
		"id": "briefing",
		"title": "tutorial.briefing.title",
		"body": "tutorial.briefing.body",
		"highlights": ["base", "nest"],
	},
	{
		"id": "resources",
		"title": "tutorial.resources.title",
		"body": "tutorial.resources.body",
		"highlights": ["resources", "base"],
	},
	{
		"id": "energy_guide",
		"title": "tutorial.energy.title",
		"body": "tutorial.energy.body",
		"category": "energy",
		"items": ["fusion_tower", "coin_tower", "super_fusion_tower", "super_generator_tower"],
		"highlights": ["tab"],
	},
	{
		"id": "deploy_generator",
		"title": "tutorial.deploy_generator.title",
		"body": "tutorial.deploy_generator.body",
		"category": "energy",
		"item_id": "fusion_tower",
		"target": Vector2i(3, 2),
	},
	{
		"id": "power_result",
		"title": "tutorial.power_result.title",
		"body": "tutorial.power_result.body",
		"highlights": ["resources", "building"],
	},
	{
		"id": "firepower_guide",
		"title": "tutorial.firepower.title",
		"body": "tutorial.firepower.body",
		"category": "firepower",
		"items": ["turret", "heavy_turret", "laser_tower", "lightning_tower"],
		"highlights": ["tab"],
	},
	{
		"id": "deploy_turret",
		"title": "tutorial.deploy_turret.title",
		"body": "tutorial.deploy_turret.body",
		"category": "firepower",
		"item_id": "turret",
		"target": Vector2i(3, 1),
	},
	{
		"id": "fortification_guide",
		"title": "tutorial.fortification.title",
		"body": "tutorial.fortification.body",
		"category": "fortification",
		"items": ["sandbag", "compression_tower"],
		"highlights": ["tab"],
	},
	{
		"id": "deploy_wall",
		"title": "tutorial.deploy_wall.title",
		"body": "tutorial.deploy_wall.body",
		"category": "fortification",
		"item_id": "sandbag",
		"target": Vector2i(2, -1),
	},
	{
		"id": "ready",
		"title": "tutorial.ready.title",
		"body": "tutorial.ready.body",
		"highlights": ["base", "nest", "building"],
	},
	{
		"id": "battle",
		"title": "tutorial.battle.title",
		"body": "tutorial.battle.body",
		"category": "firepower",
		"highlights": ["nest"],
	},
]

var game: Node
var step_index := 0
var battle_started := false

var _step: Dictionary = {}
var _time := 0.0
var _panel: PanelContainer
var _panel_margin: MarginContainer
var _progress: Label
var _title: Label
var _body: Label
var _scroll: ScrollContainer
var _item_list: VBoxContainer
var _next_button: Button
var _events := EventBindingScript.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_events.bind(Events.language_changed, _on_language_changed)
	_events.bind(Events.outcome_changed, _on_outcome_changed)
	get_viewport().size_changed.connect(_layout)
	_set_step(0)


func _exit_tree() -> void:
	_events.clear()


func current_step_id() -> String:
	return String(_step.get("id", ""))


func can_deploy(item_id: String) -> bool:
	if current_step_id() == "battle":
		return ["turret", "fusion_tower", "sandbag", "coin_tower"].has(item_id)
	return String(_step.get("item_id", "")) == item_id


func can_open_category(category: String) -> bool:
	if current_step_id() == "battle":
		return true
	return String(_step.get("category", "")) == category


func is_cell_allowed(item_id: String, cell: Vector2i) -> bool:
	if current_step_id() == "battle":
		return true
	return can_deploy(item_id) and cell == _step.get("target", Vector2i.ZERO)


func is_deployment_masked() -> bool:
	return game != null and bool(game.placing) and not String(_step.get("item_id", "")).is_empty()


func blocks_world_input() -> bool:
	return current_step_id() != "battle" and String(_step.get("item_id", "")).is_empty()


func on_building_placed(building: Node) -> void:
	if building == null or not is_instance_valid(building):
		return
	var item_id := String(_step.get("item_id", ""))
	if item_id.is_empty() or building.item_id != item_id:
		return
	if building.cell != _step.get("target", Vector2i.ZERO):
		return
	_set_step(step_index + 1)


func advance() -> void:
	if not String(_step.get("item_id", "")).is_empty() or current_step_id() == "battle":
		return
	if current_step_id() == "ready":
		_start_battle()
		return
	_set_step(step_index + 1)


func _start_battle() -> void:
	if battle_started:
		return
	battle_started = true
	_set_step(STEPS.size() - 1)
	game._end_prep()


func _set_step(index: int) -> void:
	step_index = clampi(index, 0, STEPS.size() - 1)
	_step = STEPS[step_index]
	var category := String(_step.get("category", ""))
	if not category.is_empty() and game.shop_bar.active_category != category:
		game.shop_bar._on_tab_pressed(category)
	for card in game.shop_bar.cards:
		card.set_active(String(card.item.get("id", "")) == String(_step.get("item_id", "")))
	_refresh_text()
	_layout()
	call_deferred("_layout")
	queue_redraw()
	step_changed.emit(current_step_id())


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(Palette.PAPER, 0.98)
	panel_style.border_color = Palette.ACCENT
	panel_style.set_border_width_all(1)
	panel_style.border_width_left = 5
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	panel_style.shadow_size = 10
	panel_style.shadow_offset = Vector2(0, 4)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	_panel_margin = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		_panel_margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(_panel_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel_margin.add_child(column)

	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 11)
	_progress.add_theme_color_override("font_color", Palette.ACCENT.darkened(0.18))
	column.add_child(_progress)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 23)
	_title.add_theme_color_override("font_color", Palette.INK)
	column.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 15)
	_body.add_theme_color_override("font_color", Palette.INK_MUTED)
	column.add_child(_body)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, 160)
	column.add_child(_scroll)
	_item_list = VBoxContainer.new()
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list.add_theme_constant_override("separation", 7)
	_scroll.add_child(_item_list)

	_next_button = Button.new()
	_next_button.custom_minimum_size = Vector2(180, 46)
	_next_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_next_button.add_theme_font_size_override("font_size", 16)
	_next_button.add_theme_color_override("font_color", Palette.INK)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Palette.ACCENT
	button_style.set_corner_radius_all(2)
	_next_button.add_theme_stylebox_override("normal", button_style)
	_next_button.pressed.connect(advance)
	column.add_child(_next_button)


func _refresh_text() -> void:
	if _title == null:
		return
	var compact := not String(_step.get("item_id", "")).is_empty() or current_step_id() == "battle"
	_progress.visible = not compact
	_title.add_theme_font_size_override("font_size", 18 if compact else 23)
	_body.add_theme_font_size_override("font_size", 13 if compact else 15)
	for side in ["left", "top", "right", "bottom"]:
		_panel_margin.add_theme_constant_override("margin_" + side, 12 if compact else 16)
	_progress.text = "%02d / %02d  ·  %s" % [step_index + 1, STEPS.size(), I18n.t("tutorial.label")]
	_title.text = I18n.t(String(_step.get("title", "")))
	_body.text = I18n.t(String(_step.get("body", "")))
	_next_button.text = I18n.t("tutorial.start_battle" if current_step_id() == "ready" else "tutorial.next")
	_next_button.visible = String(_step.get("item_id", "")).is_empty() and current_step_id() != "battle"
	_rebuild_items()


func _rebuild_items() -> void:
	for child in _item_list.get_children():
		_item_list.remove_child(child)
		child.queue_free()
	var items: Array = _step.get("items", [])
	_scroll.visible = not items.is_empty()
	for item_id in items:
		var item := ItemDefs.get_item(String(item_id))
		if item.is_empty():
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_item_list.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(42, 42)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(String(item.icon))
		row.add_child(icon)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(texts)
		var name_label := Label.new()
		name_label.text = I18n.t(String(item.name_key))
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", ItemDefs.category_color(String(item.category)).darkened(0.22))
		texts.add_child(name_label)
		var description := Label.new()
		description.text = I18n.t(String(item.desc_key))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", 12)
		description.add_theme_color_override("font_color", Palette.INK_MUTED)
		texts.add_child(description)


func _layout() -> void:
	if _panel == null or game == null:
		return
	var safe := ResponsiveLayout.safe_rect(self)
	var margin := ResponsiveLayout.margin(self)
	_scroll.custom_minimum_size.y = clampf(safe.size.y - 230.0, 90.0, 240.0)
	_panel.reset_size()
	var compact := not String(_step.get("item_id", "")).is_empty() or current_step_id() == "battle"
	var width := minf(360.0 if compact else 620.0, safe.size.x - margin * 2.0 - (54.0 if compact else 0.0))
	# 先给自动换行文本确定宽度，再测量高度，避免首帧按窄列撑出全屏。
	_panel.size = Vector2(width, 1.0)
	var minimum := _panel.get_combined_minimum_size()
	var height := minf(minimum.y, safe.size.y - margin * 2.0)
	_panel.size = Vector2(width, height)
	if compact:
		_panel.position = safe.position + Vector2(margin + 54.0, margin)
	elif not _step.get("items", []).is_empty():
		_panel.position = safe.position + (safe.size - _panel.size) * 0.5
	else:
		var field := ResponsiveLayout.field_rect(self)
		var x := safe.position.x + (safe.size.x - width) * 0.5
		var y := field.end.y - height - margin
		if ["resources", "power_result"].has(current_step_id()):
			y = field.position.y + margin
		_panel.position = Vector2(x, y)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _step.is_empty() or Events.outcome != "playing":
		return
	if is_deployment_masked():
		_draw_deployment_mask()
	var compact := not String(_step.get("item_id", "")).is_empty() or current_step_id() == "battle"
	if not compact:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.035, 0.04, 0.30))
	var pulse := 0.65 + sin(_time * 4.0) * 0.25
	for rect in _highlight_rects():
		draw_rect(rect, Color(Palette.ACCENT, 0.08))
		draw_rect(rect, Color(Palette.ACCENT, pulse), false, 3.0)
		draw_rect(rect.grow(5), Color(Palette.PAPER, pulse * 0.45), false, 1.0)
	if not String(_step.get("item_id", "")).is_empty():
		_draw_drag_hint()


func _draw_deployment_mask() -> void:
	var field := ResponsiveLayout.field_rect(self)
	var hole := _target_rect().grow(8.0)
	var shade := Color(0.015, 0.025, 0.035, 0.58)
	if not field.intersects(hole):
		draw_rect(field, shade)
		return
	var cut := field.intersection(hole)
	var top := Rect2(field.position, Vector2(field.size.x, cut.position.y - field.position.y))
	var bottom := Rect2(Vector2(field.position.x, cut.end.y), Vector2(field.size.x, field.end.y - cut.end.y))
	var left := Rect2(Vector2(field.position.x, cut.position.y), Vector2(cut.position.x - field.position.x, cut.size.y))
	var right := Rect2(Vector2(cut.end.x, cut.position.y), Vector2(field.end.x - cut.end.x, cut.size.y))
	for rect in [top, bottom, left, right]:
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			draw_rect(rect, shade)


func _highlight_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for key in _step.get("highlights", []):
		var rect := _rect_for_highlight(String(key))
		if rect.size.x > 0.0:
			result.append(rect)
	if not String(_step.get("item_id", "")).is_empty():
		var card := _card_rect(String(_step.item_id))
		if card.size.x > 0.0:
			result.append(card.grow(4))
		result.append(_target_rect().grow(4))
	return result


func _rect_for_highlight(key: String) -> Rect2:
	match key:
		"base":
			return _world_rect(game.base_core.global_position, Vector2(190, 190))
		"nest":
			if not game.nests.is_empty() and is_instance_valid(game.nests[0]):
				return _world_rect(game.nests[0].global_position, Vector2(112, 112))
		"resources":
			return game.shop_bar.resource_row.get_global_rect().grow(4)
		"tab":
			var category := String(_step.get("category", ""))
			if game.shop_bar.tab_buttons.has(category):
				return game.shop_bar.tab_buttons[category].get_global_rect().grow(3)
		"building":
			if not game.placed_buildings.is_empty():
				var building = game.placed_buildings.back()
				if is_instance_valid(building):
					return _world_rect(building.global_position, Vector2(76, 76))
	return Rect2()


func _world_rect(center: Vector2, world_size: Vector2) -> Rect2:
	var screen_size := world_size * float(game.camera_zoom)
	return Rect2(game.world_to_screen(center) - screen_size * 0.5, screen_size)


func _target_rect() -> Rect2:
	var center: Vector2 = game.arena.map_loader.cell_to_world(_step.get("target", Vector2i.ZERO))
	return _world_rect(center, Vector2.ONE * 64.0)


func _card_rect(item_id: String) -> Rect2:
	for card in game.shop_bar.cards:
		if is_instance_valid(card) and String(card.item.get("id", "")) == item_id:
			return card.get_global_rect()
	return Rect2()


func _draw_drag_hint() -> void:
	var card := _card_rect(String(_step.item_id))
	if card.size.x <= 0.0:
		return
	var start := card.get_center()
	var end := _target_rect().get_center()
	var distance := start.distance_to(end)
	if distance < 1.0:
		return
	var direction := (end - start) / distance
	var offset := 0.0
	while offset < distance:
		draw_line(start + direction * offset, start + direction * minf(offset + 9.0, distance), Color(Palette.ACCENT, 0.62), 2.0, true)
		offset += 16.0
	var dot := fmod(_time * 0.45, 1.0)
	draw_circle(start.lerp(end, dot), 5.0, Palette.PAPER)
	draw_circle(start.lerp(end, dot), 3.0, Palette.ACCENT)
	draw_arc(end, 13.0 + sin(_time * 4.0) * 2.0, 0.0, TAU, 32, Palette.ACCENT, 2.0, true)


func _on_language_changed(_locale: String) -> void:
	_refresh_text()
	_layout()
	call_deferred("_layout")


func _on_outcome_changed(value: String) -> void:
	_panel.visible = value == "playing"
	queue_redraw()
