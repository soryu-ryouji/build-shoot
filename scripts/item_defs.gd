extends RefCounted

## 建筑定义表：三类建筑（火力 / 阵地 / 能源）及其可用道具。
## 商店按类别切换道具列表，所有形态都直接拖放建造，不再有升级路线。

const CATEGORY_FIREPOWER := "firepower"
const CATEGORY_FORTIFICATION := "fortification"
const CATEGORY_ENERGY := "energy"

const COLOR_FIREPOWER := Color(1.0, 0.55, 0.18)
const COLOR_FORTIFICATION := Color(0.41, 0.74, 0.76)
const COLOR_ENERGY := Color(0.93, 0.76, 0.30)

## 底部商店的类别顺序与每类可选道具（第一个是默认选中项）
const CATEGORY_ORDER := [CATEGORY_FIREPOWER, CATEGORY_FORTIFICATION, CATEGORY_ENERGY]
const ITEMS_BY_CATEGORY := {
	CATEGORY_FIREPOWER: ["turret", "heavy_turret", "laser_tower", "lightning_tower"],
	CATEGORY_FORTIFICATION: ["sandbag", "compression_tower"],
	CATEGORY_ENERGY: ["fusion_tower", "coin_tower", "super_fusion_tower", "super_generator_tower"],
}

## 建筑升级曲线：低级/高级成长速度不同，激光塔按攻击与耗能翻倍成长。
const UPGRADE_RULES := {
	"turret": {"kind": "add", "damage": 5, "energy": 1, "cost": 20, "cost_mult": 1.35, "max": 5},
	"heavy_turret": {"kind": "add", "damage": 30, "energy": 2, "cost": 60, "cost_mult": 1.5, "max": 5},
	"laser_tower": {"kind": "mult", "damage": 2.0, "energy": 2.0, "cost": 120, "cost_mult": 1.8, "max": 6},
	"sandbag": {"kind": "add", "hp": 60, "energy": 1, "cost": 10, "cost_mult": 1.3, "max": 5},
	"compression_tower": {"kind": "add", "hp": 90, "energy": 1, "cost": 30, "cost_mult": 1.4, "max": 5},
	"fusion_tower": {"kind": "add", "output": 2, "cost": 30, "cost_mult": 1.4, "max": 5},
	"lightning_tower": {"kind": "add", "damage": 2, "energy": 1, "cost": 45, "cost_mult": 1.4, "max": 5},
	"coin_tower": {"kind": "add", "coins": 2, "cost": 25, "cost_mult": 1.4, "max": 5},
	"super_fusion_tower": {"kind": "add", "output": 18, "cost": 200, "cost_mult": 1.5, "max": 5},
	"super_generator_tower": {"kind": "add", "output": 36, "cost": 300, "cost_mult": 1.5, "max": 5},
}

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
	},
	"heavy_turret": {
		"id": "heavy_turret",
		"name_key": "item.heavy_turret.name",
		"desc_key": "item.heavy_turret.desc",
		"category": CATEGORY_FIREPOWER,
		"tier": 2,
		"cost": 120,
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
	},
	"laser_tower": {
		"id": "laser_tower",
		"name_key": "item.laser_tower.name",
		"desc_key": "item.laser_tower.desc",
		"category": CATEGORY_FIREPOWER,
		"tier": 2,
		"research_cost": 300,
		"cost": 150,
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
	},
	"lightning_tower": {
		"id": "lightning_tower",
		"name_key": "item.lightning_tower.name",
		"desc_key": "item.lightning_tower.desc",
		"category": CATEGORY_FIREPOWER,
		"tier": 2,
		"research_cost": 400,
		"cost": 110,
		"energy_demand": 2,
		"energy_output": 0,
		"hp": 65,
		"blocks_enemies": false,
		"buff_multiplier": 1,
		"attack_style": "lightning",
		"damage": 4,
		"interval": 1.35,
		"range": 300.0,
		"chain_count": 4,
		"chain_range": 64.0,
		"bounces": 0,
		"pierce": 0,
		"speed": 0.0,
		"radius": 0.0,
		"barrel": 42.0,
		"base": 29.0,
		"sprite_scale": 1.0,
		"color": Color(0.48, 0.84, 0.96),
		"icon": "res://assets/ui/lightning_tower.png",
	},
	"sandbag": {
		"id": "sandbag",
		"name_key": "item.sandbag.name",
		"desc_key": "item.sandbag.desc",
		"category": CATEGORY_FORTIFICATION,
		"tier": 1,
		"cost": 15,
		"energy_demand": 0,
		"energy_output": 0,
		"hp": 120,
		"blocks_enemies": true,
		"buff_multiplier": 1,
		"attack_style": "none",
		"barrel": 0.0,
		"base": 27.0,
		"sprite_scale": 1.20,
		"color": COLOR_FORTIFICATION,
		"icon": "res://assets/ui/wall.png",
	},
	"compression_tower": {
		"id": "compression_tower",
		"name_key": "item.compression_tower.name",
		"desc_key": "item.compression_tower.desc",
		"category": CATEGORY_FORTIFICATION,
		"tier": 2,
		"research_cost": 300,
		"cost": 60,
		"energy_demand": 2,
		"energy_output": 0,
		"hp": 180,
		"blocks_enemies": true,
		"buff_multiplier": 2,
		"auras": [{
			"id": "compression_damage",
			"shape": "circle",
			"radius": 128.0,
			"target_categories": [CATEGORY_FIREPOWER],
			"target_items": ["compression_tower"],
			"propagate": true,
			"show_links": true,
			"stack_group": "compression_damage",
			"stack_rule": "stack",
			"modifiers": [{"stat": "damage", "op": "mul", "value": 2.0}],
		}],
		"attack_style": "none",
		"barrel": 0.0,
		"base": 30.0,
		"sprite_scale": 1.20,
		"color": COLOR_FORTIFICATION,
		"icon": "res://assets/ui/compression_tower.png",
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
	},
"super_fusion_tower": {
"id": "super_fusion_tower",
"name_key": "item.super_fusion_tower.name",
"desc_key": "item.super_fusion_tower.desc",
"category": CATEGORY_ENERGY, "tier": 3, "research_cost": 1000, "cost": 2000,
"energy_demand": 0, "energy_output": 60, "hp": 180,
"blocks_enemies": false, "buff_multiplier": 1, "attack_style": "none",
"barrel": 0.0, "base": 32.0, "sprite_scale": 1.10,
"color": COLOR_ENERGY, "icon": "res://assets/ui/super_fusion_tower.png",
},
"super_generator_tower": {
"id": "super_generator_tower",
"name_key": "item.super_generator_tower.name",
"desc_key": "item.super_generator_tower.desc",
"category": CATEGORY_ENERGY, "tier": 3, "research_cost": 1000, "cost": 2000,
"energy_demand": 0, "energy_output": 120, "hp": 240,
"blocks_enemies": false, "buff_multiplier": 1, "attack_style": "none",
"barrel": 0.0, "base": 34.0, "sprite_scale": 1.12,
"color": COLOR_ENERGY, "icon": "res://assets/ui/super_generator_tower.png",
},
	"coin_tower": {
		"id": "coin_tower",
		"name_key": "item.coin_tower.name",
		"desc_key": "item.coin_tower.desc",
		"category": CATEGORY_ENERGY,
		"tier": 2,
		"cost": 40,
		"energy_demand": 1,
		"energy_output": 0,
		"coin_output": 5,
		"coin_interval": 4.0,
		"hp": 70,
		"blocks_enemies": false,
		"buff_multiplier": 1,
		"attack_style": "economy",
		"barrel": 0.0,
		"base": 30.0,
		"sprite_scale": 1.0,
		"color": COLOR_ENERGY,
		"icon": "res://assets/ui/coin_tower.png",
	}
}


static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func get_category_items(category: String) -> Array:
	var result: Array = []
	for id in ITEMS_BY_CATEGORY.get(category, []):
		var item: Dictionary = get_item(String(id))
		if not item.is_empty():
			result.append(item)
	return result


static func get_default_item(category: String) -> Dictionary:
	var items: Array = get_category_items(category)
	return items[0] if not items.is_empty() else {}


static func get_upgrade(id: String) -> Dictionary:
	return UPGRADE_RULES.get(id, {})


static func get_research_cost(id: String) -> int:
	return int(get_item(id).get("research_cost", 0))


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
