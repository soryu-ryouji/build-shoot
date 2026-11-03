extends Node2D

## 场上建筑：火力（炮塔 / 重型炮塔 / 激光塔）、阵地（沙袋 / 压缩塔）、能源（太阳能电板 / 聚能塔）。
## 火力自动索敌开火；阵地拦截敌人并吸收伤害；能源提供全局能源。

const Palette = preload("res://scripts/palette.gd")
const ItemDefs = preload("res://scripts/item_defs.gd")
const TurretVisuals = preload("res://scripts/turret_visuals.gd")
const SandbagTexture = preload("res://assets/ui/sandbag_field.png")
const CompressionTexture = preload("res://assets/ui/compression_tower_field.png")
const SolarTexture = preload("res://assets/ui/solar_field.png")
const FusionTexture = preload("res://assets/ui/fusion_tower_field.png")

const TURN_SPEED := 10.0
const LOCK_TOLERANCE := 0.08
const OFFLINE_MODULATE := Color(0.52, 0.54, 0.57, 1.0)

var game: Node
var item_id := ""
var name_key := ""
var desc_key := ""
var category := ""
var tier := 1
var color := Palette.CYAN
var invested := 0

var energy_demand := 0
var energy_output := 0

var max_hp := 1
var hp := 1.0
var blocks_enemies := false
var buff_multiplier := 1
var buff_line := false

var attack_style := "none"
var damage := 1
var interval := 1.0
var attack_range := 0.0
var bounces := 0
var pierce := 0
var ball_speed := 620.0
var ball_radius := 7.0
var barrel_length := 48.0
var base_radius := 24.0
var sprite_scale := 1.0

var powered := true
var alive := true
var selected := false
var shots := 0
var hurt_flash := 0.0

var aim_angle := -PI / 2.0
var _time := 0.0
var _cooldown := 0.0
var _recoil := 0.0
var _has_target := false
var _target_pos := Vector2.ZERO
var _beam_hold := 0.0
var _beam_target := Vector2.ZERO
var _beam_buffed := false


func setup(g: Node, def: Dictionary) -> void:
	game = g
	z_index = 4
	_apply_def(def)
	invested = int(def.get("cost", 0))
	max_hp = maxi(1, int(def.get("hp", 1)))
	hp = float(max_hp)
	queue_redraw()


## 原地升级为另一种形态：保留位置与发射数，血量补满，投入计入拆除退款。
func upgrade_to(def: Dictionary, paid: int) -> void:
	invested += paid
	_apply_def(def)
	max_hp = maxi(1, int(def.get("hp", 1)))
	# 形态升级后补满血，作为投入金币的即时回报
	hp = float(max_hp)
	_cooldown = 0.0
	queue_redraw()


func _apply_def(def: Dictionary) -> void:
	item_id = String(def.get("id", ""))
	name_key = String(def.get("name_key", ""))
	desc_key = String(def.get("desc_key", ""))
	category = String(def.get("category", ""))
	tier = int(def.get("tier", 1))
	color = def.get("color", Palette.CYAN)

	energy_demand = int(def.get("energy_demand", 0))
	energy_output = int(def.get("energy_output", 0))

	blocks_enemies = bool(def.get("blocks_enemies", false))
	buff_multiplier = int(def.get("buff_multiplier", 1))
	buff_line = buff_multiplier > 1

	attack_style = String(def.get("attack_style", "none"))
	damage = int(def.get("damage", 1))
	interval = float(def.get("interval", 1.0))
	attack_range = float(def.get("range", 0.0))
	bounces = int(def.get("bounces", 0))
	pierce = int(def.get("pierce", 0))
	ball_speed = float(def.get("speed", 620.0))
	ball_radius = float(def.get("radius", 7.0))
	barrel_length = float(def.get("barrel", 48.0))
	base_radius = float(def.get("base", 24.0))
	sprite_scale = float(def.get("sprite_scale", 1.0))


func get_display_name() -> String:
	return I18n.t(name_key)


func get_display_desc() -> String:
	return I18n.t(desc_key)


func get_upgrade_options() -> Array:
	return ItemDefs.get_upgrades(item_id)


func get_refund() -> int:
	# 未供电的建筑或拆掉后场上将没有任何火力时允许全额返还，避免玩家无法继续获得金币
	var full_refund := false
	if game != null:
		full_refund = not powered or not bool(game.has_firepower(self))
	return int(invested * (1.0 if full_refund else 0.5))


func get_effective_damage() -> int:
	return damage


func get_effective_rate() -> float:
	return 1.0 / maxf(interval, 0.01)


func get_effective_interval() -> float:
	return 1.0 / maxf(get_effective_rate(), 0.01)


func is_energy() -> bool:
	return category == ItemDefs.CATEGORY_ENERGY


func is_firepower() -> bool:
	return category == ItemDefs.CATEGORY_FIREPOWER


func is_fortification() -> bool:
	return category == ItemDefs.CATEGORY_FORTIFICATION


func set_powered(value: bool) -> void:
	if powered == value:
		return
	powered = value
	modulate = Color.WHITE if powered else OFFLINE_MODULATE
	if powered:
		_cooldown = 0.0
	queue_redraw()


func can_block() -> bool:
	return alive and blocks_enemies and powered and hp > 0.0


func get_block_rect() -> Rect2:
	return Rect2(global_position - Vector2(30.0, 30.0), Vector2(60.0, 60.0))


## 压缩塔的覆盖范围：与本塔同一水平线，横贯整个战场。
func covers_point(point: Vector2) -> bool:
	if not buff_line or not powered:
		return false
	var rect: Rect2 = game.get_play_rect()
	return absf(point.y - global_position.y) <= 34.0 and rect.grow(8.0).has_point(point)


func take_damage(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	hp -= amount
	hurt_flash = 1.0
	if hp <= 0.0:
		_destroy()
		return
	queue_redraw()


func _destroy() -> void:
	if not alive:
		return
	alive = false
	if game != null:
		game.on_building_destroyed(self)
	queue_free()


func _process(delta: float) -> void:
	_time += delta
	_recoil = maxf(0.0, _recoil - delta * 6.0)
	hurt_flash = maxf(0.0, hurt_flash - delta * 4.0)
	_beam_hold = maxf(0.0, _beam_hold - delta)

	if not alive:
		return
	if not is_firepower():
		if buff_line or is_energy() or hurt_flash > 0.0:
			queue_redraw()
		return
	if not powered:
		_has_target = false
		_beam_hold = 0.0
		queue_redraw()
		return

	_cooldown = maxf(0.0, _cooldown - delta)
	var target: Dictionary = game.blocks.get_nearest_target(global_position, attack_range)
	if target.is_empty():
		_has_target = false
		queue_redraw()
		return

	_has_target = true
	var rect: Rect2 = target.rect
	_target_pos = rect.get_center()
	if _beam_hold > 0.0:
		_beam_target = _target_pos
	var desired := (_target_pos - global_position).angle()
	aim_angle = lerp_angle(aim_angle, desired, clampf(delta * TURN_SPEED, 0.0, 1.0))

	if _cooldown <= 0.0:
		var diff := wrapf(aim_angle - desired, -PI, PI)
		if absf(diff) <= LOCK_TOLERANCE:
			if attack_style == "laser":
				_fire_laser(target)
			else:
				_fire_projectile()

	queue_redraw()


func get_muzzle() -> Vector2:
	return global_position + Vector2.from_angle(aim_angle) * barrel_length


func _fire_projectile() -> void:
	_cooldown = get_effective_interval()
	_recoil = 1.0
	shots += 1
	var buffed: bool = game.get_buff_multiplier(global_position) > 1
	var shot_damage := damage * (2 if buffed else 1)
	var dir := Vector2.from_angle(aim_angle)
	game.fire_item_ball(
		self,
		get_muzzle(),
		dir,
		shot_damage,
		pierce,
		bounces,
		ball_speed,
		ball_radius,
		buffed
	)


func _fire_laser(target: Dictionary) -> void:
	_cooldown = get_effective_interval()
	_recoil = 1.0
	shots += 1
	_beam_buffed = game.get_buff_multiplier(global_position) > 1
	var shot_damage := damage * (2 if _beam_buffed else 1)
	var rect: Rect2 = target.rect
	_beam_target = rect.get_center()
	_beam_hold = maxf(interval * 1.5, 0.16)
	game.hit_block(int(target.id), shot_damage, _beam_target, _beam_buffed)


func _draw() -> void:
	if selected:
		_draw_selection()

	if category == ItemDefs.CATEGORY_FORTIFICATION and buff_line:
		_draw_buff_line()

	match category:
		ItemDefs.CATEGORY_FIREPOWER:
			_draw_firepower()
		ItemDefs.CATEGORY_FORTIFICATION:
			_draw_fortification()
		ItemDefs.CATEGORY_ENERGY:
			_draw_energy()

	if hurt_flash > 0.0:
		draw_circle(Vector2.ZERO, base_radius + 4.0, Color(0.95, 0.30, 0.26, 0.20 * hurt_flash))

	_draw_health_bar()


func _draw_selection() -> void:
	if is_firepower():
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 64, Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.22), 1.5)
	draw_arc(Vector2.ZERO, base_radius + 4.0, 0.0, TAU, 32, Color(Palette.INK.r, Palette.INK.g, Palette.INK.b, 0.60), 1.5)


func _draw_firepower() -> void:
	var buffed: bool = game.get_buff_multiplier(global_position) > 1
	if _has_target and GameSettings.show_aim:
		var aim_dir := Vector2.from_angle(aim_angle)
		var local_origin := aim_dir * barrel_length
		var global_origin := global_position + local_origin
		var hit_global := TurretVisuals.predict(game.blocks, game.get_play_rect(), global_origin, aim_dir)
		var hit := hit_global - global_position
		TurretVisuals.draw_aim(self, local_origin, aim_dir, hit)
		TurretVisuals.draw_lock(self, _target_pos - global_position, _time)

	if attack_style == "laser":
		if _beam_hold > 0.0:
			_draw_laser_beam()
		TurretVisuals.draw_laser_body(self, aim_angle, base_radius, barrel_length, _recoil, color, _time, buffed)
	elif item_id == "heavy_turret":
		TurretVisuals.draw_heavy_body(self, aim_angle, base_radius, barrel_length, _recoil, color, _time)
	else:
		TurretVisuals.draw_basic_body(self, aim_angle, base_radius, barrel_length, _recoil)

	if buffed:
		var pulse := 0.5 + 0.5 * sin(_time * 7.0)
		draw_arc(Vector2.ZERO, base_radius + 6.0, 0.0, TAU, 36, Color(0.55, 0.92, 1.0, 0.35 + pulse * 0.3), 1.5)
		for k in 3:
			var a := _time * 2.0 + k * TAU / 3.0
			var p1 := Vector2.from_angle(a) * (base_radius + 4.0)
			var p2 := Vector2.from_angle(a + 0.25) * (base_radius + 11.0)
			draw_line(p1, p2, Color(0.72, 0.96, 1.0, 0.65), 1.5)


func _draw_laser_beam() -> void:
	var start := Vector2.from_angle(aim_angle) * barrel_length
	var end := _beam_target - global_position
	var flicker := 0.8 + 0.2 * sin(_time * 46.0)
	var outer := Color(0.34, 0.78, 1.0, 0.26)
	var core := Color(0.80, 0.97, 1.0, 0.92)
	if _beam_buffed:
		outer = Color(0.55, 0.75, 1.0, 0.34)
		core = Color(1.0, 1.0, 1.0, 0.98)
	draw_line(start, end, outer, 9.0 * flicker)
	draw_line(start, end, core, 2.6)
	draw_circle(start, 7.0, Color(core.r, core.g, core.b, 0.5))
	if _beam_buffed:
		var normal := (end - start).normalized().orthogonal()
		for i in 4:
			var t := fmod(_time * 5.0 + i * 0.25, 1.0)
			var p := start.lerp(end, t)
			var side := normal * (4.0 if i % 2 == 0 else -4.0)
			draw_line(p, p + side, Color(0.75, 0.95, 1.0, 0.8), 1.5)


func _draw_fortification() -> void:
	if item_id == "compression_tower":
		_draw_static_texture(CompressionTexture)
		var pulse := 0.5 + 0.5 * sin(_time * 6.0)
		draw_arc(Vector2.ZERO, 13.0 + pulse * 2.0, 0.0, TAU, 24, Color(0.70, 0.96, 1.0, 0.25 + pulse * 0.25), 1.5)
	else:
		_draw_static_texture(SandbagTexture)


func _draw_buff_line() -> void:
	var rect: Rect2 = game.get_play_rect()
	var x0 := rect.position.x - global_position.x
	var x1 := rect.end.x - global_position.x
	if x1 <= x0:
		return
	var alpha := 0.62 if selected else 0.38
	if not powered:
		alpha = 0.07
	var line_color := Color(0.38, 0.86, 0.98, alpha)
	# 半透明光带加实线，避免跟场地网格混在一起
	draw_rect(Rect2(Vector2(x0, -4.0), Vector2(x1 - x0, 8.0)), Color(0.45, 0.88, 0.98, alpha * 0.16))
	draw_line(Vector2(x0, 0.0), Vector2(x1, 0.0), line_color, 4.0 if selected else 3.0)
	var step := 54.0
	var offset := fmod(_time * 90.0, step)
	var x := x0 + offset
	while x < x1:
		draw_circle(Vector2(x, 0.0), 2.2 if selected else 1.7, Color(0.82, 0.98, 1.0, alpha + 0.18))
		x += step


func _draw_energy() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	if item_id == "fusion_tower":
		_draw_static_texture(FusionTexture)
		draw_arc(Vector2.ZERO, base_radius * 0.55, 0.0, TAU, 24, Color(1.0, 0.87, 0.48, 0.14 + pulse * 0.14), 1.5)
	else:
		_draw_static_texture(SolarTexture)
		draw_arc(Vector2.ZERO, base_radius + 2.0, 0.0, TAU, 24, Color(1.0, 0.86, 0.42, 0.06 + pulse * 0.06), 1.0)


func _draw_static_texture(texture: Texture2D) -> void:
	var side := base_radius * 2.0 * sprite_scale
	draw_texture_rect(texture, Rect2(Vector2(-side * 0.5, -side * 0.5), Vector2(side, side)), false)


func _draw_health_bar() -> void:
	if hp >= float(max_hp):
		return
	var width := maxf(34.0, base_radius * 1.8)
	var bar := Rect2(Vector2(-width * 0.5, base_radius + 9.0), Vector2(width, 5.0))
	var ratio := clampf(hp / float(maxi(max_hp, 1)), 0.0, 1.0)
	draw_rect(bar, Color(0.02, 0.03, 0.04, 0.9))
	if ratio > 0.0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), Palette.ACCENT if ratio > 0.3 else Palette.DANGER)
	draw_rect(bar, Color(1.0, 1.0, 1.0, 0.25), false, 1.0)
