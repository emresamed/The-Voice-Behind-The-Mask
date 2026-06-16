class_name PlayerSpriteFrames
extends RefCounted

## mainPlayer.png — 8×8 grid (256×256, 32px hücre)
## Satır = yön, sütun = animasyon karesi
## 0: ön/aşağı (S)  1: arka/yukarı (W)  2: sağ (D)  3: sol (A)
## 4: ön-sağ (S+D)  5: ön-sol (S+A)  6: arka-sağ (W+D)  7: arka-sol (W+A)
## Sütun 0–3: yürüme | 4–7: dash kareleri

const GRID_SIZE := 8
const WALK_COL_COUNT := 4
const DASH_COL_START := 4
const DASH_COL_COUNT := 4
const ANIM_FPS := 10.0
const DASH_ANIM_FPS := 24.0
const IDLE_COL := 0
const DASH_SCALE := 1.1


static func facing_row_from_move(mvx: float, mvy: float) -> int:
	var down := mvy < -0.001
	var up := mvy > 0.001
	var right := mvx > 0.001
	var left := mvx < -0.001

	if down and right:
		return 4
	if down and left:
		return 5
	if up and right:
		return 6
	if up and left:
		return 7
	if down:
		return 0
	if up:
		return 1
	if right:
		return 2
	if left:
		return 3
	return 0


static func draw_frame(
	canvas: CanvasItem,
	tex: Texture2D,
	pos: Vector2,
	facing_row: int,
	anim_time: float,
	moving: bool,
	size: float,
	modulate: Color,
	is_dashing: bool = false
) -> void:
	var row: int = clampi(facing_row, 0, GRID_SIZE - 1)
	var col: int
	var draw_size := size
	if is_dashing:
		col = DASH_COL_START + int(anim_time * DASH_ANIM_FPS) % DASH_COL_COUNT
		draw_size *= DASH_SCALE
	elif moving:
		col = int(anim_time * ANIM_FPS) % WALK_COL_COUNT
	else:
		col = IDLE_COL

	var tw := tex.get_width()
	var th := tex.get_height()
	var fw := tw / float(GRID_SIZE)
	var fh := th / float(GRID_SIZE)
	var src := Rect2(col * fw, row * fh, fw, fh)
	var scale := draw_size / maxf(fw, fh)
	var dst_size := Vector2(fw, fh) * scale
	var dst := Rect2(pos.x - dst_size.x * 0.5, pos.y - dst_size.y * 0.5, dst_size.x, dst_size.y)
	canvas.draw_texture_rect_region(tex, dst, src, modulate)
