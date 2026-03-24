extends SceneTree
## Scene builder — run: timeout 60 godot --headless --script scenes/build_deck_builder.gd

func _initialize() -> void:
	print("Generating: deck_builder.tscn")
	var root = Control.new()
	root.name = "DeckBuilder"
	root.position = Vector2(0, 0)
	root.size = Vector2(1920, 1080)
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
