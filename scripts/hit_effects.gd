extends Node2D

## 命中特效：逻辑仍使用轻量 Dictionary，绘制按火花、金币、闪光分三批。

const Palette = preload("res://scripts/palette.gd")

const MAX_PARTICLES := 420
const MAX_FLASHES := 40

const SPARK_SHADER := """
shader_type canvas_item;
render_mode unshaded, blend_add;
void fragment() {
	float body = 1.0 - smoothstep(0.12, 0.5, abs(UV.y - 0.5));
	float ends = 1.0 - smoothstep(0.46, 0.52, abs(UV.x - 0.5));
	COLOR = vec4(COLOR.rgb, COLOR.a * body * ends);
}
"""
const COIN_SHADER := """
shader_type canvas_item;
render_mode unshaded, blend_add;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float fill = 1.0 - smoothstep(0.65, 0.82, d);
	float ring = smoothstep(0.62, 0.74, d) * (1.0 - smoothstep(0.80, 0.96, d));
	COLOR = vec4(COLOR.rgb, COLOR.a * max(fill, ring * 0.6));
}
"""
const FLASH_SHADER := """
shader_type canvas_item;
render_mode unshaded, blend_add;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float fill = (1.0 - smoothstep(0.65, 1.0, d)) * 0.20;
	float ring = smoothstep(0.78, 0.90, d) * (1.0 - smoothstep(0.94, 1.04, d)) * 0.55;
	COLOR = vec4(COLOR.rgb, COLOR.a * (fill + ring));
}
"""

var _particles: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _sparks: MultiMesh
var _coins: MultiMesh
var _flashes_mesh: MultiMesh


func _ready() -> void:
	_rng.randomize()
	z_index = 6
	_sparks = _make_batch("SparkBatch", SPARK_SHADER)
	_coins = _make_batch("CoinBatch", COIN_SHADER)
	_flashes_mesh = _make_batch("FlashBatch", FLASH_SHADER)


func _make_batch(batch_name: String, shader_code: String) -> MultiMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = 0
	var node := MultiMeshInstance2D.new()
	node.name = batch_name
	node.multimesh = multimesh
	var shader := Shader.new()
	shader.code = shader_code
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	node.material = shader_material
	add_child(node)
	return multimesh


func emit_hit(pos: Vector2, color: Color, destroyed: bool) -> void:
	var count := 24 if destroyed else 9
	for i in count:
		_spawn(pos, color, destroyed, false)
	if destroyed:
		for i in 5:
			_spawn(pos, Palette.ACCENT, true, true)
	var flash_life := 0.22 if destroyed else 0.14
	_flashes.append({
		"pos": pos,
		"life": flash_life,
		"max_life": flash_life,
		"color": color.lerp(Color.WHITE, 0.35),
		"radius": 30.0 if destroyed else 17.0,
	})
	while _flashes.size() > MAX_FLASHES:
		_flashes.pop_front()


func count() -> int:
	return _particles.size()


func _spawn(pos: Vector2, color: Color, destroyed: bool, coin: bool) -> void:
	var angle := _rng.randf_range(0.0, TAU)
	var speed := _rng.randf_range(70.0, 240.0)
	if destroyed:
		speed *= 1.35
	var life := _rng.randf_range(0.22, 0.45)
	if destroyed:
		life = _rng.randf_range(0.35, 0.75)
	var size := _rng.randf_range(1.6, 3.6)
	if destroyed:
		size *= 1.15
	if coin:
		size = _rng.randf_range(2.4, 4.0)
	_particles.append({
		"pos": pos,
		"vel": Vector2.from_angle(angle) * speed,
		"life": life,
		"max_life": life,
		"size": size,
		"color": color,
		"coin": coin,
	})
	while _particles.size() > MAX_PARTICLES:
		_particles.pop_front()


func _process(delta: float) -> void:
	if not _flashes.is_empty():
		var flashes: Array[Dictionary] = []
		for f in _flashes:
			f.life = float(f.life) - delta
			if float(f.life) > 0.0:
				flashes.append(f)
		_flashes = flashes

	if not _particles.is_empty():
		var alive: Array[Dictionary] = []
		for p in _particles:
			var life := float(p.life) - delta
			if life <= 0.0:
				continue
			p.life = life
			var vel: Vector2 = p.vel
			vel.y += 380.0 * delta
			vel *= maxf(0.0, 1.0 - 2.5 * delta)
			p.vel = vel
			p.pos = Vector2(p.pos) + vel * delta
			alive.append(p)
		_particles = alive
	_sync_batches()


func _sync_batches() -> void:
	# 先提供写入容量，最后再收缩到各批实际数量。
	_sparks.instance_count = _particles.size()
	_coins.instance_count = _particles.size()
	var spark_count := 0
	var coin_count := 0
	for p in _particles:
		var t := clampf(float(p.life) / float(p.max_life), 0.0, 1.0)
		var col: Color = p.color
		col.a *= t
		var size := float(p.size) * (0.4 + 0.6 * t)
		var pos: Vector2 = p.pos
		if bool(p.coin):
			var diameter := size * 1.6
			_coins.set_instance_transform_2d(coin_count, Transform2D(Vector2.RIGHT * diameter, Vector2.DOWN * diameter, pos))
			_coins.set_instance_color(coin_count, col)
			coin_count += 1
			continue
		var vel: Vector2 = p.vel
		var direction := vel.normalized() if vel.length_squared() > 1.0 else Vector2.RIGHT
		var length := maxf(1.0, size * 3.0)
		var width := maxf(1.0, size)
		var axis_x := direction * length
		var axis_y := direction.orthogonal() * width
		_sparks.set_instance_transform_2d(spark_count, Transform2D(axis_x, axis_y, pos - direction * length * 0.35))
		_sparks.set_instance_color(spark_count, col)
		spark_count += 1
	_sparks.instance_count = spark_count
	_coins.instance_count = coin_count

	_flashes_mesh.instance_count = _flashes.size()
	for i in _flashes.size():
		var f: Dictionary = _flashes[i]
		var ft := clampf(float(f.life) / float(f.max_life), 0.0, 1.0)
		var radius := float(f.radius) * (1.35 - 0.35 * ft)
		var diameter := radius * 2.0
		_flashes_mesh.set_instance_transform_2d(i, Transform2D(Vector2.RIGHT * diameter, Vector2.DOWN * diameter, f.pos))
		var col: Color = f.color
		col.a = ft
		_flashes_mesh.set_instance_color(i, col)
	_flashes_mesh.instance_count = _flashes.size()
