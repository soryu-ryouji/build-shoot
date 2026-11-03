extends Node2D

## 单独验证 3D 战场视口：把它贴到 2D 世界层，等几帧后截图。
## 跑法：godot --path . res://tools/world3d_test.tscn

const BattleWorld = preload("res://scripts/battle_world.gd")
const BattleMap = preload("res://scripts/battle_map.gd")


func _ready() -> void:
	BattleMap.use(0)
	var world := BattleWorld.new()
	world.name = "BattleWorld"
	add_child(world)

	var sprite := Sprite2D.new()
	sprite.texture = world.get_texture()
	sprite.centered = true
	sprite.position = BattleMap.field_rect().get_center()
	add_child(sprite)

	var cam := Camera2D.new()
	cam.position = Vector2(264, 341)
	cam.zoom = Vector2(1.0, 1.0)
	add_child(cam)
	cam.make_current()

	print("VIEWPORT size=", world.size, " children=", world.get_child_count())
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://tools/_world3d_test.png")
	print("SAVED ", image.get_width(), "x", image.get_height())
	get_tree().quit()
