extends Control
## res://scripts/deck_builder.gd — Shopping cart deck builder with browse + cart split layout

signal deck_confirmed(deck: Array)

const MAX_DECK_SIZE: int = 20

var character_id: String = ""
var selected_card_ids: Dictionary = {}  # card_id -> card data

# Card data tracking
var all_card_data: Dictionary = {}
var current_filter: String = ""  # "" = all, "ironclad", "silent"

# STS card image mapping: delegated to Card script (single source of truth)
var _CardScript = preload("res://scripts/card.gd")

# Layout refs — built programmatically
var browse_grid: GridContainer = null
var cart_list: VBoxContainer = null
var cart_count_label: Label = null
var confirm_btn: Button = null
var filter_all_btn: Button = null
var filter_ironclad_btn: Button = null
var filter_silent_btn: Button = null
var browse_scroll: ScrollContainer = null
var cart_scroll: ScrollContainer = null

# Constants
const SCREEN_W: float = 1920.0
const SCREEN_H: float = 1080.0
const BROWSE_RATIO: float = 0.75
const CART_RATIO: float = 0.25
const BROWSE_CARD_W: float = 256.0 * 0.8
const BROWSE_CARD_H: float = 430.0 * 0.8
const TOP_BAR_H: float = 70.0
const FILTER_BAR_H: float = 50.0
const BOTTOM_BAR_H: float = 0.0  # No bottom bar — confirm is in cart

func _ready() -> void:
	_build_layout()
	# If character_id was set before _ready (via setup), populate now
	if character_id != "":
		_populate_browse()
		_update_cart_ui()

func setup(char_id: String) -> void:
	character_id = char_id
	selected_card_ids.clear()
	all_card_data.clear()
	current_filter = ""
	if is_inside_tree() and browse_grid != null:
		_populate_browse()
		_update_cart_ui()

# ─── LAYOUT BUILDER ─────────────────────────────────────────────────────────

func _build_layout() -> void:
	# Clear any pre-existing children from the .tscn (background, etc.)
	# Keep only the script-built UI
	for child in get_children():
		remove_child(child)
		child.queue_free()

	# Background
	var bg_path := "res://assets/img/dungeon_bg.png"
	if ResourceLoader.exists(bg_path):
		var bg = TextureRect.new()
		bg.name = "Background"
		bg.texture = load(bg_path)
		bg.position = Vector2.ZERO
		bg.size = Vector2(SCREEN_W, SCREEN_H)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)

	# Dark overlay
	var overlay = ColorRect.new()
	overlay.name = "DarkOverlay"
	overlay.color = Color(0.0, 0.0, 0.05, 0.65)
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(SCREEN_W, SCREEN_H)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var browse_w: float = SCREEN_W * BROWSE_RATIO
	var cart_w: float = SCREEN_W * CART_RATIO

	# ── LEFT: Browse area ──────────────────────────────────────────────────
	_build_browse_area(browse_w)

	# ── RIGHT: Cart area ───────────────────────────────────────────────────
	_build_cart_area(browse_w, cart_w)

func _build_browse_area(browse_w: float) -> void:
	var content_top: float = TOP_BAR_H

	# Title
	var title = Label.new()
	title.name = "BrowseTitle"
	title.text = "选择卡牌"
	title.position = Vector2(20, 10)
	title.size = Vector2(browse_w - 40, TOP_BAR_H - 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	# Filter bar
	var filter_bar = HBoxContainer.new()
	filter_bar.name = "FilterBar"
	filter_bar.position = Vector2(20, content_top)
	filter_bar.size = Vector2(browse_w - 40, FILTER_BAR_H)
	filter_bar.add_theme_constant_override("separation", 12)
	add_child(filter_bar)

	filter_all_btn = _make_filter_button("全部", "")
	filter_bar.add_child(filter_all_btn)
	filter_ironclad_btn = _make_filter_button("铁甲战士", "ironclad")
	filter_bar.add_child(filter_ironclad_btn)
	filter_silent_btn = _make_filter_button("静默猎手", "silent")
	filter_bar.add_child(filter_silent_btn)

	# Language buttons on right side of filter bar
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_bar.add_child(spacer)

	var lang_zh = _make_lang_button("中文", "zh")
	filter_bar.add_child(lang_zh)
	var lang_en = _make_lang_button("English", "en")
	filter_bar.add_child(lang_en)

	content_top += FILTER_BAR_H + 8

	# Scroll container for browse grid
	browse_scroll = ScrollContainer.new()
	browse_scroll.name = "BrowseScroll"
	browse_scroll.position = Vector2(10, content_top)
	browse_scroll.size = Vector2(browse_w - 20, SCREEN_H - content_top - 10)
	browse_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	browse_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(browse_scroll)

	browse_grid = GridContainer.new()
	browse_grid.name = "BrowseGrid"
	# Calculate columns based on available width
	var card_with_gap: float = BROWSE_CARD_W + 16.0
	var cols: int = int(floor((browse_w - 40.0) / card_with_gap))
	if cols < 1:
		cols = 1
	browse_grid.columns = cols
	browse_grid.add_theme_constant_override("h_separation", 16)
	browse_grid.add_theme_constant_override("v_separation", 16)
	browse_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browse_scroll.add_child(browse_grid)

func _build_cart_area(x_offset: float, cart_w: float) -> void:
	# Cart background panel
	var cart_bg = Panel.new()
	cart_bg.name = "CartBG"
	cart_bg.position = Vector2(x_offset, 0)
	cart_bg.size = Vector2(cart_w, SCREEN_H)
	var cart_style = StyleBoxFlat.new()
	cart_style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	cart_style.border_color = Color(0.3, 0.3, 0.5, 0.6)
	cart_style.border_width_left = 2
	cart_bg.add_theme_stylebox_override("panel", cart_style)
	cart_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cart_bg)

	# Cart title
	var cart_title = Label.new()
	cart_title.name = "CartTitle"
	cart_title.text = "已选牌组"
	cart_title.position = Vector2(x_offset + 15, 12)
	cart_title.size = Vector2(cart_w - 30, 46)
	cart_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cart_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cart_title.add_theme_font_size_override("font_size", 32)
	cart_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	cart_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cart_title)

	# Card count
	cart_count_label = Label.new()
	cart_count_label.name = "CartCount"
	cart_count_label.text = "0 / %d" % MAX_DECK_SIZE
	cart_count_label.position = Vector2(x_offset + 15, 54)
	cart_count_label.size = Vector2(cart_w - 30, 30)
	cart_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cart_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cart_count_label.add_theme_font_size_override("font_size", 22)
	cart_count_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	cart_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cart_count_label)

	# Scroll for cart items
	var cart_top: float = 90.0
	var cart_bottom_margin: float = 80.0  # Space for confirm button
	cart_scroll = ScrollContainer.new()
	cart_scroll.name = "CartScroll"
	cart_scroll.position = Vector2(x_offset + 5, cart_top)
	cart_scroll.size = Vector2(cart_w - 10, SCREEN_H - cart_top - cart_bottom_margin - 10)
	cart_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cart_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(cart_scroll)

	cart_list = VBoxContainer.new()
	cart_list.name = "CartList"
	cart_list.add_theme_constant_override("separation", 6)
	cart_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cart_scroll.add_child(cart_list)

	# Confirm button at bottom of cart
	confirm_btn = Button.new()
	confirm_btn.name = "ConfirmButton"
	confirm_btn.text = "确认牌组"
	confirm_btn.position = Vector2(x_offset + 20, SCREEN_H - cart_bottom_margin + 5)
	confirm_btn.size = Vector2(cart_w - 40, 55)
	confirm_btn.disabled = true
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.5, 0.15, 0.85)
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
	confirm_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	confirm_btn.pressed.connect(_on_confirm)
	add_child(confirm_btn)

# ─── FILTER BUTTONS ──────────────────────────────────────────────────────────

func _make_filter_button(text: String, filter_value: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120, 40)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.25, 0.35, 0.8)
	style.border_color = Color(0.5, 0.5, 0.7, 0.7)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.35, 0.35, 0.5, 0.9)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	btn.pressed.connect(_on_filter.bind(filter_value))
	return btn

func _make_lang_button(text: String, lang: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(80, 36)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.4, 0.7)
	style.border_color = Color(0.5, 0.5, 0.7, 0.5)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	btn.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.4, 0.4, 0.55, 0.9)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	btn.pressed.connect(_switch_language.bind(lang))
	return btn

func _on_filter(filter_value: String) -> void:
	current_filter = filter_value
	_update_filter_button_styles()
	_populate_browse()

func _update_filter_button_styles() -> void:
	# Highlight active filter button
	var buttons := {
		"": filter_all_btn,
		"ironclad": filter_ironclad_btn,
		"silent": filter_silent_btn
	}
	for key in buttons:
		var btn: Button = buttons[key]
		if btn == null:
			continue
		var style = btn.get_theme_stylebox("normal") as StyleBoxFlat
		if style:
			var new_style = style.duplicate() as StyleBoxFlat
			if key == current_filter:
				new_style.bg_color = Color(0.4, 0.35, 0.15, 0.9)
				new_style.border_color = Color(0.9, 0.75, 0.3, 0.9)
				new_style.border_width_left = 2
				new_style.border_width_right = 2
				new_style.border_width_top = 2
				new_style.border_width_bottom = 2
			else:
				new_style.bg_color = Color(0.25, 0.25, 0.35, 0.8)
				new_style.border_color = Color(0.5, 0.5, 0.7, 0.7)
				new_style.border_width_left = 1
				new_style.border_width_right = 1
				new_style.border_width_top = 1
				new_style.border_width_bottom = 1
			btn.add_theme_stylebox_override("normal", new_style)

# ─── BROWSE GRID POPULATION ─────────────────────────────────────────────────

func _populate_browse() -> void:
	if browse_grid == null:
		return
	# Clear existing browse cards
	for child in browse_grid.get_children():
		browse_grid.remove_child(child)
		child.queue_free()

	var gm = _get_game_manager()
	if gm == null:
		return

	# Build card list from database
	var cards: Array = []
	for card_id in gm.card_database:
		var card = gm.card_database[card_id]
		# Skip status cards (type 3)
		if card["type"] == 3:
			continue
		# Apply character filter
		if current_filter != "" and card["character"] != current_filter:
			continue
		# Skip cards already in cart
		if selected_card_ids.has(card_id):
			continue
		cards.append(card)
		all_card_data[card_id] = card

	# Sort by type then name
	cards.sort_custom(func(a, b):
		if a["type"] != b["type"]:
			return a["type"] < b["type"]
		return a["name"] < b["name"]
	)

	var loc = _get_loc()
	var card_size = Vector2(BROWSE_CARD_W, BROWSE_CARD_H)

	for card in cards:
		var entry = _create_browse_card(card, card_size, loc)
		browse_grid.add_child(entry)

func _create_browse_card(card: Dictionary, card_size: Vector2, loc: Node) -> Control:
	var card_id: String = card["id"]

	var card_root = _create_lightweight_card(card, card_size, loc)
	card_root.name = "Browse_" + card_id
	card_root.mouse_filter = Control.MOUSE_FILTER_PASS

	# Connect tap to add to cart
	card_root.gui_input.connect(_on_browse_card_tap.bind(card_id))
	return card_root

func _create_lightweight_card(card: Dictionary, size: Vector2, loc: Node) -> Control:
	## Lightweight card visual: Panel + 3 labels + optional art thumbnail
	## Much fewer nodes than create_card_visual (~5 vs ~10+)
	var sx: float = size.x / 320.0
	var sy: float = size.y / 430.0

	var character: String = card.get("character", "ironclad")
	var bg_color: Color
	var border_color: Color
	match character:
		"silent":
			bg_color = Color(0.1, 0.22, 0.12, 1.0)
			border_color = Color(0.2, 0.75, 0.25, 1.0)
		_:
			bg_color = Color(0.28, 0.08, 0.08, 1.0)
			border_color = Color(0.85, 0.15, 0.15, 1.0)

	var card_type: int = card.get("type", 0)
	var type_name: String
	var type_color: Color
	match card_type:
		0: type_name = "攻击"; type_color = Color(0.85, 0.2, 0.2, 1.0)
		1: type_name = "技能"; type_color = Color(0.25, 0.45, 0.85, 1.0)
		2: type_name = "能力"; type_color = Color(0.85, 0.7, 0.15, 1.0)
		_: type_name = "状态"; type_color = Color(0.5, 0.5, 0.5, 1.0)

	# Root panel with colored border
	var root = Panel.new()
	root.custom_minimum_size = size
	root.size = size
	var body_style = StyleBoxFlat.new()
	body_style.bg_color = bg_color
	var corner_r: int = int(12.0 * sx)
	body_style.corner_radius_top_left = corner_r
	body_style.corner_radius_top_right = corner_r
	body_style.corner_radius_bottom_left = corner_r
	body_style.corner_radius_bottom_right = corner_r
	var border_w: int = int(4.0 * sx)
	body_style.border_width_left = border_w
	body_style.border_width_right = border_w
	body_style.border_width_top = border_w
	body_style.border_width_bottom = border_w
	body_style.border_color = border_color
	root.add_theme_stylebox_override("panel", body_style)

	# Cost label (top-left circle area)
	var cost_val: int = card.get("cost", 0)
	var cost_lbl = Label.new()
	cost_lbl.text = str(cost_val) if cost_val >= 0 else "X"
	cost_lbl.position = Vector2(6 * sx, 4 * sy)
	cost_lbl.size = Vector2(32 * sx, 32 * sy)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", int(22 * sx))
	cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cost_lbl)

	# Card name (centered, near top)
	var card_name: String = card.get("name", "???")
	if loc and loc.has_method("card_name"):
		card_name = loc.card_name(card)
	var name_lbl = Label.new()
	name_lbl.text = card_name
	name_lbl.position = Vector2(8 * sx, 34 * sy)
	name_lbl.size = Vector2(size.x - 16 * sx, 30 * sy)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", int(15 * sx))
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_lbl)

	# Art thumbnail (if available)
	var card_id: String = card.get("id", "")
	var art_path: String = "res://assets/img/card_art/" + card_id + ".png"
	if ResourceLoader.exists(art_path):
		var art_rect = TextureRect.new()
		art_rect.texture = load(art_path)
		var art_margin: float = 10 * sx
		var art_top: float = 66 * sy
		var art_w: float = size.x - art_margin * 2
		var art_h: float = size.y * 0.45
		art_rect.position = Vector2(art_margin, art_top)
		art_rect.size = Vector2(art_w, art_h)
		art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(art_rect)

	# Type + stats line (bottom area)
	var dmg: int = card.get("damage", 0)
	var blk: int = card.get("block", 0)
	var stat_text: String = type_name
	if dmg > 0 and blk > 0:
		stat_text += "  %d/%d" % [dmg, blk]
	elif dmg > 0:
		stat_text += "  %d" % dmg
	elif blk > 0:
		stat_text += "  %d" % blk
	var stat_lbl = Label.new()
	stat_lbl.text = stat_text
	stat_lbl.position = Vector2(6 * sx, size.y - 30 * sy)
	stat_lbl.size = Vector2(size.x - 12 * sx, 26 * sy)
	stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stat_lbl.add_theme_font_size_override("font_size", int(13 * sx))
	stat_lbl.add_theme_color_override("font_color", type_color)
	stat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stat_lbl)

	return root

func _on_browse_card_tap(event: InputEvent, card_id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	# Add to cart
	if not all_card_data.has(card_id):
		return
	selected_card_ids[card_id] = all_card_data[card_id]
	# Refresh browse (removes this card) and cart
	_populate_browse()
	_rebuild_cart_list()
	_update_cart_ui()

# ─── CART LIST ───────────────────────────────────────────────────────────────

func _rebuild_cart_list() -> void:
	if cart_list == null:
		return
	# Clear existing cart items
	for child in cart_list.get_children():
		cart_list.remove_child(child)
		child.queue_free()

	var loc = _get_loc()

	# Sort selected cards by type then name
	var sorted_cards: Array = selected_card_ids.values()
	sorted_cards.sort_custom(func(a, b):
		if a["type"] != b["type"]:
			return a["type"] < b["type"]
		return a["name"] < b["name"]
	)

	for card in sorted_cards:
		var item = _create_cart_item(card, loc)
		cart_list.add_child(item)

func _create_cart_item(card: Dictionary, loc: Node) -> Control:
	var card_id: String = card["id"]
	var cart_w: float = SCREEN_W * CART_RATIO - 20

	# Compact row: [cost circle] [name] [type badge]
	var item = Panel.new()
	item.name = "Cart_" + card_id
	item.custom_minimum_size = Vector2(cart_w, 48)

	# Determine colors based on character
	var character: String = card.get("character", "ironclad")
	var bg_color: Color
	var border_color: Color
	match character:
		"silent":
			bg_color = Color(0.08, 0.18, 0.1, 0.85)
			border_color = Color(0.2, 0.6, 0.2, 0.6)
		_:
			bg_color = Color(0.2, 0.06, 0.06, 0.85)
			border_color = Color(0.7, 0.15, 0.15, 0.6)

	var item_style = StyleBoxFlat.new()
	item_style.bg_color = bg_color
	item_style.border_color = border_color
	item_style.border_width_left = 1
	item_style.border_width_right = 1
	item_style.border_width_top = 1
	item_style.border_width_bottom = 1
	item_style.corner_radius_top_left = 6
	item_style.corner_radius_top_right = 6
	item_style.corner_radius_bottom_left = 6
	item_style.corner_radius_bottom_right = 6
	item.add_theme_stylebox_override("panel", item_style)

	# Cost circle
	var cost_val: int = card.get("cost", 0)
	var cost_lbl = Label.new()
	cost_lbl.text = str(cost_val) if cost_val >= 0 else "X"
	cost_lbl.position = Vector2(4, 0)
	cost_lbl.size = Vector2(36, 48)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 22)
	cost_lbl.add_theme_color_override("font_color", Color(0.2, 0.85, 0.3))
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(cost_lbl)

	# Card name
	var card_name: String = card.get("name", "???")
	if loc and loc.has_method("card_name"):
		card_name = loc.card_name(card)
	var name_lbl = Label.new()
	name_lbl.text = card_name
	name_lbl.position = Vector2(42, 0)
	name_lbl.size = Vector2(cart_w - 90, 48)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(name_lbl)

	# Type indicator (small colored dot text)
	var card_type: int = card.get("type", 0)
	var type_char: String
	var type_color: Color
	match card_type:
		0: type_char = "攻"; type_color = Color(0.85, 0.2, 0.2)
		1: type_char = "技"; type_color = Color(0.25, 0.45, 0.85)
		2: type_char = "能"; type_color = Color(0.85, 0.7, 0.15)
		_: type_char = "状"; type_color = Color(0.5, 0.5, 0.5)
	var type_lbl = Label.new()
	type_lbl.text = type_char
	type_lbl.position = Vector2(cart_w - 40, 0)
	type_lbl.size = Vector2(36, 48)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	type_lbl.add_theme_font_size_override("font_size", 16)
	type_lbl.add_theme_color_override("font_color", type_color)
	type_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(type_lbl)

	# Remove "x" indicator (subtle)
	var remove_hint = Label.new()
	remove_hint.text = "×"
	remove_hint.position = Vector2(cart_w - 18, 0)
	remove_hint.size = Vector2(16, 48)
	remove_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remove_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	remove_hint.add_theme_font_size_override("font_size", 18)
	remove_hint.add_theme_color_override("font_color", Color(0.6, 0.3, 0.3, 0.7))
	remove_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(remove_hint)

	# Connect tap to remove from cart
	item.gui_input.connect(_on_cart_item_tap.bind(card_id))
	item.mouse_filter = Control.MOUSE_FILTER_STOP

	return item

func _on_cart_item_tap(event: InputEvent, card_id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	# Remove from cart, return to browse
	selected_card_ids.erase(card_id)
	_populate_browse()
	_rebuild_cart_list()
	_update_cart_ui()

# ─── UI UPDATE ───────────────────────────────────────────────────────────────

func _update_cart_ui() -> void:
	var total: int = selected_card_ids.size()
	if cart_count_label:
		cart_count_label.text = "%d / %d" % [total, MAX_DECK_SIZE]
		if total >= MAX_DECK_SIZE:
			cart_count_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		elif total > 0:
			cart_count_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
		else:
			cart_count_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	if confirm_btn:
		confirm_btn.disabled = (total == 0)

# ─── CONFIRM ─────────────────────────────────────────────────────────────────

func _on_confirm() -> void:
	if selected_card_ids.is_empty():
		return
	var deck: Array = selected_card_ids.keys()
	var gm = _get_game_manager()
	if gm:
		gm.player_deck = deck
	deck_confirmed.emit(deck)

# ─── LANGUAGE ────────────────────────────────────────────────────────────────

func _switch_language(lang: String) -> void:
	var loc = _get_loc()
	if loc:
		loc.set_language(lang)
	# Refresh everything with new language
	_populate_browse()
	_rebuild_cart_list()
	_update_cart_ui()

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
