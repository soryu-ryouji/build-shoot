extends RefCounted

## 主炮塔和场上炮塔共用的锁定标记 / 导引线绘制。

const Palette = preload("res://scripts/palette.gd")
const BasicBaseTexture = preload("res://assets/ui/turret_base_field.png")
const BasicHeadTexture = preload("res://assets/ui/turret_head_field.png")
const HeavyBaseTexture = preload("res://assets/ui/heavy_turret_base_field.png")
const HeavyHeadTexture = preload("res://assets/ui/heavy_turret_head_field.png")

# 基盘贴图 320x320，中心就是旋转轴；头部贴图 320x384，头部枢轴在 (160, 320)。
const BASE_TEXTURE_SIZE := Vector2(320.0, 320.0)
const HEAD_TEXTURE_SIZE := Vector2(320.0, 384.0)
const HEAD_TEXTURE_PIVOT := Vector2(160.0, 320.0)


static func predict(blocks: Node, play_rect: Rect2, origin: Vector2, direction: Vector2) -> Vector2:
	var p := origin
	var step := 5.0
	for i in 320:
		p += direction * step
		if p.x <= play_rect.position.x or p.x >= play_rect.end.x:
			return p
		if p.y <= play_rect.position.y or p.y >= play_rect.end.y:
			return p
		for b in blocks.blocks:
			var block_rect: Rect2 = b.rect
			if bool(b.alive) and block_rect.has_point(p):
				return p
	return p


static func draw_aim(canvas: CanvasItem, origin: Vector2, direction: Vector2, hit: Vector2) -> void:
	var dist := origin.distance_to(hit)
	var dots := mini(int(dist / 18.0), 80)
	for i in dots:
		var t := float(i) / float(maxi(dots, 1))
		var p := origin + direction * (i * 18.0 + 10.0)
		var alpha := 0.42 * (1.0 - t * 0.75)
		canvas.draw_circle(p, lerpf(2.6, 1.1, t), Color(0.12, 0.14, 0.15, alpha))
	if dots > 0:
		canvas.draw_arc(hit, 10.0, 0.0, TAU, 24, Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.75), 1.5)
		canvas.draw_circle(hit, 2.0, Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.90))


static func draw_lock(canvas: CanvasItem, local_target: Vector2, time: float) -> void:
	var pulse := 0.5 + 0.5 * sin(time * 6.0)
	canvas.draw_arc(local_target, 24.0 + pulse * 2.0, 0.0, TAU, 32, Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.45 + pulse * 0.25), 1.5)
	for k in 4:
		var a := k * PI / 2.0
		canvas.draw_line(
			local_target + Vector2.from_angle(a) * 19.0,
			local_target + Vector2.from_angle(a) * 27.0,
			Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.6),
			1.5
		)


static func draw_basic_body(canvas: CanvasItem, aim_angle: float, base_radius: float, _barrel_length: float, recoil: float) -> void:
	_draw_field_sprite(canvas, BasicBaseTexture, BasicHeadTexture, aim_angle, base_radius, recoil, Palette.CYAN, 7.0, 6.0)


static func draw_heavy_body(canvas: CanvasItem, aim_angle: float, base_radius: float, _barrel_length: float, recoil: float, color: Color, time: float) -> void:
	_draw_field_sprite(canvas, HeavyBaseTexture, HeavyHeadTexture, aim_angle, base_radius, recoil, color, 9.0, 4.8)
	var pulse := 0.5 + 0.5 * sin(time * 4.0)
	canvas.draw_circle(Vector2.ZERO, base_radius * 0.26, Color(color.r, color.g, color.b, 0.05 + 0.08 * pulse))


static func _draw_field_sprite(
	canvas: CanvasItem,
	base_texture: Texture2D,
	head_texture: Texture2D,
	aim_angle: float,
	base_radius: float,
	recoil: float,
	color: Color,
	recoil_distance: float,
	size_factor: float
) -> void:
	canvas.draw_circle(Vector2.ZERO, base_radius + 8.0, Color(color.r, color.g, color.b, 0.055))
	var scale := base_radius * size_factor / BASE_TEXTURE_SIZE.x
	var side := BASE_TEXTURE_SIZE.x * scale
	# 生成素材统一朝上；逻辑中的 0 弧度朝右，因此补 90 度。基盘只旋转，不随开炮移动。
	var turn := aim_angle + PI / 2.0

	canvas.draw_set_transform(Vector2.ZERO, turn, Vector2.ONE)
	canvas.draw_texture_rect(
		base_texture,
		Rect2(Vector2(-side * 0.5, -side * 0.5), Vector2(side, side)),
		false,
		Color.WHITE
	)

	# 上半身按同一枢轴摆放，开炮时沿炮口反方向后退
	var recoil_offset := -Vector2.from_angle(aim_angle) * recoil_distance * recoil
	canvas.draw_set_transform(recoil_offset, turn, Vector2.ONE)
	canvas.draw_texture_rect(
		head_texture,
		Rect2(
			Vector2(-HEAD_TEXTURE_PIVOT.x * scale, -HEAD_TEXTURE_PIVOT.y * scale),
			HEAD_TEXTURE_SIZE * scale
		),
		false,
		Color.WHITE
	)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
