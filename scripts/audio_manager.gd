extends Node

## 全局短音效池：高频事件限频，重要事件可抢占较旧的低优先级播放。

const POOL_SIZE := 12
const STREAM_PATHS := {
	"ui": "res://assets/audio/sfx/ui.wav",
	"place": "res://assets/audio/sfx/place.wav",
	"upgrade": "res://assets/audio/sfx/upgrade.wav",
	"invalid": "res://assets/audio/sfx/invalid.wav",
	"shoot": "res://assets/audio/sfx/shoot.wav",
	"heavy_shot": "res://assets/audio/sfx/heavy_shot.wav",
	"laser": "res://assets/audio/sfx/laser.wav",
	"hit": "res://assets/audio/sfx/hit.wav",
	"destroy": "res://assets/audio/sfx/destroy.wav",
	"buff": "res://assets/audio/sfx/buff.wav",
	"base_hit": "res://assets/audio/sfx/base_hit.wav",
	"victory": "res://assets/audio/sfx/victory.wav",
	"defeat": "res://assets/audio/sfx/defeat.wav",
}
const COOLDOWN_MS := {
	"ui": 35,
	"place": 70,
	"upgrade": 100,
	"invalid": 100,
	"shoot": 35,
	"heavy_shot": 90,
	"laser": 80,
	"hit": 60,
	"destroy": 80,
	"buff": 140,
	"base_hit": 260,
	"victory": 500,
	"defeat": 500,
}
const VOLUME_DB := {
	"ui": -14.0,
	"place": -10.0,
	"upgrade": -9.0,
	"invalid": -10.0,
	"shoot": -16.0,
	"heavy_shot": -10.0,
	"laser": -15.0,
	"hit": -18.0,
	"destroy": -11.0,
	"buff": -11.0,
	"base_hit": -8.0,
	"victory": -7.0,
	"defeat": -7.0,
}
const PRIORITY := {
	"place": 1,
	"upgrade": 1,
	"invalid": 1,
	"buff": 1,
	"base_hit": 2,
	"victory": 3,
	"defeat": 3,
}

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _last_played: Dictionary = {}
var _started_at: Dictionary = {}
var _player_priority: Dictionary = {}
var _play_counts: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for id in STREAM_PATHS:
		var stream = load(STREAM_PATHS[id])
		if stream is AudioStream:
			_streams[id] = stream
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % i
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)
		_player_priority[player] = 0
	get_tree().node_added.connect(_on_node_added)
	GameSettings.changed.connect(_on_settings_changed)


func _exit_tree() -> void:
	_stop_all()
	_streams.clear()


func _on_settings_changed() -> void:
	if not GameSettings.sound_enabled:
		_stop_all()


func _stop_all() -> void:
	for player in _players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


func play(id: String) -> bool:
	if not GameSettings.sound_enabled or not _streams.has(id):
		return false
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(id, -1000000)) < int(COOLDOWN_MS.get(id, 0)):
		return false
	var priority := int(PRIORITY.get(id, 0))
	var player := _find_player(priority)
	if player == null:
		return false
	_last_played[id] = now
	_started_at[player] = now
	_player_priority[player] = priority
	player.stop()
	player.stream = _streams[id]
	player.volume_db = float(VOLUME_DB.get(id, -12.0))
	player.pitch_scale = _pitch_for(id)
	if DisplayServer.get_name() != "headless":
		player.play()
	_play_counts[id] = int(_play_counts.get(id, 0)) + 1
	return true


func _find_player(priority: int) -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	if priority < 2:
		return null
	var oldest: AudioStreamPlayer = null
	var oldest_time := 9223372036854775807
	for player in _players:
		if int(_player_priority.get(player, 0)) > priority:
			continue
		var started := int(_started_at.get(player, 0))
		if started < oldest_time:
			oldest_time = started
			oldest = player
	return oldest


func _pitch_for(id: String) -> float:
	match id:
		"shoot", "laser", "hit":
			return _rng.randf_range(0.96, 1.04)
		"destroy", "place":
			return _rng.randf_range(0.97, 1.03)
	return 1.0


func stream_count() -> int:
	return _streams.size()


func active_player_count() -> int:
	var count := 0
	for player in _players:
		if player.playing:
			count += 1
	return count


func get_play_count(id: String) -> int:
	return int(_play_counts.get(id, 0))


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		if not button.pressed.is_connected(_on_any_button_pressed):
			button.pressed.connect(_on_any_button_pressed)


func _on_any_button_pressed() -> void:
	play("ui")
