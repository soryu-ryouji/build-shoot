extends RefCounted

## 可通过金币购买、拖拽布置到场上的道具定义。

const COLOR_STANDARD := Color(0.88, 0.86, 0.78)
const COLOR_HEAVY := Color(1.0, 0.55, 0.18)

const ITEMS := [
	{
		"id": "turret",
		"name_key": "item.turret.name",
		"desc_key": "item.turret.desc",
		"cost": 30,
		"damage": 1,
		"interval": 0.3,
		"range": 300.0,
		"bounces": 0,
		"pierce": 0,
		"speed": 520.0,
		"radius": 7.0,
		"barrel": 54.0,
		"base": 26.0,
		"color": COLOR_STANDARD,
	},
	{
		"id": "heavy_turret",
		"name_key": "item.heavy_turret.name",
		"desc_key": "item.heavy_turret.desc",
		"cost": 200,
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
		"color": COLOR_HEAVY,
	},
]


static func get_item(id: String) -> Dictionary:
	for item in ITEMS:
		if String(item.id) == id:
			return item
	return {}
