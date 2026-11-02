extends Node

## 极简 i18n：从 res://i18n/<locale>.json 读取扁平 key-value 表。
## 默认中文。新增语言：复制一份 json，并把语言代码加入 LOCALES。

signal locale_changed(locale: String)

const DEFAULT_LOCALE := "zh_CN"
const LOCALES := ["zh_CN", "en"]

var locale := DEFAULT_LOCALE

var _strings: Dictionary = {}
var _fallback: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fallback = _load(DEFAULT_LOCALE)
	set_locale(DEFAULT_LOCALE, false)


func set_locale(code: String, notify: bool = true) -> void:
	if not LOCALES.has(code):
		code = DEFAULT_LOCALE
	locale = code
	_strings = _load(code)
	if notify:
		locale_changed.emit(locale)


func toggle_locale() -> void:
	var idx := LOCALES.find(locale)
	set_locale(LOCALES[(idx + 1) % LOCALES.size()])


func t(key: String, args: Array = []) -> String:
	var text := String(_strings.get(key, ""))
	if text.is_empty():
		text = String(_fallback.get(key, key))
	if not args.is_empty():
		return text % args
	return text


func missing_keys(code: String) -> Array:
	var target := _load(code)
	var missing: Array = []
	for key in _fallback.keys():
		if not target.has(key):
			missing.append(key)
	return missing


func _load(code: String) -> Dictionary:
	var path := "res://i18n/%s.json" % code
	if not FileAccess.file_exists(path):
		push_error("Missing locale file: " + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open locale file: " + path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("Invalid locale JSON: " + path)
	return {}
