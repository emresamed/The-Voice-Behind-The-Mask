extends Control
## Birebir port: artifacts/echo-runner/src/game/engine.ts

signal music_changed(enabled: bool)

enum GameState { MENU, PLAYING, PAUSED, STORY, BOSS, WIN, DEAD, MARKET, SETTINGS }

# --- state (engine.ts satır 104-152) ---
var state: GameState = GameState.MENU
var score: float = 0.0
var high_score: float = 0.0
var coins: int = 0
var total_coins: int = 0
var upgrade_levels: Dictionary = MarketUpgrades.default_levels()
var checkpoint_msg: String = ""
var checkpoint_msg_timer: float = 0.0
var checkpoint_msg_is_zone: bool = false
var checkpoint_msg_color: Color = Color("#00ffb0")
var current_zone_index: int = 0
var _zone_tint: Color = Color.WHITE

var player_wx: float = GameConstants.CANVAS_W / 2.0
var player_wy: float = 0.0
var camera_wy: float = 0.0
var monster_wx: float = GameConstants.CANVAS_W / 2.0
var monster_wy: float = -GameConstants.MONSTER_START_DIST
var monster_awake: bool = false
var monster_seen_on_screen: bool = false
var monster_revealed_until: float = 0.0
var _prev_player_wx: float = GameConstants.CANVAS_W / 2.0
var _prev_player_wy: float = 0.0

var dash_cooldown: float = 0.0
var dash_time_left: float = 0.0
var dash_dir := Vector2.ZERO

var echo_held: bool = false
var echo_hold_start: float = 0.0
var echo_hold_duration: float = 0.0
var last_echo_time: float = 0.0

var danger_value: float = 0.0
var obs_hit_slow_timer: float = 0.0
var obs_hit_slow_mult: float = 1.0
var _obs_hit_flash_timer: float = 0.0
var _obs_hit_flash_color: Color = Color.WHITE

var obstacles: Array = []
var coins_arr: Array = []
var echo_pulses: Array = []
var particles: Array = []
var dash_trails: Array = []
var checkpoints: Array = []
var landmarks: Array = []
var checkpoints_passed: int = 0
var menu_buttons: Array = []
var pause_buttons: Array = []
var win_buttons: Array = []

var _story_slide := StorySlideshow.new()
var _boss_fight := BossFight.new()
var _boss_ai := BossAi.new()
var _boss_screen_shake: float = 0.0
var _dash_echo_burst_timer: float = 0.0
var _boss_dash_echo_hint_timer: float = 0.0
var _story_gate_consumed: bool = false
var _story_to_boss_fade: float = 0.0
var _story_last_placed: int = 0
var _pause_return_state: GameState = GameState.PLAYING

var spawned_up_to: float = 0.0
var heartbeat_shake: float = 0.0
var music_enabled: bool = true
var threat_audio_enabled: bool = true
var mouse: Dictionary = {"x": 0.0, "y": 0.0, "clicked": false}

const SETTINGS_PATH := "user://settings.cfg"
var _rebind_action: String = ""

var _id_counter: int = 0
var _last_time: float = 0.0
var _touch_start_x: float = 0.0
var _touch_start_y: float = 0.0
var _threat_audio := ThreatAudio.new()
var _mono_font: Font
var _play_hint_timer: float = 0.0
var _shout_hint_timer: float = 0.0
const _HUD_HINT_DURATION := 5.0

const SPRITE_GRID := 8
const SPRITE_ANIM_FPS := 10.0
const SPRITE_DIR_MAP := [2, 1, 0, 7, 6, 5, 4, 3]

var _tex_player: Texture2D = preload("res://assets/sprites/mainPlayer.png")
var _tex_enemy: Texture2D = preload("res://assets/sprites/enemy.png")
var _tex_deaddirt: Texture2D = preload("res://assets/environment/deaddirt.png")
var _tex_menu: Texture2D
var _tex_coin: Texture2D = preload("res://assets/ui/coin.png")
var _tex_obstacles := {
	"tree": preload("res://assets/obstacles/tree.png"),
	"rock": preload("res://assets/obstacles/rock.png"),
	"thorn": preload("res://assets/obstacles/thorn.png"),
	"bush": preload("res://assets/obstacles/bush.png"),
}

const GAME_FONT: Font = preload("res://assets/fonts/MrPixel.ttf")


var _player_face_dir: int = 0
var _enemy_sprite_dir := 0
var _player_anim_time := 0.0
var _dash_anim_time := 0.0
var _enemy_anim_time := 0.0
var _player_sprite_moving := false
var _monster_trap_cooldown := 0.0


func _setup_game_font() -> void:
	var font := GAME_FONT.duplicate() as FontFile
	if font == null:
		_mono_font = GAME_FONT
		return
	var fallback := SystemFont.new()
	fallback.font_names = PackedStringArray(["Segoe UI Emoji", "Segoe UI Symbol", "Segoe UI", "Arial"])
	font.fallbacks = [fallback]
	_mono_font = font


func _ready() -> void:
	InputSetup.apply()
	_setup_game_font()
	_setup_checkpoints()
	_init_zone_state()
	_last_time = GameConstants.now_ms()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	grab_focus()
	var music_btn := get_node_or_null("UI/MusicButton")
	if music_btn:
		music_btn.focus_mode = Control.FOCUS_NONE
		music_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_load_settings()
	start()
	music_changed.emit(music_enabled)


func _exit_tree() -> void:
	destroy()


func start() -> void:
	_ensure_menu_texture()
	_attach_input()
	_threat_audio.start(self)
	set_process(true)


func _ensure_menu_texture() -> void:
	if _tex_menu != null:
		return
	if ResourceLoader.exists("res://assets/ui/menu.png"):
		_tex_menu = load("res://assets/ui/menu.png") as Texture2D


func destroy() -> void:
	_save_settings()
	_detach_input()
	_stop_music()
	_threat_audio.stop()


func toggle_music() -> bool:
	music_enabled = !music_enabled
	if music_enabled:
		_start_music()
	else:
		_stop_music()
	music_changed.emit(music_enabled)
	_save_settings()
	return music_enabled


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	music_enabled = cfg.get_value("audio", "music", true)
	threat_audio_enabled = cfg.get_value("audio", "threat", true)
	high_score = float(cfg.get_value("progress", "high_score", 0.0))
	total_coins = int(cfg.get_value("progress", "total_coins", 0))
	upgrade_levels = MarketUpgrades.load_levels_from_config(cfg)
	InputSetup.apply_from_config(cfg)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "music", music_enabled)
	cfg.set_value("audio", "threat", threat_audio_enabled)
	cfg.set_value("progress", "high_score", high_score)
	cfg.set_value("progress", "total_coins", total_coins)
	MarketUpgrades.save_levels_to_config(cfg, upgrade_levels)
	InputSetup.save_to_config(cfg)
	cfg.save(SETTINGS_PATH)


func _reset_key_bindings() -> void:
	InputSetup.apply()
	_rebind_action = ""
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	InputSetup.reset_keys_in_config(cfg)
	cfg.set_value("audio", "music", music_enabled)
	cfg.set_value("audio", "threat", threat_audio_enabled)
	cfg.set_value("progress", "high_score", high_score)
	cfg.set_value("progress", "total_coins", total_coins)
	MarketUpgrades.save_levels_to_config(cfg, upgrade_levels)
	cfg.save(SETTINGS_PATH)


func _upgrade_echo_max_range() -> float:
	return MarketUpgrades.echo_max_range(int(upgrade_levels.get("echo_range", 0)))


func _upgrade_dash_cooldown() -> float:
	if state == GameState.BOSS:
		return GameConstants.DASH_COOLDOWN
	return MarketUpgrades.dash_cooldown(int(upgrade_levels.get("stamina", 0)))


func _boss_echo_cooldown_ms() -> float:
	return GameConstants.ECHO_COOLDOWN_MS


func _effective_echo_cooldown_ms() -> float:
	if state == GameState.BOSS:
		return _boss_echo_cooldown_ms()
	return _upgrade_echo_cooldown_ms()


func _upgrade_danger_decay() -> float:
	return MarketUpgrades.danger_decay_rate(int(upgrade_levels.get("calm_mind", 0)))


func _upgrade_echo_cooldown_ms() -> float:
	return MarketUpgrades.echo_cooldown_ms(int(upgrade_levels.get("echo_flow", 0)))


func _upgrade_reveal_duration_ms() -> float:
	return MarketUpgrades.reveal_duration_ms(int(upgrade_levels.get("clear_sight", 0)))


func _upgrade_monster_slow_mult() -> float:
	return MarketUpgrades.monster_slow_mult(int(upgrade_levels.get("shadow_step", 0)))


func _init_zone_state() -> void:
	current_zone_index = 0
	var zone: Dictionary = WorldZones.ZONES[0]
	_zone_tint = WorldZones.zone_tint(zone)


func _update_zone_state() -> void:
	var zi := WorldZones.zone_index_for_wy(player_wy)
	if zi == current_zone_index:
		return
	current_zone_index = zi
	var zone: Dictionary = WorldZones.ZONES[zi]
	_zone_tint = WorldZones.zone_tint(zone)
	checkpoint_msg = str(zone["name"])
	checkpoint_msg_timer = 2.8
	checkpoint_msg_is_zone = true


func _current_zone() -> Dictionary:
	return WorldZones.ZONES[current_zone_index] as Dictionary


func _buy_upgrade(upgrade_id: String) -> bool:
	var entry: Dictionary = MarketUpgrades.get_entry(upgrade_id)
	if entry.is_empty():
		return false
	var level: int = int(upgrade_levels.get(upgrade_id, 0))
	if level >= int(entry["max_level"]):
		return false
	var cost: int = MarketUpgrades.cost_for(upgrade_id, level)
	if total_coins < cost:
		return false
	total_coins -= cost
	upgrade_levels[upgrade_id] = level + 1
	_save_settings()
	return true


func _start_music() -> void:
	if not music_enabled:
		return
	BgmPlayer.play_music()


func _stop_music() -> void:
	BgmPlayer.stop_music()


func _pause_music() -> void:
	if music_enabled:
		BgmPlayer.set_paused(true)


func _resume_music() -> void:
	if music_enabled:
		BgmPlayer.set_paused(false)


func _attach_input() -> void:
	pass


func _detach_input() -> void:
	pass


func _pointer_pos() -> Vector2:
	if not is_inside_tree():
		return Vector2(mouse["x"], mouse["y"])
	var local: Vector2 = get_local_mouse_position()
	var cw := maxf(size.x, 1.0)
	var ch := maxf(size.y, 1.0)
	return Vector2(
		local.x / cw * GameConstants.CANVAS_W,
		local.y / ch * GameConstants.CANVAS_H
	)


func _event_pos(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return _pointer_pos()
	if event is InputEventScreenTouch:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var cw := maxf(size.x, 1.0)
		var ch := maxf(size.y, 1.0)
		return Vector2(local.x / cw * GameConstants.CANVAS_W, local.y / ch * GameConstants.CANVAS_H)
	return Vector2(mouse["x"], mouse["y"])


func _movement_vector() -> Vector2:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return Vector2(dir.x, -dir.y)


func _facing_to_move_vector(face_row: int) -> Vector2:
	match face_row:
		0: return Vector2(0.0, -1.0)
		1: return Vector2(0.0, 1.0)
		2: return Vector2(1.0, 0.0)
		3: return Vector2(-1.0, 0.0)
		4: return Vector2(1.0, -1.0).normalized()
		5: return Vector2(-1.0, -1.0).normalized()
		6: return Vector2(1.0, 1.0).normalized()
		7: return Vector2(-1.0, 1.0).normalized()
		_: return Vector2(0.0, 1.0)


func _try_start_dash(mvx: float, mvy: float, moving: bool) -> void:
	if state == GameState.BOSS and _boss_fight.is_movement_locked():
		return
	if dash_time_left > 0.0 or dash_cooldown > 0.0:
		return
	if not Input.is_action_just_pressed("sprint"):
		return
	if state == GameState.BOSS and _can_trigger_dash_echo():
		_execute_dash_echo(mvx, mvy, moving)
		return
	var dir := Vector2(mvx, mvy)
	if not moving:
		dir = _facing_to_move_vector(_player_face_dir)
	else:
		dir = dir.normalized()
	dash_dir = dir
	dash_time_left = GameConstants.DASH_DURATION
	dash_cooldown = _upgrade_dash_cooldown()
	_dash_anim_time = 0.0
	_spawn_dash_fx()
	_spawn_dash_trail_puff(0.95)
	SfxPlayer.play("dash")


func _dash_echo_charge_t() -> float:
	return minf(echo_hold_duration / GameConstants.ECHO_HOLD_MAX, 1.0)


func _can_trigger_dash_echo() -> bool:
	if not echo_held:
		return false
	if _dash_echo_charge_t() < GameConstants.BOSS_DASH_ECHO_CHARGE_MIN:
		return false
	return _boss_fight.dash_echo_ready()


func _execute_dash_echo(mvx: float, mvy: float, moving: bool) -> void:
	echo_held = false
	echo_hold_duration = 0.0
	_boss_fight.activate_dash_echo()
	_boss_fight.apply_boss_damage(GameConstants.boss_dash_echo_damage())
	_activate_dash_echo_fx()
	_fire_dash_echo_wave()
	_boss_screen_shake = 0.32
	var dir := Vector2(mvx, mvy)
	if not moving:
		dir = _facing_to_move_vector(_player_face_dir)
	else:
		dir = dir.normalized()
	dash_dir = dir
	dash_time_left = GameConstants.DASH_DURATION
	dash_cooldown = _upgrade_dash_cooldown()
	_dash_anim_time = 0.0
	_spawn_dash_fx()
	_spawn_dash_trail_puff(1.2)


func _spawn_dash_trail_puff(size_mult: float = 1.0) -> void:
	var back_off := 10.0 + randf() * 8.0
	dash_trails.append({
		"wx": player_wx - dash_dir.x * back_off,
		"wy": player_wy - dash_dir.y * back_off,
		"life": GameConstants.DASH_TRAIL_LIFE,
		"max_life": GameConstants.DASH_TRAIL_LIFE,
		"size": GameConstants.DASH_TRAIL_SIZE * size_mult * randf_range(0.85, 1.15),
		"drift_x": -dash_dir.x * randf_range(8.0, 22.0),
		"drift_y": -dash_dir.y * randf_range(8.0, 22.0),
	})


func _spawn_dash_trail_burst() -> void:
	for _i in range(3):
		_spawn_dash_trail_puff(randf_range(0.85, 1.05))


func _spawn_dash_fx() -> void:
	var pos := _w2s(player_wx, player_wy)
	for _i in range(10):
		var a := atan2(dash_dir.y, dash_dir.x) + randf_range(-0.55, 0.55)
		var s := 90.0 + randf() * 110.0
		particles.append({
			"x": pos.x, "y": pos.y,
			"vx": cos(a) * s, "vy": sin(a) * s,
			"life": 0.22 + randf() * 0.18, "max_life": 0.4,
			"color": "#00f5ff", "size": 2.5 + randf() * 3.0,
		})


func _in_grace_zone() -> bool:
	return player_wy < GameConstants.GRACE_ZONE_WY


func _play_echo_sfx(charge_t: float) -> void:
	SfxPlayer.play_echo_charge(charge_t)


func _play_coin_sfx() -> void:
	SfxPlayer.play("coin")


func _play_ui_click() -> void:
	SfxPlayer.play("click", 0.85)


func _state_name() -> String:
	match state:
		GameState.MENU: return "menu"
		GameState.PLAYING: return "playing"
		GameState.PAUSED: return "paused"
		GameState.STORY: return "story"
		GameState.BOSS: return "boss"
		GameState.WIN: return "win"
		GameState.DEAD: return "dead"
		GameState.MARKET: return "market"
		GameState.SETTINGS: return "settings"
		_: return "?"


func _on_mouse_move(pos: Vector2) -> void:
	mouse["x"] = pos.x
	mouse["y"] = pos.y


func _on_mouse_click(pos: Vector2) -> void:
	mouse["x"] = pos.x
	mouse["y"] = pos.y
	mouse["clicked"] = true


func _on_touch_start(pos: Vector2) -> void:
	_touch_start_x = pos.x
	_touch_start_y = pos.y
	mouse["x"] = pos.x
	mouse["y"] = pos.y
	if state in [GameState.PLAYING, GameState.BOSS]:
		_start_echo_charge()


func _on_touch_end(pos: Vector2) -> void:
	mouse["x"] = pos.x
	mouse["y"] = pos.y
	mouse["clicked"] = true
	if state in [GameState.PLAYING, GameState.BOSS]:
		_release_echo_charge()


func _gui_input(event: InputEvent) -> void:
	grab_focus()
	if event is InputEventMouseMotion:
		_on_mouse_move(_event_pos(event))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_mouse_click(_event_pos(event))
	elif event is InputEventScreenTouch:
		if event.pressed:
			_on_touch_start(_event_pos(event))
		else:
			_on_touch_end(_event_pos(event))
	elif event is InputEventKey:
		if event.pressed and not event.echo:
			_handle_key_pressed(event)
		elif not event.pressed:
			_handle_key_released(event)


func _is_escape_key(event: InputEventKey) -> bool:
	return event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE


func _on_escape_pressed() -> void:
	match state:
		GameState.PLAYING, GameState.BOSS:
			_pause_game()
		GameState.PAUSED:
			_resume_game()
		GameState.STORY:
			_story_slide.advance()
		GameState.SETTINGS:
			if _rebind_action != "":
				_rebind_action = ""
			else:
				state = GameState.MENU
				_rebind_action = ""
		GameState.MARKET:
			state = GameState.MENU


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not _is_escape_key(event):
		return
	if state in [GameState.PLAYING, GameState.PAUSED, GameState.BOSS, GameState.STORY, GameState.SETTINGS, GameState.MARKET]:
		_on_escape_pressed()
		get_viewport().set_input_as_handled()


func _handle_key_pressed(event: InputEventKey) -> void:
	match state:
		GameState.MENU:
			if event.is_action("echo") or event.is_action("retry"):
				_reset_game(true)
		GameState.PLAYING, GameState.BOSS:
			if event.is_action("echo"):
				_start_echo_charge()
		GameState.WIN:
			if event.is_action("retry"):
				_reset_game(false)
			elif event.is_action("menu_key"):
				state = GameState.MENU
		GameState.DEAD:
			if event.is_action("retry"):
				_reset_game(false)
			elif event.is_action("menu_key"):
				state = GameState.MENU
		GameState.SETTINGS:
			if _rebind_action != "":
				if _is_escape_key(event):
					_rebind_action = ""
					return
				var key := event.physical_keycode
				if key != KEY_NONE and key != 0:
					InputSetup.bind_key(_rebind_action, key)
					_rebind_action = ""
					_save_settings()
				return
			if _is_escape_key(event) or event.is_action("ui_back"):
				_on_escape_pressed()
		GameState.MARKET:
			if _is_escape_key(event) or event.is_action("ui_back") or event.is_action("retry"):
				state = GameState.MENU


func _handle_key_released(event: InputEventKey) -> void:
	if event.is_action("echo") and state in [GameState.PLAYING, GameState.BOSS]:
		_release_echo_charge()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		grab_focus()


func _process(_delta: float) -> void:
	if is_inside_tree():
		var ptr := _pointer_pos()
		mouse["x"] = ptr.x
		mouse["y"] = ptr.y
	_handle_action_input()

	var time := GameConstants.now_ms()
	var dt: float = minf((time - _last_time) / 1000.0, 0.05)
	_last_time = time
	if state in [GameState.PLAYING, GameState.PAUSED, GameState.BOSS]:
		if _play_hint_timer > 0.0:
			_play_hint_timer = maxf(0.0, _play_hint_timer - dt)
		if _shout_hint_timer > 0.0:
			_shout_hint_timer = maxf(0.0, _shout_hint_timer - dt)
	if state in [GameState.PLAYING, GameState.BOSS]:
		_update(dt, time)
	elif state == GameState.STORY:
		_update_story(dt)
		_threat_audio.update(dt, 0.0, 0.0)
	elif state == GameState.PAUSED:
		_threat_audio.update(dt, 0.0, 0.0)
	elif state == GameState.WIN:
		_handle_win_input()
		_threat_audio.update(dt, 0.0, 0.0)
	elif state == GameState.DEAD:
		_handle_dead_input()
		_threat_audio.update(dt, 0.0, 0.0)
	else:
		_threat_audio.update(dt, 0.0, 0.0)
	_render(time)
	mouse["clicked"] = false


func _handle_action_input() -> void:
	match state:
		GameState.MENU:
			if Input.is_action_just_pressed("echo") or Input.is_action_just_pressed("retry"):
				_reset_game(true)
		GameState.PLAYING:
			if Input.is_action_just_pressed("echo"):
				_start_echo_charge()
			if Input.is_action_just_released("echo"):
				_release_echo_charge()
		GameState.BOSS:
			if Input.is_action_just_pressed("echo"):
				_start_echo_charge()
			if Input.is_action_just_released("echo"):
				_release_echo_charge()
		GameState.SETTINGS:
			if _rebind_action == "" and Input.is_action_just_pressed("ui_back"):
				state = GameState.MENU
		GameState.MARKET:
			if Input.is_action_just_pressed("ui_back") or Input.is_action_just_pressed("retry"):
				state = GameState.MENU


func _handle_dead_input() -> void:
	if Input.is_action_pressed("retry"):
		_reset_game(false)
	if Input.is_action_just_pressed("menu_key"):
		state = GameState.MENU


func _pause_game() -> void:
	if state not in [GameState.PLAYING, GameState.BOSS]:
		return
	_pause_return_state = state
	_cancel_echo_charge()
	state = GameState.PAUSED
	_pause_music()


func _resume_game() -> void:
	if state != GameState.PAUSED:
		return
	state = _pause_return_state
	_resume_music()


func _quit_to_menu_from_pause() -> void:
	if state != GameState.PAUSED:
		return
	_cancel_echo_charge()
	if score > high_score:
		high_score = score
		_save_settings()
	BgmPlayer.set_paused(false)
	_stop_music()
	state = GameState.MENU


func _cancel_echo_charge() -> void:
	echo_held = false
	echo_hold_duration = 0.0


func _enter_story() -> void:
	if state != GameState.PLAYING or _story_gate_consumed:
		return
	_story_gate_consumed = true
	_cancel_echo_charge()
	checkpoint_msg = ""
	checkpoint_msg_timer = 0.0
	checkpoint_msg_is_zone = false
	_story_slide.start()
	_story_to_boss_fade = 0.0
	_story_last_placed = 0
	state = GameState.STORY
	BgmPlayer.fade_to(0.12, 0.7)


func _play_story_scene_sfx(scene_index: int) -> void:
	match scene_index:
		3:
			SfxPlayer.play("story_trex", 1.0)
		4:
			SfxPlayer.play("story_monster_roar", 1.0)
		7:
			SfxPlayer.play_echo_charge(1.0, 2.0, true)


func _update_story(dt: float) -> void:
	_story_slide.update(dt)
	var placed_n: int = _story_slide.placed_count()
	if placed_n > _story_last_placed:
		_play_story_scene_sfx(placed_n - 1)
		_story_last_placed = placed_n
	if not _story_slide.is_throwing() and (mouse["clicked"] or Input.is_action_just_pressed("echo") or Input.is_action_just_pressed("retry")):
		_story_slide.advance()
	if _story_slide.is_finished():
		_story_to_boss_fade += dt
		if _story_to_boss_fade >= GameConstants.STORY_TO_BOSS_FADE_SEC:
			_on_story_finished()


func _on_story_finished() -> void:
	_play_boss_intro_sfx()
	_start_boss_fight()


func _restore_music_after_boss() -> void:
	if music_enabled:
		BgmPlayer.play_gameplay_music(0.6, 0.35)


func _start_boss_fight() -> void:
	_boss_fight.start(player_wy)
	_boss_ai.reset()
	obstacles.clear()
	for rock in _boss_fight.build_arena_rocks(player_wx, player_wy):
		obstacles.append(rock)
	var spawn: Dictionary = _boss_fight.spawn_monster(player_wx, player_wy)
	monster_wx = float(spawn["wx"])
	monster_wy = float(spawn["wy"])
	monster_awake = true
	monster_seen_on_screen = false
	danger_value = GameConstants.DANGER_MAX
	camera_wy = player_wy
	_boss_screen_shake = 0.0
	_dash_echo_burst_timer = 0.0
	_boss_dash_echo_hint_timer = 8.0
	state = GameState.BOSS
	_pause_return_state = GameState.BOSS
	checkpoint_msg = "SON YANKI"
	checkpoint_msg_color = Color("#ff3030")
	checkpoint_msg_timer = GameConstants.BOSS_INTRO_DURATION
	checkpoint_msg_is_zone = false
	BgmPlayer.call_deferred("play_boss_music", 0.0)


func _end_boss_victory() -> void:
	_boss_fight.reset()
	_boss_ai.reset()
	monster_awake = false
	echo_pulses.clear()
	if score > high_score:
		high_score = score
	_save_settings()
	state = GameState.WIN
	if music_enabled:
		BgmPlayer.play_gameplay_music(0.8, 0.55)
	SfxPlayer.play("monster_death")


func _activate_dash_echo_fx() -> void:
	last_echo_time = GameConstants.now_ms()
	_dash_echo_burst_timer = 1.15
	_spawn_dash_echo_particles()
	SfxPlayer.play("magic")
	BgmPlayer.fade_to(1.0, 0.15)


func _spawn_dash_echo_particles() -> void:
	var pos := _w2s(player_wx, player_wy)
	for i in range(36):
		var angle := (float(i) / 36.0) * TAU + randf_range(-0.12, 0.12)
		var spd := 160.0 + randf() * 220.0
		particles.append({
			"x": pos.x, "y": pos.y,
			"vx": cos(angle) * spd, "vy": sin(angle) * spd,
			"life": 0.75 + randf() * 0.55, "max_life": 1.3,
			"color": "#ffd040" if i % 3 != 0 else "#fff6a8",
			"size": 5.0 + randf() * 6.0,
		})


func _fire_dash_echo_wave() -> void:
	var now := GameConstants.now_ms()
	echo_pulses.append({
		"id": _next_id(),
		"origin_wx": player_wx,
		"origin_wy": player_wy,
		"follows_player": false,
		"prev_radius": 0.0,
		"golden_echo": true,
		"max_radius": GameConstants.BOSS_DASH_ECHO_BURST_RADIUS,
		"wave_speed": GameConstants.BOSS_DASH_ECHO_WAVE_SPEED,
		"start_time": now,
		"charge_t": 1.0,
		"hit_boss": true,
	})


func _update_boss_combat(dt: float, now: float) -> void:
	if _boss_fight.in_intro():
		return
	if _boss_fight.is_player_dead():
		state = GameState.DEAD
		_restore_music_after_boss()
		if score > high_score:
			high_score = score
		_save_settings()
		return
	if _boss_fight.is_won():
		_end_boss_victory()
		return
	if _boss_fight.is_cinematic() and _boss_fight.cinematic_timer < dt * 2.0:
		BgmPlayer.fade_to(0.0, 0.8)

	var dash_invuln := dash_time_left > 0.0
	var player_vx := (player_wx - _prev_player_wx) / maxf(dt, 0.001)
	var player_vy := (player_wy - _prev_player_wy) / maxf(dt, 0.001)

	if not _boss_fight.is_cinematic() and _boss_fight.boss_hp > 0.0:
		var mon_dist := GameConstants.hypot(player_wx - monster_wx, player_wy - monster_wy)
		var ai_result: Dictionary = _boss_ai.update(
			dt,
			monster_wx,
			monster_wy,
			player_wx,
			player_wy,
			player_vx,
			player_vy,
			_boss_fight.phase,
			_boss_fight.in_phase_transition,
			_boss_fight.boss_hp <= 0.0,
			_boss_fight,
			_boss_chase_speed(mon_dist, _boss_fight.phase),
			_boss_chase_predict(mon_dist)
		)
		monster_wx = float(ai_result["wx"])
		monster_wy = float(ai_result["wy"])
		_enemy_sprite_dir = int(ai_result["sprite_dir"])
		_enemy_anim_time += dt

		if _boss_fight.in_phase_transition and not _boss_fight.phase_roar_played:
			_boss_fight.phase_roar_played = true
			_boss_screen_shake = 0.35
			SfxPlayer.play("magic", 0.9)

		if _boss_fight.meteor_mode and not _boss_fight.meteor_intro_done:
			_boss_fight.meteor_intro_done = true
			_boss_ai.begin_meteor_assault()
			_boss_screen_shake = 0.45
			SfxPlayer.play("monster_close", 0.85)

		if _boss_fight.meteor_anchored:
			_boss_fight.try_spawn_meteor(player_wx, player_wy, player_vx, player_vy)

		if _boss_ai.check_swipe_hit(monster_wx, monster_wy, player_wx, player_wy):
			var hp_before := _boss_fight.player_hp
			if _boss_fight.apply_player_damage(GameConstants.BOSS_SWIPE_DAMAGE, dash_invuln, "YUMRUK"):
				SfxPlayer.play("pain")
				state = GameState.DEAD
				_restore_music_after_boss()
				_save_settings()
				return
			if _boss_fight.player_hp < hp_before:
				SfxPlayer.play("pain", 0.9)
		if _boss_ai.check_charge_hit(monster_wx, monster_wy, player_wx, player_wy):
			var hp_before_charge := _boss_fight.player_hp
			if _boss_fight.apply_player_damage(GameConstants.BOSS_CHARGE_DAMAGE, dash_invuln, "HÜCUM"):
				SfxPlayer.play("pain")
				state = GameState.DEAD
				_restore_music_after_boss()
				_save_settings()
				return
			if _boss_fight.player_hp < hp_before_charge:
				SfxPlayer.play("pain", 0.9)

	if _boss_fight.check_projectile_hit(player_wx, player_wy, dash_invuln, obstacles):
		SfxPlayer.play("pain")
		state = GameState.DEAD
		_restore_music_after_boss()
		_save_settings()
		return

	_update_boss_echo_damage(now)

	if _boss_screen_shake > 0.0:
		_boss_screen_shake = maxf(0.0, _boss_screen_shake - dt)


func _update_boss_echo_damage(now: float) -> void:
	if _boss_fight.boss_hp <= 0.0 or _boss_fight.in_phase_transition:
		return
	for wave in echo_pulses:
		if wave.get("hit_boss", false):
			continue
		_sync_echo_origin(wave)
		var bounds: Dictionary = _echo_wave_bounds(wave, now)
		var outer_r: float = float(bounds["outer_r"])
		var prev_r: float = float(wave.get("prev_radius", 0.0))
		var dist: float = GameConstants.hypot(
			monster_wx - float(wave["origin_wx"]),
			monster_wy - float(wave["origin_wy"])
		)
		if prev_r < dist + GameConstants.BOSS_HIT_RADIUS and outer_r >= dist - GameConstants.BOSS_HIT_RADIUS:
			var charge_t: float = float(wave.get("charge_t", 0.5))
			_boss_fight.apply_boss_damage(GameConstants.boss_echo_damage(charge_t))
			wave["hit_boss"] = true
		wave["prev_radius"] = outer_r


func _handle_win_input() -> void:
	if Input.is_action_pressed("retry"):
		_reset_game(false)
	if Input.is_action_just_pressed("menu_key"):
		state = GameState.MENU


func _play_boss_intro_sfx() -> void:
	SfxPlayer.play("monster_close")


func _setup_checkpoints() -> void:
	checkpoints.clear()
	for i in range(1, 21):
		checkpoints.append({
			"wy": i * GameConstants.CHECKPOINT_INTERVAL,
			"label": "%dm" % (i * 500),
			"triggered": false,
		})
	landmarks = CheckpointLandmarks.build_landmark_list()


func _monster_progress_speed_mult() -> float:
	var km := player_wy / 1000.0
	return 1.0 + minf(
		km * GameConstants.MONSTER_DISTANCE_SPEED_STEP,
		GameConstants.MONSTER_DISTANCE_SPEED_CAP
	)


func _player_flawless_sustained_speed() -> float:
	var dash_cd := _upgrade_dash_cooldown()
	var cycle := GameConstants.DASH_DURATION + dash_cd
	return (GameConstants.DASH_DISTANCE + GameConstants.WALK_SPEED * dash_cd) / maxf(cycle, 0.001)


func _monster_chase_speed_cap() -> float:
	return _player_flawless_sustained_speed() * GameConstants.MONSTER_FLAWLESS_ESCAPE_RATIO


func _monster_chase_max_speed() -> float:
	var pressure: float = float(checkpoints_passed) * GameConstants.MONSTER_CHASE_PRESSURE_PER_CP
	return GameConstants.MONSTER_CHASE_MAX_SPD * (1.0 + pressure) * _monster_progress_speed_mult()


func _boss_chase_speed(mon_dist: float, phase: int) -> float:
	var danger_t := danger_value / GameConstants.DANGER_MAX
	var urgency := clampf(
		(danger_t - GameConstants.DANGER_MONSTER_WAKE_T) / (1.0 - GameConstants.DANGER_MONSTER_WAKE_T),
		0.0, 1.0
	)
	var cap := _monster_chase_speed_cap()
	var progress_mult := _monster_progress_speed_mult()
	var zone_mult := WorldZones.monster_speed_mult(_current_zone()) * _upgrade_monster_slow_mult()
	var urgency_floor := minf(0.55, maxf(0.0, (progress_mult - 1.0) * 0.45))
	var chase_urgency := lerpf(urgency_floor, 1.0, urgency)
	var raw_max := _monster_chase_max_speed() * zone_mult
	var raw_min := GameConstants.MONSTER_CHASE_MIN_SPD * progress_mult * zone_mult
	var scaled_max := minf(raw_max, cap)
	var scaled_min := minf(raw_min, scaled_max)
	var mon_spd := lerpf(scaled_min, scaled_max, chase_urgency)
	mon_spd = minf(mon_spd, cap)
	if mon_dist < 140.0:
		mon_spd *= lerpf(0.5, 1.0, mon_dist / 140.0)
	var phase_cap := GameConstants.BOSS_CHASE_SPEED_P2 if phase == 2 else GameConstants.BOSS_CHASE_SPEED_P1
	return clampf(maxf(mon_spd, phase_cap * 0.8), GameConstants.MONSTER_CHASE_MIN_SPD * 0.75, phase_cap)


func _boss_chase_predict(mon_dist: float) -> float:
	return clampf(mon_dist / 450.0, 0.2, 1.0) * GameConstants.MONSTER_PREDICT_SEC


func _boss_echo_offense_active(now: float) -> bool:
	if _boss_fight.dash_echo_active:
		return true
	if echo_held:
		return true
	for wave in echo_pulses:
		if _echo_wave_alive(wave, now):
			return true
	return false


func _start_echo_charge() -> void:
	if state not in [GameState.PLAYING, GameState.BOSS]:
		return
	if state == GameState.BOSS and _boss_fight.is_input_locked():
		return
	var now := GameConstants.now_ms()
	if now - last_echo_time < _effective_echo_cooldown_ms():
		return
	if echo_held:
		return
	echo_held = true
	echo_hold_start = now
	echo_hold_duration = 0.0


func _release_echo_charge() -> void:
	if not echo_held or state not in [GameState.PLAYING, GameState.BOSS]:
		return
	var charge_t: float = minf(echo_hold_duration / GameConstants.ECHO_HOLD_MAX, 1.0)
	echo_held = false
	echo_hold_duration = 0.0
	if charge_t < GameConstants.ECHO_CHARGE_MIN:
		return
	_fire_echo(charge_t)


func _fire_echo(charge_t: float, from_landmark: bool = false) -> void:
	var now := GameConstants.now_ms()
	if not from_landmark and now - last_echo_time < _effective_echo_cooldown_ms():
		return
	last_echo_time = now
	var base_radius: float = GameConstants.ECHO_BASE_RANGE * (
		_upgrade_echo_max_range() / GameConstants.ECHO_MAX_RANGE
	)
	var charge_frac: float = lerpf(GameConstants.ECHO_RADIUS_MIN_FRAC, 1.0, charge_t)
	var max_radius: float = base_radius * charge_frac * GameConstants.ECHO_RADIUS_SCALE
	if from_landmark:
		max_radius *= 1.15

	echo_pulses.append({
		"id": _next_id(),
		"origin_wx": player_wx,
		"origin_wy": player_wy,
		"follows_player": not from_landmark,
		"prev_radius": 0.0,
		"radius": 0.0,
		"max_radius": max_radius,
		"start_time": now,
		"charge_t": charge_t,
		"hit_boss": false,
	})
	if not from_landmark:
		if state != GameState.BOSS:
			if charge_t >= GameConstants.ECHO_SHOUT_MONSTER_WAKE_T:
				danger_value = minf(
					GameConstants.DANGER_MAX,
					danger_value + GameConstants.ECHO_DANGER * charge_t
				)
				danger_value = minf(
					GameConstants.DANGER_MAX,
					maxf(danger_value, GameConstants.DANGER_MAX * GameConstants.ECHO_SHOUT_MONSTER_WAKE_T)
				)
				if not _in_grace_zone():
					_wake_monster_from_shout()
		_play_echo_sfx(charge_t)
	_spawn_echo_particles()


func _wake_monster_from_shout() -> void:
	if not monster_awake:
		monster_wx = player_wx
		monster_wy = player_wy - GameConstants.MONSTER_WAKE_SPAWN_DIST
		monster_seen_on_screen = false
		monster_awake = true


func _next_id() -> int:
	_id_counter += 1
	return _id_counter


func _spawn_echo_particles() -> void:
	var pos := _w2s(player_wx, player_wy)
	for i in range(16):
		var angle := (float(i) / 16.0) * TAU
		var spd := 90.0 + randf() * 60.0
		particles.append({
			"x": pos.x, "y": pos.y,
			"vx": cos(angle) * spd, "vy": sin(angle) * spd,
			"life": 0.5, "max_life": 0.5,
			"color": "#00f5ff", "size": 3.0,
		})


func _reset_game(from_menu: bool = false) -> void:
	state = GameState.PLAYING
	score = 0.0
	coins = 0
	player_wx = GameConstants.CANVAS_W / 2.0
	player_wy = 0.0
	camera_wy = 0.0
	monster_wx = GameConstants.CANVAS_W / 2.0
	monster_wy = -GameConstants.MONSTER_START_DIST
	monster_awake = false
	monster_seen_on_screen = false
	monster_revealed_until = 0.0
	_prev_player_wx = player_wx
	_prev_player_wy = player_wy
	dash_cooldown = 0.0
	dash_time_left = 0.0
	dash_dir = Vector2.ZERO
	_dash_anim_time = 0.0
	danger_value = 0.0
	obs_hit_slow_timer = 0.0
	obs_hit_slow_mult = 1.0
	_obs_hit_flash_timer = 0.0
	echo_held = false
	echo_hold_duration = 0.0
	_player_face_dir = 0
	_player_anim_time = 0.0
	_monster_trap_cooldown = 0.0
	obstacles.clear()
	coins_arr.clear()
	echo_pulses.clear()
	particles.clear()
	dash_trails.clear()
	spawned_up_to = 0.0
	heartbeat_shake = 0.0
	if from_menu:
		_play_hint_timer = _HUD_HINT_DURATION
		_shout_hint_timer = _HUD_HINT_DURATION
	else:
		_play_hint_timer = 0.0
		_shout_hint_timer = 0.0
	_story_slide.reset()
	_story_last_placed = 0
	_boss_fight.reset()
	_boss_ai.reset()
	_boss_screen_shake = 0.0
	_story_gate_consumed = false
	_story_to_boss_fade = 0.0
	_pause_return_state = GameState.PLAYING
	checkpoint_msg = ""
	checkpoint_msg_timer = 0.0
	checkpoint_msg_is_zone = false
	checkpoints_passed = 0
	_init_zone_state()
	_setup_checkpoints()
	_generate_chunks_ahead()
	if music_enabled:
		_start_music()
	else:
		_stop_music()
	music_changed.emit(music_enabled)


func _w2s(wx: float, wy: float) -> Vector2:
	return Vector2(wx, GameConstants.CANVAS_H * 0.62 - (wy - camera_wy))


func _world_dir_to_screen(world_dir: Vector2) -> Vector2:
	if world_dir.length_squared() <= 0.0001:
		return Vector2.RIGHT
	return Vector2(world_dir.x, -world_dir.y).normalized()


const ECHO_SHRINK_TIME_MULT := 1.65
const ECHO_REVEAL_EDGE_FADE := 52.0


func _echo_expand_time(max_radius: float) -> float:
	return max_radius / GameConstants.ECHO_WAVE_SPEED


func _echo_shrink_time(max_radius: float) -> float:
	return _echo_expand_time(max_radius) * ECHO_SHRINK_TIME_MULT


func _echo_wave_speed(wave: Dictionary) -> float:
	return float(wave.get("wave_speed", GameConstants.ECHO_WAVE_SPEED))


func _echo_wave_bounds(wave: Dictionary, now: float) -> Dictionary:
	var elapsed: float = (now - float(wave["start_time"])) / 1000.0
	var max_r: float = float(wave["max_radius"])
	if wave.get("golden_echo", false):
		var speed := _echo_wave_speed(wave)
		var expand_t: float = max_r / maxf(speed, 1.0)
		if elapsed < expand_t:
			return {
				"outer_r": speed * elapsed,
				"inner_dark_r": 0.0,
				"phase": "expand",
				"burst_alpha": 1.0,
			}
		var fade_elapsed: float = elapsed - expand_t
		if fade_elapsed < 0.75:
			return {
				"outer_r": max_r,
				"inner_dark_r": 0.0,
				"phase": "expand",
				"burst_alpha": 1.0 - fade_elapsed / 0.75,
			}
		return {"outer_r": 0.0, "inner_dark_r": max_r, "phase": "dead", "burst_alpha": 0.0}
	var expand_t: float = max_r / maxf(_echo_wave_speed(wave), 1.0)
	var shrink_t: float = _echo_shrink_time(max_r)
	if elapsed < expand_t:
		return {
			"outer_r": _echo_wave_speed(wave) * elapsed,
			"inner_dark_r": 0.0,
			"phase": "expand",
		}
	if elapsed < expand_t + shrink_t:
		var shrink_elapsed: float = elapsed - expand_t
		return {
			"outer_r": max_r,
			"inner_dark_r": max_r * (shrink_elapsed / shrink_t),
			"phase": "shrink",
		}
	return {"outer_r": 0.0, "inner_dark_r": max_r, "phase": "dead"}


func _echo_wave_radius(wave: Dictionary, now: float) -> float:
	return float(_echo_wave_bounds(wave, now)["outer_r"])


func _echo_wave_alive(wave: Dictionary, now: float) -> bool:
	var elapsed: float = (now - float(wave["start_time"])) / 1000.0
	var max_r: float = float(wave["max_radius"])
	if wave.get("golden_echo", false):
		return elapsed < max_r / maxf(_echo_wave_speed(wave), 1.0) + 0.75
	var expand_t: float = max_r / maxf(_echo_wave_speed(wave), 1.0)
	return elapsed < expand_t + _echo_shrink_time(max_r)


func _sync_echo_origin(wave: Dictionary) -> void:
	if wave.get("follows_player", false):
		wave["origin_wx"] = player_wx
		wave["origin_wy"] = player_wy


func _any_echo_alive(now: float) -> bool:
	for wave in echo_pulses:
		if _echo_wave_alive(wave, now):
			return true
	return false


func _clear_echo_spawn_holds() -> void:
	for obs in obstacles:
		obs["echo_spawn_hold"] = false
	for c in coins_arr:
		c["echo_spawn_hold"] = false


func _echo_coverage_at(wx: float, wy: float, now: float, spawn_hold: bool = false) -> float:
	if state == GameState.BOSS and _boss_fight.full_arena_visible():
		return 1.0
	if spawn_hold and _any_echo_alive(now):
		return 0.0
	var best := 0.0
	for wave in echo_pulses:
		if not _echo_wave_alive(wave, now):
			continue
		_sync_echo_origin(wave)
		var bounds: Dictionary = _echo_wave_bounds(wave, now)
		var outer_r: float = float(bounds["outer_r"])
		var inner_dark_r: float = float(bounds["inner_dark_r"])
		if outer_r <= 0.0:
			continue
		var dist: float = GameConstants.hypot(wx - float(wave["origin_wx"]), wy - float(wave["origin_wy"]))
		if dist > outer_r or dist <= inner_dark_r:
			continue
		var outer_depth: float = outer_r - dist
		var inner_depth: float = dist - inner_dark_r
		var depth: float = minf(outer_depth, inner_depth)
		best = maxf(best, clampf(depth / ECHO_REVEAL_EDGE_FADE, 0.0, 1.0))
	return best


func _in_active_echo_radius(wx: float, wy: float, now: float) -> bool:
	return _echo_coverage_at(wx, wy, now) > 0.01


func _update(dt: float, _time: float) -> void:
	var now := GameConstants.now_ms()
	var boss_mode: bool = state == GameState.BOSS
	if boss_mode:
		_boss_fight.update(dt, obstacles)
		if _dash_echo_burst_timer > 0.0:
			_dash_echo_burst_timer = maxf(0.0, _dash_echo_burst_timer - dt)
		if _boss_dash_echo_hint_timer > 0.0:
			_boss_dash_echo_hint_timer = maxf(0.0, _boss_dash_echo_hint_timer - dt)
		if _boss_fight.is_cinematic():
			echo_pulses.clear()
		_update_boss_combat(dt, now)
		if state == GameState.DEAD or state == GameState.WIN:
			return

	var input_locked := boss_mode and _boss_fight.is_movement_locked()

	if echo_held and not input_locked:
		echo_hold_duration = minf((now - echo_hold_start) / 1000.0, GameConstants.ECHO_HOLD_MAX)
		if echo_hold_duration >= GameConstants.ECHO_HOLD_MAX:
			if boss_mode and _boss_fight.dash_echo_ready():
				echo_hold_duration = GameConstants.ECHO_HOLD_MAX
			else:
				_release_echo_charge()

	var move := Vector2.ZERO
	var mvx: float = 0.0
	var mvy: float = 0.0
	var moving: bool = false
	if not input_locked:
		move = _movement_vector()
		mvx = move.x
		mvy = move.y
		moving = move.length_squared() > 0.001
		if moving:
			move = move.normalized()
			mvx = move.x
			mvy = move.y

	if not input_locked:
		_try_start_dash(mvx, mvy, moving)

	if dash_cooldown > 0.0:
		dash_cooldown = maxf(0.0, dash_cooldown - dt)

	var dashing := dash_time_left > 0.0
	if dashing:
		dash_time_left = maxf(0.0, dash_time_left - dt)
		var dash_spd := GameConstants.DASH_DISTANCE / maxf(GameConstants.DASH_DURATION, 0.001)
		player_wx = clampf(player_wx + dash_dir.x * dash_spd * dt, GameConstants.MAP_LEFT, GameConstants.MAP_RIGHT)
		player_wy += dash_dir.y * dash_spd * dt
		_player_face_dir = PlayerSpriteFrames.facing_row_from_move(dash_dir.x, dash_dir.y)
		_player_sprite_moving = true
		_dash_anim_time += dt
		_spawn_dash_trail_puff(randf_range(0.75, 0.95))
		_resolve_dash_blocking_collision(now)
		if dash_time_left <= 0.0:
			_spawn_dash_trail_burst()
	else:
		var eff_spd: float = GameConstants.WALK_SPEED
		if obs_hit_slow_timer > 0.0:
			eff_spd *= obs_hit_slow_mult
		player_wx = clampf(player_wx + mvx * eff_spd * dt, GameConstants.MAP_LEFT, GameConstants.MAP_RIGHT)
		player_wy += mvy * eff_spd * dt
		_player_sprite_moving = moving
		if moving:
			_player_face_dir = PlayerSpriteFrames.facing_row_from_move(mvx, mvy)
			_player_anim_time += dt
		else:
			_player_anim_time = 0.0

	if boss_mode:
		player_wy = _boss_fight.clamp_player_wy(player_wy)
	camera_wy += (player_wy - camera_wy) * 9.0 * dt
	score = maxf(score, player_wy)
	_update_zone_state()
	if obs_hit_slow_timer > 0.0:
		obs_hit_slow_timer = maxf(0.0, obs_hit_slow_timer - dt)
	if _obs_hit_flash_timer > 0.0:
		_obs_hit_flash_timer = maxf(0.0, _obs_hit_flash_timer - dt)
	danger_value = maxf(0.0, danger_value - _upgrade_danger_decay() * dt)

	for wave in echo_pulses:
		_sync_echo_origin(wave)
		wave["radius"] = _echo_wave_radius(wave, now)

	echo_pulses = echo_pulses.filter(func(w): return _echo_wave_alive(w, now))
	if echo_pulses.is_empty():
		_clear_echo_spawn_holds()

	for obs in obstacles:
		if _check_obs(obs):
			if dash_time_left > 0.0 and not _obs_blocks_dash(str(obs["kind"])):
				continue
			if now - float(obs["hit_flash"]) > 400.0:
				_apply_obs_hit(obs, now)

	for c in coins_arr:
		if not c["collected"]:
			var dist: float = GameConstants.hypot(player_wx - float(c["wx"]), player_wy - float(c["wy"]))
			if dist < GameConstants.PLAYER_R + GameConstants.COIN_R:
				c["collected"] = true
				coins += 1
				total_coins += 1
				_spawn_coin_fx(c)
				_play_coin_sfx()

	var cull_y := camera_wy - GameConstants.CANVAS_H * 0.7
	obstacles = obstacles.filter(func(o): return float(o["wy"]) > cull_y)
	coins_arr = coins_arr.filter(func(c): return float(c["wy"]) > cull_y)

	for cp in checkpoints:
		if not cp["triggered"] and player_wy >= float(cp["wy"]):
			cp["triggered"] = true
			checkpoints_passed += 1
			danger_value *= GameConstants.CHECKPOINT_DANGER_RESET
			if float(cp["wy"]) < GameConstants.STORY_GATE_WY:
				checkpoint_msg = "CHECKPOINT  %s" % str(cp["label"])
				checkpoint_msg_color = Color("#00ffb0")
				checkpoint_msg_timer = 2.5
				checkpoint_msg_is_zone = false

	for lm in landmarks:
		if lm["triggered"] or player_wy < float(lm["wy"]):
			continue
		lm["triggered"] = true
		var landmark_id: String = str(lm["landmark"])
		if landmark_id == "boss_gate":
			_enter_story()
			continue
		_trigger_checkpoint_landmark(landmark_id, float(lm["wy"]))
		var lm_def: Dictionary = CheckpointLandmarks.get_def(landmark_id)
		checkpoint_msg = str(lm_def["label"])
		checkpoint_msg_color = GameConstants.color_from_hex(str(lm_def["line_color"]))
		checkpoint_msg_timer = 3.0
		checkpoint_msg_is_zone = false
	if checkpoint_msg_timer > 0.0:
		checkpoint_msg_timer -= dt

	var danger_t := danger_value / GameConstants.DANGER_MAX
	var mon_dist := GameConstants.hypot(player_wx - monster_wx, player_wy - monster_wy)

	if monster_awake and not boss_mode:
		var pvx := (player_wx - _prev_player_wx) / maxf(dt, 0.001)
		var pvy := (player_wy - _prev_player_wy) / maxf(dt, 0.001)
		var predict := clampf(mon_dist / 450.0, 0.2, 1.0) * GameConstants.MONSTER_PREDICT_SEC
		var target_wx := player_wx + pvx * predict
		var target_wy := player_wy + pvy * predict
		var urgency := clampf(
			(danger_t - GameConstants.DANGER_MONSTER_WAKE_T) / (1.0 - GameConstants.DANGER_MONSTER_WAKE_T),
			0.0, 1.0
		)
		var cap := _monster_chase_speed_cap()
		var progress_mult := _monster_progress_speed_mult()
		var zone_mult := WorldZones.monster_speed_mult(_current_zone()) * _upgrade_monster_slow_mult()
		var urgency_floor := minf(0.55, maxf(0.0, (progress_mult - 1.0) * 0.45))
		var chase_urgency := lerpf(urgency_floor, 1.0, urgency)
		var raw_max := _monster_chase_max_speed() * zone_mult
		var raw_min := GameConstants.MONSTER_CHASE_MIN_SPD * progress_mult * zone_mult
		var scaled_max := minf(raw_max, cap)
		var scaled_min := minf(raw_min, scaled_max)
		var mon_spd := lerpf(scaled_min, scaled_max, chase_urgency)
		mon_spd = minf(mon_spd, cap)
		if mon_dist < 140.0:
			mon_spd *= lerpf(0.5, 1.0, mon_dist / 140.0)
		var tx := target_wx - monster_wx
		var ty := target_wy - monster_wy
		var tl := maxf(GameConstants.hypot(tx, ty), 0.001)
		monster_wx += (tx / tl) * mon_spd * dt
		monster_wy += (ty / tl) * mon_spd * dt
		_enemy_sprite_dir = _sprite_dir_index(tx, ty)
		_enemy_anim_time += dt
		if _monster_on_screen():
			monster_seen_on_screen = true
		if monster_seen_on_screen and not _monster_on_screen() and mon_dist > GameConstants.MONSTER_ESCAPE_DIST:
			monster_awake = false
			monster_seen_on_screen = false
			monster_wx = player_wx
			monster_wy = player_wy - GameConstants.MONSTER_START_DIST

	if not boss_mode:
		_update_monster_trap_shifts(dt, danger_t, mon_dist, monster_awake)

	_prev_player_wx = player_wx
	_prev_player_wy = player_wy

	if not boss_mode and mon_dist < GameConstants.PLAYER_R + 22.0:
		SfxPlayer.play("pain")
		state = GameState.DEAD
		if score > high_score:
			high_score = score
		_save_settings()

	var threat_proximity := 0.0
	if monster_awake and monster_seen_on_screen and not boss_mode:
		threat_proximity = clampf(
			1.0 - mon_dist / GameConstants.MONSTER_WARN_DIST,
			0.0,
			1.0
		)
	if threat_audio_enabled:
		_threat_audio.update(dt, threat_proximity, danger_t)
	else:
		_threat_audio.update(dt, 0.0, 0.0)

	var i := particles.size() - 1
	while i >= 0:
		var p = particles[i]
		p["x"] = float(p["x"]) + float(p["vx"]) * dt
		p["y"] = float(p["y"]) + float(p["vy"]) * dt
		p["vy"] = float(p["vy"]) - 55.0 * dt
		p["life"] = float(p["life"]) - dt
		if float(p["life"]) <= 0.0:
			particles.remove_at(i)
		i -= 1

	for trail in dash_trails:
		trail["wx"] = float(trail["wx"]) + float(trail["drift_x"]) * dt
		trail["wy"] = float(trail["wy"]) + float(trail["drift_y"]) * dt
		trail["life"] = float(trail["life"]) - dt
	var trail_cull_y := camera_wy - GameConstants.CANVAS_H * 0.75
	dash_trails = dash_trails.filter(func(t): return float(t["life"]) > 0.0 and float(t["wy"]) > trail_cull_y)

	if not boss_mode:
		_generate_chunks_ahead()


func _obs_blocks_dash(kind: String) -> bool:
	return kind == "tree"


func _push_player_out_of_obs(obs: Dictionary) -> void:
	var cx: float = clampf(player_wx, float(obs["wx"]), float(obs["wx"]) + float(obs["w"]))
	var cy: float = clampf(player_wy, float(obs["wy"]), float(obs["wy"]) + float(obs["h"]))
	var nx: float = player_wx - cx
	var ny: float = player_wy - cy
	var nl: float = GameConstants.hypot(nx, ny)
	if nl < 0.001:
		nx = -dash_dir.x
		ny = -dash_dir.y
		nl = maxf(GameConstants.hypot(nx, ny), 0.001)
	var push: float = GameConstants.PLAYER_R + 3.0 - nl
	if push > 0.0:
		player_wx += (nx / nl) * push
		player_wy += (ny / nl) * push
	player_wx = clampf(player_wx, GameConstants.MAP_LEFT, GameConstants.MAP_RIGHT)


func _resolve_dash_blocking_collision(now: float) -> void:
	if dash_time_left <= 0.0:
		return
	for obs in obstacles:
		if not _obs_blocks_dash(str(obs["kind"])):
			continue
		if not _check_obs(obs):
			continue
		_push_player_out_of_obs(obs)
		dash_time_left = 0.0
		if now - float(obs["hit_flash"]) > 400.0:
			var rock_profile: Dictionary = ObstacleBehavior.profile("rock")
			_apply_obs_hit(obs, now, rock_profile)
			_trigger_obs_hit_flash("rock")
		return


func _apply_obs_hit(obs: Dictionary, now: float, profile_override: Dictionary = {}) -> void:
	var kind: String = str(obs["kind"])
	var profile: Dictionary = profile_override if not profile_override.is_empty() else ObstacleBehavior.profile(kind)
	obs["hit_flash"] = now
	obs["revealed_until"] = now + 1200.0
	var danger_add: float = float(profile["danger"])
	if danger_add > 0.0:
		danger_value = minf(GameConstants.DANGER_MAX, danger_value + danger_add)
	var cx: float = float(obs["wx"]) + float(obs["w"]) / 2.0
	var cy: float = float(obs["wy"]) + float(obs["h"]) / 2.0
	var nx: float = player_wx - cx
	var ny: float = player_wy - cy
	var nl: float = GameConstants.hypot(nx, ny)
	if nl < 0.001:
		nl = 1.0
	var knockback: float = float(profile["knockback"])
	player_wx += (nx / nl) * knockback
	player_wy += (ny / nl) * knockback
	var slow_duration: float = float(profile["slow_duration"])
	if slow_duration > 0.0:
		obs_hit_slow_timer = slow_duration
		obs_hit_slow_mult = float(profile["slow_mult"])
	_spawn_hit(obs)
	if profile_override.is_empty():
		_trigger_obs_hit_flash(kind)


func _trigger_obs_hit_flash(kind: String) -> void:
	var profile: Dictionary = ObstacleBehavior.profile(kind)
	_obs_hit_flash_color = GameConstants.color_from_hex(str(profile["flash_color"]))
	_obs_hit_flash_timer = 0.25


func _check_obs(obs: Dictionary) -> bool:
	var cx: float = clampf(player_wx, float(obs["wx"]), float(obs["wx"]) + float(obs["w"]))
	var cy: float = clampf(player_wy, float(obs["wy"]), float(obs["wy"]) + float(obs["h"]))
	return GameConstants.hypot(player_wx - cx, player_wy - cy) < GameConstants.PLAYER_R


func _monster_trap_cooldown_for_zone() -> float:
	return MonsterTrapShift.cooldown_sec(current_zone_index)


func _update_monster_trap_shifts(dt: float, danger_t: float, mon_dist: float, can_trigger: bool) -> void:
	var now := GameConstants.now_ms()
	var had_active := MonsterTrapShift.any_active(obstacles)
	for obs in obstacles:
		MonsterTrapShift.update_shift(obs, now)
	if had_active and not MonsterTrapShift.any_active(obstacles):
		_monster_trap_cooldown = _monster_trap_cooldown_for_zone()

	if _monster_trap_cooldown > 0.0:
		_monster_trap_cooldown = maxf(0.0, _monster_trap_cooldown - dt)

	if not can_trigger:
		return
	if MonsterTrapShift.any_active(obstacles):
		return
	if _monster_trap_cooldown > 0.0:
		return
	if mon_dist < GameConstants.MONSTER_TRAP_MIN_DIST or mon_dist > GameConstants.MONSTER_TRAP_MAX_DIST:
		return

	var pvx := (player_wx - _prev_player_wx) / maxf(dt, 0.001)
	var pvy := (player_wy - _prev_player_wy) / maxf(dt, 0.001)
	var urgency := clampf(
		(danger_t - GameConstants.DANGER_MONSTER_WAKE_T) / (1.0 - GameConstants.DANGER_MONSTER_WAKE_T),
		0.0, 1.0
	)
	var zone_index := current_zone_index
	var shift_count := MonsterTrapShift.shift_count_for_zone(zone_index, urgency)
	var candidates := MonsterTrapShift.pick_candidates(obstacles, player_wx, player_wy, shift_count)
	if candidates.is_empty():
		return

	var telegraph := MonsterTrapShift.telegraph_ms(urgency, zone_index)
	var started := 0
	for candidate in candidates:
		var plan := MonsterTrapShift.plan_shift(
			candidate, player_wx, player_wy, pvx, pvy, zone_index, urgency
		)
		if plan.is_empty():
			continue
		MonsterTrapShift.start_shift(candidate, plan, telegraph)
		started += 1
	if started == 0:
		return


func _spawn_hit(obs: Dictionary) -> void:
	var pos := _w2s(float(obs["wx"]) + float(obs["w"]) / 2.0, float(obs["wy"]) + float(obs["h"]) / 2.0)
	var col: String = GameConstants.OBS_COLORS[str(obs["kind"])]["hit"]
	for _j in range(14):
		var a := randf() * TAU
		var s := 70.0 + randf() * 120.0
		particles.append({
			"x": pos.x, "y": pos.y,
			"vx": cos(a) * s, "vy": sin(a) * s - 60.0,
			"life": 0.4 + randf() * 0.3, "max_life": 0.7,
			"color": col, "size": 3.0 + randf() * 3.0,
		})


func _spawn_coin_fx(c: Dictionary) -> void:
	var pos := _w2s(float(c["wx"]), float(c["wy"]))
	for _j in range(10):
		var a := randf() * TAU
		var s := 50.0 + randf() * 80.0
		particles.append({
			"x": pos.x, "y": pos.y,
			"vx": cos(a) * s, "vy": sin(a) * s - 80.0,
			"life": 0.5, "max_life": 0.5,
			"color": "#ffd700", "size": 4.0 + randf() * 3.0,
		})


func _trigger_checkpoint_landmark(landmark_id: String, _cp_wy: float) -> void:
	match landmark_id:
		"echo_well":
			_fire_echo(1.0, true)
		"reveal_shrine":
			_apply_reveal_shrine()


func _apply_reveal_shrine() -> void:
	var now := GameConstants.now_ms()
	var reveal_until := now + 3000.0
	for obs in obstacles:
		var ocx: float = float(obs["wx"]) + float(obs["w"]) / 2.0
		var ocy: float = float(obs["wy"]) + float(obs["h"]) / 2.0
		if GameConstants.hypot(player_wx - ocx, player_wy - ocy) < 1800.0:
			obs["revealed_until"] = maxf(float(obs["revealed_until"]), reveal_until)
	for c in coins_arr:
		if GameConstants.hypot(player_wx - float(c["wx"]), player_wy - float(c["wy"])) < 1800.0:
			c["revealed_until"] = maxf(float(c["revealed_until"]), reveal_until)


func _generate_chunks_ahead() -> void:
	var look_ahead := player_wy + GameConstants.SPAWN_AHEAD
	while spawned_up_to < look_ahead:
		_spawn_chunk(spawned_up_to)
		spawned_up_to += GameConstants.SPAWN_CHUNK


func _spawn_chunk(base_wy: float) -> void:
	var now := GameConstants.now_ms()
	var spawn_hold: bool = _any_echo_alive(now)
	var zone: Dictionary = WorldZones.zone_for_wy(base_wy + GameConstants.SPAWN_CHUNK * 0.5)
	var zone_index: int = WorldZones.zone_index_for_wy(base_wy + GameConstants.SPAWN_CHUNK * 0.5)
	var coin_count: int = WorldZones.coins_per_chunk(zone)
	var spawns: Dictionary = ChunkTemplates.build_chunk_spawns(base_wy, zone, zone_index, coin_count)
	for obs_spawn in spawns["obstacles"]:
		var o: Dictionary = obs_spawn as Dictionary
		obstacles.append({
			"id": _next_id(), "kind": str(o["kind"]),
			"wx": float(o["wx"]), "wy": float(o["wy"]),
			"w": float(o["w"]), "h": float(o["h"]),
			"revealed_until": 0.0, "hit_flash": 0.0,
			"echo_spawn_hold": spawn_hold,
		})
	for coin_spawn in spawns["coins"]:
		var c: Dictionary = coin_spawn as Dictionary
		if float(c["wy"]) < 200.0:
			continue
		coins_arr.append({
			"id": _next_id(), "wx": float(c["wx"]), "wy": float(c["wy"]),
			"revealed_until": 0.0, "collected": false,
			"echo_spawn_hold": spawn_hold,
		})


# ===================== RENDER =====================

func _render(time: float) -> void:
	queue_redraw()


func _draw() -> void:
	var time := GameConstants.now_ms()
	match state:
		GameState.MENU:
			_render_menu(time)
		GameState.MARKET:
			_render_market(time)
		GameState.SETTINGS:
			_render_settings(time)
		GameState.PLAYING, GameState.PAUSED, GameState.STORY, GameState.BOSS, GameState.WIN, GameState.DEAD:
			_render_game(time)
			if state == GameState.STORY:
				_render_story(time)
			elif state == GameState.PAUSED:
				_render_pause(time)
			elif state == GameState.WIN:
				_render_win(time)
			elif state == GameState.DEAD:
				_render_game_over(time)
func _render_game(time: float) -> void:
	var shake := heartbeat_shake
	if state == GameState.BOSS and _boss_screen_shake > 0.0:
		shake += sin(time * 0.04) * _boss_screen_shake * 14.0
	if shake != 0.0:
		draw_set_transform_matrix(Transform2D.IDENTITY.translated(Vector2(shake, 0)))

	_draw_background()
	_draw_ground()
	_draw_checkpoint_lines()
	_draw_landmark_lines()
	_draw_coins(time)
	if state != GameState.BOSS:
		_draw_trap_shift_warnings()
	_draw_obstacles()
	_draw_echo_pulses()
	if state == GameState.BOSS:
		_draw_boss_telegraphs()
		_draw_boss_projectiles()
		_draw_boss_dash_echo_fx(time)
		_draw_dash_echo_burst_fx(time)
	_draw_monster()
	if state == GameState.BOSS:
		_draw_boss_damage_popups()
	_draw_dash_trails()
	_draw_player(time)
	_draw_particles()

	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_obs_hit_flash()
	if state == GameState.BOSS and _boss_fight.player_hit_flash > 0.0:
		var hit_a: float = (_boss_fight.player_hit_flash / 0.35) * 0.35
		draw_rect(Rect2(0, 0, GameConstants.CANVAS_W, GameConstants.CANVAS_H), Color(1.0, 0.15, 0.12, hit_a))
	_draw_play_hints()
	_draw_hud(time)


func _echo_reveal_at(wx: float, wy: float, now: float) -> float:
	return _echo_coverage_at(wx, wy, now)


func _world_y_from_screen(sy: float) -> float:
	return camera_wy + GameConstants.CANVAS_H * 0.62 - sy


func _dirt_tile_metrics() -> Dictionary:
	var tw := _tex_deaddirt.get_width()
	var th := _tex_deaddirt.get_height()
	var tile_w := GameConstants.CANVAS_W / 3.0
	var tile_h := th * (tile_w / float(tw))
	return {"tw": tw, "th": th, "tile_w": tile_w, "tile_h": tile_h}


func _subtract_dark_segments(segments: Array, cut_x0: float, cut_x1: float) -> Array:
	var x0 := maxf(0.0, cut_x0)
	var x1 := minf(GameConstants.CANVAS_W, cut_x1)
	if x1 <= x0:
		return segments
	var out: Array = []
	for seg in segments:
		var a: float = seg.x
		var b: float = seg.y
		if x1 <= a or x0 >= b:
			out.append(seg)
		else:
			if a < x0:
				out.append(Vector2(a, x0))
			if x1 < b:
				out.append(Vector2(x1, b))
	return out


func _sonar_lit_segments_on_strip(ox: float, oy: float, outer_r: float, inner_dark_r: float, wy: float) -> Array:
	var dy := wy - oy
	if absf(dy) > outer_r:
		return []
	var half_wo := sqrt(maxf(0.0, outer_r * outer_r - dy * dy))
	var lit: Array = [Vector2(ox - half_wo, ox + half_wo)]
	if inner_dark_r > 0.5 and absf(dy) <= inner_dark_r:
		var half_wi := sqrt(maxf(0.0, inner_dark_r * inner_dark_r - dy * dy))
		lit = _subtract_dark_segments(lit, ox - half_wi, ox + half_wi)
	return lit


func _sonar_waves(now: float) -> Array:
	var waves: Array = []
	for wave in echo_pulses:
		_sync_echo_origin(wave)
		var bounds: Dictionary = _echo_wave_bounds(wave, now)
		var outer_r: float = float(bounds["outer_r"])
		if outer_r <= 1.0:
			continue
		waves.append({
			"ox": float(wave["origin_wx"]),
			"oy": float(wave["origin_wy"]),
			"outer_r": outer_r,
			"inner_dark_r": float(bounds["inner_dark_r"]),
		})
	return waves


func _draw_background_full() -> void:
	var m := _dirt_tile_metrics()
	var tile_w: float = m.tile_w
	var tile_h: float = m.tile_h
	var scroll := fmod(camera_wy, tile_h)
	var sy := fmod(GameConstants.CANVAS_H * 0.62 + scroll, tile_h) - tile_h
	while sy < GameConstants.CANVAS_H + tile_h:
		for col in 3:
			draw_texture_rect(
				_tex_deaddirt,
				Rect2(float(col) * tile_w, sy, tile_w, tile_h),
				false,
				_zone_tint
			)
		sy += tile_h


func _draw_sonar_darkness_mask(now: float) -> void:
	const STRIP_H := 6.0
	var dark_alpha := 1.0
	if state == GameState.BOSS:
		dark_alpha = _boss_fight.darkness_mask_alpha()
	if dark_alpha <= 0.01:
		return
	var dark_col := Color("#030306", dark_alpha)
	var waves := _sonar_waves(now)
	var sy := 0.0
	while sy < GameConstants.CANVAS_H + 0.01:
		var strip_h := minf(STRIP_H, GameConstants.CANVAS_H - sy)
		var wy := _world_y_from_screen(sy + strip_h * 0.5)
		var dark_segments: Array = [Vector2(0.0, GameConstants.CANVAS_W)]
		for wave in waves:
			for lit in _sonar_lit_segments_on_strip(
				float(wave["ox"]),
				float(wave["oy"]),
				float(wave["outer_r"]),
				float(wave["inner_dark_r"]),
				wy
			):
				dark_segments = _subtract_dark_segments(dark_segments, float(lit.x), float(lit.y))
		for seg in dark_segments:
			var w: float = seg.y - seg.x
			if w > 0.01:
				draw_rect(Rect2(seg.x, sy, w, strip_h), dark_col)
		sy += STRIP_H


func _draw_background() -> void:
	_draw_background_full()
	_draw_sonar_darkness_mask(GameConstants.now_ms())


func _draw_ground() -> void:
	var scroll_y := fmod(camera_wy, 80.0)
	var sy: float = fmod(GameConstants.CANVAS_H * 0.62 + scroll_y, 80.0)
	while sy < GameConstants.CANVAS_H + 80.0:
		draw_line(Vector2(0, sy), Vector2(GameConstants.CANVAS_W, sy), Color(1, 1, 1, 0.022), 1.0)
		sy += 80.0
	var sx := 0.0
	while sx < GameConstants.CANVAS_W + 80.0:
		draw_line(Vector2(sx, 0), Vector2(sx, GameConstants.CANVAS_H), Color(1, 1, 1, 0.022), 1.0)
		sx += 80.0
	draw_line(Vector2(GameConstants.MAP_LEFT, 0), Vector2(GameConstants.MAP_LEFT, GameConstants.CANVAS_H), Color(0, 0.78, 1, 0.08), 2.0)
	draw_line(Vector2(GameConstants.MAP_RIGHT, 0), Vector2(GameConstants.MAP_RIGHT, GameConstants.CANVAS_H), Color(0, 0.78, 1, 0.08), 2.0)


func _draw_checkpoint_lines() -> void:
	for cp in checkpoints:
		if cp["triggered"]:
			continue
		var sy := _w2s(0.0, float(cp["wy"])).y
		if sy < -10.0 or sy > GameConstants.CANVAS_H + 10.0:
			continue
		var near: bool = absf(player_wy - float(cp["wy"])) < 350.0
		var line_col := Color(0, 1, 0.7, 0.35 if near else 0.18)
		CanvasUtil.dashed_h_line(self, GameConstants.MAP_LEFT, GameConstants.MAP_RIGHT, sy, 12.0, 8.0, line_col, 1.5)
		_draw_text(str(cp["label"]), Vector2(GameConstants.MAP_LEFT - 6, sy + 4), 10, Color(0, 1, 0.7, 0.4), HORIZONTAL_ALIGNMENT_RIGHT)
		_draw_text(str(cp["label"]), Vector2(GameConstants.MAP_RIGHT + 6, sy + 4), 10, Color(0, 1, 0.7, 0.4), HORIZONTAL_ALIGNMENT_LEFT)


func _draw_landmark_lines() -> void:
	for lm in landmarks:
		if lm["triggered"]:
			continue
		var sy := _w2s(0.0, float(lm["wy"])).y
		if sy < -10.0 or sy > GameConstants.CANVAS_H + 10.0:
			continue
		var landmark_id: String = str(lm["landmark"])
		var lm_def: Dictionary = CheckpointLandmarks.get_def(landmark_id)
		var line_col := GameConstants.color_from_hex(str(lm_def["line_color"]))
		var near: bool = absf(player_wy - float(lm["wy"])) < 450.0
		line_col.a = 0.5 if near else 0.24
		if near:
			var glow_col := GameConstants.color_from_hex(str(lm_def["glow_color"]))
			CanvasUtil.glow_circle(
				self,
				Vector2(GameConstants.CANVAS_W / 2.0, sy),
				30.0,
				Color(glow_col.r, glow_col.g, glow_col.b, 0.2),
				18.0
			)
		CanvasUtil.dashed_h_line(self, GameConstants.MAP_LEFT, GameConstants.MAP_RIGHT, sy, 10.0, 6.0, line_col, 2.0 if near else 1.5)
		var tag: String = "%s  %s" % [str(lm_def["icon"]), str(lm_def["label"])]
		_draw_text(tag, Vector2(GameConstants.MAP_LEFT - 8, sy - 8), 10, line_col, HORIZONTAL_ALIGNMENT_RIGHT)
		_draw_text(str(lm["label"]), Vector2(GameConstants.MAP_LEFT - 8, sy + 10), 10, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_RIGHT)
		_draw_text(tag, Vector2(GameConstants.MAP_RIGHT + 8, sy - 8), 10, line_col, HORIZONTAL_ALIGNMENT_LEFT)
		_draw_text(str(lm["label"]), Vector2(GameConstants.MAP_RIGHT + 8, sy + 10), 10, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_LEFT)


func _draw_coins(time: float) -> void:
	var now := GameConstants.now_ms()
	for c in coins_arr:
		if c["collected"]:
			continue
		var echo_cov: float = _echo_coverage_at(
			float(c["wx"]), float(c["wy"]), now, c.get("echo_spawn_hold", false)
		)
		var alpha: float = 0.0
		if now < float(c["revealed_until"]):
			alpha = minf(1.0, (float(c["revealed_until"]) - now) / _upgrade_reveal_duration_ms() * 2.5)
		elif echo_cov > 0.0:
			alpha = echo_cov
		if alpha <= 0.0:
			continue
		var pos := _w2s(float(c["wx"]), float(c["wy"]))
		var pulse: float = sin(time * 0.005 + float(c["wx"])) * 0.15 + 0.85
		var size: float = GameConstants.COIN_R * 3.8 * pulse
		CanvasUtil.glow_circle(self, pos, size * 0.55, Color("#ffd700", alpha * 0.35), 10.0 * pulse)
		_draw_coin_sprite(pos, size, alpha)


func _obs_echo_visible(obs: Dictionary, now: float) -> bool:
	if now < float(obs.get("revealed_until", 0.0)):
		return true
	var cx: float = float(obs["wx"]) + float(obs["w"]) / 2.0
	var cy: float = float(obs["wy"]) + float(obs["h"]) / 2.0
	return _echo_coverage_at(cx, cy, now, obs.get("echo_spawn_hold", false)) > 0.01


func _draw_trap_shift_warnings() -> void:
	var now := GameConstants.now_ms()
	for obs in obstacles:
		if not obs.has("trap_shift"):
			continue
		if not _obs_echo_visible(obs, now):
			continue
		var shift: Dictionary = obs["trap_shift"]
		if str(shift.get("phase", "")) != "telegraph":
			continue
		var kind := str(obs["kind"])
		var tex: Texture2D = _tex_obstacles.get(kind)
		if tex == null:
			continue
		var w := float(obs["w"])
		var h := float(obs["h"])
		var from_pos := _w2s(float(obs["wx"]) + w / 2.0, float(obs["wy"]) + h / 2.0)
		var to_pos := _w2s(float(shift["to_wx"]) + w / 2.0, float(shift["to_wy"]) + h / 2.0)
		var elapsed := now - float(shift["start_ms"])
		var telegraph_ms := maxf(float(shift["telegraph_ms"]), 1.0)
		var urgency := clampf(elapsed / telegraph_ms, 0.0, 1.0)
		var pulse := 0.55 + sin(now * 0.018) * 0.35 + urgency * 0.25
		var ghost_col := Color(1.0, 0.22, 0.18, 0.28 + urgency * 0.22)
		_draw_obstacle_sprite(tex, to_pos, w, h, ghost_col)
		var box := Rect2(to_pos.x - w * 0.5, to_pos.y - h * 0.5, w, h)
		draw_rect(box, Color(1.0, 0.35, 0.25, 0.55 * pulse), false, 2.0 + urgency)
		draw_line(from_pos, to_pos, Color(1.0, 0.45, 0.3, 0.45 + urgency * 0.35), 1.5)
		var arrow_dir := (to_pos - from_pos).normalized()
		if arrow_dir.length_squared() > 0.01:
			var tip := to_pos - arrow_dir * 10.0
			var side := Vector2(-arrow_dir.y, arrow_dir.x) * 7.0
			draw_colored_polygon(PackedVector2Array([to_pos, tip + side, tip - side]), Color(1.0, 0.5, 0.3, 0.7))


func _draw_obstacles() -> void:
	var now := GameConstants.now_ms()
	for obs in obstacles:
		var is_trap: bool = MonsterTrapShift.is_shifting(obs)
		var is_hit: bool = now - float(obs["hit_flash"]) < 350.0
		var cx: float = float(obs["wx"]) + float(obs["w"]) / 2.0
		var cy: float = float(obs["wy"]) + float(obs["h"]) / 2.0
		var shrine_revealed: bool = now < float(obs.get("revealed_until", 0.0))
		var echo_alpha: float = _echo_coverage_at(cx, cy, now, obs.get("echo_spawn_hold", false))
		var is_revealed: bool = shrine_revealed or echo_alpha > 0.01
		if not is_revealed and not is_hit:
			continue
		var kind := str(obs["kind"])
		var tex: Texture2D = _tex_obstacles.get(kind)
		if tex == null:
			continue
		var w := float(obs["w"])
		var h := float(obs["h"])
		var pos := _w2s(cx, cy)
		var colors: Dictionary = GameConstants.OBS_COLORS[kind]
		var modulate := Color(1.15, 1.15, 1.22, 1.0 if shrine_revealed or is_hit else echo_alpha)
		if is_hit:
			modulate = GameConstants.color_from_hex(colors["hit"])
			_draw_obstacle_sonar_outline(tex, pos, w, h, 1.0, GameConstants.color_from_hex(colors["hit"]))
		elif is_trap and obs.has("trap_shift") and str(obs["trap_shift"].get("phase", "")) == "telegraph":
			var warn_pulse := 0.7 + sin(now * 0.02) * 0.3
			_draw_obstacle_sonar_outline(tex, pos, w, h, warn_pulse, Color(1.0, 0.35, 0.25, 1.0))
		elif is_revealed:
			var pulse := 0.62 + sin(now * 0.011 + float(obs["wx"]) * 0.04) * 0.38
			var outline_alpha: float = 1.0 if shrine_revealed else echo_alpha
			_draw_obstacle_sonar_outline(
				tex, pos, w, h, pulse * outline_alpha,
				Color(0.45, 0.98, 1.0, outline_alpha)
			)
		_draw_obstacle_sprite(tex, pos, w, h, modulate)


func _draw_obstacle_sonar_outline(tex: Texture2D, pos: Vector2, width: float, height: float, pulse: float, tint: Color) -> void:
	var base := Rect2(pos.x - width * 0.5, pos.y - height * 0.5, width, height)
	var spreads := [5.0, 3.5, 2.0]
	var dirs := 16
	for si in spreads.size():
		var spread: float = spreads[si]
		var falloff := 1.0 - float(si) * 0.22
		var outer := Color(tint.r * 0.25, tint.g * 0.85, tint.b, 0.42 * pulse * falloff)
		var inner := Color(tint.r * 0.7, tint.g, tint.b, 0.78 * pulse * falloff)
		for i in dirs:
			var a := (float(i) / float(dirs)) * TAU
			var off := Vector2(cos(a), sin(a)) * spread
			var col := inner if spread <= 2.5 else outer
			draw_texture_rect(tex, Rect2(base.position + off, base.size), false, col)


func _draw_obstacle_sprite(tex: Texture2D, pos: Vector2, width: float, height: float, modulate: Color = Color.WHITE) -> void:
	var dst := Rect2(pos.x - width * 0.5, pos.y - height * 0.5, width, height)
	draw_texture_rect(tex, dst, false, modulate)


func _draw_echo_pulses() -> void:
	var now := GameConstants.now_ms()
	for wave in echo_pulses:
		_sync_echo_origin(wave)
		var bounds: Dictionary = _echo_wave_bounds(wave, now)
		var outer_r: float = float(bounds["outer_r"])
		var inner_dark_r: float = float(bounds["inner_dark_r"])
		if outer_r < 1.0:
			continue
		var origin := _w2s(float(wave["origin_wx"]), float(wave["origin_wy"]))
		if wave.get("golden_echo", false):
			var burst_alpha: float = float(bounds.get("burst_alpha", 1.0))
			CanvasUtil.golden_echo_burst(self, origin, outer_r, burst_alpha)
			continue
		if str(bounds["phase"]) == "expand":
			CanvasUtil.echo_wave_front(self, origin, outer_r, 1.0)
		else:
			if inner_dark_r > 1.0:
				var fade: float = clampf(inner_dark_r / maxf(outer_r, 1.0), 0.0, 1.0)
				CanvasUtil.echo_dark_front(self, origin, inner_dark_r, outer_r, fade)
			if outer_r > inner_dark_r + 8.0:
				CanvasUtil.echo_ring_outline(self, origin, outer_r, 0.22)


func _monster_on_screen() -> bool:
	var pos := _w2s(monster_wx, monster_wy)
	var margin := 50.0
	return pos.x >= -margin and pos.x <= GameConstants.CANVAS_W + margin and pos.y >= -margin and pos.y <= GameConstants.CANVAS_H + margin


func _monster_visibility_alpha(now: float) -> float:
	if state == GameState.BOSS:
		if _boss_fight.full_arena_visible() or _boss_fight.in_phase_transition or _boss_fight.is_cinematic():
			return 1.0
	return _echo_coverage_at(monster_wx, monster_wy, now)


func _draw_monster() -> void:
	var now := GameConstants.now_ms()
	var vis := _monster_visibility_alpha(now)
	if vis <= 0.0:
		return
	var pos := _w2s(monster_wx, monster_wy)
	var dist := GameConstants.hypot(player_wx - monster_wx, player_wy - monster_wy)
	if pos.y >= -40.0 and pos.y <= GameConstants.CANVAS_H + 40.0:
		var frame := int(_enemy_anim_time * SPRITE_ANIM_FPS) % SPRITE_GRID
		var sprite_size := GameConstants.MONSTER_SPRITE_SIZE
		var modulate := Color(1, 1, 1, vis)
		if state == GameState.BOSS and _boss_fight.boss_hit_flash > 0.0:
			var hit_t: float = _boss_fight.boss_hit_flash / 0.28
			var red_mix: float = clampf(hit_t, 0.0, 1.0)
			modulate = Color(1.0, 1.0 - red_mix * 0.75, 1.0 - red_mix * 0.75, vis)
		if state == GameState.BOSS and _boss_fight.is_cinematic():
			var prog: float = _boss_fight.cinematic_progress()
			sprite_size *= lerpf(1.0, 0.35, prog)
			var wobble: float = sin(prog * 18.0) * prog * 0.08
			pos += Vector2(wobble * 30.0, prog * 12.0)
			var grey: float = lerpf(1.0, 0.35, prog)
			modulate = Color(grey, grey, grey, vis * lerpf(1.0, 0.2, prog))
		_draw_sprite_sheet_frame(_tex_enemy, pos, _enemy_sprite_dir, frame, sprite_size, modulate)
	if pos.y > GameConstants.CANVAS_H - 10.0 and dist < 500.0:
		var w: float = minf(1.0, 1.0 - dist / 500.0) * vis
		CanvasUtil.linear_gradient_rect(
			self,
			Rect2(0, GameConstants.CANVAS_H - 70, GameConstants.CANVAS_W, 70),
			Color(0.7, 0, 0, 0.0),
			Color(0.7, 0, 0, w * 0.3)
		)


func _draw_dash_trails() -> void:
	for trail in dash_trails:
		var pos := _w2s(float(trail["wx"]), float(trail["wy"]))
		if pos.y < -60.0 or pos.y > GameConstants.CANVAS_H + 60.0:
			continue
		var alpha: float = clampf(float(trail["life"]) / float(trail["max_life"]), 0.0, 1.0)
		var size: float = float(trail["size"]) * (0.5 + alpha * 0.45)
		var core := Color(0.55, 0.98, 1.0, 0.32 * alpha)
		var outer := Color(0.1, 0.75, 1.0, 0.12 * alpha)
		CanvasUtil.glow_circle(self, pos, size * 1.15, outer, 10.0 * alpha)
		CanvasUtil.glow_circle(self, pos, size * 0.85, core, 7.0 * alpha)
		CanvasUtil.glow_circle(self, pos + Vector2(-2, -2), size * 0.28, Color(0.9, 1.0, 1.0, 0.4 * alpha), 4.0)


func _draw_player(_time: float) -> void:
	var pos := _w2s(player_wx, player_wy)
	var dashing := dash_time_left > 0.0
	var golden_burst := state == GameState.BOSS and _boss_fight.dash_echo_active
	var modulate: Color = Color(0.75, 1.0, 1.0, 1.0) if dashing else Color.WHITE
	if golden_burst:
		modulate = Color(1.0, 0.92, 0.45, 1.0)
	PlayerSpriteFrames.draw_frame(
		self, _tex_player, pos, _player_face_dir,
		_dash_anim_time if dashing else _player_anim_time,
		_player_sprite_moving,
		GameConstants.PLAYER_R * 3.2, modulate, dashing
	)
	if golden_burst:
		var pulse: float = 0.65 + sin(_time * 0.012) * 0.35
		CanvasUtil.glow_circle(self, pos, GameConstants.PLAYER_R + 28.0, Color(1.0, 0.82, 0.15, 0.3 * pulse), 18.0)
		draw_arc(pos, GameConstants.PLAYER_R + 20.0, 0, TAU, 32, Color(1.0, 0.9, 0.35, 0.8 * pulse), 3.0)
	elif dashing:
		draw_arc(pos, GameConstants.PLAYER_R + 14.0, 0, TAU, 32, Color(0, 0.96, 1, 0.55), 2.0)
	else:
		draw_arc(pos, GameConstants.PLAYER_R + 12.0, 0, TAU, 32, Color(0, 0.96, 1, 0.35), 1.0)


func _draw_particles() -> void:
	for p in particles:
		var a: float = float(p["life"]) / float(p["max_life"])
		var col := GameConstants.color_from_hex(str(p["color"]))
		col.a = a
		CanvasUtil.glow_circle(self, Vector2(float(p["x"]), float(p["y"])), float(p["size"]) * a, col, 5.0)


func _draw_obs_hit_flash() -> void:
	if _obs_hit_flash_timer <= 0.0:
		return
	var alpha: float = (_obs_hit_flash_timer / 0.25) * 0.32
	var col := _obs_hit_flash_color
	col.a = alpha
	draw_rect(Rect2(0, 0, GameConstants.CANVAS_W, GameConstants.CANVAS_H), col)


func _draw_boss_damage_popups() -> void:
	var base_pos := _w2s(monster_wx, monster_wy)
	for popup in _boss_fight.damage_popups:
		var life: float = float(popup["life"])
		var max_life: float = float(popup["max_life"])
		var t: float = 1.0 - life / max_life
		var amount: float = float(popup["amount"])
		var label := "-%d" % int(roundf(amount))
		var alpha: float = clampf(life / max_life, 0.0, 1.0)
		var pos := base_pos + Vector2(
			float(popup["offset_x"]),
			float(popup["rise"]) - t * 42.0
		)
		_draw_text(label, pos, 10, Color(1.0, 0.22, 0.18, alpha), HORIZONTAL_ALIGNMENT_CENTER, true)


func _draw_boss_dash_echo_fx(time: float) -> void:
	if not _boss_fight.dash_echo_active:
		return
	var center := _w2s(player_wx, player_wy)
	var pulse: float = 0.75 + sin(time * 0.006) * 0.25
	var arena_r: float = maxf(GameConstants.CANVAS_W, GameConstants.CANVAS_H) * 0.95 * pulse
	CanvasUtil.dash_echo_aura(self, center, arena_r, 0.9)
	CanvasUtil.dash_echo_aura(self, center, arena_r * 0.55, 0.58)


func _draw_dash_echo_burst_fx(time: float) -> void:
	if _dash_echo_burst_timer <= 0.0:
		return
	var alpha: float = clampf(_dash_echo_burst_timer / 1.15, 0.0, 1.0)
	var pos := _w2s(player_wx, player_wy)
	var radius: float = lerpf(40.0, 180.0, 1.0 - alpha)
	CanvasUtil.golden_echo_burst(self, pos, radius, alpha * 0.95)
	draw_rect(
		Rect2(0, 0, GameConstants.CANVAS_W, GameConstants.CANVAS_H),
		Color(1.0, 0.88, 0.35, alpha * 0.12)
	)


func _draw_boss_telegraphs() -> void:
	if _boss_fight.in_intro() or _boss_fight.is_cinematic():
		return
	var tel: Dictionary = _boss_ai.telegraph
	var kind: String = str(tel.get("kind", ""))
	if kind.is_empty() or kind == "chase" or kind == "recover":
		return
	var pos := _w2s(float(tel.get("wx", monster_wx)), float(tel.get("wy", monster_wy)))
	match kind:
		"swipe", "swipe_active":
			var alpha: float = 1.0 if kind == "swipe_active" else float(tel.get("alpha", 0.5))
			CanvasUtil.boss_swipe_arc(self, pos, float(tel.get("angle", 0.0)), GameConstants.BOSS_SWIPE_RANGE, GameConstants.BOSS_SWIPE_ARC, alpha)
		"charge":
			var world_dir := Vector2(float(tel.get("dir_x", 0.0)), float(tel.get("dir_y", 0.0)))
			var screen_dir := _world_dir_to_screen(world_dir)
			CanvasUtil.boss_charge_line(self, pos, screen_dir, 280.0, float(tel.get("alpha", 0.5)))
		"rock":
			CanvasUtil.glow_circle(self, pos, 36.0, Color(1.0, 0.45, 0.2, 0.35 * float(tel.get("alpha", 0.5))), 14.0)
		"line_rock", "line_rock_active":
			var world_dir := Vector2(float(tel.get("dir_x", 0.0)), float(tel.get("dir_y", 0.0)))
			var screen_dir := _world_dir_to_screen(world_dir)
			var alpha: float = 1.0 if kind == "line_rock_active" else float(tel.get("alpha", 0.5))
			CanvasUtil.boss_charge_line(self, pos, screen_dir, 300.0, alpha * 0.85)
			var aim_pos := _w2s(float(tel.get("aim_wx", monster_wx)), float(tel.get("aim_wy", monster_wy)))
			CanvasUtil.glow_circle(self, aim_pos, 18.0, Color(1.0, 0.55, 0.15, 0.45 * alpha), 10.0)
		"meteor_jump":
			var target_pos := _w2s(float(tel.get("tx", monster_wx)), float(tel.get("ty", monster_wy)))
			draw_line(pos, target_pos, Color(1.0, 0.35, 0.55, 0.55), 2.5)
			CanvasUtil.glow_circle(self, target_pos, 28.0, Color(1.0, 0.25, 0.45, 0.35), 12.0)
		"meteor_rain", "meteor_anchor":
			CanvasUtil.glow_circle(self, pos, 44.0, Color(1.0, 0.2, 0.35, 0.5), 16.0)
			draw_arc(pos, 52.0, 0.0, TAU, 32, Color(1.0, 0.45, 0.2, 0.35), 2.0)
		"phase":
			pass


func _draw_boss_projectiles() -> void:
	var tex: Texture2D = _tex_obstacles.get("rock")
	if tex == null:
		return
	var w := GameConstants.BOSS_ARENA_ROCK_W * 0.45
	var h := GameConstants.BOSS_ARENA_ROCK_H * 0.45
	for p in _boss_fight.projectiles:
		if p.get("hit", false):
			continue
		var pos := _w2s(float(p["wx"]), float(p["wy"]))
		if p.get("meteor", false):
			var mw := w * 1.15
			var mh := h * 1.15
			_draw_obstacle_sprite(tex, pos, mw, mh, Color(1.25, 0.75, 0.55, 1.0))
			CanvasUtil.glow_circle(self, pos + Vector2(0.0, -12.0), 30.0, Color(1.0, 0.35, 0.2, 0.45), 14.0)
			draw_line(pos + Vector2(0.0, -28.0), pos + Vector2(0.0, 18.0), Color(1.0, 0.5, 0.2, 0.35), 3.0)
		elif p.get("line_rock", false):
			_draw_obstacle_sprite(tex, pos, w * 0.9, h * 0.9, Color(1.15, 0.95, 0.8, 1.0))
			CanvasUtil.glow_circle(self, pos, 18.0, Color(1.0, 0.55, 0.2, 0.3), 8.0)
		else:
			_draw_obstacle_sprite(tex, pos, w, h, Color(1.1, 1.05, 1.15, 1.0))
			CanvasUtil.glow_circle(self, pos, 22.0, Color(1.0, 0.4, 0.25, 0.35), 10.0)
	for imp in _boss_fight.impacts:
		var pos := _w2s(float(imp["wx"]), float(imp["wy"]))
		var life: float = float(imp["life"]) / float(imp["max_life"])
		CanvasUtil.glow_circle(self, pos, 40.0 * life, Color(0.8, 0.75, 0.7, 0.4 * life), 16.0)
		CanvasUtil.glow_circle(self, pos, 18.0 * life, Color(1.0, 0.5, 0.3, 0.55 * life), 8.0)


func _draw_boss_combat_hud(time: float) -> void:
	if _boss_fight.in_intro():
		var intro_a: float = _boss_fight.intro_alpha()
		_draw_text_glow(
			"SON YANKI",
			Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H / 2.0 - 40),
			36,
			Color("#ff3030", intro_a),
			24.0 * intro_a,
			true
		)
		return

	var hp_frac: float = _boss_fight.player_hp_frac()
	var hp_bar := Rect2(16.0, 98.0, 180.0, 6.0)
	CanvasUtil.souls_bar(self, hp_bar, hp_frac, Color(0.92, 0.92, 0.94, 0.95))
	_draw_text(
		"HP %d / %d" % [int(_boss_fight.player_hp), int(_boss_fight.player_max_hp)],
		Vector2(16, 112),
		9,
		Color(1, 1, 1, 0.4),
		HORIZONTAL_ALIGNMENT_LEFT
	)
	if _boss_fight.is_combat_invuln():
		var inv_a: float = 0.55 + sin(time * 0.008) * 0.45
		_draw_text(
			"KORUNMA %.1fs" % _boss_fight.combat_invuln_timer,
			Vector2(16, 128),
			9,
			Color("#00f5ff", inv_a),
			HORIZONTAL_ALIGNMENT_LEFT
		)

	if _boss_fight.last_hit_timer > 0.0 and not _boss_fight.last_hit_source.is_empty():
		var hit_a: float = minf(1.0, _boss_fight.last_hit_timer / 0.4)
		_draw_text_glow(
			"-%d  %s" % [int(_boss_fight.last_hit_amount), _boss_fight.last_hit_source],
			Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H * 0.38),
			18,
			Color("#ff5050", hit_a),
			14.0 * hit_a,
			true
		)

	var boss_w := 720.0
	var boss_h := 14.0
	var boss_x := GameConstants.CANVAS_W * 0.5 - boss_w * 0.5
	var boss_y := 34.0
	var boss_frac: float = _boss_fight.boss_hp_frac()
	var boss_fill := Color("#c41e1e")
	if _boss_fight.phase == 2:
		boss_fill = Color("#ff3030", 0.85 + sin(time * 0.005) * 0.15)
	elif _boss_fight.phase >= 3:
		boss_fill = Color("#ff6020", 0.9 + sin(time * 0.012) * 0.1)
	_draw_text_glow(
		GameConstants.BOSS_NAME,
		Vector2(GameConstants.CANVAS_W / 2.0, 18.0),
		14,
		Color("#ff4040", 0.9),
		12.0,
		true
	)
	CanvasUtil.souls_bar(self, Rect2(boss_x, boss_y, boss_w, boss_h), boss_frac, boss_fill)

	if _boss_fight.meteor_anchored:
		var rain_a: float = 0.7 + sin(time * 0.02) * 0.3
		_draw_text_glow(
			"GÖKTAŞI YAĞMURU",
			Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H * 0.5 - 8),
			20,
			Color("#ff6030", rain_a),
			16.0 * rain_a,
			true
		)
		_draw_text(
			"Kayaların arkasına saklan!",
			Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H * 0.5 + 18),
			11,
			Color(1.0, 0.85, 0.55, rain_a * 0.75),
			HORIZONTAL_ALIGNMENT_CENTER
		)

	if _boss_fight.in_phase_transition:
		var pt: float = _boss_fight.phase_transition_timer / GameConstants.BOSS_PHASE_TRANSITION_SEC
		_draw_text_glow(
			"İKİNCİ AŞAMA",
			Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H * 0.5 - 20),
			28,
			Color("#ff3030", 1.0 - pt),
			20.0 * (1.0 - pt),
			true
		)

	if _boss_fight.is_cinematic():
		var title_a: float = _boss_fight.cinematic_title_alpha()
		if title_a > 0.0:
			_draw_text_glow(
				"YANKI SUSTURULDU",
				Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H * 0.42),
				24,
				Color("#00f5ff", title_a),
				16.0 * title_a,
				true
			)

	var dash_echo_y := GameConstants.CANVAS_H - 88.0
	var dash_echo_name := GameConstants.BOSS_DASH_ECHO_NAME
	if _boss_fight.dash_echo_active:
		var active_frac: float = _boss_fight.dash_echo_timer / GameConstants.BOSS_DASH_ECHO_DURATION
		CanvasUtil.round_rect(self, Rect2(GameConstants.CANVAS_W * 0.5 - 58, dash_echo_y, 116, 5), 2.0, Color(1, 1, 1, 0.08))
		CanvasUtil.round_rect(self, Rect2(GameConstants.CANVAS_W * 0.5 - 58, dash_echo_y, 116 * active_frac, 5), 2.0, Color("#ffd040"))
		_draw_text(dash_echo_name, Vector2(GameConstants.CANVAS_W * 0.5, dash_echo_y - 6), 9, Color("#ffe680", 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	elif _boss_fight.dash_echo_ready():
		if echo_held and _dash_echo_charge_t() >= GameConstants.BOSS_DASH_ECHO_CHARGE_MIN:
			_draw_text("SHIFT — %s!" % dash_echo_name, Vector2(GameConstants.CANVAS_W * 0.5, dash_echo_y), 9, Color("#ffd040", 0.9), HORIZONTAL_ALIGNMENT_CENTER, true)
		else:
			_draw_text("MAX ECHO + SHIFT — %s" % dash_echo_name, Vector2(GameConstants.CANVAS_W * 0.5, dash_echo_y), 9, Color("#ffd040", 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	elif _boss_fight.dash_echo_cooldown > 0.0:
		var cd_frac: float = _boss_fight.dash_echo_cooldown_frac()
		draw_arc(Vector2(GameConstants.CANVAS_W * 0.5, dash_echo_y + 2), 8.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - cd_frac), 20, Color(1.0, 0.78, 0.2, 0.45), 2.0)
		_draw_text("%s %.0fs" % [dash_echo_name, _boss_fight.dash_echo_cooldown], Vector2(GameConstants.CANVAS_W * 0.5, dash_echo_y + 14), 8, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_CENTER)

	if _boss_dash_echo_hint_timer > 0.0:
		var hint_a: float = minf(1.0, _boss_dash_echo_hint_timer / 1.2)
		_draw_text_glow(
			"YENİ YETENEK: %s" % dash_echo_name,
			Vector2(GameConstants.CANVAS_W * 0.5, GameConstants.CANVAS_H * 0.46),
			18,
			Color("#ffd040", hint_a * 0.95),
			14.0 * hint_a,
			true
		)
		_draw_text(
			"Echo çubuğunu doldur → SHIFT ile patlat",
			Vector2(GameConstants.CANVAS_W * 0.5, GameConstants.CANVAS_H * 0.46 + 24),
			11,
			Color(1.0, 0.9, 0.55, hint_a * 0.65),
			HORIZONTAL_ALIGNMENT_CENTER
		)


func _draw_play_hints() -> void:
	if _play_hint_timer <= 0.0:
		return
	var alpha: float = 1.0 if _play_hint_timer > 1.0 else _play_hint_timer
	var cx := GameConstants.CANVAS_W / 2.0
	var base_y := GameConstants.CANVAS_H * 0.58
	var lines := [
		"WASD — Hareket",
		"SPACE (basılı) — Echo",
		"SHIFT — Dash",
	]
	for i in lines.size():
		var col := Color(0, 0.96, 1, 0.75 * alpha)
		_draw_text(lines[i], Vector2(cx, base_y + float(i) * 22.0), 12, col, HORIZONTAL_ALIGNMENT_CENTER, true)


func _draw_hud(_time: float) -> void:
	_draw_text("%dm" % int(score / 10.0), Vector2(16, 26), 15, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_LEFT, true)
	_draw_text("REKOR %dm" % int(high_score / 10.0), Vector2(16, 42), 11, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_LEFT)
	_draw_coin_amount(Vector2(16, 50), coins, 13, Color("#ffd700"))
	if checkpoint_msg_timer > 0.0 and state not in [GameState.STORY, GameState.BOSS]:
		var alpha: float = minf(1.0, checkpoint_msg_timer / 0.5)
		var msg_col := WorldZones.zone_msg_color(_current_zone()) if checkpoint_msg_is_zone else checkpoint_msg_color
		msg_col.a = alpha
		_draw_text_glow(checkpoint_msg, Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H / 2.0 - 60), 22, msg_col, 20.0, true)

	var pb_h := 120.0
	var pb_x := 16.0
	var pb_y := GameConstants.CANVAS_H - 82.0 - pb_h
	var pb_label_y := pb_y + pb_h + 14.0
	var max_cd := _upgrade_dash_cooldown()
	var cd_frac := clampf(dash_cooldown / maxf(max_cd, 0.001), 0.0, 1.0)
	var dash_ready := cd_frac <= 0.001 and dash_time_left <= 0.0
	CanvasUtil.round_rect(self, Rect2(pb_x, pb_y, 10, pb_h), 5.0, Color(1, 1, 1, 0.05))
	var dash_col: Color = Color8(60, 220, 255) if dash_ready else Color8(int(80 + (1.0 - cd_frac) * 120), int(140 + (1.0 - cd_frac) * 80), 255)
	if cd_frac > 0.0:
		CanvasUtil.round_rect(self, Rect2(pb_x, pb_y + pb_h * (1.0 - cd_frac), 10, pb_h * cd_frac), 5.0, dash_col)
	elif dash_ready:
		var ready_pulse := 0.65 + sin(_time * 0.008) * 0.35
		CanvasUtil.round_rect(self, Rect2(pb_x, pb_y + pb_h - 18.0, 10, 18.0), 5.0, Color(0, 0.96, 1, ready_pulse))
		CanvasUtil.glow_circle(self, Vector2(pb_x + 5, pb_y + pb_h - 9.0), 5.0, Color("#00f5ff"), 8.0 * ready_pulse)
	_draw_text("»", Vector2(pb_x + 5, pb_y - 6), 14, Color("#00f5ff") if dash_ready else Color(0, 0.96, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
	if cd_frac > 0.0:
		_draw_text("%.1fs" % dash_cooldown, Vector2(pb_x + 5, pb_y + pb_h * 0.5), 9, Color(0, 0.96, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	_draw_text("DASH" if dash_ready else "BEKLE", Vector2(pb_x + 5, pb_label_y), 9, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_CENTER)

	var db_x := GameConstants.CANVAS_W - 26.0
	var danger_t := danger_value / GameConstants.DANGER_MAX
	CanvasUtil.round_rect(self, Rect2(db_x, pb_y, 10, pb_h), 5.0, Color(1, 1, 1, 0.05))
	var dg := int(80 * (1.0 - danger_t))
	var danger_col: Color = Color8(255, dg, 0)
	if danger_t > 0.6:
		CanvasUtil.glow_circle(self, Vector2(db_x + 5, pb_y + pb_h * (1.0 - danger_t) + pb_h * danger_t * 0.5), 6.0, Color.RED, 12.0)
	CanvasUtil.round_rect(self, Rect2(db_x, pb_y + pb_h * (1.0 - danger_t), 10, pb_h * danger_t), 5.0, danger_col)
	_draw_text("⚠", Vector2(db_x + 5, pb_y - 6), 13, Color(1, 0.39, 0, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	_draw_text("TEHLİKE", Vector2(db_x + 5, pb_label_y), 9, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_CENTER)

	var shout_t: float = GameConstants.ECHO_SHOUT_MONSTER_WAKE_T
	if echo_held:
		var t: float = minf(echo_hold_duration / GameConstants.ECHO_HOLD_MAX, 1.0)
		var bw := 160.0
		var bx := GameConstants.CANVAS_W / 2.0 - bw / 2.0
		var by := GameConstants.CANVAS_H - 26.0
		CanvasUtil.round_rect(self, Rect2(bx, by, bw, 7), 3.0, Color(1, 1, 1, 0.07))
		var golden_ready := (
			state == GameState.BOSS
			and t >= GameConstants.BOSS_DASH_ECHO_CHARGE_MIN
			and _boss_fight.dash_echo_ready()
		)
		var cc: Color = Color("#ffd040") if golden_ready else (Color("#ff7800") if t >= shout_t else Color("#00f5ff"))
		CanvasUtil.glow_circle(self, Vector2(bx + bw * t * 0.5, by + 3.5), 4.0, cc, 7.0 if not golden_ready else 10.0)
		CanvasUtil.round_rect(self, Rect2(bx, by, bw * t, 7), 3.0, cc)
		var mark_x: float = bx + bw * shout_t
		draw_line(Vector2(mark_x, by - 1), Vector2(mark_x, by + 8), Color(1.0, 0.45, 0.2, 0.55), 1.0)
		var label: String
		if golden_ready:
			label = "SHIFT — %s!" % GameConstants.BOSS_DASH_ECHO_NAME
		elif t >= shout_t:
			label = "GÜRÜLTÜLÜ — CANAVAR DUYAR!"
		else:
			label = "ECHO %d%%" % int(t * 100)
		_draw_text(label, Vector2(GameConstants.CANVAS_W / 2.0, by - 4), 10, cc, HORIZONTAL_ALIGNMENT_CENTER)
		if t >= shout_t * 0.85 and _in_grace_zone():
			_draw_text(
				"İlk 150m: canavar uyumaz",
				Vector2(GameConstants.CANVAS_W / 2.0, by - 20),
				9,
				Color(0, 0.96, 1, 0.55),
				HORIZONTAL_ALIGNMENT_CENTER
			)
	else:
		var echo_cd := maxf(0.0, _effective_echo_cooldown_ms() - (GameConstants.now_ms() - last_echo_time))
		var echo_y := GameConstants.CANVAS_H - 54.0
		if echo_cd > 0.0:
			var echo_cd_frac := echo_cd / _effective_echo_cooldown_ms()
			var cd_pos := Vector2(GameConstants.CANVAS_W / 2.0, echo_y)
			draw_arc(cd_pos, 9.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - echo_cd_frac), 24, Color(0, 0.96, 1, 0.45), 2.0)
			_draw_text("%.1fs" % (echo_cd / 1000.0), cd_pos, 10, Color(0, 0.96, 1, 0.65), HORIZONTAL_ALIGNMENT_CENTER)
		else:
			_draw_text("ECHO HAZIR", Vector2(GameConstants.CANVAS_W / 2.0, echo_y), 10, Color(0, 0.96, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
		if _in_grace_zone():
			_draw_text(
				"İlk 150m: canavar uyumaz",
				Vector2(GameConstants.CANVAS_W / 2.0, echo_y - 30),
				9,
				Color(0, 0.96, 1, 0.45),
				HORIZONTAL_ALIGNMENT_CENTER
			)

	if _shout_hint_timer > 0.0:
		var hint_alpha: float = 1.0 if _shout_hint_timer > 1.0 else _shout_hint_timer
		_draw_text(
			"%d%%+ bağırma canavarı uyandırır" % int(shout_t * 100.0),
			Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H - 70.0),
			9,
			Color(0, 0.96, 1, 0.4 * hint_alpha),
			HORIZONTAL_ALIGNMENT_CENTER
		)

	if state == GameState.BOSS:
		_draw_boss_combat_hud(_time)

	var mon_dist := GameConstants.hypot(player_wx - monster_wx, player_wy - monster_wy)
	var threat := 0.0
	if monster_awake:
		threat = maxf(0.0, 1.0 - mon_dist / GameConstants.MONSTER_WARN_DIST)
	if state != GameState.BOSS and threat > 0.2:
		var a: float = (threat - 0.2) / 0.8
		draw_rect(Rect2(0, 0, GameConstants.CANVAS_W, GameConstants.CANVAS_H), Color(0.78, 0, 0, a * 0.1))
		_draw_text_glow("⚠ CANAVAR YAKLAŞIYOR", Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H - 10), int(11 + a * 3), Color(1, 0.2, 0.2, a * 0.9), 10.0 * a, true)


func _render_menu(_time: float) -> void:
	_draw_texture_cover(
		_tex_menu,
		Rect2(0.0, 0.0, GameConstants.CANVAS_W, GameConstants.CANVAS_H)
	)

	var bx := 96.0
	var bw := 200.0
	var bh := 38.0
	var gap := 12.0
	var start_y := 196.0

	var btns := [
		{"label": "Oyna", "action": "play"},
		{"label": "Dükkan", "action": "market"},
		{"label": "Ayarlar", "action": "settings"},
	]

	menu_buttons.clear()
	for i in range(btns.size()):
		var b: Dictionary = btns[i]
		var by := start_y + float(i) * (bh + gap)
		menu_buttons.append({"x": bx, "y": by, "w": bw, "h": bh, "label": b["label"], "action": b["action"]})
		var hover: bool = _is_hover(bx, by, bw, bh)
		var text_y := by + bh / 2.0 + 5.0
		var text_x := bx + 4.0
		var col := Color("#e8d4d4") if hover else Color(0.82, 0.72, 0.72, 0.88)
		var glow_col := Color("#ff3b3b")
		_draw_text(b["label"], Vector2(text_x + 1.0, text_y + 1.0), 26, Color(0, 0, 0, 0.55), HORIZONTAL_ALIGNMENT_LEFT, true)
		if hover:
			_draw_text_glow(b["label"], Vector2(text_x, text_y), 26, glow_col, 12.0, true)
		else:
			_draw_text(b["label"], Vector2(text_x, text_y), 26, col, HORIZONTAL_ALIGNMENT_LEFT, true)
		if hover:
			draw_line(
				Vector2(bx, by + bh - 2.0),
				Vector2(bx + bw * 0.55, by + bh - 2.0),
				Color(0.78, 0.18, 0.22, 0.9),
				2.0
			)
		if mouse["clicked"] and hover:
			_play_ui_click()
			if b["action"] == "play":
				_reset_game(true)
			elif b["action"] == "market":
				state = GameState.MARKET
				SfxPlayer.play("market")
			elif b["action"] == "settings":
				_rebind_action = ""
				state = GameState.SETTINGS

	var jam_by := start_y + float(btns.size()) * (bh + gap)
	var jam_text_y := jam_by + bh / 2.0 + 5.0
	var jam_text_x := bx + 4.0
	var jam_col := Color(0.82, 0.72, 0.72, 0.88)
	_draw_text("BANÜ JAM' 26", Vector2(jam_text_x + 1.0, jam_text_y + 1.0), 26, Color(0, 0, 0, 0.55), HORIZONTAL_ALIGNMENT_LEFT, true)
	_draw_text("BANÜ JAM' 26", Vector2(jam_text_x, jam_text_y), 26, jam_col, HORIZONTAL_ALIGNMENT_LEFT, true)

	var best_label := "En iyi: %dm  ·  " % int(high_score / 10.0)
	_draw_text(best_label, Vector2(52.0, GameConstants.CANVAS_H - 22.0), 11, Color(1, 1, 1, 0.42), HORIZONTAL_ALIGNMENT_LEFT, true)
	_draw_coin_amount(Vector2(52.0 + float(best_label.length()) * 5.6, GameConstants.CANVAS_H - 32.0), total_coins, 11, Color(1, 1, 1, 0.42))
	_draw_text("coin", Vector2(52.0 + float(best_label.length()) * 5.6 + 52.0, GameConstants.CANVAS_H - 22.0), 11, Color(1, 1, 1, 0.42), HORIZONTAL_ALIGNMENT_LEFT, true)
	_draw_text("SPACE / ENTER — Oyna", Vector2(GameConstants.CANVAS_W - 52.0, GameConstants.CANVAS_H - 22.0), 10, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_RIGHT, true)


func _render_settings(_time: float) -> void:
	draw_rect(Rect2(0, 0, GameConstants.CANVAS_W, GameConstants.CANVAS_H), Color("#030306"))
	for x in range(0, GameConstants.CANVAS_W, 60):
		draw_line(Vector2(x, 0), Vector2(x, GameConstants.CANVAS_H), Color(0, 0.78, 1, 0.04), 1.0)
	for y in range(0, GameConstants.CANVAS_H, 60):
		draw_line(Vector2(0, y), Vector2(GameConstants.CANVAS_W, y), Color(0, 0.78, 1, 0.04), 1.0)

	_draw_text_glow("AYARLAR", Vector2(GameConstants.CANVAS_W / 2.0, 52), 36, Color("#aaaaff"), 16.0, true)

	var row_w := 440.0
	var row_h := 40.0
	var row_x := GameConstants.CANVAS_W / 2.0 - row_w / 2.0
	var row_y := 92.0
	var row_gap := 10.0

	var toggles := [
		{"label": "Müzik", "on": music_enabled, "action": "music"},
		{"label": "Tehlike Sesi", "on": threat_audio_enabled, "action": "threat"},
	]
	for toggle in toggles:
		var hover: bool = _is_hover(row_x, row_y, row_w, row_h)
		var on: bool = toggle["on"]
		var border_col := Color("#00f5ff") if hover else Color(1, 1, 1, 0.15)
		CanvasUtil.round_rect(
			self, Rect2(row_x, row_y, row_w, row_h), 10.0,
			Color(0, 0.96, 1, 0.1) if hover else Color(0, 0, 0, 0.45),
			border_col, 2.0 if hover else 1.5
		)
		_draw_text(str(toggle["label"]), Vector2(row_x + 16, row_y + row_h / 2.0 + 4), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
		var status_col := Color("#00ffb0") if on else Color(1, 0.35, 0.35, 0.85)
		var status := "AÇIK" if on else "KAPALI"
		_draw_text(status, Vector2(row_x + row_w - 16, row_y + row_h / 2.0 + 4), 13, status_col, HORIZONTAL_ALIGNMENT_RIGHT, true)
		if mouse["clicked"] and hover and _rebind_action == "":
			_play_ui_click()
			match str(toggle["action"]):
				"music":
					toggle_music()
				"threat":
					threat_audio_enabled = !threat_audio_enabled
					_save_settings()
		row_y += row_h + row_gap

	row_y += 6.0
	_draw_text("TUŞ ATAMALARI", Vector2(row_x, row_y), 12, Color(0, 0.96, 1, 0.65), HORIZONTAL_ALIGNMENT_LEFT, true)
	row_y += 20.0

	var col_w := 212.0
	var col_gap := 16.0
	var key_h := 34.0
	var key_gap := 8.0
	var left_x := GameConstants.CANVAS_W / 2.0 - col_w - col_gap / 2.0
	var right_x := GameConstants.CANVAS_W / 2.0 + col_gap / 2.0
	for i in InputSetup.REBINDABLE.size():
		var entry: Dictionary = InputSetup.REBINDABLE[i]
		var col_x := left_x if i < 4 else right_x
		var col_y := row_y + float(i % 4) * (key_h + key_gap)
		var action: String = entry["action"]
		var waiting := _rebind_action == action
		var hover: bool = _is_hover(col_x, col_y, col_w, key_h)
		var border_col := Color("#00f5ff") if waiting else (Color("#aaaaff") if hover else Color(1, 1, 1, 0.12))
		CanvasUtil.round_rect(
			self, Rect2(col_x, col_y, col_w, key_h), 8.0,
			Color(0, 0.96, 1, 0.14) if waiting else (Color(0, 0.96, 1, 0.08) if hover else Color(0, 0, 0, 0.42)),
			border_col, 2.0 if (waiting or hover) else 1.5
		)
		_draw_text(str(entry["label"]), Vector2(col_x + 12, col_y + key_h / 2.0 + 3), 12, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
		var key_text := "Tuşa bas..." if waiting else InputSetup.get_primary_key_label(action)
		var key_col := Color("#00f5ff") if waiting else Color(0, 0.96, 1, 0.85)
		_draw_text(key_text, Vector2(col_x + col_w - 12, col_y + key_h / 2.0 + 3), 11, key_col, HORIZONTAL_ALIGNMENT_RIGHT, true)
		if mouse["clicked"] and hover:
			_rebind_action = action

	var reset_w := 200.0
	var reset_h := 34.0
	var reset_x := GameConstants.CANVAS_W / 2.0 - reset_w / 2.0
	var reset_y := row_y + 4.0 * (key_h + key_gap) + 10.0
	var reset_hover: bool = _is_hover(reset_x, reset_y, reset_w, reset_h)
	CanvasUtil.round_rect(
		self, Rect2(reset_x, reset_y, reset_w, reset_h), 8.0,
		Color(1, 0.5, 0.2, 0.12) if reset_hover else Color(0, 0, 0, 0.42),
		Color(1, 0.55, 0.25, 0.7), 1.5
	)
	_draw_text("Varsayılana Dön", Vector2(reset_x + reset_w / 2.0, reset_y + reset_h / 2.0 + 3), 12, Color(1, 0.7, 0.4), HORIZONTAL_ALIGNMENT_CENTER, true)
	if mouse["clicked"] and reset_hover:
		_reset_key_bindings()

	if _rebind_action != "":
		_draw_text("Yeni tuşa bas — ESC iptal", Vector2(GameConstants.CANVAS_W / 2.0, reset_y + reset_h + 18), 11, Color(0, 0.96, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER)

	var bw := 150.0
	var bh := 40.0
	var bx := GameConstants.CANVAS_W / 2.0 - bw / 2.0
	var by := GameConstants.CANVAS_H - 58.0
	var back_hover: bool = _is_hover(bx, by, bw, bh)
	CanvasUtil.round_rect(
		self, Rect2(bx, by, bw, bh), 10.0,
		Color(1, 1, 1, 0.08) if back_hover else Color(0, 0, 0, 0.45),
		Color("#aaaaaa"), 2.0 if back_hover else 1.5
	)
	_draw_text_glow("← GERİ", Vector2(GameConstants.CANVAS_W / 2.0, by + bh / 2.0 + 4), 13, Color("#aaaaaa"), 10.0 if back_hover else 6.0, true)
	if mouse["clicked"] and back_hover:
		_rebind_action = ""
		state = GameState.MENU


func _draw_market_rows(
	catalog: Array,
	row_x: float,
	row_y: float,
	row_w: float,
	row_h: float,
	row_gap: float,
	accent: Color
) -> float:
	for entry in catalog:
		var item: Dictionary = entry as Dictionary
		var upgrade_id: String = str(item["id"])
		var level: int = int(upgrade_levels.get(upgrade_id, 0))
		var max_level: int = int(item["max_level"])
		var maxed := level >= max_level
		var cost: int = MarketUpgrades.cost_for(upgrade_id, level)
		var can_afford := total_coins >= cost
		var hover: bool = _is_hover(row_x, row_y, row_w, row_h)
		var border_col := accent if hover and not maxed else Color(1, 1, 1, 0.15)
		CanvasUtil.round_rect(
			self, Rect2(row_x, row_y, row_w, row_h), 10.0,
			Color(accent.r, accent.g, accent.b, 0.1) if hover and not maxed else Color(0, 0, 0, 0.45),
			border_col, 2.0 if hover else 1.5
		)
		_draw_text(str(item["label"]), Vector2(row_x + 14, row_y + 18), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
		_draw_text(str(item["desc"]), Vector2(row_x + 14, row_y + 36), 10, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_LEFT)
		var effect := MarketUpgrades.effect_summary(upgrade_id, level)
		_draw_text("Sv.%d/%d  →  %s" % [level, max_level, effect], Vector2(row_x + row_w - 14, row_y + 18), 10, Color(0, 0.96, 1, 0.7), HORIZONTAL_ALIGNMENT_RIGHT, true)
		if maxed:
			_draw_text("MAX", Vector2(row_x + row_w - 14, row_y + 38), 12, Color("#00ffb0"), HORIZONTAL_ALIGNMENT_RIGHT, true)
		elif can_afford:
			_draw_coin_line_right(Vector2(row_x + row_w - 14, row_y + 30), cost, "Satın Al", 11, accent)
		else:
			_draw_coin_line_right(Vector2(row_x + row_w - 14, row_y + 30), cost, "Yetersiz", 11, Color(1, 0.35, 0.35, 0.75))
		if mouse["clicked"] and hover and not maxed and can_afford:
			if _buy_upgrade(upgrade_id):
				_play_ui_click()
		row_y += row_h + row_gap
	return row_y


func _render_market(_time: float) -> void:
	draw_rect(Rect2(0, 0, GameConstants.CANVAS_W, GameConstants.CANVAS_H), Color("#030306"))
	for x in range(0, GameConstants.CANVAS_W, 60):
		draw_line(Vector2(x, 0), Vector2(x, GameConstants.CANVAS_H), Color(0, 0.78, 1, 0.04), 1.0)
	for y in range(0, GameConstants.CANVAS_H, 60):
		draw_line(Vector2(0, y), Vector2(GameConstants.CANVAS_W, y), Color(0, 0.78, 1, 0.04), 1.0)

	_draw_text_glow("MARKET", Vector2(GameConstants.CANVAS_W / 2.0, 44), 34, Color("#ffd700"), 14.0, true)
	_draw_coin_amount_center(Vector2(GameConstants.CANVAS_W / 2.0, 76), total_coins, 14, Color(1, 1, 1, 0.75), " coin")

	var row_w := 500.0
	var row_h := 58.0
	var row_x := GameConstants.CANVAS_W / 2.0 - row_w / 2.0
	var row_y := 96.0
	var row_gap := 8.0

	row_y = _draw_market_rows(MarketUpgrades.COIN_CATALOG, row_x, row_y, row_w, row_h, row_gap, Color("#ffd700"))

	_draw_text("Satıra tıkla — kalıcı güçlenme", Vector2(GameConstants.CANVAS_W / 2.0, row_y + 6), 10, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_CENTER)

	var bw := 150.0
	var bh := 40.0
	var bx := GameConstants.CANVAS_W / 2.0 - bw / 2.0
	var by := GameConstants.CANVAS_H - 58.0
	var back_hover: bool = _is_hover(bx, by, bw, bh)
	CanvasUtil.round_rect(
		self, Rect2(bx, by, bw, bh), 10.0,
		Color(1, 1, 1, 0.08) if back_hover else Color(0, 0, 0, 0.45),
		Color("#aaaaaa"), 2.0 if back_hover else 1.5
	)
	_draw_text_glow("← GERİ", Vector2(GameConstants.CANVAS_W / 2.0, by + bh / 2.0 + 4), 13, Color("#aaaaaa"), 10.0 if back_hover else 6.0, true)
	if mouse["clicked"] and back_hover:
		state = GameState.MENU


func _render_overlay(title: String, sub: String, _time: float) -> void:
	draw_rect(Rect2(0, 0, GameConstants.CANVAS_W, GameConstants.CANVAS_H), Color("#030306"))
	_draw_text(title, Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H / 2.0 - 30), 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	_draw_text(sub, Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H / 2.0 + 10), 16, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_CENTER)

	var bw := 140.0
	var bh := 42.0
	var bx := GameConstants.CANVAS_W / 2.0 - bw / 2.0
	var by := GameConstants.CANVAS_H / 2.0 + 60.0
	var hover: bool = _is_hover(bx, by, bw, bh)
	CanvasUtil.round_rect(self, Rect2(bx, by, bw, bh), 8.0, Color(1, 1, 1, 0.08) if hover else Color(0, 0, 0, 0), Color("#aaaaaa"), 1.5)
	_draw_text("← GERİ", Vector2(GameConstants.CANVAS_W / 2.0, by + bh / 2.0 + 5), 13, Color("#aaaaaa"), HORIZONTAL_ALIGNMENT_CENTER, true)
	if mouse["clicked"] and hover:
		state = GameState.MENU


func _render_story(_time: float) -> void:
	var fade_alpha: float = 1.0
	if _story_slide.is_finished():
		fade_alpha = clampf(_story_to_boss_fade / GameConstants.STORY_TO_BOSS_FADE_SEC, 0.0, 1.0)
		draw_rect(Rect2(0, 0, GameConstants.CANVAS_W, GameConstants.CANVAS_H), Color(0, 0, 0, fade_alpha))
		return

	draw_rect(Rect2(0, 0, GameConstants.CANVAS_W, GameConstants.CANVAS_H), Color("#0a080c"))
	draw_rect(Rect2(0, GameConstants.CANVAS_H * 0.62, GameConstants.CANVAS_W, GameConstants.CANVAS_H * 0.38), Color("#120e14"))
	for i in range(5):
		var ly := GameConstants.CANVAS_H * 0.64 + float(i) * 18.0
		draw_line(Vector2(0, ly), Vector2(GameConstants.CANVAS_W, ly + 6.0), Color(1, 1, 1, 0.02), 1.0)

	var placed: Array = _story_slide.get_placed_cards()
	for card in placed:
		_draw_story_card(card, 1.0)

	var throwing: Dictionary = _story_slide.get_throwing_card()
	if not throwing.is_empty():
		var pose := _story_slide.card_pose(int(throwing["index"]), _story_slide.throw_progress())
		_draw_story_card(pose, 1.0, int(throwing["index"]))

	var placed_n: int = _story_slide.placed_count()
	var hint := "SPACE / TIK — Kart at"
	if placed_n >= _story_slide.slide_count():
		hint = "SPACE / TIK — Devam"
	elif _story_slide.is_throwing():
		hint = ""

	_draw_text(
		"%d / %d" % [placed_n, _story_slide.slide_count()],
		Vector2(GameConstants.CANVAS_W - 18, 16),
		10,
		Color(1, 1, 1, 0.35),
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	if not hint.is_empty():
		_draw_text(hint, Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H - 18), 10, Color(0.82, 0.72, 0.72, 0.45), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_story_card(card: Dictionary, alpha: float, scene_index: int = -1) -> void:
	var index: int = scene_index if scene_index >= 0 else int(card.get("index", 0))
	var tex: Texture2D = _story_slide.get_scene_texture(index)
	if tex == null:
		return

	var pos: Vector2 = card.get("pos", _story_slide.stack_center())
	var rot_deg: float = float(card.get("rot", 0.0))
	var scale: float = float(card.get("scale", 1.0))
	var card_w: float = StorySlideshow.CARD_W * scale
	var card_h: float = StorySlideshow.CARD_H * scale
	var half := Vector2(card_w, card_h) * 0.5
	var rot_rad: float = deg_to_rad(rot_deg)

	draw_set_transform_matrix(Transform2D(rot_rad, pos))
	var shadow_rect := Rect2(-half + Vector2(5.0, 7.0), Vector2(card_w, card_h))
	draw_rect(shadow_rect, Color(0, 0, 0, 0.42 * alpha))
	var frame_rect := Rect2(-half - Vector2(3.0, 3.0), Vector2(card_w, card_h) + Vector2(6.0, 6.0))
	CanvasUtil.round_rect(self, frame_rect, 4.0, Color(0.92, 0.9, 0.88, 0.95 * alpha), Color(0.15, 0.12, 0.1, 0.5 * alpha), 2.0)
	draw_texture_rect(tex, Rect2(-half, Vector2(card_w, card_h)), false, Color(1, 1, 1, alpha))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _render_win(_time: float) -> void:
	draw_rect(Rect2(0, 0, GameConstants.CANVAS_W, GameConstants.CANVAS_H), Color(0.01, 0.02, 0.04, 0.88))
	_draw_text_glow("KURTULABİLDİN (AMA ŞİMDİLİK)", Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H / 2.0 - 80), 36, Color("#00ffb0"), 24.0, true)
	_draw_text_glow("1. BÖLÜM TAMAMLANDI", Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H / 2.0 - 36), 22, Color("#00f5ff", 0.9), 14.0, true)
	_draw_text("%dm" % int(score / 10.0), Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H / 2.0 + 4), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	_draw_coin_amount_center(Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H / 2.0 + 36), coins, 14, Color("#ffd700"), " coin")

	var bw := 240.0
	var bh := 46.0
	var gap := 10.0
	var bx := GameConstants.CANVAS_W / 2.0 - bw / 2.0
	var start_y := GameConstants.CANVAS_H / 2.0 + 72.0
	var btns := [
		{"label": "↻  TEKRAR", "action": "retry", "color": "#00f5ff"},
		{"label": "⌂  ANA MENÜ", "action": "menu", "color": "#aaaaff"},
	]
	win_buttons.clear()
	for i in range(btns.size()):
		var b: Dictionary = btns[i]
		var by := start_y + float(i) * (bh + gap)
		win_buttons.append({"x": bx, "y": by, "w": bw, "h": bh, "label": b["label"], "action": b["action"]})
		var hover: bool = _is_hover(bx, by, bw, bh)
		var col: Color = GameConstants.color_from_hex(b["color"])
		CanvasUtil.round_rect(self, Rect2(bx, by, bw, bh), 10.0, Color(0, 0.96, 1, 0.08) if hover else Color(0, 0, 0, 0.45), col, 2.0 if hover else 1.5)
		_draw_text_glow(b["label"], Vector2(bx + bw / 2.0, by + bh / 2.0 + 4), 18, Color.WHITE if hover else col, 14.0 if hover else 8.0)
		if mouse["clicked"] and hover:
			_play_ui_click()
			if b["action"] == "retry":
				_reset_game(false)
			elif b["action"] == "menu":
				_stop_music()
				state = GameState.MENU

	var blink: float = sin(_time * 0.004) * 0.25 + 0.75
	_draw_text("SPACE — Tekrar   ·   M — Menü", Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H - 20), 11, Color(1, 1, 1, blink * 0.55), HORIZONTAL_ALIGNMENT_CENTER)


func _render_pause(_time: float) -> void:
	draw_rect(Rect2(0, 0, GameConstants.CANVAS_W, GameConstants.CANVAS_H), Color(0.01, 0.01, 0.04, 0.72))
	_draw_text_glow("DURAKLATILDI", Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H / 2.0 - 90), 40, Color("#00f5ff"), 24.0, true)
	_draw_text("%dm" % int(score / 10.0), Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H / 2.0 - 48), 18, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER)

	var bw := 260.0
	var bh := 46.0
	var gap := 10.0
	var total_h := 3.0 * bh + 2.0 * gap
	var bx := GameConstants.CANVAS_W / 2.0 - bw / 2.0
	var start_y := GameConstants.CANVAS_H / 2.0 - total_h / 2.0 + 10.0

	var btns := [
		{"label": "▶  DEVAM", "action": "resume", "color": "#00f5ff"},
		{"label": "↻  YENİDEN BAŞLA", "action": "restart", "color": "#ffd700"},
		{"label": "⌂  ANA MENÜ", "action": "menu", "color": "#aaaaff"},
	]

	pause_buttons.clear()
	for i in range(btns.size()):
		var b: Dictionary = btns[i]
		var by := start_y + float(i) * (bh + gap)
		pause_buttons.append({"x": bx, "y": by, "w": bw, "h": bh, "label": b["label"], "action": b["action"]})
		var hover: bool = _is_hover(bx, by, bw, bh)
		var col: Color = GameConstants.color_from_hex(b["color"])
		var blur: float = 18.0 if hover else 8.0
		CanvasUtil.round_rect(self, Rect2(bx, by, bw, bh), 10.0, Color(0, 0.96, 1, 0.08) if hover else Color(0, 0, 0, 0.45), col, 2.0 if hover else 1.5)
		_draw_text_glow(b["label"], Vector2(bx + bw / 2.0, by + bh / 2.0 + 4), 20, Color.WHITE if hover else col, blur)
		if mouse["clicked"] and hover:
			_play_ui_click()
			match b["action"]:
				"resume":
					_resume_game()
				"restart":
					_reset_game(false)
				"menu":
					_quit_to_menu_from_pause()

	_draw_text("ESC — Devam", Vector2(GameConstants.CANVAS_W / 2.0, start_y + total_h + 18), 11, Color(0, 0.96, 1, 0.45), HORIZONTAL_ALIGNMENT_CENTER)


func _render_game_over(time: float) -> void:
	draw_rect(Rect2(0, 0, GameConstants.CANVAS_W, GameConstants.CANVAS_H), Color(0.01, 0.01, 0.02, 0.86))
	_draw_text_glow("YAKALANDIN", Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H / 2.0 - 70), 52, Color("#ff3030"), 40.0, true)
	_draw_text("Canavar seni buldu...", Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H / 2.0 - 30), 14, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	_draw_text("%dm" % int(score / 10.0), Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H / 2.0 + 14), 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	_draw_coin_amount_center(Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H / 2.0 + 42), coins, 16, Color("#ffd700"), " coin toplandı")
	_draw_text("Cüzdan: %d coin" % total_coins, Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H / 2.0 + 62), 12, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	if score >= high_score and score > 0.0:
		_draw_text_glow("YENİ REKOR!", Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H / 2.0 + 80), 14, Color("#ffd700"), 14.0, true)

	var blink: float = sin(time * 0.004) * 0.25 + 0.75
	_draw_text("SPACE / ENTER — Tekrar oyna", Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H / 2.0 + 108), 13, Color(1, 1, 1, blink), HORIZONTAL_ALIGNMENT_CENTER, true)
	_draw_text("M — Ana Menü", Vector2(GameConstants.CANVAS_W / 2.0, GameConstants.CANVAS_H / 2.0 + 128), 13, Color(0, 0.96, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_coin_sprite(center: Vector2, size: float, alpha: float = 1.0, modulate: Color = Color.WHITE) -> void:
	if _tex_coin == null:
		return
	var half := size * 0.5
	draw_texture_rect(
		_tex_coin,
		Rect2(center.x - half, center.y - half, size, size),
		false,
		Color(modulate.r, modulate.g, modulate.b, alpha * modulate.a)
	)


func _draw_coin_amount(anchor: Vector2, amount: int, font_size: int, col: Color) -> void:
	var icon_size: float = float(font_size) + 6.0
	_draw_coin_sprite(anchor + Vector2(icon_size * 0.5, font_size * 0.42), icon_size, col.a, col)
	_draw_text(str(amount), Vector2(anchor.x + icon_size + 4.0, anchor.y + font_size * 0.82), font_size, col, HORIZONTAL_ALIGNMENT_LEFT, true)


func _draw_coin_amount_center(pos: Vector2, amount: int, font_size: int, col: Color, suffix: String = "") -> void:
	var amount_text := str(amount) + suffix
	var icon_size: float = float(font_size) + 6.0
	var char_w: float = float(font_size) * 0.52
	var total_w: float = icon_size + 4.0 + float(amount_text.length()) * char_w
	var start_x: float = pos.x - total_w * 0.5
	_draw_coin_sprite(Vector2(start_x + icon_size * 0.5, pos.y), icon_size, col.a, col)
	_draw_text(amount_text, Vector2(start_x + icon_size + 4.0, pos.y + font_size * 0.35), font_size, col, HORIZONTAL_ALIGNMENT_LEFT, true)


func _draw_coin_line_right(anchor: Vector2, amount: int, suffix: String, font_size: int, col: Color) -> void:
	var line_text := "%d — %s" % [amount, suffix]
	var icon_size: float = float(font_size) + 4.0
	var char_w: float = float(font_size) * 0.52
	var total_w: float = icon_size + 4.0 + float(line_text.length()) * char_w
	var start_x: float = anchor.x - total_w
	_draw_coin_sprite(Vector2(start_x + icon_size * 0.5, anchor.y + font_size * 0.35), icon_size, col.a, col)
	_draw_text(line_text, Vector2(start_x + icon_size + 4.0, anchor.y + font_size * 0.82), font_size, col, HORIZONTAL_ALIGNMENT_LEFT, true)


func _draw_texture_cover(tex: Texture2D, rect: Rect2) -> void:
	if tex == null:
		draw_rect(rect, Color("#030306"))
		return
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	if tw <= 0.0 or th <= 0.0:
		draw_rect(rect, Color("#030306"))
		return
	var scale := maxf(rect.size.x / tw, rect.size.y / th)
	var dst_size := Vector2(tw, th) * scale
	var dst_pos := rect.position + (rect.size - dst_size) * 0.5
	draw_texture_rect(tex, Rect2(dst_pos, dst_size), false)


func _is_hover(x: float, y: float, w: float, h: float) -> bool:
	return float(mouse["x"]) >= x and float(mouse["x"]) <= x + w and float(mouse["y"]) >= y and float(mouse["y"]) <= y + h


func _sprite_dir_index(mvx: float, mvy: float) -> int:
	var oct := int(round(atan2(mvy, mvx) / (PI / 4.0)))
	return SPRITE_DIR_MAP[(oct + 8) % 8]


func _draw_sprite_cell(tex: Texture2D, pos: Vector2, col: int, row: int, size: float, modulate: Color = Color.WHITE) -> void:
	var tw := tex.get_width()
	var th := tex.get_height()
	var fw := tw / SPRITE_GRID
	var fh := th / SPRITE_GRID
	var src := Rect2(col * fw, row * fh, fw, fh)
	var scale := size / maxf(fw, fh)
	var dst_size := Vector2(fw, fh) * scale
	var dst := Rect2(pos.x - dst_size.x * 0.5, pos.y - dst_size.y * 0.5, dst_size.x, dst_size.y)
	draw_texture_rect_region(tex, dst, src, modulate)


func _draw_sprite_sheet_frame(tex: Texture2D, pos: Vector2, dir: int, frame: int, size: float, modulate: Color = Color.WHITE) -> void:
	var tw := tex.get_width()
	var th := tex.get_height()
	var fw := tw / SPRITE_GRID
	var fh := th / SPRITE_GRID
	var col := frame % SPRITE_GRID
	var row := dir % SPRITE_GRID
	var src := Rect2(col * fw, row * fh, fw, fh)
	var scale := size / maxf(fw, fh)
	var dst_size := Vector2(fw, fh) * scale
	var dst := Rect2(pos.x - dst_size.x * 0.5, pos.y - dst_size.y * 0.5, dst_size.x, dst_size.y)
	draw_texture_rect_region(tex, dst, src, modulate)


func _draw_text(text: String, pos: Vector2, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, bold: bool = false) -> void:
	var font_size := maxi(8, size)
	var str_size := _mono_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var draw_pos := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		draw_pos.x -= str_size.x / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		draw_pos.x -= str_size.x
	draw_pos.y += font_size * 0.35
	if bold:
		draw_string(_mono_font, draw_pos + Vector2(1, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	draw_string(_mono_font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_text_glow(text: String, pos: Vector2, size: int, color: Color, blur: float, bold: bool = false) -> void:
	if blur > 0.0:
		var a := color
		a.a *= 0.22
		_draw_text(text, pos + Vector2(1, 1), size, a, HORIZONTAL_ALIGNMENT_CENTER, false)
	_draw_text(text, pos, size, color, HORIZONTAL_ALIGNMENT_CENTER, bold)
