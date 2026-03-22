extends SceneTree
## Scene builder — run: timeout 60 godot --headless --script scenes/build_deck_builder.gd

func _initialize() -> void:
	print("Generating: deck_builder.tscn")
	var root = Control.new()
	root.name = "DeckBuilder"
	root.position = Vector2(0, 0)
	root.size = Vector2(1920, 1080)
	root.set_script(load("res://scripts/deck_builder.gd"))

	# Background
	var bg = TextureRect.new()
	bg.name = "Background"
	bg.texture = load("res://assets/img/dungeon_bg.png")
	bg.position = Vector2(0, 0)
	bg.size = Vector2(1920, 1080)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(bg)

	# Dark overlay
	var dark_overlay = ColorRect.new()
	dark_overlay.name = "DarkOverlay"
	dark_overlay.color = Color(0.0, 0.0, 0.05, 0.65)
	dark_overlay.position = Vector2(0, 0)
	dark_overlay.size = Vector2(1920, 1080)
	dark_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dark_overlay)

	# Title bar at top
	var title_bar = HBoxContainer.new()
	title_bar.name = "TitleBar"
	title_bar.position = Vector2(0, 0)
	title_bar.size = Vector2(1920, 70)
	title_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(title_bar)

	var title = Label.new()
	title.name = "Title"
	title.text = "Build Your Deck"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)

	# Language selector (top-right)
	var lang_box = HBoxContainer.new()
	lang_box.name = "LangSelector"
	lang_box.add_theme_constant_override("separation", 6)
	title_bar.add_child(lang_box)

	var lang_zh_btn = Button.new()
	lang_zh_btn.name = "LangZhButton"
	lang_zh_btn.text = "中文"
	lang_zh_btn.custom_minimum_size = Vector2(80, 40)
	var lang_btn_style = StyleBoxFlat.new()
	lang_btn_style.bg_color = Color(0.3, 0.3, 0.4, 0.8)
	lang_btn_style.border_color = Color(0.6, 0.6, 0.8, 0.7)
	lang_btn_style.border_width_left = 1
	lang_btn_style.border_width_right = 1
	lang_btn_style.border_width_top = 1
	lang_btn_style.border_width_bottom = 1
	lang_btn_style.corner_radius_top_left = 6
	lang_btn_style.corner_radius_top_right = 6
	lang_btn_style.corner_radius_bottom_left = 6
	lang_btn_style.corner_radius_bottom_right = 6
	lang_zh_btn.add_theme_stylebox_override("normal", lang_btn_style)
	var lang_btn_hover = lang_btn_style.duplicate() as StyleBoxFlat
	lang_btn_hover.bg_color = Color(0.4, 0.4, 0.55, 0.9)
	lang_zh_btn.add_theme_stylebox_override("hover", lang_btn_hover)
	lang_zh_btn.add_theme_font_size_override("font_size", 18)
	lang_zh_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	lang_box.add_child(lang_zh_btn)

	var lang_en_btn = Button.new()
	lang_en_btn.name = "LangEnButton"
	lang_en_btn.text = "English"
	lang_en_btn.custom_minimum_size = Vector2(80, 40)
	var lang_en_style = lang_btn_style.duplicate() as StyleBoxFlat
	lang_en_btn.add_theme_stylebox_override("normal", lang_en_style)
	var lang_en_hover = lang_btn_hover.duplicate() as StyleBoxFlat
	lang_en_btn.add_theme_stylebox_override("hover", lang_en_hover)
	lang_en_btn.add_theme_font_size_override("font_size", 18)
	lang_en_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	lang_box.add_child(lang_en_btn)

	# Scrollable card grid area
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.position = Vector2(40, 80)
	scroll.size = Vector2(1840, 890)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)

	var grid = GridContainer.new()
	grid.name = "CardGrid"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	# Bottom bar
	var bottom_bar = HBoxContainer.new()
	bottom_bar.name = "BottomBar"
	bottom_bar.position = Vector2(0, 985)
	bottom_bar.size = Vector2(1920, 80)
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_bar.add_theme_constant_override("separation", 40)
	root.add_child(bottom_bar)

	# Total label
	var total_label = Label.new()
	total_label.name = "TotalLabel"
	total_label.text = "Selected: 0 / 10"
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_font_size_override("font_size", 32)
	total_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	bottom_bar.add_child(total_label)

	# Confirm button
	var confirm_btn = Button.new()
	confirm_btn.name = "ConfirmButton"
	confirm_btn.text = "Confirm Deck"
	confirm_btn.custom_minimum_size = Vector2(220, 55)
	confirm_btn.disabled = true
	# Style the confirm button
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.5, 0.15, 0.8)
	btn_style.border_color = Color(0.3, 0.8, 0.3, 0.9)
	btn_style.border_width_left = 2
	btn_style.border_width_right = 2
	btn_style.border_width_top = 2
	btn_style.border_width_bottom = 2
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	confirm_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover = btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.2, 0.6, 0.2, 0.9)
	confirm_btn.add_theme_stylebox_override("hover", btn_hover)
	var btn_disabled = btn_style.duplicate() as StyleBoxFlat
	btn_disabled.bg_color = Color(0.2, 0.2, 0.2, 0.6)
	btn_disabled.border_color = Color(0.4, 0.4, 0.4, 0.5)
	confirm_btn.add_theme_stylebox_override("disabled", btn_disabled)
	confirm_btn.add_theme_font_size_override("font_size", 24)
	bottom_bar.add_child(confirm_btn)

	_set_owners(root, root)
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
