extends Node2D

## 从上往下滚动的方块流。方块用 id 标识，方便在滚动/移除时安全引用。

const Palette = preload("res://scripts/palette.gd")
const MONSTER_TEXTURES := {
	"normal": preload("res://assets/ui/monster_normal.png"),
	"swift": preload("res://assets/ui/monster_swift.png"),
	"armored": preload("res://assets/ui/monster_armored.png"),
	"elite": preload("res://assets/ui/monster_elite.png"),
}
const MONSTER_ANIMATIONS := {
	"normal": preload("res://assets/ui/monster_normal_anim.png"),
	"swift": preload("res://assets/ui/monster_swift_anim.png"),
	"armored": preload("res://assets/ui/monster_armored_anim.png"),
	"elite": preload("res://assets/ui/monster_elite_anim.png"),
}

const PLAY_TOP := 112.0
const PLAY_BOTTOM := 800.0
const COLS := 11
const CELL_SIZE := Vector2(48.0, 30.0)
const CELL_GAP_X := 4.0
const GRID_ORIGIN_X := 76.0
const SPAWN_Y := PLAY_TOP - CELL_SIZE.y - 6.0

## 波次节奏：开场只有一小撮，约 12 秒后第一波爆发，之后每波之间留出清场时间。
const OPENING_CALM := 12.0
## 两波之间的基础间隔；行数越多留的时间越长，避免波次叠在一起
const WAVE_CALM_BASE := 18.0
const WAVE_CALM_PER_ROW := 3.0
## 同一波内行与行的间距，比常规行距更紧，进门时像一堵墙压下来
const WAVE_ROW_SPACING := 36.0
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
var spawned_rows := 0
var scroll_speed := 20.0
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


func _ready() -> void:
	_rng.randomize()


func reset_stream() -> void:
	active = true
	blocks.clear()
	by_id.clear()
	_next_id = 1
	destroyed = 0
	spawned_rows = 0
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
	var dy := scroll_speed * delta
	for b in blocks:
		if not bool(b.alive):
			continue
		# 被阵地建筑挡住时停下攻击，不再前进
		if _update_block_attack(b, delta):
			continue
		var step := dy * float(b.get("speed_scale", 1.0))
		if step <= 0.0:
			continue
		var rect: Rect2 = b.rect
		rect.position.y += step
		b.rect = rect
		_try_block(b)

	# 移除已经滚出底部或被击碎的方块
	var i := blocks.size() - 1
	while i >= 0:
		var b: Dictionary = blocks[i]
		var rect: Rect2 = b.rect
		if not bool(b.alive) or rect.position.y >= PLAY_BOTTOM:
			by_id.erase(int(b.id))
			blocks.remove_at(i)
		i -= 1

	# 波次调度：爆发一波，留出清场时间，再爆发下一波
	if next_wave_in > 0.0:
		next_wave_in = maxf(0.0, next_wave_in - delta)
	if next_wave_in <= 0.0:
		wave += 1
		_spawn_wave()
		next_wave_in = _calm_for_wave(wave)

	if not blocks.is_empty():
		queue_redraw()


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


func _try_block(b: Dictionary) -> void:
	if game == null:
		return
	var blocker = game.get_blocking_building(b.rect)
	if blocker == null:
		return
	var rect: Rect2 = b.rect
	var block_rect: Rect2 = blocker.get_block_rect()
	rect.position.y = minf(rect.position.y, block_rect.position.y - rect.size.y - 2.0)
	b.rect = rect
	b.blocked_by = blocker
	b.attack_flash = 1.0


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


## 场上炮塔的目标：射程内最近的方块。
func get_nearest_target(origin: Vector2, max_range: float) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := max_range * max_range
	for b in blocks:
		if not bool(b.alive):
			continue
		var rect: Rect2 = b.rect
		var center := rect.get_center()
		if center.y < PLAY_TOP:
			continue
		var dist := center.distance_squared_to(origin)
		if dist <= best_dist:
			best_dist = dist
			best = b
	return best


## 底部主炮塔的目标：优先选择最靠近底部、且还在炮塔上方的方块。
## 同一行里选离炮塔最近的一块，方便炮塔左右扫射。
func get_auto_target(origin: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_y := -INF
	var best_dx := INF
	var max_y := origin.y - 12.0
	for b in blocks:
		if not bool(b.alive):
			continue
		var rect: Rect2 = b.rect
		var c := rect.get_center()
		if c.y < PLAY_TOP or c.y > max_y:
			continue
		var dx := absf(c.x - origin.x)
		if c.y > best_y + 0.5:
			best = b
			best_y = c.y
			best_dx = dx
		elif absf(c.y - best_y) <= 0.5 and dx < best_dx:
			best = b
			best_dx = dx
	return best


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


## 每一行铺几只：开场 3 只，之后逐波逼近满行。
func _enemy_count_for_wave(wave_number: int) -> int:
	if wave_number <= 1:
		return 3
	return clampi(8 + wave_number, 8, COLS)


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
	var rows := _rows_for_wave(wave)
	var count := _enemy_count_for_wave(wave)
	for i in rows:
		_spawn_row(SPAWN_Y - i * WAVE_ROW_SPACING, count)


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


func _spawn_row(y: float, count: int) -> void:
	var row := spawned_rows
	spawned_rows += 1

	var current_wave := wave
	var color_index := int(row / 2) % 6 + 1
	var hp_base := _base_health_for_wave(current_wave)

	var target_count := mini(COLS, count)
	var present: Array[bool] = []
	present.resize(COLS)
	present.fill(false)
	var filled := 0
	while filled < target_count:
		var c := _rng.randi_range(0, COLS - 1)
		if not present[c]:
			present[c] = true
			filled += 1

	for c in COLS:
		if not present[c]:
			continue
		var kind := _pick_kind(current_wave)
		var hp := _health_for_kind(kind, hp_base)
		var color := Palette.block_color(color_index)
		match kind:
			KIND_SWIFT:
				color = Palette.CYAN
			KIND_ARMORED:
				color = Palette.METAL.lightened(0.20)
			KIND_ELITE:
				color = Palette.PINK
		var rect := Rect2(
			Vector2(GRID_ORIGIN_X + c * (CELL_SIZE.x + CELL_GAP_X), y),
			CELL_SIZE
		)
		var id := _next_id
		_next_id += 1
		var block := {
			"id": id,
			"kind": kind,
			"rect": rect,
			"hp": hp,
			"max_hp": hp,
			"speed_scale": _speed_for_kind(kind),
			"color": color,
			"flash": 0.0,
			"hp_bar_time": 0.0,
			"alive": true,
			"blocked_by": null,
			"attack_flash": 0.0,
		}
		blocks.append(block)
		by_id[id] = block


func _draw_kind(inner: Rect2, kind: String, col: Color) -> void:
	var c := inner.get_center() + Vector2(0.0, -2.0)
	match kind:
		KIND_SWIFT:
			var mark := Color(0.9, 1.0, 1.0, 0.72)
			draw_polyline(PackedVector2Array([
				c + Vector2(-8.0, -5.0),
				c + Vector2(0.0, 2.0),
				c + Vector2(8.0, -5.0),
			]), mark, 2.0, true)
		KIND_ARMORED:
			draw_rect(inner.grow(-3.0), col.lightened(0.35), false, 2.0)
			for x in [inner.position.x + 5.0, inner.end.x - 5.0]:
				draw_circle(Vector2(x, inner.position.y + 5.0), 1.5, col.lightened(0.55))
		KIND_ELITE:
			draw_arc(c, 7.0, 0.0, TAU, 6, col.lightened(0.60), 2.0, true)
			draw_circle(c, 2.5, Color(1.0, 0.9, 0.95, 0.85))


func _draw_health_bar(inner: Rect2, hp: int, max_hp: int) -> void:
	var ratio := clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	var back := Rect2(
		Vector2(inner.position.x + 4.0, inner.end.y - HEALTH_BAR_HEIGHT - 2.0),
		Vector2(inner.size.x - 8.0, HEALTH_BAR_HEIGHT)
	)
	draw_rect(back, Color(0.01, 0.02, 0.04, 0.9))
	if ratio > 0.0:
		var fill := Rect2(back.position, Vector2(back.size.x * ratio, back.size.y))
		var fill_color := Palette.ACCENT if ratio > 0.30 else Palette.DANGER
		draw_rect(fill, fill_color)
	draw_rect(back, Color(1.0, 1.0, 1.0, 0.25), false, 1.0)


func _draw() -> void:
	for b in blocks:
		if not bool(b.alive):
			continue
		var rect: Rect2 = b.rect
		var max_hp: int = int(b.max_hp)
		var hp: int = int(b.hp)
		var col: Color = b.color
		var kind := String(b.get("kind", KIND_NORMAL))

		var inner := rect.grow(-2.0)
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
		var art_rect := Rect2(rect.get_center() - art_size * 0.5 + Vector2(0, -3), art_size)

		if animation != null or texture != null:
			draw_circle(rect.get_center() + Vector2(0, 5), 19.0, Color(0.0, 0.0, 0.0, 0.12))
			draw_circle(rect.get_center(), 25.0, Color(col.r, col.g, col.b, 0.05))
			if animation != null:
				draw_texture_rect_region(animation, art_rect, frame_rect, Color.WHITE)
			else:
				draw_texture_rect(texture, art_rect, false, Color.WHITE)
		else:
			# 素材缺失时仍能显示可辨识的敌人，不影响战斗逻辑。
			draw_rect(rect, col.darkened(0.72))
			draw_rect(inner, col.darkened(0.30))
			_draw_kind(inner, kind, col)

		if hp < max_hp:
			var c := rect.get_center() + Vector2(0, -3)
			draw_line(c + Vector2(-7, -6), c + Vector2(5, 5), Color(0.0, 0.0, 0.0, 0.55), 1.5)
			draw_line(c + Vector2(-4, 6), c + Vector2(6, -4), Color(0.0, 0.0, 0.0, 0.45), 1.5)

		var flash := float(b.get("flash", 0.0))
		if flash > 0.0:
			if animation != null:
				draw_texture_rect_region(animation, art_rect, frame_rect, Color(2.0, 2.0, 2.0, 0.65 * flash))
			elif texture != null:
				draw_texture_rect(texture, art_rect, false, Color(2.0, 2.0, 2.0, 0.65 * flash))
			else:
				draw_rect(inner, Color(1.0, 1.0, 1.0, 0.45 * flash))

		# 正在啃食阵地建筑时，在方块底部画出抓挠痕迹
		var attack_flash := float(b.get("attack_flash", 0.0))
		if attack_flash > 0.0 and b.get("blocked_by", null) != null:
			var claw := rect.get_center() + Vector2(0.0, rect.size.y * 0.42)
			for k in 3:
				var x := claw.x - 8.0 + k * 8.0
				draw_line(Vector2(x, claw.y), Vector2(x - 3.0, claw.y + 9.0), Color(0.95, 0.32, 0.28, 0.8 * attack_flash), 2.0)

		# 血条只在受击后的短时间内显示，避免长时间占满屏幕
		if float(b.get("hp_bar_time", 0.0)) > 0.0 and hp < max_hp:
			_draw_health_bar(inner, hp, max_hp)
