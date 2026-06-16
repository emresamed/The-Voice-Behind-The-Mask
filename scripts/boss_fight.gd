class_name BossFight
extends RefCounted

var active: bool = false
var intro_timer: float = 0.0
var arena_center_wy: float = 0.0
var arena_center_wx: float = 0.0

var meteor_mode: bool = false
var meteor_anchored: bool = false
var meteor_intro_done: bool = false
var meteor_cooldown: float = 0.0

var boss_hp: float = GameConstants.BOSS_MAX_HP
var boss_max_hp: float = GameConstants.BOSS_MAX_HP
var phase: int = 1
var phase_transition_timer: float = 0.0
var in_phase_transition: bool = false
var phase_roar_played: bool = false

var player_hp: float = GameConstants.BOSS_PLAYER_MAX_HP
var player_max_hp: float = GameConstants.BOSS_PLAYER_MAX_HP
var player_invuln: float = 0.0
var combat_invuln_timer: float = 0.0
var player_hit_flash: float = 0.0
var last_hit_source: String = ""
var last_hit_amount: float = 0.0
var last_hit_timer: float = 0.0

var dash_echo_active: bool = false
var dash_echo_timer: float = 0.0
var dash_echo_cooldown: float = 0.0

var boss_hit_flash: float = 0.0
var damage_popups: Array = []
var _damage_popup_accum: float = 0.0
var _damage_popup_accum_timer: float = 0.0

var cinematic_active: bool = false
var cinematic_timer: float = 0.0
var darkness_fade: float = 0.0

var arena_rocks: Array = []
var projectiles: Array = []
var impacts: Array = []

func start(player_wy: float) -> void:
	active = true
	intro_timer = GameConstants.BOSS_INTRO_DURATION
	arena_center_wy = player_wy
	arena_center_wx = (GameConstants.MAP_LEFT + GameConstants.MAP_RIGHT) * 0.5
	meteor_mode = false
	meteor_anchored = false
	meteor_intro_done = false
	meteor_cooldown = 0.0
	boss_hp = GameConstants.BOSS_MAX_HP
	boss_max_hp = GameConstants.BOSS_MAX_HP
	phase = 1
	phase_transition_timer = 0.0
	in_phase_transition = false
	phase_roar_played = false
	player_hp = GameConstants.BOSS_PLAYER_MAX_HP
	player_max_hp = GameConstants.BOSS_PLAYER_MAX_HP
	player_invuln = 0.0
	combat_invuln_timer = GameConstants.BOSS_START_INVULN_SEC
	player_hit_flash = 0.0
	last_hit_source = ""
	last_hit_amount = 0.0
	last_hit_timer = 0.0
	dash_echo_active = false
	dash_echo_timer = 0.0
	dash_echo_cooldown = 0.0
	boss_hit_flash = 0.0
	damage_popups.clear()
	_damage_popup_accum = 0.0
	_damage_popup_accum_timer = 0.0
	cinematic_active = false
	cinematic_timer = 0.0
	darkness_fade = 0.0
	arena_rocks.clear()
	projectiles.clear()
	impacts.clear()
func reset() -> void:
	active = false
	intro_timer = 0.0
	arena_center_wy = 0.0
	arena_center_wx = 0.0
	meteor_mode = false
	meteor_anchored = false
	meteor_intro_done = false
	meteor_cooldown = 0.0
	boss_hp = GameConstants.BOSS_MAX_HP
	phase = 1
	in_phase_transition = false
	player_hp = GameConstants.BOSS_PLAYER_MAX_HP
	dash_echo_active = false
	dash_echo_cooldown = 0.0
	boss_hit_flash = 0.0
	damage_popups.clear()
	_damage_popup_accum = 0.0
	_damage_popup_accum_timer = 0.0
	cinematic_active = false
	arena_rocks.clear()
	projectiles.clear()
	impacts.clear()


func update(dt: float, obstacles: Array = []) -> void:
	if not active:
		return
	if intro_timer > 0.0:
		intro_timer = maxf(0.0, intro_timer - dt)
		return
	if combat_invuln_timer > 0.0:
		combat_invuln_timer = maxf(0.0, combat_invuln_timer - dt)
	if player_invuln > 0.0:
		player_invuln = maxf(0.0, player_invuln - dt)
	if player_hit_flash > 0.0:
		player_hit_flash = maxf(0.0, player_hit_flash - dt)
	if last_hit_timer > 0.0:
		last_hit_timer = maxf(0.0, last_hit_timer - dt)
	if dash_echo_cooldown > 0.0:
		dash_echo_cooldown = maxf(0.0, dash_echo_cooldown - dt)
	if dash_echo_active:
		dash_echo_timer = maxf(0.0, dash_echo_timer - dt)
		if dash_echo_timer <= 0.0:
			dash_echo_active = false
	if boss_hit_flash > 0.0:
		boss_hit_flash = maxf(0.0, boss_hit_flash - dt)
	_update_damage_popups(dt)
	_update_projectiles(dt, obstacles)
	_update_impacts(dt)
	if meteor_mode and meteor_anchored:
		_tick_meteor_rain(dt)
	if cinematic_active:
		cinematic_timer += dt
		darkness_fade = clampf(cinematic_timer / 2.5, 0.0, 1.0)
		return
	if in_phase_transition:
		phase_transition_timer = maxf(0.0, phase_transition_timer - dt)
		if phase_transition_timer <= 0.0:
			in_phase_transition = false
		return


func in_intro() -> bool:
	return active and intro_timer > 0.0


func intro_alpha() -> float:
	if intro_timer <= 0.0:
		return 0.0
	return clampf(1.0 - intro_timer / GameConstants.BOSS_INTRO_DURATION, 0.0, 1.0)


func is_input_locked() -> bool:
	return in_intro() or cinematic_active or boss_hp <= 0.0


func is_movement_locked() -> bool:
	return is_input_locked() or in_phase_transition


func is_cinematic() -> bool:
	return cinematic_active


func cinematic_progress() -> float:
	return clampf(cinematic_timer / GameConstants.BOSS_VICTORY_CINEMATIC_SEC, 0.0, 1.0)


func cinematic_title_alpha() -> float:
	if not cinematic_active:
		return 0.0
	return clampf((cinematic_timer - 1.5) / 1.5, 0.0, 1.0)


func is_won() -> bool:
	return active and cinematic_active and cinematic_timer >= GameConstants.BOSS_VICTORY_CINEMATIC_SEC


func is_player_dead() -> bool:
	return active and player_hp <= 0.0


func boss_hp_frac() -> float:
	return clampf(boss_hp / maxf(boss_max_hp, 1.0), 0.0, 1.0)


func player_hp_frac() -> float:
	return clampf(player_hp / maxf(player_max_hp, 1.0), 0.0, 1.0)


func dash_echo_ready() -> bool:
	return (
		active
		and not dash_echo_active
		and dash_echo_cooldown <= 0.0
		and not in_intro()
		and not cinematic_active
		and boss_hp > 0.0
	)


func dash_echo_cooldown_frac() -> float:
	if dash_echo_cooldown <= 0.0:
		return 0.0
	return clampf(dash_echo_cooldown / GameConstants.BOSS_DASH_ECHO_COOLDOWN, 0.0, 1.0)


func full_arena_visible() -> bool:
	return dash_echo_active or darkness_fade > 0.01


func darkness_mask_alpha() -> float:
	if dash_echo_active:
		return 0.0
	if cinematic_active:
		return 1.0 - darkness_fade
	return 1.0


func clamp_player_wy(wy: float) -> float:
	var min_wy := arena_center_wy - GameConstants.BOSS_ARENA_HALF_HEIGHT
	var max_wy := arena_center_wy + GameConstants.BOSS_ARENA_HALF_HEIGHT * 0.35
	return clampf(wy, min_wy, max_wy)


func spawn_monster(player_wx: float, player_wy: float) -> Dictionary:
	return {
		"wx": player_wx,
		"wy": player_wy - GameConstants.MONSTER_WAKE_SPAWN_DIST,
	}


func build_arena_rocks(center_wx: float, center_wy: float) -> Array:
	arena_rocks.clear()
	var layout := [
		{"xf": 0.15, "yo": -520.0},
		{"xf": 0.85, "yo": -520.0},
		{"xf": 0.22, "yo": -180.0},
		{"xf": 0.78, "yo": -180.0},
		{"xf": 0.12, "yo": 160.0},
		{"xf": 0.88, "yo": 160.0},
		{"xf": 0.35, "yo": -360.0},
		{"xf": 0.65, "yo": -360.0},
	]
	var rocks: Array = []
	var w := GameConstants.BOSS_ARENA_ROCK_W
	var h := GameConstants.BOSS_ARENA_ROCK_H
	for entry in layout:
		var wx: float = GameConstants.MAP_LEFT + GameConstants.MAP_W * float(entry["xf"]) - w * 0.5
		var wy: float = center_wy + float(entry["yo"]) - h * 0.5
		var rock := {
			"id": rocks.size() + 1,
			"wx": wx,
			"wy": wy,
			"w": w,
			"h": h,
			"kind": "rock",
			"hit_flash": -9999.0,
			"revealed_until": 999999999.0,
			"arena_rock": true,
		}
		rocks.append(rock)
		arena_rocks.append(rock)
	return rocks


func apply_boss_damage(amount: float) -> void:
	if not active or cinematic_active or in_phase_transition or intro_timer > 0.0 or boss_hp <= 0.0:
		return
	boss_hit_flash = 0.28
	_register_boss_damage_popup(amount)
	var prev_frac := boss_hp_frac()
	boss_hp = maxf(0.0, boss_hp - amount)
	if boss_hp <= 0.0:
		start_victory_cinematic()
		return
	var new_frac := boss_hp_frac()
	if phase == 1 and prev_frac > GameConstants.BOSS_PHASE2_HP_FRAC and new_frac <= GameConstants.BOSS_PHASE2_HP_FRAC:
		trigger_phase_transition()
	if not meteor_mode and prev_frac > GameConstants.BOSS_PHASE3_HP_FRAC and new_frac <= GameConstants.BOSS_PHASE3_HP_FRAC:
		trigger_meteor_phase()


func is_combat_invuln() -> bool:
	return combat_invuln_timer > 0.0


func apply_player_damage(amount: float, dash_invuln: bool, source: String = "") -> bool:
	if not active or cinematic_active or in_phase_transition:
		return false
	if dash_invuln or player_invuln > 0.0 or combat_invuln_timer > 0.0:
		return false
	player_hp = maxf(0.0, player_hp - amount)
	player_invuln = GameConstants.BOSS_PLAYER_INVULN_SEC
	player_hit_flash = 0.35
	last_hit_source = source
	last_hit_amount = amount
	last_hit_timer = 2.0
	return player_hp <= 0.0


func trigger_phase_transition() -> void:
	phase = 2
	in_phase_transition = true
	phase_transition_timer = GameConstants.BOSS_PHASE_TRANSITION_SEC
	phase_roar_played = false


func trigger_meteor_phase() -> void:
	phase = 3
	meteor_mode = true
	meteor_anchored = false
	meteor_intro_done = false
	meteor_cooldown = 0.0


func arena_center_pos() -> Vector2:
	return Vector2(arena_center_wx, arena_center_wy)


func start_victory_cinematic() -> void:
	if cinematic_active:
		return
	cinematic_active = true
	cinematic_timer = 0.0
	dash_echo_active = false


func activate_dash_echo() -> void:
	dash_echo_active = true
	dash_echo_timer = GameConstants.BOSS_DASH_ECHO_DURATION
	dash_echo_cooldown = GameConstants.BOSS_DASH_ECHO_COOLDOWN


func _register_boss_damage_popup(amount: float) -> void:
	if amount >= 2.5:
		_push_damage_popup(amount)
	else:
		_damage_popup_accum += amount


func _push_damage_popup(amount: float) -> void:
	damage_popups.append({
		"amount": amount,
		"life": 0.9,
		"max_life": 0.9,
		"offset_x": randf_range(-36.0, 36.0),
		"rise": randf_range(-18.0, -8.0),
	})


func _update_damage_popups(dt: float) -> void:
	_damage_popup_accum_timer += dt
	if _damage_popup_accum_timer >= 0.35 and _damage_popup_accum >= 1.0:
		_push_damage_popup(_damage_popup_accum)
		_damage_popup_accum = 0.0
		_damage_popup_accum_timer = 0.0
	var alive: Array = []
	for popup in damage_popups:
		var p: Dictionary = popup
		p["life"] = float(p["life"]) - dt
		if float(p["life"]) > 0.0:
			alive.append(p)
	damage_popups = alive


func spawn_line_rock_volley(from_wx: float, from_wy: float, player_wx: float, player_wy: float) -> void:
	var aim_wx := player_wx
	var aim_wy := player_wy - GameConstants.BOSS_LINE_ROCK_OFFSET
	var dx := aim_wx - from_wx
	var dy := aim_wy - from_wy
	var dist := maxf(GameConstants.hypot(dx, dy), 1.0)
	var dir_x := dx / dist
	var dir_y := dy / dist
	var spd := GameConstants.BOSS_LINE_ROCK_SPEED
	for i in range(GameConstants.BOSS_LINE_ROCK_COUNT):
		var start_frac: float = 0.18 + float(i) * 0.14
		projectiles.append({
			"wx": from_wx + dir_x * dist * start_frac,
			"wy": from_wy + dir_y * dist * start_frac,
			"vx": dir_x * spd,
			"vy": dir_y * spd,
			"life": 2.4,
			"radius": GameConstants.BOSS_ROCK_HIT_RADIUS,
			"hit": false,
			"line_rock": true,
		})


func spawn_meteor(target_wx: float, target_wy: float) -> void:
	projectiles.append({
		"wx": target_wx + randf_range(-18.0, 18.0),
		"wy": target_wy - GameConstants.BOSS_METEOR_SPAWN_HEIGHT,
		"vx": 0.0,
		"vy": GameConstants.BOSS_METEOR_FALL_SPEED,
		"life": 2.2,
		"radius": GameConstants.BOSS_METEOR_RADIUS,
		"hit": false,
		"meteor": true,
	})


func _tick_meteor_rain(dt: float) -> void:
	meteor_cooldown = maxf(0.0, meteor_cooldown - dt)


func try_spawn_meteor(player_wx: float, player_wy: float, player_vx: float, player_vy: float) -> bool:
	if not meteor_mode or not meteor_anchored or meteor_cooldown > 0.0:
		return false
	meteor_cooldown = GameConstants.BOSS_METEOR_COOLDOWN
	var predict := GameConstants.MONSTER_PREDICT_SEC * 0.35
	spawn_meteor(player_wx + player_vx * predict, player_wy + player_vy * predict)
	return true


func spawn_rock_projectile(from_wx: float, from_wy: float, target_wx: float, target_wy: float) -> void:
	var dx := target_wx - from_wx
	var dy := target_wy - from_wy
	var dist := maxf(GameConstants.hypot(dx, dy), 1.0)
	var spd := GameConstants.BOSS_ROCK_THROW_SPEED
	projectiles.append({
		"wx": from_wx,
		"wy": from_wy,
		"vx": (dx / dist) * spd,
		"vy": (dy / dist) * spd,
		"life": 2.5,
		"radius": GameConstants.BOSS_ROCK_HIT_RADIUS,
		"hit": false,
	})


func _update_projectiles(dt: float, obstacles: Array) -> void:
	var i := projectiles.size() - 1
	while i >= 0:
		var p: Dictionary = projectiles[i]
		var prev_wy := float(p["wy"])
		p["wx"] = float(p["wx"]) + float(p["vx"]) * dt
		p["wy"] = float(p["wy"]) + float(p["vy"]) * dt
		if p.get("meteor", false) and not p.get("hit", false):
			var rock_hit := _meteor_hits_rock_path(
				float(p["wx"]),
				prev_wy,
				float(p["wy"]),
				float(p["radius"]),
				obstacles
			)
			if not rock_hit.is_empty():
				p["hit"] = true
				_spawn_impact(float(rock_hit["wx"]), float(rock_hit["wy"]))
				_flash_arena_rock(rock_hit["rock"])
				projectiles.remove_at(i)
				i -= 1
				continue
		p["life"] = float(p["life"]) - dt
		if float(p["life"]) <= 0.0:
			projectiles.remove_at(i)
		i -= 1


func _meteor_hits_rock_path(
	meteor_wx: float,
	from_wy: float,
	to_wy: float,
	radius: float,
	obstacles: Array
) -> Dictionary:
	var min_y := minf(from_wy, to_wy) - radius
	var max_y := maxf(from_wy, to_wy) + radius
	for obs in obstacles:
		if not obs.get("arena_rock", false):
			continue
		var rx := float(obs["wx"]) - 4.0
		var ry := float(obs["wy"]) - 4.0
		var rw := float(obs["w"]) + 8.0
		var rh := float(obs["h"]) + 8.0
		if meteor_wx < rx or meteor_wx > rx + rw:
			continue
		if max_y < ry or min_y > ry + rh:
			continue
		var hit_wy: float = maxf(ry, minf(to_wy, ry + rh * 0.35))
		return {"wx": meteor_wx, "wy": hit_wy, "rock": obs}
	return {}


func _player_sheltered_from_meteor(
	player_wx: float,
	player_wy: float,
	meteor_wx: float,
	obstacles: Array
) -> bool:
	for obs in obstacles:
		if not obs.get("arena_rock", false):
			continue
		var rx := float(obs["wx"])
		var ry := float(obs["wy"])
		var rw := float(obs["w"])
		var rh := float(obs["h"])
		if meteor_wx < rx - 6.0 or meteor_wx > rx + rw + 6.0:
			continue
		var dist := _point_rect_dist(player_wx, player_wy, rx, ry, rw, rh)
		if dist > GameConstants.PLAYER_R + GameConstants.BOSS_METEOR_ROCK_SHELTER:
			continue
		if player_wy < ry + rh * 0.15:
			continue
		return true
	return false


func _point_rect_dist(px: float, py: float, rx: float, ry: float, rw: float, rh: float) -> float:
	var cx := clampf(px, rx, rx + rw)
	var cy := clampf(py, ry, ry + rh)
	return GameConstants.hypot(px - cx, py - cy)


func _flash_arena_rock(rock: Dictionary) -> void:
	rock["hit_flash"] = GameConstants.now_ms()
	rock["revealed_until"] = maxf(float(rock.get("revealed_until", 0.0)), GameConstants.now_ms() + 800.0)


func check_projectile_hit(
	player_wx: float,
	player_wy: float,
	dash_invuln: bool,
	obstacles: Array = []
) -> bool:
	for p in projectiles:
		if p.get("hit", false):
			continue
		var dist := GameConstants.hypot(player_wx - float(p["wx"]), player_wy - float(p["wy"]))
		if dist > GameConstants.PLAYER_R + float(p["radius"]):
			continue
		if p.get("meteor", false) and _player_sheltered_from_meteor(
			player_wx,
			player_wy,
			float(p["wx"]),
			obstacles
		):
			p["hit"] = true
			_spawn_impact(float(p["wx"]), float(p["wy"]))
			continue
		var dmg: float = GameConstants.BOSS_ROCK_DAMAGE
		var source := "KAYA ATIŞI"
		if p.get("meteor", false):
			dmg = GameConstants.BOSS_METEOR_DAMAGE
			source = "GÖKTAŞI"
		elif p.get("line_rock", false):
			dmg = GameConstants.BOSS_LINE_ROCK_DAMAGE
			source = "HAT KAYASI"
		if apply_player_damage(dmg, dash_invuln, source):
			p["hit"] = true
			_spawn_impact(float(p["wx"]), float(p["wy"]))
			return true
	return false


func _spawn_impact(wx: float, wy: float) -> void:
	impacts.append({
		"wx": wx,
		"wy": wy,
		"life": 0.45,
		"max_life": 0.45,
	})


func _update_impacts(dt: float) -> void:
	var i := impacts.size() - 1
	while i >= 0:
		var imp: Dictionary = impacts[i]
		imp["life"] = float(imp["life"]) - dt
		if float(imp["life"]) <= 0.0:
			impacts.remove_at(i)
		i -= 1


func nearest_arena_rock(boss_wx: float, boss_wy: float) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := INF
	for rock in arena_rocks:
		var cx := float(rock["wx"]) + float(rock["w"]) * 0.5
		var cy := float(rock["wy"]) + float(rock["h"]) * 0.5
		var d := GameConstants.hypot(boss_wx - cx, boss_wy - cy)
		if d < best_dist:
			best_dist = d
			best = rock
	return best
