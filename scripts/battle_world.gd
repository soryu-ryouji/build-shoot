extends SubViewport

## 真 3D 战场：8×13 的格子用 3D 网格铺出来，方向光 + 阴影。
## 正交相机俯角 45°、1 世界单位 = 1 像素，投影与旧 2.5D 完全一致：
## 3D 点 (x, 0, z) 投到设计稿的 (field_center.x + x, field_center.y + z·cos45)。

const BattleMap = preload("res://scripts/battle_map.gd")

const DESIGN_SIZE := Vector2i(720, 960)
const TILE := 48.0
const COS45 := 0.70710678
const TILE_TOP := 5.0
const HIGH_TOP := 18.0
const RIM_HEIGHT := 30.0

var _root: Node3D
var _cam: Camera3D
var _materials: Dictionary = {}


func _ready() -> void:
	size = DESIGN_SIZE
	own_world_3d = true
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	msaa_3d = Viewport.MSAA_2X

	_root = Node3D.new()
	_root.name = "World"
	add_child(_root)
	_make_materials()
	_build_environment()
	_build_camera()
	_build_map()


func _make_materials() -> void:
	_materials = {
		"deck": _material(Color(0.235, 0.250, 0.265), 0.48, 0.45),
		"deck_alt": _material(Color(0.205, 0.220, 0.235), 0.52, 0.45),
		"plate": _material(Color(0.330, 0.345, 0.360), 0.42, 0.40),
		"cream": _material(Color(0.560, 0.550, 0.505), 0.5, 0.20),
		"side": _material(Color(0.120, 0.130, 0.140), 0.42, 0.55),
		"steel": _material(Color(0.460, 0.480, 0.495), 0.30, 0.85),
		"amber": _emissive(Color(0.880, 0.550, 0.140), 0.35),
		"red": _emissive(Color(0.900, 0.150, 0.100), 1.6),
		"cyan": _emissive(Color(0.360, 0.820, 0.860), 1.2),
		"road": _material(Color(0.075, 0.082, 0.092), 0.55, 0.30),
		"lane": _material(Color(0.330, 0.325, 0.305), 0.5, 0.3),
		"lane_edge": _material(Color(0.760, 0.560, 0.250), 0.4, 0.3),
		"base": _material(Color(0.060, 0.068, 0.078), 0.65, 0.25),
	}


func _material(color: Color, rough: float, metal: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	return mat


func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.roughness = 0.35
	mat.metallic = 0.2
	return mat


func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.030, 0.035, 0.042)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46, 0.52, 0.60)
	env.ambient_light_energy = 0.5
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		env.ssao_enabled = true
		env.ssao_radius = 1.6
		env.ssao_intensity = 2.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = env
	_root.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-56.0, -38.0, 0.0)
	sun.light_energy = 1.7
	sun.light_color = Color(1.0, 0.96, 0.89)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 2400.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_blend_splits = true
	_root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-32.0, 150.0, 0.0)
	fill.light_energy = 0.5
	fill.light_color = Color(0.60, 0.72, 0.92)
	_root.add_child(fill)


func _build_camera() -> void:
	_cam = Camera3D.new()
	_cam.name = "Cam"
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = float(DESIGN_SIZE.y)
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.near = 200.0
	_cam.far = 4000.0
	_cam.position = Vector3(0.0, 1200.0, 1200.0)
	_cam.rotation_degrees = Vector3(-45.0, 0.0, 0.0)
	_root.add_child(_cam)
	_cam.current = true


## 格子中心 → 3D 坐标（格子 (0,0) 在西北角）
func tile_position(tile: Vector2i) -> Vector3:
	return Vector3((tile.x - (BattleMap.COLS - 1) * 0.5) * TILE, 0.0, (tile.y - (BattleMap.ROWS - 1) * 0.5) * TILE)


func _add_box(center: Vector3, size: Vector3, mat: StandardMaterial3D, shadows := true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = center
	if not shadows:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(node)
	return node


func _build_map() -> void:
	var field_w := BattleMap.COLS * TILE
	var field_h := BattleMap.ROWS * TILE
	# 地基
	_add_box(Vector3(0.0, -6.0, 0.0), Vector3(field_w + 120.0, 12.0, field_h + 120.0), _materials["base"])

	for row in BattleMap.ROWS:
		for col in BattleMap.COLS:
			var tile := Vector2i(col, row)
			var p := tile_position(tile)
			var variant := absi(col * 7 + row * 13 + col * row * 3) % 100
			if BattleMap.is_high(tile):
				_add_box(p + Vector3(0.0, HIGH_TOP * 0.5, 0.0), Vector3(46.0, HIGH_TOP, 46.0), _materials["side"])
				_add_box(p + Vector3(0.0, HIGH_TOP + 1.2, 0.0), Vector3(46.0, 2.4, 46.0), _materials["plate"])
				_add_box(p + Vector3(0.0, HIGH_TOP + 2.6, 0.0), Vector3(30.0, 1.0, 30.0), _materials["cream"])
				_add_box(p + Vector3(0.0, HIGH_TOP + 2.0, 21.0), Vector3(38.0, 1.2, 3.0), _materials["amber"])
			else:
				_add_box(p + Vector3(0.0, TILE_TOP * 0.5, 0.0), Vector3(46.0, TILE_TOP, 46.0),
					_materials["deck"] if variant < 55 else _materials["deck_alt"])
				_decorate_tile(p, variant)

	_build_rim()
	_build_gates()
	_build_core()
	_build_props()


## 地坪装饰：Blender 建模的构成主义浮雕贴片，按格子坐标固定散开
const INLAY_SCENES := [
	"res://assets/models/inlays/inlay_diag.glb",
	"res://assets/models/inlays/inlay_step.glb",
	"res://assets/models/inlays/inlay_l.glb",
	"res://assets/models/inlays/inlay_split.glb",
	"res://assets/models/inlays/inlay_corner.glb",
]


func _decorate_tile(p: Vector3, variant: int) -> void:
	if variant < 62:
		return
	var index := (variant - 62) % INLAY_SCENES.size()
	var packed: PackedScene = load(INLAY_SCENES[index])
	if packed == null:
		return
	var inlay := packed.instantiate()
	inlay.position = Vector3(p.x, TILE_TOP, p.z)
	inlay.scale = Vector3.ONE * 0.92
	inlay.rotation_degrees = Vector3(0.0, float((variant * 3) % 4) * 90.0, 0.0)
	_root.add_child(inlay)

## 场地外的装饰：Blender 建模的构成主义物件（铆接货箱 / 斜碑 / 管束）
const PROP_SCENES := [
	"res://assets/models/prop_crate.glb",
	"res://assets/models/prop_monolith.glb",
	"res://assets/models/prop_pipes.glb",
]


func _build_props() -> void:
	for row in range(-3, BattleMap.ROWS + 3):
		for col in range(-3, BattleMap.COLS + 3):
			if col >= -1 and col <= BattleMap.COLS and row >= -1 and row <= BattleMap.ROWS:
				continue
			if absi(col * 31 + row * 17 + col * row * 5) % 100 >= 26:
				continue
			var p := tile_position(Vector2i(col, row))
			var index := absi(col * 13 + row * 29) % PROP_SCENES.size()
			var packed: PackedScene = load(PROP_SCENES[index])
			if packed == null:
				continue
			var prop := packed.instantiate()
			prop.position = Vector3(p.x, 0.0, p.z)
			prop.rotation_degrees = Vector3(0.0, (absi(col * 7 + row * 11) % 4) * 90.0, 0.0)
			_root.add_child(prop)

	# 边框矮墙顶上再摆几件，让画面的上下边缘也有东西
	for row in range(-1, BattleMap.ROWS + 1):
		for col in range(-1, BattleMap.COLS + 1):
			var on_edge := col == -1 or col == BattleMap.COLS or row == -1 or row == BattleMap.ROWS
			if not on_edge:
				continue
			if absi(col * 19 + row * 23) % 100 >= 34:
				continue
			var packed: PackedScene = load(PROP_SCENES[absi(col * 11 + row * 7) % PROP_SCENES.size()])
			if packed == null:
				continue
			var edge_prop := packed.instantiate()
			var p2 := tile_position(Vector2i(col, row))
			edge_prop.position = Vector3(p2.x, RIM_HEIGHT, p2.z)
			edge_prop.scale = Vector3.ONE * 0.8
			edge_prop.rotation_degrees = Vector3(0.0, (absi(col * 5 + row * 3) % 4) * 90.0, 0.0)
			_root.add_child(edge_prop)

func _build_rim() -> void:
	var w := (BattleMap.COLS + 2) * TILE
	var h := (BattleMap.ROWS + 2) * TILE
	for col in range(-1, BattleMap.COLS + 1):
		for row in [-1, BattleMap.ROWS]:
			var p := tile_position(Vector2i(col, row))
			_add_box(p + Vector3(0.0, RIM_HEIGHT * 0.5, 0.0), Vector3(48.0, RIM_HEIGHT, 48.0), _materials["side"])
			_add_box(p + Vector3(0.0, RIM_HEIGHT + 1.2, 0.0), Vector3(46.0, 2.4, 46.0), _materials["plate"])
			_add_box(p + Vector3(0.0, RIM_HEIGHT - 4.0, 24.0), Vector3(40.0, 2.2, 2.0), _materials["amber"])
	for row in BattleMap.ROWS:
		for col in [-1, BattleMap.COLS]:
			var p := tile_position(Vector2i(col, row))
			_add_box(p + Vector3(0.0, RIM_HEIGHT * 0.5, 0.0), Vector3(48.0, RIM_HEIGHT, 48.0), _materials["side"])
			_add_box(p + Vector3(0.0, RIM_HEIGHT + 1.2, 0.0), Vector3(46.0, 2.4, 46.0), _materials["plate"])


## 半透明线框笼子：红色出怪口、蓝色核心，参考明日方舟的透明框
func _build_cage(center: Vector3, size: Vector3, tint: Color) -> void:
	var glass := BoxMesh.new()
	glass.size = size
	var node := MeshInstance3D.new()
	node.mesh = glass
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.10)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat
	node.position = center
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(node)

	var edge_mat := StandardMaterial3D.new()
	edge_mat.albedo_color = tint
	edge_mat.emission_enabled = true
	edge_mat.emission = tint
	edge_mat.emission_energy_multiplier = 0.8
	edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var hy := size.y * 0.5
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_bar(center + Vector3(sx * hx, 0.0, sz * hz), Vector3(1.2, size.y, 1.2), edge_mat)
	for sy in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_bar(center + Vector3(0.0, sy * hy, sz * hz), Vector3(size.x, 1.2, 1.2), edge_mat)
		for sx in [-1.0, 1.0]:
			_add_bar(center + Vector3(sx * hx, sy * hy, 0.0), Vector3(1.2, 1.2, size.z), edge_mat)


func _add_bar(pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(node)


func _build_gates() -> void:
	for gate in BattleMap.gates():
		var p := tile_position(gate)
		_build_cage(p + Vector3(0.0, TILE_TOP + 15.0, 0.0), Vector3(42.0, 30.0, 42.0), Color(0.95, 0.22, 0.16))


func _build_core() -> void:
	# 每格一个蓝色透明框，框里不再放圆盘
	for tile in BattleMap.core_tiles():
		var p := tile_position(tile)
		_build_cage(p + Vector3(0.0, TILE_TOP + 15.0, 0.0), Vector3(42.0, 30.0, 42.0), Color(0.25, 0.62, 1.0))


## 设计稿像素坐标 → 3D 地面坐标（正交相机下 x 不变，z 按 cos45 折算）
func _world_from_screen(pos: Vector2) -> Vector3:
	var field := BattleMap.field_rect()
	var center := field.get_center()
	return Vector3(pos.x - center.x, 0.0, (pos.y - center.y) / COS45)


## 2D 世界位置 → 3D 地面坐标（给建筑和敌人用）
func world_from_screen(pos: Vector2) -> Vector3:
	return _world_from_screen(pos)


## 造一个建筑的 3D 实体，返回可以旋转的根节点（炮塔按朝向转）
func create_building(item_id: String, screen_pos: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "Building3D_" + item_id
	var p := _world_from_screen(screen_pos)
	root.position = Vector3(p.x, TILE_TOP, p.z)
	match item_id:
		"turret", "heavy_turret", "laser_tower":
			_build_turret_model(root, item_id)
		"sandbag":
			_build_sandbag(root)
		"solar":
			_build_solar(root)
		"compression_tower":
			_build_compression(root)
		"fusion_tower":
			_build_fusion(root)
		_:
			_build_turret_model(root, "turret")
	_root.add_child(root)
	return root


func _build_turret_model(root: Node3D, item_id: String) -> void:
	var packed: PackedScene = load("res://assets/models/turret_construct.glb")
	if packed == null:
		return
	var model := packed.instantiate()
	var scale_factor := 1.0
	match item_id:
		"heavy_turret":
			scale_factor = 1.18
		"laser_tower":
			scale_factor = 1.05
	model.scale = Vector3.ONE * scale_factor
	root.add_child(model)


func _crate(root: Node3D, pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	root.add_child(node)
	return node


func _build_sandbag(root: Node3D) -> void:
	for i in 5:
		_crate(root, Vector3(-18.0 + i * 9.0, 5.0, 0.0), Vector3(10.0, 9.0, 12.0), _materials["cream"])
	_crate(root, Vector3(0.0, 2.0, 0.0), Vector3(44.0, 3.0, 18.0), _materials["side"])


func _build_solar(root: Node3D) -> void:
	_crate(root, Vector3(0.0, 3.0, 0.0), Vector3(40.0, 5.0, 30.0), _materials["side"])
	var panel := _crate(root, Vector3(0.0, 12.0, 0.0), Vector3(38.0, 2.0, 28.0), _materials["cream"])
	panel.rotation.x = deg_to_rad(-18.0)


func _build_compression(root: Node3D) -> void:
	_crate(root, Vector3(0.0, 4.0, 0.0), Vector3(34.0, 8.0, 34.0), _materials["side"])
	var column := CylinderMesh.new()
	column.top_radius = 7.0
	column.bottom_radius = 9.0
	column.height = 30.0
	var node := MeshInstance3D.new()
	node.mesh = column
	node.material_override = _materials["steel"]
	node.position = Vector3(0.0, 22.0, 0.0)
	root.add_child(node)
	_crate(root, Vector3(0.0, 40.0, 0.0), Vector3(16.0, 10.0, 16.0), _materials["steel"])


func _build_fusion(root: Node3D) -> void:
	var body := CylinderMesh.new()
	body.top_radius = 12.0
	body.bottom_radius = 15.0
	body.height = 26.0
	var node := MeshInstance3D.new()
	node.mesh = body
	node.material_override = _materials["steel"]
	node.position = Vector3(0.0, 15.0, 0.0)
	root.add_child(node)
	var ring := CylinderMesh.new()
	ring.top_radius = 13.0
	ring.bottom_radius = 13.0
	ring.height = 2.6
	var glow := MeshInstance3D.new()
	glow.mesh = ring
	glow.material_override = _materials["amber"]
	glow.position = Vector3(0.0, 30.0, 0.0)
	root.add_child(glow)
	var cap := CylinderMesh.new()
	cap.top_radius = 9.0
	cap.bottom_radius = 9.0
	cap.height = 4.0
	var cap_node := MeshInstance3D.new()
	cap_node.mesh = cap
	cap_node.material_override = _materials["steel"]
	cap_node.position = Vector3(0.0, 34.0, 0.0)
	root.add_child(cap_node)


## 敌人：Sprite3D 立牌 + 地面阴影，由 blocks 每帧同步位置
var _enemies: Dictionary = {}


func spawn_enemy(id: int) -> void:
	if _enemies.has(id):
		return
	var sprite := Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 1.0
	sprite.shaded = false
	sprite.position = Vector3(0.0, 26.0, 0.0)
	_root.add_child(sprite)
	var shadow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(40.0, 28.0)
	shadow.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.03, 0.04, 0.42)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = mat
	shadow.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_root.add_child(shadow)
	_enemies[id] = {"sprite": sprite, "shadow": shadow}


func update_enemy(id: int, screen_pos: Vector2, texture: Texture2D, alpha: float) -> void:
	if not _enemies.has(id):
		return
	var entry: Dictionary = _enemies[id]
	var sprite: Sprite3D = entry["sprite"]
	var shadow: MeshInstance3D = entry["shadow"]
	var p := _world_from_screen(screen_pos)
	sprite.texture = texture
	sprite.position = Vector3(p.x, 26.0, p.z)
	sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
	shadow.position = Vector3(p.x, TILE_TOP + 0.7, p.z)
	shadow.visible = alpha > 0.15


func prune_enemies(alive_ids: Array) -> void:
	for id in _enemies.keys():
		if not alive_ids.has(id):
			var entry: Dictionary = _enemies[id]
			(entry["sprite"] as Node).queue_free()
			(entry["shadow"] as Node).queue_free()
			_enemies.erase(id)