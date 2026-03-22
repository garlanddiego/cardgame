extends SceneTree
## Scene builder — run: timeout 60 godot --headless --script scenes/build_battle.gd

func _initialize() -> void:
	var root = Node2D.new()
	root.name = "Battle"
	root.set_script(load("res://scripts/battle_manager.gd"))

	# Background
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.12, 0.1, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.size = Vector2(1920, 1080)
	root.add_child(bg)

	# Player area (left side)
	var player_area = Node2D.new()
	player_area.name = "PlayerArea"
	player_area.position = Vector2(350, 500)
	root.add_child(player_area)

	# Enemy area (right side) with 3 slots
	var enemy_area = Node2D.new()
	enemy_area.name = "EnemyArea"
	enemy_area.position = Vector2(1200, 450)
	root.add_child(enemy_area)

	# Card hand (bottom center)
	var card_hand = Control.new()
	card_hand.name = "CardHand"
	card_hand.set_script(load("res://scripts/card_hand.gd"))
	card_hand.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	card_hand.position = Vector2(0, 780)
	card_hand.size = Vector2(1920, 300)
	root.add_child(card_hand)

	# HUD layer
	var hud_layer = CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	hud_layer.layer = 1
	root.add_child(hud_layer)

	var hud = Control.new()
	hud.name = "HUD"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud)

	# Energy display (bottom left)
	var energy_container = HBoxContainer.new()
	energy_container.name = "EnergyContainer"
	energy_container.position = Vector2(80, 830)
	hud.add_child(energy_container)

	var energy_label = Label.new()
	energy_label.name = "EnergyLabel"
	energy_label.text = "3/3"
	energy_label.add_theme_font_size_override("font_size", 36)
	energy_container.add_child(energy_label)

	# Draw pile (bottom right)
	var draw_pile_label = Label.new()
	draw_pile_label.name = "DrawPileLabel"
	draw_pile_label.text = "Draw: 0"
	draw_pile_label.position = Vector2(100, 950)
	draw_pile_label.add_theme_font_size_override("font_size", 20)
	hud.add_child(draw_pile_label)

	# Discard pile
	var discard_label = Label.new()
	discard_label.name = "DiscardPileLabel"
	discard_label.text = "Discard: 0"
	discard_label.position = Vector2(1700, 950)
	discard_label.add_theme_font_size_override("font_size", 20)
	hud.add_child(discard_label)

	# End turn button
	var end_turn_btn = Button.new()
	end_turn_btn.name = "EndTurnButton"
	end_turn_btn.text = "End Turn"
	end_turn_btn.position = Vector2(1700, 830)
	end_turn_btn.custom_minimum_size = Vector2(150, 50)
	hud.add_child(end_turn_btn)

	# Turn indicator
	var turn_label = Label.new()
	turn_label.name = "TurnLabel"
	turn_label.text = "Your Turn"
	turn_label.position = Vector2(860, 20)
	turn_label.add_theme_font_size_override("font_size", 32)
	hud.add_child(turn_label)

	_set_owners(root, root)
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/battle.tscn")
	print("Saved: res://scenes/battle.tscn")
	quit(0)

func _set_owners(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		if c.scene_file_path.is_empty():
			_set_owners(c, owner)
