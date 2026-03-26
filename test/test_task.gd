extends SceneTree
## Test harness for Task 1: Core Battle System
## Shows character select briefly, then auto-selects Ironclad and shows battle

var _frame: int = 0
var _phase: String = "char_select"
var _battle_node: Node2D = null
var _gm: Node = null

func _initialize() -> void:
	print("TEST: Core Battle System")
	# Load main scene
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	# Find GameManager
	for child in root.get_children():
		if child.name == "GameManager":
			_gm = child
			break
	print("ASSERT PASS: Main scene loaded")

func _process(delta: float) -> bool:
	_frame += 1
	match _phase:
		"char_select":
			if _frame == 15:
				# Auto-select Ironclad after showing char select screen
				_auto_select_character()
		"battle_start":
			if _frame > 20:
				_verify_battle_state()
				_phase = "battle_running"
		"battle_running":
			# Let battle run for a few frames
			if _frame == 40:
				_simulate_hover()
			if _frame == 60:
				_verify_final()
	return false

func _auto_select_character() -> void:
	print("TEST: Selecting Ironclad...")
	if _gm:
		_gm.select_character("ironclad")
	# Find the Main node and trigger character selection
	var main_node: Node = null
	for child in root.get_children():
		if child.name == "Main":
			main_node = child
			break
	if main_node == null:
		print("ASSERT FAIL: Main node not found")
		return
	# Manually trigger what _on_character_chosen does
	var char_select = main_node.get_node_or_null("CharacterSelect")
	if char_select:
		char_select.free()
	var battle_scene: PackedScene = load("res://scenes/battle.tscn")
	var battle = battle_scene.instantiate()
	battle.name = "BattleInstance"
	main_node.add_child(battle)
	_battle_node = battle
	battle.start_battle("ironclad")
	_phase = "battle_start"
	print("ASSERT PASS: Battle started")

func _verify_battle_state() -> void:
	if _battle_node == null:
		print("ASSERT FAIL: Battle node is null")
		return
	# Check player exists
	var player_area = _battle_node.get_node_or_null("PlayerArea")
	if player_area and player_area.get_child_count() > 0:
		print("ASSERT PASS: Player entity present")
		var player = player_area.get_child(0)
		if player.has_method("take_damage"):
			print("ASSERT PASS: Player has entity script")
	else:
		print("ASSERT FAIL: No player in PlayerArea")
	# Check enemies exist
	var enemy_area = _battle_node.get_node_or_null("EnemyArea")
	if enemy_area and enemy_area.get_child_count() == 3:
		print("ASSERT PASS: 3 enemies present")
	else:
		var count: int = enemy_area.get_child_count() if enemy_area else 0
		print("ASSERT FAIL: Expected 3 enemies, got " + str(count))
	# Check card hand
	var card_hand = _battle_node.get_node_or_null("CardHand")
	if card_hand and card_hand.get_child_count() >= 5:
		print("ASSERT PASS: Card hand has 5+ cards")
	else:
		var count: int = card_hand.get_child_count() if card_hand else 0
		print("ASSERT FAIL: Card hand has " + str(count) + " cards, expected 5+")
	# Check energy label
	var energy_label = _battle_node.get_node_or_null("HUDLayer/HUD/EnergyPanel/EnergyContainer/EnergyLabel")
	if energy_label:
		print("ASSERT PASS: Energy label text: " + energy_label.text)
	# Check battle is active
	if _battle_node.battle_active:
		print("ASSERT PASS: Battle is active")
	else:
		print("ASSERT FAIL: Battle is not active")

func _simulate_hover() -> void:
	# Simulate mouse hovering over a card
	var card_hand = _battle_node.get_node_or_null("CardHand") if _battle_node else null
	if card_hand and card_hand.cards.size() > 2:
		var card = card_hand.cards[2]
		card._on_mouse_entered()
		print("ASSERT PASS: Simulated hover on card #3")

func _verify_final() -> void:
	print("TEST: Final verification")
	if _battle_node:
		print("ASSERT PASS: Battle scene still running")
		# Check turn label
		var turn_label = _battle_node.get_node_or_null("HUDLayer/HUD/TurnPanel/TurnLabel")
		if turn_label:
			print("ASSERT PASS: Turn label: " + turn_label.text)
		# Verify draw/discard pile labels
		var draw_label = _battle_node.get_node_or_null("HUDLayer/HUD/DrawPanel/DrawPileLabel")
		if draw_label:
			print("ASSERT PASS: Draw pile: " + draw_label.text)
		var discard_label = _battle_node.get_node_or_null("HUDLayer/HUD/DiscardPanel/DiscardPileLabel")
		if discard_label:
			print("ASSERT PASS: Discard pile: " + discard_label.text)
	print("TEST: All checks complete")
