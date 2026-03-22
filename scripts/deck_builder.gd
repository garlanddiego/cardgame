extends Control
## res://scripts/deck_builder.gd — Deck building screen: pick cards before battle

signal deck_confirmed(deck: Array)

const MAX_DECK_SIZE: int = 10
const MAX_COPIES: int = 4

var character_id: String = ""
var selected_cards: Dictionary = {}  # card_id -> count
var upgraded_cards: Dictionary = {}  # card_id -> bool (whether to use upgraded version)
var total_selected: int = 0

# Node refs populated in _ready
var grid: GridContainer = null
var total_label: Label = null
var confirm_btn: Button = null
var count_labels: Dictionary = {}  # card_id -> Label node
var upgrade_btns: Dictionary = {}  # card_id -> Button node
var card_name_labels: Dictionary = {}  # card_id -> Label node
var card_desc_labels: Dictionary = {}  # card_id -> RichTextLabel node
var card_cost_labels: Dictionary = {}  # card_id -> Label node
var card_type_badges: Dictionary = {}  # card_id -> Label node
var all_card_data: Dictionary = {}  # card_id -> card dict (for refresh)

func _ready() -> void:
	_find_nodes()
	if confirm_btn:
		confirm_btn.pressed.connect(_on_confirm)
		confirm_btn.disabled = true
	_connect_language_buttons()
	_apply_localized_ui()

func _find_nodes() -> void:
	grid = _find_child_by_name(self, "CardGrid") as GridContainer
	total_label = _find_child_by_name(self, "TotalLabel") as Label
	confirm_btn = _find_child_by_name(self, "ConfirmButton") as Button

func setup(char_id: String) -> void:
	character_id = char_id
	_populate_grid()
	_update_total()

func _populate_grid() -> void:
	if grid == null:
		return
	var gm = _get_game_manager()
	if gm == null:
		return

	# Collect cards for this character, excluding status cards (type == 3)
	var char_cards: Array = []
	for card_id in gm.card_database:
		var card = gm.card_database[card_id]
		if card["character"] == character_id and card["type"] != 3:
			char_cards.append(card)

	# Sort by type then name
	char_cards.sort_custom(func(a, b):
		if a["type"] != b["type"]:
			return a["type"] < b["type"]
		return a["name"] < b["name"]
	)

	for card in char_cards:
		var entry = _create_card_entry(card)
		grid.add_child(entry)

func _create_card_entry(card: Dictionary) -> Control:
	var card_root = Control.new()
	card_root.custom_minimum_size = Vector2(200, 300)
	card_root.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow touch through to children

	# Determine frame texture path by card type
	var frame_path: String
	match card["type"]:
		0: frame_path = "res://assets/img/card_frame_attack_clean.png"
		1: frame_path = "res://assets/img/card_frame_skill.png"
		2: frame_path = "res://assets/img/card_frame_power_clean.png"
		_: frame_path = "res://assets/img/card_frame_attack_clean.png"

	# Card frame texture — fills entire card as background
	var frame_tex = TextureRect.new()
	frame_tex.name = "FrameTexture"
	if ResourceLoader.exists(frame_path):
		frame_tex.texture = load(frame_path)
	frame_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_tex.stretch_mode = TextureRect.STRETCH_SCALE
	frame_tex.position = Vector2(0, 0)
	frame_tex.size = Vector2(200, 280)
	frame_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(frame_tex)

	# Card art — top 45% area, edge-to-edge within 15px margin
	var art_rect = TextureRect.new()
	art_rect.position = Vector2(15, 15)
	art_rect.size = Vector2(170, 120)
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_SCALE
	if card.has("art") and ResourceLoader.exists(card["art"]):
		art_rect.texture = load(card["art"])
	art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(art_rect)

	# Cost circle — top-left overlay on art
	var cost_label = Label.new()
	var cost_val = card.get("cost", 0)
	cost_label.text = "X" if cost_val == -1 else str(cost_val)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.position = Vector2(10, 5)
	cost_label.size = Vector2(28, 28)
	cost_label.add_theme_font_size_override("font_size", 14)
	cost_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	var cost_style = StyleBoxFlat.new()
	cost_style.bg_color = Color(0.6, 0.4, 0.1, 0.9)
	cost_style.corner_radius_top_left = 14
	cost_style.corner_radius_top_right = 14
	cost_style.corner_radius_bottom_left = 14
	cost_style.corner_radius_bottom_right = 14
	cost_style.content_margin_left = 2
	cost_style.content_margin_right = 2
	cost_style.content_margin_top = 1
	cost_style.content_margin_bottom = 1
	cost_label.add_theme_stylebox_override("normal", cost_style)
	card_root.add_child(cost_label)

	# Card name banner — centered at ~45% height with dark background
	var name_label = Label.new()
	var loc = _get_loc()
	if loc:
		name_label.text = loc.card_name(card)
	else:
		name_label.text = card["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.position = Vector2(0, 140)
	name_label.size = Vector2(200, 25)
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	name_label.clip_text = true
	var name_style = StyleBoxFlat.new()
	name_style.bg_color = Color(0.05, 0.04, 0.03, 0.85)
	name_label.add_theme_stylebox_override("normal", name_style)
	card_root.add_child(name_label)

	# Type text — tiny text below name
	var type_badge = Label.new()
	type_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	type_badge.position = Vector2(0, 165)
	type_badge.size = Vector2(200, 15)
	type_badge.add_theme_font_size_override("font_size", 10)
	type_badge.add_theme_color_override("font_color", Color(0.65, 0.6, 0.5, 0.8))
	var loc_badge = _get_loc()
	if loc_badge:
		type_badge.text = loc_badge.type_name(card["type"])
	else:
		var badge_type_names = ["Attack", "Skill", "Power", "Status"]
		type_badge.text = badge_type_names[card["type"]]
	card_root.add_child(type_badge)

	# Description — bottom 35%, white on dark
	var desc_label = RichTextLabel.new()
	var loc3 = _get_loc()
	if loc3:
		desc_label.text = loc3.card_desc(card)
	else:
		desc_label.text = card["description"]
	desc_label.position = Vector2(8, 180)
	desc_label.size = Vector2(184, 60)
	desc_label.scroll_active = false
	desc_label.bbcode_enabled = false
	desc_label.fit_content = false
	desc_label.add_theme_font_size_override("normal_font_size", 11)
	desc_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(desc_label)

	# Controls — mobile-friendly touch targets (min 44px height)
	var controls_vbox = VBoxContainer.new()
	controls_vbox.position = Vector2(4, 230)
	controls_vbox.size = Vector2(192, 50)
	controls_vbox.add_theme_constant_override("separation", 2)
	card_root.add_child(controls_vbox)

	# +/- and upgrade in one row for compactness
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 4)
	controls_vbox.add_child(hbox)

	var minus_btn = Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(40, 36)
	_style_small_button(minus_btn, Color(0.7, 0.3, 0.3))
	minus_btn.add_theme_font_size_override("font_size", 18)
	hbox.add_child(minus_btn)

	var count_lbl = Label.new()
	count_lbl.text = "0"
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.custom_minimum_size = Vector2(24, 0)
	count_lbl.add_theme_font_size_override("font_size", 16)
	count_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	hbox.add_child(count_lbl)

	var plus_btn = Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(40, 36)
	_style_small_button(plus_btn, Color(0.3, 0.7, 0.3))
	plus_btn.add_theme_font_size_override("font_size", 18)
	hbox.add_child(plus_btn)

	# Upgrade toggle button
	var upgrade_btn = Button.new()
	var loc4 = _get_loc()
	if loc4:
		upgrade_btn.text = loc4.t("upgrade")
	else:
		upgrade_btn.text = "Upgrade"
	upgrade_btn.toggle_mode = true
	upgrade_btn.custom_minimum_size = Vector2(0, 28)
	_style_small_button(upgrade_btn, Color(0.2, 0.6, 0.9))
	upgrade_btn.add_theme_font_size_override("font_size", 11)
	controls_vbox.add_child(upgrade_btn)

	# Store refs and connect
	var card_id = card["id"]
	count_labels[card_id] = count_lbl
	upgrade_btns[card_id] = upgrade_btn
	card_name_labels[card_id] = name_label
	card_desc_labels[card_id] = desc_label
	card_cost_labels[card_id] = cost_label
	card_type_badges[card_id] = type_badge
	all_card_data[card_id] = card
	minus_btn.pressed.connect(_on_minus.bind(card_id))
	plus_btn.pressed.connect(_on_plus.bind(card_id))
	upgrade_btn.toggled.connect(_on_upgrade_toggled.bind(card_id))

	return card_root

func _style_small_button(btn: Button, color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.4)
	style.border_color = color
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(color.r, color.g, color.b, 0.6)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_font_size_override("font_size", 18)

func _on_minus(card_id: String) -> void:
	var current = selected_cards.get(card_id, 0)
	if current <= 0:
		return
	selected_cards[card_id] = current - 1
	if selected_cards[card_id] == 0:
		selected_cards.erase(card_id)
	total_selected -= 1
	_update_count_label(card_id)
	_update_total()

func _on_plus(card_id: String) -> void:
	if total_selected >= MAX_DECK_SIZE:
		return
	var current = selected_cards.get(card_id, 0)
	if current >= MAX_COPIES:
		return
	selected_cards[card_id] = current + 1
	total_selected += 1
	_update_count_label(card_id)
	_update_total()

func _update_count_label(card_id: String) -> void:
	if count_labels.has(card_id):
		count_labels[card_id].text = str(selected_cards.get(card_id, 0))

func _update_total() -> void:
	if total_label:
		var loc = _get_loc()
		if loc:
			total_label.text = loc.tf("selected_x_of_y", [total_selected, MAX_DECK_SIZE])
		else:
			total_label.text = "Selected: %d / %d" % [total_selected, MAX_DECK_SIZE]
	if confirm_btn:
		confirm_btn.disabled = (total_selected != MAX_DECK_SIZE)

func _on_upgrade_toggled(toggled: bool, card_id: String) -> void:
	upgraded_cards[card_id] = toggled
	# Update display to show upgraded stats
	var gm = _get_game_manager()
	if gm == null:
		return
	var loc = _get_loc()
	var card: Dictionary
	if toggled:
		card = gm.get_upgraded_card(card_id)
		if upgrade_btns.has(card_id):
			if loc:
				upgrade_btns[card_id].text = loc.t("upgraded_check")
			else:
				upgrade_btns[card_id].text = "Upgraded ✓"
	else:
		card = gm.get_card_data(card_id)
		if upgrade_btns.has(card_id):
			if loc:
				upgrade_btns[card_id].text = loc.t("upgrade")
			else:
				upgrade_btns[card_id].text = "Upgrade"
	# Update name and description
	if card_name_labels.has(card_id):
		if loc:
			card_name_labels[card_id].text = loc.card_name(card)
		else:
			card_name_labels[card_id].text = card.get("name", "")
	if card_desc_labels.has(card_id):
		if loc:
			card_desc_labels[card_id].text = loc.card_desc(card)
		else:
			card_desc_labels[card_id].text = card.get("description", "")

func _on_confirm() -> void:
	if total_selected != MAX_DECK_SIZE:
		return
	# Build deck array with upgrade info
	var deck: Array = []
	var gm = _get_game_manager()
	for card_id in selected_cards:
		var use_upgraded: bool = upgraded_cards.get(card_id, false)
		for i in range(selected_cards[card_id]):
			if use_upgraded and gm:
				# Store as upgraded card data directly
				deck.append(card_id + "+")
			else:
				deck.append(card_id)
	# Update GameManager
	if gm:
		gm.player_deck = deck
	deck_confirmed.emit(deck)

func _get_game_manager() -> Node:
	for child in get_tree().root.get_children():
		if child.name == "GameManager":
			return child
	return null

func _apply_localized_ui() -> void:
	var loc = _get_loc()
	if loc == null:
		return
	# Title
	var title = _find_child_by_name(self, "Title") as Label
	if title:
		title.text = loc.t("build_your_deck")
	# Confirm button
	if confirm_btn:
		confirm_btn.text = loc.t("confirm_deck")
	# Total label
	if total_label:
		total_label.text = loc.tf("selected_x_of_y", [0, MAX_DECK_SIZE])

func _connect_language_buttons() -> void:
	var zh_btn = _find_child_by_name(self, "LangZhButton") as Button
	var en_btn = _find_child_by_name(self, "LangEnButton") as Button
	if zh_btn:
		zh_btn.pressed.connect(_switch_language.bind("zh"))
	if en_btn:
		en_btn.pressed.connect(_switch_language.bind("en"))

func _switch_language(lang: String) -> void:
	var loc = _get_loc()
	if loc:
		loc.set_language(lang)
	_refresh_all_localized_text()

func _refresh_all_localized_text() -> void:
	# Refresh title, bottom bar, confirm button
	_apply_localized_ui()
	# Refresh all card names, descriptions, cost lines, type badges, and upgrade buttons
	var loc = _get_loc()
	var gm = _get_game_manager()
	for card_id in all_card_data:
		var use_upgraded: bool = upgraded_cards.get(card_id, false)
		var card: Dictionary
		if use_upgraded and gm:
			card = gm.get_upgraded_card(card_id)
		elif gm:
			card = gm.get_card_data(card_id)
		else:
			card = all_card_data[card_id]
		# Name
		if card_name_labels.has(card_id):
			if loc:
				card_name_labels[card_id].text = loc.card_name(card)
			else:
				card_name_labels[card_id].text = card.get("name", "")
		# Description
		if card_desc_labels.has(card_id):
			if loc:
				card_desc_labels[card_id].text = loc.card_desc(card)
			else:
				card_desc_labels[card_id].text = card.get("description", "")
		# Cost line
		if card_cost_labels.has(card_id):
			card_cost_labels[card_id].text = _build_cost_text(card)
		# Type badge
		if card_type_badges.has(card_id):
			card_type_badges[card_id].text = " %s " % _get_type_name(card["type"])
		# Upgrade button
		if upgrade_btns.has(card_id):
			if use_upgraded:
				if loc:
					upgrade_btns[card_id].text = loc.t("upgraded_check")
				else:
					upgrade_btns[card_id].text = "Upgraded ✓"
			else:
				if loc:
					upgrade_btns[card_id].text = loc.t("upgrade")
				else:
					upgrade_btns[card_id].text = "Upgrade"
	_update_total()

func _get_type_name(type_index: int) -> String:
	var loc = _get_loc()
	if loc:
		return loc.type_name(type_index)
	var type_names = ["Attack", "Skill", "Power", "Status"]
	if type_index >= 0 and type_index < type_names.size():
		return type_names[type_index]
	return ""

func _build_cost_text(card: Dictionary) -> String:
	var loc = _get_loc()
	var type_name_str: String = _get_type_name(card["type"])
	if card["cost"] >= 0:
		if loc:
			return loc.tf("cost_type", [card["cost"], type_name_str])
		else:
			return "Cost: %d | %s" % [card["cost"], type_name_str]
	elif card["cost"] == -1:
		if loc:
			return loc.tf("cost_x_type", [type_name_str])
		else:
			return "Cost: X | %s" % type_name_str
	else:
		return "%s" % type_name_str

func _get_loc() -> Node:
	for child in get_tree().root.get_children():
		if child.name == "Loc":
			return child
	return null

func _find_child_by_name(node: Node, child_name: String) -> Node:
	for child in node.get_children():
		if child.name == child_name:
			return child
		var found = _find_child_by_name(child, child_name)
		if found:
			return found
	return null
