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
var flame_barrier_active: bool = false
var flame_barrier_damage: int = 4
var corruption_active: bool = false
var berserk_active: bool = false
var feel_no_pain_active: bool = false
var feel_no_pain_block: int = 3
var juggernaut_active: bool = false
var juggernaut_damage: int = 5
var evolve_active: bool = false
var rage_active: bool = false
var rage_block: int = 3
var barricade_active: bool = false
var metallicize_active: bool = false
var metallicize_block: int = 3

# Temp effects (reset at end of turn)
var flex_strength_to_remove: int = 0

# Node refs
var card_hand: Node2D = null
var energy_label: Label = null
var draw_pile_label: Label = null
var discard_label: Label = null
var end_turn_btn: Button = null
var turn_label: Label = null
var player_area: Node2D = null
var enemy_area: Node2D = null

# Card detail overlay
var _card_detail_overlay: Control = null

# Pile viewer overlay
var _pile_viewer: Control = null

# Damage preview labels
var _damage_preview_labels: Array = []

# Turn banner
var _turn_banner: Label = null

func _ready() -> void:
	card_hand = get_node_or_null("CardHand")
	energy_label = get_node_or_null("HUDLayer/HUD/EnergyPanel/EnergyContainer/EnergyLabel")
	draw_pile_label = get_node_or_null("HUDLayer/HUD/DrawPileLabel")
	discard_label = get_node_or_null("HUDLayer/HUD/DiscardPileLabel")
	end_turn_btn = get_node_or_null("HUDLayer/HUD/EndTurnButton")
	turn_label = get_node_or_null("HUDLayer/HUD/TurnPanel/TurnLabel")
	player_area = get_node_or_null("PlayerArea")
	enemy_area = get_node_or_null("EnemyArea")
	if end_turn_btn:
		end_turn_btn.pressed.connect(_on_end_turn)
		_style_end_turn_button()
		var loc = _get_loc()
		if loc:
			end_turn_btn.text = loc.t("end_turn")
	if card_hand:
		card_hand.card_played.connect(_on_card_played)
		card_hand.card_played_tap.connect(_on_card_tap_play)
		card_hand.card_long_press_detail.connect(_on_card_long_press_detail)
		card_hand.card_drag_released.connect(_on_card_drag_released)

	# STS-style chain targeting arrow — circles along bezier curve
	_targeting_arrow = preload("res://scripts/targeting_arrow.gd").new()
	_targeting_arrow.name = "TargetingArrow"
	_targeting_arrow.z_index = 200
	add_child(_targeting_arrow)

	# Card detail overlay (for long-press)
	_setup_card_detail_overlay()

	# Turn banner
	_setup_turn_banner()

	# HUD font size improvements
	if energy_label:
		energy_label.add_theme_font_size_override("font_size", 32)
	if draw_pile_label:
		draw_pile_label.add_theme_font_size_override("font_size", 18)
		draw_pile_label.mouse_filter = Control.MOUSE_FILTER_STOP
		draw_pile_label.gui_input.connect(_on_draw_pile_clicked)
	if discard_label:
		discard_label.add_theme_font_size_override("font_size", 18)
		discard_label.mouse_filter = Control.MOUSE_FILTER_STOP
		discard_label.gui_input.connect(_on_discard_pile_clicked)

	# Pile viewer overlay
	_setup_pile_viewer()
	if turn_label:
		turn_label.add_theme_font_size_override("font_size", 24)

	# Reposition end turn button to right-center
	if end_turn_btn:
		end_turn_btn.position = Vector2(1920 - 280, 400)

func _exit_tree() -> void:
	if end_turn_btn and end_turn_btn.pressed.is_connected(_on_end_turn):
		end_turn_btn.pressed.disconnect(_on_end_turn)
	if card_hand:
		if card_hand.card_played.is_connected(_on_card_played):
			card_hand.card_played.disconnect(_on_card_played)
		if card_hand.card_played_tap.is_connected(_on_card_tap_play):
			card_hand.card_played_tap.disconnect(_on_card_tap_play)
		if card_hand.card_long_press_detail.is_connected(_on_card_long_press_detail):
			card_hand.card_long_press_detail.disconnect(_on_card_long_press_detail)
		if card_hand.card_drag_released.is_connected(_on_card_drag_released):
			card_hand.card_drag_released.disconnect(_on_card_drag_released)

func _style_end_turn_button() -> void:
	# Per VISUAL_DESIGN_SPEC section 4.6: 220x56, warm orange, gold border
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.600, 0.298, 0.102, 0.851)
	style.border_color = Color(0.902, 0.722, 0.290, 1.0)  # border_gold
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
	hover_style.bg_color = Color(0.702, 0.361, 0.133, 0.902)
	end_turn_btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.478, 0.239, 0.078, 1.0)
	end_turn_btn.add_theme_stylebox_override("pressed", pressed_style)

	var disabled_style = style.duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color(0.200, 0.133, 0.067, 0.60)
	disabled_style.border_color = Color(0.902, 0.722, 0.290, 0.5)  # border_gold_dim
	end_turn_btn.add_theme_stylebox_override("disabled", disabled_style)

	end_turn_btn.add_theme_font_size_override("font_size", 26)
	end_turn_btn.custom_minimum_size = Vector2(240, 70)
	end_turn_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	end_turn_btn.add_theme_color_override("font_disabled_color", Color(0.478, 0.447, 0.376, 0.80))
	# Drop shadow for button text
	end_turn_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	end_turn_btn.add_theme_constant_override("shadow_offset_x", 0)
	end_turn_btn.add_theme_constant_override("shadow_offset_y", 2)

func start_battle(character_id: String) -> void:
	battle_active = true
	turn_number = 0
	_reset_all_powers()

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

func _reset_all_powers() -> void:
	demon_form_active = false
	caltrops_active = false
	envenom_active = false
	flame_barrier_active = false
	corruption_active = false
	berserk_active = false
	feel_no_pain_active = false
	juggernaut_active = false
	evolve_active = false
	rage_active = false
	barricade_active = false
	metallicize_active = false
	flex_strength_to_remove = 0

func _get_game_manager() -> Node:
	# Autoloads are siblings in the scene tree root
	var tree_root = get_tree().root
	for child in tree_root.get_children():
		if child.name == "GameManager":
			return child
	return null

func _get_loc() -> Node:
	var tree_root = get_tree().root
	for child in tree_root.get_children():
		if child.name == "Loc":
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
			# Scale to ~600px tall (large STS-like proportions)
			var tex_height: float = tex.get_height()
			if tex_height > 0:
				var scale_factor: float = 600.0 / tex_height
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
		"slime": {"name": "Slime", "hp": 1000, "sprite": "res://assets/img/slime_sts.png", "scale_h": 350.0},
		"cultist": {"name": "Cultist", "hp": 1000, "sprite": "res://assets/img/cultist_sts.png", "scale_h": 400.0},
		"jaw_worm": {"name": "Jaw Worm", "hp": 1000, "sprite": "res://assets/img/jaw_worm_sts.png", "scale_h": 380.0},
		"guardian": {"name": "Guardian", "hp": 1000, "sprite": "res://assets/img/guardian.png", "scale_h": 400.0}
	}
	var selected_enemies: Array = ["slime"]
	for i in range(1):
		var etype: String = selected_enemies[i]
		var config = enemy_configs[etype]
		var enemy = _create_entity_node(true)
		enemy.init_entity(config["hp"], true, etype)
		# Single enemy centered in enemy area
		enemy.position = Vector2(150, 0)
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

	# Name label BELOW sprite
	var name_lbl = Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = ""
	name_lbl.position = Vector2(-90, 100)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.custom_minimum_size = Vector2(180, 24)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9))
	var name_bg = StyleBoxFlat.new()
	name_bg.bg_color = Color(0.1, 0.07, 0.03, 0.8)
	name_bg.corner_radius_top_left = 4
	name_bg.corner_radius_top_right = 4
	name_bg.corner_radius_bottom_left = 4
	name_bg.corner_radius_bottom_right = 4
	name_lbl.add_theme_stylebox_override("normal", name_bg)
	entity.add_child(name_lbl)

	# HP bar BELOW name — wider (180px), dark red bg, rounded feel
	var hp_bar_width: float = 180.0
	var hp_bg = ColorRect.new()
	hp_bg.name = "HPBarBG"
	hp_bg.color = Color(0.200, 0.059, 0.059, 1.0)  # hp_bar_bg per spec
	hp_bg.size = Vector2(hp_bar_width, 12)
	hp_bg.position = Vector2(-hp_bar_width / 2.0, 130)
	entity.add_child(hp_bg)

	# HP bar fill — red per spec, gradient handled in entity.gd
	var hp_fill = ColorRect.new()
	hp_fill.name = "HPBarFill"
	hp_fill.color = Color(0.800, 0.133, 0.133, 1.0)  # hp_bar_fill per spec
	hp_fill.size = Vector2(hp_bar_width, 12)
	hp_fill.position = Vector2(0, 0)
	hp_bg.add_child(hp_fill)

	# HP label ON TOP of HP bar (centered vertically and horizontally)
	var hp_lbl = Label.new()
	hp_lbl.name = "HPLabel"
	hp_lbl.text = "80/80"
	hp_lbl.position = Vector2(-hp_bar_width / 2.0, 130 - 3)  # Center 18px label on 12px bar
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_lbl.custom_minimum_size = Vector2(hp_bar_width, 18)
	hp_lbl.add_theme_font_size_override("font_size", 14)
	hp_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	hp_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	hp_lbl.add_theme_constant_override("shadow_offset_x", 1)
	hp_lbl.add_theme_constant_override("shadow_offset_y", 1)
	hp_lbl.z_index = 5
	entity.add_child(hp_lbl)

	# Block label — STS style: grey shield badge left of HP bar
	var block_lbl = Label.new()
	block_lbl.name = "BlockLabel"
	block_lbl.text = "0"
	block_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	block_lbl.position = Vector2(-hp_bar_width - 8, 130)  # Left of HP bar
	block_lbl.size = Vector2(40, 32)
	block_lbl.add_theme_font_size_override("font_size", 18)
	block_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	block_lbl.visible = false
	entity.add_child(block_lbl)

	# Status container BELOW HP bar
	var status_cont = HBoxContainer.new()
	status_cont.name = "StatusContainer"
	status_cont.position = Vector2(-50, 150)
	entity.add_child(status_cont)

	if is_enemy_entity:
		# Intent icon above enemy
		var intent_icon = TextureRect.new()
		intent_icon.name = "IntentIcon"
		intent_icon.custom_minimum_size = Vector2(64, 64)
		intent_icon.position = Vector2(-32, -200)
		intent_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		intent_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		intent_icon.visible = false
		entity.add_child(intent_icon)

		# Intent description — larger, positioned above sprite
		var intent_lbl = Label.new()
		intent_lbl.name = "IntentLabel"
		intent_lbl.text = ""
		intent_lbl.position = Vector2(-70, -220)
		intent_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		intent_lbl.custom_minimum_size = Vector2(140, 20)
		intent_lbl.add_theme_font_size_override("font_size", 16)
		intent_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.6))
		intent_lbl.visible = false
		entity.add_child(intent_lbl)

		# Click area for enemy targeting (invisible clickable region)
		var click_area = Area2D.new()
		click_area.name = "ClickArea"
		click_area.input_pickable = true
		var click_shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(240, 400)
		click_shape.shape = rect_shape
		click_area.add_child(click_shape)
		click_area.input_event.connect(_on_enemy_click_area_input.bind(entity))
		entity.add_child(click_area)

	return entity

func _build_deck(character_id: String, gm: Node) -> void:
	draw_pile.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	var deck_ids: Array = gm.player_deck if not gm.player_deck.is_empty() else gm.get_starting_deck(character_id)
	for card_id in deck_ids:
		var data: Dictionary
		if card_id.ends_with("+"):
			# Upgraded card
			var base_id = card_id.trim_suffix("+")
			data = gm.get_upgraded_card(base_id)
		else:
			data = gm.get_card_data(card_id)
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

	# Berserk: +1 energy per turn
	if berserk_active:
		current_energy += 1

	# Power effects at start of turn
	if demon_form_active and player and player.alive:
		player.apply_status("strength", 2)

	# Reset player block (unless Barricade is active)
	if player and not barricade_active:
		player.reset_block()

	# Reset flame barrier each turn (it's per-turn)
	flame_barrier_active = false

	# Reset rage each turn
	rage_active = false

	# Draw cards
	draw_cards(cards_per_draw)
	_update_energy_label()
	_update_pile_labels()
	if turn_label:
		var loc = _get_loc()
		if loc:
			turn_label.text = loc.t("your_turn")
		else:
			turn_label.text = "Your Turn"
		turn_label.add_theme_color_override("font_color", Color(0.27, 0.8, 0.4))
	if end_turn_btn:
		end_turn_btn.disabled = false
	_show_turn_banner("YOUR TURN", Color(0.27, 0.8, 0.4))
	if card_hand:
		card_hand.current_battle_energy = current_energy
		card_hand.update_card_playability(current_energy)
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
		# Evolve: draw extra on Status draw
		if evolve_active and card_data.get("type", 0) == 3:  # STATUS type
			draw_cards(1)
	_update_pile_labels()

func _reshuffle_discard() -> void:
	draw_pile = discard_pile.duplicate()
	discard_pile.clear()
	draw_pile.shuffle()

func _can_play_card(card_data: Dictionary) -> bool:
	# Unplayable cards (status cards)
	if card_data.get("unplayable", false):
		return false
	# Clash: only playable if all cards in hand are attacks
	if card_data.get("special", "") == "clash":
		for c in hand:
			if c.get("type", 0) != 0:  # Not ATTACK
				return false
	return true

func play_card(card_data: Dictionary, target: Node2D) -> void:
	if not battle_active or not is_player_turn:
		return

	# Check if card can be played
	if not _can_play_card(card_data):
		return

	# Handle X-cost cards (Whirlwind)
	var cost: int = card_data.get("cost", 0)
	if cost == -1:  # X cost
		cost = current_energy  # Spend all energy
	elif cost < 0:
		return  # Unplayable (status cards use -2)

	# Corruption: Skills cost 0
	if corruption_active and card_data.get("type", 0) == 1:  # SKILL
		cost = 0

	if current_energy < cost:
		return
	current_energy -= cost
	_update_energy_label()
	if card_hand:
		card_hand.current_battle_energy = current_energy
		card_hand.update_card_playability(current_energy)

	# Remove from hand tracking
	for i in range(hand.size()):
		if hand[i].get("id", "") == card_data.get("id", ""):
			hand.remove_at(i)
			break

	# Execute card effect (pass energy spent for X-cost cards)
	_execute_card(card_data, target, cost)

	# Rage: gain block when playing attacks
	if rage_active and card_data.get("type", 0) == 0 and player:  # ATTACK
		player.add_block(rage_block)
		_trigger_juggernaut()

	# Determine where the card goes after play
	var card_type: int = card_data.get("type", 0)
	var should_exhaust: bool = card_data.get("exhaust", false)

	# Corruption: Skills are exhausted
	if corruption_active and card_type == 1:  # SKILL
		should_exhaust = true

	if card_type == 2:  # POWER — always exhaust
		exhaust_pile.append(card_data)
	elif should_exhaust:
		_exhaust_card(card_data)
	else:
		discard_pile.append(card_data)

	_update_pile_labels()
	# Check win condition
	_check_battle_end()

func _exhaust_card(card_data: Dictionary) -> void:
	exhaust_pile.append(card_data)
	# Feel No Pain: gain block on exhaust
	if feel_no_pain_active and player and player.alive:
		player.add_block(feel_no_pain_block)
		_trigger_juggernaut()

func _trigger_juggernaut() -> void:
	if juggernaut_active and player and player.alive:
		var alive_enemies: Array = []
		for e in enemies:
			if e.alive:
				alive_enemies.append(e)
		if not alive_enemies.is_empty():
			var random_enemy = alive_enemies[randi() % alive_enemies.size()]
			random_enemy.take_damage(juggernaut_damage)

func _get_alive_enemies() -> Array:
	var alive: Array = []
	for e in enemies:
		if e.alive:
			alive.append(e)
	return alive

func _execute_card(card_data: Dictionary, target: Node2D, energy_spent: int = 0) -> void:
	var damage: int = card_data.get("damage", 0)
	var block_val: int = card_data.get("block", 0)
	var draw_count: int = card_data.get("draw", 0)
	var target_type: String = card_data.get("target", "enemy")
	var special: String = card_data.get("special", "")
	var times: int = card_data.get("times", 1)

	# ---- Handle specials that modify damage or have unique behavior ----

	match special:
		"body_slam":
			if player:
				damage = player.block
		"heavy_blade":
			# Strength applies x3 instead of x1
			if player:
				var str_val: int = player.get_status_stacks("strength")
				# Base damage + strength * 3 (instead of normal +strength)
				damage = card_data.get("damage", 14) + str_val * 3
				# Skip normal strength application below
				times = 1
				_deal_damage_to_target(damage, target, target_type, false)
				# Handle block/draw/status after
				_apply_block_and_draw(block_val, draw_count, card_data)
				return
		"hemokinesis":
			if player:
				player.take_damage_direct(2)
		"whirlwind":
			# Deal damage X times where X = energy spent
			times = energy_spent
		"dropkick":
			if target and target.alive and target.get_status_stacks("vulnerable") > 0:
				current_energy += 1
				_update_energy_label()
				draw_count += 1
		"bloodletting":
			if player:
				player.take_damage_direct(3)
				current_energy += 2
				_update_energy_label()
		"flex":
			if player:
				player.apply_status("strength", 2)
				flex_strength_to_remove += 2
		"limit_break":
			if player:
				var str_val: int = player.get_status_stacks("strength")
				if str_val > 0:
					player.apply_status("strength", str_val)
		"entrench":
			if player:
				var current_block: int = player.block
				player.add_block(current_block)
				_trigger_juggernaut()
		"offering":
			if player:
				player.take_damage_direct(6)
				current_energy += 2
				_update_energy_label()
				draw_count = 3
		"second_wind":
			if player:
				var cards_to_exhaust: Array = []
				for c in hand:
					if c.get("type", 0) != 0:  # Not ATTACK
						cards_to_exhaust.append(c)
				for c in cards_to_exhaust:
					hand.erase(c)
					_exhaust_card(c)
					player.add_block(5)
					_trigger_juggernaut()
				if card_hand:
					card_hand.clear_hand()
					for c in hand:
						card_hand.add_card(c)
		"clash":
			pass  # Playability check already handled in _can_play_card
		"perfected_strike":
			# Count all "Strike" cards in draw + discard + hand + exhaust
			var strike_count: int = 0
			for c in draw_pile:
				if "Strike" in c.get("name", ""):
					strike_count += 1
			for c in discard_pile:
				if "Strike" in c.get("name", ""):
					strike_count += 1
			for c in hand:
				if "Strike" in c.get("name", ""):
					strike_count += 1
			for c in exhaust_pile:
				if "Strike" in c.get("name", ""):
					strike_count += 1
			# +1 for the Perfected Strike itself (already counted if name contains Strike)
			damage = card_data.get("damage", 6) + strike_count * 2
		"fiend_fire":
			# Exhaust entire hand, deal 7 per card
			var cards_in_hand: int = hand.size()
			var cards_to_exhaust: Array = hand.duplicate()
			for c in cards_to_exhaust:
				hand.erase(c)
				_exhaust_card(c)
			if card_hand:
				card_hand.clear_hand()
			damage = card_data.get("damage", 7) * cards_in_hand
			times = 1  # All damage in one hit
		"reaper":
			# Deal damage to all, heal for unblocked
			if player:
				var actual_dmg: int = player.get_attack_damage(damage)
				var total_healed: int = 0
				for enemy in enemies:
					if enemy.alive:
						var before_hp: int = enemy.current_hp
						var enemy_block: int = enemy.block
						enemy.take_damage(actual_dmg)
						var damage_dealt: int = mini(actual_dmg, before_hp + enemy_block) - enemy_block
						if damage_dealt > 0:
							total_healed += damage_dealt
				if total_healed > 0:
					player.heal(total_healed)
			_apply_block_and_draw(block_val, draw_count, card_data)
			return
		"anger":
			# Add a copy of Anger to discard pile
			var gm = _get_game_manager()
			if gm:
				var anger_copy = gm.get_card_data("ic_anger")
				if not anger_copy.is_empty():
					discard_pile.append(anger_copy)
		"wild_strike":
			# Shuffle a Wound into draw pile
			_add_status_card_to_draw("status_wound")
		"reckless_charge":
			# Shuffle a Dazed into draw pile
			_add_status_card_to_draw("status_dazed")
		"immolate":
			# Add a Burn to discard pile
			_add_status_card_to_discard("status_burn")
		"power_through":
			# Add 2 Wounds to hand
			_add_status_card_to_hand("status_wound")
			_add_status_card_to_hand("status_wound")
		"infernal_blade":
			# Add a random Attack card to hand, cost 0
			var gm = _get_game_manager()
			if gm:
				var attack_ids: Array = []
				for key in gm.card_database:
					var c = gm.card_database[key]
					if c.get("character", "") == "ironclad" and c.get("type", 0) == 0:  # ATTACK
						attack_ids.append(key)
				if not attack_ids.is_empty():
					var rand_id = attack_ids[randi() % attack_ids.size()]
					var new_card = gm.get_card_data(rand_id)
					new_card["cost"] = 0
					hand.append(new_card)
					if card_hand:
						card_hand.add_card(new_card)
		"dual_wield":
			# Copy first Attack or Power in hand
			for c in hand:
				var ctype = c.get("type", 0)
				if ctype == 0 or ctype == 2:  # ATTACK or POWER
					var copy = c.duplicate()
					hand.append(copy)
					if card_hand:
						card_hand.add_card(copy)
					break
		"burning_pact":
			# Exhaust a random non-this card from hand (simplified)
			if not hand.is_empty():
				var idx = randi() % hand.size()
				var exhausted = hand[idx]
				hand.remove_at(idx)
				_exhaust_card(exhausted)
				if card_hand:
					card_hand.clear_hand()
					for c in hand:
						card_hand.add_card(c)

	# Apply damage with multi-hit support
	if damage > 0 and special != "reaper" and special != "heavy_blade":
		var actual_dmg: int = damage
		if player and special != "fiend_fire" and special != "perfected_strike":
			actual_dmg = player.get_attack_damage(damage)
		elif player and (special == "perfected_strike"):
			# Perfected Strike: add strength once to total
			var str_val: int = player.get_status_stacks("strength")
			actual_dmg = damage + str_val

		if times > 1:
			# Multi-hit: use tween delays so each damage number appears separately
			_apply_multi_hit_damage(actual_dmg, times, target, target_type)
		else:
			_apply_single_hit_damage(actual_dmg, target, target_type)

	# Apply block and draw
	_apply_block_and_draw(block_val, draw_count, card_data)

	# Apply status to target
	if card_data.has("apply_status"):
		var status_info = card_data["apply_status"]
		if target_type == "all_enemies":
			for enemy in enemies:
				if enemy.alive:
					enemy.apply_status(status_info["type"], status_info["stacks"])
		elif target != null and target.alive:
			target.apply_status(status_info["type"], status_info["stacks"])

	# Apply second status (e.g., Uppercut applies both Weak + Vulnerable)
	if card_data.has("apply_status_2"):
		var status_info = card_data["apply_status_2"]
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

	# Power effects
	if card_data.has("power_effect"):
		_activate_power(card_data["power_effect"])

func _apply_single_hit_damage(dmg: int, target: Node2D, target_type: String) -> void:
	if target_type == "all_enemies":
		for enemy in enemies:
			if enemy.alive:
				enemy.take_damage(dmg)
	elif target_type == "random_enemy":
		var alive = _get_alive_enemies()
		if not alive.is_empty():
			var rand_target = alive[randi() % alive.size()]
			rand_target.take_damage(dmg)
	elif target != null and target.alive:
		target.take_damage(dmg)

func _apply_multi_hit_damage(dmg: int, hit_count: int, target: Node2D, target_type: String) -> void:
	# First hit immediately
	_apply_single_hit_damage(dmg, target, target_type)
	# Remaining hits with 0.3s delays using tween
	if hit_count > 1:
		var hit_tween = create_tween()
		for i in range(1, hit_count):
			hit_tween.tween_interval(0.3)
			hit_tween.tween_callback(_apply_single_hit_damage.bind(dmg, target, target_type))

func _apply_block_and_draw(block_val: int, draw_count: int, card_data: Dictionary) -> void:
	if block_val > 0 and player:
		player.add_block(block_val)
		_trigger_juggernaut()
	if draw_count > 0:
		draw_cards(draw_count)

func _activate_power(power_name: String) -> void:
	match power_name:
		"demon_form":
			demon_form_active = true
		"caltrops":
			caltrops_active = true
		"envenom":
			envenom_active = true
		"flame_barrier":
			flame_barrier_active = true
		"corruption":
			corruption_active = true
			if card_hand:
				card_hand.corruption_active = true
		"berserk":
			berserk_active = true
			# Apply 1 Vulnerable to self
			if player:
				player.apply_status("vulnerable", 1)
		"feel_no_pain":
			feel_no_pain_active = true
		"juggernaut":
			juggernaut_active = true
		"evolve":
			evolve_active = true
		"rage":
			rage_active = true
		"barricade":
			barricade_active = true
		"metallicize":
			metallicize_active = true

func _add_status_card_to_draw(card_id: String) -> void:
	var gm = _get_game_manager()
	if gm:
		var card = gm.get_card_data(card_id)
		if not card.is_empty():
			draw_pile.insert(randi() % maxi(draw_pile.size(), 1), card)

func _add_status_card_to_discard(card_id: String) -> void:
	var gm = _get_game_manager()
	if gm:
		var card = gm.get_card_data(card_id)
		if not card.is_empty():
			discard_pile.append(card)

func _add_status_card_to_hand(card_id: String) -> void:
	var gm = _get_game_manager()
	if gm:
		var card = gm.get_card_data(card_id)
		if not card.is_empty():
			hand.append(card)
			if card_hand:
				card_hand.add_card(card)

func _deal_damage_to_target(damage: int, target: Node2D, target_type: String, use_strength: bool = true) -> void:
	if damage <= 0:
		return
	var actual_dmg: int = damage
	if target_type == "all_enemies":
		for enemy in enemies:
			if enemy.alive:
				enemy.take_damage(actual_dmg)
	elif target != null and target.alive:
		target.take_damage(actual_dmg)

func end_player_turn() -> void:
	if not battle_active or not is_player_turn:
		return
	is_player_turn = false
	if end_turn_btn:
		end_turn_btn.disabled = true

	# Remove Flex temp strength
	if flex_strength_to_remove > 0 and player:
		player.apply_status("strength", -flex_strength_to_remove)
		flex_strength_to_remove = 0

	# Metallicize: gain block at end of turn
	if metallicize_active and player and player.alive:
		player.add_block(metallicize_block)
		_trigger_juggernaut()

	# Process end-of-turn damage from status cards in hand (Burn)
	for card_data in hand:
		if card_data.get("end_turn_damage", 0) > 0 and player:
			player.take_damage_direct(card_data["end_turn_damage"])

	# Exhaust ethereal cards (Dazed)
	var ethereal_cards: Array = []
	for card_data in hand:
		if card_data.get("ethereal", false):
			ethereal_cards.append(card_data)
	for card_data in ethereal_cards:
		hand.erase(card_data)
		_exhaust_card(card_data)

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
		var loc = _get_loc()
		if loc:
			turn_label.text = loc.t("enemy_turn")
		else:
			turn_label.text = "Enemy Turn"
		turn_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_show_turn_banner("ENEMY TURN", Color(1.0, 0.3, 0.3))
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
					_screen_shake()
					# Flame Barrier: deal damage back when attacked
					if flame_barrier_active and enemy.alive:
						enemy.take_damage(flame_barrier_damage)
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
			_screen_shake()
			enemy.add_block(blk)
			if flame_barrier_active and enemy.alive:
				enemy.take_damage(flame_barrier_damage)
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
			_screen_shake()
			player.apply_status(status_name, stacks)
			if flame_barrier_active and enemy.alive:
				enemy.take_damage(flame_barrier_damage)
			if caltrops_active and enemy.alive:
				enemy.take_damage(3)

func _end_enemy_turn() -> void:
	if not battle_active:
		return
	_check_battle_end()
	if battle_active:
		start_player_turn()

func _on_card_played(card_data: Dictionary, target: Node2D) -> void:
	_clear_damage_previews()
	_clear_all_enemy_highlights()
	_hovered_enemy = null
	if _targeting_arrow:
		_targeting_arrow.hide_arrow()
		_targeting_arrow.visible = false
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
		var loc = _get_loc()
		if loc:
			turn_label.text = loc.t("defeat")
		else:
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
			var loc2 = _get_loc()
			if loc2:
				turn_label.text = loc2.t("victory")
			else:
				turn_label.text = "VICTORY!"
			turn_label.add_theme_font_size_override("font_size", 48)
			turn_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))

func _update_energy_label() -> void:
	if energy_label:
		energy_label.text = str(current_energy) + "/" + str(max_energy)

func _update_pile_labels() -> void:
	var loc = _get_loc()
	if draw_pile_label:
		if loc:
			draw_pile_label.text = loc.tf("draw_pile", [draw_pile.size()])
		else:
			draw_pile_label.text = "Draw: " + str(draw_pile.size())
	if discard_label:
		if loc:
			discard_label.text = loc.tf("discard_pile", [discard_pile.size()])
		else:
			discard_label.text = "Discard: " + str(discard_pile.size())

var _hovered_enemy: Node2D = null
var _targeting_arrow: Node2D = null  # TargetingArrow (chain-style bezier)

func _process(_delta: float) -> void:
	if not battle_active or not is_player_turn:
		if _targeting_arrow:
			_targeting_arrow.hide_arrow()
		_clear_damage_previews()
		return
	# Update targeting arrow and enemy hover highlight during tap-to-select targeting
	if card_hand and card_hand.is_targeting() and card_hand.selected_card:
		var card_data: Dictionary = card_hand.get_selected_card_data()
		var target_type: String = card_data.get("target", "enemy")
		# Draw chain-style targeting arrow from card to mouse
		if _targeting_arrow and target_type == "enemy":
			var card_pos: Vector2 = card_hand.selected_card.global_position + Vector2(160, 215)
			var mouse_pos_arrow: Vector2 = get_viewport().get_mouse_position()
			_targeting_arrow.update_arrow(card_pos, mouse_pos_arrow)
			_targeting_arrow.visible = true
		elif _targeting_arrow and target_type != "enemy":
			_targeting_arrow.hide_arrow()
			_targeting_arrow.visible = false
		if target_type == "enemy":
			var mouse_pos: Vector2 = get_viewport().get_mouse_position()
			var hover_enemy = _get_enemy_at(mouse_pos)
			if hover_enemy != _hovered_enemy:
				_clear_enemy_highlight()
				_hovered_enemy = hover_enemy
				if _hovered_enemy:
					_highlight_enemy(_hovered_enemy)
			# Show damage previews for attack cards
			if _damage_preview_labels.is_empty():
				_show_damage_previews()
		elif target_type == "all_enemies":
			# Highlight all enemies
			if _hovered_enemy == null:
				for enemy in enemies:
					if enemy.alive:
						_highlight_enemy(enemy)
				if not enemies.is_empty():
					_hovered_enemy = enemies[0]  # marker
			# Show damage previews
			if _damage_preview_labels.is_empty():
				_show_damage_previews()
	else:
		if _hovered_enemy != null:
			_clear_all_enemy_highlights()
			_hovered_enemy = null
		if _targeting_arrow:
			_targeting_arrow.hide_arrow()
			_targeting_arrow.visible = false
		_clear_damage_previews()

func _unhandled_input(event: InputEvent) -> void:
	if not battle_active or not is_player_turn:
		return
	# Right click to cancel any targeting
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if card_hand and card_hand.is_targeting():
			if card_hand.selected_card:
				card_hand.selected_card.set_selected(false)
			card_hand.selected_card = null
			card_hand.targeting_mode = false
			_clear_all_enemy_highlights()
			_clear_damage_previews()
			_hovered_enemy = null
			card_hand.update_layout()
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_on_end_turn()

func _on_card_tap_play(card_node: Area2D) -> void:
	# Handle quick-tap for non-targeted cards (self/all_enemies)
	if not battle_active or not is_player_turn:
		return
	var card_data: Dictionary = card_node.card_data
	var target_type: String = card_data.get("target", "enemy")
	if target_type == "self" and player:
		card_hand.play_selected_on(player)
	elif target_type == "all_enemies" and not enemies.is_empty():
		card_hand.play_selected_on(enemies[0])

func _on_card_drag_released(card_node: Area2D, release_position: Vector2) -> void:
	# Handle drag release — check if released over an enemy
	if not battle_active or not is_player_turn:
		return
	_clear_damage_previews()
	_clear_all_enemy_highlights()
	_hovered_enemy = null
	if _targeting_arrow:
		_targeting_arrow.hide_arrow()
		_targeting_arrow.visible = false
	var target_enemy = _get_enemy_at(release_position)
	if target_enemy and target_enemy.alive:
		# Play card on this enemy
		card_hand.play_card_on(card_node, target_enemy)
	else:
		# No valid target — snap card back to hand
		if card_node and is_instance_valid(card_node):
			card_node.set_selected(false)
		card_hand.selected_card = null
		card_hand.targeting_mode = false
		card_hand.update_layout()

func _highlight_enemy(enemy: Node2D) -> void:
	enemy.modulate = Color(1.2, 1.2, 1.0)  # Bright warm highlight on hover

func _clear_enemy_highlight() -> void:
	if _hovered_enemy and is_instance_valid(_hovered_enemy):
		_hovered_enemy.modulate = Color.WHITE

func _clear_all_enemy_highlights() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.modulate = Color.WHITE

func _get_enemy_at(screen_pos: Vector2) -> Node2D:
	if enemy_area == null:
		return null
	for enemy in enemies:
		if not enemy.alive:
			continue
		var enemy_global_pos: Vector2 = enemy_area.position + enemy.position
		var rect = Rect2(enemy_global_pos - Vector2(120, 200), Vector2(240, 400))
		if rect.has_point(screen_pos):
			return enemy
	return null

# ---- Enemy click handling for tap-to-select targeting ----

func _on_enemy_click_area_input(_viewport: Node, event: InputEvent, _shape_idx: int, enemy_entity: Node2D) -> void:
	if not battle_active or not is_player_turn:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if card_hand and card_hand.is_targeting() and card_hand.selected_card:
			var card_data: Dictionary = card_hand.get_selected_card_data()
			var target_type: String = card_data.get("target", "enemy")
			if target_type == "enemy" and enemy_entity.alive:
				_clear_damage_previews()
				_clear_all_enemy_highlights()
				_hovered_enemy = null
				if _targeting_arrow:
					_targeting_arrow.hide_arrow()
					_targeting_arrow.visible = false
				card_hand.play_card_on(card_hand.selected_card, enemy_entity)

# ---- Card Detail Overlay (long-press) ----

func _setup_card_detail_overlay() -> void:
	var hud_layer = get_node_or_null("HUDLayer")
	if hud_layer == null:
		return
	_card_detail_overlay = Control.new()
	_card_detail_overlay.name = "CardDetailOverlay"
	_card_detail_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_detail_overlay.visible = false
	_card_detail_overlay.z_index = 500
	_card_detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# Semi-transparent dark background
	var bg = ColorRect.new()
	bg.name = "DarkBG"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_detail_overlay.add_child(bg)

	# Large card image centered
	var card_img = TextureRect.new()
	card_img.name = "DetailCardImage"
	card_img.custom_minimum_size = Vector2(500, 670)
	card_img.size = Vector2(500, 670)
	card_img.position = Vector2((1920 - 500) / 2.0, (1080 - 670) / 2.0)
	card_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_img.stretch_mode = TextureRect.STRETCH_SCALE
	card_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_detail_overlay.add_child(card_img)

	# Tap anywhere to dismiss
	_card_detail_overlay.gui_input.connect(_on_detail_overlay_input)
	hud_layer.add_child(_card_detail_overlay)

func _on_detail_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_card_detail_overlay.visible = false

func _on_card_long_press_detail(card_node: Area2D) -> void:
	if _card_detail_overlay == null:
		return
	var card_data_dict: Dictionary = card_node.card_data
	var card_id: String = card_data_dict.get("id", "")
	# Use the card's own STS image if it has one
	var sts_path: String = ""
	if card_node.sts_card_image and card_node.sts_card_image.texture:
		var detail_img = _card_detail_overlay.get_node_or_null("DetailCardImage") as TextureRect
		if detail_img:
			detail_img.texture = card_node.sts_card_image.texture
		_card_detail_overlay.visible = true
		return
	# Fallback: try loading via static map
	var card_script_class = load("res://scripts/card.gd")
	sts_path = card_script_class._get_sts_card_path(card_id)
	var detail_img = _card_detail_overlay.get_node_or_null("DetailCardImage") as TextureRect
	if detail_img and sts_path != "" and ResourceLoader.exists(sts_path):
		detail_img.texture = load(sts_path)
	_card_detail_overlay.visible = true

# ---- Damage Preview ----

func _show_damage_previews() -> void:
	_clear_damage_previews()
	if card_hand == null or not card_hand.is_targeting() or card_hand.selected_card == null:
		return
	var card_data: Dictionary = card_hand.get_selected_card_data()
	var damage: int = card_data.get("damage", 0)
	if damage <= 0:
		return
	var target_type: String = card_data.get("target", "enemy")
	if target_type != "enemy" and target_type != "all_enemies":
		return
	# Calculate actual damage with player strength and weak
	var actual_dmg: int = damage
	if player:
		actual_dmg = player.get_attack_damage(damage)
	# Show preview labels above enemies
	for enemy in enemies:
		if not enemy.alive:
			continue
		var preview_lbl = Label.new()
		preview_lbl.text = str(actual_dmg)
		preview_lbl.add_theme_font_size_override("font_size", 28)
		preview_lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		preview_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		preview_lbl.add_theme_constant_override("shadow_offset_x", 1)
		preview_lbl.add_theme_constant_override("shadow_offset_y", 2)
		preview_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		preview_lbl.custom_minimum_size = Vector2(80, 30)
		# Position above enemy sprite
		var enemy_global = enemy_area.position + enemy.position if enemy_area else enemy.position
		preview_lbl.position = Vector2(enemy_global.x - 40, enemy_global.y - 260)
		# Add to HUD layer so it's on top
		var hud_layer = get_node_or_null("HUDLayer")
		if hud_layer:
			hud_layer.add_child(preview_lbl)
			_damage_preview_labels.append(preview_lbl)

func _clear_damage_previews() -> void:
	for lbl in _damage_preview_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	_damage_preview_labels.clear()

# ---- Turn Banner Animation ----

func _setup_turn_banner() -> void:
	var hud_ctrl = get_node_or_null("HUDLayer/HUD")
	if hud_ctrl == null:
		return
	_turn_banner = Label.new()
	_turn_banner.name = "TurnBanner"
	_turn_banner.text = ""
	_turn_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_turn_banner.custom_minimum_size = Vector2(600, 100)
	_turn_banner.size = Vector2(600, 100)
	_turn_banner.position = Vector2(660, 490)
	_turn_banner.add_theme_font_size_override("font_size", 56)
	_turn_banner.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_turn_banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_turn_banner.add_theme_constant_override("shadow_offset_x", 2)
	_turn_banner.add_theme_constant_override("shadow_offset_y", 3)
	_turn_banner.modulate = Color(1, 1, 1, 0)
	_turn_banner.visible = false
	_turn_banner.z_index = 400
	_turn_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_ctrl.add_child(_turn_banner)

func _show_turn_banner(text: String, color: Color) -> void:
	if _turn_banner == null:
		return
	_turn_banner.text = text
	_turn_banner.add_theme_color_override("font_color", color)
	_turn_banner.visible = true
	_turn_banner.modulate = Color(1, 1, 1, 0)
	_turn_banner.scale = Vector2(0.8, 0.8)
	_turn_banner.pivot_offset = Vector2(300, 50)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_turn_banner, "modulate", Color(1, 1, 1, 1), 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(_turn_banner, "scale", Vector2(1.0, 1.0), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.set_parallel(false)
	tween.tween_interval(0.8)
	tween.tween_property(_turn_banner, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_callback(func(): _turn_banner.visible = false)

# ---- Screen Shake ----

func _screen_shake(intensity: float = 8.0, duration: float = 0.15) -> void:
	var original_pos: Vector2 = position
	var tween = create_tween()
	var steps: int = 4
	var step_dur: float = duration / float(steps)
	for i in range(steps):
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(self, "position", original_pos + offset, step_dur)
	tween.tween_property(self, "position", original_pos, step_dur)

# ---- Pile Viewer ----

func _setup_pile_viewer() -> void:
	var hud_ctrl = get_node_or_null("HUDLayer/HUD")
	if hud_ctrl == null:
		return
	_pile_viewer = Control.new()
	_pile_viewer.name = "PileViewer"
	_pile_viewer.size = Vector2(1920, 1080)
	_pile_viewer.visible = false
	_pile_viewer.z_index = 500
	_pile_viewer.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_ctrl.add_child(_pile_viewer)

	# Dark background
	var bg = ColorRect.new()
	bg.name = "BG"
	bg.size = Vector2(1920, 1080)
	bg.color = Color(0, 0, 0, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_pile_viewer_bg_clicked)
	_pile_viewer.add_child(bg)

	# Title
	var title = Label.new()
	title.name = "Title"
	title.position = Vector2(0, 20)
	title.size = Vector2(1920, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 1, 0.8))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pile_viewer.add_child(title)

	# Close button (X) top-right
	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "X"
	close_btn.position = Vector2(1920 - 80, 15)
	close_btn.custom_minimum_size = Vector2(50, 50)
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	var close_sb = StyleBoxFlat.new()
	close_sb.bg_color = Color(0.5, 0.1, 0.1, 0.9)
	close_sb.corner_radius_top_left = 8
	close_sb.corner_radius_top_right = 8
	close_sb.corner_radius_bottom_left = 8
	close_sb.corner_radius_bottom_right = 8
	close_btn.add_theme_stylebox_override("normal", close_sb)
	var close_hover = close_sb.duplicate() as StyleBoxFlat
	close_hover.bg_color = Color(0.7, 0.15, 0.15, 0.95)
	close_btn.add_theme_stylebox_override("hover", close_hover)
	close_btn.pressed.connect(func(): _pile_viewer.visible = false)
	_pile_viewer.add_child(close_btn)

	# Scroll container for card grid
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.position = Vector2(60, 80)
	scroll.size = Vector2(1800, 940)
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_pile_viewer.add_child(scroll)

	var grid = GridContainer.new()
	grid.name = "CardGrid"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

func _on_draw_pile_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_pile_viewer("抽牌堆", draw_pile)

func _on_discard_pile_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_pile_viewer("弃牌堆", discard_pile)

func _on_pile_viewer_bg_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_pile_viewer.visible = false

func _show_pile_viewer(title: String, pile: Array) -> void:
	if _pile_viewer == null:
		return
	_pile_viewer.visible = true

	# Set title
	var title_label_node = _pile_viewer.get_node_or_null("Title") as Label
	if title_label_node:
		title_label_node.text = "%s (%d张)" % [title, pile.size()]

	# Clear old cards
	var grid = _pile_viewer.get_node_or_null("Scroll/CardGrid") as GridContainer
	if grid == null:
		return
	for c in grid.get_children():
		c.queue_free()

	# Sort cards by type then name
	var sorted_pile = pile.duplicate()
	sorted_pile.sort_custom(func(a, b):
		if a.get("type", 0) != b.get("type", 0):
			return a.get("type", 0) < b.get("type", 0)
		return a.get("name", "") < b.get("name", "")
	)

	var loc = _get_loc()
	var mini_size := Vector2(200, 270)

	# Add each card as a mini card visual in the grid
	for cd in sorted_pile:
		var card_panel = Panel.new()
		card_panel.custom_minimum_size = mini_size
		card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var card_type: int = cd.get("type", 0)
		var bg_color: Color
		var border_color: Color
		var type_name: String
		match card_type:
			0:
				bg_color = Color(0.25, 0.08, 0.08, 0.95)
				border_color = Color(0.8, 0.2, 0.2, 1.0)
				type_name = "攻击"
			1:
				bg_color = Color(0.08, 0.18, 0.08, 0.95)
				border_color = Color(0.2, 0.7, 0.3, 1.0)
				type_name = "技能"
			2:
				bg_color = Color(0.12, 0.08, 0.22, 0.95)
				border_color = Color(0.4, 0.3, 0.9, 1.0)
				type_name = "能力"
			_:
				bg_color = Color(0.15, 0.15, 0.15, 0.95)
				border_color = Color(0.5, 0.5, 0.5, 1.0)
				type_name = "状态"

		var sb = StyleBoxFlat.new()
		sb.bg_color = bg_color
		sb.border_color = border_color
		sb.border_width_left = 3
		sb.border_width_right = 3
		sb.border_width_top = 3
		sb.border_width_bottom = 3
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		card_panel.add_theme_stylebox_override("panel", sb)

		# Cost (top-left)
		var cost_val: int = cd.get("cost", 0)
		var cost_lbl = Label.new()
		cost_lbl.text = str(cost_val) if cost_val >= 0 else "X"
		cost_lbl.position = Vector2(8, 4)
		cost_lbl.add_theme_font_size_override("font_size", 20)
		cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_panel.add_child(cost_lbl)

		# Name (centered)
		var card_name: String = cd.get("name", "?")
		if loc and loc.has_method("card_name"):
			card_name = loc.card_name(cd)
		var name_lbl = Label.new()
		name_lbl.text = card_name
		name_lbl.position = Vector2(6, 30)
		name_lbl.size = Vector2(mini_size.x - 12, 28)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9))
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_panel.add_child(name_lbl)

		# Type label
		var type_lbl = Label.new()
		type_lbl.text = type_name
		type_lbl.position = Vector2(6, 58)
		type_lbl.size = Vector2(mini_size.x - 12, 18)
		type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_lbl.add_theme_font_size_override("font_size", 11)
		type_lbl.add_theme_color_override("font_color", border_color)
		type_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_panel.add_child(type_lbl)

		# Stats
		var dmg: int = cd.get("damage", 0)
		var blk: int = cd.get("block", 0)
		var stat_text: String = ""
		if dmg > 0 and blk > 0:
			stat_text = "⚔ %d   🛡 %d" % [dmg, blk]
		elif dmg > 0:
			stat_text = "⚔ %d" % dmg
		elif blk > 0:
			stat_text = "🛡 %d" % blk
		if stat_text != "":
			var stat_lbl = Label.new()
			stat_lbl.text = stat_text
			stat_lbl.position = Vector2(6, 85)
			stat_lbl.size = Vector2(mini_size.x - 12, 30)
			stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stat_lbl.add_theme_font_size_override("font_size", 20)
			stat_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			stat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_panel.add_child(stat_lbl)

		# Description (bottom half, short)
		var desc: String = cd.get("description", "")
		if loc and loc.has_method("card_desc"):
			desc = loc.card_desc(cd)
		if desc != "":
			var desc_lbl = Label.new()
			desc_lbl.text = desc
			desc_lbl.position = Vector2(8, 125)
			desc_lbl.size = Vector2(mini_size.x - 16, mini_size.y - 135)
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_lbl.add_theme_font_size_override("font_size", 11)
			desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
			desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_panel.add_child(desc_lbl)

		grid.add_child(card_panel)
