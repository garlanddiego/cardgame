extends SceneTree
## Showcase test — captures game at each step via --write-movie

var _frame: int = 0
var _phase: String = "char_select"
var _battle: Node2D = null
var _main: Node = null
var _gm: Node = null

func _initialize() -> void:
	var main_packed = load("res://scenes/main.tscn")
	_main = main_packed.instantiate()
	root.add_child(_main)
	for child in root.get_children():
		if child.name == "GameManager":
			_gm = child
			break

func _process(_delta: float) -> bool:
	_frame += 1

	match _phase:
		"char_select":
			# Frames 1-10: Show character selection screen
			if _frame == 10:
				_start_battle()
				_phase = "battle_init"

		"battle_init":
			# Frames 10-25: Battle initializing
			if _frame == 25:
				_phase = "show_hand"

		"show_hand":
			# Frames 25-35: Show initial hand of 5 cards
			if _frame == 35:
				_hover_card(2)
				_phase = "hover"

		"hover":
			# Frames 35-48: Show card hover zoom + lift + spread
			if _frame == 48:
				_unhover_card(2)
				_phase = "pre_select"

		"pre_select":
			if _frame == 52:
				_phase = "select"

		"select":
			# Click first card to select it
			if _frame == 55:
				_click_card(0)
				_phase = "targeting"

		"targeting":
			# Frames 55-65: Show selected card (golden border)
			if _frame == 65:
				_play_current_card()
				_phase = "played1"

		"played1":
			# Frames 65-75: After first card played, 4 cards remain
			if _frame == 75:
				_click_card(0)
				_phase = "play2"

		"play2":
			if _frame == 80:
				_play_current_card()
				_phase = "played2"

		"played2":
			# After second card played, 3 cards remain
			if _frame == 90:
				_click_card(0)
				_phase = "play3"

		"play3":
			if _frame == 95:
				_play_current_card()
				_phase = "played3"

		"played3":
			if _frame == 105:
				# End turn
				if _battle and _battle.battle_active:
					_battle.end_player_turn()
				_phase = "end_turn"

		"end_turn":
			# Frames 105-115: Cards discarded, enemy turn starts
			if _frame == 155:
				_phase = "turn2"

		"turn2":
			# Frames 155+: New turn, fresh hand drawn
			if _frame == 175:
				quit(0)

	return false

func _start_battle() -> void:
	if _gm:
		_gm.select_character("ironclad")
	var char_select = _main.get_node_or_null("CharacterSelect")
	if char_select:
		char_select.free()
	var battle_scene: PackedScene = load("res://scenes/battle.tscn")
	_battle = battle_scene.instantiate()
	_battle.name = "Battle"
	_main.add_child(_battle)
	_battle.start_battle("ironclad")

func _hover_card(index: int) -> void:
	if _battle == null:
		return
	var card_hand = _battle.get_node_or_null("CardHand")
	if card_hand and card_hand.cards.size() > index:
		var card = card_hand.cards[index]
		card.emit_signal("card_hovered", card)

func _unhover_card(index: int) -> void:
	if _battle == null:
		return
	var card_hand = _battle.get_node_or_null("CardHand")
	if card_hand and card_hand.cards.size() > index:
		var card = card_hand.cards[index]
		card.emit_signal("card_unhovered", card)

func _click_card(index: int) -> void:
	if _battle == null:
		return
	var card_hand = _battle.get_node_or_null("CardHand")
	if card_hand and card_hand.cards.size() > index:
		var card = card_hand.cards[index]
		card.emit_signal("card_clicked", card)

func _play_current_card() -> void:
	if _battle == null:
		return
	var card_hand = _battle.get_node_or_null("CardHand")
	if card_hand == null or not card_hand.is_targeting():
		return
	var data = card_hand.get_selected_card_data()
	var target_type = data.get("target", "enemy")
	if target_type == "enemy":
		for enemy in _battle.enemies:
			if enemy.alive:
				card_hand.play_selected_on(enemy)
				return
	elif target_type == "self" and _battle.player:
		card_hand.play_selected_on(_battle.player)
	elif target_type == "all_enemies" and not _battle.enemies.is_empty():
		card_hand.play_selected_on(_battle.enemies[0])
