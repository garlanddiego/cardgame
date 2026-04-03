extends SceneTree
## Scene builder — run: timeout 60 godot --headless --script scenes/build_battle.gd

func _initialize() -> void:
	print("Generating: battle.tscn")
	var root = Node2D.new()
	root.name = "Battle"
	root.set_script(load("res://scripts/battle_manager.gd"))

	# Dungeon background image
	var bg = TextureRect.new()
	bg.name = "Background"
	bg.texture = load("res://assets/img/dungeon_bg_sts.png")
	bg.position = Vector2.ZERO
	bg.size = Vector2(2560, 1080)  # Extra wide to cover any aspect ratio
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.z_index = -10
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	# Player area — positioned so midpoint of player+enemies is screen center
	# With 1 enemy: player at ~480, enemy at ~1200 → midpoint ~840 (near center)
	var player_area = Node2D.new()
	player_area.name = "PlayerArea"
	player_area.position = Vector2(480, 480)
	root.add_child(player_area)

	# Enemy area — right side, centered vertically
	var enemy_area = Node2D.new()
	enemy_area.name = "EnemyArea"
	enemy_area.position = Vector2(1200, 480)
	root.add_child(enemy_area)

	# Card hand (bottom center) - Node2D for Area2D-based cards
	var card_hand = Node2D.new()
	card_hand.name = "CardHand"
	card_hand.set_script(load("res://scripts/card_hand.gd"))
	card_hand.position = Vector2(0, 715)  # Shifted down 15px per user request
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
	energy_panel.position = Vector2(24, 772)  # Moved up 50px
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

	# Draw pile (bottom left, STS-style: card stack icon + number)
	var draw_panel = Panel.new()
	draw_panel.name = "DrawPanel"
	draw_panel.position = Vector2(20, 960)  # 1080-15-105=960
	draw_panel.size = Vector2(70, 105)  # 50% taller
	var draw_style = StyleBoxFlat.new()
	draw_style.bg_color = Color(0.12, 0.15, 0.25, 0.9)
	draw_style.border_color = Color(0.4, 0.5, 0.8)
	draw_style.set_border_width_all(2)
	draw_style.set_corner_radius_all(8)
	draw_panel.add_theme_stylebox_override("panel", draw_style)
	draw_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(draw_panel)
	var draw_pile_label = Label.new()
	draw_pile_label.name = "DrawPileLabel"
	draw_pile_label.text = "0"
	draw_pile_label.position = Vector2(0, 40)
	draw_pile_label.size = Vector2(70, 50)
	draw_pile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draw_pile_label.add_theme_font_size_override("font_size", 32)
	draw_pile_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	draw_panel.add_child(draw_pile_label)
	var draw_icon = Label.new()
	draw_icon.text = "🂠"
	draw_icon.position = Vector2(0, 8)
	draw_icon.size = Vector2(70, 30)
	draw_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draw_icon.add_theme_font_size_override("font_size", 18)
	draw_panel.add_child(draw_icon)

	# Discard pile (bottom right, STS-style: card stack icon + number)
	var discard_panel = Panel.new()
	discard_panel.name = "DiscardPanel"
	discard_panel.position = Vector2(1830, 960)  # 1080-15-105=960
	discard_panel.size = Vector2(70, 105)  # 50% taller
	var discard_style = StyleBoxFlat.new()
	discard_style.bg_color = Color(0.25, 0.12, 0.12, 0.9)
	discard_style.border_color = Color(0.8, 0.4, 0.4)
	discard_style.set_border_width_all(2)
	discard_style.set_corner_radius_all(8)
	discard_panel.add_theme_stylebox_override("panel", discard_style)
	discard_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(discard_panel)
	var discard_label = Label.new()
	discard_label.name = "DiscardPileLabel"
	discard_label.text = "0"
	discard_label.position = Vector2(0, 40)
	discard_label.size = Vector2(70, 50)
	discard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_label.add_theme_font_size_override("font_size", 32)
	discard_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.7))
	discard_panel.add_child(discard_label)
	var discard_icon = Label.new()
	discard_icon.text = "🂠"
	discard_icon.position = Vector2(0, 8)
	discard_icon.size = Vector2(70, 30)
	discard_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_icon.add_theme_font_size_override("font_size", 18)
	discard_panel.add_child(discard_icon)

	# End turn button — per spec section 4.6: 220x56, positioned at 1680,762
	var end_turn_btn = Button.new()
	end_turn_btn.name = "EndTurnButton"
	end_turn_btn.text = "End Turn"
	end_turn_btn.position = Vector2(1640, 765)  # Aligned with energy panel center
	end_turn_btn.custom_minimum_size = Vector2(240, 70)
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
