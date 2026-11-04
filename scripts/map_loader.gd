extends Node2D

## 从单一 JSON 数据文件生成 TileMapLayer，并作为所有格子交互的唯一坐标来源。

const MAP_CENTER := Vector2(360.0, 456.0)
const REQUIRED_CELL_SIZE := Vector2i(64, 64)
## 向外连续铺设，覆盖当前支持的长屏镜头，避免露出纯色背景。
const SURROUND_RADIUS := 8

var map_data: Dictionary = {}
var map_id := ""
var grid_size := Vector2i.ZERO
var cell_size := Vector2i(64, 64)
var origin := Vector2.ZERO
var play_rect := Rect2()
var frame_rect := Rect2()
var load_error := ""

var ground_layer: TileMapLayer
var decoration_layer: TileMapLayer

var _tile_set: TileSet
var _palette: Dictionary = {}
var _ground_cells: Dictionary = {}
var _blocked: Dictionary = {}
var _base_buildable: Array = []
var _occupied: Dictionary = {}


func _ready() -> void:
	_ensure_layers()


func load_map(path: String) -> bool:
	load_error = ""
	_ensure_layers()
	if not FileAccess.file_exists(path):
		return _fail("地图文件不存在：%s" % path)

	var json := JSON.new()
	var text := FileAccess.get_file_as_string(path)
	var parse_result := json.parse(text)
	if parse_result != OK:
		return _fail("%s:%d JSON 解析失败：%s" % [path, json.get_error_line(), json.get_error_message()])
	if typeof(json.data) != TYPE_DICTIONARY:
		return _fail("%s 顶层必须是对象" % path)
	var data: Dictionary = json.data
	if int(data.get("version", 0)) != 1:
		return _fail("%s 仅支持 version=1" % path)
	if not _read_size(data):
		return false
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
	if not _read_layers(data.get("layers", {})):
		return false
	_read_blocked(data.get("blocked_cells", []))
	if not load_error.is_empty():
		return false

	map_data = data
	map_id = String(data.get("id", ""))
	origin = MAP_CENTER - Vector2(grid_size * cell_size) * 0.5
	play_rect = Rect2(origin, Vector2(grid_size * cell_size))
	frame_rect = play_rect.grow_individual(24.0, 40.0, 24.0, 40.0)
	_occupied.clear()
	_rebuild_buildable()
	_draw_layers()
	print("MAP LOADED id=%s size=%s path=%s" % [map_id, str(grid_size), path])
	return true


func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local := (world_pos - origin) / Vector2(cell_size)
	return Vector2i(floori(local.x), floori(local.y))


func cell_to_world(cell: Vector2i) -> Vector2:
	return origin + (Vector2(cell) + Vector2.ONE * 0.5) * Vector2(cell_size)


func get_play_rect() -> Rect2:
	return play_rect


func get_frame_rect() -> Rect2:
	return frame_rect


func get_all_cells() -> Array:
	return _ground_cells.keys()


func get_buildable_cells() -> Array:
	var cells: Array = []
	for cell in _base_buildable:
		if not _occupied.has(cell):
			cells.append(cell)
	return cells


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y


func is_buildable(cell: Vector2i) -> bool:
	return _ground_cells.has(cell) and not _blocked.has(cell) and not _occupied.has(cell)


func set_occupied(cell: Vector2i, building: Node) -> void:
	_occupied[cell] = building


func clear_occupied(cell: Vector2i) -> void:
	_occupied.erase(cell)


func clear_all_occupancy() -> void:
	_occupied.clear()


func get_occupied_building(cell: Vector2i) -> Node:
	return _occupied.get(cell, null) as Node


func _ensure_layers() -> void:
	if ground_layer != null:
		return
	ground_layer = TileMapLayer.new()
	ground_layer.name = "GroundLayer"
	ground_layer.z_index = 0
	add_child(ground_layer)
	decoration_layer = TileMapLayer.new()
	decoration_layer.name = "DecorationLayer"
	decoration_layer.z_index = 0
	add_child(decoration_layer)


func _read_size(data: Dictionary) -> bool:
	var raw = data.get("size")
	if typeof(raw) != TYPE_ARRAY or raw.size() != 2:
		return _fail("size 必须是 [宽度, 高度]")
	var width := int(raw[0])
	var height := int(raw[1])
	if width <= 0 or height <= 0 or width > 256 or height > 256:
		return _fail("地图尺寸必须在 1～256 格之间")
	grid_size = Vector2i(width, height)
	return true


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
		var alternative := int(entry.get("alternative", 0))
		var source := _tile_set.get_source(source_id) as TileSetAtlasSource
		if source == null or not source.has_tile(atlas):
			return _fail("palette.%s 引用了不存在的瓦片 source=%d atlas=%s" % [alias, source_id, str(atlas)])
		_palette[String(alias)] = {"source": source_id, "atlas": atlas, "alternative": alternative}
	return true


func _read_layers(raw) -> bool:
	_ground_cells.clear()
	if typeof(raw) != TYPE_DICTIONARY or typeof(raw.get("ground")) != TYPE_ARRAY:
		return _fail("layers.ground 必须是二维数组")
	var ground: Array = raw.ground
	if ground.size() != grid_size.y:
		return _fail("ground 行数 %d 与地图高度 %d 不一致" % [ground.size(), grid_size.y])
	for y in ground.size():
		if not _validate_row(ground[y], "ground", y):
			return false
		for x in grid_size.x:
			var alias = ground[y][x]
			if alias != null:
				_ground_cells[Vector2i(x, y)] = String(alias)
	var decorations = raw.get("decoration", [])
	if typeof(decorations) != TYPE_ARRAY:
		return _fail("layers.decoration 必须是二维数组")
	if not decorations.is_empty():
		if decorations.size() != grid_size.y:
			return _fail("decoration 行数与地图高度不一致")
		for y in decorations.size():
			if not _validate_row(decorations[y], "decoration", y):
				return false
	return true


func _validate_row(row, layer_name: String, y: int) -> bool:
	if typeof(row) != TYPE_ARRAY or row.size() != grid_size.x:
		return _fail("%s 第 %d 行必须有 %d 列" % [layer_name, y, grid_size.x])
	for value in row:
		if value != null and not _palette.has(String(value)):
			return _fail("%s 第 %d 行引用未知瓦片：%s" % [layer_name, y, str(value)])
	return true


func _read_blocked(raw) -> void:
	_blocked.clear()
	if typeof(raw) != TYPE_ARRAY:
		_fail("blocked_cells 必须是数组")
		return
	for value in raw:
		if typeof(value) != TYPE_ARRAY or value.size() != 2:
			_fail("blocked_cells 每项必须是 [x, y]")
			return
		var cell := Vector2i(int(value[0]), int(value[1]))
		if not is_inside(cell):
			_fail("blocked_cells 越界：%s" % str(cell))
			return
		_blocked[cell] = true


func _rebuild_buildable() -> void:
	_base_buildable.clear()
	for cell in _ground_cells:
		if not _blocked.has(cell):
			_base_buildable.append(cell)


func _draw_layers() -> void:
	ground_layer.clear()
	decoration_layer.clear()
	ground_layer.tile_set = _tile_set
	decoration_layer.tile_set = _tile_set
	ground_layer.position = origin
	decoration_layer.position = origin
	for cell in _ground_cells:
		_set_tile(ground_layer, cell, _ground_cells[cell])

	var decorations: Array = map_data.get("layers", {}).get("decoration", [])
	for y in decorations.size():
		for x in grid_size.x:
			var alias = decorations[y][x]
			if alias != null:
				_set_tile(decoration_layer, Vector2i(x, y), String(alias))

	# 战斗区内外是一张连续地面；可建造边界不参与材质分区。
	var floor_aliases: Array = []
	for alias in _ground_cells.values():
		if not floor_aliases.has(alias):
			floor_aliases.append(alias)
	for y in range(-SURROUND_RADIUS, grid_size.y + SURROUND_RADIUS):
		for x in range(-SURROUND_RADIUS, grid_size.x + SURROUND_RADIUS):
			var cell := Vector2i(x, y)
			if is_inside(cell):
				continue
			var index := posmod(x * 7 + y * 11, floor_aliases.size())
			_set_tile(ground_layer, cell, String(floor_aliases[index]))
			# 外围只逐渐增加工业装饰，不改变地面明度或材质。
			var decoration_hash := posmod(x * 13 + y * 17, 41)
			if _palette.has("pipe") and decoration_hash == 0:
				_set_tile(decoration_layer, cell, "pipe")
			elif _palette.has("vent") and decoration_hash == 3:
				_set_tile(decoration_layer, cell, "vent")
			elif _palette.has("orange_mark") and decoration_hash == 7:
				_set_tile(decoration_layer, cell, "orange_mark")


func _set_tile(layer: TileMapLayer, cell: Vector2i, alias: String) -> void:
	var tile: Dictionary = _palette[alias]
	layer.set_cell(cell, int(tile.source), tile.atlas, int(tile.alternative))


func _fail(message: String) -> bool:
	load_error = message
	push_error("MAP LOAD ERROR: " + message)
	return false
