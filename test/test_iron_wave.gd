extends SceneTree
## Test Iron Wave: before/after screenshots showing damage + block gain
var _frame: int = 0
var _main: Node = null
var _battle: Node2D = null
var _phase: String = "setup"

func _initialize() -> void:
	var main_packed = load("res://scenes/main.tscn")
	_main = main_packed.instantiate()
	root.add_child(_main)

func _process(_delta: float) -> bool:
	_frame += 1

	match _phase:
		"setup":
			if _frame == 10:
				var builder = _find_child(_main, "DeckBuilder")
				if builder:
					# Select ONLY iron_wave — guaranteed to be drawn
					builder.selected_card_ids["ic_iron_wave"] = true
					builder._update_ui()
			if _frame == 15:
				var builder = _find_child(_main, "DeckBuilder")
				if builder:
					builder._on_confirm()
					_phase = "find_battle"

		"find_battle":
			if _frame == 30:
				_battle = _find_child(_main, "BattleInstance") as Node2D
				if _battle == null:
					_battle = _find_child(_main, "Battle") as Node2D
				if _battle:
					_phase = "before"
				else:
					print("ERROR: Battle not found at frame 30, retrying...")
			if _frame == 40 and _battle == null:
				_battle = _find_child(_main, "BattleInstance") as Node2D
				if _battle == null:
					_battle = _find_child(_main, "Battle") as Node2D
				if _battle:
					_phase = "before"
				else:
					print("ERROR: Battle still not found")
					quit(1)

		"before":
			if _frame == 50:
				# Print state before playing Iron Wave
				if _battle.player:
					print("BEFORE: Player HP=%d Block=%d" % [_battle.player.current_hp, _battle.player.block])
				for e in _battle.enemies:
					if e.alive:
						print("BEFORE: Enemy HP=%d/%d Block=%d" % [e.current_hp, e.max_hp, e.block])
				_phase = "play"

		"play":
			if _frame == 55:
				# Find and play Iron Wave on the enemy
				var ch = _battle.get_node_or_null("CardHand")
				if ch:
					var played = false
					for card in ch.cards:
						if not is_instance_valid(card):
							continue
						var card_id = card.card_data.get("id", "")
						if card_id == "ic_iron_wave":
							print("PLAYING: Iron Wave (5 dmg + 5 block)")
							# Use play_card_on directly — targeted cards need drag, not click
							for enemy in _battle.enemies:
								if enemy.alive:
									ch.play_card_on(card, enemy)
									played = true
									break
							break
					if not played:
						print("WARNING: Could not play Iron Wave - card not found in hand")
				_phase = "after"

		"after":
			if _frame == 70:
				# Print state after playing Iron Wave
				if _battle.player:
					print("AFTER: Player HP=%d Block=%d" % [_battle.player.current_hp, _battle.player.block])
				for e in _battle.enemies:
					if e.alive:
						print("AFTER: Enemy HP=%d/%d Block=%d" % [e.current_hp, e.max_hp, e.block])

				# Verify results
				if _battle.player and _battle.player.block >= 5:
					print("VERIFY: Player block gained - PASS")
				else:
					print("VERIFY: Player block gained - FAIL")

				var enemy_damaged = false
				for e in _battle.enemies:
					if e.current_hp < e.max_hp:
						enemy_damaged = true
				if enemy_damaged:
					print("VERIFY: Enemy took damage - PASS")
				else:
					print("VERIFY: Enemy took damage - FAIL")

				_phase = "done"

		"done":
			if _frame == 85:
				print("TEST COMPLETE")
				quit(0)

	# Safety timeout
	if _frame > 300:
		print("TEST: Safety timeout at frame %d" % _frame)
		quit(1)

	return false

func _find_child(node: Node, child_name: String) -> Node:
	for c in node.get_children():
		if c.name == child_name:
			return c
		var found = _find_child(c, child_name)
		if found:
			return found
	return null
