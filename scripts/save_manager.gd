extends Node

## JSON 存档、磁盘读取、删除与继续游戏请求。游戏状态序列化由 Main 提供。

signal save_changed

const SAVE_VERSION := 1
var save_path := "user://savegame.json"
var load_requested := false
var last_error := ""


func has_save() -> bool:
    return FileAccess.file_exists(save_path)


func save_game(game: Node) -> bool:
    if game == null or not is_instance_valid(game) or game.outcome != "playing":
        last_error = "当前状态不能保存"
        return false
    var data: Dictionary = game.get_save_data()
    data["version"] = SAVE_VERSION
    data["saved_at"] = int(Time.get_unix_time_from_system())
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://"))
    var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
    if file == null:
        last_error = "无法写入存档"
        return false
    file.store_string(JSON.stringify(data))
    file.flush()
    file.close()
    var absolute := ProjectSettings.globalize_path(save_path)
    var temporary := ProjectSettings.globalize_path(save_path + ".tmp")
    if FileAccess.file_exists(save_path):
        DirAccess.remove_absolute(absolute)
    var result := DirAccess.rename_absolute(temporary, absolute)
    if result != OK:
        last_error = "存档写入失败：%d" % result
        return false
    last_error = ""
    save_changed.emit()
    return true


func read_save() -> Dictionary:
    last_error = ""
    if not has_save():
        last_error = "没有存档"
        return {}
    var file := FileAccess.open(save_path, FileAccess.READ)
    if file == null:
        last_error = "无法读取存档"
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary or int(parsed.get("version", 0)) != SAVE_VERSION:
        last_error = "存档版本不兼容或已损坏"
        return {}
    if not parsed.has("game") or not parsed.game is Dictionary:
        last_error = "存档缺少游戏数据"
        return {}
    return parsed


func delete_save() -> bool:
    if not has_save():
        return true
    var result := DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
    if result != OK:
        last_error = "删除存档失败：%d" % result
        return false
    load_requested = false
    last_error = ""
    save_changed.emit()
    return true
