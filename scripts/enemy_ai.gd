extends RefCounted
## res://scripts/enemy_ai.gd

var enemy_type: String = ""
var turn_count: int = 0

func _init(type: String = "") -> void:
	enemy_type = type

func get_next_action(entity: Node2D) -> Dictionary:
	return {}

func _slime_action(entity: Node2D) -> Dictionary:
	return {}

func _cultist_action(entity: Node2D) -> Dictionary:
	return {}

func _jaw_worm_action(entity: Node2D) -> Dictionary:
	return {}

func _guardian_action(entity: Node2D) -> Dictionary:
	return {}
