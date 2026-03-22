extends Control
## res://scripts/character_select.gd — Character selection screen

signal character_chosen(character_id: String)

func _ready() -> void:
	# Load character art - find nodes through the panel containers
	var ironclad_art = _find_child_by_name(self, "IroncladArt") as TextureRect
	if ironclad_art:
		var tex = load("res://assets/img/ironclad.png")
		if tex:
			ironclad_art.texture = tex
	var silent_art = _find_child_by_name(self, "SilentArt") as TextureRect
	if silent_art:
		var tex = load("res://assets/img/silent.png")
		if tex:
			silent_art.texture = tex
	# Connect buttons
	var ironclad_btn = _find_child_by_name(self, "IroncladButton") as Button
	if ironclad_btn:
		ironclad_btn.pressed.connect(_on_ironclad_pressed)
		_style_button(ironclad_btn, Color(0.8, 0.2, 0.2))
	var silent_btn = _find_child_by_name(self, "SilentButton") as Button
	if silent_btn:
		silent_btn.pressed.connect(_on_silent_pressed)
		_style_button(silent_btn, Color(0.2, 0.7, 0.3))

func _find_child_by_name(node: Node, child_name: String) -> Node:
	for child in node.get_children():
		if child.name == child_name:
			return child
		var found = _find_child_by_name(child, child_name)
		if found:
			return found
	return null

func _style_button(btn: Button, color: Color) -> void:
	if btn == null:
		return
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.3)
	style.border_color = color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", style)
	var hover_style = style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(color.r, color.g, color.b, 0.5)
	btn.add_theme_stylebox_override("hover", hover_style)

func _on_ironclad_pressed() -> void:
	character_chosen.emit("ironclad")

func _on_silent_pressed() -> void:
	character_chosen.emit("silent")
