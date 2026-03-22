extends Control
## res://scripts/card_ui.gd

signal card_clicked(card_data: Dictionary)
signal card_hovered(card_data: Dictionary)
signal card_unhovered

var card_data: Dictionary = {}
var is_hovered: bool = false
var is_selected: bool = false

func _ready() -> void:
	pass

func setup(data: Dictionary) -> void:
	pass

func set_selected(selected: bool) -> void:
	pass

func _on_mouse_entered() -> void:
	pass

func _on_mouse_exited() -> void:
	pass

func _gui_input(event: InputEvent) -> void:
	pass
