extends Node2D
## res://scripts/targeting_arrow.gd — STS-style chain targeting arrow with bezier curve

var start_pos: Vector2 = Vector2.ZERO
var end_pos: Vector2 = Vector2.ZERO
var active: bool = false

func _draw() -> void:
	if not active:
		return
	# Calculate bezier control point (lift upward)
	var mid: Vector2 = (start_pos + end_pos) / 2.0
	var dist: float = start_pos.distance_to(end_pos)
	var lift: float = clampf(dist * 0.4, 80.0, 280.0)
	var control: Vector2 = mid + Vector2(0, -lift)
	# Determine segment spacing — one circle every ~20px
	var curve_len: float = _approx_bezier_length(start_pos, control, end_pos)
	var segment_count: int = maxi(int(curve_len / 20.0), 6)
	# Draw chain of circles along curve
	for i in range(segment_count + 1):
		var t: float = float(i) / float(segment_count)
		var point: Vector2 = _bezier(start_pos, control, end_pos, t)
		# Vary size: smaller at ends, larger in middle, with slight pulse
		var size_factor: float = sin(t * PI)
		var radius: float = 5.0 + size_factor * 4.0
		# Color gradient: darker red at start, brighter at tip
		var color: Color = Color(0.8, 0.15, 0.1).lerp(Color(1.0, 0.3, 0.15), t)
		draw_circle(point, radius, color)
		# Inner highlight for depth
		draw_circle(point, radius * 0.45, Color(1.0, 0.5, 0.3, 0.5))
	# Arrowhead at tip
	var pre_tip: Vector2 = _bezier(start_pos, control, end_pos, 0.94)
	var dir: Vector2 = (end_pos - pre_tip).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var tip: Vector2 = end_pos + dir * 16.0
	var arrow_color: Color = Color(0.9, 0.2, 0.1)
	draw_colored_polygon(
		PackedVector2Array([tip, end_pos + perp * 13.0, end_pos - perp * 13.0]),
		arrow_color
	)
	# Inner highlight on arrowhead
	draw_colored_polygon(
		PackedVector2Array([tip - dir * 2.0, end_pos + perp * 7.0, end_pos - perp * 7.0]),
		Color(1.0, 0.45, 0.25, 0.5)
	)

func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0: Vector2 = p0.lerp(p1, t)
	var q1: Vector2 = p1.lerp(p2, t)
	return q0.lerp(q1, t)

func _approx_bezier_length(p0: Vector2, p1: Vector2, p2: Vector2) -> float:
	var length: float = 0.0
	var prev: Vector2 = p0
	var steps: int = 16
	for i in range(1, steps + 1):
		var t: float = float(i) / float(steps)
		var curr: Vector2 = _bezier(p0, p1, p2, t)
		length += prev.distance_to(curr)
		prev = curr
	return length

func update_arrow(from: Vector2, to: Vector2) -> void:
	start_pos = from
	end_pos = to
	active = true
	queue_redraw()

func hide_arrow() -> void:
	if active:
		active = false
		queue_redraw()
