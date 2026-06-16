class_name BossAi
extends RefCounted

enum State {
	CHASE,
	SWIPE_WINDUP,
	SWIPE_ACTIVE,
	CHARGE_WINDUP,
	CHARGE_ACTIVE,
	ROCK_WINDUP,
	ROCK_THROW,
	LINE_ROCK_WINDUP,
	LINE_ROCK_THROW,
	METEOR_JUMP,
	METEOR_ANCHOR,
	RECOVER,
	PHASE_TRANSITION,
	DYING,
}

var state: State = State.CHASE
var state_timer: float = 0.0
var pattern_index: int = 0
var face_angle: float = 0.0
var sprite_dir: int = 0

var charge_dir := Vector2.ZERO
var charge_travelled: float = 0.0
var charge_max_dist: float = 0.0
var charge_dash_speed: float = 0.0
var charge_hit_player: bool = false
var swipe_hit_player: bool = false
var rock_target_rock: Dictionary = {}
var pending_rock_throw: bool = false
var pending_line_rock_throw: bool = false
var line_rock_dir := Vector2.ZERO
var telegraph: Dictionary = {}


func reset() -> void:
	state = State.CHASE
	state_timer = 0.0
	pattern_index = 0
	face_angle = 0.0
	sprite_dir = 0
	charge_dir = Vector2.ZERO
	charge_travelled = 0.0
	charge_dash_speed = 0.0
	charge_hit_player = false
	swipe_hit_player = false
	rock_target_rock = {}
	pending_rock_throw = false
	pending_line_rock_throw = false
	line_rock_dir = Vector2.ZERO
	telegraph = {}


func update(
	dt: float,
	boss_wx: float,
	boss_wy: float,
	player_wx: float,
	player_wy: float,
	player_vx: float,
	player_vy: float,
	phase: int,
	in_phase_transition: bool,
	boss_dead: bool,
	boss_fight: BossFight,
	chase_speed: float,
	predict_sec: float
) -> Dictionary:
	if boss_dead:
		state = State.DYING
		telegraph = {"kind": "dying"}
		return {"wx": boss_wx, "wy": boss_wy, "sprite_dir": sprite_dir, "state": state}

	if in_phase_transition:
		state = State.PHASE_TRANSITION
		telegraph = {"kind": "phase", "timer": boss_fight.phase_transition_timer}
		return {"wx": boss_wx, "wy": boss_wy, "sprite_dir": sprite_dir, "state": state}

	if state == State.PHASE_TRANSITION:
		on_phase_transition_end()

	if boss_fight.meteor_mode:
		return _update_meteor_mode(dt, boss_wx, boss_wy, player_wx, player_wy, boss_fight)

	state_timer = maxf(0.0, state_timer - dt)
	var dist := GameConstants.hypot(player_wx - boss_wx, player_wy - boss_wy)
	var recover_time := GameConstants.BOSS_RECOVER_P1 if phase == 1 else GameConstants.BOSS_RECOVER_P2

	match state:
		State.CHASE:
			telegraph = {"kind": "chase"}
			var tx := player_wx + player_vx * predict_sec - boss_wx
			var ty := player_wy + player_vy * predict_sec - boss_wy
			var tl := maxf(GameConstants.hypot(tx, ty), 0.001)
			boss_wx += (tx / tl) * chase_speed * dt
			boss_wy += (ty / tl) * chase_speed * dt
			face_angle = atan2(ty, tx)
			sprite_dir = _dir_from_angle(face_angle)
			var next_atk := _peek_attack(phase)
			if next_atk == State.SWIPE_WINDUP and dist < GameConstants.BOSS_MELEE_RANGE:
				_begin_attack(phase, boss_wx, boss_wy, player_wx, player_wy, player_vx, player_vy, boss_fight)
			elif next_atk == State.CHARGE_WINDUP and dist >= GameConstants.BOSS_CHARGE_MIN_RANGE:
				_begin_attack(phase, boss_wx, boss_wy, player_wx, player_wy, player_vx, player_vy, boss_fight)
			elif next_atk == State.LINE_ROCK_WINDUP and phase >= 2 and dist >= GameConstants.BOSS_CHARGE_MIN_RANGE:
				_begin_attack(phase, boss_wx, boss_wy, player_wx, player_wy, player_vx, player_vy, boss_fight)
			elif next_atk == State.ROCK_WINDUP and phase >= 2 and dist >= GameConstants.BOSS_MELEE_RANGE:
				_begin_attack(phase, boss_wx, boss_wy, player_wx, player_wy, player_vx, player_vy, boss_fight)

		State.SWIPE_WINDUP:
			face_angle = atan2(player_wy - boss_wy, player_wx - boss_wx)
			sprite_dir = _dir_from_angle(face_angle)
			telegraph = {
				"kind": "swipe",
				"wx": boss_wx,
				"wy": boss_wy,
				"angle": face_angle,
				"alpha": 1.0 - state_timer / GameConstants.BOSS_SWIPE_WINDUP,
			}
			if state_timer <= 0.0:
				state = State.SWIPE_ACTIVE
				state_timer = GameConstants.BOSS_SWIPE_ACTIVE
				swipe_hit_player = false

		State.SWIPE_ACTIVE:
			telegraph = {
				"kind": "swipe_active",
				"wx": boss_wx,
				"wy": boss_wy,
				"angle": face_angle,
			}
			if state_timer <= 0.0:
				_enter_recover(recover_time)

		State.CHARGE_WINDUP:
			_aim_charge_at_player(boss_wx, boss_wy, player_wx, player_wy, player_vx, player_vy)
			face_angle = atan2(charge_dir.y, charge_dir.x)
			sprite_dir = _dir_from_angle(face_angle)
			telegraph = {
				"kind": "charge",
				"wx": boss_wx,
				"wy": boss_wy,
				"dir_x": charge_dir.x,
				"dir_y": charge_dir.y,
				"alpha": 1.0 - state_timer / GameConstants.BOSS_CHARGE_WINDUP,
			}
			if state_timer <= 0.0:
				_launch_charge_dash(boss_wx, boss_wy, player_wx, player_wy, player_vx, player_vy)

		State.CHARGE_ACTIVE:
			var step := charge_dash_speed * dt
			boss_wx += charge_dir.x * step
			boss_wy += charge_dir.y * step
			charge_travelled += step
			boss_wx = clampf(boss_wx, GameConstants.MAP_LEFT + 30.0, GameConstants.MAP_RIGHT - 30.0)
			face_angle = atan2(charge_dir.y, charge_dir.x)
			sprite_dir = _dir_from_angle(face_angle)
			telegraph = {"kind": "chase"}
			if charge_hit_player or state_timer <= 0.0 or charge_travelled >= charge_max_dist:
				_enter_recover(recover_time)

		State.ROCK_WINDUP:
			if not rock_target_rock.is_empty():
				var rcx := float(rock_target_rock["wx"]) + float(rock_target_rock["w"]) * 0.5
				var rcy := float(rock_target_rock["wy"]) + float(rock_target_rock["h"]) * 0.5
				var rtx := rcx - boss_wx
				var rty := rcy - boss_wy
				var rtl := maxf(GameConstants.hypot(rtx, rty), 0.001)
				if rtl > 50.0:
					boss_wx += (rtx / rtl) * chase_speed * 0.85 * dt
					boss_wy += (rty / rtl) * chase_speed * 0.85 * dt
				face_angle = atan2(rty, rtx)
				sprite_dir = _dir_from_angle(face_angle)
			telegraph = {
				"kind": "rock",
				"wx": boss_wx,
				"wy": boss_wy,
				"alpha": 1.0 - state_timer / GameConstants.BOSS_ROCK_WINDUP,
			}
			if state_timer <= 0.0:
				state = State.ROCK_THROW
				state_timer = 0.15
				pending_rock_throw = true

		State.ROCK_THROW:
			telegraph = {"kind": "rock_throw", "wx": boss_wx, "wy": boss_wy}
			if pending_rock_throw:
				var predict := GameConstants.MONSTER_PREDICT_SEC * 1.2
				boss_fight.spawn_rock_projectile(
					boss_wx,
					boss_wy,
					player_wx + player_vx * predict,
					player_wy + player_vy * predict
				)
				pending_rock_throw = false
			if state_timer <= 0.0:
				_enter_recover(recover_time)

		State.LINE_ROCK_WINDUP:
			_aim_line_rock_at_player(boss_wx, boss_wy, player_wx, player_wy)
			face_angle = atan2(line_rock_dir.y, line_rock_dir.x)
			sprite_dir = _dir_from_angle(face_angle)
			telegraph = {
				"kind": "line_rock",
				"wx": boss_wx,
				"wy": boss_wy,
				"dir_x": line_rock_dir.x,
				"dir_y": line_rock_dir.y,
				"aim_wx": player_wx,
				"aim_wy": player_wy - GameConstants.BOSS_LINE_ROCK_OFFSET,
				"alpha": 1.0 - state_timer / GameConstants.BOSS_LINE_ROCK_WINDUP,
			}
			if state_timer <= 0.0:
				state = State.LINE_ROCK_THROW
				state_timer = 0.18
				pending_line_rock_throw = true

		State.LINE_ROCK_THROW:
			telegraph = {
				"kind": "line_rock_active",
				"wx": boss_wx,
				"wy": boss_wy,
				"dir_x": line_rock_dir.x,
				"dir_y": line_rock_dir.y,
				"aim_wx": player_wx,
				"aim_wy": player_wy - GameConstants.BOSS_LINE_ROCK_OFFSET,
			}
			if pending_line_rock_throw:
				boss_fight.spawn_line_rock_volley(boss_wx, boss_wy, player_wx, player_wy)
				pending_line_rock_throw = false
			if state_timer <= 0.0:
				_enter_recover(recover_time)

		State.METEOR_JUMP, State.METEOR_ANCHOR:
			pass

		State.RECOVER:
			telegraph = {"kind": "recover"}
			if state_timer <= 0.0:
				state = State.CHASE
				pattern_index = (pattern_index + 1) % _pattern_size(phase)

		State.PHASE_TRANSITION, State.DYING:
			pass

	boss_wy = boss_fight.clamp_player_wy(boss_wy)
	return {"wx": boss_wx, "wy": boss_wy, "sprite_dir": sprite_dir, "state": state}


func on_phase_transition_end() -> void:
	state = State.CHASE
	state_timer = 0.0
	pattern_index = 0
	swipe_hit_player = false
	charge_hit_player = false
	pending_rock_throw = false
	pending_line_rock_throw = false
	rock_target_rock = {}
	telegraph = {"kind": "chase"}


func begin_meteor_assault() -> void:
	state = State.METEOR_JUMP
	state_timer = 0.0
	pending_rock_throw = false
	pending_line_rock_throw = false
	telegraph = {"kind": "meteor_jump"}


func _update_meteor_mode(
	dt: float,
	boss_wx: float,
	boss_wy: float,
	player_wx: float,
	player_wy: float,
	boss_fight: BossFight
) -> Dictionary:
	var center := boss_fight.arena_center_pos()
	match state:
		State.METEOR_JUMP:
			var dx := center.x - boss_wx
			var dy := center.y - boss_wy
			var dist := maxf(GameConstants.hypot(dx, dy), 0.001)
			var step := GameConstants.BOSS_METEOR_JUMP_SPEED * dt
			if dist <= step + 6.0:
				boss_wx = center.x
				boss_wy = center.y
				state = State.METEOR_ANCHOR
				boss_fight.meteor_anchored = true
				boss_fight.meteor_cooldown = 0.0
				face_angle = atan2(player_wy - boss_wy, player_wx - boss_wx)
				sprite_dir = _dir_from_angle(face_angle)
				telegraph = {"kind": "meteor_anchor", "wx": boss_wx, "wy": boss_wy}
			else:
				boss_wx += (dx / dist) * step
				boss_wy += (dy / dist) * step
				face_angle = atan2(dy, dx)
				sprite_dir = _dir_from_angle(face_angle)
				telegraph = {"kind": "meteor_jump", "wx": boss_wx, "wy": boss_wy, "tx": center.x, "ty": center.y}
		State.METEOR_ANCHOR:
			boss_wx = center.x
			boss_wy = center.y
			face_angle = atan2(player_wy - boss_wy, player_wx - boss_wx)
			sprite_dir = _dir_from_angle(face_angle)
			telegraph = {"kind": "meteor_rain", "wx": boss_wx, "wy": boss_wy}
		_:
			begin_meteor_assault()
	return {"wx": boss_wx, "wy": boss_wy, "sprite_dir": sprite_dir, "state": state}


func is_chasing() -> bool:
	return state == State.CHASE


func check_swipe_hit(boss_wx: float, boss_wy: float, player_wx: float, player_wy: float) -> bool:
	if state != State.SWIPE_ACTIVE or swipe_hit_player:
		return false
	var dx := player_wx - boss_wx
	var dy := player_wy - boss_wy
	var dist := GameConstants.hypot(dx, dy)
	if dist > GameConstants.BOSS_SWIPE_RANGE + GameConstants.PLAYER_R * 0.5:
		return false
	var fwd_x := cos(face_angle)
	var fwd_y := sin(face_angle)
	if dx * fwd_x + dy * fwd_y < 0.0:
		return false
	var ang := atan2(dy, dx)
	var diff := absf(wrapf(ang - face_angle, -PI, PI))
	if diff > GameConstants.BOSS_SWIPE_ARC * 0.42:
		return false
	swipe_hit_player = true
	return true


func check_charge_hit(boss_wx: float, boss_wy: float, player_wx: float, player_wy: float) -> bool:
	if state != State.CHARGE_ACTIVE or charge_hit_player:
		return false
	if charge_travelled < GameConstants.BOSS_CHARGE_MIN_TRAVEL:
		return false
	var rel_x := player_wx - boss_wx
	var rel_y := player_wy - boss_wy
	var dist := GameConstants.hypot(rel_x, rel_y)
	if dist > GameConstants.PLAYER_R + GameConstants.BOSS_CHARGE_HIT_RADIUS:
		return false
	var perp := absf(rel_x * charge_dir.y - rel_y * charge_dir.x)
	if perp > GameConstants.PLAYER_R + GameConstants.BOSS_CHARGE_HIT_WIDTH:
		return false
	charge_hit_player = true
	return true


func _pattern_size(phase: int) -> int:
	return 2 if phase == 1 else 3


func _peek_attack(phase: int) -> State:
	if phase == 1:
		return State.SWIPE_WINDUP if pattern_index % 2 == 0 else State.CHARGE_WINDUP
	var step := pattern_index % 3
	if step == 0:
		return State.SWIPE_WINDUP
	if step == 1:
		return State.CHARGE_WINDUP
	return State.LINE_ROCK_WINDUP


func _begin_attack(
	phase: int,
	boss_wx: float,
	boss_wy: float,
	player_wx: float,
	player_wy: float,
	player_vx: float,
	player_vy: float,
	boss_fight: BossFight
) -> void:
	var atk := _peek_attack(phase)
	match atk:
		State.SWIPE_WINDUP:
			state = State.SWIPE_WINDUP
			state_timer = GameConstants.BOSS_SWIPE_WINDUP
			face_angle = atan2(player_wy - boss_wy, player_wx - boss_wx)
		State.CHARGE_WINDUP:
			state = State.CHARGE_WINDUP
			state_timer = GameConstants.BOSS_CHARGE_WINDUP
			charge_hit_player = false
			charge_travelled = 0.0
			_aim_charge_at_player(boss_wx, boss_wy, player_wx, player_wy, player_vx, player_vy)
		State.LINE_ROCK_WINDUP:
			state = State.LINE_ROCK_WINDUP
			state_timer = GameConstants.BOSS_LINE_ROCK_WINDUP
			pending_line_rock_throw = false
			_aim_line_rock_at_player(boss_wx, boss_wy, player_wx, player_wy)
		State.ROCK_WINDUP:
			state = State.ROCK_WINDUP
			state_timer = GameConstants.BOSS_ROCK_WINDUP
			rock_target_rock = boss_fight.nearest_arena_rock(boss_wx, boss_wy)
			pending_rock_throw = false


func _aim_line_rock_at_player(
	boss_wx: float,
	boss_wy: float,
	player_wx: float,
	player_wy: float
) -> void:
	var aim_wx := player_wx
	var aim_wy := player_wy - GameConstants.BOSS_LINE_ROCK_OFFSET
	var dx := aim_wx - boss_wx
	var dy := aim_wy - boss_wy
	var dist := maxf(GameConstants.hypot(dx, dy), 0.001)
	line_rock_dir = Vector2(dx / dist, dy / dist)


func _aim_charge_at_player(
	boss_wx: float,
	boss_wy: float,
	player_wx: float,
	player_wy: float,
	player_vx: float,
	player_vy: float
) -> void:
	var predict := GameConstants.MONSTER_PREDICT_SEC
	var tx := player_wx + player_vx * predict - boss_wx
	var ty := player_wy + player_vy * predict - boss_wy
	var tl := maxf(GameConstants.hypot(tx, ty), 0.001)
	charge_dir = Vector2(tx / tl, ty / tl)
	charge_max_dist = tl + GameConstants.BOSS_CHARGE_OVERSHOOT


func _launch_charge_dash(
	boss_wx: float,
	boss_wy: float,
	player_wx: float,
	player_wy: float,
	player_vx: float,
	player_vy: float
) -> void:
	_aim_charge_at_player(boss_wx, boss_wy, player_wx, player_wy, player_vx, player_vy)
	state = State.CHARGE_ACTIVE
	charge_travelled = 0.0
	charge_hit_player = false
	var dash_time: float = charge_max_dist / GameConstants.BOSS_CHARGE_SPEED + GameConstants.BOSS_CHARGE_SLOW_EXTRA
	charge_dash_speed = charge_max_dist / maxf(dash_time, 0.001)
	state_timer = maxf(dash_time, GameConstants.BOSS_CHARGE_ACTIVE)


func _enter_recover(duration: float) -> void:
	state = State.RECOVER
	state_timer = duration


func _dir_from_angle(ang: float) -> int:
	var deg := rad_to_deg(ang)
	if deg >= -22.5 and deg < 22.5:
		return 2
	if deg >= 22.5 and deg < 67.5:
		return 6
	if deg >= 67.5 and deg < 112.5:
		return 0
	if deg >= 112.5 and deg < 157.5:
		return 4
	if deg >= 157.5 or deg < -157.5:
		return 3
	if deg >= -157.5 and deg < -112.5:
		return 5
	if deg >= -112.5 and deg < -67.5:
		return 1
	return 7
