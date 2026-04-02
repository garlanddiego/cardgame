class_name NewCards
## res://scripts/cards/new_cards.gd — New version cards (cross-mechanic combos)

enum CardType { ATTACK, SKILL, POWER, STATUS }

static func get_cards() -> Dictionary:
	var db: Dictionary = {}

	# =========================================================================
	# POWER CARDS (3)
	# =========================================================================

	# 1. Venomous Might — poison → strength bridge
	db["nw_venomous_might"] = {
		"id": "nw_venomous_might", "name": "Venomous Might", "cost": 1,
		"type": CardType.POWER, "character": "neutral", "damage": 0, "block": 0,
		"description": "At the start of each\nturn, gain Strength\nequal to total enemy\nPoison ÷ 4.",
		"art": "", "target": "self", "version": "new",
		"power_effect": "venomous_might",
		"power_stacks": 1,
		"actions": [{"type": "power_effect", "power": "venomous_might"}]
	}

	# 2. Psi Surge — draw → energy bridge
	db["nw_psi_surge"] = {
		"id": "nw_psi_surge", "name": "Psi Surge", "cost": 2,
		"type": CardType.POWER, "character": "neutral", "damage": 0, "block": 0,
		"description": "Whenever you draw 3+\ncards in a single\naction, gain 1 Energy.",
		"art": "", "target": "self", "version": "new",
		"power_effect": "psi_surge",
		"power_stacks": 1,
		"actions": [{"type": "power_effect", "power": "psi_surge"}]
	}

	# 3. Blood Fury — self-damage → double next attack
	db["nw_blood_fury"] = {
		"id": "nw_blood_fury", "name": "Blood Fury", "cost": 1,
		"type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0,
		"description": "Whenever you lose HP\nfrom a card, your\nnext Attack deals\ndouble damage.",
		"art": "", "target": "self", "version": "new",
		"power_effect": "blood_fury",
		"power_stacks": 1,
		"actions": [{"type": "power_effect", "power": "blood_fury"}]
	}

	# =========================================================================
	# ATTACK CARDS (3)
	# =========================================================================

	# 4. Toxic Storm — X cost AoE + poison stacking
	db["nw_toxic_storm"] = {
		"id": "nw_toxic_storm", "name": "Toxic Storm", "cost": -1,
		"type": CardType.ATTACK, "character": "silent", "damage": 3, "block": 0,
		"description": "Deal 3 damage to ALL\nenemies X times.\nApply 1 Poison each\nhit.",
		"art": "", "target": "all_enemies", "version": "new",
		"poison_per_hit": 1,
		"actions": [{"type": "call", "fn": "toxic_storm"}]
	}

	# 5. Echo Slash — scales with attacks played this turn
	db["nw_echo_slash"] = {
		"id": "nw_echo_slash", "name": "Echo Slash", "cost": 2,
		"type": CardType.ATTACK, "character": "neutral", "damage": 5, "block": 0,
		"description": "Deal 5 damage.\nHit once more for\neach Attack played\nthis turn.",
		"art": "", "target": "enemy", "version": "new",
		"hits_per_attack": true,
		"actions": [{"type": "call", "fn": "echo_slash"}]
	}

	# 6. Gambler's Blade — hand size → damage
	db["nw_gamblers_blade"] = {
		"id": "nw_gamblers_blade", "name": "Gambler's Blade", "cost": 0,
		"type": CardType.ATTACK, "character": "silent", "damage": 0, "block": 0,
		"description": "Deal damage equal to\nhand size × 3.\nDiscard 1 card.",
		"art": "", "target": "enemy", "version": "new",
		"damage_per_hand": 3,
		"actions": [{"type": "call", "fn": "gamblers_blade"}]
	}

	# =========================================================================
	# SKILL CARDS (3)
	# =========================================================================

	# 7. Poison Shield — poison → block bridge
	db["nw_poison_shield"] = {
		"id": "nw_poison_shield", "name": "Poison Shield", "cost": 1,
		"type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0,
		"description": "Gain Block equal to\ntotal Poison on all\nenemies.",
		"art": "", "target": "self", "version": "new",
		"block_from_enemy_poison": true,
		"actions": [{"type": "call", "fn": "poison_shield"}]
	}

	# 8. Tactical Retreat — versatile cycle card
	db["nw_tactical_retreat"] = {
		"id": "nw_tactical_retreat", "name": "Tactical Retreat", "cost": 1,
		"type": CardType.SKILL, "character": "neutral", "damage": 0, "block": 6,
		"description": "Gain 6 Block.\nDraw 2 cards.\nDiscard 1 card.",
		"art": "", "target": "self", "draw": 2, "discard": 1, "version": "new",
		"actions": [{"type": "block"}, {"type": "draw"}]
	}

	# 9. All In — energy → draw burst
	db["nw_all_in"] = {
		"id": "nw_all_in", "name": "All In", "cost": 0,
		"type": CardType.SKILL, "character": "neutral", "damage": 0, "block": 0,
		"description": "Consume all Energy.\nDraw 2 cards per\nEnergy consumed.\nExhaust.",
		"art": "", "target": "self", "exhaust": true, "version": "new",
		"consume_energy": true, "draw_per_energy": 2,
		"actions": [{"type": "call", "fn": "all_in"}]
	}

	return db

static func get_upgrade_overrides() -> Dictionary:
	return {}
