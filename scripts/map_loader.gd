extends Node2D

## 无限稀疏地图：基地位于 [0,0]，只铺设镜头附近的确定性瓦片。

const REQUIRED_CELL_SIZE := Vector2i(64, 64)
const VIEW_PADDING := 2

var map_data: Dictionary = {}
var map_id := ""
var cell_size := Vector2i(64, 64)
var load_error := ""

var ground_layer: TileMapLayer
var decoration_layer: TileMapLayer

var _tile_set: TileSet
var _palette: Dictionary = {}
var _floor_aliases: Array = []
var _visible_cells: Dictionary = {}
var _view_bounds := Rect2i()
var _occupied: Dictionary = {}
var _reserved: Dictionary = {}
var _seed := 0
var _base: Dictionary = {}
var _nests: Array = []


func _ready() -> void:
	_ensure_layers()


func load_map(path: String) -> bool:
	load_error = ""
	_ensure_layers()
	if not FileAccess.file_exists(path):
		return _fail("地图文件不存在：%s" % path)
	var json := JSON.new()
	var parse_result := json.parse(FileAccess.get_file_as_string(path))
	if parse_result != OK:
		return _fail("%s:%d JSON 解析失败：%s" % [path, json.get_error_line(), json.get_error_message()])
	if typeof(json.data) != TYPE_DICTIONARY:
		return _fail("%s 顶层必须是对象" % path)
	var data: Dictionary = json.data
	if int(data.get("version", 0)) != 2:
		return _fail("%s 仅支持 version=2 无限地图" % path)
	var tileset_path := String(data.get("tileset", ""))
	if tileset_path.is_empty() or not ResourceLoader.exists(tileset_path):
		return _fail("%s TileSet 不存在：%s" % [path, tileset_path])
	_tile_set = load(tileset_path) as TileSet
	if _tile_set == null:
		return _fail("%s 不是有效 TileSet：%s" % [path, tileset_path])
	cell_size = _tile_set.tile_size
	if cell_size != REQUIRED_CELL_SIZE:
		return _fail("%s 瓦片尺寸必须为 64×64，当前为 %s" % [path, str(cell_size)])
	if not _compile_palette(data.get("palette", {})):
		return false
	if not _read_generation(data.get("generation", {})):
		return false
	if not _read_content(data):
		return false

	map_data = data
	map_id = String(data.get("id", ""))
	_occupied.clear()
	_visible_cells.clear()
	_view_bounds = Rect2i(2147483647, 2147483647, 0, 0)
	ground_layer.tile_set = _tile_set
	decoration_layer.tile_set = _tile_set
	ground_layer.clear()
	decoration_layer.clear()
	ground_layer.position = -Vector2(cell_size) * 0.5
	decoration_layer.position = -Vector2(cell_size) * 0.5
	print("MAP LOADED id=%s infinite nests=%d" % [map_id, _nests.size()])
	return true


func world_to_cell(world_pos: Vector2) -> Vector2i:
	var scaled := world_pos / Vector2(cell_size)
	return Vector2i(roundi(scaled.x), roundi(scaled.y))


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * Vector2(cell_size)


func update_view(center: Vector2, world_size: Vector2) -> void:
	if _floor_aliases.is_empty() or world_size.x <= 0.0 or world_size.y <= 0.0:
		return
	var half := world_size * 0.5
	var minimum := world_to_cell(center - half) - Vector2i.ONE * VIEW_PADDING
	var maximum := world_to_cell(center + half) + Vector2i.ONE * VIEW_PADDING
	var bounds := Rect2i(minimum, maximum - minimum + Vector2i.ONE)
	if bounds == _view_bounds:
		return
	_view_bounds = bounds
	var next_visible: Dictionary = {}
	for y in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, y)
			next_visible[cell] = true
			if not _visible_cells.has(cell):
				_draw_cell(cell)
	for cell in _visible_cells:
		if not next_visible.has(cell):
			ground_layer.erase_cell(cell)
			decoration_layer.erase_cell(cell)
	_visible_cells = next_visible


func get_visible_cells() -> Array:
	return _visible_cells.keys()


func is_cell_visible(cell: Vector2i) -> bool:
	return _visible_cells.has(cell)


func get_buildable_cells() -> Array:
	# 只返回镜头附近的格子，不能遍历无限地图。
	var cells: Array = []
	for cell in _visible_cells:
		if is_buildable(cell):
			cells.append(cell)
	return cells


func is_buildable(cell: Vector2i) -> bool:
	return not _reserved.has(cell) and not _occupied.has(cell)


func set_occupied(cell: Vector2i, building: Node) -> void:
	_occupied[cell] = building


func clear_occupied(cell: Vector2i) -> void:
	_occupied.erase(cell)


func clear_all_occupancy() -> void:
	_occupied.clear()


func get_occupied_building(cell: Vector2i) -> Node:
	return _occupied.get(cell, null) as Node


func release_reserved(cell: Vector2i) -> void:
	_reserved.erase(cell)


func get_base_definition() -> Dictionary:
	return _base


func get_base_position() -> Vector2:
	return cell_to_world(_base.get("cell", Vector2i.ZERO))


func get_nest_definitions() -> Array:
	return _nests


func _ensure_layers() -> void:
	if ground_layer != null:
		return
	ground_layer = TileMapLayer.new()
	ground_layer.name = "GroundLayer"
	add_child(ground_layer)
	decoration_layer = TileMapLayer.new()
	decoration_layer.name = "DecorationLayer"
	add_child(decoration_layer)


func _compile_palette(raw) -> bool:
	_palette.clear()
	if typeof(raw) != TYPE_DICTIONARY or raw.is_empty():
		return _fail("palette 不能为空")
	for alias in raw:
		var entry = raw[alias]
		if typeof(entry) != TYPE_DICTIONARY:
			return _fail("palette.%s 必须是对象" % alias)
		var atlas_raw = entry.get("atlas")
		if typeof(atlas_raw) != TYPE_ARRAY or atlas_raw.size() != 2:
			return _fail("palette.%s.atlas 必须是 [x, y]" % alias)
		var source_id := int(entry.get("source", -1))
		var atlas := Vector2i(int(atlas_raw[0]), int(atlas_raw[1]))
		var source := _tile_set.get_source(source_id) as TileSetAtlasSource
		if source == null or not source.has_tile(atlas):
			return _fail("palette.%s 引用了不存在的瓦片 source=%d atlas=%s" % [alias, source_id, str(atlas)])
		_palette[String(alias)] = {"source": source_id, "atlas": atlas, "alternative": int(entry.get("alternative", 0))}
	return true


func _read_generation(raw) -> bool:
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail("generation 必须是对象")
	_seed = int(raw.get("seed", 0))
	_floor_aliases.clear()
	var aliases = raw.get("ground_tiles", [])
	if typeof(aliases) != TYPE_ARRAY or aliases.is_empty():
		return _fail("generation.ground_tiles 不能为空")
	for alias in aliases:
		if not _palette.has(String(alias)):
			return _fail("generation.ground_tiles 引用未知瓦片：%s" % str(alias))
		_floor_aliases.append(String(alias))
	return true


func _read_content(data: Dictionary) -> bool:
	_reserved.clear()
	_nests.clear()
	var base_raw = data.get("base", {})
	if typeof(base_raw) != TYPE_DICTIONARY:
		return _fail("base 必须是对象")
	var base_cell_result := _read_cell(base_raw.get("cell", [0, 0]))
	if not base_cell_result[0]:
		return _fail("base.cell 必须是 [x, y]")
	var base_cell: Vector2i = base_cell_result[1]
	var size_raw = base_raw.get("size", [3, 3])
	if typeof(size_raw) != TYPE_ARRAY or size_raw.size() != 2:
		return _fail("base.size 必须是 [宽度, 高度]")
	var base_size := Vector2i(int(size_raw[0]), int(size_raw[1]))
	if base_size.x <= 0 or base_size.y <= 0 or base_size.x > 9 or base_size.y > 9:
		return _fail("base.size 必须在 1～9 格之间")
	_base = {
		"cell": base_cell,
		"size": base_size,
		"hp": maxi(1, int(base_raw.get("hp", 1000))),
	}
	var start := base_cell - Vector2i(base_size.x / 2, base_size.y / 2)
	for y in base_size.y:
		for x in base_size.x:
			_reserved[start + Vector2i(x, y)] = true

	var nests_raw = data.get("nests", [])
	if typeof(nests_raw) != TYPE_ARRAY:
		return _fail("nests 必须是数组")
	for index in nests_raw.size():
		var raw = nests_raw[index]
		if typeof(raw) != TYPE_DICTIONARY:
			return _fail("nests[%d] 必须是对象" % index)
		var cell_result := _read_cell(raw.get("cell", []))
		if not cell_result[0]:
			return _fail("nests[%d].cell 必须是 [x, y]" % index)
		var cell: Vector2i = cell_result[1]
		if _reserved.has(cell):
			return _fail("nests[%d] 与基地或其他巢穴重叠" % index)
		var definition := {
			"id": index + 1,
			"cell": cell,
			"hp": maxi(1, int(raw.get("hp", 80))),
			"spawn_interval": maxf(0.2, float(raw.get("spawn_interval", 5.0))),
			"kind": String(raw.get("kind", "normal")),
			"reward": maxi(0, int(raw.get("reward", 25))),
		}
		_nests.append(definition)
		_reserved[cell] = true
	return true


func _read_cell(raw) -> Array:
	if typeof(raw) != TYPE_ARRAY or raw.size() != 2:
		return [false, Vector2i.ZERO]
	return [true, Vector2i(int(raw[0]), int(raw[1]))]


func _draw_cell(cell: Vector2i) -> void:
	var hash_value := posmod(_seed + cell.x * 73856093 ^ cell.y * 19349663, 1000003)
	var alias := String(_floor_aliases[hash_value % _floor_aliases.size()])
	_set_tile(ground_layer, cell, alias)
	if _palette.has("pipe") and hash_value % 41 == 0:
		_set_tile(decoration_layer, cell, "pipe")
	elif _palette.has("vent") and hash_value % 41 == 3:
		_set_tile(decoration_layer, cell, "vent")
	elif _palette.has("orange_mark") and hash_value % 41 == 7:
		_set_tile(decoration_layer, cell, "orange_mark")


func _set_tile(layer: TileMapLayer, cell: Vector2i, alias: String) -> void:
	var tile: Dictionary = _palette[alias]
	layer.set_cell(cell, int(tile.source), tile.atlas, int(tile.alternative))


func _fail(message: String) -> bool:
	load_error = message
	push_error("MAP LOAD ERROR: " + message)
	return false
