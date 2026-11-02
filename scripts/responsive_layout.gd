extends RefCounted

## 逻辑视口、横竖屏与移动设备安全区域的统一计算。

const DESIGN_SIZE := Vector2i(720, 960)


static func viewport_size(item: CanvasItem) -> Vector2:
	return item.get_viewport().get_visible_rect().size


static func margin(item: CanvasItem) -> float:
	var size := viewport_size(item)
	return clampf(minf(size.x, size.y) * 0.025, 12.0, 24.0)


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
