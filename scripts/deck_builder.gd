extends Control
## res://scripts/deck_builder.gd — Two-page deck builder: Select cards then Confirm/Customize

signal deck_confirmed(deck: Array)

const MAX_DECK_SIZE: int = 10
const MAX_COPIES: int = 4

var character_id: String = ""
var selected_card_ids: Array = []  # Array of card_id strings (allows duplicates)
var upgraded_cards: Dictionary = {}  # card_id -> bool
var page: String = "select"  # "select" or "confirm"

# Node refs populated in _ready
var grid: GridContainer = null
var total_label: Label = null
var confirm_btn: Button = null
var next_btn: Button = null
var back_btn: Button = null
var scroll_container: ScrollContainer = null
var title_label: Label = null
var bottom_bar: HBoxContainer = null

# Tracking dictionaries for localization refresh
var card_name_labels: Dictionary = {}
var card_desc_labels: Dictionary = {}
var card_cost_labels: Dictionary = {}
var card_type_badges: Dictionary = {}
var all_card_data: Dictionary = {}
var select_highlights: Dictionary = {}  # card_id -> ColorRect (green border overlay)
var confirm_upgrade_btns: Dictionary = {}  # card_id -> Button (upgrade toggles on confirm page)
var confirm_count_labels: Dictionary = {}  # card_id -> Label (quantity on confirm page)
var confirm_remove_btns: Dictionary = {}  # card_id -> Button (X remove on confirm page)

func _ready() -> void:
	_find_nodes()
	if next_btn:
		next_btn.pressed.connect(_on_next)
		next_btn.visible = false
	if back_btn:
		back_btn.pressed.connect(_on_back)
		back_btn.visible = false
	if confirm_btn:
		confirm_btn.pressed.connect(_on_confirm)
		confirm_btn.visible = false
	_connect_language_buttons()
	_apply_localized_ui()

func _find_nodes() -> void:
	grid = _find_child_by_name(self, "CardGrid") as GridContainer
	total_label = _find_child_by_name(self, "TotalLabel") as Label
	confirm_btn = _find_child_by_name(self, "ConfirmButton") as Button
	next_btn = _find_child_by_name(self, "NextButton") as Button
	back_btn = _find_child_by_name(self, "BackButton") as Button
	scroll_container = _find_child_by_name(self, "ScrollContainer") as ScrollContainer
	title_label = _find_child_by_name(self, "Title") as Label
	bottom_bar = _find_child_by_name(self, "BottomBar") as HBoxContainer

func setup(char_id: String) -> void:
	character_id = char_id
	selected_card_ids.clear()
	upgraded_cards.clear()
	page = "select"
	_build_select_page()

# ─── PAGE BUILDERS ───────────────────────────────────────────────────────────

func _build_select_page() -> void:
	page = "select"
	_clear_grid()
	_clear_tracking()
	if grid:
		grid.columns = 6
	if title_label:
		var loc = _get_loc()
		if loc:
			title_label.text = loc.t("build_your_deck")
		else:
			title_label.text = "Build Your Deck"
	_populate_select_grid()
	_update_select_ui()

func _build_confirm_page() -> void:
	page = "confirm"
	_clear_grid()
	_clear_tracking()
	if grid:
		grid.columns = 5
	if title_label:
		var loc = _get_loc()
		if loc:
			title_label.text = loc.t("confirm_deck")
		else:
			title_label.text = "Confirm Deck"
	_populate_confirm_grid()
	_update_confirm_ui()

func _clear_grid() -> void:
	if grid == null:
		return
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

func _clear_tracking() -> void:
	card_name_labels.clear()
	card_desc_labels.clear()
	card_cost_labels.clear()
	card_type_badges.clear()
	select_highlights.clear()
	confirm_upgrade_btns.clear()
	confirm_count_labels.clear()
	confirm_remove_btns.clear()

# ─── SELECT PAGE ─────────────────────────────────────────────────────────────

func _populate_select_grid() -> void:
	if grid == null:
		return
	var gm = _get_game_manager()
	if gm == null:
		return

	var char_cards: Array = []
	for card_id in gm.card_database:
		var card = gm.card_database[card_id]
		if card["character"] == character_id and card["type"] != 3:
			char_cards.append(card)

	char_cards.sort_custom(func(a, b):
		if a["type"] != b["type"]:
			return a["type"] < b["type"]
		return a["name"] < b["name"]
	)

	for card in char_cards:
		var entry = _create_select_card_entry(card)
		grid.add_child(entry)

func _create_select_card_entry(card: Dictionary) -> Control:
	var card_id: String = card["id"]
	all_card_data[card_id] = card

	var card_root = Panel.new()
	card_root.custom_minimum_size = Vector2(420, 340)
	card_root.mouse_filter = Control.MOUSE_FILTER_STOP
	# Transparent style so frame texture shows through
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.04, 0.03, 0.9)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	card_root.add_theme_stylebox_override("panel", panel_style)

	# Green highlight border (initially hidden)
	var highlight = ColorRect.new()
	highlight.name = "Highlight"
	highlight.position = Vector2(-4, -4)
	highlight.size = Vector2(428, 348)
	highlight.color = Color(0.2, 0.9, 0.2, 0.0)  # invisible initially
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.z_index = -1
	card_root.add_child(highlight)
	select_highlights[card_id] = highlight

	# Card frame texture — scaled to fill
	var frame_path: String
	match card["type"]:
		0: frame_path = "res://assets/img/card_frame_attack_clean.png"
		1: frame_path = "res://assets/img/card_frame_skill.png"
		2: frame_path = "res://assets/img/card_frame_power_clean.png"
		_: frame_path = "res://assets/img/card_frame_attack_clean.png"

	var frame_tex = TextureRect.new()
	frame_tex.name = "FrameTexture"
	if ResourceLoader.exists(frame_path):
		frame_tex.texture = load(frame_path)
	frame_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_tex.stretch_mode = TextureRect.STRETCH_SCALE
	frame_tex.position = Vector2(0, 0)
	frame_tex.size = Vector2(420, 340)
	frame_tex.modulate = Color(1, 1, 1, 0.6)
	frame_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(frame_tex)

	# Card art — large, centered
	var art_rect = TextureRect.new()
	art_rect.position = Vector2(20, 10)
	art_rect.size = Vector2(160, 130)
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if card.has("art") and ResourceLoader.exists(card["art"]):
		art_rect.texture = load(card["art"])
	art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(art_rect)

	# Cost circle — top-left, larger
	var cost_label = Label.new()
	var cost_val = card.get("cost", 0)
	cost_label.text = "X" if cost_val == -1 else str(cost_val)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.position = Vector2(14, 8)
	cost_label.size = Vector2(36, 36)
	cost_label.add_theme_font_size_override("font_size", 20)
	cost_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	var cost_style = StyleBoxFlat.new()
	cost_style.bg_color = Color(0.6, 0.4, 0.1, 0.9)
	cost_style.corner_radius_top_left = 18
	cost_style.corner_radius_top_right = 18
	cost_style.corner_radius_bottom_left = 18
	cost_style.corner_radius_bottom_right = 18
	cost_style.content_margin_left = 4
	cost_style.content_margin_right = 4
	cost_style.content_margin_top = 2
	cost_style.content_margin_bottom = 2
	cost_label.add_theme_stylebox_override("normal", cost_style)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(cost_label)
	card_cost_labels[card_id] = cost_label

	# Card name — right side of card, large readable text
	var name_label = Label.new()
	var loc = _get_loc()
	if loc:
		name_label.text = loc.card_name(card)
	else:
		name_label.text = card["name"]
	name_label.position = Vector2(190, 12)
	name_label.size = Vector2(220, 30)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(name_label)
	card_name_labels[card_id] = name_label

	# Type + cost text
	var type_badge = Label.new()
	type_badge.position = Vector2(190, 42)
	type_badge.size = Vector2(220, 20)
	type_badge.add_theme_font_size_override("font_size", 14)
	type_badge.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55, 0.9))
	type_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var loc_badge = _get_loc()
	if loc_badge:
		type_badge.text = loc_badge.type_name(card["type"]) + " | " + _build_cost_text(card)
	else:
		var badge_type_names = ["Attack", "Skill", "Power", "Status"]
		type_badge.text = badge_type_names[card["type"]] + " | " + _build_cost_text(card)
	card_root.add_child(type_badge)
	card_type_badges[card_id] = type_badge

	# Description — right side, readable text
	var desc_label = RichTextLabel.new()
	var loc3 = _get_loc()
	if loc3:
		desc_label.text = loc3.card_desc(card)
	else:
		desc_label.text = card["description"]
	desc_label.position = Vector2(190, 66)
	desc_label.size = Vector2(220, 80)
	desc_label.scroll_active = false
	desc_label.bbcode_enabled = false
	desc_label.fit_content = false
	desc_label.add_theme_font_size_override("normal_font_size", 15)
	desc_label.add_theme_color_override("default_color", Color(0.9, 0.9, 0.9))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(desc_label)
	card_desc_labels[card_id] = desc_label

	# Selection count badge (bottom-right)
	var count_badge = Label.new()
	count_badge.name = "CountBadge"
	count_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_badge.position = Vector2(370, 290)
	count_badge.size = Vector2(40, 40)
	count_badge.add_theme_font_size_override("font_size", 20)
	count_badge.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.1, 0.7, 0.1, 0.9)
	badge_style.corner_radius_top_left = 20
	badge_style.corner_radius_top_right = 20
	badge_style.corner_radius_bottom_left = 20
	badge_style.corner_radius_bottom_right = 20
	count_badge.add_theme_stylebox_override("normal", badge_style)
	count_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_badge.visible = false
	card_root.add_child(count_badge)

	# Connect tap on entire card
	card_root.gui_input.connect(_on_select_card_input.bind(card_id, highlight, count_badge))

	return card_root

func _on_select_card_input(event: InputEvent, card_id: String, highlight: ColorRect, count_badge: Label) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	var current_count: int = _count_in_selected(card_id)

	if current_count > 0 and selected_card_ids.size() >= MAX_DECK_SIZE:
		# Already selected and deck full — deselect one copy
		_remove_one_from_selected(card_id)
	elif current_count > 0 and current_count >= MAX_COPIES:
		# At max copies — deselect all copies
		_remove_all_from_selected(card_id)
	elif selected_card_ids.size() >= MAX_DECK_SIZE:
		# Deck is full, can't add more
		return
	else:
		# Add one copy
		selected_card_ids.append(card_id)

	# Update visuals
	var new_count: int = _count_in_selected(card_id)
	if new_count > 0:
		highlight.color = Color(0.2, 0.9, 0.2, 0.25)
		count_badge.text = str(new_count)
		count_badge.visible = true
	else:
		highlight.color = Color(0.2, 0.9, 0.2, 0.0)
		count_badge.visible = false

	_update_select_ui()

func _count_in_selected(card_id: String) -> int:
	var count: int = 0
	for id in selected_card_ids:
		if id == card_id:
			count += 1
	return count

func _remove_one_from_selected(card_id: String) -> void:
	for i in range(selected_card_ids.size() - 1, -1, -1):
		if selected_card_ids[i] == card_id:
			selected_card_ids.remove_at(i)
			return

func _remove_all_from_selected(card_id: String) -> void:
	var i: int = selected_card_ids.size() - 1
	while i >= 0:
		if selected_card_ids[i] == card_id:
			selected_card_ids.remove_at(i)
		i -= 1

func _update_select_ui() -> void:
	var total: int = selected_card_ids.size()
	if total_label:
		var loc = _get_loc()
		if loc:
			total_label.text = loc.tf("selected_x_of_y", [total, MAX_DECK_SIZE])
		else:
			total_label.text = "Selected: %d / %d" % [total, MAX_DECK_SIZE]
	# Show/hide buttons
	var full: bool = (total == MAX_DECK_SIZE)
	if next_btn:
		next_btn.visible = full
	if confirm_btn:
		confirm_btn.visible = false
	if back_btn:
		back_btn.visible = false

# ─── CONFIRM PAGE ────────────────────────────────────────────────────────────

func _populate_confirm_grid() -> void:
	if grid == null:
		return
	var gm = _get_game_manager()
	if gm == null:
		return

	# Build unique cards with counts
	var unique_counts: Dictionary = {}  # card_id -> count
	for card_id in selected_card_ids:
		unique_counts[card_id] = unique_counts.get(card_id, 0) + 1

	# Sort by type then name
	var sorted_ids: Array = unique_counts.keys()
	sorted_ids.sort_custom(func(a, b):
		var ca = gm.card_database.get(a, {})
		var cb = gm.card_database.get(b, {})
		if ca.get("type", 0) != cb.get("type", 0):
			return ca.get("type", 0) < cb.get("type", 0)
		return ca.get("name", "") < cb.get("name", "")
	)

	for card_id in sorted_ids:
		var card = gm.card_database.get(card_id, {})
		if card.is_empty():
			continue
		all_card_data[card_id] = card
		var entry = _create_confirm_card_entry(card, unique_counts[card_id])
		grid.add_child(entry)

func _create_confirm_card_entry(card: Dictionary, count: int) -> Control:
	var card_id: String = card["id"]

	var card_root = Control.new()
	card_root.custom_minimum_size = Vector2(280, 380)

	# Card frame texture
	var frame_path: String
	match card["type"]:
		0: frame_path = "res://assets/img/card_frame_attack_clean.png"
		1: frame_path = "res://assets/img/card_frame_skill.png"
		2: frame_path = "res://assets/img/card_frame_power_clean.png"
		_: frame_path = "res://assets/img/card_frame_attack_clean.png"

	var frame_tex = TextureRect.new()
	frame_tex.name = "FrameTexture"
	if ResourceLoader.exists(frame_path):
		frame_tex.texture = load(frame_path)
	frame_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_tex.stretch_mode = TextureRect.STRETCH_SCALE
	frame_tex.position = Vector2(0, 0)
	frame_tex.size = Vector2(280, 320)
	frame_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(frame_tex)

	# Card art
	var art_rect = TextureRect.new()
	art_rect.position = Vector2(20, 20)
	art_rect.size = Vector2(240, 140)
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_SCALE
	if card.has("art") and ResourceLoader.exists(card["art"]):
		art_rect.texture = load(card["art"])
	art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(art_rect)

	# Cost circle
	var cost_label = Label.new()
	var cost_val = card.get("cost", 0)
	cost_label.text = "X" if cost_val == -1 else str(cost_val)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.position = Vector2(12, 8)
	cost_label.size = Vector2(32, 32)
	cost_label.add_theme_font_size_override("font_size", 16)
	cost_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	var cost_style = StyleBoxFlat.new()
	cost_style.bg_color = Color(0.6, 0.4, 0.1, 0.9)
	cost_style.corner_radius_top_left = 16
	cost_style.corner_radius_top_right = 16
	cost_style.corner_radius_bottom_left = 16
	cost_style.corner_radius_bottom_right = 16
	cost_style.content_margin_left = 2
	cost_style.content_margin_right = 2
	cost_style.content_margin_top = 1
	cost_style.content_margin_bottom = 1
	cost_label.add_theme_stylebox_override("normal", cost_style)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(cost_label)
	card_cost_labels[card_id] = cost_label

	# Card name
	var name_label = Label.new()
	var loc = _get_loc()
	if loc:
		name_label.text = loc.card_name(card)
	else:
		name_label.text = card["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.position = Vector2(0, 165)
	name_label.size = Vector2(280, 28)
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	name_label.clip_text = true
	var name_style = StyleBoxFlat.new()
	name_style.bg_color = Color(0.05, 0.04, 0.03, 0.85)
	name_label.add_theme_stylebox_override("normal", name_style)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(name_label)
	card_name_labels[card_id] = name_label

	# Description
	var desc_label = RichTextLabel.new()
	var loc3 = _get_loc()
	if loc3:
		desc_label.text = loc3.card_desc(card)
	else:
		desc_label.text = card["description"]
	desc_label.position = Vector2(10, 198)
	desc_label.size = Vector2(260, 60)
	desc_label.scroll_active = false
	desc_label.bbcode_enabled = false
	desc_label.fit_content = false
	desc_label.add_theme_font_size_override("normal_font_size", 12)
	desc_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(desc_label)
	card_desc_labels[card_id] = desc_label

	# Quantity label
	var qty_label = Label.new()
	qty_label.name = "QtyLabel"
	qty_label.text = "x%d" % count
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qty_label.position = Vector2(230, 8)
	qty_label.size = Vector2(40, 28)
	qty_label.add_theme_font_size_override("font_size", 16)
	qty_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	var qty_style = StyleBoxFlat.new()
	qty_style.bg_color = Color(0.2, 0.5, 0.8, 0.8)
	qty_style.corner_radius_top_left = 8
	qty_style.corner_radius_top_right = 8
	qty_style.corner_radius_bottom_left = 8
	qty_style.corner_radius_bottom_right = 8
	qty_label.add_theme_stylebox_override("normal", qty_style)
	qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(qty_label)
	confirm_count_labels[card_id] = qty_label

	# Controls row below the card frame
	var controls_hbox = HBoxContainer.new()
	controls_hbox.position = Vector2(4, 330)
	controls_hbox.size = Vector2(272, 40)
	controls_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_hbox.add_theme_constant_override("separation", 8)
	card_root.add_child(controls_hbox)

	# Upgrade toggle
	var upgrade_btn = Button.new()
	var loc4 = _get_loc()
	var is_upgraded: bool = upgraded_cards.get(card_id, false)
	if is_upgraded:
		if loc4:
			upgrade_btn.text = loc4.t("upgraded_check")
		else:
			upgrade_btn.text = "Upgraded"
	else:
		if loc4:
			upgrade_btn.text = loc4.t("upgrade")
		else:
			upgrade_btn.text = "Upgrade"
	upgrade_btn.toggle_mode = true
	upgrade_btn.button_pressed = is_upgraded
	upgrade_btn.custom_minimum_size = Vector2(100, 36)
	_style_small_button(upgrade_btn, Color(0.2, 0.6, 0.9))
	upgrade_btn.add_theme_font_size_override("font_size", 13)
	controls_hbox.add_child(upgrade_btn)
	confirm_upgrade_btns[card_id] = upgrade_btn
	upgrade_btn.toggled.connect(_on_upgrade_toggled.bind(card_id))

	# Remove button
	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.custom_minimum_size = Vector2(40, 36)
	_style_small_button(remove_btn, Color(0.8, 0.2, 0.2))
	remove_btn.add_theme_font_size_override("font_size", 16)
	controls_hbox.add_child(remove_btn)
	confirm_remove_btns[card_id] = remove_btn
	remove_btn.pressed.connect(_on_remove_card.bind(card_id))

	return card_root

func _on_remove_card(card_id: String) -> void:
	_remove_all_from_selected(card_id)
	# If deck is now under 10, go back to select page
	if selected_card_ids.size() < MAX_DECK_SIZE:
		_build_select_page()
	else:
		_build_confirm_page()

func _update_confirm_ui() -> void:
	var total: int = selected_card_ids.size()
	if total_label:
		var loc = _get_loc()
		if loc:
			total_label.text = loc.tf("selected_x_of_y", [total, MAX_DECK_SIZE])
		else:
			total_label.text = "Selected: %d / %d" % [total, MAX_DECK_SIZE]
	if next_btn:
		next_btn.visible = false
	if confirm_btn:
		confirm_btn.visible = (total == MAX_DECK_SIZE)
	if back_btn:
		back_btn.visible = true

# ─── NAVIGATION ──────────────────────────────────────────────────────────────

func _on_next() -> void:
	if selected_card_ids.size() == MAX_DECK_SIZE:
		_build_confirm_page()

func _on_back() -> void:
	_build_select_page()

# ─── UPGRADE TOGGLE ──────────────────────────────────────────────────────────

func _on_upgrade_toggled(toggled: bool, card_id: String) -> void:
	upgraded_cards[card_id] = toggled
	var gm = _get_game_manager()
	if gm == null:
		return
	var loc = _get_loc()
	var card: Dictionary
	if toggled:
		card = gm.get_upgraded_card(card_id)
		if confirm_upgrade_btns.has(card_id):
			if loc:
				confirm_upgrade_btns[card_id].text = loc.t("upgraded_check")
			else:
				confirm_upgrade_btns[card_id].text = "Upgraded"
	else:
		card = gm.get_card_data(card_id)
		if confirm_upgrade_btns.has(card_id):
			if loc:
				confirm_upgrade_btns[card_id].text = loc.t("upgrade")
			else:
				confirm_upgrade_btns[card_id].text = "Upgrade"
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

# ─── CONFIRM ─────────────────────────────────────────────────────────────────

func _on_confirm() -> void:
	if selected_card_ids.size() != MAX_DECK_SIZE:
		return
	var deck: Array = []
	var gm = _get_game_manager()
	for card_id in selected_card_ids:
		var use_upgraded: bool = upgraded_cards.get(card_id, false)
		if use_upgraded and gm:
			deck.append(card_id + "+")
		else:
			deck.append(card_id)
	if gm:
		gm.player_deck = deck
	deck_confirmed.emit(deck)

# ─── STYLING ─────────────────────────────────────────────────────────────────

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
	var pressed_style = style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(color.r, color.g, color.b, 0.7)
	btn.add_theme_stylebox_override("pressed", pressed_style)

# ─── UTILITY ─────────────────────────────────────────────────────────────────

func _get_game_manager() -> Node:
	for child in get_tree().root.get_children():
		if child.name == "GameManager":
			return child
	return null

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

# ─── LOCALIZATION ────────────────────────────────────────────────────────────

func _apply_localized_ui() -> void:
	var loc = _get_loc()
	if loc == null:
		return
	if title_label:
		if page == "select":
			title_label.text = loc.t("build_your_deck")
		else:
			title_label.text = loc.t("confirm_deck")
	if confirm_btn:
		confirm_btn.text = loc.t("confirm_deck")
	if next_btn:
		next_btn.text = loc.t("next_step") if loc.has_method("t") else "Next"
	if back_btn:
		back_btn.text = loc.t("back") if loc.has_method("t") else "Back"
	if total_label:
		total_label.text = loc.tf("selected_x_of_y", [selected_card_ids.size(), MAX_DECK_SIZE])

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
	_apply_localized_ui()
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
		if card_cost_labels.has(card_id):
			card_cost_labels[card_id].text = _build_cost_text(card)
		if card_type_badges.has(card_id):
			card_type_badges[card_id].text = _get_type_name(card["type"])
		if confirm_upgrade_btns.has(card_id):
			if use_upgraded:
				if loc:
					confirm_upgrade_btns[card_id].text = loc.t("upgraded_check")
				else:
					confirm_upgrade_btns[card_id].text = "Upgraded"
			else:
				if loc:
					confirm_upgrade_btns[card_id].text = loc.t("upgrade")
				else:
					confirm_upgrade_btns[card_id].text = "Upgrade"
	if page == "select":
		_update_select_ui()
	else:
		_update_confirm_ui()

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
