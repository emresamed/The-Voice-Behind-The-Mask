class_name CheckpointLandmarks
extends RefCounted

const ROTATION: Array[String] = ["echo_well", "reveal_shrine"]

# Checkpoint'ler arasına yerleştirilir (her 500m değil).
const LANDMARK_FIRST_WY := 7500.0
const LANDMARK_INTERVAL_WY := 10000.0
const LANDMARK_COUNT := 12

const DEFS: Dictionary = {
	"echo_well": {
		"label": "ECHO KUYUSU",
		"line_color": "#00f5ff",
		"glow_color": "#00f5ff",
		"icon": "◎",
	},
	"reveal_shrine": {
		"label": "KIRIK TAPINAK",
		"line_color": "#aaaaff",
		"glow_color": "#8888ff",
		"icon": "⛩",
	},
	"boss_gate": {
		"label": "SON KAPI",
		"line_color": "#ff3030",
		"glow_color": "#ff5050",
		"icon": "☠",
	},
}


static func landmark_for_index(index: int) -> String:
	return ROTATION[index % ROTATION.size()]


static func build_landmark_list() -> Array:
	var result: Array = []
	var wy: float = LANDMARK_FIRST_WY
	for idx in range(LANDMARK_COUNT):
		result.append({
			"wy": wy,
			"landmark": landmark_for_index(idx),
			"label": "%dm" % int(wy / 10.0),
			"triggered": false,
		})
		wy += LANDMARK_INTERVAL_WY
	result.append({
		"wy": GameConstants.STORY_GATE_WY,
		"landmark": "boss_gate",
		"label": "%dm" % GameConstants.STORY_GATE_METERS,
		"triggered": false,
	})
	return result


static func get_def(landmark_id: String) -> Dictionary:
	if DEFS.has(landmark_id):
		return DEFS[landmark_id] as Dictionary
	return DEFS["echo_well"] as Dictionary
