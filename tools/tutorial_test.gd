extends Node

## 教学流程与真实鼠标拖拽回归测试。

var main: Node
var failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size = Vector2i(1280, 720)
	call_deferred("_run")


func _run() -> void:
	main = load("res://scenes/tutorial.tscn").instantiate()
	add_child(main)
	await _frames(3)

	_check(main.tutorial_mode, "tutorial scene enables tutorial mode")
	_check(main.arena.map_loader.map_id == "tutorial_01", "tutorial uses its own map")
	_check(main.nests.size() == 1, "tutorial has one nest")
	_check(main.preparing and main.tutorial.current_step_id() == "briefing", "tutorial holds preparation at briefing")
	var initial_safe := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	_check(initial_safe.encloses(main.tutorial._panel.get_global_rect()), "briefing panel stays inside the viewport")
	main._process(8.0)
	_check(main.preparing and main.nests.size() == 1, "explanation never starts the normal countdown")
	_check(not SaveManager.save_game(main), "tutorial cannot overwrite the normal save")

	var introduced: Dictionary = {}
	for step in main.tutorial.STEPS:
		for item_id in step.get("items", []):
			introduced[item_id] = true
	_check(introduced.size() == 10, "all ten buildings are introduced")

	main.begin_placement("fusion_tower")
	_check(not main.placing, "briefing blocks deployment")
	main.tutorial.advance()
	_check(main.tutorial.current_step_id() == "resources", "briefing advances to resources")
	main.tutorial.advance()
	_check(main.tutorial.current_step_id() == "energy_guide", "resources advances to energy guide")
	_check(main.shop_bar.active_category == "energy" and main.shop_bar.cards.size() == 4, "energy guide shows all energy cards")
	get_window().size = Vector2i(640, 360)
	await _frames(3)
	var safe := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	_check(safe.encloses(main.tutorial._panel.get_global_rect()), "compact guide stays inside the viewport")
	get_window().size = Vector2i(1280, 720)
	await _frames(3)
	main.tutorial.advance()
	_check(main.tutorial.current_step_id() == "deploy_generator", "energy guide starts deployment exercise")
	await _frames(2)
	_check(main.tutorial._panel.size.x <= 360.0, "deployment prompt uses compact width")
	_check(main.tutorial._panel.position.x < get_viewport().get_visible_rect().size.x * 0.5, "deployment prompt leaves the right-side target visible")
	_check(not main.tutorial.is_deployment_masked(), "mask stays hidden before dragging")
	main.shop_bar._on_tab_pressed("firepower")
	_check(main.shop_bar.active_category == "energy", "exercise locks unrelated tabs")
	main.begin_placement("turret")
	_check(not main.placing, "exercise rejects the wrong building")
	_check(not main.research_item("super_fusion_tower"), "tutorial disables research spending")

	var starting_coins := int(main.coins)
	main.begin_placement("fusion_tower")
	_check(main.placing and Engine.time_scale < 0.5, "allowed card starts normal deployment focus")
	main.open_settings()
	_check(get_tree().paused and not main.placing and is_equal_approx(Engine.time_scale, 1.0), "settings safely cancel tutorial drag")
	main.close_settings()
	_check(not get_tree().paused and main.tutorial.current_step_id() == "deploy_generator", "closing settings restores the same exercise")

	main.begin_placement("fusion_tower")
	main.update_placement(_world(Vector2i(2, 2)))
	_check(not main.highlights.hover_valid, "non-recommended cell is marked invalid")
	main.finish_placement("fusion_tower", _world(Vector2i(2, 2)))
	_check(main.placed_buildings.is_empty() and main.coins == starting_coins, "invalid drop does not build or charge")
	_check(main.tutorial.current_step_id() == "deploy_generator", "invalid drop does not advance")
	await _cancel_card_drag("fusion_tower")
	_check(main.placed_buildings.is_empty() and not main.placing, "dragging back to the shop cancels cleanly")
	_check(main.coins == starting_coins and main.tutorial.current_step_id() == "deploy_generator", "cancel does not charge or advance")

	await _drag_card("fusion_tower", Vector2i(3, 2))
	_check(main.placed_buildings.size() == 1, "real drag deploys the generator once")
	_check(main.coins == starting_coins - 40, "real drag charges exactly once")
	_check(main.tutorial.current_step_id() == "power_result", "only successful placement advances")
	_check(main.power_supply == 4, "generator updates tutorial power display")

	main.tutorial.advance()
	_check(main.tutorial.current_step_id() == "firepower_guide", "power result advances to firepower guide")
	_check(main.shop_bar.active_category == "firepower" and main.shop_bar.cards.size() == 4, "firepower guide shows all firepower cards")
	main.tutorial.advance()
	await _drag_card("turret", Vector2i(3, 1))
	_check(main.tutorial.current_step_id() == "fortification_guide", "turret drag advances to fortification guide")
	_check(main.placed_buildings.size() == 2 and main.placed_buildings[1].powered, "deployed turret is powered")
	_check(main.shop_bar.active_category == "fortification" and main.shop_bar.cards.size() == 2, "fortification guide shows both cards")

	main.tutorial.advance()
	await _drag_card("sandbag", Vector2i(2, -1))
	_check(main.tutorial.current_step_id() == "ready", "wall drag completes all exercises")
	_check(main.placed_buildings.size() == 3 and main.coins == starting_coins - 85, "three exercises charge the expected total")
	_check(main.preparing and main.blocks.blocks.is_empty(), "enemies remain disabled before the drill")

	I18n.set_locale("en")
	_check(main.tutorial._title.text == "DEFENSE READY", "tutorial UI updates to English")
	_check(I18n.missing_keys("en").is_empty(), "English includes every tutorial key")
	I18n.set_locale("zh_CN")
	_check(main.tutorial._title.text == "防线已就绪", "tutorial UI restores Chinese")

	main.tutorial.advance()
	_check(main.tutorial.battle_started and not main.preparing, "ready button starts the live drill")
	_check(main.tutorial.can_deploy("turret"), "drill permits basic extra deployment")
	main.hit_nest(main.nests[0], 9999, main.nests[0].global_position, false)
	for enemy in main.blocks.blocks.duplicate():
		main.hit_block(int(enemy.id), 9999)
	main.blocks.clear_enemies()
	main.check_outcome()
	_check(main.outcome == "won" and main.result_panel.visible, "clearing the drill shows completion")
	_check(main.result_panel.title_label.text == "教学完成", "tutorial uses its own completion text")
	_check(get_tree().paused, "completion pauses the tutorial")

	get_tree().paused = false
	Engine.time_scale = 1.0
	_finish()


func _cancel_card_drag(item_id: String) -> void:
	var card: Control = null
	for candidate in main.shop_bar.cards:
		if String(candidate.item.get("id", "")) == item_id:
			card = candidate
			break
	if card == null:
		_check(false, "cancel drag card exists: " + item_id)
		return
	var start := card.get_global_rect().get_center()
	var outside := start + Vector2(0, -30)
	_mouse_motion(start, start)
	await _frames(1)
	_mouse_button(start, true)
	await _frames(1)
	_mouse_motion(start, outside)
	await _frames(1)
	_mouse_motion(outside, start)
	await _frames(1)
	_mouse_button(start, false)
	await _frames(2)


func _drag_card(item_id: String, target: Vector2i) -> void:
	var card: Control = null
	for candidate in main.shop_bar.cards:
		if String(candidate.item.get("id", "")) == item_id:
			card = candidate
			break
	_check(card != null, "drag card exists: " + item_id)
	if card == null:
		return
	await _frames(1)
	var start := card.get_global_rect().get_center()
	var middle := start + Vector2(0, -24)
	var end: Vector2 = main.world_to_screen(_world(target))
	_mouse_motion(start, start)
	await _frames(1)
	_mouse_button(start, true)
	await _frames(1)
	_mouse_motion(start, middle)
	await _frames(1)
	_check(main.placing and main.placing_id == item_id, "mouse threshold starts drag: " + item_id)
	_check(main.tutorial.is_deployment_masked(), "active drag masks non-target field: " + item_id)
	_mouse_motion(middle, end)
	await _frames(1)
	_mouse_button(end, false)
	await _frames(2)
	_check(not main.tutorial.is_deployment_masked(), "completed drag removes mask: " + item_id)


func _mouse_button(pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = pos
	event.global_position = pos
	event.pressed = pressed
	get_viewport().push_input(event, true)


func _mouse_motion(from: Vector2, to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	event.relative = to - from
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(event, true)


func _world(cell: Vector2i) -> Vector2:
	return main.arena.map_loader.cell_to_world(cell)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("TUTORIAL TEST PASS  steps=%d buildings=3" % main.tutorial.STEPS.size())
		get_tree().quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		get_tree().quit(1)
