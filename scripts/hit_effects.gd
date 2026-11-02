extends Node2D

## 轻量命中特效：方块被击中时溅出火花，击碎时火花更大并附带金币碎屑。
## 使用手写粒子而不是 CPUParticles2D，方便按方块颜色动态着色。

const Palette = preload("res://scripts/palette.gd")

const MAX_PARTICLES := 420

var _particles: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	z_index = 6
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func emit_hit(pos: Vector2, color: Color, destroyed: bool) -> void:
	var count := 24 if destroyed else 9
	for i in count:
		_spawn(pos, color, destroyed, false)
	if destroyed:
		# 金币碎屑
		for i in 5:
			_spawn(pos, Palette.ACCENT, true, true)

	# 中心闪光
	var flash_life := 0.22 if destroyed else 0.14
	_flashes.append({
		"pos": pos,
		"life": flash_life,
		"max_life": flash_life,
		"color": color.lerp(Color.WHITE, 0.35),
		"radius": 30.0 if destroyed else 17.0,
	})
	while _flashes.size() > 40:
		_flashes.pop_front()
	queue_redraw()


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

	if _particles.is_empty():
		queue_redraw()
		return
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
	queue_redraw()


func _draw() -> void:
	for f in _flashes:
		var ft := clampf(float(f.life) / float(f.max_life), 0.0, 1.0)
		var radius := float(f.radius) * (1.35 - 0.35 * ft)
		var flash_col: Color = f.color
		flash_col.a = 0.20 * ft
		draw_circle(f.pos, radius, flash_col)
		draw_arc(f.pos, radius, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.55 * ft), 2.0)

	for p in _particles:
		var t := clampf(float(p.life) / float(p.max_life), 0.0, 1.0)
		var col: Color = p.color
		col.a = t
		var size := float(p.size) * (0.4 + 0.6 * t)
		var pos: Vector2 = p.pos
		var vel: Vector2 = p.vel
		if bool(p.coin):
			draw_circle(pos, size * 0.8, col)
			draw_arc(pos, size * 0.8, 0.0, TAU, 12, Color(1.0, 1.0, 1.0, t * 0.6), 1.0)
		else:
			if vel.length_squared() > 1.0:
				draw_line(pos, pos - vel.normalized() * size * 3.0, col, maxf(1.0, size))
			draw_circle(pos, size * 0.6, col)
