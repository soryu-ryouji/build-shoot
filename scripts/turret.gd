extends Node2D

## 自动炮塔：锁定目标、平滑转向、自动开火。玩家不再控制方向。

const Palette = preload("res://scripts/palette.gd")

const BARREL_LENGTH := 54.0
const AIM_MIN := -PI + 0.02
const AIM_MAX := -0.02
const TURN_SPEED := 14.0
const LOCK_TOLERANCE := 0.05

var game: Node
var aim_angle := -PI / 2.0
var has_target := false
var target_pos := Vector2.ZERO
var target_angle := -PI / 2.0

var _recoil := 0.0
var _time := 0.0


func _ready() -> void:
	position = Vector2(360.0, 772.0)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_recoil = maxf(0.0, _recoil - delta * 6.0)
	if has_target:
		aim_angle = lerp_angle(aim_angle, target_angle, clampf(delta * TURN_SPEED, 0.0, 1.0))
		aim_angle = clampf(aim_angle, AIM_MIN, AIM_MAX)
	queue_redraw()


func set_target(pos: Vector2) -> void:
	target_pos = pos
	target_angle = clampf((pos - global_position).angle(), AIM_MIN, AIM_MAX)
	has_target = true


func clear_target() -> void:
	has_target = false


func is_locked() -> bool:
	if not has_target:
		return false
	var diff := wrapf(aim_angle - target_angle, -PI, PI)
	return absf(diff) <= LOCK_TOLERANCE


func get_muzzle() -> Vector2:
	return global_position + Vector2.from_angle(aim_angle) * BARREL_LENGTH


func play_recoil() -> void:
	_recoil = 1.0


## 预测射线：用来画瞄准虚线，撞到方块或墙就停。
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

	# 锁定环
	if has_target:
		var lock := target_pos - global_position
		var pulse := 0.5 + 0.5 * sin(_time * 6.0)
		draw_arc(lock, 24.0 + pulse * 2.0, 0.0, TAU, 32, Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.45 + pulse * 0.25), 1.5)
		for k in 4:
			var a := k * PI / 2.0
			draw_line(
				lock + Vector2.from_angle(a) * 19.0,
				lock + Vector2.from_angle(a) * 27.0,
				Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.6),
				1.5
			)

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
