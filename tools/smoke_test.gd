extends Node

## 无头冒烟测试：三类建筑、能源供需与瘫痪、形态升级、沙袋拦截、压缩塔直线增益、电击弹、波次与 i18n。
## 用法：
##   Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . res://tools/smoke_test.tscn

const ItemDefs = preload("res://scripts/item_defs.gd")

var main: Node
var failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	main = packed.instantiate()
	add_child(main)
	await _frames(3)

	# ---------------------------------------------------------------- 开局
	_check(main.blocks.blocks.is_empty(), "no blocks during preparation")
	_check(main.preparing, "preparation phase active")
	_check(float(main.prep_timer) > 4.5, "preparation lasts about 5 seconds")
	_check(int(main.coins) == 50, "starts with 50 coins")
	_check(main.placed_buildings.is_empty(), "no placed building at start")
	_check(main.power_supply == 0 and main.power_demand == 0, "no power demand at start")
	_check(main.power_ok, "power is stable with no buildings")

	# ---------------------------------------------------------------- i18n
	_check(I18n.locale == "zh_CN", "default locale is Chinese")
	_check(I18n.t("hud.mode") == "无尽模式", "Chinese translation loaded")
	_check(I18n.t("category.firepower") == "火力", "category translation loaded")
	var missing := I18n.missing_keys("en")
	_check(missing.is_empty(), "en locale has all keys: %s" % str(missing))
	I18n.set_locale("en")
	_check(I18n.t("hud.mode") == "ENDLESS", "English translation loads")
	I18n.toggle_locale()
	_check(I18n.locale == "zh_CN", "locale toggles back to Chinese")

	# ---------------------------------------------------------------- 定义表
	var fire_items: Array = ItemDefs.get_category_items(ItemDefs.CATEGORY_FIREPOWER)
	var fort_items: Array = ItemDefs.get_category_items(ItemDefs.CATEGORY_FORTIFICATION)
	var energy_items: Array = ItemDefs.get_category_items(ItemDefs.CATEGORY_ENERGY)
	_check(fire_items.size() == 3, "firepower category lists turret, heavy and laser")
	_check(String(fire_items[0].id) == "turret" and String(fire_items[1].id) == "heavy_turret" and String(fire_items[2].id) == "laser_tower", "firepower item order")
	_check(fort_items.size() == 2, "fortification category lists sandbag and compression tower")
	_check(energy_items.size() == 2, "energy category lists solar and fusion tower")
	_check(int(ItemDefs.get_item("turret").cost) + int(ItemDefs.get_item("solar").cost) == 50, "starting coins cover energy plus turret")
	_check(int(ItemDefs.get_item("heavy_turret").cost) == 120, "heavy turret is a full-cost item")
	_check(int(ItemDefs.get_item("laser_tower").cost) == 150, "laser tower is a full-cost item")
	_check(int(ItemDefs.get_item("compression_tower").cost) == 60, "compression tower is a full-cost item")
	_check(int(ItemDefs.get_item("fusion_tower").cost) == 60, "fusion tower is a full-cost item")
	_check(int(ItemDefs.get_item("solar").energy_output) * 2 == int(ItemDefs.get_item("fusion_tower").energy_output), "fusion tower doubles power output")
	_check(int(ItemDefs.get_item("turret").energy_demand) == 1, "turret drains one power")
	_check(int(ItemDefs.get_item("heavy_turret").energy_demand) == 2, "heavy turret drains two power")
	_check(int(ItemDefs.get_item("laser_tower").energy_demand) == 3, "laser tower drains three power")
	_check(int(ItemDefs.get_item("sandbag").energy_demand) == 1, "sandbag drains one power")
	_check(int(ItemDefs.get_item("compression_tower").energy_demand) == 2, "compression tower drains two power")
	_check(int(ItemDefs.get_item("compression_tower").buff_multiplier) == 2, "compression tower doubles damage")
	_check(ItemDefs.get_item("compression_tower").desc_key != "", "all items have descriptions")

	# ---------------------------------------------------------------- 商店类别与道具列表
	_check(main.shop_bar.cards.size() == 3, "shop has three category cards")
	_check(main.shop_bar.chips.size() == 3, "firepower starts with three item chips")
	main.shop_bar._on_category_pressed("fortification", Vector2(100, 100))
	_check(main.shop_bar.active_category == "fortification", "clicking a category switches the item list")
	_check(main.shop_bar.chips.size() == 2, "fortification lists two items")
	main.shop_bar._on_item_chip_pressed("compression_tower")
	_check(String(main.shop_bar.selected["fortification"]) == "compression_tower", "selecting an item updates the category")
	main.shop_bar._refresh_cards()
	_check(String(main.shop_bar.cards[1].item.id) == "compression_tower", "category card adopts the selected item")
	main.shop_bar.cancel_drag()
	main.shop_bar._on_category_pressed("firepower", Vector2(100, 100))
	main.shop_bar._on_item_chip_pressed("turret")
	main.shop_bar.cancel_drag()

	# 拖拽部署时战场减速并压暗背景
	main.begin_placement("solar")
	_check(Engine.time_scale < 0.5, "deploying slows game time")
	_check(main.dim_rect.visible, "deploying dims the surrounding screen")
	main.cancel_placement()
	_check(is_equal_approx(Engine.time_scale, 1.0), "cancelled deploy restores game speed")
	_check(not main.dim_rect.visible, "cancelled deploy restores brightness")

	# 类别卡按住后移动超过阈值才开始拖拽，纯点击只切换类别
	main.shop_bar._on_category_pressed("firepower", Vector2(100, 100))
	_check(main.shop_bar._pending and not main.shop_bar._dragging, "category press waits before dragging")
	var move := InputEventMouseMotion.new()
	move.position = Vector2(120, 100)
	main.shop_bar._input(move)
	_check(main.shop_bar._dragging and main.placing, "moving past the threshold starts item drag")
	main.shop_bar.cancel_drag()
	main.cancel_placement()
	_check(not main.placing, "cancelled shop drag clears placement")

	# ---------------------------------------------------------------- 布置与能源
	# 场上没有火力时拆除全额返还，保证不会因为花光金币而无法重建
	main.begin_placement("sandbag")
	main.finish_placement("sandbag", Vector2(520, 700))
	_check(main.placed_buildings.size() == 1, "sandbag placed before firepower")
	var first_sandbag: Node = main.placed_buildings[0]
	_check(int(first_sandbag.get_refund()) == 15, "no-firepower dismantle refunds in full")
	main.select_building(first_sandbag)
	_check(main.focus_panel.visible, "static building opens the focus panel")
	main.dismantle_selected()
	_check(main.placed_buildings.is_empty(), "sandbag removed after refund check")
	_check(int(main.coins) == 50, "full refund restores the starting coins")

	main.begin_placement("turret")
	_check(main.placing, "placement begins")
	main.update_placement(Vector2(400, 400))
	main.finish_placement("turret", Vector2(400, 400))
	_check(main.orienting, "directional building enters orientation step")
	_check(not main.placing, "placement drag ends before orientation")
	_check(int(main.coins) == 50, "direction confirmation happens before payment")
	_check(is_equal_approx(main.orient_facing, -PI / 2.0), "default facing points up")
	main._update_orientation(main.orient_pos + Vector2(100, 0))
	_check(is_equal_approx(main.orient_facing, 0.0), "dragging sets the facing")
	main._confirm_orientation()
	_check(main.placed_buildings.size() == 1, "basic turret placed")
	_check(int(main.coins) == 20, "basic turret costs 30")
	var turret: Node = main.placed_buildings[0]
	_check(turret.category == ItemDefs.CATEGORY_FIREPOWER, "turret is firepower")
	_check(turret.global_position == main.snap_to_grid(Vector2(400, 400)), "placement snaps to grid")
	_check(is_equal_approx(turret.facing_angle, 0.0), "chosen facing is stored on the building")
	_check(int(turret.damage) == 1, "basic turret base damage")
	_check(int(turret.attack_range) == 300, "basic turret short range")
	_check(absf(float(turret.interval) - 0.3) < 0.001, "basic turret interval")
	_check(main.power_supply == 0 and main.power_demand == 1, "turret alone demands power")
	_check(not main.power_ok, "power deficit without an energy building")
	_check(not turret.powered, "turret is paralyzed without power")
	await _frames(2)
	_check(int(turret.shots) == 0, "paralyzed turret cannot fire")

	main.begin_placement("solar")
	main.update_placement(Vector2(250, 400))
	main.finish_placement("solar", Vector2(250, 400))
	_check(not main.orienting, "static energy building skips orientation")
	_check(main.placed_buildings.size() == 2, "solar panel placed")
	_check(int(main.coins) == 0, "solar panel costs 20")
	_check(main.power_supply == 2 and main.power_demand == 1, "solar supplies two power")
	_check(main.power_ok, "one solar powers one turret")
	_check(turret.powered, "turret is powered after solar placement")
	var solar: Node = main.placed_buildings[1]
	_check(solar.category == ItemDefs.CATEGORY_ENERGY, "solar is energy")
	_check(int(solar.energy_output) == 2, "solar outputs two")
	_check(int(turret.get_refund()) == 30, "dismantling the last firepower refunds in full")
	var behind := _add_test_block(Vector2(300, 400), 10)
	var turret_cells: Array = main.get_range_cells(turret.global_position, turret.attack_range)
	var behind_target: Dictionary = main.blocks.get_nearest_target(turret.global_position, turret.attack_range, turret_cells)
	_check(int(behind_target.get("id", -1)) == int(behind.id), "turret range is tile-based and covers behind its facing")
	main.blocks.blocks.erase(behind)
	main.blocks.by_id.erase(int(behind.id))
	main.select_building(solar)
	_check(main.focus_panel.visible, "focus panel opens for energy building")
	main.clear_selection()

	# 网格吸附边缘
	var left: Vector2 = main.snap_to_grid(Vector2(65, 400))
	var right: Vector2 = main.snap_to_grid(Vector2(655, 400))
	var top: Vector2 = main.snap_to_grid(Vector2(416, 113))
	var bottom: Vector2 = main.snap_to_grid(Vector2(416, 790))
	var corner: Vector2 = main.snap_to_grid(Vector2(660, 805))
	_check(is_equal_approx(left.x, 96.0), "left edge snaps")
	_check(is_equal_approx(right.x, 624.0), "right edge snaps")
	_check(is_equal_approx(top.y, 144.0), "top edge snaps")
	_check(is_equal_approx(bottom.y, 768.0), "bottom edge snaps")
	_check(is_equal_approx(corner.x, 624.0) and is_equal_approx(corner.y, 768.0), "frame edge clamps")
	_check(main.is_valid_placement(left), "left edge cell is placeable")
	_check(main.is_valid_placement(right), "right edge cell is placeable")
	_check(main.is_valid_placement(top), "top edge cell is placeable")
	_check(main.is_valid_placement(bottom), "bottom edge cell is placeable")

	# 金币不足 / 非法位置
	main.coins = 0
	main.begin_placement("turret")
	_check(not main.placing, "cannot place without coins")
	main.coins = 500
	main.begin_placement("turret")
	main.finish_placement("turret", Vector2(10, 10))
	_check(main.placed_buildings.size() == 2, "invalid placement rejected")
	_check(int(main.coins) == 500, "invalid placement costs nothing")

	# ---------------------------------------------------------------- 直接建造高级道具
	main.select_building(turret)
	_check(main.focus_panel.visible, "focus panel opens")
	_check(main.focus_panel.stat_values[0].text == "1", "focus panel shows base damage")
	main.clear_selection()

	var coins_before := int(main.coins)
	main.begin_placement("heavy_turret")
	main.finish_placement("heavy_turret", Vector2(380, 700))
	_check(main.orienting, "heavy turret also asks for a facing")
	main._confirm_orientation()
	_check(main.placed_buildings.size() == 3, "heavy turret placed as its own item")
	_check(int(main.coins) == coins_before - 120, "heavy turret costs 120")
	var heavy_build: Node = main.placed_buildings[2]
	_check(heavy_build.item_id == "heavy_turret", "heavy turret keeps its own definition")
	_check(int(heavy_build.damage) == 10, "heavy turret base damage")
	_check(absf(float(heavy_build.interval) - 2.0) < 0.001, "heavy turret fires slowly")
	_check(int(heavy_build.pierce) == -1, "heavy turret pierces while power remains")
	_check(int(heavy_build.attack_range) == 500, "heavy turret long range")
	_check(int(heavy_build.energy_demand) == 2, "heavy turret drains two power")
	main.select_building(heavy_build)
	_check(main.focus_panel.stat_values[3].text == "∞", "focus panel shows unlimited pierce")
	main.clear_selection()

	main.begin_placement("fusion_tower")
	main.finish_placement("fusion_tower", Vector2(620, 480))
	_check(not main.orienting, "fusion tower skips orientation")
	_check(int(main.coins) == coins_before - 180, "fusion tower costs 60 after heavy")
	var fusion: Node = main.placed_buildings[3]
	_check(fusion.item_id == "fusion_tower", "fusion tower placed directly")
	_check(int(fusion.energy_output) == 4, "fusion tower outputs four")
	_check(main.power_supply == 6 and main.power_demand == 3, "fusion tower raises supply")
	_check(main.power_ok, "fusion tower powers the heavy turret")

	# ---------------------------------------------------------------- 激光塔
	main.begin_placement("laser_tower")
	main.finish_placement("laser_tower", Vector2(560, 560))
	_check(main.orienting, "laser tower enters orientation step")
	main._confirm_orientation()
	_check(int(main.coins) == coins_before - 330, "laser tower costs 150 after heavy and fusion")
	var laser: Node = main.placed_buildings[4]
	_check(laser.item_id == "laser_tower", "laser tower placed directly")
	_check(laser.attack_style == "laser", "laser tower uses beam attack")
	_check(int(laser.energy_demand) == 3, "laser tower drains three power")
	_check(main.power_demand == 6, "laser tower raises power demand")
	_check(main.power_supply == 6 and main.power_ok, "existing energy covers the laser tower")
	main.clear_selection()

	var laser_target := _add_test_block(Vector2(560, 470), 40)
	laser.aim_angle = (laser_target.rect.get_center() - laser.global_position).angle()
	var balls_before: int = int(main.balls_layer.get_child_count())
	var hp_before := int(laser_target.hp)
	var shots_before := int(laser.shots)
	laser._fire_laser(laser_target)
	_check(int(laser_target.hp) == hp_before - 5, "laser beam damages its target directly")
	_check(int(laser.shots) == shots_before + 1, "laser shot recorded")
	_check(float(laser._beam_hold) > 0.0, "laser beam stays visible")
	_check(int(main.balls_layer.get_child_count()) == balls_before, "laser does not spawn a ball")
	main.blocks.blocks.erase(laser_target)
	main.blocks.by_id.erase(int(laser_target.id))

	# ---------------------------------------------------------------- 波次与滚动
	# 关掉现有火力的扳机，避免它们清掉用于滚动测试的方块
	for b in main.placed_buildings:
		if b.is_firepower():
			b._cooldown = 9999.0
	main._end_prep()
	await _frames(8)
	_check(not main.preparing, "preparation ends")
	_check(main.blocks.blocks.size() > 0, "block stream starts after preparation")
	for kind in ["normal", "swift", "armored", "elite"]:
		var atlas: Texture2D = main.blocks.MONSTER_ANIMATIONS[kind]
		_check(atlas.get_width() == 1024 and atlas.get_height() == 256, "%s animation atlas has four frames" % kind)
	var first: Dictionary = main.blocks.blocks[0]
	var first_rect: Rect2 = first.rect
	_check(first_rect.position.y < 112.0, "first blocks start above the visible area")
	_check(int(first.max_hp) == 3, "first wave enemies have low health")
	_check(main.blocks.blocks.size() >= 3 and main.blocks.blocks.size() <= 4, "first wave has low enemy density")
	_check(String(first.kind) == "normal", "first row uses normal enemies")
	_check(main.blocks._enemy_count_for_wave(1) == 3, "wave one spawns three enemies")
	_check(main.blocks._rows_for_wave(1) == 1, "wave one is a single row")
	_check(int(main.blocks.wave) == 1, "opening wave is wave one")
	_check(float(main.blocks.next_wave_in) > 10.0, "opening phase has a long calm window")
	_check(main.blocks._rows_for_wave(2) == 3, "wave two floods three rows")
	_check(main.blocks._rows_for_wave(2) * main.blocks._enemy_count_for_wave(2) >= 30, "wave two brings at least thirty enemies")
	_check(main.blocks._rows_for_wave(6) > main.blocks._rows_for_wave(2), "later waves add rows")
	_check(main.blocks._calm_for_wave(2) >= 24.0, "calm window leaves room to clear")
	_check(main.blocks._calm_for_wave(6) > main.blocks._calm_for_wave(2), "bigger waves get more breathing room")
	_check(main.blocks._enemy_count_for_wave(4) > main.blocks._enemy_count_for_wave(1), "later waves increase enemy count")
	_check(main.blocks._enemy_count_for_wave(9) == main.blocks.COLS, "enemy count eventually fills a row")
	_check(main.blocks._base_health_for_wave(5) > main.blocks._base_health_for_wave(1) * 2, "enemy health climbs quickly")
	_check(main.blocks._base_health_for_wave(10) > main.blocks._base_health_for_wave(5) * 2, "health growth accelerates")
	_check(main.blocks._health_for_kind("swift", 6) < main.blocks._health_for_kind("normal", 6), "swift enemies have lighter health")
	_check(main.blocks._health_for_kind("armored", 6) > main.blocks._health_for_kind("normal", 6), "armored enemies have heavier health")
	_check(main.blocks._health_for_kind("elite", 6) > main.blocks._health_for_kind("armored", 6), "elite enemies have the thickest health")
	_check(main.blocks._speed_for_kind("swift") > main.blocks._speed_for_kind("normal"), "swift enemies move faster")
	_check(main.blocks._speed_for_kind("armored") < main.blocks._speed_for_kind("normal"), "armored enemies move slower")
	_check(float(main.blocks.HEALTH_BAR_HEIGHT) >= 6.0, "health bars are thicker than health pips")
	_check(float(first.get("hp_bar_time", -1.0)) == 0.0, "health bar hidden before the first hit")
	var hit: Dictionary = main.blocks.damage(int(first.id), 1)
	_check(bool(hit.hit) and not bool(hit.destroyed), "damage registers on a healthy block")
	_check(absf(float(first.hp_bar_time) - float(main.blocks.HEALTH_BAR_DURATION)) < 0.001, "health bar appears on hit")
	_check(is_equal_approx(float(main.blocks.HEALTH_BAR_DURATION), 3.0), "health bar lasts three seconds")
	main.blocks._process(1.0)
	_check(float(first.hp_bar_time) < float(main.blocks.HEALTH_BAR_DURATION), "health bar countdown ticks down")
	main.blocks.damage(int(first.id), 1)
	_check(absf(float(first.hp_bar_time) - float(main.blocks.HEALTH_BAR_DURATION)) < 0.001, "repeated hits refresh the health bar timer")
	main.blocks._process(float(main.blocks.HEALTH_BAR_DURATION) + 0.1)
	_check(float(first.hp_bar_time) == 0.0, "health bar disappears after the timer runs out")

	var tracked: Dictionary = _lowest_block()
	var tracked_id := int(tracked.id)
	var tracked_y := float(tracked.rect.position.y)
	await _frames(30)
	var tracked_now = main.blocks.by_id.get(tracked_id)
	_check(tracked_now != null, "tracked block still on screen")
	if tracked_now != null:
		_check(float(tracked_now.rect.position.y) > tracked_y + 5.0, "blocks scroll downward")
	var target_block := _lowest_block()
	var before_destroyed := int(main.blocks.destroyed)
	var before_coins := int(main.coins)
	var reward := int(target_block.max_hp)
	var before_particles: int = int(main.effects.count())
	main.hit_block(int(target_block.id), 999)
	_check(int(main.blocks.destroyed) == before_destroyed + 1, "direct hit destroys a block")
	_check(int(main.coins) >= before_coins + reward, "block destruction awards coins")
	_check(int(main.effects.count()) > before_particles, "hit spawns particles")

	# ---------------------------------------------------------------- 受控场地：阵地与增益
	main.blocks.next_wave_in = 999.0
	main.blocks.blocks.clear()
	main.blocks.by_id.clear()
	for ball in main.balls_layer.get_children():
		if is_instance_valid(ball):
			ball._vanish()
	_clear_buildings()
	main.coins = 2000
	_place("fusion_tower", Vector2(120, 740))
	_place("fusion_tower", Vector2(600, 740))
	_place("solar", Vector2(360, 740))
	var row_turret: Node = _place("turret", Vector2(180, 620))
	var off_turret: Node = _place("turret", Vector2(180, 700))
	var heavy: Node = _place("heavy_turret", Vector2(400, 700))
	var compression: Node = _place("compression_tower", Vector2(300, 620), PI)
	var sandbag: Node = _place("sandbag", Vector2(480, 620))
	main.refresh_power()
	_check(main.power_supply == 10, "controlled field has ten power")
	_check(main.power_demand == 7, "controlled field demand is seven")
	_check(main.power_ok, "controlled field is powered")
	_check(compression.category == ItemDefs.CATEGORY_FORTIFICATION, "compression tower is fortification")
	_check(compression.buff_line, "compression tower covers a line")
	_check(compression.covers_point(row_turret.global_position), "compression covers same row")
	_check(not compression.covers_point(off_turret.global_position), "compression ignores other rows")
	_check(main.get_buff_multiplier(row_turret.global_position) == 2, "row turret gets double damage")
	_check(main.get_buff_multiplier(off_turret.global_position) == 1, "off-row turret stays normal")

	main.select_building(compression)
	_check(main.focus_panel.visible, "compression focus panel opens")
	_check(main.focus_panel.stat_values[2].text == "×2", "focus panel shows compression multiplier")
	_check(main.focus_panel.stat_values[4].text == I18n.t("focus.line_row"), "focus panel shows line coverage")
	main.clear_selection()
	main.select_building(main.placed_buildings[0])
	_check(main.focus_panel.stat_values[0].text == "+4", "focus panel shows fusion output")
	_check(main.focus_panel.stat_values[2].text == "+4", "focus panel shows fusion net output")
	main.clear_selection()

	var balls_before_buff: int = int(main.balls_layer.get_child_count())
	row_turret._fire_projectile()
	_check(int(main.balls_layer.get_child_count()) == balls_before_buff + 1, "buffed turret fires a ball")
	if main.balls_layer.get_child_count() > balls_before_buff:
		var electric_ball: Node = main.balls_layer.get_child(main.balls_layer.get_child_count() - 1)
		_check(int(electric_ball.damage) == 2, "compression doubles ball damage")
		_check(bool(electric_ball.electric), "compression gives balls an electric effect")
		electric_ball._vanish()

	# ---------------------------------------------------------------- 沙袋拦截
	main.blocks.blocks.clear()
	main.blocks.by_id.clear()
	var attacker := _add_test_block(Vector2(480, 550), 30)
	attacker.speed_scale = 1.0
	for i in 18:
		main.blocks._physics_process(0.1)
	_check(attacker.get("blocked_by", null) == sandbag, "enemy stops at the sandbag")
	_check(float(attacker.rect.position.y) <= sandbag.global_position.y, "blocked enemy stays above the sandbag")
	var sandbag_hp := float(sandbag.hp)
	for i in 5:
		main.blocks._physics_process(0.1)
	_check(float(sandbag.hp) < sandbag_hp, "sandbag absorbs enemy attacks")
	sandbag_hp = float(sandbag.hp)
	for i in 4:
		main.blocks._physics_process(0.1)
	_check(float(sandbag.hp) < sandbag_hp, "sandbag keeps taking damage while blocking")

	sandbag.hp = 1.0
	main.blocks._physics_process(0.2)
	_check(not sandbag.alive, "sandbag can be destroyed")
	_check(not main.placed_buildings.has(sandbag), "destroyed sandbag leaves the field")
	var y_after_break := float(attacker.rect.position.y)
	main.blocks._physics_process(0.2)
	_check(attacker.get("blocked_by", null) == null, "enemy is released after the sandbag breaks")
	_check(float(attacker.rect.position.y) > y_after_break, "released enemy resumes moving")

	# ---------------------------------------------------------------- 能源不足：既有优先，新建筑离线
	var removed := 0
	for b in main.placed_buildings.duplicate():
		if String(b.item_id) == "fusion_tower" and removed < 2:
			main.select_building(b)
			main.dismantle_selected()
			removed += 1
	_check(removed == 2, "both fusion towers dismantled")
	_check(not main.power_ok, "dismantling energy buildings causes a deficit")
	_check(main.power_offline == 2, "only the newest consumers go offline")
	main.hud._process(0.0)
	_check("离线 2" in main.hud.energy_label.text, "HUD keeps the energy capacity and offline count")
	_check(row_turret.powered and off_turret.powered, "existing firepower keeps running during a deficit")
	_check(not heavy.powered and not compression.powered, "newer buildings go offline first")
	_check(heavy.modulate != Color.WHITE, "offline building icon is grayed out")
	_check(row_turret.modulate == Color.WHITE, "powered building icon keeps its color")
	_check(main.get_buff_multiplier(row_turret.global_position) == 1, "offline compression stops buffing")
	_check(int(row_turret.get_refund()) == 15, "powered building keeps the normal dismantle refund")
	_check(int(heavy.get_refund()) == 120, "offline building can be dismantled for full refund")

	# 新布置的建筑在缺电时直接离线，但既有建筑继续工作
	var new_turret: Node = _place("turret", Vector2(600, 700))
	_check(not new_turret.powered, "new building is offline when power is short")
	_check(new_turret.modulate != Color.WHITE, "new offline building icon is grayed out")
	_check(row_turret.powered, "existing turret keeps running after a new building is placed")
	_check(main.power_offline == 3, "offline count includes the new building")
	main.blocks.blocks.clear()
	main.blocks.by_id.clear()
	var target := _add_test_block(Vector2(600, 630), 10)
	new_turret._cooldown = 0.0
	var shots_during_deficit := int(new_turret.shots)
	new_turret._process(0.2)
	_check(int(new_turret.shots) == shots_during_deficit, "offline new turret cannot fire")

	var restored_a: Node = _place("solar", Vector2(600, 740))
	var restored_b: Node = _place("solar", Vector2(540, 700))
	var restored_c: Node = _place("solar", Vector2(600, 600))
	main.refresh_power()
	_check(
		int(restored_a.energy_output) == 2 and int(restored_b.energy_output) == 2 and int(restored_c.energy_output) == 2,
		"three solars restore supply"
	)
	_check(main.power_ok, "power recovers after adding supply")
	_check(main.power_offline == 0, "no building stays offline after supply recovers")
	main.hud._process(0.0)
	_check(not ("离线" in main.hud.energy_label.text), "HUD clears the offline count after recovery")
	_check(heavy.modulate == Color.WHITE and new_turret.modulate == Color.WHITE, "building icons restore color when powered")
	_check(row_turret.powered, "existing turret stays powered")
	_check(new_turret.powered, "new turret comes online after supply recovers")
	_check(heavy.powered and compression.powered, "older and newer buildings all come online")
	_check(main.get_buff_multiplier(row_turret.global_position) == 2, "compression buff returns with power")
	_check(int(row_turret.get_refund()) == 15, "refund returns to half after power is restored")
	_check(int(new_turret.get_refund()) == 15, "powered new turret also refunds half")
	main.blocks.blocks.erase(target)
	main.blocks.by_id.erase(int(target.id))

	# ---------------------------------------------------------------- 重炮贯穿与波次推进
	main.blocks.blocks.clear()
	main.blocks.by_id.clear()
	for b in main.placed_buildings:
		if b.is_firepower():
			b._cooldown = 9999.0
	var origin := Vector2(360.0, 740.0)
	for i in 3:
		_add_test_block(origin + Vector2(0.0, -50.0 * float(i + 1)), 1)
	var last_target := _add_test_block(origin + Vector2(0.0, -200.0), 3)
	var power_baseline := int(main.blocks.destroyed)
	main.fire_item_ball(heavy, origin, Vector2.UP, 5, -1, 0, 500.0, 7.0)
	await _frames(30)
	_check(int(main.blocks.destroyed) == power_baseline + 3, "heavy ball spends power on each kill")
	_check(bool(last_target.alive) and int(last_target.hp) == 1, "heavy ball leaves a three-health target at one health")
	_check(main.balls_layer.get_child_count() == 0, "heavy ball stops once its power runs out")

	# 自动索敌与开火
	main.blocks.blocks.clear()
	main.blocks.by_id.clear()
	for b in main.placed_buildings:
		if b.is_firepower():
			b._cooldown = 0.0
	var auto_shots := int(off_turret.shots)
	var auto_destroyed := int(main.blocks.destroyed)
	_add_test_block(off_turret.global_position + Vector2(0.0, -70.0), 1)
	await _frames(30)
	_check(int(off_turret.shots) > auto_shots, "placed turret fires automatically")
	_check(int(main.blocks.destroyed) > auto_destroyed, "placed turret destroys blocks")

	main.blocks.blocks.clear()
	main.blocks.by_id.clear()
	main.blocks.next_wave_in = 0.0
	var wave_before := int(main.blocks.wave)
	main.blocks._physics_process(0.016)
	_check(int(main.blocks.wave) == wave_before + 1, "wave advances when the calm timer ends")
	_check(float(main.blocks.next_wave_in) > 0.0, "next wave countdown restarts")
	_check(main.blocks.blocks.size() > 0, "new wave spawns a batch")

	# ---------------------------------------------------------------- 设置与主菜单
	main.open_settings()
	_check(main.settings_panel.visible, "in-game settings panel opens")
	_check(get_tree().paused, "in-game settings pause gameplay")
	GameSettings.set_option("show_grid", false)
	_check(not GameSettings.show_grid, "settings option updates immediately")
	GameSettings.set_option("show_grid", true)
	main.close_settings()
	_check(not main.settings_panel.visible, "in-game settings panel closes")
	_check(not get_tree().paused, "closing settings resumes gameplay")

	var menu_scene: PackedScene = load("res://scenes/main_menu.tscn")
	var menu := menu_scene.instantiate()
	add_child(menu)
	_check(menu.start_button != null and menu.settings_button != null, "main menu builds actions")
	menu.open_settings()
	_check(menu.settings_panel.visible, "main menu settings open")
	_check(not menu.settings_panel.in_game, "main menu hides in-game actions")
	_check(not get_tree().paused, "main menu settings do not pause tree")
	menu.settings_panel.close_panel()
	_check(not menu.settings_panel.visible, "main menu settings close")
	menu.queue_free()

	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("SMOKE TEST PASS  destroyed=%d coins=%d" % [int(main.blocks.destroyed), int(main.coins)])
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: " + f)
		get_tree().quit(1)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _clear_buildings() -> void:
	if main.selected_building != null:
		main.clear_selection()
	for b in main.placed_buildings:
		if is_instance_valid(b):
			b.queue_free()
	main.placed_buildings.clear()
	main.refresh_power()


func _place(item_id: String, target: Vector2, facing := -PI / 2.0) -> Node:
	var item: Dictionary = ItemDefs.get_item(item_id)
	return main._place_building(item, main.snap_to_grid(target), facing)


func _add_test_block(center: Vector2, hp: int) -> Dictionary:
	var id := int(main.blocks._next_id)
	main.blocks._next_id += 1
	var block := {
		"id": id,
		"kind": "normal",
		"rect": Rect2(center - Vector2(24.0, 15.0), Vector2(48.0, 30.0)),
		"hp": hp,
		"max_hp": hp,
		"speed_scale": 0.0,
		"color": Color.WHITE,
		"flash": 0.0,
		"hp_bar_time": 0.0,
		"attack_flash": 0.0,
		"blocked_by": null,
		"alive": true,
	}
	main.blocks.blocks.append(block)
	main.blocks.by_id[id] = block
	return block


func _lowest_block() -> Dictionary:
	var lowest: Dictionary = {}
	var best := -INF
	for b in main.blocks.blocks:
		if not bool(b.alive):
			continue
		var rect: Rect2 = b.rect
		if rect.position.y > best:
			best = rect.position.y
			lowest = b
	return lowest


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
