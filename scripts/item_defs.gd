extends RefCounted

## 建筑定义表：三类基础建筑（火力 / 阵地 / 能源）以及各自的升级形态。
## 商店只出售基础形态，升级在聚焦面板里完成。

const CATEGORY_FIREPOWER := "firepower"
const CATEGORY_FORTIFICATION := "fortification"
const CATEGORY_ENERGY := "energy"

const COLOR_FIREPOWER := Color(1.0, 0.55, 0.18)
const COLOR_FORTIFICATION := Color(0.41, 0.74, 0.76)
const COLOR_ENERGY := Color(0.93, 0.76, 0.30)

## 底部商店的展示顺序
const SHOP_ORDER := ["turret", "sandbag", "solar"]

const ITEMS := {
	"turret": {
		"id": "turret",
		"name_key": "item.turret.name",
		"desc_key": "item.turret.desc",
		"category": CATEGORY_FIREPOWER,
		"tier": 1,
		"cost": 30,
		"energy_demand": 1,
		"energy_output": 0,
		"hp": 50,
		"blocks_enemies": false,
		"buff_multiplier": 1,
		"attack_style": "projectile",
		"damage": 1,
		"interval": 0.3,
		"range": 300.0,
		"bounces": 0,
		"pierce": 0,
		"speed": 520.0,
		"radius": 7.0,
		"barrel": 54.0,
		"base": 26.0,
		"color": COLOR_FIREPOWER,
		"icon": "res://assets/ui/turret.png",
		"upgrades": ["heavy_turret", "laser_tower"],
	},
	"heavy_turret": {
		"id": "heavy_turret",
		"name_key": "item.heavy_turret.name",
		"desc_key": "item.heavy_turret.desc",
		"category": CATEGORY_FIREPOWER,
		"tier": 2,
		"cost": 90,
		"energy_demand": 2,
		"energy_output": 0,
		"hp": 80,
		"blocks_enemies": false,
		"buff_multiplier": 1,
		"attack_style": "projectile",
		"damage": 10,
		"interval": 2.0,
		"range": 500.0,
		"bounces": 0,
		# -1：不限穿透次数，按剩余威力连续贯穿到威力耗尽
		"pierce": -1,
		"speed": 560.0,
		"radius": 8.0,
		"barrel": 52.0,
		"base": 30.0,
		"color": COLOR_FIREPOWER,
		"icon": "res://assets/ui/heavy_turret.png",
		"upgrades": [],
	},
	"laser_tower": {
		"id": "laser_tower",
		"name_key": "item.laser_tower.name",
		"desc_key": "item.laser_tower.desc",
		"category": CATEGORY_FIREPOWER,
		"tier": 2,
		"cost": 120,
		"energy_demand": 3,
		"energy_output": 0,
		"hp": 70,
		"blocks_enemies": false,
		"buff_multiplier": 1,
		"attack_style": "laser",
		"damage": 5,
		"interval": 0.2,
		"range": 420.0,
		"bounces": 0,
		"pierce": 0,
		"speed": 0.0,
		"radius": 0.0,
		"barrel": 54.0,
		"base": 28.0,
		"color": Color(0.72, 0.90, 0.96),
		"icon": "res://assets/ui/laser_tower.png",
		"upgrades": [],
	},
	"sandbag": {
		"id": "sandbag",
		"name_key": "item.sandbag.name",
		"desc_key": "item.sandbag.desc",
		"category": CATEGORY_FORTIFICATION,
		"tier": 1,
		"cost": 15,
		"energy_demand": 1,
		"energy_output": 0,
		"hp": 120,
		"blocks_enemies": true,
		"buff_multiplier": 1,
		"attack_style": "none",
		"barrel": 0.0,
		"base": 27.0,
		"sprite_scale": 1.20,
		"color": COLOR_FORTIFICATION,
		"icon": "res://assets/ui/sandbag.png",
		"upgrades": ["compression_tower"],
	},
	"compression_tower": {
		"id": "compression_tower",
		"name_key": "item.compression_tower.name",
		"desc_key": "item.compression_tower.desc",
		"category": CATEGORY_FORTIFICATION,
		"tier": 2,
		"cost": 45,
		"energy_demand": 2,
		"energy_output": 0,
		"hp": 180,
		"blocks_enemies": true,
		"buff_multiplier": 2,
		"attack_style": "none",
		"barrel": 0.0,
		"base": 30.0,
		"sprite_scale": 1.20,
		"color": COLOR_FORTIFICATION,
		"icon": "res://assets/ui/compression_tower.png",
		"upgrades": [],
	},
	"solar": {
		"id": "solar",
		"name_key": "item.solar.name",
		"desc_key": "item.solar.desc",
		"category": CATEGORY_ENERGY,
		"tier": 1,
		"cost": 20,
		"energy_demand": 0,
		"energy_output": 2,
		"hp": 50,
		"blocks_enemies": false,
		"buff_multiplier": 1,
		"attack_style": "none",
		"barrel": 0.0,
		"base": 27.0,
		"sprite_scale": 1.25,
		"color": COLOR_ENERGY,
		"icon": "res://assets/ui/solar.png",
		"upgrades": ["fusion_tower"],
	},
	"fusion_tower": {
		"id": "fusion_tower",
		"name_key": "item.fusion_tower.name",
		"desc_key": "item.fusion_tower.desc",
		"category": CATEGORY_ENERGY,
		"tier": 2,
		"cost": 40,
		"energy_demand": 0,
		"energy_output": 4,
		"hp": 80,
		"blocks_enemies": false,
		"buff_multiplier": 1,
		"attack_style": "none",
		"barrel": 0.0,
		"base": 31.0,
		"sprite_scale": 1.15,
		"color": COLOR_ENERGY,
		"icon": "res://assets/ui/fusion_tower.png",
		"upgrades": [],
	},
}


static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func get_shop_items() -> Array:
	var result: Array = []
	for id in SHOP_ORDER:
		var item: Dictionary = get_item(String(id))
		if not item.is_empty():
			result.append(item)
	return result


static func is_shop_item(id: String) -> bool:
	return SHOP_ORDER.has(id)


static func get_upgrades(id: String) -> Array:
	var item: Dictionary = get_item(id)
	if item.is_empty():
		return []
	var result: Array = []
	for upgrade_id in item.get("upgrades", []):
		var upgrade: Dictionary = get_item(String(upgrade_id))
		if not upgrade.is_empty():
			result.append(upgrade)
	return result


static func category_name_key(category: String) -> String:
	return "category." + category


static func category_color(category: String) -> Color:
	match category:
		CATEGORY_FIREPOWER:
			return COLOR_FIREPOWER
		CATEGORY_FORTIFICATION:
			return COLOR_FORTIFICATION
		CATEGORY_ENERGY:
			return COLOR_ENERGY
	return Color.WHITE
