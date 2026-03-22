extends SceneTree
## Full flow test: deck builder → select cards → battle

var _frame: int = 0
var _main: Node = null
var _builder: Control = null

func _initialize() -> void:
	var main_packed = load("res://scenes/main.tscn")
	_main = main_packed.instantiate()
	root.add_child(_main)

func _process(_delta: float) -> bool:
	_frame += 1

	# Frame 15: Deck builder should be visible, select some cards
	if _frame == 15:
		_builder = _find_child(_main, "DeckBuilder")
		if _builder:
			# Auto-select 10 cards: 4x Strike, 3x Defend, 2x Bash, 1x Cleave
			_add_cards("ic_strike", 4)
			_add_cards("ic_defend", 3)
			_add_cards("ic_bash", 2)
			_add_cards("ic_cleave", 1)

	# Frame 25: Confirm deck
	if _frame == 25:
		if _builder and _builder.has_method("_on_confirm"):
			_builder._on_confirm()

	# Frame 50: Battle should be running
	# Frame 80: Let battle settle
	if _frame == 80:
		quit(0)

	return false

func _add_cards(card_id: String, count: int) -> void:
	if _builder == null:
		return
	for i in range(count):
		_builder._on_plus(card_id)

func _find_child(node: Node, child_name: String) -> Node:
	for c in node.get_children():
		if c.name == child_name:
			return c
		var found = _find_child(c, child_name)
		if found:
			return found
	return null
