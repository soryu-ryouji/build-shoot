extends SceneTree

## 从处理后的 PNG 构建可复用工业 TileSet。

const ATLAS := preload("res://assets/tilesets/industrial.png")
const OUTPUT := "res://assets/tilesets/industrial.tres"


func _initialize() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 64)
	var source := TileSetAtlasSource.new()
	source.texture = ATLAS
	source.texture_region_size = Vector2i(64, 64)
	for y in 2:
		for x in 8:
			if y == 0 and x >= 6:
				continue
			if y == 1 and x >= 5:
				continue
			source.create_tile(Vector2i(x, y))
	tile_set.add_source(source, 0)
	var result := ResourceSaver.save(tile_set, OUTPUT)
	if result != OK:
		printerr("TileSet save failed: ", result)
		quit(1)
		return
	print("TILESET SAVED ", OUTPUT)
	quit()
