extends RefCounted

## 一体式瓦片地图：12×14 的格子，敌人沿画在地图上的通路从顶部缺口走到下方核心。
## 路线、缺口、核心的坐标只在这里定义，绘制（arena）和行走（blocks）共用同一份数据。

const COLS := 12
const ROWS := 14
const TILE := 48.0
const ORIGIN := Vector2(72.0, 120.0)

const GATE_A := Vector2i(1, 0)
const GATE_B := Vector2i(10, 0)

## 核心占两格，路线终点落在右半边
const CORE_LEFT := Vector2i(5, 13)
const CORE_RIGHT := Vector2i(6, 13)

const ROUTE_A := [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3),
	Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3),
	Vector2i(5, 4), Vector2i(5, 5), Vector2i(5, 6),
	Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 6),
	Vector2i(8, 7), Vector2i(8, 8), Vector2i(8, 9), Vector2i(8, 10),
	Vector2i(7, 10), Vector2i(6, 10),
	Vector2i(6, 11), Vector2i(6, 12), Vector2i(6, 13),
]

const ROUTE_B := [
	Vector2i(10, 0), Vector2i(10, 1), Vector2i(10, 2),
	Vector2i(9, 2), Vector2i(8, 2),
	Vector2i(8, 3), Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 6),
	Vector2i(8, 7), Vector2i(8, 8), Vector2i(8, 9), Vector2i(8, 10),
	Vector2i(7, 10), Vector2i(6, 10),
	Vector2i(6, 11), Vector2i(6, 12), Vector2i(6, 13),
]


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


static func is_gate(tile: Vector2i) -> bool:
	return tile == GATE_A or tile == GATE_B


static func is_core(tile: Vector2i) -> bool:
	return tile.y == CORE_LEFT.y and (tile.x == CORE_LEFT.x or tile.x == CORE_RIGHT.x)


## 缺口和核心是地图结构，不能在上面造建筑；其余格子都能建。
static func is_buildable(tile: Vector2i) -> bool:
	return in_bounds(tile) and not is_gate(tile) and not is_core(tile)


static func route_for_gate(index: int) -> Array:
	return ROUTE_A if index == 0 else ROUTE_B


static func gate_tile(index: int) -> Vector2i:
	return GATE_A if index == 0 else GATE_B


static func core_center() -> Vector2:
	return (tile_center(CORE_LEFT) + tile_center(CORE_RIGHT)) * 0.5


## 路线去重后的线段列表：绘制通路时只画一次，避免两条路线重叠处变深。
static func segments() -> Array:
	var seen := {}
	var result: Array = []
	for route in [ROUTE_A, ROUTE_B]:
		for i in route.size() - 1:
			var a: Vector2i = route[i]
			var b: Vector2i = route[i + 1]
			var key := "%s|%s" % [a, b] if a.x + a.y <= b.x + b.y else "%s|%s" % [b, a]
			if seen.has(key):
				continue
			seen[key] = true
			result.append([tile_center(a), tile_center(b)])
	return result
