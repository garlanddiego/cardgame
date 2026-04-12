extends SceneTree
## Scene builder — run: timeout 60 godot --headless --script scenes/build_character_select.gd

func _initialize() -> void:
	print("Generating: character_select.tscn")
	var root = Control.new()
	root.name = "CharacterSelect"
	root.anchor_left = 0.0
	root.anchor_top = 0.0
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.set_script(load("res://scripts/character_select.gd"))

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
