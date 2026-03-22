extends SceneTree
## Scene builder — run: timeout 60 godot --headless --script scenes/build_battle.gd

func _initialize() -> void:
	print("Generating: battle.tscn")
	var root = Node2D.new()
	root.name = "Battle"
	root.set_script(load("res://scripts/battle_manager.gd"))

	# Background - dungeon image as Sprite2D (TextureRect doesn't work in Node2D)
	var bg = Sprite2D.new()
	bg.name = "Background"
	bg.texture = load("res://assets/img/sts_sprites/battle_bg.png")
	bg.centered = false
	# Scale to fill 1920x1080
	if bg.texture:
		var tex_size: Vector2 = bg.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			bg.scale = Vector2(1920.0 / tex_size.x, 1080.0 / tex_size.y)
	bg.z_index = -10
	root.add_child(bg)

	# Player area (far left, like STS)
	var player_area = Node2D.new()
	player_area.name = "PlayerArea"
	player_area.position = Vector2(180, 500)
	root.add_child(player_area)

	# Enemy area (spread across right half, at ground level)
	var enemy_area = Node2D.new()
	enemy_area.name = "EnemyArea"
	enemy_area.position = Vector2(900, 500)
	root.add_child(enemy_area)

	# Card hand (bottom center) - Node2D for Area2D-based cards
	var card_hand = Node2D.new()
	card_hand.name = "CardHand"
	card_hand.set_script(load("res://scripts/card_hand.gd"))
	card_hand.position = Vector2(0, 750)
	root.add_child(card_hand)

	# HUD layer
	var hud_layer = CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	hud_layer.layer = 1
	root.add_child(hud_layer)

	# Dark overlay on HUD layer (behind HUD elements)
	var dark_overlay = ColorRect.new()
	dark_overlay.name = "DarkOverlay"
	dark_overlay.color = Color(0.0, 0.0, 0.05, 0.05)  # Minimal overlay to preserve dungeon atmosphere
	dark_overlay.position = Vector2(0, 0)
	dark_overlay.size = Vector2(1920, 1080)
	dark_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(dark_overlay)

	var hud = Control.new()
	hud.name = "HUD"
	hud.position = Vector2(0, 0)
	hud.size = Vector2(1920, 1080)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud)

	# Energy display (bottom left) — bigger, styled per spec section 4.1
	var energy_panel = PanelContainer.new()
	energy_panel.name = "EnergyPanel"
	energy_panel.position = Vector2(24, 822)
	energy_panel.custom_minimum_size = Vector2(120, 72)
	var energy_style = StyleBoxFlat.new()
	energy_style.bg_color = Color(0.05, 0.08, 0.18, 0.85)
	energy_style.border_color = Color(0.5, 0.8, 1.0, 0.9)
	energy_style.border_width_left = 3
	energy_style.border_width_right = 3
	energy_style.border_width_top = 3
	energy_style.border_width_bottom = 3
	energy_style.corner_radius_top_left = 36
	energy_style.corner_radius_top_right = 36
	energy_style.corner_radius_bottom_left = 36
	energy_style.corner_radius_bottom_right = 36
	energy_style.content_margin_left = 12
	energy_style.content_margin_right = 12
	energy_style.content_margin_top = 8
	energy_style.content_margin_bottom = 8
	energy_panel.add_theme_stylebox_override("panel", energy_style)
	hud.add_child(energy_panel)

	var energy_container = HBoxContainer.new()
	energy_container.name = "EnergyContainer"
	energy_container.alignment = BoxContainer.ALIGNMENT_CENTER
	energy_panel.add_child(energy_container)

	# Energy orb icon — spec calls for 72x72 ideally
	var energy_icon = TextureRect.new()
	energy_icon.name = "EnergyIcon"
	energy_icon.texture = load("res://assets/img/ui_icons/energy_orb.png")
	energy_icon.custom_minimum_size = Vector2(48, 48)
	energy_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	energy_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	energy_container.add_child(energy_icon)

	var energy_label = Label.new()
	energy_label.name = "EnergyLabel"
	energy_label.text = "3/3"
	energy_label.add_theme_font_size_override("font_size", 36)
	energy_label.add_theme_color_override("font_color", Color(0.200, 0.600, 1.0, 1.0))  # energy_blue
	energy_container.add_child(energy_label)

	# Draw pile label (bottom left)
	var draw_pile_label = Label.new()
	draw_pile_label.name = "DrawPileLabel"
	draw_pile_label.text = "Draw: 0"
	draw_pile_label.position = Vector2(60, 900)
	draw_pile_label.add_theme_font_size_override("font_size", 18)
	draw_pile_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	hud.add_child(draw_pile_label)

	# Discard pile (bottom right)
	var discard_label = Label.new()
	discard_label.name = "DiscardPileLabel"
	discard_label.text = "Discard: 0"
	discard_label.position = Vector2(1740, 900)
	discard_label.add_theme_font_size_override("font_size", 18)
	discard_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.7))
	hud.add_child(discard_label)

	# End turn button — per spec section 4.6: 220x56, positioned at 1680,762
	var end_turn_btn = Button.new()
	end_turn_btn.name = "EndTurnButton"
	end_turn_btn.text = "End Turn"
	end_turn_btn.position = Vector2(1680, 762)
	end_turn_btn.custom_minimum_size = Vector2(220, 56)
	hud.add_child(end_turn_btn)

	# Turn indicator with semi-transparent bg
	var turn_panel = PanelContainer.new()
	turn_panel.name = "TurnPanel"
	turn_panel.position = Vector2(830, 10)
	turn_panel.custom_minimum_size = Vector2(260, 50)
	var turn_style = StyleBoxFlat.new()
	turn_style.bg_color = Color(0.05, 0.05, 0.1, 0.7)
	turn_style.border_color = Color(0.6, 0.6, 0.3, 0.6)
	turn_style.border_width_left = 1
	turn_style.border_width_right = 1
	turn_style.border_width_top = 1
	turn_style.border_width_bottom = 1
	turn_style.corner_radius_top_left = 6
	turn_style.corner_radius_top_right = 6
	turn_style.corner_radius_bottom_left = 6
	turn_style.corner_radius_bottom_right = 6
	turn_style.content_margin_left = 12
	turn_style.content_margin_right = 12
	turn_style.content_margin_top = 4
	turn_style.content_margin_bottom = 4
	turn_panel.add_theme_stylebox_override("panel", turn_style)
	hud.add_child(turn_panel)

	var turn_label = Label.new()
	turn_label.name = "TurnLabel"
	turn_label.text = "Your Turn"
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 28)
	turn_label.add_theme_color_override("font_color", Color(0.27, 0.8, 0.4))
	turn_panel.add_child(turn_label)

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
