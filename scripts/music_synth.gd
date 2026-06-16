class_name MusicSynth
extends RefCounted

const BGM_PATH := "res://assets/audio/gameplay-soundtrack.wav"
const BGM_VOLUME := 0.72

var _player: AudioStreamPlayer


func is_playing() -> bool:
	return _player != null and is_instance_valid(_player) and _player.playing


func start(parent: Node) -> void:
	if parent == null:
		return
	_ensure_player(parent)
	if _player == null:
		return
	if _player.playing:
		return
	_player.call_deferred("play")


func stop() -> void:
	if _player != null and is_instance_valid(_player):
		_player.stop()


func _ensure_player(parent: Node) -> void:
	if _player != null and is_instance_valid(_player):
		_refresh_stream()
		return

	var existing := parent.get_node_or_null("GameplayMusic") as AudioStreamPlayer
	if existing:
		_player = existing
		_refresh_stream()
		return

	var stream := _load_stream()
	if stream == null:
		return

	_player = AudioStreamPlayer.new()
	_player.name = "GameplayMusic"
	_player.stream = stream
	_player.volume_db = linear_to_db(BGM_VOLUME)
	_player.bus = &"Master"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(_player)


func _refresh_stream() -> void:
	var stream := _load_stream()
	if stream == null:
		return
	_player.stream = stream
	_player.volume_db = linear_to_db(BGM_VOLUME)
	_player.bus = &"Master"


func _load_stream() -> AudioStream:
	var stream: AudioStream = load(BGM_PATH)
	if stream == null:
		push_error("Müzik dosyası yüklenemedi: %s (Godot'ta Reimport yapıp oyunu yeniden başlat)" % BGM_PATH)
		return null
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream
