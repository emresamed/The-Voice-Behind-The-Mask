extends Node
## Oyun müziği — autoload; gameplay ve boss için ayrı çalar.

const GAMEPLAY_BGM_PATH := "res://assets/audio/gameplay-soundtrack.ogg"
const BOSS_BGM_PATH := "res://assets/audio/boss-fight.ogg"
const BGM_VOLUME := 0.85

var _gameplay_player: AudioStreamPlayer
var _boss_player: AudioStreamPlayer
var _active_mode: String = "gameplay"
var _fade_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_gameplay_player = _make_player("GameplayBgm")
	_boss_player = _make_player("BossBgm")
	add_child(_gameplay_player)
	add_child(_boss_player)


func _make_player(node_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.bus = &"Master"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.volume_db = _linear_to_db(1.0)
	return player


func play_music() -> void:
	play_gameplay_music(0.0)


func play_gameplay_music(fade_duration: float = 0.0, target_linear: float = 1.0) -> void:
	_active_mode = "gameplay"
	_boss_player.stop()
	_boss_player.stream = null
	_start_stream_on(_gameplay_player, GAMEPLAY_BGM_PATH, target_linear, fade_duration)


func play_boss_music(fade_duration: float = 0.0) -> void:
	_active_mode = "boss"
	_kill_fade()
	_gameplay_player.stop()
	_gameplay_player.stream = null
	_start_stream_on(_boss_player, BOSS_BGM_PATH, 1.0, fade_duration)


func stop_music() -> void:
	_kill_fade()
	_gameplay_player.stop()
	_boss_player.stop()
	_gameplay_player.stream = null
	_boss_player.stream = null
	_active_mode = "gameplay"


func is_playing() -> bool:
	return _gameplay_player.playing or _boss_player.playing


func set_paused(paused: bool) -> void:
	_gameplay_player.stream_paused = paused
	_boss_player.stream_paused = paused


func set_volume_linear(linear: float) -> void:
	_active_player().volume_db = _linear_to_db(linear)


func fade_to(linear: float, duration: float) -> void:
	var player := _audible_player()
	if duration <= 0.001:
		_kill_fade()
		player.volume_db = _linear_to_db(linear)
		return
	_kill_fade()
	_fade_tween = create_tween()
	_fade_tween.tween_property(player, "volume_db", _linear_to_db(linear), duration)


func _active_player() -> AudioStreamPlayer:
	return _boss_player if _active_mode == "boss" else _gameplay_player


func _audible_player() -> AudioStreamPlayer:
	if _boss_player.playing:
		return _boss_player
	if _gameplay_player.playing:
		return _gameplay_player
	return _active_player()


func _start_stream_on(
	player: AudioStreamPlayer,
	path: String,
	target_linear: float,
	fade_duration: float
) -> void:
	var stream := _load_looped_stream(path)
	if stream == null:
		if path == BOSS_BGM_PATH:
			push_error("Boss müziği yüklenemedi: %s" % path)
		else:
			push_error("Müzik yüklenemedi: %s" % path)
		return
	_kill_fade()
	player.stop()
	player.stream = stream
	player.stream_paused = false
	if fade_duration <= 0.001:
		player.volume_db = _linear_to_db(target_linear)
	else:
		player.volume_db = -80.0
	player.play()
	if fade_duration > 0.001:
		_fade_tween = create_tween()
		_fade_tween.tween_property(player, "volume_db", _linear_to_db(target_linear), fade_duration)


func _linear_to_db(linear: float) -> float:
	return linear_to_db(clampf(linear, 0.0, 1.0) * BGM_VOLUME)


func _load_looped_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_error("BGM dosyası bulunamadı: %s" % path)
		return null
	var stream: AudioStream = load(path)
	if stream == null:
		return null
	if stream is AudioStreamOggVorbis:
		var ogg := (stream as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
		ogg.loop = true
		return ogg
	if stream is AudioStreamWAV:
		var wav := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		return wav
	return stream


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
