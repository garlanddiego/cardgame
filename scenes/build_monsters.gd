extends SceneTree
## Scene builder — run: timeout 120 godot --headless --script scenes/build_monsters.gd
## Generates monster sprite PNGs for card game (STS style)
## Each monster has 3 frames: idle, attack, hit — saved to assets/img/monsters/

func _initialize() -> void:
	print("=== Monster Sprite Generator ===")
	DirAccess.make_dir_recursive_absolute("res://assets/img/monsters")

	_generate_mushroom()
	_generate_ghost_rat()
	_generate_skeleton()
	_generate_poison_spider()
	_generate_shadow_rogue()
	_generate_gargoyle()
	_generate_fire_mage()
	_generate_frost_giant()
	_generate_death_knight()
	_generate_ancient_dragon()

	print("=== All monsters generated ===")
	quit()

# ---------------------------------------------------------------------------
#  DRAWING HELPERS
# ---------------------------------------------------------------------------

func _fill_circle(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	var r2 := radius * radius
	for y in range(maxi(cy - radius, 0), mini(cy + radius + 1, img.get_height())):
		for x in range(maxi(cx - radius, 0), mini(cx + radius + 1, img.get_width())):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r2:
				img.set_pixel(x, y, color)

func _fill_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, color: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	for y in range(maxi(cy - ry, 0), mini(cy + ry + 1, img.get_height())):
		for x in range(maxi(cx - rx, 0), mini(cx + rx + 1, img.get_width())):
			var dx := float(x - cx) / float(rx)
			var dy := float(y - cy) / float(ry)
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, color)

func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for py in range(maxi(y, 0), mini(y + h, img.get_height())):
		for px in range(maxi(x, 0), mini(x + w, img.get_width())):
			img.set_pixel(px, py, color)

func _fill_rect_rounded(img: Image, x: int, y: int, w: int, h: int, radius: int, color: Color) -> void:
	# Fill the main rect body
	_fill_rect(img, x + radius, y, w - 2 * radius, h, color)
	_fill_rect(img, x, y + radius, w, h - 2 * radius, color)
	# Fill the four corners
	_fill_circle(img, x + radius, y + radius, radius, color)
	_fill_circle(img, x + w - radius - 1, y + radius, radius, color)
	_fill_circle(img, x + radius, y + h - radius - 1, radius, color)
	_fill_circle(img, x + w - radius - 1, y + h - radius - 1, radius, color)

func _draw_line_thick(img: Image, x1: int, y1: int, x2: int, y2: int, thickness: int, color: Color) -> void:
	var steps := maxi(absi(x2 - x1), absi(y2 - y1))
	if steps == 0:
		_fill_circle(img, x1, y1, thickness / 2, color)
		return
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var px := int(lerpf(float(x1), float(x2), t))
		var py := int(lerpf(float(y1), float(y2), t))
		_fill_circle(img, px, py, thickness / 2, color)

func _fill_triangle(img: Image, p1: Vector2i, p2: Vector2i, p3: Vector2i, color: Color) -> void:
	var min_y := maxi(mini(mini(p1.y, p2.y), p3.y), 0)
	var max_y := mini(maxi(maxi(p1.y, p2.y), p3.y), img.get_height() - 1)
	var min_x := maxi(mini(mini(p1.x, p2.x), p3.x), 0)
	var max_x := mini(maxi(maxi(p1.x, p2.x), p3.x), img.get_width() - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if _point_in_triangle(Vector2i(x, y), p1, p2, p3):
				img.set_pixel(x, y, color)

func _point_in_triangle(p: Vector2i, a: Vector2i, b: Vector2i, c: Vector2i) -> bool:
	var d1 := _sign_tri(p, a, b)
	var d2 := _sign_tri(p, b, c)
	var d3 := _sign_tri(p, c, a)
	var has_neg := (d1 < 0) or (d2 < 0) or (d3 < 0)
	var has_pos := (d1 > 0) or (d2 > 0) or (d3 > 0)
	return not (has_neg and has_pos)

func _sign_tri(p1: Vector2i, p2: Vector2i, p3: Vector2i) -> float:
	return float((p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y))

func _fill_quad(img: Image, p1: Vector2i, p2: Vector2i, p3: Vector2i, p4: Vector2i, color: Color) -> void:
	_fill_triangle(img, p1, p2, p3, color)
	_fill_triangle(img, p1, p3, p4, color)

func _blend_pixel(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or x >= img.get_width() or y < 0 or y >= img.get_height():
		return
	var existing := img.get_pixel(x, y)
	var blended := Color(
		existing.r * (1.0 - color.a) + color.r * color.a,
		existing.g * (1.0 - color.a) + color.g * color.a,
		existing.b * (1.0 - color.a) + color.b * color.a,
		clampf(existing.a + color.a, 0.0, 1.0)
	)
	img.set_pixel(x, y, blended)

func _fill_circle_blend(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	var r2 := radius * radius
	for y in range(maxi(cy - radius, 0), mini(cy + radius + 1, img.get_height())):
		for x in range(maxi(cx - radius, 0), mini(cx + radius + 1, img.get_width())):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r2:
				_blend_pixel(img, x, y, color)

func _fill_ellipse_blend(img: Image, cx: int, cy: int, rx: int, ry: int, color: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	for y in range(maxi(cy - ry, 0), mini(cy + ry + 1, img.get_height())):
		for x in range(maxi(cx - rx, 0), mini(cx + rx + 1, img.get_width())):
			var dx := float(x - cx) / float(rx)
			var dy := float(y - cy) / float(ry)
			if dx * dx + dy * dy <= 1.0:
				_blend_pixel(img, x, y, color)

## Apply a color tint to all non-transparent pixels
func _tint_image(img: Image, tint: Color, amount: float) -> void:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				c.r = lerpf(c.r, tint.r, amount)
				c.g = lerpf(c.g, tint.g, amount)
				c.b = lerpf(c.b, tint.b, amount)
				img.set_pixel(x, y, c)

## Shift all non-transparent pixels by dx, dy
func _shift_image(source: Image, dx: int, dy: int) -> Image:
	var w := source.get_width()
	var h := source.get_height()
	var result := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var sx := x - dx
			var sy := y - dy
			if sx >= 0 and sx < w and sy >= 0 and sy < h:
				result.set_pixel(x, y, source.get_pixel(sx, sy))
	return result

func _save(img: Image, path: String) -> void:
	var err := img.save_png(path)
	if err != OK:
		push_error("Failed to save: %s (error %d)" % [path, err])
	else:
		print("  Saved: %s" % path)

func _create_image(size: int = 256) -> Image:
	return Image.create(size, size, false, Image.FORMAT_RGBA8)

# ---------------------------------------------------------------------------
#  Outline helper — draw a dark outline around non-transparent pixels
# ---------------------------------------------------------------------------
func _add_outline(img: Image, outline_color: Color = Color(0.05, 0.05, 0.05, 0.8), thickness: int = 2) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var alpha_map: Array = []
	for y in range(h):
		var row: Array = []
		for x in range(w):
			row.append(img.get_pixel(x, y).a > 0.1)
		alpha_map.append(row)
	for y in range(h):
		for x in range(w):
			if alpha_map[y][x]:
				continue
			var near := false
			for dy in range(-thickness, thickness + 1):
				for dx in range(-thickness, thickness + 1):
					if dx * dx + dy * dy > thickness * thickness:
						continue
					var nx := x + dx
					var ny := y + dy
					if nx >= 0 and nx < w and ny >= 0 and ny < h:
						if alpha_map[ny][nx]:
							near = true
							break
				if near:
					break
			if near:
				img.set_pixel(x, y, outline_color)

# ---------------------------------------------------------------------------
#  Drop shadow
# ---------------------------------------------------------------------------
func _add_shadow(img: Image, offset_x: int = 3, offset_y: int = 5, shadow_color: Color = Color(0, 0, 0, 0.3)) -> void:
	var w := img.get_width()
	var h := img.get_height()
	# Collect shadow pixels first
	var shadow_pixels: Array[Vector2i] = []
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.1:
				var sx := x + offset_x
				var sy := y + offset_y
				if sx >= 0 and sx < w and sy >= 0 and sy < h:
					if img.get_pixel(sx, sy).a < 0.1:
						shadow_pixels.append(Vector2i(sx, sy))
	for p in shadow_pixels:
		img.set_pixel(p.x, p.y, shadow_color)


# ===========================================================================
#  1. MUSHROOM (蘑菇怪)
# ===========================================================================
func _draw_mushroom(img: Image, offset_x: int = 0, offset_y: int = 0) -> void:
	var cx := 128 + offset_x
	var base_y := 220 + offset_y

	# Shadow on ground
	_fill_ellipse(img, cx, base_y + 10, 50, 8, Color(0.1, 0.05, 0.0, 0.3))

	# Stem
	_fill_rect_rounded(img, cx - 18, base_y - 70, 36, 80, 8, Color(0.85, 0.8, 0.7, 1.0))
	# Stem shading
	_fill_rect(img, cx - 18, base_y - 70, 10, 80, Color(0.75, 0.7, 0.6, 0.4))

	# Stem base (wider)
	_fill_ellipse(img, cx, base_y + 5, 28, 12, Color(0.8, 0.75, 0.65, 1.0))

	# Cap - large semicircle
	var cap_color := Color(0.7, 0.15, 0.1, 1.0)
	var cap_dark := Color(0.5, 0.1, 0.05, 1.0)
	_fill_ellipse(img, cx, base_y - 80, 60, 50, cap_color)
	# Cap top highlight
	_fill_ellipse(img, cx - 8, base_y - 95, 35, 25, Color(0.85, 0.2, 0.15, 0.6))
	# Cap bottom edge (darker rim)
	_fill_ellipse(img, cx, base_y - 65, 58, 12, cap_dark)

	# Spots on cap (white)
	var spot_color := Color(1.0, 0.95, 0.85, 0.9)
	_fill_circle(img, cx - 25, base_y - 100, 8, spot_color)
	_fill_circle(img, cx + 15, base_y - 90, 10, spot_color)
	_fill_circle(img, cx - 5, base_y - 110, 6, spot_color)
	_fill_circle(img, cx + 35, base_y - 80, 7, spot_color)
	_fill_circle(img, cx - 40, base_y - 80, 5, spot_color)

	# Eyes (angry)
	_fill_ellipse(img, cx - 14, base_y - 50, 7, 9, Color.WHITE)
	_fill_ellipse(img, cx + 14, base_y - 50, 7, 9, Color.WHITE)
	_fill_circle(img, cx - 12, base_y - 48, 4, Color(0.1, 0.0, 0.0, 1.0))
	_fill_circle(img, cx + 16, base_y - 48, 4, Color(0.1, 0.0, 0.0, 1.0))
	# Angry eyebrows
	_draw_line_thick(img, cx - 22, base_y - 62, cx - 8, base_y - 58, 3, Color(0.4, 0.1, 0.05, 1.0))
	_draw_line_thick(img, cx + 22, base_y - 62, cx + 8, base_y - 58, 3, Color(0.4, 0.1, 0.05, 1.0))

	# Mouth (frown)
	_fill_ellipse(img, cx, base_y - 36, 10, 5, Color(0.2, 0.0, 0.0, 1.0))

func _generate_mushroom() -> void:
	print("Generating: mushroom")
	# Idle
	var idle := _create_image()
	_draw_mushroom(idle)
	_add_outline(idle)
	_add_shadow(idle)
	_save(idle, "res://assets/img/monsters/mushroom_idle.png")

	# Attack — lean forward
	var attack := _create_image()
	_draw_mushroom(attack, 15, -5)
	_add_outline(attack)
	_save(attack, "res://assets/img/monsters/mushroom_attack.png")

	# Hit — squish down
	var hit := _create_image()
	_draw_mushroom(hit, -8, 10)
	_tint_image(hit, Color(1.0, 0.3, 0.3), 0.25)
	_add_outline(hit)
	_save(hit, "res://assets/img/monsters/mushroom_hit.png")


# ===========================================================================
#  2. GHOST RAT (幽灵鼠)
# ===========================================================================
func _draw_ghost_rat(img: Image, offset_x: int = 0, offset_y: int = 0, alpha_mult: float = 1.0) -> void:
	var cx := 128 + offset_x
	var base_y := 200 + offset_y
	var base_alpha := 0.7 * alpha_mult

	# Body — translucent blue oval
	var body_color := Color(0.3, 0.5, 0.9, base_alpha)
	_fill_ellipse(img, cx, base_y, 45, 30, body_color)
	# Body highlight
	_fill_ellipse(img, cx - 10, base_y - 10, 25, 15, Color(0.5, 0.7, 1.0, base_alpha * 0.5))

	# Head
	_fill_ellipse(img, cx + 35, base_y - 15, 25, 22, Color(0.35, 0.5, 0.85, base_alpha))
	# Snout
	_fill_ellipse(img, cx + 55, base_y - 12, 12, 10, Color(0.4, 0.55, 0.9, base_alpha))
	# Nose
	_fill_circle(img, cx + 65, base_y - 12, 4, Color(0.8, 0.4, 0.5, base_alpha))

	# Ears
	_fill_ellipse(img, cx + 25, base_y - 35, 10, 14, Color(0.4, 0.55, 0.9, base_alpha))
	_fill_ellipse(img, cx + 40, base_y - 35, 10, 14, Color(0.4, 0.55, 0.9, base_alpha))
	# Inner ears
	_fill_ellipse(img, cx + 25, base_y - 33, 6, 9, Color(0.6, 0.5, 0.8, base_alpha * 0.7))
	_fill_ellipse(img, cx + 40, base_y - 33, 6, 9, Color(0.6, 0.5, 0.8, base_alpha * 0.7))

	# Glowing eyes
	_fill_circle(img, cx + 32, base_y - 18, 5, Color(1.0, 0.9, 0.2, min(1.0, base_alpha + 0.3)))
	_fill_circle(img, cx + 45, base_y - 18, 5, Color(1.0, 0.9, 0.2, min(1.0, base_alpha + 0.3)))
	# Pupil
	_fill_circle(img, cx + 33, base_y - 17, 2, Color(0.1, 0.0, 0.0, base_alpha))
	_fill_circle(img, cx + 46, base_y - 17, 2, Color(0.1, 0.0, 0.0, base_alpha))

	# Legs (4 short ones)
	var leg_color := Color(0.3, 0.45, 0.85, base_alpha * 0.9)
	_fill_ellipse(img, cx - 25, base_y + 20, 8, 14, leg_color)
	_fill_ellipse(img, cx - 5, base_y + 22, 8, 14, leg_color)
	_fill_ellipse(img, cx + 15, base_y + 20, 8, 14, leg_color)
	_fill_ellipse(img, cx + 35, base_y + 18, 8, 12, leg_color)

	# Spectral tail — wavy line going left
	var tail_color := Color(0.4, 0.6, 1.0, base_alpha * 0.6)
	for i in range(40):
		var tx := cx - 45 - i
		var ty := base_y + int(sin(float(i) * 0.3) * 8.0)
		var fade := 1.0 - float(i) / 40.0
		_fill_circle_blend(img, tx, ty, int(4.0 * fade), Color(tail_color.r, tail_color.g, tail_color.b, tail_color.a * fade))

	# Ghostly glow around body
	_fill_ellipse_blend(img, cx, base_y, 55, 40, Color(0.5, 0.7, 1.0, 0.1))

func _generate_ghost_rat() -> void:
	print("Generating: ghost_rat")
	var idle := _create_image()
	_draw_ghost_rat(idle)
	_add_outline(idle, Color(0.2, 0.3, 0.6, 0.5))
	_save(idle, "res://assets/img/monsters/ghost_rat_idle.png")

	var attack := _create_image()
	_draw_ghost_rat(attack, 20, -8)
	_add_outline(attack, Color(0.2, 0.3, 0.6, 0.5))
	_save(attack, "res://assets/img/monsters/ghost_rat_attack.png")

	var hit := _create_image()
	_draw_ghost_rat(hit, -5, 0, 0.5)
	_add_outline(hit, Color(0.2, 0.3, 0.6, 0.3))
	_save(hit, "res://assets/img/monsters/ghost_rat_hit.png")


# ===========================================================================
#  3. SKELETON (骷髅兵)
# ===========================================================================
func _draw_skeleton(img: Image, offset_x: int = 0, offset_y: int = 0, sword_angle: float = 0.0) -> void:
	var cx := 128 + offset_x
	var base_y := 230 + offset_y
	var bone := Color(0.92, 0.9, 0.85, 1.0)
	var bone_dark := Color(0.7, 0.68, 0.62, 1.0)
	var eye_color := Color(0.1, 0.0, 0.0, 1.0)

	# Ground shadow
	_fill_ellipse(img, cx, base_y + 5, 35, 6, Color(0.1, 0.1, 0.1, 0.25))

	# Legs (two bone segments each)
	# Left leg
	_draw_line_thick(img, cx - 12, base_y - 40, cx - 18, base_y - 10, 5, bone)
	_draw_line_thick(img, cx - 18, base_y - 10, cx - 15, base_y + 5, 4, bone)
	# Right leg
	_draw_line_thick(img, cx + 12, base_y - 40, cx + 18, base_y - 10, 5, bone)
	_draw_line_thick(img, cx + 18, base_y - 10, cx + 15, base_y + 5, 4, bone)
	# Feet
	_fill_ellipse(img, cx - 15, base_y + 5, 10, 4, bone_dark)
	_fill_ellipse(img, cx + 15, base_y + 5, 10, 4, bone_dark)

	# Pelvis
	_fill_ellipse(img, cx, base_y - 45, 18, 10, bone)

	# Ribcage / torso
	_fill_ellipse(img, cx, base_y - 80, 22, 30, bone)
	# Rib lines (darker)
	for i in range(4):
		var ry := base_y - 95 + i * 12
		_draw_line_thick(img, cx - 18, ry, cx + 18, ry, 2, bone_dark)
	# Spine
	_draw_line_thick(img, cx, base_y - 45, cx, base_y - 105, 4, bone_dark)

	# Arms
	# Left arm (hanging)
	_draw_line_thick(img, cx - 22, base_y - 95, cx - 35, base_y - 65, 4, bone)
	_draw_line_thick(img, cx - 35, base_y - 65, cx - 30, base_y - 45, 3, bone)

	# Right arm (holding sword) — angle adjusts for attack
	var shoulder_x := cx + 22
	var shoulder_y := base_y - 95
	var elbow_x := cx + 38 + int(sin(sword_angle) * 10.0)
	var elbow_y := base_y - 75 + int(cos(sword_angle) * 5.0)
	var hand_x := cx + 45 + int(sin(sword_angle) * 20.0)
	var hand_y := base_y - 60 + int(cos(sword_angle) * 15.0)
	_draw_line_thick(img, shoulder_x, shoulder_y, elbow_x, elbow_y, 4, bone)
	_draw_line_thick(img, elbow_x, elbow_y, hand_x, hand_y, 3, bone)

	# Sword
	var sword_tip_x := hand_x + int(sin(sword_angle + 0.3) * 50.0)
	var sword_tip_y := hand_y - 45 + int(cos(sword_angle) * 10.0)
	_draw_line_thick(img, hand_x, hand_y, sword_tip_x, sword_tip_y, 3, Color(0.7, 0.7, 0.75, 1.0))
	# Sword highlight
	_draw_line_thick(img, hand_x + 1, hand_y, sword_tip_x + 1, sword_tip_y, 1, Color(0.9, 0.9, 0.95, 0.6))
	# Crossguard
	_fill_rect(img, hand_x - 8, hand_y - 3, 16, 5, Color(0.5, 0.4, 0.2, 1.0))

	# Skull
	_fill_circle(img, cx, base_y - 120, 20, bone)
	# Jaw
	_fill_ellipse(img, cx, base_y - 100, 15, 8, bone)
	# Eye sockets
	_fill_ellipse(img, cx - 8, base_y - 123, 6, 7, eye_color)
	_fill_ellipse(img, cx + 8, base_y - 123, 6, 7, eye_color)
	# Red eye glow
	_fill_circle(img, cx - 8, base_y - 122, 2, Color(0.8, 0.1, 0.0, 0.8))
	_fill_circle(img, cx + 8, base_y - 122, 2, Color(0.8, 0.1, 0.0, 0.8))
	# Nose hole
	_fill_triangle(img, Vector2i(cx - 3, base_y - 113), Vector2i(cx + 3, base_y - 113), Vector2i(cx, base_y - 108), eye_color)
	# Teeth
	for i in range(5):
		_fill_rect(img, cx - 10 + i * 5, base_y - 103, 3, 5, bone)
		_fill_rect(img, cx - 10 + i * 5, base_y - 103, 3, 1, bone_dark)

func _generate_skeleton() -> void:
	print("Generating: skeleton")
	var idle := _create_image()
	_draw_skeleton(idle)
	_add_outline(idle)
	_add_shadow(idle)
	_save(idle, "res://assets/img/monsters/skeleton_idle.png")

	var attack := _create_image()
	_draw_skeleton(attack, 12, -3, 1.2)
	_add_outline(attack)
	_save(attack, "res://assets/img/monsters/skeleton_attack.png")

	var hit := _create_image()
	_draw_skeleton(hit, -10, 3, -0.3)
	_tint_image(hit, Color(1.0, 0.4, 0.4), 0.2)
	_add_outline(hit)
	_save(hit, "res://assets/img/monsters/skeleton_hit.png")


# ===========================================================================
#  4. POISON SPIDER (毒蛛)
# ===========================================================================
func _draw_poison_spider(img: Image, offset_x: int = 0, offset_y: int = 0) -> void:
	var cx := 128 + offset_x
	var base_y := 180 + offset_y
	var body_color := Color(0.35, 0.1, 0.4, 1.0)
	var leg_color := Color(0.2, 0.5, 0.15, 1.0)
	var fang_color := Color(0.5, 0.8, 0.2, 1.0)

	# Legs (8 total — 4 each side, segmented)
	var leg_starts_l: Array[Vector2i] = [
		Vector2i(cx - 20, base_y - 5),
		Vector2i(cx - 18, base_y + 5),
		Vector2i(cx - 15, base_y + 15),
		Vector2i(cx - 12, base_y + 22),
	]
	var leg_mids_l: Array[Vector2i] = [
		Vector2i(cx - 60, base_y - 30),
		Vector2i(cx - 65, base_y - 10),
		Vector2i(cx - 62, base_y + 12),
		Vector2i(cx - 55, base_y + 35),
	]
	var leg_ends_l: Array[Vector2i] = [
		Vector2i(cx - 75, base_y + 10),
		Vector2i(cx - 80, base_y + 25),
		Vector2i(cx - 78, base_y + 40),
		Vector2i(cx - 70, base_y + 55),
	]
	for i in range(4):
		_draw_line_thick(img, leg_starts_l[i].x, leg_starts_l[i].y, leg_mids_l[i].x, leg_mids_l[i].y, 4, leg_color)
		_draw_line_thick(img, leg_mids_l[i].x, leg_mids_l[i].y, leg_ends_l[i].x, leg_ends_l[i].y, 3, leg_color)
		# Mirror for right side
		var rs := Vector2i(cx + (cx - leg_starts_l[i].x), leg_starts_l[i].y)
		var rm := Vector2i(cx + (cx - leg_mids_l[i].x), leg_mids_l[i].y)
		var re := Vector2i(cx + (cx - leg_ends_l[i].x), leg_ends_l[i].y)
		_draw_line_thick(img, rs.x, rs.y, rm.x, rm.y, 4, leg_color)
		_draw_line_thick(img, rm.x, rm.y, re.x, re.y, 3, leg_color)

	# Abdomen (large back part)
	_fill_ellipse(img, cx, base_y + 20, 35, 28, body_color)
	# Abdomen pattern
	_fill_ellipse(img, cx, base_y + 15, 18, 12, Color(0.5, 0.15, 0.55, 0.6))
	_fill_circle(img, cx, base_y + 8, 6, Color(0.6, 0.2, 0.1, 0.5))

	# Cephalothorax (front body)
	_fill_ellipse(img, cx, base_y - 5, 25, 20, Color(0.4, 0.12, 0.45, 1.0))

	# Head
	_fill_ellipse(img, cx, base_y - 22, 18, 15, body_color)

	# Eyes (8 eyes — 2 large, 6 small)
	_fill_circle(img, cx - 8, base_y - 28, 5, Color(0.9, 0.1, 0.1, 1.0))
	_fill_circle(img, cx + 8, base_y - 28, 5, Color(0.9, 0.1, 0.1, 1.0))
	_fill_circle(img, cx - 8, base_y - 27, 2, Color(1.0, 1.0, 0.8, 1.0))
	_fill_circle(img, cx + 8, base_y - 27, 2, Color(1.0, 1.0, 0.8, 1.0))
	# Small eyes
	_fill_circle(img, cx - 14, base_y - 24, 2, Color(0.8, 0.1, 0.1, 0.8))
	_fill_circle(img, cx + 14, base_y - 24, 2, Color(0.8, 0.1, 0.1, 0.8))
	_fill_circle(img, cx - 4, base_y - 32, 2, Color(0.8, 0.1, 0.1, 0.8))
	_fill_circle(img, cx + 4, base_y - 32, 2, Color(0.8, 0.1, 0.1, 0.8))
	_fill_circle(img, cx - 12, base_y - 18, 2, Color(0.8, 0.1, 0.1, 0.7))
	_fill_circle(img, cx + 12, base_y - 18, 2, Color(0.8, 0.1, 0.1, 0.7))

	# Fangs (dripping green)
	_draw_line_thick(img, cx - 6, base_y - 12, cx - 10, base_y + 2, 3, fang_color)
	_draw_line_thick(img, cx + 6, base_y - 12, cx + 10, base_y + 2, 3, fang_color)
	# Drip
	_fill_circle(img, cx - 10, base_y + 5, 3, Color(0.4, 0.8, 0.1, 0.7))
	_fill_circle(img, cx + 10, base_y + 5, 3, Color(0.4, 0.8, 0.1, 0.7))

func _generate_poison_spider() -> void:
	print("Generating: poison_spider")
	var idle := _create_image()
	_draw_poison_spider(idle)
	_add_outline(idle, Color(0.15, 0.05, 0.2, 0.7))
	_add_shadow(idle)
	_save(idle, "res://assets/img/monsters/poison_spider_idle.png")

	var attack := _create_image()
	_draw_poison_spider(attack, 18, -10)
	_add_outline(attack, Color(0.15, 0.05, 0.2, 0.7))
	_save(attack, "res://assets/img/monsters/poison_spider_attack.png")

	var hit := _create_image()
	_draw_poison_spider(hit, -12, 5)
	_tint_image(hit, Color(1.0, 0.5, 0.5), 0.2)
	_add_outline(hit, Color(0.15, 0.05, 0.2, 0.7))
	_save(hit, "res://assets/img/monsters/poison_spider_hit.png")


# ===========================================================================
#  5. SHADOW ROGUE (暗影刺客)
# ===========================================================================
func _draw_shadow_rogue(img: Image, offset_x: int = 0, offset_y: int = 0, fade: float = 1.0) -> void:
	var cx := 128 + offset_x
	var base_y := 230 + offset_y
	var dark := Color(0.12, 0.1, 0.15, 0.95 * fade)
	var cloak := Color(0.18, 0.15, 0.22, 0.9 * fade)
	var glow := Color(0.6, 0.2, 0.8, 0.8 * fade)

	# Ground shadow
	_fill_ellipse_blend(img, cx, base_y + 5, 30, 6, Color(0.05, 0.0, 0.05, 0.3 * fade))

	# Cloak / body — tall triangle shape
	_fill_triangle(img, Vector2i(cx - 35, base_y), Vector2i(cx + 35, base_y), Vector2i(cx, base_y - 120), cloak)
	# Inner cloak darker
	_fill_triangle(img, Vector2i(cx - 20, base_y - 5), Vector2i(cx + 20, base_y - 5), Vector2i(cx, base_y - 100), dark)

	# Hood
	_fill_circle(img, cx, base_y - 115, 22, cloak)
	_fill_ellipse(img, cx, base_y - 108, 20, 16, dark)

	# Glowing eyes under hood
	_fill_circle(img, cx - 8, base_y - 115, 4, glow)
	_fill_circle(img, cx + 8, base_y - 115, 4, glow)
	_fill_circle(img, cx - 8, base_y - 115, 2, Color(0.9, 0.5, 1.0, fade))
	_fill_circle(img, cx + 8, base_y - 115, 2, Color(0.9, 0.5, 1.0, fade))

	# Daggers (two, glowing)
	var dagger_color := Color(0.7, 0.75, 0.8, fade)
	var dagger_glow := Color(0.5, 0.8, 0.5, 0.6 * fade)
	# Left dagger
	_draw_line_thick(img, cx - 38, base_y - 50, cx - 50, base_y - 80, 3, dagger_color)
	_fill_circle_blend(img, cx - 50, base_y - 80, 4, dagger_glow)
	# Right dagger
	_draw_line_thick(img, cx + 38, base_y - 50, cx + 50, base_y - 80, 3, dagger_color)
	_fill_circle_blend(img, cx + 50, base_y - 80, 4, dagger_glow)

	# Smoke wisps around base
	for i in range(6):
		var wx := cx - 30 + i * 12
		var wy := base_y - 5 + (i % 3) * 4
		_fill_circle_blend(img, wx, wy, 8 + i % 3, Color(0.2, 0.15, 0.25, 0.15 * fade))

func _generate_shadow_rogue() -> void:
	print("Generating: shadow_rogue")
	var idle := _create_image()
	_draw_shadow_rogue(idle)
	_add_outline(idle, Color(0.3, 0.1, 0.4, 0.6))
	_save(idle, "res://assets/img/monsters/shadow_rogue_idle.png")

	var attack := _create_image()
	_draw_shadow_rogue(attack, 20, -5)
	_add_outline(attack, Color(0.3, 0.1, 0.4, 0.6))
	_save(attack, "res://assets/img/monsters/shadow_rogue_attack.png")

	var hit := _create_image()
	_draw_shadow_rogue(hit, -8, 3, 0.55)
	_add_outline(hit, Color(0.3, 0.1, 0.4, 0.4))
	_save(hit, "res://assets/img/monsters/shadow_rogue_hit.png")


# ===========================================================================
#  6. GARGOYLE (石像鬼)
# ===========================================================================
func _draw_gargoyle(img: Image, offset_x: int = 0, offset_y: int = 0, wing_spread: float = 1.0) -> void:
	var cx := 128 + offset_x
	var base_y := 220 + offset_y
	var stone := Color(0.45, 0.43, 0.42, 1.0)
	var stone_dark := Color(0.3, 0.28, 0.27, 1.0)
	var stone_light := Color(0.58, 0.56, 0.53, 1.0)

	# Ground shadow
	_fill_ellipse(img, cx, base_y + 8, 40, 7, Color(0.1, 0.1, 0.1, 0.3))

	# Wings (bat-like, behind body)
	var wing_w := int(55.0 * wing_spread)
	var wing_h := int(45.0 * wing_spread)
	# Left wing
	_fill_triangle(img, Vector2i(cx - 15, base_y - 70), Vector2i(cx - 15 - wing_w, base_y - 70 - wing_h), Vector2i(cx - 15 - wing_w + 10, base_y - 30), stone_dark)
	_fill_triangle(img, Vector2i(cx - 15, base_y - 55), Vector2i(cx - 15 - wing_w + 15, base_y - 70 - wing_h + 15), Vector2i(cx - 15 - wing_w + 20, base_y - 25), Color(0.35, 0.33, 0.32, 0.7))
	# Right wing
	_fill_triangle(img, Vector2i(cx + 15, base_y - 70), Vector2i(cx + 15 + wing_w, base_y - 70 - wing_h), Vector2i(cx + 15 + wing_w - 10, base_y - 30), stone_dark)
	_fill_triangle(img, Vector2i(cx + 15, base_y - 55), Vector2i(cx + 15 + wing_w - 15, base_y - 70 - wing_h + 15), Vector2i(cx + 15 + wing_w - 20, base_y - 25), Color(0.35, 0.33, 0.32, 0.7))

	# Body — stocky
	_fill_ellipse(img, cx, base_y - 30, 28, 40, stone)
	# Chest highlight
	_fill_ellipse(img, cx - 5, base_y - 40, 15, 20, stone_light)

	# Legs — thick and squat
	_fill_rect_rounded(img, cx - 22, base_y + 2, 18, 22, 4, stone)
	_fill_rect_rounded(img, cx + 4, base_y + 2, 18, 22, 4, stone)
	# Claws
	for i in range(3):
		_fill_circle(img, cx - 20 + i * 5, base_y + 24, 3, stone_dark)
		_fill_circle(img, cx + 6 + i * 5, base_y + 24, 3, stone_dark)

	# Arms
	_draw_line_thick(img, cx - 28, base_y - 50, cx - 40, base_y - 25, 6, stone)
	_draw_line_thick(img, cx + 28, base_y - 50, cx + 40, base_y - 25, 6, stone)
	# Clawed hands
	_fill_circle(img, cx - 42, base_y - 22, 5, stone_dark)
	_fill_circle(img, cx + 42, base_y - 22, 5, stone_dark)

	# Head
	_fill_ellipse(img, cx, base_y - 75, 20, 18, stone)
	# Horns
	_fill_triangle(img, Vector2i(cx - 15, base_y - 85), Vector2i(cx - 10, base_y - 85), Vector2i(cx - 22, base_y - 110), stone_dark)
	_fill_triangle(img, Vector2i(cx + 15, base_y - 85), Vector2i(cx + 10, base_y - 85), Vector2i(cx + 22, base_y - 110), stone_dark)

	# Face
	# Eyes — glowing yellow
	_fill_ellipse(img, cx - 8, base_y - 78, 5, 4, Color(0.9, 0.7, 0.1, 1.0))
	_fill_ellipse(img, cx + 8, base_y - 78, 5, 4, Color(0.9, 0.7, 0.1, 1.0))
	_fill_circle(img, cx - 8, base_y - 78, 2, Color(0.5, 0.2, 0.0, 1.0))
	_fill_circle(img, cx + 8, base_y - 78, 2, Color(0.5, 0.2, 0.0, 1.0))
	# Mouth — snarling
	_fill_ellipse(img, cx, base_y - 66, 10, 5, Color(0.15, 0.1, 0.1, 1.0))
	# Fangs
	_fill_triangle(img, Vector2i(cx - 6, base_y - 68), Vector2i(cx - 3, base_y - 68), Vector2i(cx - 5, base_y - 60), Color(0.8, 0.8, 0.75, 1.0))
	_fill_triangle(img, Vector2i(cx + 3, base_y - 68), Vector2i(cx + 6, base_y - 68), Vector2i(cx + 5, base_y - 60), Color(0.8, 0.8, 0.75, 1.0))

	# Stone cracks (detail lines)
	_draw_line_thick(img, cx - 10, base_y - 20, cx - 5, base_y - 5, 1, stone_dark)
	_draw_line_thick(img, cx + 8, base_y - 35, cx + 15, base_y - 20, 1, stone_dark)

func _generate_gargoyle() -> void:
	print("Generating: gargoyle")
	var idle := _create_image()
	_draw_gargoyle(idle)
	_add_outline(idle)
	_add_shadow(idle)
	_save(idle, "res://assets/img/monsters/gargoyle_idle.png")

	# Attack — swoop forward, wings wide
	var attack := _create_image()
	_draw_gargoyle(attack, 18, -15, 1.4)
	_add_outline(attack)
	_save(attack, "res://assets/img/monsters/gargoyle_attack.png")

	# Hit — crack effect
	var hit := _create_image()
	_draw_gargoyle(hit, -8, 5, 0.7)
	_tint_image(hit, Color(0.8, 0.6, 0.5), 0.2)
	# Draw crack lines
	_draw_line_thick(hit, 120, 140, 105, 170, 2, Color(0.2, 0.2, 0.2, 0.8))
	_draw_line_thick(hit, 105, 170, 115, 195, 2, Color(0.2, 0.2, 0.2, 0.8))
	_draw_line_thick(hit, 140, 150, 150, 180, 2, Color(0.2, 0.2, 0.2, 0.8))
	_add_outline(hit)
	_save(hit, "res://assets/img/monsters/gargoyle_hit.png")


# ===========================================================================
#  7. FIRE MAGE (火焰法师)
# ===========================================================================
func _draw_fire_mage(img: Image, offset_x: int = 0, offset_y: int = 0, casting: bool = false) -> void:
	var cx := 128 + offset_x
	var base_y := 230 + offset_y
	var robe := Color(0.65, 0.12, 0.08, 1.0)
	var robe_dark := Color(0.4, 0.08, 0.05, 1.0)
	var skin := Color(0.85, 0.7, 0.55, 1.0)

	# Ground shadow
	_fill_ellipse(img, cx, base_y + 5, 35, 7, Color(0.1, 0.05, 0.0, 0.3))

	# Robe body — large triangle
	_fill_triangle(img, Vector2i(cx - 38, base_y + 5), Vector2i(cx + 38, base_y + 5), Vector2i(cx, base_y - 90), robe)
	# Robe shading
	_fill_triangle(img, Vector2i(cx - 25, base_y), Vector2i(cx - 5, base_y), Vector2i(cx - 8, base_y - 70), robe_dark)

	# Belt
	_fill_rect(img, cx - 22, base_y - 45, 44, 6, Color(0.5, 0.35, 0.15, 1.0))
	_fill_circle(img, cx, base_y - 42, 4, Color(0.8, 0.6, 0.1, 1.0))  # Belt buckle

	# Arms / sleeves
	# Left arm — down
	_fill_triangle(img, Vector2i(cx - 22, base_y - 75), Vector2i(cx - 18, base_y - 60), Vector2i(cx - 45, base_y - 55), robe)
	_fill_circle(img, cx - 45, base_y - 55, 6, skin)  # Hand

	# Right arm — holding staff (or raised for casting)
	var staff_hand_x := cx + 40
	var staff_hand_y := base_y - 65
	if casting:
		staff_hand_x = cx + 45
		staff_hand_y = base_y - 85
	_fill_triangle(img, Vector2i(cx + 22, base_y - 75), Vector2i(cx + 18, base_y - 60), Vector2i(staff_hand_x, staff_hand_y), robe)
	_fill_circle(img, staff_hand_x, staff_hand_y, 5, skin)

	# Staff
	var staff_top_y := staff_hand_y - 55
	_draw_line_thick(img, staff_hand_x, staff_hand_y, staff_hand_x + 5, base_y + 5, 4, Color(0.4, 0.25, 0.1, 1.0))
	# Staff orb (fire)
	_fill_circle(img, staff_hand_x + 2, staff_top_y, 10, Color(1.0, 0.5, 0.0, 0.9))
	_fill_circle(img, staff_hand_x + 2, staff_top_y, 6, Color(1.0, 0.8, 0.2, 0.9))
	_fill_circle(img, staff_hand_x + 2, staff_top_y - 2, 3, Color(1.0, 1.0, 0.6, 0.9))

	# Head
	_fill_circle(img, cx, base_y - 105, 16, skin)
	# Hood
	_fill_ellipse(img, cx, base_y - 112, 20, 18, robe)
	_fill_ellipse(img, cx, base_y - 104, 16, 12, Color(0.1, 0.05, 0.05, 0.8))  # Shadow under hood

	# Eyes (glowing orange)
	_fill_circle(img, cx - 6, base_y - 107, 3, Color(1.0, 0.6, 0.1, 1.0))
	_fill_circle(img, cx + 6, base_y - 107, 3, Color(1.0, 0.6, 0.1, 1.0))
	_fill_circle(img, cx - 6, base_y - 107, 1, Color(1.0, 1.0, 0.5, 1.0))
	_fill_circle(img, cx + 6, base_y - 107, 1, Color(1.0, 1.0, 0.5, 1.0))

	# Beard
	_fill_triangle(img, Vector2i(cx - 10, base_y - 95), Vector2i(cx + 10, base_y - 95), Vector2i(cx, base_y - 75), Color(0.7, 0.65, 0.6, 0.8))

	# Fire particles (if casting)
	if casting:
		for i in range(8):
			var fx := staff_hand_x + 2 + int(sin(float(i) * 1.3) * 20.0)
			var fy := staff_top_y - 10 - i * 5
			var fr := 5 - i / 2
			if fr > 0:
				_fill_circle_blend(img, fx, fy, fr, Color(1.0, 0.4 + float(i) * 0.05, 0.0, 0.7 - float(i) * 0.08))

func _generate_fire_mage() -> void:
	print("Generating: fire_mage")
	var idle := _create_image()
	_draw_fire_mage(idle)
	_add_outline(idle)
	_add_shadow(idle)
	_save(idle, "res://assets/img/monsters/fire_mage_idle.png")

	var attack := _create_image()
	_draw_fire_mage(attack, 10, -5, true)
	_add_outline(attack)
	_save(attack, "res://assets/img/monsters/fire_mage_attack.png")

	var hit := _create_image()
	_draw_fire_mage(hit, -10, 5)
	_tint_image(hit, Color(1.0, 0.4, 0.3), 0.2)
	_add_outline(hit)
	_save(hit, "res://assets/img/monsters/fire_mage_hit.png")


# ===========================================================================
#  8. FROST GIANT (冰霜巨人)
# ===========================================================================
func _draw_frost_giant(img: Image, offset_x: int = 0, offset_y: int = 0, slamming: bool = false) -> void:
	var cx := 128 + offset_x
	var base_y := 235 + offset_y
	var ice_blue := Color(0.4, 0.6, 0.85, 1.0)
	var ice_dark := Color(0.25, 0.4, 0.65, 1.0)
	var ice_light := Color(0.7, 0.85, 0.95, 1.0)
	var crystal := Color(0.6, 0.85, 1.0, 0.7)

	# Ground shadow
	_fill_ellipse(img, cx, base_y + 5, 45, 8, Color(0.1, 0.15, 0.2, 0.3))

	# Legs — thick
	_fill_rect_rounded(img, cx - 28, base_y - 30, 22, 35, 5, ice_dark)
	_fill_rect_rounded(img, cx + 6, base_y - 30, 22, 35, 5, ice_dark)
	# Feet
	_fill_ellipse(img, cx - 17, base_y + 5, 16, 6, ice_dark)
	_fill_ellipse(img, cx + 17, base_y + 5, 16, 6, ice_dark)

	# Body — massive torso
	_fill_ellipse(img, cx, base_y - 60, 38, 42, ice_blue)
	# Chest highlight
	_fill_ellipse(img, cx - 8, base_y - 70, 20, 25, ice_light)
	# Belly
	_fill_ellipse(img, cx, base_y - 45, 30, 18, ice_dark)

	# Arms — large
	var arm_raise := -20 if slamming else 0
	# Left arm
	_draw_line_thick(img, cx - 38, base_y - 75, cx - 55, base_y - 50 + arm_raise, 10, ice_blue)
	_draw_line_thick(img, cx - 55, base_y - 50 + arm_raise, cx - 60, base_y - 30 + arm_raise, 8, ice_dark)
	_fill_circle(img, cx - 62, base_y - 28 + arm_raise, 8, ice_dark)
	# Right arm
	_draw_line_thick(img, cx + 38, base_y - 75, cx + 55, base_y - 50 + arm_raise, 10, ice_blue)
	_draw_line_thick(img, cx + 55, base_y - 50 + arm_raise, cx + 60, base_y - 30 + arm_raise, 8, ice_dark)
	_fill_circle(img, cx + 62, base_y - 28 + arm_raise, 8, ice_dark)

	# Head — smaller than body
	_fill_ellipse(img, cx, base_y - 105, 18, 20, ice_blue)
	# Brow ridge
	_fill_ellipse(img, cx, base_y - 112, 20, 8, ice_dark)

	# Eyes — icy white
	_fill_ellipse(img, cx - 7, base_y - 108, 4, 5, Color.WHITE)
	_fill_ellipse(img, cx + 7, base_y - 108, 4, 5, Color.WHITE)
	_fill_circle(img, cx - 7, base_y - 107, 2, Color(0.1, 0.3, 0.6, 1.0))
	_fill_circle(img, cx + 7, base_y - 107, 2, Color(0.1, 0.3, 0.6, 1.0))

	# Mouth
	_fill_ellipse(img, cx, base_y - 96, 8, 4, Color(0.15, 0.2, 0.35, 1.0))
	# Icy breath
	for i in range(5):
		var bx := cx + 12 + i * 6
		var by := base_y - 96 + int(sin(float(i)) * 3.0)
		_fill_circle_blend(img, bx, by, 4 - i / 2, Color(0.8, 0.9, 1.0, 0.3 - float(i) * 0.05))

	# Ice crystals on shoulders
	_fill_triangle(img, Vector2i(cx - 35, base_y - 85), Vector2i(cx - 28, base_y - 85), Vector2i(cx - 32, base_y - 105), crystal)
	_fill_triangle(img, Vector2i(cx - 40, base_y - 80), Vector2i(cx - 34, base_y - 78), Vector2i(cx - 38, base_y - 98), crystal)
	_fill_triangle(img, Vector2i(cx + 28, base_y - 85), Vector2i(cx + 35, base_y - 85), Vector2i(cx + 32, base_y - 105), crystal)
	_fill_triangle(img, Vector2i(cx + 34, base_y - 78), Vector2i(cx + 40, base_y - 80), Vector2i(cx + 38, base_y - 98), crystal)

	# Ice crystal on head
	_fill_triangle(img, Vector2i(cx - 5, base_y - 125), Vector2i(cx + 5, base_y - 125), Vector2i(cx, base_y - 145), crystal)

func _generate_frost_giant() -> void:
	print("Generating: frost_giant")
	var idle := _create_image()
	_draw_frost_giant(idle)
	_add_outline(idle, Color(0.1, 0.2, 0.35, 0.7))
	_add_shadow(idle)
	_save(idle, "res://assets/img/monsters/frost_giant_idle.png")

	var attack := _create_image()
	_draw_frost_giant(attack, 12, -8, true)
	_add_outline(attack, Color(0.1, 0.2, 0.35, 0.7))
	_save(attack, "res://assets/img/monsters/frost_giant_attack.png")

	var hit := _create_image()
	_draw_frost_giant(hit, -8, 5)
	_tint_image(hit, Color(0.6, 0.8, 1.0), 0.15)
	# Draw ice crack lines
	_draw_line_thick(hit, 115, 160, 100, 185, 2, Color(0.4, 0.6, 0.9, 0.7))
	_draw_line_thick(hit, 100, 185, 110, 200, 1, Color(0.4, 0.6, 0.9, 0.5))
	_draw_line_thick(hit, 140, 155, 150, 175, 2, Color(0.4, 0.6, 0.9, 0.7))
	_add_outline(hit, Color(0.1, 0.2, 0.35, 0.7))
	_save(hit, "res://assets/img/monsters/frost_giant_hit.png")


# ===========================================================================
#  9. DEATH KNIGHT (死灵骑士)
# ===========================================================================
func _draw_death_knight(img: Image, offset_x: int = 0, offset_y: int = 0, cleave: bool = false) -> void:
	var cx := 128 + offset_x
	var base_y := 230 + offset_y
	var armor := Color(0.15, 0.12, 0.18, 1.0)
	var armor_edge := Color(0.25, 0.22, 0.28, 1.0)
	var armor_highlight := Color(0.35, 0.3, 0.38, 0.6)
	var green_glow := Color(0.1, 0.9, 0.2, 0.9)

	# Ground shadow
	_fill_ellipse(img, cx, base_y + 5, 35, 7, Color(0.05, 0.1, 0.05, 0.3))

	# Legs — armored
	_fill_rect_rounded(img, cx - 24, base_y - 35, 20, 40, 4, armor)
	_fill_rect_rounded(img, cx + 4, base_y - 35, 20, 40, 4, armor)
	# Knee guards
	_fill_ellipse(img, cx - 14, base_y - 18, 10, 7, armor_edge)
	_fill_ellipse(img, cx + 14, base_y - 18, 10, 7, armor_edge)
	# Boots
	_fill_rect_rounded(img, cx - 26, base_y, 22, 10, 3, armor)
	_fill_rect_rounded(img, cx + 4, base_y, 22, 10, 3, armor)

	# Torso — heavy armor
	_fill_rect_rounded(img, cx - 30, base_y - 90, 60, 60, 6, armor)
	# Chest plate highlight
	_fill_ellipse(img, cx, base_y - 65, 22, 20, armor_highlight)
	# Armor lines
	_draw_line_thick(img, cx, base_y - 85, cx, base_y - 40, 2, armor_edge)
	_draw_line_thick(img, cx - 25, base_y - 60, cx + 25, base_y - 60, 1, armor_edge)

	# Shoulder pauldrons
	_fill_ellipse(img, cx - 35, base_y - 85, 18, 12, armor)
	_fill_ellipse(img, cx + 35, base_y - 85, 18, 12, armor)
	# Spikes on shoulders
	_fill_triangle(img, Vector2i(cx - 42, base_y - 90), Vector2i(cx - 35, base_y - 90), Vector2i(cx - 38, base_y - 108), armor_edge)
	_fill_triangle(img, Vector2i(cx + 35, base_y - 90), Vector2i(cx + 42, base_y - 90), Vector2i(cx + 38, base_y - 108), armor_edge)

	# Arms
	var sword_arm_offset := -25 if cleave else 0
	# Left arm
	_draw_line_thick(img, cx - 35, base_y - 80, cx - 48, base_y - 55, 7, armor)
	_fill_circle(img, cx - 50, base_y - 52, 6, armor_edge)
	# Right arm (sword arm)
	_draw_line_thick(img, cx + 35, base_y - 80, cx + 50, base_y - 60 + sword_arm_offset, 7, armor)
	_fill_circle(img, cx + 52, base_y - 58 + sword_arm_offset, 6, armor_edge)

	# Spectral sword
	var sword_base_x := cx + 52
	var sword_base_y := base_y - 58 + sword_arm_offset
	var sword_tip_x := sword_base_x + 15
	var sword_tip_y := sword_base_y - 55
	if cleave:
		sword_tip_x = sword_base_x + 30
		sword_tip_y = sword_base_y - 30
	# Sword glow
	_draw_line_thick(img, sword_base_x, sword_base_y, sword_tip_x, sword_tip_y, 5, Color(0.05, 0.4, 0.1, 0.5))
	# Sword blade
	_draw_line_thick(img, sword_base_x, sword_base_y, sword_tip_x, sword_tip_y, 3, Color(0.1, 0.8, 0.2, 0.8))
	_draw_line_thick(img, sword_base_x + 1, sword_base_y, sword_tip_x + 1, sword_tip_y, 1, Color(0.3, 1.0, 0.4, 0.6))
	# Crossguard
	_fill_rect(img, sword_base_x - 8, sword_base_y - 2, 16, 4, armor_edge)

	# Helmet
	_fill_ellipse(img, cx, base_y - 105, 18, 22, armor)
	# Visor slit
	_fill_rect(img, cx - 14, base_y - 108, 28, 5, Color(0.05, 0.05, 0.05, 1.0))
	# Green glowing eyes
	_fill_circle(img, cx - 7, base_y - 107, 3, green_glow)
	_fill_circle(img, cx + 7, base_y - 107, 3, green_glow)
	_fill_circle(img, cx - 7, base_y - 107, 1, Color(0.5, 1.0, 0.6, 1.0))
	_fill_circle(img, cx + 7, base_y - 107, 1, Color(0.5, 1.0, 0.6, 1.0))
	# Helmet crest
	_fill_triangle(img, Vector2i(cx - 5, base_y - 125), Vector2i(cx + 5, base_y - 125), Vector2i(cx, base_y - 145), armor_edge)

	# Green mist at base
	for i in range(5):
		var mx := cx - 30 + i * 15
		var my := base_y + int(sin(float(i) * 1.5) * 3.0)
		_fill_circle_blend(img, mx, my, 10, Color(0.1, 0.8, 0.2, 0.12))

func _generate_death_knight() -> void:
	print("Generating: death_knight")
	var idle := _create_image()
	_draw_death_knight(idle)
	_add_outline(idle)
	_add_shadow(idle)
	_save(idle, "res://assets/img/monsters/death_knight_idle.png")

	var attack := _create_image()
	_draw_death_knight(attack, 15, -5, true)
	_add_outline(attack)
	_save(attack, "res://assets/img/monsters/death_knight_attack.png")

	var hit := _create_image()
	_draw_death_knight(hit, -10, 3)
	_tint_image(hit, Color(1.0, 0.4, 0.3), 0.2)
	# Armor dent marks
	_fill_circle(hit, 125, 165, 4, Color(0.25, 0.22, 0.28, 0.8))
	_draw_line_thick(hit, 122, 162, 128, 168, 1, Color(0.4, 0.35, 0.42, 0.6))
	_add_outline(hit)
	_save(hit, "res://assets/img/monsters/death_knight_hit.png")


# ===========================================================================
#  10. ANCIENT DRAGON (远古巨龙) — BOSS 384x384
# ===========================================================================
func _draw_ancient_dragon(img: Image, offset_x: int = 0, offset_y: int = 0, breathing_fire: bool = false) -> void:
	var cx := 192 + offset_x
	var base_y := 340 + offset_y
	var red := Color(0.7, 0.15, 0.08, 1.0)
	var red_dark := Color(0.45, 0.08, 0.04, 1.0)
	var gold := Color(0.85, 0.7, 0.2, 1.0)
	var gold_dark := Color(0.65, 0.5, 0.1, 1.0)
	var belly := Color(0.9, 0.75, 0.3, 1.0)

	# Ground shadow
	_fill_ellipse(img, cx, base_y + 10, 80, 12, Color(0.1, 0.05, 0.0, 0.3))

	# Tail (behind body, curving right)
	for i in range(25):
		var t := float(i) / 25.0
		var tx := cx + 50 + int(t * 80.0)
		var ty := base_y - 30 + int(sin(t * 3.0) * 20.0)
		var tr := int(lerpf(12.0, 3.0, t))
		_fill_circle(img, tx, ty, tr, red_dark)
	# Tail tip (spade)
	_fill_triangle(img, Vector2i(cx + 125, base_y - 25), Vector2i(cx + 140, base_y - 40), Vector2i(cx + 145, base_y - 15), red)

	# Wings (large, spread behind)
	# Left wing
	_fill_triangle(img, Vector2i(cx - 30, base_y - 120), Vector2i(cx - 150, base_y - 200), Vector2i(cx - 120, base_y - 60), red_dark)
	_fill_triangle(img, Vector2i(cx - 30, base_y - 100), Vector2i(cx - 130, base_y - 170), Vector2i(cx - 100, base_y - 55), Color(0.55, 0.1, 0.05, 0.7))
	# Wing membrane lines
	_draw_line_thick(img, cx - 30, base_y - 120, cx - 140, base_y - 180, 2, red)
	_draw_line_thick(img, cx - 30, base_y - 110, cx - 135, base_y - 140, 2, red)
	_draw_line_thick(img, cx - 30, base_y - 100, cx - 120, base_y - 100, 2, red)

	# Right wing
	_fill_triangle(img, Vector2i(cx + 30, base_y - 120), Vector2i(cx + 150, base_y - 200), Vector2i(cx + 120, base_y - 60), red_dark)
	_fill_triangle(img, Vector2i(cx + 30, base_y - 100), Vector2i(cx + 130, base_y - 170), Vector2i(cx + 100, base_y - 55), Color(0.55, 0.1, 0.05, 0.7))
	_draw_line_thick(img, cx + 30, base_y - 120, cx + 140, base_y - 180, 2, red)
	_draw_line_thick(img, cx + 30, base_y - 110, cx + 135, base_y - 140, 2, red)
	_draw_line_thick(img, cx + 30, base_y - 100, cx + 120, base_y - 100, 2, red)

	# Legs — thick and powerful
	# Left leg
	_fill_rect_rounded(img, cx - 45, base_y - 30, 25, 35, 6, red_dark)
	_fill_ellipse(img, cx - 33, base_y + 5, 18, 8, red_dark)
	# Claws
	_fill_triangle(img, Vector2i(cx - 48, base_y + 5), Vector2i(cx - 45, base_y), Vector2i(cx - 52, base_y + 12), gold_dark)
	_fill_triangle(img, Vector2i(cx - 38, base_y + 8), Vector2i(cx - 35, base_y + 3), Vector2i(cx - 40, base_y + 15), gold_dark)
	_fill_triangle(img, Vector2i(cx - 28, base_y + 6), Vector2i(cx - 25, base_y + 1), Vector2i(cx - 30, base_y + 13), gold_dark)

	# Right leg
	_fill_rect_rounded(img, cx + 20, base_y - 30, 25, 35, 6, red_dark)
	_fill_ellipse(img, cx + 33, base_y + 5, 18, 8, red_dark)
	_fill_triangle(img, Vector2i(cx + 28, base_y + 5), Vector2i(cx + 25, base_y), Vector2i(cx + 22, base_y + 12), gold_dark)
	_fill_triangle(img, Vector2i(cx + 38, base_y + 8), Vector2i(cx + 35, base_y + 3), Vector2i(cx + 32, base_y + 15), gold_dark)
	_fill_triangle(img, Vector2i(cx + 48, base_y + 6), Vector2i(cx + 45, base_y + 1), Vector2i(cx + 42, base_y + 13), gold_dark)

	# Body — massive
	_fill_ellipse(img, cx, base_y - 60, 50, 45, red)
	# Belly (lighter)
	_fill_ellipse(img, cx, base_y - 50, 30, 30, belly)
	# Belly scales
	for i in range(4):
		var sy := base_y - 70 + i * 14
		_fill_ellipse(img, cx, sy, 25 - i * 3, 5, gold_dark)

	# Neck (long, curving up)
	for i in range(15):
		var t := float(i) / 15.0
		var nx := cx - int(t * 20.0)
		var ny := base_y - 100 - int(t * 70.0)
		var nr := int(lerpf(22.0, 14.0, t))
		_fill_circle(img, nx, ny, nr, red)
		# Neck underside
		_fill_circle(img, nx + 2, ny + int(float(nr) * 0.4), nr - 5, belly)

	# Head
	var head_x := cx - 20
	var head_y := base_y - 180
	_fill_ellipse(img, head_x, head_y, 22, 16, red)
	# Snout
	_fill_ellipse(img, head_x - 18, head_y + 2, 15, 10, red)
	# Lower jaw
	_fill_ellipse(img, head_x - 15, head_y + 8, 12, 6, red_dark)

	# Horns
	_fill_triangle(img, Vector2i(head_x - 5, head_y - 14), Vector2i(head_x + 5, head_y - 14), Vector2i(head_x - 15, head_y - 38), gold)
	_fill_triangle(img, Vector2i(head_x + 8, head_y - 12), Vector2i(head_x + 16, head_y - 12), Vector2i(head_x + 25, head_y - 35), gold)

	# Eyes — fierce yellow/orange
	_fill_ellipse(img, head_x - 5, head_y - 5, 5, 4, Color(1.0, 0.8, 0.0, 1.0))
	_fill_ellipse(img, head_x + 10, head_y - 5, 5, 4, Color(1.0, 0.8, 0.0, 1.0))
	# Slit pupils
	_fill_rect(img, head_x - 6, head_y - 7, 2, 5, Color(0.1, 0.0, 0.0, 1.0))
	_fill_rect(img, head_x + 9, head_y - 7, 2, 5, Color(0.1, 0.0, 0.0, 1.0))

	# Nostrils
	_fill_circle(img, head_x - 28, head_y, 3, Color(0.2, 0.05, 0.02, 1.0))
	_fill_circle(img, head_x - 28, head_y + 5, 3, Color(0.2, 0.05, 0.02, 1.0))

	# Teeth
	for i in range(6):
		var tooth_x := head_x - 25 + i * 5
		_fill_triangle(img, Vector2i(tooth_x - 1, head_y + 5), Vector2i(tooth_x + 2, head_y + 5), Vector2i(tooth_x, head_y + 13), Color(0.95, 0.9, 0.8, 1.0))

	# Spines along back
	for i in range(8):
		var t := float(i) / 8.0
		var sx := cx + 15 - int(t * 35.0)
		var sy := base_y - 95 - int(t * 75.0)
		var sh := 12 - i
		if sh > 3:
			_fill_triangle(img, Vector2i(sx - 3, sy), Vector2i(sx + 3, sy), Vector2i(sx, sy - sh), gold)

	# Fire breath (if attacking)
	if breathing_fire:
		for i in range(15):
			var t := float(i) / 15.0
			var fx := head_x - 30 - int(t * 60.0)
			var fy := head_y + 5 + int(sin(t * 4.0) * (10.0 + t * 15.0))
			var fr := int(lerpf(8.0, 18.0, t))
			var fire_alpha := 0.8 - t * 0.4
			_fill_circle_blend(img, fx, fy, fr, Color(1.0, 0.5 - t * 0.3, 0.0, fire_alpha))
			if fr > 4:
				_fill_circle_blend(img, fx, fy, fr - 3, Color(1.0, 0.8, 0.2, fire_alpha * 0.7))

func _generate_ancient_dragon() -> void:
	print("Generating: ancient_dragon (384x384 BOSS)")
	var size := 384
	var idle := Image.create(size, size, false, Image.FORMAT_RGBA8)
	_draw_ancient_dragon(idle)
	_add_outline(idle, Color(0.05, 0.02, 0.0, 0.8), 3)
	_add_shadow(idle, 4, 6)
	_save(idle, "res://assets/img/monsters/ancient_dragon_idle.png")

	var attack := Image.create(size, size, false, Image.FORMAT_RGBA8)
	_draw_ancient_dragon(attack, 15, -8, true)
	_add_outline(attack, Color(0.05, 0.02, 0.0, 0.8), 3)
	_save(attack, "res://assets/img/monsters/ancient_dragon_attack.png")

	var hit := Image.create(size, size, false, Image.FORMAT_RGBA8)
	_draw_ancient_dragon(hit, -12, 5)
	_tint_image(hit, Color(1.0, 0.4, 0.3), 0.2)
	_add_outline(hit, Color(0.05, 0.02, 0.0, 0.8), 3)
	_save(hit, "res://assets/img/monsters/ancient_dragon_hit.png")
