extends Node

## 全局事件中心：保存可重放的最新状态，并向 UI 发布具体、可类型检查的信号。
## event_published 用于调试、日志或通用扩展；业务 UI 优先绑定具体信号。

signal event_published(event_name: StringName, payload: Variant)
signal coins_changed(current: int, previous: int)
signal power_changed(demand: int, supply: int, offline: int)
signal base_health_changed(current: float, maximum: int)
signal nest_count_changed(alive: int)
signal destroyed_changed(count: int)
signal selection_changed(building: Node)
signal building_changed(building: Node)
signal placement_changed(active: bool, item_id: String)
signal outcome_changed(outcome: String)
signal language_changed(locale: String)
signal setting_changed(option: String, value: bool)
signal research_changed(item_id: String, unlocked: bool)
signal toast_requested(text: String, color: Color)

var coins := 150
var power_demand := 0
var power_supply := 0
var power_offline := 0
var base_hp := 1000.0
var base_max_hp := 1000
var nest_count := 0
var destroyed := 0
var selected_building: Node = null
var outcome := "playing"
var unlocked_items: Dictionary = {}


## 每局开始时清空上一局缓存。场景重载后新 UI 仍会读到一致的状态。
func reset_session() -> void:
    coins = 150
    power_demand = 0
    power_supply = 0
    power_offline = 0
    base_hp = 1000.0
    base_max_hp = 1000
    nest_count = 0
    destroyed = 0
    selected_building = null
    outcome = "playing"
    unlocked_items.clear()
    event_published.emit(&"session_reset", {})


func set_coins(current: int, previous: int = -1) -> void:
    current = maxi(0, current)
    var old := coins if previous < 0 else previous
    if coins == current and previous < 0:
        return
    coins = current
    coins_changed.emit(current, old)
    event_published.emit(&"coins_changed", {"current": current, "previous": old})


func set_power(demand: int, supply: int, offline: int) -> void:
    if power_demand == demand and power_supply == supply and power_offline == offline:
        return
    power_demand = demand
    power_supply = supply
    power_offline = offline
    power_changed.emit(demand, supply, offline)
    event_published.emit(&"power_changed", {"demand": demand, "supply": supply, "offline": offline})


func set_base_health(current: float, maximum: int) -> void:
    base_hp = maxf(0.0, current)
    base_max_hp = maxi(1, maximum)
    base_health_changed.emit(base_hp, base_max_hp)
    event_published.emit(&"base_health_changed", {"current": base_hp, "maximum": base_max_hp})


func set_nest_count(alive: int) -> void:
    nest_count = maxi(0, alive)
    nest_count_changed.emit(nest_count)
    event_published.emit(&"nest_count_changed", nest_count)


func set_destroyed(count: int) -> void:
    destroyed = maxi(0, count)
    destroyed_changed.emit(destroyed)
    event_published.emit(&"destroyed_changed", destroyed)


func select_building(building: Node) -> void:
    selected_building = building
    selection_changed.emit(building)
    event_published.emit(&"selection_changed", building)


## 建筑属性、射击次数、供电或增益变化后发布；对象本身仍是属性的唯一数据源。
func update_building(building: Node) -> void:
    if building == null or not is_instance_valid(building):
        return
    building_changed.emit(building)
    event_published.emit(&"building_changed", building)


func set_placement(active: bool, item_id: String = "") -> void:
    placement_changed.emit(active, item_id)
    event_published.emit(&"placement_changed", {"active": active, "item_id": item_id})


func set_outcome(value: String) -> void:
    if outcome == value:
        return
    outcome = value
    outcome_changed.emit(value)
    event_published.emit(&"outcome_changed", value)


func set_language(locale: String) -> void:
    language_changed.emit(locale)
    event_published.emit(&"language_changed", locale)


func set_setting(option: String, value: bool) -> void:
    setting_changed.emit(option, value)
    event_published.emit(&"setting_changed", {"option": option, "value": value})


func set_item_unlocked(item_id: String, unlocked: bool = true) -> void:
    unlocked_items[item_id] = unlocked
    research_changed.emit(item_id, unlocked)
    event_published.emit(&"research_changed", {"item_id": item_id, "unlocked": unlocked})


func toast(text: String, color: Color) -> void:
    toast_requested.emit(text, color)
    event_published.emit(&"toast_requested", text)
