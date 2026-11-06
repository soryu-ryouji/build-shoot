extends Node

## 跨场景设置。无头测试不读写用户配置，保证测试结果可复现。

signal changed

const CONFIG_PATH := "user://settings.cfg"
const BOOLEAN_OPTIONS := ["fullscreen", "animate_monsters", "show_grid", "show_aim", "sound_enabled", "music_enabled"]

var fullscreen := false
var animate_monsters := true
var show_grid := true
var show_aim := true
var sound_enabled := true
var music_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() != "headless":
		_load_settings()


func set_option(option: String, value: bool) -> void:
	if not BOOLEAN_OPTIONS.has(option) or bool(get(option)) == value:
		return
	set(option, value)
	if option == "fullscreen":
		_apply_fullscreen()
	changed.emit()
	Events.set_setting(option, value)
	save_settings()


func save_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var config := ConfigFile.new()
	config.set_value("general", "locale", I18n.locale)
	for option in BOOLEAN_OPTIONS:
		config.set_value("options", option, get(option))
	config.save(CONFIG_PATH)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	var saved_locale := String(config.get_value("general", "locale", I18n.DEFAULT_LOCALE))
	I18n.set_locale(saved_locale)
	for option in BOOLEAN_OPTIONS:
		set(option, bool(config.get_value("options", option, get(option))))
	_apply_fullscreen()


func _apply_fullscreen() -> void:
	# Web 端由外层横屏舞台控制尺寸，不调用浏览器全屏
	if DisplayServer.get_name() == "headless" or OS.has_feature("web"):
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
