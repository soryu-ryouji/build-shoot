extends Node2D

## 游戏主体：滚动方块流、自动炮塔、金币道具、经验/升级、界面联动。

const Palette = preload("res://scripts/palette.gd")
const Arena = preload("res://scripts/arena.gd")
const Blocks = preload("res://scripts/blocks.gd")
const Ball = preload("res://scripts/ball.gd")
const Hud = preload("res://scripts/hud.gd")
const UpgradeScreen = preload("res://scripts/upgrade_screen.gd")
const HitEffects = preload("res://scripts/hit_effects.gd")
const ItemDefs = preload("res://scripts/item_defs.gd")
const ShopBar = preload("res://scripts/shop_bar.gd")
const FocusPanel = preload("res://scripts/focus_panel.gd")
const PlacedTurret = preload("res://scripts/placed_turret.gd")
const PlacementGhost = preload("res://scripts/placement_ghost.gd")

enum State { PLAYING, UPGRADE }

const PREP_TIME := 5.0
const PLACE_GRID := 64.0

const UPGRADE_DEFS := [
	{"id": "bounce", "max": 4},
	{"id": "damage", "max": 5},
	{"id": "pierce", "max": 3},
	{"id": "chain", "max": 3},
	{"id": "speed", "max": 5},
	{"id": "crit", "max": 4},
	{"id": "salvage", "max": 4},
	{"id": "big", "max": 3},
]

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
var upgrade_screen: CanvasLayer

var placed_turrets: Array = []
var selected_turret: Node = null
var placing := false
var placing_id := ""
var placing_cost := 0

var state: int = State.PLAYING
var preparing := true
var prep_timer := PREP_TIME
var level := 1
var xp := 0
var xp_needed := 80
var coins := 30
var active_balls: Array = []
var pending_levels := 0
var shots_fired := 0

var upgrades := {}
var stats := {
	"damage": 1,
	"pierce": 0,
	"speed": 520.0,
	"bounces": 0,
	"crit": 0.0,
	"salvage": 1.0,
	"chain": 0,
	"radius": 7.0,
}


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

	upgrade_screen = UpgradeScreen.new()
	upgrade_screen.name = "UpgradeScreen"
	add_child(upgrade_screen)
	upgrade_screen.chosen.connect(_on_upgrade_chosen)


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


func get_ball_damage(base: int) -> int:
	if float(stats.crit) > 0.0 and randf() < float(stats.crit):
		return base * 2
	return base


# ---------------------------------------------------------------- 方块 / 经验

func hit_block(id: int, amount: int, depth: int = 0, hit_pos: Vector2 = Vector2.INF) -> void:
	var res: Dictionary = blocks.damage(id, amount)
	if not bool(res.get("hit", false)):
		return

	var center: Vector2 = res.rect.get_center()
	var fx_pos := center if hit_pos == Vector2.INF else hit_pos
	effects.emit_hit(fx_pos, res.color, bool(res.destroyed))

	if not bool(res.destroyed):
		return

	_reward_block(int(res.max_hp))

	# 连锁爆炸：破坏的方块会伤到相邻方块，深度限制避免爆炸性递归
	if int(stats.chain) > 0 and depth < 4:
		var destroyed_rect: Rect2 = res.rect
		var grown := destroyed_rect.grow(3.0)
		for b in blocks.blocks:
			if not bool(b.alive):
				continue
			var rect: Rect2 = b.rect
			if rect.intersects(grown):
				hit_block(int(b.id), int(stats.chain), depth + 1)


func _reward_block(max_hp: int) -> void:
	coins += maxi(1, max_hp)
	var gain := int(round((4.0 + max_hp * 2.0) * float(stats.salvage)))
	add_xp(gain)
	hud.pop_coins()


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		pending_levels += 1
		xp_needed = 80 + (level - 1) * 60

	if pending_levels > 0 and state == State.PLAYING:
		_open_upgrade()


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
	if state != State.PLAYING:
		return
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


func fire_item_ball(source: Node, pos: Vector2, dir: Vector2, dmg: int, pierce: int, bounces: int, speed: float, radius: float) -> void:
	shots_fired += 1
	var ball = Ball.new()
	ball.setup(self, pos, dir, speed, radius, dmg, pierce, bounces)
	balls_layer.add_child(ball)
	ball.vanished.connect(_on_ball_vanished.bind(ball))
	active_balls.append(ball)


# ---------------------------------------------------------------- 升级

func _open_upgrade() -> void:
	var choices := _pick_upgrades(3)
	if choices.is_empty():
		pending_levels = 0
		return

	cancel_placement()
	clear_selection()
	state = State.UPGRADE
	get_tree().paused = true
	upgrade_screen.show_choices(choices)


func _pick_upgrades(count: int) -> Array:
	var pool: Array = []
	for def in UPGRADE_DEFS:
		var cur := int(upgrades.get(String(def.id), 0))
		if cur < int(def.max):
			pool.append({
				"id": def.id,
				"rank": cur + 1,
				"max": def.max,
			})
	pool.shuffle()
	if pool.size() > count:
		pool.resize(count)
	return pool


func _on_upgrade_chosen(id: String) -> void:
	_apply_upgrade(id)
	pending_levels = maxi(pending_levels - 1, 0)

	var choices := _pick_upgrades(3)
	if pending_levels > 0 and not choices.is_empty():
		upgrade_screen.show_choices(choices)
		return

	pending_levels = 0
	upgrade_screen.hide_screen()
	state = State.PLAYING
	get_tree().paused = false
	hud.toast(I18n.t("toast.upgrade_installed"), Palette.ACCENT)


func _apply_upgrade(id: String) -> void:
	upgrades[id] = int(upgrades.get(id, 0)) + 1
	match id:
		"bounce":
			stats.bounces = int(stats.bounces) + 2
		"damage":
			stats.damage = int(stats.damage) + 1
		"pierce":
			stats.pierce = int(stats.pierce) + 1
		"chain":
			stats.chain = int(stats.chain) + 1
		"speed":
			stats.speed = minf(float(stats.speed) * 1.12, 1150.0)
		"crit":
			stats.crit = minf(float(stats.crit) + 0.15, 0.75)
		"salvage":
			stats.salvage = float(stats.salvage) + 0.25
		"big":
			stats.radius = minf(float(stats.radius) + 2.0, 16.0)
