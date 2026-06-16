extends Button

func _get_engine() -> Node:
	return get_parent().get_parent()


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_on_pressed)
	var engine := _get_engine()
	if engine and engine.has_signal("music_changed"):
		engine.music_changed.connect(_on_music_changed)
		if "music_enabled" in engine:
			_on_music_changed(engine.music_enabled)


func _on_pressed() -> void:
	var engine := _get_engine()
	if engine and engine.has_method("toggle_music"):
		engine.toggle_music()


func _on_music_changed(enabled: bool) -> void:
	text = "🔊" if enabled else "🔇"
	add_theme_color_override("font_color", Color("#00f5ff") if enabled else Color(1, 1, 1, 0.4))
	add_theme_color_override("font_hover_color", Color("#00f5ff") if enabled else Color(1, 1, 1, 0.4))
