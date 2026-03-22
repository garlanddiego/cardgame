extends SceneTree

var frame_count: int = 0
var main_scene: Node = null

func _initialize() -> void:
	var main_packed = load("res://scenes/main.tscn")
	main_scene = main_packed.instantiate()
	root.add_child(main_scene)

func _process(_delta: float) -> bool:
	frame_count += 1
	if frame_count == 5:
		# Click Ironclad button
		var cs = _find_child(main_scene, "CharacterSelect")
		if cs:
			var btn = _find_child(cs, "IroncladButton") as Button
			if btn:
				btn.emit_signal("pressed")
	if frame_count == 15:
		_capture("screenshots/test_ui/char_select.png")
	if frame_count == 30:
		_capture("screenshots/test_ui/battle_overlapping_cards.png")
	if frame_count == 35:
		quit(0)
	return false

func _capture(path: String) -> void:
	var dir = path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var img = root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("Captured: " + path)

func _find_child(node: Node, child_name: String) -> Node:
	for c in node.get_children():
		if c.name == child_name:
			return c
		var found = _find_child(c, child_name)
		if found:
			return found
	return null
