extends Control
## Prohibition icon: circle with diagonal slash, drawn on cost orb for unplayable cards

func _draw():
	var center := size / 2
	var radius: float = minf(size.x, size.y) / 2 - 3.0
	var color := Color(1.0, 0.15, 0.15, 0.95)
	var width := 3.0
	# Circle
	draw_arc(center, radius, 0, TAU, 32, color, width, true)
	# Diagonal slash (top-right to bottom-left)
	var offset := radius * 0.7
	draw_line(center + Vector2(offset, -offset), center + Vector2(-offset, offset), color, width, true)
