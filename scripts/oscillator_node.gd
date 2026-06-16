extends Node

var wave := "sine"
var frequency := 440.0
var gain := 0.1

var _player: AudioStreamPlayer
var _phase := 0.0
const MIX_RATE := 44100.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.1
	_player.stream = gen
	add_child(_player)
	_player.play()
	set_process(true)


func _process(_delta: float) -> void:
	var playback := _player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frames := playback.get_frames_available()
	for _i in range(frames):
		var sample := _sample()
		playback.push_frame(Vector2(sample, sample))
		_phase += frequency / MIX_RATE
		while _phase >= 1.0:
			_phase -= 1.0


func _sample() -> float:
	match wave:
		"saw":
			return (_phase * 2.0 - 1.0) * gain
		_:
			return sin(_phase * TAU) * gain
