extends Control

## 界面：顶部模式/金币/击碎数，底部球状态与道具栏，中间飘字。
## 所有文案通过 I18n 的 key 读取，默认中文。

const Palette = preload("res://scripts/palette.gd")
const NumberFont = preload("res://theme/number_font.tres")

var game: Node

var mode_label: Label
var tag_label: Label
var coins_label: Label
var coins_title_label: Label
var destroyed_label: Label
var balls_label: Label
var bounce_label: Label
var prep_label: Label
var toast_label: Label

var _toast_time := 0.0
var _coin_pop := 0.0
var _top_panel: StyleBoxFlat
var _coin_panel: StyleBoxFlat
var _message_panel: StyleBoxFlat


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	I18n.locale_changed.connect(_on_locale_changed)
	_refresh_static_texts()
	queue_redraw()


func _build() -> void:
	_top_panel = _panel_style(Color(Palette.PAPER, 0.94), Color(1.0, 1.0, 0.98, 0.72), 0)
	_coin_panel = _panel_style(Color(1.0, 1.0, 0.98, 0.30), Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.65), 0)
	_message_panel = _panel_style(Color(Palette.PAPER, 0.95), Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.75), 0)

	mode_label = _make_label(I18n.t("hud.mode"), Vector2(52, 20), Vector2(238, 36), 26, Palette.INK, HORIZONTAL_ALIGNMENT_LEFT)

	tag_label = _make_label(I18n.t("hud.tag"), Vector2(52, 55), Vector2(246, 18), 11, Palette.INK_MUTED)

	coins_title_label = _make_label(I18n.t("hud.coins_label"), Vector2(358, 24), Vector2(132, 15), 9, Palette.INK_MUTED)
	coins_label = _make_label(I18n.t("hud.coins_value", [0]), Vector2(358, 37), Vector2(136, 34), 27, Palette.ACCENT)
	coins_label.add_theme_font_override("font", NumberFont)
	coins_label.pivot_offset = Vector2(0, 17)

	destroyed_label = _make_label(I18n.t("hud.destroyed", [0]), Vector2(510, 28), Vector2(128, 34), 12, Palette.INK_MUTED, HORIZONTAL_ALIGNMENT_RIGHT)

	balls_label = _make_label(I18n.t("hud.ball_many", [0]), Vector2(40, 820), Vector2(220, 24), 13, Palette.INK)
	bounce_label = _make_label(I18n.t("hud.ready"), Vector2(460, 820), Vector2(220, 24), 11, Palette.INK_MUTED, HORIZONTAL_ALIGNMENT_RIGHT)

	prep_label = _make_label("", Vector2(60, 348), Vector2(600, 64), 32, Palette.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	prep_label.add_theme_constant_override("outline_size", 5)
	prep_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	prep_label.visible = false

	toast_label = _make_label("", Vector2(60, 386), Vector2(600, 58), 28, Palette.CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.add_theme_constant_override("outline_size", 5)
	toast_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	toast_label.modulate.a = 0.0


func _panel_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.12)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


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
	coins_title_label.text = I18n.t("hud.coins_label")


func _on_locale_changed(_locale: String) -> void:
	_refresh_static_texts()


func _process(delta: float) -> void:
	if game == null:
		return

	coins_label.text = I18n.t("hud.coins_value", [int(game.coins)])
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
	# 顶部信息按模式、资源、战绩分组，避免漂浮文字互相争抢视觉层级。
	draw_style_box(_top_panel, Rect2(24, 16, 672, 64))
	draw_colored_polygon(PackedVector2Array([Vector2(680, 16), Vector2(696, 16), Vector2(696, 32)]), Palette.ARENA_BG)
	draw_rect(Rect2(36, 29, 4, 38), Palette.ACCENT)
	draw_style_box(_coin_panel, Rect2(324, 22, 184, 50))
	draw_line(Vector2(516, 28), Vector2(516, 66), Color(0.10, 0.12, 0.13, 0.16), 1.0)
	draw_line(Vector2(24, 80), Vector2(198, 80), Palette.ACCENT, 2.0)

	var coin_center := Vector2(340, 47)
	draw_circle(coin_center, 10.0, Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.10))
	draw_circle(coin_center, 6.5, Palette.ACCENT.darkened(0.12))
	draw_arc(coin_center, 6.5, 0.0, TAU, 24, Palette.ACCENT.lightened(0.5), 1.2)
	draw_circle(coin_center, 2.0, Color(1.0, 0.95, 0.7, 0.9))

	# 场地下沿只保留一条低亮度状态线。
	draw_line(Vector2(48, 816), Vector2(672, 816), Color(0.10, 0.12, 0.13, 0.20), 1.0)
	draw_rect(Rect2(24, 828, 8, 8), Palette.ACCENT)
	draw_line(Vector2(48, 820), Vector2(160, 820), Palette.ACCENT, 2.0)

	if game != null and game.preparing:
		draw_style_box(_message_panel, Rect2(250, 352, 220, 56))
	if toast_label.modulate.a > 0.0:
		_message_panel.bg_color.a = 0.92 * toast_label.modulate.a
		_message_panel.border_color.a = 0.45 * toast_label.modulate.a
		draw_style_box(_message_panel, Rect2(210, 392, 300, 46))

