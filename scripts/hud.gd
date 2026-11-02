extends Control

## 界面：顶部模式/连击/击碎数，底部球状态/等级/经验条，中间飘字。

const Palette = preload("res://scripts/palette.gd")

var game: Node

var mode_label: Label
var tag_label: Label
var combo_caption: Label
var combo_label: Label
var destroyed_label: Label
var balls_label: Label
var bounce_label: Label
var level_label: Label
var xp_label: Label
var hint_label: Label
var toast_label: Label

var _xp_ratio := 0.0
var _toast_time := 0.0
var _combo_pop := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	queue_redraw()


func _build() -> void:
	mode_label = _make_label("ENDLESS", Vector2(40, 16), Vector2(320, 40), 28, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	mode_label.add_theme_constant_override("outline_size", 6)
	mode_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))

	tag_label = _make_label("BLOCK STREAM / RICOCHET", Vector2(40, 56), Vector2(420, 26), 16, Palette.MUTED)

	combo_caption = _make_label("COMBO", Vector2(540, 12), Vector2(140, 20), 14, Palette.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	combo_label = _make_label("x1", Vector2(540, 22), Vector2(140, 44), 34, Palette.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	combo_label.add_theme_constant_override("outline_size", 8)
	combo_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.65))
	combo_label.pivot_offset = Vector2(70, 22)

	destroyed_label = _make_label("DESTROYED 0", Vector2(480, 70), Vector2(200, 20), 13, Palette.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)

	balls_label = _make_label("00 BALLS", Vector2(40, 824), Vector2(260, 32), 22, Palette.CYAN)
	bounce_label = _make_label("READY", Vector2(280, 830), Vector2(160, 24), 14, Palette.CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	level_label = _make_label("LV 01", Vector2(520, 822), Vector2(160, 34), 24, Palette.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)

	xp_label = _make_label("XP 0 / 80", Vector2(40, 856), Vector2(300, 20), 12, Palette.MUTED)

	hint_label = _make_label(
		"MOUSE / TOUCH TO AIM    AUTO FIRE    R TO RESTART",
		Vector2(40, 922), Vector2(640, 24), 12, Palette.MUTED, HORIZONTAL_ALIGNMENT_CENTER
	)

	toast_label = _make_label("", Vector2(60, 400), Vector2(600, 64), 40, Palette.CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.add_theme_constant_override("outline_size", 10)
	toast_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	toast_label.modulate.a = 0.0

	combo_caption.visible = false
	combo_label.visible = false


func _make_label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _process(delta: float) -> void:
	if game == null:
		return

	destroyed_label.text = "DESTROYED %d" % int(game.blocks.destroyed)

	var ball_count: int = game.active_balls.size()
	balls_label.text = "%02d %s" % [ball_count, "BALL" if ball_count == 1 else "BALLS"]
	if ball_count > 0:
		var ball: Node = game.active_balls[ball_count - 1]
		if int(ball.bounces_left) > 0:
			bounce_label.text = "BOUNCES %d" % int(ball.bounces_left)
		else:
			bounce_label.text = "SINGLE HIT"
	else:
		bounce_label.text = "READY"

	level_label.text = "LV %02d" % int(game.level)
	xp_label.text = "XP %d / %d" % [int(game.xp), int(game.xp_needed)]
	_xp_ratio = clampf(float(game.xp) / float(maxi(int(game.xp_needed), 1)), 0.0, 1.0)

	if int(game.combo) >= 2:
		combo_caption.visible = true
		combo_label.visible = true
		combo_label.text = "x%d" % int(game.combo)
		if _combo_pop > 0.0:
			_combo_pop = maxf(0.0, _combo_pop - delta * 4.0)
			combo_label.scale = Vector2.ONE * (1.0 + 0.28 * _combo_pop)
		else:
			combo_label.scale = Vector2.ONE
	else:
		combo_caption.visible = false
		combo_label.visible = false

	if _toast_time > 0.0:
		_toast_time -= delta
		toast_label.modulate.a = clampf(_toast_time / 0.4, 0.0, 1.0)
	else:
		toast_label.modulate.a = 0.0

	queue_redraw()


func pop_combo(_value: int) -> void:
	_combo_pop = 1.0


func toast(text: String, color: Color) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	toast_label.modulate.a = 1.0
	_toast_time = 1.5


func _draw() -> void:
	# 顶部分隔线
	draw_line(Vector2(40, 90), Vector2(680, 90), Color(1, 1, 1, 0.06), 1.0)

	# 底部霓虹分隔线
	var segments := 32
	var width := 640.0
	var seg_w := width / segments
	for i in segments:
		var t := float(i) / float(segments - 1)
		var col: Color = Palette.CYAN.lerp(Palette.PINK, t)
		col.a = 0.65
		draw_line(Vector2(40.0 + i * seg_w, 816), Vector2(40.0 + (i + 1) * seg_w, 816), col, 2.0)

	# 经验条
	var bar := Rect2(40, 890, 640, 8)
	draw_rect(bar, Color(1, 1, 1, 0.07))
	if _xp_ratio > 0.0:
		var fill := Rect2(bar.position, Vector2(bar.size.x * _xp_ratio, bar.size.y))
		draw_rect(fill, Palette.CYAN)
		draw_rect(fill, Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.25), false, 3.0)
	for i in range(1, 10):
		var x := bar.position.x + bar.size.x * (i / 10.0)
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0.03, 0.05, 0.1, 0.8), 1.0)
