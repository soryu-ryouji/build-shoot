extends CanvasLayer

## 升级三选一界面。暂停游戏时仍可交互。文案通过 I18n 的 key 读取。

const Palette = preload("res://scripts/palette.gd")

signal chosen(id: String)

var root: Control
var card_row: HBoxContainer
var title_label: Label
var subtitle_label: Label
var buttons: Array[Button] = []

var _choices: Array = []
var _active := false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var line := ColorRect.new()
	line.color = Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.5)
	line.position = Vector2(120, 196)
	line.size = Vector2(480, 2)
	root.add_child(line)

	title_label = Label.new()
	title_label.position = Vector2(0, 150)
	title_label.size = Vector2(720, 56)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 46)
	title_label.add_theme_color_override("font_color", Palette.TEXT)
	title_label.add_theme_constant_override("outline_size", 10)
	title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
	root.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.position = Vector2(0, 212)
	subtitle_label.size = Vector2(720, 28)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 14)
	subtitle_label.add_theme_color_override("font_color", Palette.MUTED)
	root.add_child(subtitle_label)

	card_row = HBoxContainer.new()
	card_row.position = Vector2(53, 290)
	card_row.size = Vector2(614, 320)
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 10)
	root.add_child(card_row)

	I18n.locale_changed.connect(_on_locale_changed)
	_refresh_static_texts()


func _refresh_static_texts() -> void:
	title_label.text = I18n.t("upgrade.title")
	subtitle_label.text = I18n.t("upgrade.subtitle")


func _on_locale_changed(_locale: String) -> void:
	_refresh_static_texts()
	if _active:
		show_choices(_choices)


func show_choices(choices: Array) -> void:
	_choices = choices
	_active = true
	root.visible = true

	for b in buttons:
		if is_instance_valid(b):
			# 先脱离布局，避免新旧卡片同帧叠在一起
			b.get_parent().remove_child(b)
			b.queue_free()
	buttons.clear()

	for i in choices.size():
		var def: Dictionary = choices[i]
		var name_key := "upgrade.%s.name" % String(def.id)
		var desc_key := "upgrade.%s.desc" % String(def.id)
		var rank_text := I18n.t("upgrade.rank", [int(def.rank), int(def.max)])
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(198, 300)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = "[%d]\n\n%s\n\n%s\n\n%s" % [
			i + 1,
			I18n.t(name_key),
			I18n.t(desc_key),
			rank_text,
		]
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Palette.TEXT)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		btn.add_theme_constant_override("line_spacing", 4)
		btn.add_theme_stylebox_override("normal", _card_style(Color(0.08, 0.16, 0.28, 0.95), Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.35)))
		btn.add_theme_stylebox_override("hover", _card_style(Color(0.10, 0.22, 0.36, 0.98), Palette.CYAN))
		btn.add_theme_stylebox_override("pressed", _card_style(Color(0.06, 0.12, 0.22, 1.0), Palette.ACCENT))
		btn.pressed.connect(_choose.bind(String(def.id)))
		card_row.add_child(btn)
		buttons.append(btn)


func hide_screen() -> void:
	_active = false
	root.visible = false


func _card_style(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 18.0
	return sb


func _choose(id: String) -> void:
	if not _active:
		return
	_active = false
	root.visible = false
	chosen.emit(id)


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1:
				if _choices.size() >= 1:
					_choose(String(_choices[0].id))
			KEY_2, KEY_KP_2:
				if _choices.size() >= 2:
					_choose(String(_choices[1].id))
			KEY_3, KEY_KP_3:
				if _choices.size() >= 3:
					_choose(String(_choices[2].id))
			KEY_R:
				get_tree().paused = false
				get_tree().reload_current_scene()
			KEY_L:
				I18n.toggle_locale()
