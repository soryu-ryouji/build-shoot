extends Control

## UI 上层的建筑实体拖拽预览，与战场共用贴图，不包含卡片背景或文本。

const Palette = preload("res://scripts/palette.gd")
const ItemDefs = preload("res://scripts/item_defs.gd")
const BasicBaseTexture = preload("res://assets/ui/turret_base_field.png")
const BasicHeadTexture = preload("res://assets/ui/turret_head_field.png")
const HeavyBaseTexture = preload("res://assets/ui/heavy_turret_base_field.png")
const HeavyHeadTexture = preload("res://assets/ui/heavy_turret_head_field.png")
const LaserBaseTexture = preload("res://assets/ui/laser_tower_base_field.png")
const LaserHeadTexture = preload("res://assets/ui/laser_tower_head_field.png")
const SandbagTexture = preload("res://assets/ui/sandbag_field.png")
const CompressionTexture = preload("res://assets/ui/compression_tower_field.png")
const SolarTexture = preload("res://assets/ui/solar_field.png")
const FusionTexture = preload("res://assets/ui/fusion_tower_field.png")

var _item: Dictionary = {}


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    visible = false
    size = Vector2(88, 88)


func show_item(item: Dictionary, screen_pos: Vector2) -> void:
    if item.is_empty():
        return
    _item = item
    visible = true
    follow(screen_pos)
    queue_redraw()


func follow(screen_pos: Vector2) -> void:
    var parent_control := get_parent() as Control
    if parent_control == null:
        return
    var viewport := get_viewport_rect().size
    var screen_target := screen_pos - size * 0.5
    screen_target.x = clampf(screen_target.x, 4.0, maxf(4.0, viewport.x - size.x - 4.0))
    screen_target.y = clampf(screen_target.y, 4.0, maxf(4.0, viewport.y - size.y - 4.0))
    position = parent_control.get_global_transform_with_canvas().affine_inverse() * screen_target


func hide_preview() -> void:
    visible = false
    _item = {}


func _draw() -> void:
    if _item.is_empty():
        return
    var center := size * 0.5
    var id := String(_item.get("id", ""))
    draw_circle(center + Vector2(0, 4), 27.0, Color(0.05, 0.07, 0.08, 0.14))
    match id:
        "turret":
            _draw_turret(center, BasicBaseTexture, BasicHeadTexture, 6.0)
        "heavy_turret":
            _draw_turret(center, HeavyBaseTexture, HeavyHeadTexture, 4.8)
        "laser_tower":
            _draw_turret(center, LaserBaseTexture, LaserHeadTexture, 6.0)
        "sandbag":
            _draw_static(center, SandbagTexture, 58.0)
        "compression_tower":
            _draw_static(center, CompressionTexture, 58.0)
        "solar":
            _draw_static(center, SolarTexture, 58.0)
        "fusion_tower":
            _draw_static(center, FusionTexture, 58.0)


func _draw_turret(center: Vector2, base: Texture2D, head: Texture2D, size_factor: float) -> void:
    var scale := 25.0 * size_factor / 320.0
    var side := 320.0 * scale
    draw_texture_rect(base, Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side), false, Color.WHITE)
    var head_pos := center + Vector2(-160.0, -320.0) * scale
    draw_texture_rect(head, Rect2(head_pos, Vector2(320, 384) * scale), false, Color.WHITE)


func _draw_static(center: Vector2, texture: Texture2D, side: float) -> void:
    draw_texture_rect(texture, Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side), false, Color.WHITE)
