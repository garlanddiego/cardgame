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
var select_highlights: Dictionary = {}  # card_id -> Control (card root for highlight)

# Frame textures per card type (0=Attack, 1=Skill, 2=Power)
var _frame_textures: Array = []

func _load_frame_textures() -> void:
	if _frame_textures.size() == 0:
		_frame_textures.resize(3)
		_frame_textures[0] = load("res://assets/img/frame_attack_v2.png")
		_frame_textures[1] = load("res://assets/img/frame_skill_v2.png")
		_frame_textures[2] = load("res://assets/img/frame_power_v2.png")

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

# ─── STS-STYLE CARD ENTRY with NinePatchRect frames ─────────────────────────

func _get_frame_texture(card_type: int) -> Texture2D:
	_load_frame_textures()
	if card_type >= 0 and card_type < _frame_textures.size():
		return _frame_textures[card_type]
	return _frame_textures[0]

func _create_card_entry(card: Dictionary) -> Control:
	var card_id: String = card["id"]
	all_card_data[card_id] = card

	# 6 columns with 32px spacing: (1900 - 5*32) / 6 = ~290px wide
	var CARD_W: float = 290.0
	var CARD_H: float = 390.0

	var card_root = Control.new()
	card_root.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card_root.mouse_filter = Control.MOUSE_FILTER_PASS

	select_highlights[card_id] = card_root

	# --- NinePatchRect frame background (fills entire card) ---
	var frame = NinePatchRect.new()
	frame.name = "CardFrame"
	frame.texture = _get_frame_texture(card["type"])
	frame.position = Vector2.ZERO
	frame.size = Vector2(CARD_W, CARD_H)
	# Patch margins in source image pixels (896x1200):
	# Decorative borders are ~120px thick on each side
	frame.patch_margin_left = 120
	frame.patch_margin_top = 140
	frame.patch_margin_right = 120
	frame.patch_margin_bottom = 200
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(frame)

	# --- Card art area: in the frame's center window (~top 45%) ---
	var art_x: float = 26.0
	var art_y: float = 32.0
	var art_w: float = 238.0
	var art_h: float = 160.0

	var art_rect = TextureRect.new()
	art_rect.position = Vector2(art_x, art_y)
	art_rect.size = Vector2(art_w, art_h)
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if card.has("art") and ResourceLoader.exists(card["art"]):
		art_rect.texture = load(card["art"])
	art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(art_rect)

	# --- Cost number overlaying the frame's built-in gem ---
	var cost_label = Label.new()
	var cost_val = card.get("cost", 0)
	cost_label.text = "X" if cost_val == -1 else str(cost_val)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.position = Vector2(8, 5)
	cost_label.size = Vector2(32, 32)
	cost_label.add_theme_font_size_override("font_size", 22)
	cost_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(cost_label)
	card_cost_labels[card_id] = cost_label

	# --- Card name: positioned in the lower text area ---
	var name_label = Label.new()
	var loc = _get_loc()
	if loc:
		name_label.text = loc.card_name(card)
	else:
		name_label.text = card["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.position = Vector2(20, 200)
	name_label.size = Vector2(250, 24)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(name_label)
	card_name_labels[card_id] = name_label

	# --- Type text: small, centered, muted ---
	var type_badge = Label.new()
	type_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_badge.position = Vector2(20, 226)
	type_badge.size = Vector2(250, 16)
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

	# --- Description: in the lower text panel ---
	var desc_label = RichTextLabel.new()
	var loc3 = _get_loc()
	if loc3:
		desc_label.text = loc3.card_desc(card)
	else:
		desc_label.text = card["description"]
	desc_label.position = Vector2(20, 248)
	desc_label.size = Vector2(250, 130)
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

func _on_card_tap(event: InputEvent, card_id: String, card_root: Control) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	if selected_card_ids.has(card_id):
		# Deselect — restore normal appearance
		selected_card_ids.erase(card_id)
		_set_card_selected(card_root, false)
	else:
		# Select — green tint highlight
		selected_card_ids[card_id] = true
		_set_card_selected(card_root, true)

	_update_ui()

func _set_card_selected(card_root: Control, selected: bool) -> void:
	if selected:
		# Bright green-white tint to indicate selection
		card_root.modulate = Color(0.7, 1.0, 0.7, 1.0)
	else:
		card_root.modulate = Color(1.0, 1.0, 1.0, 1.0)

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
