extends Node2D

## 玩家花金币布置到场地上的自动炮塔：锁定射程内最近的方块并开火。

const Palette = preload("res://scripts/palette.gd")
const TurretVisuals = preload("res://scripts/turret_visuals.gd")

const TURN_SPEED := 10.0
const LOCK_TOLERANCE := 0.08

var game: Node
var item_id := ""
var name_key := ""
var desc_key := ""
var cost := 0
var damage := 1
var interval := 1.0
var attack_range := 360.0
var bounces := 0
var pierce := 0
var ball_speed := 620.0
var ball_radius := 7.0
var barrel_length := 48.0
var base_radius := 24.0
var color := Palette.CYAN

var shots := 0
var selected := false

var aim_angle := -PI / 2.0
var _time := 0.0
var _cooldown := 0.0
var _recoil := 0.0
var _has_target := false
var _target_pos := Vector2.ZERO


func setup(g: Node, item: Dictionary) -> void:
	game = g
	item_id = String(item.id)
	name_key = String(item.name_key)
	desc_key = String(item.desc_key)
	cost = int(item.cost)
	damage = int(item.damage)
	interval = float(item.interval)
	attack_range = float(item.range)
	bounces = int(item.bounces)
	pierce = int(item.pierce)
	ball_speed = float(item.speed)
	ball_radius = float(item.radius)
	barrel_length = float(item.barrel)
	base_radius = float(item.base)
	color = item.color
	z_index = 4


func get_display_name() -> String:
	return I18n.t(name_key)


func get_display_desc() -> String:
	return I18n.t(desc_key)


func get_refund() -> int:
	return int(cost * 0.5)


func has_target() -> bool:
	return _has_target


func get_effective_damage() -> int:
	return damage + maxi(0, int(game.stats.damage) - 1)


func get_effective_pierce() -> int:
	return pierce + int(game.stats.pierce)


func get_effective_bounces() -> int:
	return bounces + int(game.stats.bounces)


func get_effective_speed() -> float:
	return ball_speed * (float(game.stats.speed) / 520.0)


func get_effective_radius() -> float:
	return ball_radius + (float(game.stats.radius) - 7.0)


func get_muzzle() -> Vector2:
	return global_position + Vector2.from_angle(aim_angle) * barrel_length


func _process(delta: float) -> void:
	_time += delta
	_recoil = maxf(0.0, _recoil - delta * 6.0)
	_cooldown = maxf(0.0, _cooldown - delta)

	var target: Dictionary = game.blocks.get_nearest_target(global_position, attack_range)
	if target.is_empty():
		_has_target = false
		queue_redraw()
		return

	_has_target = true
	var rect: Rect2 = target.rect
	_target_pos = rect.get_center()
	var desired := (_target_pos - global_position).angle()
	aim_angle = lerp_angle(aim_angle, desired, clampf(delta * TURN_SPEED, 0.0, 1.0))

	if _cooldown <= 0.0:
		var diff := wrapf(aim_angle - desired, -PI, PI)
		if absf(diff) <= LOCK_TOLERANCE:
			_fire()

	queue_redraw()


func _fire() -> void:
	_cooldown = interval
	_recoil = 1.0
	shots += 1
	var dir := Vector2.from_angle(aim_angle)
	game.fire_item_ball(
		self,
		get_muzzle(),
		dir,
		get_effective_damage(),
		get_effective_pierce(),
		get_effective_bounces(),
		get_effective_speed(),
		get_effective_radius()
	)


func _draw() -> void:
	# 没有可锁定目标时不显示导引虚线和锁定环
	if _has_target:
		var aim_dir := Vector2.from_angle(aim_angle)
		var local_origin := aim_dir * barrel_length
		var global_origin := global_position + local_origin
		var hit_global := TurretVisuals.predict(game.blocks, game.get_play_rect(), global_origin, aim_dir)
		var hit := hit_global - global_position
		TurretVisuals.draw_aim(self, local_origin, aim_dir, hit)
		TurretVisuals.draw_lock(self, _target_pos - global_position, _time)

	if selected:
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.10), 1.5)
		draw_arc(Vector2.ZERO, base_radius + 3.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.65), 1.5)

	if item_id == "turret":
		TurretVisuals.draw_basic_body(self, aim_angle, base_radius, barrel_length, _recoil)
	else:
		TurretVisuals.draw_heavy_body(self, aim_angle, base_radius, barrel_length, _recoil, color, _time)
