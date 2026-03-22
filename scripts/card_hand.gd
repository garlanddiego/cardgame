extends Node2D
## res://scripts/card_hand.gd — Fan layout of Area2D cards, hover zoom, drag-to-target
## Refactored to use Area2D-based Card class with drag interaction

signal card_played(card_data: Dictionary, target: Node2D)

var cards: Array = []
var selected_card: Area2D = null
var hovered_card: Area2D = null
var targeting_mode: bool = false
var _dragging_card: Area2D = null
var _drag_origin_pos: Vector2 = Vector2.ZERO

var card_script: GDScript = null

# STS-style layout — matching card.gd CARD_SIZE (260x350)
const CARD_WIDTH: float = 260.0
const CARD_HEIGHT: float = 350.0
const CARD_OVERLAP: float = 30.0  # Slight edge overlap only (~30px)
const HOVER_LIFT: float = -100.0  # Card lifts well above hand
const HOVER_SPREAD: float = 40.0  # Neighbors spread on hover
const MAX_ROTATION: float = 8.0  # Fan arc
const ARC_HEIGHT: float = 20.0  # Gentle curve
const HAND_Y: float = 0.0

func _ready() -> void:
	card_script = load("res://scripts/card.gd")

func add_card(card_data: Dictionary) -> void:
	if card_script == null:
		return
	var card = Area2D.new()
	card.set_script(card_script)
	card.card_data = card_data
	add_child(card)
	cards.append(card)
	card.card_clicked.connect(_on_card_clicked)
	card.card_focused.connect(_on_card_hovered)
	card.card_unfocused.connect(_on_card_unhovered)
	card.card_drag_started.connect(_on_card_drag_started)
	card.card_drag_ended.connect(_on_card_drag_ended)
	update_layout()

func remove_card(card_node: Area2D) -> void:
	if card_node in cards:
		cards.erase(card_node)
		card_node.queue_free()
		if selected_card == card_node:
			selected_card = null
			targeting_mode = false
		if _dragging_card == card_node:
			_dragging_card = null
		update_layout()

func clear_hand() -> void:
	for card in cards:
		if is_instance_valid(card):
			card.queue_free()
	cards.clear()
	selected_card = null
	targeting_mode = false
	_dragging_card = null

func update_layout() -> void:
	if cards.is_empty():
		return
	var card_count: int = cards.size()
	# Cards overlap: each card takes CARD_WIDTH - CARD_OVERLAP horizontal space
	var step: float = CARD_WIDTH - CARD_OVERLAP
	var total_width: float = step * (card_count - 1) + CARD_WIDTH
	var start_x: float = (1920.0 - total_width) / 2.0
	var base_y: float = HAND_Y  # Cards positioned relative to this Node2D

	var hovered_index: int = -1
	if hovered_card != null and hovered_card in cards:
		hovered_index = cards.find(hovered_card)

	for i in range(card_count):
		var card = cards[i]
		if not is_instance_valid(card):
			continue
		# Skip layout update for card being dragged
		if card == _dragging_card:
			continue
		var t: float = 0.5
		if card_count > 1:
			t = float(i) / float(card_count - 1)

		var x_pos: float = start_x + i * step
		var arc_t: float = (t - 0.5) * 2.0
		var y_offset: float = ARC_HEIGHT * arc_t * arc_t
		var rot: float = -MAX_ROTATION + t * MAX_ROTATION * 2.0

		# Spread neighbors when a card is hovered
		if hovered_index >= 0 and i != hovered_index:
			if i < hovered_index:
				x_pos -= HOVER_SPREAD * (1.0 - float(hovered_index - i) / float(card_count))
			elif i > hovered_index:
				x_pos += HOVER_SPREAD * (1.0 - float(i - hovered_index) / float(card_count))

		var target_pos := Vector2(x_pos, base_y + y_offset)
		var target_rot := rot
		var target_scale := Vector2.ONE

		if card == hovered_card:
			target_pos.y += HOVER_LIFT
			target_rot = 0.0
			target_scale = Vector2(1.3, 1.3)

		# Use the card's move_to method for smooth animation
		card.move_to(target_pos, target_rot, target_scale, 0.12)

		card.z_index = i
		card.base_z_index = i

		if card == hovered_card:
			card.z_index = 100

# ---- Drag-to-target handlers ----

func _on_card_drag_started(card_node: Area2D) -> void:
	_dragging_card = card_node
	_drag_origin_pos = card_node.position
	# Visually indicate dragging
	card_node.set_selected(true)
	# Enter targeting mode so battle_manager shows arrow
	selected_card = card_node
	targeting_mode = true

func _on_card_drag_ended(card_node: Area2D, release_position: Vector2) -> void:
	if _dragging_card != card_node:
		return
	_dragging_card = null
	card_node.set_selected(false)

	# Check card target type for auto-play logic
	var card_data: Dictionary = card_node.card_data
	var target_type: String = card_data.get("target", "enemy")

	# For drag-to-target, we emit the release position info
	# The battle_manager will check if release is over an enemy
	# We signal with null target — battle_manager resolves the actual target
	# via _on_card_drag_release which is connected in battle_manager
	card_drag_released.emit(card_node, release_position)

	# Reset targeting state (battle_manager will handle play or snap-back)
	selected_card = null
	targeting_mode = false
	update_layout()

# Signal for battle_manager to handle drag release target resolution
signal card_drag_released(card_node: Area2D, release_position: Vector2)

func _on_card_clicked(card_node: Area2D) -> void:
	# Quick tap: for non-targeted cards (self/all_enemies), play immediately
	var card_data: Dictionary = card_node.card_data
	var target_type: String = card_data.get("target", "enemy")

	if target_type == "self" or target_type == "all_enemies":
		# Single tap plays non-targeted cards
		selected_card = card_node
		targeting_mode = true
		# Emit so battle_manager can auto-play
		card_played_tap.emit(card_node)
	else:
		# For targeted cards, quick tap does nothing (must drag)
		pass

# Signal for quick-tap on non-targeted cards
signal card_played_tap(card_node: Area2D)

func _on_card_hovered(card_node: Area2D) -> void:
	if _dragging_card != null:
		return  # Don't change hover during drag
	hovered_card = card_node
	update_layout()

func _on_card_unhovered(card_node: Area2D) -> void:
	if hovered_card == card_node:
		hovered_card = null
	update_layout()

func try_play_card_on_target(target: Node2D) -> bool:
	if not targeting_mode or selected_card == null:
		return false
	var data: Dictionary = selected_card.card_data
	var card_target: String = data.get("target", "enemy")
	if card_target == "self" and not target.is_enemy:
		_do_play(data, target)
		return true
	elif card_target == "enemy" and target.is_enemy:
		_do_play(data, target)
		return true
	elif card_target == "all_enemies":
		_do_play(data, target)
		return true
	return false

func play_selected_on(target: Node2D) -> void:
	if selected_card == null:
		return
	_do_play(selected_card.card_data, target)

func play_card_on(card_node: Area2D, target: Node2D) -> void:
	if card_node == null:
		return
	selected_card = card_node
	_do_play(card_node.card_data, target)

func _do_play(data: Dictionary, target: Node2D) -> void:
	var card_node = selected_card
	selected_card = null
	targeting_mode = false
	_dragging_card = null
	remove_card(card_node)
	card_played.emit(data, target)

func get_selected_card_data() -> Dictionary:
	if selected_card != null:
		return selected_card.card_data
	return {}

func is_targeting() -> bool:
	return targeting_mode
