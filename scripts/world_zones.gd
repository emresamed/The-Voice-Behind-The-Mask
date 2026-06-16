class_name WorldZones
extends RefCounted

const ZONES := [
	{
		"id": "dead_dirt",
		"name": "Ölü Toprak",
		"start_wy": 0.0,
		"tint": Color("#e8ddd0"),
		"msg_color": "#c8b8a0",
		"obs_weights": {"tree": 25, "rock": 25, "thorn": 20, "bush": 30},
		"coins_per_chunk": 3,
		"monster_speed_mult": 1.0,
	},
	{
		"id": "scrubland",
		"name": "Çalılık",
		"start_wy": 5000.0,
		"tint": Color("#c8ddb0"),
		"msg_color": "#90c860",
		"obs_weights": {"tree": 10, "rock": 15, "thorn": 35, "bush": 40},
		"coins_per_chunk": 4,
		"monster_speed_mult": 1.14,
	},
	{
		"id": "rocky",
		"name": "Taşlık",
		"start_wy": 15000.0,
		"tint": Color("#b8b8c8"),
		"msg_color": "#9090b8",
		"obs_weights": {"tree": 10, "rock": 50, "thorn": 25, "bush": 15},
		"coins_per_chunk": 5,
		"monster_speed_mult": 1.32,
	},
	{
		"id": "dark_forest",
		"name": "Karanlık Orman",
		"start_wy": 30000.0,
		"tint": Color("#88a878"),
		"msg_color": "#50a848",
		"obs_weights": {"tree": 50, "rock": 10, "thorn": 15, "bush": 25},
		"coins_per_chunk": 6,
		"monster_speed_mult": 1.52,
	},
]


static func zone_index_for_wy(wy: float) -> int:
	var idx: int = 0
	for i in range(ZONES.size()):
		if wy >= float(ZONES[i]["start_wy"]):
			idx = i
	return idx


static func zone_for_wy(wy: float) -> Dictionary:
	return ZONES[zone_index_for_wy(wy)] as Dictionary


static func pick_obstacle_kind(zone: Dictionary) -> String:
	var weights: Dictionary = zone["obs_weights"]
	var total: int = 0
	for kind in weights:
		total += int(weights[kind])
	if total <= 0:
		return "tree"
	var roll: int = randi() % total
	for kind in weights:
		roll -= int(weights[kind])
		if roll < 0:
			return str(kind)
	return "tree"


static func coins_per_chunk(zone: Dictionary) -> int:
	return int(zone["coins_per_chunk"])


static func monster_speed_mult(zone: Dictionary) -> float:
	return float(zone["monster_speed_mult"])


static func zone_tint(zone: Dictionary) -> Color:
	return zone["tint"] as Color


static func zone_msg_color(zone: Dictionary) -> Color:
	return GameConstants.color_from_hex(str(zone["msg_color"]))
