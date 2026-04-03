extends Area2D
## res://scripts/card.gd — Professional card class inspired by db0/godot-card-game-framework
## State-machine driven Area2D card with tween-based animations
## Now uses STS card images instead of individual frame/art/label components

signal card_clicked(card_node: Area2D)
signal card_focused(card_node: Area2D)
signal card_unfocused(card_node: Area2D)
signal card_long_pressed(card_node: Area2D)
signal card_drag_started(card_node: Area2D)
signal card_drag_ended(card_node: Area2D, release_position: Vector2)

enum CardState {
	IN_HAND,
	FOCUSED_IN_HAND,
	SELECTED,
	DROPPING_TO_BOARD,
	ON_PLAY_BOARD,
	IN_PILE,
	MOVING_TO_CONTAINER
}

const CARD_SIZE := Vector2(296, 422)  # width 296, height reduced 15%

var card_data: Dictionary = {}
var card_state: int = CardState.IN_HAND
var is_hovered: bool = false
var is_selected: bool = false
var base_z_index: int = 0
var _current_tween: Tween = null

# Tap and long-press detection
var _is_pressed: bool = false
var _press_time: float = 0.0
var _press_start_pos: Vector2 = Vector2.ZERO
var _long_press_fired: bool = false
var _is_dragging: bool = false
const LONG_PRESS_TIME: float = 0.5  # 500ms for long press (card detail)
const TAP_MOVE_THRESHOLD: float = 15.0  # Max movement for a tap
const DRAG_TIME_THRESHOLD: float = 0.2  # 200ms hold to start drag
const DRAG_MOVE_THRESHOLD: float = 15.0  # 15px movement to start drag

# Child node references (populated in _ready or after build)
var collision_shape: CollisionShape2D = null
var card_visual: Control = null
var sts_card_image: TextureRect = null  # Single STS card image

# STS card image mapping (shared from deck_builder approach)
static var _sts_card_map: Dictionary = {}

static func _build_sts_card_map() -> void:
	if not _sts_card_map.is_empty():
		return
	# Direct mapping from card_id to image file, identified by reading Chinese card names
	# Pages 1-3 are base cards (54 total); pages 4-5 are upgraded versions
	var _base := "res://assets/img/sts_cards/"
	_sts_card_map = {
		# Page 1
		"ic_strike": _base + "page1_card01.png",
		"ic_infernal_blade": _base + "page1_card02.png",
		"ic_sentinel": _base + "page1_card03.png",
		"ic_dual_wield": _base + "page1_card04.png",
		"ic_blood_for_blood": _base + "page1_card05.png",
		"ic_sever_soul": _base + "page1_card06.png",
		"ic_fire_breathing": _base + "page1_card07.png",
		"ic_carnage": _base + "page1_card08.png",
		"ic_dark_embrace": _base + "page1_card09.png",
		"ic_intimidate": _base + "page1_card10.png",
		"ic_power_through": _base + "page1_card11.png",
		"ic_flame_barrier": _base + "page1_card12.png",
		"ic_bloodletting": _base + "page1_card13.png",
		"ic_rupture": _base + "page1_card14.png",
		"ic_battle_trance": _base + "page1_card15.png",
		"ic_hemokinesis": _base + "page1_card16.png",
		"ic_ghostly_armor": _base + "page1_card17.png",
		"ic_entrench": _base + "page1_card18.png",
		# Page 2
		"ic_rampage": _base + "page2_card01.png",
		"ic_corruption": _base + "page2_card02.png",
		"ic_demon_form": _base + "page2_card03.png",
		"ic_fiend_fire": _base + "page2_card04.png",
		"ic_berserk": _base + "page2_card05.png",
		"ic_limit_break": _base + "page2_card06.png",
		"ic_impervious": _base + "page2_card07.png",
		"ic_bludgeon": _base + "page2_card08.png",
		"ic_immolate": _base + "page2_card09.png",
		"ic_barricade": _base + "page2_card10.png",
		"ic_reckless_charge": _base + "page2_card11.png",
		"ic_whirlwind": _base + "page2_card12.png",
		"ic_feel_no_pain": _base + "page2_card13.png",
		"ic_reaper": _base + "page2_card14.png",
		"ic_brutality": _base + "page2_card15.png",
		"ic_exhume": _base + "page2_card16.png",
		"ic_offering": _base + "page2_card17.png",
		"ic_double_tap": _base + "page2_card18.png",
		# Page 3
		"ic_juggernaut": _base + "page3_card01.png",
		"ic_disarm": _base + "page3_card02.png",
		"ic_anger": _base + "page3_card03.png",
		"ic_war_cry": _base + "page3_card04.png",
		"ic_shrug_it_off": _base + "page3_card05.png",
		"ic_twin_strike": _base + "page3_card06.png",
		"ic_pommel_strike": _base + "page3_card07.png",
		"ic_sword_boomerang": _base + "page3_card08.png",
		"ic_cleave": _base + "page3_card09.png",
		"ic_flex": _base + "page3_card10.png",
		"ic_wild_strike": _base + "page3_card11.png",
		"ic_defend": _base + "page3_card12.png",
		"ic_bash": _base + "page3_card13.png",
		"ic_headbutt": _base + "page3_card14.png",
		"ic_perfected_strike": _base + "page3_card15.png",
		"ic_clothesline": _base + "page3_card16.png",
		"ic_havoc": _base + "page3_card17.png",
		"ic_heavy_blade": _base + "page3_card18.png",
	}

static func _get_sts_card_path(card_id: String) -> String:
	_build_sts_card_map()
	if _sts_card_map.has(card_id):
		return _sts_card_map[card_id]
	return ""

## Creates a reusable card visual Control at the given size.
## This is the SINGLE source of truth for card rendering.
## STS2-style: clean, minimal, programmatic — no frame images.
## Pass a Loc node if available for localized text; null otherwise.
static func create_card_visual(card: Dictionary, size: Vector2, loc: Node = null) -> Control:
	var BASE_W: float = 320.0
	var BASE_H: float = 430.0
	var sx: float = size.x / BASE_W
	var sy: float = size.y / BASE_H

	# Character-based colors (STS2 style)
	var character: String = card.get("character", "ironclad")
	var bg_color: Color
	var border_color: Color
	match character:
		"silent":
			bg_color = Color(0.1, 0.22, 0.12, 1.0)    # Dark green
			border_color = Color(0.2, 0.75, 0.25, 1.0)  # Bright green
		"neutral", "colorless":
			bg_color = Color(0.18, 0.18, 0.2, 1.0)      # Dark grey
			border_color = Color(0.5, 0.5, 0.55, 1.0)    # Grey
		_:  # ironclad / default
			bg_color = Color(0.28, 0.08, 0.08, 1.0)     # Dark red/maroon
			border_color = Color(0.85, 0.15, 0.15, 1.0)  # Bright red

	# Card type info
	var card_type: int = card.get("type", 0)
	var type_name: String
	var type_color: Color
	match card_type:
		0:  type_name = "攻击"; type_color = Color(0.85, 0.2, 0.2, 1.0)   # Red
		1:  type_name = "技能"; type_color = Color(0.25, 0.45, 0.85, 1.0)  # Blue
		2:  type_name = "能力"; type_color = Color(0.85, 0.7, 0.15, 1.0)   # Gold
		_:  type_name = "状态"; type_color = Color(0.5, 0.5, 0.5, 1.0)     # Grey

	var root = Control.new()
	root.name = "CardVisualRoot"
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- Layer 1: Card body with colored background + thick border + rounded corners ---
	var card_body = Panel.new()
	card_body.name = "CardBody"
	card_body.position = Vector2.ZERO
	card_body.size = size
	var body_style = StyleBoxFlat.new()
	body_style.bg_color = bg_color
	var corner_r: int = int(12.0 * sx)
	body_style.corner_radius_top_left = corner_r
	body_style.corner_radius_top_right = corner_r
	body_style.corner_radius_bottom_left = corner_r
	body_style.corner_radius_bottom_right = corner_r
	var border_w: int = int(4.0 * sx)
	body_style.border_width_left = border_w
	body_style.border_width_right = border_w
	body_style.border_width_top = border_w
	body_style.border_width_bottom = border_w
	body_style.border_color = border_color
	card_body.add_theme_stylebox_override("panel", body_style)
	card_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card_body)

	# --- Layer 2: Name banner (grey strip near top, above art) ---
	var banner_y: float = 18.0 * sy
	var banner_h: float = 30.0 * sy
	var banner_margin: float = 8.0 * sx
	var banner_bg = Panel.new()
	banner_bg.name = "NameBanner"
	banner_bg.position = Vector2(banner_margin, banner_y)
	banner_bg.size = Vector2(size.x - banner_margin * 2.0, banner_h)
	var banner_style = StyleBoxFlat.new()
	banner_style.bg_color = Color(0.55, 0.55, 0.58, 0.9)  # Silver/grey
	var banner_cr: int = int(4.0 * sx)
	banner_style.corner_radius_top_left = banner_cr
	banner_style.corner_radius_top_right = banner_cr
	banner_style.corner_radius_bottom_left = banner_cr
	banner_style.corner_radius_bottom_right = banner_cr
	banner_bg.add_theme_stylebox_override("panel", banner_style)
	banner_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_bg.z_index = 5
	root.add_child(banner_bg)

	var card_name: String = card.get("name", "???")
	if loc and loc.has_method("card_name"):
		card_name = loc.card_name(card)
	var name_lbl = Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = card_name
	name_lbl.position = Vector2(banner_margin + 24.0 * sx, banner_y)
	name_lbl.size = Vector2(size.x - banner_margin * 2.0 - 24.0 * sx, banner_h)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", int(28 * sx))  # Card name
	var name_color: Color = Color(0.2, 0.6, 0.2) if card.get("upgraded", false) else Color(1.0, 1.0, 1.0)
	name_lbl.add_theme_color_override("font_color", name_color)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.z_index = 6
	root.add_child(name_lbl)

	# --- Layer 3: Art area (top 55%, below banner) ---
	var art_margin: float = 8.0 * sx
	var art_top: float = banner_y + banner_h + 4.0 * sy
	var art_h: float = size.y * 0.55 - art_top + 8.0 * sy  # Fill to ~55%
	var art_w: float = size.x - art_margin * 2.0

	# Dark art placeholder area
	var art_bg = Panel.new()
	art_bg.name = "ArtBG"
	art_bg.position = Vector2(art_margin, art_top)
	art_bg.size = Vector2(art_w, art_h)
	var art_bg_style = StyleBoxFlat.new()
	art_bg_style.bg_color = Color(0.05, 0.05, 0.07, 1.0)  # Near-black
	var art_cr: int = int(6.0 * sx)
	art_bg_style.corner_radius_top_left = art_cr
	art_bg_style.corner_radius_top_right = art_cr
	art_bg_style.corner_radius_bottom_left = art_cr
	art_bg_style.corner_radius_bottom_right = art_cr
	art_bg.add_theme_stylebox_override("panel", art_bg_style)
	art_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_bg.z_index = 2
	root.add_child(art_bg)

	# Load art image if available — check card["art"] field first, then fallback
	var card_id: String = card.get("id", "")
	# Upgraded cards (id ends with "+") use same art as base card
	var art_card_id: String = card_id.trim_suffix("+")
	var art_path: String = card.get("art", "")
	if art_path.is_empty() or not ResourceLoader.exists(art_path):
		art_path = "res://assets/img/card_art/" + art_card_id + ".png"
	if ResourceLoader.exists(art_path):
		var art_clip = Control.new()
		art_clip.name = "ArtClip"
		art_clip.position = Vector2(art_margin, art_top)
		art_clip.size = Vector2(art_w, art_h)
		art_clip.clip_contents = true
		art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_clip.z_index = 3
		root.add_child(art_clip)
		var art_img = TextureRect.new()
		art_img.size = Vector2(art_w, art_h)
		art_img.texture = load(art_path)
		art_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_clip.add_child(art_img)

	# --- Layer 4: Type badge (small rounded rect, right side below art) ---
	var type_badge_w: float = 52.0 * sx
	var type_badge_h: float = 20.0 * sy
	var type_badge_x: float = (size.x - type_badge_w) / 2.0  # Centered
	var type_badge_y: float = art_top + art_h + 3.0 * sy  # Below art, moved down 7px
	var type_badge = Panel.new()
	type_badge.name = "TypeBadge"
	type_badge.position = Vector2(type_badge_x, type_badge_y)
	type_badge.size = Vector2(type_badge_w, type_badge_h)
	var type_style = StyleBoxFlat.new()
	type_style.bg_color = type_color
	var type_cr: int = int(4.0 * sx)
	type_style.corner_radius_top_left = type_cr
	type_style.corner_radius_top_right = type_cr
	type_style.corner_radius_bottom_left = type_cr
	type_style.corner_radius_bottom_right = type_cr
	type_badge.add_theme_stylebox_override("panel", type_style)
	type_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	type_badge.z_index = 7
	root.add_child(type_badge)

	var type_lbl = Label.new()
	type_lbl.name = "TypeLabel"
	type_lbl.text = type_name
	type_lbl.position = Vector2(type_badge_x, type_badge_y)
	type_lbl.size = Vector2(type_badge_w, type_badge_h)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	type_lbl.add_theme_font_size_override("font_size", int(12 * sx))
	type_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	type_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	type_lbl.z_index = 8
	root.add_child(type_lbl)

	# --- Layer 5: Description area (bottom ~35%) ---
	var desc_top: float = size.y * 0.55
	var desc_margin: float = 10.0 * sx
	var desc_w: float = size.x - desc_margin * 2.0
	var desc_h: float = size.y - desc_top - 10.0 * sy

	var desc_bg = Panel.new()
	desc_bg.name = "DescBG"
	desc_bg.position = Vector2(desc_margin, desc_top)
	desc_bg.size = Vector2(desc_w, desc_h)
	var desc_style = StyleBoxFlat.new()
	desc_style.bg_color = Color(0.0, 0.0, 0.0, 0.6)  # Semi-transparent dark
	var desc_cr: int = int(6.0 * sx)
	desc_style.corner_radius_top_left = desc_cr
	desc_style.corner_radius_top_right = desc_cr
	desc_style.corner_radius_bottom_left = desc_cr
	desc_style.corner_radius_bottom_right = desc_cr
	desc_bg.add_theme_stylebox_override("panel", desc_style)
	desc_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_bg.z_index = 4
	root.add_child(desc_bg)

	var desc: String = card.get("description", "")
	if loc and loc.has_method("card_desc"):
		desc = loc.card_desc(card)
	# Append hero target indicator for self-targeting cards
	var hero_tgt: String = card.get("hero_target", "")
	if hero_tgt != "" and card.get("target", "") == "self":
		var hero_char: String = card.get("character", "")
		if hero_tgt == "self":
			var hero_display: String = ""
			match hero_char:
				"ironclad": hero_display = "铁甲战士"
				"silent": hero_display = "沉默猎手"
			if hero_display != "":
				desc += "\n→ %s" % hero_display
		elif hero_tgt == "all_heroes":
			desc += "\n→ 所有英雄"
		elif hero_tgt == "target_hero":
			desc += "\n→ 选择英雄"
	if desc != "":
		var desc_lbl = Label.new()
		desc_lbl.name = "DescLabel"
		desc_lbl.text = desc
		desc_lbl.position = Vector2(desc_margin + 6.0 * sx, desc_top + 4.0 * sy)
		desc_lbl.size = Vector2(desc_w - 12.0 * sx, desc_h - 8.0 * sy)
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", int(22 * sx))  # Description text
		desc_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc_lbl.z_index = 5
		root.add_child(desc_lbl)

	# --- Layer 6: Cost circle (top-left, overlapping border) ---
	var cost_val: int = card.get("cost", 0)
	var orb_r: float = 27.0 * sx  # 50% bigger (was 18)
	var orb_cx: float = 6.0 * sx + orb_r  # Slightly inside left border
	var orb_cy: float = 6.0 * sy + orb_r  # Slightly inside top border

	var orb_bg = Panel.new()
	orb_bg.name = "CostOrbBG"
	orb_bg.position = Vector2(orb_cx - orb_r, orb_cy - orb_r)
	orb_bg.size = Vector2(orb_r * 2, orb_r * 2)
	var orb_style = StyleBoxFlat.new()
	orb_style.bg_color = Color(0.08, 0.08, 0.1, 0.85)  # Dark semi-transparent
	orb_style.corner_radius_top_left = int(orb_r)
	orb_style.corner_radius_top_right = int(orb_r)
	orb_style.corner_radius_bottom_left = int(orb_r)
	orb_style.corner_radius_bottom_right = int(orb_r)
	orb_style.border_width_left = int(2.0 * sx)
	orb_style.border_width_right = int(2.0 * sx)
	orb_style.border_width_top = int(2.0 * sx)
	orb_style.border_width_bottom = int(2.0 * sx)
	orb_style.border_color = border_color
	orb_bg.add_theme_stylebox_override("panel", orb_style)
	orb_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb_bg.z_index = 10
	root.add_child(orb_bg)

	var cost_lbl = Label.new()
	cost_lbl.name = "CostLabel"
	if cost_val >= 0:
		cost_lbl.text = str(cost_val)
	elif cost_val == -1:
		cost_lbl.text = "X"
	else:
		cost_lbl.text = ""  # Status/unplayable — prohibition icon shown by card_hand
	cost_lbl.position = Vector2(orb_cx - orb_r, orb_cy - orb_r)
	cost_lbl.size = Vector2(orb_r * 2, orb_r * 2)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", int(30 * sx))  # Bigger (was 22)
	cost_lbl.add_theme_color_override("font_color", Color(0.2, 0.85, 0.3))  # Green number
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_lbl.z_index = 11
	root.add_child(cost_lbl)

	return root

func _ready() -> void:
	# If no children exist yet, build them (for runtime instantiation)
	if get_child_count() == 0:
		_build_card_nodes()
	else:
		_find_child_refs()

	# Connect Area2D mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

	# Set up collision
	input_pickable = true

	if not card_data.is_empty():
		_apply_card_data()

func _build_card_nodes() -> void:
	# CollisionShape2D
	collision_shape = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	shape.size = CARD_SIZE
	collision_shape.shape = shape
	collision_shape.position = Vector2(CARD_SIZE.x / 2.0, CARD_SIZE.y / 2.0)
	add_child(collision_shape)

	# CardVisual (Control) — all visual elements are children of this
	card_visual = Control.new()
	card_visual.name = "CardVisual"
	card_visual.size = CARD_SIZE
	card_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card_visual)

	# Dark card background (visible if STS image is missing)
	var card_bg = ColorRect.new()
	card_bg.name = "CardBackground"
	card_bg.position = Vector2(0, 0)
	card_bg.size = CARD_SIZE
	card_bg.color = Color(0.08, 0.06, 0.04, 0.95)
	card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_visual.add_child(card_bg)

	# STS card image — complete card visual (frame + art + text baked in)
	sts_card_image = TextureRect.new()
	sts_card_image.name = "STSCardImage"
	sts_card_image.size = CARD_SIZE
	sts_card_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sts_card_image.stretch_mode = TextureRect.STRETCH_SCALE
	sts_card_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_visual.add_child(sts_card_image)

	# No selection glow overlay — cards show only the STS card image

func _find_child_refs() -> void:
	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	card_visual = get_node_or_null("CardVisual") as Control
	if card_visual:
		sts_card_image = card_visual.get_node_or_null("STSCardImage") as TextureRect

func setup(data: Dictionary) -> void:
	card_data = data
	if is_inside_tree():
		_apply_card_data()

func set_card_data(data: Dictionary) -> void:
	setup(data)

func _apply_card_data() -> void:
	if card_data.is_empty():
		return

	# Build STS2-style programmatic card visual
	_apply_fallback_texture()

func _apply_fallback_texture() -> void:
	## Delegates to the shared create_card_visual() static method
	if card_visual == null:
		return
	if sts_card_image:
		sts_card_image.visible = false

	var loc = _get_loc()
	var visual = create_card_visual(card_data, CARD_SIZE, loc)
	# Reparent all children from the generated visual into card_visual
	var children_to_move: Array = []
	for child in visual.get_children():
		children_to_move.append(child)
	for child in children_to_move:
		visual.remove_child(child)
		card_visual.add_child(child)
	visual.queue_free()

func set_selected(selected: bool) -> void:
	is_selected = selected
	# Disable input_pickable when selected to prevent jitter from mouse exit/enter loop
	# (card lifts → mouse exits Area2D → card drops → mouse enters → repeat)
	input_pickable = not selected
	if card_visual:
		if selected:
			# Slight golden tint when selected — no border overlay
			card_visual.modulate = Color(1.1, 1.0, 0.7, 1.0)
		else:
			card_visual.modulate = Color.WHITE

func move_to(target_pos: Vector2, target_rot: float, target_scale: Vector2, duration: float = 0.15) -> void:
	# Cancel any in-progress tween
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	_current_tween.set_ease(Tween.EASE_OUT)
	_current_tween.set_trans(Tween.TRANS_CUBIC)
	_current_tween.tween_property(self, "position", target_pos, duration)
	_current_tween.tween_property(self, "rotation_degrees", target_rot, duration)
	_current_tween.tween_property(self, "scale", target_scale, duration)

func set_state(new_state: int) -> void:
	card_state = new_state

# ---- Tap-to-select and long-press handling ----

func _process(delta: float) -> void:
	if _is_pressed and not _long_press_fired and not _is_dragging:
		_press_time += delta
		# Check if drag should start (time OR distance threshold)
		var current_mouse: Vector2 = get_viewport().get_mouse_position()
		var dist: float = _press_start_pos.distance_to(current_mouse)
		if _press_time >= DRAG_TIME_THRESHOLD or dist >= DRAG_MOVE_THRESHOLD:
			_is_dragging = true
			card_drag_started.emit(self)
		# Check for long press only if not dragging and finger hasn't moved
		elif _press_time >= LONG_PRESS_TIME and dist < TAP_MOVE_THRESHOLD:
			_long_press_fired = true
			_is_pressed = false
			_press_time = 0.0
			card_long_pressed.emit(self)
	# During drag, card stays in place — targeting arrow is shown by battle_manager
	# (no position update here)

# ---- Signal handlers ----

func _on_mouse_entered() -> void:
	is_hovered = true
	card_focused.emit(self)

func _on_mouse_exited() -> void:
	is_hovered = false
	if not _is_pressed and not is_selected:
		card_unfocused.emit(self)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_pressed = true
				_press_time = 0.0
				_long_press_fired = false
				_is_dragging = false
				_press_start_pos = event.global_position
			elif not event.pressed:
				if _is_dragging:
					# End drag — emit release position
					_is_dragging = false
					_is_pressed = false
					_press_time = 0.0
					card_drag_ended.emit(self, event.global_position)
				elif _is_pressed and not _long_press_fired:
					# Quick tap — check if finger moved too far
					var dist: float = _press_start_pos.distance_to(event.global_position)
					if dist < TAP_MOVE_THRESHOLD:
						card_clicked.emit(self)
				_is_pressed = false
				_press_time = 0.0

func _unhandled_input(event: InputEvent) -> void:
	# Catch mouse release outside the card area during drag
	if _is_dragging and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_is_dragging = false
			_is_pressed = false
			_press_time = 0.0
			card_drag_ended.emit(self, event.global_position)

func _get_loc() -> Node:
	if not is_inside_tree():
		return null
	for child in get_tree().root.get_children():
		if child.name == "Loc":
			return child
	return null
