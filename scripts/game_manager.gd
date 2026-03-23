extends Node
## res://scripts/game_manager.gd — Global state: card database, character defs, run state

signal character_selected(character_id: String)
signal battle_started
signal battle_ended(won: bool)

enum CardType { ATTACK, SKILL, POWER, STATUS }

var current_character: String = ""
var player_max_hp: int = 80
var player_hp: int = 80
var player_deck: Array = []

var card_database: Dictionary = {}
var character_data: Dictionary = {}

# Art paths for cycling
var _ironclad_art: Array = [
	"res://assets/img/card_art_ironclad/strike.png",
	"res://assets/img/card_art_ironclad/heavy_strike.png",
	"res://assets/img/card_art_ironclad/iron_wave.png",
	"res://assets/img/card_art_ironclad/body_slam.png",
	"res://assets/img/card_art_ironclad/searing_blow.png",
	"res://assets/img/card_art_ironclad/headbutt.png",
	"res://assets/img/card_art_ironclad/reckless_strike.png",
	"res://assets/img/card_art_ironclad/cleave.png",
	"res://assets/img/card_art_ironclad/shrug_it_off.png",
	"res://assets/img/card_art_ironclad/flame_barrier.png",
	"res://assets/img/card_art_ironclad/battle_trance.png",
	"res://assets/img/card_art_ironclad/demon_form.png",
	"res://assets/img/card_art_ironclad/bludgeon.png",
	"res://assets/img/card_art_ironclad/pummel.png",
	"res://assets/img/card_art_ironclad/intimidate.png",
	"res://assets/img/card_art_ironclad/warcry.png",
]

func _ready() -> void:
	_init_character_data()
	_init_card_database()

func _init_character_data() -> void:
	character_data = {
		"ironclad": {
			"name": "Ironclad",
			"max_hp": 1000,
			"color": Color(0.8, 0.2, 0.2),
			"sprite": "res://assets/img/ironclad_sts.png",
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

func _ic_art(index: int) -> String:
	return _ironclad_art[index % _ironclad_art.size()]

func _init_card_database() -> void:
	# =========================================================================
	# IRONCLAD ATTACKS (26 cards)
	# =========================================================================

	# 1. Strike
	card_database["ic_strike"] = {"id": "ic_strike", "name": "Strike", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 6, "block": 0, "description": "Deal 6 damage.", "art": _ic_art(0), "target": "enemy"}

	# 2. Bash
	card_database["ic_bash"] = {"id": "ic_bash", "name": "Bash", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 8, "block": 0, "description": "Deal 8 damage.\nApply 2 Vulnerable.", "art": _ic_art(1), "target": "enemy", "apply_status": {"type": "vulnerable", "stacks": 2}}

	# 3. Iron Wave
	card_database["ic_iron_wave"] = {"id": "ic_iron_wave", "name": "Iron Wave", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 5, "block": 5, "description": "Deal 5 damage.\nGain 5 Block.", "art": _ic_art(2), "target": "enemy"}

	# 4. Body Slam
	card_database["ic_body_slam"] = {"id": "ic_body_slam", "name": "Body Slam", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 0, "block": 0, "description": "Deal damage equal\nto your Block.", "art": _ic_art(3), "target": "enemy", "special": "body_slam"}

	# 5. Anger
	card_database["ic_anger"] = {"id": "ic_anger", "name": "Anger", "cost": 0, "type": CardType.ATTACK, "character": "ironclad", "damage": 6, "block": 0, "description": "Deal 6 damage.\nAdd a copy to\nyour discard pile.", "art": _ic_art(0), "target": "enemy", "special": "anger"}

	# 6. Cleave
	card_database["ic_cleave"] = {"id": "ic_cleave", "name": "Cleave", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 8, "block": 0, "description": "Deal 8 damage to\nALL enemies.", "art": _ic_art(7), "target": "all_enemies"}

	# 7. Twin Strike
	card_database["ic_twin_strike"] = {"id": "ic_twin_strike", "name": "Twin Strike", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 5, "block": 0, "description": "Deal 5 damage twice.", "art": _ic_art(0), "target": "enemy", "times": 2}

	# 8. Wild Strike
	card_database["ic_wild_strike"] = {"id": "ic_wild_strike", "name": "Wild Strike", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 12, "block": 0, "description": "Deal 12 damage.\nShuffle a Wound into\nyour draw pile.", "art": _ic_art(6), "target": "enemy", "special": "wild_strike"}

	# 9. Pommel Strike
	card_database["ic_pommel_strike"] = {"id": "ic_pommel_strike", "name": "Pommel Strike", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 9, "block": 0, "description": "Deal 9 damage.\nDraw 1 card.", "art": _ic_art(0), "target": "enemy", "draw": 1}

	# 10. Headbutt
	card_database["ic_headbutt"] = {"id": "ic_headbutt", "name": "Headbutt", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 9, "block": 0, "description": "Deal 9 damage.", "art": _ic_art(5), "target": "enemy"}

	# 11. Pummel
	card_database["ic_pummel"] = {"id": "ic_pummel", "name": "Pummel", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 2, "block": 0, "description": "Deal 2 damage x4.", "art": _ic_art(13), "target": "enemy", "times": 4}

	# 12. Uppercut
	card_database["ic_uppercut"] = {"id": "ic_uppercut", "name": "Uppercut", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 13, "block": 0, "description": "Deal 13 damage.\nApply 1 Weak.\nApply 1 Vulnerable.", "art": _ic_art(1), "target": "enemy", "apply_status": {"type": "vulnerable", "stacks": 1}, "apply_status_2": {"type": "weak", "stacks": 1}}

	# 13. Immolate
	card_database["ic_immolate"] = {"id": "ic_immolate", "name": "Immolate", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 21, "block": 0, "description": "Deal 21 damage to\nALL enemies.\nAdd a Burn to discard.", "art": _ic_art(9), "target": "all_enemies", "special": "immolate"}

	# 14. Fiend Fire
	card_database["ic_fiend_fire"] = {"id": "ic_fiend_fire", "name": "Fiend Fire", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 7, "block": 0, "description": "Exhaust your hand.\nDeal 7 damage for\neach card exhausted.", "art": _ic_art(11), "target": "enemy", "special": "fiend_fire", "exhaust": true}

	# 15. Reaper
	card_database["ic_reaper"] = {"id": "ic_reaper", "name": "Reaper", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 4, "block": 0, "description": "Deal 4 damage to\nALL enemies.\nHeal for unblocked damage.", "art": _ic_art(11), "target": "all_enemies", "special": "reaper", "exhaust": true}

	# 16. Heavy Blade
	card_database["ic_heavy_blade"] = {"id": "ic_heavy_blade", "name": "Heavy Blade", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 14, "block": 0, "description": "Deal 14 damage.\nStrength applies x3.", "art": _ic_art(1), "target": "enemy", "special": "heavy_blade"}

	# 17. Thunderclap
	card_database["ic_thunderclap"] = {"id": "ic_thunderclap", "name": "Thunderclap", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 4, "block": 0, "description": "Deal 4 damage to\nALL enemies.\nApply 1 Vulnerable.", "art": _ic_art(7), "target": "all_enemies", "apply_status": {"type": "vulnerable", "stacks": 1}}

	# 18. Hemokinesis
	card_database["ic_hemokinesis"] = {"id": "ic_hemokinesis", "name": "Hemokinesis", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 15, "block": 0, "description": "Lose 2 HP.\nDeal 15 damage.", "art": _ic_art(6), "target": "enemy", "special": "hemokinesis"}

	# 19. Reckless Charge
	card_database["ic_reckless_charge"] = {"id": "ic_reckless_charge", "name": "Reckless Charge", "cost": 0, "type": CardType.ATTACK, "character": "ironclad", "damage": 7, "block": 0, "description": "Deal 7 damage.\nShuffle a Dazed into\nyour draw pile.", "art": _ic_art(6), "target": "enemy", "special": "reckless_charge"}

	# 20. Clash
	card_database["ic_clash"] = {"id": "ic_clash", "name": "Clash", "cost": 0, "type": CardType.ATTACK, "character": "ironclad", "damage": 14, "block": 0, "description": "Can only be played if\nevery card in hand\nis an Attack.\nDeal 14 damage.", "art": _ic_art(0), "target": "enemy", "special": "clash"}

	# 21. Perfected Strike
	card_database["ic_perfected_strike"] = {"id": "ic_perfected_strike", "name": "Perfected Strike", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 6, "block": 0, "description": "Deal 6 damage. Deals\n2 additional damage\nfor each \"Strike\" card\nin your deck.", "art": _ic_art(0), "target": "enemy", "special": "perfected_strike"}

	# 22. Bludgeon
	card_database["ic_bludgeon"] = {"id": "ic_bludgeon", "name": "Bludgeon", "cost": 3, "type": CardType.ATTACK, "character": "ironclad", "damage": 32, "block": 0, "description": "Deal 32 damage.", "art": _ic_art(12), "target": "enemy"}

	# 23. Sword Boomerang
	card_database["ic_sword_boomerang"] = {"id": "ic_sword_boomerang", "name": "Sword Boomerang", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 3, "block": 0, "description": "Deal 3 damage to a\nrandom enemy 3 times.", "art": _ic_art(0), "target": "random_enemy", "times": 3}

	# 24. Searing Blow
	card_database["ic_searing_blow"] = {"id": "ic_searing_blow", "name": "Searing Blow", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 12, "block": 0, "description": "Deal 12 damage.", "art": _ic_art(4), "target": "enemy"}

	# 25. Whirlwind
	card_database["ic_whirlwind"] = {"id": "ic_whirlwind", "name": "Whirlwind", "cost": -1, "type": CardType.ATTACK, "character": "ironclad", "damage": 5, "block": 0, "description": "Deal 5 damage to ALL\nenemies X times.\n(X = current Energy)", "art": _ic_art(7), "target": "all_enemies", "special": "whirlwind"}

	# 26. Dropkick
	card_database["ic_dropkick"] = {"id": "ic_dropkick", "name": "Dropkick", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 5, "block": 0, "description": "Deal 5 damage.\nIf enemy is Vulnerable:\ngain 1 Energy, draw 1.", "art": _ic_art(5), "target": "enemy", "special": "dropkick"}

	# 27a. Carnage
	card_database["ic_carnage"] = {"id": "ic_carnage", "name": "Carnage", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 20, "block": 0, "description": "Ethereal.\nDeal 20 damage.", "art": _ic_art(6), "target": "enemy", "ethereal": true}

	# 27b. Clothesline
	card_database["ic_clothesline"] = {"id": "ic_clothesline", "name": "Clothesline", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 12, "block": 0, "description": "Deal 12 damage.\nApply 2 Weak.", "art": _ic_art(1), "target": "enemy", "apply_status": {"type": "weak", "stacks": 2}}

	# 27c. Feed
	card_database["ic_feed"] = {"id": "ic_feed", "name": "Feed", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 10, "block": 0, "description": "Deal 10 damage.\nIf this kills, gain\n3 Max HP. Exhaust.", "art": _ic_art(6), "target": "enemy", "special": "feed", "exhaust": true}

	# 27d. Rampage
	card_database["ic_rampage"] = {"id": "ic_rampage", "name": "Rampage", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 8, "block": 0, "description": "Deal 8 damage.\nIncreases by 5\neach time played.", "art": _ic_art(0), "target": "enemy", "special": "rampage"}

	# 27e. Sever Soul
	card_database["ic_sever_soul"] = {"id": "ic_sever_soul", "name": "Sever Soul", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 16, "block": 0, "description": "Exhaust all non-Attack\ncards in hand.\nDeal 16 damage.", "art": _ic_art(0), "target": "enemy", "special": "sever_soul"}

	# =========================================================================
	# IRONCLAD SKILLS (27 cards)
	# =========================================================================

	# 27. Defend
	card_database["ic_defend"] = {"id": "ic_defend", "name": "Defend", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 5, "description": "Gain 5 Block.", "art": _ic_art(8), "target": "self"}

	# 28. Shrug It Off
	card_database["ic_shrug_it_off"] = {"id": "ic_shrug_it_off", "name": "Shrug It Off", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 8, "description": "Gain 8 Block.\nDraw 1 card.", "art": _ic_art(8), "target": "self", "draw": 1}

	# 29. Flame Barrier
	card_database["ic_flame_barrier"] = {"id": "ic_flame_barrier", "name": "Flame Barrier", "cost": 2, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 12, "description": "Gain 12 Block.\nWhen attacked this turn,\ndeal 4 damage back.", "art": _ic_art(9), "target": "self", "power_effect": "flame_barrier"}

	# 30. Battle Trance
	card_database["ic_battle_trance"] = {"id": "ic_battle_trance", "name": "Battle Trance", "cost": 0, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Draw 3 cards.", "art": _ic_art(10), "target": "self", "draw": 3}

	# 31. Bloodletting
	card_database["ic_bloodletting"] = {"id": "ic_bloodletting", "name": "Bloodletting", "cost": 0, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Lose 3 HP.\nGain 2 Energy.", "art": _ic_art(6), "target": "self", "special": "bloodletting"}

	# 32. Flex
	card_database["ic_flex"] = {"id": "ic_flex", "name": "Flex", "cost": 0, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Gain 2 Strength.\nAt end of turn,\nlose 2 Strength.", "art": _ic_art(1), "target": "self", "special": "flex"}

	# 33. Limit Break
	card_database["ic_limit_break"] = {"id": "ic_limit_break", "name": "Limit Break", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Double your Strength.\nExhaust.", "art": _ic_art(1), "target": "self", "special": "limit_break", "exhaust": true}

	# 34. Entrench
	card_database["ic_entrench"] = {"id": "ic_entrench", "name": "Entrench", "cost": 2, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Double your Block.", "art": _ic_art(8), "target": "self", "special": "entrench"}

	# 35. Shockwave
	card_database["ic_shockwave"] = {"id": "ic_shockwave", "name": "Shockwave", "cost": 2, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Apply 3 Weak and\n3 Vulnerable to\nALL enemies. Exhaust.", "art": _ic_art(7), "target": "all_enemies", "apply_status": {"type": "weak", "stacks": 3}, "apply_status_2": {"type": "vulnerable", "stacks": 3}, "exhaust": true}

	# 36. Armaments
	card_database["ic_armaments"] = {"id": "ic_armaments", "name": "Armaments", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 5, "description": "Gain 5 Block.", "art": _ic_art(8), "target": "self"}

	# 37. Power Through
	card_database["ic_power_through"] = {"id": "ic_power_through", "name": "Power Through", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 15, "description": "Gain 15 Block.\nAdd 2 Wounds to\nyour hand.", "art": _ic_art(8), "target": "self", "special": "power_through"}

	# 38. Offering
	card_database["ic_offering"] = {"id": "ic_offering", "name": "Offering", "cost": 0, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Lose 6 HP.\nGain 2 Energy.\nDraw 3 cards.\nExhaust.", "art": _ic_art(11), "target": "self", "special": "offering", "exhaust": true}

	# 39. War Cry
	card_database["ic_war_cry"] = {"id": "ic_war_cry", "name": "War Cry", "cost": 0, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Draw 1 card.\nExhaust.", "art": _ic_art(15), "target": "self", "draw": 1, "exhaust": true}

	# 40. Burning Pact
	card_database["ic_burning_pact"] = {"id": "ic_burning_pact", "name": "Burning Pact", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Exhaust 1 card.\nDraw 2 cards.", "art": _ic_art(9), "target": "self", "draw": 2, "special": "burning_pact"}

	# 41. Seeing Red
	card_database["ic_seeing_red"] = {"id": "ic_seeing_red", "name": "Seeing Red", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Gain 2 Energy.\nExhaust.", "art": _ic_art(6), "target": "self", "energy_gain": 2, "exhaust": true}

	# 42. Second Wind
	card_database["ic_second_wind"] = {"id": "ic_second_wind", "name": "Second Wind", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Exhaust all non-Attack\ncards in hand. Gain\n5 Block for each.", "art": _ic_art(8), "target": "self", "special": "second_wind"}

	# 43. Intimidate
	card_database["ic_intimidate"] = {"id": "ic_intimidate", "name": "Intimidate", "cost": 0, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Apply 1 Weak to\nALL enemies. Exhaust.", "art": _ic_art(14), "target": "all_enemies", "apply_status": {"type": "weak", "stacks": 1}, "exhaust": true}

	# 44. Infernal Blade
	card_database["ic_infernal_blade"] = {"id": "ic_infernal_blade", "name": "Infernal Blade", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Add a random Attack\nto your hand. It\ncosts 0. Exhaust.", "art": _ic_art(9), "target": "self", "special": "infernal_blade", "exhaust": true}

	# 45. Dual Wield
	card_database["ic_dual_wield"] = {"id": "ic_dual_wield", "name": "Dual Wield", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Copy an Attack or\nPower card in hand.", "art": _ic_art(0), "target": "self", "special": "dual_wield"}

	# 45a. Ghostly Armor
	card_database["ic_ghostly_armor"] = {"id": "ic_ghostly_armor", "name": "Ghostly Armor", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 10, "description": "Ethereal.\nGain 10 Block.", "art": _ic_art(8), "target": "self", "ethereal": true}

	# 45b. Havoc
	card_database["ic_havoc"] = {"id": "ic_havoc", "name": "Havoc", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Play the top card of\nyour draw pile and\nExhaust it.", "art": _ic_art(6), "target": "self", "special": "havoc", "exhaust": true}

	# 45c. Impervious
	card_database["ic_impervious"] = {"id": "ic_impervious", "name": "Impervious", "cost": 2, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 30, "description": "Gain 30 Block.\nExhaust.", "art": _ic_art(8), "target": "self", "exhaust": true}

	# 45d. Exhume
	card_database["ic_exhume"] = {"id": "ic_exhume", "name": "Exhume", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Put a card from your\nexhaust pile into\nyour hand. Exhaust.", "art": _ic_art(11), "target": "self", "special": "exhume", "exhaust": true}

	# 45e. Sentinel
	card_database["ic_sentinel"] = {"id": "ic_sentinel", "name": "Sentinel", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 5, "description": "Gain 5 Block.\nIf this card is\nExhausted, gain\n2 Energy.", "art": _ic_art(8), "target": "self", "special": "sentinel"}

	# 45f. Spot Weakness
	card_database["ic_spot_weakness"] = {"id": "ic_spot_weakness", "name": "Spot Weakness", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "If the enemy intends\nto attack, gain\n3 Strength.", "art": _ic_art(1), "target": "enemy", "special": "spot_weakness"}

	# 45g. True Grit
	card_database["ic_true_grit"] = {"id": "ic_true_grit", "name": "True Grit", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 7, "description": "Gain 7 Block.\nExhaust a random\ncard in your hand.", "art": _ic_art(8), "target": "self", "special": "true_grit"}

	# 45h. Disarm
	card_database["ic_disarm"] = {"id": "ic_disarm", "name": "Disarm", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Enemy loses 2\nStrength. Exhaust.", "art": _ic_art(1), "target": "enemy", "apply_status": {"type": "strength", "stacks": -2}, "exhaust": true}

	# =========================================================================
	# IRONCLAD POWERS (14 cards)
	# =========================================================================

	# 46. Demon Form
	card_database["ic_demon_form"] = {"id": "ic_demon_form", "name": "Demon Form", "cost": 3, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "At the start of\neach turn, gain 2\nStrength.", "art": _ic_art(11), "target": "self", "power_effect": "demon_form"}

	# 47. Corruption
	card_database["ic_corruption"] = {"id": "ic_corruption", "name": "Corruption", "cost": 3, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Skills cost 0.\nWhenever you play a\nSkill, Exhaust it.", "art": _ic_art(11), "target": "self", "power_effect": "corruption"}

	# 48. Berserk
	card_database["ic_berserk"] = {"id": "ic_berserk", "name": "Berserk", "cost": 0, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Gain 1 Vulnerable.\nAt the start of each\nturn, gain 1 Energy.", "art": _ic_art(11), "target": "self", "power_effect": "berserk"}

	# 49. Feel No Pain
	card_database["ic_feel_no_pain"] = {"id": "ic_feel_no_pain", "name": "Feel No Pain", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever a card is\nExhausted, gain\n3 Block.", "art": _ic_art(11), "target": "self", "power_effect": "feel_no_pain"}

	# 50. Juggernaut
	card_database["ic_juggernaut"] = {"id": "ic_juggernaut", "name": "Juggernaut", "cost": 2, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever you gain\nBlock, deal 5 damage\nto a random enemy.", "art": _ic_art(12), "target": "self", "power_effect": "juggernaut"}

	# 51. Evolve
	card_database["ic_evolve"] = {"id": "ic_evolve", "name": "Evolve", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever you draw a\nStatus card, draw 1.", "art": _ic_art(11), "target": "self", "power_effect": "evolve"}

	# 52. Rage
	card_database["ic_rage"] = {"id": "ic_rage", "name": "Rage", "cost": 0, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever you play an\nAttack this turn,\ngain 3 Block.", "art": _ic_art(11), "target": "self", "power_effect": "rage"}

	# 53. Barricade
	card_database["ic_barricade"] = {"id": "ic_barricade", "name": "Barricade", "cost": 3, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Block is not removed\nat the start of\nyour turn.", "art": _ic_art(12), "target": "self", "power_effect": "barricade"}

	# 54. Inflame
	card_database["ic_inflame"] = {"id": "ic_inflame", "name": "Inflame", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Gain 2 Strength.", "art": _ic_art(11), "target": "self", "apply_self_status": {"type": "strength", "stacks": 2}}

	# 55. Metallicize
	card_database["ic_metallicize"] = {"id": "ic_metallicize", "name": "Metallicize", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "At the end of your\nturn, gain 3 Block.", "art": _ic_art(12), "target": "self", "power_effect": "metallicize"}

	# 56. Brutality
	card_database["ic_brutality"] = {"id": "ic_brutality", "name": "Brutality", "cost": 0, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "At the start of your\nturn, lose 1 HP and\ndraw 1 card.", "art": _ic_art(11), "target": "self", "power_effect": "brutality"}

	# 57. Combust
	card_database["ic_combust"] = {"id": "ic_combust", "name": "Combust", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "At the end of your\nturn, lose 1 HP and\ndeal 5 damage to ALL\nenemies.", "art": _ic_art(9), "target": "self", "power_effect": "combust"}

	# 58. Dark Embrace
	card_database["ic_dark_embrace"] = {"id": "ic_dark_embrace", "name": "Dark Embrace", "cost": 2, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever a card is\nExhausted, draw 1.", "art": _ic_art(11), "target": "self", "power_effect": "dark_embrace"}

	# 59. Rupture
	card_database["ic_rupture"] = {"id": "ic_rupture", "name": "Rupture", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever you lose HP\nfrom a card, gain\n1 Strength.", "art": _ic_art(11), "target": "self", "power_effect": "rupture"}

	# 60. Blood for Blood
	card_database["ic_blood_for_blood"] = {"id": "ic_blood_for_blood", "name": "Blood for Blood", "cost": 4, "type": CardType.ATTACK, "character": "ironclad", "damage": 18, "block": 0, "description": "Costs 1 less for each\ntime you lose HP this\ncombat. Deal 18 dmg.", "art": _ic_art(5), "target": "enemy", "special": "blood_for_blood"}
	# 61. Double Tap
	card_database["ic_double_tap"] = {"id": "ic_double_tap", "name": "Double Tap", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "This turn, your next\nAttack is played twice.", "art": _ic_art(13), "target": "self", "power_effect": "double_tap"}
	# 62. Fire Breathing
	card_database["ic_fire_breathing"] = {"id": "ic_fire_breathing", "name": "Fire Breathing", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever you draw a\nStatus or Curse, deal\n6 damage to ALL.", "art": _ic_art(9), "target": "self", "power_effect": "fire_breathing"}

	# =========================================================================
	# STATUS CARDS (used by various effects)
	# =========================================================================

	card_database["status_wound"] = {"id": "status_wound", "name": "Wound", "cost": -2, "type": CardType.STATUS, "character": "neutral", "damage": 0, "block": 0, "description": "Unplayable.", "art": _ic_art(6), "target": "none", "unplayable": true}

	card_database["status_burn"] = {"id": "status_burn", "name": "Burn", "cost": -2, "type": CardType.STATUS, "character": "neutral", "damage": 0, "block": 0, "description": "Unplayable.\nTake 2 damage at\nend of turn.", "art": _ic_art(9), "target": "none", "unplayable": true, "end_turn_damage": 2}

	card_database["status_dazed"] = {"id": "status_dazed", "name": "Dazed", "cost": -2, "type": CardType.STATUS, "character": "neutral", "damage": 0, "block": 0, "description": "Unplayable.\nEthereal.", "art": _ic_art(10), "target": "none", "unplayable": true, "ethereal": true}

	# =========================================================================
	# SILENT CARDS (14 cards — unchanged)
	# =========================================================================

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
		# STS Ironclad starter: 5 Strike, 4 Defend, 1 Bash
		for i in range(5):
			deck.append("ic_strike")
		for i in range(4):
			deck.append("ic_defend")
		deck.append("ic_bash")
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

# =============================================================================
# UPGRADE SYSTEM
# =============================================================================

func get_upgraded_card(card_id: String) -> Dictionary:
	var base := get_card_data(card_id)
	if base.is_empty():
		return {}
	var overrides := _get_upgrade_overrides()
	if overrides.has(card_id):
		for key in overrides[card_id]:
			if key == "apply_status" or key == "apply_status_2" or key == "apply_self_status":
				base[key] = overrides[card_id][key]
			else:
				base[key] = overrides[card_id][key]
	base["name"] = base["name"] + "+"
	base["upgraded"] = true
	return base

func _get_upgrade_overrides() -> Dictionary:
	return {
		# =====================================================================
		# IRONCLAD ATTACKS
		# =====================================================================
		"ic_strike": {"damage": 9, "description": "Deal 9 damage."},
		"ic_bash": {"damage": 10, "apply_status": {"type": "vulnerable", "stacks": 3}, "description": "Deal 10 damage.\nApply 3 Vulnerable."},
		"ic_iron_wave": {"damage": 7, "block": 7, "description": "Deal 7 damage.\nGain 7 Block."},
		"ic_body_slam": {"cost": 0, "description": "Deal damage equal\nto your Block."},
		"ic_anger": {"damage": 8, "description": "Deal 8 damage.\nAdd a copy to\nyour discard pile."},
		"ic_cleave": {"damage": 11, "description": "Deal 11 damage to\nALL enemies."},
		"ic_twin_strike": {"damage": 7, "description": "Deal 7 damage twice."},
		"ic_wild_strike": {"damage": 17, "description": "Deal 17 damage.\nShuffle a Wound into\nyour draw pile."},
		"ic_pommel_strike": {"damage": 10, "draw": 2, "description": "Deal 10 damage.\nDraw 2 cards."},
		"ic_headbutt": {"damage": 12, "description": "Deal 12 damage."},
		"ic_pummel": {"damage": 2, "times": 5, "description": "Deal 2 damage x5."},
		"ic_uppercut": {"damage": 16, "apply_status": {"type": "vulnerable", "stacks": 2}, "apply_status_2": {"type": "weak", "stacks": 2}, "description": "Deal 16 damage.\nApply 2 Weak.\nApply 2 Vulnerable."},
		"ic_immolate": {"damage": 28, "description": "Deal 28 damage to\nALL enemies.\nAdd a Burn to discard."},
		"ic_fiend_fire": {"damage": 10, "description": "Exhaust your hand.\nDeal 10 damage for\neach card exhausted."},
		"ic_reaper": {"damage": 5, "description": "Deal 5 damage to\nALL enemies.\nHeal for unblocked damage."},
		"ic_heavy_blade": {"damage": 18, "description": "Deal 18 damage.\nStrength applies x5.", "special": "heavy_blade_plus"},
		"ic_thunderclap": {"damage": 7, "description": "Deal 7 damage to\nALL enemies.\nApply 1 Vulnerable."},
		"ic_hemokinesis": {"damage": 20, "description": "Lose 2 HP.\nDeal 20 damage."},
		"ic_reckless_charge": {"damage": 10, "description": "Deal 10 damage.\nShuffle a Dazed into\nyour draw pile."},
		"ic_clash": {"damage": 18, "description": "Can only be played if\nevery card in hand\nis an Attack.\nDeal 18 damage."},
		"ic_perfected_strike": {"damage": 6, "description": "Deal 6 damage. Deals\n3 additional damage\nfor each \"Strike\" card\nin your deck.", "special": "perfected_strike_plus"},
		"ic_bludgeon": {"damage": 42, "description": "Deal 42 damage."},
		"ic_sword_boomerang": {"times": 4, "description": "Deal 3 damage to a\nrandom enemy 4 times."},
		"ic_searing_blow": {"damage": 16, "description": "Deal 16 damage."},
		"ic_whirlwind": {"damage": 8, "description": "Deal 8 damage to ALL\nenemies X times.\n(X = current Energy)"},
		"ic_dropkick": {"damage": 8, "description": "Deal 8 damage.\nIf enemy is Vulnerable:\ngain 1 Energy, draw 1."},
		"ic_carnage": {"damage": 28, "description": "Ethereal.\nDeal 28 damage."},
		"ic_clothesline": {"damage": 14, "apply_status": {"type": "weak", "stacks": 3}, "description": "Deal 14 damage.\nApply 3 Weak."},
		"ic_feed": {"damage": 12, "description": "Deal 12 damage.\nIf this kills, gain\n4 Max HP. Exhaust.", "special": "feed_plus"},
		"ic_rampage": {"damage": 8, "description": "Deal 8 damage.\nIncreases by 8\neach time played.", "special": "rampage_plus"},
		"ic_sever_soul": {"damage": 22, "description": "Exhaust all non-Attack\ncards in hand.\nDeal 22 damage."},

		# =====================================================================
		# IRONCLAD SKILLS
		# =====================================================================
		"ic_defend": {"block": 8, "description": "Gain 8 Block."},
		"ic_shrug_it_off": {"block": 11, "description": "Gain 11 Block.\nDraw 1 card."},
		"ic_flame_barrier": {"block": 16, "description": "Gain 16 Block.\nWhen attacked this turn,\ndeal 6 damage back."},
		"ic_battle_trance": {"draw": 4, "description": "Draw 4 cards."},
		"ic_bloodletting": {"description": "Lose 3 HP.\nGain 3 Energy."},
		"ic_flex": {"description": "Gain 4 Strength.\nAt end of turn,\nlose 4 Strength."},
		"ic_limit_break": {"exhaust": false, "description": "Double your Strength."},
		"ic_entrench": {"cost": 1, "description": "Double your Block."},
		"ic_shockwave": {"apply_status": {"type": "weak", "stacks": 5}, "apply_status_2": {"type": "vulnerable", "stacks": 5}, "description": "Apply 5 Weak and\n5 Vulnerable to\nALL enemies. Exhaust."},
		"ic_armaments": {"block": 5, "description": "Gain 5 Block.\nUpgrade ALL cards\nin hand.", "special": "armaments_plus"},
		"ic_power_through": {"block": 20, "description": "Gain 20 Block.\nAdd 2 Wounds to\nyour hand."},
		"ic_offering": {"draw": 5, "description": "Lose 6 HP.\nGain 2 Energy.\nDraw 5 cards.\nExhaust."},
		"ic_war_cry": {"draw": 2, "description": "Draw 2 cards.\nExhaust."},
		"ic_burning_pact": {"draw": 3, "description": "Exhaust 1 card.\nDraw 3 cards."},
		"ic_seeing_red": {"cost": 0, "description": "Gain 2 Energy.\nExhaust."},
		"ic_second_wind": {"description": "Exhaust all non-Attack\ncards in hand. Gain\n7 Block for each."},
		"ic_intimidate": {"apply_status": {"type": "weak", "stacks": 2}, "description": "Apply 2 Weak to\nALL enemies. Exhaust."},
		"ic_infernal_blade": {"cost": 0, "description": "Add a random Attack\nto your hand. It\ncosts 0. Exhaust."},
		"ic_dual_wield": {"description": "Copy an Attack or\nPower card in hand\n2 times.", "special": "dual_wield_plus"},
		"ic_ghostly_armor": {"block": 13, "description": "Ethereal.\nGain 13 Block."},
		"ic_havoc": {"cost": 0, "description": "Play the top card of\nyour draw pile and\nExhaust it."},
		"ic_impervious": {"block": 40, "description": "Gain 40 Block.\nExhaust."},
		"ic_exhume": {"cost": 0, "description": "Put a card from your\nexhaust pile into\nyour hand. Exhaust."},
		"ic_sentinel": {"block": 8, "description": "Gain 8 Block.\nIf this card is\nExhausted, gain\n3 Energy."},
		"ic_spot_weakness": {"description": "If the enemy intends\nto attack, gain\n4 Strength."},
		"ic_true_grit": {"block": 9, "description": "Gain 9 Block.\nExhaust a card in\nyour hand.", "special": "true_grit_plus"},
		"ic_disarm": {"apply_status": {"type": "strength", "stacks": -3}, "description": "Enemy loses 3\nStrength. Exhaust."},

		# =====================================================================
		# IRONCLAD POWERS
		# =====================================================================
		"ic_demon_form": {"description": "At the start of\neach turn, gain 3\nStrength.", "power_effect": "demon_form_plus"},
		"ic_corruption": {"cost": 2, "description": "Skills cost 0.\nWhenever you play a\nSkill, Exhaust it."},
		"ic_berserk": {"description": "Gain 1 Vulnerable.\nAt the start of each\nturn, gain 2 Energy.", "power_effect": "berserk_plus"},
		"ic_feel_no_pain": {"description": "Whenever a card is\nExhausted, gain\n4 Block.", "power_effect": "feel_no_pain_plus"},
		"ic_juggernaut": {"description": "Whenever you gain\nBlock, deal 7 damage\nto a random enemy.", "power_effect": "juggernaut_plus"},
		"ic_evolve": {"description": "Whenever you draw a\nStatus card, draw 2.", "power_effect": "evolve_plus"},
		"ic_rage": {"description": "Whenever you play an\nAttack this turn,\ngain 5 Block.", "power_effect": "rage_plus"},
		"ic_barricade": {"cost": 2, "description": "Block is not removed\nat the start of\nyour turn."},
		"ic_inflame": {"apply_self_status": {"type": "strength", "stacks": 3}, "description": "Gain 3 Strength."},
		"ic_metallicize": {"description": "At the end of your\nturn, gain 4 Block.", "power_effect": "metallicize_plus"},
		"ic_brutality": {"description": "At the start of your\nturn, lose 1 HP and\ndraw 1 card.\nInnate.", "power_effect": "brutality", "innate": true},
		"ic_combust": {"description": "At the end of your\nturn, lose 1 HP and\ndeal 7 damage to ALL\nenemies.", "power_effect": "combust_plus"},
		"ic_dark_embrace": {"cost": 1, "description": "Whenever a card is\nExhausted, draw 1."},
		"ic_rupture": {"description": "Whenever you lose HP\nfrom a card, gain\n2 Strength.", "power_effect": "rupture_plus"},
		"ic_blood_for_blood": {"damage": 22, "description": "Costs 1 less for each\ntime you lose HP.\nDeal 22 damage."},
		"ic_double_tap": {"description": "This turn, your next\n2 Attacks are played\ntwice."},
		"ic_fire_breathing": {"description": "Whenever you draw a\nStatus or Curse, deal\n10 damage to ALL."},
	}
