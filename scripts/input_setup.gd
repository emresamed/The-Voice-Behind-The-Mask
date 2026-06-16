class_name InputSetup
extends RefCounted

const REBINDABLE := [
	{"action": "move_left", "label": "Sol"},
	{"action": "move_right", "label": "Sağ"},
	{"action": "move_up", "label": "Yukarı"},
	{"action": "move_down", "label": "Aşağı"},
	{"action": "sprint", "label": "Dash"},
	{"action": "echo", "label": "Echo"},
	{"action": "menu_key", "label": "Menü"},
	{"action": "ui_back", "label": "Geri"},
]

static func default_bindings() -> Dictionary:
	return {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"sprint": [KEY_SHIFT],
		"echo": [KEY_SPACE],
		"retry": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
		"menu_key": [KEY_M],
		"pause": [KEY_ESCAPE],
		"ui_back": [KEY_ESCAPE],
	}


static func apply() -> void:
	_apply_bindings(default_bindings())


static func apply_from_config(cfg: ConfigFile) -> void:
	var bindings := default_bindings().duplicate(true)
	for entry in REBINDABLE:
		var action: String = entry["action"]
		if cfg.has_section_key("keys", action):
			var saved = cfg.get_value("keys", action)
			if saved is Array and not saved.is_empty():
				bindings[action] = saved
	_apply_bindings(bindings)


static func save_to_config(cfg: ConfigFile) -> void:
	for entry in REBINDABLE:
		var action: String = entry["action"]
		cfg.set_value("keys", action, get_action_keys(action))


static func reset_keys_in_config(cfg: ConfigFile) -> void:
	if cfg.has_section("keys"):
		var keys: PackedStringArray = cfg.get_section_keys("keys")
		for key_name in keys:
			cfg.erase_section_key("keys", key_name)


static func get_action_keys(action: String) -> Array:
	var keys: Array = []
	if not InputMap.has_action(action):
		return keys
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			keys.append(ev.physical_keycode)
	return keys


static func get_primary_key_label(action: String) -> String:
	var keys := get_action_keys(action)
	if keys.is_empty():
		return "?"
	return key_label(int(keys[0]))


static func key_label(key: int) -> String:
	if key <= 0:
		return "?"
	var text := OS.get_keycode_string(key)
	if text.is_empty():
		return "Tuş %d" % key
	return text


static func bind_key(action: String, key: int) -> void:
	for entry in REBINDABLE:
		var other: String = entry["action"]
		if other == action:
			continue
		var keys: Array = get_action_keys(other)
		var filtered: Array = []
		for k in keys:
			if int(k) != key:
				filtered.append(k)
		_set_action_keys(other, filtered)
	_set_action_keys(action, [key])
	_sync_retry_keys()


static func _sync_retry_keys() -> void:
	var keys: Array = [KEY_ENTER, KEY_KP_ENTER]
	for echo_key in get_action_keys("echo"):
		if int(echo_key) not in keys:
			keys.insert(0, echo_key)
	_set_action_keys("retry", keys)


static func _set_action_keys(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action, 0.5)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		ev.keycode = key
		ev.location = KEY_LOCATION_UNSPECIFIED
		InputMap.action_add_event(action, ev)


static func _apply_bindings(bindings: Dictionary) -> void:
	for action: String in bindings:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, 0.5)
		for key in bindings[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			ev.keycode = key
			ev.location = KEY_LOCATION_UNSPECIFIED
			InputMap.action_add_event(action, ev)
