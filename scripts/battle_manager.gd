extends Node2D
## res://scripts/battle_manager.gd — Full battle loop: draw, play, enemy turn, win/lose

signal turn_started(is_player: bool)
signal turn_ended
signal card_played_signal(card_data: Dictionary, target: Node2D)
signal enemy_died(enemy_index: int)
signal player_died
signal battle_won

@export var max_energy: int = 3
@export var cards_per_draw: int = 10
@export var enemy_count: int = 1
@export var config_player_hp: int = 80
var config_enemy_hps: Array = [50, 50, 50]
var dual_hero_mode: bool = false
var second_character_id: String = ""
var second_player: Node2D = null  # Back-row hero (dual hero mode)
@export var player_sprite_scale_height: float = 400.0  ## Target height in pixels for player sprite
@export var enemy_sprite_scale_height: float = 350.0  ## Target height in pixels for enemy sprite
@export var damage_number_font_size: int = 36  ## Font size for floating damage numbers
@export var hp_bar_width: float = 180.0  ## Width of entity HP bars

# Entity template scene
var _entity_template: PackedScene = null

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
var infinite_blades_active: bool = false

# Temp effects (reset at end of turn)
var flex_strength_to_remove: int = 0
var anticipate_dex_to_remove: int = 0
var attacks_played_this_turn: int = 0

# Next-turn effect queue — processed at start of next player turn
var _next_turn_effects: Array = []  # List of dicts: {"type": "block", "value": 4}, etc.
var _blur_active: bool = false  # Block is not removed next turn
var _double_damage_next_turn: bool = false  # Phantasmal Killer
var _double_damage_this_turn: bool = false
var _burst_active: bool = false  # Next skill played twice
var _no_draw_next_turn: bool = false  # Bullet Time
var _bullet_time_this_turn: bool = false  # All cards cost 0 this turn

# Node refs
var card_hand: Node2D = null
var energy_label: Label = null
var draw_pile_label: Label = null
var discard_label: Label = null
var end_turn_btn: Button = null
var turn_label: Label = null
var player_area: Node2D = null
var enemy_area: Node2D = null
var draw_panel: Panel = null
var discard_panel: Panel = null

# Card detail overlay
var _card_detail_overlay: Control = null

# Pile viewer overlay
var _pile_viewer: Control = null

# Discard selection (in-hand mode)
var _discard_overlay: Control = null
var _discard_hand_bg: ColorRect = null  # Dark rect behind hand cards during discard
var _discard_selected_cards: Array = []  # indices into hand array
var _discard_required_count: int = 0
var _discard_callback: Callable
var _discard_confirm_btn: Button = null
var _discard_title_label: Label = null

# Damage preview labels
var _damage_preview_labels: Array = []

# Turn banner
var _turn_banner: Label = null

func _ready() -> void:
	# Preload entity template scene
	_entity_template = preload("res://scenes/entity_template.tscn")

	card_hand = get_node_or_null("CardHand")
	energy_label = get_node_or_null("HUDLayer/HUD/EnergyPanel/EnergyContainer/EnergyLabel")
	# Labels are now children of their Panel containers in the scene
	draw_panel = get_node_or_null("HUDLayer/HUD/DrawPanel") as Panel
	discard_panel = get_node_or_null("HUDLayer/HUD/DiscardPanel") as Panel
	draw_pile_label = get_node_or_null("HUDLayer/HUD/DrawPanel/DrawPileLabel")
	discard_label = get_node_or_null("HUDLayer/HUD/DiscardPanel/DiscardPileLabel")
	end_turn_btn = get_node_or_null("HUDLayer/HUD/EndTurnButton")
	turn_label = get_node_or_null("HUDLayer/HUD/TurnPanel/TurnLabel")
	player_area = get_node_or_null("PlayerArea")
	enemy_area = get_node_or_null("EnemyArea")

	# EndTurnButton — styling is now in the scene; just connect signal and set localized text
	if end_turn_btn:
		end_turn_btn.pressed.connect(_on_end_turn)
		var loc = _get_loc()
		if loc:
			end_turn_btn.text = loc.t("end_turn")

	# Connect draw/discard panel click signals (panels are pre-styled in scene)
	if draw_panel:
		draw_panel.gui_input.connect(_on_draw_pile_clicked)
	if discard_panel:
		discard_panel.gui_input.connect(_on_discard_pile_clicked)

	# Exit button — return to character select / deck builder
	var exit_btn = get_node_or_null("HUDLayer/HUD/ExitButton")
	if exit_btn:
		exit_btn.pressed.connect(_on_exit_battle)

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

	# Top status bar
	_setup_top_status_bar()
	# Pile viewer overlay
	_setup_pile_viewer()
	# Discard selection overlay
	_setup_discard_overlay()
	# Swap heroes button (dual hero mode only, created in start_battle)

func _exit_tree() -> void:
	if end_turn_btn and end_turn_btn.pressed.is_connected(_on_end_turn):
		end_turn_btn.pressed.disconnect(_on_end_turn)
	if draw_panel and draw_panel.gui_input.is_connected(_on_draw_pile_clicked):
		draw_panel.gui_input.disconnect(_on_draw_pile_clicked)
	if discard_panel and discard_panel.gui_input.is_connected(_on_discard_pile_clicked):
		discard_panel.gui_input.disconnect(_on_discard_pile_clicked)
	if card_hand:
		if card_hand.card_played.is_connected(_on_card_played):
			card_hand.card_played.disconnect(_on_card_played)
		if card_hand.card_played_tap.is_connected(_on_card_tap_play):
			card_hand.card_played_tap.disconnect(_on_card_tap_play)
		if card_hand.card_long_press_detail.is_connected(_on_card_long_press_detail):
			card_hand.card_long_press_detail.disconnect(_on_card_long_press_detail)
		if card_hand.card_drag_released.is_connected(_on_card_drag_released):
			card_hand.card_drag_released.disconnect(_on_card_drag_released)

## _style_end_turn_button() — REMOVED: styling is now in battle.tscn scene file

func start_battle(character_id: String) -> void:
	battle_active = true
	turn_number = 0
	_reset_all_powers()

	# Get GameManager
	var gm = _get_game_manager()
	if gm == null:
		push_error("GameManager not found")
		return

	# Setup player entity (front row = closer to enemies)
	_setup_player(character_id, gm)
	# Setup second player (back row) if dual hero mode
	if dual_hero_mode and second_character_id != "":
		_setup_second_player(second_character_id, gm)
		_create_swap_button()
	# Setup enemies
	_setup_enemies()
	# Center the battle layout dynamically
	_center_battle_layout()
	# Re-center swap button after layout shift
	if dual_hero_mode:
		_update_swap_button_position()
	# Build deck from both characters if dual hero mode
	_build_deck(character_id, gm)
	# Update top status bar with initial HP
	_update_status_bar()
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
	_next_turn_effects.clear()
	_blur_active = false
	_double_damage_next_turn = false
	_double_damage_this_turn = false
	_burst_active = false
	_no_draw_next_turn = false
	_bullet_time_this_turn = false

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
	# Create front-row player entity
	player = _create_entity_node(false)
	var char_data = gm.character_data[character_id]
	var player_hp: int = config_player_hp if config_player_hp > 0 else char_data["max_hp"]
	player.init_entity(player_hp, false)
	# In dual mode, offset front row to the right (100px+ gap between hero sprites)
	if dual_hero_mode:
		player.position = Vector2(160, 0)
	# Set sprite
	var sprite = player.get_node_or_null("Sprite") as Sprite2D
	if sprite:
		var tex = load(char_data["sprite"])
		if tex:
			sprite.texture = tex
			var tex_height: float = tex.get_height()
			if tex_height > 0:
				var sf: float = player_sprite_scale_height / tex_height
				if dual_hero_mode:
					sf *= 0.85  # Slightly smaller in dual mode
				sprite.scale = Vector2(sf, sf)
	var nlabel = player.get_node_or_null("NameLabel") as Label
	if nlabel:
		nlabel.text = char_data["name"]
	player_area.add_child(player)

func _setup_second_player(character_id: String, gm: Node) -> void:
	if player_area == null:
		return
	second_player = _create_entity_node(false)
	var char_data = gm.character_data[character_id]
	var hp: int = config_player_hp if config_player_hp > 0 else char_data["max_hp"]
	second_player.init_entity(hp, false)
	# Back row: positioned to the left of front row
	second_player.position = Vector2(-230, 0)
	var sprite = second_player.get_node_or_null("Sprite") as Sprite2D
	if sprite:
		var tex = load(char_data["sprite"])
		if tex:
			sprite.texture = tex
			var tex_height: float = tex.get_height()
			if tex_height > 0:
				var sf: float = (player_sprite_scale_height * 0.85) / tex_height
				sprite.scale = Vector2(sf, sf)
	var nlabel = second_player.get_node_or_null("NameLabel") as Label
	if nlabel:
		nlabel.text = char_data["name"]
	player_area.add_child(second_player)
	# Connect died signal
	second_player.died.connect(func(): _on_second_player_died())

var _swap_button: Button = null

func _create_swap_button() -> void:
	## Create a button between the two heroes to swap front/back positions
	var hud = get_node_or_null("HUDLayer/HUD")
	if hud == null:
		return
	_swap_button = Button.new()
	_swap_button.text = "⇄ 换位"
	_swap_button.custom_minimum_size = Vector2(100, 40)
	_swap_button.add_theme_font_size_override("font_size", 24)
	_swap_button.add_theme_color_override("font_color", Color.WHITE)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.25, 0.5, 0.8)
	style.border_color = Color(0.6, 0.5, 0.9, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_swap_button.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.4, 0.35, 0.65, 0.9)
	_swap_button.add_theme_stylebox_override("hover", hover)
	# Position centered between the two heroes (computed dynamically)
	_swap_button.layout_mode = 1
	_swap_button.anchors_preset = 0
	_swap_button.anchor_left = 0.0
	_swap_button.anchor_top = 0.0
	_update_swap_button_position()
	_swap_button.pressed.connect(_on_swap_heroes)
	hud.add_child(_swap_button)

func _update_swap_button_position() -> void:
	if _swap_button == null or player_area == null:
		return
	if player == null or second_player == null:
		return
	# Compute global midpoint between the two heroes
	var front_global_x: float = player_area.position.x + player.position.x
	var back_global_x: float = player_area.position.x + second_player.position.x
	var mid_x: float = (front_global_x + back_global_x) / 2.0
	var mid_y: float = player_area.position.y
	# Center the button on the midpoint (button is 100px wide, 40px tall)
	var btn_w: float = _swap_button.custom_minimum_size.x
	var btn_h: float = _swap_button.custom_minimum_size.y
	_swap_button.offset_left = mid_x - btn_w / 2.0
	_swap_button.offset_top = mid_y + 100.0
	_swap_button.offset_right = mid_x + btn_w / 2.0
	_swap_button.offset_bottom = mid_y + 100.0 + btn_h

func _on_swap_heroes() -> void:
	## Swap front and back row heroes
	if player == null or second_player == null:
		return
	if not player.alive and not second_player.alive:
		return
	# Swap positions
	var temp_pos: Vector2 = player.position
	player.position = second_player.position
	second_player.position = temp_pos
	# Swap references
	var temp = player
	player = second_player
	second_player = temp
	# Names stay the same, no front/back row labels

func _on_second_player_died() -> void:
	# Check if both players are dead
	if player and not player.alive:
		_on_player_died()

func _center_battle_layout() -> void:
	## Dynamically center the battle layout so the midpoint between
	## front hero and front enemy is at screen center X
	if player_area == null or enemy_area == null:
		return
	var vw: float = get_viewport_rect().size.x
	var screen_center: float = vw / 2.0

	# Calculate front hero X (rightmost hero = closest to enemies)
	var front_hero_x: float = player_area.position.x
	if player:
		front_hero_x = player_area.position.x + player.position.x

	# Calculate front enemy X (leftmost enemy = closest to heroes)
	var front_enemy_x: float = enemy_area.position.x
	if not enemies.is_empty():
		var min_x: float = INF
		for e in enemies:
			if e.position.x < min_x:
				min_x = e.position.x
		front_enemy_x = enemy_area.position.x + min_x

	# Current midpoint
	var midpoint: float = (front_hero_x + front_enemy_x) / 2.0

	# Shift both areas equally to center the midpoint
	var shift: float = screen_center - midpoint
	player_area.position.x += shift
	enemy_area.position.x += shift

func get_front_player() -> Node2D:
	## Returns the front-row hero (default target for enemy attacks)
	if player and player.alive:
		return player
	elif second_player and second_player.alive:
		return second_player
	return null

func _get_self_target(card_data: Dictionary = {}) -> Node2D:
	## Returns the hero that self-targeting effects should apply to.
	## In single hero mode, always returns player.
	## In dual hero mode, returns player (front) by default.
	## TODO: Add hero selection prompt for manual targeting
	if player and player.alive:
		return player
	elif second_player and second_player.alive:
		return second_player
	return null

func _highlight_heroes() -> void:
	for hero in _get_all_alive_heroes():
		if hero.has_method("show_target_highlight"):
			hero.show_target_highlight()

func _unhighlight_heroes() -> void:
	for hero in _get_all_alive_heroes():
		if hero.has_method("hide_target_highlight"):
			hero.hide_target_highlight()

func _get_closest_hero(click_pos: Vector2) -> Node2D:
	## Returns the hero closest to the click position (for self-targeting in dual mode)
	var heroes = _get_all_alive_heroes()
	if heroes.is_empty():
		return null
	if heroes.size() == 1:
		return heroes[0]
	var closest: Node2D = null
	var closest_dist: float = INF
	for hero in heroes:
		var hero_global_pos: Vector2 = hero.global_position
		var dist: float = click_pos.distance_to(hero_global_pos)
		if dist < closest_dist:
			closest_dist = dist
			closest = hero
	return closest

func _get_all_alive_heroes() -> Array:
	## Returns all alive heroes (for "all heroes" effects)
	var heroes: Array = []
	if player and player.alive:
		heroes.append(player)
	if second_player and second_player.alive:
		heroes.append(second_player)
	return heroes

func _setup_enemies() -> void:
	if enemy_area == null:
		return
	enemies.clear()
	enemy_ais.clear()
	var enemy_types = ["slime", "cultist", "jaw_worm", "guardian"]
	var enemy_configs = {
		"slime": {"name": "Slime", "hp": 1000, "sprite": "res://assets/img/slime_sts.png", "scale_h": 350.0},
		"cultist": {"name": "Cultist", "hp": 1000, "sprite": "res://assets/img/cultist_sts.png", "scale_h": 400.0},
		"jaw_worm": {"name": "Jaw Worm", "hp": 1000, "sprite": "res://assets/img/jaw_worm_sts.png", "scale_h": 380.0},
		"guardian": {"name": "Guardian", "hp": 1000, "sprite": "res://assets/img/guardian.png", "scale_h": 400.0}
	}
	# Select random enemy types based on enemy_count
	var count: int = clampi(enemy_count, 1, 3)
	var shuffled_types = enemy_types.duplicate()
	shuffled_types.shuffle()
	var selected_enemies: Array = []
	for i in range(count):
		selected_enemies.append(shuffled_types[i % shuffled_types.size()])
	# Position enemies based on count
	var positions: Array = []
	if count == 1:
		positions = [Vector2(100, 0)]
	elif count == 2:
		positions = [Vector2(-20, 0), Vector2(320, 0)]
	else:
		positions = [Vector2(-80, 0), Vector2(120, 0), Vector2(320, 0)]
	for i in range(count):
		var etype: String = selected_enemies[i]
		var config = enemy_configs[etype]
		var enemy = _create_entity_node(true)
		var enemy_hp: int = config_enemy_hps[i] if i < config_enemy_hps.size() and config_enemy_hps[i] > 0 else config["hp"]
		enemy.init_entity(enemy_hp, true, etype)
		enemy.position = positions[i]
		# Set sprite
		var sprite = enemy.get_node_or_null("Sprite") as Sprite2D
		if sprite:
			var tex = load(config["sprite"])
			if tex:
				var tex_height: float = tex.get_height()
				if tex_height > 0:
					var sf: float = config["scale_h"] / tex_height
					# Scale down slightly for multiple enemies
					if count > 1:
						sf *= 0.8
					sprite.scale = Vector2(sf, sf)
				sprite.texture = tex
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
	## Instantiate entity from the scene template (scenes/entity_template.tscn).
	## For player entities, intent/click nodes are hidden or removed.
	var entity: Node2D
	if _entity_template:
		entity = _entity_template.instantiate()
	else:
		# Fallback if template not loaded
		entity = Node2D.new()
		entity.name = "Entity"
		entity.set_script(load("res://scripts/entity.gd"))
		return entity

	if is_enemy_entity:
		# Connect click area for enemy targeting
		var click_area = entity.get_node_or_null("ClickArea") as Area2D
		if click_area:
			click_area.input_event.connect(_on_enemy_click_area_input.bind(entity))
	else:
		# Player doesn't need intent or click area — remove them immediately
		# (before entity enters tree, so _setup_visuals won't find dangling refs)
		var intent_icon_node = entity.get_node_or_null("IntentIcon")
		if intent_icon_node:
			entity.remove_child(intent_icon_node)
			intent_icon_node.queue_free()
		var intent_label_node = entity.get_node_or_null("IntentLabel")
		if intent_label_node:
			entity.remove_child(intent_label_node)
			intent_label_node.queue_free()
		var click_area_node = entity.get_node_or_null("ClickArea")
		if click_area_node:
			entity.remove_child(click_area_node)
			click_area_node.queue_free()

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
	# Move innate cards to top of draw pile so they're drawn first
	var innate_cards: Array = []
	var non_innate: Array = []
	for card in draw_pile:
		if card.get("innate", false):
			innate_cards.append(card)
		else:
			non_innate.append(card)
	draw_pile = non_innate + innate_cards  # Innate at end = drawn first (pop_back)
	_update_pile_labels()

func start_player_turn() -> void:
	if not battle_active:
		return
	is_player_turn = true
	turn_number += 1
	current_energy = max_energy
	attacks_played_this_turn = 0

	# Remove Anticipate temp dexterity from previous turn
	if anticipate_dex_to_remove > 0 and player:
		player.apply_status("dexterity", -anticipate_dex_to_remove)
		anticipate_dex_to_remove = 0

	# Berserk: +1 energy per turn (check all heroes)
	for hero in _get_all_alive_heroes():
		if hero.active_powers.get("berserk", 0) > 0:
			current_energy += 1

	# Power effects at start of turn — apply to the hero that has each power
	for hero in _get_all_alive_heroes():
		if hero.active_powers.get("demon_form", 0) > 0:
			hero.apply_status("strength", 2)
		if hero.active_powers.get("infinite_blades", 0) > 0:
			_add_shiv_to_hand(1)

	# Reset block for each hero (unless that hero has Barricade or Blur)
	for hero in _get_all_alive_heroes():
		var has_barricade: bool = hero.active_powers.get("barricade", 0) > 0
		if not has_barricade and not _blur_active:
			hero.reset_block()
	# Blur only lasts one turn — reset after preserving block
	if _blur_active:
		_blur_active = false

	# Reset flame barrier each turn (it's per-turn)
	flame_barrier_active = false

	# Reset rage each turn
	rage_active = false

	# Process queued next-turn effects
	_process_next_turn_effects()

	# Phantasmal Killer: double damage this turn
	if _double_damage_next_turn:
		_double_damage_this_turn = true
		_double_damage_next_turn = false
	else:
		_double_damage_this_turn = false

	# Bullet Time: no draw if flagged
	var draw_count: int = cards_per_draw
	if _no_draw_next_turn:
		draw_count = 0
		_no_draw_next_turn = false
	_bullet_time_this_turn = false

	# Draw cards
	draw_cards(draw_count)
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
	var drawn_count: int = 0
	for i in range(count):
		if hand.size() >= 10:
			if player:
				player.show_speech("手上的牌太多啦", 1.2)
			break
		if draw_pile.is_empty():
			_reshuffle_discard()
		if draw_pile.is_empty():
			break
		var card_data: Dictionary = draw_pile.pop_back()
		hand.append(card_data)
		if card_hand:
			# Stagger draw animation: each card flies in with a slight delay
			if drawn_count > 0:
				var delay_tween = create_tween()
				var idx = drawn_count
				delay_tween.tween_interval(0.1 * idx)
				delay_tween.tween_callback(func():
					if card_hand and is_instance_valid(card_hand):
						card_hand.add_card(card_data)
						card_hand.update_card_playability(current_energy)
				)
			else:
				card_hand.add_card(card_data)
		drawn_count += 1
		# Evolve: draw extra on Status draw
		if evolve_active and card_data.get("type", 0) == 3:  # STATUS type
			draw_cards(1)
	_update_pile_labels()
	# Update cost colors for all cards (including newly drawn ones)
	if card_hand:
		card_hand.update_card_playability(current_energy)

func _reshuffle_discard() -> void:
	draw_pile = discard_pile.duplicate()
	discard_pile.clear()
	draw_pile.shuffle()
	_show_turn_banner("Reshuffling...", Color(0.7, 0.85, 1.0))
	# Visual: small card icon flies from discard pile to draw pile
	_animate_reshuffle()

func _can_play_card(card_data: Dictionary) -> bool:
	# Unplayable cards (status cards)
	if card_data.get("unplayable", false):
		return false
	var special: String = card_data.get("special", "")
	# Clash: only playable if all cards in hand are attacks
	if special == "clash":
		for c in hand:
			if c.get("type", 0) != 0:  # Not ATTACK
				return false
	# Grand Finale: only playable if draw pile is empty
	if special == "grand_finale":
		if not draw_pile.is_empty():
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
		if player:
			player.show_speech("费用不够！", 1.2)
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

	# Burst: if active and this is a Skill, play it again
	if _burst_active and card_data.get("type", 0) == 1:  # SKILL
		_burst_active = false
		_execute_card(card_data, target, cost)

	# Track attacks played this turn (for Finisher)
	if card_data.get("type", 0) == 0:  # ATTACK
		attacks_played_this_turn += 1

	# Rage: gain block when playing attacks (applies to hero that has Rage)
	if card_data.get("type", 0) == 0:  # ATTACK
		for hero in _get_all_alive_heroes():
			if hero.active_powers.get("rage", 0) > 0:
				hero.add_block(rage_block)
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

	# Handle discard requirement (e.g., Acrobatics: draw 3, discard 1)
	var discard_count: int = card_data.get("discard", 0)
	if discard_count > 0 and not hand.is_empty():
		discard_count = mini(discard_count, hand.size())
		if hand.size() <= discard_count:
			# Auto-discard all remaining cards (no selection needed)
			_auto_discard(hand.size())
			_on_discard_complete()
		else:
			_show_discard_selection(discard_count, _on_discard_complete)
		return  # Don't check battle end yet — wait for discard to finish

	# Check win condition
	_check_battle_end()

func _exhaust_card(card_data: Dictionary) -> void:
	exhaust_pile.append(card_data)
	# Feel No Pain: gain block on exhaust (applies to hero that has the power)
	for hero in _get_all_alive_heroes():
		if hero.active_powers.get("feel_no_pain", 0) > 0:
			hero.add_block(feel_no_pain_block)
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

# ==========================================================================
# Data-driven action executor — cards with "actions" array use this path
# ==========================================================================
func _execute_actions(actions: Array, card_data: Dictionary, target: Node2D, energy_spent: int) -> void:
	var target_type: String = card_data.get("target", "enemy")

	for action in actions:
		var atype: String = action.get("type", "")
		match atype:
			# ---- Damage (single target or multi-hit) ----
			"damage":
				var base_dmg: int = action.get("value", card_data.get("damage", 0))
				var times: int = action.get("times", card_data.get("times", 1))
				var use_strength: bool = action.get("use_strength", true)
				var actual_dmg: int = base_dmg
				if use_strength and player:
					actual_dmg = player.get_attack_damage(base_dmg)
				# Phantasmal Killer: double damage this turn
				if _double_damage_this_turn:
					actual_dmg *= 2
				if actual_dmg > 0:
					if times > 1:
						_apply_multi_hit_damage(actual_dmg, times, target, target_type)
					else:
						_apply_single_hit_damage(actual_dmg, target, target_type)

			# ---- Damage all enemies ----
			"damage_all":
				var base_dmg: int = action.get("value", card_data.get("damage", 0))
				var times: int = action.get("times", 1)
				var actual_dmg: int = base_dmg
				if player:
					actual_dmg = player.get_attack_damage(base_dmg)
				if _double_damage_this_turn:
					actual_dmg *= 2
				if actual_dmg > 0:
					if times > 1:
						_apply_multi_hit_damage(actual_dmg, times, target, "all_enemies")
					else:
						_apply_single_hit_damage(actual_dmg, target, "all_enemies")

			# ---- Block ----
			"block":
				var blk: int = action.get("value", card_data.get("block", 0))
				if blk > 0:
					if target_type == "all_heroes":
						for hero in _get_all_alive_heroes():
							hero.add_block(blk)
							_trigger_juggernaut()
					else:
						var block_target = target if (target_type == "self" and target != null and not target.is_enemy) else player
						if block_target:
							block_target.add_block(blk)
							_trigger_juggernaut()

			# ---- Draw cards ----
			"draw":
				var count: int = action.get("value", card_data.get("draw", 1))
				if count > 0:
					draw_cards(count)

			# ---- Apply status to target (enemy) ----
			"apply_status":
				# If action specifies "source" key (e.g. "apply_status" or "apply_status_2"),
				# read status/stacks from card_data[source] so upgrades propagate.
				var source_key: String = action.get("source", "")
				var status_type: String = action.get("status", "")
				var stacks: int = action.get("stacks", 1)
				if source_key != "" and card_data.has(source_key):
					var src = card_data[source_key]
					status_type = src.get("type", status_type)
					stacks = src.get("stacks", stacks)
				if status_type != "":
					if target_type == "all_enemies":
						for enemy in enemies:
							if enemy.alive:
								enemy.apply_status(status_type, stacks)
					elif target != null and target.alive:
						target.apply_status(status_type, stacks)

			# ---- Apply status to self ----
			"apply_self_status":
				var status_type: String = action.get("status", "")
				var stacks: int = action.get("stacks", 1)
				if target_type == "all_heroes":
					for hero in _get_all_alive_heroes():
						if status_type != "":
							hero.apply_status(status_type, stacks)
				else:
					var self_target = target if (target_type == "self" and target != null and not target.is_enemy) else player
					if status_type != "" and self_target:
						self_target.apply_status(status_type, stacks)

			# ---- Gain energy ----
			"gain_energy":
				var amount: int = action.get("value", 1)
				current_energy += amount
				_update_energy_label()
				if card_hand:
					card_hand.current_battle_energy = current_energy
					card_hand.update_card_playability(current_energy)

			# ---- Queue effect for next turn ----
			"next_turn":
				var next_effect: Dictionary = action.get("effect", {})
				if not next_effect.is_empty():
					_next_turn_effects.append(next_effect)

			# ---- Blur: block is not removed next turn ----
			"blur":
				_blur_active = true

			# ---- Phantasmal Killer: double damage next turn ----
			"phantasmal_killer":
				_double_damage_next_turn = true

			# ---- Burst: next skill played twice ----
			"burst":
				_burst_active = true

			# ---- Bullet Time: cards cost 0 this turn, no draw next turn ----
			"bullet_time":
				_bullet_time_this_turn = true
				_no_draw_next_turn = true
				# Set all hand cards cost to 0 for this turn
				if card_hand:
					card_hand.update_card_playability(current_energy)

			# ---- Heal ----
			"heal":
				var amount: int = action.get("value", 0)
				if amount > 0 and player:
					player.heal(amount)

			# ---- Add shiv cards to hand ----
			"add_shiv":
				var count: int = action.get("value", 1)
				_add_shiv_to_hand(count)

			# ---- Add copy of card to discard (e.g. Anger) ----
			"copy_to_discard":
				var card_id: String = action.get("card_id", card_data.get("id", ""))
				var gm = _get_game_manager()
				if gm:
					var copy = gm.get_card_data(card_id)
					if not copy.is_empty():
						discard_pile.append(copy)

			# ---- Add status card to draw pile ----
			"add_card_to_draw":
				var card_id: String = action.get("card_id", "")
				if card_id != "":
					_add_status_card_to_draw(card_id)

			# ---- Add status card to discard pile ----
			"add_card_to_discard":
				var card_id: String = action.get("card_id", "")
				if card_id != "":
					_add_status_card_to_discard(card_id)

			# ---- Add status card to hand ----
			"add_card_to_hand":
				var card_id: String = action.get("card_id", "")
				var count: int = action.get("count", 1)
				for _i in range(count):
					if card_id != "":
						_add_status_card_to_hand(card_id)

			# ---- Self damage (e.g. Hemokinesis) ----
			"self_damage":
				var amount: int = action.get("value", 0)
				if amount > 0 and player:
					player.take_damage_direct(amount)

			# ---- Power effect activation ----
			"power_effect":
				var power_name: String = action.get("power", "")
				if power_name != "":
					var power_target = target if (target_type == "self" and target != null and not target.is_enemy) else player
					_activate_power(power_name, power_target)

			# ---- Call named action function (for complex card behaviors) ----
			"call":
				var fn_name: String = action.get("fn", "")
				if fn_name != "":
					_call_action(fn_name, card_data, target, energy_spent)

	_update_pile_labels()

func _execute_card(card_data: Dictionary, target: Node2D, energy_spent: int = 0) -> void:
	if card_data.has("actions"):
		_execute_actions(card_data["actions"], card_data, target, energy_spent)

func _call_action(fn_name: String, card_data: Dictionary, target: Node2D, energy_spent: int) -> void:
	var target_type: String = card_data.get("target", "enemy")
	match fn_name:
		"body_slam":
			if player:
				var dmg: int = player.block
				if dmg > 0:
					_apply_single_hit_damage(dmg, target, target_type)
		"heavy_blade":
			if player:
				var str_val: int = player.get_status_stacks("strength")
				var mult: int = card_data.get("str_mult", 3)
				var dmg: int = card_data.get("damage", 14) + str_val * mult
				_apply_single_hit_damage(dmg, target, target_type)
		"whirlwind":
			var base_dmg: int = card_data.get("damage", 5)
			if player:
				base_dmg = player.get_attack_damage(base_dmg)
			if energy_spent > 0 and base_dmg > 0:
				_apply_multi_hit_damage(base_dmg, energy_spent, target, "all_enemies")
		"skewer":
			var base_dmg: int = card_data.get("damage", 7)
			if player:
				base_dmg = player.get_attack_damage(base_dmg)
			if energy_spent > 0 and base_dmg > 0:
				_apply_multi_hit_damage(base_dmg, energy_spent, target, target_type)
		"malaise":
			var x: int = energy_spent
			if card_data.get("upgraded", false):
				x += 1
			if target and target.alive and x > 0:
				target.apply_status("weak", x)
				var current_str: int = target.get_status_stacks("strength")
				var new_str: int = maxi(0, current_str - x)
				target.status_effects["strength"] = new_str
				target.status_changed.emit("strength", new_str)
				target._update_status_display()
		"dropkick":
			var base_dmg: int = card_data.get("damage", 5)
			if player:
				base_dmg = player.get_attack_damage(base_dmg)
			_apply_single_hit_damage(base_dmg, target, target_type)
			if target and target.alive and target.get_status_stacks("vulnerable") > 0:
				current_energy += 1
				_update_energy_label()
				if card_hand:
					card_hand.current_battle_energy = current_energy
					card_hand.update_card_playability(current_energy)
				draw_cards(1)
		"heel_hook":
			var base_dmg: int = card_data.get("damage", 5)
			if player:
				base_dmg = player.get_attack_damage(base_dmg)
			_apply_single_hit_damage(base_dmg, target, target_type)
			if target and target.alive and target.get_status_stacks("weak") > 0:
				current_energy += 1
				_update_energy_label()
				if card_hand:
					card_hand.current_battle_energy = current_energy
					card_hand.update_card_playability(current_energy)
				draw_cards(1)
		"flex":
			var stacks: int = card_data.get("flex_stacks", 2)
			var self_hero = target if (target != null and not target.is_enemy) else player
			if self_hero:
				self_hero.apply_status("strength", stacks)
				flex_strength_to_remove += stacks
		"anticipate":
			var self_hero = target if (target != null and not target.is_enemy) else player
			if self_hero:
				var stacks: int = card_data.get("temp_dex", 3)
				self_hero.apply_status("dexterity", stacks)
				anticipate_dex_to_remove += stacks
		"limit_break":
			var self_hero = target if (target != null and not target.is_enemy) else player
			if self_hero:
				var str_val: int = self_hero.get_status_stacks("strength")
				if str_val > 0:
					self_hero.apply_status("strength", str_val)
		"entrench":
			var self_hero = target if (target != null and not target.is_enemy) else player
			if self_hero:
				var current_block: int = self_hero.block
				self_hero.add_block(current_block)
				_trigger_juggernaut()
		"second_wind":
			var self_hero = target if (target != null and not target.is_enemy) else player
			if self_hero:
				var blk_per: int = card_data.get("block_per", 5)
				var cards_to_exhaust: Array = []
				for c in hand:
					if c.get("type", 0) != 0:
						cards_to_exhaust.append(c)
				for c in cards_to_exhaust:
					hand.erase(c)
					_exhaust_card(c)
					self_hero.add_block(blk_per)
					_trigger_juggernaut()
				if card_hand:
					card_hand.clear_hand()
					for c in hand:
						card_hand.add_card(c)
		"perfected_strike":
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
			var bonus_per: int = card_data.get("strike_bonus", 2)
			var base_dmg: int = card_data.get("damage", 6) + strike_count * bonus_per
			if player:
				var str_val: int = player.get_status_stacks("strength")
				base_dmg += str_val
			_apply_single_hit_damage(base_dmg, target, target_type)
		"fiend_fire":
			var cards_in_hand: int = hand.size()
			var cards_to_exhaust: Array = hand.duplicate()
			for c in cards_to_exhaust:
				hand.erase(c)
				_exhaust_card(c)
			if card_hand:
				card_hand.clear_hand()
			var dmg: int = card_data.get("damage", 7) * cards_in_hand
			if dmg > 0:
				_apply_single_hit_damage(dmg, target, target_type)
		"reaper":
			if player:
				var base_dmg: int = card_data.get("damage", 4)
				var actual_dmg: int = player.get_attack_damage(base_dmg)
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
		"burning_pact":
			if not hand.is_empty():
				var idx: int = randi() % hand.size()
				var exhausted = hand[idx]
				hand.remove_at(idx)
				_exhaust_card(exhausted)
				if card_hand:
					card_hand.clear_hand()
					for c in hand:
						card_hand.add_card(c)
			draw_cards(card_data.get("draw", 2))
		"infernal_blade":
			var gm = _get_game_manager()
			if gm:
				var char_id: String = card_data.get("character", "ironclad")
				var attack_ids: Array = []
				for key in gm.card_database:
					var c = gm.card_database[key]
					if c.get("character", "") == char_id and c.get("type", 0) == 0:
						attack_ids.append(key)
				if not attack_ids.is_empty():
					var rand_id = attack_ids[randi() % attack_ids.size()]
					var new_card = gm.get_card_data(rand_id)
					new_card["cost"] = 0
					hand.append(new_card)
					if card_hand:
						card_hand.add_card(new_card)
		"distraction":
			var gm = _get_game_manager()
			if gm:
				var char_id: String = card_data.get("character", "silent")
				var skill_ids: Array = []
				for key in gm.card_database:
					var c = gm.card_database[key]
					if c.get("character", "") == char_id and c.get("type", 0) == 1:
						skill_ids.append(key)
				if not skill_ids.is_empty():
					var rand_id = skill_ids[randi() % skill_ids.size()]
					var new_card = gm.get_card_data(rand_id)
					new_card["cost"] = 0
					hand.append(new_card)
					if card_hand:
						card_hand.add_card(new_card)
		"dual_wield":
			var copies: int = card_data.get("copies", 1)
			for _i in range(copies):
				for c in hand:
					var ctype = c.get("type", 0)
					if ctype == 0 or ctype == 2:
						var copy = c.duplicate()
						hand.append(copy)
						if card_hand:
							card_hand.add_card(copy)
						break
		"calculated_gamble":
			var gamble_count: int = hand.size()
			for c in hand:
				discard_pile.append(c)
				_check_sly_on_discard(c)
			hand.clear()
			if card_hand:
				card_hand.clear_hand()
			_update_pile_labels()
			draw_cards(gamble_count)
		"feed":
			var base_dmg: int = card_data.get("damage", 10)
			if player:
				base_dmg = player.get_attack_damage(base_dmg)
			if target and target.alive:
				var before_hp: int = target.current_hp
				target.take_damage(base_dmg)
				if not target.alive and player:
					var hp_gain: int = card_data.get("max_hp_gain", 3)
					player.max_hp += hp_gain
					player.heal(hp_gain)
		"rampage":
			var rampage_bonus: int = card_data.get("_rampage_bonus", 0)
			var base_dmg: int = card_data.get("damage", 8) + rampage_bonus
			if player:
				base_dmg = player.get_attack_damage(base_dmg)
			_apply_single_hit_damage(base_dmg, target, target_type)
			card_data["_rampage_bonus"] = rampage_bonus + card_data.get("rampage_inc", 5)
		"sever_soul":
			var cards_to_exhaust: Array = []
			for c in hand:
				if c.get("type", 0) != 0:
					cards_to_exhaust.append(c)
			for c in cards_to_exhaust:
				hand.erase(c)
				_exhaust_card(c)
			if card_hand:
				card_hand.clear_hand()
				for c in hand:
					card_hand.add_card(c)
			var base_dmg: int = card_data.get("damage", 16)
			if player:
				base_dmg = player.get_attack_damage(base_dmg)
			_apply_single_hit_damage(base_dmg, target, target_type)
		"havoc":
			if not draw_pile.is_empty():
				var top_card = draw_pile.pop_front()
				_execute_card(top_card, target, 0)
				_exhaust_card(top_card)
				if card_hand:
					card_hand.clear_hand()
					for c in hand:
						card_hand.add_card(c)
				_update_pile_labels()
		"exhume":
			if not exhaust_pile.is_empty():
				var retrieved = exhaust_pile.pop_back()
				hand.append(retrieved)
				if card_hand:
					card_hand.add_card(retrieved)
		"spot_weakness":
			if target and target.alive and player:
				var enemy_intent: String = target.intent.get("intent", "")
				if enemy_intent == "attack" or enemy_intent == "attack_buff" or enemy_intent == "attack_debuff":
					var str_gain: int = card_data.get("spot_str", 3)
					player.apply_status("strength", str_gain)
		"true_grit":
			if not hand.is_empty():
				var idx: int = randi() % hand.size()
				var exhausted = hand[idx]
				hand.remove_at(idx)
				_exhaust_card(exhausted)
				if card_hand:
					card_hand.clear_hand()
					for c in hand:
						card_hand.add_card(c)
		"escape_plan":
			if not draw_pile.is_empty():
				var drawn = draw_pile.pop_front()
				hand.append(drawn)
				if card_hand:
					card_hand.add_card(drawn)
				if drawn.get("type", 0) == 1 and player:
					player.add_block(card_data.get("escape_block", 3))
					_trigger_juggernaut()
				_update_pile_labels()
		"concentrate":
			var to_discard_count: int = mini(card_data.get("discard_count", 3), hand.size())
			if to_discard_count > 0 and not hand.is_empty():
				var energy_gain_val: int = card_data.get("energy_gain_val", 2)
				if hand.size() <= to_discard_count:
					# Auto-discard all remaining cards (no selection needed)
					_auto_discard(hand.size())
					_on_concentrate_discard_done(energy_gain_val)
				else:
					_show_discard_selection(to_discard_count, _on_concentrate_discard_done.bind(energy_gain_val))
			else:
				# Nothing to discard, just gain energy
				current_energy += card_data.get("energy_gain_val", 2)
				_update_energy_label()
				if card_hand:
					card_hand.current_battle_energy = current_energy
					card_hand.update_card_playability(current_energy)
				_update_pile_labels()
		"finisher":
			var base_dmg: int = card_data.get("damage", 6) * attacks_played_this_turn
			if player and base_dmg > 0:
				base_dmg = player.get_attack_damage(base_dmg)
				_apply_single_hit_damage(base_dmg, target, target_type)
		"glass_knife":
			var base_dmg: int = card_data.get("damage", 8)
			var times_val: int = card_data.get("times", 2)
			if player:
				base_dmg = player.get_attack_damage(base_dmg)
			if base_dmg > 0:
				_apply_multi_hit_damage(base_dmg, times_val, target, target_type)
			card_data["damage"] = maxi(0, card_data.get("damage", 8) - 2)
		"choke":
			var base_dmg: int = card_data.get("damage", 12)
			if player:
				base_dmg = player.get_attack_damage(base_dmg)
			_apply_single_hit_damage(base_dmg, target, target_type)
			if target and target.alive:
				target.apply_status("choke", card_data.get("choke_stacks", 3))
		"catalyst":
			if target and target.alive:
				var poison: int = target.get_status_stacks("poison")
				if poison > 0:
					var mult: int = card_data.get("poison_mult", 2)
					target.apply_status("poison", poison * (mult - 1))
		"corpse_explosion":
			if target and target.alive:
				target.set_meta("corpse_explosion", true)
		"grand_finale":
			var base_dmg: int = card_data.get("damage", 50)
			if player:
				base_dmg = player.get_attack_damage(base_dmg)
			_apply_single_hit_damage(base_dmg, target, target_type)
		"unload":
			var base_dmg: int = card_data.get("damage", 14)
			if player:
				base_dmg = player.get_attack_damage(base_dmg)
			_apply_single_hit_damage(base_dmg, target, target_type)
			var to_discard: Array = []
			for c in hand:
				if c.get("type", 0) != 0:
					to_discard.append(c)
			for c in to_discard:
				hand.erase(c)
				discard_pile.append(c)
				_check_sly_on_discard(c)
			if card_hand:
				card_hand.clear_hand()
				for c in hand:
					card_hand.add_card(c)
			_update_pile_labels()
		"storm_of_steel":
			var shiv_count: int = hand.size()
			for c in hand:
				discard_pile.append(c)
				_check_sly_on_discard(c)
			hand.clear()
			if card_hand:
				card_hand.clear_hand()
			_update_pile_labels()
			_add_shiv_to_hand(shiv_count)
		"expertise":
			var target_hand_size: int = card_data.get("target_hand_size", 6)
			var to_draw: int = maxi(0, target_hand_size - hand.size())
			if to_draw > 0:
				draw_cards(to_draw)
		"alchemize":
			if player:
				player.heal(5)
		"blood_for_blood":
			var base_dmg: int = card_data.get("damage", 18)
			if player:
				base_dmg = player.get_attack_damage(base_dmg)
			_apply_single_hit_damage(base_dmg, target, target_type)
	_update_pile_labels()

func _apply_single_hit_damage(dmg: int, target: Node2D, target_type: String) -> void:
	if target_type == "all_enemies":
		# Sequential AOE: hit each enemy with a slight delay for visual impact
		var delay: float = 0.0
		for enemy in enemies:
			if enemy.alive:
				if delay > 0:
					var aoe_tween = create_tween()
					aoe_tween.tween_interval(delay)
					aoe_tween.tween_callback(enemy.take_damage.bind(dmg))
				else:
					enemy.take_damage(dmg)
				delay += 0.12
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

func _activate_power(power_name: String, power_target: Node2D = null) -> void:
	# Add visual power indicator on the targeted hero
	var hero = power_target if power_target else player
	if hero:
		hero.add_power(power_name)
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
			# Apply 1 Vulnerable to the hero who activated it
			if hero:
				hero.apply_status("vulnerable", 1)
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
		"infinite_blades":
			infinite_blades_active = true

func _process_next_turn_effects() -> void:
	for effect in _next_turn_effects:
		var etype: String = effect.get("type", "")
		var value: int = effect.get("value", 0)
		match etype:
			"block":
				if value > 0 and player and player.alive:
					player.add_block(value)
					_trigger_juggernaut()
			"gain_energy":
				if value > 0:
					current_energy += value
					_update_energy_label()
					if card_hand:
						card_hand.current_battle_energy = current_energy
						card_hand.update_card_playability(current_energy)
	_next_turn_effects.clear()

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
				# Animate from screen center (where played card paused)
				card_hand.add_card(card, false, Vector2(960, 400))

func _add_shiv_to_hand(count: int = 1) -> void:
	var gm = _get_game_manager()
	for i in range(count):
		if hand.size() >= 10:
			if player:
				player.show_speech("手上的牌太多啦", 1.2)
			break
		var shiv = gm.get_card_data("si_shiv")
		if shiv.is_empty():
			continue
		hand.append(shiv)
		if card_hand:
			# Stagger shiv animation and fly from screen center
			if i > 0:
				var delay_tween = create_tween()
				var shiv_copy = shiv
				delay_tween.tween_interval(0.12 * i)
				delay_tween.tween_callback(func():
					if card_hand and is_instance_valid(card_hand):
						card_hand.add_card(shiv_copy, false, Vector2(960, 400))
				)
			else:
				card_hand.add_card(shiv, false, Vector2(960, 400))
	_update_pile_labels()

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

	# Metallicize: gain block at end of turn (apply to hero that has the power)
	for hero in _get_all_alive_heroes():
		if hero.active_powers.get("metallicize", 0) > 0:
			hero.add_block(metallicize_block)
			_trigger_juggernaut()

	# Noxious Fumes: apply poison to all enemies at end of turn
	for hero in _get_all_alive_heroes():
		if hero.active_powers.get("noxious_fumes", 0) > 0:
			var stacks: int = hero.active_powers["noxious_fumes"]
			for enemy in enemies:
				if enemy.alive:
					enemy.apply_status("poison", stacks)

	# Process end-of-turn damage from status cards in hand (Burn)
	var front = get_front_player()
	for card_data in hand:
		if card_data.get("end_turn_damage", 0) > 0 and front:
			front.take_damage_direct(card_data["end_turn_damage"])

	# Exhaust ethereal cards (Dazed)
	var ethereal_cards: Array = []
	for card_data in hand:
		if card_data.get("ethereal", false):
			ethereal_cards.append(card_data)
	for card_data in ethereal_cards:
		hand.erase(card_data)
		_exhaust_card(card_data)

	# Discard remaining hand — trigger sly cards
	for card_data in hand:
		discard_pile.append(card_data)
		_check_sly_on_discard(card_data)
	hand.clear()
	if card_hand:
		card_hand.clear_hand()
	# Tick status effects for all heroes
	for hero in _get_all_alive_heroes():
		hero.tick_status_effects()
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
	# Tick poison on all enemies before their actions
	_tick_enemy_poison(0)

func _tick_enemy_poison(index: int) -> void:
	if index >= enemies.size():
		# All poison ticked, now process enemy actions
		_check_battle_end()
		if battle_active:
			_process_enemy_actions(0)
		return
	var enemy = enemies[index]
	if enemy.alive and enemy.status_effects.has("poison") and enemy.status_effects["poison"] > 0:
		enemy.tick_poison()
		# Small delay so player can see the poison damage
		var timer = get_tree().create_timer(0.4)
		timer.timeout.connect(_tick_enemy_poison.bind(index + 1))
	else:
		_tick_enemy_poison(index + 1)

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

func _enemy_lunge(enemy: Node2D) -> void:
	## Enemy lunge animation toward player (STS-style)
	if enemy == null or not enemy.alive:
		return
	var orig_pos: Vector2 = enemy.position
	var lunge_offset := Vector2(-60, 0)  # Lunge toward player (left)
	var tween = create_tween()
	tween.tween_property(enemy, "position", orig_pos + lunge_offset, 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(enemy, "position", orig_pos, 0.25).set_ease(Tween.EASE_IN)

func _check_reactive_powers(attacked_hero: Node2D, enemy: Node2D) -> void:
	## Check if attacked hero has reactive powers (caltrops, flame_barrier) and apply
	if attacked_hero == null or enemy == null or not enemy.alive:
		return
	if attacked_hero.active_powers.get("flame_barrier", 0) > 0:
		enemy.take_damage(flame_barrier_damage)
	if attacked_hero.active_powers.get("caltrops", 0) > 0:
		enemy.take_damage(3)

func _execute_enemy_action(enemy: Node2D, action: Dictionary) -> void:
	var front = get_front_player()
	if front == null:
		return
	var action_type: String = action.get("type", "attack")
	match action_type:
		"attack":
			var value: int = action.get("value", 5)
			var times: int = action.get("times", 1)
			var actual_dmg: int = enemy.get_attack_damage(value)
			_enemy_lunge(enemy)
			# In dual hero mode, attack front-row hero
			var attack_target = front
			for _i in range(times):
				if attack_target.alive:
					attack_target.take_damage(actual_dmg)
					_screen_shake()
					_check_reactive_powers(attack_target, enemy)
				elif dual_hero_mode:
					# Front row dead, switch to back row
					attack_target = get_front_player()
					if attack_target and attack_target.alive:
						attack_target.take_damage(actual_dmg)
						_screen_shake()
						_check_reactive_powers(attack_target, enemy)
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
			_enemy_lunge(enemy)
			if front.alive:
				front.take_damage(actual_dmg)
				_screen_shake()
			enemy.add_block(blk)
			_check_reactive_powers(front, enemy)
		"mode_shift":
			var blk: int = action.get("block_val", 9)
			enemy.add_block(blk)
		"attack_debuff":
			var dmg: int = action.get("value", 5)
			var status_name: String = action.get("status", "vulnerable")
			var stacks: int = action.get("stacks", 1)
			var actual_dmg: int = enemy.get_attack_damage(dmg)
			_enemy_lunge(enemy)
			front.take_damage(actual_dmg)
			_screen_shake()
			front.apply_status(status_name, stacks)
			_check_reactive_powers(front, enemy)

func _end_enemy_turn() -> void:
	if not battle_active:
		return
	_check_battle_end()
	if battle_active:
		start_player_turn()

func _on_card_played(card_data: Dictionary, target: Node2D) -> void:
	_clear_damage_previews()
	_clear_all_enemy_highlights()
	_unhighlight_heroes()
	_hovered_enemy = null
	if _targeting_arrow:
		_targeting_arrow.hide_arrow()
		_targeting_arrow.visible = false
	play_card(card_data, target)

func _on_end_turn() -> void:
	end_player_turn()

func _on_exit_battle() -> void:
	## Return to main menu
	battle_active = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_entity_died(entity: Node2D) -> void:
	for i in range(enemies.size()):
		if enemies[i] == entity:
			enemy_died.emit(i)
			break
	_check_battle_end()

func _on_player_died() -> void:
	# In dual hero mode, only end battle if both heroes are dead
	if dual_hero_mode:
		var any_alive: bool = false
		if player and player.alive:
			any_alive = true
		if second_player and second_player.alive:
			any_alive = true
		if any_alive:
			return  # One hero still alive, continue battle
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
	if draw_pile_label:
		draw_pile_label.text = str(draw_pile.size())
	if discard_label:
		discard_label.text = str(discard_pile.size())
	# Pile panel positions are set by the scene anchors — no runtime override needed

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
		# Draw chain-style targeting arrow from card to mouse for all targeting modes
		if _targeting_arrow:
			var card_pos: Vector2 = card_hand.selected_card.global_position + Vector2(160, 215)
			var mouse_pos_arrow: Vector2 = get_viewport().get_mouse_position()
			_targeting_arrow.update_arrow(card_pos, mouse_pos_arrow)
			_targeting_arrow.visible = true
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
		elif target_type == "self" and dual_hero_mode:
			# In dual hero mode, self-target cards need hero selection
			# Highlight heroes to indicate they're clickable targets
			_highlight_heroes()
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
		elif target_type == "all_heroes":
			# Highlight all heroes for all-heroes targeting
			_highlight_heroes()
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
	# Don't process targeting during discard selection
	if card_hand and card_hand.discard_mode:
		return
	# Right click to cancel any targeting
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if card_hand and card_hand.is_targeting():
			if card_hand.selected_card:
				card_hand.selected_card.set_selected(false)
			card_hand.selected_card = null
			card_hand.targeting_mode = false
			_clear_all_enemy_highlights()
			_unhighlight_heroes()
			_clear_damage_previews()
			_hovered_enemy = null
			card_hand.update_layout()
	# Left click during targeting: check target type and play
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if card_hand and card_hand.is_targeting() and card_hand.selected_card:
			var card_data: Dictionary = card_hand.get_selected_card_data()
			var target_type: String = card_data.get("target", "enemy")
			if target_type == "self":
				_clear_damage_previews()
				if dual_hero_mode:
					# In dual hero mode, must click on a specific hero
					var click_pos: Vector2 = event.global_position
					var hero_target = _get_closest_hero(click_pos)
					if hero_target:
						_unhighlight_heroes()
						card_hand.play_selected_on(hero_target)
				elif player:
					card_hand.play_selected_on(player)
			elif target_type == "all_enemies" and not enemies.is_empty():
				_clear_damage_previews()
				_clear_all_enemy_highlights()
				_hovered_enemy = null
				card_hand.play_selected_on(enemies[0])
			elif target_type == "all_heroes":
				_clear_damage_previews()
				_unhighlight_heroes()
				if player:
					card_hand.play_selected_on(player)
			elif target_type == "enemy":
				# Click-to-target: check if click is on an enemy
				var click_pos: Vector2 = event.global_position
				var target_enemy = _get_enemy_at(click_pos)
				if target_enemy and target_enemy.alive:
					_clear_damage_previews()
					_clear_all_enemy_highlights()
					_hovered_enemy = null
					if _targeting_arrow:
						_targeting_arrow.hide_arrow()
						_targeting_arrow.visible = false
					card_hand.play_card_on(card_hand.selected_card, target_enemy)
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_on_end_turn()

func _on_card_tap_play(card_node: Area2D) -> void:
	# Handle quick-tap for non-targeted cards (all_enemies only; self cards use targeting)
	if not battle_active or not is_player_turn:
		return
	var card_data: Dictionary = card_node.card_data
	var target_type: String = card_data.get("target", "enemy")
	if target_type == "self":
		if dual_hero_mode:
			# Enter targeting mode — highlight heroes for selection
			card_hand.selected_card = card_node
			card_node.set_selected(true)
			card_hand.targeting_mode = true
			_highlight_heroes()
		else:
			if player:
				card_hand.play_selected_on(player)
	elif target_type == "all_enemies" and not enemies.is_empty():
		card_hand.play_selected_on(enemies[0])

func _on_card_drag_released(card_node: Area2D, release_position: Vector2) -> void:
	# Handle drag release — check target based on card type
	if not battle_active or not is_player_turn:
		return
	_clear_damage_previews()
	_clear_all_enemy_highlights()
	_unhighlight_heroes()
	_hovered_enemy = null
	if _targeting_arrow:
		_targeting_arrow.hide_arrow()
		_targeting_arrow.visible = false
	var card_data: Dictionary = card_node.card_data
	var target_type: String = card_data.get("target", "enemy")
	if target_type == "self":
		# Self-targeting: find closest hero at release position
		var hero_target: Node2D = null
		if dual_hero_mode:
			hero_target = _get_closest_hero(release_position)
		else:
			hero_target = player
		if hero_target:
			card_hand.play_card_on(card_node, hero_target)
		else:
			_snap_card_back(card_node)
	else:
		var target_enemy = _get_enemy_at(release_position)
		if target_enemy and target_enemy.alive:
			card_hand.play_card_on(card_node, target_enemy)
		else:
			_snap_card_back(card_node)

func _snap_card_back(card_node: Area2D) -> void:
	if card_node and is_instance_valid(card_node):
		card_node.set_selected(false)
	card_hand.selected_card = null
	card_hand.targeting_mode = false
	card_hand.update_layout()

func _highlight_enemy(enemy: Node2D) -> void:
	if enemy.has_method("show_target_highlight"):
		enemy.show_target_highlight()
	else:
		enemy.modulate = Color(1.2, 1.2, 1.0)

func _clear_enemy_highlight() -> void:
	if _hovered_enemy and is_instance_valid(_hovered_enemy):
		if _hovered_enemy.has_method("hide_target_highlight"):
			_hovered_enemy.hide_target_highlight()
		else:
			_hovered_enemy.modulate = Color.WHITE

func _clear_all_enemy_highlights() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			if enemy.has_method("hide_target_highlight"):
				enemy.hide_target_highlight()
			else:
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

# ---- Top Status Bar ----

var _status_bar_hp1: Label = null
var _status_bar_hp2: Label = null

func _setup_top_status_bar() -> void:
	var hud = get_node_or_null("HUDLayer/HUD")
	if hud == null:
		return
	# Dark bar at top
	var bar = Panel.new()
	bar.name = "TopStatusBar"
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.05, 0.04, 0.03, 0.85)
	bar_style.content_margin_left = 16
	bar_style.content_margin_right = 16
	bar_style.content_margin_top = 4
	bar_style.content_margin_bottom = 4
	bar.add_theme_stylebox_override("panel", bar_style)
	bar.layout_mode = 1
	bar.anchor_left = 0.0
	bar.anchor_top = 0.0
	bar.anchor_right = 1.0
	bar.anchor_bottom = 0.0
	bar.offset_bottom = 60.0  # +50% height
	hud.add_child(bar)

	# Left side: hero HPs + gold
	var left_hbox = HBoxContainer.new()
	left_hbox.add_theme_constant_override("separation", 20)
	left_hbox.position = Vector2(16, 6)
	bar.add_child(left_hbox)

	# Hero 1 HP
	_status_bar_hp1 = Label.new()
	_status_bar_hp1.text = "♥ 80/80"
	_status_bar_hp1.add_theme_font_size_override("font_size", 24)
	_status_bar_hp1.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	left_hbox.add_child(_status_bar_hp1)

	# Hero 2 HP (only in dual mode)
	_status_bar_hp2 = Label.new()
	_status_bar_hp2.text = "♥ 80/80"
	_status_bar_hp2.add_theme_font_size_override("font_size", 24)
	_status_bar_hp2.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	_status_bar_hp2.visible = false  # Hidden until dual mode activates
	left_hbox.add_child(_status_bar_hp2)

	# Gold
	var gold_label = Label.new()
	gold_label.text = "💰 0"
	gold_label.add_theme_font_size_override("font_size", 24)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	left_hbox.add_child(gold_label)

	# Right side buttons
	var right_hbox = HBoxContainer.new()
	right_hbox.add_theme_constant_override("separation", 12)
	right_hbox.layout_mode = 1
	right_hbox.anchor_left = 1.0
	right_hbox.anchor_right = 1.0
	right_hbox.offset_left = -300.0
	right_hbox.offset_top = 4.0
	right_hbox.offset_right = -16.0
	right_hbox.offset_bottom = 36.0
	bar.add_child(right_hbox)

	var region_btn = _create_top_button("地域")
	right_hbox.add_child(region_btn)

	var settings_btn = _create_top_button("设置")
	right_hbox.add_child(settings_btn)

	# Exit button already exists, remove old one
	var old_exit = get_node_or_null("HUDLayer/HUD/ExitButton")
	if old_exit:
		old_exit.queue_free()
	var exit_btn = _create_top_button("退出")
	exit_btn.pressed.connect(_on_exit_battle)
	right_hbox.add_child(exit_btn)

func _create_top_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(80, 40)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.8, 0.78, 0.7))
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.13, 0.1, 0.7)
	style.border_color = Color(0.4, 0.35, 0.25, 0.6)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style)
	return btn

func _update_status_bar() -> void:
	if _status_bar_hp1 and player:
		_status_bar_hp1.text = "♥ %d/%d" % [player.current_hp, player.max_hp]
	if _status_bar_hp2:
		if dual_hero_mode and second_player:
			_status_bar_hp2.visible = true
			_status_bar_hp2.text = "♥ %d/%d" % [second_player.current_hp, second_player.max_hp]
		else:
			_status_bar_hp2.visible = false

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
	tween.tween_interval(0.5)
	tween.tween_property(_turn_banner, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_callback(func(): _turn_banner.visible = false)

# ---- Screen Shake ----

func _animate_reshuffle() -> void:
	## Visual: small card-shaped rectangles fly from discard pile to draw pile
	var discard_pos := Vector2(1860, 950)  # Discard pile position (bottom right)
	var draw_pos := Vector2(60, 950)  # Draw pile position (bottom left)
	var count: int = mini(5, draw_pile.size())  # Show max 5 card fragments
	for i in range(count):
		var frag = ColorRect.new()
		frag.size = Vector2(30, 40)
		frag.color = Color(0.7, 0.6, 0.4, 0.8)
		frag.position = discard_pos + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		frag.z_index = 300
		add_child(frag)
		var t = create_tween()
		t.tween_interval(0.08 * i)  # Stagger
		t.tween_property(frag, "position", draw_pos + Vector2(randf_range(-15, 15), randf_range(-10, 10)), 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		t.tween_property(frag, "modulate:a", 0.0, 0.15)
		t.tween_callback(frag.queue_free)

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
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
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
	var mini_size := Vector2(256, 350)

	# Use Card.create_card_visual() — sized for readability in pile viewer
	var card_script_class_pv = load("res://scripts/card.gd")

	for cd in sorted_pile:
		var card_visual = card_script_class_pv.create_card_visual(cd, mini_size, loc)
		card_visual.custom_minimum_size = mini_size
		card_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(card_visual)

# ---- Discard Selection (In-Hand Mode) ----

func _setup_discard_overlay() -> void:
	## Discard overlay in HUDLayer — darkens area above hand (y: 60-700).
	## Hand cards below y:700 are NOT covered, so they remain clickable.
	var hud_layer = get_node_or_null("HUDLayer")
	if hud_layer == null:
		return
	_discard_overlay = Control.new()
	_discard_overlay.name = "DiscardOverlay"
	_discard_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_discard_overlay.visible = false
	_discard_overlay.z_index = 500
	_discard_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(_discard_overlay)

	# Dark background covering y:60-700 (above hand area)
	var bg = ColorRect.new()
	bg.name = "DarkBG"
	bg.position = Vector2(0, 60)
	bg.size = Vector2(1920, 640)
	bg.color = Color(0, 0, 0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_discard_overlay.add_child(bg)

	# Title label — top center of the overlay
	_discard_title_label = Label.new()
	_discard_title_label.name = "Title"
	_discard_title_label.text = ""
	_discard_title_label.position = Vector2(0, 80)
	_discard_title_label.size = Vector2(1920, 50)
	_discard_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_discard_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_discard_title_label.add_theme_font_size_override("font_size", 36)
	_discard_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_discard_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_discard_title_label.add_theme_constant_override("shadow_offset_x", 1)
	_discard_title_label.add_theme_constant_override("shadow_offset_y", 2)
	_discard_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_discard_overlay.add_child(_discard_title_label)

	# Confirm button — below where the selected card appears
	_discard_confirm_btn = Button.new()
	_discard_confirm_btn.name = "ConfirmButton"
	_discard_confirm_btn.text = "确认弃牌"
	_discard_confirm_btn.position = Vector2(810, 700)
	_discard_confirm_btn.custom_minimum_size = Vector2(300, 55)
	_discard_confirm_btn.add_theme_font_size_override("font_size", 28)
	_discard_confirm_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	_discard_confirm_btn.pressed.connect(_on_discard_confirm)
	_discard_overlay.add_child(_discard_confirm_btn)
	_update_discard_confirm_style()

	# Dark rect behind hand cards (in main scene, below card z-index)
	_discard_hand_bg = ColorRect.new()
	_discard_hand_bg.name = "DiscardHandBG"
	_discard_hand_bg.position = Vector2(0, 700)
	_discard_hand_bg.size = Vector2(1920, 380)
	_discard_hand_bg.color = Color(0, 0, 0, 0.6)
	_discard_hand_bg.z_index = -1  # Below hand cards
	_discard_hand_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block card clicks
	_discard_hand_bg.visible = false
	add_child(_discard_hand_bg)

func _show_discard_selection(count: int, callback: Callable) -> void:
	if card_hand == null:
		# Fallback: auto-discard random cards
		_auto_discard(count)
		callback.call()
		return
	_discard_required_count = count
	_discard_callback = callback
	_discard_selected_cards.clear()

	# Update title
	if _discard_title_label:
		_discard_title_label.text = "选择 %d 张牌弃掉 (点击手牌选择)" % count

	_update_discard_confirm_style()

	# Show the darkening overlay
	if _discard_overlay:
		_discard_overlay.visible = true
	if _discard_hand_bg:
		_discard_hand_bg.visible = true

	# Hide the pending played card so it doesn't interfere during discard
	if card_hand and card_hand._pending_card_node and is_instance_valid(card_hand._pending_card_node):
		card_hand._pending_card_node.visible = false

	# Disable end turn button and pile panels during discard
	if end_turn_btn:
		end_turn_btn.disabled = true
	if draw_panel:
		draw_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if discard_panel:
		discard_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Enter discard selection mode on the hand
	card_hand.enter_discard_mode(count)
	# Connect the selection changed signal
	if not card_hand.discard_selection_changed.is_connected(_on_hand_discard_selection_changed):
		card_hand.discard_selection_changed.connect(_on_hand_discard_selection_changed)

func _on_hand_discard_selection_changed(selected_count: int) -> void:
	## Called when the player selects/deselects cards in the hand for discard
	_discard_selected_cards = card_hand.get_discard_selected_indices()
	_update_discard_confirm_style()

func _update_discard_confirm_style() -> void:
	if _discard_confirm_btn == null:
		return
	var ready: bool = _discard_selected_cards.size() >= _discard_required_count
	if ready:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.6, 0.2, 0.9)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		_discard_confirm_btn.add_theme_stylebox_override("normal", style)
		var hover_style = style.duplicate() as StyleBoxFlat
		hover_style.bg_color = Color(0.2, 0.7, 0.25, 0.95)
		_discard_confirm_btn.add_theme_stylebox_override("hover", hover_style)
		_discard_confirm_btn.disabled = false
	else:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.3, 0.3, 0.7)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		_discard_confirm_btn.add_theme_stylebox_override("normal", style)
		_discard_confirm_btn.add_theme_stylebox_override("hover", style)
		_discard_confirm_btn.disabled = true
	_discard_confirm_btn.text = "确认弃牌 (%d/%d)" % [_discard_selected_cards.size(), _discard_required_count]

func _on_discard_confirm() -> void:
	if _discard_selected_cards.size() < _discard_required_count:
		return
	# Sort indices descending so we can remove from hand without index shifting
	var sorted_indices = _discard_selected_cards.duplicate()
	sorted_indices.sort()
	sorted_indices.reverse()
	# Exit discard mode first (resets card highlights)
	if card_hand:
		if card_hand.discard_selection_changed.is_connected(_on_hand_discard_selection_changed):
			card_hand.discard_selection_changed.disconnect(_on_hand_discard_selection_changed)
		card_hand.exit_discard_mode()
	for idx in sorted_indices:
		if idx < hand.size():
			var card_data = hand[idx]
			discard_pile.append(card_data)
			_check_sly_on_discard(card_data)
			hand.remove_at(idx)
	# Rebuild hand display
	if card_hand:
		card_hand.clear_hand()
		for c in hand:
			card_hand.add_card(c)
	_discard_selected_cards.clear()
	# Lower hand back to normal layer
	if _discard_overlay:
		_discard_overlay.visible = false
	if _discard_hand_bg:
		_discard_hand_bg.visible = false
	# Re-enable buttons
	if end_turn_btn:
		end_turn_btn.disabled = false
	if draw_panel:
		draw_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if discard_panel:
		discard_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Show and complete the played card's fly-to-discard animation
	if card_hand:
		if card_hand._pending_card_node and is_instance_valid(card_hand._pending_card_node):
			card_hand._pending_card_node.visible = true
		card_hand.complete_pending_play()
	_update_pile_labels()
	if _discard_callback.is_valid():
		_discard_callback.call()

func _on_discard_cancel() -> void:
	## Cancel the discard selection — close overlay without discarding
	if card_hand:
		if card_hand.discard_selection_changed.is_connected(_on_hand_discard_selection_changed):
			card_hand.discard_selection_changed.disconnect(_on_hand_discard_selection_changed)
		card_hand.exit_discard_mode()
	_discard_selected_cards.clear()
	if _discard_overlay:
		_discard_overlay.visible = false
	if _discard_hand_bg:
		_discard_hand_bg.visible = false
	# Re-enable buttons
	if end_turn_btn:
		end_turn_btn.disabled = false
	if draw_panel:
		draw_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if discard_panel:
		discard_panel.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_discard_complete() -> void:
	# Called after discard selection finishes
	# Update card cost colors after discard changes hand
	if card_hand:
		card_hand.update_card_playability(current_energy)
	_check_battle_end()

func _on_concentrate_discard_done(energy_gain_val: int) -> void:
	# Called after Concentrate discard selection completes — gain energy
	current_energy += energy_gain_val
	_update_energy_label()
	if card_hand:
		card_hand.current_battle_energy = current_energy
		card_hand.update_card_playability(current_energy)
	_update_pile_labels()
	_check_battle_end()

func _auto_discard(count: int) -> void:
	# Fallback: discard random cards from hand
	for _i in range(count):
		if hand.is_empty():
			break
		var idx = randi() % hand.size()
		var card_data = hand[idx]
		discard_pile.append(card_data)
		hand.remove_at(idx)
	if card_hand:
		card_hand.clear_hand()
		for c in hand:
			card_hand.add_card(c)
	_update_pile_labels()

func _check_sly_on_discard(card_data: Dictionary) -> void:
	## Sly mechanic: when a card with special "sly" is discarded, trigger its effects
	if card_data.get("special", "") != "sly":
		return
	if not battle_active or player == null or not player.alive:
		return
	# Pick a target for the sly effect
	var target_type: String = card_data.get("target", "enemy")
	var target: Node2D = null
	if target_type == "all_enemies":
		# all_enemies doesn't need a specific target, but we pass the first alive enemy
		var alive = _get_alive_enemies()
		if not alive.is_empty():
			target = alive[0]
	elif target_type == "random_enemy":
		var alive = _get_alive_enemies()
		if not alive.is_empty():
			target = alive[randi() % alive.size()]
	elif target_type == "enemy":
		var alive = _get_alive_enemies()
		if not alive.is_empty():
			target = alive[randi() % alive.size()]
	elif target_type == "self":
		target = player
	if target == null and target_type != "self":
		return
	# Execute the card effects (without spending energy)
	_execute_card(card_data, target, 0)

# ---- Pile Selection Popup (for cards like Exhume) ----

var _pile_selection_overlay: Control = null
var _pile_selection_callback: Callable
var _pile_selection_count: int = 0
var _pile_selection_selected: Array = []
var _pile_selection_card_nodes: Array = []
var _pile_selection_confirm_btn: Button = null

func _show_pile_selection(pile: Array, title: String, count: int, callback: Callable) -> void:
	## Show a fullscreen overlay where the player selects 'count' cards from 'pile'.
	## Selected card data is returned via callback as an Array.
	if pile.is_empty():
		callback.call([])
		return
	_pile_selection_callback = callback
	_pile_selection_count = count
	_pile_selection_selected.clear()
	_pile_selection_card_nodes.clear()

	# Create overlay if not exists
	if _pile_selection_overlay != null and is_instance_valid(_pile_selection_overlay):
		_pile_selection_overlay.queue_free()

	var hud_layer = get_node_or_null("HUDLayer")
	if hud_layer == null:
		callback.call([])
		return

	_pile_selection_overlay = Control.new()
	_pile_selection_overlay.name = "PileSelectionOverlay"
	_pile_selection_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pile_selection_overlay.z_index = 700
	_pile_selection_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# Dark background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_pile_selection_overlay.add_child(bg)

	# Title
	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.position = Vector2(0, 30)
	title_lbl.size = Vector2(1920, 60)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 36)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title_lbl.add_theme_constant_override("shadow_offset_x", 1)
	title_lbl.add_theme_constant_override("shadow_offset_y", 2)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pile_selection_overlay.add_child(title_lbl)

	# Scroll + Grid for cards
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(60, 110)
	scroll.size = Vector2(1800, 800)
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_pile_selection_overlay.add_child(scroll)

	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	var loc = _get_loc()
	var card_script_class = load("res://scripts/card.gd")
	var mini_size := Vector2(180, 250)

	for i in range(pile.size()):
		var cd: Dictionary = pile[i]
		var card_visual = card_script_class.create_card_visual(cd, mini_size, loc)
		var btn_wrapper = Button.new()
		btn_wrapper.custom_minimum_size = mini_size
		btn_wrapper.size = mini_size
		btn_wrapper.clip_contents = true
		btn_wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0, 0, 0, 0.01)
		btn_wrapper.add_theme_stylebox_override("normal", btn_style)
		var btn_hover = StyleBoxFlat.new()
		btn_hover.bg_color = Color(1, 1, 1, 0.1)
		btn_wrapper.add_theme_stylebox_override("hover", btn_hover)
		var btn_pressed = StyleBoxFlat.new()
		btn_pressed.bg_color = Color(1, 0.8, 0.2, 0.2)
		btn_wrapper.add_theme_stylebox_override("pressed", btn_pressed)
		btn_wrapper.add_child(card_visual)
		var card_index: int = i
		btn_wrapper.pressed.connect(_on_pile_selection_card_toggled.bind(card_index))
		btn_wrapper.set_meta("card_index", card_index)
		btn_wrapper.set_meta("selected", false)
		grid.add_child(btn_wrapper)
		_pile_selection_card_nodes.append(btn_wrapper)

	# Confirm button
	_pile_selection_confirm_btn = Button.new()
	_pile_selection_confirm_btn.text = "确认选择 (0/%d)" % count
	_pile_selection_confirm_btn.position = Vector2(810, 930)
	_pile_selection_confirm_btn.custom_minimum_size = Vector2(300, 60)
	_pile_selection_confirm_btn.add_theme_font_size_override("font_size", 28)
	_pile_selection_confirm_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	_pile_selection_confirm_btn.disabled = true
	var confirm_style = StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.3, 0.3, 0.3, 0.7)
	confirm_style.corner_radius_top_left = 10
	confirm_style.corner_radius_top_right = 10
	confirm_style.corner_radius_bottom_left = 10
	confirm_style.corner_radius_bottom_right = 10
	_pile_selection_confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	_pile_selection_confirm_btn.add_theme_stylebox_override("hover", confirm_style)
	_pile_selection_confirm_btn.pressed.connect(_on_pile_selection_confirm.bind(pile))
	_pile_selection_overlay.add_child(_pile_selection_confirm_btn)

	hud_layer.add_child(_pile_selection_overlay)

func _on_pile_selection_card_toggled(card_index: int) -> void:
	var btn: Button = null
	for node in _pile_selection_card_nodes:
		if node.get_meta("card_index") == card_index:
			btn = node
			break
	if btn == null:
		return
	var is_selected: bool = btn.get_meta("selected")
	if is_selected:
		btn.set_meta("selected", false)
		btn.modulate = Color.WHITE
		_pile_selection_selected.erase(card_index)
	else:
		if _pile_selection_selected.size() >= _pile_selection_count:
			return
		btn.set_meta("selected", true)
		btn.modulate = Color(0.4, 0.9, 1.0, 1.0)  # Blue highlight
		_pile_selection_selected.append(card_index)
	_update_pile_selection_confirm()

func _update_pile_selection_confirm() -> void:
	if _pile_selection_confirm_btn == null:
		return
	var ready: bool = _pile_selection_selected.size() >= _pile_selection_count
	_pile_selection_confirm_btn.text = "确认选择 (%d/%d)" % [_pile_selection_selected.size(), _pile_selection_count]
	_pile_selection_confirm_btn.disabled = not ready
	if ready:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.6, 0.2, 0.9)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		_pile_selection_confirm_btn.add_theme_stylebox_override("normal", style)
		var hover_style = style.duplicate() as StyleBoxFlat
		hover_style.bg_color = Color(0.2, 0.7, 0.25, 0.95)
		_pile_selection_confirm_btn.add_theme_stylebox_override("hover", hover_style)
	else:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.3, 0.3, 0.7)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		_pile_selection_confirm_btn.add_theme_stylebox_override("normal", style)
		_pile_selection_confirm_btn.add_theme_stylebox_override("hover", style)

func _on_pile_selection_confirm(pile: Array) -> void:
	if _pile_selection_selected.size() < _pile_selection_count:
		return
	var selected_cards: Array = []
	for idx in _pile_selection_selected:
		if idx < pile.size():
			selected_cards.append(pile[idx])
	# Close overlay
	if _pile_selection_overlay and is_instance_valid(_pile_selection_overlay):
		_pile_selection_overlay.queue_free()
		_pile_selection_overlay = null
	_pile_selection_selected.clear()
	_pile_selection_card_nodes.clear()
	_pile_selection_confirm_btn = null
	# Invoke callback with selected cards
	if _pile_selection_callback.is_valid():
		_pile_selection_callback.call(selected_cards)
