extends Node

## 主界面截图；附加 --settings 时截取主界面设置面板。

var menu: Control


func _ready() -> void:
	get_window().content_scale_size = Vector2i(720, 960)
	get_window().size = Vector2i(720, 960)
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
	if image.get_size() != Vector2i(720, 960):
		image.resize(720, 960, Image.INTERPOLATE_LANCZOS)
	var path := "res://menu_settings_preview.png" if show_settings else "res://menu_preview.png"
	image.save_png(ProjectSettings.globalize_path(path))
	get_tree().quit()
