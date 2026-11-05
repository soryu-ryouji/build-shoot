extends RefCounted

## 无限地图敌人空间哈希：桶坐标与 MapLoader 的 64px 中心格一致。
## 只保存实际有敌人的格子，不依赖地图边界；跨格更新，交换删除为 O(1)。

const CELL_SIZE := 64.0

var _cells: Dictionary = {}
var _enemy_cells: Dictionary = {}
var _enemy_slots: Dictionary = {}
var _size := 0


func clear() -> void:
	_cells.clear()
	_enemy_cells.clear()
	_enemy_slots.clear()
	_size = 0


func size() -> int:
	return _size


func rebuild(enemies: Array) -> void:
	clear()
	for enemy in enemies:
		upsert(enemy)


func upsert(enemy: Dictionary) -> void:
	var id := int(enemy.get("id", 0))
	if id <= 0:
		return
	if not bool(enemy.get("alive", false)):
		remove(id)
		return
	var cell := cell_at(enemy.get("rect", Rect2()).get_center())
	if _enemy_cells.has(id) and _enemy_cells[id] == cell:
		return
	remove(id)
	if not _cells.has(cell):
		_cells[cell] = []
	var bucket: Array = _cells[cell]
	_enemy_slots[id] = bucket.size()
	bucket.append(enemy)
	_enemy_cells[id] = cell
	_size += 1


func remove(id: int) -> void:
	if not _enemy_cells.has(id):
		return
	var cell: Vector2i = _enemy_cells[id]
	var bucket: Array = _cells.get(cell, [])
	var slot := int(_enemy_slots.get(id, -1))
	if slot >= 0 and slot < bucket.size():
		var last: Dictionary = bucket.pop_back()
		if slot < bucket.size():
			bucket[slot] = last
			_enemy_slots[int(last.id)] = slot
	if bucket.is_empty():
		_cells.erase(cell)
	_enemy_cells.erase(id)
	_enemy_slots.erase(id)
	_size -= 1


func cell_at(point: Vector2) -> Vector2i:
	var scaled := point / CELL_SIZE
	return Vector2i(roundi(scaled.x), roundi(scaled.y))


func query_rect(rect: Rect2) -> Array:
	var minimum := cell_at(rect.position)
	var maximum := cell_at(rect.end - Vector2.ONE * 0.001)
	var result: Array = []
	for x in range(mini(minimum.x, maximum.x), maxi(minimum.x, maximum.x) + 1):
		for y in range(mini(minimum.y, maximum.y), maxi(minimum.y, maximum.y) + 1):
			_append_cell(Vector2i(x, y), result)
	return result


func query_circle(center: Vector2, radius: float) -> Array:
	var extent := Vector2.ONE * maxf(radius, 0.0)
	return query_rect(Rect2(center - extent, extent * 2.0))


func query_cells(cells: Array) -> Array:
	var result: Array = []
	for cell in cells:
		_append_cell(cell, result)
	return result


func _append_cell(cell: Vector2i, result: Array) -> void:
	for enemy in _cells.get(cell, []):
		if bool(enemy.get("alive", false)):
			result.append(enemy)
