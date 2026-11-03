extends Node2D

## 2.5D 战场：整张地图由 Blender 渲染的 48×34 地块拼出来。
## 地板铺满整个可视区域，场地外压暗并加暗角，把视线收在战场上。
## 路线与格子坐标来自 battle_map.gd。

const Palette = preload("res://scripts/palette.gd")
const BattleMap = preload("res://scripts/battle_map.gd")

const TILE_ART := "res://assets/ui/tiles/"
## 贴片画布 64×64，格子地面中心在 (32,32)
const SPRITE := 64.0
const SPRITE_HALF := 32.0
## 场地外压暗后的色调
const OUTSIDE_TINT := Color(0.52, 0.55, 0.58)
## 相机取景范围：8×13 瓦片区（384×442）四周各留 24 像素
const FRAME_RECT := Rect2(48.0, 96.0, 432.0, 490.0)

var _floor: Array[Texture2D] = []
var _props: Array[Texture2D] = []
var _high: Texture2D
var _rim: Texture2D
var _core: Texture2D
var _gates: Array[Texture2D] = []

var _view_rect := Rect2()
var core_ratio := 1.0
var core_flash := 0.0


func get_play_rect() -> Rect2:
	return BattleMap.field_rect()


func _ready() -> void:
	_floor = [_texture("floor_a"), _texture("floor_b"), _texture("floor_c"), _texture("floor_d")]
	for name in ["prop_crates", "prop_pipes", "prop_barrier", "prop_coil", "prop_vent"]:
		_props.append(_texture(name))
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
	_view_rect = _visible_world_rect()
	var bounds := _visible_tiles()
	_draw_ground(bounds)
	_draw_props()
	_draw_map()
	_draw_core()
	_draw_vignette()


# ---------------------------------------------------------------- 视野与地坪

## 当前画面覆盖的世界矩形
func _visible_world_rect() -> Rect2:
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	var view := get_viewport_rect().size
	var world_a := inverse * Vector2.ZERO
	var world_b := inverse * view
	return Rect2(
		Vector2(minf(world_a.x, world_b.x), minf(world_a.y, world_b.y)),
		Vector2(absf(world_a.x - world_b.x), absf(world_a.y - world_b.y))
	)


## 可视范围覆盖的格子区间（往外多铺两格，避免边缘露底）
func _visible_tiles() -> Dictionary:
	return {
		"c0": floori((_view_rect.position.x - BattleMap.ORIGIN.x) / BattleMap.TILE) - 1,
		"c1": floori((_view_rect.end.x - BattleMap.ORIGIN.x) / BattleMap.TILE) + 1,
		"r0": floori((_view_rect.position.y - BattleMap.ORIGIN.y) / BattleMap.TILE_H) - 1,
		"r1": floori((_view_rect.end.y - BattleMap.ORIGIN.y) / BattleMap.TILE_H) + 1,
	}


func _inside_field(tile: Vector2i) -> bool:
	return tile.x >= -1 and tile.x <= BattleMap.COLS and tile.y >= -1 and tile.y <= BattleMap.ROWS


## 地板：铺满可视区域；场地外压暗，屏幕上不会露出空白
func _draw_ground(bounds: Dictionary) -> void:
	for row in range(int(bounds.r0), int(bounds.r1) + 1):
		for col in range(int(bounds.c0), int(bounds.c1) + 1):
			var tile := Vector2i(col, row)
			var tint := Color(1.0, 1.0, 1.0) if _inside_field(tile) else OUTSIDE_TINT
			_draw_tile(_floor_for(tile), BattleMap.tile_center(tile), tint)


## 四种地板变体按格子坐标固定散开，同一张图每次布局一致
func _floor_for(tile: Vector2i) -> Texture2D:
	if _floor.is_empty():
		return null
	var h := absi(tile.x * 7 + tile.y * 13 + tile.x * tile.y * 3) % 100
	if h < 48:
		return _floor[0]
	if h < 72:
		return _floor[1]
	if h < 90:
		return _floor[2]
	return _floor[mini(3, _floor.size() - 1)]


## 地图外的空地上撒装饰物，靠近边框留一格净空
func _draw_props() -> void:
	if _props.is_empty():
		return
	for row in range(-6, BattleMap.ROWS + 6):
		for col in range(-6, BattleMap.COLS + 6):
			if col >= -1 and col <= BattleMap.COLS and row >= -1 and row <= BattleMap.ROWS:
				continue
			if absi(col * 31 + row * 17 + col * row * 5) % 100 >= 20:
				continue
			var index := absi(col * 13 + row * 29) % _props.size()
			_draw_tile(_props[index], BattleMap.tile_center(Vector2i(col, row)), OUTSIDE_TINT)


# ---------------------------------------------------------------- 地图内容

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


## 路面：深色金属带 + 黄色虚线中心线
func _draw_road() -> void:
	var half := 14.0
	var road := Color(0.055, 0.062, 0.072, 0.95)
	var edge := Color(0.42, 0.44, 0.46, 0.45)
	for segment in BattleMap.segments():
		draw_line(segment[0], segment[1], road, half * 2.0)
	for route in BattleMap.active_map().routes:
		for tile in route:
			draw_rect(Rect2(BattleMap.tile_center(tile) - Vector2(half, half), Vector2(half, half) * 2.0), road)
	for segment in BattleMap.segments():
		var dir: Vector2 = (segment[1] - segment[0]).normalized()
		var normal := dir.orthogonal() * half
		draw_line(segment[0] + normal, segment[1] + normal, edge, 1.0)
		draw_line(segment[0] - normal, segment[1] - normal, edge, 1.0)
	var yellow := Color(0.85, 0.68, 0.22, 0.85)
	for segment in BattleMap.segments():
		var a: Vector2 = segment[0]
		var dir: Vector2 = (segment[1] - a).normalized()
		var length: float = a.distance_to(segment[1])
		var t := 6.0
		while t < length:
			draw_line(a + dir * t, a + dir * minf(t + 6.0, length), yellow, 2.0)
			t += 14.0


func _draw_tile(texture: Texture2D, center: Vector2, tint := Color.WHITE) -> void:
	if texture == null:
		return
	draw_texture_rect(texture, Rect2(center - Vector2(SPRITE_HALF, SPRITE_HALF), Vector2(SPRITE, SPRITE)), false, tint)


# ---------------------------------------------------------------- 核心与暗角

## 核心：2 格大小的装置 + 血条 + 受击脉冲
func _draw_core() -> void:
	var center := BattleMap.core_center()
	if _core != null:
		draw_texture_rect(_core, Rect2(center - Vector2(56.0, 56.0), Vector2(112.0, 112.0)), false)
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


## 四周压暗，把视线收在战场中间
func _draw_vignette() -> void:
	var frame := FRAME_RECT
	var view := _view_rect
	var step := 26.0
	var i := 0
	while frame.position.y - step * (i + 1) > view.position.y:
		var a := minf(0.06 + i * 0.035, 0.55)
		draw_rect(Rect2(view.position.x, frame.position.y - step * (i + 1), view.size.x, step), Color(0.02, 0.03, 0.04, a))
		i += 1
	i = 0
	while frame.end.y + step * i < view.end.y:
		var a := minf(0.06 + i * 0.035, 0.55)
		draw_rect(Rect2(view.position.x, frame.end.y + step * i, view.size.x, step), Color(0.02, 0.03, 0.04, a))
		i += 1
	i = 0
	while frame.position.x - step * (i + 1) > view.position.x:
		var a := minf(0.05 + i * 0.02, 0.35)
		draw_rect(Rect2(frame.position.x - step * (i + 1), view.position.y, step, view.size.y), Color(0.02, 0.03, 0.04, a))
		i += 1
	i = 0
	while frame.end.x + step * i < view.end.x:
		var a := minf(0.05 + i * 0.02, 0.35)
		draw_rect(Rect2(frame.end.x + step * i, view.position.y, step, view.size.y), Color(0.02, 0.03, 0.04, a))
		i += 1
