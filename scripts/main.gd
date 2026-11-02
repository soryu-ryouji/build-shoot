extends Node2D

## 游戏主体：滚动方块、金币道具、网格布置、炮塔金币强化、界面联动。

const Palette = preload("res://scripts/palette.gd")
const Arena = preload("res://scripts/arena.gd")
const Blocks = preload("res://scripts/blocks.gd")
const Ball = preload("res://scripts/ball.gd")
const Hud = preload("res://scripts/hud.gd")
const HitEffects = preload("res://scripts/hit_effects.gd")
const ItemDefs = preload("res://scripts/item_defs.gd")
const ShopBar = preload("res://scripts/shop_bar.gd")
const FocusPanel = preload("res://scripts/focus_panel.gd")
const PlacedTurret = preload("res://scripts/placed_turret.gd")
const PlacementGhost = preload("res://scripts/placement_ghost.gd")

const PREP_TIME := 5.0
const PLACE_GRID := 64.0

var arena: Node2D
var blocks: Node2D
var blocks_clip: Control
var balls_layer: Node2D
var items_layer: Node2D
var effects: Node2D
var placement_ghost: Node2D
var hud: Control
var shop_bar: Control
var focus_panel: Control

var placed_turrets: Array = []
var selected_turret: Node = null
var placing := false
var placing_id := ""
var placing_cost := 0

var preparing := true
var prep_timer := PREP_TIME
var coins := 30
var active_balls: Array = []
var shots_fired := 0


func _ready() -> void:
	randomize()
	_setup_nodes()
	hud.toast(I18n.t("toast.place_turret"), Palette.CYAN)


func _process(delta: float) -> void:
	if not preparing:
		return
	prep_timer -= delta
	if prep_timer <= 0.0:
		_end_prep()


func _end_prep() -> void:
	preparing = false
	prep_timer = 0.0
	blocks.reset_stream()
	hud.toast(I18n.t("toast.start"), Palette.CYAN)


func _setup_nodes() -> void:
	arena = Arena.new()
	arena.name = "Arena"
	add_child(arena)

	var play_rect: Rect2 = arena.get_play_rect()

	# 用 Control 裁剪方块，滚动时从顶部边缘平滑进入
	blocks_clip = Control.new()
	blocks_clip.name = "BlocksClip"
	blocks_clip.position = play_rect.position
	blocks_clip.size = play_rect.size
	blocks_clip.clip_contents = true
	blocks_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(blocks_clip)

	blocks = Blocks.new()
	blocks.name = "Blocks"
	blocks.position = -play_rect.position
	blocks_clip.add_child(blocks)

	items_layer = Node2D.new()
	items_layer.name = "Items"
	add_child(items_layer)

	balls_layer = Node2D.new()
	balls_layer.name = "Balls"
	add_child(balls_layer)

	effects = HitEffects.new()
	effects.name = "HitEffects"
	add_child(effects)

	placement_ghost = PlacementGhost.new()
	placement_ghost.name = "PlacementGhost"
	add_child(placement_ghost)

	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HudLayer"
	hud_layer.layer = 1
	add_child(hud_layer)

	hud = Hud.new()
	hud.name = "Hud"
	hud.game = self
	hud_layer.add_child(hud)

	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UILayer"
	ui_layer.layer = 2
	add_child(ui_layer)

	shop_bar = ShopBar.new()
	shop_bar.name = "ShopBar"
	shop_bar.game = self
	ui_layer.add_child(shop_bar)
	shop_bar.drag_started.connect(_on_shop_drag_started)
	shop_bar.drag_moved.connect(_on_shop_drag_moved)
	shop_bar.drag_released.connect(_on_shop_drag_released)

	focus_panel = FocusPanel.new()
	focus_panel.name = "FocusPanel"
	focus_panel.game = self
	ui_layer.add_child(focus_panel)


func _draw() -> void:
	draw_rect(Rect2(-40.0, -40.0, 800.0, 1040.0), Palette.BG)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				get_tree().paused = false
				get_tree().reload_current_scene()
			KEY_L:
				I18n.toggle_locale()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_world_click(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_world_click(event.position)


# ---------------------------------------------------------------- 球

func _on_ball_vanished(ball: Node) -> void:
	active_balls.erase(ball)


# ---------------------------------------------------------------- 方块 / 金币

func hit_block(id: int, amount: int, hit_pos: Vector2 = Vector2.INF) -> void:
	var res: Dictionary = blocks.damage(id, amount)
	if not bool(res.get("hit", false)):
		return

	var center: Vector2 = res.rect.get_center()
	var fx_pos := center if hit_pos == Vector2.INF else hit_pos
	effects.emit_hit(fx_pos, res.color, bool(res.destroyed))

	if bool(res.destroyed):
		_reward_block(int(res.max_hp))


func _reward_block(max_hp: int) -> void:
	coins += maxi(1, max_hp)
	hud.pop_coins()


func get_play_rect() -> Rect2:
	return arena.get_play_rect()


# ---------------------------------------------------------------- 道具布置

func _on_shop_drag_started(item_id: String) -> void:
	begin_placement(item_id)


func _on_shop_drag_moved(pos: Vector2) -> void:
	update_placement(pos)


func _on_shop_drag_released(item_id: String, pos: Vector2) -> void:
	finish_placement(item_id, pos)


func begin_placement(item_id: String) -> void:
	var item: Dictionary = ItemDefs.get_item(item_id)
	if item.is_empty():
		return
	if coins < int(item.cost):
		hud.toast(I18n.t("shop.not_enough"), Palette.DANGER)
		return

	clear_selection()
	placing = true
	placing_id = item_id
	placing_cost = int(item.cost)
	placement_ghost.begin(item)
	update_placement(get_viewport().get_mouse_position())


func update_placement(pos: Vector2) -> void:
	if not placing:
		return
	var snapped := snap_to_grid(pos)
	var valid := is_valid_placement(snapped) and coins >= placing_cost
	placement_ghost.update_preview(snapped, valid)


func finish_placement(item_id: String, pos: Vector2) -> void:
	if not placing or item_id != placing_id:
		cancel_placement()
		return

	var item: Dictionary = ItemDefs.get_item(placing_id)
	var snapped := snap_to_grid(pos)
	var valid := is_valid_placement(snapped) and coins >= int(item.cost)
	if valid:
		coins -= int(item.cost)
		_place_turret(item, snapped)
	elif coins < int(item.cost):
		hud.toast(I18n.t("shop.not_enough"), Palette.DANGER)
	elif _inside_arena(snapped):
		hud.toast(I18n.t("shop.invalid"), Palette.DANGER)

	placing = false
	placing_id = ""
	placing_cost = 0
	placement_ghost.end()


func cancel_placement() -> void:
	placing = false
	placing_id = ""
	placing_cost = 0
	if placement_ghost != null:
		placement_ghost.end()
	if shop_bar != null:
		shop_bar.cancel_drag()


func snap_to_grid(pos: Vector2) -> Vector2:
	var rect: Rect2 = get_play_rect()
	var origin := rect.position + Vector2(PLACE_GRID * 0.5, PLACE_GRID * 0.5)
	var gx := origin.x + roundf((pos.x - origin.x) / PLACE_GRID) * PLACE_GRID
	var gy := origin.y + roundf((pos.y - origin.y) / PLACE_GRID) * PLACE_GRID
	return Vector2(gx, gy)


func is_valid_placement(pos: Vector2) -> bool:
	var rect: Rect2 = get_play_rect()
	var margin := 60.0
	if pos.x < rect.position.x + margin or pos.x > rect.end.x - margin:
		return false
	if pos.y < rect.position.y + margin or pos.y > rect.end.y - margin:
		return false
	for t in placed_turrets:
		if is_instance_valid(t) and pos.distance_to(t.global_position) < 62.0:
			return false
	return true


func _inside_arena(pos: Vector2) -> bool:
	var rect: Rect2 = get_play_rect()
	return rect.has_point(pos)


func _place_turret(item: Dictionary, pos: Vector2) -> void:
	var t = PlacedTurret.new()
	t.setup(self, item)
	t.position = pos
	items_layer.add_child(t)
	placed_turrets.append(t)


func _handle_world_click(pos: Vector2) -> void:
	if placing:
		return
	if focus_panel != null and focus_panel.visible and focus_panel.get_global_rect().has_point(pos):
		return
	for t in placed_turrets:
		if is_instance_valid(t) and pos.distance_to(t.global_position) <= 34.0:
			select_turret(t)
			return
	clear_selection()


func select_turret(t: Node) -> void:
	if t == null or not is_instance_valid(t):
		return
	selected_turret = t
	for other in placed_turrets:
		if is_instance_valid(other):
			other.selected = (other == t)
	focus_panel.show_turret(t)


func clear_selection() -> void:
	if selected_turret != null and is_instance_valid(selected_turret):
		selected_turret.selected = false
	selected_turret = null
	if focus_panel != null:
		focus_panel.hide_panel()


func dismantle_selected() -> void:
	var t = selected_turret
	if t == null or not is_instance_valid(t):
		clear_selection()
		return
	coins += int(t.get_refund())
	placed_turrets.erase(t)
	t.queue_free()
	clear_selection()
	hud.pop_coins()


func upgrade_selected_damage() -> void:
	var t = selected_turret
	if t == null or not is_instance_valid(t):
		return
	var cost := int(t.get_upgrade_cost())
	if coins < cost:
		hud.toast(I18n.t("shop.not_enough"), Palette.DANGER)
		return
	coins -= cost
	t.apply_damage_upgrade(cost)


func fire_item_ball(source: Node, pos: Vector2, dir: Vector2, dmg: int, pierce: int, bounces: int, speed: float, radius: float) -> void:
	shots_fired += 1
	var ball = Ball.new()
	ball.setup(self, pos, dir, speed, radius, dmg, pierce, bounces)
	balls_layer.add_child(ball)
	ball.vanished.connect(_on_ball_vanished.bind(ball))
	active_balls.append(ball)
