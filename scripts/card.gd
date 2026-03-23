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

const CARD_SIZE := Vector2(320, 430)

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

	# Always use AI-generated frame + art
	_apply_fallback_texture()

func _apply_fallback_texture() -> void:
	## STS card: frame texture + art overlay + text labels
	if card_visual == null:
		return
	if sts_card_image:
		sts_card_image.visible = false

	var card_type: int = card_data.get("type", 0)
	var frame_path: String
	var border_color: Color
	var type_name: String
	match card_type:
		0:  frame_path = "res://assets/img/card_frame_attack_sts.png"; border_color = Color(0.8, 0.2, 0.2); type_name = "攻击"
		1:  frame_path = "res://assets/img/card_frame_skill_sts.png"; border_color = Color(0.2, 0.7, 0.3); type_name = "技能"
		2:  frame_path = "res://assets/img/card_frame_power_sts.png"; border_color = Color(0.5, 0.3, 0.9); type_name = "能力"
		_:  frame_path = "res://assets/img/card_frame_skill_sts.png"; border_color = Color(0.5, 0.5, 0.5); type_name = "状态"

	var W: float = CARD_SIZE.x  # 320
	var H: float = CARD_SIZE.y  # 430

	# Hide default background
	var card_bg = card_visual.get_node_or_null("CardBackground") as ColorRect
	if card_bg:
		card_bg.visible = false

	# === FRAME TEXTURE (full card size, decorative border) ===
	if ResourceLoader.exists(frame_path):
		var frame_img = TextureRect.new()
		frame_img.name = "CardFrame"
		frame_img.size = CARD_SIZE
		frame_img.texture = load(frame_path)
		frame_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame_img.stretch_mode = TextureRect.STRETCH_SCALE
		frame_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_visual.add_child(frame_img)

	# === ART IMAGE (inside the frame's art area) ===
	# Art area on frame: approximately x:24-296 y:50-240 (272x190)
	var art_x: float = 24.0
	var art_y: float = 50.0
	var art_w: float = W - 48.0  # 272
	var art_h: float = 190.0
	var card_id: String = card_data.get("id", "")
	var art_path: String = "res://assets/img/card_art/" + card_id + ".png"
	if ResourceLoader.exists(art_path):
		var art_img = TextureRect.new()
		art_img.name = "CardArt"
		art_img.position = Vector2(art_x, art_y)
		art_img.size = Vector2(art_w, art_h)
		art_img.texture = load(art_path)
		art_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_img.stretch_mode = TextureRect.STRETCH_SCALE
		art_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_visual.add_child(art_img)

	# === COST (top-left, on the energy gem) ===
	var cost_val: int = card_data.get("cost", 0)
	var cost_lbl = Label.new()
	cost_lbl.name = "FallbackCost"
	cost_lbl.text = str(cost_val) if cost_val >= 0 else "X"
	cost_lbl.position = Vector2(10, 6)
	cost_lbl.size = Vector2(30, 30)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 18)
	cost_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_lbl.z_index = 5
	card_visual.add_child(cost_lbl)

	# === NAME (on the banner scroll at top) ===
	var loc = _get_loc()
	var card_name: String = card_data.get("name", "???")
	if loc and loc.has_method("card_name"):
		card_name = loc.card_name(card_data)
	var name_lbl = Label.new()
	name_lbl.name = "FallbackName"
	name_lbl.text = card_name
	name_lbl.position = Vector2(40, 8)
	name_lbl.size = Vector2(W - 50, 32)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.z_index = 5
	card_visual.add_child(name_lbl)

	# === TYPE TAG (below art, on the type divider) ===
	var type_lbl = Label.new()
	type_lbl.name = "FallbackType"
	type_lbl.text = type_name
	type_lbl.position = Vector2(0, 245)
	type_lbl.size = Vector2(W, 20)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.add_theme_font_size_override("font_size", 11)
	type_lbl.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	type_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	type_lbl.z_index = 5
	card_visual.add_child(type_lbl)

	# === DESCRIPTION (bottom area, inside the description frame) ===
	var desc_y: float = 270.0
	var dmg: int = card_data.get("damage", 0)
	var blk: int = card_data.get("block", 0)
	var stat_text: String = ""
	if dmg > 0 and blk > 0:
		stat_text = "⚔ %d   🛡 %d" % [dmg, blk]
	elif dmg > 0:
		stat_text = "⚔ %d" % dmg
	elif blk > 0:
		stat_text = "🛡 %d" % blk
	if stat_text != "":
		var stat_lbl = Label.new()
		stat_lbl.name = "FallbackStats"
		stat_lbl.text = stat_text
		stat_lbl.position = Vector2(10, 140)
		stat_lbl.size = Vector2(CARD_SIZE.x - 20, 50)
		stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_lbl.add_theme_font_size_override("font_size", 32)
		stat_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		stat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_visual.add_child(stat_lbl)

	# Description text (bottom half)
	var desc: String = card_data.get("description", "")
	if loc and loc.has_method("card_desc"):
		desc = loc.card_desc(card_data)
	if desc != "":
		var desc_lbl = Label.new()
		desc_lbl.name = "FallbackDesc"
		desc_lbl.text = desc
		desc_lbl.position = Vector2(16, 210)
		desc_lbl.size = Vector2(CARD_SIZE.x - 32, CARD_SIZE.y - 230)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 14)
		desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_visual.add_child(desc_lbl)

func set_selected(selected: bool) -> void:
	is_selected = selected
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
	if not _is_pressed:
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
