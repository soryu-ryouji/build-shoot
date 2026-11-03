extends Node2D

## 敌人流：从地图顶部的缺口出场，沿 battle_map 里的路线走向底部核心。
## 被阵地建筑挡住时停下攻击，撞到核心则扣基地血量。

const Palette = preload("res://scripts/palette.gd")
const BattleMap = preload("res://scripts/battle_map.gd")

const MONSTER_TEXTURES := {
	"normal": preload("res://assets/ui/monster_normal.png"),
	"swift": preload("res://assets/ui/monster_swift.png"),
	"armored": preload("res://assets/ui/monster_armored.png"),
	"elite": preload("res://assets/ui/monster_elite.png"),
}
## 2.5D 敌人贴片：Blender 正交渲染，64×64，地面中心在画布中心
const MONSTER_SPRITES := {
	"normal": preload("res://assets/ui/enemies/normal.png"),
	"swift": preload("res://assets/ui/enemies/swift.png"),
	"armored": preload("res://assets/ui/enemies/armored.png"),
	"elite": preload("res://assets/ui/enemies/elite.png"),
}
const MONSTER_ANIMATIONS := {
	"normal": preload("res://assets/ui/monster_normal_anim.png"),
	"swift": preload("res://assets/ui/monster_swift_anim.png"),
	"armored": preload("res://assets/ui/monster_armored_anim.png"),
	"elite": preload("res://assets/ui/monster_elite_anim.png"),
}

const CELL_SIZE := Vector2(48.0, 30.0)
## 基础行走速度（世界像素/秒）；各类敌人再乘自己的倍率
const WALK_SPEED := 84.0
## 出场淡入时长
const SPAWN_FADE := 0.3

## 波次节奏：开场只有一小撮，约 12 秒后第一波爆发，之后每波之间留出清场时间。
const OPENING_CALM := 12.0
const WAVE_CALM_BASE := 18.0
const WAVE_CALM_PER_ROW := 3.0
## 一波里两只敌人之间的出场间隔
const SPAWN_INTERVAL := 0.55
const WAVE_MAX_ROWS := 5
## 每波血量按该系数复利增长，逼玩家把金币投进强化
const HEALTH_GROWTH := 1.28

const KIND_NORMAL := "normal"
const KIND_SWIFT := "swift"
const KIND_ARMORED := "armored"
const KIND_ELITE := "elite"
const HEALTH_BAR_HEIGHT := 6.0
## 受击后血条显示的持续时间，再次受击会刷新
const HEALTH_BAR_DURATION := 3.0
const ANIMATION_FRAME_SIZE := 256.0

var blocks: Array[Dictionary] = []
var by_id := {}
var destroyed := 0
var spawned := 0
var active := false
var game: Node

## 当前波次；0 表示还没开始（准备阶段）
var wave := 0
## 距离下一波还有几秒，HUD 用它显示倒计时
var next_wave_in := 0.0

var _next_id := 1
var _rng := RandomNumberGenerator.new()
var _flashing := false
var _animation_time := 0.0
## 待出场的敌人：{delay, gate}
var _pending: Array = []


func _ready() -> void:
	_rng.randomize()


func reset_stream() -> void:
	active = true
	blocks.clear()
	by_id.clear()
	_pending.clear()
	_next_id = 1
	destroyed = 0
	spawned = 0
	_flashing = false
	_animation_time = 0.0

	# 开场只放一小撮，给玩家布置和强化的时间；12 秒后第二波爆发
	wave = 1
	next_wave_in = OPENING_CALM
	_spawn_wave()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not active:
		return
	_advance_blocks(delta)
	_schedule_waves(delta)
	_spawn_pending(delta)

	if not blocks.is_empty():
		queue_redraw()


func _advance_blocks(delta: float) -> void:
	for b in blocks:
		if not bool(b.alive):
			continue
		if float(b.spawn) < 1.0:
			b.spawn = minf(1.0, float(b.spawn) + delta / SPAWN_FADE)
		# 被阵地建筑挡住时停下攻击，不再前进
		if _update_block_attack(b, delta):
			continue
		_walk(b, delta)

	# 撞到核心、被击碎或已经在终点消失的方块统一清掉
	var i := blocks.size() - 1
	while i >= 0:
		var removed: Dictionary = blocks[i]
		if not bool(removed.alive):
			by_id.erase(int(removed.id))
			blocks.remove_at(i)
		i -= 1


func _walk(b: Dictionary, delta: float) -> void:
	var route: Array = b.route
	if route.is_empty():
		return
	var step := int(b.step)
	var start_step := step
	var center: Vector2 = b.center
	var prev := center
	var remaining := WALK_SPEED * float(b.get("speed_scale", 1.0)) * delta
	var blocker: Node = null

	while remaining > 0.0 and step < route.size():
		var target: Vector2 = BattleMap.tile_center(route[step])
		var dist := center.distance_to(target)
		if dist > remaining:
			center = center.move_toward(target, remaining)
			remaining = 0.0
		else:
			center = target
			remaining = maxf(0.0, remaining - dist)
			step += 1
		blocker = game.get_blocking_building(_rect_at(center)) if game != null else null
		if blocker != null:
			break

	if blocker != null:
		# 停在建筑前：位置回退到这一步开始前，但把阻挡者记下来继续啃
		b.center = prev
		b.rect = _rect_at(prev)
		b.step = start_step
		b.blocked_by = blocker
		b.attack_flash = 1.0
		return

	b.center = center
	b.rect = _rect_at(center)
	b.step = step
	if step >= route.size():
		_reach_core(b)


func _reach_core(b: Dictionary) -> void:
	b.alive = false
	if game != null:
		game.on_enemy_leaked(b)


func _rect_at(center: Vector2) -> Rect2:
	return Rect2(center - CELL_SIZE * 0.5, CELL_SIZE)


func _update_block_attack(b: Dictionary, delta: float) -> bool:
	var blocker = b.get("blocked_by", null)
	if blocker == null:
		return false
	if not is_instance_valid(blocker) or not blocker.can_block():
		b.blocked_by = null
		return false
	blocker.take_damage(_attack_dps(String(b.kind)) * delta)
	b.attack_flash = 1.0
	return true


func _attack_dps(kind: String) -> float:
	match kind:
		KIND_SWIFT:
			return 6.0
		KIND_ARMORED:
			return 3.0
		KIND_ELITE:
			return 12.0
	return 5.0


func _process(delta: float) -> void:
	if active:
		if GameSettings.animate_monsters:
			_animation_time += delta
		queue_redraw()
	var any_attack := false
	for b in blocks:
		if float(b.get("attack_flash", 0.0)) > 0.0:
			b.attack_flash = maxf(0.0, float(b.attack_flash) - delta * 4.0)
			any_attack = true
	if any_attack:
		queue_redraw()
	var any_hp_bar := false
	for b in blocks:
		var bar_time := float(b.get("hp_bar_time", 0.0))
		if bar_time > 0.0:
			b.hp_bar_time = maxf(0.0, bar_time - delta)
			any_hp_bar = true

	if not _flashing:
		if any_hp_bar:
			queue_redraw()
		return
	var any := false
	for b in blocks:
		if float(b.get("flash", 0.0)) > 0.0:
			b.flash = maxf(0.0, float(b.flash) - delta * 5.0)
			any = true
	_flashing = any
	queue_redraw()


## 场上炮塔的目标：射程格子内最近的方块。
func get_nearest_target(origin: Vector2, max_range: float, range_cells: Array = []) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := INF if not range_cells.is_empty() else max_range * max_range
	for b in blocks:
		if not bool(b.alive):
			continue
		# 刚出场还没淡入完的敌人不作为目标
		if float(b.get("spawn", 1.0)) < 1.0:
			continue
		var center: Vector2 = b.center
		if not range_cells.is_empty() and not _cell_in_range(center, range_cells):
			continue
		var dist := center.distance_squared_to(origin)
		if dist <= best_dist:
			best_dist = dist
			best = b
	return best


func _cell_in_range(point: Vector2, range_cells: Array) -> bool:
	var cell: Vector2 = game.snap_to_grid(point)
	for allowed in range_cells:
		if cell.distance_to(allowed) < 0.5:
			return true
	return false


func damage(id: int, amount: int) -> Dictionary:
	var b = by_id.get(id)
	if b == null:
		return {"hit": false}
	var block: Dictionary = b
	if not bool(block.alive):
		return {"hit": false}

	block.hp = int(block.hp) - amount
	block.flash = 1.0
	block.hp_bar_time = HEALTH_BAR_DURATION
	_flashing = true
	if int(block.hp) <= 0:
		block.alive = false
		block.hp_bar_time = 0.0
		destroyed += 1
		queue_redraw()
		return {
			"hit": true,
			"destroyed": true,
			"rect": block.rect,
			"max_hp": int(block.max_hp),
			"color": block.color,
		}

	queue_redraw()
	return {
		"hit": true,
		"destroyed": false,
		"rect": block.rect,
		"max_hp": int(block.max_hp),
		"color": block.color,
	}


func _base_health_for_wave(wave_number: int) -> int:
	return int(round(3.0 * pow(HEALTH_GROWTH, maxi(wave_number, 1) - 1)))


## 每一行的规模：开场 3 只，之后随波次增长，上限铺满地图宽度。
func _enemy_count_for_wave(wave_number: int) -> int:
	if wave_number <= 1:
		return 3
	return clampi(6 + wave_number, 6, BattleMap.COLS)


## 一波铺几行：第 2 波 3 行（30 只），第 4 波 4 行，第 6 波起 5 行。
func _rows_for_wave(wave_number: int) -> int:
	if wave_number <= 1:
		return 1
	if wave_number <= 3:
		return 3
	if wave_number <= 5:
		return 4
	return WAVE_MAX_ROWS


## 一波打完后留给玩家清场与强化的时间。
func _calm_for_wave(wave_number: int) -> float:
	return WAVE_CALM_BASE + _rows_for_wave(wave_number) * WAVE_CALM_PER_ROW


func _spawn_wave() -> void:
	var total := _rows_for_wave(wave) * _enemy_count_for_wave(wave)
	for i in total:
		_pending.append({"delay": float(i) * SPAWN_INTERVAL, "gate": i % 2})


func _spawn_pending(delta: float) -> void:
	var i := _pending.size() - 1
	while i >= 0:
		var entry: Dictionary = _pending[i]
		entry.delay = float(entry.delay) - delta
		if float(entry.delay) <= 0.0:
			_pending.remove_at(i)
			_spawn_enemy(int(entry.gate))
		i -= 1


func _schedule_waves(delta: float) -> void:
	if next_wave_in > 0.0:
		next_wave_in = maxf(0.0, next_wave_in - delta)
	if next_wave_in <= 0.0:
		wave += 1
		_spawn_wave()
		next_wave_in = _calm_for_wave(wave)


func _spawn_enemy(gate_index: int) -> void:
	var route: Array = BattleMap.route_for_gate(gate_index)
	var kind := _pick_kind(wave)
	var hp := _health_for_kind(kind, _base_health_for_wave(wave))
	var color := Palette.block_color(int(spawned / 2) % 6 + 1)
	match kind:
		KIND_SWIFT:
			color = Palette.CYAN
		KIND_ARMORED:
			color = Palette.METAL.lightened(0.20)
		KIND_ELITE:
			color = Palette.PINK

	var center: Vector2 = BattleMap.tile_center(route[0])
	var id := _next_id
	_next_id += 1
	var block := {
		"id": id,
		"kind": kind,
		"route": route,
		"step": 1,
		"center": center,
		"rect": _rect_at(center),
		"hp": hp,
		"max_hp": hp,
		"speed_scale": _speed_for_kind(kind),
		"color": color,
		"flash": 0.0,
		"hp_bar_time": 0.0,
		"alive": true,
		"blocked_by": null,
		"attack_flash": 0.0,
		"spawn": 0.0,
	}
	blocks.append(block)
	by_id[id] = block
	spawned += 1


func _pick_kind(wave_number: int) -> String:
	var roll := _rng.randf()
	if wave_number >= 4 and roll < 0.10:
		return KIND_ELITE
	if wave_number >= 3 and roll < 0.28:
		return KIND_ARMORED
	if wave_number >= 2 and roll < 0.55:
		return KIND_SWIFT
	return KIND_NORMAL


func _health_for_kind(kind: String, base_hp: int) -> int:
	match kind:
		KIND_SWIFT:
			return maxi(2, int(round(base_hp * 0.7)))
		KIND_ARMORED:
			return int(round(base_hp * 2.0))
		KIND_ELITE:
			return int(round(base_hp * 3.5))
	return base_hp


func _speed_for_kind(kind: String) -> float:
	match kind:
		KIND_SWIFT:
			return 1.3
		KIND_ARMORED:
			return 0.8
		KIND_ELITE:
			return 0.9
	return 1.0



func _draw_kind(inner: Rect2, kind: String, col: Color, alpha := 1.0) -> void:
	var c := inner.get_center() + Vector2(0.0, -2.0)
	match kind:
		KIND_SWIFT:
			var mark := Color(0.9, 1.0, 1.0, 0.72 * alpha)
			draw_polyline(PackedVector2Array([
				c + Vector2(-8.0, -5.0),
				c + Vector2(0.0, 2.0),
				c + Vector2(8.0, -5.0),
			]), mark, 2.0, true)
		KIND_ARMORED:
			draw_rect(inner.grow(-3.0), Color(col.lightened(0.35), alpha), false, 2.0)
			for x in [inner.position.x + 5.0, inner.end.x - 5.0]:
				draw_circle(Vector2(x, inner.position.y + 5.0), 1.5, Color(col.lightened(0.55), alpha))
		KIND_ELITE:
			draw_arc(c, 7.0, 0.0, TAU, 6, Color(col.lightened(0.60), alpha), 2.0, true)
			draw_circle(c, 2.5, Color(1.0, 0.9, 0.95, 0.85 * alpha))


func _draw_health_bar(inner: Rect2, hp: int, max_hp: int, alpha := 1.0) -> void:
	var ratio := clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	var back := Rect2(
		Vector2(inner.position.x + 4.0, inner.end.y - HEALTH_BAR_HEIGHT - 2.0),
		Vector2(inner.size.x - 8.0, HEALTH_BAR_HEIGHT)
	)
	draw_rect(back, Color(0.01, 0.02, 0.04, 0.9 * alpha))
	if ratio > 0.0:
		var fill := Rect2(back.position, Vector2(back.size.x * ratio, back.size.y))
		var fill_color := Palette.ACCENT if ratio > 0.30 else Palette.DANGER
		draw_rect(fill, Color(fill_color, alpha))
	draw_rect(back, Color(1.0, 1.0, 1.0, 0.25 * alpha), false, 1.0)


func _draw() -> void:
	for b in blocks:
		if not bool(b.alive):
			continue
		var rect: Rect2 = b.rect
		var center: Vector2 = b.center
		var max_hp: int = int(b.max_hp)
		var hp: int = int(b.hp)
		var col: Color = b.color
		var kind := String(b.get("kind", KIND_NORMAL))
		# 出场淡入
		var alpha := clampf(float(b.get("spawn", 1.0)), 0.0, 1.0)
		var scale := lerpf(0.45, 1.0, alpha)
		if alpha <= 0.0:
			continue
		alpha = smoothstep(0.0, 1.0, alpha)

		var inner := rect.grow(-2.0)
		var body := Rect2(center - CELL_SIZE * 0.5 * scale, CELL_SIZE * scale)
		var texture: Texture2D = MONSTER_TEXTURES.get(kind, MONSTER_TEXTURES[KIND_NORMAL])
		var animation: Texture2D = MONSTER_ANIMATIONS.get(kind, MONSTER_ANIMATIONS[KIND_NORMAL])
		var fps := 8.0
		if kind == KIND_SWIFT:
			fps = 12.0
		elif kind == KIND_ARMORED:
			fps = 6.0
		elif kind == KIND_ELITE:
			fps = 7.0
		var phase := float(int(b.id) % 8) * 0.09
		var frame := int((_animation_time + phase) * fps) % 4 if GameSettings.animate_monsters else 0
		var frame_rect := Rect2(frame * ANIMATION_FRAME_SIZE, 0.0, ANIMATION_FRAME_SIZE, ANIMATION_FRAME_SIZE)
		var art_size := Vector2(52, 48)
		if kind == KIND_ARMORED:
			art_size = Vector2(56, 50)
		elif kind == KIND_ELITE:
			art_size = Vector2(58, 54)
		elif kind == KIND_SWIFT:
			art_size = Vector2(50, 46)
		var art_rect := Rect2(center - art_size * 0.5 * scale + Vector2(0.0, -3.0 * scale), art_size * scale)

		var sprite: Texture2D = MONSTER_SPRITES.get(kind, null)
		if sprite != null:
			# 2.5D 贴片：轻微上下浮动代替逐帧动画
			var bob := sin((_animation_time + phase) * 7.0) * 1.6 * scale
			draw_circle(center + Vector2(0, 4), 20.0 * scale, Color(0.0, 0.0, 0.0, 0.34 * alpha))
			var side := 64.0 * scale
			draw_texture_rect(
				sprite,
				Rect2(center - Vector2(side, side) * 0.5 + Vector2(0.0, bob - 6.0 * scale), Vector2(side, side)),
				false,
				Color(1.0, 1.0, 1.0, alpha)
			)
		elif animation != null or texture != null:
			draw_circle(center + Vector2(0, 5), 19.0 * scale, Color(0.0, 0.0, 0.0, 0.12 * alpha))
			draw_circle(center, 25.0 * scale, Color(col.r, col.g, col.b, 0.05 * alpha))
			if animation != null:
				draw_texture_rect_region(animation, art_rect, frame_rect, Color(1.0, 1.0, 1.0, alpha))
			else:
				draw_texture_rect(texture, art_rect, false, Color(1.0, 1.0, 1.0, alpha))
		else:
			# 素材缺失时仍能显示可辨识的敌人，不影响战斗逻辑。
			draw_rect(body, Color(col.darkened(0.72), alpha))
			draw_rect(body.grow(-2.0 * scale), Color(col.darkened(0.30), alpha))
			_draw_kind(body.grow(-2.0 * scale), kind, col, alpha)

		if hp < max_hp:
			var c := rect.get_center() + Vector2(0, -3)
			draw_line(c + Vector2(-7, -6), c + Vector2(5, 5), Color(0.0, 0.0, 0.0, 0.55 * alpha), 1.5)
			draw_line(c + Vector2(-4, 6), c + Vector2(6, -4), Color(0.0, 0.0, 0.0, 0.45 * alpha), 1.5)

		var flash := float(b.get("flash", 0.0))
		if flash > 0.0:
			if animation != null:
				draw_texture_rect_region(animation, art_rect, frame_rect, Color(2.0, 2.0, 2.0, 0.65 * flash * alpha))
			elif texture != null:
				draw_texture_rect(texture, art_rect, false, Color(2.0, 2.0, 2.0, 0.65 * flash * alpha))
			else:
				draw_rect(inner, Color(1.0, 1.0, 1.0, 0.45 * flash * alpha))

		# 正在啃食阵地建筑时，在方块底部画出抓挠痕迹
		var attack_flash := float(b.get("attack_flash", 0.0))
		if attack_flash > 0.0 and b.get("blocked_by", null) != null:
			var claw := center + Vector2(0.0, rect.size.y * 0.42)
			for k in 3:
				var x := claw.x - 8.0 + k * 8.0
				draw_line(Vector2(x, claw.y), Vector2(x - 3.0, claw.y + 9.0), Color(0.95, 0.32, 0.28, 0.8 * attack_flash * alpha), 2.0)

		# 血条只在受击后的短时间内显示，避免长时间占满屏幕
		if float(b.get("hp_bar_time", 0.0)) > 0.0 and hp < max_hp:
			_draw_health_bar(inner, hp, max_hp, alpha)
