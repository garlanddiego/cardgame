extends SceneTree

var _frame: int = 0
var _main: Node = null
var _gm: Node = null

func _initialize() -> void:
	var main_packed = load("res://scenes/main.tscn")
	_main = main_packed.instantiate()
	root.add_child(_main)
	for child in root.get_children():
		if child.name == "GameManager":
			_gm = child
			break

func _process(_delta: float) -> bool:
	_frame += 1
	# Frame 10: Click Ironclad button (triggers character_chosen signal via button)
	if _frame == 10:
		var cs = _find_child(_main, "CharacterSelect")
		if cs:
			var btn = _find_child(cs, "IroncladButton") as Button
			if btn:
				btn.pressed.emit()
	# Frame 25: Deck builder should be visible
	if _frame == 40:
		quit(0)
	return false

func _find_child(node: Node, child_name: String) -> Node:
	for c in node.get_children():
		if c.name == child_name:
			return c
		var found = _find_child(c, child_name)
		if found:
			return found
	return null
