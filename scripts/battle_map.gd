extends RefCounted

## 多张一体式瓦片地图：12×14 的格子，敌人沿画在地图上的通路从缺口走到核心。
## 地图数据（路线、缺口、核心、地板贴图）只在这里定义，绘制和行走共用同一份坐标。

const COLS := 12
const ROWS := 14
const TILE := 48.0
const ORIGIN := Vector2(72.0, 120.0)

## 阵地在通路上也能建（相当于明日方舟的近战阻挡位），火力和能源只能放在路外。
const CATEGORY_FORTIFICATION := "fortification"

const ROUTE_JUNCTION_A := [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3),
	Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3),
	Vector2i(5, 4), Vector2i(5, 5), Vector2i(5, 6),
	Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 6),
	Vector2i(8, 7), Vector2i(8, 8), Vector2i(8, 9), Vector2i(8, 10),
	Vector2i(7, 10), Vector2i(6, 10),
	Vector2i(6, 11), Vector2i(6, 12), Vector2i(6, 13),
]

const ROUTE_JUNCTION_B := [
	Vector2i(10, 0), Vector2i(10, 1), Vector2i(10, 2),
	Vector2i(9, 2), Vector2i(8, 2),
	Vector2i(8, 3), Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 6),
	Vector2i(8, 7), Vector2i(8, 8), Vector2i(8, 9), Vector2i(8, 10),
	Vector2i(7, 10), Vector2i(6, 10),
	Vector2i(6, 11), Vector2i(6, 12), Vector2i(6, 13),
]

const ROUTE_CHICANE_A := [
	Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4),
	Vector2i(1, 4), Vector2i(2, 4), Vector2i(2, 5), Vector2i(2, 6), Vector2i(2, 7),
	Vector2i(2, 8), Vector2i(3, 8), Vector2i(4, 8), Vector2i(5, 8),
	Vector2i(5, 9), Vector2i(5, 10), Vector2i(5, 11),
	Vector2i(6, 11), Vector2i(6, 12), Vector2i(6, 13),
]

const ROUTE_CHICANE_B := [
	Vector2i(11, 1), Vector2i(11, 2), Vector2i(11, 3), Vector2i(11, 4),
	Vector2i(10, 4), Vector2i(9, 4), Vector2i(9, 5), Vector2i(9, 6), Vector2i(9, 7),
	Vector2i(9, 8), Vector2i(8, 8), Vector2i(7, 8), Vector2i(6, 8),
	Vector2i(6, 9), Vector2i(6, 10), Vector2i(6, 11),
	Vector2i(6, 12), Vector2i(6, 13),
]

const ROUTE_ZIGZAG_A := [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2),
	Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2),
	Vector2i(5, 3), Vector2i(5, 4), Vector2i(5, 5),
	Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5),
	Vector2i(8, 6), Vector2i(8, 7), Vector2i(8, 8),
	Vector2i(7, 8), Vector2i(6, 8), Vector2i(5, 8), Vector2i(4, 8), Vector2i(3, 8),
	Vector2i(3, 9), Vector2i(3, 10),
	Vector2i(4, 10), Vector2i(5, 10), Vector2i(6, 10), Vector2i(7, 10), Vector2i(8, 10),
	Vector2i(9, 10), Vector2i(9, 11), Vector2i(9, 12), Vector2i(9, 13),
]

const ROUTE_ZIGZAG_B := [
	Vector2i(10, 0), Vector2i(10, 1), Vector2i(10, 2),
	Vector2i(9, 2), Vector2i(8, 2),
	Vector2i(8, 3), Vector2i(8, 4), Vector2i(8, 5),
	Vector2i(8, 6), Vector2i(8, 7), Vector2i(8, 8),
	Vector2i(7, 8), Vector2i(6, 8), Vector2i(5, 8), Vector2i(4, 8), Vector2i(3, 8),
	Vector2i(3, 9), Vector2i(3, 10),
	Vector2i(4, 10), Vector2i(5, 10), Vector2i(6, 10), Vector2i(7, 10), Vector2i(8, 10),
	Vector2i(9, 10), Vector2i(9, 11), Vector2i(9, 12), Vector2i(9, 13),
]

const MAPS := [
	{
		"id": "junction",
		"name_key": "map.junction",
		"gates": [Vector2i(1, 0), Vector2i(10, 0)],
		"core": [Vector2i(5, 13), Vector2i(6, 13)],
		"routes": [ROUTE_JUNCTION_A, ROUTE_JUNCTION_B],
		"art": "res://assets/ui/map_junction.png",
	},
	{
		"id": "chicane",
		"name_key": "map.chicane",
		"gates": [Vector2i(0, 1), Vector2i(11, 1)],
		"core": [Vector2i(5, 13), Vector2i(6, 13)],
		"routes": [ROUTE_CHICANE_A, ROUTE_CHICANE_B],
		"art": "res://assets/ui/map_chicane.png",
	},
	{
		"id": "zigzag",
		"name_key": "map.zigzag",
		"gates": [Vector2i(1, 0), Vector2i(10, 0)],
		"core": [Vector2i(9, 13), Vector2i(10, 13)],
		"routes": [ROUTE_ZIGZAG_A, ROUTE_ZIGZAG_B],
		"art": "res://assets/ui/map_zigzag.png",
	},
]

static var _active := 0
static var _path_cache: Dictionary = {}


# ---------------------------------------------------------------- 地图切换

static func map_count() -> int:
	return MAPS.size()


static func use(index: int) -> void:
	_active = clampi(index, 0, MAPS.size() - 1)
	_path_cache.clear()


static func active_map() -> Dictionary:
	return MAPS[_active]


static func map_name_key() -> String:
	return String(active_map().name_key)


static func art_path() -> String:
	return String(active_map().art)


# ---------------------------------------------------------------- 坐标换算

static func field_rect() -> Rect2:
	return Rect2(ORIGIN, Vector2(COLS, ROWS) * TILE)


static func tile_rect(tile: Vector2i) -> Rect2:
	return Rect2(ORIGIN + Vector2(tile) * TILE, Vector2(TILE, TILE))


static func tile_center(tile: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(tile) + Vector2(0.5, 0.5)) * TILE


static func tile_at(point: Vector2) -> Vector2i:
	var local := (point - ORIGIN) / TILE
	return Vector2i(floori(local.x), floori(local.y))


static func clamp_tile(tile: Vector2i) -> Vector2i:
	return Vector2i(clampi(tile.x, 0, COLS - 1), clampi(tile.y, 0, ROWS - 1))


static func in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < COLS and tile.y >= 0 and tile.y < ROWS


# ---------------------------------------------------------------- 地图结构

static func gates() -> Array:
	return active_map().gates


static func gate_tile(index: int) -> Vector2i:
	var gate_list: Array = active_map().gates
	return gate_list[clampi(index, 0, gate_list.size() - 1)]


static func core_tiles() -> Array:
	return active_map().core


static func is_gate(tile: Vector2i) -> bool:
	return gates().has(tile)


static func is_core(tile: Vector2i) -> bool:
	return core_tiles().has(tile)


static func route_for_gate(index: int) -> Array:
	var routes: Array = active_map().routes
	return routes[clampi(index, 0, routes.size() - 1)]


static func core_center() -> Vector2:
	var tiles: Array = core_tiles()
	var sum := Vector2.ZERO
	for tile in tiles:
		sum += tile_center(tile)
	return sum / float(maxi(tiles.size(), 1))


## 缺口、核心所在格子不能建造；通路只放阵地建筑（近战阻挡位），火力和能源放在路外。
static func is_buildable(tile: Vector2i, category := "") -> bool:
	if not in_bounds(tile) or is_gate(tile) or is_core(tile):
		return false
	if is_path(tile) and category != CATEGORY_FORTIFICATION:
		return false
	return true


static func is_path(tile: Vector2i) -> bool:
	if _path_cache.is_empty():
		_build_path_cache()
	return _path_cache.has(tile)


static func _build_path_cache() -> void:
	for route in active_map().routes:
		for tile in route:
			_path_cache[tile] = true


## 路线去重后的线段列表：绘制通路时只画一次，避免两条路线重叠处变深。
static func segments() -> Array:
	var seen := {}
	var result: Array = []
	for route in active_map().routes:
		for i in route.size() - 1:
			var a: Vector2i = route[i]
			var b: Vector2i = route[i + 1]
			var key := "%s|%s" % [a, b]
			var flipped := "%s|%s" % [b, a]
			if seen.has(key) or seen.has(flipped):
				continue
			seen[key] = true
			result.append([tile_center(a), tile_center(b)])
	return result


## 数据自检：格子相邻、起点在缺口、终点在核心。冒烟测试逐张地图调用。
static func validate(index: int) -> Array:
	var problems: Array = []
	var saved := _active
	_active = clampi(index, 0, MAPS.size() - 1)
	var map: Dictionary = MAPS[_active]
	var gate_list: Array = map.gates
	var routes: Array = map.routes
	if routes.size() != gate_list.size():
		problems.append("%s: gate/route count mismatch" % map.id)
	for i in routes.size():
		var route: Array = routes[i]
		if route.is_empty():
			problems.append("%s route %d is empty" % [map.id, i])
			continue
		if route[0] != gate_list[i]:
			problems.append("%s route %d does not start on its gate" % [map.id, i])
		if not is_core(route[route.size() - 1]):
			problems.append("%s route %d does not end on the core" % [map.id, i])
		for s in route.size() - 1:
			var a: Vector2i = route[s]
			var b: Vector2i = route[s + 1]
			if absi(a.x - b.x) + absi(a.y - b.y) != 1:
				problems.append("%s route %d step %d is not adjacent" % [map.id, i, s])
			if not in_bounds(a):
				problems.append("%s route %d leaves the grid" % [map.id, i])
			if is_core(a) and s < route.size() - 1:
				problems.append("%s route %d passes through the core early" % [map.id, i])
	_active = saved
	_path_cache.clear()
	return problems
