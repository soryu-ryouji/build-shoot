extends RefCounted

## 2.5D 建筑贴图：Blender 用同一台正交相机渲染（俯角 asin(34/48)，1 世界单位 = 1 像素），
## 地面接触点落在图片中心，游戏里按瓦片中心直接贴。
## 火力塔有 8 个朝向（北起顺时针 45° 一张），其余建筑一张。

const SPRITE_SIZE := 160

static var _cache := {}


static func available(item_id: String) -> bool:
	return not textures(item_id).is_empty()


static func textures(item_id: String) -> Array:
	if _cache.has(item_id):
		return _cache[item_id]
	var list: Array = []
	for index in 8:
		var path := "res://assets/ui/25d/%s_d%d.png" % [item_id, index]
		if ResourceLoader.exists(path):
			list.append(load(path))
	if list.is_empty():
		var single := "res://assets/ui/25d/%s.png" % item_id
		if ResourceLoader.exists(single):
			list.append(load(single))
	_cache[item_id] = list
	return list


static func texture_for(item_id: String, aim_angle: float) -> Texture2D:
	var list := textures(item_id)
	if list.is_empty():
		return null
	if list.size() == 1:
		return list[0]
	var index := int(round((aim_angle + PI * 0.5) / (PI / 4.0)))
	index = ((index % 8) + 8) % 8
	return list[index]
