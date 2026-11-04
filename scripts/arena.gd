extends Node2D

## 通用战场容器。具体地面和尺寸全部来自 JSON，不再引用整张地图插画。

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


func get_play_rect() -> Rect2:
	return map_loader.get_play_rect()


func get_frame_rect() -> Rect2:
	return map_loader.get_frame_rect()
