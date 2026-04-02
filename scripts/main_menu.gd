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

	# Standard Mode button (primary — STS tower climbing)
	var standard_btn = _create_menu_button("标准模式", Color(0.9, 0.6, 0.1))
	standard_btn.pressed.connect(_on_standard_mode_pressed)
	vbox.add_child(standard_btn)

	# Test Battle button
	var battle_btn = _create_menu_button("套牌战斗", Color(0.85, 0.2, 0.2))
	battle_btn.pressed.connect(_on_battle_pressed)
	vbox.add_child(battle_btn)

	# Draft Battle button
	var draft_btn = _create_menu_button("选牌战斗", Color(0.2, 0.7, 0.3))
	draft_btn.pressed.connect(_on_draft_battle_pressed)
	vbox.add_child(draft_btn)

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

func _on_standard_mode_pressed() -> void:
	_start_standard_run("ironclad", "silent")

func _show_hero_select_popup() -> void:
	# Dark overlay
	var overlay = ColorRect.new()
	overlay.name = "HeroSelectOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.1, 0.08, 0.95)
	panel_style.border_color = Color(0.6, 0.5, 0.3)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 40
	panel_style.content_margin_right = 40
	panel_style.content_margin_top = 30
	panel_style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "标准模式 — 双英雄选择"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = "选择两位英雄开始爬塔（10层 → Boss）"
	desc.add_theme_font_size_override("font_size", 20)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)

	# Hero 1 selection
	var h1_label = Label.new()
	h1_label.text = "英雄 1:"
	h1_label.add_theme_font_size_override("font_size", 24)
	h1_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	vbox.add_child(h1_label)

	var h1_row = HBoxContainer.new()
	h1_row.add_theme_constant_override("separation", 20)
	h1_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(h1_row)

	var h1_ic = _create_menu_button("铁甲战士", Color(0.8, 0.2, 0.2))
	h1_ic.custom_minimum_size = Vector2(200, 50)
	var h1_si = _create_menu_button("沉默猎手", Color(0.2, 0.7, 0.3))
	h1_si.custom_minimum_size = Vector2(200, 50)
	h1_row.add_child(h1_ic)
	h1_row.add_child(h1_si)

	# Hero 2 selection
	var h2_label = Label.new()
	h2_label.text = "英雄 2:"
	h2_label.add_theme_font_size_override("font_size", 24)
	h2_label.add_theme_color_override("font_color", Color(0.3, 0.7, 0.3))
	vbox.add_child(h2_label)

	var h2_row = HBoxContainer.new()
	h2_row.add_theme_constant_override("separation", 20)
	h2_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(h2_row)

	var h2_ic = _create_menu_button("铁甲战士", Color(0.8, 0.2, 0.2))
	h2_ic.custom_minimum_size = Vector2(200, 50)
	var h2_si = _create_menu_button("沉默猎手", Color(0.2, 0.7, 0.3))
	h2_si.custom_minimum_size = Vector2(200, 50)
	h2_row.add_child(h2_ic)
	h2_row.add_child(h2_si)

	# Selection state
	var selected = {"h1": "ironclad", "h2": "silent"}

	# Highlight default
	h1_ic.modulate = Color(1.5, 1.5, 1.5)
	h2_si.modulate = Color(1.5, 1.5, 1.5)

	h1_ic.pressed.connect(func():
		selected["h1"] = "ironclad"
		h1_ic.modulate = Color(1.5, 1.5, 1.5)
		h1_si.modulate = Color.WHITE
	)
	h1_si.pressed.connect(func():
		selected["h1"] = "silent"
		h1_si.modulate = Color(1.5, 1.5, 1.5)
		h1_ic.modulate = Color.WHITE
	)
	h2_ic.pressed.connect(func():
		selected["h2"] = "ironclad"
		h2_ic.modulate = Color(1.5, 1.5, 1.5)
		h2_si.modulate = Color.WHITE
	)
	h2_si.pressed.connect(func():
		selected["h2"] = "silent"
		h2_si.modulate = Color(1.5, 1.5, 1.5)
		h2_ic.modulate = Color.WHITE
	)

	# Start button
	var start_btn = _create_menu_button("开始爬塔", Color(0.9, 0.6, 0.1))
	start_btn.pressed.connect(func():
		overlay.queue_free()
		_start_standard_run(selected["h1"], selected["h2"])
	)
	vbox.add_child(start_btn)

	# Cancel
	var cancel_btn = _create_menu_button("取消", Color(0.4, 0.4, 0.4))
	cancel_btn.custom_minimum_size = Vector2(200, 50)
	cancel_btn.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(cancel_btn)

func _start_standard_run(h1: String, h2: String) -> void:
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		rm.start_run(h1, h2)
	var gm_node = get_node_or_null("/root/GameManager")
	if gm_node:
		gm_node.select_character(h1)
	get_tree().change_scene_to_file("res://scenes/standard_mode.tscn")

func _on_battle_pressed() -> void:
	# Skip character selection — go directly to deck builder with Silent
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.select_character("silent")
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_draft_battle_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/draft_battle.tscn")

func _on_creator_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/card_generator.tscn")
