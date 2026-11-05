extends Node

## 全局循环音乐：双播放器交叉淡化，设置关闭时停止，场景只指定曲目。

const STREAM_PATHS := {
	"menu": "res://assets/audio/music/menu_loop.wav",
	"battle": "res://assets/audio/music/battle_loop.wav",
}
const TRACK_VOLUME_DB := {"menu": -12.0, "battle": -14.0}
const FADE_SECONDS := 0.65
const SILENT_DB := -45.0

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _track := ""
var _current := 0
var _fade := 1.0
var _old_volume_db := SILENT_DB


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in STREAM_PATHS:
		var stream = load(STREAM_PATHS[id])
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(round(stream.get_length() * float(stream.mix_rate)))
			_streams[id] = stream
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % i
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)
	GameSettings.changed.connect(_on_settings_changed)
	play_track("menu")


func play_track(id: String) -> void:
	if not STREAM_PATHS.has(id):
		return
	if _track == id:
		if GameSettings.music_enabled and not _players[_current].playing:
			_start_current(false)
		return
	_track = id
	if not GameSettings.music_enabled or not _streams.has(id):
		return
	var old := _players[_current]
	_old_volume_db = old.volume_db if old.playing else SILENT_DB
	_fade = 0.0 if old.playing else 1.0
	_current = 1 - _current
	_start_current(_fade < 1.0)


func _start_current(with_fade: bool) -> void:
	if not _streams.has(_track) or not GameSettings.music_enabled:
		return
	var player := _players[_current]
	player.stop()
	player.stream = _streams[_track]
	player.volume_db = SILENT_DB if with_fade else float(TRACK_VOLUME_DB[_track])
	if DisplayServer.get_name() != "headless":
		player.play()


func _process(delta: float) -> void:
	if not GameSettings.music_enabled or _fade >= 1.0 or _players.is_empty():
		return
	_fade = minf(1.0, _fade + delta / FADE_SECONDS)
	var current := _players[_current]
	var old := _players[1 - _current]
	current.volume_db = lerpf(SILENT_DB, float(TRACK_VOLUME_DB[_track]), _fade)
	old.volume_db = lerpf(_old_volume_db, SILENT_DB, _fade)
	if _fade >= 1.0:
		old.stop()


func _on_settings_changed() -> void:
	if not GameSettings.music_enabled:
		_stop_all()
	elif not _players[_current].playing:
		_start_current(false)


func _stop_all() -> void:
	for player in _players:
		if is_instance_valid(player):
			player.stop()


func _exit_tree() -> void:
	_stop_all()
	for player in _players:
		if is_instance_valid(player):
			player.stream = null
	_streams.clear()


func current_track() -> String:
	return _track


func stream_count() -> int:
	return _streams.size()


func loops_enabled() -> bool:
	if _streams.size() != STREAM_PATHS.size():
		return false
	for stream in _streams.values():
		if stream.loop_mode != AudioStreamWAV.LOOP_FORWARD or stream.loop_end <= 0:
			return false
	return true


func active_player_count() -> int:
	var count := 0
	for player in _players:
		if player.playing:
			count += 1
	return count
