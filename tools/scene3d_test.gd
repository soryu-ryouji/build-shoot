extends Node3D

## 3D 战场原型：验证「地块是 3D 网格 + 真光照阴影」的效果。
## 跑法：godot --path . res://tools/scene3d_test.tscn
## 产物：tools/_3d_test.png

const TILE := 48.0
const COLS := 8
const ROWS := 13

var _cam: Camera3D


func _ready() -> void:
	_build_environment()
	_build_floor()
	_build_high_ground()
	_build_turret()
	_cam = _build_camera()
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://tools/_3d_test.png")
	print("SAVED tools/_3d_test.png ", image.get_width(), "x", image.get_height())
	get_tree().quit()


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.04, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.40, 0.45, 0.52)
	env.ambient_light_energy = 0.55
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -38.0, 0.0)
	sun.light_energy = 2.2
	sun.light_color = Color(1.0, 0.96, 0.90)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 2000.0
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35.0, 150.0, 0.0)
	fill.light_energy = 0.55
	fill.light_color = Color(0.62, 0.72, 0.90)
	fill.shadow_enabled = false
	add_child(fill)


func _material(color: Color, rough := 0.45, metal := 0.35) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	return mat


func _plate(x: float, z: float, size_x: float, size_z: float, height: float, mat: StandardMaterial3D, base_y := 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size_x, height, size_z)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = Vector3(x, base_y + height * 0.5, z)
	add_child(node)


func _build_floor() -> void:
	var deck := _material(Color(0.20, 0.22, 0.245), 0.5, 0.45)
	var plate := _material(Color(0.34, 0.36, 0.38), 0.42, 0.4)
	var cream := _material(Color(0.72, 0.71, 0.66), 0.45, 0.2)
	var base := _material(Color(0.07, 0.08, 0.09), 0.7, 0.2)
	_plate(0.0, 0.0, COLS * TILE + 96.0, ROWS * TILE + 96.0, 8.0, base, -8.0)
	for row in ROWS:
		for col in COLS:
			var x := (col - (COLS - 1) * 0.5) * TILE
			var z := (row - (ROWS - 1) * 0.5) * TILE
			_plate(x, z, 46.0, 46.0, 5.0, deck)
			var variant := absi(col * 7 + row * 13 + col * row * 3) % 100
			if variant < 35:
				_plate(x, z, 30.0, 30.0, 1.2, plate, 5.0)
			elif variant < 55:
				_plate(x, z, 28.0, 28.0, 1.4, cream, 5.0)


func _build_high_ground() -> void:
	var side := _material(Color(0.13, 0.14, 0.15), 0.4, 0.55)
	var top := _material(Color(0.40, 0.42, 0.44), 0.42, 0.4)
	var amber := _material(Color(0.88, 0.55, 0.14), 0.35, 0.2)
	var cells: Array[Vector2i] = [
		Vector2i(0, 4), Vector2i(1, 4), Vector2i(0, 5), Vector2i(1, 5), Vector2i(6, 8), Vector2i(7, 8)
	]
	for cell in cells:
		var x: float = (cell.x - (COLS - 1) * 0.5) * TILE
		var z: float = (cell.y - (ROWS - 1) * 0.5) * TILE
		_plate(x, z, 46.0, 46.0, 18.0, side)
		_plate(x, z, 44.0, 44.0, 2.0, top, 18.0)
		var strip := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(38.0, 1.6, 3.0)
		strip.mesh = mesh
		strip.material_override = amber
		strip.position = Vector3(x, 20.6, z + 20.0)
		add_child(strip)


func _build_turret() -> void:
	var packed: PackedScene = load("res://assets/models/turret_construct.glb")
	if packed == null:
		push_warning("turret_construct.glb missing")
		return
	var turret := packed.instantiate()
	turret.position = Vector3((3 - (COLS - 1) * 0.5) * TILE, 7.0, (9 - (ROWS - 1) * 0.5) * TILE)
	add_child(turret)


func _build_camera() -> Camera3D:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 620.0
	cam.position = Vector3(0.0, 900.0, 900.0)
	cam.rotation_degrees = Vector3(-45.0, 0.0, 0.0)
	cam.near = 100.0
	cam.far = 4000.0
	add_child(cam)
	cam.current = true
	return cam
