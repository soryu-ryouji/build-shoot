extends Node2D

## 无限地图炮弹：分步移动 + 圆-矩形碰撞，可攻击敌人与巢穴。

const Palette = preload("res://scripts/palette.gd")

## pierce 取这个值时不限穿透次数，每命中一个目标消耗对应血量所需的威力
const PIERCE_UNLIMITED := -1

var game: Node
var dir := Vector2.UP
var speed := 520.0
var radius := 7.0
var damage := 1  # 单次伤害；无限穿透时同时作为剩余威力预算
var pierce := 0  # 剩余穿透次数；PIERCE_UNLIMITED 表示按威力预算无限穿透
var bounces_left := 6
var max_bounces := 6
var alive := true
## 压缩塔增益后的炮弹：带电击特效果，伤害已在发射时翻倍
var electric := false

var _ignored := {}
var _trail: Array[Vector2] = []
var _life := 0.0


func setup(
	g: Node,
	start_pos: Vector2,
	start_dir: Vector2,
	p_speed: float,
	p_radius: float,
	p_damage: int,
	p_pierce: int,
	p_bounces: int,
	p_electric: bool = false
) -> void:
	game = g
	position = start_pos
	dir = start_dir.normalized()
	speed = p_speed
	radius = p_radius
	damage = p_damage
	pierce = p_pierce
	bounces_left = p_bounces
	max_bounces = maxi(p_bounces, 1)
	electric = p_electric
	_trail = [start_pos, start_pos]


func _ready() -> void:
	z_index = 5
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not alive or game == null:
		return

	_life += delta
	if _life > 20.0:
		_vanish()
		return

	# 单步位移不超过半径的一半，避免高速穿模
	var travel := speed * delta
	var max_step := maxf(1.5, radius * 0.5)
	var guard := 0
	while travel > 0.0001 and guard < 160:
		guard += 1
		var step := minf(max_step, travel)
		_advance(step)
		travel -= step
		if not alive:
			return

	_trail.push_back(position)
	if _trail.size() > 10:
		_trail.pop_front()
	queue_redraw()


func _advance(dist: float) -> void:
	position += dir * dist

	# 穿透忽略列表按实际目标更新，避免局部查询下残留已离开的目标。
	for bid in _ignored.keys():
		var previous: Dictionary = game.get_target_by_id(bid)
		if previous.is_empty() or not bool(previous.get("alive", false)) or not _overlaps(previous.rect):
			_ignored.erase(bid)

	# 查询区域覆盖附近格，扩张量包含敌人与巢穴的最大半尺寸。
	var extent := Vector2(radius + 38.0, radius + 34.0)
	var block_list: Array = game.blocks.query_rect(Rect2(position - extent, extent * 2.0))
	block_list.append_array(game.get_nest_targets())
	var count := block_list.size()
	for i in count:
		if not alive:
			return
		var b: Dictionary = block_list[i]
		if not bool(b.alive):
			continue
		var bid := int(b.id)
		var rect: Rect2 = b.rect
		var overlapping := _overlaps(rect)

		if _ignored.has(bid):
			if not overlapping:
				_ignored.erase(bid)
			continue
		if not overlapping:
			continue

		if pierce == PIERCE_UNLIMITED:
			# 威力即穿透预算：目标吃下多少血就扣多少威力，预算耗尽后停在原地
			var absorbed := mini(damage, int(b.hp))
			damage -= absorbed
			_ignored[bid] = true
			game.hit_target(b, absorbed, position, electric)
			if damage <= 0:
				_spend_bounce()
				return
			continue
		if pierce > 0:
			# 穿透不消耗弹跳次数，穿过期间忽略这块，直到完全离开
			pierce -= 1
			_ignored[bid] = true
			game.hit_target(b, damage, position, electric)
		else:
			var reflected := _resolve_rect(rect)
			game.hit_target(b, damage, position, electric)
			if reflected:
				_spend_bounce()
				if not alive:
					return


func _overlaps(rect: Rect2) -> bool:
	var closest := Vector2(
		clampf(position.x, rect.position.x, rect.end.x),
		clampf(position.y, rect.position.y, rect.end.y)
	)
	return position.distance_squared_to(closest) < radius * radius


## 返回 true 表示发生了反弹（消耗一次弹跳），false 表示只是被推出。
func _resolve_rect(rect: Rect2) -> bool:
	var closest := Vector2(
		clampf(position.x, rect.position.x, rect.end.x),
		clampf(position.y, rect.position.y, rect.end.y)
	)
	var delta := position - closest

	if delta.length_squared() < 0.0001:
		# 圆心陷进矩形内部：沿最短方向推出
		var left := position.x - rect.position.x
		var right := rect.end.x - position.x
		var top := position.y - rect.position.y
		var bottom := rect.end.y - position.y
		var m := minf(minf(left, right), minf(top, bottom))
		if m == left:
			position.x = rect.position.x - radius
			dir.x = -absf(dir.x)
		elif m == right:
			position.x = rect.end.x + radius
			dir.x = absf(dir.x)
		elif m == top:
			position.y = rect.position.y - radius
			dir.y = -absf(dir.y)
		else:
			position.y = rect.end.y + radius
			dir.y = absf(dir.y)
		return true

	var normal := delta.normalized()
	var pen := radius - delta.length()
	if pen <= 0.0:
		return false
	position += normal * (pen + 0.5)
	if dir.dot(normal) < 0.0:
		dir = dir.bounce(normal)
		return true
	return false


func _spend_bounce() -> void:
	bounces_left -= 1
	if bounces_left <= 0:
		_vanish()


func _vanish() -> void:
	if not alive:
		return
	alive = false
	queue_free()


func _draw() -> void:
	if not alive:
		return

	var glow := Color(0.50, 0.90, 1.0) if electric else Color(1.0, 0.82, 0.4)
	var core := Color(0.78, 0.98, 1.0) if electric else Palette.BALL

	# _trail 存的是全局坐标，绘制时要转换成本地坐标
	for i in _trail.size():
		var t := float(i) / float(_trail.size())
		draw_circle(_trail[i] - position, radius * (0.45 + 0.45 * t), Color(glow.r, glow.g, glow.b, 0.04 + t * 0.16))
	draw_line(Vector2.ZERO, -dir * 22.0, Color(glow.r, glow.g, glow.b, 0.22), maxf(2.0, radius * 0.6))
	draw_circle(Vector2.ZERO, radius + 6.0, Color(glow.r, glow.g, glow.b, 0.07))
	draw_circle(Vector2.ZERO, radius + 2.0, Color(glow.r, glow.g, glow.b, 0.18))
	draw_circle(Vector2.ZERO, radius, core)
	draw_circle(Vector2.ZERO, radius * 0.5, Color(1.0, 1.0, 1.0, 0.9))

	if electric:
		# 三簇短电弧，跟着球体旋转抖动
		for k in 3:
			var a := _life * 26.0 + k * TAU / 3.0
			var p1 := Vector2.from_angle(a) * (radius + 1.0)
			var p2 := Vector2.from_angle(a + 0.35) * (radius + 6.0)
			var p3 := Vector2.from_angle(a + 0.12) * (radius + 10.0)
			draw_polyline(PackedVector2Array([p1, p2, p3]), Color(0.74, 0.97, 1.0, 0.75), 1.4)
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 20, Color(0.62, 0.94, 1.0, 0.40), 1.0)

	# 剩余弹跳次数：外圈进度弧，少于 3 次时变红
	if max_bounces > 0:
		var ratio := clampf(float(bounces_left) / float(max_bounces), 0.0, 1.0)
		var ring_col := Palette.CYAN if bounces_left > 2 else Palette.DANGER
		draw_arc(Vector2.ZERO, radius + 4.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 24, Color(ring_col.r, ring_col.g, ring_col.b, 0.65), 1.5)
