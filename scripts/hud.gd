extends Control

## 界面：顶部模式/金币/击碎数，底部球状态/等级/经验条，中间飘字。
## 所有文案通过 I18n 的 key 读取，默认中文。

const Palette = preload("res://scripts/palette.gd")

var game: Node

var mode_label: Label
var tag_label: Label
var coins_label: Label
var destroyed_label: Label
var balls_label: Label
var bounce_label: Label
var level_label: Label
var xp_label: Label
var hint_label: Label
var prep_label: Label
var toast_label: Label

var _xp_ratio := 0.0
var _toast_time := 0.0
var _coin_pop := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	I18n.locale_changed.connect(_on_locale_changed)
	_refresh_static_texts()
	queue_redraw()


func _build() -> void:
	mode_label = _make_label(I18n.t("hud.mode"), Vector2(40, 16), Vector2(260, 40), 28, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	mode_label.add_theme_constant_override("outline_size", 6)
	mode_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))

	tag_label = _make_label(I18n.t("hud.tag"), Vector2(40, 56), Vector2(420, 26), 16, Palette.MUTED)

	coins_label = _make_label(I18n.t("hud.coins", [0]), Vector2(330, 14), Vector2(140, 32), 22, Palette.ACCENT)
	coins_label.pivot_offset = Vector2(0, 16)

	destroyed_label = _make_label(I18n.t("hud.destroyed", [0]), Vector2(480, 18), Vector2(200, 22), 14, Palette.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)

	balls_label = _make_label(I18n.t("hud.ball_many", [0]), Vector2(40, 816), Vector2(260, 22), 16, Palette.CYAN)
	bounce_label = _make_label(I18n.t("hud.ready"), Vector2(280, 818), Vector2(160, 20), 12, Palette.CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	level_label = _make_label(I18n.t("hud.level", [1]), Vector2(520, 814), Vector2(160, 26), 18, Palette.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)

	xp_label = _make_label(I18n.t("hud.xp", [0, 80]), Vector2(40, 838), Vector2(120, 14), 10, Palette.MUTED)

	hint_label = _make_label(
		I18n.t("hud.hint"),
		Vector2(40, 934), Vector2(640, 18), 10, Palette.MUTED, HORIZONTAL_ALIGNMENT_CENTER
	)

	prep_label = _make_label("", Vector2(60, 296), Vector2(600, 56), 38, Palette.CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	prep_label.add_theme_constant_override("outline_size", 10)
	prep_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	prep_label.visible = false

	toast_label = _make_label("", Vector2(60, 400), Vector2(600, 64), 40, Palette.CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.add_theme_constant_override("outline_size", 10)
	toast_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	toast_label.modulate.a = 0.0


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


func _refresh_static_texts() -> void:
	mode_label.text = I18n.t("hud.mode")
	tag_label.text = I18n.t("hud.tag")
	hint_label.text = I18n.t("hud.hint")


func _on_locale_changed(_locale: String) -> void:
	_refresh_static_texts()


func _process(delta: float) -> void:
	if game == null:
		return

	coins_label.text = I18n.t("hud.coins", [int(game.coins)])
	if _coin_pop > 0.0:
		_coin_pop = maxf(0.0, _coin_pop - delta * 4.0)
		coins_label.scale = Vector2.ONE * (1.0 + 0.15 * _coin_pop)
	else:
		coins_label.scale = Vector2.ONE

	if game.preparing:
		prep_label.visible = true
		prep_label.text = I18n.t("hud.prepare", [ceili(float(game.prep_timer))])
	else:
		prep_label.visible = false

	destroyed_label.text = I18n.t("hud.destroyed", [int(game.blocks.destroyed)])

	var ball_count: int = game.active_balls.size()
	var ball_key := "hud.ball_one" if ball_count == 1 else "hud.ball_many"
	balls_label.text = I18n.t(ball_key, [ball_count])
	if ball_count > 0:
		var ball: Node = game.active_balls[ball_count - 1]
		if int(ball.bounces_left) > 0:
			bounce_label.text = I18n.t("hud.bounces", [int(ball.bounces_left)])
		else:
			bounce_label.text = I18n.t("hud.single_hit")
	else:
		bounce_label.text = I18n.t("hud.ready")

	level_label.text = I18n.t("hud.level", [int(game.level)])
	xp_label.text = I18n.t("hud.xp", [int(game.xp), int(game.xp_needed)])
	_xp_ratio = clampf(float(game.xp) / float(maxi(int(game.xp_needed), 1)), 0.0, 1.0)

	if _toast_time > 0.0:
		_toast_time -= delta
		toast_label.modulate.a = clampf(_toast_time / 0.4, 0.0, 1.0)
	else:
		toast_label.modulate.a = 0.0

	queue_redraw()


func pop_coins() -> void:
	_coin_pop = 1.0


func toast(text: String, color: Color) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	toast_label.modulate.a = 1.0
	_toast_time = 1.5


func _draw() -> void:
	# 顶部分隔线
	draw_line(Vector2(40, 90), Vector2(680, 90), Color(1, 1, 1, 0.06), 1.0)

	# 金币图标
	var coin_center := Vector2(316, 30)
	draw_circle(coin_center, 9.5, Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.10))
	draw_circle(coin_center, 6.5, Palette.ACCENT.darkened(0.12))
	draw_arc(coin_center, 6.5, 0.0, TAU, 24, Palette.ACCENT.lightened(0.5), 1.2)
	draw_circle(coin_center, 2.0, Color(1.0, 0.95, 0.7, 0.9))

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
	var bar := Rect2(170, 844, 510, 5)
	draw_rect(bar, Color(1, 1, 1, 0.07))
	if _xp_ratio > 0.0:
		var fill := Rect2(bar.position, Vector2(bar.size.x * _xp_ratio, bar.size.y))
		draw_rect(fill, Palette.CYAN)
		draw_rect(fill, Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.25), false, 2.0)
	for i in range(1, 10):
		var x := bar.position.x + bar.size.x * (i / 10.0)
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0.03, 0.05, 0.1, 0.8), 1.0)
