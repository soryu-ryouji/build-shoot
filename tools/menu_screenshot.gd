extends Node

## 主界面截图；附加 --settings 时截取主界面设置面板。

var menu: Control


func _ready() -> void:
	var target_size := _requested_size()
	get_window().content_scale_size = Vector2i(720, 960)
	get_window().size = target_size
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	menu = packed.instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	var show_settings := "--settings" in OS.get_cmdline_user_args()
	if show_settings:
		menu.open_settings()
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "res://menu_settings_preview.png" if show_settings else "res://menu_preview.png"
	if target_size != Vector2i(720, 960):
		path = "res://menu_%dx%d%s.png" % [target_size.x, target_size.y, "_settings" if show_settings else ""]
	elif image.get_size() != Vector2i(720, 960):
		image.resize(720, 960, Image.INTERPOLATE_LANCZOS)
	image.save_png(ProjectSettings.globalize_path(path))
	get_tree().quit()


func _requested_size() -> Vector2i:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
				return Vector2i(maxi(320, int(parts[0])), maxi(480, int(parts[1])))
	return Vector2i(720, 960)
