extends Area2D
## res://scripts/card.gd — Professional card class inspired by db0/godot-card-game-framework
## State-machine driven Area2D card with tween-based animations

signal card_clicked(card_node: Area2D)
signal card_focused(card_node: Area2D)
signal card_unfocused(card_node: Area2D)

enum CardState {
	IN_HAND,
	FOCUSED_IN_HAND,
	DRAGGED,
	DROPPING_TO_BOARD,
	ON_PLAY_BOARD,
	IN_PILE,
	MOVING_TO_CONTAINER
}

const CARD_SIZE := Vector2(220, 310)

var card_data: Dictionary = {}
var card_state: int = CardState.IN_HAND
var is_hovered: bool = false
var is_selected: bool = false
var base_z_index: int = 0
var _current_tween: Tween = null

# Child node references (populated in _ready or after build)
var collision_shape: CollisionShape2D = null
var card_visual: Control = null
var frame_texture: TextureRect = null
var card_art: TextureRect = null
var cost_label: Label = null
var name_label: Label = null
var type_label: Label = null
var desc_label: RichTextLabel = null

func _ready() -> void:
	# If no children exist yet, build them (for runtime instantiation)
	if get_child_count() == 0:
		_build_card_nodes()
	else:
		_find_child_refs()

	# Connect Area2D mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

	# Set up collision
	input_pickable = true

	if not card_data.is_empty():
		_apply_card_data()

func _build_card_nodes() -> void:
	# CollisionShape2D
	collision_shape = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	shape.size = CARD_SIZE
	collision_shape.shape = shape
	collision_shape.position = Vector2(CARD_SIZE.x / 2.0, CARD_SIZE.y / 2.0)
	add_child(collision_shape)

	# CardVisual (Control) — all visual elements are children of this
	card_visual = Control.new()
	card_visual.name = "CardVisual"
	card_visual.size = CARD_SIZE
	card_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card_visual)

	# Dark card background (visible if frame texture is missing)
	var card_bg = ColorRect.new()
	card_bg.name = "CardBackground"
	card_bg.position = Vector2(0, 0)
	card_bg.size = CARD_SIZE
	card_bg.color = Color(0.08, 0.06, 0.04, 0.95)
	card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_visual.add_child(card_bg)

	# Frame texture (card background/frame)
	frame_texture = TextureRect.new()
	frame_texture.name = "FrameTexture"
	frame_texture.size = CARD_SIZE
	frame_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_texture.stretch_mode = TextureRect.STRETCH_SCALE
	frame_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_visual.add_child(frame_texture)

	# Card art (positioned in the art window area of the frame)
	card_art = TextureRect.new()
	card_art.name = "CardArt"
	card_art.position = Vector2(22, 42)
	card_art.size = Vector2(176, 122)
	card_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	card_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_visual.add_child(card_art)

	# Cost label (top-left circle area)
	cost_label = Label.new()
	cost_label.name = "CostLabel"
	cost_label.position = Vector2(7, 5)
	cost_label.size = Vector2(36, 36)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 24)
	cost_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_visual.add_child(cost_label)

	# Name label (card name banner area)
	name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.position = Vector2(12, 168)
	name_label.size = Vector2(196, 26)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_visual.add_child(name_label)

	# Type label (small type text below name)
	type_label = Label.new()
	type_label.name = "TypeLabel"
	type_label.position = Vector2(12, 194)
	type_label.size = Vector2(196, 18)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_visual.add_child(type_label)

	# Description label (card description area)
	desc_label = RichTextLabel.new()
	desc_label.name = "DescLabel"
	desc_label.position = Vector2(17, 216)
	desc_label.size = Vector2(186, 84)
	desc_label.bbcode_enabled = true
	desc_label.fit_content = false
	desc_label.scroll_active = false
	desc_label.add_theme_font_size_override("normal_font_size", 12)
	desc_label.add_theme_color_override("default_color", Color(0.85, 0.82, 0.75))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_visual.add_child(desc_label)

func _find_child_refs() -> void:
	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	card_visual = get_node_or_null("CardVisual") as Control
	if card_visual:
		frame_texture = card_visual.get_node_or_null("FrameTexture") as TextureRect
		card_art = card_visual.get_node_or_null("CardArt") as TextureRect
		cost_label = card_visual.get_node_or_null("CostLabel") as Label
		name_label = card_visual.get_node_or_null("NameLabel") as Label
		type_label = card_visual.get_node_or_null("TypeLabel") as Label
		desc_label = card_visual.get_node_or_null("DescLabel") as RichTextLabel

func setup(data: Dictionary) -> void:
	card_data = data
	if is_inside_tree():
		_apply_card_data()

func set_card_data(data: Dictionary) -> void:
	setup(data)

func _apply_card_data() -> void:
	if card_data.is_empty():
		return
	var loc = _get_loc()

	# Cost
	if cost_label:
		var cost_val: int = card_data.get("cost", 0)
		if cost_val == -1:
			cost_label.text = "X"
		elif cost_val < -1:
			cost_label.text = ""
		else:
			cost_label.text = str(cost_val)

	# Name
	if name_label:
		if loc:
			name_label.text = loc.card_name(card_data)
		else:
			name_label.text = card_data.get("name", "Card")

	# Description
	if desc_label:
		if loc:
			desc_label.text = loc.card_desc(card_data)
		else:
			desc_label.text = card_data.get("description", "")

	# Type
	if type_label:
		var type_idx: int = card_data.get("type", 0)
		if loc:
			type_label.text = loc.type_name(type_idx)
		else:
			var gm_types = ["Attack", "Skill", "Power", "Status"]
			if type_idx >= 0 and type_idx < gm_types.size():
				type_label.text = gm_types[type_idx]

	# Card art
	if card_art:
		var art_path: String = card_data.get("art", "")
		if art_path != "":
			var tex = load(art_path)
			if tex:
				card_art.texture = tex

	# Card frame based on type
	_apply_frame_texture()

func _apply_frame_texture() -> void:
	if frame_texture == null:
		return
	var card_type: int = card_data.get("type", 0)
	var frame_path: String
	match card_type:
		0:  # Attack
			frame_path = "res://assets/img/card_frame_attack_clean.png"
		1:  # Skill
			frame_path = "res://assets/img/card_frame_skill.png"
		2:  # Power
			frame_path = "res://assets/img/card_frame_power_clean.png"
		_:  # Status / other
			frame_path = "res://assets/img/card_frame_skill.png"
	var tex = load(frame_path)
	if tex:
		frame_texture.texture = tex

func set_selected(selected: bool) -> void:
	is_selected = selected
	if card_visual:
		if selected:
			card_visual.modulate = Color(1.2, 1.1, 0.8)
		else:
			card_visual.modulate = Color.WHITE

func move_to(target_pos: Vector2, target_rot: float, target_scale: Vector2, duration: float = 0.15) -> void:
	# Cancel any in-progress tween
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	_current_tween.set_ease(Tween.EASE_OUT)
	_current_tween.set_trans(Tween.TRANS_CUBIC)
	_current_tween.tween_property(self, "position", target_pos, duration)
	_current_tween.tween_property(self, "rotation_degrees", target_rot, duration)
	_current_tween.tween_property(self, "scale", target_scale, duration)

func set_state(new_state: int) -> void:
	card_state = new_state

# ---- Signal handlers ----

func _on_mouse_entered() -> void:
	is_hovered = true
	card_focused.emit(self)

func _on_mouse_exited() -> void:
	is_hovered = false
	card_unfocused.emit(self)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(self)

func _get_loc() -> Node:
	if not is_inside_tree():
		return null
	for child in get_tree().root.get_children():
		if child.name == "Loc":
			return child
	return null
