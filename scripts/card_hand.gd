extends Node2D
## res://scripts/card_hand.gd — Fan layout of Area2D cards, hover zoom, drag-to-target
## Refactored to use Area2D-based Card class with drag interaction

signal card_played(card_data: Dictionary, target: Node2D)
signal card_drag_released(card_node: Area2D, release_position: Vector2)

var cards: Array = []
var selected_card: Area2D = null
var focused_card: Area2D = null  # First-tap zoom preview
var hovered_card: Area2D = null
var targeting_mode: bool = false
var current_battle_energy: int = 3
var corruption_active: bool = false

var card_script: GDScript = null
var _any_card_dragging: bool = false

# STS2-style layout — matching card.gd CARD_SIZE (256x430)
const CARD_WIDTH: float = 256.0
const CARD_HEIGHT: float = 430.0
const CARD_OVERLAP: float = 60.0  # Overlap for 5+ cards
@export var hover_lift: float = -380.0  ## Card lifts well above hand (card bottom at ~360 absolute)
const HOVER_SPREAD: float = 40.0  # Neighbors spread on hover
const MAX_ROTATION: float = 8.0  # Fan arc
const ARC_HEIGHT: float = 15.0  # Gentle curve
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
	card.card_long_pressed.connect(_on_card_long_pressed)
	card.card_drag_started.connect(_on_card_drag_started)
	card.card_drag_ended.connect(_on_card_drag_ended)
	update_layout()

func remove_card(card_node: Area2D) -> void:
	if card_node in cards:
		cards.erase(card_node)
		# Disconnect signals before freeing
		if card_node.card_clicked.is_connected(_on_card_clicked):
			card_node.card_clicked.disconnect(_on_card_clicked)
		if card_node.card_focused.is_connected(_on_card_hovered):
			card_node.card_focused.disconnect(_on_card_hovered)
		if card_node.card_unfocused.is_connected(_on_card_unhovered):
			card_node.card_unfocused.disconnect(_on_card_unhovered)
		if card_node.card_long_pressed.is_connected(_on_card_long_pressed):
			card_node.card_long_pressed.disconnect(_on_card_long_pressed)
		if card_node.card_drag_started.is_connected(_on_card_drag_started):
			card_node.card_drag_started.disconnect(_on_card_drag_started)
		if card_node.card_drag_ended.is_connected(_on_card_drag_ended):
			card_node.card_drag_ended.disconnect(_on_card_drag_ended)
		card_node.queue_free()
		if selected_card == card_node:
			selected_card = null
			targeting_mode = false
		if focused_card == card_node:
			focused_card = null
		update_layout()

func clear_hand() -> void:
	for card in cards:
		if is_instance_valid(card):
			card.queue_free()
	cards.clear()
	selected_card = null
	focused_card = null
	targeting_mode = false

func update_layout() -> void:
	if cards.is_empty():
		return
	var card_count: int = cards.size()
	# Cards overlap: each card takes CARD_WIDTH - CARD_OVERLAP horizontal space
	var step: float = CARD_WIDTH - CARD_OVERLAP
	var total_width: float = step * (card_count - 1) + CARD_WIDTH
	var vw: float = get_viewport_rect().size.x
	var start_x: float = (vw - total_width) / 2.0
	var base_y: float = HAND_Y  # Cards positioned relative to this Node2D

	# Shrink cards when hand has 7+
	var base_scale: float = 1.0
	if card_count >= 7:
		base_scale = 0.9

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
		var target_scale := Vector2(base_scale, base_scale)

		if card == selected_card:
			target_pos.y += hover_lift - 30  # Selected card lifts even higher
			target_rot = 0.0
			target_scale = Vector2(1.4, 1.4)
		elif card == focused_card:
			target_pos.y += hover_lift - 10  # Focused card lifts up for preview
			target_rot = 0.0
			target_scale = Vector2(1.5, 1.5)
		elif card == hovered_card:
			target_pos.y += hover_lift
			target_rot = 0.0
			target_scale = Vector2(1.4, 1.4)

		# Use the card's move_to method for smooth animation
		card.move_to(target_pos, target_rot, target_scale, 0.12)

		card.z_index = i
		card.base_z_index = i

		if card == selected_card:
			card.z_index = 150
		elif card == focused_card:
			card.z_index = 120
		elif card == hovered_card:
			card.z_index = 100

# ---- Tap-to-select handlers ----

# Signal for auto-play on non-targeted cards (self/all_enemies)
signal card_played_tap(card_node: Area2D)
# Signal for long-press card detail
signal card_long_press_detail(card_node: Area2D)

func _can_afford_card(card_data_check: Dictionary) -> bool:
	var cost: int = card_data_check.get("cost", 0)
	# X-cost cards (cost -1): playable if energy > 0
	if cost == -1:
		return current_battle_energy > 0
	# Corruption: skills cost 0
	if corruption_active and card_data_check.get("type", 0) == 1:  # SKILL
		return true
	if cost <= 0:
		return true
	return cost <= current_battle_energy

func _on_card_clicked(card_node: Area2D) -> void:
	## Single-click card selection:
	## - Click card → select it (lift up, show targeting)
	## - Click different card → switch selection
	## - Click same card → deselect
	## - Targeted cards: click enemy after selecting to play
	## - Non-targeted: click background after selecting to play
	if _any_card_dragging:
		return
	var card_data_val: Dictionary = card_node.card_data
	var target_type: String = card_data_val.get("target", "enemy")

	# If a different card is already selected → switch to this card
	if selected_card != null and selected_card != card_node and is_instance_valid(selected_card):
		selected_card.set_selected(false)
		selected_card = null
		focused_card = null
		targeting_mode = false
		# Fall through to select the new card below

	# If THIS card is already selected → deselect (cancel)
	elif selected_card == card_node:
		card_node.set_selected(false)
		selected_card = null
		focused_card = null
		targeting_mode = false
		update_layout()
		return

	# Energy check
	if not _can_afford_card(card_data_val):
		update_layout()
		return

	# SELECT this card on single click
	selected_card = card_node
	card_node.set_selected(true)
	targeting_mode = true
	focused_card = null
	hovered_card = null
	update_layout()

func _on_card_long_pressed(card_node: Area2D) -> void:
	card_long_press_detail.emit(card_node)

func _on_card_hovered(card_node: Area2D) -> void:
	if _any_card_dragging:
		return
	# Don't change hover during selection/targeting
	if selected_card != null:
		return
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
	focused_card = null
	targeting_mode = false
	# Animate card flying toward the discard pile (bottom-right) before removing
	if card_node and is_instance_valid(card_node):
		# Discard pile is at approximately (1700, 890) in screen coordinates
		var discard_global := Vector2(1700, 890)
		var fly_pos: Vector2 = to_local(discard_global)
		card_node.move_to(fly_pos, 0.0, Vector2(0.3, 0.3), 0.2)
		cards.erase(card_node)
		# Disconnect signals before freeing
		if card_node.card_clicked.is_connected(_on_card_clicked):
			card_node.card_clicked.disconnect(_on_card_clicked)
		if card_node.card_focused.is_connected(_on_card_hovered):
			card_node.card_focused.disconnect(_on_card_hovered)
		if card_node.card_unfocused.is_connected(_on_card_unhovered):
			card_node.card_unfocused.disconnect(_on_card_unhovered)
		if card_node.card_long_pressed.is_connected(_on_card_long_pressed):
			card_node.card_long_pressed.disconnect(_on_card_long_pressed)
		if card_node.card_drag_started.is_connected(_on_card_drag_started):
			card_node.card_drag_started.disconnect(_on_card_drag_started)
		if card_node.card_drag_ended.is_connected(_on_card_drag_ended):
			card_node.card_drag_ended.disconnect(_on_card_drag_ended)
		# Remove after fly animation completes
		var tween = create_tween()
		tween.tween_interval(0.2)
		tween.tween_callback(func():
			if is_instance_valid(card_node):
				card_node.queue_free()
		)
		update_layout()
	else:
		remove_card(card_node)
	card_played.emit(data, target)

func update_card_playability(current_energy: int) -> void:
	for card in cards:
		if not is_instance_valid(card):
			continue
		var cost: int = card.card_data.get("cost", 0)
		if cost == -1:
			cost = 0  # X-cost cards are always playable
		if card.card_visual:
			# Always keep full color (no grey dimming)
			if not card.is_selected:
				card.card_visual.modulate = Color(1, 1, 1, 1)
			# Find cost label: try CostLabel first (STS2 card visual), then FallbackCost
			var cost_lbl: Label = null
			cost_lbl = card.card_visual.get_node_or_null("CostLabel") as Label
			if cost_lbl == null:
				cost_lbl = card.card_visual.get_node_or_null("FallbackCost") as Label
			# Determine affordable color
			var affordable: bool = cost <= current_energy
			var cost_color: Color = Color(0.2, 0.85, 0.3) if affordable else Color(1.0, 0.2, 0.2)
			if cost_lbl:
				cost_lbl.add_theme_color_override("font_color", cost_color)
			# Update the cost orb background border color to match
			var orb_bg: Panel = card.card_visual.get_node_or_null("CostOrbBG") as Panel
			if orb_bg:
				var orb_style = orb_bg.get_theme_stylebox("panel") as StyleBoxFlat
				if orb_style:
					# Duplicate to avoid shared resource issues
					var new_style = orb_style.duplicate() as StyleBoxFlat
					new_style.border_color = cost_color
					orb_bg.add_theme_stylebox_override("panel", new_style)

func get_selected_card_data() -> Dictionary:
	if selected_card != null:
		return selected_card.card_data
	return {}

func is_targeting() -> bool:
	return targeting_mode

# ---- Drag-to-play handlers ----

func _on_card_drag_started(card_node: Area2D) -> void:
	_any_card_dragging = true
	hovered_card = null  # Clear hover when drag starts
	focused_card = null  # Clear focus too
	# Energy check before allowing drag
	if not _can_afford_card(card_node.card_data):
		# Cancel the drag and snap card back
		_any_card_dragging = false
		card_node._is_dragging = false
		card_node._is_pressed = false
		card_node._press_time = 0.0
		update_layout()
		return
	# Deselect previous if any
	if selected_card != null and is_instance_valid(selected_card) and selected_card != card_node:
		selected_card.set_selected(false)
	selected_card = card_node
	card_node.set_selected(true)
	targeting_mode = true
	# Card stays in place — targeting arrow shown by battle_manager
	card_node.z_index = 200

func _on_card_drag_ended(card_node: Area2D, release_position: Vector2) -> void:
	_any_card_dragging = false
	# Emit signal for battle_manager to resolve the target at release position
	var card_data: Dictionary = card_node.card_data
	var target_type: String = card_data.get("target", "enemy")
	# Self/all_enemies: auto-play on drag release anywhere
	if target_type == "self" or target_type == "all_enemies":
		card_played_tap.emit(card_node)
		return
	# Enemy-targeted: let battle_manager resolve
	card_drag_released.emit(card_node, release_position)
