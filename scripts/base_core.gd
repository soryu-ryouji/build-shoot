extends Node2D

## 中央基地：怪物抵达后持续攻击，生命归零时本局失败。

const Palette = preload("res://scripts/palette.gd")

var game: Node
var cell := Vector2i.ZERO
var max_hp := 1000
var hp := 1000.0
var alive := true
var body_size := Vector2(176, 176)
var _hurt_flash := 0.0
var _texture: Texture2D


func setup(g: Node, definition: Dictionary) -> void:
	game = g
	cell = definition.get("cell", Vector2i.ZERO)
	max_hp = int(definition.get("hp", 1000))
	hp = float(max_hp)
	position = game.arena.map_loader.cell_to_world(cell)
	var cells: Vector2i = definition.get("size", Vector2i(3, 3))
	body_size = Vector2(cells) * 64.0 - Vector2(16.0, 16.0)
	if ResourceLoader.exists("res://assets/ui/base_core.png"):
		_texture = load("res://assets/ui/base_core.png")


func _ready() -> void:
	z_index = 3


func _process(delta: float) -> void:
	_hurt_flash = maxf(0.0, _hurt_flash - delta * 3.5)
	if alive:
		queue_redraw()


func get_rect() -> Rect2:
	return Rect2(global_position - body_size * 0.42, body_size * 0.84)


func take_damage(amount: float) -> void:
	if not alive or amount <= 0.0 or game.outcome != "playing":
		return
	hp = maxf(0.0, hp - amount)
	_hurt_flash = 1.0
	if hp <= 0.0:
		alive = false
		game.on_base_destroyed()
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-body_size * 0.5, body_size)
	draw_circle(Vector2(0, 12), body_size.x * 0.43, Color(0, 0, 0, 0.16))
	if _texture != null:
		draw_texture_rect(_texture, rect, false, Color.WHITE if alive else Color(0.35, 0.37, 0.39))
	else:
		var color := Color(0.83, 0.84, 0.80) if alive else Color(0.30, 0.32, 0.34)
		draw_circle(Vector2.ZERO, body_size.x * 0.43, Color(0.15, 0.18, 0.20))
		draw_circle(Vector2.ZERO, body_size.x * 0.37, color)
		draw_arc(Vector2.ZERO, body_size.x * 0.29, 0, TAU, 6, Palette.ACCENT, 6.0)
		draw_circle(Vector2.ZERO, body_size.x * 0.16, Palette.CYAN)
	if _hurt_flash > 0.0:
		draw_circle(Vector2.ZERO, body_size.x * 0.45, Color(1.0, 0.25, 0.18, 0.24 * _hurt_flash))

	var bar := Rect2(Vector2(-70, body_size.y * 0.43), Vector2(140, 10))
	draw_rect(bar.grow(2), Color(0.03, 0.04, 0.05, 0.88))
	var ratio := clampf(hp / float(maxi(max_hp, 1)), 0.0, 1.0)
	var fill := Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y))
	draw_rect(fill, Palette.CYAN if ratio > 0.3 else Palette.DANGER)
	draw_rect(bar, Color.WHITE, false, 1.0)
