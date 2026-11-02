extends Node2D

## 游戏主体：滚动方块流、单球发射、经验/升级、界面联动。

const Palette = preload("res://scripts/palette.gd")
const Arena = preload("res://scripts/arena.gd")
const Blocks = preload("res://scripts/blocks.gd")
const Ball = preload("res://scripts/ball.gd")
const Turret = preload("res://scripts/turret.gd")
const Hud = preload("res://scripts/hud.gd")
const UpgradeScreen = preload("res://scripts/upgrade_screen.gd")

enum State { PLAYING, UPGRADE }

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
var turret: Node2D
var hud: Control
var upgrade_screen: CanvasLayer

var state: int = State.PLAYING
var auto_fire := true
var level := 1
var xp := 0
var xp_needed := 80
var combo := 0
var combo_timer := 0.0
var active_balls: Array = []
var pending_levels := 0
var fire_timer := 0.0

var upgrades := {}
var stats := {
	"damage": 1,
	"pierce": 0,
	"speed": 520.0,
	"cooldown": 0.3,
	"bounces": 0,
	"crit": 0.0,
	"salvage": 1.0,
	"chain": 0,
	"radius": 7.0,
}


func _ready() -> void:
	randomize()
	_setup_nodes()
	blocks.reset_stream()


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

	balls_layer = Node2D.new()
	balls_layer.name = "Balls"
	add_child(balls_layer)

	turret = Turret.new()
	turret.name = "Turret"
	turret.game = self
	add_child(turret)

	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HudLayer"
	hud_layer.layer = 1
	add_child(hud_layer)

	hud = Hud.new()
	hud.name = "Hud"
	hud.game = self
	hud_layer.add_child(hud)

	upgrade_screen = UpgradeScreen.new()
	upgrade_screen.name = "UpgradeScreen"
	add_child(upgrade_screen)
	upgrade_screen.chosen.connect(_on_upgrade_chosen)


func _draw() -> void:
	draw_rect(Rect2(-40.0, -40.0, 800.0, 1040.0), Palette.BG)


func _process(delta: float) -> void:
	fire_timer = maxf(0.0, fire_timer - delta)

	# 炮塔默认持续开火，鼠标/触摸只负责调整方向
	if auto_fire:
		request_fire()

	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0



func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				get_tree().paused = false
				get_tree().reload_current_scene()
			KEY_L:
				I18n.toggle_locale()


# ---------------------------------------------------------------- 射击

func request_fire() -> void:
	if state != State.PLAYING:
		return
	# 枪的冷却独立结算，不等场上的球
	if fire_timer > 0.0:
		return

	# 每次发射生成一颗独立的球，旧球继续飞行，不会被吞掉
	fire_timer = float(stats.cooldown)
	_spawn_ball(turret.get_muzzle(), Vector2.from_angle(turret.aim_angle))
	turret.play_recoil()


func _spawn_ball(pos: Vector2, dir: Vector2) -> void:
	var ball = Ball.new()
	ball.setup(
		self,
		pos,
		dir,
		float(stats.speed),
		float(stats.radius),
		int(stats.damage),
		int(stats.pierce),
		int(stats.bounces)
	)
	balls_layer.add_child(ball)
	ball.vanished.connect(_on_ball_vanished.bind(ball))
	active_balls.append(ball)


func _on_ball_vanished(ball: Node) -> void:
	active_balls.erase(ball)


func get_ball_damage(base: int) -> int:
	if float(stats.crit) > 0.0 and randf() < float(stats.crit):
		return base * 2
	return base


# ---------------------------------------------------------------- 方块 / 经验

func hit_block(id: int, amount: int, depth: int = 0) -> void:
	var res: Dictionary = blocks.damage(id, amount)
	if not bool(res.get("hit", false)) or not bool(res.get("destroyed", false)):
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
	combo += 1
	combo_timer = 2.4
	var combo_mult := 1.0 + minf((combo - 1) * 0.06, 1.0)
	var gain := int(round((4.0 + max_hp * 2.0) * combo_mult * float(stats.salvage)))
	add_xp(gain)
	hud.pop_combo(combo)


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


# ---------------------------------------------------------------- 升级

func _open_upgrade() -> void:
	var choices := _pick_upgrades(3)
	if choices.is_empty():
		pending_levels = 0
		return

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
