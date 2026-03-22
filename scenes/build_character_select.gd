extends SceneTree
## Scene builder — run: timeout 60 godot --headless --script scenes/build_character_select.gd

func _initialize() -> void:
	print("Generating: character_select.tscn")
	var root = Control.new()
	root.name = "CharacterSelect"
	# Explicitly set size instead of anchors (parent is Node2D, not Control)
	root.position = Vector2(0, 0)
	root.size = Vector2(1920, 1080)
	root.set_script(load("res://scripts/character_select.gd"))

	# Dark background using Sprite2D approach won't work in Control.
	# Use TextureRect which works fine when Control is root
	var bg = TextureRect.new()
	bg.name = "Background"
	bg.texture = load("res://assets/img/dungeon_bg.png")
	bg.position = Vector2(0, 0)
	bg.size = Vector2(1920, 1080)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(bg)

	# Extra dark overlay
	var dark_overlay = ColorRect.new()
	dark_overlay.name = "DarkOverlay"
	dark_overlay.color = Color(0.0, 0.0, 0.0, 0.5)
	dark_overlay.position = Vector2(0, 0)
	dark_overlay.size = Vector2(1920, 1080)
	dark_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dark_overlay)

	# Center container - position explicitly
	var center = CenterContainer.new()
	center.name = "Center"
	center.position = Vector2(0, 0)
	center.size = Vector2(1920, 1080)
	root.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	# Title
	var title = Label.new()
	title.name = "Title"
	title.text = "Choose Your Character"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	vbox.add_child(title)

	var spacer = Control.new()
	spacer.name = "Spacer"
	spacer.custom_minimum_size = Vector2(0, 50)
	vbox.add_child(spacer)

	# Character buttons container
	var hbox = HBoxContainer.new()
	hbox.name = "Characters"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 120)
	vbox.add_child(hbox)

	# Ironclad panel
	var ironclad_panel = PanelContainer.new()
	ironclad_panel.name = "IroncladPanel"
	var ic_style = StyleBoxFlat.new()
	ic_style.bg_color = Color(0.15, 0.05, 0.05, 0.8)
	ic_style.border_color = Color(0.8, 0.2, 0.2, 0.8)
	ic_style.border_width_left = 2
	ic_style.border_width_right = 2
	ic_style.border_width_top = 2
	ic_style.border_width_bottom = 2
	ic_style.corner_radius_top_left = 12
	ic_style.corner_radius_top_right = 12
	ic_style.corner_radius_bottom_left = 12
	ic_style.corner_radius_bottom_right = 12
	ic_style.content_margin_left = 20
	ic_style.content_margin_right = 20
	ic_style.content_margin_top = 20
	ic_style.content_margin_bottom = 20
	ironclad_panel.add_theme_stylebox_override("panel", ic_style)
	hbox.add_child(ironclad_panel)

	var ironclad_box = VBoxContainer.new()
	ironclad_box.name = "IroncladBox"
	ironclad_box.alignment = BoxContainer.ALIGNMENT_CENTER
	ironclad_panel.add_child(ironclad_box)

	var ironclad_art = TextureRect.new()
	ironclad_art.name = "IroncladArt"
	ironclad_art.custom_minimum_size = Vector2(200, 300)
	ironclad_art.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	ironclad_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ironclad_box.add_child(ironclad_art)

	var ironclad_btn = Button.new()
	ironclad_btn.name = "IroncladButton"
	ironclad_btn.text = "Ironclad"
	ironclad_btn.custom_minimum_size = Vector2(200, 50)
	ironclad_box.add_child(ironclad_btn)

	var ironclad_desc = Label.new()
	ironclad_desc.name = "IroncladDesc"
	ironclad_desc.text = "HP: 80 | Strength-focused"
	ironclad_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ironclad_desc.add_theme_color_override("font_color", Color(0.9, 0.7, 0.7))
	ironclad_box.add_child(ironclad_desc)

	# Silent panel
	var silent_panel = PanelContainer.new()
	silent_panel.name = "SilentPanel"
	var si_style = StyleBoxFlat.new()
	si_style.bg_color = Color(0.05, 0.12, 0.05, 0.8)
	si_style.border_color = Color(0.2, 0.7, 0.3, 0.8)
	si_style.border_width_left = 2
	si_style.border_width_right = 2
	si_style.border_width_top = 2
	si_style.border_width_bottom = 2
	si_style.corner_radius_top_left = 12
	si_style.corner_radius_top_right = 12
	si_style.corner_radius_bottom_left = 12
	si_style.corner_radius_bottom_right = 12
	si_style.content_margin_left = 20
	si_style.content_margin_right = 20
	si_style.content_margin_top = 20
	si_style.content_margin_bottom = 20
	silent_panel.add_theme_stylebox_override("panel", si_style)
	hbox.add_child(silent_panel)

	var silent_box = VBoxContainer.new()
	silent_box.name = "SilentBox"
	silent_box.alignment = BoxContainer.ALIGNMENT_CENTER
	silent_panel.add_child(silent_box)

	var silent_art = TextureRect.new()
	silent_art.name = "SilentArt"
	silent_art.custom_minimum_size = Vector2(200, 300)
	silent_art.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	silent_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	silent_box.add_child(silent_art)

	var silent_btn = Button.new()
	silent_btn.name = "SilentButton"
	silent_btn.text = "Silent"
	silent_btn.custom_minimum_size = Vector2(200, 50)
	silent_box.add_child(silent_btn)

	var silent_desc = Label.new()
	silent_desc.name = "SilentDesc"
	silent_desc.text = "HP: 70 | Agility-focused"
	silent_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	silent_desc.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	silent_box.add_child(silent_desc)

	_set_owners(root, root)
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/character_select.tscn")
	print("Saved: res://scenes/character_select.tscn")
	quit(0)

func _set_owners(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		if c.scene_file_path.is_empty():
			_set_owners(c, owner)
