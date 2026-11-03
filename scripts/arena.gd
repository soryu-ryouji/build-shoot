extends Node2D

## 2.5D 战场：整张地图由 Blender 渲染的 48×34 地块拼出来。
## 地板铺满整个可视区域（不留黑边），地图内的路面按四向连接拼、高台整块抬起，
## 缺口、核心、边框都是同一套贴片。路线与格子坐标来自 battle_map.gd。

const Palette = preload("res://scripts/palette.gd")
const BattleMap = preload("res://scripts/battle_map.gd")

const TILE_ART := "res://assets/ui/tiles/"
## 贴片画布 64×64，格子地面中心在 (32,32)
const SPRITE := 64.0
const SPRITE_HALF := 32.0

## 相机取景范围：8×13 瓦片区（384×442）四周各留 24 像素
const FRAME_RECT := Rect2(48.0, 96.0, 432.0, 490.0)

var core_ratio := 1.0
var core_flash := 0.0

var _floor: Array[Texture2D] = []
var _high: Texture2D
var _rim: Texture2D
var _core: Texture2D
var _gates: Array[Texture2D] = []


func get_play_rect() -> Rect2:
	return BattleMap.field_rect()


func _ready() -> void:
	_floor = [_texture("floor_a"), _texture("floor_b")]
	_high = _texture("high")
	_rim = _texture("rim")
	_core = _texture("core")

	for index in 4:
		_gates.append(_texture("gate_%d" % index))


func _texture(name: String) -> Texture2D:
	var path := TILE_ART + name + ".png"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func set_core_ratio(value: float) -> void:
	core_ratio = clampf(value, 0.0, 1.0)
	queue_redraw()


func flash_core() -> void:
	core_flash = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if core_flash > 0.0:
		core_flash = maxf(0.0, core_flash - delta * 2.5)
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-2000.0, -2000.0), Vector2(5000.0, 5000.0)), Palette.BG)
	var bounds := _visible_tiles()
	_draw_ground(bounds)
	_draw_map()
	_draw_core()


## 可视范围覆盖的格子区间（往外多铺两格，避免边缘露底）
func _visible_tiles() -> Dictionary:
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	var view := get_viewport_rect().size
	var world_a := inverse * Vector2.ZERO
	var world_b := inverse * view
	var min_world := Vector2(minf(world_a.x, world_b.x), minf(world_a.y, world_b.y))
	var max_world := Vector2(maxf(world_a.x, world_b.x), maxf(world_a.y, world_b.y))
	return {
		"c0": floori((min_world.x - BattleMap.ORIGIN.x) / BattleMap.TILE) - 1,
		"c1": floori((max_world.x - BattleMap.ORIGIN.x) / BattleMap.TILE) + 1,
		"r0": floori((min_world.y - BattleMap.ORIGIN.y) / BattleMap.TILE_H) - 1,
		"r1": floori((max_world.y - BattleMap.ORIGIN.y) / BattleMap.TILE_H) + 1,
	}


## 地板：铺满可视区域，地图外面也铺，屏幕上不会露出空白
func _draw_ground(bounds: Dictionary) -> void:
	for row in range(int(bounds.r0), int(bounds.r1) + 1):
		for col in range(int(bounds.c0), int(bounds.c1) + 1):
			var texture: Texture2D = _floor[absi(col + row) % _floor.size()]
			_draw_tile(texture, BattleMap.tile_center(Vector2i(col, row)))


## 地图内容：先铺路面带，再按行铺高台和缺口，南侧的高块自然压住北侧
func _draw_map() -> void:
	_draw_road()
	var gates: Array = BattleMap.gates()
	var gate_index := {}
	for index in gates.size():
		gate_index[gates[index]] = index

	for row in BattleMap.ROWS:
		for col in BattleMap.COLS:
			var tile := Vector2i(col, row)
			var center := BattleMap.tile_center(tile)
			if BattleMap.is_high(tile):
				_draw_tile(_high, center)
			elif gate_index.has(tile):
				_draw_tile(_gates[gate_index[tile] % _gates.size()], center)

	# 外框：地图四周一圈矮墙，把战场和外面的地板分开
	for col in range(-1, BattleMap.COLS + 1):
		_draw_tile(_rim, BattleMap.tile_center(Vector2i(col, -1)))
		_draw_tile(_rim, BattleMap.tile_center(Vector2i(col, BattleMap.ROWS)))
	for row in BattleMap.ROWS:
		_draw_tile(_rim, BattleMap.tile_center(Vector2i(-1, row)))
		_draw_tile(_rim, BattleMap.tile_center(Vector2i(BattleMap.COLS, row)))


## 路面：在地板之上画一条连续的路带（走廊式，2 格宽的一半），再压中心线和方向箭头
func _draw_road() -> void:
	var half := 17.0
	var road := Color(0.16, 0.18, 0.20, 0.92)
	var line := Color(0.72, 0.76, 0.78, 0.55)
	for segment in BattleMap.segments():
		draw_line(segment[0], segment[1], road, half * 2.0)
	for route in BattleMap.active_map().routes:
		for tile in route:
			draw_rect(Rect2(BattleMap.tile_center(tile) - Vector2(half, half), Vector2(half, half) * 2.0), road)
	for segment in BattleMap.segments():
		draw_line(segment[0], segment[1], line, 2.0)


func _draw_tile(texture: Texture2D, center: Vector2) -> void:
	if texture == null:
		return
	draw_texture_rect(texture, Rect2(center - Vector2(SPRITE_HALF, SPRITE_HALF), Vector2(SPRITE, SPRITE)), false)


## 核心：2 格大小的装置 + 血条 + 受击脉冲
func _draw_core() -> void:
	var center := BattleMap.core_center()
	if _core != null:
		draw_texture_rect(_core, Rect2(center - Vector2(64.0, 64.0), Vector2(128.0, 128.0)), false)
	if core_flash > 0.0:
		draw_circle(center, 42.0, Color(Palette.DANGER, 0.28 * core_flash))
	var bar := Rect2(center + Vector2(-34.0, -46.0), Vector2(68.0, 5.0))
	draw_rect(bar, Color(0.02, 0.04, 0.05, 0.8))
	if core_ratio > 0.0:
		draw_rect(
			Rect2(bar.position, Vector2(bar.size.x * core_ratio, bar.size.y)),
			Palette.CYAN if core_ratio > 0.3 else Palette.DANGER,
		)
	draw_rect(bar, Color(1.0, 1.0, 1.0, 0.25), false, 1.0)
