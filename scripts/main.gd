extends Node2D
## res://scripts/main.gd — Entry point, manages scene switching

var battle_scene: PackedScene = null

func _ready() -> void:
	battle_scene = load("res://scenes/battle.tscn")
	# Connect to character select
	var char_select = get_node_or_null("CharacterSelect")
	if char_select:
		char_select.character_chosen.connect(_on_character_chosen)

func _on_character_chosen(character_id: String) -> void:
	# Get GameManager autoload
	var gm: Node = null
	for child in get_tree().root.get_children():
		if child.name == "GameManager":
			gm = child
			break
	if gm:
		gm.select_character(character_id)
	# Remove character select
	var old = get_node_or_null("CharacterSelect")
	if old:
		old.free()
	# Load battle
	var battle = battle_scene.instantiate()
	battle.name = "BattleInstance"
	add_child(battle)
	# Start battle
	battle.start_battle(character_id)
