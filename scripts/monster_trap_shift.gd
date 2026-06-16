class_name MonsterTrapShift
extends RefCounted

const DIRS: Array[String] = ["left", "right", "forward", "back"]


static func cooldown_sec(zone_index: int) -> float:
	return maxf(
		GameConstants.MONSTER_TRAP_COOLDOWN_MIN,
		GameConstants.MONSTER_TRAP_COOLDOWN - float(zone_index) * GameConstants.MONSTER_TRAP_COOLDOWN_ZONE_STEP
	)


static func shift_count_for_zone(zone_index: int, urgency: float) -> int:
	var base := 1 + zone_index
	if urgency > 0.55:
		base += 1
	if urgency > 0.82 and zone_index >= 2:
		base += 1
	return clampi(base, 1, 4)


static func pick_candidates(obstacles: Array, player_wx: float, player_wy: float, count: int) -> Array:
	var scored: Array = []
	for obs in obstacles:
		if _is_shifting(obs):
			continue
		var w := float(obs["w"])
		var h := float(obs["h"])
		var ocx := float(obs["wx"]) + w * 0.5
		var ocy := float(obs["wy"]) + h * 0.5
		var ahead := ocy - player_wy
		var lateral := absf(ocx - player_wx)
		if ahead < -GameConstants.MONSTER_TRAP_RANGE_BEHIND:
			continue
		if ahead > GameConstants.MONSTER_TRAP_RANGE_AHEAD:
			continue
		if lateral > GameConstants.MAP_W * 0.46:
			continue
		var score := 220.0 - absf(ahead - 130.0) * 0.9 - lateral * 0.28
		if ahead > 40.0:
			score += 35.0
		scored.append({"obs": obs, "score": score})
	scored.sort_custom(func(a, b): return a["score"] > b["score"])

	var result: Array = []
	for entry in scored:
		if result.size() >= count:
			break
		var obs: Dictionary = entry["obs"]
		if _overlaps_shift_targets(obs, result):
			continue
		result.append(obs)
	return result


static func plan_shift(
	obs: Dictionary,
	player_wx: float,
	player_wy: float,
	player_vx: float,
	player_vy: float,
	zone_index: int = 0,
	urgency: float = 0.5
) -> Dictionary:
	var w := float(obs["w"])
	var h := float(obs["h"])
	var from_wx := float(obs["wx"])
	var from_wy := float(obs["wy"])
	var ocx := from_wx + w * 0.5
	var ocy := from_wy + h * 0.5

	var zone_boost := float(zone_index) * 0.08 + urgency * 0.12
	var lead_x := player_wx + clampf(player_vx * 0.45, -95.0, 95.0)
	var lead_y := player_wy + maxf(player_vy * 0.42, 0.0) + 95.0 + zone_index * 12.0

	var forward_chance := clampf(0.58 + float(zone_index) * 0.1 + urgency * 0.15, 0.58, 0.92)
	var dir: String
	if randf() < forward_chance:
		dir = "forward"
	elif randf() < 0.5:
		dir = "left" if ocx > lead_x else "right"
	else:
		dir = "right" if ocx <= lead_x else "left"

	var to_wx := from_wx
	var to_wy := from_wy
	var max_x := GameConstants.MONSTER_TRAP_MAX_SHIFT_X * (1.0 + zone_boost)
	var max_y := GameConstants.MONSTER_TRAP_MAX_SHIFT_Y * (1.0 + zone_boost)
	var lane_pull := clampf(0.78 + zone_boost, 0.78, 0.96)

	match dir:
		"left":
			to_wx = from_wx - randf_range(max_x * 0.45, max_x)
			if ocx > lead_x:
				to_wx = lerpf(from_wx, lead_x - w * 0.5, lane_pull)
		"right":
			to_wx = from_wx + randf_range(max_x * 0.45, max_x)
			if ocx < lead_x:
				to_wx = lerpf(from_wx, lead_x - w * 0.5, lane_pull)
		"forward":
			to_wy = from_wy + randf_range(max_y * 0.62, max_y * 1.08)
			to_wx = lerpf(from_wx, lead_x - w * 0.5, lane_pull + 0.06)
			if ocy < lead_y - 20.0:
				to_wy = maxf(to_wy, lerpf(from_wy, lead_y - h * 0.5, 0.9))
		"back":
			to_wy = from_wy - randf_range(max_y * 0.22, max_y * 0.45)
			to_wx = lerpf(from_wx, lead_x - w * 0.5, lane_pull * 0.55)

	to_wx = clampf(to_wx, GameConstants.MAP_LEFT, GameConstants.MAP_RIGHT - w)
	to_wy = clampf(to_wy, player_wy - GameConstants.MONSTER_TRAP_RANGE_BEHIND, player_wy + GameConstants.MONSTER_TRAP_RANGE_AHEAD)

	if GameConstants.hypot(to_wx - from_wx, to_wy - from_wy) < 42.0:
		return {}

	return {
		"to_wx": to_wx,
		"to_wy": to_wy,
		"dir": dir,
	}


static func telegraph_ms(urgency: float, zone_index: int = 0) -> float:
	var base := lerpf(
		GameConstants.MONSTER_TRAP_TELEGRAPH_MS,
		GameConstants.MONSTER_TRAP_TELEGRAPH_MIN_MS,
		clampf(urgency, 0.0, 1.0)
	)
	return maxf(520.0, base - float(zone_index) * 55.0)


static func start_shift(obs: Dictionary, plan: Dictionary, telegraph_duration: float) -> void:
	var now := GameConstants.now_ms()
	obs["trap_shift"] = {
		"phase": "telegraph",
		"from_wx": float(obs["wx"]),
		"from_wy": float(obs["wy"]),
		"to_wx": float(plan["to_wx"]),
		"to_wy": float(plan["to_wy"]),
		"dir": str(plan.get("dir", "")),
		"start_ms": now,
		"telegraph_ms": telegraph_duration,
		"move_ms": GameConstants.MONSTER_TRAP_MOVE_MS,
	}


static func update_shift(obs: Dictionary, now: float) -> bool:
	if not obs.has("trap_shift"):
		return false
	var shift: Dictionary = obs["trap_shift"]
	var phase: String = str(shift.get("phase", ""))
	if phase.is_empty():
		return false

	var elapsed := now - float(shift["start_ms"])
	if phase == "telegraph":
		if elapsed >= float(shift["telegraph_ms"]):
			shift["phase"] = "move"
			shift["start_ms"] = now
		return true

	if phase == "move":
		var move_ms := maxf(float(shift["move_ms"]), 1.0)
		var t := clampf(elapsed / move_ms, 0.0, 1.0)
		var ease := t * t * (3.0 - 2.0 * t)
		obs["wx"] = lerpf(float(shift["from_wx"]), float(shift["to_wx"]), ease)
		obs["wy"] = lerpf(float(shift["from_wy"]), float(shift["to_wy"]), ease)
		if t >= 1.0:
			obs.erase("trap_shift")
			return false
	return true


static func is_shifting(obs: Dictionary) -> bool:
	return _is_shifting(obs)


static func count_active(obstacles: Array) -> int:
	var n := 0
	for obs in obstacles:
		if _is_shifting(obs):
			n += 1
	return n


static func any_active(obstacles: Array) -> bool:
	return count_active(obstacles) > 0


static func _is_shifting(obs: Dictionary) -> bool:
	if not obs.has("trap_shift"):
		return false
	return not str(obs["trap_shift"].get("phase", "")).is_empty()


static func _overlaps_shift_targets(candidate: Dictionary, picked: Array) -> bool:
	var cx := float(candidate["wx"]) + float(candidate["w"]) * 0.5
	var cy := float(candidate["wy"]) + float(candidate["h"]) * 0.5
	for obs in picked:
		var ocx := float(obs["wx"]) + float(obs["w"]) * 0.5
		var ocy := float(obs["wy"]) + float(obs["h"]) * 0.5
		if GameConstants.hypot(cx - ocx, cy - ocy) < 88.0:
			return true
	return false
