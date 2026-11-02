extends Node2D

## 从上往下滚动的方块流。方块用 id 标识，方便在滚动/移除时安全引用。

const Palette = preload("res://scripts/palette.gd")

const PLAY_TOP := 112.0
const PLAY_BOTTOM := 800.0
const COLS := 11
const CELL_SIZE := Vector2(48.0, 30.0)
const CELL_GAP_X := 4.0
const GRID_ORIGIN_X := 76.0
const ROW_PITCH := 48.0
const SPAWN_Y := PLAY_TOP - CELL_SIZE.y - 6.0

var blocks: Array[Dictionary] = []
var by_id := {}
var destroyed := 0
var spawned_rows := 0
var scroll_speed := 20.0
var active := false

var _next_id := 1
var _spawn_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _flashing := false


func _ready() -> void:
	_rng.randomize()


func reset_stream() -> void:
	active = true
	blocks.clear()
	by_id.clear()
	_next_id = 1
	destroyed = 0
	spawned_rows = 0
	# 开局只给两行，留出发育时间；之后按固定节奏往下补
	_spawn_timer = 3.5
	_flashing = false

	# 只在顶部视野外预置一行，倒计时结束后从边缘逐渐滚入
	_spawn_row(SPAWN_Y)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not active:
		return
	var dy := scroll_speed * delta
	for b in blocks:
		if bool(b.alive):
			b.rect.position.y += dy

	# 移除已经滚出底部或被击碎的方块
	var i := blocks.size() - 1
	while i >= 0:
		var b: Dictionary = blocks[i]
		var rect: Rect2 = b.rect
		if not bool(b.alive) or rect.position.y >= PLAY_BOTTOM:
			by_id.erase(int(b.id))
			blocks.remove_at(i)
		i -= 1

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer += ROW_PITCH / scroll_speed
		_spawn_row(SPAWN_Y)

	if not blocks.is_empty():
		queue_redraw()


func _process(delta: float) -> void:
	if not _flashing:
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
	_flashing = true
	if int(block.hp) <= 0:
		block.alive = false
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


func _spawn_row(y: float) -> void:
	var row := spawned_rows
	spawned_rows += 1

	var color_index := int(row / 2) % 6 + 1
	var hp_base := clampi(1 + int(row / 14), 1, 5)

	# 先铺满，再挖 2~3 段连续缺口，保证行与行之间、块与块之间都有空隙
	var present: Array[bool] = []
	present.resize(COLS)
	present.fill(true)
	var gap_count := _rng.randi_range(2, 3)
	for g in gap_count:
		var gap_len := _rng.randi_range(2, 3)
		var start := _rng.randi_range(0, COLS - gap_len)
		for c in range(start, start + gap_len):
			present[c] = false
	for c in COLS:
		if _rng.randf() < 0.04:
			present[c] = false

	var filled := 0
	for c in COLS:
		if present[c]:
			filled += 1
	while filled < 5:
		var c := _rng.randi_range(0, COLS - 1)
		if not present[c]:
			present[c] = true
			filled += 1

	for c in COLS:
		if not present[c]:
			continue
		var hp := hp_base
		if _rng.randf() < 0.15:
			hp += 1
		hp = clampi(hp, 1, 6)
		var rect := Rect2(
			Vector2(GRID_ORIGIN_X + c * (CELL_SIZE.x + CELL_GAP_X), y),
			CELL_SIZE
		)
		var id := _next_id
		_next_id += 1
		var block := {
			"id": id,
			"rect": rect,
			"hp": hp,
			"max_hp": hp,
			"color": Palette.block_color(color_index),
			"flash": 0.0,
			"alive": true,
		}
		blocks.append(block)
		by_id[id] = block


func _draw() -> void:
	for b in blocks:
		if not bool(b.alive):
			continue
		var rect: Rect2 = b.rect
		var max_hp: int = int(b.max_hp)
		var hp: int = int(b.hp)
		var col: Color = b.color

		draw_rect(rect.grow(4.0), Color(col.r, col.g, col.b, 0.07))
		draw_rect(rect, col.darkened(0.72))
		var inner := rect.grow(-2.0)
		draw_rect(inner, col.darkened(0.30))
		draw_line(inner.position + Vector2(1.0, 1.0), Vector2(inner.end.x - 1.0, inner.position.y + 1.0), col.lightened(0.45), 2.0)
		draw_line(Vector2(inner.position.x + 1.0, inner.end.y - 1.0), Vector2(inner.end.x - 1.0, inner.end.y - 1.0), col.darkened(0.62), 2.0)

		if hp < max_hp:
			draw_rect(inner, Color(0.02, 0.03, 0.08, 0.38))
			var c := rect.get_center()
			draw_line(c + Vector2(-7, -6), c + Vector2(5, 5), Color(0.0, 0.0, 0.0, 0.45), 1.5)
			draw_line(c + Vector2(-4, 6), c + Vector2(6, -4), Color(0.0, 0.0, 0.0, 0.35), 1.5)

		var flash := float(b.get("flash", 0.0))
		if flash > 0.0:
			draw_rect(inner, Color(1.0, 1.0, 1.0, 0.45 * flash))

		for j in hp:
			var pip := Rect2(Vector2(inner.position.x + 4.0 + j * 5.0, inner.end.y - 6.0), Vector2(3.0, 3.0))
			draw_rect(pip, Color(1.0, 1.0, 1.0, 0.6))
