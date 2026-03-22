extends Control
## res://scripts/card_hand.gd — Fan layout of cards, hover zoom, two-step targeting

signal card_played(card_data: Dictionary, target: Node2D)

var cards: Array = []
var selected_card: Control = null
var hovered_card: Control = null
var targeting_mode: bool = false

var card_scene: PackedScene = null

# Layout constants
const CARD_WIDTH: float = 120.0
const CARD_HEIGHT: float = 180.0
const CARD_OVERLAP: float = 70.0  # Cards overlap by this many pixels
const HOVER_LIFT: float = -60.0  # How far up the card moves on hover
const HOVER_SPREAD: float = 40.0  # How far neighbors spread on hover
const MAX_ROTATION: float = 12.0
const ARC_HEIGHT: float = 20.0

func _ready() -> void:
	card_scene = load("res://scenes/card_ui.tscn")

func add_card(card_data: Dictionary) -> void:
	if card_scene == null:
		return
	var card = card_scene.instantiate()
	card.card_data = card_data
	add_child(card)
	cards.append(card)
	card.card_clicked.connect(_on_card_clicked)
	card.card_hovered.connect(_on_card_hovered)
	card.card_unhovered.connect(_on_card_unhovered)
	update_layout()

func remove_card(card_node: Control) -> void:
	if card_node in cards:
		cards.erase(card_node)
		card_node.queue_free()
		if selected_card == card_node:
			selected_card = null
			targeting_mode = false
		update_layout()

func clear_hand() -> void:
	for card in cards:
		if is_instance_valid(card):
			card.queue_free()
	cards.clear()
	selected_card = null
	targeting_mode = false

func update_layout() -> void:
	if cards.is_empty():
		return
	var card_count: int = cards.size()
	# Cards overlap: each card takes CARD_WIDTH - CARD_OVERLAP horizontal space
	var step: float = CARD_WIDTH - CARD_OVERLAP
	var total_width: float = step * (card_count - 1) + CARD_WIDTH
	var start_x: float = (1920.0 - total_width) / 2.0
	var base_y: float = 50.0

	var hovered_index: int = -1
	if hovered_card != null and hovered_card in cards:
		hovered_index = cards.find(hovered_card)

	for i in range(card_count):
		var card = cards[i]
		if not is_instance_valid(card):
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

		# Animate smoothly
		var tween = card.create_tween()
		tween.set_parallel(true)
		tween.tween_property(card, "position", target_pos, 0.12)
		tween.tween_property(card, "rotation_degrees", target_rot, 0.12)
		tween.tween_property(card, "scale", target_scale, 0.12)

		card.z_index = i
		card.base_z_index = i
		card.pivot_offset = Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT)

		if card == hovered_card:
			card.z_index = 100

func _on_card_clicked(card_node: Control) -> void:
	if targeting_mode and selected_card == card_node:
		# Deselect
		card_node.set_selected(false)
		selected_card = null
		targeting_mode = false
		return
	if targeting_mode and selected_card != null:
		selected_card.set_selected(false)
	selected_card = card_node
	card_node.set_selected(true)
	targeting_mode = true

func _on_card_hovered(card_node: Control) -> void:
	hovered_card = card_node
	update_layout()

func _on_card_unhovered(card_node: Control) -> void:
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

func _do_play(data: Dictionary, target: Node2D) -> void:
	var card_node = selected_card
	selected_card = null
	targeting_mode = false
	remove_card(card_node)
	card_played.emit(data, target)

func get_selected_card_data() -> Dictionary:
	if selected_card != null:
		return selected_card.card_data
	return {}

func is_targeting() -> bool:
	return targeting_mode
