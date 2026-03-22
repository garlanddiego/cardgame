extends Control
## res://scripts/deck_builder.gd — STS-style single-page deck builder with tap-to-select

signal deck_confirmed(deck: Array)

const MAX_DECK_SIZE: int = 10

var character_id: String = ""
var selected_card_ids: Dictionary = {}  # card_id -> true (unique selections only)

# Node refs populated in _ready
var grid: GridContainer = null
var total_label: Label = null
var confirm_btn: Button = null
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
	scroll_container = _find_child_by_name(self, "ScrollContainer") as ScrollContainer
	title_label = _find_child_by_name(self, "Title") as Label
	bottom_bar = _find_child_by_name(self, "BottomBar") as HBoxContainer

func setup(char_id: String) -> void:
	character_id = char_id
	selected_card_ids.clear()
	_build_card_grid()

# ─── GRID BUILDER ────────────────────────────────────────────────────────────

func _build_card_grid() -> void:
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
	_populate_grid()
	_update_ui()

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

func _populate_grid() -> void:
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
		var entry = _create_card_entry(card)
		grid.add_child(entry)

# ─── STS-STYLE CARD ENTRY (372x495 portrait, 3:4 ratio) ─────────────────────

func _get_card_bg_color(card_type: int) -> Color:
	match card_type:
		0: return Color(0.45, 0.12, 0.1)    # Attack: dark red/maroon
		1: return Color(0.12, 0.35, 0.15)   # Skill: dark green
		2: return Color(0.2, 0.15, 0.4)     # Power: dark blue-purple
		_: return Color(0.25, 0.25, 0.25)

func _get_card_border_color(card_type: int) -> Color:
	match card_type:
		0: return Color(0.7, 0.2, 0.15)     # Attack: brighter red
		1: return Color(0.2, 0.6, 0.25)     # Skill: brighter green
		2: return Color(0.4, 0.3, 0.7)      # Power: brighter purple
		_: return Color(0.5, 0.5, 0.5)

func _create_card_entry(card: Dictionary) -> Control:
	var card_id: String = card["id"]
	all_card_data[card_id] = card

	# 6 columns with 32px spacing: (1900 - 5*32) / 6 = ~290px wide
	var CARD_W: float = 290.0
	var CARD_H: float = 390.0

	var card_root = Panel.new()
	card_root.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card_root.mouse_filter = Control.MOUSE_FILTER_PASS

	# Solid colored background + thick type-colored border + rounded corners
	var bg_color: Color = _get_card_bg_color(card["type"])
	var border_color: Color = _get_card_border_color(card["type"])

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = bg_color
	panel_style.border_color = border_color
	panel_style.border_width_left = 6
	panel_style.border_width_right = 6
	panel_style.border_width_top = 6
	panel_style.border_width_bottom = 6
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	card_root.add_theme_stylebox_override("panel", panel_style)

	select_highlights[card_id] = card_root

	# Frame texture overlay for quality/texture feel
	var frame_path: String
	match card["type"]:
		0: frame_path = "res://assets/img/card_frame_attack_clean.png"
		1: frame_path = "res://assets/img/card_frame_skill.png"
		2: frame_path = "res://assets/img/card_frame_power_clean.png"
		_: frame_path = "res://assets/img/card_frame_attack_clean.png"
	var frame_tex = TextureRect.new()
	frame_tex.name = "FrameOverlay"
	if ResourceLoader.exists(frame_path):
		frame_tex.texture = load(frame_path)
	frame_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_tex.stretch_mode = TextureRect.STRETCH_SCALE
	frame_tex.position = Vector2(0, 0)
	frame_tex.size = Vector2(CARD_W, CARD_H)
	frame_tex.modulate = Color(1, 1, 1, 0.6)  # Visible texture overlay for quality
	frame_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(frame_tex)

	# --- Card art area: top ~50% of card, inset 4px from edges ---
	var art_x: float = 4.0
	var art_y: float = 4.0
	var art_w: float = CARD_W - 8.0
	var art_h: float = CARD_H * 0.50

	# Art background — slightly darker than card bg
	var art_bg = ColorRect.new()
	art_bg.name = "ArtBackground"
	art_bg.position = Vector2(art_x, art_y)
	art_bg.size = Vector2(art_w, art_h)
	art_bg.color = Color(bg_color.r * 0.5, bg_color.g * 0.5, bg_color.b * 0.5, 1.0)
	art_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(art_bg)

	# Card art texture
	var art_rect = TextureRect.new()
	art_rect.position = Vector2(art_x, art_y)
	art_rect.size = Vector2(art_w, art_h)
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if card.has("art") and ResourceLoader.exists(card["art"]):
		art_rect.texture = load(card["art"])
	art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(art_rect)

	# --- Cost orb: AI-generated 3D golden orb with number overlay ---
	var cost_size: float = 44.0
	# Orb image background
	var cost_orb = TextureRect.new()
	cost_orb.name = "CostOrb"
	var orb_tex = load("res://assets/img/cost_orb_clean.png")
	if orb_tex:
		cost_orb.texture = orb_tex
	cost_orb.position = Vector2(4, 2)
	cost_orb.size = Vector2(cost_size, cost_size)
	cost_orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cost_orb.stretch_mode = TextureRect.STRETCH_SCALE
	cost_orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(cost_orb)
	# Cost number on top of orb
	var cost_label = Label.new()
	var cost_val = card.get("cost", 0)
	cost_label.text = "X" if cost_val == -1 else str(cost_val)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.position = Vector2(4, 2)
	cost_label.size = Vector2(cost_size, cost_size)
	cost_label.add_theme_font_size_override("font_size", 22)
	cost_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(cost_label)
	card_cost_labels[card_id] = cost_label

	# --- Card name banner: centered, slightly darker bg ---
	var name_y: float = art_y + art_h + 2.0
	var name_label = Label.new()
	var loc = _get_loc()
	if loc:
		name_label.text = loc.card_name(card)
	else:
		name_label.text = card["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.position = Vector2(4, name_y)
	name_label.size = Vector2(CARD_W - 8, 26)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	name_label.clip_text = true
	var name_style = StyleBoxFlat.new()
	name_style.bg_color = Color(bg_color.r * 0.6, bg_color.g * 0.6, bg_color.b * 0.6, 0.9)
	name_style.corner_radius_top_left = 3
	name_style.corner_radius_top_right = 3
	name_style.corner_radius_bottom_left = 3
	name_style.corner_radius_bottom_right = 3
	name_style.content_margin_left = 4
	name_style.content_margin_right = 4
	name_label.add_theme_stylebox_override("normal", name_style)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(name_label)
	card_name_labels[card_id] = name_label

	# --- Type text: very small, centered, muted ---
	var type_y: float = name_y + 28.0
	var type_badge = Label.new()
	type_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_badge.position = Vector2(4, type_y)
	type_badge.size = Vector2(CARD_W - 8, 14)
	type_badge.add_theme_font_size_override("font_size", 10)
	type_badge.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6, 0.8))
	type_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var loc_badge = _get_loc()
	if loc_badge:
		type_badge.text = loc_badge.type_name(card["type"])
	else:
		var badge_type_names = ["Attack", "Skill", "Power", "Status"]
		type_badge.text = badge_type_names[card["type"]]
	card_root.add_child(type_badge)
	card_type_badges[card_id] = type_badge

	# --- Description: centered, white, bottom ~30% of card ---
	var desc_y: float = type_y + 16.0
	var desc_h: float = CARD_H - desc_y - 6.0
	var desc_label = RichTextLabel.new()
	var loc3 = _get_loc()
	if loc3:
		desc_label.text = loc3.card_desc(card)
	else:
		desc_label.text = card["description"]
	desc_label.position = Vector2(8, desc_y)
	desc_label.size = Vector2(CARD_W - 16, desc_h)
	desc_label.scroll_active = false
	desc_label.bbcode_enabled = true
	desc_label.fit_content = false
	desc_label.add_theme_font_size_override("normal_font_size", 14)
	desc_label.add_theme_color_override("default_color", Color(0.95, 0.95, 0.95))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(desc_label)
	card_desc_labels[card_id] = desc_label

	# Connect tap on entire card
	card_root.gui_input.connect(_on_card_tap.bind(card_id, card_root))

	return card_root

# ─── TAP TO SELECT/DESELECT ─────────────────────────────────────────────────

func _on_card_tap(event: InputEvent, card_id: String, card_panel: Panel) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	if selected_card_ids.has(card_id):
		# Deselect — restore original border
		selected_card_ids.erase(card_id)
		_set_card_border(card_panel, false)
	else:
		# Select — green bright border
		selected_card_ids[card_id] = true
		_set_card_border(card_panel, true)

	_update_ui()

func _set_card_border(card_panel: Panel, selected: bool) -> void:
	var style = card_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if selected:
		style.border_color = Color(0.2, 1.0, 0.2, 1.0)  # Bright green
		style.border_width_left = 8
		style.border_width_right = 8
		style.border_width_top = 8
		style.border_width_bottom = 8
	else:
		style.border_width_left = 6
		style.border_width_right = 6
		style.border_width_top = 6
		style.border_width_bottom = 6
		# Restore original type-colored border
		for cid in all_card_data:
			if select_highlights.get(cid) == card_panel:
				style.border_color = _get_card_border_color(all_card_data[cid]["type"])
				break
	card_panel.add_theme_stylebox_override("panel", style)

# ─── UI UPDATE ───────────────────────────────────────────────────────────────

func _update_ui() -> void:
	var total: int = selected_card_ids.size()
	if total_label:
		var loc = _get_loc()
		if loc:
			total_label.text = loc.tf("selected_x_of_y", [total, MAX_DECK_SIZE])
		else:
			total_label.text = "已选: %d/10" % total
	if confirm_btn:
		confirm_btn.disabled = (total == 0)  # Always enabled as long as at least 1 card selected

# ─── CONFIRM ─────────────────────────────────────────────────────────────────

func _on_confirm() -> void:
	if selected_card_ids.size() == 0:
		return
	var deck: Array = selected_card_ids.keys()
	var gm = _get_game_manager()
	if gm:
		gm.player_deck = deck
	deck_confirmed.emit(deck)

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
		title_label.text = loc.t("build_your_deck")
	if confirm_btn:
		confirm_btn.text = loc.t("confirm_deck")
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
		var card: Dictionary
		if gm:
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
		if card_type_badges.has(card_id):
			if loc:
				card_type_badges[card_id].text = loc.type_name(card["type"])
			else:
				card_type_badges[card_id].text = _get_type_name(card["type"])
	_update_ui()

func _get_type_name(type_index: int) -> String:
	var loc = _get_loc()
	if loc:
		return loc.type_name(type_index)
	var type_names = ["Attack", "Skill", "Power", "Status"]
	if type_index >= 0 and type_index < type_names.size():
		return type_names[type_index]
	return ""
