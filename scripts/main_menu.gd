extends Control
## res://scripts/main_menu.gd — Main menu with Test Battle and Card Creator options

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.04, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Try to load dungeon background
	var bg_path := "res://assets/img/dungeon_bg.png"
	if ResourceLoader.exists(bg_path):
		var bg_tex = TextureRect.new()
		bg_tex.texture = load(bg_path)
		bg_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_tex.modulate = Color(0.4, 0.4, 0.4, 1.0)
		bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg_tex)

	# Dark overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# Center container
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	# Game title
	var title = Label.new()
	title.text = "杀戮尖塔"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Slay the Spire"
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45, 0.8))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)

	# Test Battle button
	var battle_btn = _create_menu_button("测试战斗", Color(0.85, 0.2, 0.2))
	battle_btn.pressed.connect(_on_battle_pressed)
	vbox.add_child(battle_btn)

	# Card Creator button
	var creator_btn = _create_menu_button("卡牌制作器", Color(0.85, 0.7, 0.15))
	creator_btn.pressed.connect(_on_creator_pressed)
	vbox.add_child(creator_btn)

func _create_menu_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(360, 70)
	btn.add_theme_font_size_override("font_size", 32)
	btn.add_theme_color_override("font_color", Color.WHITE)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.35)
	style.border_color = color
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	btn.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(color.r, color.g, color.b, 0.55)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed_style = style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(color.r, color.g, color.b, 0.7)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	return btn

func _on_battle_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_creator_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/card_generator.tscn")
