class_name ChunkTemplates
extends RefCounted

const TEMPLATES: Array[Dictionary] = [
	{
		"id": "scatter",
		"weight": 22,
		"min_zone": 0,
		"obstacles": [
			{"x_frac": 0.14, "y_frac": 0.15, "kind": "zone", "jitter": 0.1},
			{"x_frac": 0.78, "y_frac": 0.22, "kind": "zone", "jitter": 0.1},
			{"x_frac": 0.62, "y_frac": 0.34, "kind": "thorn", "jitter": 0.06},
			{"x_frac": 0.86, "y_frac": 0.55, "kind": "zone", "jitter": 0.1},
			{"x_frac": 0.2, "y_frac": 0.68, "kind": "zone", "jitter": 0.1},
			{"x_frac": 0.72, "y_frac": 0.82, "kind": "zone", "jitter": 0.1},
		],
		"coins": [
			{"x_frac": 0.5, "y_frac": 0.3},
			{"x_frac": 0.35, "y_frac": 0.55},
			{"x_frac": 0.65, "y_frac": 0.75},
		],
	},
	{
		"id": "open_field",
		"weight": 12,
		"min_zone": 0,
		"obstacles": [
			{"x_frac": 0.08, "y_frac": 0.2, "kind": "zone"},
			{"x_frac": 0.84, "y_frac": 0.25, "kind": "zone"},
			{"x_frac": 0.12, "y_frac": 0.75, "kind": "zone"},
			{"x_frac": 0.8, "y_frac": 0.7, "kind": "zone"},
		],
		"coins": [
			{"x_frac": 0.42, "y_frac": 0.35},
			{"x_frac": 0.55, "y_frac": 0.5},
			{"x_frac": 0.48, "y_frac": 0.65},
			{"x_frac": 0.5, "y_frac": 0.8},
		],
	},
	{
		"id": "corridor",
		"weight": 14,
		"min_zone": 1,
		"obstacles": [
			{"x_frac": 0.04, "y_frac": 0.18, "kind": "zone"},
			{"x_frac": 0.04, "y_frac": 0.5, "kind": "zone"},
			{"x_frac": 0.04, "y_frac": 0.82, "kind": "zone"},
			{"x_frac": 0.78, "y_frac": 0.22, "kind": "zone"},
			{"x_frac": 0.78, "y_frac": 0.52, "kind": "zone"},
			{"x_frac": 0.78, "y_frac": 0.8, "kind": "zone"},
		],
		"coins": [
			{"x_frac": 0.48, "y_frac": 0.35},
			{"x_frac": 0.52, "y_frac": 0.6},
			{"x_frac": 0.5, "y_frac": 0.82},
		],
	},
	{
		"id": "s_curve",
		"weight": 18,
		"min_zone": 1,
		"obstacles": [
			{"x_frac": 0.12, "y_frac": 0.15, "kind": "thorn"},
			{"x_frac": 0.82, "y_frac": 0.28, "kind": "bush"},
			{"x_frac": 0.24, "y_frac": 0.44, "kind": "zone"},
			{"x_frac": 0.76, "y_frac": 0.58, "kind": "zone"},
			{"x_frac": 0.18, "y_frac": 0.72, "kind": "bush"},
			{"x_frac": 0.84, "y_frac": 0.85, "kind": "thorn"},
		],
		"coins": [
			{"x_frac": 0.42, "y_frac": 0.22},
			{"x_frac": 0.58, "y_frac": 0.4},
			{"x_frac": 0.44, "y_frac": 0.62},
			{"x_frac": 0.56, "y_frac": 0.78},
		],
	},
	{
		"id": "trap",
		"weight": 18,
		"min_zone": 2,
		"obstacles": [
			{"x_frac": 0.22, "y_frac": 0.32, "kind": "rock"},
			{"x_frac": 0.74, "y_frac": 0.32, "kind": "rock"},
			{"x_frac": 0.14, "y_frac": 0.55, "kind": "zone"},
			{"x_frac": 0.82, "y_frac": 0.55, "kind": "zone"},
			{"x_frac": 0.3, "y_frac": 0.75, "kind": "thorn"},
			{"x_frac": 0.68, "y_frac": 0.75, "kind": "thorn"},
		],
		"coins": [
			{"x_frac": 0.5, "y_frac": 0.48},
			{"x_frac": 0.44, "y_frac": 0.58},
			{"x_frac": 0.56, "y_frac": 0.58},
			{"x_frac": 0.5, "y_frac": 0.68},
		],
	},
	{
		"id": "gate",
		"weight": 14,
		"min_zone": 2,
		"obstacles": [
			{"x_frac": 0.05, "y_frac": 0.48, "kind": "rock"},
			{"x_frac": 0.26, "y_frac": 0.5, "kind": "tree"},
			{"x_frac": 0.74, "y_frac": 0.48, "kind": "rock"},
			{"x_frac": 0.9, "y_frac": 0.52, "kind": "tree"},
			{"x_frac": 0.88, "y_frac": 0.48, "kind": "rock"},
			{"x_frac": 0.16, "y_frac": 0.78, "kind": "zone"},
		],
		"coins": [
			{"x_frac": 0.4, "y_frac": 0.35},
			{"x_frac": 0.6, "y_frac": 0.35},
			{"x_frac": 0.5, "y_frac": 0.62},
			{"x_frac": 0.5, "y_frac": 0.82},
		],
	},
]


static func pick_template(zone_index: int) -> Dictionary:
	var pool: Array[Dictionary] = []
	var total_weight: int = 0
	for template in TEMPLATES:
		if zone_index >= int(template.get("min_zone", 0)):
			pool.append(template)
			total_weight += int(template["weight"])
	if pool.is_empty():
		return TEMPLATES[0]
	var roll: int = randi() % total_weight
	for template in pool:
		roll -= int(template["weight"])
		if roll < 0:
			return template
	return pool[0]


static func build_chunk_spawns(base_wy: float, zone: Dictionary, zone_index: int, coin_count: int) -> Dictionary:
	var template: Dictionary = pick_template(zone_index)
	return {
		"obstacles": _build_obstacle_spawns(base_wy, zone, template),
		"coins": _build_coin_spawns(base_wy, template, coin_count),
	}


static func _build_obstacle_spawns(base_wy: float, zone: Dictionary, template: Dictionary) -> Array:
	var result: Array = []
	for slot in template["obstacles"]:
		var obs := _spawn_obstacle_from_slot(base_wy, zone, slot as Dictionary)
		if not obs.is_empty():
			result.append(obs)

	if base_wy >= GameConstants.GRACE_ZONE_WY:
		var bonus_count := _bonus_obstacle_count(result.size())
		for _i in range(bonus_count):
			var bonus := _spawn_bonus_obstacle(base_wy, zone, result)
			if not bonus.is_empty():
				result.append(bonus)

	return result


static func _grace_kind(kind: String, wy: float) -> String:
	if wy < GameConstants.GRACE_ZONE_WY and kind == "thorn":
		return "bush"
	return kind


static func _spawn_obstacle_from_slot(base_wy: float, zone: Dictionary, slot_dict: Dictionary) -> Dictionary:
	var kind: String = _resolve_kind(slot_dict, zone)
	var sz: Dictionary = GameConstants.OBS_SIZES[kind]
	var x_frac: float = float(slot_dict["x_frac"])
	var y_frac: float = float(slot_dict["y_frac"])
	if slot_dict.has("jitter"):
		var jitter: float = float(slot_dict["jitter"])
		x_frac = clampf(x_frac + randf_range(-jitter, jitter), 0.0, 1.0)
		y_frac = clampf(y_frac + randf_range(-jitter, jitter), 0.0, 1.0)
	if _is_edge_wall_slot(x_frac):
		return _make_obstacle(base_wy, kind, x_frac, y_frac, float(sz["w"]), float(sz["h"]))
	return _make_obstacle_with_distribution(base_wy, zone, kind, x_frac, y_frac, float(sz["w"]), float(sz["h"]))


static func _spawn_bonus_obstacle(base_wy: float, zone: Dictionary, existing: Array) -> Dictionary:
	var kind := WorldZones.pick_obstacle_kind(zone)
	if base_wy < GameConstants.GRACE_ZONE_WY and kind == "thorn":
		kind = "bush"
	var sz: Dictionary = GameConstants.OBS_SIZES[kind]
	for _attempt in range(8):
		var x_frac: float
		var y_frac := randf_range(0.18, 0.84)
		if _roll_player_lane_trap():
			x_frac = _player_lane_x_frac()
		else:
			x_frac = _random_map_x_frac()
		var obs := _make_obstacle(base_wy, kind, x_frac, y_frac, float(sz["w"]), float(sz["h"]))
		if obs.is_empty():
			continue
		if _overlaps_existing(obs, existing):
			continue
		return obs
	return {}


static func _make_obstacle_with_distribution(
	base_wy: float,
	zone: Dictionary,
	kind: String,
	template_x: float,
	template_y: float,
	obs_w: float,
	obs_h: float
) -> Dictionary:
	var x_frac: float
	var y_frac: float = template_y
	if _roll_player_lane_trap():
		x_frac = _player_lane_x_frac()
	else:
		x_frac = _random_map_x_frac()
		y_frac = clampf(template_y + randf_range(-0.08, 0.08), 0.1, 0.9)
	return _make_obstacle(base_wy, kind, x_frac, y_frac, obs_w, obs_h)


static func _make_obstacle(
	base_wy: float,
	kind: String,
	x_frac: float,
	y_frac: float,
	obs_w: float,
	obs_h: float
) -> Dictionary:
	var wy := _obs_y(base_wy, y_frac)
	if wy < 300.0:
		return {}
	kind = _grace_kind(kind, wy)
	var sz: Dictionary = GameConstants.OBS_SIZES[kind]
	obs_w = float(sz["w"])
	obs_h = float(sz["h"])
	var wx := _obs_x(x_frac, obs_w)
	return {
		"kind": kind,
		"wx": wx,
		"wy": wy,
		"w": obs_w,
		"h": obs_h,
	}


static func _bonus_obstacle_count(current_count: int) -> int:
	if current_count <= 0:
		return 0
	return int(ceil(float(current_count) * (GameConstants.TRAP_DENSITY_MULT - 1.0)))


static func _roll_player_lane_trap() -> bool:
	return randf() < GameConstants.PLAYER_LANE_TRAP_FRAC


static func _is_edge_wall_slot(x_frac: float) -> bool:
	return x_frac <= 0.1 or x_frac >= 0.86


static func _random_map_x_frac() -> float:
	return randf_range(0.06, 0.92)


static func _player_lane_x_frac() -> float:
	var lane_half := GameConstants.PLAYER_LANE_HALF_WIDTH
	return clampf(
		GameConstants.PLAYER_LANE_CENTER + randf_range(-lane_half, lane_half),
		0.06,
		0.94
	)


static func _overlaps_existing(candidate: Dictionary, existing: Array) -> bool:
	var cx := float(candidate["wx"]) + float(candidate["w"]) * 0.5
	var cy := float(candidate["wy"]) + float(candidate["h"]) * 0.5
	for obs in existing:
		var ocx := float(obs["wx"]) + float(obs["w"]) * 0.5
		var ocy := float(obs["wy"]) + float(obs["h"]) * 0.5
		if GameConstants.hypot(cx - ocx, cy - ocy) < 72.0:
			return true
	return false


static func _build_coin_spawns(base_wy: float, template: Dictionary, coin_count: int) -> Array:
	var slots: Array = template["coins"]
	var result: Array = []
	var count: int = mini(coin_count, slots.size())
	for i in range(count):
		var slot: Dictionary = slots[i] as Dictionary
		var wx: float = _coin_x(float(slot["x_frac"]))
		var wy: float = _coin_y(base_wy, float(slot["y_frac"]))
		if wy < 200.0:
			continue
		result.append({"wx": wx, "wy": wy})
	var remaining: int = coin_count - result.size()
	for _j in range(remaining):
		result.append({
			"wx": GameConstants.MAP_LEFT + GameConstants.COIN_R + randf() * (GameConstants.MAP_W - GameConstants.COIN_R * 2.0),
			"wy": base_wy + 40.0 + randf() * (GameConstants.SPAWN_CHUNK - 50.0),
		})
	return result


static func _resolve_kind(slot: Dictionary, zone: Dictionary) -> String:
	var kind: String = str(slot.get("kind", "zone"))
	if kind == "zone":
		return WorldZones.pick_obstacle_kind(zone)
	return kind


static func _obs_x(x_frac: float, obs_w: float) -> float:
	return GameConstants.MAP_LEFT + x_frac * (GameConstants.MAP_W - obs_w)


static func _obs_y(base_wy: float, y_frac: float) -> float:
	return base_wy + 80.0 + y_frac * (GameConstants.SPAWN_CHUNK - 100.0)


static func _coin_x(x_frac: float) -> float:
	return GameConstants.MAP_LEFT + GameConstants.COIN_R + x_frac * (GameConstants.MAP_W - GameConstants.COIN_R * 2.0)


static func _coin_y(base_wy: float, y_frac: float) -> float:
	return base_wy + 40.0 + y_frac * (GameConstants.SPAWN_CHUNK - 50.0)
