extends Node2D

## 无限地图基地防守：巢穴生成敌人，建筑部署、能源、升级与镜头联动。

const DEPLOY_TIME_SCALE := 0.28
const PREP_TIME := 5.0
const LINE_RANGE := 768.0
const LEGACY_INDUSTRIAL_CELLS := {
    1: Vector2i(-5, -4),
    2: Vector2i(6, -3),
    3: Vector2i(-6, 5),
    4: Vector2i(5, 6),
}

const Palette = preload("res://scripts/palette.gd")
const Arena = preload("res://scripts/arena.gd")
const Blocks = preload("res://scripts/blocks.gd")
const Ball = preload("res://scripts/ball.gd")
const HudScene = preload("res://scenes/ui/hud.tscn")
const HitEffects = preload("res://scripts/hit_effects.gd")
const ItemDefs = preload("res://scripts/item_defs.gd")
const ShopBarScene = preload("res://scenes/ui/shop_bar.tscn")
const FocusPanelScene = preload("res://scenes/ui/focus_panel.tscn")
const PlacedBuilding = preload("res://scripts/placed_building.gd")
const PlacementGhost = preload("res://scripts/placement_ghost.gd")
const TileHighlights = preload("res://scripts/tile_highlights.gd")
const SettingsPanelScene = preload("res://scenes/ui/settings_panel.tscn")
const ResultPanelScene = preload("res://scenes/ui/result_panel.tscn")
const ResponsiveLayout = preload("res://scripts/responsive_layout.gd")
const BaseCore = preload("res://scripts/base_core.gd")
const Nest = preload("res://scripts/nest.gd")
const BuildingBuffs = preload("res://scripts/building_buffs.gd")
const EnergyLinks = preload("res://scripts/energy_links.gd")
const TutorialGuide = preload("res://scripts/tutorial_guide.gd")

@export var tutorial_mode := false
@export var map_path := Arena.DEFAULT_MAP_PATH

var arena: Node2D
var blocks: Node2D
var base_core: Node2D
var nests: Array = []
var balls_layer: Node2D
var items_layer: Node2D
var effects: Node2D
var highlights: Node2D
var energy_links: Node2D
var placement_ghost: Node2D
var hud: Control
var shop_bar: Control
var focus_panel: Control
var settings_panel: Control
var tutorial: Control
var result_panel: PanelContainer
var result_title: Label
var result_detail: Label
var world_camera: Camera2D
var dim_rect: ColorRect

var placed_buildings: Array = []
var buff_system: RefCounted
var _buildings_by_cell: Dictionary = {}
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
var elapsed := 0.0
var outcome := "playing":
    set(value):
        if outcome == value:
            return
        outcome = value
        Events.set_outcome(value)
var coins := 150:
    set(value):
        value = maxi(0, value)
        if coins == value:
            return
        var previous := coins
        coins = value
        Events.set_coins(value, previous)

var power_supply := 0
var power_demand := 0
var power_offline := 0
var power_ok := true

var camera_center := Vector2.ZERO
var camera_zoom := 0.6
var _base_zoom := 0.0
var _mouse_pan_candidate := false
var _mouse_panning := false
var _mouse_pan_start := Vector2.ZERO
var _touch_points: Dictionary = {}
var _touch_moved := false
var _pinching := false
var _pinch_distance := 0.0
var _pinch_zoom := 1.0
var _autosave_timer := 15.0


func _ready() -> void:
    Events.reset_session()
    randomize()
    Engine.time_scale = 1.0
    buff_system = BuildingBuffs.new(self)
    _setup_nodes()
    Music.play_track("battle")
    if tutorial_mode:
        SaveManager.load_requested = false
    elif SaveManager.load_requested:
        call_deferred("_restore_pending_save")


func _process(delta: float) -> void:
    _process_camera(delta)
    if outcome == "playing" and not tutorial_mode:
        _autosave_timer -= delta
        if _autosave_timer <= 0.0:
            _autosave_timer = 15.0
            SaveManager.save_game(self)
    if outcome != "playing":
        return
    if preparing:
        if tutorial_mode:
            return
        prep_timer -= delta
        if prep_timer <= 0.0:
            _end_prep()
    else:
        elapsed += delta


func _end_prep() -> void:
    preparing = false
    prep_timer = 0.0
    blocks.reset_stream()


func _setup_nodes() -> void:
    arena = Arena.new()
    arena.name = "Arena"
    arena.map_path = map_path
    add_child(arena)

    highlights = TileHighlights.new()
    highlights.name = "TileHighlights"
    highlights.map = arena.map_loader
    add_child(highlights)

    energy_links = EnergyLinks.new()
    energy_links.name = "EnergyLinks"
    add_child(energy_links)

    blocks = Blocks.new()
    blocks.name = "Blocks"
    # 敌人接触所有建筑并停下攻击；绘制在建筑上方，避免接触时被遮住。
    blocks.z_index = 5
    blocks.game = self
    add_child(blocks)

    items_layer = Node2D.new()
    items_layer.name = "Items"
    add_child(items_layer)

    base_core = BaseCore.new()
    base_core.name = "BaseCore"
    base_core.setup(self, arena.map_loader.get_base_definition())
    add_child(base_core)
    for definition in arena.map_loader.get_nest_definitions():
        var nest = Nest.new()
        nest.name = "Nest%d" % int(definition.id)
        nest.setup(self, definition)
        add_child(nest)
        nests.append(nest)
    Events.set_nest_count(nests.size())

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
    # 使用普通透明遮罩，避免 Web 部署时全屏 Shader 重绘造成建筑闪烁。
    dim_rect.color = Color(0.015, 0.025, 0.035, 0.16)
    hud_layer.add_child(dim_rect)

    hud = HudScene.instantiate()
    hud.name = "Hud"
    hud.game = self
    hud_layer.add_child(hud)
    hud.settings_requested.connect(open_settings)

    var ui_layer := CanvasLayer.new()
    ui_layer.name = "UILayer"
    ui_layer.layer = 2
    add_child(ui_layer)
    shop_bar = ShopBarScene.instantiate()
    shop_bar.name = "ShopBar"
    shop_bar.game = self
    ui_layer.add_child(shop_bar)
    shop_bar.drag_started.connect(_on_shop_drag_started)
    shop_bar.drag_moved.connect(_on_shop_drag_moved)
    shop_bar.drag_released.connect(_on_shop_drag_released)
    shop_bar.drag_cancelled.connect(cancel_placement)
    focus_panel = FocusPanelScene.instantiate()
    focus_panel.name = "FocusPanel"
    focus_panel.game = self
    ui_layer.add_child(focus_panel)
    settings_panel = SettingsPanelScene.instantiate()
    settings_panel.name = "SettingsPanel"
    ui_layer.add_child(settings_panel)
    settings_panel.save_button.visible = not tutorial_mode
    settings_panel.closed.connect(_on_settings_closed)
    settings_panel.restart_requested.connect(_on_settings_restart)
    settings_panel.menu_requested.connect(_on_settings_menu)
    settings_panel.save_requested.connect(_on_save_requested)
    _build_result_panel(ui_layer)
    if tutorial_mode:
        tutorial = TutorialGuide.new()
        tutorial.name = "TutorialGuide"
        tutorial.game = self
        ui_layer.add_child(tutorial)
    get_viewport().size_changed.connect(_layout)
    _layout()


func _build_result_panel(parent: Node) -> void:
    result_panel = ResultPanelScene.instantiate()
    result_panel.tutorial_result = tutorial_mode
    parent.add_child(result_panel)
    result_title = result_panel.title_label
    result_detail = result_panel.detail_label
    result_panel.restart_requested.connect(_on_settings_restart)
    result_panel.menu_requested.connect(_on_settings_menu)


func _layout() -> void:
    var field := ResponsiveLayout.field_rect(self)
    _base_zoom = maxf(0.1, minf((field.size.x - 16.0) / 640.0, (field.size.y - 16.0) / 420.0))
    camera_zoom = clampf(camera_zoom, _base_zoom * 0.65, _base_zoom * 2.0)
    if world_camera.zoom == Vector2.ONE:
        camera_zoom = _base_zoom
    _apply_camera()


func _apply_camera() -> void:
    if world_camera == null:
        return
    var view := ResponsiveLayout.viewport_size(self)
    var field := ResponsiveLayout.field_rect(self)
    var offset := field.get_center() - view * 0.5
    world_camera.zoom = Vector2.ONE * camera_zoom
    world_camera.position = camera_center - offset / camera_zoom
    arena.map_loader.update_view(world_camera.position, view / camera_zoom)
    highlights.camera_zoom = camera_zoom
    highlights.queue_redraw()
    if shop_bar != null:
        shop_bar.set_camera_zoom(camera_zoom)


func center_on_base() -> void:
    camera_center = base_core.global_position
    _apply_camera()


func _process_camera(delta: float) -> void:
    if placing or orienting or outcome != "playing" or get_tree().paused:
        return
    if tutorial_mode and tutorial != null and tutorial.blocks_world_input():
        return
    var direction := Vector2.ZERO
    if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
        direction.x -= 1.0
    if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
        direction.x += 1.0
    if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
        direction.y -= 1.0
    if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
        direction.y += 1.0
    if direction != Vector2.ZERO:
        camera_center += direction.normalized() * 420.0 * delta
        _apply_camera()


func screen_to_world(pos: Vector2) -> Vector2:
    return get_viewport().get_canvas_transform().affine_inverse() * pos


func world_to_screen(pos: Vector2) -> Vector2:
    return get_viewport().get_canvas_transform() * pos


func _visible_world_rect() -> Rect2:
    var size := ResponsiveLayout.field_rect(self).size / camera_zoom
    return Rect2(camera_center - size * 0.5, size)


func _draw() -> void:
    draw_rect(Rect2(-20000.0, -20000.0, 40000.0, 40000.0), Palette.ARENA_BG)


func open_settings() -> void:
    if outcome != "playing":
        return
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
    if outcome == "playing" and not tutorial_mode:
        SaveManager.save_game(self)
    SaveManager.load_requested = false
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
            KEY_HOME:
                center_on_base()
        return
    if outcome != "playing":
        return
    if tutorial_mode and tutorial != null and tutorial.blocks_world_input():
        return
    if orienting:
        _handle_orientation_input(event)
        return
    if placing:
        return
    if event is InputEventMouseButton:
        if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _zoom_at(event.position, 1.12)
            return
        if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _zoom_at(event.position, 1.0 / 1.12)
            return
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                _mouse_pan_candidate = true
                _mouse_panning = false
                _mouse_pan_start = event.position
            else:
                if _mouse_pan_candidate and not _mouse_panning:
                    _handle_world_click(screen_to_world(event.position))
                _mouse_pan_candidate = false
                _mouse_panning = false
            return
    if event is InputEventMouseMotion and _mouse_pan_candidate:
        if not _mouse_panning and event.position.distance_to(_mouse_pan_start) > 5.0:
            _mouse_panning = true
        if _mouse_panning:
            _pan_camera(event.relative)
        return
    if event is InputEventScreenTouch:
        _handle_touch(event)
    elif event is InputEventScreenDrag:
        _handle_touch_drag(event)


func _pan_camera(relative: Vector2) -> void:
    camera_center -= relative / camera_zoom
    _apply_camera()


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
    var before := screen_to_world(screen_pos)
    camera_zoom = clampf(camera_zoom * factor, _base_zoom * 0.65, _base_zoom * 2.0)
    _apply_camera()
    var after := screen_to_world(screen_pos)
    camera_center += before - after
    _apply_camera()


func _handle_touch(event: InputEventScreenTouch) -> void:
    if event.pressed:
        _touch_points[event.index] = event.position
        if _touch_points.size() == 1:
            _touch_moved = false
            _pinching = false
        elif _touch_points.size() == 2:
            _begin_pinch()
        return
    var can_click := _touch_points.size() == 1 and _touch_points.has(event.index) and not _touch_moved and not _pinching
    _touch_points.erase(event.index)
    if can_click:
        _handle_world_click(screen_to_world(event.position))
    if _touch_points.size() < 2:
        _pinching = false
    if _touch_points.is_empty():
        _touch_moved = false


func _handle_touch_drag(event: InputEventScreenDrag) -> void:
    if not _touch_points.has(event.index):
        return
    _touch_points[event.index] = event.position
    if _touch_points.size() >= 2:
        var points := _touch_points.values()
        var distance: float = points[0].distance_to(points[1])
        if _pinch_distance > 0.0:
            camera_zoom = clampf(_pinch_zoom * distance / _pinch_distance, _base_zoom * 0.65, _base_zoom * 2.0)
            _apply_camera()
        _touch_moved = true
    elif not _pinching:
        _touch_moved = true
        _pan_camera(event.relative)


func _begin_pinch() -> void:
    var points := _touch_points.values()
    _pinch_distance = points[0].distance_to(points[1])
    _pinch_zoom = camera_zoom
    _pinching = true
    _touch_moved = true


# ---------------------------------------------------------------- 目标、基地与胜负

func hit_target(target: Dictionary, amount: int, hit_pos: Vector2, electric: bool) -> void:
    if String(target.get("target_type", "enemy")) == "nest":
        hit_nest(target.get("node"), amount, hit_pos, electric)
    else:
        hit_block(int(target.id), amount, hit_pos, electric)


func hit_block(id: int, amount: int, hit_pos: Vector2 = Vector2.INF, electric: bool = false) -> void:
    var res: Dictionary = blocks.damage(id, amount)
    if not bool(res.get("hit", false)):
        return
    Sfx.play("destroy" if bool(res.destroyed) else "hit")
    var center: Vector2 = res.rect.get_center()
    var fx_pos := center if hit_pos == Vector2.INF else hit_pos
    var fx_color: Color = res.color
    if electric:
        fx_color = Color(0.68, 0.94, 1.0)
    effects.emit_hit(fx_pos, fx_color, bool(res.destroyed))
    if bool(res.destroyed):
        _reward_block(int(res.max_hp))


func hit_nest(nest: Node, amount: int, hit_pos: Vector2, electric: bool) -> void:
    if nest == null or not is_instance_valid(nest) or not nest.alive:
        return
    var destroyed: bool = nest.take_damage(amount)
    Sfx.play("destroy" if destroyed else "hit")
    effects.emit_hit(hit_pos, Color(0.68, 0.94, 1.0) if electric else Palette.PINK, destroyed)


func get_nest_targets() -> Array:
    var targets: Array = []
    for nest in nests:
        if is_instance_valid(nest) and nest.alive:
            targets.append(nest.get_target())
    return targets


func get_target_by_id(id: int) -> Dictionary:
    var enemy = blocks.by_id.get(id)
    if enemy != null:
        return enemy
    for nest in nests:
        if is_instance_valid(nest) and 100000 + int(nest.id) == id:
            return nest.get_target()
    return {}


func _reward_block(max_hp: int) -> void:
    coins += maxi(1, int(floor(max_hp * 0.35)))


func on_nest_destroyed(nest: Node) -> void:
    nests.erase(nest)
    Events.set_nest_count(nests.size())
    arena.map_loader.release_reserved(nest.cell)
    coins += int(nest.reward)
    effects.emit_hit(nest.global_position, Palette.ACCENT, true)
    check_outcome()


func damage_base(amount: float) -> void:
    if base_core != null and base_core.alive:
        Sfx.play("base_hit")
        base_core.take_damage(amount)


func on_base_destroyed() -> void:
    outcome = "lost"
    _show_result()


func check_outcome() -> void:
    if outcome != "playing" or preparing:
        return
    if nests.is_empty() and blocks.blocks.is_empty():
        outcome = "won"
        _show_result()


func _show_result() -> void:
    Sfx.play("victory" if outcome == "won" else "defeat")
    cancel_placement()
    clear_selection()

    get_tree().paused = true


# ---------------------------------------------------------------- 道具布置

func can_use_shop_item(item_id: String) -> bool:
    return not tutorial_mode or (tutorial != null and tutorial.can_deploy(item_id))


func can_use_shop_category(category: String) -> bool:
    return not tutorial_mode or (tutorial != null and tutorial.can_open_category(category))


func is_item_unlocked(item_id: String) -> bool:
    return ItemDefs.get_research_cost(item_id) <= 0 or bool(Events.unlocked_items.get(item_id, false))


func research_item(item_id: String) -> bool:
    if tutorial_mode:
        return false
    if is_item_unlocked(item_id):
        return true
    var cost := ItemDefs.get_research_cost(item_id)
    if coins < cost:
        Events.toast(I18n.t("shop.not_enough"), Palette.DANGER)
        return false
    coins -= cost
    Events.set_item_unlocked(item_id, true)
    Sfx.play("upgrade")
    Events.toast(I18n.t("shop.researched", [I18n.t(ItemDefs.get_item(item_id).name_key)]), Palette.ACCENT)
    return true


func _on_shop_drag_started(item_id: String) -> void:
    begin_placement(item_id)


func _on_shop_drag_moved(pos: Vector2) -> void:
    if shop_bar.is_ui_position(pos):
        _set_drag_preview_hidden(true)
        return
    _set_drag_preview_hidden(false)
    update_placement(screen_to_world(pos))


func _set_drag_preview_hidden(hidden: bool) -> void:
    placement_ghost.visible = not hidden
    highlights.set_preview_visible(not hidden)


func _on_shop_drag_released(item_id: String, pos: Vector2) -> void:
    finish_placement(item_id, screen_to_world(pos))


func begin_placement(item_id: String) -> void:
    if outcome != "playing":
        return
    if not can_use_shop_item(item_id):
        if tutorial_mode:
            Events.toast(I18n.t("tutorial.follow_step"), Palette.ACCENT)
        return
    var item: Dictionary = ItemDefs.get_item(item_id)
    if item.is_empty():
        return
    if not is_item_unlocked(item_id):
        Events.toast(I18n.t("shop.research_required"), Palette.DANGER)
        return
    if coins < int(item.cost):
        Sfx.play("invalid")
        Events.toast(I18n.t("shop.not_enough"), Palette.DANGER)
        return
    cancel_orientation()
    clear_selection()
    _set_drag_preview_hidden(false)
    _set_deploy_focus(true)
    placing = true
    placing_id = item_id
    Events.set_placement(true, item_id)
    placing_cost = int(item.cost)
    placement_ghost.begin(item)
    highlights.clear_range()
    update_placement(screen_to_world(get_viewport().get_mouse_position()))


func update_placement(pos: Vector2) -> void:
    if not placing:
        return
    var snapped := snap_to_grid(pos)
    var valid := is_valid_placement(snapped) and coins >= placing_cost
    placement_ghost.update_preview(snapped, valid)
    var hover_cell: Vector2i = arena.map_loader.world_to_cell(snapped)
    highlights.show_placement(arena.map_loader.get_buildable_cells(), hover_cell, valid)
    var item: Dictionary = ItemDefs.get_item(placing_id)
    if String(item.get("category", "")) == ItemDefs.CATEGORY_FIREPOWER:
        highlights.set_range_cells(get_range_cells(snapped, float(item.get("range", 0.0))))
    else:
        highlights.set_range_cells(get_aura_cells(item, snapped))


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
        Sfx.play("invalid")
        Events.toast(I18n.t("shop.not_enough"), Palette.DANGER)
    else:
        Sfx.play("invalid")
        Events.toast(I18n.t("shop.invalid"), Palette.DANGER)
    Events.set_placement(false)
    _set_deploy_focus(false)
    placement_ghost.end()
    highlights.clear_all()


func cancel_placement() -> void:
    _set_drag_preview_hidden(false)
    Events.set_placement(false)
    placing = false
    placing_id = ""
    placing_cost = 0
    _set_deploy_focus(false)
    cancel_orientation()
    if placement_ghost != null:
        placement_ghost.end()
    if highlights != null:
        highlights.clear_all()
    if shop_bar != null:
        shop_bar.cancel_drag()


func cancel_orientation() -> void:
    orienting = false
    orient_dragging = false
    orient_item = {}
    orient_pos = Vector2.ZERO
    if placement_ghost != null:
        placement_ghost.end()
    if highlights != null:
        highlights.clear_all()


func _set_deploy_focus(active: bool) -> void:
    Engine.time_scale = DEPLOY_TIME_SCALE if active else 1.0
    if dim_rect != null:
        dim_rect.visible = active


func _needs_direction(item: Dictionary) -> bool:
    # 只有直线光环需要朝向；圆形和全局光环直接部署。
    for aura in item.get("auras", []):
        if String(aura.get("shape", "")) == "line":
            return true
    return false


func _begin_orientation(item: Dictionary, pos: Vector2) -> void:
    orienting = true
    orient_dragging = false
    orient_item = item
    orient_pos = pos
    orient_facing = -PI / 2.0
    placement_ghost.begin_orientation(pos, item, orient_facing, _visible_world_rect())
    highlights.clear_placement()
    if String(item.get("category", "")) == ItemDefs.CATEGORY_FIREPOWER:
        highlights.set_range_cells(get_range_cells(pos, float(item.get("range", 0.0))))
    elif _needs_direction(item):
        highlights.set_range_cells(get_line_cells(pos, Vector2.from_angle(orient_facing)))
    else:
        highlights.set_range_cells([])


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
        highlights.set_range_cells(get_line_cells(orient_pos, Vector2.from_angle(orient_facing)))


func _confirm_orientation() -> void:
    var item := orient_item
    var pos := orient_pos
    var facing := orient_facing
    var cost := int(item.get("cost", 0))
    if coins < cost:
        Events.toast(I18n.t("shop.not_enough"), Palette.DANGER)
        _set_deploy_focus(false)
        cancel_orientation()
        return
    coins -= cost
    orienting = false
    orient_dragging = false
    orient_item = {}
    orient_pos = Vector2.ZERO
    Events.set_placement(false)
    _set_deploy_focus(false)
    placement_ghost.end()
    highlights.clear_all()
    _place_building(item, pos, facing)


func snap_to_grid(pos: Vector2) -> Vector2:
    return arena.map_loader.cell_to_world(arena.map_loader.world_to_cell(pos))


func get_range_cells(center: Vector2, radius: float) -> Array:
    var cells: Array = []
    var center_cell: Vector2i = arena.map_loader.world_to_cell(center)
    var steps := ceili(radius / 64.0) + 1
    for y in range(-steps, steps + 1):
        for x in range(-steps, steps + 1):
            var cell := center_cell + Vector2i(x, y)
            if arena.map_loader.cell_to_world(cell).distance_to(center) <= radius:
                cells.append(cell)
    return cells


func get_aura_cells(item: Dictionary, center: Vector2) -> Array:
    var cells: Array = []
    var seen: Dictionary = {}
    for aura in item.get("auras", []):
        var aura_cells: Array = []
        var shape := String(aura.get("shape", "none"))
        if shape == "circle":
            aura_cells = get_range_cells(center, float(aura.get("radius", 0.0)))
        elif shape == "line":
            aura_cells = get_line_cells(center, Vector2.from_angle(float(item.get("facing", -PI / 2.0))))
        for cell in aura_cells:
            if not seen.has(cell):
                seen[cell] = true
                cells.append(cell)
    return cells


func _get_connected_aura_cells(building: Node) -> Array:
    var cells: Array = []
    var seen: Dictionary = {}
    # 本塔重叠格由青色层负责，橙色只表示其他网络成员新增的范围。
    for cell in get_aura_cells({"auras": building.auras, "facing": building.facing_angle}, building.global_position):
        seen[cell] = true
    if buff_system == null:
        return cells
    for other in buff_system.get_connected_buildings(building):
        for cell in get_aura_cells({"auras": other.auras, "facing": other.facing_angle}, other.global_position):
            if not seen.has(cell):
                seen[cell] = true
                cells.append(cell)
    return cells


func get_line_cells(center: Vector2, direction: Vector2) -> Array:
    var cells: Array = []
    var center_cell: Vector2i = arena.map_loader.world_to_cell(center)
    var steps := ceili(LINE_RANGE / 64.0) + 1
    for y in range(-steps, steps + 1):
        for x in range(-steps, steps + 1):
            var cell := center_cell + Vector2i(x, y)
            var offset: Vector2 = arena.map_loader.cell_to_world(cell) - center
            if absf(offset.cross(direction)) <= 34.0 and absf(offset.dot(direction)) <= LINE_RANGE:
                cells.append(cell)
    return cells


func is_valid_placement(pos: Vector2) -> bool:
    var cell: Vector2i = arena.map_loader.world_to_cell(pos)
    if tutorial_mode and placing and tutorial != null and not tutorial.is_cell_allowed(placing_id, cell):
        return false
    return arena.map_loader.is_buildable(cell)


func _place_building(item: Dictionary, pos: Vector2, facing := -PI / 2.0) -> Node:
    var cell: Vector2i = arena.map_loader.world_to_cell(pos)
    var building = PlacedBuilding.new()
    building.setup(self, item, facing)
    building.cell = cell
    building.position = arena.map_loader.cell_to_world(cell)
    items_layer.add_child(building)
    placed_buildings.append(building)
    arena.map_loader.set_occupied(cell, building)
    refresh_power()
    Sfx.play("place")
    if not item.get("auras", []).is_empty():
        Sfx.play("buff")
    if tutorial_mode and tutorial != null:
        tutorial.on_building_placed(building)
    return building


func _handle_world_click(pos: Vector2) -> void:
    if placing:
        return
    if focus_panel != null and focus_panel.visible and focus_panel.get_global_rect().has_point(pos):
        return
    var best: Node = null
    var best_distance := 46.0
    for building in placed_buildings:
        if not is_instance_valid(building):
            continue
        var distance := pos.distance_to(building.global_position)
        if distance <= best_distance:
            best = building
            best_distance = distance
    if best != null:
        select_building(best)
    else:
        clear_selection()


func select_building(t: Node) -> void:
    if t == null or not is_instance_valid(t):
        return
    selected_building = t
    for other in placed_buildings:
        if is_instance_valid(other):
            other.selected = (other == t)
    if t.is_firepower():
        highlights.set_range_cells(get_range_cells(t.global_position, t.attack_range))
    else:
        var own_cells := get_aura_cells({"auras": t.auras, "facing": t.facing_angle}, t.global_position)
        highlights.set_aura_ranges(own_cells, _get_connected_aura_cells(t))
    Events.select_building(t)


func clear_selection() -> void:
    if selected_building != null and is_instance_valid(selected_building):
        selected_building.selected = false
    selected_building = null
    if highlights != null:
        highlights.clear_range()
    if focus_panel != null:
        Events.select_building(null)


func upgrade_selected() -> void:
    var building = selected_building
    if building == null or not is_instance_valid(building):
        return
    var cost := int(building.get_upgrade_cost())
    if cost < 0:
        return
    if coins < cost:
        Events.toast(I18n.t("shop.not_enough"), Palette.DANGER)
        return
    coins -= cost
    building.apply_upgrade(cost)
    Sfx.play("upgrade")
    refresh_power()
    if building.is_firepower():
        highlights.set_range_cells(get_range_cells(building.global_position, building.attack_range))


func dismantle_selected() -> void:
    var t = selected_building
    if t == null or not is_instance_valid(t):
        clear_selection()
        return
    coins += int(t.get_refund())
    placed_buildings.erase(t)
    arena.map_loader.clear_occupied(t.cell)
    t.alive = false
    t.queue_free()
    clear_selection()
    refresh_power()


# ---------------------------------------------------------------- 建筑与战斗支持

func refresh_power() -> void:
    var supply := 0
    for b in placed_buildings:
        if is_instance_valid(b) and bool(b.alive):
            supply += int(b.energy_output)
    var remaining := supply
    var demand := 0
    var offline := 0
    for b in placed_buildings:
        if not is_instance_valid(b) or not bool(b.alive):
            continue
        demand += int(b.energy_demand)
        if b.is_power_generator():
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
    Events.set_power(demand, supply, offline)
    _rebuild_building_index()
    recompute_buffs()
    refresh_wall_connections()
    if is_instance_valid(selected_building):
        Events.update_building(selected_building)


func refresh_wall_connections() -> void:
    for building in placed_buildings:
        if is_instance_valid(building) and building.item_id == "sandbag":
            building.update_wall_connections()


func get_wall_connection_mask(target: Node) -> int:
    var mask := 0
    for other in placed_buildings:
        if other == target or not is_instance_valid(other) or not other.alive or other.item_id != "sandbag":
            continue
        var delta: Vector2i = other.cell - target.cell
        if delta == Vector2i.UP:
            mask |= 1
        elif delta == Vector2i.RIGHT:
            mask |= 2
        elif delta == Vector2i.DOWN:
            mask |= 4
        elif delta == Vector2i.LEFT:
            mask |= 8
    return mask


func recompute_buffs() -> void:
    if buff_system != null:
        buff_system.recompute()


## 坐标查询保留给部署和测试；场上塔使用重算后的有效属性缓存。
func get_buff_multiplier(point: Vector2) -> float:
    if buff_system == null:
        return 1.0
    return buff_system.get_multiplier_at(point)


func is_building_buffed(point: Vector2) -> bool:
    return get_buff_multiplier(point) > 1


func _rebuild_building_index() -> void:
    _buildings_by_cell.clear()
    for b in placed_buildings:
        if not is_instance_valid(b) or not bool(b.alive):
            continue
        var cell: Vector2i = arena.map_loader.world_to_cell(b.global_position)
        if not _buildings_by_cell.has(cell):
            _buildings_by_cell[cell] = []
        _buildings_by_cell[cell].append(b)


func get_blocking_building(rect: Rect2) -> Node:
    var best: Node = null
    var best_distance := INF
    var query_rect := rect.grow(30.0)
    var minimum: Vector2i = arena.map_loader.world_to_cell(query_rect.position)
    var maximum: Vector2i = arena.map_loader.world_to_cell(query_rect.end - Vector2.ONE * 0.001)
    for x in range(minimum.x, maximum.x + 1):
        for y in range(minimum.y, maximum.y + 1):
            for b in _buildings_by_cell.get(Vector2i(x, y), []):
                if not is_instance_valid(b) or not bool(b.alive):
                    continue
                var contact: float = Blocks.ENEMY_CONTACT_RADIUS + b.get_contact_radius()
                if b.global_position.distance_squared_to(rect.get_center()) > contact * contact:
                    continue
                var distance: float = b.global_position.distance_squared_to(rect.get_center())
                if distance < best_distance:
                    best = b
                    best_distance = distance
    return best


func on_building_destroyed(building: Node) -> void:
    Sfx.play("destroy")
    placed_buildings.erase(building)
    arena.map_loader.clear_occupied(building.cell)
    if selected_building == building:
        clear_selection()
    refresh_power()
    if hud != null:
        Events.toast(I18n.t("building.destroyed"), Palette.DANGER)


func has_firepower(exclude: Node = null) -> bool:
    for b in placed_buildings:
        if b == exclude or not is_instance_valid(b):
            continue
        if bool(b.alive) and b.is_firepower():
            return true
    return false


func get_lightning_chain(first_target: Dictionary, maximum: int = 4, radius: float = 64.0) -> Array:
    var chain: Array = []
    var used := {}
    var current := first_target
    for index in maxi(1, maximum):
        if current.is_empty() or not bool(current.get("alive", false)):
            break
        var id := int(current.get("id", -1))
        if used.has(id):
            break
        used[id] = true
        chain.append(current)
        var center: Vector2 = current.rect.get_center()
        var nearby: Array = blocks.query_rect(Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0))
        var next: Dictionary = {}
        var nearest := INF
        for candidate in nearby:
            var candidate_id := int(candidate.get("id", -1))
            if used.has(candidate_id) or not bool(candidate.get("alive", false)):
                continue
            var distance := center.distance_to(candidate.rect.get_center())
            if distance <= radius and distance < nearest:
                nearest = distance
                next = candidate
        if next.is_empty():
            break
        current = next
    return chain


func fire_item_ball(source: Node, pos: Vector2, dir: Vector2, dmg: int, pierce: int, bounces: int, speed: float, radius: float, electric: bool = false) -> void:
    Sfx.play("heavy_shot" if String(source.item_id) == "heavy_turret" else "shoot")
    var ball = Ball.new()
    ball.setup(self, pos, dir, speed, radius, dmg, pierce, bounces, electric)
    balls_layer.add_child(ball)


# ---------------------------------------------------------------- 存档序列化与恢复

func _on_save_requested() -> void:
    if SaveManager.save_game(self):
        Events.toast(I18n.t("settings.save_success"), Palette.ACCENT)
    else:
        Events.toast(SaveManager.last_error, Palette.DANGER)


func _restore_pending_save() -> void:
    SaveManager.load_requested = false
    var data := SaveManager.read_save()
    if data.is_empty() or not restore_save(data):
        Events.toast(I18n.t("settings.load_failed"), Palette.DANGER)
        return
    Events.toast(I18n.t("settings.load_success"), Palette.ACCENT)


func get_save_data() -> Dictionary:
    var buildings: Array = []
    for building in placed_buildings:
        if not is_instance_valid(building) or not building.alive:
            continue
        buildings.append({
            "item_id": String(building.item_id),
            "cell": [int(building.cell.x), int(building.cell.y)],
            "level": int(building.level),
            "invested": int(building.invested),
            "hp": float(building.hp),
            "shots": int(building.shots),
            "facing": float(building.facing_angle),
            "coin_timer": float(building._coin_timer),
        })
    var nest_data: Array = []
    for nest in nests:
        if is_instance_valid(nest) and nest.alive:
            nest_data.append({"id": int(nest.id), "cell": [int(nest.cell.x), int(nest.cell.y)], "hp": float(nest.hp), "spawn_timer": float(nest.spawn_timer)})
    var enemies: Array = []
    for enemy in blocks.blocks:
        if bool(enemy.get("alive", false)):
            enemies.append({
                "kind": String(enemy.kind),
                "position": [float(enemy.rect.get_center().x), float(enemy.rect.get_center().y)],
                "hp": int(enemy.hp),
                "max_hp": int(enemy.max_hp),
                "speed_scale": float(enemy.speed_scale),
            })
    return {
        "game": {
            "map_id": arena.map_loader.map_id,
            "map_revision": int(arena.map_loader.revision),
            "coins": int(coins),
            "elapsed": float(elapsed),
            "preparing": preparing,
            "prep_timer": float(prep_timer),
            "base_hp": float(base_core.hp),
            "destroyed": int(blocks.destroyed),
            "unlocked": Events.unlocked_items.keys(),
            "camera": [float(camera_center.x), float(camera_center.y)],
            "zoom": float(camera_zoom),
            "buildings": buildings,
            "nests": nest_data,
            "enemies": enemies,
        },
    }


func restore_save(data: Dictionary) -> bool:
    var game: Dictionary = data.get("game", {})
    if game.is_empty() or String(game.get("map_id", "")) != arena.map_loader.map_id:
        return false
    get_tree().paused = false
    cancel_placement()
    clear_selection()
    for building in placed_buildings:
        if is_instance_valid(building):
            arena.map_loader.clear_occupied(building.cell)
            building.queue_free()
    placed_buildings.clear()
    for nest in nests:
        if is_instance_valid(nest):
            arena.map_loader.release_reserved(nest.cell)
            nest.queue_free()
    nests.clear()
    blocks.clear_enemies()

    var definitions := {}
    for definition in arena.map_loader.get_nest_definitions():
        definitions[int(definition.id)] = definition
    for saved_nest in game.get("nests", []):
        var id := int(saved_nest.get("id", -1))
        if not definitions.has(id):
            continue
        var nest = Nest.new()
        nest.name = "Nest%d" % id
        nest.setup(self, definitions[id])
        var saved_cell: Array = saved_nest.get("cell", [])
        if saved_cell.size() == 2:
            nest.cell = Vector2i(int(saved_cell[0]), int(saved_cell[1]))
        elif arena.map_loader.map_id == "industrial_01" and int(game.get("map_revision", 1)) < 2 and LEGACY_INDUSTRIAL_CELLS.has(id):
            nest.cell = LEGACY_INDUSTRIAL_CELLS[id]
        nest.position = arena.map_loader.cell_to_world(nest.cell)
        arena.map_loader.reserve_cell(nest.cell)
        nest.hp = clampf(float(saved_nest.get("hp", nest.max_hp)), 1.0, float(nest.max_hp))
        nest.spawn_timer = float(saved_nest.get("spawn_timer", nest.spawn_interval))
        add_child(nest)
        nests.append(nest)

    for saved_building in game.get("buildings", []):
        var item := ItemDefs.get_item(String(saved_building.get("item_id", "")))
        if item.is_empty():
            continue
        var cell_data: Array = saved_building.get("cell", [0, 0])
        var cell := Vector2i(int(cell_data[0]), int(cell_data[1]))
        var building = _place_building(item, arena.map_loader.cell_to_world(cell), float(saved_building.get("facing", -PI / 2.0)))
        var saved_level := int(saved_building.get("level", 1))
        while building.level < saved_level:
            if not building.apply_upgrade(0):
                break
        building.invested = int(saved_building.get("invested", building.invested))
        building.hp = clampf(float(saved_building.get("hp", building.max_hp)), 1.0, float(building.max_hp))
        building.shots = int(saved_building.get("shots", 0))
        building._coin_timer = float(saved_building.get("coin_timer", building.coin_interval))

    for saved_enemy in game.get("enemies", []):
        var position_data: Array = saved_enemy.get("position", [0.0, 0.0])
        var position := Vector2(float(position_data[0]), float(position_data[1]))
        var enemy: Dictionary = blocks.spawn_enemy(position, String(saved_enemy.get("kind", "normal")))
        if enemy.is_empty():
            continue
        enemy.max_hp = maxi(1, int(saved_enemy.get("max_hp", enemy.max_hp)))
        enemy.hp = clampi(int(saved_enemy.get("hp", enemy.max_hp)), 1, int(enemy.max_hp))
        enemy.speed_scale = float(saved_enemy.get("speed_scale", enemy.speed_scale))

    Events.unlocked_items.clear()
    for item_id in game.get("unlocked", []):
        Events.set_item_unlocked(String(item_id), true)
    preparing = bool(game.get("preparing", false))
    prep_timer = float(game.get("prep_timer", 0.0))
    elapsed = float(game.get("elapsed", 0.0))
    coins = int(game.get("coins", 150))
    base_core.hp = clampf(float(game.get("base_hp", base_core.max_hp)), 1.0, float(base_core.max_hp))
    base_core.alive = true
    blocks.destroyed = int(game.get("destroyed", blocks.destroyed))
    Events.set_base_health(base_core.hp, base_core.max_hp)
    Events.set_nest_count(nests.size())
    Events.set_destroyed(blocks.destroyed)
    var camera_data: Array = game.get("camera", [0.0, 0.0])
    camera_center = Vector2(float(camera_data[0]), float(camera_data[1]))
    camera_zoom = float(game.get("zoom", _base_zoom))
    refresh_power()
    _layout()
    _autosave_timer = 15.0
    return true
