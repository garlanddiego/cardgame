extends Control
## res://scripts/card_ui.gd — Single card rendering and interaction

signal card_clicked(card_node: Control)
signal card_hovered(card_node: Control)
signal card_unhovered(card_node: Control)

var card_data: Dictionary = {}
var is_hovered: bool = false
var is_selected: bool = false
var original_scale: Vector2 = Vector2.ONE
var base_z_index: int = 0

@onready var panel: PanelContainer = $Panel
@onready var cost_label: Label = $Panel/VBox/CostLabel
@onready var card_art: TextureRect = $Panel/VBox/CardArt
@onready var name_label: Label = $Panel/VBox/NameLabel
@onready var desc_label: RichTextLabel = $Panel/VBox/DescLabel
@onready var type_label: Label = $Panel/VBox/TypeLabel

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	mouse_filter = Control.MOUSE_FILTER_STOP
	original_scale = scale
	if not card_data.is_empty():
		_apply_card_data()

func setup(data: Dictionary) -> void:
	card_data = data
	if is_inside_tree():
		_apply_card_data()

func _apply_card_data() -> void:
	if card_data.is_empty():
		return
	var loc = _get_loc()
	# Cost
	if cost_label:
		cost_label.text = str(card_data.get("cost", 0))
		cost_label.add_theme_font_size_override("font_size", 18)
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	# Name
	if name_label:
		if loc:
			name_label.text = loc.card_name(card_data)
		else:
			name_label.text = card_data.get("name", "Card")
		name_label.add_theme_font_size_override("font_size", 12)
	# Description
	if desc_label:
		if loc:
			desc_label.text = loc.card_desc(card_data)
		else:
			desc_label.text = card_data.get("description", "")
		desc_label.add_theme_font_size_override("normal_font_size", 10)
	# Type
	if type_label:
		var type_idx: int = card_data.get("type", 0)
		if loc:
			type_label.text = loc.type_name(type_idx)
		else:
			var gm_types = ["Attack", "Skill", "Power"]
			if type_idx >= 0 and type_idx < gm_types.size():
				type_label.text = gm_types[type_idx]
		type_label.add_theme_font_size_override("font_size", 10)
	# Card art
	if card_art:
		var art_path: String = card_data.get("art", "")
		if art_path != "":
			var tex = load(art_path)
			if tex:
				card_art.texture = tex
	# Card border color based on type
	_apply_card_style()

func _apply_card_style() -> void:
	if panel == null:
		return
	var style = StyleBoxFlat.new()
	var card_type: int = card_data.get("type", 0)
	var card_char: String = card_data.get("character", "")
	if card_char == "bloodfiend":
		# Bloodfiend: red-black theme for all card types
		match card_type:
			0:  # Attack
				style.bg_color = Color(0.18, 0.04, 0.04, 0.94)
				style.border_color = Color(0.7, 0.1, 0.1)
			1:  # Skill
				style.bg_color = Color(0.12, 0.04, 0.06, 0.94)
				style.border_color = Color(0.6, 0.1, 0.15)
			2:  # Power
				style.bg_color = Color(0.15, 0.03, 0.08, 0.94)
				style.border_color = Color(0.65, 0.08, 0.2)
	else:
		match card_type:
			0:  # Attack
				style.bg_color = Color(0.25, 0.08, 0.08, 0.92)
				style.border_color = Color(0.8, 0.2, 0.2)
			1:  # Skill
				style.bg_color = Color(0.08, 0.2, 0.08, 0.92)
				style.border_color = Color(0.2, 0.7, 0.3)
			2:  # Power
				style.bg_color = Color(0.12, 0.1, 0.22, 0.92)
				style.border_color = Color(0.4, 0.4, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

func set_selected(selected: bool) -> void:
	is_selected = selected
	if panel == null:
		return
	if selected:
		var style = panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		style.border_color = Color(1.0, 0.9, 0.3)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		panel.add_theme_stylebox_override("panel", style)
	else:
		_apply_card_style()

func _on_mouse_entered() -> void:
	is_hovered = true
	card_hovered.emit(self)

func _on_mouse_exited() -> void:
	is_hovered = false
	card_unhovered.emit(self)

func _get_loc() -> Node:
	for child in get_tree().root.get_children():
		if child.name == "Loc":
			return child
	return null

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(self)
			accept_event()
