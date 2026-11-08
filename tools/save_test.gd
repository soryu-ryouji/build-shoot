extends Node

var failures: Array[String] = []
var main: Node
var scene_tree: SceneTree


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    scene_tree = get_tree()
    call_deferred("_run")


func _run() -> void:
    SaveManager.save_path = ProjectSettings.globalize_path("res://.godot/save_test.json")
    SaveManager.delete_save()
    await _create_main()
    main.coins = 1500
    main.research_item("lightning_tower")
    var turret = _place("turret", Vector2i(-3, 0))
    main.select_building(turret)
    main.upgrade_selected()
    main.clear_selection()
    _place("fusion_tower", Vector2i(-3, 2))
    var coin = _place("coin_tower", Vector2i(3, 2))
    coin._coin_timer = 1.75
    var wall_a = _place("sandbag", Vector2i(0, 3))
    _place("sandbag", Vector2i(1, 3))
    _place("sandbag", Vector2i(0, 4))
    _place("lightning_tower", Vector2i(3, -2))
    main.coins = 1234
    main._end_prep()
    var enemy: Dictionary = main.blocks.spawn_enemy(Vector2(100, 80), "normal")
    main.blocks.damage(int(enemy.id), 2)
    main.nests[0].take_damage(10)
    main.damage_base(100)
    main.camera_center = Vector2(100, 50)
    main._apply_camera()
    var save_result := SaveManager.save_game(main)
    _check(save_result, "save writes successfully")
    _check(SaveManager.has_save(), "save file exists")
    var data := SaveManager.read_save()
    _check(not data.is_empty(), "save can be read")

    main.queue_free()
    await _frames(3)
    await _create_main()
    _check(main.restore_save(data), "save restores into a fresh scene")
    _check(main.coins == 1234, "coins restored")
    _check(main.is_item_unlocked("lightning_tower"), "research restored")
    _check(main.base_core.hp == 900.0, "base health restored")
    _check(main.nests[0].hp == main.nests[0].max_hp - 10.0, "nest health restored")
    _check(not main.arena.map_loader.is_buildable(main.nests[0].cell), "restored nest remains reserved")
    _check(main.nests[0].cell == Vector2i(-9, -7), "current save keeps the expanded nest layout")
    _check(main.blocks.blocks.size() == 1 and int(main.blocks.blocks[0].hp) == 3, "enemy and health restored")
    _check(main.camera_center == Vector2(100, 50), "camera restored")
    var found_wall := false
    var found_turret := false
    var found_coin := false
    for building in main.placed_buildings:
        if building.item_id == "sandbag" and building.cell == Vector2i(0, 3):
            found_wall = building.wall_mask == 6
        if building.item_id == "turret":
            found_turret = building.level == 2
        if building.item_id == "coin_tower":
            found_coin = is_equal_approx(building._coin_timer, 1.75)
    _check(found_wall, "wall connections restored")
    _check(found_turret, "building level restored")
    _check(found_coin, "production timer restored")
    _check(main.settings_panel.save_button != null, "manual save button exists")

    var legacy := data.duplicate(true)
    legacy.game.erase("map_revision")
    for saved_nest in legacy.game.nests:
        saved_nest.erase("cell")
    _check(main.restore_save(legacy), "legacy save remains readable")
    _check(main.nests[0].cell == Vector2i(-5, -4), "legacy save preserves its original nest position")

    main.queue_free()
    await _frames(3)
    var menu = load("res://scenes/main_menu.tscn").instantiate()
    add_child(menu)
    await _frames(2)
    _check(menu.continue_button.visible and menu.delete_save_button.visible, "continue and delete buttons appear")
    menu._on_delete_save()
    _check(SaveManager.has_save() and menu._delete_armed, "first delete click only arms confirmation")
    menu._on_delete_save()
    _check(not SaveManager.has_save() and not menu.delete_save_button.visible, "second click deletes save and hides buttons")
    menu.queue_free()
    if failures.is_empty():
        print("SAVE TEST PASS")
        scene_tree.quit(0)
    else:
        for failure in failures:
            printerr("FAIL: " + failure)
        scene_tree.quit(1)


func _create_main() -> void:
    main = load("res://scenes/main.tscn").instantiate()
    add_child(main)
    await _frames(3)


func _place(item_id: String, cell: Vector2i) -> Node:
    return main._place_building(main.ItemDefs.get_item(item_id), main.arena.map_loader.cell_to_world(cell))


func _frames(count: int) -> void:
    for i in count:
        await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
