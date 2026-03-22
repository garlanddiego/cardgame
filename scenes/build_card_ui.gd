extends SceneTree
## Scene builder — run: timeout 60 godot --headless --script scenes/build_card_ui.gd

func _initialize() -> void:
	var root = Control.new()
	root.name = "CardUI"
	root.custom_minimum_size = Vector2(120, 180)
	root.set_script(load("res://scripts/card_ui.gd"))

	# Card background panel
	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	panel.add_child(vbox)

	# Cost label
	var cost_label = Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "1"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(cost_label)

	# Card art placeholder
	var art = TextureRect.new()
	art.name = "CardArt"
	art.custom_minimum_size = Vector2(100, 80)
	art.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(art)

	# Card name
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = "Card Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Description
	var desc_label = RichTextLabel.new()
	desc_label.name = "DescLabel"
	desc_label.custom_minimum_size = Vector2(0, 50)
	desc_label.bbcode_enabled = true
	desc_label.fit_content = true
	desc_label.scroll_active = false
	vbox.add_child(desc_label)

	# Type label
	var type_label = Label.new()
	type_label.name = "TypeLabel"
	type_label.text = "Attack"
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_label)

	_set_owners(root, root)
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/card_ui.tscn")
	print("Saved: res://scenes/card_ui.tscn")
	quit(0)

func _set_owners(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		if c.scene_file_path.is_empty():
			_set_owners(c, owner)
