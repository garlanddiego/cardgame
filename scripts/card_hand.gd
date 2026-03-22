extends Control
## res://scripts/card_hand.gd

signal card_played(card_data: Dictionary, target: Node2D)

var cards: Array = []
var selected_card: Control = null
var hovering: bool = false

func _ready() -> void:
	pass

func add_card(card_data: Dictionary) -> void:
	pass

func remove_card(card_node: Control) -> void:
	pass

func clear_hand() -> void:
	pass

func update_layout() -> void:
	pass

func _on_card_clicked(card_data: Dictionary) -> void:
	pass

func _on_card_hovered(card_data: Dictionary) -> void:
	pass

func _on_card_unhovered() -> void:
	pass
