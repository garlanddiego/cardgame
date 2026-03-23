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
	# Direct mapping from card_id to image file, identified by reading Chinese card names
	# Pages 1-3 are base cards (54 total); pages 4-5 are upgraded versions
	var _base := "res://assets/img/sts_cards/"
	_sts_card_map = {
		# Page 1
		"ic_strike": _base + "page1_card01.png",
		"ic_infernal_blade": _base + "page1_card02.png",
		"ic_sentinel": _base + "page1_card03.png",
		"ic_dual_wield": _base + "page1_card04.png",
		"ic_blood_for_blood": _base + "page1_card05.png",
		"ic_sever_soul": _base + "page1_card06.png",
		"ic_fire_breathing": _base + "page1_card07.png",
		"ic_carnage": _base + "page1_card08.png",
		"ic_dark_embrace": _base + "page1_card09.png",
		"ic_intimidate": _base + "page1_card10.png",
		"ic_power_through": _base + "page1_card11.png",
		"ic_flame_barrier": _base + "page1_card12.png",
		"ic_bloodletting": _base + "page1_card13.png",
		"ic_rupture": _base + "page1_card14.png",
		"ic_battle_trance": _base + "page1_card15.png",
		"ic_hemokinesis": _base + "page1_card16.png",
		"ic_ghostly_armor": _base + "page1_card17.png",
		"ic_entrench": _base + "page1_card18.png",
		# Page 2
		"ic_rampage": _base + "page2_card01.png",
		"ic_corruption": _base + "page2_card02.png",
		"ic_demon_form": _base + "page2_card03.png",
		"ic_fiend_fire": _base + "page2_card04.png",
		"ic_berserk": _base + "page2_card05.png",
		"ic_limit_break": _base + "page2_card06.png",
		"ic_impervious": _base + "page2_card07.png",
		"ic_bludgeon": _base + "page2_card08.png",
		"ic_immolate": _base + "page2_card09.png",
		"ic_barricade": _base + "page2_card10.png",
		"ic_reckless_charge": _base + "page2_card11.png",
		"ic_whirlwind": _base + "page2_card12.png",
		"ic_feel_no_pain": _base + "page2_card13.png",
		"ic_reaper": _base + "page2_card14.png",
		"ic_brutality": _base + "page2_card15.png",
		"ic_exhume": _base + "page2_card16.png",
		"ic_offering": _base + "page2_card17.png",
		"ic_double_tap": _base + "page2_card18.png",
		# Page 3
		"ic_juggernaut": _base + "page3_card01.png",
		"ic_disarm": _base + "page3_card02.png",
		"ic_anger": _base + "page3_card03.png",
		"ic_war_cry": _base + "page3_card04.png",
		"ic_shrug_it_off": _base + "page3_card05.png",
		"ic_twin_strike": _base + "page3_card06.png",
		"ic_pommel_strike": _base + "page3_card07.png",
		"ic_sword_boomerang": _base + "page3_card08.png",
		"ic_cleave": _base + "page3_card09.png",
		"ic_flex": _base + "page3_card10.png",
		"ic_wild_strike": _base + "page3_card11.png",
		"ic_defend": _base + "page3_card12.png",
		"ic_bash": _base + "page3_card13.png",
		"ic_headbutt": _base + "page3_card14.png",
		"ic_perfected_strike": _base + "page3_card15.png",
		"ic_clothesline": _base + "page3_card16.png",
		"ic_havoc": _base + "page3_card17.png",
		"ic_heavy_blade": _base + "page3_card18.png",
	}

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
