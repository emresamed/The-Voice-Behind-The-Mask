class_name ObstacleBehavior
extends RefCounted

const PROFILES: Dictionary = {
	"thorn": {
		"knockback": 12.0,
		"danger": 35.0,
		"slow_duration": 0.5,
		"slow_mult": 0.55,
		"flash_color": "#ff3030",
	},
	"rock": {
		"knockback": 28.0,
		"danger": 18.0,
		"slow_duration": 0.4,
		"slow_mult": 0.5,
		"flash_color": "#8888aa",
	},
	"bush": {
		"knockback": 10.0,
		"danger": 0.0,
		"slow_duration": 0.6,
		"slow_mult": 0.4,
		"flash_color": "#50a830",
	},
	"tree": {
		"knockback": 20.0,
		"danger": 25.0,
		"slow_duration": 0.0,
		"slow_mult": 1.0,
		"flash_color": "#35c44e",
	},
}


static func profile(kind: String) -> Dictionary:
	if PROFILES.has(kind):
		return PROFILES[kind] as Dictionary
	return PROFILES["tree"] as Dictionary
