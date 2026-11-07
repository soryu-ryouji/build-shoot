extends Node

## 事件中心、绑定生命周期、晚加入同步和 UI 预置体实例化回归。

const EventBindingScript = preload("res://scripts/event_binding.gd")
const PREFABS := [
    "res://scenes/ui/hud.tscn",
    "res://scenes/ui/shop_bar.tscn",
    "res://scenes/ui/item_card.tscn",
    "res://scenes/ui/drag_preview.tscn",
    "res://scenes/ui/focus_panel.tscn",
    "res://scenes/ui/settings_panel.tscn",
    "res://scenes/ui/result_panel.tscn",
    "res://scenes/main_menu.tscn",
]

var failures: Array[String] = []


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_run")


func _run() -> void:
    Events.reset_session()
    var binding := EventBindingScript.new()
    var received: Array = []
    var published: Array = []
    var callback := func(current: int, previous: int) -> void:
        received.append([current, previous])
    binding.bind(Events.coins_changed, callback)
    binding.bind(Events.coins_changed, callback)
    binding.bind(Events.event_published, func(event_name: StringName, _payload: Variant) -> void:
        published.append(event_name)
    )
    _check(binding.count() == 2, "duplicate connections are rejected")
    Events.set_coins(220)
    _check(received == [[220, 150]], "typed signal carries current and previous values")
    _check(Events.coins == 220, "latest value is cached for late subscribers")
    _check(published.has(&"coins_changed"), "generic publication feed is emitted")
    binding.clear()
    _check(binding.count() == 0, "binding list is cleared")
    Events.set_coins(260)
    _check(received.size() == 1, "cleared binding no longer receives events")

    # Shop is created after a state change and must show cached resources immediately.
    var shop = load("res://scenes/ui/shop_bar.tscn").instantiate()
    add_child(shop)
    await _frames(2)
    _check("260" in shop.coins_label.text, "late shop binding reads cached coins")
    Events.set_coins(321)
    Events.set_power(4, 6, 0)
    await _frames(2)
    _check("321" in shop.coins_label.text, "shop reacts to coin event")
    _check("4/6" in shop.energy_label.text, "shop reacts to power event")
    _check(shop._events.count() == 3, "shop owns three managed event connections")
    shop.queue_free()
    await _frames(2)

    for path in PREFABS:
        var packed: PackedScene = load(path)
        _check(packed != null and packed.can_instantiate(), "prefab loads: " + path)
        if packed == null:
            continue
        var instance = packed.instantiate()
        add_child(instance)
        await _frames(1)
        instance.queue_free()
        await _frames(2)

    var result = load("res://scenes/ui/result_panel.tscn").instantiate()
    add_child(result)
    await _frames(2)
    Events.set_outcome("won")
    await _frames(2)
    _check(result.visible and result.title_label.text == I18n.t("result.won"), "result prefab reacts to outcome event")
    result.queue_free()
    await _frames(2)

    Events.reset_session()
    if failures.is_empty():
        print("EVENT CENTER TEST PASS")
        get_tree().quit(0)
    else:
        for failure in failures:
            printerr("FAIL: " + failure)
        get_tree().quit(1)


func _frames(count: int) -> void:
    for i in count:
        await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
