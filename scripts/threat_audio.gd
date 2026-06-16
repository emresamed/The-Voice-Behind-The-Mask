class_name ThreatAudio
extends RefCounted

const THEME_PATH := "res://assets/audio/sfx/monster-close.ogg"
const HEART_PATH := "res://assets/audio/sfx/heartbeat.ogg"

var _theme: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _smoothed_proximity := 0.0
var _beat_timer := 0.0
var _heart_env := 0.0


func start(parent: Node) -> void:
	stop()
	_theme = _make_loop_player(parent, THEME_PATH, "ThreatTheme")
	_heart = _make_loop_player(parent, HEART_PATH, "ThreatHeart")


func stop() -> void:
	if is_instance_valid(_theme):
		_theme.queue_free()
	if is_instance_valid(_heart):
		_heart.queue_free()
	_theme = null
	_heart = null
	_smoothed_proximity = 0.0
	_beat_timer = 0.0
	_heart_env = 0.0


func update(dt: float, proximity: float, danger_t: float) -> void:
	_update_proximity_theme(dt, proximity)
	_update_danger_heartbeat(dt, danger_t)


func _update_proximity_theme(dt: float, proximity: float) -> void:
	if _theme == null:
		return
	var target := clampf(proximity, 0.0, 1.0)
	_smoothed_proximity = lerpf(_smoothed_proximity, target, minf(1.0, dt * 10.0))
	if _smoothed_proximity <= 0.01:
		_theme.volume_db = -80.0
		_theme.pitch_scale = 0.9
		return
	var tension := _smoothed_proximity * _smoothed_proximity
	_theme.volume_db = linear_to_db(lerpf(0.06, 0.92, tension))
	_theme.pitch_scale = lerpf(0.82, 1.12, tension)


func _update_danger_heartbeat(dt: float, danger_t: float) -> void:
	if _heart == null:
		return
	var threat := clampf(danger_t, 0.0, 1.0)
	if threat <= 0.02:
		_heart.volume_db = -80.0
		_heart_env = 0.0
		return
	var beat_iv := lerpf(1.1, 0.32, threat)
	_beat_timer -= dt
	if _beat_timer <= 0.0:
		_beat_timer = beat_iv
		_heart_env = lerpf(0.3, 0.95, threat)
	_heart_env = maxf(0.0, _heart_env - dt * lerpf(3.0, 7.0, threat))
	_heart.volume_db = linear_to_db(_heart_env * 0.55)
	_heart.pitch_scale = lerpf(0.88, 1.08, threat)


func _make_loop_player(parent: Node, path: String, node_name: String) -> AudioStreamPlayer:
	var stream: AudioStream = load(path)
	if stream == null:
		push_warning("Tehlike sesi yüklenemedi: %s" % path)
		return null
	if stream is AudioStreamOggVorbis:
		var ogg := (stream as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
		ogg.loop = true
		stream = ogg
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.stream = stream
	player.volume_db = -80.0
	player.pitch_scale = 1.0
	player.bus = &"Master"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(player)
	player.play()
	return player
