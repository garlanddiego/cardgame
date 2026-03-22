extends Node2D
## res://scripts/battle_manager.gd — Full battle loop: draw, play, enemy turn, win/lose

signal turn_started(is_player: bool)
signal turn_ended
signal card_played_signal(card_data: Dictionary, target: Node2D)
signal enemy_died(enemy_index: int)
signal player_died
signal battle_won

@export var max_energy: int = 3
@export var cards_per_draw: int = 5

var current_energy: int = 3
var draw_pile: Array = []
var discard_pile: Array = []
var exhaust_pile: Array = []
var hand: Array = []
var is_player_turn: bool = true
var enemies: Array = []
var enemy_ais: Array = []
var player: Node2D = null
var battle_active: bool = false
var turn_number: int = 0

# Power effect tracking
var demon_form_active: bool = false
var caltrops_active: bool = false
var envenom_active: bool = false

# Node refs
var card_hand: Control = null
var energy_label: Label = null
var draw_pile_label: Label = null
var discard_label: Label = null
var end_turn_btn: Button = null
var turn_label: Label = null
var player_area: Node2D = null
var enemy_area: Node2D = null

func _ready() -> void:
	card_hand = get_node_or_null("CardHand")
	energy_label = get_node_or_null("HUDLayer/HUD/EnergyContainer/EnergyLabel")
	draw_pile_label = get_node_or_null("HUDLayer/HUD/DrawPileLabel")
	discard_label = get_node_or_null("HUDLayer/HUD/DiscardPileLabel")
	end_turn_btn = get_node_or_null("HUDLayer/HUD/EndTurnButton")
	turn_label = get_node_or_null("HUDLayer/HUD/TurnLabel")
	player_area = get_node_or_null("PlayerArea")
	enemy_area = get_node_or_null("EnemyArea")
	if end_turn_btn:
		end_turn_btn.pressed.connect(_on_end_turn)
		_style_end_turn_button()
	if card_hand:
		card_hand.card_played.connect(_on_card_played)

func _style_end_turn_button() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.6, 0.3, 0.1, 0.85)
	style.border_color = Color(0.9, 0.7, 0.3)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	end_turn_btn.add_theme_stylebox_override("normal", style)
	var hover_style = style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.7, 0.4, 0.15, 0.9)
	end_turn_btn.add_theme_stylebox_override("hover", hover_style)
	end_turn_btn.add_theme_font_size_override("font_size", 20)

func start_battle(character_id: String) -> void:
	battle_active = true
	turn_number = 0
	demon_form_active = false
	caltrops_active = false
	envenom_active = false

	# Get GameManager
	var gm = _get_game_manager()
	if gm == null:
		push_error("GameManager not found")
		return

	# Setup player entity
	_setup_player(character_id, gm)
	# Setup enemies
	_setup_enemies()
	# Build deck from character
	_build_deck(character_id, gm)
	# Start first turn
	start_player_turn()

func _get_game_manager() -> Node:
	# Autoloads are siblings in the scene tree root
	var tree_root = get_tree().root
	for child in tree_root.get_children():
		if child.name == "GameManager":
			return child
	return null

func _setup_player(character_id: String, gm: Node) -> void:
	if player_area == null:
		return
	# Create player entity
	player = _create_entity_node(false)
	var char_data = gm.character_data[character_id]
	player.init_entity(char_data["max_hp"], false)
	# Set sprite
	var sprite = player.get_node_or_null("Sprite") as Sprite2D
	if sprite:
		var tex = load(char_data["sprite"])
		if tex:
			sprite.texture = tex
			# Scale to ~200px tall
			var tex_height: float = tex.get_height()
			if tex_height > 0:
				var scale_factor: float = 200.0 / tex_height
				sprite.scale = Vector2(scale_factor, scale_factor)
	var nlabel = player.get_node_or_null("NameLabel") as Label
	if nlabel:
		nlabel.text = char_data["name"]
	player_area.add_child(player)

func _setup_enemies() -> void:
	if enemy_area == null:
		return
	enemies.clear()
	enemy_ais.clear()
	# Pick 3 random enemy types
	var enemy_types = ["slime", "cultist", "jaw_worm"]
	var enemy_configs = {
		"slime": {"name": "Slime", "hp": 30, "sprite": "res://assets/img/slime.png", "scale_h": 150.0},
		"cultist": {"name": "Cultist", "hp": 50, "sprite": "res://assets/img/cultist.png", "scale_h": 180.0},
		"jaw_worm": {"name": "Jaw Worm", "hp": 44, "sprite": "res://assets/img/jaw_worm.png", "scale_h": 150.0},
		"guardian": {"name": "Guardian", "hp": 60, "sprite": "res://assets/img/guardian.png", "scale_h": 200.0}
	}
	var selected_enemies: Array = ["slime", "cultist", "jaw_worm"]
	for i in range(3):
		var etype: String = selected_enemies[i]
		var config = enemy_configs[etype]
		var enemy = _create_entity_node(true)
		enemy.init_entity(config["hp"], true, etype)
		enemy.position = Vector2(0, i * 200 - 200)
		# Set sprite
		var sprite = enemy.get_node_or_null("Sprite") as Sprite2D
		if sprite:
			var tex = load(config["sprite"])
			if tex:
				sprite.texture = tex
				var tex_height: float = tex.get_height()
				if tex_height > 0:
					var sf: float = config["scale_h"] / tex_height
					sprite.scale = Vector2(sf, sf)
		var nlabel = enemy.get_node_or_null("NameLabel") as Label
		if nlabel:
			nlabel.text = config["name"]
		enemy_area.add_child(enemy)
		enemies.append(enemy)
		# Create AI
		var ai_script = load("res://scripts/enemy_ai.gd")
		var ai = ai_script.new(etype)
		enemy_ais.append(ai)
		# Connect died signal
		enemy.died.connect(_on_entity_died.bind(enemy))
		# Set initial intent
		enemy.intent = ai.get_next_action(enemy)
		enemy.update_intent_display()
	# Connect player died
	if player:
		player.died.connect(func(): _on_player_died())

func _create_entity_node(is_enemy_entity: bool) -> Node2D:
	var entity = Node2D.new()
	entity.name = "Entity"
	entity.set_script(load("res://scripts/entity.gd"))

	# Sprite
	var sprite = Sprite2D.new()
	sprite.name = "Sprite"
	entity.add_child(sprite)

	# Name label above sprite
	var name_lbl = Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = ""
	name_lbl.position = Vector2(-50, -140)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.custom_minimum_size = Vector2(100, 20)
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
	entity.add_child(name_lbl)

	# HP bar background
	var hp_bg = ColorRect.new()
	hp_bg.name = "HPBarBG"
	hp_bg.color = Color(0.15, 0.15, 0.15, 0.8)
	hp_bg.size = Vector2(100, 12)
	hp_bg.position = Vector2(-50, -120)
	entity.add_child(hp_bg)

	# HP bar fill
	var hp_fill = ColorRect.new()
	hp_fill.name = "HPBarFill"
	hp_fill.color = Color(0.2, 0.8, 0.2)
	hp_fill.size = Vector2(100, 12)
	hp_fill.position = Vector2(0, 0)
	hp_bg.add_child(hp_fill)

	# HP label
	var hp_lbl = Label.new()
	hp_lbl.name = "HPLabel"
	hp_lbl.text = "80/80"
	hp_lbl.position = Vector2(-50, -108)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.custom_minimum_size = Vector2(100, 16)
	hp_lbl.add_theme_font_size_override("font_size", 11)
	entity.add_child(hp_lbl)

	# Block label (shield icon area)
	var block_lbl = Label.new()
	block_lbl.name = "BlockLabel"
	block_lbl.text = "0"
	block_lbl.position = Vector2(-60, -50)
	block_lbl.add_theme_font_size_override("font_size", 16)
	block_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	block_lbl.visible = false
	entity.add_child(block_lbl)

	# Status container
	var status_cont = HBoxContainer.new()
	status_cont.name = "StatusContainer"
	status_cont.position = Vector2(-50, 80)
	entity.add_child(status_cont)

	if is_enemy_entity:
		# Intent icon above enemy
		var intent_icon = TextureRect.new()
		intent_icon.name = "IntentIcon"
		intent_icon.custom_minimum_size = Vector2(32, 32)
		intent_icon.position = Vector2(-16, -170)
		intent_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		intent_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		intent_icon.visible = false
		entity.add_child(intent_icon)

		# Intent description
		var intent_lbl = Label.new()
		intent_lbl.name = "IntentLabel"
		intent_lbl.text = ""
		intent_lbl.position = Vector2(-50, -195)
		intent_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		intent_lbl.custom_minimum_size = Vector2(100, 16)
		intent_lbl.add_theme_font_size_override("font_size", 10)
		intent_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.6))
		intent_lbl.visible = false
		entity.add_child(intent_lbl)

	return entity

func _build_deck(character_id: String, gm: Node) -> void:
	draw_pile.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	var deck_ids: Array = gm.get_starting_deck(character_id)
	for card_id in deck_ids:
		var data: Dictionary = gm.get_card_data(card_id)
		if not data.is_empty():
			draw_pile.append(data)
	# Shuffle
	draw_pile.shuffle()
	_update_pile_labels()

func start_player_turn() -> void:
	if not battle_active:
		return
	is_player_turn = true
	turn_number += 1
	current_energy = max_energy
	# Power effects at start of turn
	if demon_form_active and player and player.alive:
		player.apply_status("strength", 2)
	# Reset player block
	if player:
		player.reset_block()
	# Draw cards
	draw_cards(cards_per_draw)
	_update_energy_label()
	_update_pile_labels()
	if turn_label:
		turn_label.text = "Your Turn"
		turn_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	if end_turn_btn:
		end_turn_btn.disabled = false
	turn_started.emit(true)

func draw_cards(count: int) -> void:
	for i in range(count):
		if draw_pile.is_empty():
			_reshuffle_discard()
		if draw_pile.is_empty():
			break
		var card_data: Dictionary = draw_pile.pop_back()
		hand.append(card_data)
		if card_hand:
			card_hand.add_card(card_data)
	_update_pile_labels()

func _reshuffle_discard() -> void:
	draw_pile = discard_pile.duplicate()
	discard_pile.clear()
	draw_pile.shuffle()

func play_card(card_data: Dictionary, target: Node2D) -> void:
	if not battle_active or not is_player_turn:
		return
	var cost: int = card_data.get("cost", 0)
	if current_energy < cost:
		return
	current_energy -= cost
	_update_energy_label()

	# Remove from hand tracking
	for i in range(hand.size()):
		if hand[i].get("id", "") == card_data.get("id", ""):
			hand.remove_at(i)
			break

	# Execute card effect
	_execute_card(card_data, target)

	# Power cards go to exhaust
	var card_type: int = card_data.get("type", 0)
	if card_type == 2:  # POWER
		exhaust_pile.append(card_data)
	else:
		discard_pile.append(card_data)
	_update_pile_labels()
	# Check win condition
	_check_battle_end()

func _execute_card(card_data: Dictionary, target: Node2D) -> void:
	var damage: int = card_data.get("damage", 0)
	var block_val: int = card_data.get("block", 0)
	var draw_count: int = card_data.get("draw", 0)
	var target_type: String = card_data.get("target", "enemy")
	var special: String = card_data.get("special", "")

	# Handle special cards
	if special == "body_slam" and player:
		damage = player.block

	# Apply damage
	if damage > 0:
		var actual_dmg: int = damage
		if player:
			actual_dmg = player.get_attack_damage(damage)
		if target_type == "all_enemies":
			for enemy in enemies:
				if enemy.alive:
					enemy.take_damage(actual_dmg)
		elif target != null and target.alive:
			target.take_damage(actual_dmg)

	# Apply block
	if block_val > 0 and player:
		player.add_block(block_val)

	# Apply status to target
	if card_data.has("apply_status"):
		var status_info = card_data["apply_status"]
		if target_type == "all_enemies":
			for enemy in enemies:
				if enemy.alive:
					enemy.apply_status(status_info["type"], status_info["stacks"])
		elif target != null and target.alive:
			target.apply_status(status_info["type"], status_info["stacks"])

	# Apply status to self
	if card_data.has("apply_self_status") and player:
		var status_info = card_data["apply_self_status"]
		player.apply_status(status_info["type"], status_info["stacks"])

	# Energy gain
	if card_data.has("energy_gain"):
		current_energy += card_data["energy_gain"]
		_update_energy_label()

	# Draw cards
	if draw_count > 0:
		draw_cards(draw_count)

	# Power effects
	if card_data.has("power_effect"):
		match card_data["power_effect"]:
			"demon_form":
				demon_form_active = true
			"caltrops":
				caltrops_active = true
			"envenom":
				envenom_active = true

func end_player_turn() -> void:
	if not battle_active or not is_player_turn:
		return
	is_player_turn = false
	if end_turn_btn:
		end_turn_btn.disabled = true
	# Discard remaining hand
	for card_data in hand:
		discard_pile.append(card_data)
	hand.clear()
	if card_hand:
		card_hand.clear_hand()
	# Tick player status effects
	if player:
		player.tick_status_effects()
	_update_pile_labels()
	turn_ended.emit()
	# Start enemy turn after short delay
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(start_enemy_turn)

func start_enemy_turn() -> void:
	if not battle_active:
		return
	if turn_label:
		turn_label.text = "Enemy Turn"
		turn_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	turn_started.emit(false)
	# Process each enemy action sequentially
	_process_enemy_actions(0)

func _process_enemy_actions(index: int) -> void:
	if index >= enemies.size():
		_end_enemy_turn()
		return
	if not battle_active:
		return
	var enemy = enemies[index]
	if not enemy.alive:
		_process_enemy_actions(index + 1)
		return
	var ai = enemy_ais[index]
	var action: Dictionary = enemy.intent

	# Reset enemy block
	enemy.reset_block()

	# Execute action
	_execute_enemy_action(enemy, action)

	# Tick enemy status
	enemy.tick_status_effects()

	# Generate next intent
	enemy.intent = ai.get_next_action(enemy)
	enemy.update_intent_display()

	# Check if player died
	if player and not player.alive:
		_on_player_died()
		return

	# Next enemy after delay
	var timer = get_tree().create_timer(0.6)
	timer.timeout.connect(_process_enemy_actions.bind(index + 1))

func _execute_enemy_action(enemy: Node2D, action: Dictionary) -> void:
	if player == null or not player.alive:
		return
	var action_type: String = action.get("type", "attack")
	match action_type:
		"attack":
			var value: int = action.get("value", 5)
			var times: int = action.get("times", 1)
			var actual_dmg: int = enemy.get_attack_damage(value)
			for _i in range(times):
				if player.alive:
					player.take_damage(actual_dmg)
					# Caltrops: deal damage back
					if caltrops_active and enemy.alive:
						enemy.take_damage(3)
		"buff":
			var status_name: String = action.get("status", "strength")
			var value: int = action.get("value", 1)
			enemy.apply_status(status_name, value)
		"block":
			var value: int = action.get("value", 5)
			enemy.add_block(value)
		"attack_block":
			var dmg: int = action.get("damage", 5)
			var blk: int = action.get("block_val", 5)
			var actual_dmg: int = enemy.get_attack_damage(dmg)
			player.take_damage(actual_dmg)
			enemy.add_block(blk)
			if caltrops_active and enemy.alive:
				enemy.take_damage(3)
		"mode_shift":
			var blk: int = action.get("block_val", 9)
			enemy.add_block(blk)
		"attack_debuff":
			var dmg: int = action.get("value", 5)
			var status_name: String = action.get("status", "vulnerable")
			var stacks: int = action.get("stacks", 1)
			var actual_dmg: int = enemy.get_attack_damage(dmg)
			player.take_damage(actual_dmg)
			player.apply_status(status_name, stacks)
			if caltrops_active and enemy.alive:
				enemy.take_damage(3)

func _end_enemy_turn() -> void:
	if not battle_active:
		return
	_check_battle_end()
	if battle_active:
		start_player_turn()

func _on_card_played(card_data: Dictionary, target: Node2D) -> void:
	play_card(card_data, target)

func _on_end_turn() -> void:
	end_player_turn()

func _on_entity_died(entity: Node2D) -> void:
	for i in range(enemies.size()):
		if enemies[i] == entity:
			enemy_died.emit(i)
			break
	_check_battle_end()

func _on_player_died() -> void:
	battle_active = false
	player_died.emit()
	if turn_label:
		turn_label.text = "DEFEAT"
		turn_label.add_theme_font_size_override("font_size", 48)
		turn_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))

func _check_battle_end() -> void:
	if not battle_active:
		return
	var all_dead: bool = true
	for enemy in enemies:
		if enemy.alive:
			all_dead = false
			break
	if all_dead:
		battle_active = false
		battle_won.emit()
		if turn_label:
			turn_label.text = "VICTORY!"
			turn_label.add_theme_font_size_override("font_size", 48)
			turn_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))

func _update_energy_label() -> void:
	if energy_label:
		energy_label.text = str(current_energy) + "/" + str(max_energy)

func _update_pile_labels() -> void:
	if draw_pile_label:
		draw_pile_label.text = "Draw: " + str(draw_pile.size())
	if discard_label:
		discard_label.text = "Discard: " + str(discard_pile.size())

var _hovered_enemy: Node2D = null

func _process(_delta: float) -> void:
	if not battle_active or not is_player_turn:
		return
	# Update enemy hover highlight when targeting
	if card_hand and card_hand.is_targeting():
		var card_data: Dictionary = card_hand.get_selected_card_data()
		var target_type: String = card_data.get("target", "enemy")
		if target_type == "enemy":
			var mouse_pos: Vector2 = get_viewport().get_mouse_position()
			var hover_enemy = _get_enemy_at(mouse_pos)
			if hover_enemy != _hovered_enemy:
				_clear_enemy_highlight()
				_hovered_enemy = hover_enemy
				if _hovered_enemy:
					_highlight_enemy(_hovered_enemy)
		elif target_type == "all_enemies":
			# Highlight all enemies
			if _hovered_enemy == null:
				for enemy in enemies:
					if enemy.alive:
						_highlight_enemy(enemy)
				if not enemies.is_empty():
					_hovered_enemy = enemies[0]  # marker
	else:
		if _hovered_enemy != null:
			_clear_all_enemy_highlights()
			_hovered_enemy = null

func _unhandled_input(event: InputEvent) -> void:
	if not battle_active or not is_player_turn:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if card_hand and card_hand.is_targeting():
			var card_data: Dictionary = card_hand.get_selected_card_data()
			var target_type: String = card_data.get("target", "enemy")
			var mouse_pos: Vector2 = event.position
			if target_type == "self":
				# Non-targeted: click anywhere to play
				if player:
					_clear_all_enemy_highlights()
					card_hand.play_selected_on(player)
			elif target_type == "all_enemies":
				# Non-targeted: click anywhere to play on all
				if not enemies.is_empty():
					_clear_all_enemy_highlights()
					card_hand.play_selected_on(enemies[0])
			else:
				# Targeted: must click on an enemy
				var clicked_enemy = _get_enemy_at(mouse_pos)
				if clicked_enemy:
					_clear_all_enemy_highlights()
					card_hand.play_selected_on(clicked_enemy)
	# Right click to deselect card
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if card_hand and card_hand.is_targeting():
			card_hand.selected_card.set_selected(false)
			card_hand.selected_card = null
			card_hand.targeting_mode = false
			_clear_all_enemy_highlights()
			_hovered_enemy = null
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_on_end_turn()

func _highlight_enemy(enemy: Node2D) -> void:
	var sprite = enemy.get_node_or_null("Sprite") as Sprite2D
	if sprite:
		sprite.modulate = Color(1.3, 1.0, 1.0)  # Slight red tint highlight

func _clear_enemy_highlight() -> void:
	if _hovered_enemy and is_instance_valid(_hovered_enemy):
		var sprite = _hovered_enemy.get_node_or_null("Sprite") as Sprite2D
		if sprite:
			sprite.modulate = Color.WHITE

func _clear_all_enemy_highlights() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			var sprite = enemy.get_node_or_null("Sprite") as Sprite2D
			if sprite:
				sprite.modulate = Color.WHITE

func _get_enemy_at(screen_pos: Vector2) -> Node2D:
	if enemy_area == null:
		return null
	for enemy in enemies:
		if not enemy.alive:
			continue
		var enemy_global_pos: Vector2 = enemy_area.position + enemy.position
		var rect = Rect2(enemy_global_pos - Vector2(75, 100), Vector2(150, 200))
		if rect.has_point(screen_pos):
			return enemy
	return null
