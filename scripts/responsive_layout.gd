extends RefCounted

## 逻辑视口、横竖屏与移动设备安全区域的统一计算。
## HUD、商店和战场共用这里的矩形定义，改高度时三处不会再各自漂移。

const UiMetrics = preload("res://scripts/ui_metrics.gd")

const DESIGN_SIZE := Vector2i(720, 960)

## 战场与上下栏之间保留的最小留白。
const FIELD_GAP := 6.0


static func viewport_size(item: CanvasItem) -> Vector2:
	return item.get_viewport().get_visible_rect().size


static func margin(item: CanvasItem) -> float:
	var size := viewport_size(item)
	return clampf(minf(size.x, size.y) * 0.028, 14.0, 22.0)


static func safe_rect(item: CanvasItem) -> Rect2:
	var viewport := Rect2(Vector2.ZERO, viewport_size(item))
	if not OS.has_feature("mobile"):
		return viewport

	var window_size := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if window_size.x <= 0.0 or window_size.y <= 0.0 or safe.size == Vector2i.ZERO:
		return viewport

	var factor := viewport.size / window_size
	var logical := Rect2(Vector2(safe.position) * factor, Vector2(safe.size) * factor)
	return viewport.intersection(logical)


## 顶部信息栏的矩形。左右各留 10 逻辑像素，和商店的 margin 区分开。
static func hud_rect(item: CanvasItem) -> Rect2:
	var safe := safe_rect(item)
	var inset := minf(margin(item), 10.0)
	return Rect2(
		safe.position + Vector2(inset, inset),
		Vector2(safe.size.x - inset * 2.0, UiMetrics.HUD_HEIGHT),
	)


## 底部商店的矩形，贴住安全区底边。
static func shop_rect(item: CanvasItem) -> Rect2:
	var safe := safe_rect(item)
	var inset := margin(item)
	return Rect2(
		Vector2(safe.position.x + inset, safe.end.y - inset - UiMetrics.SHOP_HEIGHT),
		Vector2(safe.size.x - inset * 2.0, UiMetrics.SHOP_HEIGHT),
	)


## HUD 与商店之间的可用区域，战场在这块矩形里居中并尽量放大。
static func field_rect(item: CanvasItem) -> Rect2:
	var safe := safe_rect(item)
	var top := hud_rect(item).end.y + FIELD_GAP
	var bottom := shop_rect(item).position.y - FIELD_GAP
	return Rect2(safe.position.x, top, safe.size.x, maxf(bottom - top, 1.0))
