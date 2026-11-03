extends Node

## 把 battle_map.gd 里的地图数据导出成 JSON，供 Blender 建模脚本读取，避免两份坐标各自漂移。

const BattleMap = preload("res://scripts/battle_map.gd")

const OUTPUT := "res://assets/maps/maps.json"


func _ready() -> void:
	var maps: Array = []
	for index in BattleMap.map_count():
		var data: Dictionary = BattleMap.MAPS[index]
		var routes: Array = []
		for route in data.routes:
			var points: Array = []
			for tile in route:
				points.append([tile.x, tile.y])
			routes.append(points)
		var gates: Array = []
		for tile in data.gates:
			gates.append([tile.x, tile.y])
		var core: Array = []
		for tile in data.core:
			core.append([tile.x, tile.y])
		maps.append({
			"id": String(data.id),
			"gates": gates,
			"core": core,
			"routes": routes,
			"high": data.get("high", []),
		})

	var payload := {
		"cols": BattleMap.COLS,
		"rows": BattleMap.ROWS,
		"tile": BattleMap.TILE,
		"tile_h": BattleMap.TILE_H,
		"high_lift": BattleMap.HIGH_LIFT,
		"origin": [BattleMap.ORIGIN.x, BattleMap.ORIGIN.y],
		"maps": maps,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/maps"))
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	print("MAP DATA ", OUTPUT, " maps=", maps.size())
	get_tree().quit()
