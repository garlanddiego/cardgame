extends SceneTree
## Test Bash: 8 damage + 2 Vulnerable. Before/after screenshots.

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
					builder.selected_card_ids["ic_bash"] = true
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
		"before":
			if _frame == 45:
				print("BEFORE: Player HP=%d Block=%d" % [_battle.player.current_hp, _battle.player.block])
				for e in _battle.enemies:
					if e.alive:
						print("BEFORE: Enemy (%s) HP=%d/%d Status=%s" % [e.enemy_type, e.current_hp, e.max_hp, str(e.status_effects)])
				_phase = "play"
		"play":
			if _frame == 50:
				var ch = _battle.get_node_or_null("CardHand")
				if ch:
					for card in ch.cards:
						if card.card_data.get("id", "") == "ic_bash":
							print("PLAYING: Bash (8 dmg + 2 Vulnerable)")
							ch.play_card_on(card, _battle.enemies[0])
							break
				_phase = "after"
		"after":
			if _frame == 60:
				print("AFTER: Player HP=%d Block=%d" % [_battle.player.current_hp, _battle.player.block])
				for e in _battle.enemies:
					if e.alive:
						print("AFTER: Enemy (%s) HP=%d/%d Status=%s" % [e.enemy_type, e.current_hp, e.max_hp, str(e.status_effects)])
				_phase = "done"
		"done":
			if _frame == 70:
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
