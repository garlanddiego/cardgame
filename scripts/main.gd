extends Node2D
## res://scripts/main.gd — Entry point, manages scene switching

var battle_scene: PackedScene = null
var deck_builder_scene: PackedScene = null
var current_character: String = "ironclad"

func _ready() -> void:
	battle_scene = load("res://scenes/battle.tscn")
	deck_builder_scene = load("res://scenes/deck_builder.tscn")
	# Remove old character select if exists
	var char_select = get_node_or_null("CharacterSelect")
	if char_select:
		char_select.queue_free()
	# Show simple character chooser
	call_deferred("_show_character_chooser")

func _show_character_chooser() -> void:
	var chooser = Control.new()
	chooser.name = "CharacterChooser"
	chooser.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(chooser)
	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.04, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	chooser.add_child(bg)
	# Title
	var title = Label.new()
	title.text = "选择英雄"
	title.position = Vector2(0, 50)
	title.size = Vector2(1920, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 1, 0.9))
	chooser.add_child(title)
	# Ironclad button
	var ic_btn = Button.new()
	ic_btn.name = "IroncladBtn"
	ic_btn.text = "铁甲战士 (Ironclad)"
	ic_btn.position = Vector2(300, 300)
	ic_btn.custom_minimum_size = Vector2(500, 100)
	ic_btn.add_theme_font_size_override("font_size", 32)
	var ic_style = StyleBoxFlat.new()
	ic_style.bg_color = Color(0.5, 0.1, 0.1, 0.9)
	ic_style.border_color = Color(0.85, 0.15, 0.15)
	ic_style.border_width_left = 4; ic_style.border_width_right = 4
	ic_style.border_width_top = 4; ic_style.border_width_bottom = 4
	ic_style.corner_radius_top_left = 12; ic_style.corner_radius_top_right = 12
	ic_style.corner_radius_bottom_left = 12; ic_style.corner_radius_bottom_right = 12
	ic_btn.add_theme_stylebox_override("normal", ic_style)
	ic_btn.pressed.connect(_on_character_chosen.bind("ironclad"))
	chooser.add_child(ic_btn)
	# Silent button
	var si_btn = Button.new()
	si_btn.name = "SilentBtn"
	si_btn.text = "静默猎手 (Silent)"
	si_btn.position = Vector2(1100, 300)
	si_btn.custom_minimum_size = Vector2(500, 100)
	si_btn.add_theme_font_size_override("font_size", 32)
	var si_style = StyleBoxFlat.new()
	si_style.bg_color = Color(0.1, 0.35, 0.1, 0.9)
	si_style.border_color = Color(0.2, 0.75, 0.25)
	si_style.border_width_left = 4; si_style.border_width_right = 4
	si_style.border_width_top = 4; si_style.border_width_bottom = 4
	si_style.corner_radius_top_left = 12; si_style.corner_radius_top_right = 12
	si_style.corner_radius_bottom_left = 12; si_style.corner_radius_bottom_right = 12
	si_btn.add_theme_stylebox_override("normal", si_style)
	si_btn.pressed.connect(_on_character_chosen.bind("silent"))
	chooser.add_child(si_btn)

func _on_character_chosen(character_id: String) -> void:
	current_character = character_id
	var gm = _get_gm()
	if gm:
		gm.select_character(character_id)
	var chooser = get_node_or_null("CharacterChooser")
	if chooser:
		chooser.queue_free()
	call_deferred("_load_deck_builder")

func _load_deck_builder() -> void:
	var builder = deck_builder_scene.instantiate()
	builder.name = "DeckBuilder"
	add_child(builder)
	builder.deck_confirmed.connect(_on_deck_confirmed.bind(current_character))
	builder.setup(current_character)

func _on_deck_confirmed(deck: Array, character_id: String) -> void:
	var old = get_node_or_null("DeckBuilder")
	if old:
		old.queue_free()
	call_deferred("_load_battle", character_id)

func _load_battle(character_id: String) -> void:
	var battle = battle_scene.instantiate()
	battle.name = "BattleInstance"
	add_child(battle)
	battle.start_battle(character_id)

func _get_gm() -> Node:
	for child in get_tree().root.get_children():
		if child.name == "GameManager":
			return child
	return null
