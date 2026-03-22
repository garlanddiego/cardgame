extends Node2D
## res://scripts/main.gd — Entry point, manages scene switching

var battle_scene: PackedScene = null
var deck_builder_scene: PackedScene = null
var current_character: String = "ironclad"

func _ready() -> void:
	battle_scene = load("res://scenes/battle.tscn")
	deck_builder_scene = load("res://scenes/deck_builder.tscn")
	# Skip character select, go straight to deck builder with Ironclad
	var char_select = get_node_or_null("CharacterSelect")
	if char_select:
		char_select.queue_free()
	# Select Ironclad by default
	var gm = _get_gm()
	if gm:
		gm.select_character("ironclad")
	# Load deck builder directly
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
