extends Node2D
## res://scripts/main.gd — Entry point, manages scene switching

var battle_scene: PackedScene = null
var deck_builder_scene: PackedScene = null
var current_character: String = "ironclad"
var second_character: String = "silent"

# Battle config from popup
var _config_draw: int = 5
var _config_energy: int = 3
var _config_enemies: int = 1
var _config_player_hp: int = 80
var _config_enemy_hps: Array = [50, 50, 50]  # HP for each enemy slot
var _config_dual_hero: bool = false

const BG_COLOR := Color(0.08, 0.06, 0.05, 1.0)
const PANEL_BG := Color(0.12, 0.10, 0.09, 1.0)
const ACCENT_GOLD := Color(0.85, 0.7, 0.15, 1.0)
const ACCENT_RED := Color(0.85, 0.2, 0.2, 1.0)
const ACCENT_GREEN := Color(0.2, 0.7, 0.3, 1.0)
const TEXT_COLOR := Color(0.95, 0.92, 0.85, 1.0)
const DIM_TEXT := Color(0.6, 0.58, 0.52, 1.0)
const INPUT_BG := Color(0.18, 0.15, 0.13, 1.0)
const BUTTON_NORMAL := Color(0.2, 0.17, 0.14, 1.0)
const BUTTON_HOVER := Color(0.3, 0.25, 0.2, 1.0)
const BUTTON_SELECTED := Color(0.5, 0.35, 0.1, 1.0)
const BORDER_COLOR := Color(0.4, 0.32, 0.2, 0.8)

func _ready() -> void:
	battle_scene = load("res://scenes/battle.tscn")
	deck_builder_scene = load("res://scenes/deck_builder.tscn")
	# Start with hero selection screen
	call_deferred("_show_character_select")

func _show_character_select() -> void:
	# Remove existing children
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame

	# Load and show character select
	var cs_scene = load("res://scenes/character_select.tscn")
	var char_select = cs_scene.instantiate()
	char_select.name = "CharacterSelect"
	add_child(char_select)

	char_select.character_chosen.connect(_on_character_chosen)
	char_select.dual_battle_chosen.connect(_on_dual_battle_chosen)
	char_select.back_pressed.connect(_on_back_to_menu)

func _on_character_chosen(character_id: String) -> void:
	current_character = character_id
	_config_dual_hero = false
	var gm = _get_gm()
	if gm:
		gm.select_character(current_character)
		gm.player_deck.clear()
	_remove_character_select()
	call_deferred("_load_deck_builder")

func _on_dual_battle_chosen(hero1_id: String, hero2_id: String) -> void:
	current_character = hero1_id
	second_character = hero2_id
	_config_dual_hero = true
	var gm = _get_gm()
	if gm:
		gm.select_character(current_character)
		gm.player_deck.clear()
	_remove_character_select()
	call_deferred("_load_deck_builder")

func _on_back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _remove_character_select() -> void:
	var cs = get_node_or_null("CharacterSelect")
	if cs:
		cs.queue_free()

func _load_deck_builder() -> void:
	var builder = deck_builder_scene.instantiate()
	builder.name = "DeckBuilder"
	add_child(builder)
	builder.deck_confirmed.connect(_on_deck_confirmed)
	builder.setup(current_character)

func _start_battle_from_deck(deck: Array) -> void:
	# Start battle directly with pre-set deck (from draft mode)
	var gm = _get_gm()
	if gm:
		gm.player_deck = deck
	# Show battle config popup with deck already set
	_show_battle_config_popup()

func _on_deck_confirmed(deck: Array) -> void:
	# Show battle config popup instead of jumping straight to battle
	_show_battle_config_popup()

func _show_battle_config_popup() -> void:
	# Use CanvasLayer to properly overlay on Node2D
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "BattleConfigOverlay"
	canvas_layer.layer = 100
	add_child(canvas_layer)

	# Full-screen overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(overlay)

	# Center panel
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 500)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel_style.border_color = ACCENT_GOLD
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 40
	panel_style.content_margin_right = 40
	panel_style.content_margin_top = 30
	panel_style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "战斗设置"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Separator
	var sep = HSeparator.new()
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = BORDER_COLOR
	sep_style.content_margin_top = 4
	sep_style.content_margin_bottom = 4
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Show selected hero info
	var hero_names := {"ironclad": "铁甲战士", "silent": "静默猎手", "bloodfiend": "嗜血狂魔", "fire_mage": "火法师", "forger": "铸造者"}
	var hero_info = Label.new()
	if _config_dual_hero:
		hero_info.text = "英雄: %s + %s (双英雄)" % [hero_names.get(current_character, current_character), hero_names.get(second_character, second_character)]
	else:
		hero_info.text = "英雄: %s" % hero_names.get(current_character, current_character)
	hero_info.add_theme_font_size_override("font_size", 22)
	hero_info.add_theme_color_override("font_color", ACCENT_GOLD)
	hero_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hero_info)

	# --- Draw per turn ---
	var draw_row = _create_config_row("每回合抽牌", _config_draw, 1, 20, func(val: int):
		_config_draw = val
	)
	vbox.add_child(draw_row)

	# --- Energy per turn ---
	var energy_row = _create_config_row("每回合能量", _config_energy, 1, 10, func(val: int):
		_config_energy = val
	)
	vbox.add_child(energy_row)

	# --- Player HP ---
	var player_hp_row = _create_config_row("英雄生命值", _config_player_hp, 10, 999, func(val: int):
		_config_player_hp = val
	)
	vbox.add_child(player_hp_row)

	# --- Enemy count + HP container ---
	var enemy_hp_container = VBoxContainer.new()
	enemy_hp_container.add_theme_constant_override("separation", 8)
	vbox.add_child(enemy_hp_container)

	var _rebuild_enemy_hps = func():
		# Clear and rebuild enemy HP rows
		for child in enemy_hp_container.get_children():
			if child.name != "EnemyCountRow":
				child.queue_free()
		for i in range(_config_enemies):
			var label_text: String = "怪物%d生命值" % (i + 1) if _config_enemies > 1 else "怪物生命值"
			var idx: int = i
			var hp_row = _create_config_row(label_text, _config_enemy_hps[i], 10, 999, func(val: int):
				_config_enemy_hps[idx] = val
			)
			enemy_hp_container.add_child(hp_row)

	var enemy_row = _create_config_row("怪物数量", _config_enemies, 1, 3, func(val: int):
		_config_enemies = val
		_rebuild_enemy_hps.call()
	)
	enemy_row.name = "EnemyCountRow"
	enemy_hp_container.add_child(enemy_row)
	# Build initial enemy HP rows
	_rebuild_enemy_hps.call()

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# --- Buttons row ---
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 20)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var back_hero_btn = _create_action_button("重选英雄", Color(0.5, 0.4, 0.2))
	back_hero_btn.pressed.connect(func():
		canvas_layer.queue_free()
		_show_character_select()
	)
	btn_row.add_child(back_hero_btn)

	var cancel_btn = _create_action_button("返回选牌", DIM_TEXT)
	cancel_btn.pressed.connect(func():
		canvas_layer.queue_free()
	)
	btn_row.add_child(cancel_btn)

	var start_btn = _create_action_button("开始战斗", ACCENT_RED)
	start_btn.pressed.connect(func():
		canvas_layer.queue_free()
		_start_battle_with_config()
	)
	btn_row.add_child(start_btn)

func _start_battle_with_config() -> void:
	# Remove ALL children except battle-related ones
	for child in get_children():
		if child.name != "BattleInstance":
			child.queue_free()
	# Wait for cleanup before loading battle
	await get_tree().process_frame
	_load_battle(current_character)

func _load_battle(character_id: String) -> void:
	var battle = battle_scene.instantiate()
	battle.name = "BattleInstance"
	add_child(battle)
	# Apply config
	battle.cards_per_draw = _config_draw
	battle.max_energy = _config_energy
	battle.enemy_count = _config_enemies
	battle.config_player_hp = _config_player_hp
	battle.config_enemy_hps = _config_enemy_hps.duplicate()
	battle.dual_hero_mode = _config_dual_hero
	battle.second_character_id = second_character if _config_dual_hero else ""
	battle.start_battle(character_id)

func _create_config_row(label_text: String, default_val: int, min_val: int, max_val: int, on_change: Callable) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", TEXT_COLOR)
	lbl.custom_minimum_size = Vector2(200, 0)
	row.add_child(lbl)

	var val_label = Label.new()
	val_label.text = str(default_val)
	val_label.add_theme_font_size_override("font_size", 26)
	val_label.add_theme_color_override("font_color", ACCENT_GOLD)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_label.custom_minimum_size = Vector2(60, 44)
	var val_style = StyleBoxFlat.new()
	val_style.bg_color = INPUT_BG
	val_style.border_color = BORDER_COLOR
	val_style.border_width_left = 1
	val_style.border_width_right = 1
	val_style.border_width_top = 1
	val_style.border_width_bottom = 1
	val_style.corner_radius_top_left = 4
	val_style.corner_radius_top_right = 4
	val_style.corner_radius_bottom_left = 4
	val_style.corner_radius_bottom_right = 4
	val_label.add_theme_stylebox_override("normal", val_style)

	var current_val: int = default_val

	var minus_btn = Button.new()
	minus_btn.text = "−"
	minus_btn.custom_minimum_size = Vector2(50, 44)
	minus_btn.add_theme_font_size_override("font_size", 28)
	minus_btn.add_theme_color_override("font_color", TEXT_COLOR)
	_style_spin_button(minus_btn)
	minus_btn.pressed.connect(func():
		current_val = maxi(min_val, current_val - 1)
		val_label.text = str(current_val)
		on_change.call(current_val)
	)
	row.add_child(minus_btn)

	row.add_child(val_label)

	var plus_btn = Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(50, 44)
	plus_btn.add_theme_font_size_override("font_size", 28)
	plus_btn.add_theme_color_override("font_color", TEXT_COLOR)
	_style_spin_button(plus_btn)
	plus_btn.pressed.connect(func():
		current_val = mini(max_val, current_val + 1)
		val_label.text = str(current_val)
		on_change.call(current_val)
	)
	row.add_child(plus_btn)

	return row

func _create_action_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 55)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.4)
	style.border_color = color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(color.r, color.g, color.b, 0.65)
	btn.add_theme_stylebox_override("hover", hover)
	return btn

func _style_spin_button(btn: Button) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = BUTTON_NORMAL
	style.border_color = BORDER_COLOR
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
	hover.bg_color = BUTTON_HOVER
	btn.add_theme_stylebox_override("hover", hover)

func _get_gm() -> Node:
	for child in get_tree().root.get_children():
		if child.name == "GameManager":
			return child
	return null
