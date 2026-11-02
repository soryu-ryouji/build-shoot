extends Node2D

## 固定在底部的炮塔：鼠标/触摸瞄准，点击或空格发射。

const Palette = preload("res://scripts/palette.gd")

const BARREL_LENGTH := 54.0
const AIM_MIN := -PI + 0.12
const AIM_MAX := -0.12

var game: Node
var aim_angle := -PI / 2.0

var _recoil := 0.0


func _ready() -> void:
	position = Vector2(360.0, 772.0)
	queue_redraw()


func _process(delta: float) -> void:
	_recoil = maxf(0.0, _recoil - delta * 6.0)
	queue_redraw()


func get_muzzle() -> Vector2:
	return global_position + Vector2.from_angle(aim_angle) * BARREL_LENGTH


func play_recoil() -> void:
	_recoil = 1.0


func _unhandled_input(event: InputEvent) -> void:
	# 只调整方向，开火由 main 的自动射击驱动
	if event is InputEventMouseMotion:
		_aim_at(event.position)
	elif event is InputEventMouseButton:
		if event.pressed:
			_aim_at(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_aim_at(event.position)
	elif event is InputEventScreenDrag:
		_aim_at(event.position)


func _aim_at(target: Vector2) -> void:
	var d := target - global_position
	if d.length_squared() < 4.0:
		return
	var a := d.angle()
	if d.y >= 0.0:
		a = AIM_MAX if d.x >= 0.0 else AIM_MIN
	aim_angle = clampf(a, AIM_MIN, AIM_MAX)


## 预测射线：用来画瞄准虚线，撞到方块/反射板/墙就停。
func _predict(origin: Vector2, direction: Vector2) -> Vector2:
	var play_rect: Rect2 = game.get_play_rect()
	var p := origin
	var step := 5.0
	for i in 320:
		p += direction * step
		if p.x <= play_rect.position.x or p.x >= play_rect.end.x:
			return p
		if p.y <= play_rect.position.y:
			return p
		for b in game.blocks.blocks:
			var block_rect: Rect2 = b.rect
			if bool(b.alive) and block_rect.has_point(p):
				return p
	return p


func _draw() -> void:
	var aim_dir := Vector2.from_angle(aim_angle)
	var local_origin := aim_dir * BARREL_LENGTH
	var global_origin := global_position + local_origin
	var hit_global := _predict(global_origin, aim_dir)
	var hit := hit_global - global_position
	var dist := local_origin.distance_to(hit)
	var dots := mini(int(dist / 18.0), 80)
	for i in dots:
		var t := float(i) / float(maxi(dots, 1))
		var p := local_origin + aim_dir * (i * 18.0 + 10.0)
		var alpha := 0.42 * (1.0 - t * 0.75)
		draw_circle(p, lerpf(2.6, 1.1, t), Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, alpha))
	if dots > 0:
		draw_arc(hit, 10.0, 0.0, TAU, 24, Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.7), 1.5)
		draw_circle(hit, 2.0, Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.85))

	# 炮塔底座
	draw_circle(Vector2.ZERO, 34.0, Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.06))
	draw_circle(Vector2.ZERO, 26.0, Color("101a2b"))
	draw_arc(Vector2.ZERO, 25.0, 0.0, TAU, 48, Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.75), 2.0)
	draw_circle(Vector2.ZERO, 10.0, Palette.ACCENT)
	draw_circle(Vector2.ZERO, 4.5, Color(1.0, 1.0, 1.0, 0.85))

	# 炮管
	draw_set_transform(Vector2.ZERO, aim_angle, Vector2.ONE)
	var recoil := -7.0 * _recoil
	var barrel := Rect2(Vector2(6.0 + recoil, -10.0), Vector2(BARREL_LENGTH - 8.0, 20.0))
	draw_rect(barrel.grow(2.0), Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.16))
	draw_rect(barrel, Color("1b2638"))
	draw_rect(barrel.grow(-3.0), Color("34455e"))
	draw_rect(Rect2(Vector2(BARREL_LENGTH - 13.0 + recoil, -11.0), Vector2(9.0, 22.0)), Palette.ACCENT)
	draw_circle(Vector2(BARREL_LENGTH - 3.0 + recoil, 0.0), 4.0, Color(1.0, 0.9, 0.6, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
