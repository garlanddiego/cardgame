extends SceneTree
## End-to-end test: random 10 cards → full battle until victory or defeat

var _frame: int = 0
var _main: Node = null
var _builder: Node = null
var _battle: Node2D = null
var _phase: String = "deck_build"
var _turn_count: int = 0

func _initialize() -> void:
	var main_packed = load("res://scenes/main.tscn")
	_main = main_packed.instantiate()
	root.add_child(_main)

func _process(_delta: float) -> bool:
	_frame += 1

	match _phase:
		"deck_build":
			if _frame == 10:
				_builder = _find_child(_main, "DeckBuilder")
				if _builder:
					_random_select_10()
			if _frame == 20:
				if _builder:
					_builder._on_confirm()
					_phase = "battle_init"

		"battle_init":
			if _frame == 35:
				_battle = _find_child(_main, "BattleInstance") as Node2D
				if _battle == null:
					_battle = _find_child(_main, "Battle") as Node2D
				if _battle:
					_phase = "player_turn"
				else:
					print("ERROR: Battle not found")
					quit(1)

		"player_turn":
			# Play cards automatically
			if _battle and _battle.battle_active and _battle.is_player_turn:
				_auto_play_card()
			elif _battle and not _battle.battle_active:
				_phase = "battle_end"
			elif _battle and not _battle.is_player_turn:
				_phase = "enemy_turn"

		"enemy_turn":
			# Wait for enemy turn to finish
			if _battle and _battle.is_player_turn:
				_turn_count += 1
				if _turn_count > 20:
					print("TEST: Too many turns, ending")
					_phase = "battle_end"
				else:
					_phase = "player_turn"
			elif _battle and not _battle.battle_active:
				_phase = "battle_end"

		"battle_end":
			print("TEST: Battle ended at frame " + str(_frame) + " after " + str(_turn_count) + " turns")
			if _battle:
				var all_dead = true
				for enemy in _battle.enemies:
					if enemy.alive:
						all_dead = false
				if all_dead:
					print("TEST RESULT: VICTORY")
				elif _battle.player and not _battle.player.alive:
					print("TEST RESULT: DEFEAT")
				else:
					print("TEST RESULT: DRAW/TIMEOUT")
			# Wait a few more frames for final state
			if _frame > 500 or _turn_count > 20:
				quit(0)
			_phase = "done"

		"done":
			if _frame % 30 == 0:
				quit(0)

	# Safety timeout
	if _frame > 2000:
		print("TEST: Safety timeout")
		quit(0)

	return false

func _random_select_10() -> void:
	var gm = _get_gm()
	if gm == null or _builder == null:
		return
	var all_ids: Array = []
	for card_id in gm.card_database:
		var card = gm.card_database[card_id]
		if card["character"] == "ironclad" and card["type"] != 3:
			all_ids.append(card_id)
	all_ids.shuffle()
	for i in range(mini(10, all_ids.size())):
		_builder.selected_card_ids[all_ids[i]] = true
	_builder._update_ui()
	print("TEST: Selected 10 random cards")

func _auto_play_card() -> void:
	if _battle == null or not _battle.battle_active:
		return
	var card_hand = _battle.get_node_or_null("CardHand")
	if card_hand == null:
		return

	# Try to play a card
	if card_hand.cards.size() > 0 and _battle.current_energy > 0:
		# Find a playable card (cost <= energy)
		for card in card_hand.cards:
			if not is_instance_valid(card):
				continue
			var data = card.card_data
			var cost = data.get("cost", 0)
			if cost == -1:
				cost = _battle.current_energy  # X-cost uses all energy
			if cost <= _battle.current_energy and not data.get("unplayable", false):
				# Select and play
				card_hand._on_card_clicked(card)
				# Auto-target
				var target_type = data.get("target", "enemy")
				if target_type == "enemy":
					for enemy in _battle.enemies:
						if enemy.alive:
							card_hand.play_selected_on(enemy)
							return
				elif target_type == "self" and _battle.player:
					card_hand.play_selected_on(_battle.player)
					return
				elif target_type == "all_enemies" and not _battle.enemies.is_empty():
					card_hand.play_selected_on(_battle.enemies[0])
					return
				# If we got here, couldn't target — deselect
				if card_hand.selected_card:
					card_hand.selected_card.set_selected(false)
					card_hand.selected_card = null
					card_hand.targeting_mode = false

	# No playable cards or no energy — end turn
	if _battle.is_player_turn and _battle.battle_active:
		_battle.end_player_turn()

func _get_gm() -> Node:
	for child in root.get_children():
		if child.name == "GameManager":
			return child
	return null

func _find_child(node: Node, child_name: String) -> Node:
	for c in node.get_children():
		if c.name == child_name:
			return c
		var found = _find_child(c, child_name)
		if found:
			return found
	return null
