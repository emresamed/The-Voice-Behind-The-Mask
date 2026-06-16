class_name GameConstants
extends RefCounted

const CANVAS_W := 960
const CANVAS_H := 540

const MAP_LEFT := 60
const MAP_RIGHT := CANVAS_W - 60
const MAP_W := MAP_RIGHT - MAP_LEFT

const WALK_SPEED := 180.0
const PLAYER_R := 14.0

const DASH_DISTANCE := 138.0
const DASH_DURATION := 0.11
const DASH_COOLDOWN := 3.0
const DASH_TRAIL_LIFE := 0.62
const DASH_TRAIL_SIZE := 15.0

const ECHO_BASE_RANGE := 200.0
const ECHO_RANGE_STEP := 90.0
const ECHO_MAX_RANGE := 750.0
const ECHO_WAVE_SPEED := 420.0
const REVEAL_DURATION := 800.0
const ECHO_HOLD_MAX := 1.0
const ECHO_CHARGE_MIN := 0.12
const ECHO_RADIUS_MIN_FRAC := 0.32
const ECHO_RADIUS_SCALE := 1.15
const ECHO_DANGER := 22.0
const ECHO_COOLDOWN_MS := 700.0

const DANGER_DECAY := 7.0
const DANGER_OBS_HIT := 28.0
const DANGER_MAX := 100.0

const MONSTER_BASE_SPD := 62.0
const MONSTER_DANGER_BOOST := 1.5
const MONSTER_START_DIST := 700.0
const DANGER_MONSTER_WAKE_T := 0.6
const ECHO_SHOUT_MONSTER_WAKE_T := 0.6
const GRACE_ZONE_METERS := 150.0
const GRACE_ZONE_WY := GRACE_ZONE_METERS * 10.0
const MONSTER_WAKE_SPAWN_DIST := 400.0
const MONSTER_WARN_DIST := 500.0
const MONSTER_CHASE_MIN_SPD := 95.0
const MONSTER_CHASE_MAX_SPD := 235.0
const MONSTER_CHASE_PRESSURE_PER_CP := 0.05
const MONSTER_DISTANCE_SPEED_STEP := 0.055
const MONSTER_DISTANCE_SPEED_CAP := 1.25
## Hatasız oyun (sürekli hareket + dash ritmi) hızının altında kalır; canavar asla yetişemez.
const MONSTER_FLAWLESS_ESCAPE_RATIO := 0.84
const MONSTER_FOLLOW_SPD := 165.0
const MONSTER_PREDICT_SEC := 0.4
const MONSTER_ESCAPE_DIST := 380.0
const MONSTER_SPRITE_SIZE := 96.0

const MONSTER_TRAP_COOLDOWN := 4.0
const MONSTER_TRAP_COOLDOWN_MIN := 1.45
const MONSTER_TRAP_COOLDOWN_ZONE_STEP := 0.72
const MONSTER_TRAP_TELEGRAPH_MS := 980.0
const MONSTER_TRAP_TELEGRAPH_MIN_MS := 620.0
const MONSTER_TRAP_MOVE_MS := 340.0
const MONSTER_TRAP_MAX_SHIFT_X := 165.0
const MONSTER_TRAP_MAX_SHIFT_Y := 200.0
const MONSTER_TRAP_RANGE_AHEAD := 480.0
const MONSTER_TRAP_RANGE_BEHIND := 90.0
const MONSTER_TRAP_MIN_DIST := 170.0
const MONSTER_TRAP_MAX_DIST := 520.0

const COINS_PER_CHUNK := 4
const COIN_R := 9.0
const CHECKPOINT_INTERVAL := 5000.0
const CHECKPOINT_DANGER_RESET := 0.5

const STORY_GATE_WY := 5000.0
const STORY_GATE_METERS := 500
const STORY_SLIDE_DEFAULT_DURATION := 4.0
const STORY_TO_BOSS_FADE_SEC := 0.5
const BOSS_INTRO_DURATION := 2.0
const BOSS_ARENA_HALF_HEIGHT := 900.0

const BOSS_NAME := "YANKI CANAVARI"
const BOSS_MAX_HP := 900.0
const BOSS_HIT_RADIUS := 40.0
const BOSS_PLAYER_MAX_HP := 100.0
const BOSS_PLAYER_INVULN_SEC := 0.9
const BOSS_START_INVULN_SEC := 3.0
const BOSS_PHASE2_HP_FRAC := 0.5
const BOSS_PHASE3_HP_FRAC := 0.25
const BOSS_PHASE_TRANSITION_SEC := 1.5

const BOSS_CHASE_SPEED_P1 := 220.0
const BOSS_CHASE_SPEED_P2 := 285.0
const BOSS_SWIPE_DAMAGE := 28.0
const BOSS_SWIPE_WINDUP := 0.55
const BOSS_SWIPE_ACTIVE := 0.18
const BOSS_SWIPE_RANGE := 120.0
const BOSS_SWIPE_ARC := deg_to_rad(90.0)
const BOSS_CHARGE_DAMAGE := 38.0
const BOSS_CHARGE_WINDUP := 1.5
const BOSS_CHARGE_ACTIVE := 0.55
const BOSS_CHARGE_SPEED := 1225.0
const BOSS_CHARGE_MIN_TRAVEL := 30.0
const BOSS_CHARGE_HIT_WIDTH := 26.0
const BOSS_CHARGE_HIT_RADIUS := 38.0
const BOSS_CHARGE_OVERSHOOT := 90.0
const BOSS_CHARGE_SLOW_EXTRA := 1.0
const BOSS_ROCK_DAMAGE := 32.0
const BOSS_ROCK_WINDUP := 0.8
const BOSS_ROCK_THROW_SPEED := 680.0
const BOSS_ROCK_SCALE := 1.8
const BOSS_ROCK_HIT_RADIUS := 22.0
const BOSS_RECOVER_P1 := 0.62
const BOSS_RECOVER_P2 := 0.4
const BOSS_LINE_ROCK_WINDUP := 0.65
const BOSS_LINE_ROCK_COUNT := 5
const BOSS_LINE_ROCK_OFFSET := 150.0
const BOSS_LINE_ROCK_SPEED := 760.0
const BOSS_LINE_ROCK_DAMAGE := 30.0
const BOSS_METEOR_JUMP_SPEED := 640.0
const BOSS_METEOR_COOLDOWN := 0.1
const BOSS_METEOR_SPAWN_HEIGHT := 540.0
const BOSS_METEOR_FALL_SPEED := 1180.0
const BOSS_METEOR_DAMAGE := 26.0
const BOSS_METEOR_RADIUS := 28.0
const BOSS_METEOR_ROCK_SHELTER := 16.0
const BOSS_MELEE_RANGE := 130.0
const BOSS_CHARGE_MIN_RANGE := 115.0

const BOSS_ECHO_DAMAGE_BASE := 4.0
const BOSS_ECHO_DAMAGE_CHARGE := 6.0
const BOSS_ECHO_CHARGE_TIER_MULT := 1.3
const BOSS_ECHO_CHARGE_TIER_STEP := 0.25
const BOSS_DASH_ECHO_DURATION := 10.0
const BOSS_DASH_ECHO_COOLDOWN := 20.0
const BOSS_DASH_ECHO_DAMAGE_MULT := 2.5
const BOSS_DASH_ECHO_CHARGE_MIN := 0.98
const BOSS_DASH_ECHO_BURST_RADIUS := 920.0
const BOSS_DASH_ECHO_WAVE_SPEED := 720.0
const BOSS_DASH_ECHO_NAME := "ŞAFAK GETİREN"

const BOSS_VICTORY_CINEMATIC_SEC := 4.0
const BOSS_ARENA_ROCK_W := 134.0
const BOSS_ARENA_ROCK_H := 96.0

const SPAWN_AHEAD := 2000.0
const SPAWN_CHUNK := 380.0
const OBS_PER_CHUNK := 6
const TRAP_DENSITY_MULT := 1.25
const PLAYER_LANE_TRAP_FRAC := 0.1
const PLAYER_LANE_CENTER := 0.5
const PLAYER_LANE_HALF_WIDTH := 0.14

const OBS_COLORS := {
	"tree": {"fill": "#1a5c28", "glow": "#35c44e", "hit": "#80ff80"},
	"rock": {"fill": "#4a4a4a", "glow": "#8888aa", "hit": "#d0d0ff"},
	"thorn": {"fill": "#7a1010", "glow": "#ff3030", "hit": "#ff8080"},
	"bush": {"fill": "#2d5c1a", "glow": "#50a830", "hit": "#a0ff70"},
}

const OBS_SIZES := {
	"tree": {"w": 94.0, "h": 96.0},
	"rock": {"w": 84.0, "h": 60.0},
	"thorn": {"w": 66.0, "h": 66.0},
	"bush": {"w": 93.0, "h": 57.0},
}

static func boss_echo_damage(charge_t: float) -> float:
	var t := clampf(charge_t, 0.0, 1.0)
	var base := BOSS_ECHO_DAMAGE_BASE + t * BOSS_ECHO_DAMAGE_CHARGE
	var tier := mini(int(t / BOSS_ECHO_CHARGE_TIER_STEP), 3)
	return base * pow(BOSS_ECHO_CHARGE_TIER_MULT, float(tier))


static func boss_dash_echo_damage() -> float:
	return boss_echo_damage(1.0) * BOSS_DASH_ECHO_DAMAGE_MULT


static func now_ms() -> float:
	return float(Time.get_ticks_msec())


static func hypot(dx: float, dy: float) -> float:
	return Vector2(dx, dy).length()

static func color_from_hex(hex: String) -> Color:
	return Color(hex)
