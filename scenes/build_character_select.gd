extends SceneTree
## Scene builder — run: timeout 60 godot --headless --script scenes/build_character_select.gd

func _initialize() -> void:
	var root = Control.new()
	root.name = "CharacterSelect"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://scripts/character_select.gd"))

	# Background
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.1, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	# Center container
	var center = CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	center.add_child(vbox)

	# Title
	var title = Label.new()
	title.name = "Title"
	title.text = "Choose Your Character"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	var spacer = Control.new()
	spacer.name = "Spacer"
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)

	# Character buttons container
	var hbox = HBoxContainer.new()
	hbox.name = "Characters"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 80)
	vbox.add_child(hbox)

	# Ironclad button
	var ironclad_box = VBoxContainer.new()
	ironclad_box.name = "IroncladBox"
	hbox.add_child(ironclad_box)

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
	ironclad_box.add_child(ironclad_desc)

	# Silent button
	var silent_box = VBoxContainer.new()
	silent_box.name = "SilentBox"
	hbox.add_child(silent_box)

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
