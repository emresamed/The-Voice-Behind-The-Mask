class_name SfxBurst
extends Node
## Kısa tek atımlık prosedürel ses.

const OscillatorNode = preload("res://scripts/oscillator_node.gd")

var _osc: OscillatorNode
var _life := 0.0
var _duration := 0.1
var _peak_gain := 0.12


func setup(freq: float, duration: float, wave: String = "sine", peak_gain: float = 0.12) -> void:
	_duration = maxf(duration, 0.04)
	_life = _duration
	_peak_gain = peak_gain
	_osc = OscillatorNode.new()
	_osc.wave = wave
	_osc.frequency = freq
	_osc.gain = peak_gain
	add_child(_osc)
	set_process(true)


func _process(delta: float) -> void:
	_life = maxf(0.0, _life - delta)
	if _osc != null:
		var t: float = _life / _duration
		_osc.gain = _peak_gain * t * t
	if _life <= 0.0:
		queue_free()


static func play(parent: Node, freq: float, duration: float, wave: String = "sine", peak_gain: float = 0.12) -> void:
	if parent == null:
		return
	var sfx := SfxBurst.new()
	sfx.setup(freq, duration, wave, peak_gain)
	parent.add_child(sfx)
