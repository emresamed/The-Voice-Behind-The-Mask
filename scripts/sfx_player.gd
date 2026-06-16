extends Node
## Kısa ses efektleri — autoload.

const SFX_DIR := "res://assets/audio/sfx/"
const SFX_VOLUME := 0.9

const ECHO_CHARGE_PATH := SFX_DIR + "echo-charge.ogg"

func _ready() -> void:
	_ensure_bass_bus()


const PATHS := {
	"click": SFX_DIR + "click.ogg",
	"coin": SFX_DIR + "coin.ogg",
	"dash": SFX_DIR + "dash.ogg",
	"echo": SFX_DIR + "echo.ogg",
	"magic": SFX_DIR + "magic.ogg",
	"market": SFX_DIR + "market.ogg",
	"monster_close": SFX_DIR + "monster-close.ogg",
	"story_trex": SFX_DIR + "story-trex-roar.mp3",
	"story_monster_roar": SFX_DIR + "story-monster-roar.ogg",
	"monster_death": SFX_DIR + "monster-death.ogg",
	"pain": SFX_DIR + "pain.ogg",
}


func play_echo_charge(charge_t: float, volume_linear: float = 1.0, bass_boost: bool = false) -> void:
	var frac := clampf(charge_t, 0.0, 1.0)
	if not ResourceLoader.exists(ECHO_CHARGE_PATH):
		play("echo", lerpf(0.65, 1.0, frac) * volume_linear)
		return
	var stream: AudioStream = load(ECHO_CHARGE_PATH)
	if stream == null:
		return
	var full_len := stream.get_length()
	if full_len <= 0.0:
		play("echo", volume_linear)
		return
	var play_len := maxf(full_len * frac, 0.04)
	var player := _make_player(stream, lerpf(0.65, 1.0, frac) * volume_linear, bass_boost)
	player.play()
	var tween := create_tween()
	tween.tween_interval(play_len)
	tween.tween_callback(func() -> void:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	)


func play(sound_id: String, volume_linear: float = 1.0) -> void:
	if not PATHS.has(sound_id):
		push_warning("Bilinmeyen SFX: %s" % sound_id)
		return
	var path: String = PATHS[sound_id]
	if not ResourceLoader.exists(path):
		push_warning("SFX dosyası yok: %s" % path)
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	var player := _make_player(stream, volume_linear)
	player.play()


func _ensure_bass_bus() -> StringName:
	const BUS_NAME := &"SfxBass"
	var bus_idx := AudioServer.get_bus_index(BUS_NAME)
	if bus_idx >= 0:
		return BUS_NAME
	bus_idx = AudioServer.bus_count
	AudioServer.add_bus(bus_idx)
	AudioServer.set_bus_name(bus_idx, BUS_NAME)
	AudioServer.set_bus_send(bus_idx, &"Master")
	var eq := AudioEffectEQ10.new()
	eq.set_band_gain_db(0, 7.0)
	eq.set_band_gain_db(1, 4.5)
	eq.set_band_gain_db(2, 2.0)
	AudioServer.add_bus_effect(bus_idx, eq)
	return BUS_NAME


func _make_player(stream: AudioStream, volume_linear: float, bass_boost: bool = false) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = _ensure_bass_bus() if bass_boost else &"Master"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.volume_db = linear_to_db(maxf(volume_linear, 0.0) * SFX_VOLUME)
	if bass_boost:
		player.pitch_scale = 0.9
	player.stream = stream
	player.finished.connect(player.queue_free)
	add_child(player)
	return player
