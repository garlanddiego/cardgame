extends Area2D
## res://scripts/card.gd — Professional card class inspired by db0/godot-card-game-framework
## State-machine driven Area2D card with tween-based animations
## Now uses STS card images instead of individual frame/art/label components

signal card_clicked(card_node: Area2D)
signal card_focused(card_node: Area2D)
signal card_unfocused(card_node: Area2D)
signal card_drag_started(card_node: Area2D)
signal card_drag_ended(card_node: Area2D, release_position: Vector2)

enum CardState {
	IN_HAND,
	FOCUSED_IN_HAND,
	DRAGGED,
	DROPPING_TO_BOARD,
	ON_PLAY_BOARD,
	IN_PILE,
	MOVING_TO_CONTAINER
}

const CARD_SIZE := Vector2(260, 350)

var card_data: Dictionary = {}
var card_state: int = CardState.IN_HAND
var is_hovered: bool = false
var is_selected: bool = false
var base_z_index: int = 0
var _current_tween: Tween = null

# Drag-to-target state
var _is_pressed: bool = false
var _press_time: float = 0.0
var _drag_active: bool = false
var _press_start_pos: Vector2 = Vector2.ZERO
const DRAG_HOLD_TIME: float = 0.2  # 200ms hold to start drag
const DRAG_DISTANCE_THRESHOLD: float = 15.0  # pixels moved to start drag immediately

# Child node references (populated in _ready or after build)
var collision_shape: CollisionShape2D = null
var card_visual: Control = null
var sts_card_image: TextureRect = null  # Single STS card image

# STS card image mapping (shared from deck_builder approach)
static var _sts_card_map: Dictionary = {}

static func _build_sts_card_map() -> void:
	if _sts_card_map.size() > 0:
		return
	var ordered_ids: Array = [
		# ATTACKS (type 0) — sorted by name
		"ic_anger", "ic_bash", "ic_blood_for_blood", "ic_bludgeon", "ic_body_slam",
		"ic_carnage", "ic_clash", "ic_cleave", "ic_clothesline", "ic_dropkick",
		"ic_feed", "ic_fiend_fire", "ic_headbutt", "ic_heavy_blade", "ic_hemokinesis",
		"ic_immolate", "ic_iron_wave", "ic_perfected_strike",
		"ic_pommel_strike", "ic_pummel", "ic_rampage", "ic_reaper", "ic_reckless_charge",
		"ic_searing_blow", "ic_sever_soul", "ic_strike", "ic_sword_boomerang",
		"ic_thunderclap", "ic_twin_strike", "ic_uppercut", "ic_whirlwind", "ic_wild_strike",
		# SKILLS (type 1) — sorted by name
		"ic_armaments", "ic_battle_trance", "ic_bloodletting", "ic_burning_pact",
		"ic_defend", "ic_disarm", "ic_double_tap", "ic_dual_wield", "ic_entrench",
		"ic_exhume", "ic_flame_barrier", "ic_flex", "ic_ghostly_armor", "ic_havoc",
		"ic_impervious", "ic_infernal_blade", "ic_intimidate", "ic_limit_break",
		"ic_offering", "ic_power_through", "ic_second_wind", "ic_seeing_red",
		"ic_sentinel", "ic_shockwave", "ic_shrug_it_off", "ic_spot_weakness",
		"ic_true_grit", "ic_war_cry",
		# POWERS (type 2) — sorted by name
		"ic_barricade", "ic_berserk", "ic_brutality", "ic_combust", "ic_corruption",
		"ic_dark_embrace", "ic_demon_form", "ic_evolve", "ic_feel_no_pain",
		"ic_fire_breathing", "ic_inflame", "ic_juggernaut", "ic_metallicize",
		"ic_rage", "ic_rupture",
	]
	var page := 1
	var card_on_page := 1
	var cards_per_page := 18
	var max_page := 3  # Only pages 1-3 are base cards
	for card_id in ordered_ids:
		if page > max_page:
			break
		var img_path := "res://assets/img/sts_cards/page%d_card%02d.png" % [page, card_on_page]
		_sts_card_map[card_id] = img_path
		card_on_page += 1
		if card_on_page > cards_per_page:
			card_on_page = 1
			page += 1

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

	# Load the STS card image based on card ID
	if sts_card_image:
		var card_id: String = card_data.get("id", "")
		var sts_path: String = _get_sts_card_path(card_id)
		if sts_path != "" and ResourceLoader.exists(sts_path):
			sts_card_image.texture = load(sts_path)
		else:
			# Fallback: try loading frame texture for unknown cards
			_apply_fallback_texture()

func _apply_fallback_texture() -> void:
	# If no STS image found, show a colored background based on type
	if sts_card_image == null:
		return
	var card_type: int = card_data.get("type", 0)
	var frame_path: String
	var fallback_path: String
	match card_type:
		0:  # Attack
			frame_path = "res://assets/img/frame_attack_v2.png"
			fallback_path = "res://assets/img/card_frame_attack_clean.png"
		1:  # Skill
			frame_path = "res://assets/img/frame_skill_v2.png"
			fallback_path = "res://assets/img/card_frame_skill.png"
		2:  # Power
			frame_path = "res://assets/img/frame_power_v2.png"
			fallback_path = "res://assets/img/card_frame_power_clean.png"
		_:  # Status / other
			frame_path = "res://assets/img/frame_skill_v2.png"
			fallback_path = "res://assets/img/card_frame_skill.png"
	var tex = load(frame_path)
	if tex == null:
		tex = load(fallback_path)
	if tex:
		sts_card_image.texture = tex

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

# ---- Drag-to-target handling ----

func _process(delta: float) -> void:
	if _is_pressed and not _drag_active:
		_press_time += delta
		# Check if held long enough or moved far enough to start drag
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var dist: float = _press_start_pos.distance_to(mouse_pos)
		if _press_time >= DRAG_HOLD_TIME or dist >= DRAG_DISTANCE_THRESHOLD:
			_start_drag()
	if _drag_active:
		# Card follows mouse while dragging
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		position = mouse_pos - Vector2(CARD_SIZE.x / 2.0, CARD_SIZE.y / 2.0)

func _start_drag() -> void:
	_drag_active = true
	card_state = CardState.DRAGGED
	z_index = 200
	# Lift card slightly with scale
	scale = Vector2(1.15, 1.15)
	rotation_degrees = 0
	# Cancel any running move tween
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	card_drag_started.emit(self)

func _end_drag() -> void:
	var release_pos: Vector2 = get_viewport().get_mouse_position()
	_drag_active = false
	_is_pressed = false
	_press_time = 0.0
	card_state = CardState.IN_HAND
	card_drag_ended.emit(self, release_pos)

# ---- Signal handlers ----

func _on_mouse_entered() -> void:
	is_hovered = true
	card_focused.emit(self)

func _on_mouse_exited() -> void:
	is_hovered = false
	if not _drag_active and not _is_pressed:
		card_unfocused.emit(self)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_pressed = true
				_press_time = 0.0
				_press_start_pos = event.global_position
			elif not event.pressed:
				if _drag_active:
					_end_drag()
				elif _is_pressed:
					# Quick tap — released before drag threshold
					_is_pressed = false
					_press_time = 0.0
					card_clicked.emit(self)

func _input(event: InputEvent) -> void:
	# Catch mouse release even if outside card area during drag
	if _drag_active and event is InputEventMouseButton:
		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_end_drag()

func _get_loc() -> Node:
	if not is_inside_tree():
		return null
	for child in get_tree().root.get_children():
		if child.name == "Loc":
			return child
	return null
