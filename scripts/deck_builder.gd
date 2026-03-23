extends Control
## res://scripts/deck_builder.gd — STS-style single-page deck builder with tap-to-select
## Uses extracted STS card images as complete card visuals.

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

# Tracking dictionaries
var all_card_data: Dictionary = {}
var select_highlights: Dictionary = {}  # card_id -> Control (card root for highlight)

# STS card image mapping: delegated to Card script (single source of truth)
var _CardScript = preload("res://scripts/card.gd")

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
		grid.columns = 3
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

# ─── CARD ENTRY (STS image or text-rendered fallback) ────────────────────────

func _create_card_entry(card: Dictionary) -> Control:
	var card_id: String = card["id"]
	all_card_data[card_id] = card

	var CARD_W: float = 440.0
	var CARD_H: float = 590.0

	var card_root = Control.new()
	card_root.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card_root.mouse_filter = Control.MOUSE_FILTER_PASS
	select_highlights[card_id] = card_root

	# Card with STS-style frame + AI art + text (same as battle cards)
	var card_type: int = card.get("type", 0)
	var frame_path: String
	var type_name: String
	match card_type:
		0:  frame_path = "res://assets/img/card_frame_attack_sts.png"; type_name = "攻击"
		1:  frame_path = "res://assets/img/card_frame_skill_sts.png"; type_name = "技能"
		2:  frame_path = "res://assets/img/card_frame_power_sts.png"; type_name = "能力"
		_:  frame_path = "res://assets/img/card_frame_skill_sts.png"; type_name = "状态"

	# Scale factors from card.gd (320x430) to deck builder (360x485)
	var sx: float = CARD_W / 320.0  # 1.125
	var sy: float = CARD_H / 430.0  # 1.128

	# Dark background
	var bg = ColorRect.new()
	bg.name = "CardBG"
	bg.size = Vector2(CARD_W, CARD_H)
	bg.color = Color(0.08, 0.06, 0.04, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(bg)

	# Frame texture
	if ResourceLoader.exists(frame_path):
		var frame_img = TextureRect.new()
		frame_img.name = "CardFrame"
		frame_img.size = Vector2(CARD_W, CARD_H)
		frame_img.texture = load(frame_path)
		frame_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame_img.stretch_mode = TextureRect.STRETCH_SCALE
		frame_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_root.add_child(frame_img)

	# Art image (clipped inside frame)
	var art_path: String = "res://assets/img/card_art/" + card_id + ".png"
	if ResourceLoader.exists(art_path):
		var art_clip = Control.new()
		art_clip.name = "ArtClip"
		art_clip.position = Vector2(30 * sx, 52 * sy)
		art_clip.size = Vector2(260 * sx, 172 * sy)
		art_clip.clip_contents = true
		art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_root.add_child(art_clip)
		var art_img = TextureRect.new()
		art_img.size = Vector2(260 * sx, 172 * sy)
		art_img.texture = load(art_path)
		art_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_clip.add_child(art_img)

	# Cost on blue gem
	var cost_val: int = card.get("cost", 0)
	var cost_lbl = Label.new()
	cost_lbl.text = str(cost_val) if cost_val >= 0 else "X"
	cost_lbl.position = Vector2(5 * sx, 4 * sy)
	cost_lbl.size = Vector2(34 * sx, 34 * sy)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 20)
	cost_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_lbl.z_index = 5
	card_root.add_child(cost_lbl)

	# Name on scroll banner
	var loc = _get_loc()
	var card_name: String = card.get("name", "???")
	if loc and loc.has_method("card_name"):
		card_name = loc.card_name(card)
	var name_lbl = Label.new()
	name_lbl.text = card_name
	name_lbl.position = Vector2(38 * sx, 6 * sy)
	name_lbl.size = Vector2(250 * sx, 30 * sy)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.z_index = 5
	card_root.add_child(name_lbl)

	# Type tag
	var type_lbl = Label.new()
	type_lbl.text = type_name
	type_lbl.position = Vector2(28 * sx, 232 * sy)
	type_lbl.size = Vector2(264 * sx, 18 * sy)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.add_theme_font_size_override("font_size", 12)
	type_lbl.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	type_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	type_lbl.z_index = 5
	card_root.add_child(type_lbl)

	# Description in bottom frame area
	var desc: String = card.get("description", "")
	if loc and loc.has_method("card_desc"):
		desc = loc.card_desc(card)
	if desc != "":
		var desc_lbl = Label.new()
		desc_lbl.text = desc
		desc_lbl.position = Vector2(30 * sx, 260 * sy)
		desc_lbl.size = Vector2(260 * sx, 148 * sy)
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 14)
		desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc_lbl.z_index = 5
		card_root.add_child(desc_lbl)

	# Connect tap
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
	# Manage selection glow border overlay
	var glow = card_root.get_node_or_null("SelectionBorder") as Panel
	var check = card_root.get_node_or_null("CheckMark") as Label
	if selected:
		# Green tint per spec
		card_root.modulate = Color(0.8, 1.2, 0.8, 1.0)
		# Show gold border glow overlay (thicker: 8px)
		if glow == null:
			glow = Panel.new()
			glow.name = "SelectionBorder"
			glow.position = Vector2(-4, -4)
			glow.size = card_root.custom_minimum_size + Vector2(8, 8)
			glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sb = StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0)  # transparent fill
			sb.border_color = Color(0.902, 0.722, 0.290, 1.0)  # border_gold
			sb.border_width_left = 8
			sb.border_width_right = 8
			sb.border_width_top = 8
			sb.border_width_bottom = 8
			sb.corner_radius_top_left = 8
			sb.corner_radius_top_right = 8
			sb.corner_radius_bottom_left = 8
			sb.corner_radius_bottom_right = 8
			glow.add_theme_stylebox_override("panel", sb)
			card_root.add_child(glow)
		else:
			glow.visible = true
		# Show checkmark overlay
		if check == null:
			check = Label.new()
			check.name = "CheckMark"
			check.text = "✓"
			check.add_theme_font_size_override("font_size", 64)
			check.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
			check.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
			check.add_theme_constant_override("shadow_offset_x", 2)
			check.add_theme_constant_override("shadow_offset_y", 2)
			check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			check.position = Vector2(card_root.custom_minimum_size.x - 60, 10)
			check.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_root.add_child(check)
		else:
			check.visible = true
	else:
		card_root.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if glow:
			glow.visible = false
		if check:
			check.visible = false

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
	if selected_card_ids.is_empty():
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
	# Card images already contain baked-in text, no per-card text refresh needed
	_update_ui()
