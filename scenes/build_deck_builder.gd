extends SceneTree
## Scene builder — run: timeout 60 godot --headless --script scenes/build_deck_builder.gd

func _initialize() -> void:
	print("Generating: deck_builder.tscn")
	var root = Control.new()
	root.name = "DeckBuilder"
	root.anchor_left = 0.0
	root.anchor_top = 0.0
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 0
	root.offset_top = 0
	root.offset_right = 0
	root.offset_bottom = 0
	root.set_script(load("res://scripts/deck_builder.gd"))

	# Layout is built entirely in _ready() by the script.
	# The .tscn only provides the root Control node.

	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/deck_builder.tscn")
	print("Saved: res://scenes/deck_builder.tscn")
	quit(0)

func _set_owners(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		if c.scene_file_path.is_empty():
			_set_owners(c, owner)
