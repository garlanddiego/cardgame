extends Node
## res://scripts/game_manager.gd

signal character_selected(character_id: String)
signal battle_started
signal battle_ended(won: bool)

enum CardType { ATTACK, SKILL, POWER }

var current_character: String = ""
var player_max_hp: int = 80
var player_hp: int = 80
var player_deck: Array = []

var card_database: Dictionary = {}
var character_data: Dictionary = {}

func _ready() -> void:
	pass

func select_character(character_id: String) -> void:
	pass

func get_starting_deck(character_id: String) -> Array:
	return []

func get_card_data(card_id: String) -> Dictionary:
	return {}
