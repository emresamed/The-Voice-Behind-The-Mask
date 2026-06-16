class_name MarketUpgrades
extends RefCounted

const COIN_CATALOG: Array[Dictionary] = [
	{
		"id": "echo_range",
		"label": "Echo Menzili",
		"desc": "Max menzil +%10",
		"max_level": 5,
		"base_cost": 40,
		"currency": "coin",
	},
	{
		"id": "stamina",
		"label": "Çeviklik",
		"desc": "Dash bekleme -%10",
		"max_level": 5,
		"base_cost": 35,
		"currency": "coin",
	},
	{
		"id": "calm_mind",
		"label": "Sakin Zihin",
		"desc": "Tehlike azalması +%15",
		"max_level": 5,
		"base_cost": 35,
		"currency": "coin",
	},
	{
		"id": "echo_flow",
		"label": "Echo Akışı",
		"desc": "Echo bekleme -%12",
		"max_level": 4,
		"base_cost": 50,
		"currency": "coin",
	},
	{
		"id": "shadow_step",
		"label": "Gölge Adım",
		"desc": "Canavar hızı -%5",
		"max_level": 4,
		"base_cost": 60,
		"currency": "coin",
	},
	{
		"id": "clear_sight",
		"label": "Net Görüş",
		"desc": "Echo görüş +%15 süre",
		"max_level": 3,
		"base_cost": 45,
		"currency": "coin",
	},
]


static func default_levels() -> Dictionary:
	return {
		"echo_range": 0,
		"stamina": 0,
		"calm_mind": 0,
		"echo_flow": 0,
		"shadow_step": 0,
		"clear_sight": 0,
	}


static func get_entry(upgrade_id: String) -> Dictionary:
	for entry in COIN_CATALOG:
		if entry["id"] == upgrade_id:
			return entry
	return {}


static func cost_for(upgrade_id: String, current_level: int) -> int:
	var entry: Dictionary = get_entry(upgrade_id)
	if entry.is_empty():
		return 0
	return int(entry["base_cost"]) * (current_level + 1)


static func currency_for(upgrade_id: String) -> String:
	var entry: Dictionary = get_entry(upgrade_id)
	if entry.is_empty():
		return "coin"
	return str(entry.get("currency", "coin"))


static func load_levels_from_config(cfg: ConfigFile) -> Dictionary:
	var levels: Dictionary = default_levels()
	for entry in COIN_CATALOG:
		var id: String = entry["id"]
		levels[id] = int(cfg.get_value("upgrades", id, 0))
	return levels


static func save_levels_to_config(cfg: ConfigFile, levels: Dictionary) -> void:
	for entry in COIN_CATALOG:
		var id: String = entry["id"]
		cfg.set_value("upgrades", id, int(levels.get(id, 0)))


static func echo_max_range(level: int) -> float:
	return GameConstants.ECHO_MAX_RANGE * (1.0 + 0.1 * float(level))


static func dash_cooldown(level: int) -> float:
	return maxf(1.8, GameConstants.DASH_COOLDOWN * (1.0 - 0.1 * float(level)))


static func danger_decay_rate(level: int) -> float:
	return GameConstants.DANGER_DECAY * (1.0 + 0.15 * float(level))


static func echo_cooldown_ms(level: int) -> float:
	return GameConstants.ECHO_COOLDOWN_MS * maxf(0.4, 1.0 - 0.12 * float(level))


static func monster_slow_mult(level: int) -> float:
	return maxf(0.75, 1.0 - 0.05 * float(level))


static func reveal_duration_ms(level: int) -> float:
	return GameConstants.REVEAL_DURATION * (1.0 + 0.15 * float(level))


static func effect_summary(upgrade_id: String, level: int) -> String:
	match upgrade_id:
		"echo_range":
			return "%dm" % int(echo_max_range(level))
		"stamina":
			return "%.1fs" % dash_cooldown(level)
		"calm_mind":
			return "%.1f/s" % danger_decay_rate(level)
		"echo_flow":
			return "%.0fms" % echo_cooldown_ms(level)
		"shadow_step":
			return "-%d%%" % int((1.0 - monster_slow_mult(level)) * 100.0)
		"clear_sight":
			return "%.0fms" % reveal_duration_ms(level)
	return ""
