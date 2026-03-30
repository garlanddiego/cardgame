class_name NeutralCards
## res://scripts/cards/neutral_cards.gd — Status cards (pluggable)

enum CardType { ATTACK, SKILL, POWER, STATUS }

static func get_cards() -> Dictionary:
	var db: Dictionary = {}

	db["status_wound"] = {"id": "status_wound", "name": "Wound", "cost": -2, "type": CardType.STATUS, "character": "neutral", "damage": 0, "block": 0, "description": "Unplayable.", "art": "", "target": "none", "unplayable": true}
	db["status_burn"] = {"id": "status_burn", "name": "Burn", "cost": -2, "type": CardType.STATUS, "character": "neutral", "damage": 0, "block": 0, "description": "Unplayable.\nTake 2 damage at\nend of turn.", "art": "", "target": "none", "unplayable": true, "end_turn_damage": 2}
	db["status_dazed"] = {"id": "status_dazed", "name": "Dazed", "cost": -2, "type": CardType.STATUS, "character": "neutral", "damage": 0, "block": 0, "description": "Unplayable.\nEthereal.", "art": "", "target": "none", "unplayable": true, "ethereal": true}

	return db

static func get_upgrade_overrides() -> Dictionary:
	return {}
