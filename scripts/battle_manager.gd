extends Node2D
## res://scripts/battle_manager.gd

signal turn_started(is_player: bool)
signal turn_ended
signal card_played(card_data: Dictionary, target: Node2D)
signal enemy_died(enemy_index: int)
signal player_died
signal battle_won

@export var max_energy: int = 3
@export var cards_per_draw: int = 5

var current_energy: int = 3
var draw_pile: Array = []
var discard_pile: Array = []
var exhaust_pile: Array = []
var hand: Array = []
var is_player_turn: bool = true
var enemies: Array = []
var player: Node2D = null

func _ready() -> void:
	pass

func start_battle() -> void:
	pass

func start_player_turn() -> void:
	pass

func draw_cards(count: int) -> void:
	pass

func play_card(card_data: Dictionary, target: Node2D) -> void:
	pass

func end_player_turn() -> void:
	pass

func start_enemy_turn() -> void:
	pass

func _on_card_played(card_data: Dictionary, target: Node2D) -> void:
	pass

func _on_end_turn() -> void:
	pass

func _on_entity_died(entity: Node2D) -> void:
	pass
