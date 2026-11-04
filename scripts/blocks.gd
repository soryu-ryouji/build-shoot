extends Node2D

## 巢穴生成的敌人集合。敌人从任意方向接近中央基地，并攻击途中拦截建筑。

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

const KIND_NORMAL := "normal"
const KIND_SWIFT := "swift"
const KIND_ARMORED := "armored"
const KIND_ELITE := "elite"
const CELL_SIZE := Vector2(48.0, 30.0)
const HEALTH_BAR_HEIGHT := 6.0
const HEALTH_BAR_DURATION := 3.0
const ANIMATION_FRAME_SIZE := 256.0

var blocks: Array[Dictionary] = []
var by_id := {}
var destroyed := 0
var active := false
var game: Node

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
	_flashing = false
	_animation_time = 0.0
	queue_redraw()


func spawn_from_nest(nest: Node) -> Dictionary:
	if not is_instance_valid(nest) or not nest.alive:
		return {}
	var to_base: Vector2 = (game.base_core.global_position - nest.global_position).normalized()
	var side := to_base.orthogonal() * _rng.randf_range(-22.0, 22.0)
	var position: Vector2 = nest.global_position + to_base * 58.0 + side
	var health_scale := 1.0 + minf(2.0, game.elapsed / 240.0)
	return spawn_enemy(position, nest.kind, health_scale)


func spawn_enemy(center: Vector2, kind := KIND_NORMAL, health_scale := 1.0) -> Dictionary:
	var base_hp := 5
	if kind == KIND_SWIFT:
		base_hp = 4
	elif kind == KIND_ARMORED:
		base_hp = 10
	elif kind == KIND_ELITE:
		base_hp = 18
	var hp := maxi(1, int(round(base_hp * health_scale)))
	var color := Palette.CYAN
	match kind:
		KIND_NORMAL:
			color = Palette.block_color(1)
		KIND_ARMORED:
			color = Palette.METAL.lightened(0.20)
		KIND_ELITE:
			color = Palette.PINK
	var id := _next_id
	_next_id += 1
	var block := {
		"id": id,
		"target_type": "enemy",
		"kind": kind,
		"rect": Rect2(center - CELL_SIZE * 0.5, CELL_SIZE),
		"hp": hp,
		"max_hp": hp,
		"speed_scale": _speed_for_kind(kind),
		"color": color,
		"flash": 0.0,
		"hp_bar_time": 0.0,
		"alive": true,
		"blocked_by": null,
		"attacking_base": false,
		"attack_flash": 0.0,
	}
	blocks.append(block)
	by_id[id] = block
	queue_redraw()
	return block


func _physics_process(delta: float) -> void:
	if not active or game.outcome != "playing":
		return
	for b in blocks:
		if not bool(b.alive):
			continue
		if _attack_blocker(b, delta):
			continue
		var rect: Rect2 = b.rect
		if game.base_core.alive and rect.intersects(game.base_core.get_rect().grow(4.0)):
			b.attacking_base = true
			b.attack_flash = 1.0
			game.damage_base(_attack_dps(String(b.kind)) * delta)
			continue
		b.attacking_base = false
		var direction: Vector2 = (game.base_core.global_position - rect.get_center()).normalized()
		rect.position += direction * 24.0 * float(b.get("speed_scale", 1.0)) * delta
		b.rect = rect
		_try_block(b)

	var index := blocks.size() - 1
	while index >= 0:
		var b: Dictionary = blocks[index]
		if not bool(b.alive):
			by_id.erase(int(b.id))
			blocks.remove_at(index)
		index -= 1
	if not blocks.is_empty():
		queue_redraw()
	game.check_outcome()


func _attack_blocker(b: Dictionary, delta: float) -> bool:
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
	var blocker = game.get_blocking_building(b.rect)
	if blocker == null:
		return
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


func _speed_for_kind(kind: String) -> float:
	match kind:
		KIND_SWIFT:
			return 1.35
		KIND_ARMORED:
			return 0.72
		KIND_ELITE:
			return 0.85
	return 1.0


func _process(delta: float) -> void:
	if active and GameSettings.animate_monsters:
		_animation_time += delta
	if active:
		queue_redraw()
	for b in blocks:
		if float(b.get("attack_flash", 0.0)) > 0.0:
			b.attack_flash = maxf(0.0, float(b.attack_flash) - delta * 4.0)
		if float(b.get("hp_bar_time", 0.0)) > 0.0:
			b.hp_bar_time = maxf(0.0, float(b.hp_bar_time) - delta)
		if float(b.get("flash", 0.0)) > 0.0:
			b.flash = maxf(0.0, float(b.flash) - delta * 5.0)


## 炮塔的统一目标：范围内的敌人或巢穴，取距离最近者。
func get_nearest_target(origin: Vector2, max_range: float, range_cells: Array = []) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := INF if not range_cells.is_empty() else max_range * max_range
	var targets: Array = blocks.duplicate()
	targets.append_array(game.get_nest_targets())
	for target in targets:
		if not bool(target.alive):
			continue
		var rect: Rect2 = target.rect
		var center := rect.get_center()
		if not range_cells.is_empty() and not _cell_in_range(center, range_cells):
			continue
		var dist := center.distance_squared_to(origin)
		if dist <= best_dist:
			best_dist = dist
			best = target
	return best


func _cell_in_range(point: Vector2, range_cells: Array) -> bool:
	var cell: Vector2i = game.arena.map_loader.world_to_cell(point)
	return range_cells.has(cell)


func damage(id: int, amount: int) -> Dictionary:
	var value = by_id.get(id)
	if value == null:
		return {"hit": false}
	var block: Dictionary = value
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
		return {"hit": true, "destroyed": true, "rect": block.rect, "max_hp": int(block.max_hp), "color": block.color}
	queue_redraw()
	return {"hit": true, "destroyed": false, "rect": block.rect, "max_hp": int(block.max_hp), "color": block.color}


func _draw_kind(inner: Rect2, kind: String, col: Color, alpha := 1.0) -> void:
	var c := inner.get_center() + Vector2(0.0, -2.0)
	match kind:
		KIND_SWIFT:
			var mark := Color(0.9, 1.0, 1.0, 0.72 * alpha)
			draw_polyline(PackedVector2Array([c + Vector2(-8.0, -5.0), c + Vector2(0.0, 2.0), c + Vector2(8.0, -5.0)]), mark, 2.0, true)
		KIND_ARMORED:
			draw_rect(inner.grow(-3.0), Color(col.lightened(0.35), alpha), false, 2.0)
			for x in [inner.position.x + 5.0, inner.end.x - 5.0]:
				draw_circle(Vector2(x, inner.position.y + 5.0), 1.5, Color(col.lightened(0.55), alpha))
		KIND_ELITE:
			draw_arc(c, 7.0, 0.0, TAU, 6, Color(col.lightened(0.60), alpha), 2.0, true)
			draw_circle(c, 2.5, Color(1.0, 0.9, 0.95, 0.85 * alpha))


func _draw_health_bar(inner: Rect2, hp: int, max_hp: int, alpha := 1.0) -> void:
	var ratio := clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	var back := Rect2(Vector2(inner.position.x + 4.0, inner.end.y - HEALTH_BAR_HEIGHT - 2.0), Vector2(inner.size.x - 8.0, HEALTH_BAR_HEIGHT))
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
		var max_hp: int = int(b.max_hp)
		var hp: int = int(b.hp)
		var col: Color = b.color
		var kind := String(b.get("kind", KIND_NORMAL))
		var alpha := 1.0
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
		draw_circle(rect.get_center() + Vector2(0, 5), 19.0, Color(0.0, 0.0, 0.0, 0.12))
		draw_circle(rect.get_center(), 25.0, Color(col.r, col.g, col.b, 0.05))
		if animation != null:
			draw_texture_rect_region(animation, art_rect, frame_rect, Color.WHITE)
		elif texture != null:
			draw_texture_rect(texture, art_rect, false, Color.WHITE)
		else:
			draw_rect(rect, Color(col.darkened(0.72), alpha))
			_draw_kind(inner, kind, col, alpha)
		var flash := float(b.get("flash", 0.0))
		if flash > 0.0 and animation != null:
			draw_texture_rect_region(animation, art_rect, frame_rect, Color(2.0, 2.0, 2.0, 0.65 * flash))
		elif flash > 0.0 and texture != null:
			draw_texture_rect(texture, art_rect, false, Color(2.0, 2.0, 2.0, 0.65 * flash))
		var attack_flash := float(b.get("attack_flash", 0.0))
		if attack_flash > 0.0 and (b.get("blocked_by", null) != null or bool(b.get("attacking_base", false))):
			var claw := rect.get_center() + Vector2(0.0, rect.size.y * 0.42)
			for k in 3:
				var x := claw.x - 8.0 + k * 8.0
				draw_line(Vector2(x, claw.y), Vector2(x - 3.0, claw.y + 9.0), Color(0.95, 0.32, 0.28, 0.8 * attack_flash), 2.0)
		if float(b.get("hp_bar_time", 0.0)) > 0.0 and hp < max_hp:
			_draw_health_bar(inner, hp, max_hp, alpha)
