extends Control
## res://scripts/card_hand.gd — Fan layout of cards, hover zoom, two-step targeting

signal card_played(card_data: Dictionary, target: Node2D)

var cards: Array = []
var selected_card: Control = null
var hovered_card: Control = null
var targeting_mode: bool = false

var card_scene: PackedScene = null

func _ready() -> void:
	card_scene = load("res://scenes/card_ui.tscn")

func add_card(card_data: Dictionary) -> void:
	if card_scene == null:
		return
	var card = card_scene.instantiate()
	card.card_data = card_data
	add_child(card)
	cards.append(card)
	# Connect signals
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
	var card_width: float = 120.0
	var card_height: float = 180.0
	# Fan parameters
	var total_width: float = mini(card_count * 130, 900) as float
	var start_x: float = (1920.0 - total_width) / 2.0
	var base_y: float = 40.0  # relative to card_hand position
	var max_rotation: float = 15.0
	var arc_height: float = 30.0

	for i in range(card_count):
		var card = cards[i]
		if not is_instance_valid(card):
			continue
		var t: float = 0.5
		if card_count > 1:
			t = float(i) / float(card_count - 1)
		# Position along arc
		var x_pos: float = start_x + t * total_width - card_width / 2.0
		var arc_t: float = (t - 0.5) * 2.0  # -1 to 1
		var y_offset: float = arc_height * arc_t * arc_t
		var rot: float = -max_rotation + t * max_rotation * 2.0

		card.position = Vector2(x_pos, base_y + y_offset)
		card.rotation_degrees = rot
		card.z_index = i
		card.base_z_index = i
		card.pivot_offset = Vector2(card_width / 2.0, card_height)

		# Reset scale unless hovered
		if card != hovered_card:
			card.scale = Vector2.ONE

func _on_card_clicked(card_node: Control) -> void:
	if targeting_mode and selected_card == card_node:
		# Deselect
		card_node.set_selected(false)
		selected_card = null
		targeting_mode = false
		return
	if targeting_mode and selected_card != null:
		# Switch selection
		selected_card.set_selected(false)
	selected_card = card_node
	card_node.set_selected(true)
	targeting_mode = true

func _on_card_hovered(card_node: Control) -> void:
	hovered_card = card_node
	# Zoom 30% larger
	var tween = create_tween()
	tween.tween_property(card_node, "scale", Vector2(1.3, 1.3), 0.1)
	card_node.z_index = 100  # Bring to front

func _on_card_unhovered(card_node: Control) -> void:
	if hovered_card == card_node:
		hovered_card = null
	var tween = create_tween()
	tween.tween_property(card_node, "scale", Vector2.ONE, 0.1)
	card_node.z_index = card_node.base_z_index

func try_play_card_on_target(target: Node2D) -> bool:
	if not targeting_mode or selected_card == null:
		return false
	var data: Dictionary = selected_card.card_data
	var card_target: String = data.get("target", "enemy")
	# Validate target
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
