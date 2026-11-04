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

	_build_road()
	_build_rim()
	_build_gates()
	_build_core()
	_build_props()


## 地坪上的装饰性方格：面板、米白块、琥珀边、通风格栅、检修口、导轨、角灯
func _decorate_tile(p: Vector3, variant: int) -> void:
	var y := TILE_TOP
	if variant < 14:
		_add_box(p + Vector3(0.0, y + 0.6, 0.0), Vector3(32.0, 1.2, 32.0), _materials["plate"])
	elif variant < 26:
		_add_box(p + Vector3(0.0, y + 0.7, 0.0), Vector3(26.0, 1.4, 26.0), _materials["cream"])
	elif variant < 38:
		_add_box(p + Vector3(0.0, y + 0.5, 18.0), Vector3(34.0, 0.8, 2.4), _materials["amber"])
	elif variant < 50:
		# 通风格栅
		_add_box(p + Vector3(0.0, y + 0.5, 0.0), Vector3(28.0, 1.0, 20.0), _materials["base"])
		for i in 3:
			_add_box(p + Vector3(-8.0 + i * 8.0, y + 1.1, 0.0), Vector3(4.0, 0.8, 16.0), _materials["steel"])
	elif variant < 62:
		# 检修口 + 琥珀标记
		_add_box(p + Vector3(0.0, y + 1.2, 0.0), Vector3(22.0, 2.4, 18.0), _materials["plate"])
		_add_box(p + Vector3(0.0, y + 2.6, -6.0), Vector3(14.0, 0.8, 2.0), _materials["amber"])
	elif variant < 74:
		# 两条导轨
		for i in 2:
			_add_box(p + Vector3(0.0, y + 1.0, -7.0 + i * 14.0), Vector3(38.0, 1.6, 2.4), _materials["steel"])
	elif variant < 86:
		# 四角指示灯
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_add_box(p + Vector3(sx * 16.0, y + 0.7, sz * 16.0), Vector3(5.0, 1.0, 5.0), _materials["amber"])
	else:
		# 小平台 + 米白顶
		_add_box(p + Vector3(0.0, y + 2.0, 0.0), Vector3(26.0, 4.0, 26.0), _materials["side"])
		_add_box(p + Vector3(0.0, y + 4.4, 0.0), Vector3(20.0, 1.2, 20.0), _materials["cream"])


## 场地外的低模装饰：货箱、管线、通风机，按格子坐标固定散开
func _build_props() -> void:
	for row in range(-3, BattleMap.ROWS + 3):
		for col in range(-3, BattleMap.COLS + 3):
			if col >= -1 and col <= BattleMap.COLS and row >= -1 and row <= BattleMap.ROWS:
				continue
			if absi(col * 31 + row * 17 + col * row * 5) % 100 >= 24:
				continue
			var p := tile_position(Vector2i(col, row))
			match absi(col * 13 + row * 29) % 3:
				0:
					_crate(_root, p + Vector3(-6.0, 6.0, -4.0), Vector3(16.0, 12.0, 14.0), _materials["deck"])
					_crate(_root, p + Vector3(8.0, 5.0, 3.0), Vector3(13.0, 10.0, 12.0), _materials["deck_alt"])
					_crate(_root, p + Vector3(-5.0, 12.5, -4.0), Vector3(12.0, 1.0, 10.0), _materials["cream"])
				1:
					for i in 2:
						var pipe := CylinderMesh.new()
						pipe.top_radius = 4.0
						pipe.bottom_radius = 4.0
						pipe.height = 30.0
						pipe.radial_segments = 12
						var node := MeshInstance3D.new()
						node.mesh = pipe
						node.material_override = _materials["steel"]
						node.position = p + Vector3(0.0, 6.0, -5.0 + i * 9.0)
						node.rotation_degrees = Vector3(0.0, 0.0, 90.0)
						_root.add_child(node)
				2:
					_crate(_root, p + Vector3(0.0, 5.0, 0.0), Vector3(24.0, 10.0, 18.0), _materials["deck"])
					for i in 3:
						_crate(_root, p + Vector3(-8.0 + i * 8.0, 11.0, 0.0), Vector3(4.0, 2.0, 12.0), _materials["steel"])


## 路径：比地坪略亮的走道 + 琥珀虚线，不用黑色
func _build_road() -> void:
	var half := 14.0
	for segment in BattleMap.segments():
		var a: Vector2 = segment[0]
		var b: Vector2 = segment[1]
		var pa := _world_from_screen(a)
		var pb := _world_from_screen(b)
		var center := (pa + pb) * 0.5
		var length := pa.distance_to(pb)
		var angle := atan2(pb.z - pa.z, pb.x - pa.x)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(length + 28.0, 0.7, half * 2.0)
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = _materials["lane"]
		node.position = Vector3(center.x, TILE_TOP + 0.35, center.z)
		node.rotation.y = -angle
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(node)

		# 走道两侧的琥珀细边，比黑带更接近工业地坪的分道线
		for side: float in [-1.0, 1.0]:
			var normal: Vector2 = Vector2(-(pb.z - pa.z), pb.x - pa.x).normalized() * (half - 1.5) * side
			var edge := BoxMesh.new()
			edge.size = Vector3(length + 26.0, 0.4, 1.1)
			var edge_node := MeshInstance3D.new()
			edge_node.mesh = edge
			edge_node.material_override = _materials["lane_edge"]
			edge_node.position = Vector3(center.x + normal.x, TILE_TOP + 0.75, center.z + normal.y)
			edge_node.rotation.y = -angle
			edge_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_root.add_child(edge_node)

		# 中线琥珀虚线
		var dir := Vector2(pb.x - pa.x, pb.z - pa.z)
		var dash_len := 7.0
		var gap := 46.0
		var travelled := gap * 0.5
		while travelled + dash_len < length:
			var t := (travelled + dash_len * 0.5) / length
			var pos := pa + Vector3(dir.x, 0.0, dir.y) * t
			var dash := BoxMesh.new()
			dash.size = Vector3(dash_len, 0.4, 1.8)
			var dash_node := MeshInstance3D.new()
			dash_node.mesh = dash
			dash_node.material_override = _materials["amber"]
			dash_node.position = Vector3(pos.x, TILE_TOP + 0.85, pos.z)
			dash_node.rotation.y = -angle
			dash_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_root.add_child(dash_node)
			travelled += gap


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


func _build_gates() -> void:
	for gate in BattleMap.gates():
		var p := tile_position(gate)
		_add_box(p + Vector3(0.0, TILE_TOP + 0.8, 0.0), Vector3(36.0, 1.6, 36.0), _materials["red"])


func _build_core() -> void:
	var center := BattleMap.core_center()
	var p := _world_from_screen(center)
	var disc := CylinderMesh.new()
	disc.top_radius = 40.0
	disc.bottom_radius = 40.0
	disc.height = 8.0
	var node := MeshInstance3D.new()
	node.mesh = disc
	node.material_override = _materials["side"]
	node.position = Vector3(p.x, TILE_TOP + 4.0, p.z)
	_root.add_child(node)
	var inner := CylinderMesh.new()
	inner.top_radius = 24.0
	inner.bottom_radius = 24.0
	inner.height = 3.0
	var glow := MeshInstance3D.new()
	glow.mesh = inner
	glow.material_override = _materials["cyan"]
	glow.position = Vector3(p.x, TILE_TOP + 8.5, p.z)
	_root.add_child(glow)


## 2D 世界坐标（设计稿像素）→ 3D 地面坐标
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