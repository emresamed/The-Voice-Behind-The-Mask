class_name CanvasUtil
extends RefCounted

static func glow_circle(canvas: CanvasItem, center: Vector2, radius: float, color: Color, blur: float) -> void:
	if blur <= 0.0:
		canvas.draw_circle(center, radius, color)
		return
	var steps := maxi(3, int(blur / 4.0))
	for i in range(steps, 0, -1):
		var t := float(i) / float(steps)
		var c := color
		c.a = color.a * (1.0 - t * 0.85) * 0.35
		canvas.draw_circle(center, radius + blur * t * 0.55, c)
	canvas.draw_circle(center, radius, color)


static func glow_ring(canvas: CanvasItem, center: Vector2, radius: float, color: Color, blur: float, line_width: float = 2.5) -> void:
	const SEGMENTS := 72
	const END_ANGLE := TAU - 0.001
	if blur <= 0.0:
		canvas.draw_arc(center, radius, 0, END_ANGLE, SEGMENTS, color, line_width, true)
		return
	var steps := maxi(3, int(blur / 4.0))
	for i in range(steps, 0, -1):
		var t := float(i) / float(steps)
		var c := color
		c.a = color.a * (1.0 - t * 0.85) * 0.35
		canvas.draw_arc(center, radius + blur * t * 0.55, 0, END_ANGLE, SEGMENTS, c, line_width, true)
	canvas.draw_arc(center, radius, 0, END_ANGLE, SEGMENTS, color, line_width, true)


static func _draw_ring(canvas: CanvasItem, center: Vector2, inner_r: float, outer_r: float, color: Color) -> void:
	if outer_r <= inner_r or color.a <= 0.0:
		return
	var segments := 64
	var pts := PackedVector2Array()
	for i in range(segments + 1):
		var a := (float(i) / float(segments)) * TAU
		pts.append(center + Vector2(cos(a), sin(a)) * outer_r)
	for i in range(segments, -1, -1):
		var a := (float(i) / float(segments)) * TAU
		pts.append(center + Vector2(cos(a), sin(a)) * inner_r)
	canvas.draw_colored_polygon(pts, color)


static func radial_fill_circle(canvas: CanvasItem, center: Vector2, radius: float, inner: Color, mid: Color, outer: Color) -> void:
	var inner_r := radius * 0.3
	var rings := 24
	for i in range(rings):
		var t0 := float(i) / float(rings)
		var t1 := float(i + 1) / float(rings)
		var r0 := inner_r + (radius - inner_r) * t0
		var r1 := inner_r + (radius - inner_r) * t1
		var t_mid := (t0 + t1) * 0.5
		var c: Color
		if t_mid > 0.7:
			c = mid.lerp(outer, (t_mid - 0.7) / 0.3)
		else:
			c = inner.lerp(mid, t_mid / 0.7)
		_draw_ring(canvas, center, r0, r1, c)


static func echo_reveal_fill(canvas: CanvasItem, center: Vector2, radius: float, alpha: float) -> void:
	if radius <= 1.0 or alpha <= 0.0:
		return
	var rings := 48
	for i in range(rings):
		var t0 := float(i) / float(rings)
		var t1 := float(i + 1) / float(rings)
		var r0 := radius * t0
		var r1 := radius * t1
		var edge := 0.25 + t1 * 0.75
		var c := Color(0.04, 0.22, 0.28, alpha * edge * 0.04)
		_draw_ring(canvas, center, r0, r1, c)


static func echo_wave_front(canvas: CanvasItem, center: Vector2, radius: float, alpha: float) -> void:
	if radius <= 1.0 or alpha <= 0.0:
		return
	var band := maxf(7.0, radius * 0.035)
	var inner := maxf(0.0, radius - band * 0.55)
	var outer := radius + band * 0.25
	var core := Color(0.55, 0.98, 1.0, alpha * 0.5)
	var glow := Color(0.1, 0.82, 1.0, alpha * 0.18)
	for step in range(5, 0, -1):
		var t := float(step) / 5.0
		var c := glow
		c.a = glow.a * (1.0 - t * 0.75) * 0.28
		var spread := band * t * 0.55
		_draw_ring(canvas, center, inner - spread, outer + spread * 0.9, c)
	_draw_ring(canvas, center, inner, outer, core)
	glow_ring(canvas, center, radius, Color(0.7, 1.0, 1.0, alpha * 0.75), 12.0, 1.5)


static func echo_dark_front(canvas: CanvasItem, center: Vector2, inner_radius: float, outer_radius: float, alpha: float) -> void:
	if inner_radius <= 1.0 or alpha <= 0.0:
		return
	var band := maxf(6.0, inner_radius * 0.04)
	var inner := maxf(0.0, inner_radius - band * 0.35)
	var outer := inner_radius + band * 0.45
	var core := Color(0.02, 0.03, 0.06, alpha * 0.55)
	var edge := Color(0.04, 0.08, 0.12, alpha * 0.35)
	_draw_ring(canvas, center, inner, outer, edge)
	_draw_ring(canvas, center, inner_radius - band * 0.15, inner_radius + band * 0.2, core)
	if outer_radius > inner_radius + 12.0:
		glow_ring(canvas, center, inner_radius, Color(0.02, 0.05, 0.08, alpha * 0.4), 8.0, 1.0)


static func echo_ring_outline(canvas: CanvasItem, center: Vector2, radius: float, alpha: float) -> void:
	if radius <= 1.0 or alpha <= 0.0:
		return
	var band := maxf(4.0, radius * 0.02)
	_draw_ring(
		canvas,
		center,
		radius - band,
		radius + band * 0.2,
		Color(0.2, 0.75, 0.9, alpha * 0.35)
	)


static func linear_gradient_rect(canvas: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	var steps := maxi(1, int(rect.size.y))
	for i in range(steps):
		var t := float(i) / float(steps)
		var y := rect.position.y + t * rect.size.y
		var h := rect.size.y / float(steps) + 1.0
		canvas.draw_rect(Rect2(rect.position.x, y, rect.size.x, h), top.lerp(bottom, t), true)


static func dashed_h_line(canvas: CanvasItem, x1: float, x2: float, y: float, dash: float, gap: float, color: Color, width: float) -> void:
	var x := x1
	while x < x2:
		var end_x := minf(x + dash, x2)
		canvas.draw_line(Vector2(x, y), Vector2(end_x, y), color, width)
		x += dash + gap


static func round_rect(canvas: CanvasItem, rect: Rect2, radius: float, fill: Color, border: Color = Color.TRANSPARENT, border_w: float = 0.0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(int(radius))
	if border != Color.TRANSPARENT:
		style.border_color = border
		style.set_border_width_all(int(border_w))
	canvas.draw_style_box(style, rect)


static func souls_bar(
	canvas: CanvasItem,
	rect: Rect2,
	fill_frac: float,
	fill_color: Color,
	bg_color: Color = Color(1, 1, 1, 0.06),
	border_color: Color = Color(1, 1, 1, 0.18)
) -> void:
	round_rect(canvas, rect, 2.0, bg_color, border_color, 1.0)
	var inner := Rect2(rect.position.x + 1.0, rect.position.y + 1.0, maxf(0.0, (rect.size.x - 2.0) * clampf(fill_frac, 0.0, 1.0)), rect.size.y - 2.0)
	if inner.size.x > 0.5:
		round_rect(canvas, inner, 1.0, fill_color)


static func golden_echo_burst(canvas: CanvasItem, center: Vector2, radius: float, alpha: float) -> void:
	if radius <= 1.0 or alpha <= 0.0:
		return
	var band := maxf(10.0, radius * 0.04)
	var inner := maxf(0.0, radius - band * 0.6)
	var outer := radius + band * 0.35
	var core := Color(1.0, 0.88, 0.2, alpha * 0.62)
	var glow := Color(1.0, 0.62, 0.08, alpha * 0.28)
	for step in range(6, 0, -1):
		var t := float(step) / 6.0
		var c := glow
		c.a = glow.a * (1.0 - t * 0.7) * 0.35
		var spread := band * t * 0.65
		_draw_ring(canvas, center, inner - spread, outer + spread, c)
	_draw_ring(canvas, center, inner, outer, core)
	glow_ring(canvas, center, radius, Color(1.0, 0.95, 0.45, alpha * 0.85), 16.0, 2.5)
	glow_ring(canvas, center, radius * 0.72, Color(1.0, 0.75, 0.15, alpha * 0.45), 10.0, 1.5)


static func dash_echo_aura(canvas: CanvasItem, center: Vector2, radius: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	radial_fill_circle(
		canvas,
		center,
		radius,
		Color(1.0, 0.82, 0.2, alpha * 0.1),
		Color(0.85, 0.55, 0.05, alpha * 0.07),
		Color(0.35, 0.2, 0.02, alpha * 0.04)
	)
	glow_ring(canvas, center, radius * 0.92, Color(1.0, 0.9, 0.35, alpha * 0.38), 18.0, 2.0)


static func surge_aura(canvas: CanvasItem, center: Vector2, radius: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	radial_fill_circle(
		canvas,
		center,
		radius,
		Color(0.1, 0.85, 1.0, alpha * 0.12),
		Color(0.05, 0.45, 0.65, alpha * 0.08),
		Color(0.02, 0.15, 0.25, alpha * 0.04)
	)
	glow_ring(canvas, center, radius * 0.92, Color(0.5, 0.98, 1.0, alpha * 0.35), 18.0, 2.0)


static func boss_swipe_arc(canvas: CanvasItem, center: Vector2, angle: float, range: float, arc: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var segments := 20
	var pts := PackedVector2Array([center])
	var start := angle - arc * 0.5
	for i in range(segments + 1):
		var a := start + (float(i) / float(segments)) * arc
		pts.append(center + Vector2(cos(a), sin(a)) * range)
	canvas.draw_colored_polygon(pts, Color(1.0, 0.15, 0.12, 0.22 * alpha))
	glow_ring(canvas, center, range * 0.55, Color(1.0, 0.25, 0.2, 0.45 * alpha), 10.0, 2.0)


static func boss_charge_line(canvas: CanvasItem, from_pos: Vector2, dir: Vector2, length: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var end_pos := from_pos + dir.normalized() * length
	canvas.draw_line(from_pos, end_pos, Color(1.0, 0.35, 0.25, 0.55 * alpha), 3.0)
	canvas.draw_line(from_pos, end_pos, Color(1.0, 0.6, 0.4, 0.25 * alpha), 8.0)


static func ellipse(canvas: CanvasItem, center: Vector2, rx: float, ry: float, rot: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(32):
		var a := (float(i) / 32.0) * TAU
		var p := Vector2(cos(a) * rx, sin(a) * ry)
		p = p.rotated(rot)
		pts.append(center + p)
	canvas.draw_colored_polygon(pts, color)
