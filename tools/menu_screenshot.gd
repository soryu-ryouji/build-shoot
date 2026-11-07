extends Node

## 主界面截图；附加 --settings 时截取主界面设置面板。

const DEFAULT_SIZE := Vector2i(1280, 720)

var menu: Control


func _ready() -> void:
	var target_size := _requested_size()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	get_window().size = target_size
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--locale="):
			I18n.set_locale(arg.trim_prefix("--locale="))
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
	var path := ""
	if _has_size_arg():
		path = "res://menu_%dx%d%s.png" % [target_size.x, target_size.y, "_settings" if show_settings else ""]
	elif show_settings:
		path = "res://menu_settings_preview.png"
	else:
		path = "res://menu_preview.png"
	image.save_png(ProjectSettings.globalize_path(path))
	get_tree().quit()


func _has_size_arg() -> bool:
	return _requested_size_argument() != Vector2i.ZERO


func _requested_size() -> Vector2i:
	var requested := _requested_size_argument()
	return DEFAULT_SIZE if requested == Vector2i.ZERO else requested


func _requested_size_argument() -> Vector2i:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
				return Vector2i(maxi(640, int(parts[0])), maxi(360, int(parts[1])))
	return Vector2i.ZERO
