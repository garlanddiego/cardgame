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
var config_player_max_hp: int = 0  # True max HP (0 = same as config_player_hp)
var config_enemy_hps: Array = [50, 50, 50]
var dual_hero_mode: bool = false
var second_character_id: String = ""
var second_player: Node2D = null  # Back-row hero (dual hero mode)
var _player_character_id: String = ""  # Character ID of front-row hero
var _second_character_id: String = ""  # Character ID of back-row hero
var _dead_hero_char: String = ""  # Character ID of dead hero (cards become unplayable)
@export var player_sprite_scale_height: float = 431.0  ## Target height in pixels for player sprite (+20%)
@export var enemy_sprite_scale_height: float = 336.0  ## Target height in pixels for enemy sprite (+20%)
@export var damage_number_font_size: int = 36  ## Font size for floating damage numbers
@export var hp_bar_width: float = 198.0  ## Width of entity HP bars (180 * 1.1)

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
var envenom_stacks: int = 0
var flame_barrier_active: bool = false
var flame_barrier_damage: int = 4
var corruption_active: bool = false
var berserk_active: bool = false
var feel_no_pain_active: bool = false
var feel_no_pain_block: int = 3
var juggernaut_active: bool = false
var juggernaut_damage: int = 5
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

# ── Battle Statistics (for card synergies) ────────────────────────────────
# Per-turn stats (reset at start of each player turn)
var cards_played_this_turn: int = 0
var cards_drawn_this_turn: int = 0
var cards_discarded_this_turn: int = 0
var hp_loss_count_this_turn: int = 0
var cards_exhausted_this_turn: int = 0
# Per-combat stats (reset at start of battle)
var hp_lost_this_combat: int = 0
var total_attacks_played: int = 0
var total_cards_played: int = 0

# Next-turn effect queue — processed at start of next player turn
var _next_turn_effects: Array = []  # List of dicts: {"type": "block", "value": 4}, etc.
var _blur_active: bool = false  # Block is not removed next turn
var _double_damage_next_turn: bool = false  # Phantasmal Killer
var _double_damage_this_turn: bool = false
var _burst_active: bool = false  # Next skill played twice
var _double_tap_active: bool = false  # Next attack played twice
var _no_draw_next_turn: bool = false  # Bullet Time
var _bullet_time_this_turn: bool = false  # All cards cost 0 this turn
var _setup_mode: bool = false  # Setup card: selected card goes to draw pile top instead of discard

# Blood Fiend state
var _bloodbath_target: Node2D = null
var _bloodbath_card_data: Dictionary = {}
var _bloodbath_hero: Node2D = null
var _blood_pact_draw: int = 2
var _bf_flex_heroes: Array = []  # Track temp strength from bloodrage
var _bf_predator_instinct_block: int = 0  # Block per attack this turn
var _bf_predator_instinct_draw: int = 0  # Draw per attack this turn
var _bf_blood_shell_active: bool = false  # Apply bloodlust when hit this turn
var _bf_blood_shell_stacks: int = 1  # Bloodlust stacks to apply when hit

# ── Forger / Greatsword state ────────────────────────────────────────────────
var _greatsword_hp: int = 0           # Current HP (0 = not summoned)
var _greatsword_max_hp: int = 0       # Max HP reached (for display)
var _greatsword_thorns: int = 0       # Permanent thorns
var _greatsword_temp_thorns: int = 0  # Per-turn thorns (reset each turn)
var _greatsword_double_damage: bool = false  # Overcharge: sword damage x2 this turn
var _forged_this_turn: bool = false    # Whether forge was called this turn
var _greatsword_no_summon_this_turn: bool = false  # After Sword Sacrifice
var _greatsword_node: Node2D = null   # Visual node for greatsword
var _fg_energy_reserve_active: bool = false  # Save unspent energy
var _fg_energy_reserve_bonus: int = 0  # Extra energy on reserve (+upgrade)
var _fg_melt_down_draw: int = 1       # Next-turn draw from melt_down
var _fg_melt_down_pending: bool = false
var _fg_salvage_mode: bool = false     # Salvage: pick card from discard pile

# Standard Mode: custom monster configuration
var standard_mode_monsters: Array = []  # [{id: "mushroom", hp: 40}, ...]

# Node refs
var card_hand: Node2D = null
var energy_label: Label = null
var draw_pile_label: Label = null
var discard_label: Label = null
var end_turn_btn: Button = null
var ai_btn: Button = null
var _ai_overlay: Control = null
var turn_label: Label = null
var player_area: Node2D = null
var enemy_area: Node2D = null
var draw_panel: Panel = null
var discard_panel: Panel = null

# Delay for card-to-hand generation (wait for played card animation to finish)
var _card_gen_delay: float = 0.0

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
var _discard_as_exhaust: bool = false  # Burning Pact: exhaust instead of discard
var _blood_rush_mode: bool = false  # Blood Rush: reduce cost instead of removing card
var _discard_confirm_btn: Button = null
var _discard_title_label: Label = null

# Damage preview labels
var _damage_preview_labels: Array = []

# Turn banner
var _turn_banner: Label = null

const BATTLE_BACKGROUNDS: Array[String] = [
	"res://assets/img/dungeon_bg_sts.png",
	"res://assets/img/battle_bg_1.png",
	"res://assets/img/battle_bg_2.png",
	"res://assets/img/battle_bg_3.png",
	"res://assets/img/battle_bg_4.png",
	"res://assets/img/battle_bg_5.png",
]

func _ready() -> void:
	# Random battle background
	var bg_node = get_node_or_null("Background") as TextureRect
	if bg_node:
		var available: Array[String] = []
		for path in BATTLE_BACKGROUNDS:
			if ResourceLoader.exists(path):
				available.append(path)
		if not available.is_empty():
			bg_node.texture = load(available[randi() % available.size()])

	# Preload entity template scene
	_entity_template = preload("res://scenes/entity_template.tscn")

	card_hand = get_node_or_null("CardHand")
	energy_label = get_node_or_null("HUDLayer/HUD/EnergyPanel/EnergyContainer/EnergyLabel")
	# Labels are now children of their Panel containers in the scene
	draw_panel = get_node_or_null("HUDLayer/HUD/DrawPanel") as Panel
	discard_panel = get_node_or_null("HUDLayer/HUD/DiscardPanel") as Panel
	draw_pile_label = get_node_or_null("HUDLayer/HUD/DrawPanel/DrawPileLabel")
	discard_label = get_node_or_null("HUDLayer/HUD/DiscardPanel/DiscardPileLabel")
	# Fallback: labels may be directly under HUD (not inside Panel wrappers)
	if draw_pile_label == null:
		draw_pile_label = get_node_or_null("HUDLayer/HUD/DrawPileLabel")
	if discard_label == null:
		discard_label = get_node_or_null("HUDLayer/HUD/DiscardPileLabel")
	end_turn_btn = get_node_or_null("HUDLayer/HUD/EndTurnButton")
	turn_label = get_node_or_null("HUDLayer/HUD/TurnPanel/TurnLabel")
	player_area = get_node_or_null("PlayerArea")
	enemy_area = get_node_or_null("EnemyArea")

	# EndTurnButton — STS-style polished button
	if end_turn_btn:
		end_turn_btn.pressed.connect(_on_end_turn)
		end_turn_btn.add_theme_font_size_override("font_size", 28)
		end_turn_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
		end_turn_btn.add_theme_color_override("font_shadow_color", Color(0.2, 0.1, 0.0, 0.7))
		end_turn_btn.add_theme_constant_override("shadow_offset_x", 0)
		end_turn_btn.add_theme_constant_override("shadow_offset_y", 2)
		# Normal: warm amber with gold border
		var et_style := StyleBoxFlat.new()
		et_style.bg_color = Color(0.55, 0.32, 0.08, 0.92)
		et_style.border_color = Color(0.95, 0.75, 0.3)
		et_style.set_border_width_all(3)
		et_style.set_corner_radius_all(14)
		et_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
		et_style.shadow_size = 4
		et_style.shadow_offset = Vector2(0, 3)
		et_style.content_margin_left = 16
		et_style.content_margin_right = 16
		et_style.content_margin_top = 8
		et_style.content_margin_bottom = 8
		end_turn_btn.add_theme_stylebox_override("normal", et_style)
		# Hover: brighter amber
		var et_hover := et_style.duplicate() as StyleBoxFlat
		et_hover.bg_color = Color(0.7, 0.42, 0.12, 0.95)
		et_hover.border_color = Color(1.0, 0.85, 0.4)
		end_turn_btn.add_theme_stylebox_override("hover", et_hover)
		# Pressed: darker, inset feel
		var et_pressed := et_style.duplicate() as StyleBoxFlat
		et_pressed.bg_color = Color(0.4, 0.22, 0.05, 0.95)
		et_pressed.shadow_size = 1
		et_pressed.shadow_offset = Vector2(0, 1)
		end_turn_btn.add_theme_stylebox_override("pressed", et_pressed)
		# Disabled: muted gray (enemy turn)
		var et_disabled := StyleBoxFlat.new()
		et_disabled.bg_color = Color(0.18, 0.18, 0.2, 0.7)
		et_disabled.border_color = Color(0.3, 0.3, 0.35)
		et_disabled.set_border_width_all(2)
		et_disabled.set_corner_radius_all(14)
		et_disabled.content_margin_left = 16
		et_disabled.content_margin_right = 16
		et_disabled.content_margin_top = 8
		et_disabled.content_margin_bottom = 8
		end_turn_btn.add_theme_stylebox_override("disabled", et_disabled)
		end_turn_btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))
		var loc = _get_loc()
		if loc:
			end_turn_btn.text = loc.t("end_turn")

	# AI Recommend button — below End Turn
	_create_ai_button()

	# Connect draw/discard click signals
	if draw_panel:
		draw_panel.gui_input.connect(_on_draw_pile_clicked)
	elif draw_pile_label:
		draw_pile_label.gui_input.connect(_on_draw_pile_clicked)
	if discard_panel:
		discard_panel.gui_input.connect(_on_discard_pile_clicked)
	elif discard_label:
		discard_label.gui_input.connect(_on_discard_pile_clicked)

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
	_dead_hero_char = ""
	_reset_all_powers()
	# Reset per-combat battle stats
	hp_lost_this_combat = 0
	total_attacks_played = 0
	total_cards_played = 0
	# Reset greatsword
	_reset_greatsword_for_battle()

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
	# Reset dead hero card state
	if card_hand:
		card_hand.dead_hero_chars = []
	# Start first turn
	start_player_turn()

func _reset_all_powers() -> void:
	demon_form_active = false
	caltrops_active = false
	envenom_stacks = 0
	flame_barrier_active = false
	corruption_active = false
	berserk_active = false
	feel_no_pain_active = false
	juggernaut_active = false

	rage_active = false
	barricade_active = false
	metallicize_active = false
	flex_strength_to_remove = 0
	_next_turn_effects.clear()
	_blur_active = false
	_double_damage_next_turn = false
	_double_damage_this_turn = false
	_burst_active = false
	_double_tap_active = false
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
	_player_character_id = character_id
	# Create front-row player entity
	player = _create_entity_node(false)
	var char_data = gm.character_data[character_id]
	var player_hp: int = config_player_hp if config_player_hp > 0 else char_data["max_hp"]
	var player_max: int = config_player_max_hp if config_player_max_hp > 0 else char_data["max_hp"]
	player.init_entity(player_hp, false, "", player_max)
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
				sf *= char_data.get("sprite_scale", 1.0)
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
	_second_character_id = character_id
	second_player = _create_entity_node(false)
	var char_data = gm.character_data[character_id]
	var hp: int = get_meta("standard_hero2_hp", 0) as int
	if hp <= 0:
		hp = config_player_hp if config_player_hp > 0 else char_data["max_hp"]
	var hero2_max: int = get_meta("standard_hero2_max_hp", 0) as int
	if hero2_max <= 0:
		hero2_max = char_data["max_hp"]
	second_player.init_entity(hp, false, "", hero2_max)
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
				sf *= char_data.get("sprite_scale", 1.0)
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
	_swap_button.z_index = 50
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
	# Swap character IDs
	var temp_id = _player_character_id
	_player_character_id = _second_character_id
	_second_character_id = temp_id
	# Update monster intents based on new front hero
	_refresh_enemy_intents()

func _on_second_player_died() -> void:
	# Remove swap button — can't swap with a dead hero
	if _swap_button and is_instance_valid(_swap_button):
		_swap_button.queue_free()
		_swap_button = null
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
	## In dual hero mode, routes to the hero matching the card's character.
	if dual_hero_mode and not card_data.is_empty():
		var card_char: String = card_data.get("character", "")
		if card_char == _player_character_id and player and player.alive:
			return player
		elif card_char == _second_character_id and second_player and second_player.alive:
			return second_player
	# Fallback: front-row hero
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

	# Legacy enemy configs (for non-standard modes)
	var legacy_configs = {
		"slime": {"name": "Slime", "hp": 1000, "sprite": "res://assets/img/slime_sts.png", "scale_h": 420.0},
		"cultist": {"name": "Cultist", "hp": 1000, "sprite": "res://assets/img/cultist_sts.png", "scale_h": 480.0},
		"jaw_worm": {"name": "Jaw Worm", "hp": 1000, "sprite": "res://assets/img/jaw_worm_sts.png", "scale_h": 456.0},
		"guardian": {"name": "Guardian", "hp": 1000, "sprite": "res://assets/img/guardian.png", "scale_h": 480.0}
	}

	# Merge standard mode monster configs
	var _monsters_script = load("res://scripts/monsters.gd") if ResourceLoader.exists("res://scripts/monsters.gd") else null
	var monsters_db: Dictionary = _monsters_script.get_all() if _monsters_script else {}
	for mid in monsters_db:
		var m: Dictionary = monsters_db[mid]
		legacy_configs[mid] = {
			"name": m.get("name", mid),
			"hp": m.get("base_hp", 50),
			"sprite": m.get("sprite", ""),
			"scale_h": m.get("scale_h", 300.0),
		}

	# Build selected enemies list
	var selected_enemies: Array = []  # [{type, hp}]
	if standard_mode_monsters.size() > 0:
		# Standard mode — use pre-configured monsters
		for m in standard_mode_monsters:
			selected_enemies.append({"type": m["id"], "hp": m["hp"]})
	else:
		# Legacy mode — random from original 4
		var enemy_types = ["slime", "cultist", "jaw_worm", "guardian"]
		var count: int = clampi(enemy_count, 1, 3)
		var shuffled_types = enemy_types.duplicate()
		shuffled_types.shuffle()
		for i in range(count):
			var etype: String = shuffled_types[i % shuffled_types.size()]
			var hp: int = config_enemy_hps[i] if i < config_enemy_hps.size() and config_enemy_hps[i] > 0 else legacy_configs[etype]["hp"]
			selected_enemies.append({"type": etype, "hp": hp})
	# Position enemies based on count
	var count: int = selected_enemies.size()
	var positions: Array = []
	if count == 1:
		positions = [Vector2(100, 0)]
	elif count == 2:
		positions = [Vector2(-20, 0), Vector2(320, 0)]
	else:
		positions = [Vector2(-80, 0), Vector2(120, 0), Vector2(320, 0)]
	for i in range(count):
		var entry: Dictionary = selected_enemies[i]
		var etype: String = entry["type"]
		var config: Dictionary = legacy_configs.get(etype, {"name": etype, "hp": 50, "sprite": "", "scale_h": 300.0})
		var enemy = _create_entity_node(true)
		var enemy_hp: int = entry["hp"]
		enemy.init_entity(enemy_hp, true, etype)
		enemy.position = positions[i]
		# Set sprite
		var sprite = enemy.get_node_or_null("Sprite") as Sprite2D
		if sprite and config["sprite"] != "":
			var tex = load(config["sprite"]) if ResourceLoader.exists(config["sprite"]) else null
			if tex:
				var tex_height: float = tex.get_height()
				if tex_height > 0:
					var sf: float = config["scale_h"] / tex_height
					if count > 1:
						sf *= 0.8
					sprite.scale = Vector2(sf, sf)
				sprite.texture = tex
				sprite.flip_h = true  # Face left toward heroes
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
	# Reset per-turn battle stats
	attacks_played_this_turn = 0
	cards_played_this_turn = 0
	cards_drawn_this_turn = 0
	cards_discarded_this_turn = 0
	hp_loss_count_this_turn = 0
	cards_exhausted_this_turn = 0

	# Anticipate dex removal now happens at end of turn (with Flex)

	# Berserk: +energy per turn (check all heroes)
	for hero in _get_all_alive_heroes():
		var berserk_stacks: int = hero.active_powers.get("berserk", 0)
		if berserk_stacks > 0:
			current_energy += berserk_stacks

	# Power effects at start of turn — apply to the hero that has each power
	for hero in _get_all_alive_heroes():
		if hero.active_powers.get("demon_form", 0) > 0:
			hero.apply_status("strength", hero.active_powers["demon_form"])
		if hero.active_powers.get("infinite_blades", 0) > 0:
			_add_shiv_to_hand(hero.active_powers["infinite_blades"])
		if hero.active_powers.get("venomous_might", 0) > 0:
			var total_poison: int = 0
			for enemy in enemies:
				if enemy.alive:
					total_poison += enemy.get_status_stacks("poison")
			var str_gain: int = total_poison / 4
			if str_gain > 0:
				hero.apply_status("strength", str_gain)

		# Wraith Form: lose dexterity each turn (stacks = dex loss per turn)
		if hero.active_powers.get("wraith_form", 0) > 0:
			hero.apply_status("dexterity", -hero.active_powers["wraith_form"])
		# Brutality: lose HP and draw cards (stacks)
		if hero.active_powers.get("brutality", 0) > 0:
			var stacks: int = hero.active_powers["brutality"]
			hero.take_damage_direct(stacks)
			draw_cards(stacks)
		# Tools of the Trade: draw N, then show discard selection for N
		if hero.active_powers.get("tools_of_the_trade", 0) > 0:
			_tools_discard_count = hero.active_powers["tools_of_the_trade"]
			draw_cards(_tools_discard_count)
		# Blood Frenzy: gain strength and lose HP each turn
		if hero.active_powers.get("blood_frenzy", 0) > 0:
			var bf_str: int = hero.active_powers["blood_frenzy"]
			hero.apply_status("strength", bf_str)
			hero.take_damage_direct(2)
			_bf_on_hp_loss(hero, 2)
		# Blood Bond: if HP below 25%, gain energy and strength
		if hero.active_powers.get("blood_bond", 0) > 0:
			if hero.max_hp > 0 and float(hero.current_hp) / float(hero.max_hp) < 0.25:
				current_energy += 1
				_update_energy_label()
				var bond_str: int = hero.active_powers["blood_bond"]
				hero.apply_status("strength", bond_str)

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

	# Reset Blood Fiend temporary effects
	_bf_predator_instinct_block = 0
	_bf_predator_instinct_draw = 0
	_bf_blood_shell_active = false
	_bf_blood_shell_stacks = 1

	# Reset Forger per-turn state
	_greatsword_double_damage = false
	_forged_this_turn = false
	_greatsword_no_summon_this_turn = false
	_greatsword_temp_thorns = 0
	_update_greatsword_display()

	# Forger start-of-turn powers
	for hero in _get_all_alive_heroes():
		# Auto Forge: forge at start of turn
		var af: int = hero.active_powers.get("fg_auto_forge", 0)
		if af > 0:
			_forge_sword(af)
		# Iron Will: gain block at start of turn
		var iw: int = hero.active_powers.get("fg_iron_will", 0)
		if iw > 0:
			hero.add_block(iw)
			_trigger_juggernaut()
			_fg_on_hero_gain_block(hero, iw)
		# Sword Ward: gain block if greatsword exists
		var sw: int = hero.active_powers.get("fg_sword_ward", 0)
		if sw > 0 and _greatsword_hp > 0:
			hero.add_block(sw)
			_trigger_juggernaut()
			_fg_on_hero_gain_block(hero, sw)

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
	_update_unplayable_ids()
	_update_energy_label()
	_update_pile_labels()

	# Tools of the Trade: show discard selection after draw phase
	if _tools_discard_count > 0 and not hand.is_empty():
		var to_discard: int = mini(_tools_discard_count, hand.size())
		_tools_discard_count = 0
		_show_discard_selection(to_discard, _on_tools_discard_complete)
		return  # Player turn continues after discard selection
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
		card_hand._any_card_dragging = false
		card_hand.selected_card = null
		card_hand.focused_card = null
		card_hand.targeting_mode = false
		card_hand.current_battle_energy = current_energy
		card_hand.update_card_playability(current_energy)
	turn_started.emit(true)

func draw_cards(count: int, instant: bool = false) -> void:
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
		cards_drawn_this_turn += 1
		if card_hand:
			if instant:
				card_hand.add_card(card_data, false)
			elif drawn_count > 0:
				# Stagger draw animation: each card flies in with a slight delay
				var delay_tween = create_tween()
				var idx = drawn_count
				delay_tween.tween_interval(0.15 * idx)
				delay_tween.tween_callback(func():
					if card_hand and is_instance_valid(card_hand):
						card_hand.add_card(card_data)
						card_hand.update_card_playability(current_energy)
				)
			else:
				card_hand.add_card(card_data)
		drawn_count += 1
		# Evolve: draw extra on Status draw
		if card_data.get("type", 0) == 3:  # STATUS type
			for _h in _get_all_alive_heroes():
				var evolve_draw: int = _h.active_powers.get("evolve", 0)
				if evolve_draw > 0:
					draw_cards(evolve_draw)
		# Fire Breathing: deal damage to ALL on Status/Curse draw
		if card_data.get("type", 0) == 3:  # STATUS type
			for _h in _get_all_alive_heroes():
				var fb_dmg: int = _h.active_powers.get("fire_breathing", 0)
				if fb_dmg > 0:
					for enemy in enemies:
						if enemy.alive:
							enemy.take_damage(fb_dmg)
	_update_pile_labels()
	# Psi Surge: gain energy when drawing 3+ cards at once
	if count >= 3 and player:
		if player.active_powers.get("psi_surge", 0) > 0:
			current_energy += 1
			_update_energy_label()
			if card_hand:
				card_hand.current_battle_energy = current_energy
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

func _update_unplayable_ids() -> void:
	"""Update the list of card IDs that can't be played due to special conditions."""
	if card_hand == null:
		return
	var blocked: Array = []
	for card_data in hand:
		if not _can_play_card(card_data):
			blocked.append(card_data.get("id", ""))
	card_hand.unplayable_ids = blocked

func _card_affects_hero(card_data: Dictionary) -> bool:
	## Returns true if a self-target card directly modifies hero attributes/status.
	## Cards that only manipulate hand/draw/energy (Blade Dance, Prepared, etc.) return false.
	if card_data.get("type", 0) == 2:  # POWER type
		return true
	if card_data.get("block", 0) > 0 or card_data.get("block_per", 0) > 0:
		return true
	if card_data.get("double_block", false) or card_data.get("double_strength", false):
		return true
	if card_data.get("power_effect", "") != "":
		return true
	if not card_data.get("apply_self_status", {}).is_empty():
		return true
	if card_data.get("temp_dex", 0) != 0 or card_data.get("flex_stacks", 0) != 0:
		return true
	if card_data.get("escape_block", 0) > 0:
		return true
	for action in card_data.get("actions", []):
		if action.get("type", "") == "self_damage":
			return true
	return false

func _can_play_card(card_data: Dictionary) -> bool:
	# Unplayable cards (status cards)
	if card_data.get("unplayable", false):
		return false
	# Dead hero's cards are unplayable
	if dual_hero_mode and _dead_hero_char != "":
		var card_char: String = card_data.get("character", "")
		if card_char == _dead_hero_char:
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

	# In dual hero mode, self-targeting cards target whoever the player clicked
	# (target is already set by card_hand play flow — don't override it)

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

	# Play character-specific animation
	var anim_hero: Node2D = _get_card_hero(card_data)
	var card_type_anim: int = card_data.get("type", 0)
	if card_type_anim == 0:  # ATTACK
		_play_attack_effect(card_data, anim_hero, target)
	elif card_type_anim == 1:  # SKILL
		_play_skill_effect(card_data, anim_hero)

	# Delay card-to-hand generation until played card animation finishes
	_card_gen_delay = 0.55

	# Move card to its destination pile BEFORE executing effects,
	# so reshuffle during draw can find it in discard_pile
	var card_type: int = card_data.get("type", 0)
	var should_exhaust: bool = card_data.get("exhaust", false)
	if corruption_active and card_type == 1:  # SKILL
		should_exhaust = true
	if card_type == 2:  # POWER — always exhaust
		exhaust_pile.append(card_data)
	elif should_exhaust:
		_exhaust_card(card_data)
	else:
		discard_pile.append(card_data)

	# Execute card effect (pass energy spent for X-cost cards)
	_execute_card(card_data, target, cost)

	# Burst: if active and this is a Skill, play it again
	if _burst_active and card_data.get("type", 0) == 1:  # SKILL
		_burst_active = false
		_execute_card(card_data, target, cost)

	# Double Tap: if active and this is an Attack, play it again
	if _double_tap_active and card_data.get("type", 0) == 0:  # ATTACK
		_double_tap_active = false
		_execute_card(card_data, target, cost)

	# Track battle stats
	cards_played_this_turn += 1
	total_cards_played += 1
	if card_data.get("type", 0) == 0:  # ATTACK
		attacks_played_this_turn += 1
		total_attacks_played += 1

	# Rage: gain block when playing attacks (applies to hero that has Rage)
	if card_data.get("type", 0) == 0:  # ATTACK
		for hero in _get_all_alive_heroes():
			var rage_stacks: int = hero.active_powers.get("rage", 0)
			if rage_stacks > 0:
				hero.add_block(rage_stacks)
				_fg_on_hero_gain_block(hero, rage_stacks)
				_trigger_juggernaut()
		# Predator Instinct: gain block + draw per attack played (temporary)
		if _bf_predator_instinct_block > 0:
			for hero in _get_all_alive_heroes():
				hero.add_block(_bf_predator_instinct_block)
				_fg_on_hero_gain_block(hero, _bf_predator_instinct_block)
				_trigger_juggernaut()
		if _bf_predator_instinct_draw > 0:
			draw_cards(_bf_predator_instinct_draw)
		# Sword Mastery: forge on attack play
		for hero in _get_all_alive_heroes():
			var sm: int = hero.active_powers.get("fg_sword_mastery", 0)
			if sm > 0:
				_forge_sword(sm)

	# A Thousand Cuts: deal damage to ALL enemies on card play
	for hero in _get_all_alive_heroes():
		var atc_stacks: int = hero.active_powers.get("a_thousand_cuts", 0)
		if atc_stacks > 0:
			for enemy in enemies:
				if enemy.alive:
					enemy.take_damage(atc_stacks)

	# After Image: gain Block on card play
	for hero in _get_all_alive_heroes():
		var ai_stacks: int = hero.active_powers.get("after_image", 0)
		if ai_stacks > 0:
			hero.add_block(ai_stacks)
			_fg_on_hero_gain_block(hero, ai_stacks)
			_trigger_juggernaut()

	_card_gen_delay = 0.0  # Reset in case no generation effect consumed it
	_update_pile_labels()
	_refresh_enemy_intents()

	# Re-update card playability (card effects may have changed energy)
	_update_unplayable_ids()
	if card_hand:
		card_hand.current_battle_energy = current_energy
		card_hand.update_card_playability(current_energy)

	# Handle discard requirement (e.g., Acrobatics: draw 3, discard 1)
	var discard_count: int = card_data.get("discard", 0)
	if discard_count > 0 and not hand.is_empty():
		discard_count = mini(discard_count, hand.size())
		if hand.size() <= discard_count:
			# Auto-discard all remaining cards with animation
			_auto_discard(hand.size(), false, _on_discard_complete)
		else:
			_show_discard_selection(discard_count, _on_discard_complete)
		return  # Don't check battle end yet — wait for discard to finish

	# Check win condition
	_check_battle_end()

func _exhaust_card(card_data: Dictionary) -> void:
	exhaust_pile.append(card_data)
	cards_exhausted_this_turn += 1
	# Feel No Pain: gain block on exhaust (applies to hero that has the power)
	for hero in _get_all_alive_heroes():
		if hero.active_powers.get("feel_no_pain", 0) > 0:
			hero.add_block(feel_no_pain_block)
			_fg_on_hero_gain_block(hero, feel_no_pain_block)
			_trigger_juggernaut()
	# Dark Embrace: draw 1 on exhaust
	for hero in _get_all_alive_heroes():
		if hero.active_powers.get("dark_embrace", 0) > 0:
			draw_cards(1)
	# Crimson Pact: deal damage to random enemy on exhaust
	for hero in _get_all_alive_heroes():
		if hero.active_powers.get("crimson_pact", 0) > 0:
			var cp_dmg: int = hero.active_powers["crimson_pact"]
			var alive = _get_alive_enemies()
			if not alive.is_empty():
				var rand_enemy = alive[randi() % alive.size()]
				rand_enemy.take_damage(cp_dmg)
	# Undying Rage: gain strength on exhaust
	for hero in _get_all_alive_heroes():
		if hero.active_powers.get("undying_rage", 0) > 0:
			hero.apply_status("strength", hero.active_powers["undying_rage"])

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
func _get_card_hero(card_data: Dictionary) -> Node2D:
	## Returns the hero that should execute this card (based on character match)
	if dual_hero_mode:
		var card_char: String = card_data.get("character", "")
		if card_char == _player_character_id and player and player.alive:
			return player
		elif card_char == _second_character_id and second_player and second_player.alive:
			return second_player
	if player and player.alive:
		return player
	elif second_player and second_player.alive:
		return second_player
	return null

func _execute_actions(actions: Array, card_data: Dictionary, target: Node2D, energy_spent: int) -> void:
	var target_type: String = card_data.get("target", "enemy")
	var card_hero: Node2D = _get_card_hero(card_data)  # The hero playing this card

	for action in actions:
		var atype: String = action.get("type", "")
		match atype:
			# ---- Damage (single target or multi-hit) ----
			"damage":
				var base_dmg: int = action.get("value", card_data.get("damage", 0))
				var times: int = action.get("times", card_data.get("times", 1))
				var use_strength: bool = action.get("use_strength", true)
				var actual_dmg: int = base_dmg
				if use_strength and card_hero:
					actual_dmg = card_hero.get_attack_damage(base_dmg)
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
				var times: int = action.get("times", card_data.get("times", 1))
				var actual_dmg: int = base_dmg
				if card_hero:
					actual_dmg = card_hero.get_attack_damage(base_dmg)
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
					var buff_target_override: String = action.get("buff_target", "")
					var hero_tgt: String = card_data.get("hero_target", "self")
					if target_type == "all_heroes" or buff_target_override == "all_heroes" or hero_tgt == "all_heroes":
						for hero in _get_all_alive_heroes():
							hero.add_block(blk)
							_fg_on_hero_gain_block(hero, blk)
							_trigger_juggernaut()
					elif target_type == "enemy" and card_data.get("type", 0) == 0:
						# Attack cards: block goes to the card's own hero
						var block_target = card_hero if card_hero else player
						if block_target:
							block_target.add_block(blk)
							_fg_on_hero_gain_block(block_target, blk)
							_trigger_juggernaut()
					else:
						# "self" or "target_hero": block goes to the target hero
						var block_target = target if (target_type == "self" and target != null and not target.is_enemy) else card_hero
						if block_target == null:
							block_target = player
						if block_target:
							block_target.add_block(blk)
							_fg_on_hero_gain_block(block_target, blk)
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
				var status_times: int = action.get("times", card_data.get("times", 1))
				if status_type != "":
					for _t in range(status_times):
						if target_type == "all_enemies":
							for enemy in enemies:
								if enemy.alive:
									enemy.apply_status(status_type, stacks)
						elif target_type == "random_enemy":
							var alive_enemies: Array = []
							for enemy in enemies:
								if enemy.alive:
									alive_enemies.append(enemy)
							if not alive_enemies.is_empty():
								var rand_enemy = alive_enemies[randi() % alive_enemies.size()]
								rand_enemy.apply_status(status_type, stacks)
						elif target != null and target.alive:
							target.apply_status(status_type, stacks)
					# Blood Fiend: trigger powers on applying vulnerable
					if status_type == "vulnerable":
						_bf_on_apply_vulnerable_check(card_hero, "vulnerable", stacks)

			# ---- Apply status to self ----
			"apply_self_status":
				var status_type: String = action.get("status", "")
				var stacks: int = action.get("stacks", 1)
				var hero_tgt: String = card_data.get("hero_target", "self")
				if target_type == "all_heroes" or hero_tgt == "all_heroes":
					for hero in _get_all_alive_heroes():
						if status_type != "":
							hero.apply_status(status_type, stacks)
				else:
					var self_target = target if (target_type == "self" and target != null and not target.is_enemy) else card_hero
					if self_target == null:
						self_target = player
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
				if amount > 0:
					var hero_tgt: String = card_data.get("hero_target", "self")
					if hero_tgt == "all_heroes":
						for hero in _get_all_alive_heroes():
							hero.heal(amount)
					else:
						var heal_target = target if (target_type == "self" and target != null and not target.is_enemy) else card_hero
						if heal_target == null:
							heal_target = player
						if heal_target:
							heal_target.heal(amount)

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
				var self_dmg_hero: Node2D = card_hero if card_hero else player
				if amount > 0 and self_dmg_hero:
					self_dmg_hero.take_damage_direct(amount)
					# Rupture: gain strength on self HP loss from card
					var rupture_str: int = self_dmg_hero.active_powers.get("rupture", 0)
					if rupture_str > 0:
						self_dmg_hero.apply_status("strength", rupture_str)
					# Blood Fury: next attack deals double damage
					if self_dmg_hero.active_powers.get("blood_fury", 0) > 0:
						_double_damage_this_turn = true
					# Blood Fiend HP-loss reactive powers
					_bf_on_hp_loss(self_dmg_hero, amount)

			# ---- Power effect activation ----
			"power_effect":
				# Use card_data's power_effect (reflects upgrades) over action's static value
				var power_name: String = card_data.get("power_effect", action.get("power", ""))
				if power_name != "":
					var hero_tgt: String = card_data.get("hero_target", "self")
					var upgraded: bool = card_data.get("upgraded", false)
					if hero_tgt == "all_heroes":
						for hero in _get_all_alive_heroes():
							_activate_power(power_name, hero, card_data.get("per_turn", {}), upgraded)
					else:
						var power_target = target if (target_type == "self" and target != null and not target.is_enemy) else card_hero
						if power_target == null:
							power_target = player
						_activate_power(power_name, power_target, card_data.get("per_turn", {}), upgraded)

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
	var card_hero: Node2D = _get_card_hero(card_data)
	if card_hero == null:
		card_hero = player
	match fn_name:
		"body_slam":
			if card_hero:
				var dmg: int = card_hero.block
				if dmg > 0:
					_apply_single_hit_damage(dmg, target, target_type)
		"heavy_blade":
			var hb_hero = _get_card_hero(card_data) if _get_card_hero(card_data) else player
			if hb_hero:
				var str_val: int = hb_hero.get_status_stacks("strength")
				var mult: int = card_data.get("str_mult", 3)
				var base_dmg: int = card_data.get("damage", 14)
				# Strength applies x mult (normal cards apply x1, heavy blade x3/x5)
				var dmg: int = base_dmg + str_val * mult
				if hb_hero.status_effects.get("weak", 0) > 0:
					dmg = int(dmg * 0.75)
				if _double_damage_this_turn:
					dmg *= 2
				_apply_single_hit_damage(dmg, target, target_type)
		"whirlwind":
			var base_dmg: int = card_data.get("damage", 5)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			if energy_spent > 0 and base_dmg > 0:
				_apply_multi_hit_damage(base_dmg, energy_spent, target, "all_enemies")
		"skewer":
			var base_dmg: int = card_data.get("damage", 7)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
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
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
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
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
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
			for hero in _get_all_alive_heroes():
				hero.apply_status("strength", stacks)
			flex_strength_to_remove += stacks
		"anticipate":
			var stacks: int = card_data.get("temp_dex", 3)
			for hero in _get_all_alive_heroes():
				hero.apply_status("dexterity", stacks)
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
				_fg_on_hero_gain_block(self_hero, current_block)
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
					_fg_on_hero_gain_block(self_hero, blk_per)
					_trigger_juggernaut()
				if card_hand:
					card_hand.clear_hand()
					for c in hand:
						card_hand.add_card(c, false)
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
			if card_hero:
				var str_val: int = card_hero.get_status_stacks("strength")
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
			# Each exhausted card = one hit with Strength applied
			if cards_in_hand > 0 and card_hero:
				var per_hit: int = card_hero.get_attack_damage(card_data.get("damage", 7))
				if _double_damage_this_turn:
					per_hit *= 2
				_apply_multi_hit_damage(per_hit, cards_in_hand, target, target_type)
		"reaper":
			if card_hero:
				var base_dmg: int = card_data.get("damage", 4)
				var actual_dmg: int = card_hero.get_attack_damage(base_dmg)
				var total_healed: int = 0
				for enemy in enemies:
					if enemy.alive:
						var before_hp: int = enemy.current_hp
						var enemy_block: int = enemy.block
						enemy.take_damage(actual_dmg)
						_on_hero_hit_enemy(enemy, before_hp)
						var damage_dealt: int = mini(actual_dmg, before_hp + enemy_block) - enemy_block
						if damage_dealt > 0:
							total_healed += damage_dealt
				if total_healed > 0:
					player.heal(total_healed)
		"burning_pact":
			var bp_draw: int = card_data.get("draw", 2)
			if not hand.is_empty():
				if hand.size() <= 1:
					# Auto-exhaust all remaining cards with animation, then draw
					_auto_discard(hand.size(), true, func(): draw_cards(bp_draw))
					return
				_discard_as_exhaust = true
				_show_discard_selection(1, func():
					draw_cards(bp_draw)
				)
				if _discard_title_label:
					_discard_title_label.text = "选择 1 张牌消耗"
				return  # Wait for selection
			draw_cards(bp_draw)
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
						_delayed_add_card(new_card)
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
						_delayed_add_card(new_card)
		"dual_wield":
			var copies: int = card_data.get("copies", 1)
			for _i in range(copies):
				for c in hand:
					var ctype = c.get("type", 0)
					if ctype == 0 or ctype == 2:
						var copy = c.duplicate()
						hand.append(copy)
						if card_hand:
							_delayed_add_card(copy)
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
			var feed_hero: Node2D = _get_card_hero(card_data) if _get_card_hero(card_data) else player
			var base_dmg: int = card_data.get("damage", 10)
			if feed_hero:
				base_dmg = feed_hero.get_attack_damage(base_dmg)
			if target and target.alive:
				var hp_before_feed: int = target.current_hp
				target.take_damage(base_dmg)
				_on_hero_hit_enemy(target, hp_before_feed)
				if not target.alive and feed_hero:
					var hp_gain: int = card_data.get("max_hp_gain", 3)
					feed_hero.max_hp += hp_gain
					feed_hero.heal(hp_gain)
		"rampage":
			var rampage_bonus: int = card_data.get("_rampage_bonus", 0)
			var base_dmg: int = card_data.get("damage", 8) + rampage_bonus
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			print("[RAMPAGE] bonus=%d, base=%d, total=%d" % [rampage_bonus, card_data.get("damage", 8), base_dmg])
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
					card_hand.add_card(c, false)
			var base_dmg: int = card_data.get("damage", 16)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			_apply_single_hit_damage(base_dmg, target, target_type)
		"havoc":
			if not draw_pile.is_empty():
				var top_card = draw_pile.pop_back()
				_execute_card(top_card, target, 0)
				_exhaust_card(top_card)
				if card_hand:
					card_hand.clear_hand()
					for c in hand:
						card_hand.add_card(c, false)
				_update_pile_labels()
		"exhume":
			if not exhaust_pile.is_empty():
				var retrieved = exhaust_pile.pop_back()
				hand.append(retrieved)
				if card_hand:
					_delayed_add_card(retrieved)
		"spot_weakness":
			if target and target.alive:
				var enemy_intent: String = target.intent.get("intent", "")
				if enemy_intent == "attack" or enemy_intent == "attack_buff" or enemy_intent == "attack_debuff":
					var str_gain: int = card_data.get("spot_str", 3)
					for hero in _get_all_alive_heroes():
						hero.apply_status("strength", str_gain)
		"true_grit":
			if not hand.is_empty():
				var idx: int = randi() % hand.size()
				var exhausted = hand[idx]
				hand.remove_at(idx)
				_exhaust_card(exhausted)
				if card_hand:
					card_hand.clear_hand()
					for c in hand:
						card_hand.add_card(c, false)
		"escape_plan":
			if not draw_pile.is_empty():
				var drawn = draw_pile.pop_back()
				hand.append(drawn)
				if card_hand:
					_delayed_add_card(drawn)
				if drawn.get("type", 0) == 1 and player:
					var esc_blk: int = card_data.get("escape_block", 3)
					player.add_block(esc_blk)
					_fg_on_hero_gain_block(player, esc_blk)
					_trigger_juggernaut()
				_update_pile_labels()
		"concentrate":
			var to_discard_count: int = mini(card_data.get("discard_count", 3), hand.size())
			if to_discard_count > 0 and not hand.is_empty():
				var energy_gain_val: int = card_data.get("energy_gain_val", 2)
				if hand.size() <= to_discard_count:
					# Auto-discard all remaining cards with animation
					_auto_discard(hand.size(), false, _on_concentrate_discard_done.bind(energy_gain_val))
					return
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
			# Deal (base + strength) per attack played this turn
			if attacks_played_this_turn > 0 and card_hero:
				var per_hit: int = card_hero.get_attack_damage(card_data.get("damage", 6))
				if _double_damage_this_turn:
					per_hit *= 2
				_apply_multi_hit_damage(per_hit, attacks_played_this_turn, target, target_type)
		"glass_knife":
			var base_dmg: int = card_data.get("damage", 8)
			var times_val: int = card_data.get("times", 2)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			if base_dmg > 0:
				_apply_multi_hit_damage(base_dmg, times_val, target, target_type)
			var new_dmg: int = maxi(0, card_data.get("damage", 8) - 2)
			print("[GLASS_KNIFE] damage %d → %d" % [card_data.get("damage", 8), new_dmg])
			card_data["damage"] = new_dmg
		"choke":
			var base_dmg: int = card_data.get("damage", 12)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
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
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			_apply_single_hit_damage(base_dmg, target, target_type)
		"unload":
			var base_dmg: int = card_data.get("damage", 14)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
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
					card_hand.add_card(c, false)
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
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			_apply_single_hit_damage(base_dmg, target, target_type)
		"setup":
			# Put a card from hand on top of draw pile
			if not hand.is_empty():
				if hand.size() <= 1:
					# Auto-move all remaining to draw pile with animation
					for c in hand:
						draw_pile.append(c)
					hand.clear()
					if card_hand:
						card_hand.complete_pending_play()
					# Animate visual cards flying to draw pile
					if card_hand and not card_hand.cards.is_empty():
						var draw_target: Vector2 = card_hand.to_local(Vector2(75, 985))
						var nodes: Array = card_hand.cards.duplicate()
						for i in range(nodes.size()):
							var node = nodes[i]
							if not is_instance_valid(node):
								continue
							var fly = create_tween()
							fly.tween_property(node, "position", draw_target, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
							fly.parallel().tween_property(node, "scale", Vector2(0.3, 0.3), 0.2).set_ease(Tween.EASE_IN)
							fly.parallel().tween_property(node, "modulate:a", 0.0, 0.15).set_delay(0.08)
						var cleanup = create_tween()
						cleanup.tween_interval(0.3)
						cleanup.tween_callback(func():
							if card_hand:
								card_hand.clear_hand()
							_on_setup_complete()
						)
					else:
						if card_hand:
							card_hand.clear_hand()
						_on_setup_complete()
					return
				_setup_mode = true
				_show_discard_selection(1, _on_setup_complete)
				return  # Wait for selection
		# ---- NEW CARDS ----
		"toxic_storm":
			# X cost: deal 3 damage X times to all, apply 1 poison per hit
			var base_dmg: int = card_data.get("damage", 3)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			if energy_spent > 0:
				for _hit in range(energy_spent):
					for enemy in enemies:
						if enemy.alive:
							var hp_before_ts: int = enemy.current_hp
							enemy.take_damage(base_dmg)
							_on_hero_hit_enemy(enemy, hp_before_ts)
							enemy.apply_status("poison", 1)
		"echo_slash":
			# Deal 5 damage, +1 hit per attack played this turn
			var base_dmg: int = card_data.get("damage", 5)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			# attacks_played_this_turn counts cards played before this one
			var hits: int = 1 + attacks_played_this_turn
			if _double_damage_this_turn:
				base_dmg *= 2
			_apply_multi_hit_damage(base_dmg, hits, target, target_type)
		"gamblers_blade":
			# Deal hand_size * 3 damage, discard 1
			var hand_count: int = hand.size()
			var dmg: int = hand_count * 3
			if card_hero:
				var str_val: int = card_hero.get_status_stacks("strength")
				dmg += str_val
				if card_hero.status_effects.get("weak", 0) > 0:
					dmg = int(dmg * 0.75)
			if _double_damage_this_turn:
				dmg *= 2
			_apply_single_hit_damage(dmg, target, target_type)
			# Discard 1 random card
			if not hand.is_empty():
				var idx: int = randi() % hand.size()
				var discarded = hand[idx]
				hand.remove_at(idx)
				discard_pile.append(discarded)
				_check_sly_on_discard(discarded)
				if card_hand:
					card_hand.clear_hand()
					for c in hand:
						card_hand.add_card(c, false)
		"poison_shield":
			# Gain block = total poison on all enemies
			var total_poison: int = 0
			for enemy in enemies:
				if enemy.alive:
					total_poison += enemy.get_status_stacks("poison")
			if total_poison > 0 and player:
				player.add_block(total_poison)
				_fg_on_hero_gain_block(player, total_poison)
				_trigger_juggernaut()
		"all_in":
			# Consume all energy, draw 2 per energy consumed
			var energy_to_consume: int = current_energy
			if energy_to_consume > 0:
				current_energy = 0
				_update_energy_label()
				if card_hand:
					card_hand.current_battle_energy = current_energy
				draw_cards(energy_to_consume * 2)
		# ---- BLOOD FIEND CARDS ----
		"execution":
			var base_dmg: int = card_data.get("damage", 8)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			if _double_damage_this_turn:
				base_dmg *= 2
			if target and target.alive:
				var hp_before_exec: int = target.current_hp
				_apply_single_hit_damage(base_dmg, target, target_type)
				# Only double bloodlust if damage actually reduced HP
				if target.current_hp < hp_before_exec:
					var bl: int = target.get_status_stacks("bloodlust")
					if bl > 0:
						target.apply_status("bloodlust", bl)
						_bf_on_apply_bloodlust_check(card_hero, target, bl)
		"blood_whirl":
			var self_dmg_hero: Node2D = card_hero if card_hero else player
			if self_dmg_hero:
				self_dmg_hero.take_damage_direct(2)
				_bf_on_hp_loss(self_dmg_hero, 2)
			var base_dmg: int = card_data.get("damage", 6)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			if _double_damage_this_turn:
				base_dmg *= 2
			for enemy in enemies:
				if enemy.alive:
					var hp_before_bw: int = enemy.current_hp
					enemy.take_damage(base_dmg)
					enemy.apply_status("bloodlust", 1)
					_bf_on_apply_bloodlust_check(card_hero, enemy, 1)
					_on_hero_hit_enemy(enemy, hp_before_bw)
		"savage_strike":
			var base_dmg: int = card_data.get("damage", 6)
			base_dmg += hp_lost_this_combat
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			if _double_damage_this_turn:
				base_dmg *= 2
			_apply_single_hit_damage(base_dmg, target, target_type)
		"prey_on_weakness":
			var base_dmg: int = card_data.get("damage", 6)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			if _double_damage_this_turn:
				base_dmg *= 2
			var hits_pw: int = 1
			if target and target.alive and target.get_status_stacks("vulnerable") > 0:
				hits_pw = 2
			_apply_multi_hit_damage(base_dmg, hits_pw, target, target_type)
		"exploit":
			var base_dmg: int = card_data.get("damage", 3)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			if _double_damage_this_turn:
				base_dmg *= 2
			_apply_single_hit_damage(base_dmg, target, target_type)
			if target and target.alive and target.get_status_stacks("vulnerable") > 0:
				var draw_count: int = card_data.get("bf_exploit_draw", 1)
				draw_cards(draw_count)
		"crushing_blow":
			var base_dmg: int = card_data.get("damage", 10)
			var vuln_bonus: int = card_data.get("vuln_bonus", 4)
			var vuln_stacks: int = 0
			if target:
				vuln_stacks = target.get_status_stacks("vulnerable")
			base_dmg += vuln_stacks * vuln_bonus
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			if _double_damage_this_turn:
				base_dmg *= 2
			_apply_single_hit_damage(base_dmg, target, target_type)
			if target and vuln_stacks > 0:
				target.status_effects.erase("vulnerable")
				target.status_changed.emit("vulnerable", 0)
				target._update_status_display()
		"flesh_rend":
			# Exhaust 1 card from hand, deal its cost * multiplier
			if hand.is_empty():
				return
			var idx_fr: int = randi() % hand.size()
			var exhausted_card: Dictionary = hand[idx_fr]
			var card_cost: int = exhausted_card.get("cost", 0)
			hand.remove_at(idx_fr)
			_exhaust_card(exhausted_card)
			if card_hand:
				card_hand.clear_hand()
				for c in hand:
					card_hand.add_card(c, false)
			var mult: int = card_data.get("cost_mult", 8)
			var dmg_fr: int = card_cost * mult
			if card_hero:
				var str_val: int = card_hero.get_status_stacks("strength")
				dmg_fr += str_val
				if card_hero.status_effects.get("weak", 0) > 0:
					dmg_fr = int(dmg_fr * 0.75)
			if _double_damage_this_turn:
				dmg_fr *= 2
			dmg_fr = maxi(0, dmg_fr)
			_apply_single_hit_damage(dmg_fr, target, target_type)
		"soul_harvest":
			# Exhaust all other cards in hand, deal damage per card
			var cards_to_exhaust: Array = hand.duplicate()
			var exhaust_count: int = cards_to_exhaust.size()
			for c in cards_to_exhaust:
				hand.erase(c)
				_exhaust_card(c)
			if card_hand:
				card_hand.clear_hand()
			if exhaust_count > 0 and card_hero:
				var per_hit: int = card_hero.get_attack_damage(card_data.get("damage", 7))
				if _double_damage_this_turn:
					per_hit *= 2
				_apply_multi_hit_damage(per_hit, exhaust_count, target, target_type)
		"relentless":
			var base_dmg: int = card_data.get("damage", 6)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			if _double_damage_this_turn:
				base_dmg *= 2
			var hits_rl: int = 1 + cards_exhausted_this_turn
			_apply_multi_hit_damage(base_dmg, hits_rl, target, target_type)
		"vampiric_embrace":
			var base_dmg: int = card_data.get("damage", 4)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			if _double_damage_this_turn:
				base_dmg *= 2
			var total_healed: int = 0
			for enemy in enemies:
				if enemy.alive:
					var before_hp: int = enemy.current_hp
					enemy.take_damage(base_dmg)
					_on_hero_hit_enemy(enemy, before_hp)
					# Heal = actual HP lost (before_hp - current_hp accounts for vuln, bloodlust, block)
					var hp_lost: int = before_hp - maxi(enemy.current_hp, 0)
					if hp_lost > 0:
						total_healed += hp_lost
			var heal_hero: Node2D = card_hero if card_hero else player
			if total_healed > 0 and heal_hero:
				heal_hero.heal(total_healed)
		"leech":
			var base_dmg: int = card_data.get("damage", 6)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			if _double_damage_this_turn:
				base_dmg *= 2
			if target and target.alive:
				var before_hp: int = target.current_hp
				target.take_damage(base_dmg)
				_on_hero_hit_enemy(target, before_hp)
				# Heal if attack actually reduced HP (accounts for vuln, bloodlust, block)
				if target.current_hp < before_hp:
					var heal_amt: int = card_data.get("heal_on_hit", 2)
					var lh: Node2D = card_hero if card_hero else player
					if lh:
						lh.heal(heal_amt)
		"blood_feast":
			var bf_hero: Node2D = card_hero if card_hero else player
			var base_dmg: int = card_data.get("damage", 7)
			if bf_hero:
				base_dmg = bf_hero.get_attack_damage(base_dmg)
			if _double_damage_this_turn:
				base_dmg *= 2
			if target and target.alive:
				var hp_before_bf: int = target.current_hp
				target.take_damage(base_dmg)
				_on_hero_hit_enemy(target, hp_before_bf)
				if not target.alive and bf_hero:
					var hp_gain: int = card_data.get("max_hp_gain", 3)
					bf_hero.max_hp += hp_gain
					bf_hero.heal(hp_gain)
		"desperate_duel":
			var dd_hero: Node2D = card_hero if card_hero else player
			var dd_self_str: int = card_data.get("bf_self_str", 2)
			var dd_enemy_str: int = card_data.get("bf_enemy_str", 1)
			# Buff hero strength before attacking
			if dd_hero:
				dd_hero.apply_status("strength", dd_self_str)
			# Buff enemy strength
			if target and target.alive:
				target.apply_status("strength", dd_enemy_str)
			# Now deal damage (includes the new strength)
			var dd_dmg: int = card_data.get("damage", 8)
			if dd_hero:
				dd_dmg = dd_hero.get_attack_damage(dd_dmg)
			if _double_damage_this_turn:
				dd_dmg *= 2
			if target and target.alive:
				_apply_single_hit_damage(dd_dmg, target, "enemy")
		"blood_wave":
			var bw_hero: Node2D = card_hero if card_hero else player
			var base_dmg: int = card_data.get("damage", 5)
			if bw_hero:
				base_dmg = bw_hero.get_attack_damage(base_dmg)
			if _double_damage_this_turn:
				base_dmg *= 2
			var vuln_stacks_bw: int = card_data.get("apply_status", {}).get("stacks", 1)
			for enemy in enemies:
				if enemy.alive:
					var hp_before_bwave: int = enemy.current_hp
					enemy.take_damage(base_dmg)
					_on_hero_hit_enemy(enemy, hp_before_bwave)
					enemy.apply_status("vulnerable", vuln_stacks_bw)
			_bf_on_apply_vulnerable_check(bw_hero, "vulnerable", vuln_stacks_bw)
		"blood_fang":
			var bfang_hero: Node2D = card_hero if card_hero else player
			var base_dmg_bfang: int = card_data.get("damage", 6)
			if bfang_hero:
				base_dmg_bfang = bfang_hero.get_attack_damage(base_dmg_bfang)
			if _double_damage_this_turn:
				base_dmg_bfang *= 2
			var hits_bfang: int = card_data.get("times", 2)
			var bl_on_unblocked: int = card_data.get("bf_bloodlust_on_unblocked", 1)
			for _hh in range(hits_bfang):
				if target and target.alive:
					var before_hp_bfang: int = target.current_hp
					target.take_damage(base_dmg_bfang)
					var hp_dmg_bfang: int = before_hp_bfang - target.current_hp
					if hp_dmg_bfang > 0:
						target.apply_status("bloodlust", bl_on_unblocked)
						_bf_on_apply_bloodlust_check(bfang_hero, target, bl_on_unblocked)
					_on_hero_hit_enemy(target, before_hp_bfang)
		"blood_rage":
			var br_hero2: Node2D = card_hero if card_hero else player
			var base_dmg: int = card_data.get("damage", 6)
			if br_hero2:
				base_dmg = br_hero2.get_attack_damage(base_dmg)
			if _double_damage_this_turn:
				base_dmg *= 2
			var hits_br: int = 1 + hp_loss_count_this_turn
			_apply_multi_hit_damage(base_dmg, hits_br, target, target_type)
		"siphon_life":
			var sl_hero: Node2D = card_hero if card_hero else player
			if target and target.alive:
				var bl_stacks: int = target.get_status_stacks("bloodlust")
				if bl_stacks > 0 and sl_hero:
					var mult: int = card_data.get("bf_siphon_mult", 1)
					sl_hero.heal(bl_stacks * mult)
				target.status_effects.erase("bloodlust")
				target.status_changed.emit("bloodlust", 0)
				target._update_status_display()
		"blood_mirror":
			var bm_hero: Node2D = card_hero if card_hero else player
			if bm_hero:
				bm_hero.take_damage_direct(3)
				_bf_on_hp_loss(bm_hero, 3)
			var bl_apply: int = card_data.get("bf_bloodlust_all", 2)
			for enemy in enemies:
				if enemy.alive:
					enemy.apply_status("bloodlust", bl_apply)
					_bf_on_apply_bloodlust_check(bm_hero, enemy, bl_apply)
		"bloodbath":
			# Exhaust 1 card, apply bloodlust + vulnerable to target
			if hand.is_empty():
				_apply_bloodbath_effect(card_data, target, card_hero)
			elif hand.size() <= 1:
				var c = hand[0]
				hand.remove_at(0)
				_exhaust_card(c)
				if card_hand:
					card_hand.clear_hand()
				_apply_bloodbath_effect(card_data, target, card_hero)
			else:
				_bloodbath_target = target
				_bloodbath_card_data = card_data
				_bloodbath_hero = card_hero
				_show_discard_selection(1, _on_bloodbath_exhaust_done)
				return
		"blood_pact":
			# Exhaust 1 card, draw N (like burning_pact)
			var bp_draw: int = card_data.get("draw", 2)
			if hand.is_empty():
				draw_cards(bp_draw)
			elif hand.size() <= 1:
				var c = hand[0]
				hand.remove_at(0)
				_exhaust_card(c)
				if card_hand:
					card_hand.clear_hand()
				draw_cards(bp_draw)
			else:
				_blood_pact_draw = bp_draw
				_show_discard_selection(1, _on_blood_pact_exhaust_done)
				return
		"bloodrage":
			var br_hero: Node2D = card_hero if card_hero else player
			for h_br in _get_all_alive_heroes():
				h_br.take_damage_direct(2)
				_bf_on_hp_loss(h_br, 2)
			for enemy in enemies:
				if enemy.alive:
					enemy.apply_status("vulnerable", 1)
			_bf_on_apply_vulnerable_check(br_hero, "vulnerable", 1)
			var flex_str: int = card_data.get("flex_stacks", 2)
			if br_hero:
				br_hero.apply_status("strength", flex_str)
				_bf_flex_heroes.append({"hero": br_hero, "stacks": flex_str})
		"vital_guard":
			var vg_hero: Node2D = card_hero if card_hero else player
			if vg_hero:
				var base_block: int = card_data.get("block", 6)
				var bonus: int = card_data.get("bonus_block", 6)
				var threshold: float = card_data.get("hp_threshold", 0.28)
				var total_block: int = base_block
				if vg_hero.max_hp > 0 and float(vg_hero.current_hp) / float(vg_hero.max_hp) < threshold:
					total_block += bonus
				vg_hero.add_block(total_block)
				_fg_on_hero_gain_block(vg_hero, total_block)
				_trigger_juggernaut()
		"blood_rush":
			# Let the player choose an attack card to reduce its cost by 1
			var has_attacks: bool = false
			for c in hand:
				if c.get("type", -1) == 0:
					has_attacks = true
					break
			if has_attacks:
				_blood_rush_mode = true
				if card_hand:
					card_hand._discard_type_filter = 0  # Attack cards only
				_show_discard_selection(1, _on_blood_rush_done)
				return
			# No attacks in hand — do nothing
		"bloodhound":
			var draw_n: int = card_data.get("bf_draw_count", 3)
			var hand_before: int = hand.size()
			draw_cards(draw_n, true)  # instant=true to avoid tween race
			# Discard non-attack cards that were just drawn
			var to_discard_bh: Array = []
			for i in range(hand_before, hand.size()):
				if hand[i].get("type", -1) != 0:  # Not ATTACK
					to_discard_bh.append(hand[i])
			for c in to_discard_bh:
				hand.erase(c)
				discard_pile.append(c)
				_check_sly_on_discard(c)
				# Remove visual card node
				if card_hand:
					for card_node in card_hand.cards.duplicate():
						if is_instance_valid(card_node) and card_node.card_data == c:
							card_hand.remove_card(card_node)
							break
		"survival_instinct":
			var si_hero: Node2D = card_hero if card_hero else player
			if si_hero:
				var threshold_pct: float = 0.25
				var is_low: bool = si_hero.max_hp > 0 and float(si_hero.current_hp) / float(si_hero.max_hp) < threshold_pct
				var block_val: int = card_data.get("bf_low_hp_block", 6) if is_low else card_data.get("block", 3)
				si_hero.add_block(block_val)
				_fg_on_hero_gain_block(si_hero, block_val)
				_trigger_juggernaut()

		# ══════════════════════════════════════════════════════════════════════
		# FORGER CARD HANDLERS
		# ══════════════════════════════════════════════════════════════════════
		"sword_crash":
			# Damage = greatsword HP (upgraded: ×1.5)
			var mult: float = card_data.get("fg_sword_mult", 1.0)
			var dmg: int = int(_get_greatsword_attack_damage() * mult)
			if dmg > 0 and card_hero:
				dmg = card_hero.get_attack_damage(dmg) - card_hero.get_status_stacks("strength")
				dmg += card_hero.get_status_stacks("strength")
			if dmg > 0:
				_play_greatsword_attack_effect(target)
				_apply_single_hit_damage(dmg, target, target_type)
		"riposte_strike":
			var base_dmg: int = card_data.get("damage", 6)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			var thorns_mult: int = card_data.get("fg_thorns_mult", 2)
			var hero_thorns: int = 0
			if card_hero:
				hero_thorns = card_hero.get_status_stacks("thorns")
			base_dmg += hero_thorns * thorns_mult
			_apply_single_hit_damage(base_dmg, target, target_type)
		"fg_shield_bash":
			var sh_hero: Node2D = card_hero if card_hero else player
			if sh_hero:
				var dmg: int = sh_hero.block
				if dmg > 0:
					_apply_single_hit_damage(dmg, target, target_type)
		"forge_slam":
			var base_dmg: int = card_data.get("damage", 12)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			_apply_single_hit_damage(base_dmg, target, target_type)
			var forge_amt: int = card_data.get("fg_forge", 5)
			_forge_sword(forge_amt)
		"greatsword_cleave":
			var mult: float = card_data.get("fg_sword_mult", 1.0)
			var dmg: int = int(_get_greatsword_attack_damage() * mult)
			if dmg > 0:
				_play_greatsword_attack_effect(target)
				_apply_single_hit_damage(dmg, target, "all_enemies")
		"magnetic_edge":
			var forge_amt: int = card_data.get("fg_forge", 4)
			_forge_sword(forge_amt)
			var threshold: int = card_data.get("fg_threshold", 20)
			var base_dmg: int = card_data.get("damage", 5)
			if _greatsword_hp >= threshold:
				base_dmg = card_data.get("fg_threshold_damage", 12)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			_apply_single_hit_damage(base_dmg, target, target_type)
		"molten_core":
			var base_dmg: int = card_data.get("damage", 8)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			var times: int = card_data.get("times", 2)
			_apply_multi_hit_damage(base_dmg, times, target, target_type)
			var forge_amt: int = card_data.get("fg_forge", 6)
			_forge_sword(forge_amt)
		"hardened_blade":
			var base_dmg: int = card_data.get("damage", 8)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			_apply_single_hit_damage(base_dmg, target, target_type)
			if _greatsword_hp > 0:
				var blk: int = card_data.get("fg_sword_block", 4)
				var hero_blk: Node2D = card_hero if card_hero else player
				if hero_blk:
					hero_blk.add_block(blk)
					_trigger_juggernaut()
					_fg_on_hero_gain_block(hero_blk, blk)
		"reforged_edge":
			var base_dmg: int = card_data.get("damage", 7)
			if _forged_this_turn:
				base_dmg += card_data.get("fg_forged_bonus", 7)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			_apply_single_hit_damage(base_dmg, target, target_type)
		"eruption_strike":
			var base_dmg: int = card_data.get("damage", 15)
			if card_hero:
				base_dmg = card_hero.get_attack_damage(base_dmg)
			_apply_single_hit_damage(base_dmg, target, target_type)
			_next_turn_effects.append({"type": "gain_energy", "value": 1})
			var forge_amt: int = card_data.get("fg_forge", 4)
			_forge_sword(forge_amt)
		"blade_storm":
			var pct: int = card_data.get("fg_sword_pct", 50)
			var dmg: int = int(_get_greatsword_attack_damage() * pct / 100.0)
			var hits: int = card_data.get("fg_hits", 3)
			if dmg > 0:
				_play_greatsword_attack_effect(target)
				_apply_multi_hit_damage(dmg, hits, target, "all_enemies")

		# ── Forger Skills ──
		"delay_charge":
			var forge_amt: int = card_data.get("fg_forge", 5)
			_forge_sword(forge_amt)
			var next_energy: int = card_data.get("fg_next_energy", 1)
			_next_turn_effects.append({"type": "gain_energy", "value": next_energy})
		"sharpen":
			var forge_amt: int = card_data.get("fg_forge", 8)
			_forge_sword(forge_amt)
			draw_cards(card_data.get("draw", 1))
		"forge_armor":
			var blk: int = card_data.get("block", 10)
			var hero_blk: Node2D = card_hero if card_hero else player
			if hero_blk:
				hero_blk.add_block(blk)
				_trigger_juggernaut()
				_fg_on_hero_gain_block(hero_blk, blk)
			var forge_amt: int = card_data.get("fg_forge", 5)
			_forge_sword(forge_amt)
		"impervious_wall":
			var forge_amt: int = card_data.get("fg_forge", 20)
			_forge_sword(forge_amt)
		"block_transfer":
			var total_block: int = 0
			for hero in _get_all_alive_heroes():
				total_block += hero.block
				hero.reset_block()
			if total_block > 0:
				_forge_sword(total_block)
		"summon_sword":
			var hp_val: int = card_data.get("fg_summon_hp", 10)
			_summon_greatsword(hp_val)
		"reinforce":
			if _greatsword_hp > 0:
				var pct: int = card_data.get("fg_reinforce_pct", 70)
				var bonus: int = int(_greatsword_hp * pct / 100.0)
				_greatsword_hp += bonus
				_greatsword_max_hp = maxi(_greatsword_max_hp, _greatsword_hp)
				_update_greatsword_display()
		"temper":
			var blk: int = card_data.get("block", 6)
			var hero_blk: Node2D = card_hero if card_hero else player
			if hero_blk:
				hero_blk.add_block(blk)
				_trigger_juggernaut()
				_fg_on_hero_gain_block(hero_blk, blk)
			var next_block: int = card_data.get("fg_next_block", 6)
			_next_turn_effects.append({"type": "block", "value": next_block})
		"forge_shield":
			var blk: int = card_data.get("block", 12)
			var hero_blk: Node2D = card_hero if card_hero else player
			if hero_blk:
				hero_blk.add_block(blk)
				_trigger_juggernaut()
				_fg_on_hero_gain_block(hero_blk, blk)
			var next_draw: int = card_data.get("fg_next_draw", 2)
			_next_turn_effects.append({"type": "draw", "value": next_draw})
		"melt_down":
			# Exhaust 1 card, add cost×N to sword, next turn draw
			if hand.is_empty():
				var next_draw: int = card_data.get("fg_next_draw", 1)
				_next_turn_effects.append({"type": "draw", "value": next_draw})
			elif hand.size() <= 1:
				var c = hand[0]
				var cost_val: int = maxi(c.get("cost", 0), 0)
				hand.remove_at(0)
				_exhaust_card(c)
				if card_hand:
					card_hand.clear_hand()
				var mult: int = card_data.get("fg_cost_mult", 6)
				_forge_sword(cost_val * mult)
				var next_draw: int = card_data.get("fg_next_draw", 1)
				_next_turn_effects.append({"type": "draw", "value": next_draw})
			else:
				_fg_melt_down_pending = true
				_discard_as_exhaust = true
				_show_discard_selection(1, func():
					# Find the exhausted card's cost
					# The last exhausted card is the one we just picked
					var last_exhausted = exhaust_pile.back() if not exhaust_pile.is_empty() else {}
					var cost_val: int = maxi(last_exhausted.get("cost", 0), 0)
					var mult: int = card_data.get("fg_cost_mult", 6)
					_forge_sword(cost_val * mult)
					var next_draw: int = card_data.get("fg_next_draw", 1)
					_next_turn_effects.append({"type": "draw", "value": next_draw})
					_fg_melt_down_pending = false
					_update_pile_labels()
				)
				if _discard_title_label:
					_discard_title_label.text = "选择 1 张牌消耗"
				return
		"overcharge":
			_greatsword_double_damage = true
		"absorb_impact":
			var sword_cost: int = card_data.get("fg_sword_cost", 5)
			_greatsword_hp = maxi(0, _greatsword_hp - sword_cost)
			_update_greatsword_display()
			var blk: int = card_data.get("block", 8)
			var hero_blk: Node2D = card_hero if card_hero else player
			if hero_blk:
				hero_blk.add_block(blk)
				_trigger_juggernaut()
				_fg_on_hero_gain_block(hero_blk, blk)
		"heat_treat":
			var forge_amt: int = card_data.get("fg_forge", 6)
			_forge_sword(forge_amt)
			var thorns_val: int = card_data.get("fg_thorns", 1)
			var ht_hero: Node2D = card_hero if card_hero else player
			if ht_hero:
				ht_hero.apply_status("thorns", thorns_val)
		"forge_barrier":
			var mult: float = card_data.get("fg_barrier_mult", 1.0)
			var blk: int = int(_greatsword_hp * mult)
			var hero_blk: Node2D = card_hero if card_hero else player
			if hero_blk and blk > 0:
				hero_blk.add_block(blk)
				_trigger_juggernaut()
				_fg_on_hero_gain_block(hero_blk, blk)
		"sword_sacrifice":
			var hero_blk: Node2D = card_hero if card_hero else player
			var bonus: int = card_data.get("fg_sacrifice_block_bonus", 10)
			var blk: int = _greatsword_hp + bonus
			if hero_blk and blk > 0:
				hero_blk.add_block(blk)
				_trigger_juggernaut()
				_fg_on_hero_gain_block(hero_blk, blk)
			var aoe_dmg: int = card_data.get("fg_sacrifice_dmg", 10)
			for enemy in enemies:
				if enemy.alive:
					var hp_before_ss: int = enemy.current_hp
					enemy.take_damage(aoe_dmg)
					_on_hero_hit_enemy(enemy, hp_before_ss)
			_destroy_greatsword()
			_greatsword_no_summon_this_turn = true
		"thorn_forge":
			var hero_thorns: int = card_data.get("fg_hero_thorns", 4)
			var hero_tf: Node2D = card_hero if card_hero else player
			if hero_tf:
				hero_tf.apply_status("thorns", hero_thorns)
			var sword_thorns: int = card_data.get("fg_sword_thorns", 4)
			_greatsword_temp_thorns += sword_thorns
			_update_greatsword_display()
		"salvage":
			var blk: int = card_data.get("block", 6)
			var hero_blk: Node2D = card_hero if card_hero else player
			if hero_blk:
				hero_blk.add_block(blk)
				_trigger_juggernaut()
				_fg_on_hero_gain_block(hero_blk, blk)
			# Pick 1 card from discard pile → top of draw pile
			if not discard_pile.is_empty():
				_fg_salvage_mode = true
				_show_discard_selection(1, func():
					# Move selected card from discard to draw pile top
					if not _discard_selected_cards.is_empty():
						var idx: int = _discard_selected_cards[0]
						if idx >= 0 and idx < discard_pile.size():
							var card = discard_pile[idx]
							discard_pile.remove_at(idx)
							draw_pile.append(card)
					_fg_salvage_mode = false
					_update_pile_labels()
				)
				return
		"thorn_wall":
			var blk: int = card_data.get("block", 12)
			var hero_blk: Node2D = card_hero if card_hero else player
			if hero_blk:
				hero_blk.add_block(blk)
				_trigger_juggernaut()
				_fg_on_hero_gain_block(hero_blk, blk)
			var thorns_val: int = card_data.get("fg_thorns", 3)
			if hero_blk:
				hero_blk.apply_status("thorns", thorns_val)
		"quick_temper":
			var forge_amt: int = card_data.get("fg_forge", 3)
			_forge_sword(forge_amt)
			if card_data.get("draw", 0) > 0:
				draw_cards(card_data["draw"])
		"chain_forge":
			var forge_base: int = card_data.get("fg_forge_base", 4)
			var forge_chain: int = card_data.get("fg_forge_chain", 8)
			var forge_amt: int = forge_chain if _forged_this_turn else forge_base
			_forge_sword(forge_amt)
			draw_cards(1)
		"repurpose":
			# Exhaust 1 card, block = cost×N, forge = cost×M
			if hand.is_empty():
				pass
			elif hand.size() <= 1:
				var c = hand[0]
				var cost_val: int = maxi(c.get("cost", 0), 0)
				hand.remove_at(0)
				_exhaust_card(c)
				if card_hand:
					card_hand.clear_hand()
				var blk_mult: int = card_data.get("fg_block_mult", 4)
				var forge_mult: int = card_data.get("fg_forge_mult", 3)
				var hero_blk: Node2D = card_hero if card_hero else player
				if hero_blk:
					hero_blk.add_block(cost_val * blk_mult)
					_trigger_juggernaut()
				_forge_sword(cost_val * forge_mult)
			else:
				_discard_as_exhaust = true
				_show_discard_selection(1, func():
					var last_exhausted = exhaust_pile.back() if not exhaust_pile.is_empty() else {}
					var cost_val: int = maxi(last_exhausted.get("cost", 0), 0)
					var blk_mult: int = card_data.get("fg_block_mult", 4)
					var forge_mult: int = card_data.get("fg_forge_mult", 3)
					var hero_blk: Node2D = card_hero if card_hero else player
					if hero_blk:
						hero_blk.add_block(cost_val * blk_mult)
						_trigger_juggernaut()
					_forge_sword(cost_val * forge_mult)
					_update_pile_labels()
				)
				if _discard_title_label:
					_discard_title_label.text = "选择 1 张牌消耗"
				return

		# ── Forger Powers (call-type) ──
		"thorn_aura":
			var hero_thorns: int = card_data.get("fg_hero_thorns", 3)
			var hero_ta: Node2D = card_hero if card_hero else player
			if hero_ta:
				hero_ta.apply_status("thorns", hero_thorns)
				hero_ta.add_power("fg_thorn_aura", hero_thorns)
			var sword_thorns: int = card_data.get("fg_sword_thorns", 3)
			_greatsword_thorns += sword_thorns
			_update_greatsword_display()
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
					aoe_tween.tween_callback(_hit_enemy_with_effects.bind(enemy, dmg))
				else:
					_hit_enemy_with_effects(enemy, dmg)
				delay += 0.12
	elif target_type == "random_enemy":
		var alive = _get_alive_enemies()
		if not alive.is_empty():
			var rand_target = alive[randi() % alive.size()]
			_hit_enemy_with_effects(rand_target, dmg)
	elif target != null and target.alive:
		_hit_enemy_with_effects(target, dmg)

func _hit_enemy_with_effects(enemy: Node2D, dmg: int) -> void:
	if not enemy.alive or not enemy.is_enemy:
		return
	var hp_before: int = enemy.current_hp
	enemy.take_damage(dmg)
	_on_hero_hit_enemy(enemy, hp_before)

func _on_hero_hit_enemy(enemy: Node2D, hp_before: int) -> void:
	## Global post-damage effects: envenom, sanguine aura, then hemophilia.
	## Call after ANY hero attack deals damage to an enemy.
	var took_hp_damage: bool = enemy.current_hp < hp_before
	# Envenom: apply poison on hit
	if envenom_stacks > 0 and enemy.alive:
		enemy.apply_status("poison", envenom_stacks)
	# Sanguine Aura: apply bloodlust only on unblocked damage (before hemophilia check)
	if took_hp_damage:
		for _h in _get_all_alive_heroes():
			var sa: int = _h.active_powers.get("sanguine_aura", 0)
			if sa > 0 and enemy.alive:
				enemy.apply_status("bloodlust", sa)
				_bf_on_apply_bloodlust_check(_h, enemy, sa)
	# Hemophilia: heal when enemy has bloodlust (checked AFTER sanguine aura may apply it)
	if enemy.get_status_stacks("bloodlust") > 0:
		_bf_hemophilia_heal()

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
		_fg_on_hero_gain_block(player, block_val)
		_trigger_juggernaut()
	if draw_count > 0:
		draw_cards(draw_count)

# ── Blood Fiend Helpers ──────────────────────────────────────────────────────
func _apply_bloodbath_effect(card_data: Dictionary, target: Node2D, hero: Node2D) -> void:
	var bl_stacks: int = card_data.get("bf_bloodlust_apply", 2)
	if target and target.alive:
		target.apply_status("bloodlust", bl_stacks)
		_bf_on_apply_bloodlust_check(hero, target, bl_stacks)
		var vuln: Dictionary = card_data.get("apply_status", {})
		if not vuln.is_empty():
			target.apply_status(vuln.get("type", "vulnerable"), vuln.get("stacks", 1))
			_bf_on_apply_vulnerable_check(hero, "vulnerable", vuln.get("stacks", 1))
	_update_pile_labels()

func _on_bloodbath_exhaust_done() -> void:
	_apply_bloodbath_effect(_bloodbath_card_data, _bloodbath_target, _bloodbath_hero)

func _on_blood_pact_exhaust_done() -> void:
	draw_cards(_blood_pact_draw)
	_update_pile_labels()

func _on_blood_rush_done() -> void:
	# Card was cost-reduced in place by _on_discard_confirm (blood_rush_mode)
	_update_pile_labels()

func _bf_on_hp_loss(hero: Node2D, amount: int) -> void:
	## Trigger all bloodfiend powers that react to HP loss
	hp_lost_this_combat += amount
	hp_loss_count_this_turn += 1
	if hero == null:
		return
	# Bloodlust power: gain strength on HP loss
	var bl_power: int = hero.active_powers.get("bf_bloodlust_power", 0)
	if bl_power > 0:
		hero.apply_status("strength", bl_power)
	# Pain Threshold: draw + block on HP loss
	var pt: int = hero.active_powers.get("pain_threshold", 0)
	if pt > 0:
		draw_cards(1)
		hero.add_block(pt)
		_fg_on_hero_gain_block(hero, pt)
		_trigger_juggernaut()

func _bf_on_apply_vulnerable_check(hero: Node2D, _status_type: String, _stacks: int) -> void:
	## Trigger powers that react to applying vulnerable
	if hero == null:
		return
	# Predator's Mark: gain strength when applying vulnerable
	var pm: int = hero.active_powers.get("predators_mark", 0)
	if pm > 0:
		hero.apply_status("strength", pm)
	# Blood Scent: draw when applying vulnerable
	var bs: int = hero.active_powers.get("blood_scent", 0)
	if bs > 0:
		draw_cards(bs)

func _bf_on_apply_bloodlust_check(hero: Node2D, enemy_node: Node2D, _stacks: int) -> void:
	## Trigger powers that react to applying bloodlust to an enemy
	if hero == null:
		return
	# Scarlet Chains: applying bloodlust also applies weak
	if hero.active_powers.get("scarlet_chains", 0) > 0 and enemy_node and enemy_node.alive:
		enemy_node.apply_status("weak", 1)

func _bf_hemophilia_heal() -> void:
	## Hemophilia: when enemy takes bloodlust damage, heal 1 HP per hero with the power
	for _h in _get_all_alive_heroes():
		var hemo: int = _h.active_powers.get("hemophilia", 0)
		if hemo > 0:
			_h.heal(1)

# ── Forger / Greatsword Helpers ──────────────────────────────────────────────
func _forge_sword(amount: int) -> void:
	## Add HP to greatsword. Auto-summons if not alive. Triggers Forge Master.
	if _greatsword_no_summon_this_turn and _greatsword_hp <= 0:
		return  # Cannot summon this turn (Sword Sacrifice)
	var was_dead: bool = _greatsword_hp <= 0
	# Forge Master bonus
	var bonus: int = 0
	for hero in _get_all_alive_heroes():
		bonus += hero.active_powers.get("fg_forge_master", 0)
	var total: int = amount + bonus
	if _greatsword_hp <= 0:
		_greatsword_hp = total
	else:
		_greatsword_hp += total
	_greatsword_max_hp = maxi(_greatsword_max_hp, _greatsword_hp)
	_forged_this_turn = true
	_update_greatsword_display()
	if was_dead:
		_play_summon_effect()
	else:
		_play_forge_effect()
	# Resonance check is handled by block gain, not forge

func _summon_greatsword(hp: int) -> void:
	## Summon or add HP to greatsword
	if _greatsword_no_summon_this_turn and _greatsword_hp <= 0:
		return
	var was_dead: bool = _greatsword_hp <= 0
	if _greatsword_hp <= 0:
		_greatsword_hp = hp
	else:
		_greatsword_hp += hp
	_greatsword_max_hp = maxi(_greatsword_max_hp, _greatsword_hp)
	_update_greatsword_display()
	if was_dead:
		_play_summon_effect()
	else:
		_play_forge_effect()

func _destroy_greatsword() -> void:
	var was_alive: bool = _greatsword_hp > 0
	_greatsword_hp = 0
	_greatsword_thorns = 0
	_greatsword_temp_thorns = 0
	if was_alive:
		_play_shatter_effect()
	_update_greatsword_display()

func _greatsword_take_damage(dmg: int, attacker: Node2D) -> int:
	## Greatsword absorbs damage. Returns remaining damage to pass through.
	if _greatsword_hp <= 0:
		return dmg
	# Greatsword thorns: deal damage back to attacker
	var total_thorns: int = _greatsword_thorns + _greatsword_temp_thorns
	if total_thorns > 0 and attacker and attacker.alive:
		attacker.take_damage(total_thorns)
	# Iron Skin: hero gains block equal to damage taken by sword
	for hero in _get_all_alive_heroes():
		var iron_skin: int = hero.active_powers.get("fg_iron_skin", 0)
		if iron_skin > 0:
			var is_blk: int = dmg + iron_skin - 1
			hero.add_block(is_blk)
			_fg_on_hero_gain_block(hero, is_blk)
			_trigger_juggernaut()
	# Counter Forge: forge on sword hit
	for hero in _get_all_alive_heroes():
		var cf: int = hero.active_powers.get("fg_counter_forge", 0)
		if cf > 0:
			_forge_sword(cf)
	var absorbed: int = mini(dmg, _greatsword_hp)
	_greatsword_hp -= absorbed
	if _greatsword_hp <= 0:
		_greatsword_hp = 0
		_greatsword_thorns = 0
		_greatsword_temp_thorns = 0
		_play_shatter_effect()
	_update_greatsword_display()
	return dmg - absorbed

func _get_greatsword_attack_damage() -> int:
	## Get greatsword HP as attack damage, applying double damage if active
	var dmg: int = _greatsword_hp
	if _greatsword_double_damage:
		dmg *= 2
	return dmg

func _update_greatsword_display() -> void:
	## Update or create the greatsword visual display
	if _greatsword_node == null:
		_create_greatsword_visual()
	if _greatsword_node == null:
		return
	_greatsword_node.visible = _greatsword_hp > 0
	# Update HP label
	var hp_label: Label = _greatsword_node.get_node_or_null("HPLabel")
	if hp_label:
		hp_label.text = "%d" % _greatsword_hp
	# Update HP bar fill
	var hp_bar_fill: ColorRect = _greatsword_node.get_node_or_null("HPBarFill")
	if hp_bar_fill:
		var max_hp: int = maxi(_greatsword_max_hp, 1)
		var ratio: float = clampf(float(_greatsword_hp) / float(max_hp), 0.0, 1.0)
		hp_bar_fill.size.x = 100.0 * ratio
	# Update thorns label
	var thorns_label: Label = _greatsword_node.get_node_or_null("ThornsLabel")
	if thorns_label:
		var total_thorns: int = _greatsword_thorns + _greatsword_temp_thorns
		thorns_label.visible = total_thorns > 0
		thorns_label.text = "荆棘 %d" % total_thorns

func _create_greatsword_visual() -> void:
	## Create the greatsword as a Node2D positioned next to the hero, HP bar aligned with hero's
	if player_area == null:
		return
	_greatsword_node = Node2D.new()
	_greatsword_node.name = "Greatsword"
	_greatsword_node.visible = false
	# Position: 70% of the distance between hero and enemy area
	var hero_x: float = 0.0
	if player:
		hero_x = player.position.x
	var gap: float = 720.0  # default PlayerArea-EnemyArea distance
	if enemy_area and player_area:
		gap = enemy_area.position.x - player_area.position.x
	_greatsword_node.position = Vector2(hero_x + gap * 0.7, 0)
	_greatsword_node.z_index = 5
	player_area.add_child(_greatsword_node)

	# Sword sprite — 80% of hero height
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	var sword_path := "res://assets/img/greatsword_v2.png"
	if not ResourceLoader.exists(sword_path):
		sword_path = "res://assets/img/greatsword.png"
	if ResourceLoader.exists(sword_path):
		sprite.texture = load(sword_path)
	var target_h: float = player_sprite_scale_height * 0.8  # 80% of hero height
	var tex_h: float = 512.0
	if sprite.texture:
		tex_h = sprite.texture.get_height()
	var sword_sf: float = target_h / tex_h
	sprite.scale = Vector2(sword_sf, sword_sf)
	sprite.position = Vector2(0, 30)  # Shift down so bottom half looks buried
	_greatsword_node.add_child(sprite)

	# Ground cover — dark bar to simulate "buried in ground"
	var ground := ColorRect.new()
	ground.name = "Ground"
	ground.color = Color(0.15, 0.12, 0.08, 0.9)
	ground.size = Vector2(80, 20)
	ground.position = Vector2(-40, 80)
	_greatsword_node.add_child(ground)

	# HP bar background — aligned with hero HP bar (y=150 in entity_template)
	var hp_bar_bg := ColorRect.new()
	hp_bar_bg.name = "HPBarBG"
	hp_bar_bg.color = Color(0.2, 0.06, 0.06, 1.0)
	hp_bar_bg.size = Vector2(100, 10)
	hp_bar_bg.position = Vector2(-50, 150)
	_greatsword_node.add_child(hp_bar_bg)

	# HP bar fill
	var hp_bar_fill := ColorRect.new()
	hp_bar_fill.name = "HPBarFill"
	hp_bar_fill.color = Color(0.9, 0.5, 0.1, 1.0)
	hp_bar_fill.size = Vector2(100, 10)
	hp_bar_fill.position = Vector2(-50, 150)
	_greatsword_node.add_child(hp_bar_fill)

	# HP label — matches hero HP label position (y=140)
	var hp_label := Label.new()
	hp_label.name = "HPLabel"
	hp_label.text = "0"
	hp_label.add_theme_font_size_override("font_size", 22)
	hp_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	hp_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	hp_label.add_theme_constant_override("shadow_offset_x", 1)
	hp_label.add_theme_constant_override("shadow_offset_y", 1)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.size = Vector2(100, 30)
	hp_label.position = Vector2(-50, 135)
	_greatsword_node.add_child(hp_label)

	# Title label below HP bar
	var title := Label.new()
	title.name = "Title"
	title.text = "巨剑"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.8, 0.65, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(100, 18)
	title.position = Vector2(-50, 162)
	_greatsword_node.add_child(title)

	# Thorns label (hidden by default)
	var thorns_label := Label.new()
	thorns_label.name = "ThornsLabel"
	thorns_label.text = ""
	thorns_label.visible = false
	thorns_label.add_theme_font_size_override("font_size", 12)
	thorns_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.3))
	thorns_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thorns_label.size = Vector2(100, 16)
	thorns_label.position = Vector2(-50, 178)
	_greatsword_node.add_child(thorns_label)

func _play_forge_effect() -> void:
	## Play forge animation: orange glow + sparks on the greatsword
	if _greatsword_node == null or not _greatsword_node.visible:
		return
	var sword_pos: Vector2 = _greatsword_node.global_position + Vector2(0, 20)
	# Orange glow flash on sword
	var glow := ColorRect.new()
	glow.color = Color(1.0, 0.6, 0.1, 0.7)
	glow.size = Vector2(60, 80)
	glow.position = sword_pos + Vector2(-30, -50)
	glow.z_index = 200
	add_child(glow)
	var tw := create_tween()
	tw.tween_property(glow, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_callback(glow.queue_free)
	# Sparks particles
	for i in range(6):
		var spark := Polygon2D.new()
		spark.polygon = PackedVector2Array([
			Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)
		])
		spark.color = Color(1.0, 0.7 + randf() * 0.3, 0.1, 1.0)
		spark.position = sword_pos + Vector2(randf_range(-20, 20), randf_range(-40, 10))
		spark.z_index = 210
		add_child(spark)
		var stw := create_tween()
		stw.set_parallel(true)
		var end_pos: Vector2 = spark.position + Vector2(randf_range(-30, 30), randf_range(-60, -20))
		stw.tween_property(spark, "position", end_pos, 0.4 + randf() * 0.3)
		stw.tween_property(spark, "modulate:a", 0.0, 0.5)
		stw.set_parallel(false)
		stw.tween_callback(spark.queue_free)
	# Sword pulse scale
	var sprite: Node = _greatsword_node.get_node_or_null("Sprite")
	if sprite:
		var orig_scale: Vector2 = sprite.scale
		var ptw := create_tween()
		ptw.tween_property(sprite, "scale", orig_scale * 1.15, 0.1).set_ease(Tween.EASE_OUT)
		ptw.tween_property(sprite, "scale", orig_scale, 0.2).set_ease(Tween.EASE_IN)

func _play_greatsword_attack_effect(target: Node2D) -> void:
	## Play greatsword attack animation: sword swings toward target then returns
	if _greatsword_node == null or not _greatsword_node.visible:
		return
	var sprite: Node = _greatsword_node.get_node_or_null("Sprite")
	if sprite == null:
		return
	# Swing animation: tilt toward enemy, then spring back
	var tw := create_tween()
	# Wind up — tilt back
	tw.tween_property(sprite, "rotation", -0.3, 0.1).set_ease(Tween.EASE_IN)
	# Swing forward — tilt toward enemy
	tw.tween_property(sprite, "rotation", 0.5, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Hit effect at target
	tw.tween_callback(func():
		if target and is_instance_valid(target):
			_generic_hit_effect(target)
		# Slash arc from sword to target
		var slash := Polygon2D.new()
		slash.polygon = PackedVector2Array([
			Vector2(0, -8), Vector2(80, -3), Vector2(80, 3), Vector2(0, 8)
		])
		slash.color = Color(1.0, 0.6, 0.1, 0.8)
		slash.position = _greatsword_node.global_position + Vector2(20, 0)
		slash.z_index = 200
		add_child(slash)
		var stw := create_tween()
		stw.tween_property(slash, "modulate:a", 0.0, 0.3)
		stw.tween_callback(slash.queue_free)
	)
	# Return to neutral
	tw.tween_property(sprite, "rotation", 0.0, 0.2).set_ease(Tween.EASE_IN_OUT)

func _play_summon_effect() -> void:
	## Play summon animation: sword rises from ground with energy burst
	if _greatsword_node == null:
		return
	var sprite: Node = _greatsword_node.get_node_or_null("Sprite")
	if sprite == null:
		return
	# Sword rises up from below
	var orig_pos: Vector2 = sprite.position
	sprite.position = orig_pos + Vector2(0, 80)
	sprite.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "position", orig_pos, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(sprite, "modulate:a", 1.0, 0.3)
	tw.set_parallel(false)
	# Energy burst at sword position
	tw.tween_callback(func():
		var sword_pos: Vector2 = _greatsword_node.global_position + Vector2(0, 20)
		# Expanding ring
		var ring := Polygon2D.new()
		var pts: PackedVector2Array = PackedVector2Array()
		for a in range(0, 360, 15):
			pts.append(Vector2(cos(deg_to_rad(a)) * 5, sin(deg_to_rad(a)) * 5))
		ring.polygon = pts
		ring.color = Color(1.0, 0.7, 0.2, 0.8)
		ring.position = sword_pos
		ring.z_index = 200
		add_child(ring)
		var rtw := create_tween()
		rtw.set_parallel(true)
		rtw.tween_property(ring, "scale", Vector2(8, 8), 0.4).set_ease(Tween.EASE_OUT)
		rtw.tween_property(ring, "modulate:a", 0.0, 0.4)
		rtw.set_parallel(false)
		rtw.tween_callback(ring.queue_free)
		# Ground dust particles
		for i in range(8):
			var dust := Polygon2D.new()
			dust.polygon = PackedVector2Array([
				Vector2(-3, -2), Vector2(3, -2), Vector2(3, 2), Vector2(-3, 2)
			])
			dust.color = Color(0.6, 0.5, 0.3, 0.8)
			dust.position = sword_pos + Vector2(randf_range(-30, 30), 50)
			dust.z_index = 190
			add_child(dust)
			var dtw := create_tween()
			dtw.set_parallel(true)
			var end_p: Vector2 = dust.position + Vector2(randf_range(-20, 20), randf_range(-40, -15))
			dtw.tween_property(dust, "position", end_p, 0.5)
			dtw.tween_property(dust, "modulate:a", 0.0, 0.5)
			dtw.set_parallel(false)
			dtw.tween_callback(dust.queue_free)
	)

func _play_shatter_effect() -> void:
	## Play shatter animation: sword breaks into fragments that fly outward
	if _greatsword_node == null:
		return
	var sword_pos: Vector2 = _greatsword_node.global_position + Vector2(0, 20)
	# Screen shake (small)
	var orig_cam_pos: Vector2 = Vector2.ZERO
	var cam := get_viewport().get_camera_2d()
	if cam:
		orig_cam_pos = cam.offset
		var stw := create_tween()
		stw.tween_property(cam, "offset", orig_cam_pos + Vector2(4, -3), 0.05)
		stw.tween_property(cam, "offset", orig_cam_pos + Vector2(-4, 3), 0.05)
		stw.tween_property(cam, "offset", orig_cam_pos, 0.05)
	# Shatter fragments flying outward
	for i in range(12):
		var frag := Polygon2D.new()
		var fw: float = randf_range(4, 10)
		var fh: float = randf_range(6, 14)
		frag.polygon = PackedVector2Array([
			Vector2(-fw, -fh), Vector2(fw * 0.5, -fh * 0.7),
			Vector2(fw, fh * 0.3), Vector2(-fw * 0.3, fh)
		])
		frag.color = Color(0.4 + randf() * 0.2, 0.35 + randf() * 0.15, 0.25, 1.0)
		frag.position = sword_pos + Vector2(randf_range(-15, 15), randf_range(-40, 20))
		frag.z_index = 210
		add_child(frag)
		var ftw := create_tween()
		ftw.set_parallel(true)
		var end_pos: Vector2 = frag.position + Vector2(randf_range(-80, 80), randf_range(-60, 40))
		ftw.tween_property(frag, "position", end_pos, 0.5 + randf() * 0.3).set_ease(Tween.EASE_OUT)
		ftw.tween_property(frag, "rotation", randf_range(-TAU, TAU), 0.6)
		ftw.tween_property(frag, "modulate:a", 0.0, 0.6)
		ftw.set_parallel(false)
		ftw.tween_callback(frag.queue_free)
	# Red flash at sword position
	var flash := ColorRect.new()
	flash.color = Color(0.8, 0.2, 0.1, 0.6)
	flash.size = Vector2(80, 100)
	flash.position = sword_pos + Vector2(-40, -60)
	flash.z_index = 200
	add_child(flash)
	var flash_tw := create_tween()
	flash_tw.tween_property(flash, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_OUT)
	flash_tw.tween_callback(flash.queue_free)

func _reset_greatsword_for_battle() -> void:
	_greatsword_hp = 0
	_greatsword_max_hp = 0
	_greatsword_thorns = 0
	_greatsword_temp_thorns = 0
	_greatsword_double_damage = false
	_forged_this_turn = false
	_greatsword_no_summon_this_turn = false
	_fg_energy_reserve_active = false
	_fg_energy_reserve_bonus = 0
	_fg_melt_down_pending = false
	_fg_salvage_mode = false
	if _greatsword_node:
		_greatsword_node.visible = false

func _fg_on_hero_gain_block(_hero: Node2D, _amount: int) -> void:
	## Resonance: when a hero gains block, forge
	for h in _get_all_alive_heroes():
		var res_stacks: int = h.active_powers.get("fg_resonance", 0)
		if res_stacks > 0:
			_forge_sword(res_stacks)

func _fg_on_melt_down_exhaust_done() -> void:
	_update_pile_labels()

func _fg_on_repurpose_exhaust_done() -> void:
	_update_pile_labels()

func _fg_on_salvage_select_done() -> void:
	_fg_salvage_mode = false
	_update_pile_labels()

func _activate_power(power_name: String, power_target: Node2D = null, per_turn: Dictionary = {}, is_upgraded: bool = false) -> void:
	# Determine upgrade status from parameter or legacy _plus suffix
	var is_plus: bool = is_upgraded or power_name.ends_with("_plus")
	var base_name: String = power_name.trim_suffix("_plus") if power_name.ends_with("_plus") else power_name
	var hero = power_target if power_target else player

	# Determine stack value for the power icon display
	# Powers that show effect value as stacks (stackable across multiple plays)
	var power_stacks: int = 1  # Default
	var show_icon: bool = true  # Whether to show a power icon

	match base_name:
		"demon_form":
			demon_form_active = true
			power_stacks = 3 if is_plus else 2  # Strength gained per turn
		"caltrops":
			caltrops_active = true
			power_stacks = 5 if is_plus else 3  # Damage reflected per hit
		"envenom":
			envenom_stacks = 2 if is_plus else 1
			power_stacks = 2 if is_plus else 1  # Poison per unblocked hit
		"flame_barrier":
			flame_barrier_active = true
			flame_barrier_damage = 6 if is_plus else 4
			show_icon = false  # Skill card, not a persistent power
		"corruption":
			corruption_active = true
			if card_hand:
				card_hand.corruption_active = true
			power_stacks = 0  # Binary — no number
		"berserk":
			berserk_active = true
			if hero:
				hero.apply_status("vulnerable", 1)
			power_stacks = 2 if is_plus else 1  # Energy per turn
		"feel_no_pain":
			feel_no_pain_active = true
			feel_no_pain_block = 4 if is_plus else 3
			power_stacks = feel_no_pain_block
		"juggernaut":
			juggernaut_active = true
			juggernaut_damage = 7 if is_plus else 5
			power_stacks = juggernaut_damage
		"evolve":
			power_stacks = 2 if is_plus else 1  # Cards drawn per status
		"rage":
			rage_active = true
			rage_block = 5 if is_plus else 3
			power_stacks = rage_block
		"barricade":
			barricade_active = true
			power_stacks = 0  # Binary — no number
		"metallicize":
			metallicize_active = true
			metallicize_block = 4 if is_plus else 3
			power_stacks = metallicize_block
		"infinite_blades":
			infinite_blades_active = true
			power_stacks = 1  # Shivs per turn, stackable
		"noxious_fumes":
			power_stacks = 3 if is_plus else 2  # Poison per turn to all enemies
		"accuracy":
			power_stacks = 6 if is_plus else 4  # Extra shiv damage
		"a_thousand_cuts":
			power_stacks = 2 if is_plus else 1  # Damage per card played
		"after_image":
			power_stacks = 1  # Block per card played, stackable
		"well_laid_plans":
			power_stacks = 2 if is_plus else 1  # Cards retained
		"wraith_form":
			power_stacks = 1  # Dex loss per turn (the icon shows this)
			# Apply intangible stacks as a status effect
			if hero:
				hero.apply_status("intangible", 3 if is_plus else 2)
		"tools_of_the_trade":
			power_stacks = 1  # Draw/discard per turn, stackable
		"brutality":
			power_stacks = 1  # Draw per turn (costs 1HP), stackable
		"combust":
			power_stacks = 7 if is_plus else 5  # Damage per turn to all
		"dark_embrace":
			power_stacks = 0  # Binary — no number
		"rupture":
			power_stacks = 2 if is_plus else 1  # Strength per HP loss
		"double_tap":
			_double_tap_active = true
			show_icon = false  # Temporary effect, no persistent icon
		"fire_breathing":
			power_stacks = 10 if is_plus else 6  # Damage on status draw
		"venomous_might":
			pass  # Handled at start of turn
		"psi_surge":
			pass  # Handled on draw_cards
		"blood_fury":
			pass  # Handled on self HP loss from card
		"blood_frenzy", "blood_frenzy_plus":
			power_stacks = 3 if is_plus else 2
		"bf_bloodlust_power", "bf_bloodlust_power_plus":
			power_stacks = 2 if is_plus else 1
		"sanguine_aura":
			power_stacks = 1
		"crimson_pact", "crimson_pact_plus":
			power_stacks = 8 if is_plus else 5
		"predators_mark":
			power_stacks = 1
		"blood_scent", "blood_scent_plus":
			power_stacks = 2 if is_plus else 1
		"undying_rage":
			power_stacks = 1
		"pain_threshold", "pain_threshold_plus":
			power_stacks = 6 if is_plus else 3
		"blood_bond", "blood_bond_plus":
			power_stacks = 2 if is_plus else 1
		"undying_will":
			power_stacks = 3 if is_plus else 2
		"scarlet_chains":
			power_stacks = 1
		"hemophilia":
			power_stacks = 1
		"predator_instinct":
			_bf_predator_instinct_block = 4 if is_plus else 2
			_bf_predator_instinct_draw = 1
			show_icon = false  # Temporary skill effect
		"blood_shell":
			_bf_blood_shell_active = true
			_bf_blood_shell_stacks = 2 if is_plus else 1
			show_icon = false  # Temporary skill effect
		# ── Forger Powers ──
		"fg_sword_mastery":
			power_stacks = 3 if is_plus else 2
		"fg_energy_reserve":
			_fg_energy_reserve_active = true
			_fg_energy_reserve_bonus = 1 if is_plus else 0
			power_stacks = 0
		"fg_living_sword":
			power_stacks = 100 if is_plus else 50
		"fg_iron_will":
			power_stacks = 6 if is_plus else 4
		"fg_forge_master":
			power_stacks = 3 if is_plus else 2
		"fg_auto_forge":
			power_stacks = 6 if is_plus else 4
		"fg_iron_skin":
			power_stacks = 1
		"fg_resonance":
			power_stacks = 2 if is_plus else 1
		"fg_sword_ward":
			power_stacks = 5 if is_plus else 3
		"fg_counter_forge":
			power_stacks = 5 if is_plus else 3
		"fg_thorn_aura":
			show_icon = false  # Handled by thorn_aura call action

	# Accumulate per_turn effects on hero metadata for simulator snapshot
	if not per_turn.is_empty() and hero and hero.has_method("set_meta"):
		var pt: Dictionary = hero.get_meta("sim_per_turn") if hero.has_meta("sim_per_turn") else {}
		for key in per_turn:
			pt[key] = pt.get(key, 0) + per_turn[key]
		hero.set_meta("sim_per_turn", pt)

	# Add power icon with correct stack value
	if show_icon and hero:
		hero.add_power(base_name, power_stacks if power_stacks > 0 else 1)

func _process_next_turn_effects() -> void:
	for effect in _next_turn_effects:
		var etype: String = effect.get("type", "")
		var value: int = effect.get("value", 0)
		match etype:
			"block":
				if value > 0 and player and player.alive:
					player.add_block(value)
					_fg_on_hero_gain_block(player, value)
					_trigger_juggernaut()
			"gain_energy":
				if value > 0:
					current_energy += value
					_update_energy_label()
					if card_hand:
						card_hand.current_battle_energy = current_energy
						card_hand.update_card_playability(current_energy)
			"draw":
				if value > 0:
					draw_cards(value)
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
				var vw: float = get_viewport_rect().size.x
				var delay: float = _card_gen_delay
				_card_gen_delay = maxf(_card_gen_delay - 0.12, 0.0)  # Stagger subsequent cards
				if delay > 0:
					var card_copy = card
					var spawn_center := Vector2(vw / 2.0, 400)
					var t = create_tween()
					t.tween_interval(delay)
					t.tween_callback(func():
						if card_hand and is_instance_valid(card_hand):
							card_hand.add_card(card_copy, false, spawn_center)
							_reset_hand_state()
					)
				else:
					card_hand.add_card(card, false, Vector2(vw / 2.0, 400))

func _delayed_add_card(card_data: Dictionary) -> void:
	## Add a card visual to hand with delay if a card-play animation is in progress
	var vw: float = get_viewport_rect().size.x
	var delay: float = _card_gen_delay
	_card_gen_delay = maxf(_card_gen_delay - 0.12, 0.0)
	if delay > 0:
		var cd = card_data
		var spawn_center := Vector2(vw / 2.0, 400)
		var t = create_tween()
		t.tween_interval(delay)
		t.tween_callback(func():
			if card_hand and is_instance_valid(card_hand):
				card_hand.add_card(cd, false, spawn_center)
				_reset_hand_state()
		)
	else:
		card_hand.add_card(card_data, false, Vector2(vw / 2.0, 400))
		_reset_hand_state()

func _add_shiv_to_hand(count: int = 1) -> void:
	var gm = _get_game_manager()
	# Consume delay — wait for played card animation before adding cards
	var base_delay: float = _card_gen_delay
	_card_gen_delay = 0.0
	var shivs_to_add: Array = []
	for i in range(count):
		if hand.size() + shivs_to_add.size() >= 10:
			if player:
				player.show_speech("手上的牌太多啦", 1.2)
			break
		var shiv = gm.get_card_data("si_shiv")
		if shiv.is_empty():
			continue
		# Accuracy: boost shiv damage (stacks = bonus damage)
		for _h in _get_all_alive_heroes():
			var acc_bonus: int = _h.active_powers.get("accuracy", 0)
			if acc_bonus > 0:
				shiv["damage"] = shiv.get("damage", 4) + acc_bonus
		shivs_to_add.append(shiv)
	# Add shiv data to hand immediately (for game state)
	for shiv in shivs_to_add:
		hand.append(shiv)
	# Add visual cards with delay (wait for played card to fly away first)
	if card_hand and not shivs_to_add.is_empty():
		var vw: float = get_viewport_rect().size.x
		for i in range(shivs_to_add.size()):
			var shiv_copy = shivs_to_add[i]
			var delay: float = base_delay + 0.12 * i
			if delay > 0:
				var spawn_center := Vector2(vw / 2.0, 400)
				var t = create_tween()
				t.tween_interval(delay)
				t.tween_callback(func():
					if card_hand and is_instance_valid(card_hand):
						card_hand.add_card(shiv_copy, false, spawn_center)
						_reset_hand_state()
				)
			else:
				card_hand.add_card(shivs_to_add[i], false, Vector2(vw / 2.0, 400))
	_reset_hand_state()
	_update_pile_labels()

func _reset_hand_state() -> void:
	## Reset card interaction state and update playability
	if card_hand:
		card_hand.selected_card = null
		card_hand.focused_card = null
		card_hand.targeting_mode = false
		card_hand._any_card_dragging = false
	_update_unplayable_ids()
	if card_hand:
		card_hand.update_card_playability(current_energy)
	_update_pile_labels()

func _deal_damage_to_target(damage: int, target: Node2D, target_type: String, _use_strength: bool = true) -> void:
	if damage <= 0:
		return
	var actual_dmg: int = damage
	if target_type == "all_enemies":
		for enemy in enemies:
			if enemy.alive:
				var hp_before_ddt: int = enemy.current_hp
				enemy.take_damage(actual_dmg)
				_on_hero_hit_enemy(enemy, hp_before_ddt)
				_swap_enemy_hit_sprite(enemy)
	elif target != null and target.alive:
		var hp_before_ddt2: int = target.current_hp
		target.take_damage(actual_dmg)
		if target.is_enemy:
			_on_hero_hit_enemy(target, hp_before_ddt2)
			_swap_enemy_hit_sprite(target)

func end_player_turn() -> void:
	if not battle_active or not is_player_turn:
		return
	is_player_turn = false
	if end_turn_btn:
		end_turn_btn.disabled = true

	# Remove Flex temp strength
	if flex_strength_to_remove > 0:
		for hero in _get_all_alive_heroes():
			hero.apply_status("strength", -flex_strength_to_remove)
		flex_strength_to_remove = 0

	# Remove Blood Fiend flex temp strength (from bloodrage)
	for bf_flex in _bf_flex_heroes:
		var h = bf_flex.get("hero")
		var s: int = bf_flex.get("stacks", 0)
		if h and is_instance_valid(h) and h.alive and s > 0:
			h.apply_status("strength", -s)
	_bf_flex_heroes.clear()

	# Remove Anticipate temp dexterity
	if anticipate_dex_to_remove > 0:
		for hero in _get_all_alive_heroes():
			hero.apply_status("dexterity", -anticipate_dex_to_remove)
		anticipate_dex_to_remove = 0

	# Metallicize: gain block at end of turn (apply to hero that has the power)
	for hero in _get_all_alive_heroes():
		if hero.active_powers.get("metallicize", 0) > 0:
			hero.add_block(metallicize_block)
			_fg_on_hero_gain_block(hero, metallicize_block)
			_trigger_juggernaut()

	# Noxious Fumes: apply poison to all enemies at end of turn
	for hero in _get_all_alive_heroes():
		if hero.active_powers.get("noxious_fumes", 0) > 0:
			var stacks: int = hero.active_powers["noxious_fumes"]
			for enemy in enemies:
				if enemy.alive:
					enemy.apply_status("poison", stacks)

	# Combust: lose 1HP, deal stacks damage to ALL enemies at end of turn
	for hero in _get_all_alive_heroes():
		if hero.active_powers.get("combust", 0) > 0:
			var combust_stacks: int = hero.active_powers["combust"]
			hero.take_damage_direct(1)
			for enemy in enemies:
				if enemy.alive:
					enemy.take_damage(combust_stacks)
	# Living Sword: end of turn, sword attacks random enemy
	for hero in _get_all_alive_heroes():
		var ls_pct: int = hero.active_powers.get("fg_living_sword", 0)
		if ls_pct > 0 and _greatsword_hp > 0:
			var alive_enemies: Array = _get_alive_enemies()
			if not alive_enemies.is_empty():
				var dmg: int = int(_greatsword_hp * ls_pct / 100.0)
				if dmg > 0:
					var rand_enemy = alive_enemies[randi() % alive_enemies.size()]
					_play_greatsword_attack_effect(rand_enemy)
					rand_enemy.take_damage(dmg)

	# Energy Reserve: save unspent energy for next turn
	if _fg_energy_reserve_active and current_energy > 0:
		_next_turn_effects.append({"type": "gain_energy", "value": current_energy + _fg_energy_reserve_bonus})

	# Check if combust/living_sword killed all enemies
	_check_battle_end()
	if not battle_active:
		return

	# Process end-of-turn damage from status cards in hand (Burn)
	var front = get_front_player()
	for card_data in hand:
		if card_data.get("end_turn_damage", 0) > 0 and front:
			front.take_damage_direct(card_data["end_turn_damage"])

	# Exhaust ethereal cards with shatter animation (Dazed, Ghostly Armor, Carnage, etc.)
	var ethereal_cards: Array = []
	for card_data in hand:
		if card_data.get("ethereal", false):
			ethereal_cards.append(card_data)
	if not ethereal_cards.is_empty():
		# Animate ethereal card nodes shattering before removing data
		if card_hand:
			var ethereal_nodes: Array = []
			for card_node in card_hand.cards.duplicate():
				if is_instance_valid(card_node) and card_node.card_data.get("ethereal", false):
					ethereal_nodes.append(card_node)
			for card_node in ethereal_nodes:
				card_hand._shatter_card(card_node)
				card_hand.remove_card(card_node)
			if not ethereal_nodes.is_empty():
				await get_tree().create_timer(0.7).timeout
		# Update hand data
		for card_data in ethereal_cards:
			hand.erase(card_data)
			_exhaust_card(card_data)

	# Check for Retain (Well-Laid Plans): let player keep cards in hand
	var retain_count: int = 0
	for hero in _get_all_alive_heroes():
		if hero.active_powers.get("well_laid_plans", 0) > 0:
			retain_count += hero.active_powers.get("well_laid_plans", 0)
	if retain_count > 0 and hand.size() > retain_count:
		# Show retain selection UI, then continue end-of-turn in callback
		_show_discard_selection(retain_count, _on_retain_complete)
		_discard_title_label.text = "保留 %d 张手牌" % retain_count
		_discard_confirm_btn.text = "确认 (0/%d)" % retain_count
		return  # End of turn continues in _on_retain_complete
	elif retain_count > 0 and hand.size() <= retain_count:
		# Keep all cards (fewer than retain count)
		_finish_end_of_turn()
		return

	_finish_end_of_turn()

func _on_retain_complete() -> void:
	## Called after retain selection — discard non-retained cards, continue end of turn
	# The "discard" selection actually picked cards to KEEP — invert logic
	var retained_indices: Array = _discard_selected_cards.duplicate()
	retained_indices.sort()
	# Cards NOT in the retained list should be discarded
	var cards_to_discard: Array = []
	for i in range(hand.size()):
		if i not in retained_indices:
			cards_to_discard.append(hand[i])
	for card_data in cards_to_discard:
		hand.erase(card_data)
		discard_pile.append(card_data)
		_check_sly_on_discard(card_data)
	_discard_selected_cards.clear()
	# Rebuild hand with only retained cards
	if card_hand:
		card_hand.clear_hand()
		for c in hand:
			card_hand.add_card(c, false)
	_retain_applied = true
	_finish_end_of_turn()

var _retain_applied: bool = false  # Set by _on_retain_complete to skip hand discard
var _tools_discard_count: int = 0  # Tools of the Trade discards pending

func _on_tools_discard_complete() -> void:
	## Called after Tools of the Trade discard selection completes
	_update_unplayable_ids()
	if card_hand:
		card_hand.current_battle_energy = current_energy
		card_hand.update_card_playability(current_energy)
	_update_pile_labels()
	_refresh_enemy_intents()
	_check_battle_end()

func _finish_end_of_turn() -> void:
	## Common end-of-turn logic after retain selection (or when no retain)
	# Discard remaining hand (skip if retain already handled it)
	if not _retain_applied and not hand.is_empty():
		var hand_copy: Array = hand.duplicate()
		for card_data in hand_copy:
			discard_pile.append(card_data)
			_check_sly_on_discard(card_data)
		hand.clear()
		if card_hand:
			# Animate cards flying to discard pile one by one (right to left)
			_animate_hand_discard()
		else:
			_after_hand_discard()
			return
	else:
		_after_hand_discard()
		return
	_retain_applied = false

func _animate_hand_discard() -> void:
	## Animate each card in hand flying to discard pile position, then clean up
	if not card_hand or card_hand.cards.is_empty():
		_after_hand_discard()
		return
	var vw: float = get_viewport_rect().size.x
	var discard_target: Vector2 = card_hand.to_local(Vector2(vw - 95, 985))
	var card_nodes: Array = card_hand.cards.duplicate()
	# Reverse so rightmost card goes first
	card_nodes.reverse()
	var total_delay: float = 0.0
	for i in range(card_nodes.size()):
		var card_node = card_nodes[i]
		if not is_instance_valid(card_node):
			continue
		var fly_tween = create_tween()
		fly_tween.tween_interval(0.08 * i)
		fly_tween.tween_property(card_node, "position", discard_target, 0.2).set_ease(Tween.EASE_IN)
		fly_tween.parallel().tween_property(card_node, "scale", Vector2(0.3, 0.3), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		fly_tween.parallel().tween_property(card_node, "modulate:a", 0.0, 0.15).set_delay(0.1).set_ease(Tween.EASE_IN)
		total_delay = 0.08 * i + 0.2
	# After all animations, clear hand and continue
	var cleanup_tween = create_tween()
	cleanup_tween.tween_interval(total_delay + 0.05)
	cleanup_tween.tween_callback(_on_hand_discard_complete)

func _on_hand_discard_complete() -> void:
	if card_hand:
		card_hand.clear_hand()
	_after_hand_discard()

func _after_hand_discard() -> void:
	_retain_applied = false
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

	# Execute action (may be multi-hit with delays)
	var hit_count: int = 0
	if action.get("type", "attack") == "attack":
		hit_count = action.get("times", 1)
	if hit_count > 1:
		# Multi-hit: stagger each hit, then continue after all hits finish
		_execute_enemy_multi_hit(enemy, action, 0, hit_count, func():
			_finish_enemy_action(enemy, ai, index)
		)
		return
	_execute_enemy_action(enemy, action)
	_finish_enemy_action(enemy, ai, index)

func _finish_enemy_action(enemy: Node2D, ai, index: int) -> void:
	# Tick enemy status
	enemy.tick_status_effects()
	# Generate next intent
	enemy.intent = ai.get_next_action(enemy)
	enemy.update_intent_display()
	# Check if all heroes are dead
	_on_player_died()
	if not battle_active:
		return
	# Next enemy after delay
	var timer = get_tree().create_timer(0.6)
	timer.timeout.connect(_process_enemy_actions.bind(index + 1))

func _execute_enemy_multi_hit(enemy: Node2D, action: Dictionary, hit_idx: int, total: int, on_done: Callable) -> void:
	if hit_idx >= total or not battle_active:
		on_done.call()
		return
	var front = get_front_player()
	if front == null:
		on_done.call()
		return
	var value: int = action.get("value", 5)
	var actual_dmg: int = enemy.get_attack_damage(value)
	_enemy_lunge(enemy)
	var attack_target = front
	var remaining_dmg: int = actual_dmg
	if _greatsword_hp > 0:
		remaining_dmg = _greatsword_take_damage(actual_dmg, enemy)
		_screen_shake()
	if remaining_dmg > 0 and attack_target.alive:
		attack_target.take_damage(remaining_dmg)
		_screen_shake()
		_check_reactive_powers(attack_target, enemy)
	elif remaining_dmg > 0 and dual_hero_mode:
		attack_target = get_front_player()
		if attack_target and attack_target.alive:
			attack_target.take_damage(remaining_dmg)
			_screen_shake()
			_check_reactive_powers(attack_target, enemy)
	elif remaining_dmg <= 0:
		_check_reactive_powers(attack_target, enemy)
	# Check if hero died
	_on_player_died()
	if not battle_active:
		return
	# Next hit after delay
	var delay_timer = get_tree().create_timer(0.5)
	delay_timer.timeout.connect(_execute_enemy_multi_hit.bind(enemy, action, hit_idx + 1, total, on_done))

func _enemy_lunge(enemy: Node2D) -> void:
	## Enemy lunge animation toward player (STS-style) + bite effect + sprite swap
	if enemy == null or not enemy.alive:
		return
	# Swap to attack sprite
	_swap_enemy_attack_sprite(enemy)
	var orig_pos: Vector2 = enemy.position
	var lunge_offset := Vector2(-60, 0)  # Lunge toward player (left)
	var tween = create_tween()
	tween.tween_property(enemy, "position", orig_pos + lunge_offset, 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(enemy, "position", orig_pos, 0.25).set_ease(Tween.EASE_IN)
	# Bite effect at the target hero
	var front = get_front_player()
	if front:
		_enemy_bite_effect(enemy, front)

func _swap_enemy_attack_sprite(enemy_node: Node2D) -> void:
	"""Swap enemy sprite to attack pose temporarily."""
	if enemy_node == null or not is_instance_valid(enemy_node):
		return
	var sprite: Sprite2D = enemy_node.get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		return
	var original_tex: Texture2D = sprite.texture
	var attack_path: String = _get_enemy_sprite_path(enemy_node, "attack")
	if attack_path == "" or not ResourceLoader.exists(attack_path):
		return
	var attack_tex: Texture2D = load(attack_path)
	sprite.texture = attack_tex
	var tw = create_tween()
	tw.tween_interval(0.7)
	tw.tween_callback(func():
		if is_instance_valid(sprite) and is_instance_valid(enemy_node):
			sprite.texture = original_tex
	)

func _swap_enemy_hit_sprite(enemy_node: Node2D) -> void:
	"""Swap enemy sprite to hit/damage pose temporarily."""
	if enemy_node == null or not is_instance_valid(enemy_node):
		return
	var sprite: Sprite2D = enemy_node.get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		return
	var original_tex: Texture2D = sprite.texture
	var hit_path: String = _get_enemy_sprite_path(enemy_node, "hit")
	if hit_path == "" or not ResourceLoader.exists(hit_path):
		return
	var hit_tex: Texture2D = load(hit_path)
	sprite.texture = hit_tex
	var tw = create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(func():
		if is_instance_valid(sprite) and is_instance_valid(enemy_node):
			sprite.texture = original_tex
	)

func _get_enemy_sprite_path(enemy_node: Node2D, pose: String) -> String:
	"""Get attack/hit sprite path for an enemy from monster DB or legacy paths."""
	var etype: String = enemy_node.enemy_type if enemy_node.has_method("get") else ""
	if etype == "":
		etype = enemy_node.get("enemy_type") if "enemy_type" in enemy_node else ""
	# Check monster database first
	var _monsters_script = load("res://scripts/monsters.gd") if ResourceLoader.exists("res://scripts/monsters.gd") else null
	if _monsters_script:
		var monsters_db: Dictionary = _monsters_script.get_all()
		if etype in monsters_db:
			var key: String = "attack_sprite" if pose == "attack" else "hit_sprite"
			return monsters_db[etype].get(key, "")
	# Legacy fallback
	var legacy := {
		"slime": {"attack": "res://assets/img/anim/slime_attack.png", "hit": "res://assets/img/anim/slime_hit.png"},
		"cultist": {"attack": "res://assets/img/anim/cultist_attack.png", "hit": "res://assets/img/anim/cultist_hit.png"},
		"jaw_worm": {"attack": "res://assets/img/anim/jaw_worm_attack.png", "hit": "res://assets/img/anim/jaw_worm_hit.png"},
		"guardian": {"attack": "res://assets/img/anim/guardian_attack.png", "hit": "res://assets/img/anim/guardian_hit.png"},
	}
	if etype in legacy:
		return legacy[etype].get(pose, "")
	# Try to match from texture path
	var sprite: Sprite2D = enemy_node.get_node_or_null("Sprite") as Sprite2D
	if sprite and sprite.texture and sprite.texture.resource_path:
		var tex_path: String = sprite.texture.resource_path
		for key in legacy:
			if key in tex_path:
				return legacy[key].get(pose, "")
	return ""

func _check_reactive_powers(attacked_hero: Node2D, enemy: Node2D) -> void:
	## Check if attacked hero has reactive powers (caltrops, flame_barrier) and apply
	if attacked_hero == null or enemy == null or not enemy.alive:
		return
	# Flame Barrier: per-turn skill effect (not a persistent power)
	if flame_barrier_active and flame_barrier_damage > 0:
		enemy.take_damage(flame_barrier_damage)
	var caltrops_dmg: int = attacked_hero.active_powers.get("caltrops", 0)
	if caltrops_dmg > 0:
		enemy.take_damage(caltrops_dmg)
	# Hero thorns (荆棘光环): deal thorns damage back to attacker
	var hero_thorns_dmg: int = attacked_hero.get_status_stacks("thorns")
	if hero_thorns_dmg > 0 and enemy.alive:
		enemy.take_damage(hero_thorns_dmg)
	# Blood Shell: apply bloodlust to attacker when hit (temporary)
	if _bf_blood_shell_active and enemy.alive:
		enemy.apply_status("bloodlust", _bf_blood_shell_stacks)
		_bf_on_apply_bloodlust_check(attacked_hero, enemy, _bf_blood_shell_stacks)

func _execute_enemy_action(enemy: Node2D, action: Dictionary) -> void:
	var front = get_front_player()
	if front == null:
		return
	var action_type: String = action.get("type", "attack")
	match action_type:
		"attack":
			# Multi-hit is handled by _execute_enemy_multi_hit; this handles single-hit only
			var value: int = action.get("value", 5)
			var actual_dmg: int = enemy.get_attack_damage(value)
			_enemy_lunge(enemy)
			var attack_target = front
			var remaining_dmg: int = actual_dmg
			if _greatsword_hp > 0:
				remaining_dmg = _greatsword_take_damage(actual_dmg, enemy)
				_screen_shake()
			if remaining_dmg > 0 and attack_target.alive:
				attack_target.take_damage(remaining_dmg)
				_screen_shake()
				_check_reactive_powers(attack_target, enemy)
			elif remaining_dmg > 0 and dual_hero_mode:
				attack_target = get_front_player()
				if attack_target and attack_target.alive:
					attack_target.take_damage(remaining_dmg)
					_screen_shake()
					_check_reactive_powers(attack_target, enemy)
			elif remaining_dmg <= 0:
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
			var remaining_ab: int = actual_dmg
			if _greatsword_hp > 0:
				remaining_ab = _greatsword_take_damage(actual_dmg, enemy)
				_screen_shake()
			if remaining_ab > 0 and front.alive:
				front.take_damage(remaining_ab)
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
			var remaining_ad: int = actual_dmg
			if _greatsword_hp > 0:
				remaining_ad = _greatsword_take_damage(actual_dmg, enemy)
				_screen_shake()
			if remaining_ad > 0 and front.alive:
				front.take_damage(remaining_ad)
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

# ---------------------------------------------------------------------------
# AI Recommend — solve best play sequence
# ---------------------------------------------------------------------------

func _create_ai_button() -> void:
	var hud = get_node_or_null("HUDLayer/HUD")
	if hud == null:
		return
	ai_btn = Button.new()
	ai_btn.name = "AIButton"
	ai_btn.text = "AI"
	ai_btn.custom_minimum_size = Vector2(60, 50)
	if end_turn_btn:
		ai_btn.position = end_turn_btn.position + Vector2(-70, 10)
	else:
		var vw: float = get_viewport_rect().size.x
		ai_btn.position = Vector2(vw - 370, 560)
	ai_btn.add_theme_font_size_override("font_size", 18)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.35, 0.65, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.6, 1.0, 0.8)
	ai_btn.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.2, 0.45, 0.75, 0.95)
	ai_btn.add_theme_stylebox_override("hover", hover_style)
	ai_btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	ai_btn.pressed.connect(_on_ai_recommend)
	hud.add_child(ai_btn)

func _on_ai_recommend() -> void:
	if not battle_active or not is_player_turn:
		return
	ai_btn.disabled = true
	ai_btn.text = "..."
	# Run solver (synchronous — fast enough for typical hand sizes)
	var _BattleSim = load("res://scripts/battle_sim.gd")
	var result: Dictionary = _BattleSim.solve(self)
	ai_btn.text = "AI"
	ai_btn.disabled = false
	_show_ai_overlay(result)

func _show_ai_overlay(result: Dictionary) -> void:
	# Remove old overlay
	if _ai_overlay and is_instance_valid(_ai_overlay):
		_ai_overlay.queue_free()
	var hud = get_node_or_null("HUDLayer/HUD")
	if hud == null:
		return

	_ai_overlay = Control.new()
	_ai_overlay.name = "AIOverlay"
	_ai_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ai_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(_ai_overlay)

	# Semi-transparent background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_ai_overlay.add_child(bg)

	# Content panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 500)
	panel.position = Vector2(610, 200)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.1, 0.15, 0.95)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_width_left = 2; panel_style.border_width_right = 2
	panel_style.border_width_top = 2; panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.3, 0.6, 1.0, 0.6)
	panel_style.content_margin_left = 24; panel_style.content_margin_right = 24
	panel_style.content_margin_top = 20; panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	_ai_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "AI 最优出牌方案"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Sequence display
	var seq: Array = result.get("sequence", [])
	if seq.is_empty():
		var no_play := Label.new()
		no_play.text = "建议: 不出牌，直接结束回合"
		no_play.add_theme_font_size_override("font_size", 22)
		no_play.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
		vbox.add_child(no_play)
	else:
		var seq_title := Label.new()
		seq_title.text = "出牌顺序:"
		seq_title.add_theme_font_size_override("font_size", 20)
		seq_title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		vbox.add_child(seq_title)
		# Look up card names from hand/game manager (use Chinese names via Loc)
		var gm = _get_game_manager()
		var loc = _get_loc()
		for i in range(seq.size()):
			var card_id: String = seq[i]
			var card_name: String = card_id
			if loc:
				var cn: String = loc.card_name(gm.card_database.get(card_id, {})) if gm else ""
				if cn != "":
					card_name = cn
			elif gm and gm.card_database.has(card_id):
				card_name = gm.card_database[card_id].get("name", card_id)
			var line := Label.new()
			line.text = "  %d. %s" % [i + 1, card_name]
			line.add_theme_font_size_override("font_size", 22)
			line.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
			vbox.add_child(line)

	# Detail text — parse all info lines
	var detail_text: String = result.get("detail", "")
	var detail_lines: Array = detail_text.split("\n")
	for line_str in detail_lines:
		# Skip title and sequence lines (already shown above)
		if line_str.begins_with("===") or line_str.begins_with("出牌顺序") or line_str.begins_with("建议"):
			continue
		if line_str.begins_with("  %d" % 1) or line_str.begins_with("  %d" % 2):
			continue
		# Show all other info lines
		if line_str.strip_edges().is_empty():
			continue
		if line_str.begins_with("搜索"):
			continue
		var lbl := Label.new()
		lbl.text = line_str
		lbl.add_theme_font_size_override("font_size", 18)
		if "英雄HP" in line_str or "力量" in line_str:
			lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
		elif "敌人" in line_str:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		elif "毒" in line_str:
			lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		elif "全局" in line_str or "预计" in line_str:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		elif "HP损失" in line_str:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		elif "无额外" in line_str:
			lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		else:
			lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		vbox.add_child(lbl)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(120, 40)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(func():
		if _ai_overlay and is_instance_valid(_ai_overlay):
			_ai_overlay.queue_free()
			_ai_overlay = null
	)
	var center_h := CenterContainer.new()
	center_h.add_child(close_btn)
	vbox.add_child(center_h)

	# Also close on background click
	bg.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if _ai_overlay and is_instance_valid(_ai_overlay):
				_ai_overlay.queue_free()
				_ai_overlay = null
	)

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
	# Check if any hero is still alive — if so, don't end the battle
	if player and player.alive:
		return
	if dual_hero_mode:
		if second_player and second_player.alive:
			# One hero died — remove swap button
			if _swap_button and is_instance_valid(_swap_button):
				_swap_button.queue_free()
				_swap_button = null
			# Track dead hero — their cards become unplayable
			var dead_hero: Node2D = null
			var dead_char_id: String = ""
			if player and not player.alive:
				_dead_hero_char = _player_character_id
				dead_hero = player
				dead_char_id = _player_character_id
			elif second_player and not second_player.alive:
				_dead_hero_char = _second_character_id
				dead_hero = second_player
				dead_char_id = _second_character_id
			# Swap dead hero sprite to fallen pose
			if dead_hero and dead_char_id != "":
				_show_hero_fallen(dead_hero, dead_char_id)
			# Mark all dead hero's cards as ethereal across all piles
			if _dead_hero_char != "":
				for pile in [hand, draw_pile, discard_pile]:
					for card_data in pile:
						if card_data.get("character", "") == _dead_hero_char:
							card_data["ethereal"] = true
			# Refresh card playability (dead hero's cards become blocked)
			if card_hand:
				card_hand.dead_hero_chars = [_dead_hero_char]
			_update_unplayable_ids()
			if card_hand:
				card_hand.update_card_playability(current_energy)
			return  # One hero still alive, continue battle
	# All heroes dead
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
		# Play death animation on all enemies, then emit battle_won
		_play_enemy_death_anims()

func _play_enemy_death_anims() -> void:
	## Show fallen sprite first, then swap to death sprite and fade out
	var _ms = load("res://scripts/monsters.gd") if ResourceLoader.exists("res://scripts/monsters.gd") else null
	var monsters_db: Dictionary = _ms.get_all() if _ms else {}
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var sprite: Sprite2D = enemy.get_node_or_null("Sprite") as Sprite2D
		if sprite == null:
			continue
		var etype: String = enemy.get("enemy_type") if "enemy_type" in enemy else ""
		# Phase 1: swap to fallen sprite (knocked down)
		if etype in monsters_db and monsters_db[etype].has("fallen_sprite"):
			var fallen_tex = load(monsters_db[etype]["fallen_sprite"])
			if fallen_tex:
				sprite.texture = fallen_tex
	# Hold fallen pose for 0.6s, then start dissolve
	var timer = get_tree().create_timer(0.6)
	timer.timeout.connect(_play_death_dissolve)

func _play_death_dissolve() -> void:
	## Phase 2: swap to death sprite and fade out
	var _ms = load("res://scripts/monsters.gd") if ResourceLoader.exists("res://scripts/monsters.gd") else null
	var monsters_db: Dictionary = _ms.get_all() if _ms else {}
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var sprite: Sprite2D = enemy.get_node_or_null("Sprite") as Sprite2D
		if sprite == null:
			continue
		var etype: String = enemy.get("enemy_type") if "enemy_type" in enemy else ""
		if etype in monsters_db and monsters_db[etype].has("death_sprite"):
			var death_tex = load(monsters_db[etype]["death_sprite"])
			if death_tex:
				sprite.texture = death_tex
		# Fade out + sink
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(enemy, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
		tween.tween_property(enemy, "position:y", enemy.position.y + 30, 0.8).set_ease(Tween.EASE_IN)
	# Wait for dissolve, then victory
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(_on_death_anim_complete)

func _on_death_anim_complete() -> void:
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

func _on_deck_count_clicked() -> void:
	## Show all cards in the current battle deck (including exhausted cards)
	var active_cards: Array = []
	active_cards.append_array(draw_pile)
	active_cards.append_array(hand)
	active_cards.append_array(discard_pile)
	# Mark exhausted cards
	var exhausted_cards: Array = []
	for cd in exhaust_pile:
		var marked = cd.duplicate()
		marked["_exhausted"] = true
		exhausted_cards.append(marked)
	var all_cards: Array = []
	all_cards.append_array(active_cards)
	all_cards.append_array(exhausted_cards)
	# Sort by type then name
	all_cards.sort_custom(func(a, b):
		if a.get("type", 0) != b.get("type", 0):
			return a.get("type", 0) < b.get("type", 0)
		return a.get("name", "") < b.get("name", "")
	)
	_show_pile_viewer("战斗卡组 (%d)" % all_cards.size(), all_cards)

func _refresh_enemy_intents() -> void:
	## Recalculate enemy intent display values based on current statuses
	var front = get_front_player()
	for enemy in enemies:
		if not enemy.alive or enemy.intent.is_empty():
			continue
		var intent_type: String = enemy.intent.get("type", "")
		if intent_type != "attack" and intent_type != "attack_block":
			continue
		var base_dmg: int = enemy.intent.get("value", enemy.intent.get("damage", 0))
		var times: int = enemy.intent.get("times", 1)
		# Apply enemy's strength
		var actual_dmg: int = enemy.get_attack_damage(base_dmg)
		# Apply hero's vulnerable (50% more damage taken)
		if front and front.status_effects.get("vulnerable", 0) > 0:
			actual_dmg = int(ceil(float(actual_dmg) * 1.5))
		# Apply hero's intangible (cap at 1)
		if front and front.status_effects.get("intangible", 0) > 0:
			actual_dmg = 1
		# Update display text
		if times > 1:
			enemy.intent["desc"] = "%dx%d" % [actual_dmg, times]
		else:
			enemy.intent["desc"] = str(actual_dmg)
		enemy.update_intent_display()

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
			# Arrow starts from top edge of card (not center)
			var card_pos: Vector2 = card_hand.selected_card.global_position + Vector2(148, -10)
			var mouse_pos_arrow: Vector2 = get_viewport().get_mouse_position()
			# Green arrow for self/hero targets, red for enemy targets
			var arrow_mode: String = "red"
			if target_type == "self" or target_type == "all_heroes":
				arrow_mode = "green"
			_targeting_arrow.update_arrow(card_pos, mouse_pos_arrow, arrow_mode)
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
		elif target_type == "self":
			# hero_target routing: "self" = card's own hero, "all_heroes" = all, "target_hero" = user picks
			var ht: String = card_data.get("hero_target", "self")
			if ht == "target_hero" and dual_hero_mode:
				_highlight_heroes()
			elif ht == "all_heroes":
				_highlight_heroes()
			else:
				# Highlight the card's own hero (single or dual mode)
				var own_hero = _get_card_hero(card_data)
				if own_hero == null:
					own_hero = player
				if own_hero and own_hero.has_method("show_target_highlight"):
					own_hero.show_target_highlight()
		elif target_type == "all_enemies" or target_type == "random_enemy":
			# Highlight all enemies (random_enemy uses same UI as all_enemies)
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
	# Left click: check if clicking on the selected card (deselect) or target
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if card_hand and card_hand.selected_card:
			# Check if click is on the selected card itself → deselect
			var click_pos_check: Vector2 = event.global_position
			var sel_card = card_hand.selected_card
			var card_global_pos: Vector2 = sel_card.global_position
			var card_rect = Rect2(card_global_pos, Vector2(296, 422) * sel_card.scale)
			if card_rect.has_point(click_pos_check):
				# Clicking on the selected card → deselect
				sel_card.set_selected(false)
				card_hand.selected_card = null
				card_hand.targeting_mode = false
				card_hand.focused_card = null
				_clear_all_enemy_highlights()
				_unhighlight_heroes()
				_clear_damage_previews()
				_hovered_enemy = null
				if _targeting_arrow:
					_targeting_arrow.hide_arrow()
					_targeting_arrow.visible = false
				card_hand.update_layout()
				return
			# If clicking on another hand card, let card_hand handle selection switch
			if card_hand.has_card_at(click_pos_check):
				return
			var card_data: Dictionary = card_hand.get_selected_card_data()
			var target_type: String = card_data.get("target", "enemy")
			var click_pos: Vector2 = event.global_position
			if target_type == "self":
				var ht: String = card_data.get("hero_target", "self")
				# Must click on a hero to play
				var clicked_hero: Node2D = _get_hero_at(click_pos)
				if clicked_hero:
					_clear_damage_previews()
					_unhighlight_heroes()
					if ht == "target_hero" and dual_hero_mode:
						card_hand.play_selected_on(clicked_hero)
					elif ht == "all_heroes":
						card_hand.play_selected_on(player)
					else:
						var own_hero = _get_card_hero(card_data)
						if own_hero == null:
							own_hero = player
						card_hand.play_selected_on(own_hero)
			elif target_type == "all_enemies" or target_type == "random_enemy":
				# Must click on an enemy to play
				if _is_over_any_enemy(click_pos):
					_clear_damage_previews()
					_clear_all_enemy_highlights()
					_hovered_enemy = null
					if target_type == "all_enemies" and not enemies.is_empty():
						card_hand.play_selected_on(enemies[0])
					elif target_type == "random_enemy":
						var alive = _get_alive_enemies()
						if not alive.is_empty():
							card_hand.play_selected_on(alive[randi() % alive.size()])
			elif target_type == "all_heroes":
				# Must click on a hero to play
				var clicked_hero: Node2D = _get_hero_at(click_pos)
				if clicked_hero:
					_clear_damage_previews()
					_unhighlight_heroes()
					if player:
						card_hand.play_selected_on(player)
			elif target_type == "enemy":
				# Must click on a specific enemy
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
	# Tap always enters targeting mode — player must then click/tap a valid target
	if not battle_active or not is_player_turn:
		return
	var card_data: Dictionary = card_node.card_data
	var target_type: String = card_data.get("target", "enemy")
	card_hand.selected_card = card_node
	card_node.set_selected(true)
	card_hand.targeting_mode = true
	if target_type == "self" or target_type == "all_heroes":
		_highlight_heroes()
	elif target_type == "all_enemies" or target_type == "random_enemy":
		_highlight_all_enemies()
	# "enemy" type already enters targeting mode via card_hand

func _on_card_drag_released(card_node: Area2D, release_position: Vector2) -> void:
	# Handle drag release — card only plays if released ON a highlighted target
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
		var ht: String = card_data.get("hero_target", "self")
		if ht == "target_hero" and dual_hero_mode:
			# Must release on a hero
			var hero_target: Node2D = _get_hero_at(release_position)
			if hero_target:
				card_hand.play_card_on(card_node, hero_target)
			else:
				_snap_card_back(card_node)
		elif ht == "all_heroes":
			# Must release on any hero
			var hero_target: Node2D = _get_hero_at(release_position)
			if hero_target:
				card_hand.play_card_on(card_node, player)
			else:
				_snap_card_back(card_node)
		else:
			# "self" — must release on own hero
			var own_hero = _get_card_hero(card_data)
			if own_hero == null:
				own_hero = player
			var hit_hero: Node2D = _get_hero_at(release_position)
			if hit_hero:
				card_hand.play_card_on(card_node, own_hero)
			else:
				_snap_card_back(card_node)
	elif target_type == "random_enemy":
		# Must release on any enemy area
		if _is_over_any_enemy(release_position):
			var alive = _get_alive_enemies()
			if not alive.is_empty():
				card_hand.play_card_on(card_node, alive[randi() % alive.size()])
			else:
				_snap_card_back(card_node)
		else:
			_snap_card_back(card_node)
	elif target_type == "all_enemies":
		# Must release on any enemy
		if _is_over_any_enemy(release_position):
			if not enemies.is_empty():
				card_hand.play_card_on(card_node, enemies[0])
			else:
				_snap_card_back(card_node)
		else:
			_snap_card_back(card_node)
	else:
		# Single enemy target — must release on that specific enemy
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

func _highlight_all_enemies() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.alive:
			_highlight_enemy(enemy)

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

func _get_hero_at(screen_pos: Vector2) -> Node2D:
	## Returns the hero under screen_pos, or null if none.
	if player_area == null:
		return null
	for hero in _get_all_alive_heroes():
		var hero_global_pos: Vector2 = player_area.position + hero.position
		var rect = Rect2(hero_global_pos - Vector2(120, 200), Vector2(240, 400))
		if rect.has_point(screen_pos):
			return hero
	return null

func _is_over_any_enemy(screen_pos: Vector2) -> bool:
	## Returns true if screen_pos is over any alive enemy (for all_enemies / random_enemy).
	if enemy_area == null:
		return false
	for enemy in enemies:
		if not enemy.alive:
			continue
		var enemy_global_pos: Vector2 = enemy_area.position + enemy.position
		var rect = Rect2(enemy_global_pos - Vector2(120, 200), Vector2(240, 400))
		if rect.has_point(screen_pos):
			return true
	return false

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

# Card detail page state
var _detail_card_list: Array = []  # List of card dicts for navigation
var _detail_card_index: int = 0
var _detail_show_upgrade: bool = false
var _detail_card_container: Control = null
var _detail_keyword_container: VBoxContainer = null
var _detail_upgrade_check: CheckBox = null

# Keyword definitions for tooltip display
const KEYWORD_DEFS: Dictionary = {
	"vulnerable": {"name": "易伤 Vulnerable", "desc": "受到的攻击伤害增加50%。"},
	"weak": {"name": "虚弱 Weak", "desc": "造成的攻击伤害减少25%。"},
	"poison": {"name": "中毒 Poison", "desc": "每回合开始时受到等同层数的伤害，\n然后层数减1。"},
	"strength": {"name": "力量 Strength", "desc": "每点力量增加1点攻击伤害。"},
	"dexterity": {"name": "敏捷 Dexterity", "desc": "每点敏捷增加1点格挡值。"},
	"exhaust": {"name": "消耗 Exhaust", "desc": "打出后移除，不进入弃牌堆。"},
	"ethereal": {"name": "虚无 Ethereal", "desc": "回合结束时，若在手中则消耗。"},
	"block": {"name": "格挡 Block", "desc": "在生命值之前吸收伤害。\n下回合开始时清除。"},
	"innate": {"name": "固有 Innate", "desc": "战斗开始时必定被抽到。"},
	"sly": {"name": "奇巧 Sly", "desc": "被弃牌时触发卡牌效果。"},
	"retain": {"name": "保留 Retain", "desc": "回合结束时保留在手中，不被弃掉。"},
	"intangible": {"name": "无实体 Intangible", "desc": "受到的伤害和失去的HP减少到1。"},
}

func _setup_card_detail_overlay() -> void:
	var hud_layer = get_node_or_null("HUDLayer")
	if hud_layer == null:
		return
	_card_detail_overlay = Control.new()
	_card_detail_overlay.name = "CardDetailOverlay"
	_card_detail_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_detail_overlay.visible = false
	_card_detail_overlay.z_index = 600  # Above pile viewer (500)
	_card_detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# Dark background
	var bg = ColorRect.new()
	bg.name = "DarkBG"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.8)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_detail_overlay.add_child(bg)

	# Card container (holds the rendered card visual, centered)
	_detail_card_container = Control.new()
	_detail_card_container.name = "CardContainer"
	_detail_card_container.position = Vector2(560, 60)
	_detail_card_container.size = Vector2(480, 800)
	_detail_card_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_detail_overlay.add_child(_detail_card_container)

	# Keyword tooltips (right side, with scroll for overflow)
	var kw_scroll = ScrollContainer.new()
	kw_scroll.name = "KeywordScroll"
	kw_scroll.position = Vector2(1100, 80)
	kw_scroll.size = Vector2(400, 850)
	kw_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	kw_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_card_detail_overlay.add_child(kw_scroll)
	_detail_keyword_container = VBoxContainer.new()
	_detail_keyword_container.name = "KeywordContainer"
	_detail_keyword_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_keyword_container.add_theme_constant_override("separation", 12)
	_detail_keyword_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kw_scroll.add_child(_detail_keyword_container)

	# Left arrow button
	var left_btn = Button.new()
	left_btn.name = "PrevBtn"
	left_btn.text = "◀"
	left_btn.position = Vector2(480, 430)
	left_btn.custom_minimum_size = Vector2(60, 60)
	left_btn.add_theme_font_size_override("font_size", 32)
	left_btn.pressed.connect(_detail_prev)
	_card_detail_overlay.add_child(left_btn)

	# Right arrow button
	var right_btn = Button.new()
	right_btn.name = "NextBtn"
	right_btn.text = "▶"
	right_btn.position = Vector2(1040, 430)
	right_btn.custom_minimum_size = Vector2(60, 60)
	right_btn.add_theme_font_size_override("font_size", 32)
	right_btn.pressed.connect(_detail_next)
	_card_detail_overlay.add_child(right_btn)

	# View Upgrade checkbox (below card, centered)
	_detail_upgrade_check = CheckBox.new()
	_detail_upgrade_check.name = "UpgradeCheck"
	_detail_upgrade_check.text = "查看升级版"
	_detail_upgrade_check.position = Vector2(660, 860)
	_detail_upgrade_check.custom_minimum_size = Vector2(200, 40)
	_detail_upgrade_check.add_theme_font_size_override("font_size", 24)
	_detail_upgrade_check.add_theme_color_override("font_color", Color(0.2, 0.7, 0.2))
	_detail_upgrade_check.toggled.connect(_on_detail_upgrade_toggled)
	_card_detail_overlay.add_child(_detail_upgrade_check)

	# Close button (top-right)
	var close_btn = Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "✕"
	close_btn.position = Vector2(1470, 20)
	close_btn.custom_minimum_size = Vector2(50, 50)
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.pressed.connect(func(): _card_detail_overlay.visible = false)
	_card_detail_overlay.add_child(close_btn)

	hud_layer.add_child(_card_detail_overlay)

func _show_card_detail(card_data: Dictionary, card_list: Array = [], index: int = 0) -> void:
	if _card_detail_overlay == null:
		return
	_detail_card_list = card_list
	_detail_card_index = index
	var is_upgraded: bool = card_data.get("upgraded", false)
	_detail_show_upgrade = is_upgraded
	if _detail_upgrade_check:
		_detail_upgrade_check.button_pressed = is_upgraded
		# Hide upgrade checkbox if card has no upgrade
		var card_id: String = card_data.get("id", "")
		var has_upgrade: bool = false
		var gm = _get_game_manager()
		if gm:
			has_upgrade = gm._upgrade_overrides_cache.has(card_id)
		_detail_upgrade_check.visible = has_upgrade
	_render_detail_card(card_data)
	_card_detail_overlay.visible = true

func _render_detail_card(card_data: Dictionary) -> void:
	if _detail_card_container == null:
		return
	# Clear previous card visual
	for child in _detail_card_container.get_children():
		_detail_card_container.remove_child(child)
		child.queue_free()
	if card_data.is_empty():
		return
	# Render large card visual
	var loc = _get_loc()
	var card_size = Vector2(460, 770)
	var _CardScript = load("res://scripts/card.gd")
	var card_visual = _CardScript.create_card_visual(card_data, card_size, loc)
	card_visual.position = Vector2(0, 0)
	_detail_card_container.add_child(card_visual)
	# Update keyword tooltips
	_update_detail_keywords(card_data)
	# Update navigation button visibility
	var prev_btn = _card_detail_overlay.get_node_or_null("PrevBtn")
	var next_btn = _card_detail_overlay.get_node_or_null("NextBtn")
	if prev_btn:
		prev_btn.visible = _detail_card_list.size() > 1
	if next_btn:
		next_btn.visible = _detail_card_list.size() > 1

func _update_detail_keywords(card_data: Dictionary) -> void:
	if _detail_keyword_container == null:
		return
	for child in _detail_keyword_container.get_children():
		_detail_keyword_container.remove_child(child)
		child.queue_free()
	# Scan card description for keywords
	var desc: String = card_data.get("description", "").to_lower()
	var found_keywords: Array = []
	for keyword in KEYWORD_DEFS:
		if keyword in desc or (card_data.has(keyword) and typeof(card_data[keyword]) == TYPE_BOOL and card_data[keyword] == true) or card_data.get("special", "") == keyword:
			if keyword not in found_keywords:
				found_keywords.append(keyword)
	# Also check for common implicit keywords
	if card_data.get("exhaust", false) and "exhaust" not in found_keywords:
		found_keywords.append("exhaust")
	if card_data.get("ethereal", false) and "ethereal" not in found_keywords:
		found_keywords.append("ethereal")
	if card_data.get("innate", false) and "innate" not in found_keywords:
		found_keywords.append("innate")
	# Render keyword tooltips
	for keyword in found_keywords:
		var kw_data = KEYWORD_DEFS[keyword]
		var panel = PanelContainer.new()
		var kw_style = StyleBoxFlat.new()
		kw_style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
		kw_style.border_color = Color(0.5, 0.45, 0.3, 0.7)
		kw_style.border_width_left = 1
		kw_style.border_width_right = 1
		kw_style.border_width_top = 1
		kw_style.border_width_bottom = 1
		kw_style.corner_radius_top_left = 6
		kw_style.corner_radius_top_right = 6
		kw_style.corner_radius_bottom_left = 6
		kw_style.corner_radius_bottom_right = 6
		kw_style.content_margin_left = 12
		kw_style.content_margin_right = 12
		kw_style.content_margin_top = 8
		kw_style.content_margin_bottom = 8
		panel.add_theme_stylebox_override("panel", kw_style)
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		var title = Label.new()
		title.text = kw_data["name"]
		title.add_theme_font_size_override("font_size", 20)
		title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		vbox.add_child(title)
		var body = Label.new()
		body.text = kw_data["desc"]
		body.add_theme_font_size_override("font_size", 16)
		body.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(body)
		panel.add_child(vbox)
		_detail_keyword_container.add_child(panel)

func _detail_prev() -> void:
	if _detail_card_list.is_empty():
		return
	_detail_card_index = (_detail_card_index - 1 + _detail_card_list.size()) % _detail_card_list.size()
	var card = _detail_card_list[_detail_card_index]
	_update_upgrade_check_visibility(card)
	if _detail_show_upgrade:
		var gm = _get_game_manager()
		if gm:
			var upgraded = gm.get_upgraded_card(card.get("id", ""))
			if not upgraded.is_empty():
				card = upgraded
	_render_detail_card(card)

func _detail_next() -> void:
	if _detail_card_list.is_empty():
		return
	_detail_card_index = (_detail_card_index + 1) % _detail_card_list.size()
	var card = _detail_card_list[_detail_card_index]
	_update_upgrade_check_visibility(card)
	if _detail_show_upgrade:
		var gm = _get_game_manager()
		if gm:
			var upgraded = gm.get_upgraded_card(card.get("id", ""))
			if not upgraded.is_empty():
				card = upgraded
	_render_detail_card(card)

func _update_upgrade_check_visibility(card: Dictionary) -> void:
	if _detail_upgrade_check == null:
		return
	var gm = _get_game_manager()
	var has_upgrade: bool = false
	if gm:
		has_upgrade = gm._upgrade_overrides_cache.has(card.get("id", ""))
	_detail_upgrade_check.visible = has_upgrade
	if not has_upgrade:
		_detail_show_upgrade = false
		_detail_upgrade_check.button_pressed = false

func _on_detail_upgrade_toggled(pressed: bool) -> void:
	_detail_show_upgrade = pressed
	if _detail_card_list.is_empty() or _detail_card_index >= _detail_card_list.size():
		return
	var card = _detail_card_list[_detail_card_index]
	if pressed:
		var gm = _get_game_manager()
		if gm:
			var upgraded = gm.get_upgraded_card(card.get("id", ""))
			if not upgraded.is_empty():
				card = upgraded
	_render_detail_card(card)

func _on_detail_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_card_detail_overlay.visible = false

func _on_card_long_press_detail(card_node: Area2D) -> void:
	if _card_detail_overlay == null:
		return
	_show_card_detail(card_node.card_data, [card_node.card_data], 0)

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
	# Calculate actual damage with card hero's strength and weak
	var actual_dmg: int = damage
	var preview_hero: Node2D = _get_card_hero(card_data)
	if preview_hero == null:
		preview_hero = player
	if preview_hero:
		actual_dmg = preview_hero.get_attack_damage(damage)
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
	var vw_tb: float = get_viewport_rect().size.x
	_turn_banner.position = Vector2((vw_tb - 600) / 2.0, 490)
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
	tween.tween_property(_turn_banner, "modulate", Color(1, 1, 1, 0), 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func(): _turn_banner.visible = false)

# ---- Screen Shake ----

func _animate_reshuffle() -> void:
	## Visual: small card-shaped rectangles fly from discard pile to draw pile
	var vw: float = get_viewport_rect().size.x
	var discard_pos := Vector2(vw - 75, 945)  # Discard pile position (bottom right)
	var draw_pos := Vector2(75, 945)  # Draw pile position (bottom left)
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
		t.tween_property(frag, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
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

# ---- Attack Animations ----

func _hero_lunge(hero_node: Node2D, target_node: Node2D) -> void:
	## Hero lunges toward target (rightward) and back
	if hero_node == null or not hero_node.alive:
		return
	var orig_pos: Vector2 = hero_node.position
	var lunge_offset := Vector2(60, 0)  # Lunge toward enemies (right)
	var tween = create_tween()
	tween.tween_property(hero_node, "position", orig_pos + lunge_offset, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(hero_node, "position", orig_pos, 0.2).set_ease(Tween.EASE_IN)

func _play_attack_effect(card_data: Dictionary, hero_node: Node2D, target_node: Node2D) -> void:
	## Play character-specific attack visual effect with sprite swap
	var card_char: String = card_data.get("character", "")
	# Swap hero sprite to attack pose
	_swap_hero_attack_sprite(hero_node, card_char)
	if card_char == "ironclad":
		_sword_slash_effect(hero_node, target_node)
	elif card_char == "silent":
		_dagger_throw_effect(hero_node, target_node)
	elif card_char == "bloodfiend":
		_blood_claw_effect(hero_node, target_node)
	elif card_char == "forger":
		_hammer_throw_effect(hero_node, target_node)
	else:
		_generic_hit_effect(target_node)

func _show_hero_fallen(hero_node: Node2D, char_id: String) -> void:
	## Swap dead hero sprite to fallen/kneeling pose
	if hero_node == null or not is_instance_valid(hero_node):
		return
	var sprite: Sprite2D = hero_node.get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		return
	var gm = _get_game_manager()
	if gm == null:
		return
	var char_data: Dictionary = gm.character_data.get(char_id, {})
	var fallen_path: String = char_data.get("fallen_sprite", "")
	if fallen_path == "":
		return
	var fallen_tex = load(fallen_path)
	if fallen_tex == null:
		return
	sprite.texture = fallen_tex

func _swap_hero_attack_sprite(hero_node: Node2D, char_id: String) -> void:
	"""Swap hero sprite to attack pose, then swap back after delay."""
	if hero_node == null or not is_instance_valid(hero_node):
		return
	var sprite: Sprite2D = hero_node.get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		return
	var original_tex: Texture2D = sprite.texture
	# Load attack texture
	var attack_path: String = ""
	if char_id == "ironclad":
		attack_path = "res://assets/img/anim/ironclad_attack_1.png"
	elif char_id == "silent":
		attack_path = "res://assets/img/anim/silent_attack_1.png"
	elif char_id == "bloodfiend":
		attack_path = "res://assets/img/anim/bloodfiend_attack_1.png"
	elif char_id == "forger":
		attack_path = "res://assets/img/anim/forger_attack_1.png"
	if attack_path == "":
		return
	if not ResourceLoader.exists(attack_path):
		print("[ANIM] Attack texture not found: %s" % attack_path)
		return
	var attack_tex: Texture2D = load(attack_path)
	print("[ANIM] Swapping to attack pose: %s" % attack_path)
	# Swap to attack pose
	sprite.texture = attack_tex
	# Swap back after 0.4s
	var tw = create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(func():
		if is_instance_valid(sprite) and is_instance_valid(hero_node):
			sprite.texture = original_tex
	)

func _play_skill_effect(card_data: Dictionary, hero_node: Node2D) -> void:
	## Play character-specific skill visual effect (glow/aura) + sprite swap
	if hero_node == null or not is_instance_valid(hero_node):
		return
	var card_char: String = card_data.get("character", "")
	# Swap hero sprite to skill/casting pose
	_swap_hero_skill_sprite(hero_node, card_char)
	var glow_color: Color = Color(0.8, 0.3, 0.2, 0.6)  # Red for ironclad
	if card_char == "silent":
		glow_color = Color(0.2, 0.8, 0.3, 0.6)  # Green for silent
	elif card_char == "bloodfiend":
		glow_color = Color(0.8, 0.1, 0.2, 0.6)  # Crimson for bloodfiend
	# Expanding ring effect
	var ring = ColorRect.new()
	ring.size = Vector2(10, 10)
	ring.color = glow_color
	ring.position = hero_node.global_position + Vector2(-5, -40)
	ring.z_index = 250
	ring.pivot_offset = Vector2(5, 5)
	add_child(ring)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(20, 20), 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(false)
	tw.tween_callback(ring.queue_free)

func _swap_hero_skill_sprite(hero_node: Node2D, char_id: String) -> void:
	"""Swap hero sprite to skill/casting pose temporarily."""
	if hero_node == null or not is_instance_valid(hero_node):
		return
	var sprite: Sprite2D = hero_node.get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		return
	var original_tex: Texture2D = sprite.texture
	var skill_path: String = ""
	if char_id == "ironclad":
		skill_path = "res://assets/img/anim/ironclad_skill.png"
	elif char_id == "silent":
		skill_path = "res://assets/img/anim/silent_skill.png"
	elif char_id == "bloodfiend":
		skill_path = "res://assets/img/anim/bloodfiend_skill.png"
	elif char_id == "forger":
		skill_path = "res://assets/img/anim/forger_skill.png"
	if skill_path == "" or not ResourceLoader.exists(skill_path):
		return
	sprite.texture = load(skill_path)
	var tw = create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(func():
		if is_instance_valid(sprite) and is_instance_valid(hero_node):
			sprite.texture = original_tex
	)

func _sword_slash_effect(hero_node: Node2D, target_node: Node2D) -> void:
	## Ironclad: slash arc at target position
	if target_node == null or not is_instance_valid(target_node):
		return
	_hero_lunge(hero_node, target_node)
	var slash = Line2D.new()
	slash.name = "SlashEffect"
	slash.width = 6.0
	slash.default_color = Color(1.0, 0.7, 0.2, 0.9)
	slash.z_index = 300
	# Arc from upper-left to lower-right of target
	var center: Vector2 = target_node.global_position + Vector2(0, -30)
	var arc_points: PackedVector2Array = PackedVector2Array()
	for i in range(12):
		var t: float = float(i) / 11.0
		var angle: float = -0.8 + t * 1.6  # Arc sweep
		var radius: float = 60.0 + t * 20.0
		arc_points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius))
	slash.points = arc_points
	add_child(slash)
	var tw = create_tween()
	tw.tween_property(slash, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(slash.queue_free)

func _blood_claw_effect(hero_node: Node2D, target_node: Node2D) -> void:
	## Blood Fiend: crimson claw slash at target
	if hero_node == null or target_node == null:
		return
	if not is_instance_valid(hero_node) or not is_instance_valid(target_node):
		return
	_hero_lunge(hero_node, target_node)
	var pos: Vector2 = target_node.global_position + Vector2(-15, -40)
	# Three-claw slash lines
	for i in range(3):
		var claw = Line2D.new()
		claw.width = 4.0
		claw.default_color = Color(0.9, 0.1, 0.15, 0.9)
		var offset_x: float = -12.0 + i * 12.0
		claw.add_point(pos + Vector2(offset_x - 15, -20))
		claw.add_point(pos + Vector2(offset_x + 15, 20))
		claw.z_index = 300
		add_child(claw)
		var tw = create_tween()
		tw.tween_interval(0.05 * i)
		tw.tween_property(claw, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
		tw.tween_callback(claw.queue_free)
	_generic_hit_effect(target_node)

func _dagger_throw_effect(hero_node: Node2D, target_node: Node2D) -> void:
	## Silent: dagger projectile flies from hero to target
	if hero_node == null or target_node == null:
		return
	if not is_instance_valid(hero_node) or not is_instance_valid(target_node):
		return
	var start: Vector2 = hero_node.global_position + Vector2(30, -30)
	var end_p: Vector2 = target_node.global_position + Vector2(0, -20)
	# Small dagger shape (triangle)
	var dagger = Polygon2D.new()
	dagger.polygon = PackedVector2Array([
		Vector2(0, -8), Vector2(16, 0), Vector2(0, 8)
	])
	dagger.color = Color(0.7, 0.85, 0.7, 0.9)
	dagger.position = start
	dagger.z_index = 300
	# Rotate to face target
	var dir_angle: float = start.angle_to_point(end_p)
	dagger.rotation = dir_angle + PI
	add_child(dagger)
	var tw = create_tween()
	tw.tween_property(dagger, "position", end_p, 0.15).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_generic_hit_effect(target_node)
		dagger.queue_free()
	)

func _hammer_throw_effect(hero_node: Node2D, target_node: Node2D) -> void:
	## Forger: hammer flies out to enemy, hits, then boomerangs back
	if hero_node == null or target_node == null:
		return
	if not is_instance_valid(hero_node) or not is_instance_valid(target_node):
		return
	var start: Vector2 = hero_node.global_position + Vector2(30, -40)
	var end_p: Vector2 = target_node.global_position + Vector2(0, -20)
	# Hammer shape — rectangular head + short handle
	var hammer = Polygon2D.new()
	hammer.polygon = PackedVector2Array([
		# Head (wide block)
		Vector2(-6, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-6, 10),
		# Handle (narrow)
		Vector2(-6, -3), Vector2(-18, -3), Vector2(-18, 3), Vector2(-6, 3),
	])
	hammer.color = Color(0.7, 0.55, 0.35, 0.95)
	hammer.position = start
	hammer.z_index = 300
	add_child(hammer)
	# Phase 1: fly to enemy with spinning
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(hammer, "position", end_p, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(hammer, "rotation", TAU * 2, 0.2)  # Spin 2 full rotations
	tw.set_parallel(false)
	# Phase 2: hit flash
	tw.tween_callback(func():
		_generic_hit_effect(target_node)
	)
	tw.tween_interval(0.1)
	# Phase 3: arc back to hero (boomerang return) — curve upward
	var mid_y: float = min(start.y, end_p.y) - 80  # Arc above both points
	var mid_point: Vector2 = Vector2((start.x + end_p.x) * 0.5, mid_y)
	# Simulate arc with 3 waypoints
	var arc_p1: Vector2 = end_p.lerp(mid_point, 0.5)
	var arc_p2: Vector2 = mid_point.lerp(start, 0.5)
	tw.set_parallel(true)
	tw.tween_property(hammer, "position", arc_p1, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(hammer, "rotation", TAU * 3, 0.3)  # Keep spinning
	tw.set_parallel(false)
	tw.tween_property(hammer, "position", arc_p2, 0.1)
	tw.tween_property(hammer, "position", start, 0.1).set_ease(Tween.EASE_IN)
	tw.tween_callback(hammer.queue_free)

func _generic_hit_effect(target_node: Node2D) -> void:
	## Flash hit effect at target position
	if target_node == null or not is_instance_valid(target_node):
		return
	var flash = ColorRect.new()
	flash.size = Vector2(20, 20)
	flash.color = Color(1.0, 1.0, 0.8, 0.8)
	flash.position = target_node.global_position + Vector2(-10, -30)
	flash.z_index = 300
	flash.pivot_offset = Vector2(10, 10)
	add_child(flash)
	var tw = create_tween()
	tw.tween_property(flash, "scale", Vector2(4, 4), 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_callback(flash.queue_free)

func _enemy_bite_effect(enemy: Node2D, target_node: Node2D) -> void:
	## Monster bite: two jaw shapes close on target
	if target_node == null or not is_instance_valid(target_node):
		return
	var center: Vector2 = target_node.global_position + Vector2(0, -20)
	# Upper jaw
	var jaw_up = Polygon2D.new()
	jaw_up.polygon = PackedVector2Array([
		Vector2(-25, 0), Vector2(0, -20), Vector2(25, 0),
		Vector2(15, -5), Vector2(0, -10), Vector2(-15, -5)
	])
	jaw_up.color = Color(0.7, 0.2, 0.15, 0.8)
	jaw_up.position = center + Vector2(0, -30)
	jaw_up.z_index = 300
	add_child(jaw_up)
	# Lower jaw (mirrored)
	var jaw_down = Polygon2D.new()
	jaw_down.polygon = PackedVector2Array([
		Vector2(-25, 0), Vector2(0, 20), Vector2(25, 0),
		Vector2(15, 5), Vector2(0, 10), Vector2(-15, 5)
	])
	jaw_down.color = Color(0.7, 0.2, 0.15, 0.8)
	jaw_down.position = center + Vector2(0, 30)
	jaw_down.z_index = 300
	add_child(jaw_down)
	# Jaws close together
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(jaw_up, "position:y", center.y - 5, 0.15).set_ease(Tween.EASE_IN)
	tw.tween_property(jaw_down, "position:y", center.y + 5, 0.15).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_interval(0.1)
	tw.set_parallel(true)
	tw.tween_property(jaw_up, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_property(jaw_down, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(jaw_up.queue_free)
	tw.tween_callback(jaw_down.queue_free)

# ---- Pile Viewer ----

func _setup_pile_viewer() -> void:
	var hud_ctrl = get_node_or_null("HUDLayer/HUD")
	if hud_ctrl == null:
		return
	var vw: float = get_viewport_rect().size.x
	_pile_viewer = Control.new()
	_pile_viewer.name = "PileViewer"
	_pile_viewer.size = Vector2(vw, 1080)
	_pile_viewer.visible = false
	_pile_viewer.z_index = 500
	_pile_viewer.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_ctrl.add_child(_pile_viewer)

	# Dark background
	var bg = ColorRect.new()
	bg.name = "BG"
	bg.size = Vector2(vw, 1080)
	bg.color = Color(0, 0, 0, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_pile_viewer_bg_clicked)
	_pile_viewer.add_child(bg)

	# Title — below persistent HUD bar (75px)
	var title = Label.new()
	title.name = "Title"
	title.position = Vector2(0, 85)
	title.size = Vector2(vw, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 1, 0.8))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pile_viewer.add_child(title)

	# Scroll container for card grid (added before close button so button gets input priority)
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.position = Vector2(60, 140)
	scroll.size = Vector2(vw - 120, 880)
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_pile_viewer.add_child(scroll)

	var grid = GridContainer.new()
	grid.name = "CardGrid"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	# Close button (X) top-right — below persistent HUD bar
	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "✕"
	close_btn.position = Vector2(vw - 80, 85)
	close_btn.custom_minimum_size = Vector2(60, 60)
	close_btn.add_theme_font_size_override("font_size", 32)
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
	var mini_size := Vector2(296, 422)

	# Use Card.create_card_visual() — sized to match hand card size
	var card_script_class_pv = load("res://scripts/card.gd")

	for i in range(sorted_pile.size()):
		var cd = sorted_pile[i]
		var card_visual = card_script_class_pv.create_card_visual(cd, mini_size, loc)
		card_visual.custom_minimum_size = mini_size
		card_visual.mouse_filter = Control.MOUSE_FILTER_STOP
		# Click to open card detail
		card_visual.gui_input.connect(_on_pile_card_clicked.bind(sorted_pile, i))
		# Dim exhausted cards with a semi-transparent overlay and label
		if cd.get("_exhausted", false):
			card_visual.modulate = Color(0.5, 0.5, 0.5, 0.7)
			var exhaust_label = Label.new()
			exhaust_label.text = "已消耗"
			exhaust_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			exhaust_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			exhaust_label.size = mini_size
			exhaust_label.add_theme_font_size_override("font_size", 24)
			exhaust_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
			exhaust_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_visual.add_child(exhaust_label)
		grid.add_child(card_visual)

func _on_pile_card_clicked(event: InputEvent, pile: Array, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if index >= 0 and index < pile.size():
			_show_card_detail(pile[index], pile, index)

# ---- Discard Selection (In-Hand Mode) ----

func _setup_discard_overlay() -> void:
	## Discard overlay — dark BG in main scene (so selected cards render above it),
	## title/confirm on HUDLayer (always on top).
	var hud_layer = get_node_or_null("HUDLayer")
	if hud_layer == null:
		return
	var vw: float = get_viewport_rect().size.x

	# Dark background in MAIN SCENE (not HUDLayer) so cards with z_index=600+
	# render above it. z_index=550 is above entities but below selected cards.
	_discard_overlay = Control.new()
	_discard_overlay.name = "DiscardOverlay"
	_discard_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_discard_overlay.visible = false
	_discard_overlay.z_index = 550
	_discard_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_discard_overlay)

	var bg = ColorRect.new()
	bg.name = "DarkBG"
	bg.position = Vector2(0, 0)
	bg.size = Vector2(vw, 700)
	bg.color = Color(0, 0, 0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_discard_overlay.add_child(bg)

	# Title label and confirm button on HUDLayer (always visible above cards)
	_discard_title_label = Label.new()
	_discard_title_label.name = "DiscardTitle"
	_discard_title_label.text = ""
	_discard_title_label.position = Vector2(0, 80)
	_discard_title_label.size = Vector2(vw, 50)
	_discard_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_discard_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_discard_title_label.add_theme_font_size_override("font_size", 36)
	_discard_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_discard_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_discard_title_label.add_theme_constant_override("shadow_offset_x", 1)
	_discard_title_label.add_theme_constant_override("shadow_offset_y", 2)
	_discard_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_discard_title_label.visible = false
	_discard_title_label.z_index = 700
	hud_layer.add_child(_discard_title_label)

	_discard_confirm_btn = Button.new()
	_discard_confirm_btn.name = "DiscardConfirmButton"
	_discard_confirm_btn.text = "确认"
	_discard_confirm_btn.position = Vector2(vw - 320, 512)
	_discard_confirm_btn.custom_minimum_size = Vector2(300, 55)
	_discard_confirm_btn.visible = false
	_discard_confirm_btn.add_theme_font_size_override("font_size", 28)
	_discard_confirm_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	_discard_confirm_btn.pressed.connect(_on_discard_confirm)
	_discard_confirm_btn.z_index = 700
	hud_layer.add_child(_discard_confirm_btn)
	_update_discard_confirm_style()

	# Dark rect behind hand cards (in main scene, below card z-index)
	_discard_hand_bg = ColorRect.new()
	_discard_hand_bg.name = "DiscardHandBG"
	_discard_hand_bg.position = Vector2(0, 700)
	_discard_hand_bg.size = Vector2(vw, 380)
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
		if _blood_rush_mode:
			_discard_title_label.text = "选择1张攻击牌降低费用 (点击手牌选择)"
		else:
			_discard_title_label.text = "选择 %d 张牌弃掉 (点击手牌选择)" % count

	_update_discard_confirm_style()

	# Show the darkening overlay and title/confirm
	if _discard_overlay:
		_discard_overlay.visible = true
	if _discard_title_label:
		_discard_title_label.visible = true
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
	# Don't show button when no discard selection is active
	if _discard_required_count <= 0:
		_discard_confirm_btn.visible = false
		_discard_confirm_btn.disabled = true
		return
	var ready: bool = _discard_selected_cards.size() >= _discard_required_count
	if ready:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.6, 0.2, 0.9)
		style.set_corner_radius_all(10)
		_discard_confirm_btn.add_theme_stylebox_override("normal", style)
		var hover_style = style.duplicate() as StyleBoxFlat
		hover_style.bg_color = Color(0.2, 0.7, 0.25, 0.95)
		_discard_confirm_btn.add_theme_stylebox_override("hover", hover_style)
		_discard_confirm_btn.disabled = false
		_discard_confirm_btn.visible = true
	else:
		_discard_confirm_btn.visible = false
		_discard_confirm_btn.disabled = true
	_discard_confirm_btn.text = "确认 (%d/%d)" % [_discard_selected_cards.size(), _discard_required_count]

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
			if _blood_rush_mode:
				# Blood Rush: reduce card cost by 1, keep in hand
				var old_cost: int = card_data.get("cost", 1)
				if old_cost > 0:
					card_data["cost"] = old_cost - 1
					# Also reduce matching copies in draw/discard pile
					for dc in draw_pile + discard_pile:
						if dc.get("id", "") == card_data.get("id", "") and dc.get("cost", 1) == old_cost:
							dc["cost"] = old_cost - 1
							break
			elif _discard_as_exhaust:
				_exhaust_card(card_data)
				hand.remove_at(idx)
			elif _setup_mode:
				# Setup: put on top of draw pile instead of discard
				draw_pile.append(card_data)
				hand.remove_at(idx)
			else:
				discard_pile.append(card_data)
				_check_sly_on_discard(card_data)
				hand.remove_at(idx)
	_setup_mode = false
	_discard_as_exhaust = false
	_blood_rush_mode = false
	# Rebuild hand display — snap to position without any animation
	if card_hand:
		card_hand.clear_hand()
		for c in hand:
			card_hand.add_card(c, false)
		card_hand.snap_layout()
	_discard_selected_cards.clear()
	# Hide overlay and title/confirm
	if _discard_overlay:
		_discard_overlay.visible = false
	if _discard_title_label:
		_discard_title_label.visible = false
	if _discard_confirm_btn:
		_discard_confirm_btn.visible = false
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
	if _discard_title_label:
		_discard_title_label.visible = false
	if _discard_confirm_btn:
		_discard_confirm_btn.visible = false
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
	if card_hand:
		card_hand.update_card_playability(current_energy)
	_check_battle_end()

func _on_setup_complete() -> void:
	# Called after Setup card selection finishes — card is already on draw pile
	if card_hand:
		card_hand.update_card_playability(current_energy)
	_update_pile_labels()
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

func _auto_discard(count: int, exhaust: bool = false, callback: Callable = Callable()) -> void:
	## Auto-discard (or exhaust) cards from hand with fly animation.
	## Calls callback after animation completes. Also completes pending played card.
	for _i in range(count):
		if hand.is_empty():
			break
		var idx = randi() % hand.size()
		var cdata = hand[idx]
		if exhaust:
			_exhaust_card(cdata)
		else:
			discard_pile.append(cdata)
			_check_sly_on_discard(cdata)
		hand.remove_at(idx)

	# Complete the pending played card animation (prevents floating)
	if card_hand:
		card_hand.complete_pending_play()

	# Animate remaining visual card nodes flying to pile
	var has_visual_cards: bool = card_hand != null and not card_hand.cards.is_empty()
	if has_visual_cards:
		var vw: float = get_viewport_rect().size.x
		var pile_target: Vector2 = Vector2(vw - 75, 985) if not exhaust else Vector2(vw / 2.0, 400)
		var card_nodes: Array = card_hand.cards.duplicate()
		var anim_duration: float = 0.0
		for i in range(card_nodes.size()):
			var node = card_nodes[i]
			if not is_instance_valid(node):
				continue
			var local_target: Vector2 = card_hand.to_local(pile_target)
			var fly = create_tween()
			fly.tween_interval(0.06 * i)
			fly.tween_property(node, "position", local_target, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
			fly.parallel().tween_property(node, "scale", Vector2(0.3, 0.3), 0.2).set_ease(Tween.EASE_IN)
			fly.parallel().tween_property(node, "modulate:a", 0.0, 0.15).set_delay(0.08).set_ease(Tween.EASE_IN)
			anim_duration = 0.06 * i + 0.25
		# After animation, rebuild hand and call callback
		var cleanup = create_tween()
		cleanup.tween_interval(anim_duration + 0.05)
		cleanup.tween_callback(func():
			if card_hand:
				card_hand.clear_hand()
				for c in hand:
					card_hand.add_card(c, false)
			_update_pile_labels()
			if callback.is_valid():
				callback.call()
		)
	else:
		# No visual cards to animate
		if card_hand:
			card_hand.clear_hand()
			for c in hand:
				card_hand.add_card(c, false)
		_update_pile_labels()
		if callback.is_valid():
			callback.call()

func _check_sly_on_discard(card_data: Dictionary) -> void:
	## On-discard triggers: sly cards (includes Reflex, Tactician, Flick-Flack, etc.)
	var special: String = card_data.get("special", "")
	if special != "sly":
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
	var vw: float = get_viewport_rect().size.x
	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.position = Vector2(0, 30)
	title_lbl.size = Vector2(vw, 60)
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
	scroll.size = Vector2(vw - 120, 800)
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
	_pile_selection_confirm_btn.text = "确认 (0/%d)" % count
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
	_pile_selection_confirm_btn.text = "确认 (%d/%d)" % [_pile_selection_selected.size(), _pile_selection_count]
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
