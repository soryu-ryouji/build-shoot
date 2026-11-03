extends Node2D

## 游戏主体：滚动方块、金币经济、三类建筑布置、能源结算与界面联动。

const DEPLOY_TIME_SCALE := 0.28

const Palette = preload("res://scripts/palette.gd")
const Arena = preload("res://scripts/arena.gd")
const Blocks = preload("res://scripts/blocks.gd")
const Ball = preload("res://scripts/ball.gd")
const Hud = preload("res://scripts/hud.gd")
const HitEffects = preload("res://scripts/hit_effects.gd")
const ItemDefs = preload("res://scripts/item_defs.gd")
const ShopBar = preload("res://scripts/shop_bar.gd")
const FocusPanel = preload("res://scripts/focus_panel.gd")
const PlacedBuilding = preload("res://scripts/placed_building.gd")
const PlacementGhost = preload("res://scripts/placement_ghost.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const ResponsiveLayout = preload("res://scripts/responsive_layout.gd")

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
var settings_panel: Control
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

## 全局能源：按建筑布置顺序供电，既有建筑优先；产能不足时只有排在后面的建筑离线。
var power_supply := 0
var power_demand := 0
var power_offline := 0
var power_ok := true


func _ready() -> void:
	randomize()
	Engine.time_scale = 1.0
	_setup_nodes()


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
	blocks.game = self
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
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var view := ResponsiveLayout.viewport_size(self)
	# 纯竖屏按宽度适配，左右各保留 8 逻辑像素；高度不反向压缩战场。
	var zoom := (view.x - 16.0) / 624.0
	world_camera.zoom = Vector2.ONE * zoom


func screen_to_world(pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * pos


func world_to_screen(pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * pos


func _draw() -> void:
	draw_rect(Rect2(-3000.0, -3000.0, 6000.0, 6000.0), Palette.ARENA_BG)


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
	var snapped := snap_to_grid(pos)
	var valid := is_valid_placement(snapped) and coins >= placing_cost
	placement_ghost.update_preview(snapped, valid)
	var item: Dictionary = ItemDefs.get_item(placing_id)
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
	var valid := is_valid_placement(snapped) and coins >= int(item.cost)
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
	var rect: Rect2 = get_play_rect()
	var x0 := rect.position.x + 32.0
	var y0 := rect.position.y + 32.0
	var x1 := rect.end.x - 32.0
	var y1 := rect.end.y - 32.0

	# 用 64px 的单元铺满四边，最外侧格子中心距边缘 32px，底座刚好放得下
	var steps_x := maxi(1, int(floorf((x1 - x0) / PLACE_GRID)))
	var steps_y := maxi(1, int(floorf((y1 - y0) / PLACE_GRID)))
	var step_x := (x1 - x0) / float(steps_x)
	var step_y := (y1 - y0) / float(steps_y)

	var gx := x0 + roundf((pos.x - x0) / step_x) * step_x
	var gy := y0 + roundf((pos.y - y0) / step_y) * step_y

	# 在场地及边框附近拖动时，把最外侧的格子夹到可用范围内，避免边缘一直判红
	if rect.grow(16.0).has_point(pos):
		gx = clampf(gx, x0, x1)
		gy = clampf(gy, y0, y1)

	return Vector2(gx, gy)


func get_range_cells(center: Vector2, radius: float) -> Array:
	var cells: Array = []
	for cell in _grid_centers():
		if cell.distance_to(center) <= radius:
			cells.append(cell)
	return cells


func get_line_cells(center: Vector2, direction: Vector2) -> Array:
	var cells: Array = []
	for cell in _grid_centers():
		if absf((cell - center).cross(direction)) <= 34.0:
			cells.append(cell)
	return cells


func _grid_centers() -> Array:
	var rect: Rect2 = get_play_rect()
	var x0 := rect.position.x + 32.0
	var y0 := rect.position.y + 32.0
	var x1 := rect.end.x - 32.0
	var y1 := rect.end.y - 32.0
	var steps_x := maxi(1, int(floorf((x1 - x0) / PLACE_GRID)))
	var steps_y := maxi(1, int(floorf((y1 - y0) / PLACE_GRID)))
	var step_x := (x1 - x0) / float(steps_x)
	var step_y := (y1 - y0) / float(steps_y)
	var result: Array = []
	for ix in steps_x + 1:
		for iy in steps_y + 1:
			result.append(Vector2(x0 + step_x * ix, y0 + step_y * iy))
	return result


func is_valid_placement(pos: Vector2) -> bool:
	var rect: Rect2 = get_play_rect()
	var margin := 32.0
	if pos.x < rect.position.x + margin or pos.x > rect.end.x - margin:
		return false
	if pos.y < rect.position.y + margin or pos.y > rect.end.y - margin:
		return false
	for t in placed_buildings:
		if is_instance_valid(t) and pos.distance_to(t.global_position) < 62.0:
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
