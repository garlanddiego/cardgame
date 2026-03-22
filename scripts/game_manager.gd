extends Node
## res://scripts/game_manager.gd — Global state: card database, character defs, run state

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
	_init_character_data()
	_init_card_database()

func _init_character_data() -> void:
	character_data = {
		"ironclad": {
			"name": "Ironclad",
			"max_hp": 80,
			"color": Color(0.8, 0.2, 0.2),
			"sprite": "res://assets/img/ironclad.png",
			"description": "A powerful warrior who uses strength and heavy attacks."
		},
		"silent": {
			"name": "Silent",
			"max_hp": 70,
			"color": Color(0.2, 0.7, 0.3),
			"sprite": "res://assets/img/silent.png",
			"description": "A deadly hunter who uses agility and poison."
		}
	}

func _init_card_database() -> void:
	# Ironclad cards (14)
	card_database["ic_strike"] = {"id": "ic_strike", "name": "Strike", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 6, "block": 0, "description": "Deal 6 damage.", "art": "res://assets/img/card_art_ironclad/strike.png", "target": "enemy"}
	card_database["ic_heavy_strike"] = {"id": "ic_heavy_strike", "name": "Heavy Strike", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 14, "block": 0, "description": "Deal 14 damage.", "art": "res://assets/img/card_art_ironclad/heavy_strike.png", "target": "enemy"}
	card_database["ic_iron_wave"] = {"id": "ic_iron_wave", "name": "Iron Wave", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 5, "block": 5, "description": "Deal 5 damage.\nGain 5 Block.", "art": "res://assets/img/card_art_ironclad/iron_wave.png", "target": "enemy"}
	card_database["ic_body_slam"] = {"id": "ic_body_slam", "name": "Body Slam", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 0, "block": 0, "description": "Deal damage equal\nto your Block.", "art": "res://assets/img/card_art_ironclad/body_slam.png", "target": "enemy", "special": "body_slam"}
	card_database["ic_searing_blow"] = {"id": "ic_searing_blow", "name": "Searing Blow", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 12, "block": 0, "description": "Deal 12 damage.", "art": "res://assets/img/card_art_ironclad/searing_blow.png", "target": "enemy"}
	card_database["ic_headbutt"] = {"id": "ic_headbutt", "name": "Headbutt", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 9, "block": 0, "description": "Deal 9 damage.", "art": "res://assets/img/card_art_ironclad/headbutt.png", "target": "enemy"}
	card_database["ic_reckless_strike"] = {"id": "ic_reckless_strike", "name": "Reckless Strike", "cost": 0, "type": CardType.ATTACK, "character": "ironclad", "damage": 7, "block": 0, "description": "Deal 7 damage.\nShuffle a Wound into\nyour draw pile.", "art": "res://assets/img/card_art_ironclad/reckless_strike.png", "target": "enemy"}
	card_database["ic_cleave"] = {"id": "ic_cleave", "name": "Cleave", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 8, "block": 0, "description": "Deal 8 damage to\nALL enemies.", "art": "res://assets/img/card_art_ironclad/cleave.png", "target": "all_enemies"}
	card_database["ic_shrug_it_off"] = {"id": "ic_shrug_it_off", "name": "Shrug It Off", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 8, "description": "Gain 8 Block.\nDraw 1 card.", "art": "res://assets/img/card_art_ironclad/shrug_it_off.png", "target": "self", "draw": 1}
	card_database["ic_flame_barrier"] = {"id": "ic_flame_barrier", "name": "Flame Barrier", "cost": 2, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 12, "description": "Gain 12 Block.", "art": "res://assets/img/card_art_ironclad/flame_barrier.png", "target": "self"}
	card_database["ic_battle_trance"] = {"id": "ic_battle_trance", "name": "Battle Trance", "cost": 0, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Draw 3 cards.", "art": "res://assets/img/card_art_ironclad/battle_trance.png", "target": "self", "draw": 3}
	card_database["ic_demon_form"] = {"id": "ic_demon_form", "name": "Demon Form", "cost": 3, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "At the start of\neach turn, gain 2\nStrength.", "art": "res://assets/img/card_art_ironclad/demon_form.png", "target": "self", "power_effect": "demon_form"}
	card_database["ic_bludgeon"] = {"id": "ic_bludgeon", "name": "Bludgeon", "cost": 3, "type": CardType.ATTACK, "character": "ironclad", "damage": 32, "block": 0, "description": "Deal 32 damage.", "art": "res://assets/img/card_art_ironclad/bludgeon.png", "target": "enemy"}
	card_database["ic_intimidate"] = {"id": "ic_intimidate", "name": "Intimidate", "cost": 0, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Apply 1 Weak to\nALL enemies.", "art": "res://assets/img/card_art_ironclad/intimidate.png", "target": "all_enemies", "apply_status": {"type": "weak", "stacks": 1}}

	# Silent cards (14)
	card_database["si_dagger_throw"] = {"id": "si_dagger_throw", "name": "Dagger Throw", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 9, "block": 0, "description": "Deal 9 damage.\nDraw 1 card.", "art": "res://assets/img/card_art_silent/dagger_throw.png", "target": "enemy", "draw": 1}
	card_database["si_quick_slash"] = {"id": "si_quick_slash", "name": "Quick Slash", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 8, "block": 0, "description": "Deal 8 damage.\nDraw 1 card.", "art": "res://assets/img/card_art_silent/quick_slash.png", "target": "enemy", "draw": 1}
	card_database["si_poisoned_stab"] = {"id": "si_poisoned_stab", "name": "Poisoned Stab", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 5, "block": 0, "description": "Deal 5 damage.\nApply 3 Vulnerable.", "art": "res://assets/img/card_art_silent/poisoned_stab.png", "target": "enemy", "apply_status": {"type": "vulnerable", "stacks": 3}}
	card_database["si_dash"] = {"id": "si_dash", "name": "Dash", "cost": 2, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 10, "description": "Gain 10 Block.", "art": "res://assets/img/card_art_silent/dash.png", "target": "self"}
	card_database["si_backstab"] = {"id": "si_backstab", "name": "Backstab", "cost": 0, "type": CardType.ATTACK, "character": "silent", "damage": 11, "block": 0, "description": "Deal 11 damage.", "art": "res://assets/img/card_art_silent/backstab.png", "target": "enemy"}
	card_database["si_fan_of_knives"] = {"id": "si_fan_of_knives", "name": "Fan of Knives", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 4, "block": 0, "description": "Deal 4 damage to\nALL enemies.\nDraw 1 card.", "art": "res://assets/img/card_art_silent/fan_of_knives.png", "target": "all_enemies", "draw": 1}
	card_database["si_blade_dance"] = {"id": "si_blade_dance", "name": "Blade Dance", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Add 3 Shivs to\nyour hand.", "art": "res://assets/img/card_art_silent/blade_dance.png", "target": "self", "special": "blade_dance"}
	card_database["si_predator_strike"] = {"id": "si_predator_strike", "name": "Predator", "cost": 2, "type": CardType.ATTACK, "character": "silent", "damage": 15, "block": 0, "description": "Deal 15 damage.", "art": "res://assets/img/card_art_silent/predator_strike.png", "target": "enemy"}
	card_database["si_dodge"] = {"id": "si_dodge", "name": "Dodge and Roll", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 4, "description": "Gain 4 Block.\nGain 4 Dexterity\nnext turn.", "art": "res://assets/img/card_art_silent/dodge.png", "target": "self"}
	card_database["si_cloak"] = {"id": "si_cloak", "name": "Cloak of Shadows", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 6, "description": "Gain 6 Block.", "art": "res://assets/img/card_art_silent/cloak_of_shadows.png", "target": "self"}
	card_database["si_caltrops"] = {"id": "si_caltrops", "name": "Caltrops", "cost": 1, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "Whenever you are\nattacked, deal 3\ndamage back.", "art": "res://assets/img/card_art_silent/caltrops.png", "target": "self", "power_effect": "caltrops"}
	card_database["si_envenom"] = {"id": "si_envenom", "name": "Envenom", "cost": 2, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "Whenever you deal\nunblocked damage,\napply 1 Vulnerable.", "art": "res://assets/img/card_art_silent/envenom.png", "target": "self", "power_effect": "envenom"}
	card_database["si_adrenaline"] = {"id": "si_adrenaline", "name": "Adrenaline", "cost": 0, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Gain 1 Energy.\nDraw 2 cards.", "art": "res://assets/img/card_art_silent/adrenaline.png", "target": "self", "draw": 2, "energy_gain": 1}
	card_database["si_accuracy"] = {"id": "si_accuracy", "name": "Accuracy", "cost": 1, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "Gain 3 Dexterity.", "art": "res://assets/img/card_art_silent/accuracy.png", "target": "self", "apply_self_status": {"type": "dexterity", "stacks": 3}}

func select_character(character_id: String) -> void:
	current_character = character_id
	var data = character_data[character_id]
	player_max_hp = data["max_hp"]
	player_hp = player_max_hp
	player_deck = get_starting_deck(character_id)
	character_selected.emit(character_id)

func get_starting_deck(character_id: String) -> Array:
	var deck: Array = []
	if character_id == "ironclad":
		# 5 Strikes, 4 Defends, 5 specials
		for i in range(4):
			deck.append("ic_strike")
		deck.append("ic_heavy_strike")
		deck.append("ic_iron_wave")
		deck.append("ic_shrug_it_off")
		deck.append("ic_shrug_it_off")
		deck.append("ic_flame_barrier")
		deck.append("ic_cleave")
		deck.append("ic_headbutt")
		deck.append("ic_battle_trance")
		deck.append("ic_intimidate")
		deck.append("ic_body_slam")
	elif character_id == "silent":
		for i in range(4):
			deck.append("si_dagger_throw")
		deck.append("si_quick_slash")
		deck.append("si_poisoned_stab")
		deck.append("si_dash")
		deck.append("si_backstab")
		deck.append("si_fan_of_knives")
		deck.append("si_cloak")
		deck.append("si_dodge")
		deck.append("si_blade_dance")
		deck.append("si_adrenaline")
		deck.append("si_predator_strike")
	return deck

func get_card_data(card_id: String) -> Dictionary:
	if card_database.has(card_id):
		return card_database[card_id].duplicate()
	return {}
