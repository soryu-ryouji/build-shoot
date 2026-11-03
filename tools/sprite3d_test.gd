extends Node3D

## 验证 Sprite3D 在 SubViewport 里能不能渲染（敌人 3D 立牌的前置排查）。
## godot --path . res://tools/sprite3d_test.tscn

const BattleWorld = preload("res://scripts/battle_world.gd")
const BattleMap = preload("res://scripts/battle_map.gd")


func _ready() -> void:
	BattleMap.use(0)
	var world := BattleWorld.new()
	add_child(world)

	# 先等一帧，让 battle_world 的 _ready 建好场景
	await get_tree().process_frame
	var root: Node3D = world.get_node("World")

	var texture: Texture2D = load("res://assets/ui/enemies/normal.png")
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = 1.0
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.position = Vector3(0.0, 24.0, 0.0)
	root.add_child(sprite)

	var sprite2 := Sprite3D.new()
	sprite2.texture = texture
	sprite2.pixel_size = 1.0
	sprite2.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite2.shaded = false
	sprite2.position = Vector3(120.0, 24.0, 0.0)
	root.add_child(sprite2)

	print("SPRITE3D added=", sprite.is_inside_tree(), " visible=", sprite.visible, " tex=", sprite.texture)

	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := world.get_texture().get_image()
	image.save_png("res://tools/_sprite3d_world.png")
	print("SAVED world ", image.get_size())
	get_tree().quit()
