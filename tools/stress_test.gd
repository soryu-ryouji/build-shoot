extends Node

## 2D 无限地图压力测试：固定千怪、火力/激光、增益与能源，关闭自动生成和胜负干扰。
## 用法：
##   Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . res://tools/stress_test.tscn
##   -- --enemies=1000 --seconds=10

const ItemDefs = preload("res://scripts/item_defs.gd")

const WARMUP_SECONDS := 1.0
const HIGH_HP := 1_000_000_000
const FIRE_PATTERN := ["turret", "turret", "heavy_turret", "laser_tower"]
const FIRE_CELLS := [
	Vector2i(-3, 0), Vector2i(3, 0), Vector2i(0, -3), Vector2i(0, 3),
	Vector2i(-3, -2), Vector2i(3, 2), Vector2i(-2, 3), Vector2i(2, -3),
	Vector2i(-4, 0), Vector2i(4, 0), Vector2i(0, -4), Vector2i(0, 4),
	Vector2i(-4, -2), Vector2i(4, 2), Vector2i(-2, 4), Vector2i(2, -4),
]
const ENERGY_CELLS := [
	Vector2i(-4, -4), Vector2i(-3, -4), Vector2i(3, 4), Vector2i(4, 4),
	Vector2i(-4, 4), Vector2i(4, -4), Vector2i(-4, 2), Vector2i(4, -2),
]

var main: Node
var enemy_count := 1000
var sample_seconds := 10.0
var sampling := false
var process_samples: Array[float] = []
var physics_samples: Array[float] = []
var process_frames := 0
var sample_started_usec := 0
var sample_wall_seconds := 0.0
var min_enemies := 0
var max_enemies := 0
var last_nodes := 0
var last_draw_calls := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	_parse_arguments()
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		printerr("STRESS TEST FAIL: cannot load scenes/main.tscn")
		get_tree().quit(1)
		return
	main = packed.instantiate()
	add_child(main)
	await _frames(3)

	_setup_game()
	if not _setup_is_valid():
		get_tree().quit(1)
		return
	print(
		"STRESS TEST CONFIG enemies=%d seconds=%.2f warmup=%.2f towers=%d nests=%d power=%d/%d" % [
			enemy_count, sample_seconds, WARMUP_SECONDS, FIRE_CELLS.size(),
			main.nests.size(), main.power_supply, main.power_demand,
		]
	)

	# 预热让炮塔完成首次索敌和转向，采样阶段只统计稳定战斗。
	await get_tree().create_timer(WARMUP_SECONDS, true, false, true).timeout
	_start_sampling()
	await get_tree().create_timer(sample_seconds, true, false, true).timeout
	sampling = false
	sample_wall_seconds = float(Time.get_ticks_usec() - sample_started_usec) / 1_000_000.0
	_report()
	get_tree().quit(0)


func _parse_arguments() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--enemies="):
			var value := arg.trim_prefix("--enemies=")
			if value.is_valid_int():
				enemy_count = maxi(1, int(value))
		elif arg.begins_with("--seconds="):
			var value := arg.trim_prefix("--seconds=")
			if value.is_valid_float():
				sample_seconds = clampf(float(value), 8.0, 300.0)


func _setup_game() -> void:
	main.preparing = false
	main.prep_timer = 0.0
	main.outcome = "playing"
	main.elapsed = 0.0
	main.blocks.reset_stream()
	main.center_on_base()

	main.base_core.max_hp = HIGH_HP
	main.base_core.hp = float(HIGH_HP)
	main.base_core.alive = true
	for nest in main.nests:
		# 保留巢穴作为合法目标，避免清空 nests 触发胜利；只冻结自动生成。
		nest.spawn_timer = 1_000_000_000.0
		nest.spawn_interval = 1_000_000_000.0
		nest.max_hp = HIGH_HP
		nest.hp = float(HIGH_HP)

	_setup_buildings()
	_setup_enemies()
	main.refresh_power()


func _setup_buildings() -> void:
	for i in FIRE_CELLS.size():
		_place(String(FIRE_PATTERN[i % FIRE_PATTERN.size()]), FIRE_CELLS[i])
	# 两条相向的直线增益覆盖同排炮塔；高 HP 防止拦截时被千怪立即拆掉。
	var compression_a := _place("compression_tower", Vector2i(-3, 3), 0.0)
	var compression_b := _place("compression_tower", Vector2i(3, -3), PI)
	for compression in [compression_a, compression_b]:
		compression.max_hp = HIGH_HP
		compression.hp = float(HIGH_HP)
	# 16 火力需 28 点、2 增益需 4 点，8 聚能塔恰好供应 32 点。
	for cell in ENERGY_CELLS:
		_place("fusion_tower", cell)


func _setup_enemies() -> void:
	var center: Vector2 = main.base_core.global_position
	var visible: Rect2 = main._visible_world_rect()
	var outer_radius := minf(280.0, minf(visible.size.x, visible.size.y) * 0.42)
	var inner_radius := minf(190.0, outer_radius * 0.68)
	var golden_angle := PI * (3.0 - sqrt(5.0))
	for i in enemy_count:
		# 黄金角 + 面积均匀半径：确定性分布在基地周围，初始位置全部位于镜头内。
		var ratio := (float(i) + 0.5) / float(enemy_count)
		var radius := sqrt(lerpf(inner_radius * inner_radius, outer_radius * outer_radius, ratio))
		var position := center + Vector2.from_angle(float(i) * golden_angle) * radius
		# normal 基础 HP=5；由 spawn_enemy 同步维护后续的空间索引。
		main.blocks.spawn_enemy(position, "normal", float(HIGH_HP) / 5.0)
	main.blocks.queue_redraw()


func _place(item_id: String, cell: Vector2i, facing := -PI / 2.0) -> Node:
	return main._place_building(
		ItemDefs.get_item(item_id), main.arena.map_loader.cell_to_world(cell), facing
	)


func _setup_is_valid() -> bool:
	var valid: bool = (
		main.blocks.blocks.size() == enemy_count
		and main.blocks.spatial_index.size() == enemy_count
		and FIRE_CELLS.size() == 16
		and main.placed_buildings.size() == FIRE_CELLS.size() + ENERGY_CELLS.size() + 2
		and not main.nests.is_empty()
		and main.power_ok
		and main.outcome == "playing"
	)
	if not valid:
		printerr(
			"STRESS TEST FAIL: setup enemies=%d/%d buildings=%d nests=%d power=%d/%d outcome=%s" % [
				main.blocks.blocks.size(), enemy_count, main.placed_buildings.size(),
				main.nests.size(), main.power_supply, main.power_demand, main.outcome,
			]
		)
	return valid


func _start_sampling() -> void:
	process_samples.clear()
	physics_samples.clear()
	process_frames = 0
	min_enemies = main.blocks.blocks.size()
	max_enemies = min_enemies
	sample_started_usec = Time.get_ticks_usec()
	sampling = true


func _process(_delta: float) -> void:
	if not sampling:
		return
	process_samples.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
	process_frames += 1
	var count: int = main.blocks.blocks.size()
	min_enemies = mini(min_enemies, count)
	max_enemies = maxi(max_enemies, count)
	last_nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	last_draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


func _physics_process(_delta: float) -> void:
	if sampling:
		physics_samples.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)


func _report() -> void:
	var fps := float(process_frames) / maxf(sample_wall_seconds, 0.000001)
	print(
		"STRESS TEST RESULT samples process=%d physics=%d simulated=%.2fs wall=%.3fs" % [
			process_samples.size(), physics_samples.size(), sample_seconds, sample_wall_seconds,
		]
	)
	print(
		"enemies initial=%d final=%d min=%d max=%d | nodes=%d | draw_calls=%d" % [
			enemy_count, main.blocks.blocks.size(), min_enemies, max_enemies,
			last_nodes, last_draw_calls,
		]
	)
	print(
		"process_ms average=%.3f p95=%.3f | physics_ms average=%.3f p95=%.3f | FPS=%.2f" % [
			_average(process_samples), _p95(process_samples),
			_average(physics_samples), _p95(physics_samples), fps,
		]
	)
	print("STRESS TEST PASS (measurement completed; no hardware FPS threshold)")


func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _p95(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(ceili(float(sorted.size()) * 0.95) - 1, 0, sorted.size() - 1)]


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
