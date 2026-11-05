extends Node

## 无限地图、基地防守、巢穴、建筑、能源与 i18n 冒烟测试。

const ItemDefs = preload("res://scripts/item_defs.gd")

var main: Node
var failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	_create_main()
	await _frames(3)

	# ---------------------------------------------------------------- 初始状态与无限地图
	_check(main.blocks.blocks.is_empty(), "no enemies during preparation")
	_check(main.preparing and float(main.prep_timer) > 4.5, "five second preparation")
	_check(int(main.coins) == 150, "starting coins")
	_check(main.base_core.max_hp == 1000 and main.base_core.hp == 1000.0, "base starts intact")
	_check(main.base_core.global_position == Vector2.ZERO, "base is the world origin")
	_check(main.nests.size() == 4, "JSON nests are instantiated")
	_check(main.arena.map_loader.map_id == "industrial_01", "version two JSON map loads")
	_check(main.arena.map_loader.cell_size == Vector2i(64, 64), "64 pixel cells")
	_check(main.arena.map_loader.ground_layer.tile_set != null, "infinite ground uses TileMapLayer")
	_check(not main.arena.map_loader.get_visible_cells().is_empty(), "only visible ground is generated")
	for cell in [Vector2i(100, -100), Vector2i(-10000, 8000), Vector2i.ZERO]:
		var point: Vector2 = main.arena.map_loader.cell_to_world(cell)
		_check(main.arena.map_loader.world_to_cell(point) == cell, "sparse coordinate round trip %s" % str(cell))
	_check(main.is_valid_placement(Vector2(6400, -6400)), "distant ground is buildable")
	for y in range(-1, 2):
		for x in range(-1, 2):
			_check(not main.arena.map_loader.is_buildable(Vector2i(x, y)), "base footprint is reserved")
	var first_nest: Node = main.nests[0]
	_check(not main.arena.map_loader.is_buildable(first_nest.cell), "nest cell is reserved")
	main.arena.map_loader.update_view(Vector2(6400, -6400), Vector2(640, 640))
	_check(main.arena.map_loader.is_cell_visible(Vector2i(100, -100)), "camera loads distant ground on demand")
	main.center_on_base()

	# ---------------------------------------------------------------- i18n 与道具
	_check(I18n.locale == "zh_CN", "default locale")
	_check(I18n.t("hud.mode") == "基地防线", "defense HUD translation")
	_check(I18n.missing_keys("en").is_empty(), "English keys complete")
	I18n.set_locale("en")
	_check(I18n.t("hud.mode") == "BASE DEFENSE", "English HUD")
	I18n.set_locale("zh_CN")
	_check(Sfx.stream_count() == 13, "all thirteen sound effects load")
	var hit_plays := Sfx.get_play_count("hit")
	_check(Sfx.play("hit"), "sound effect plays through the shared pool")
	_check(Sfx.get_play_count("hit") == hit_plays + 1, "accepted sound is counted")
	_check(not Sfx.play("hit"), "immediate duplicate hit is rate limited")
	GameSettings.set_option("sound_enabled", false)
	_check(not Sfx.play("destroy"), "disabled sound setting blocks playback")
	GameSettings.set_option("sound_enabled", true)
	_check(main.settings_panel.option_buttons.has("sound_enabled"), "settings expose the sound toggle")
	_check(Music.stream_count() == 2, "both looping music tracks load")
	_check(Music.loops_enabled(), "music tracks have forward loops and explicit end frames")
	_check(Music.current_track() == "battle", "game scene selects battle music")
	Music.play_track("menu")
	_check(Music.current_track() == "menu", "music manager switches to menu track")
	Music.play_track("battle")
	GameSettings.set_option("music_enabled", false)
	_check(not GameSettings.music_enabled, "music setting disables independently")
	GameSettings.set_option("music_enabled", true)
	_check(main.settings_panel.option_buttons.has("music_enabled"), "settings expose the music toggle")
	_check(ItemDefs.get_category_items(ItemDefs.CATEGORY_FIREPOWER).size() == 3, "firepower items")
	_check(ItemDefs.get_category_items(ItemDefs.CATEGORY_FORTIFICATION).size() == 2, "fortification items")
	_check(ItemDefs.get_category_items(ItemDefs.CATEGORY_ENERGY).size() == 2, "energy items")
	_check(int(ItemDefs.get_item("turret").cost) + int(ItemDefs.get_item("solar").cost) == 50, "starting build remains affordable")
	_check(main.hud.base_button != null, "return to base button exists")

	# ---------------------------------------------------------------- 商店与放置
	main.shop_bar._on_category_pressed("fortification", Vector2(100, 100))
	_check(main.shop_bar.chips.size() == 2, "category switches item list")
	main.shop_bar._on_item_chip_pressed("compression_tower")
	main.shop_bar.cancel_drag()
	main.shop_bar._on_category_pressed("firepower", Vector2(100, 100))
	main.shop_bar.cancel_drag()
	main.begin_placement("solar")
	_check(Engine.time_scale < 0.5 and main.dim_rect.visible, "deployment focus active")
	main.cancel_placement()
	_check(is_equal_approx(Engine.time_scale, 1.0) and not main.dim_rect.visible, "deployment cancel restores")

	main.begin_placement("sandbag")
	main.finish_placement("sandbag", _world(-3, 3))
	_check(main.placed_buildings.size() == 1, "sandbag placement")
	var refund_building: Node = main.placed_buildings[0]
	_check(int(refund_building.get_refund()) == 15, "full refund without firepower")
	main.select_building(refund_building)
	main.dismantle_selected()
	_check(main.placed_buildings.is_empty() and main.coins == 150, "dismantle releases building and coins")
	_check(main.arena.map_loader.is_buildable(Vector2i(-3, 3)), "dismantle releases cell")

	main.coins = 100
	main.begin_placement("compression_tower")
	main.update_placement(_world(3, 3))
	_check(not main.highlights.range_cells.is_empty(), "compression shows two-cell aura preview")
	main.finish_placement("compression_tower", _world(3, 3))
	_check(not main.orienting, "compression places directly without orientation")
	_check(main.highlights.range_cells.is_empty(), "placement confirms and hides aura range")
	main.select_building(main.placed_buildings[0])
	main.dismantle_selected()
	main.coins = 50

	main.begin_placement("turret")
	main.update_placement(_world(-3, 0))
	_check(not main.highlights.placement_cells.is_empty(), "visible buildable cells highlight")
	_check(main.highlights.hover_valid, "empty hover is valid")
	main.finish_placement("turret", _world(-3, 0))
	var turret: Node = main.placed_buildings[0]
	_check(turret.cell == Vector2i(-3, 0), "turret snaps to sparse cell")
	_check(main.coins == 20, "turret cost")
	_check(main.arena.map_loader.get_occupied_building(turret.cell) == turret, "building occupies cell")
	_check(not turret.powered, "turret needs power")
	_place("solar", Vector2i(-3, 2))
	_check(turret.powered and main.power_supply == 2, "solar powers turret")
	main.begin_placement("solar")
	main.update_placement(turret.global_position)
	_check(not main.highlights.hover_valid, "occupied hover is invalid")
	main.finish_placement("solar", turret.global_position)
	_check(main.placed_buildings.size() == 2, "occupied placement rejected")
	main.cancel_placement()
	main.coins = 500
	main.begin_placement("solar")
	main.finish_placement("solar", Vector2.ZERO)
	_check(main.placed_buildings.size() == 2 and main.coins == 500, "base placement rejected without charge")
	main.begin_placement("solar")
	main.finish_placement("solar", first_nest.global_position)
	_check(main.placed_buildings.size() == 2, "nest placement rejected")
	main.cancel_placement()

	# ---------------------------------------------------------------- 巢穴索敌与炮弹
	await _frames(2)
	_check(int(turret.shots) == 0, "turrets do not fire during preparation")
	var target: Dictionary = main.blocks.get_nearest_target(turret.global_position, turret.attack_range, main.get_range_cells(turret.global_position, turret.attack_range))
	_check(String(target.get("target_type", "")) == "nest", "turret can target a nest")
	_check(target.get("node") == first_nest, "nearest nest selected")
	var nest_hp := float(first_nest.hp)
	main.hit_nest(first_nest, 10, first_nest.global_position, false)
	_check(first_nest.hp == nest_hp - 10.0, "nest takes damage")
	_place("fusion_tower", Vector2i(-4, -2))
	var laser: Node = _place("laser_tower", Vector2i(-4, -3))
	main.refresh_power()
	_check(laser.powered, "fusion powers laser")
	nest_hp = float(first_nest.hp)
	laser._fire_laser(first_nest.get_target())
	_check(first_nest.hp == nest_hp - 5.0, "laser damages nest")
	var coins_before_nest := int(main.coins)
	main.fire_item_ball(turret, first_nest.global_position + Vector2(-110, 0), Vector2.RIGHT, 999, 0, 0, 620.0, 7.0)
	var ball: Node = main.balls_layer.get_child(0)
	ball._physics_process(0.3)
	_check(not main.nests.has(first_nest), "projectile destroys nest")
	_check(main.coins > coins_before_nest, "destroyed nest grants reward")
	_check(main.arena.map_loader.is_buildable(first_nest.cell), "destroyed nest releases cell")
	_check(first_nest.spawn_timer > 0.0 or not is_instance_valid(first_nest), "destroyed nest cannot spawn")

	# ---------------------------------------------------------------- 巢穴生成与基地导向移动
	for building in main.placed_buildings:
		building._cooldown = 9999.0
	main._end_prep()
	var spawning_nest: Node = main.nests[0]
	spawning_nest.spawn_timer = 0.0
	spawning_nest._process(0.02)
	_check(main.blocks.blocks.size() == 1, "nest spawns an enemy")
	var enemy: Dictionary = main.blocks.blocks[0]
	var before_distance: float = enemy.rect.get_center().distance_to(main.base_core.global_position)
	main.blocks._physics_process(0.5)
	_check(enemy.rect.get_center().distance_to(main.base_core.global_position) < before_distance, "enemy moves toward base")
	var spawn_count: int = main.blocks.blocks.size()
	spawning_nest.spawn_timer = 0.01
	spawning_nest._process(0.02)
	_check(main.blocks.blocks.size() == spawn_count + 1, "each nest spawns independently")
	main.hit_block(int(enemy.id), 1)
	_check(float(enemy.hp_bar_time) > 0.0, "enemy health bar appears")
	main.blocks._process(3.2)
	_check(float(enemy.hp_bar_time) == 0.0, "enemy health bar expires")
	var destroyed_before := int(main.blocks.destroyed)
	main.hit_block(int(enemy.id), 999)
	_check(main.blocks.destroyed == destroyed_before + 1, "enemy destruction counted")

	# ---------------------------------------------------------------- 阵地拦截
	main.blocks.clear_enemies()
	_clear_buildings()
	main.coins = 2000
	_place("fusion_tower", Vector2i(3, 0))
	var sandbag: Node = _place("sandbag", Vector2i(0, -3))
	var attacker: Dictionary = main.blocks.spawn_enemy(Vector2(0, -238), "normal")
	for i in 8:
		main.blocks._physics_process(0.1)
	_check(attacker.get("blocked_by") == sandbag, "sandbag intercepts base-bound enemy")
	var diagonal: Dictionary = main.blocks.spawn_enemy(Vector2(48, -240), "normal")
	for i in 20:
		main.blocks._physics_process(0.1)
	_check(diagonal.get("blocked_by") == sandbag, "diagonal enemy is intercepted by circular contact")
	var building_contact: float = 18.0 + sandbag.get_contact_radius()
	_check(diagonal.rect.get_center().distance_to(sandbag.global_position) <= building_contact + 1.0, "diagonal contact has no rectangular-corner gap")
	var sandbag_hp := float(sandbag.hp)
	main.blocks._physics_process(0.5)
	_check(sandbag.hp < sandbag_hp, "sandbag absorbs attacks")
	sandbag.hp = 1.0
	main.blocks._physics_process(0.5)
	_check(not sandbag.alive, "fortification can be destroyed")
	_check(main.arena.map_loader.is_buildable(Vector2i(0, -3)), "destroyed fortification releases cell")
	var base_attacker: Dictionary = main.blocks.spawn_enemy(Vector2(0, -160), "normal")
	for i in 35:
		main.blocks._physics_process(0.1)
	_check(bool(base_attacker.get("attacking_base", false)), "enemy attacks base on circular contact")
	var base_contact: float = 18.0 + main.base_core.get_contact_radius()
	_check(base_attacker.rect.get_center().length() <= base_contact + 1.0, "base contact stays close to visible core")

	# ---------------------------------------------------------------- 升级、能源与增益
	_clear_buildings()
	main.blocks.clear_enemies()
	main.coins = 3000
	var upgraded: Node = _place("turret", Vector2i(-4, 0))
	_place("fusion_tower", Vector2i(-4, 2))
	var heavy: Node = _place("heavy_turret", Vector2i(4, 0))
	var upgraded_laser: Node = _place("laser_tower", Vector2i(4, 2))
	_place("fusion_tower", Vector2i(4, -2))
	main.refresh_power()
	_check(main.power_ok, "energy covers advanced buildings")
	main.select_building(upgraded)
	main.upgrade_selected()
	_check(upgraded.level == 2 and upgraded.damage == 6, "turret upgrade")
	_check(upgraded.energy_demand == 2, "upgrade raises power demand")
	main.clear_selection()
	_check(heavy.item_id == "heavy_turret" and upgraded_laser.attack_style == "laser", "advanced building definitions")
	var buffed: Node = _place("turret", Vector2i(0, 6))
	var compression: Node = _place("compression_tower", Vector2i(0, 4), -PI / 2.0)
	_place("solar", Vector2i(-2, 4))
	main.refresh_power()
	_check(compression.covers_point(buffed.global_position), "compression covers a target two cells away")
	_check(not compression.covers_point(_world(0, 7)), "compression excludes targets three cells away")
	_check(main.get_buff_multiplier(buffed.global_position) == 2, "compression buff applies")
	var initial_link: Dictionary = _find_link(compression, buffed)
	_check(not initial_link.is_empty(), "active aura creates an energy link")
	if not initial_link.is_empty():
		var link_direction: Vector2 = initial_link.end - initial_link.start
		var target_direction: Vector2 = buffed.global_position - compression.global_position
		_check(link_direction.dot(target_direction) > 0.0, "energy link flows from source toward target")
	_check(int(buffed.get_effective_damage()) == 2, "buff cache drives effective damage")
	main.select_building(buffed)
	_check(main.focus_panel.stat_values[0].text == "1 → 2", "focus panel shows base and buffed damage")
	main.clear_selection()
	var balls_before_buff: int = main.balls_layer.get_child_count()
	buffed._fire_projectile()
	_check(main.balls_layer.get_child_count() == balls_before_buff + 1, "buffed turret fires")
	var buffed_ball: Node = main.balls_layer.get_child(main.balls_layer.get_child_count() - 1)
	_check(int(buffed_ball.damage) == 2, "projectile reads effective damage")
	buffed_ball._vanish()

	# 同组取最高，不同组叠乘；拆除后剩余光环立即重算。
	var stronger_def: Dictionary = ItemDefs.get_item("compression_tower").duplicate(true)
	stronger_def["id"] = "test_stronger_compression"
	stronger_def["energy_demand"] = 0
	stronger_def["auras"][0]["propagate"] = false
	stronger_def["auras"][0]["target_categories"] = [ItemDefs.CATEGORY_FIREPOWER]
	stronger_def["auras"][0]["target_items"] = []
	stronger_def["auras"][0]["modifiers"][0]["value"] = 3.0
	var stronger: Node = main._place_building(stronger_def, _world(0, 5), -PI / 2.0)
	_check(int(buffed.get_effective_damage()) == 3, "same aura group takes highest multiplier")
	main.select_building(stronger)
	main.dismantle_selected()
	_check(int(buffed.get_effective_damage()) == 2, "removing stronger aura restores base compression")

	var amplifier_def: Dictionary = ItemDefs.get_item("compression_tower").duplicate(true)
	amplifier_def["id"] = "test_amplifier"
	amplifier_def["energy_demand"] = 0
	amplifier_def["auras"] = [{
		"id": "test_amplifier",
		"shape": "global",
		"target_categories": [ItemDefs.CATEGORY_FIREPOWER],
		"stack_group": "test_amplifier",
		"stack_rule": "max",
		"modifiers": [{"stat": "damage", "op": "mul", "value": 3.0}],
	}]
	var amplifier: Node = main._place_building(amplifier_def, _world(1, 5))
	_check(int(buffed.get_effective_damage()) == 6, "different aura groups multiply")
	_check(int(upgraded.get_effective_damage()) == 18, "global aura applies to upgraded base damage")
	main.select_building(buffed)
	_check(main.focus_panel.stat_values[0].text == "1 → 6", "focus panel shows effective damage")
	main.clear_selection()
	main.select_building(amplifier)
	main.dismantle_selected()
	_check(int(buffed.get_effective_damage()) == 2 and int(upgraded.get_effective_damage()) == 6, "aura removal restores remaining stats")
	compression.set_powered(false)
	main.recompute_buffs()
	_check(int(buffed.get_effective_damage()) == 1, "offline aura stops affecting damage")
	_check(main.energy_links.link_count() == 0, "offline aura removes energy links")
	compression.set_powered(true)
	main.recompute_buffs()
	_check(int(buffed.get_effective_damage()) == 2, "restored power restores aura")
	_check(main.energy_links.link_count() == 1, "restored power restores the energy link")

	# 圆形可传递光环：A(0,4) → B(2,4) → C(2,2) → D(0,2) → 炮塔(-2,2)。
	# 只按建造顺序向前传递，D 验证不封顶继续到 ×16。
	var chain_def: Dictionary = ItemDefs.get_item("compression_tower").duplicate(true)
	chain_def["energy_demand"] = 0
	var chain_b: Node = main._place_building(chain_def, _world(2, 4))
	var chain_c: Node = main._place_building(chain_def, _world(2, 2))
	var chain_d: Node = main._place_building(chain_def, _world(0, 2))
	var chain_tower_def: Dictionary = ItemDefs.get_item("turret").duplicate(true)
	chain_tower_def["energy_demand"] = 0
	var chain_target: Node = main._place_building(chain_tower_def, _world(-2, 2))
	_check(is_equal_approx(compression.get_primary_aura_output_multiplier(), 2.0), "chain source keeps base multiplier")
	_check(is_equal_approx(chain_b.get_primary_aura_output_multiplier(), 4.0), "second compression propagates x4")
	_check(is_equal_approx(chain_c.get_primary_aura_output_multiplier(), 8.0), "third compression propagates x8")
	_check(is_equal_approx(chain_d.get_primary_aura_output_multiplier(), 16.0), "propagation continues without a multiplier cap")
	_check(int(chain_target.get_effective_damage()) == 16, "firepower receives uncapped propagated multiplier")
	_check(not _find_link(chain_d, chain_target).is_empty(), "propagated aura links the final compression to firepower")
	main.select_building(chain_d)
	_check(main.focus_panel.stat_values[2].text == "×16", "compression panel shows uncapped propagated output")
	_check(main.focus_panel.stat_values[4].text == "周围 2 格", "compression panel shows two-cell coverage")
	main.clear_selection()

	# 圆形范围内即使互相覆盖，也只允许旧塔向新塔传递，不产生递归。
	var cycle_source: Node = main._place_building(chain_def, _world(-6, -8))
	var cycle_a: Node = main._place_building(chain_def, _world(-6, -6))
	var cycle_b: Node = main._place_building(chain_def, _world(-4, -6))
	var cycle_target: Node = main._place_building(chain_tower_def, _world(-2, -6))
	_check(is_equal_approx(cycle_source.get_primary_aura_output_multiplier(), 2.0), "newer towers cannot amplify their older source")
	_check(is_equal_approx(cycle_a.get_primary_aura_output_multiplier(), 4.0), "older source buffs a newer tower in two cells")
	_check(is_equal_approx(cycle_b.get_primary_aura_output_multiplier(), 8.0), "mutual circular coverage still follows build order")
	_check(int(cycle_target.get_effective_damage()) == 8, "ordered circular network reaches firepower")
	for tower in [chain_b, chain_c, chain_d, chain_target, cycle_a, cycle_b, cycle_target, cycle_source]:
		main.select_building(tower)
		main.dismantle_selected()
	_check(int(buffed.get_effective_damage()) == 2, "removing propagation network restores original aura")

	# ---------------------------------------------------------------- 镜头
	var old_center: Vector2 = main.camera_center
	main._pan_camera(Vector2(80, 20))
	_check(main.camera_center != old_center, "blank drag pans camera")
	main.center_on_base()
	_check(main.camera_center == main.base_core.global_position, "home returns to base")
	var old_zoom := float(main.camera_zoom)
	main._zoom_at(Vector2(200, 400), 1.1)
	_check(main.camera_zoom > old_zoom, "zoom control changes camera")

	# ---------------------------------------------------------------- 胜利
	for nest in main.nests.duplicate():
		main.hit_nest(nest, 9999, nest.global_position, false)
	for enemy_value in main.blocks.blocks.duplicate():
		main.hit_block(int(enemy_value.id), 9999)
	main.blocks.clear_enemies()
	main.check_outcome()
	_check(main.outcome == "won", "all nests and enemies cleared wins")
	_check(main.result_panel.visible and get_tree().paused, "victory shows result panel")

	# ---------------------------------------------------------------- 独立基地失败场景
	get_tree().paused = false
	main.queue_free()
	await _frames(2)
	_create_main()
	await _frames(2)
	main.damage_base(2000.0)
	_check(main.base_core.hp == 0.0 and not main.base_core.alive, "base health reaches zero")
	_check(main.outcome == "lost", "base destruction loses the game")
	_check(main.result_panel.visible, "defeat shows restart panel")
	get_tree().paused = false

	# ---------------------------------------------------------------- 第二 JSON 与校验
	var loader: Node2D = load("res://scripts/map_loader.gd").new()
	add_child(loader)
	_check(loader.load_map("res://tools/fixtures/map_test_layout.json"), "second infinite JSON loads")
	_check(loader.get_nest_definitions().size() == 1, "second map has independent nest data")
	_check(loader.world_to_cell(Vector2(768, -896)) == Vector2i(12, -14), "second map distant nest coordinates")
	_check(not loader.load_map("res://tools/fixtures/map_invalid.json"), "overlapping nest is rejected")
	_check(not loader.load_error.is_empty(), "invalid map reports validation error")
	loader.queue_free()

	_finish()


func _create_main() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)


func _world(x: int, y: int) -> Vector2:
	return main.arena.map_loader.cell_to_world(Vector2i(x, y))


func _place(item_id: String, cell: Vector2i, facing := -PI / 2.0) -> Node:
	return main._place_building(ItemDefs.get_item(item_id), main.arena.map_loader.cell_to_world(cell), facing)


func _clear_buildings() -> void:
	if main.selected_building != null:
		main.clear_selection()
	for building in main.placed_buildings:
		if is_instance_valid(building):
			main.arena.map_loader.clear_occupied(building.cell)
			building.queue_free()
	main.placed_buildings.clear()
	main.refresh_power()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _find_link(source: Node, target: Node) -> Dictionary:
	for segment in main.energy_links.get_segments():
		if segment.source == source and segment.target == target:
			return segment
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SMOKE TEST PASS  nests=%d base_hp=%d" % [main.nests.size(), int(main.base_core.hp)])
		get_tree().quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		get_tree().quit(1)
