extends Node2D

## 巢穴：独立计时生成怪物，可被炮塔和炮弹摧毁。

const Palette = preload("res://scripts/palette.gd")

var game: Node
var id := 0
var cell := Vector2i.ZERO
var kind := "normal"
var max_hp := 80
var hp := 80.0
var spawn_interval := 5.0
var spawn_count := 1
var spawn_timer := 1.0
var reward := 25
var alive := true
var _age := 0.0
var _hurt_flash := 0.0
var _texture: Texture2D


func setup(g: Node, definition: Dictionary) -> void:
	game = g
	id = int(definition.get("id", 0))
	cell = definition.get("cell", Vector2i.ZERO)
	kind = String(definition.get("kind", "normal"))
	max_hp = int(definition.get("hp", 80))
	hp = float(max_hp)
	spawn_interval = float(definition.get("spawn_interval", 5.0))
	spawn_count = maxi(1, int(definition.get("spawn_count", 1)))
	spawn_timer = 0.8 + id * 0.35
	reward = int(definition.get("reward", 25))
	position = game.arena.map_loader.cell_to_world(cell)
	if ResourceLoader.exists("res://assets/ui/nest.png"):
		_texture = load("res://assets/ui/nest.png")


func _ready() -> void:
	z_index = 3


func _process(delta: float) -> void:
	if not alive:
		return
	_age += delta
	_hurt_flash = maxf(0.0, _hurt_flash - delta * 4.0)
	if not game.preparing and game.outcome == "playing":
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer += spawn_interval
			for index in spawn_count:
				game.blocks.spawn_from_nest(self)
	queue_redraw()


func get_rect() -> Rect2:
	return Rect2(global_position - Vector2(38, 34), Vector2(76, 68))


func get_target() -> Dictionary:
	return {
		"id": 100000 + id,
		"target_type": "nest",
		"node": self,
		"rect": get_rect(),
		"hp": int(ceil(hp)),
		"max_hp": max_hp,
		"alive": alive,
		"color": Palette.PINK,
	}


func take_damage(amount: int) -> bool:
	if not alive or amount <= 0:
		return false
	hp = maxf(0.0, hp - amount)
	_hurt_flash = 1.0
	if hp <= 0.0:
		alive = false
		game.on_nest_destroyed(self)
		queue_free()
		return true
	queue_redraw()
	return false


func _draw() -> void:
	if not alive:
		return
	var pulse := 0.5 + 0.5 * sin(_age * 3.0 + id)
	var rect := Rect2(Vector2(-62, -62), Vector2(124, 124))
	draw_circle(Vector2(0, 8), 48.0 + pulse * 3.0, Color(0.15, 0.02, 0.08, 0.10 + pulse * 0.05))
	if _texture != null:
		draw_texture_rect(_texture, rect, false, Color.WHITE)
	else:
		draw_circle(Vector2.ZERO, 48, Color(0.15, 0.10, 0.18))
		draw_arc(Vector2.ZERO, 40, 0, TAU, 12, Palette.PINK.darkened(0.25), 10.0)
		draw_circle(Vector2.ZERO, 24 + pulse * 3, Color(0.04, 0.02, 0.05))
		draw_circle(Vector2.ZERO, 12 + pulse * 2, Palette.ACCENT)
	if _hurt_flash > 0.0:
		draw_circle(Vector2.ZERO, 52, Color(1, 1, 1, 0.35 * _hurt_flash))
	if hp < max_hp:
		var bar := Rect2(Vector2(-42, 54), Vector2(84, 8))
		draw_rect(bar.grow(2), Color(0.03, 0.04, 0.05, 0.9))
		var fill := Rect2(bar.position, Vector2(bar.size.x * hp / float(max_hp), bar.size.y))
		draw_rect(fill, Palette.PINK if hp / float(max_hp) > 0.3 else Palette.DANGER)
		draw_rect(bar, Color.WHITE, false, 1.0)
