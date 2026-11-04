extends Node2D

## 游戏主体：路线地图、金币经济、三类建筑布置、能源结算与界面联动。

const DEPLOY_TIME_SCALE := 0.28

const Palette = preload("res://scripts/palette.gd")
const Arena = preload("res://scripts/arena.gd")
const BattleMap = preload("res://scripts/battle_map.gd")
const Blocks = preload("res://scripts/blocks.gd")
const Ball = preload("res://scripts/ball.gd")
const Hud = preload("res://scripts/hud.gd")
const HitEffects = preload("res://scripts/hit_effects.gd")
const ItemDefs = preload("res://scripts/item_defs.gd")
const ShopBar = preload("res://scripts/shop_bar.gd")
const FocusPanel = preload("res://scripts/focus_panel.gd")
const GameOverPanel = preload("res://scripts/game_over_panel.gd")
const PlacedBuilding = preload("res://scripts/placed_building.gd")
const PlacementGhost = preload("res://scripts/placement_ghost.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const ResponsiveLayout = preload("res://scripts/responsive_layout.gd")
const BattleWorld = preload("res://scripts/battle_world.gd")

const PREP_TIME := 5.0
const BASE_HP := 12

var arena: Node2D
var blocks: Node2D
var blocks_clip: Control
var balls_layer: Node2D
var battle_world: SubViewport
var world_sprite: Sprite2D
var items_layer: Node2D
var effects: Node2D
var placement_ghost: Node2D
var hud: Control
var shop_bar: Control
var focus_panel: Control
var settings_panel: Control
var game_over_panel: Control
var world_camera: Camera2D
var dim_rect: ColorRect

var placed_buildings: Array = []
var selected_building: Node = null
var placing := false
var placing_id := ""
var placing_cost := 0
var orienting := false
var orient_item: Dictionary = {}
var orient_pos := Vector2.ZERO
var orient_facing := -PI / 2.0
var orient_dragging := false

var preparing := true
var prep_timer := PREP_TIME
var coins := 50

## 核心血量：敌人走到核心扣 1 点，扣完判负
var base_hp := BASE_HP
var base_max_hp := BASE_HP
var game_over := false

## 全局能源：按建筑布置顺序供电，既有建筑优先；产能不足时只有排在后面的建筑离线。
var power_supply := 0
var power_demand := 0
var power_offline := 0
var power_ok := true


func _ready() -> void:
	randomize()
	Engine.time_scale = 1.0
	_setup_nodes()


## 地图序号：主界面选中的地图，命令行 --map=N 可覆盖（截图与测试用）
func _requested_map_index() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			return maxi(0, int(arg.trim_prefix("--map=")))
	return maxi(0, int(GameSettings.map_index))


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
	hud.toast(I18n.t(BattleMap.map_name_key()), Palette.CYAN)


## ---------------------------------------------------------------- 核心与失败

func on_enemy_leaked(_enemy: Dictionary) -> void:
	if game_over:
		return
	if effects != null:
		effects.emit_hit(BattleMap.core_center(), Palette.DANGER, true)
	damage_base(1)


func damage_base(amount: int) -> void:
	if game_over:
		return
	base_hp = maxi(0, base_hp - amount)
	if arena != null:
		arena.set_core_ratio(float(base_hp) / float(maxi(base_max_hp, 1)))
		arena.flash_core()
	if base_hp <= 0:
		_trigger_game_over()


func _trigger_game_over() -> void:
	if game_over:
		return
	game_over = true
	blocks.active = false
	cancel_placement()
	clear_selection()
	game_over_panel.show_result(int(blocks.wave), int(blocks.destroyed))
	get_tree().paused = true


func _setup_nodes() -> void:
	BattleMap.use(_requested_map_index())

	# 3D 战场：视口渲染，再用一张贴图铺回 2D 世界层
	battle_world = BattleWorld.new()
	battle_world.name = "BattleWorld"
	add_child(battle_world)

	world_sprite = Sprite2D.new()
	world_sprite.name = "WorldView"
	world_sprite.texture = battle_world.get_texture()
	world_sprite.centered = true
	world_sprite.position = BattleMap.field_rect().get_center()
	world_sprite.z_index = 0
	add_child(world_sprite)


	arena = Arena.new()
	arena.name = "Arena"
	add_child(arena)

	# 用 Control 裁剪敌人层，避免贴图溢出到地图边框外
	blocks_clip = Control.new()
	blocks_clip.name = "BlocksClip"
	blocks_clip.position = Arena.FRAME_RECT.position
	blocks_clip.size = Arena.FRAME_RECT.size
	blocks_clip.clip_contents = true
	blocks_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(blocks_clip)

	blocks = Blocks.new()
	blocks.name = "Blocks"
	blocks.position = -Arena.FRAME_RECT.position
	blocks.game = self
	blocks_clip.add_child(blocks)

	items_layer = Node2D.new()
	items_layer.name = "Items"
	# 2.5D 建筑要按位置前后遮挡，靠 y 排序决定绘制顺序
	items_layer.y_sort_enabled = true
	add_child(items_layer)

	balls_layer = Node2D.new()
	balls_layer.name = "Balls"
	add_child(balls_layer)

	effects = HitEffects.new()
	effects.name = "HitEffects"
	add_child(effects)

	placement_ghost = PlacementGhost.new()
	placement_ghost.name = "PlacementGhost"
	placement_ghost.game = self
	add_child(placement_ghost)

	world_camera = Camera2D.new()
	world_camera.name = "WorldCamera"
	world_camera.position = Vector2(360, 456)
	add_child(world_camera)
	world_camera.make_current()

	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HudLayer"
	hud_layer.layer = 1
	add_child(hud_layer)

	dim_rect = ColorRect.new()
	dim_rect.name = "DeployDim"
	dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim_rect.visible = false
	var dim_shader := Shader.new()
	dim_shader.code = """
shader_type canvas_item;
uniform float strength = 0.55;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = max(abs(p.x), abs(p.y));
	float edge = smoothstep(0.42, 1.16, d);
	COLOR = vec4(0.015, 0.025, 0.035, edge * strength);
}
"""
	var dim_material := ShaderMaterial.new()
	dim_material.shader = dim_shader
	dim_rect.material = dim_material
	hud_layer.add_child(dim_rect)

	hud = Hud.new()
	hud.name = "Hud"
	hud.game = self
	hud_layer.add_child(hud)
	hud.settings_requested.connect(open_settings)

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

	settings_panel = SettingsPanel.new()
	settings_panel.name = "SettingsPanel"
	ui_layer.add_child(settings_panel)
	settings_panel.closed.connect(_on_settings_closed)
	settings_panel.restart_requested.connect(_on_settings_restart)
	settings_panel.menu_requested.connect(_on_settings_menu)

	game_over_panel = GameOverPanel.new()
	game_over_panel.name = "GameOverPanel"
	ui_layer.add_child(game_over_panel)
	game_over_panel.restart_requested.connect(_on_settings_restart)
	game_over_panel.menu_requested.connect(_on_settings_menu)

	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var field := ResponsiveLayout.field_rect(self)
	# 战场按 HUD 与商店之间的可用区缩放：先满足宽度，高度不够时再收紧，整张地图不会被上下栏遮住。
	var fit_width := (field.size.x - 16.0) / Arena.FRAME_RECT.size.x
	var fit_height := field.size.y / Arena.FRAME_RECT.size.y
	var zoom := maxf(minf(fit_width, fit_height), 0.1)
	world_camera.zoom = Vector2.ONE * zoom

	# 相机对准可用区中心，而不是屏幕中心，上下留白因此对称。
	var view := ResponsiveLayout.viewport_size(self)
	var offset := field.get_center() - view * 0.5
	world_camera.position = Arena.FRAME_RECT.get_center() - offset / zoom


func screen_to_world(pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * pos


func world_to_screen(pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * pos


func _draw() -> void:
	draw_rect(Rect2(-3000.0, -3000.0, 6000.0, 6000.0), Palette.BG)


func open_settings() -> void:
	cancel_placement()
	clear_selection()
	settings_panel.open_panel(true)
	get_tree().paused = true


func close_settings() -> void:
	settings_panel.close_panel()


func _on_settings_closed() -> void:
	get_tree().paused = false


func _on_settings_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_settings_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				open_settings()
			KEY_R:
				get_tree().paused = false
				get_tree().reload_current_scene()
			KEY_L:
				I18n.toggle_locale()
				GameSettings.save_settings()
		return

	if orienting:
		_handle_orientation_input(event)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_world_click(screen_to_world(event.position))
	elif event is InputEventScreenTouch and event.pressed:
		_handle_world_click(screen_to_world(event.position))


# ---------------------------------------------------------------- 方块 / 金币

func hit_block(id: int, amount: int, hit_pos: Vector2 = Vector2.INF, electric: bool = false) -> void:
	var res: Dictionary = blocks.damage(id, amount)
	if not bool(res.get("hit", false)):
		return

	var center: Vector2 = res.rect.get_center()
	var fx_pos := center if hit_pos == Vector2.INF else hit_pos
	var fx_color: Color = res.color
	if electric:
		fx_color = Color(0.68, 0.94, 1.0)
	effects.emit_hit(fx_pos, fx_color, bool(res.destroyed))

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
	update_placement(screen_to_world(pos))


func _on_shop_drag_released(item_id: String, pos: Vector2) -> void:
	finish_placement(item_id, screen_to_world(pos))


func begin_placement(item_id: String) -> void:
	var item: Dictionary = ItemDefs.get_item(item_id)
	if item.is_empty():
		return
	if coins < int(item.cost):
		hud.toast(I18n.t("shop.not_enough"), Palette.DANGER)
		return

	cancel_orientation()
	clear_selection()
	_set_deploy_focus(true)
	placing = true
	placing_id = item_id
	placing_cost = int(item.cost)
	placement_ghost.begin(item)
	update_placement(screen_to_world(get_viewport().get_mouse_position()))


func update_placement(pos: Vector2) -> void:
	if not placing:
		return
	var item: Dictionary = ItemDefs.get_item(placing_id)
	var snapped := snap_to_grid(pos)
	var valid := is_valid_placement(snapped, String(item.get("category", ""))) and coins >= placing_cost
	placement_ghost.update_preview(snapped, valid)
	if String(item.get("category", "")) == ItemDefs.CATEGORY_FIREPOWER:
		placement_ghost.set_range_cells(get_range_cells(snapped, float(item.get("range", 0.0))))
	elif _needs_direction(item):
		placement_ghost.set_range_cells(get_line_cells(snapped, Vector2.from_angle(-PI / 2.0)))
	else:
		placement_ghost.set_range_cells([])


func finish_placement(item_id: String, pos: Vector2) -> void:
	if not placing or item_id != placing_id:
		cancel_placement()
		return

	var item: Dictionary = ItemDefs.get_item(placing_id)
	var snapped := snap_to_grid(pos)
	var valid := is_valid_placement(snapped, String(item.get("category", ""))) and coins >= int(item.cost)
	placing = false
	placing_id = ""
	placing_cost = 0

	if valid:
		if _needs_direction(item):
			_begin_orientation(item, snapped)
			return
		coins -= int(item.cost)
		_place_building(item, snapped)
	elif coins < int(item.cost):
		hud.toast(I18n.t("shop.not_enough"), Palette.DANGER)
	elif BattleMap.is_path(BattleMap.tile_at(snapped)) and String(item.get("category", "")) != BattleMap.CATEGORY_FORTIFICATION:
		hud.toast(I18n.t("shop.need_fortification"), Palette.DANGER)
	elif _inside_arena(snapped):
		hud.toast(I18n.t("shop.invalid"), Palette.DANGER)

	_set_deploy_focus(false)
	placement_ghost.end()


func cancel_placement() -> void:
	placing = false
	placing_id = ""
	placing_cost = 0
	_set_deploy_focus(false)
	cancel_orientation()
	if placement_ghost != null:
		placement_ghost.end()
	if shop_bar != null:
		shop_bar.cancel_drag()


func cancel_orientation() -> void:
	orienting = false
	orient_dragging = false
	orient_item = {}
	orient_pos = Vector2.ZERO
	if placement_ghost != null:
		placement_ghost.end()


func _set_deploy_focus(active: bool) -> void:
	Engine.time_scale = DEPLOY_TIME_SCALE if active else 1.0
	if dim_rect != null:
		dim_rect.visible = active


func _needs_direction(item: Dictionary) -> bool:
	# 只有覆盖范围随朝向变化的建筑需要二次确认；炮塔/电力塔/沙袋直接放置。
	return int(item.get("buff_multiplier", 1)) > 1


func _begin_orientation(item: Dictionary, pos: Vector2) -> void:
	orienting = true
	orient_dragging = false
	orient_item = item
	orient_pos = pos
	orient_facing = -PI / 2.0
	placement_ghost.begin_orientation(pos, item, orient_facing, get_play_rect())
	if String(item.get("category", "")) == ItemDefs.CATEGORY_FIREPOWER:
		placement_ghost.set_range_cells(get_range_cells(pos, float(item.get("range", 0.0))))
	elif _needs_direction(item):
		placement_ghost.set_range_cells(get_line_cells(pos, Vector2.from_angle(orient_facing)))
	else:
		placement_ghost.set_range_cells([])


func _handle_orientation_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			orient_dragging = true
			_update_orientation(screen_to_world(event.position))
		elif orient_dragging:
			_update_orientation(screen_to_world(event.position))
			_confirm_orientation()
		return
	if event is InputEventMouseMotion and orient_dragging:
		_update_orientation(screen_to_world(event.position))
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			orient_dragging = true
			_update_orientation(screen_to_world(event.position))
		elif orient_dragging:
			_update_orientation(screen_to_world(event.position))
			_confirm_orientation()
		return
	if event is InputEventScreenDrag and orient_dragging:
		_update_orientation(screen_to_world(event.position))


func _update_orientation(world_pos: Vector2) -> void:
	var offset := world_pos - orient_pos
	if offset.length() < 10.0:
		return
	var angle := offset.angle()
	orient_facing = roundf(angle / (PI / 4.0)) * (PI / 4.0)
	placement_ghost.set_facing(orient_facing)
	if _needs_direction(orient_item):
		placement_ghost.set_range_cells(get_line_cells(orient_pos, Vector2.from_angle(orient_facing)))


func _confirm_orientation() -> void:
	var item := orient_item
	var pos := orient_pos
	var facing := orient_facing
	var cost := int(item.get("cost", 0))
	if coins < cost:
		hud.toast(I18n.t("shop.not_enough"), Palette.DANGER)
		_set_deploy_focus(false)
		cancel_orientation()
		return
	coins -= cost
	orienting = false
	orient_dragging = false
	orient_item = {}
	orient_pos = Vector2.ZERO
	_set_deploy_focus(false)
	placement_ghost.end()
	_place_building(item, pos, facing)


func snap_to_grid(pos: Vector2) -> Vector2:
	# 拖到场地边缘附近时吸附并夹到最外圈；拖到场地外很远则保留界外格子，由 is_valid_placement 判红
	var tile: Vector2i = BattleMap.tile_at(pos)
	if BattleMap.field_rect().grow(24.0).has_point(pos):
		tile = BattleMap.clamp_tile(tile)
	return BattleMap.tile_center(tile)


func get_range_cells(center: Vector2, radius: float) -> Array:
	var cells: Array = []
	for cell in _grid_centers():
		if cell.distance_to(center) <= radius:
			cells.append(cell)
	return cells


func get_line_cells(center: Vector2, direction: Vector2) -> Array:
	var cells: Array = []
	for cell in _grid_centers():
		if absf((cell - center).cross(direction)) <= BattleMap.TILE * 0.7:
			cells.append(cell)
	return cells


func _grid_centers() -> Array:
	var result: Array = []
	for c in BattleMap.COLS:
		for r in BattleMap.ROWS:
			result.append(BattleMap.tile_center(Vector2i(c, r)))
	return result


func is_valid_placement(pos: Vector2, category := "") -> bool:
	var tile: Vector2i = BattleMap.tile_at(pos)
	# 缺口和核心不能建；通路只放阵地建筑，火力和能源必须放在路外
	if not BattleMap.is_buildable(tile, category):
		return false
	for t in placed_buildings:
		if is_instance_valid(t) and BattleMap.tile_at(t.global_position) == tile:
			return false
	return true


func _inside_arena(pos: Vector2) -> bool:
	var rect: Rect2 = get_play_rect()
	return rect.has_point(pos)


func _place_building(item: Dictionary, pos: Vector2, facing := -PI / 2.0) -> Node:
	var building = PlacedBuilding.new()
	building.setup(self, item, facing)
	building.position = pos
	items_layer.add_child(building)
	placed_buildings.append(building)
	if battle_world != null:
		building.visual3d = battle_world.create_building(String(item.id), pos)
	refresh_power()
	return building


func _handle_world_click(pos: Vector2) -> void:
	if placing:
		return
	if focus_panel != null and focus_panel.visible and focus_panel.get_global_rect().has_point(pos):
		return
	# 手机上炮塔贴图只有 40dp 左右，判定半径放宽到 46 世界单位并取最近的一座
	var best: Node = null
	var best_distance := 46.0
	for t in placed_buildings:
		if not is_instance_valid(t):
			continue
		var distance := pos.distance_to(t.global_position)
		if distance <= best_distance:
			best = t
			best_distance = distance
	if best != null:
		select_building(best)
		return
	clear_selection()


func select_building(t: Node) -> void:
	if t == null or not is_instance_valid(t):
		return
	selected_building = t
	for other in placed_buildings:
		if is_instance_valid(other):
			other.selected = (other == t)
	focus_panel.show_building(t)


func clear_selection() -> void:
	if selected_building != null and is_instance_valid(selected_building):
		selected_building.selected = false
	selected_building = null
	if focus_panel != null:
		focus_panel.hide_panel()


func upgrade_selected() -> void:
	var building = selected_building
	if building == null or not is_instance_valid(building):
		return
	var cost := int(building.get_upgrade_cost())
	if cost < 0:
		return
	if coins < cost:
		hud.toast(I18n.t("shop.not_enough"), Palette.DANGER)
		return
	coins -= cost
	building.apply_upgrade(cost)
	refresh_power()
	if focus_panel != null and focus_panel.visible:
		focus_panel.refresh()
	hud.pop_coins()


func dismantle_selected() -> void:
	var t = selected_building
	if t == null or not is_instance_valid(t):
		clear_selection()
		return
	coins += int(t.get_refund())
	placed_buildings.erase(t)
	t.alive = false
	t.queue_free()
	clear_selection()
	refresh_power()
	hud.pop_coins()


## ---------------------------------------------------------------- 能源

func refresh_power() -> void:
	var supply := 0
	for b in placed_buildings:
		if is_instance_valid(b) and bool(b.alive):
			supply += int(b.energy_output)

	var remaining := supply
	var demand := 0
	var offline := 0

	# 先到先得：按布置顺序分配能源，新建筑排在最后，缺电时由新建筑承担离线。
	for b in placed_buildings:
		if not is_instance_valid(b) or not bool(b.alive):
			continue
		demand += int(b.energy_demand)
		if bool(b.is_energy()):
			b.set_powered(true)
			continue
		if remaining >= int(b.energy_demand):
			b.set_powered(true)
			remaining -= int(b.energy_demand)
		else:
			b.set_powered(false)
			offline += 1

	power_supply = supply
	power_demand = demand
	power_offline = offline
	power_ok = offline == 0


## 压缩塔的直线增益：返回 1 或 2。多个压缩塔不叠加。
func get_buff_multiplier(point: Vector2) -> int:
	for b in placed_buildings:
		if is_instance_valid(b) and bool(b.powered) and int(b.buff_multiplier) > 1 and b.covers_point(point):
			return int(b.buff_multiplier)
	return 1


func is_building_buffed(point: Vector2) -> bool:
	return get_buff_multiplier(point) > 1


## 敌人只会被阵地建筑拦截；同一条线上取最靠上的那座。
func get_blocking_building(rect: Rect2) -> Node:
	var best: Node = null
	var best_y := INF
	for b in placed_buildings:
		if not is_instance_valid(b):
			continue
		if not b.can_block():
			continue
		if b.get_block_rect().intersects(rect) and b.global_position.y < best_y:
			best = b
			best_y = b.global_position.y
	return best


func on_building_destroyed(building: Node) -> void:
	placed_buildings.erase(building)
	if selected_building == building:
		clear_selection()
	refresh_power()
	if hud != null:
		hud.toast(I18n.t("building.destroyed"), Palette.DANGER)


## 场上是否还有火力建筑；exclude 用于拆除前判断拆掉后是否仍有输出。
func has_firepower(exclude: Node = null) -> bool:
	for b in placed_buildings:
		if b == exclude or not is_instance_valid(b):
			continue
		if bool(b.alive) and b.is_firepower():
			return true
	return false


func fire_item_ball(source: Node, pos: Vector2, dir: Vector2, dmg: int, pierce: int, bounces: int, speed: float, radius: float, electric: bool = false) -> void:
	var ball = Ball.new()
	ball.setup(self, pos, dir, speed, radius, dmg, pierce, bounces, electric)
	balls_layer.add_child(ball)
