extends Node2D

## 巢穴生成的敌人集合。敌人从任意方向接近中央基地，并攻击途中拦截建筑。

const Palette = preload("res://scripts/palette.gd")
const EnemySpatialIndex = preload("res://scripts/enemy_spatial_index.gd")
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
const ENEMY_CONTACT_RADIUS := 18.0
const HEALTH_BAR_HEIGHT := 6.0
const HEALTH_BAR_DURATION := 3.0
const ENEMY_BATCH_CAPACITY := 2048
const ENEMY_QUAD_SIZE := 64.0
const ENEMY_KINDS := [KIND_NORMAL, KIND_SWIFT, KIND_ARMORED, KIND_ELITE]
const ENEMY_SHADER_CODE := """
shader_type canvas_item;

uniform sampler2D monster_texture : source_color, filter_linear, repeat_disable;
uniform vec4 kind_color : source_color;
uniform vec2 art_size;
varying vec4 enemy_data;

void vertex() {
	enemy_data = INSTANCE_CUSTOM;
}

float circle_mask(vec2 point, vec2 center, float radius) {
	return 1.0 - step(radius, distance(point, center));
}

float segment_distance(vec2 point, vec2 a, vec2 b) {
	vec2 pa = point - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

vec4 over(vec4 front, vec4 back) {
	return front + back * (1.0 - front.a);
}

void fragment() {
	vec2 local = (UV - 0.5) * 64.0;
	float shadow_alpha = 0.12 * circle_mask(local, vec2(0.0, 5.0), 19.0);
	vec4 accumulated = vec4(0.0, 0.0, 0.0, shadow_alpha);
	float glow_alpha = 0.05 * circle_mask(local, vec2(0.0), 25.0);
	accumulated = over(vec4(kind_color.rgb * glow_alpha, glow_alpha), accumulated);

	vec2 art_uv = (local - vec2(0.0, -3.0) + art_size * 0.5) / art_size;
	vec4 texel = vec4(0.0);
	if (all(greaterThanEqual(art_uv, vec2(0.0))) && all(lessThanEqual(art_uv, vec2(1.0)))) {
		float frame = clamp(floor(enemy_data.r + 0.5), 0.0, 3.0);
		vec2 atlas_uv = vec2((frame + art_uv.x) * 0.25, art_uv.y);
		texel = texture(monster_texture, atlas_uv);
	}
	accumulated = over(vec4(texel.rgb * texel.a, texel.a), accumulated);
	float flash_alpha = texel.a * 0.65 * clamp(enemy_data.g, 0.0, 1.0);
	accumulated = over(vec4(texel.rgb * 2.0 * flash_alpha, flash_alpha), accumulated);

	float claw_mask = 0.0;
	for (int k = 0; k < 3; k++) {
		float x = -8.0 + float(k) * 8.0;
		float d = segment_distance(local, vec2(x, 12.6), vec2(x - 3.0, 21.6));
		claw_mask = max(claw_mask, 1.0 - step(1.0, d));
	}
	float claw_alpha = 0.8 * clamp(enemy_data.b, 0.0, 1.0) * claw_mask;
	vec3 claw_color = vec3(0.95, 0.32, 0.28);
	accumulated = over(vec4(claw_color * claw_alpha, claw_alpha), accumulated);
	COLOR = vec4(accumulated.rgb / max(accumulated.a, 0.0001), accumulated.a);
}
"""

var blocks: Array[Dictionary] = []
var by_id := {}
var destroyed := 0
var active := false
var game: Node
var spatial_index := EnemySpatialIndex.new()

var _next_id := 1
var _rng := RandomNumberGenerator.new()
var _animation_time := 0.0
var _enemy_batches: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	_setup_enemy_batches()


func _setup_enemy_batches() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * ENEMY_QUAD_SIZE
	var shader := Shader.new()
	shader.code = ENEMY_SHADER_CODE
	for kind in ENEMY_KINDS:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		multimesh.use_custom_data = true
		multimesh.mesh = quad
		multimesh.instance_count = ENEMY_BATCH_CAPACITY
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("monster_texture", MONSTER_ANIMATIONS[kind])
		mat.set_shader_parameter("kind_color", _color_for_kind(kind))
		mat.set_shader_parameter("art_size", _art_size_for_kind(kind))
		var node := MultiMeshInstance2D.new()
		node.name = "EnemyBatch_" + kind
		node.multimesh = multimesh
		node.material = mat
		node.show_behind_parent = true
		add_child(node)
		var free_slots: Array[int] = []
		for slot in range(ENEMY_BATCH_CAPACITY - 1, -1, -1):
			multimesh.set_instance_transform_2d(slot, _hidden_instance_transform())
			multimesh.set_instance_custom_data(slot, Color(0.0, 0.0, 0.0, 0.0))
			free_slots.append(slot)
		_enemy_batches[kind] = {"multimesh": multimesh, "free_slots": free_slots}


func _hidden_instance_transform() -> Transform2D:
	return Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)


func _color_for_kind(kind: String) -> Color:
	match kind:
		KIND_SWIFT:
			return Palette.CYAN
		KIND_ARMORED:
			return Palette.METAL.lightened(0.20)
		KIND_ELITE:
			return Palette.PINK
	return Palette.block_color(1)


func _art_size_for_kind(kind: String) -> Vector2:
	match kind:
		KIND_SWIFT:
			return Vector2(50.0, 46.0)
		KIND_ARMORED:
			return Vector2(56.0, 50.0)
		KIND_ELITE:
			return Vector2(58.0, 54.0)
	return Vector2(52.0, 48.0)


func _animation_fps(kind: String) -> float:
	match kind:
		KIND_SWIFT:
			return 12.0
		KIND_ARMORED:
			return 6.0
		KIND_ELITE:
			return 7.0
	return 8.0


func _allocate_enemy_slot(enemy: Dictionary) -> void:
	var kind := String(enemy.get("kind", KIND_NORMAL))
	if not _enemy_batches.has(kind):
		kind = KIND_NORMAL
	var batch: Dictionary = _enemy_batches[kind]
	var free_slots: Array = batch["free_slots"]
	if free_slots.is_empty():
		enemy["_batch_kind"] = kind
		enemy["_slot"] = -1
		return
	enemy["_batch_kind"] = kind
	enemy["_slot"] = int(free_slots.pop_back())
	_update_enemy_instance(enemy)


func _release_enemy_slot(enemy: Dictionary) -> void:
	var slot := int(enemy.get("_slot", -1))
	var kind := String(enemy.get("_batch_kind", KIND_NORMAL))
	if slot < 0 or not _enemy_batches.has(kind):
		return
	var batch: Dictionary = _enemy_batches[kind]
	var multimesh: MultiMesh = batch["multimesh"]
	multimesh.set_instance_transform_2d(slot, _hidden_instance_transform())
	multimesh.set_instance_custom_data(slot, Color(0.0, 0.0, 0.0, 0.0))
	var free_slots: Array = batch["free_slots"]
	free_slots.append(slot)
	enemy["_slot"] = -1


func _update_enemy_instance(enemy: Dictionary) -> void:
	var slot := int(enemy.get("_slot", -1))
	if slot < 0:
		return
	var kind := String(enemy.get("_batch_kind", KIND_NORMAL))
	var batch: Dictionary = _enemy_batches[kind]
	var multimesh: MultiMesh = batch["multimesh"]
	var rect: Rect2 = enemy.rect
	multimesh.set_instance_transform_2d(slot, Transform2D(0.0, rect.get_center()))
	var phase := float(int(enemy.id) % 8) * 0.09
	var frame := int((_animation_time + phase) * _animation_fps(kind)) % 4 if GameSettings.animate_monsters else 0
	var attack := float(enemy.get("attack_flash", 0.0))
	if enemy.get("blocked_by", null) == null and not bool(enemy.get("attacking_base", false)):
		attack = 0.0
	multimesh.set_instance_custom_data(slot, Color(float(frame), float(enemy.get("flash", 0.0)), attack, 0.0))


func reset_stream() -> void:
	active = true
	clear_enemies()
	_next_id = 1
	destroyed = 0
	_animation_time = 0.0
	queue_redraw()


func clear_enemies() -> void:
	for enemy in blocks:
		_release_enemy_slot(enemy)
	blocks.clear()
	by_id.clear()
	spatial_index.clear()
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
	register_enemy(block)
	queue_redraw()
	return block


func register_enemy(enemy: Dictionary) -> void:
	_allocate_enemy_slot(enemy)
	blocks.append(enemy)
	by_id[int(enemy.id)] = enemy
	spatial_index.upsert(enemy)


func query_rect(rect: Rect2) -> Array:
	return spatial_index.query_rect(rect)


func rebuild_spatial_index() -> void:
	spatial_index.rebuild(blocks)


func _physics_process(delta: float) -> void:
	if not active or game.outcome != "playing":
		return
	for b in blocks:
		if not bool(b.alive):
			continue
		if _attack_blocker(b, delta):
			continue
		var rect: Rect2 = b.rect
		var base_contact: float = ENEMY_CONTACT_RADIUS + game.base_core.get_contact_radius()
		if game.base_core.alive and rect.get_center().distance_squared_to(game.base_core.global_position) <= base_contact * base_contact:
			b.attacking_base = true
			b.attack_flash = 1.0
			game.damage_base(_attack_dps(String(b.kind)) * delta)
			continue
		b.attacking_base = false
		var direction: Vector2 = (game.base_core.global_position - rect.get_center()).normalized()
		rect.position += direction * 24.0 * float(b.get("speed_scale", 1.0)) * delta
		b.rect = rect
		spatial_index.upsert(b)
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
		if bool(b.alive):
			_update_enemy_instance(b)


## 炮塔目标：敌人来自射程格空间桶，少量巢穴仍逐一检查。
func get_nearest_target(origin: Vector2, max_range: float, range_cells: Array = []) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := INF if not range_cells.is_empty() else max_range * max_range
	var targets: Array = spatial_index.query_cells(range_cells) if not range_cells.is_empty() else spatial_index.query_circle(origin, max_range)
	targets.append_array(game.get_nest_targets())
	for target in targets:
		if not bool(target.alive):
			continue
		var rect: Rect2 = target.rect
		var center := rect.get_center()
		if not range_cells.is_empty() and String(target.get("target_type", "enemy")) == "nest" and not _cell_in_range(center, range_cells):
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
	if int(block.hp) <= 0:
		block.alive = false
		_release_enemy_slot(block)
		spatial_index.remove(id)
		block.hp_bar_time = 0.0
		destroyed += 1
		Events.set_destroyed(destroyed)
		queue_redraw()
		return {"hit": true, "destroyed": true, "rect": block.rect, "max_hp": int(block.max_hp), "color": block.color}
	queue_redraw()
	return {"hit": true, "destroyed": false, "rect": block.rect, "max_hp": int(block.max_hp), "color": block.color}


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
	# 怪物与特效由 MultiMesh 绘制；这里只保留需要独立更新的血条。
	for b in blocks:
		if not bool(b.alive):
			continue
		var hp := int(b.hp)
		var max_hp := int(b.max_hp)
		if float(b.get("hp_bar_time", 0.0)) > 0.0 and hp < max_hp:
			_draw_health_bar(b.rect.grow(-2.0), hp, max_hp)
