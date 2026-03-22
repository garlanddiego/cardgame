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

func _ready() -> void:
	_find_nodes()
	if confirm_btn:
		confirm_btn.pressed.connect(_on_confirm)
		confirm_btn.disabled = true

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

func _create_card_entry(card: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 260)

	# Style by card type
	var style = StyleBoxFlat.new()
	var type_color: Color
	match card["type"]:
		0:  # ATTACK
			type_color = Color(0.8, 0.25, 0.2)
		1:  # SKILL
			type_color = Color(0.2, 0.5, 0.8)
		2:  # POWER
			type_color = Color(0.7, 0.55, 0.1)
		_:
			type_color = Color(0.5, 0.5, 0.5)
	style.bg_color = Color(type_color.r * 0.2, type_color.g * 0.2, type_color.b * 0.2, 0.9)
	style.border_color = Color(type_color.r, type_color.g, type_color.b, 0.7)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Card art
	var art_rect = TextureRect.new()
	art_rect.custom_minimum_size = Vector2(80, 80)
	art_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if card.has("art") and ResourceLoader.exists(card["art"]):
		art_rect.texture = load(card["art"])
	vbox.add_child(art_rect)

	# Card name
	var name_label = Label.new()
	name_label.text = card["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	vbox.add_child(name_label)

	# Cost + type line
	var type_names = ["Attack", "Skill", "Power", "Status"]
	var cost_text = ""
	if card["cost"] >= 0:
		cost_text = "Cost: %d | %s" % [card["cost"], type_names[card["type"]]]
	elif card["cost"] == -1:
		cost_text = "Cost: X | %s" % type_names[card["type"]]
	else:
		cost_text = "%s" % type_names[card["type"]]
	var cost_label = Label.new()
	cost_label.text = cost_text
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 14)
	cost_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	vbox.add_child(cost_label)

	# Description
	var desc_label = RichTextLabel.new()
	desc_label.text = card["description"]
	desc_label.custom_minimum_size = Vector2(0, 40)
	desc_label.fit_content = true
	desc_label.scroll_active = false
	desc_label.bbcode_enabled = false
	desc_label.add_theme_font_size_override("normal_font_size", 13)
	desc_label.add_theme_color_override("default_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(desc_label)

	# Upgrade toggle + count controls
	var controls_vbox = VBoxContainer.new()
	controls_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(controls_vbox)

	# Upgrade toggle button
	var upgrade_btn = Button.new()
	upgrade_btn.text = "Upgrade"
	upgrade_btn.toggle_mode = true
	upgrade_btn.custom_minimum_size = Vector2(0, 28)
	_style_small_button(upgrade_btn, Color(0.2, 0.6, 0.9))
	controls_vbox.add_child(upgrade_btn)

	# +/- controls
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	controls_vbox.add_child(hbox)

	var minus_btn = Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(36, 36)
	_style_small_button(minus_btn, Color(0.7, 0.3, 0.3))
	hbox.add_child(minus_btn)

	var count_lbl = Label.new()
	count_lbl.text = "0"
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.custom_minimum_size = Vector2(30, 0)
	count_lbl.add_theme_font_size_override("font_size", 20)
	count_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	hbox.add_child(count_lbl)

	var plus_btn = Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(36, 36)
	_style_small_button(plus_btn, Color(0.3, 0.7, 0.3))
	hbox.add_child(plus_btn)

	# Store refs and connect
	var card_id = card["id"]
	count_labels[card_id] = count_lbl
	upgrade_btns[card_id] = upgrade_btn
	card_name_labels[card_id] = name_label
	card_desc_labels[card_id] = desc_label
	minus_btn.pressed.connect(_on_minus.bind(card_id))
	plus_btn.pressed.connect(_on_plus.bind(card_id))
	upgrade_btn.toggled.connect(_on_upgrade_toggled.bind(card_id))

	return panel

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
		total_label.text = "Selected: %d / %d" % [total_selected, MAX_DECK_SIZE]
	if confirm_btn:
		confirm_btn.disabled = (total_selected != MAX_DECK_SIZE)

func _on_upgrade_toggled(toggled: bool, card_id: String) -> void:
	upgraded_cards[card_id] = toggled
	# Update display to show upgraded stats
	var gm = _get_game_manager()
	if gm == null:
		return
	var card: Dictionary
	if toggled:
		card = gm.get_upgraded_card(card_id)
		if upgrade_btns.has(card_id):
			upgrade_btns[card_id].text = "Upgraded ✓"
	else:
		card = gm.get_card_data(card_id)
		if upgrade_btns.has(card_id):
			upgrade_btns[card_id].text = "Upgrade"
	# Update name and description
	if card_name_labels.has(card_id):
		card_name_labels[card_id].text = card.get("name", "")
	if card_desc_labels.has(card_id):
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

func _find_child_by_name(node: Node, child_name: String) -> Node:
	for child in node.get_children():
		if child.name == child_name:
			return child
		var found = _find_child_by_name(child, child_name)
		if found:
			return found
	return null
