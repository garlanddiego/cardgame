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

# STS card image mapping: card_id -> res:// path
# Images are ordered to match the grid sort order (type ascending, then name ascending)
var _sts_card_map: Dictionary = {}

func _build_sts_card_map() -> void:
	if _sts_card_map.size() > 0:
		return
	# Images are at assets/img/sts_cards/page{N}_card{MM}.png
	# 82 images total across 5 pages, mapped in grid sort order (type then name)
	var ordered_ids: Array = [
		# ATTACKS (type 0) — sorted by name
		"ic_anger", "ic_bash", "ic_blood_for_blood", "ic_bludgeon", "ic_body_slam",
		"ic_carnage", "ic_clash", "ic_cleave", "ic_clothesline", "ic_dropkick",
		"ic_feed", "ic_fiend_fire", "ic_headbutt", "ic_heavy_blade", "ic_hemokinesis",
		"ic_immolate", "ic_iron_wave", "ic_perfected_strike",
		"ic_pommel_strike", "ic_pummel", "ic_rampage", "ic_reaper", "ic_reckless_charge",
		"ic_searing_blow", "ic_sever_soul", "ic_strike", "ic_sword_boomerang",
		"ic_thunderclap", "ic_twin_strike", "ic_uppercut", "ic_whirlwind", "ic_wild_strike",
		# SKILLS (type 1) — sorted by name
		"ic_armaments", "ic_battle_trance", "ic_bloodletting", "ic_burning_pact",
		"ic_defend", "ic_disarm", "ic_double_tap", "ic_dual_wield", "ic_entrench",
		"ic_exhume", "ic_flame_barrier", "ic_flex", "ic_ghostly_armor", "ic_havoc",
		"ic_impervious", "ic_infernal_blade", "ic_intimidate", "ic_limit_break",
		"ic_offering", "ic_power_through", "ic_second_wind", "ic_seeing_red",
		"ic_sentinel", "ic_shockwave", "ic_shrug_it_off", "ic_spot_weakness",
		"ic_true_grit", "ic_war_cry",
		# POWERS (type 2) — sorted by name
		"ic_barricade", "ic_berserk", "ic_brutality", "ic_combust", "ic_corruption",
		"ic_dark_embrace", "ic_demon_form", "ic_evolve", "ic_feel_no_pain",
		"ic_fire_breathing", "ic_inflame", "ic_juggernaut", "ic_metallicize",
		"ic_rage", "ic_rupture",
	]

	# Generate sequential page/card filenames
	var page := 1
	var card_on_page := 1
	var cards_per_page := 18
	for card_id in ordered_ids:
		var img_path := "res://assets/img/sts_cards/page%d_card%02d.png" % [page, card_on_page]
		_sts_card_map[card_id] = img_path
		card_on_page += 1
		if card_on_page > cards_per_page:
			card_on_page = 1
			page += 1

func _get_sts_card_path(card_id: String) -> String:
	_build_sts_card_map()
	if _sts_card_map.has(card_id):
		return _sts_card_map[card_id]
	return ""

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

# ─── STS CARD IMAGE ENTRY ────────────────────────────────────────────────────

func _create_card_entry(card: Dictionary) -> Control:
	var card_id: String = card["id"]
	all_card_data[card_id] = card

	var CARD_W: float = 290.0
	var CARD_H: float = 390.0

	var card_root = Control.new()
	card_root.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card_root.mouse_filter = Control.MOUSE_FILTER_PASS
	select_highlights[card_id] = card_root

	# Use complete STS card image as the entire card visual
	var card_img = TextureRect.new()
	card_img.name = "CardImage"
	card_img.position = Vector2.ZERO
	card_img.size = Vector2(CARD_W, CARD_H)
	card_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_img.stretch_mode = TextureRect.STRETCH_SCALE
	card_img.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Load the STS card image
	var sts_path = _get_sts_card_path(card_id)
	if sts_path != "" and ResourceLoader.exists(sts_path):
		card_img.texture = load(sts_path)

	card_root.add_child(card_img)

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
	# Manage selection glow border overlay
	var glow = card_root.get_node_or_null("SelectionBorder") as Panel
	if selected:
		# Green tint per spec
		card_root.modulate = Color(0.8, 1.2, 0.8, 1.0)
		# Show gold border glow overlay
		if glow == null:
			glow = Panel.new()
			glow.name = "SelectionBorder"
			glow.position = Vector2(-4, -4)
			glow.size = card_root.custom_minimum_size + Vector2(8, 8)
			glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sb = StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0)  # transparent fill
			sb.border_color = Color(0.902, 0.722, 0.290, 1.0)  # border_gold
			sb.border_width_left = 6
			sb.border_width_right = 6
			sb.border_width_top = 6
			sb.border_width_bottom = 6
			sb.corner_radius_top_left = 6
			sb.corner_radius_top_right = 6
			sb.corner_radius_bottom_left = 6
			sb.corner_radius_bottom_right = 6
			glow.add_theme_stylebox_override("panel", sb)
			card_root.add_child(glow)
		else:
			glow.visible = true
	else:
		card_root.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if glow:
			glow.visible = false

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
	# Card images already contain baked-in text, no per-card text refresh needed
	_update_ui()
