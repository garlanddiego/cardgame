extends SceneTree
## Full flow test: deck builder (select → confirm) → battle

var _frame: int = 0
var _main: Node = null
var _builder: Node = null

func _initialize() -> void:
	var main_packed = load("res://scenes/main.tscn")
	_main = main_packed.instantiate()
	root.add_child(_main)

func _process(_delta: float) -> bool:
	_frame += 1

	# Frame 10: Find deck builder
	if _frame == 10:
		_builder = _find_child(_main, "DeckBuilder")

	# Frame 15: Programmatically select 10 cards
	if _frame == 15:
		if _builder:
			var gm = _get_gm()
			if gm:
				var count: int = 0
				for card_id in gm.card_database:
					var card = gm.card_database[card_id]
					if card["character"] == "ironclad" and card["type"] != 3 and count < 10:
						_builder.selected_card_ids.append(card_id)
						count += 1
				_builder._update_select_ui()

	# Frame 25: Go to confirm page
	if _frame == 25:
		if _builder:
			_builder._on_next()

	# Frame 40: Confirm the deck
	if _frame == 40:
		if _builder:
			_builder._on_confirm()

	# Frame 70: Battle running
	if _frame == 80:
		quit(0)

	return false

func _get_gm() -> Node:
	for child in root.get_children():
		if child.name == "GameManager":
			return child
	return null

func _find_child(node: Node, child_name: String) -> Node:
	for c in node.get_children():
		if c.name == child_name:
			return c
		var found = _find_child(c, child_name)
		if found:
			return found
	return null
