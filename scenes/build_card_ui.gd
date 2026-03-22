extends SceneTree
## Scene builder — run: timeout 60 godot --headless --script scenes/build_card_ui.gd
## Builds the Area2D-based card scene used in battle

func _initialize() -> void:
	var root = Area2D.new()
	root.name = "Card"
	root.set_script(load("res://scripts/card.gd"))
	root.input_pickable = true

	# CollisionShape2D for Area2D mouse detection
	var coll = CollisionShape2D.new()
	coll.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(180, 260)
	coll.shape = shape
	coll.position = Vector2(90, 130)  # Center of card
	root.add_child(coll)

	# CardVisual — all visual elements
	var card_visual = Control.new()
	card_visual.name = "CardVisual"
	card_visual.size = Vector2(180, 260)
	card_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card_visual)

	# Frame texture (card background/border image)
	var frame_tex = TextureRect.new()
	frame_tex.name = "FrameTexture"
	frame_tex.size = Vector2(180, 260)
	frame_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_tex.stretch_mode = TextureRect.STRETCH_SCALE
	frame_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_visual.add_child(frame_tex)

	# Card art (positioned in the art window of the frame)
	var art = TextureRect.new()
	art.name = "CardArt"
	art.position = Vector2(18, 34)
	art.size = Vector2(144, 100)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_visual.add_child(art)

	# Cost label (top-left)
	var cost_label = Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "1"
	cost_label.position = Vector2(6, 4)
	cost_label.size = Vector2(30, 30)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_visual.add_child(cost_label)

	# Card name
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = "Card Name"
	name_label.position = Vector2(10, 138)
	name_label.size = Vector2(160, 22)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_visual.add_child(name_label)

	# Type label
	var type_label = Label.new()
	type_label.name = "TypeLabel"
	type_label.text = "Attack"
	type_label.position = Vector2(10, 160)
	type_label.size = Vector2(160, 16)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_visual.add_child(type_label)

	# Description
	var desc_label = RichTextLabel.new()
	desc_label.name = "DescLabel"
	desc_label.position = Vector2(14, 178)
	desc_label.size = Vector2(152, 72)
	desc_label.bbcode_enabled = true
	desc_label.fit_content = false
	desc_label.scroll_active = false
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_visual.add_child(desc_label)

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
