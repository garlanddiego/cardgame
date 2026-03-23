extends SceneTree
## Test Strike, Defend, Bash — capture before/after each card play

var _frame: int = 0
var _main: Node = null
var _builder: Node = null
var _battle: Node2D = null
var _phase: String = "setup"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://screenshots/card_test")
	var main_packed = load("res://scenes/main.tscn")
	_main = main_packed.instantiate()
	root.add_child(main_packed.instantiate())
	# Wait for GameManager
	_main = root.get_children()[-1]

func _process(_delta: float) -> bool:
	_frame += 1

	match _phase:
		"setup":
			if _frame == 10:
				# Find deck builder and select Strike, Defend, Bash
				_builder = _find_child(root, "DeckBuilder")
				if _builder:
					# Select exactly these 3 cards + fillers
					var gm = _get_gm()
					if gm:
						_builder.selected_card_ids["ic_strike"] = true
						_builder.selected_card_ids["ic_defend"] = true
						_builder.selected_card_ids["ic_bash"] = true
						# Add more to make a playable deck
						_builder.selected_card_ids["ic_strike"] = true
						var count = 3
						for cid in gm.card_database:
							if count >= 10:
								break
							var c = gm.card_database[cid]
							if c["character"] == "ironclad" and c["type"] != 3 and not _builder.selected_card_ids.has(cid):
								_builder.selected_card_ids[cid] = true
								count += 1
						_builder._update_ui()
			if _frame == 15:
				if _builder:
					_builder._on_confirm()
					_phase = "find_battle"

		"find_battle":
			if _frame == 30:
				_battle = _find_child(root, "BattleInstance") as Node2D
				if _battle == null:
					_battle = _find_child(root, "Battle") as Node2D
				if _battle:
					_phase = "before_play"
				else:
					print("ERROR: No battle found")
					quit(1)

		"before_play":
			# Capture the initial battle state
			if _frame == 35:
				print("TEST: Before any cards played")
				print("  Player HP: %d/%d" % [_battle.player.current_hp, _battle.player.max_hp])
				print("  Player Block: %d" % _battle.player.block)
				print("  Energy: %d/%d" % [_battle.current_energy, _battle.max_energy])
				for i in range(_battle.enemies.size()):
					var e = _battle.enemies[i]
					if e.alive:
						print("  Enemy %d (%s): HP %d/%d, Status: %s" % [i, e.enemy_type, e.current_hp, e.max_hp, str(e.status_effects)])
				print("  Hand size: %d" % _battle.hand.size())
				for cd in _battle.hand:
					print("    Card: %s (cost %d)" % [cd.get("name", "?"), cd.get("cost", 0)])
				_phase = "play_card_1"

		"play_card_1":
			# Play first available attack card on enemy 0
			if _frame == 40:
				var card_hand = _battle.get_node_or_null("CardHand")
				if card_hand and not card_hand.cards.is_empty():
					for card in card_hand.cards:
						var data = card.card_data
						if data.get("damage", 0) > 0 and data.get("target", "") == "enemy":
							print("TEST: Playing %s (damage %d) on enemy 0" % [data["name"], data["damage"]])
							card_hand.play_card_on(card, _battle.enemies[0])
							break
				_phase = "after_play_1"

		"after_play_1":
			if _frame == 45:
				print("TEST: After playing attack card")
				for i in range(_battle.enemies.size()):
					var e = _battle.enemies[i]
					if e.alive:
						print("  Enemy %d (%s): HP %d/%d, Status: %s" % [i, e.enemy_type, e.current_hp, e.max_hp, str(e.status_effects)])
				_phase = "play_defend"

		"play_defend":
			if _frame == 50:
				var card_hand = _battle.get_node_or_null("CardHand")
				if card_hand:
					for card in card_hand.cards:
						var data = card.card_data
						if data.get("block", 0) > 0:
							print("TEST: Playing %s (block %d)" % [data["name"], data["block"]])
							if _battle.player:
								card_hand.play_card_on(card, _battle.player)
							break
				_phase = "after_defend"

		"after_defend":
			if _frame == 55:
				print("TEST: After playing defend")
				print("  Player Block: %d" % _battle.player.block)
				_phase = "play_bash"

		"play_bash":
			if _frame == 60:
				var card_hand = _battle.get_node_or_null("CardHand")
				if card_hand:
					for card in card_hand.cards:
						var data = card.card_data
						if data.get("id", "") == "ic_bash" or (data.get("apply_status", {}).get("type", "") == "vulnerable"):
							print("TEST: Playing %s (damage %d, applies vulnerable)" % [data["name"], data.get("damage", 0)])
							card_hand.play_card_on(card, _battle.enemies[0])
							break
				_phase = "after_bash"

		"after_bash":
			if _frame == 65:
				print("TEST: After playing Bash")
				for i in range(_battle.enemies.size()):
					var e = _battle.enemies[i]
					if e.alive:
						print("  Enemy %d (%s): HP %d/%d, Status: %s" % [i, e.enemy_type, e.current_hp, e.max_hp, str(e.status_effects)])
				_phase = "done"

		"done":
			if _frame == 75:
				quit(0)

	return false

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
