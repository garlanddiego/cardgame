extends Node2D
## res://scripts/card_hand.gd — Fan layout of Area2D cards, hover zoom, drag-to-target
## Refactored to use Area2D-based Card class with drag interaction

signal card_played(card_data: Dictionary, target: Node2D)
signal card_drag_released(card_node: Area2D, release_position: Vector2)
signal discard_selection_changed(selected_count: int)

var cards: Array = []
var selected_card: Area2D = null
var focused_card: Area2D = null  # First-tap zoom preview
var hovered_card: Area2D = null
var targeting_mode: bool = false
var current_battle_energy: int = 3
var corruption_active: bool = false
var unplayable_ids: Array = []  # Card IDs that can't be played (special conditions not met)
var dead_hero_chars: Array = []  # Character IDs of dead heroes — their cards look ethereal

# Discard selection mode — cards are tapped to toggle discard selection
var discard_mode: bool = false
var _discard_max: int = 0  # Max cards to select for discard
var _discard_selected_indices: Array = []  # Indices into cards array

var card_script: GDScript = null
var _any_card_dragging: bool = false

# STS2-style layout — matching card.gd CARD_SIZE (256x495)
const CARD_WIDTH: float = 296.0
const CARD_HEIGHT: float = 422.0  # height reduced 15%
const CARD_OVERLAP: float = 60.0  # Overlap for 5+ cards
@export var hover_lift: float = -380.0  ## Card lifts well above hand (card bottom at ~360 absolute)
const HOVER_SPREAD: float = 40.0  # Neighbors spread on hover
const MAX_ROTATION: float = 8.0  # Fan arc
const ARC_HEIGHT: float = 15.0  # Gentle curve
const HAND_Y: float = 0.0

func _ready() -> void:
	card_script = load("res://scripts/card.gd")

func add_card(card_data: Dictionary, animate_from_draw: bool = true, animate_from_global: Vector2 = Vector2(-1, -1)) -> void:
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
	# Start card at specified position and fly in
	if animate_from_global.x >= 0:
		card.position = to_local(animate_from_global)
		card.scale = Vector2(0.3, 0.3)
		card.set_meta("fly_in", true)
	elif animate_from_draw:
		var draw_pile_pos: Vector2 = to_local(Vector2(95, 985))
		card.position = draw_pile_pos
		card.scale = Vector2(0.3, 0.3)
		card.set_meta("fly_in", true)
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
	_any_card_dragging = false
	hovered_card = null
	discard_mode = false

func snap_layout() -> void:
	## Position all cards instantly (no tween animation)
	if cards.is_empty():
		return
	var card_count: int = cards.size()
	var vw: float = get_viewport_rect().size.x
	var margin: float = 50.0
	var available_width: float = vw - margin * 2.0
	var base_scale: float = 1.0
	if card_count > 8:
		base_scale = 0.7
	elif card_count > 6:
		base_scale = 0.8
	elif card_count > 4:
		base_scale = 0.9
	var scaled_card_w: float = CARD_WIDTH * base_scale
	var step: float = scaled_card_w - CARD_OVERLAP * base_scale
	var total_width: float = step * (card_count - 1) + scaled_card_w
	if total_width > available_width and card_count > 1:
		step = (available_width - scaled_card_w) / float(card_count - 1)
		total_width = step * (card_count - 1) + scaled_card_w
	var start_x: float = margin + (available_width - total_width) / 2.0
	var base_y: float = HAND_Y
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
		card.position = Vector2(x_pos, base_y + y_offset)
		card.rotation = rot
		card.scale = Vector2(base_scale, base_scale)
		card.z_index = i
		card.base_z_index = i

func update_layout() -> void:
	if cards.is_empty():
		return
	var card_count: int = cards.size()
	var vw: float = get_viewport_rect().size.x
	# Reserve space on each side (piles are below card area now, less margin needed)
	var margin: float = 50.0
	var available_width: float = vw - margin * 2.0

	# Progressive card scaling based on hand size
	var base_scale: float = 1.0
	if card_count > 8:
		base_scale = 0.7
	elif card_count > 6:
		base_scale = 0.8
	elif card_count > 4:
		base_scale = 0.9

	var scaled_card_w: float = CARD_WIDTH * base_scale
	var step: float = scaled_card_w - CARD_OVERLAP * base_scale
	var total_width: float = step * (card_count - 1) + scaled_card_w
	# If still too wide, compress further
	if total_width > available_width and card_count > 1:
		step = (available_width - scaled_card_w) / float(card_count - 1)
		total_width = step * (card_count - 1) + scaled_card_w
	var start_x: float = margin + (available_width - total_width) / 2.0
	var base_y: float = HAND_Y

	var hovered_index: int = -1
	if hovered_card != null and hovered_card in cards:
		hovered_index = cards.find(hovered_card)

	# Count visible cards (exclude those at center in discard mode)
	var visible_count: int = card_count
	if discard_mode:
		visible_count -= _discard_selected_indices.size()
	if visible_count > 0:
		step = scaled_card_w - CARD_OVERLAP * base_scale
		total_width = step * (visible_count - 1) + scaled_card_w
		if total_width > available_width and visible_count > 1:
			step = (available_width - scaled_card_w) / float(visible_count - 1)
			total_width = step * (visible_count - 1) + scaled_card_w
		start_x = margin + (available_width - total_width) / 2.0

	var slot_index: int = 0  # Track position slot for visible cards
	for i in range(card_count):
		var card = cards[i]
		if not is_instance_valid(card):
			continue
		# Skip cards that are at screen center (discard selection)
		if discard_mode and i in _discard_selected_indices:
			continue

		var t: float = 0.5
		if visible_count > 1:
			t = float(slot_index) / float(visible_count - 1)

		var x_pos: float = start_x + slot_index * step
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
			# Selected card: fixed size (scale 1.0), bottom edge 5px from screen bottom
			var vh: float = get_viewport_rect().size.y
			var hand_y: float = global_position.y
			var fixed_scale: float = 1.0
			target_pos.y = (vh - 5.0) - hand_y - CARD_HEIGHT * fixed_scale
			target_rot = 0.0
			target_scale = Vector2(fixed_scale, fixed_scale)
		elif not discard_mode and (card == focused_card or card == hovered_card):
			# Hover/focus (NOT in discard mode): lift card, same as selected
			var vh2: float = get_viewport_rect().size.y
			var hand_y2: float = global_position.y
			target_pos.y = (vh2 - 5.0) - hand_y2 - CARD_HEIGHT * 1.0
			target_rot = 0.0
			target_scale = Vector2(1.0, 1.0)

		# Determine animation speed
		var anim_dur: float = 0.12  # Default for layout shifts
		if card == selected_card:
			anim_dur = 0.1
		elif card.has_meta("fly_in") and card.get_meta("fly_in"):
			anim_dur = 0.5  # Slower fly-in for newly drawn/generated cards
			card.set_meta("fly_in", false)
		card.move_to(target_pos, target_rot, target_scale, anim_dur)

		card.z_index = slot_index
		card.base_z_index = slot_index
		slot_index += 1

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
	# Check unplayable (special conditions not met)
	var card_id: String = card_data_check.get("id", "")
	if card_id in unplayable_ids:
		return false
	if card_data_check.get("unplayable", false):
		return false
	var cost: int = card_data_check.get("cost", 0)
	# X-cost cards (cost -1): playable if energy > 0
	if cost == -1:
		return current_battle_energy > 0
	# Corruption: skills cost 0
	if corruption_active and card_data_check.get("type", 0) == 1:  # SKILL
		return true
	if cost == 0:
		return true
	if cost < 0 and cost != -1:
		return false  # Negative cost (except X=-1) = unplayable
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

	# Discard selection mode: toggle card for discard instead of playing
	if discard_mode:
		print("[CardHand] Discard mode click on card %s" % card_node.card_data.get("name", "?"))
		_toggle_discard_card(card_node)
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

	# SELECT this card on single click
	selected_card = card_node
	card_node.set_selected(true)

	# Only enable targeting if card is playable
	if _can_afford_card(card_data_val):
		targeting_mode = true
	else:
		targeting_mode = false  # Card lifted for viewing but no targeting arrow
	focused_card = null
	hovered_card = null
	update_layout()

func _toggle_discard_card(card_node: Area2D) -> void:
	## Toggle a card for discard — supports multiple selections up to _discard_max
	var idx: int = cards.find(card_node)
	if idx < 0:
		return
	if idx in _discard_selected_indices:
		# Already selected → deselect, return card to hand
		_discard_selected_indices.erase(idx)
		card_node.scale = Vector2(1.0, 1.0)
	else:
		if _discard_selected_indices.size() >= _discard_max:
			# At max: replace the oldest selection (swap)
			var old_idx: int = _discard_selected_indices[0]
			_discard_selected_indices.erase(old_idx)
			if old_idx < cards.size() and is_instance_valid(cards[old_idx]):
				cards[old_idx].scale = Vector2(1.0, 1.0)
		_discard_selected_indices.append(idx)
		card_node.z_index = 600
	# Reposition all selected cards in center
	_reposition_discard_preview()
	update_layout()
	discard_selection_changed.emit(_discard_selected_indices.size())

func _reposition_discard_preview() -> void:
	## Arrange all selected discard cards side by side at screen center
	var count: int = _discard_selected_indices.size()
	if count == 0:
		return
	var vw: float = get_viewport_rect().size.x
	var gap: float = 20.0
	var total_w: float = count * CARD_WIDTH + (count - 1) * gap
	var start_x: float = (vw - total_w) / 2.0
	for i in range(count):
		var card_idx: int = _discard_selected_indices[i]
		if card_idx < cards.size() and is_instance_valid(cards[card_idx]):
			var x: float = start_x + i * (CARD_WIDTH + gap)
			var pos: Vector2 = to_local(Vector2(x, 250))
			cards[card_idx].move_to(pos, 0.0, Vector2(1.0, 1.0), 0.2)
			cards[card_idx].z_index = 600 + i

func _unhandled_input(event: InputEvent) -> void:
	# Deselect card on any tap when card is selected but not in targeting mode
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected_card != null and not targeting_mode and is_instance_valid(selected_card):
			selected_card.set_selected(false)
			selected_card = null
			focused_card = null
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
	elif card_target == "random_enemy":
		_do_play(data, target)
		return true
	elif card_target == "all_heroes" and not target.is_enemy:
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

var _pending_card_node: Area2D = null  # Card waiting at center for delayed fly-away
var _pending_card_target: Node2D = null

func _do_play(data: Dictionary, target: Node2D) -> void:
	var card_node = selected_card
	selected_card = null
	focused_card = null
	targeting_mode = false
	var has_discard: bool = data.get("discard", 0) > 0
	# Animate card: fly to center → pause → then to final destination
	if card_node and is_instance_valid(card_node):
		var is_power: bool = data.get("type", 0) == 2
		var should_exhaust: bool = data.get("exhaust", false) and not is_power
		# Step 1: Fly to screen center
		var center_pos: Vector2 = to_local(Vector2(get_viewport_rect().size.x / 2.0, 400))
		card_node.move_to(center_pos, 0.0, Vector2(1.2, 1.2), 0.2)
		if has_discard and not is_power and not should_exhaust:
			# Card has discard requirement: keep at center, fly away after discard completes
			_pending_card_node = card_node
			_pending_card_target = target
		else:
			# Step 2: After pause, fly to final destination
			var anim_tween = create_tween()
			anim_tween.tween_interval(0.25)
			anim_tween.tween_callback(func():
				if not is_instance_valid(card_node):
					return
				if is_power:
					var player_pos: Vector2 = to_local(target.global_position) if target and is_instance_valid(target) else to_local(Vector2(370, 460))
					card_node.move_to(player_pos, 0.0, Vector2(0.3, 0.3), 0.25)
				elif should_exhaust:
					_shatter_card(card_node)
				else:
					var discard_pos: Vector2 = to_local(Vector2(get_viewport_rect().size.x - 95, 985))
					card_node.move_to(discard_pos, 0.0, Vector2(0.3, 0.3), 0.25)
			)
		cards.erase(card_node)
		# Fully disable played card: no input, no processing
		card_node.input_pickable = false
		card_node.set_process(false)
		card_node.set_process_unhandled_input(false)
		card_node._is_pressed = false
		card_node._is_dragging = false
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
		# Remove after full animation completes (0.25 pause + 0.25 fly)
		if _pending_card_node != card_node:
			var tween = create_tween()
			tween.tween_interval(0.6)
			tween.tween_callback(func():
				if is_instance_valid(card_node):
					card_node.queue_free()
			)
		# else: pending card stays at center until complete_pending_play() is called
		update_layout()
	else:
		remove_card(card_node)
	card_played.emit(data, target)

func complete_pending_play() -> void:
	## Called after discard flow completes — send the pending card to discard pile
	if _pending_card_node and is_instance_valid(_pending_card_node):
		var discard_pos: Vector2 = to_local(Vector2(get_viewport_rect().size.x - 95, 985))
		_pending_card_node.move_to(discard_pos, 0.0, Vector2(0.3, 0.3), 0.25)
		var node = _pending_card_node
		var tween = create_tween()
		tween.tween_interval(0.3)
		tween.tween_callback(func():
			if is_instance_valid(node):
				node.queue_free()
		)
	_pending_card_node = null
	_pending_card_target = null

func _shatter_card(card_node: Area2D) -> void:
	## Create fragment particles that fly outward from the card position
	var base_pos: Vector2 = card_node.position
	var frag_count: int = 8
	# Hide the original card immediately
	card_node.visible = false
	for i in range(frag_count):
		var frag = ColorRect.new()
		frag.size = Vector2(20 + randf() * 20, 15 + randf() * 15)
		frag.color = Color(0.8, 0.3 + randf() * 0.3, 0.1, 0.9)
		frag.position = base_pos + Vector2(randf_range(-30, 30), randf_range(-40, 40))
		add_child(frag)
		# Random outward direction
		var angle: float = (float(i) / frag_count) * TAU + randf_range(-0.3, 0.3)
		var dist: float = 80 + randf() * 120
		var target_pos: Vector2 = frag.position + Vector2(cos(angle), sin(angle)) * dist
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(frag, "position", target_pos, 0.4 + randf() * 0.2).set_ease(Tween.EASE_OUT)
		t.tween_property(frag, "rotation", randf_range(-2.0, 2.0), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(frag, "modulate:a", 0.0, 0.5).set_delay(0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(frag, "scale", Vector2(0.2, 0.2), 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		t.set_parallel(false)
		t.tween_callback(frag.queue_free)

func update_card_playability(current_energy: int) -> void:
	for card in cards:
		if not is_instance_valid(card):
			continue
		var cost: int = card.card_data.get("cost", 0)
		if cost == -1:
			cost = 0  # X-cost cards are always playable
		if card.card_visual:
			if not card.is_selected:
				card.card_visual.modulate = Color(1, 1, 1, 1)
			# Find cost label: try CostLabel first (STS2 card visual), then FallbackCost
			var cost_lbl: Label = null
			cost_lbl = card.card_visual.get_node_or_null("CostLabel") as Label
			if cost_lbl == null:
				cost_lbl = card.card_visual.get_node_or_null("FallbackCost") as Label
			# Determine affordable + playable
			var card_id: String = card.card_data.get("id", "")
			var is_blocked: bool = card_id in unplayable_ids or card.card_data.get("unplayable", false)
			var affordable: bool = (cost <= current_energy) and not is_blocked
			var cost_color: Color = Color(0.2, 0.85, 0.3) if affordable else Color(1.0, 0.2, 0.2)
			# Show/remove prohibition icon for blocked cards
			var blocked_node = card.card_visual.get_node_or_null("BlockedIcon")
			if is_blocked and blocked_node == null:
				var icon = preload("res://scripts/blocked_icon.gd").new()
				icon.name = "BlockedIcon"
				var orb_bg = card.card_visual.get_node_or_null("CostOrbBG")
				if orb_bg:
					icon.position = orb_bg.position
					icon.size = orb_bg.size
				else:
					icon.position = Vector2(4, 4)
					icon.size = Vector2(40, 40)
				icon.z_index = 20
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card.card_visual.add_child(icon)
				if cost_lbl:
					cost_lbl.text = ""
			elif not is_blocked and blocked_node:
				blocked_node.queue_free()
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

func enter_discard_mode(max_count: int) -> void:
	## Enter discard selection mode — cards are tapped to toggle for discard
	print("[CardHand] Entering discard mode, max=%d, cards=%d" % [max_count, cards.size()])
	for c in cards:
		if is_instance_valid(c):
			print("  Card '%s' input_pickable=%s" % [c.card_data.get("name", "?"), str(c.input_pickable)])
	discard_mode = true
	_discard_max = max_count
	_discard_selected_indices.clear()
	# Deselect any currently selected/focused card
	if selected_card and is_instance_valid(selected_card):
		selected_card.set_selected(false)
	selected_card = null
	focused_card = null
	hovered_card = null
	targeting_mode = false
	update_layout()

func exit_discard_mode() -> void:
	## Exit discard selection mode, reset card highlights
	discard_mode = false
	_discard_max = 0
	for i in range(cards.size()):
		var card = cards[i]
		if is_instance_valid(card) and card.card_visual:
			card.card_visual.modulate = Color(1, 1, 1, 1)
	_discard_selected_indices.clear()
	update_layout()

func get_discard_selected_indices() -> Array:
	return _discard_selected_indices.duplicate()

func get_selected_card_data() -> Dictionary:
	if selected_card != null:
		return selected_card.card_data
	return {}

func is_targeting() -> bool:
	return targeting_mode

# ---- Drag-to-play handlers ----

func _on_card_drag_started(card_node: Area2D) -> void:
	if discard_mode:
		return  # No drag-to-play in discard selection mode
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
	# All_enemies / random_enemy: auto-play on drag release anywhere
	if target_type in ["all_enemies", "random_enemy"]:
		card_played_tap.emit(card_node)
		return
	# Self and enemy-targeted: let battle_manager resolve at release position
	card_drag_released.emit(card_node, release_position)
