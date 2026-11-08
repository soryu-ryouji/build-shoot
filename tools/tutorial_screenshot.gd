extends Node

## 教学画面检查：--step=energy_guide / deploy_generator / ready，--size=1280x720。

const ItemDefs = preload("res://scripts/item_defs.gd")
var main: Node


func _ready() -> void:
	var size := Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				size = Vector2i(int(parts[0]), int(parts[1]))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	get_window().size = size
	main = load("res://scenes/tutorial.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var wanted := "deploy_generator"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--step="):
			wanted = arg.trim_prefix("--step=")
	var guard := 0
	while main.tutorial.current_step_id() != wanted and guard < 20:
		guard += 1
		var item_id := String(main.tutorial._step.get("item_id", ""))
		if item_id.is_empty():
			main.tutorial.advance()
		else:
			var target: Vector2i = main.tutorial._step.target
			main._place_building(ItemDefs.get_item(item_id), main.arena.map_loader.cell_to_world(target))
		await get_tree().process_frame
	var dragging := "--drag" in OS.get_cmdline_user_args()
	if dragging and not String(main.tutorial._step.get("item_id", "")).is_empty():
		main.begin_placement(String(main.tutorial._step.item_id))
		main.update_placement(main.arena.map_loader.cell_to_world(main.tutorial._step.target))
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var suffix := "_drag" if dragging else ""
	image.save_png(ProjectSettings.globalize_path("res://build/tutorial_%s%s.png" % [wanted, suffix]))
	get_tree().quit()
