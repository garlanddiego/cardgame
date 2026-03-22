extends SceneTree
## Presentation video script — ~30 second cinematic showcase of the card battle game
## Phases: character select (3s) -> battle overview (3s) -> play cards (12s) ->
##         enemy turn (4s) -> more cards + status effects (5s) -> enemy dies + victory (3s)

var _frame: int = 0
var _phase: String = "init"
var _battle_node: Node2D = null
var _gm: Node = null
var _main_node: Node = null
var _camera: Camera2D = null

# Timing constants (at 30 FPS)
const CHAR_SELECT_END: int = 90       # 3s: show char select
const BATTLE_SETUP_END: int = 150     # 5s: battle starts, overview
const HOVER_CARD_1: int = 180         # 6s: hover first card
const PLAY_CARD_1: int = 210          # 7s: play first attack card
const HOVER_CARD_2: int = 240         # 8s: hover second card
const PLAY_CARD_2: int = 270          # 9s: play second card (skill/block)
const HOVER_CARD_3: int = 300         # 10s: hover third card
const PLAY_CARD_3: int = 330          # 11s: play third card (attack)
const END_TURN_1: int = 390           # 13s: end turn -> enemy turn starts
const ENEMY_TURN_WAIT: int = 480      # 16s: enemy turn processes
const TURN_2_START: int = 510         # 17s: turn 2 begins with new cards
const HOVER_CARD_4: int = 540         # 18s: hover card
const PLAY_CARD_4: int = 570          # 19s: play card with status effect
const HOVER_CARD_5: int = 600         # 20s: hover another card
const PLAY_CARD_5: int = 630          # 21s: play another attack
const PLAY_CARD_6: int = 690          # 23s: play another card
const END_TURN_2: int = 720           # 24s: end turn 2
const ENEMY_TURN_2_WAIT: int = 780    # 26s: enemy turn 2
const FINAL_WAIT: int = 870           # 29s: final moments
const TOTAL_FRAMES: int = 900         # 30s: end

var _hovered_card_node: Control = null
var _played_card_count: int = 0
var _camera_target_pos: Vector2 = Vector2(960, 540)
var _camera_zoom_target: Vector2 = Vector2(1.0, 1.0)

func _initialize() -> void:
	print("PRESENTATION: Starting cinematic capture")
	# Load main scene (starts with character select)
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	_main_node = main

	# Find GameManager autoload
	for child in root.get_children():
		if child.name == "GameManager":
			_gm = child
			break

	# Add a Camera2D for cinematic control
	_camera = Camera2D.new()
	_camera.name = "CinematicCamera"
	_camera.position = Vector2(960, 540)
	_camera.zoom = Vector2(1.0, 1.0)
	root.add_child(_camera)
	_camera.make_current()

	_phase = "char_select"
	print("PRESENTATION: Phase - Character Select")

func _process(delta: float) -> bool:
	_frame += 1

	# Smooth camera movement
	if _camera:
		_camera.position = _camera.position.lerp(_camera_target_pos, 0.05)
		_camera.zoom = _camera.zoom.lerp(_camera_zoom_target, 0.05)

	match _phase:
		"char_select":
			_do_char_select_phase()
		"battle_overview":
			_do_battle_overview_phase()
		"playing_cards":
			_do_playing_cards_phase()
		"enemy_turn":
			_do_enemy_turn_phase()
		"turn_2":
			_do_turn_2_phase()
		"enemy_turn_2":
			_do_enemy_turn_2_phase()
		"finale":
			_do_finale_phase()

	return false

func _do_char_select_phase() -> void:
	# Zoom into character select for the first 2 seconds
	if _frame < 30:
		_camera_target_pos = Vector2(960, 540)
		_camera_zoom_target = Vector2(1.0, 1.0)
	elif _frame < 60:
		# Slowly zoom in on the character options
		_camera_zoom_target = Vector2(1.15, 1.15)
		_camera_target_pos = Vector2(960, 480)

	if _frame == CHAR_SELECT_END:
		print("PRESENTATION: Selecting Ironclad character")
		_select_character("ironclad")
		_phase = "battle_overview"
		print("PRESENTATION: Phase - Battle Overview")

func _do_battle_overview_phase() -> void:
	# Reset camera to overview
	if _frame == CHAR_SELECT_END + 5:
		_camera_zoom_target = Vector2(1.0, 1.0)
		_camera_target_pos = Vector2(960, 540)

	# Slowly zoom into the battle scene
	if _frame > CHAR_SELECT_END + 30:
		_camera_zoom_target = Vector2(1.05, 1.05)
		_camera_target_pos = Vector2(960, 500)

	if _frame >= BATTLE_SETUP_END:
		_phase = "playing_cards"
		print("PRESENTATION: Phase - Playing Cards")

func _do_playing_cards_phase() -> void:
	# Zoom to see cards better
	if _frame == HOVER_CARD_1 - 10:
		_camera_zoom_target = Vector2(1.1, 1.1)
		_camera_target_pos = Vector2(960, 600)

	# Hover first card
	if _frame == HOVER_CARD_1:
		_hover_card(0)
	# Play first card (attack on first enemy)
	if _frame == PLAY_CARD_1:
		_unhover_card()
		_play_card_on_enemy(0, 0)

	# Hover second card
	if _frame == HOVER_CARD_2:
		_camera_target_pos = Vector2(960, 580)
		_hover_card(1)
	# Play second card
	if _frame == PLAY_CARD_2:
		_unhover_card()
		_play_card_on_self(0)

	# Hover third card
	if _frame == HOVER_CARD_3:
		_hover_card(0)
	# Play third card on second enemy
	if _frame == PLAY_CARD_3:
		_unhover_card()
		_play_card_on_enemy(0, 1)

	# Zoom out to see battlefield
	if _frame > PLAY_CARD_3 + 10:
		_camera_zoom_target = Vector2(1.0, 1.0)
		_camera_target_pos = Vector2(960, 540)

	if _frame == END_TURN_1:
		_end_turn()
		_phase = "enemy_turn"
		print("PRESENTATION: Phase - Enemy Turn")

func _do_enemy_turn_phase() -> void:
	# Camera pans slightly to enemies during their turn
	if _frame < END_TURN_1 + 30:
		_camera_target_pos = Vector2(1100, 450)
		_camera_zoom_target = Vector2(1.1, 1.1)
	elif _frame > END_TURN_1 + 60:
		_camera_target_pos = Vector2(960, 540)
		_camera_zoom_target = Vector2(1.0, 1.0)

	if _frame >= TURN_2_START:
		_phase = "turn_2"
		print("PRESENTATION: Phase - Turn 2")

func _do_turn_2_phase() -> void:
	# Pan down to see new cards
	if _frame == TURN_2_START + 10:
		_camera_target_pos = Vector2(960, 580)
		_camera_zoom_target = Vector2(1.08, 1.08)

	# Hover and play cards
	if _frame == HOVER_CARD_4:
		_hover_card(0)
	if _frame == PLAY_CARD_4:
		_unhover_card()
		_play_card_on_enemy(0, 0)

	if _frame == HOVER_CARD_5:
		_hover_card(0)
	if _frame == PLAY_CARD_5:
		_unhover_card()
		_play_card_on_enemy(0, 1)

	if _frame == PLAY_CARD_6:
		if _battle_node and _battle_node.hand.size() > 0:
			_hover_card(0)
			# Small delay then play
			await_and_play_card()

	# Zoom to see status effects on enemies
	if _frame == PLAY_CARD_6 + 15:
		_camera_target_pos = Vector2(1200, 400)
		_camera_zoom_target = Vector2(1.2, 1.2)

	if _frame == END_TURN_2:
		_camera_target_pos = Vector2(960, 540)
		_camera_zoom_target = Vector2(1.0, 1.0)
		_end_turn()
		_phase = "enemy_turn_2"
		print("PRESENTATION: Phase - Enemy Turn 2")

func _do_enemy_turn_2_phase() -> void:
	# Zoom to enemies
	if _frame < END_TURN_2 + 30:
		_camera_target_pos = Vector2(1100, 400)
		_camera_zoom_target = Vector2(1.1, 1.1)
	elif _frame > END_TURN_2 + 45:
		_camera_target_pos = Vector2(960, 540)
		_camera_zoom_target = Vector2(1.0, 1.0)

	if _frame >= FINAL_WAIT:
		_phase = "finale"
		print("PRESENTATION: Phase - Finale")

func _do_finale_phase() -> void:
	# Final overview zoom
	_camera_target_pos = Vector2(960, 540)
	_camera_zoom_target = Vector2(1.0, 1.0)

# Helper functions

func _select_character(character_id: String) -> void:
	if _gm:
		_gm.select_character(character_id)
	if _main_node == null:
		return
	# Remove character select
	var char_select = _main_node.get_node_or_null("CharacterSelect")
	if char_select:
		char_select.free()
	# Load battle
	var battle_scene: PackedScene = load("res://scenes/battle.tscn")
	var battle = battle_scene.instantiate()
	battle.name = "BattleInstance"
	_main_node.add_child(battle)
	_battle_node = battle
	battle.start_battle(character_id)

func _hover_card(index: int) -> void:
	if _battle_node == null:
		return
	var card_hand = _battle_node.get_node_or_null("CardHand")
	if card_hand == null or card_hand.cards.size() <= index:
		return
	var card = card_hand.cards[index]
	if not is_instance_valid(card):
		return
	_hovered_card_node = card
	card._on_mouse_entered()
	print("PRESENTATION: Hovering card - " + str(card.card_data.get("name", "?")))

func _unhover_card() -> void:
	if _hovered_card_node and is_instance_valid(_hovered_card_node):
		_hovered_card_node._on_mouse_exited()
		_hovered_card_node = null

func _play_card_on_enemy(card_index: int, enemy_index: int) -> void:
	if _battle_node == null:
		return
	if not _battle_node.battle_active or not _battle_node.is_player_turn:
		return
	var card_hand = _battle_node.get_node_or_null("CardHand")
	if card_hand == null or card_hand.cards.size() <= card_index:
		return
	var card = card_hand.cards[card_index]
	if not is_instance_valid(card):
		return
	var card_data: Dictionary = card.card_data
	var cost: int = card_data.get("cost", 0)
	if _battle_node.current_energy < cost:
		print("PRESENTATION: Not enough energy for " + card_data.get("name", "?"))
		return

	# Find target
	var target: Node2D = null
	var target_type: String = card_data.get("target", "enemy")
	if target_type == "self":
		target = _battle_node.player
	elif target_type == "all_enemies":
		for e in _battle_node.enemies:
			if e.alive:
				target = e
				break
	else:
		# Target specific enemy
		if enemy_index < _battle_node.enemies.size() and _battle_node.enemies[enemy_index].alive:
			target = _battle_node.enemies[enemy_index]
		else:
			# Find first alive enemy
			for e in _battle_node.enemies:
				if e.alive:
					target = e
					break
	if target == null:
		return

	# Select the card, then play it
	card_hand._on_card_clicked(card)
	card_hand.play_selected_on(target)
	_played_card_count += 1
	print("PRESENTATION: Played " + card_data.get("name", "?") + " on target")

func _play_card_on_self(card_index: int) -> void:
	if _battle_node == null:
		return
	if not _battle_node.battle_active or not _battle_node.is_player_turn:
		return
	var card_hand = _battle_node.get_node_or_null("CardHand")
	if card_hand == null or card_hand.cards.size() <= card_index:
		return
	var card = card_hand.cards[card_index]
	if not is_instance_valid(card):
		return
	var card_data: Dictionary = card.card_data
	var cost: int = card_data.get("cost", 0)
	if _battle_node.current_energy < cost:
		print("PRESENTATION: Not enough energy for " + card_data.get("name", "?"))
		return

	var target: Node2D = _battle_node.player
	if target == null:
		return

	card_hand._on_card_clicked(card)
	card_hand.play_selected_on(target)
	_played_card_count += 1
	print("PRESENTATION: Played " + card_data.get("name", "?") + " on self")

func _end_turn() -> void:
	if _battle_node and _battle_node.battle_active and _battle_node.is_player_turn:
		_battle_node.end_player_turn()
		print("PRESENTATION: Turn ended")

func await_and_play_card() -> void:
	if _battle_node == null or not _battle_node.battle_active:
		return
	_unhover_card()
	if _battle_node.hand.size() > 0:
		_play_card_on_enemy(0, 2)
