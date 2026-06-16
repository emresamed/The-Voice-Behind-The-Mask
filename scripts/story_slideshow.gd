class_name StorySlideshow
extends RefCounted

const SCENE_PATHS: Array[String] = [
	"res://assets/story/sahne1.png",
	"res://assets/story/sahne2.png",
	"res://assets/story/sahne3.png",
	"res://assets/story/sahne4.png",
	"res://assets/story/sahne5.png",
	"res://assets/story/sahne6.png",
	"res://assets/story/sahne7.png",
	"res://assets/story/sahne8.png",
	"res://assets/story/sahne9.png",
]

const SCENE_COUNT := 9
const THROW_DURATION := 0.46
const CARD_W := 400.0
const CARD_H := 214.0

const _STACK_POSES: Array[Vector3] = [
	Vector3(0.0, 0.0, -4.0),
	Vector3(12.0, 8.0, 5.5),
	Vector3(-10.0, 15.0, -6.0),
	Vector3(15.0, 22.0, 4.0),
	Vector3(-14.0, 28.0, 7.0),
	Vector3(18.0, 34.0, -5.5),
	Vector3(-8.0, 40.0, 3.5),
	Vector3(13.0, 46.0, -7.5),
	Vector3(6.0, 52.0, 6.0),
]

var _placed: Array[Dictionary] = []
var _throwing: Dictionary = {}
var _finished: bool = false
var _running: bool = false
var _textures: Dictionary = {}


func start() -> void:
	_placed.clear()
	_throwing = {}
	_finished = false
	_running = true


func reset() -> void:
	_placed.clear()
	_throwing = {}
	_finished = false
	_running = false


func update(dt: float) -> void:
	if not _running or _finished or _throwing.is_empty():
		return
	_throwing["timer"] = float(_throwing.get("timer", 0.0)) + dt
	if float(_throwing["timer"]) >= THROW_DURATION:
		_land_throwing_card()


func advance() -> void:
	if _finished or not _running:
		return
	if not _throwing.is_empty():
		return
	if _placed.size() < SCENE_COUNT:
		_begin_throw(_placed.size())
	else:
		_finish()


func skip_to_end() -> void:
	_finish()


func is_finished() -> bool:
	return _finished


func is_running() -> bool:
	return _running and not _finished


func is_throwing() -> bool:
	return not _throwing.is_empty()


func slide_count() -> int:
	return SCENE_COUNT


func placed_count() -> int:
	return _placed.size()


func get_placed_cards() -> Array[Dictionary]:
	return _placed


func get_throwing_card() -> Dictionary:
	return _throwing


func throw_progress() -> float:
	if _throwing.is_empty():
		return 1.0
	return clampf(float(_throwing.get("timer", 0.0)) / THROW_DURATION, 0.0, 1.0)


func get_scene_texture(index: int) -> Texture2D:
	if index < 0 or index >= SCENE_PATHS.size():
		return null
	return get_slide_texture(SCENE_PATHS[index])


func get_slide_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _textures.has(path):
		return _textures[path] as Texture2D
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		_textures[path] = tex
	return tex


func stack_center() -> Vector2:
	return Vector2(GameConstants.CANVAS_W * 0.5, GameConstants.CANVAS_H * 0.5 - 8.0)


func card_pose(index: int, eased_t: float = 1.0) -> Dictionary:
	var pose := _STACK_POSES[clampi(index, 0, _STACK_POSES.size() - 1)]
	var center := stack_center()
	var final_pos := center + Vector2(pose.x, pose.y)
	var final_rot: float = pose.z
	if eased_t >= 1.0:
		return {"pos": final_pos, "rot": final_rot, "scale": 1.0}
	var start_pos := final_pos + Vector2(130.0, -175.0)
	var start_rot: float = final_rot + 16.0
	var t: float = _ease_throw(eased_t)
	return {
		"pos": start_pos.lerp(final_pos, t),
		"rot": lerpf(start_rot, final_rot, t),
		"scale": lerpf(1.06, 1.0, t),
	}


func _begin_throw(index: int) -> void:
	_throwing = {"index": index, "timer": 0.0}


func _land_throwing_card() -> void:
	var index: int = int(_throwing.get("index", -1))
	if index >= 0:
		var pose := card_pose(index, 1.0)
		_placed.append({
			"index": index,
			"pos": pose["pos"],
			"rot": pose["rot"],
			"scale": 1.0,
		})
	_throwing = {}


func _finish() -> void:
	_running = false
	_finished = true
	_throwing = {}


func _ease_throw(t: float) -> float:
	var inv: float = 1.0 - t
	return 1.0 - inv * inv * inv
