extends RefCounted

## 主炮塔和场上炮塔共用的锁定标记 / 导引线绘制。

const Palette = preload("res://scripts/palette.gd")


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
		canvas.draw_circle(p, lerpf(2.6, 1.1, t), Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, alpha))
	if dots > 0:
		canvas.draw_arc(hit, 10.0, 0.0, TAU, 24, Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.7), 1.5)
		canvas.draw_circle(hit, 2.0, Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.85))


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


static func draw_basic_body(canvas: CanvasItem, aim_angle: float, base_radius: float, barrel_length: float, recoil: float) -> void:
	# 与主炮塔完全一致的基础炮塔外观
	canvas.draw_circle(Vector2.ZERO, base_radius + 8.0, Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.06))
	canvas.draw_circle(Vector2.ZERO, base_radius, Color("101a2b"))
	canvas.draw_arc(Vector2.ZERO, base_radius - 1.0, 0.0, TAU, 48, Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.75), 2.0)
	canvas.draw_circle(Vector2.ZERO, base_radius * 0.385, Palette.ACCENT)
	canvas.draw_circle(Vector2.ZERO, base_radius * 0.173, Color(1.0, 1.0, 1.0, 0.85))

	canvas.draw_set_transform(Vector2.ZERO, aim_angle, Vector2.ONE)
	var r := -7.0 * recoil
	var h := base_radius * 0.77
	var barrel := Rect2(Vector2(6.0 + r, -h * 0.5), Vector2(barrel_length - 8.0, h))
	canvas.draw_rect(barrel.grow(2.0), Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.16))
	canvas.draw_rect(barrel, Color("1b2638"))
	canvas.draw_rect(barrel.grow(-3.0), Color("34455e"))
	canvas.draw_rect(Rect2(Vector2(barrel_length - 13.0 + r, -h * 0.55), Vector2(9.0, h * 1.1)), Palette.ACCENT)
	canvas.draw_circle(Vector2(barrel_length - 3.0 + r, 0.0), 4.0, Color(1.0, 0.9, 0.6, 0.9))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func draw_heavy_body(canvas: CanvasItem, aim_angle: float, base_radius: float, barrel_length: float, recoil: float, color: Color, time: float) -> void:
	# 重型炮塔：六边形装甲底座、外露能量核心、三联穿透标记和厚重炮管
	canvas.draw_circle(Vector2.ZERO, base_radius + 10.0, Color(color.r, color.g, color.b, 0.06))

	var hex := PackedVector2Array()
	for i in 6:
		hex.append(Vector2.from_angle(PI / 6.0 + i * TAU / 6.0) * base_radius)
	canvas.draw_colored_polygon(hex, Color("141a24"))
	var outline := hex.duplicate()
	outline.append(hex[0])
	canvas.draw_polyline(outline, Color(color.r, color.g, color.b, 0.8), 2.0)

	canvas.draw_circle(Vector2.ZERO, base_radius * 0.72, Color("0c111a"))
	canvas.draw_arc(Vector2.ZERO, base_radius * 0.72, 0.0, TAU, 36, Color(color.r, color.g, color.b, 0.4), 1.5)

	for side in [-1.0, 1.0]:
		var plate := Rect2(Vector2(side * base_radius * 0.72 - 4.0, -11.0), Vector2(8.0, 22.0))
		canvas.draw_rect(plate, Color("1b2638"))
		canvas.draw_rect(plate.grow(-2.0), color.darkened(0.5))

	var pulse := 0.5 + 0.5 * sin(time * 4.0)
	canvas.draw_circle(Vector2.ZERO, base_radius * 0.38, Color(color.r, color.g, color.b, 0.12 + 0.10 * pulse))
	canvas.draw_circle(Vector2.ZERO, base_radius * 0.23, color.darkened(0.2))
	canvas.draw_circle(Vector2.ZERO, base_radius * 0.09, Color(1.0, 0.95, 0.75, 0.9))

	# 3 个穿透标记
	for i in 3:
		canvas.draw_circle(Vector2(-7.0 + i * 7.0, base_radius * 0.56), 2.0, Color(color.r, color.g, color.b, 0.85))

	canvas.draw_set_transform(Vector2.ZERO, aim_angle, Vector2.ONE)
	var r := -9.0 * recoil
	var h := base_radius * 0.56
	var barrel := Rect2(Vector2(4.0 + r, -h * 0.5), Vector2(barrel_length - 6.0, h))
	canvas.draw_rect(barrel.grow(3.0), Color(color.r, color.g, color.b, 0.12))
	canvas.draw_rect(barrel, Color("1b2638"))
	canvas.draw_rect(barrel.grow(-2.0), color.darkened(0.42))
	canvas.draw_line(Vector2(8.0 + r, 0.0), Vector2(barrel_length - 12.0 + r, 0.0), Color(color.r, color.g, color.b, 0.65), 3.0)
	for i in 3:
		var x := 12.0 + i * 8.0 + r
		canvas.draw_line(Vector2(x, -h * 0.55), Vector2(x, h * 0.55), Color(color.r, color.g, color.b, 0.65), 1.5)

	var muzzle := Rect2(Vector2(barrel_length - 10.0 + r, -h * 0.85), Vector2(9.0, h * 1.7))
	canvas.draw_rect(muzzle, Color("1b2638"))
	canvas.draw_rect(muzzle.grow(-1.5), color.darkened(0.25))
	canvas.draw_rect(Rect2(Vector2(barrel_length - 2.0 + r, -h * 0.9), Vector2(3.0, h * 0.6)), color)
	canvas.draw_rect(Rect2(Vector2(barrel_length - 2.0 + r, h * 0.3), Vector2(3.0, h * 0.6)), color)
	canvas.draw_circle(Vector2(barrel_length - 5.0 + r, 0.0), 3.0, Color(1.0, 0.9, 0.65, 0.9))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
