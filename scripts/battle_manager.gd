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
		card_hand.card_drag_released.connect(_on_card_drag_released)
		card_hand.card_played_tap.connect(_on_card_tap_play)

	# STS-style chain targeting arrow — circles along bezier curve
	_targeting_arrow = preload("res://scripts/targeting_arrow.gd").new()
	_targeting_arrow.name = "TargetingArrow"
	_targeting_arrow.z_index = 200
	add_child(_targeting_arrow)

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

	end_turn_btn.add_theme_font_size_override("font_size", 20)
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
			# Scale to ~450px tall (large STS-like proportions)
			var tex_height: float = tex.get_height()
			if tex_height > 0:
				var scale_factor: float = 450.0 / tex_height
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
		"slime": {"name": "Slime", "hp": 30, "sprite": "res://assets/img/sts_sprites/enemy_slime_clean.png", "scale_h": 350.0},
		"cultist": {"name": "Cultist", "hp": 50, "sprite": "res://assets/img/sts_sprites/enemy_cultist_ref_clean.png", "scale_h": 400.0},
		"jaw_worm": {"name": "Jaw Worm", "hp": 44, "sprite": "res://assets/img/sts_sprites/enemy_jaw_worm_clean.png", "scale_h": 380.0},
		"guardian": {"name": "Guardian", "hp": 60, "sprite": "res://assets/img/sts_sprites/enemy_cultist_clean.png", "scale_h": 400.0}
	}
	var selected_enemies: Array = ["slime", "cultist", "jaw_worm"]
	for i in range(3):
		var etype: String = selected_enemies[i]
		var config = enemy_configs[etype]
		var enemy = _create_entity_node(true)
		enemy.init_entity(config["hp"], true, etype)
		# Horizontal spread, grounded at same level, slight stagger for depth
		var x_offsets = [0, 220, 440]
		var y_offsets = [0, -10, 10]  # Subtle stagger for depth
		enemy.position = Vector2(x_offsets[i], y_offsets[i])
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
	name_lbl.position = Vector2(-70, 100)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.custom_minimum_size = Vector2(140, 22)
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9))
	var name_bg = StyleBoxFlat.new()
	name_bg.bg_color = Color(0.1, 0.07, 0.03, 0.8)
	name_bg.corner_radius_top_left = 4
	name_bg.corner_radius_top_right = 4
	name_bg.corner_radius_bottom_left = 4
	name_bg.corner_radius_bottom_right = 4
	name_lbl.add_theme_stylebox_override("normal", name_bg)
	entity.add_child(name_lbl)

	# HP bar BELOW name — wider (140px), dark red bg, rounded feel
	var hp_bar_width: float = 140.0
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

	# HP label BELOW bar
	var hp_lbl = Label.new()
	hp_lbl.name = "HPLabel"
	hp_lbl.text = "80/80"
	hp_lbl.position = Vector2(-hp_bar_width / 2.0, 148)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.custom_minimum_size = Vector2(hp_bar_width, 18)
	hp_lbl.add_theme_font_size_override("font_size", 16)
	hp_lbl.add_theme_color_override("font_color", Color(0.949, 0.929, 0.847, 1.0))  # text_primary
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
		intent_icon.custom_minimum_size = Vector2(40, 40)
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
	var deck_ids: Array = gm.player_deck if gm.player_deck.size() > 0 else gm.get_starting_deck(character_id)
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
		if alive_enemies.size() > 0:
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
				if attack_ids.size() > 0:
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
			if hand.size() > 0:
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

		for _hit in range(times):
			if target_type == "all_enemies":
				for enemy in enemies:
					if enemy.alive:
						enemy.take_damage(actual_dmg)
			elif target_type == "random_enemy":
				var alive = _get_alive_enemies()
				if alive.size() > 0:
					var rand_target = alive[randi() % alive.size()]
					rand_target.take_damage(actual_dmg)
			elif target != null and target.alive:
				target.take_damage(actual_dmg)

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
		return
	# Update targeting arrow and enemy hover highlight during drag
	if card_hand and card_hand.is_targeting() and card_hand.selected_card:
		var card_data: Dictionary = card_hand.get_selected_card_data()
		var target_type: String = card_data.get("target", "enemy")
		# Draw chain-style targeting arrow from card origin to mouse during drag
		if _targeting_arrow and target_type == "enemy":
			var card_pos: Vector2 = card_hand.selected_card.global_position + Vector2(130, 175)
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
		if _targeting_arrow:
			_targeting_arrow.hide_arrow()
			_targeting_arrow.visible = false

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
			_hovered_enemy = null
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_on_end_turn()

func _on_card_drag_released(card_node: Area2D, release_position: Vector2) -> void:
	if not battle_active or not is_player_turn:
		return
	var card_data: Dictionary = card_node.card_data
	var target_type: String = card_data.get("target", "enemy")
	_clear_all_enemy_highlights()
	_hovered_enemy = null
	if _targeting_arrow:
		_targeting_arrow.hide_arrow()
		_targeting_arrow.visible = false

	if target_type == "enemy":
		var enemy_target = _get_enemy_at(release_position)
		if enemy_target:
			card_hand.selected_card = card_node
			card_hand.play_card_on(card_node, enemy_target)
		# else: dropped on nothing — card snaps back (layout update handles this)
	elif target_type == "self":
		if player:
			card_hand.selected_card = card_node
			card_hand.play_card_on(card_node, player)
	elif target_type == "all_enemies":
		if not enemies.is_empty():
			card_hand.selected_card = card_node
			card_hand.play_card_on(card_node, enemies[0])

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
		var rect = Rect2(enemy_global_pos - Vector2(120, 200), Vector2(240, 400))
		if rect.has_point(screen_pos):
			return enemy
	return null
