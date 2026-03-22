extends Node2D
## res://scripts/entity.gd

signal hp_changed(current: int, max_val: int)
signal block_changed(amount: int)
signal status_changed(status_type: String, stacks: int)
signal died

@export var max_hp: int = 80
@export var is_enemy: bool = false

var current_hp: int = 80
var block: int = 0
var status_effects: Dictionary = {}
var enemy_type: String = ""
var intent: Dictionary = {}

func _ready() -> void:
	pass

func take_damage(amount: int) -> void:
	pass

func heal(amount: int) -> void:
	pass

func add_block(amount: int) -> void:
	pass

func apply_status(status_type: String, stacks: int) -> void:
	pass

func tick_status_effects() -> void:
	pass

func reset_block() -> void:
	pass
