extends RefCounted

## 横屏逻辑视口与移动设备安全区域的统一计算。
## HUD、底部建造栏、战场和建筑详情共用这里的矩形定义。

const UiMetrics = preload("res://scripts/ui_metrics.gd")

const DESIGN_SIZE := Vector2i(960, 540)
const FIELD_GAP := 6.0


static func viewport_size(item: CanvasItem) -> Vector2:
    return item.get_viewport().get_visible_rect().size


static func margin(item: CanvasItem) -> float:
    var size := viewport_size(item)
    return clampf(minf(size.x, size.y) * 0.026, 14.0, 20.0)


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


## 顶部信息栏横跨屏幕，只保留菜单和居中的资源信息。
static func hud_rect(item: CanvasItem) -> Rect2:
    var safe := safe_rect(item)
    var inset := minf(margin(item), 10.0)
    return Rect2(
        safe.position + Vector2(inset, inset),
        Vector2(safe.size.x - inset * 2.0, UiMetrics.HUD_HEIGHT),
    )


## 底部建造栏居中，标签页在上，当前类别的道具卡在下。
static func shop_rect(item: CanvasItem) -> Rect2:
    var safe := safe_rect(item)
    var inset := margin(item)
    var width := minf(UiMetrics.SHOP_MAX_WIDTH, safe.size.x - inset * 2.0)
    return Rect2(
        Vector2(safe.position.x + (safe.size.x - width) * 0.5, safe.end.y - inset - UiMetrics.SHOP_HEIGHT),
        Vector2(width, UiMetrics.SHOP_HEIGHT),
    )


## 战场使用 HUD 与底部建造栏之间的完整宽度。
static func field_rect(item: CanvasItem) -> Rect2:
    var safe := safe_rect(item)
    var top := hud_rect(item).end.y + FIELD_GAP
    var bottom := shop_rect(item).position.y - FIELD_GAP
    return Rect2(safe.position.x, top, safe.size.x, maxf(bottom - top, 1.0))


## 建筑详情使用紧凑横向面板，位于战场上方区域的左侧。
static func focus_rect(item: CanvasItem) -> Rect2:
    var field := field_rect(item)
    var inset := margin(item)
    return Rect2(
        field.position + Vector2(inset, 8.0),
        Vector2(minf(UiMetrics.FOCUS_WIDTH, field.size.x - inset * 2.0), maxf(field.size.y - 16.0, 1.0)),
    )
