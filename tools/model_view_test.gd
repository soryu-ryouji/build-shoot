extends Node3D

## 单独看 GLB 模型：验证比例与材质。
## godot --path . res://tools/model_view_test.tscn


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.7)
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -40.0, 0.0)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.26, 0.27)
	ground.material_override = mat
	add_child(ground)

	var packed: PackedScene = load("res://assets/models/turret_construct.glb")
	var model := packed.instantiate()
	add_child(model)

	var cam := Camera3D.new()
	cam.position = Vector3(90.0, 90.0, 110.0)
	cam.look_at_from_position(Vector3(90.0, 90.0, 110.0), Vector3(0.0, 25.0, 0.0))
	cam.fov = 40.0
	add_child(cam)
	cam.current = true

	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://tools/_model_view.png")
	print("SAVED ", image.get_size())
	get_tree().quit()
