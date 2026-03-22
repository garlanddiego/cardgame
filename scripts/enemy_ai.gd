extends RefCounted
## res://scripts/enemy_ai.gd — Enemy AI patterns for 4 enemy types

var enemy_type: String = ""
var turn_count: int = 0
var mode: int = 0  # For guardian mode shifts

func _init(type: String = "") -> void:
	enemy_type = type

func get_next_action(entity: Node2D) -> Dictionary:
	turn_count += 1
	match enemy_type:
		"slime":
			return _slime_action(entity)
		"cultist":
			return _cultist_action(entity)
		"jaw_worm":
			return _jaw_worm_action(entity)
		"guardian":
			return _guardian_action(entity)
	return {"type": "attack", "value": 5, "intent": "attack"}

func _slime_action(_entity: Node2D) -> Dictionary:
	# Slime: multi-attack pattern — alternates between single and multi-hit
	if turn_count % 2 == 1:
		return {"type": "attack", "value": 4, "times": 2, "intent": "attack", "desc": "Attacks 2x4"}
	else:
		return {"type": "attack", "value": 8, "times": 1, "intent": "attack", "desc": "Attacks for 8"}

func _cultist_action(_entity: Node2D) -> Dictionary:
	# Cultist: buffs first turn, then attacks with increasing strength
	if turn_count == 1:
		return {"type": "buff", "status": "strength", "value": 3, "intent": "buff", "desc": "Gains 3 Strength"}
	else:
		return {"type": "attack", "value": 6, "times": 1, "intent": "attack", "desc": "Attacks for 6"}

func _jaw_worm_action(_entity: Node2D) -> Dictionary:
	# Jaw Worm: aggressive/defensive cycle
	if turn_count % 3 == 1:
		return {"type": "attack", "value": 11, "times": 1, "intent": "attack", "desc": "Attacks for 11"}
	elif turn_count % 3 == 2:
		return {"type": "block", "value": 6, "intent": "defend", "desc": "Gains 6 Block"}
	else:
		return {"type": "attack_block", "damage": 7, "block_val": 5, "intent": "attack", "desc": "Attacks 7, Blocks 5"}

func _guardian_action(_entity: Node2D) -> Dictionary:
	# Guardian: mode shift — attack mode then defense mode with thorns
	if mode == 0:
		if turn_count % 3 == 0:
			mode = 1
			return {"type": "mode_shift", "block_val": 9, "intent": "defend", "desc": "Enters Defense Mode, gains 9 Block"}
		else:
			return {"type": "attack", "value": 10, "times": 1, "intent": "attack", "desc": "Attacks for 10"}
	else:
		mode = 0
		return {"type": "attack_debuff", "value": 8, "status": "vulnerable", "stacks": 1, "intent": "debuff", "desc": "Attacks 8, applies Vulnerable"}

func get_intent_icon(intent: String) -> String:
	match intent:
		"attack":
			return "res://assets/img/ui_icons/attack_intent.png"
		"defend":
			return "res://assets/img/ui_icons/defend_intent.png"
		"buff":
			return "res://assets/img/ui_icons/buff_intent.png"
		"debuff":
			return "res://assets/img/ui_icons/debuff_intent.png"
	return "res://assets/img/ui_icons/attack_intent.png"
