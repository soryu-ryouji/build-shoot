extends Node2D

## 无限战场容器。基地、巢穴和地面生成规则全部来自 JSON。

const MapLoader = preload("res://scripts/map_loader.gd")
const DEFAULT_MAP_PATH := "res://data/maps/industrial_01.json"

var map_loader: Node2D


func _ready() -> void:
	map_loader = MapLoader.new()
	map_loader.name = "MapLoader"
	add_child(map_loader)
	map_loader.load_map(DEFAULT_MAP_PATH)


func load_map(path: String) -> bool:
	return map_loader.load_map(path)
