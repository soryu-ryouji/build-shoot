extends Node2D

## 一体式战场地图：外围机械背景、瓦片地面、敌人通路、顶部缺口与底部核心都在这一层绘制。
## 路线与格子坐标来自 battle_map.gd，绘制不做任何二次推算。

const Palette = preload("res://scripts/palette.gd")
const BattleMap = preload("res://scripts/battle_map.gd")
const ArenaTexture = preload("res://assets/ui/arena.png")

const FRAME_RECT := Rect2(48.0, 96.0, 624.0, 720.0)
const TEXTURE_RECT := Rect2(0.0, 0.0, 720.0, 960.0)
const TEXTURE_TILES := Rect2(-1440.0, -1920.0, 3600.0, 4800.0)

const ROAD_WIDTH := 34.0
const ROAD_COLOR := Color(0.38, 0.43, 0.47, 0.62)
const ROAD_EDGE := Color(0.95, 0.97, 0.99, 0.30)

## 核心血量比例，由 main 在掉血时同步过来
var core_ratio := 1.0
## 核心刚被撞时的红色脉冲
var core_flash := 0.0

var _gate_style: StyleBoxFlat
var _gate_glow: StyleBoxFlat
var _core_style: StyleBoxFlat
var _core_glow: StyleBoxFlat
## 当前地图的地板、缺口与核心贴图；素材缺失时回退到代码绘制
var _floor_texture: Texture2D
var _gate_texture: Texture2D
var _core_texture: Texture2D


func get_play_rect() -> Rect2:
	return BattleMap.field_rect()


func _ready() -> void:
	GameSettings.changed.connect(queue_redraw)
	_floor_texture = _load_texture(BattleMap.art_path())
	_gate_texture = _load_texture("res://assets/ui/gate.png")
	_core_texture = _load_texture("res://assets/ui/core.png")
	_gate_style = _style(Color(Palette.INK, 0.92), Color(Palette.DANGER.darkened(0.2), 0.9), 8, 2)
	_gate_glow = _style(Color(Palette.DANGER, 0.22), Color(0, 0, 0, 0), 6, 0)
	_core_style = _style(Color(Palette.INK, 0.94), Color(Palette.CYAN, 0.9), 10, 2)
	_core_glow = _style(Color(Palette.CYAN, 0.14), Color(0, 0, 0, 0), 8, 0)


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _style(fill: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


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
	draw_rect(TEXTURE_RECT, Palette.ARENA_BG)
	# 外围机械背景：长屏与横屏超出原图时延续地图，而不是露出纯色空白
	draw_texture_rect(ArenaTexture, TEXTURE_TILES, true, Color.WHITE)

	_draw_floor()
	_draw_road()
	_draw_core()
	_draw_gates()
	_draw_frame()


## 瓦片地面：该地图的地板贴图铺满瓦片区；缺贴图时回退到浅色底 + 格子缝
func _draw_floor() -> void:
	var field := BattleMap.field_rect()
	if _floor_texture != null:
		draw_texture_rect(_floor_texture, field, false)
		return
	draw_rect(field, Color(Palette.PAPER, 0.20))
	if GameSettings.show_grid:
		var seam := Color(Palette.INK, 0.055)
		for c in BattleMap.COLS + 1:
			var x := field.position.x + c * BattleMap.TILE
			draw_line(Vector2(x, field.position.y), Vector2(x, field.end.y), seam, 1.0)
		for r in BattleMap.ROWS + 1:
			var y := field.position.y + r * BattleMap.TILE
			draw_line(Vector2(field.position.x, y), Vector2(field.end.x, y), seam, 1.0)


## 敌人通路：路线带 + 内圈亮线 + 沿途的方向箭头
func _draw_road() -> void:
	var routes: Array = BattleMap.active_map().routes
	for segment in BattleMap.segments():
		draw_line(segment[0], segment[1], ROAD_COLOR, ROAD_WIDTH)
	for route in routes:
		for i in route.size() - 1:
			var a: Vector2 = BattleMap.tile_center(route[i])
			var b: Vector2 = BattleMap.tile_center(route[i + 1])
			draw_line(a, b, ROAD_EDGE, 2.0, true)

	# 转角处补一块方形，避免直角出现缺口（不用圆，圆会让整条路看起来像一串珠子）
	var joint := Vector2(ROAD_WIDTH, ROAD_WIDTH)
	for route in routes:
		for tile in route:
			draw_rect(Rect2(BattleMap.tile_center(tile) - joint * 0.5, joint), ROAD_COLOR)

	# 方向箭头：每三格一个，指向核心方向
	for route in routes:
		var i := 0
		while i < route.size() - 1:
			var a: Vector2 = BattleMap.tile_center(route[i])
			var b: Vector2 = BattleMap.tile_center(route[i + 1])
			var dir := (b - a).normalized()
			var side := Vector2(-dir.y, dir.x)
			var tip := a + (b - a) * 0.5
			draw_polyline(PackedVector2Array([
				tip - dir * 7.0 + side * 7.0,
				tip + dir * 7.0,
				tip - dir * 7.0 - side * 7.0,
			]), Color(1.0, 0.98, 0.94, 0.55), 2.0, true)
			i += 3


func _draw_gates() -> void:
	for index in BattleMap.gates().size():
		var tile: Vector2i = BattleMap.gate_tile(index)
		var rect := BattleMap.tile_rect(tile)
		if _gate_texture != null:
			# 门洞按路线离开缺口的方向旋转，让开口朝着敌人要走的通路
			var route: Array = BattleMap.route_for_gate(index)
			var direction := Vector2.DOWN
			if route.size() > 1:
				direction = (BattleMap.tile_center(route[1]) - BattleMap.tile_center(route[0])).normalized()
			var size := Vector2(46.0, 68.0)
			var pivot := rect.get_center() + direction * 6.0
			draw_set_transform(pivot, direction.angle() - PI * 0.5, Vector2.ONE)
			draw_texture_rect(_gate_texture, Rect2(-size * 0.5, size), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		var inner := rect.grow(-4.0)
		draw_style_box(_gate_glow, inner.grow(4.0))
		draw_style_box(_gate_style, inner)
		# 门口朝下的箭头，和通路方向一致
		var center := inner.get_center()
		draw_polyline(PackedVector2Array([
			center + Vector2(-11.0, -7.0),
			center + Vector2(0.0, 4.0),
			center + Vector2(11.0, -7.0),
		]), Color(Palette.ACCENT, 0.75), 2.5, true)


func _draw_core() -> void:
	var left := BattleMap.tile_rect(BattleMap.core_tiles()[0])
	var right := BattleMap.tile_rect(BattleMap.core_tiles()[1])
	var rect := Rect2(left.position, Vector2(right.end.x - left.position.x, left.size.y)).grow(-3.0)
	var flash := core_flash
	_core_glow.bg_color = Color(Palette.CYAN, 0.10 + 0.10 * core_ratio + 0.25 * flash)
	draw_style_box(_core_glow, rect.grow(5.0))
	_core_style.border_color = Color(Palette.DANGER if flash > 0.2 else Palette.CYAN, 0.9)
	draw_style_box(_core_style, rect)

	var center := rect.get_center()
	if _core_texture != null:
		# 核心贴图按 1.4 格绘制，压住基座两侧
		var art := BattleMap.TILE * 1.4
		draw_texture_rect(_core_texture, Rect2(center - Vector2(art, art) * 0.5, Vector2(art, art)), false)
	else:
		# 回退：同心环 + 中心光点
		draw_arc(center, 17.0, 0.0, TAU, 32, Color(Palette.CYAN, 0.55 + 0.35 * flash), 2.0, true)
		draw_arc(center, 11.0, -PI * 0.5, PI * 1.5, 24, Color(Palette.PAPER, 0.75), 1.5, true)
		draw_circle(center, 4.0 + 1.5 * flash, Color(Palette.CYAN, 0.9))

	# 核心血量条压在结构上沿
	var bar := Rect2(rect.position + Vector2(6.0, -8.0), Vector2(rect.size.x - 12.0, 5.0))
	draw_rect(bar, Color(0.02, 0.04, 0.05, 0.75))
	if core_ratio > 0.0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * core_ratio, bar.size.y)), Palette.CYAN if core_ratio > 0.3 else Palette.DANGER)
	draw_rect(bar, Color(1.0, 1.0, 1.0, 0.22), false, 1.0)


func _draw_frame() -> void:
	# 细边框配合四角标记，不再用整圈高亮霓虹压住画面。
	draw_rect(FRAME_RECT, Color(Palette.INK.r, Palette.INK.g, Palette.INK.b, 0.72), false, 2.0)
	draw_rect(FRAME_RECT.grow(-4.0), Color(Palette.PAPER.r, Palette.PAPER.g, Palette.PAPER.b, 0.55), false, 1.0)
	var corner_color := Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.65)
	_draw_corner(FRAME_RECT.position, Vector2(1, 1), corner_color)
	_draw_corner(Vector2(FRAME_RECT.end.x, FRAME_RECT.position.y), Vector2(-1, 1), corner_color)
	_draw_corner(Vector2(FRAME_RECT.position.x, FRAME_RECT.end.y), Vector2(1, -1), corner_color)
	_draw_corner(FRAME_RECT.end, Vector2(-1, -1), corner_color)


func _draw_corner(point: Vector2, direction: Vector2, color: Color) -> void:
	draw_line(point, point + Vector2(direction.x * 30.0, 0.0), color, 2.0)
	draw_line(point, point + Vector2(0.0, direction.y * 30.0), color, 2.0)
