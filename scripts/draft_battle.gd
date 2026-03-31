extends Control
## scripts/draft_battle.gd — Draft Battle: select heroes → draft 10 cards → battle

const CardScript = preload("res://scripts/card.gd")

enum Phase { SETTINGS, DRAFTING, READY }
var phase: int = Phase.SETTINGS

# Settings
var selected_heroes: Array = []  # ["ironclad", "silent"]
var use_upgraded: bool = true

# Draft state
var card_pool: Array = []  # Available card IDs
var drafted_cards: Array = []  # Selected card data dicts
var draft_round: int = 0
var draft_total: int = 10
var current_options: Array = []  # 4 card dicts for current round

# UI refs
var _settings_panel: Control = null
var _draft_panel: Control = null
var _option_cards: Array = []  # 4 card visual containers
var _round_label: Label = null
var _drafted_label: Label = null

const BG_COLOR := Color(0.06, 0.05, 0.04, 1.0)
const GOLD := Color(0.85, 0.7, 0.15, 1.0)
const TEXT := Color(0.95, 0.92, 0.85, 1.0)
const DIM := Color(0.6, 0.58, 0.52, 1.0)

func _ready() -> void:
	# Remove builder node
	var builder = get_node_or_null("Builder")
	if builder:
		builder.queue_free()
	_build_settings_ui()

# =============================================================================
# SETTINGS PHASE
# =============================================================================

func _build_settings_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_settings_panel = Control.new()
	_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_settings_panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	# Center on screen
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.custom_minimum_size = Vector2(500, 0)
	_settings_panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "选牌战斗"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Hero selection
	var hero_label = Label.new()
	hero_label.text = "选择英雄（可多选）"
	hero_label.add_theme_font_size_override("font_size", 28)
	hero_label.add_theme_color_override("font_color", TEXT)
	vbox.add_child(hero_label)

	var hero_row = HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 20)
	hero_row.alignment = BoxContainer.ALIGNMENT_CENTER

	var ic_check = CheckBox.new()
	ic_check.text = "铁甲战士"
	ic_check.add_theme_font_size_override("font_size", 26)
	ic_check.add_theme_color_override("font_color", Color(0.85, 0.2, 0.2))
	ic_check.button_pressed = true
	selected_heroes.append("ironclad")
	ic_check.toggled.connect(func(on): _toggle_hero("ironclad", on))
	hero_row.add_child(ic_check)

	var si_check = CheckBox.new()
	si_check.text = "沉默猎手"
	si_check.add_theme_font_size_override("font_size", 26)
	si_check.add_theme_color_override("font_color", Color(0.2, 0.7, 0.3))
	si_check.button_pressed = true
	selected_heroes.append("silent")
	si_check.toggled.connect(func(on): _toggle_hero("silent", on))
	hero_row.add_child(si_check)

	vbox.add_child(hero_row)

	# Upgrade toggle
	var upgrade_check = CheckBox.new()
	upgrade_check.text = "使用升级版卡牌"
	upgrade_check.add_theme_font_size_override("font_size", 24)
	upgrade_check.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	upgrade_check.button_pressed = true
	upgrade_check.toggled.connect(func(on): use_upgraded = on)
	vbox.add_child(upgrade_check)

	# Start button
	var start_btn = Button.new()
	start_btn.text = "开始选牌"
	start_btn.custom_minimum_size = Vector2(300, 60)
	start_btn.add_theme_font_size_override("font_size", 30)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.6, 0.3, 0.9)
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
	start_btn.add_theme_stylebox_override("normal", btn_style)
	start_btn.pressed.connect(_start_drafting)
	vbox.add_child(start_btn)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "返回"
	back_btn.custom_minimum_size = Vector2(200, 50)
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	vbox.add_child(back_btn)


func _toggle_hero(hero_id: String, on: bool) -> void:
	if on and hero_id not in selected_heroes:
		selected_heroes.append(hero_id)
	elif not on and hero_id in selected_heroes:
		selected_heroes.erase(hero_id)


func _start_drafting() -> void:
	if selected_heroes.is_empty():
		return

	# Build card pool
	var gm = get_node_or_null("/root/GameManager")
	if gm == null:
		return

	card_pool.clear()
	for card_id in gm.card_database:
		var card: Dictionary = gm.card_database[card_id]
		if card.get("status", "active") != "active":
			continue
		if card.get("type", 0) == 3:  # Skip status cards
			continue
		var char_id: String = card.get("character", "")
		if char_id not in selected_heroes:
			continue
		# Skip basic strike/defend
		if card_id in ["ic_strike", "ic_defend", "si_strike", "si_defend"]:
			continue
		card_pool.append(card_id)

	if card_pool.is_empty():
		return

	# Switch to draft phase
	phase = Phase.DRAFTING
	draft_round = 0
	drafted_cards.clear()
	_settings_panel.visible = false
	_build_draft_ui()
	_next_draft_round()


# =============================================================================
# DRAFT PHASE
# =============================================================================

func _build_draft_ui() -> void:
	_draft_panel = Control.new()
	_draft_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_draft_panel)

	# Round label
	_round_label = Label.new()
	_round_label.position = Vector2(0, 20)
	_round_label.size = Vector2(1920, 50)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.add_theme_font_size_override("font_size", 36)
	_round_label.add_theme_color_override("font_color", GOLD)
	_draft_panel.add_child(_round_label)

	# Drafted count
	_drafted_label = Label.new()
	_drafted_label.position = Vector2(0, 70)
	_drafted_label.size = Vector2(1920, 40)
	_drafted_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drafted_label.add_theme_font_size_override("font_size", 22)
	_drafted_label.add_theme_color_override("font_color", DIM)
	_draft_panel.add_child(_drafted_label)

	# Back button during draft
	var back_btn = Button.new()
	back_btn.text = "返回主菜单"
	back_btn.position = Vector2(30, 20)
	back_btn.custom_minimum_size = Vector2(160, 40)
	back_btn.add_theme_font_size_override("font_size", 20)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	_draft_panel.add_child(back_btn)

	# 4 card option containers
	var card_w: float = 320.0
	var card_h: float = 480.0
	var gap: float = 40.0
	var total_w: float = 4 * card_w + 3 * gap
	var start_x: float = (1920 - total_w) / 2.0
	var card_y: float = 150.0

	for i in range(4):
		var container = Control.new()
		container.position = Vector2(start_x + i * (card_w + gap), card_y)
		container.size = Vector2(card_w, card_h)
		container.mouse_filter = Control.MOUSE_FILTER_STOP
		container.gui_input.connect(_on_option_clicked.bind(i))
		_draft_panel.add_child(container)
		_option_cards.append(container)


func _next_draft_round() -> void:
	draft_round += 1
	if draft_round > draft_total:
		_finish_drafting()
		return

	_round_label.text = "第 %d / %d 轮选牌" % [draft_round, draft_total]
	_drafted_label.text = "已选 %d 张" % drafted_cards.size()

	# Pick 4 random cards from pool
	var gm = get_node_or_null("/root/GameManager")
	current_options.clear()
	var pool_copy: Array = card_pool.duplicate()
	pool_copy.shuffle()

	var loc = get_node_or_null("/root/Loc")

	for i in range(mini(4, pool_copy.size())):
		var card_id: String = pool_copy[i]
		var card_data: Dictionary = gm.card_database[card_id].duplicate()
		if use_upgraded:
			var upgraded = gm.get_upgraded_card(card_id)
			if not upgraded.is_empty():
				card_data = upgraded
		current_options.append(card_data)

	# Render option cards
	for i in range(4):
		var container: Control = _option_cards[i]
		# Clear previous
		for child in container.get_children():
			child.queue_free()

		if i < current_options.size():
			var card_data: Dictionary = current_options[i]
			var visual = CardScript.create_card_visual(card_data, Vector2(320, 480), loc)
			container.add_child(visual)
			container.visible = true
		else:
			container.visible = false


func _on_option_clicked(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if index >= 0 and index < current_options.size():
			# Add selected card to drafted deck
			drafted_cards.append(current_options[index])
			_next_draft_round()


func _finish_drafting() -> void:
	phase = Phase.READY
	# Build deck from drafted cards and start battle
	var gm = get_node_or_null("/root/GameManager")
	if gm == null:
		return

	# Set player deck to drafted card IDs (with "+" suffix for upgraded)
	gm.player_deck.clear()
	for card_data in drafted_cards:
		var card_id: String = card_data.get("id", "")
		if card_data.get("upgraded", false) and not card_id.ends_with("+"):
			card_id += "+"
		gm.player_deck.append(card_id)

	# Use the first selected hero
	if not selected_heroes.is_empty():
		gm.select_character(selected_heroes[0])

	# Go to battle
	get_tree().change_scene_to_file("res://scenes/main.tscn")
