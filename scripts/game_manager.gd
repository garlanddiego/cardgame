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

# Cached upgrade overrides from all card packs
var _upgrade_overrides_cache: Dictionary = {}

var _IroncladCards = preload("res://scripts/cards/ironclad_cards.gd")
var _SilentCards = preload("res://scripts/cards/silent_cards.gd")
var _NeutralCards = preload("res://scripts/cards/neutral_cards.gd")
var _NewCards = preload("res://scripts/cards/new_cards.gd")
var _BloodfiendCards = preload("res://scripts/cards/bloodfiend_cards.gd")
var _FireMageCards = preload("res://scripts/cards/fire_mage_cards.gd")

func _ready() -> void:
	_init_character_data()
	# Register pluggable card packs
	_register_card_pack(_IroncladCards)
	_register_card_pack(_SilentCards)
	_register_card_pack(_NeutralCards)
	_register_card_pack(_NewCards)
	_register_card_pack(_BloodfiendCards)
	_register_card_pack(_FireMageCards)
	# Build unified database from all packs
	_build_card_database()
	# Export cards JSON for external tools (simulator)
	export_all_cards_json()

func _register_card_pack(pack_class) -> void:
	var cards: Dictionary = pack_class.get_cards()
	var upgrades: Dictionary = pack_class.get_upgrade_overrides()
	card_database.merge(cards)
	_upgrade_overrides_cache.merge(upgrades)

const CUSTOM_CARDS_PATH := "user://custom_cards.json"

func _build_card_database() -> void:
	# Set defaults for all cards
	for card_id in card_database:
		if not card_database[card_id].has("version"):
			card_database[card_id]["version"] = "old"
		if not card_database[card_id].has("status"):
			card_database[card_id]["status"] = "active"
		# hero_target: every card with a character belongs to a hero
		# Status cards (wound/burn/dazed) have no character, so they're excluded
		var card_char: String = card_database[card_id].get("character", "")
		if card_char != "" and not card_database[card_id].has("hero_target"):
			card_database[card_id]["hero_target"] = "self"
	# Load and merge locally saved card modifications/additions
	_load_custom_cards()

func _load_custom_cards() -> void:
	if not FileAccess.file_exists(CUSTOM_CARDS_PATH):
		return
	var file = FileAccess.open(CUSTOM_CARDS_PATH, FileAccess.READ)
	if file == null:
		return
	var json_text: String = file.get_as_text()
	file.close()
	var json = JSON.new()
	var err = json.parse(json_text)
	if err != OK:
		push_warning("Failed to parse custom cards: %s" % json.get_error_message())
		return
	var custom_data = json.data
	if custom_data is Dictionary:
		for card_id in custom_data:
			card_database[card_id] = custom_data[card_id]

const CARDS_EXPORT_PATH := "res://tools/cards_export.json"

func export_all_cards_json() -> void:
	## Export the full card database to JSON for use by external tools (simulator, etc.)
	var export_data: Dictionary = {}
	for card_id in card_database:
		var card = card_database[card_id].duplicate()
		# Convert enums to ints for JSON compatibility
		if card.has("type") and card["type"] is int:
			pass  # Already int
		export_data[card_id] = card
	# Also export upgrade overrides
	var full_export: Dictionary = {
		"cards": export_data,
		"upgrades": _upgrade_overrides_cache,
	}
	var file = FileAccess.open(CARDS_EXPORT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(full_export, "\t"))
		file.close()
		print("Exported %d cards to %s" % [export_data.size(), CARDS_EXPORT_PATH])

func save_custom_cards() -> void:
	## Save all non-code cards (custom/modified) to local JSON file.
	## Cards whose data differs from code-defined versions are saved.
	var custom_cards: Dictionary = {}
	# Rebuild code-defined cards to compare
	var code_cards: Dictionary = {}
	for pack in [_IroncladCards, _SilentCards, _NeutralCards, _NewCards, _BloodfiendCards, _FireMageCards]:
		code_cards.merge(pack.get_cards())
	# Find cards that are new or modified
	for card_id in card_database:
		if not code_cards.has(card_id):
			# New card (not in any pack)
			custom_cards[card_id] = card_database[card_id]
		elif str(card_database[card_id]) != str(code_cards[card_id]):
			# Modified card
			custom_cards[card_id] = card_database[card_id]
	# Write to file
	var file = FileAccess.open(CUSTOM_CARDS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to save custom cards")
		return
	file.store_string(JSON.stringify(custom_cards, "\t"))
	file.close()

func _init_character_data() -> void:
	character_data = {
		"ironclad": {
			"name": "Ironclad",
			"max_hp": 70,
			"color": Color(0.8, 0.2, 0.2),
			"sprite": "res://assets/img/ironclad.png",
			"fallen_sprite": "res://assets/img/ironclad_fallen.png",
			"description": "A powerful warrior who uses strength and heavy attacks."
		},
		"silent": {
			"name": "Silent",
			"max_hp": 60,
			"color": Color(0.2, 0.7, 0.3),
			"sprite": "res://assets/img/silent.png",
			"fallen_sprite": "res://assets/img/silent_fallen.png",
			"description": "A deadly hunter who uses agility and poison."
		},
		"bloodfiend": {
			"name": "Blood Fiend",
			"max_hp": 65,
			"color": Color(0.7, 0.1, 0.2),
			"sprite": "res://assets/img/bloodfiend.png",
			"fallen_sprite": "res://assets/img/bloodfiend_fallen.png",
			"description": "A blood-crazed berserker who sacrifices HP for devastating power."
		},
		"fire_mage": {
			"name": "Fire Mage",
			"max_hp": 60,
			"color": Color(0.9, 0.4, 0.1),
			"sprite": "res://assets/img/fire_mage.png",
			"fallen_sprite": "res://assets/img/fire_mage_fallen.png",
			"description": "A pyromancer who consumes cards to fuel devastating spells."
		}
	}

func _ic_art(_index: int) -> String:
	return ""

func _init_card_database() -> void:
	# Legacy — card database is now built from card packs in _ready()
	pass

func _legacy_init_card_database() -> void:
	# =========================================================================
	# IRONCLAD ATTACKS (26 cards)
	# =========================================================================

	# 1. Strike
	card_database["ic_strike"] = {"id": "ic_strike", "name": "Strike", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 6, "block": 0, "description": "Deal 6 damage.", "art": _ic_art(0), "target": "enemy", "actions": [{"type": "damage"}]}

	# 2. Bash
	card_database["ic_bash"] = {"id": "ic_bash", "name": "Bash", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 8, "block": 0, "description": "Deal 8 damage.\nApply 2 Vulnerable.", "art": _ic_art(1), "target": "enemy", "apply_status": {"type": "vulnerable", "stacks": 2}, "actions": [{"type": "damage"}, {"type": "apply_status", "source": "apply_status"}]}

	# 3. Iron Wave
	card_database["ic_iron_wave"] = {"id": "ic_iron_wave", "name": "Iron Wave", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 5, "block": 5, "description": "Deal 5 damage.\nGain 5 Block.", "art": _ic_art(2), "target": "enemy", "actions": [{"type": "damage"}, {"type": "block"}]}

	# 4. Body Slam
	card_database["ic_body_slam"] = {"id": "ic_body_slam", "name": "Body Slam", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 0, "block": 0, "description": "Deal damage equal\nto your Block.", "art": _ic_art(3), "target": "enemy", "actions": [{"type": "call", "fn": "body_slam"}]}

	# 5. Anger
	card_database["ic_anger"] = {"id": "ic_anger", "name": "Anger", "cost": 0, "type": CardType.ATTACK, "character": "ironclad", "damage": 6, "block": 0, "description": "Deal 6 damage.\nAdd a copy to\nyour discard pile.", "art": _ic_art(0), "target": "enemy", "actions": [{"type": "damage"}, {"type": "copy_to_discard", "card_id": "ic_anger"}]}

	# 6. Cleave
	card_database["ic_cleave"] = {"id": "ic_cleave", "name": "Cleave", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 8, "block": 0, "description": "Deal 8 damage to\nALL enemies.", "art": _ic_art(7), "target": "all_enemies", "actions": [{"type": "damage_all"}]}

	# 7. Twin Strike
	card_database["ic_twin_strike"] = {"id": "ic_twin_strike", "name": "Twin Strike", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 5, "block": 0, "description": "Deal 5 damage twice.", "art": _ic_art(0), "target": "enemy", "times": 2, "actions": [{"type": "damage"}]}

	# 8. Wild Strike
	card_database["ic_wild_strike"] = {"id": "ic_wild_strike", "name": "Wild Strike", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 12, "block": 0, "description": "Deal 12 damage.\nShuffle a Wound into\nyour draw pile.", "art": _ic_art(6), "target": "enemy", "actions": [{"type": "damage"}, {"type": "add_card_to_draw", "card_id": "status_wound"}]}

	# 9. Pommel Strike
	card_database["ic_pommel_strike"] = {"id": "ic_pommel_strike", "name": "Pommel Strike", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 9, "block": 0, "description": "Deal 9 damage.\nDraw 1 card.", "art": _ic_art(0), "target": "enemy", "draw": 1, "actions": [{"type": "damage"}, {"type": "draw"}]}

	# 10. Headbutt
	card_database["ic_headbutt"] = {"id": "ic_headbutt", "name": "Headbutt", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 9, "block": 0, "description": "Deal 9 damage.", "art": _ic_art(5), "target": "enemy", "actions": [{"type": "damage"}]}

	# 11. Pummel
	card_database["ic_pummel"] = {"id": "ic_pummel", "name": "Pummel", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 2, "block": 0, "description": "Deal 2 damage x4.", "art": _ic_art(13), "target": "enemy", "times": 4, "actions": [{"type": "damage"}]}

	# 12. Uppercut
	card_database["ic_uppercut"] = {"id": "ic_uppercut", "name": "Uppercut", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 13, "block": 0, "description": "Deal 13 damage.\nApply 1 Weak.\nApply 1 Vulnerable.", "art": _ic_art(1), "target": "enemy", "apply_status": {"type": "vulnerable", "stacks": 1}, "apply_status_2": {"type": "weak", "stacks": 1}, "actions": [{"type": "damage"}, {"type": "apply_status", "source": "apply_status"}, {"type": "apply_status", "source": "apply_status_2"}]}

	# 13. Immolate
	card_database["ic_immolate"] = {"id": "ic_immolate", "name": "Immolate", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 21, "block": 0, "description": "Deal 21 damage to\nALL enemies.\nAdd a Burn to discard.", "art": _ic_art(9), "target": "all_enemies", "actions": [{"type": "damage_all"}, {"type": "add_card_to_discard", "card_id": "status_burn"}]}

	# 14. Fiend Fire
	card_database["ic_fiend_fire"] = {"id": "ic_fiend_fire", "name": "Fiend Fire", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 7, "block": 0, "description": "Exhaust your hand.\nDeal 7 damage for\neach card exhausted.", "art": _ic_art(11), "target": "enemy", "exhaust": true, "actions": [{"type": "call", "fn": "fiend_fire"}]}

	# 15. Reaper
	card_database["ic_reaper"] = {"id": "ic_reaper", "name": "Reaper", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 4, "block": 0, "description": "Deal 4 damage to\nALL enemies.\nHeal for unblocked damage.", "art": _ic_art(11), "target": "all_enemies", "exhaust": true, "actions": [{"type": "call", "fn": "reaper"}]}

	# 16. Heavy Blade
	card_database["ic_heavy_blade"] = {"id": "ic_heavy_blade", "name": "Heavy Blade", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 14, "block": 0, "description": "Deal 14 damage.\nStrength applies x3.", "art": _ic_art(1), "target": "enemy", "str_mult": 3, "actions": [{"type": "call", "fn": "heavy_blade"}]}

	# 17. Thunderclap
	card_database["ic_thunderclap"] = {"id": "ic_thunderclap", "name": "Thunderclap", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 4, "block": 0, "description": "Deal 4 damage to\nALL enemies.\nApply 1 Vulnerable.", "art": _ic_art(7), "target": "all_enemies", "apply_status": {"type": "vulnerable", "stacks": 1}, "actions": [{"type": "damage_all"}, {"type": "apply_status", "source": "apply_status"}]}

	# 18. Hemokinesis
	card_database["ic_hemokinesis"] = {"id": "ic_hemokinesis", "name": "Hemokinesis", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 15, "block": 0, "description": "Lose 2 HP.\nDeal 15 damage.", "art": _ic_art(6), "target": "enemy", "actions": [{"type": "self_damage", "value": 2}, {"type": "damage"}]}

	# 19. Reckless Charge
	card_database["ic_reckless_charge"] = {"id": "ic_reckless_charge", "name": "Reckless Charge", "cost": 0, "type": CardType.ATTACK, "character": "ironclad", "damage": 7, "block": 0, "description": "Deal 7 damage.\nShuffle a Dazed into\nyour draw pile.", "art": _ic_art(6), "target": "enemy", "actions": [{"type": "damage"}, {"type": "add_card_to_draw", "card_id": "status_dazed"}]}

	# 20. Clash
	card_database["ic_clash"] = {"id": "ic_clash", "name": "Clash", "cost": 0, "type": CardType.ATTACK, "character": "ironclad", "damage": 14, "block": 0, "description": "Can only be played if\nevery card in hand\nis an Attack.\nDeal 14 damage.", "art": _ic_art(0), "target": "enemy", "special": "clash", "actions": [{"type": "damage"}]}

	# 21. Perfected Strike
	card_database["ic_perfected_strike"] = {"id": "ic_perfected_strike", "name": "Perfected Strike", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 6, "block": 0, "description": "Deal 6 damage. Deals\n2 additional damage\nfor each \"Strike\" card\nin your deck.", "art": _ic_art(0), "target": "enemy", "strike_bonus": 2, "actions": [{"type": "call", "fn": "perfected_strike"}]}

	# 22. Bludgeon
	card_database["ic_bludgeon"] = {"id": "ic_bludgeon", "name": "Bludgeon", "cost": 3, "type": CardType.ATTACK, "character": "ironclad", "damage": 32, "block": 0, "description": "Deal 32 damage.", "art": _ic_art(12), "target": "enemy", "actions": [{"type": "damage"}]}

	# 23. Sword Boomerang
	card_database["ic_sword_boomerang"] = {"id": "ic_sword_boomerang", "name": "Sword Boomerang", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 3, "block": 0, "description": "Deal 3 damage to a\nrandom enemy 3 times.", "art": _ic_art(0), "target": "random_enemy", "times": 3, "actions": [{"type": "damage"}]}

	# 24. Searing Blow
	card_database["ic_searing_blow"] = {"id": "ic_searing_blow", "name": "Searing Blow", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 12, "block": 0, "description": "Deal 12 damage.", "art": _ic_art(4), "target": "enemy", "actions": [{"type": "damage"}]}

	# 25. Whirlwind
	card_database["ic_whirlwind"] = {"id": "ic_whirlwind", "name": "Whirlwind", "cost": -1, "type": CardType.ATTACK, "character": "ironclad", "damage": 5, "block": 0, "description": "Deal 5 damage to ALL\nenemies X times.\n(X = current Energy)", "art": _ic_art(7), "target": "all_enemies", "actions": [{"type": "call", "fn": "whirlwind"}]}

	# 26. Dropkick
	card_database["ic_dropkick"] = {"id": "ic_dropkick", "name": "Dropkick", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 5, "block": 0, "description": "Deal 5 damage.\nIf enemy is Vulnerable:\ngain 1 Energy, draw 1.", "art": _ic_art(5), "target": "enemy", "actions": [{"type": "call", "fn": "dropkick"}]}

	# 27a. Carnage
	card_database["ic_carnage"] = {"id": "ic_carnage", "name": "Carnage", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 20, "block": 0, "description": "Ethereal.\nDeal 20 damage.", "art": _ic_art(6), "target": "enemy", "ethereal": true, "actions": [{"type": "damage"}]}

	# 27b. Clothesline
	card_database["ic_clothesline"] = {"id": "ic_clothesline", "name": "Clothesline", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 12, "block": 0, "description": "Deal 12 damage.\nApply 2 Weak.", "art": _ic_art(1), "target": "enemy", "apply_status": {"type": "weak", "stacks": 2}, "actions": [{"type": "damage"}, {"type": "apply_status", "source": "apply_status"}]}

	# 27c. Feed
	card_database["ic_feed"] = {"id": "ic_feed", "name": "Feed", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 10, "block": 0, "description": "Deal 10 damage.\nIf this kills, gain\n3 Max HP. Exhaust.", "art": _ic_art(6), "target": "enemy", "exhaust": true, "max_hp_gain": 3, "actions": [{"type": "call", "fn": "feed"}]}

	# 27d. Rampage
	card_database["ic_rampage"] = {"id": "ic_rampage", "name": "Rampage", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 8, "block": 0, "description": "Deal 8 damage.\nIncreases by 5\neach time played.", "art": _ic_art(0), "target": "enemy", "rampage_inc": 5, "actions": [{"type": "call", "fn": "rampage"}]}

	# 27e. Sever Soul
	card_database["ic_sever_soul"] = {"id": "ic_sever_soul", "name": "Sever Soul", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 16, "block": 0, "description": "Exhaust all non-Attack\ncards in hand.\nDeal 16 damage.", "art": _ic_art(0), "target": "enemy", "actions": [{"type": "call", "fn": "sever_soul"}]}

	# =========================================================================
	# IRONCLAD SKILLS (27 cards)
	# =========================================================================

	# 27. Defend
	card_database["ic_defend"] = {"id": "ic_defend", "name": "Defend", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 5, "description": "Gain 5 Block.", "art": _ic_art(8), "target": "self", "actions": [{"type": "block"}]}

	# 28. Shrug It Off
	card_database["ic_shrug_it_off"] = {"id": "ic_shrug_it_off", "name": "Shrug It Off", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 8, "description": "Gain 8 Block.\nDraw 1 card.", "art": _ic_art(8), "target": "self", "draw": 1, "actions": [{"type": "block"}, {"type": "draw"}]}

	# 29. Flame Barrier
	card_database["ic_flame_barrier"] = {"id": "ic_flame_barrier", "name": "Flame Barrier", "cost": 2, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 12, "description": "Gain 12 Block.\nWhen attacked this turn,\ndeal 4 damage back.", "art": _ic_art(9), "target": "self", "power_effect": "flame_barrier", "actions": [{"type": "block"}, {"type": "power_effect", "power": "flame_barrier"}]}

	# 30. Battle Trance
	card_database["ic_battle_trance"] = {"id": "ic_battle_trance", "name": "Battle Trance", "cost": 0, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Draw 3 cards.", "art": _ic_art(10), "target": "self", "draw": 3, "actions": [{"type": "draw"}]}

	# 31. Bloodletting
	card_database["ic_bloodletting"] = {"id": "ic_bloodletting", "name": "Bloodletting", "cost": 0, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Lose 3 HP.\nGain 2 Energy.", "art": _ic_art(6), "target": "self", "actions": [{"type": "self_damage", "value": 3}, {"type": "gain_energy", "value": 2}]}

	# 32. Flex
	card_database["ic_flex"] = {"id": "ic_flex", "name": "Flex", "cost": 0, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Gain 2 Strength.\nAt end of turn,\nlose 2 Strength.", "art": _ic_art(1), "target": "self", "flex_stacks": 2, "actions": [{"type": "call", "fn": "flex"}]}

	# 33. Limit Break
	card_database["ic_limit_break"] = {"id": "ic_limit_break", "name": "Limit Break", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Double your Strength.\nExhaust.", "art": _ic_art(1), "target": "self", "exhaust": true, "actions": [{"type": "call", "fn": "limit_break"}]}

	# 34. Entrench
	card_database["ic_entrench"] = {"id": "ic_entrench", "name": "Entrench", "cost": 2, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Double your Block.", "art": _ic_art(8), "target": "self", "actions": [{"type": "call", "fn": "entrench"}]}

	# 35. Shockwave
	card_database["ic_shockwave"] = {"id": "ic_shockwave", "name": "Shockwave", "cost": 2, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Apply 3 Weak and\n3 Vulnerable to\nALL enemies. Exhaust.", "art": _ic_art(7), "target": "all_enemies", "apply_status": {"type": "weak", "stacks": 3}, "apply_status_2": {"type": "vulnerable", "stacks": 3}, "exhaust": true, "actions": [{"type": "apply_status", "source": "apply_status"}, {"type": "apply_status", "source": "apply_status_2"}]}

	# 36. Armaments
	card_database["ic_armaments"] = {"id": "ic_armaments", "name": "Armaments", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 5, "description": "Gain 5 Block.", "art": _ic_art(8), "target": "self", "actions": [{"type": "block"}]}

	# 37. Power Through
	card_database["ic_power_through"] = {"id": "ic_power_through", "name": "Power Through", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 15, "description": "Gain 15 Block.\nAdd 2 Wounds to\nyour hand.", "art": _ic_art(8), "target": "self", "actions": [{"type": "block"}, {"type": "add_card_to_hand", "card_id": "status_wound", "count": 2}]}

	# 38. Offering
	card_database["ic_offering"] = {"id": "ic_offering", "name": "Offering", "cost": 0, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Lose 6 HP.\nGain 2 Energy.\nDraw 3 cards.\nExhaust.", "art": _ic_art(11), "target": "self", "exhaust": true, "actions": [{"type": "self_damage", "value": 6}, {"type": "gain_energy", "value": 2}, {"type": "draw", "value": 3}]}

	# 39. War Cry
	card_database["ic_war_cry"] = {"id": "ic_war_cry", "name": "War Cry", "cost": 0, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Draw 1 card.\nExhaust.", "art": _ic_art(15), "target": "self", "draw": 1, "exhaust": true, "actions": [{"type": "draw"}]}

	# 40. Burning Pact
	card_database["ic_burning_pact"] = {"id": "ic_burning_pact", "name": "Burning Pact", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Exhaust 1 card.\nDraw 2 cards.", "art": _ic_art(9), "target": "self", "draw": 2, "actions": [{"type": "call", "fn": "burning_pact"}]}

	# 41. Seeing Red
	card_database["ic_seeing_red"] = {"id": "ic_seeing_red", "name": "Seeing Red", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Gain 2 Energy.\nExhaust.", "art": _ic_art(6), "target": "self", "energy_gain": 2, "exhaust": true, "actions": [{"type": "gain_energy", "value": 2}]}

	# 42. Second Wind
	card_database["ic_second_wind"] = {"id": "ic_second_wind", "name": "Second Wind", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Exhaust all non-Attack\ncards in hand. Gain\n5 Block for each.", "art": _ic_art(8), "target": "self", "block_per": 5, "actions": [{"type": "call", "fn": "second_wind"}]}

	# 43. Intimidate
	card_database["ic_intimidate"] = {"id": "ic_intimidate", "name": "Intimidate", "cost": 0, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Apply 1 Weak to\nALL enemies. Exhaust.", "art": _ic_art(14), "target": "all_enemies", "apply_status": {"type": "weak", "stacks": 1}, "exhaust": true, "actions": [{"type": "apply_status", "source": "apply_status"}]}

	# 44. Infernal Blade
	card_database["ic_infernal_blade"] = {"id": "ic_infernal_blade", "name": "Infernal Blade", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Add a random Attack\nto your hand. It\ncosts 0. Exhaust.", "art": _ic_art(9), "target": "self", "exhaust": true, "actions": [{"type": "call", "fn": "infernal_blade"}]}

	# 45. Dual Wield
	card_database["ic_dual_wield"] = {"id": "ic_dual_wield", "name": "Dual Wield", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Copy an Attack or\nPower card in hand.", "art": _ic_art(0), "target": "self", "copies": 1, "actions": [{"type": "call", "fn": "dual_wield"}]}

	# 45a. Ghostly Armor
	card_database["ic_ghostly_armor"] = {"id": "ic_ghostly_armor", "name": "Ghostly Armor", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 10, "description": "Ethereal.\nGain 10 Block.", "art": _ic_art(8), "target": "self", "ethereal": true, "actions": [{"type": "block"}]}

	# 45b. Havoc
	card_database["ic_havoc"] = {"id": "ic_havoc", "name": "Havoc", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Play the top card of\nyour draw pile and\nExhaust it.", "art": _ic_art(6), "target": "self", "exhaust": true, "actions": [{"type": "call", "fn": "havoc"}]}

	# 45c. Impervious
	card_database["ic_impervious"] = {"id": "ic_impervious", "name": "Impervious", "cost": 2, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 30, "description": "Gain 30 Block.\nExhaust.", "art": _ic_art(8), "target": "self", "exhaust": true, "actions": [{"type": "block"}]}

	# 45d. Exhume
	card_database["ic_exhume"] = {"id": "ic_exhume", "name": "Exhume", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Put a card from your\nexhaust pile into\nyour hand. Exhaust.", "art": _ic_art(11), "target": "self", "exhaust": true, "actions": [{"type": "call", "fn": "exhume"}]}

	# 45e. Sentinel
	card_database["ic_sentinel"] = {"id": "ic_sentinel", "name": "Sentinel", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 5, "description": "Gain 5 Block.\nIf this card is\nExhausted, gain\n2 Energy.", "art": _ic_art(8), "target": "self", "actions": [{"type": "block"}]}

	# 45f. Spot Weakness
	card_database["ic_spot_weakness"] = {"id": "ic_spot_weakness", "name": "Spot Weakness", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "If the enemy intends\nto attack, gain\n3 Strength.", "art": _ic_art(1), "target": "enemy", "spot_str": 3, "actions": [{"type": "call", "fn": "spot_weakness"}]}

	# 45g. True Grit
	card_database["ic_true_grit"] = {"id": "ic_true_grit", "name": "True Grit", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 7, "description": "Gain 7 Block.\nExhaust a random\ncard in your hand.", "art": _ic_art(8), "target": "self", "actions": [{"type": "block"}, {"type": "call", "fn": "true_grit"}]}

	# 45h. Disarm
	card_database["ic_disarm"] = {"id": "ic_disarm", "name": "Disarm", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Enemy loses 2\nStrength. Exhaust.", "art": _ic_art(1), "target": "enemy", "apply_status": {"type": "strength", "stacks": -2}, "exhaust": true, "actions": [{"type": "apply_status", "source": "apply_status"}]}

	# =========================================================================
	# IRONCLAD POWERS (14 cards)
	# =========================================================================

	# 46. Demon Form
	card_database["ic_demon_form"] = {"id": "ic_demon_form", "name": "Demon Form", "cost": 3, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "At the start of\neach turn, gain 2\nStrength.", "art": _ic_art(11), "target": "self", "power_effect": "demon_form", "actions": [{"type": "power_effect", "power": "demon_form"}]}

	# 47. Corruption
	card_database["ic_corruption"] = {"id": "ic_corruption", "name": "Corruption", "cost": 3, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Skills cost 0.\nWhenever you play a\nSkill, Exhaust it.", "art": _ic_art(11), "target": "self", "power_effect": "corruption", "actions": [{"type": "power_effect", "power": "corruption"}]}

	# 48. Berserk
	card_database["ic_berserk"] = {"id": "ic_berserk", "name": "Berserk", "cost": 0, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Gain 1 Vulnerable.\nAt the start of each\nturn, gain 1 Energy.", "art": _ic_art(11), "target": "self", "power_effect": "berserk", "actions": [{"type": "power_effect", "power": "berserk"}]}

	# 49. Feel No Pain
	card_database["ic_feel_no_pain"] = {"id": "ic_feel_no_pain", "name": "Feel No Pain", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever a card is\nExhausted, gain\n3 Block.", "art": _ic_art(11), "target": "self", "power_effect": "feel_no_pain", "actions": [{"type": "power_effect", "power": "feel_no_pain"}]}

	# 50. Juggernaut
	card_database["ic_juggernaut"] = {"id": "ic_juggernaut", "name": "Juggernaut", "cost": 2, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever you gain\nBlock, deal 5 damage\nto a random enemy.", "art": _ic_art(12), "target": "self", "power_effect": "juggernaut", "actions": [{"type": "power_effect", "power": "juggernaut"}]}

	# 51. Evolve
	card_database["ic_evolve"] = {"id": "ic_evolve", "name": "Evolve", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever you draw a\nStatus card, draw 1.", "art": _ic_art(11), "target": "self", "power_effect": "evolve", "actions": [{"type": "power_effect", "power": "evolve"}]}

	# 52. Rage
	card_database["ic_rage"] = {"id": "ic_rage", "name": "Rage", "cost": 0, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever you play an\nAttack this turn,\ngain 3 Block.", "art": _ic_art(11), "target": "self", "power_effect": "rage", "actions": [{"type": "power_effect", "power": "rage"}]}

	# 53. Barricade
	card_database["ic_barricade"] = {"id": "ic_barricade", "name": "Barricade", "cost": 3, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Block is not removed\nat the start of\nyour turn.", "art": _ic_art(12), "target": "self", "power_effect": "barricade", "actions": [{"type": "power_effect", "power": "barricade"}]}

	# 54. Inflame
	card_database["ic_inflame"] = {"id": "ic_inflame", "name": "Inflame", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Gain 2 Strength.", "art": _ic_art(11), "target": "self", "apply_self_status": {"type": "strength", "stacks": 2}, "actions": [{"type": "apply_self_status", "status": "strength", "stacks": 2}]}

	# 55. Metallicize
	card_database["ic_metallicize"] = {"id": "ic_metallicize", "name": "Metallicize", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "At the end of your\nturn, gain 3 Block.", "art": _ic_art(12), "target": "self", "power_effect": "metallicize", "actions": [{"type": "power_effect", "power": "metallicize"}]}

	# 56. Brutality
	card_database["ic_brutality"] = {"id": "ic_brutality", "name": "Brutality", "cost": 0, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "At the start of your\nturn, lose 1 HP and\ndraw 1 card.", "art": _ic_art(11), "target": "self", "power_effect": "brutality", "actions": [{"type": "power_effect", "power": "brutality"}]}

	# 57. Combust
	card_database["ic_combust"] = {"id": "ic_combust", "name": "Combust", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "At the end of your\nturn, lose 1 HP and\ndeal 5 damage to ALL\nenemies.", "art": _ic_art(9), "target": "self", "power_effect": "combust", "actions": [{"type": "power_effect", "power": "combust"}]}

	# 58. Dark Embrace
	card_database["ic_dark_embrace"] = {"id": "ic_dark_embrace", "name": "Dark Embrace", "cost": 2, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever a card is\nExhausted, draw 1.", "art": _ic_art(11), "target": "self", "power_effect": "dark_embrace", "actions": [{"type": "power_effect", "power": "dark_embrace"}]}

	# 59. Rupture
	card_database["ic_rupture"] = {"id": "ic_rupture", "name": "Rupture", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever you lose HP\nfrom a card, gain\n1 Strength.", "art": _ic_art(11), "target": "self", "power_effect": "rupture", "actions": [{"type": "power_effect", "power": "rupture"}]}

	# 60. Blood for Blood
	card_database["ic_blood_for_blood"] = {"id": "ic_blood_for_blood", "name": "Blood for Blood", "cost": 4, "type": CardType.ATTACK, "character": "ironclad", "damage": 18, "block": 0, "description": "Costs 1 less for each\ntime you lose HP this\ncombat. Deal 18 dmg.", "art": _ic_art(5), "target": "enemy", "actions": [{"type": "call", "fn": "blood_for_blood"}]}
	# 61. Double Tap
	card_database["ic_double_tap"] = {"id": "ic_double_tap", "name": "Double Tap", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "This turn, your next\nAttack is played twice.", "art": _ic_art(13), "target": "self", "power_effect": "double_tap", "actions": [{"type": "power_effect", "power": "double_tap"}]}
	# 62. Fire Breathing
	card_database["ic_fire_breathing"] = {"id": "ic_fire_breathing", "name": "Fire Breathing", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever you draw a\nStatus or Curse, deal\n6 damage to ALL.", "art": _ic_art(9), "target": "self", "power_effect": "fire_breathing", "actions": [{"type": "power_effect", "power": "fire_breathing"}]}

	# =========================================================================
	# STATUS CARDS (used by various effects)
	# =========================================================================

	card_database["status_wound"] = {"id": "status_wound", "name": "Wound", "cost": -2, "type": CardType.STATUS, "character": "neutral", "damage": 0, "block": 0, "description": "Unplayable.", "art": _ic_art(6), "target": "none", "unplayable": true}

	card_database["status_burn"] = {"id": "status_burn", "name": "Burn", "cost": -2, "type": CardType.STATUS, "character": "neutral", "damage": 0, "block": 0, "description": "Unplayable.\nTake 2 damage at\nend of turn.", "art": _ic_art(9), "target": "none", "unplayable": true, "end_turn_damage": 2}

	card_database["status_dazed"] = {"id": "status_dazed", "name": "Dazed", "cost": -2, "type": CardType.STATUS, "character": "neutral", "damage": 0, "block": 0, "description": "Unplayable.\nEthereal.", "art": _ic_art(10), "target": "none", "unplayable": true, "ethereal": true}

	# =========================================================================
	# SILENT CARDS (75 cards)
	# =========================================================================

	# --- Basic Cards ---
	# 1. Strike
	card_database["si_strike"] = {"id": "si_strike", "name": "Strike", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 6, "block": 0, "description": "Deal 6 damage.", "art": "", "target": "enemy", "actions": [{"type": "damage"}]}
	# 2. Defend
	card_database["si_defend"] = {"id": "si_defend", "name": "Defend", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 5, "description": "Gain 5 Block.", "art": "", "target": "self", "actions": [{"type": "block"}]}
	# 3. Neutralize
	card_database["si_neutralize"] = {"id": "si_neutralize", "name": "Neutralize", "cost": 0, "type": CardType.ATTACK, "character": "silent", "damage": 3, "block": 0, "description": "Deal 3 damage.\nApply 1 Weak.", "art": "", "target": "enemy", "apply_status": {"type": "weak", "stacks": 1}, "actions": [{"type": "damage"}, {"type": "apply_status", "source": "apply_status"}]}
	# 4. Survivor
	card_database["si_survivor"] = {"id": "si_survivor", "name": "Survivor", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 8, "description": "Gain 8 Block.\nDiscard 1 card.", "art": "", "target": "self", "discard": 1, "actions": [{"type": "block"}]}

	# --- Common Attacks ---
	# 5. Slice
	card_database["si_slice"] = {"id": "si_slice", "name": "Slice", "cost": 0, "type": CardType.ATTACK, "character": "silent", "damage": 6, "block": 0, "description": "Deal 6 damage.", "art": "", "target": "enemy", "actions": [{"type": "damage"}]}
	# 6. Dagger Spray
	card_database["si_dagger_spray"] = {"id": "si_dagger_spray", "name": "Dagger Spray", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 4, "block": 0, "description": "Deal 4 damage to ALL\nenemies twice.", "art": "", "target": "all_enemies", "times": 2, "actions": [{"type": "damage_all"}]}
	# 7. Dagger Throw
	card_database["si_dagger_throw"] = {"id": "si_dagger_throw", "name": "Dagger Throw", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 9, "block": 0, "description": "Deal 9 damage.\nDraw 1, Discard 1.", "art": "", "target": "enemy", "draw": 1, "discard": 1, "actions": [{"type": "damage"}, {"type": "draw"}]}
	# 8. Flick-Flack
	card_database["si_flick_flack"] = {"id": "si_flick_flack", "name": "Flick-Flack", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 7, "block": 0, "description": "Sly. Deal 7 damage\nto ALL enemies.", "art": "", "target": "all_enemies", "special": "sly", "actions": [{"type": "damage_all"}]}
	# 9. Leading Strike
	card_database["si_leading_strike"] = {"id": "si_leading_strike", "name": "Leading Strike", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 7, "block": 0, "description": "Deal 7 damage.\nAdd 1 Shiv to hand.", "art": "", "target": "enemy", "actions": [{"type": "damage"}, {"type": "add_shiv", "value": 1}]}
	# 10. Poisoned Stab
	card_database["si_poisoned_stab"] = {"id": "si_poisoned_stab", "name": "Poisoned Stab", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 6, "block": 0, "description": "Deal 6 damage.\nApply 3 Poison.", "art": "", "target": "enemy", "apply_status": {"type": "poison", "stacks": 3}, "actions": [{"type": "damage"}, {"type": "apply_status", "source": "apply_status"}]}
	# 11. Sucker Punch
	card_database["si_sucker_punch"] = {"id": "si_sucker_punch", "name": "Sucker Punch", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 8, "block": 0, "description": "Deal 8 damage.\nApply 1 Weak.", "art": "", "target": "enemy", "apply_status": {"type": "weak", "stacks": 1}, "actions": [{"type": "damage"}, {"type": "apply_status", "source": "apply_status"}]}
	# 12. Ricochet
	card_database["si_ricochet"] = {"id": "si_ricochet", "name": "Ricochet", "cost": 2, "type": CardType.ATTACK, "character": "silent", "damage": 3, "block": 0, "description": "Sly. Deal 3 damage\nto random enemy 4x.", "art": "", "target": "random_enemy", "times": 4, "special": "sly", "actions": [{"type": "damage"}]}
	# 13. Quick Slash
	card_database["si_quick_slash"] = {"id": "si_quick_slash", "name": "Quick Slash", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 8, "block": 0, "description": "Deal 8 damage.\nDraw 1 card.", "art": "", "target": "enemy", "draw": 1, "actions": [{"type": "damage"}, {"type": "draw"}]}

	# --- Common Skills ---
	# 14. Anticipate
	card_database["si_anticipate"] = {"id": "si_anticipate", "name": "Anticipate", "cost": 0, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Gain 3 Dexterity\nthis turn.", "art": "", "target": "self", "temp_dex": 3, "actions": [{"type": "call", "fn": "anticipate"}]}
	# 15. Deflect
	card_database["si_deflect"] = {"id": "si_deflect", "name": "Deflect", "cost": 0, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 4, "description": "Gain 4 Block.", "art": "", "target": "self", "actions": [{"type": "block"}]}
	# 16. Prepared
	card_database["si_prepared"] = {"id": "si_prepared", "name": "Prepared", "cost": 0, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Draw 1, Discard 1.", "art": "", "target": "self", "draw": 1, "discard": 1, "actions": [{"type": "draw"}]}
	# 17. Backflip
	card_database["si_backflip"] = {"id": "si_backflip", "name": "Backflip", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 5, "description": "Gain 5 Block.\nDraw 2 cards.", "art": "", "target": "self", "draw": 2, "actions": [{"type": "block"}, {"type": "draw"}]}
	# 18. Dodge and Roll
	card_database["si_dodge_and_roll"] = {"id": "si_dodge_and_roll", "name": "Dodge and Roll", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 4, "description": "Gain 4 Block this\nturn and next.", "art": "", "target": "self", "actions": [{"type": "block"}, {"type": "next_turn", "effect": {"type": "block", "value": 4}}]}
	# 19. Cloak and Dagger
	card_database["si_cloak_and_dagger"] = {"id": "si_cloak_and_dagger", "name": "Cloak and Dagger", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 6, "description": "Gain 6 Block.\nAdd 1 Shiv to hand.", "art": "", "target": "self", "actions": [{"type": "block"}, {"type": "add_shiv", "value": 1}]}
	# 20. Outmaneuver
	card_database["si_outmaneuver"] = {"id": "si_outmaneuver", "name": "Outmaneuver", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Gain 2 Energy\nnext turn.", "art": "", "target": "self", "actions": [{"type": "next_turn", "effect": {"type": "gain_energy", "value": 2}}]}
	# 21. Acrobatics
	card_database["si_acrobatics"] = {"id": "si_acrobatics", "name": "Acrobatics", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Draw 3 cards.\nDiscard 1.", "art": "", "target": "self", "draw": 3, "discard": 1, "actions": [{"type": "draw"}]}
	# 22. Blade Dance
	card_database["si_blade_dance"] = {"id": "si_blade_dance", "name": "Blade Dance", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Add 3 Shivs to\nyour hand.", "art": "", "target": "self", "actions": [{"type": "add_shiv", "value": 3}]}
	# 23. Escape Plan
	card_database["si_escape_plan"] = {"id": "si_escape_plan", "name": "Escape Plan", "cost": 0, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Draw 1 card. If it\nis a Skill, gain\n3 Block.", "art": "", "target": "self", "escape_block": 3, "actions": [{"type": "call", "fn": "escape_plan"}]}
	# 24. Calculated Gamble
	card_database["si_calculated_gamble"] = {"id": "si_calculated_gamble", "name": "Calculated Gamble", "cost": 0, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Discard your hand.\nDraw that many cards.", "art": "", "target": "self", "actions": [{"type": "call", "fn": "calculated_gamble"}]}
	# 25. Concentrate
	card_database["si_concentrate"] = {"id": "si_concentrate", "name": "Concentrate", "cost": 0, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Discard 3 cards.\nGain 2 Energy.", "art": "", "target": "self", "discard_count": 3, "energy_gain_val": 2, "actions": [{"type": "call", "fn": "concentrate"}]}

	# --- Uncommon Attacks ---
	# 26. Predator
	card_database["si_predator"] = {"id": "si_predator", "name": "Predator", "cost": 2, "type": CardType.ATTACK, "character": "silent", "damage": 15, "block": 0, "description": "Deal 15 damage.", "art": "", "target": "enemy", "actions": [{"type": "damage"}]}
	# 27. Masterful Stab
	card_database["si_masterful_stab"] = {"id": "si_masterful_stab", "name": "Masterful Stab", "cost": 0, "type": CardType.ATTACK, "character": "silent", "damage": 12, "block": 0, "description": "Innate.\nDeal 12 damage.", "art": "", "target": "enemy", "innate": true, "actions": [{"type": "damage"}]}
	# 28. Skewer
	card_database["si_skewer"] = {"id": "si_skewer", "name": "Skewer", "cost": -1, "type": CardType.ATTACK, "character": "silent", "damage": 7, "block": 0, "description": "Deal 7 damage X times.\n(X = current Energy)", "art": "", "target": "enemy", "actions": [{"type": "call", "fn": "skewer"}]}
	# 29. Die Die Die
	card_database["si_die_die_die"] = {"id": "si_die_die_die", "name": "Die Die Die", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 13, "block": 0, "description": "Deal 13 damage to\nALL enemies. Exhaust.", "art": "", "target": "all_enemies", "exhaust": true, "actions": [{"type": "damage_all"}]}
	# 30. Endless Agony
	card_database["si_endless_agony"] = {"id": "si_endless_agony", "name": "Endless Agony", "cost": 0, "type": CardType.ATTACK, "character": "silent", "damage": 4, "block": 0, "description": "Deal 4 damage.\nExhaust. When drawn,\nadd copy to hand.", "art": "", "target": "enemy", "exhaust": true, "actions": [{"type": "damage"}]}
	# 31. Eviscerate
	card_database["si_eviscerate"] = {"id": "si_eviscerate", "name": "Eviscerate", "cost": 3, "type": CardType.ATTACK, "character": "silent", "damage": 7, "block": 0, "description": "Deal 7 damage\n3 times.", "art": "", "target": "enemy", "times": 3, "actions": [{"type": "damage"}]}
	# 32. Finisher
	card_database["si_finisher"] = {"id": "si_finisher", "name": "Finisher", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 6, "block": 0, "description": "Deal 6 damage for\neach Attack played\nthis turn.", "art": "", "target": "enemy", "actions": [{"type": "call", "fn": "finisher"}]}
	# 33. Flying Knee
	card_database["si_flying_knee"] = {"id": "si_flying_knee", "name": "Flying Knee", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 8, "block": 0, "description": "Deal 8 damage.\nGain 1 Energy\nnext turn.", "art": "", "target": "enemy", "actions": [{"type": "damage"}, {"type": "next_turn", "effect": {"type": "gain_energy", "value": 1}}]}
	# 34. Heel Hook
	card_database["si_heel_hook"] = {"id": "si_heel_hook", "name": "Heel Hook", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 5, "block": 0, "description": "Deal 5 damage.\nIf enemy is Weak:\ngain 1 Energy, draw 1.", "art": "", "target": "enemy", "actions": [{"type": "call", "fn": "heel_hook"}]}
	# 35. Glass Knife
	card_database["si_glass_knife"] = {"id": "si_glass_knife", "name": "Glass Knife", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 8, "block": 0, "description": "Deal 8 damage twice.\nDamage decreases by 2\neach use.", "art": "", "target": "enemy", "times": 2, "actions": [{"type": "call", "fn": "glass_knife"}]}
	# 36. Choke
	card_database["si_choke"] = {"id": "si_choke", "name": "Choke", "cost": 2, "type": CardType.ATTACK, "character": "silent", "damage": 12, "block": 0, "description": "Deal 12 damage.\nWhenever enemy plays\na card, take 3 damage.", "art": "", "target": "enemy", "choke_stacks": 3, "actions": [{"type": "call", "fn": "choke"}]}
	# 37. Riddle with Holes
	card_database["si_riddle_with_holes"] = {"id": "si_riddle_with_holes", "name": "Riddle with Holes", "cost": 2, "type": CardType.ATTACK, "character": "silent", "damage": 3, "block": 0, "description": "Deal 3 damage\n5 times.", "art": "", "target": "enemy", "times": 5, "actions": [{"type": "damage"}]}

	# --- Uncommon Skills ---
	# 38. Blur
	card_database["si_blur"] = {"id": "si_blur", "name": "Blur", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 5, "description": "Gain 5 Block.\nBlock not removed\nnext turn.", "art": "", "target": "self", "actions": [{"type": "block"}, {"type": "blur"}]}
	# 39. Dash
	card_database["si_dash"] = {"id": "si_dash", "name": "Dash", "cost": 2, "type": CardType.SKILL, "character": "silent", "damage": 10, "block": 10, "description": "Gain 10 Block.\nDeal 10 damage.", "art": "", "target": "enemy", "actions": [{"type": "block"}, {"type": "damage"}]}
	# 40. Terror
	card_database["si_terror"] = {"id": "si_terror", "name": "Terror", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Apply 99 Vulnerable.\nExhaust.", "art": "", "target": "enemy", "apply_status": {"type": "vulnerable", "stacks": 99}, "exhaust": true, "actions": [{"type": "apply_status", "source": "apply_status"}]}
	# 41. Distraction
	card_database["si_distraction"] = {"id": "si_distraction", "name": "Distraction", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Add a random Skill\nto your hand.\nExhaust.", "art": "", "target": "self", "exhaust": true, "actions": [{"type": "call", "fn": "distraction"}]}
	# 42. Expertise
	card_database["si_expertise"] = {"id": "si_expertise", "name": "Expertise", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Draw cards until you\nhave 6 in hand.", "art": "", "target": "self", "target_hand_size": 6, "actions": [{"type": "call", "fn": "expertise"}]}
	# 43. Infinite Blades
	card_database["si_infinite_blades"] = {"id": "si_infinite_blades", "name": "Infinite Blades", "cost": 1, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "At start of turn,\nadd a Shiv to hand.", "art": "", "target": "self", "power_effect": "infinite_blades", "actions": [{"type": "power_effect", "power": "infinite_blades"}]}
	# 44. Leg Sweep
	card_database["si_leg_sweep"] = {"id": "si_leg_sweep", "name": "Leg Sweep", "cost": 2, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 11, "description": "Apply 2 Weak.\nGain 11 Block.", "art": "", "target": "enemy", "apply_status": {"type": "weak", "stacks": 2}, "actions": [{"type": "apply_status", "source": "apply_status"}, {"type": "block"}]}
	# 45. Reflex
	card_database["si_reflex"] = {"id": "si_reflex", "name": "Reflex", "cost": 0, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Unplayable.\nWhen discarded,\ndraw 2 cards.", "art": "", "target": "self", "unplayable": true, "special": "reflex", "actions": []}
	# 46. Setup
	card_database["si_setup"] = {"id": "si_setup", "name": "Setup", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Put a card from hand\non top of draw pile.", "art": "", "target": "self", "actions": [{"type": "draw", "value": 0}]}
	# 47. Tactician
	card_database["si_tactician"] = {"id": "si_tactician", "name": "Tactician", "cost": 0, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Unplayable.\nWhen discarded,\ngain 1 Energy.", "art": "", "target": "self", "unplayable": true, "special": "tactician", "actions": []}
	# 48. Bouncing Flask
	card_database["si_bouncing_flask"] = {"id": "si_bouncing_flask", "name": "Bouncing Flask", "cost": 2, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Apply 3 Poison to\nrandom enemies 3x.", "art": "", "target": "random_enemy", "apply_status": {"type": "poison", "stacks": 3}, "times": 3, "actions": [{"type": "apply_status", "source": "apply_status"}]}
	# 49. Catalyst
	card_database["si_catalyst"] = {"id": "si_catalyst", "name": "Catalyst", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Double a target's\nPoison. Exhaust.", "art": "", "target": "enemy", "exhaust": true, "poison_mult": 2, "actions": [{"type": "call", "fn": "catalyst"}]}
	# 50. Crippling Cloud
	card_database["si_crippling_cloud"] = {"id": "si_crippling_cloud", "name": "Crippling Cloud", "cost": 2, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Apply 4 Poison and\n2 Weak to ALL enemies.", "art": "", "target": "all_enemies", "apply_status": {"type": "poison", "stacks": 4}, "apply_status_2": {"type": "weak", "stacks": 2}, "actions": [{"type": "apply_status", "source": "apply_status"}, {"type": "apply_status", "source": "apply_status_2"}]}
	# 51. Deadly Poison
	card_database["si_deadly_poison"] = {"id": "si_deadly_poison", "name": "Deadly Poison", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Apply 5 Poison.", "art": "", "target": "enemy", "apply_status": {"type": "poison", "stacks": 5}, "actions": [{"type": "apply_status", "source": "apply_status"}]}
	# 52. Noxious Fumes
	card_database["si_noxious_fumes"] = {"id": "si_noxious_fumes", "name": "Noxious Fumes", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "At start of turn,\napply 2 Poison to\nALL enemies.", "art": "", "target": "self", "power_effect": "noxious_fumes", "actions": [{"type": "power_effect", "power": "noxious_fumes"}]}

	# --- Uncommon Powers ---
	# 53. Accuracy
	card_database["si_accuracy"] = {"id": "si_accuracy", "name": "Accuracy", "cost": 1, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "Shivs deal 4 more\ndamage.", "art": "", "target": "self", "power_effect": "accuracy", "actions": [{"type": "power_effect", "power": "accuracy"}]}
	# 54. Caltrops
	card_database["si_caltrops"] = {"id": "si_caltrops", "name": "Caltrops", "cost": 1, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "When attacked, deal\n3 damage back.", "art": "", "target": "self", "power_effect": "caltrops", "actions": [{"type": "power_effect", "power": "caltrops"}]}
	# 55. A Thousand Cuts
	card_database["si_a_thousand_cuts"] = {"id": "si_a_thousand_cuts", "name": "A Thousand Cuts", "cost": 2, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "Whenever you play a\ncard, deal 1 damage\nto ALL enemies.", "art": "", "target": "self", "power_effect": "a_thousand_cuts", "actions": [{"type": "power_effect", "power": "a_thousand_cuts"}]}
	# 56. Envenom
	card_database["si_envenom"] = {"id": "si_envenom", "name": "Envenom", "cost": 2, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "Whenever you deal\nunblocked damage,\napply 1 Poison.", "art": "", "target": "self", "power_effect": "envenom", "actions": [{"type": "power_effect", "power": "envenom"}]}
	# 57. Footwork
	card_database["si_footwork"] = {"id": "si_footwork", "name": "Footwork", "cost": 1, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "Gain 2 Dexterity.", "art": "", "target": "self", "apply_self_status": {"type": "dexterity", "stacks": 2}, "actions": [{"type": "apply_self_status", "status": "dexterity", "stacks": 2}]}
	# 58. Tools of the Trade
	card_database["si_tools_of_the_trade"] = {"id": "si_tools_of_the_trade", "name": "Tools of the Trade", "cost": 1, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "At start of turn,\ndraw 1, discard 1.", "art": "", "target": "self", "power_effect": "tools_of_the_trade", "actions": [{"type": "power_effect", "power": "tools_of_the_trade"}]}

	# --- Rare Attacks ---
	# 59. Backstab
	card_database["si_backstab"] = {"id": "si_backstab", "name": "Backstab", "cost": 0, "type": CardType.ATTACK, "character": "silent", "damage": 11, "block": 0, "description": "Deal 11 damage.\nInnate. Exhaust.", "art": "", "target": "enemy", "innate": true, "exhaust": true, "actions": [{"type": "damage"}]}
	# 60. Grand Finale
	card_database["si_grand_finale"] = {"id": "si_grand_finale", "name": "Grand Finale", "cost": 0, "type": CardType.ATTACK, "character": "silent", "damage": 50, "block": 0, "description": "Can only play if draw\npile is empty.\nDeal 50 damage.", "art": "", "target": "enemy", "special": "grand_finale", "actions": [{"type": "call", "fn": "grand_finale"}]}
	# 61. Unload
	card_database["si_unload"] = {"id": "si_unload", "name": "Unload", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 14, "block": 0, "description": "Deal 14 damage.\nDiscard all non-Attack\ncards in hand.", "art": "", "target": "enemy", "actions": [{"type": "call", "fn": "unload"}]}

	# --- Rare Skills ---
	# 62. Adrenaline
	card_database["si_adrenaline"] = {"id": "si_adrenaline", "name": "Adrenaline", "cost": 0, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Gain 1 Energy.\nDraw 2 cards.\nExhaust.", "art": "", "target": "self", "draw": 2, "energy_gain": 1, "exhaust": true, "actions": [{"type": "gain_energy", "value": 1}, {"type": "draw"}]}
	# 63. Alchemize
	card_database["si_alchemize"] = {"id": "si_alchemize", "name": "Alchemize", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Obtain a random\npotion. Exhaust.", "art": "", "target": "self", "exhaust": true, "actions": [{"type": "call", "fn": "alchemize"}]}
	# 64. Bullet Time
	card_database["si_bullet_time"] = {"id": "si_bullet_time", "name": "Bullet Time", "cost": 3, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Cards cost 0 this\nturn. No draw\nnext turn.", "art": "", "target": "self", "actions": [{"type": "bullet_time"}]}
	# 65. Burst
	card_database["si_burst"] = {"id": "si_burst", "name": "Burst", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Next Skill is played\ntwice.", "art": "", "target": "self", "actions": [{"type": "burst"}]}
	# 66. Corpse Explosion
	card_database["si_corpse_explosion"] = {"id": "si_corpse_explosion", "name": "Corpse Explosion", "cost": 2, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Apply 6 Poison.\nWhen enemy dies, deal\ndamage to ALL.", "art": "", "target": "enemy", "apply_status": {"type": "poison", "stacks": 6}, "actions": [{"type": "apply_status", "source": "apply_status"}, {"type": "call", "fn": "corpse_explosion"}]}
	# 67. Malaise
	card_database["si_malaise"] = {"id": "si_malaise", "name": "Malaise", "cost": -1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Enemy loses X Strength.\nApply X Weak.", "art": "", "target": "enemy", "actions": [{"type": "call", "fn": "malaise"}]}
	# 68. Nightmare
	card_database["si_nightmare"] = {"id": "si_nightmare", "name": "Nightmare", "cost": 3, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Choose a card. Add\n3 copies to hand\nnext turn.", "art": "", "target": "self", "actions": [{"type": "draw", "value": 0}]}
	# 69. Phantasmal Killer
	card_database["si_phantasmal_killer"] = {"id": "si_phantasmal_killer", "name": "Phantasmal Killer", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Next turn, deal\ndouble damage.", "art": "", "target": "self", "actions": [{"type": "phantasmal_killer"}]}

	# --- Rare Powers ---
	# 70. After Image
	card_database["si_after_image"] = {"id": "si_after_image", "name": "After Image", "cost": 1, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "Whenever you play a\ncard, gain 1 Block.", "art": "", "target": "self", "power_effect": "after_image", "actions": [{"type": "power_effect", "power": "after_image"}]}
	# 71. Storm of Steel
	card_database["si_storm_of_steel"] = {"id": "si_storm_of_steel", "name": "Storm of Steel", "cost": 0, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Discard your hand.\nAdd a Shiv per card\ndiscarded.", "art": "", "target": "self", "actions": [{"type": "call", "fn": "storm_of_steel"}]}
	# 72. Well-Laid Plans
	card_database["si_well_laid_plans"] = {"id": "si_well_laid_plans", "name": "Well-Laid Plans", "cost": 1, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "At end of turn,\nRetain up to 1 card.", "art": "", "target": "self", "power_effect": "well_laid_plans", "actions": [{"type": "power_effect", "power": "well_laid_plans"}]}
	# 73. Wraith Form
	card_database["si_wraith_form"] = {"id": "si_wraith_form", "name": "Wraith Form", "cost": 3, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "Gain 2 Intangible.\nLose 1 Dexterity\nper turn.", "art": "", "target": "self", "power_effect": "wraith_form", "actions": [{"type": "power_effect", "power": "wraith_form"}]}

	# --- Status Cards ---
	# 74. Shiv
	card_database["si_shiv"] = {"id": "si_shiv", "name": "Shiv", "cost": 0, "type": CardType.ATTACK, "character": "silent", "damage": 4, "block": 0, "description": "Deal 4 damage.\nExhaust.", "art": "", "target": "enemy", "exhaust": true, "actions": [{"type": "damage"}]}
	# 75. Shiv+
	card_database["si_shiv_plus"] = {"id": "si_shiv_plus", "name": "Shiv+", "cost": 0, "type": CardType.ATTACK, "character": "silent", "damage": 6, "block": 0, "description": "Deal 6 damage.\nExhaust.", "art": "", "target": "enemy", "exhaust": true, "upgraded": true, "actions": [{"type": "damage"}]}

func select_character(character_id: String) -> void:
	current_character = character_id
	var data = character_data[character_id]
	player_max_hp = data["max_hp"]
	player_hp = player_max_hp
	# Don't reset player_deck — it's set by the deck builder
	character_selected.emit(character_id)

func get_starting_deck(character_id: String) -> Array:
	## Each hero starts with 2 Strike + 2 Defend (4 cards per hero, 8 total)
	var deck: Array = []
	if character_id == "ironclad":
		for i in 2: deck.append("ic_strike")
		for i in 2: deck.append("ic_defend")
	elif character_id == "silent":
		for i in 2: deck.append("si_strike")
		for i in 2: deck.append("si_defend")
	elif character_id == "bloodfiend":
		for i in 2: deck.append("bf_strike")
		for i in 2: deck.append("bf_defend")
	elif character_id == "fire_mage":
		for i in 2: deck.append("fm_strike")
		for i in 2: deck.append("fm_defend")
	return deck

func get_card_data(card_id: String) -> Dictionary:
	if card_database.has(card_id):
		return card_database[card_id].duplicate(true)
	return {}

# =============================================================================
# UPGRADE SYSTEM
# =============================================================================

func get_upgraded_card(card_id: String) -> Dictionary:
	# Deep copy to avoid mutating the shared card_database
	var base: Dictionary = {}
	if card_database.has(card_id):
		base = card_database[card_id].duplicate(true)
	if base.is_empty():
		return {}
	var overrides := _get_upgrade_overrides()
	if overrides.has(card_id):
		for key in overrides[card_id]:
			base[key] = overrides[card_id][key]
	# Sync top-level overrides into the actions array so execution reads correct values
	if base.has("actions") and base["actions"] is Array:
		for action in base["actions"]:
			var atype: String = action.get("type", "")
			match atype:
				"apply_self_status":
					if base.has("apply_self_status"):
						var src: Dictionary = base["apply_self_status"]
						action["status"] = src.get("type", action.get("status", ""))
						action["stacks"] = src.get("stacks", action.get("stacks", 1))
				"apply_status":
					var src_key: String = action.get("source", "apply_status")
					if base.has(src_key):
						var src: Dictionary = base[src_key]
						action["status"] = src.get("type", action.get("status", ""))
						action["stacks"] = src.get("stacks", action.get("stacks", 1))
				"power_effect":
					if base.has("power_effect"):
						action["power"] = base["power_effect"]
	base["name"] = base["name"] + "+"
	base["upgraded"] = true
	return base

# =============================================================================
# RARITY-WEIGHTED CARD SELECTION
# =============================================================================

## Roll a single random card for a hero using rarity weights.
## 70% common, 20% uncommon, 10% rare.  20% chance to be upgraded.
## Cards without a "rarity" field (basic strike/defend) are excluded.
func get_random_card_by_rarity(hero_id: String, exclude_ids: Array = []) -> Dictionary:
	var roll: float = randf()
	var rarity: String
	if roll < 0.7:
		rarity = "common"
	elif roll < 0.9:
		rarity = "uncommon"
	else:
		rarity = "rare"
	var pool: Array = _get_cards_by_rarity(hero_id, rarity, exclude_ids)
	# Fallback to common if rolled rarity has no cards
	if pool.is_empty() and rarity != "common":
		pool = _get_cards_by_rarity(hero_id, "common", exclude_ids)
	if pool.is_empty():
		return {}
	var card: Dictionary = pool[randi() % pool.size()].duplicate(true)
	# 20% chance upgraded
	if randf() < 0.2:
		var upgraded := get_upgraded_card(card["id"])
		if not upgraded.is_empty():
			card = upgraded
	return card

## Get N random cards for a hero, no duplicates, rarity-weighted + upgrade chance.
func get_random_cards_for_hero(hero_id: String, count: int) -> Array:
	var result: Array = []
	var exclude: Array = []
	for _i in range(count):
		var card := get_random_card_by_rarity(hero_id, exclude)
		if card.is_empty():
			break
		result.append(card)
		exclude.append(card["id"])
	return result

## Get N random cards from a mixed pool of hero IDs, rarity-weighted.
func get_random_cards_multi_hero(hero_ids: Array, count: int) -> Array:
	var result: Array = []
	var exclude: Array = []
	for _i in range(count):
		var hid: String = hero_ids[randi() % hero_ids.size()]
		var card := get_random_card_by_rarity(hid, exclude)
		if card.is_empty():
			# Try other heroes
			for other in hero_ids:
				if other != hid:
					card = get_random_card_by_rarity(other, exclude)
					if not card.is_empty():
						break
		if card.is_empty():
			break
		result.append(card)
		exclude.append(card["id"])
	return result

func _get_cards_by_rarity(hero_id: String, rarity: String, exclude_ids: Array) -> Array:
	var pool: Array = []
	for cid in card_database:
		var cd: Dictionary = card_database[cid]
		if cd.get("character", "") != hero_id:
			continue
		if cd.get("rarity", "") != rarity:
			continue
		if cid in exclude_ids:
			continue
		pool.append(cd)
	return pool

func _get_upgrade_overrides() -> Dictionary:
	return _upgrade_overrides_cache

func _legacy_get_upgrade_overrides() -> Dictionary:
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
		"ic_heavy_blade": {"damage": 18, "str_mult": 5, "description": "Deal 18 damage.\nStrength applies x5."},
		"ic_thunderclap": {"damage": 7, "description": "Deal 7 damage to\nALL enemies.\nApply 1 Vulnerable."},
		"ic_hemokinesis": {"damage": 20, "description": "Lose 2 HP.\nDeal 20 damage."},
		"ic_reckless_charge": {"damage": 10, "description": "Deal 10 damage.\nShuffle a Dazed into\nyour draw pile."},
		"ic_clash": {"damage": 18, "description": "Can only be played if\nevery card in hand\nis an Attack.\nDeal 18 damage."},
		"ic_perfected_strike": {"damage": 6, "strike_bonus": 3, "description": "Deal 6 damage. Deals\n3 additional damage\nfor each \"Strike\" card\nin your deck."},
		"ic_bludgeon": {"damage": 42, "description": "Deal 42 damage."},
		"ic_sword_boomerang": {"times": 4, "description": "Deal 3 damage to a\nrandom enemy 4 times."},
		"ic_searing_blow": {"damage": 16, "description": "Deal 16 damage."},
		"ic_whirlwind": {"damage": 8, "description": "Deal 8 damage to ALL\nenemies X times.\n(X = current Energy)"},
		"ic_dropkick": {"damage": 8, "description": "Deal 8 damage.\nIf enemy is Vulnerable:\ngain 1 Energy, draw 1."},
		"ic_carnage": {"damage": 28, "description": "Ethereal.\nDeal 28 damage."},
		"ic_clothesline": {"damage": 14, "apply_status": {"type": "weak", "stacks": 3}, "description": "Deal 14 damage.\nApply 3 Weak."},
		"ic_feed": {"damage": 12, "max_hp_gain": 4, "description": "Deal 12 damage.\nIf this kills, gain\n4 Max HP. Exhaust."},
		"ic_rampage": {"damage": 8, "rampage_inc": 8, "description": "Deal 8 damage.\nIncreases by 8\neach time played."},
		"ic_sever_soul": {"damage": 22, "description": "Exhaust all non-Attack\ncards in hand.\nDeal 22 damage."},

		# =====================================================================
		# IRONCLAD SKILLS
		# =====================================================================
		"ic_defend": {"block": 8, "description": "Gain 8 Block."},
		"ic_shrug_it_off": {"block": 11, "description": "Gain 11 Block.\nDraw 1 card."},
		"ic_flame_barrier": {"block": 16, "description": "Gain 16 Block.\nWhen attacked this turn,\ndeal 6 damage back."},
		"ic_battle_trance": {"draw": 4, "description": "Draw 4 cards."},
		"ic_bloodletting": {"actions": [{"type": "self_damage", "value": 3}, {"type": "gain_energy", "value": 3}], "description": "Lose 3 HP.\nGain 3 Energy."},
		"ic_flex": {"flex_stacks": 4, "description": "Gain 4 Strength.\nAt end of turn,\nlose 4 Strength."},
		"ic_limit_break": {"exhaust": false, "description": "Double your Strength."},
		"ic_entrench": {"cost": 1, "description": "Double your Block."},
		"ic_shockwave": {"apply_status": {"type": "weak", "stacks": 5}, "apply_status_2": {"type": "vulnerable", "stacks": 5}, "description": "Apply 5 Weak and\n5 Vulnerable to\nALL enemies. Exhaust."},
		"ic_armaments": {"block": 5, "description": "Gain 5 Block.\nUpgrade ALL cards\nin hand."},
		"ic_power_through": {"block": 20, "description": "Gain 20 Block.\nAdd 2 Wounds to\nyour hand."},
		"ic_offering": {"actions": [{"type": "self_damage", "value": 6}, {"type": "gain_energy", "value": 2}, {"type": "draw", "value": 5}], "description": "Lose 6 HP.\nGain 2 Energy.\nDraw 5 cards.\nExhaust."},
		"ic_war_cry": {"draw": 2, "description": "Draw 2 cards.\nExhaust."},
		"ic_burning_pact": {"draw": 3, "description": "Exhaust 1 card.\nDraw 3 cards."},
		"ic_seeing_red": {"cost": 0, "description": "Gain 2 Energy.\nExhaust."},
		"ic_second_wind": {"block_per": 7, "description": "Exhaust all non-Attack\ncards in hand. Gain\n7 Block for each."},
		"ic_intimidate": {"apply_status": {"type": "weak", "stacks": 2}, "description": "Apply 2 Weak to\nALL enemies. Exhaust."},
		"ic_infernal_blade": {"cost": 0, "description": "Add a random Attack\nto your hand. It\ncosts 0. Exhaust."},
		"ic_dual_wield": {"copies": 2, "description": "Copy an Attack or\nPower card in hand\n2 times."},
		"ic_ghostly_armor": {"block": 13, "description": "Ethereal.\nGain 13 Block."},
		"ic_havoc": {"cost": 0, "description": "Play the top card of\nyour draw pile and\nExhaust it."},
		"ic_impervious": {"block": 40, "description": "Gain 40 Block.\nExhaust."},
		"ic_exhume": {"cost": 0, "description": "Put a card from your\nexhaust pile into\nyour hand. Exhaust."},
		"ic_sentinel": {"block": 8, "description": "Gain 8 Block.\nIf this card is\nExhausted, gain\n3 Energy."},
		"ic_spot_weakness": {"spot_str": 4, "description": "If the enemy intends\nto attack, gain\n4 Strength."},
		"ic_true_grit": {"block": 9, "description": "Gain 9 Block.\nExhaust a card in\nyour hand."},
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

		# =====================================================================
		# SILENT BASIC
		# =====================================================================
		"si_strike": {"damage": 9, "description": "Deal 9 damage."},
		"si_defend": {"block": 8, "description": "Gain 8 Block."},
		"si_neutralize": {"damage": 4, "apply_status": {"type": "weak", "stacks": 2}, "description": "Deal 4 damage.\nApply 2 Weak."},
		"si_survivor": {"block": 11, "description": "Gain 11 Block.\nDiscard 1 card."},

		# =====================================================================
		# SILENT COMMON ATTACKS
		# =====================================================================
		"si_slice": {"damage": 9, "description": "Deal 9 damage."},
		"si_dagger_spray": {"damage": 6, "description": "Deal 6 damage to ALL\nenemies twice."},
		"si_dagger_throw": {"damage": 12, "description": "Deal 12 damage.\nDraw 1, Discard 1."},
		"si_flick_flack": {"damage": 10, "description": "Sly. Deal 10 damage\nto ALL enemies."},
		"si_leading_strike": {"damage": 10, "description": "Deal 10 damage.\nAdd 1 Shiv to hand."},
		"si_poisoned_stab": {"damage": 8, "apply_status": {"type": "poison", "stacks": 4}, "description": "Deal 8 damage.\nApply 4 Poison."},
		"si_sucker_punch": {"damage": 11, "apply_status": {"type": "weak", "stacks": 2}, "description": "Deal 11 damage.\nApply 2 Weak."},
		"si_ricochet": {"damage": 4, "description": "Sly. Deal 4 damage\nto random enemy 4x."},
		"si_quick_slash": {"damage": 12, "description": "Deal 12 damage.\nDraw 1 card."},

		# =====================================================================
		# SILENT COMMON SKILLS
		# =====================================================================
		"si_anticipate": {"description": "Gain 5 Dexterity\nthis turn."},
		"si_deflect": {"block": 7, "description": "Gain 7 Block."},
		"si_prepared": {"draw": 2, "description": "Draw 2, Discard 1."},
		"si_backflip": {"block": 8, "description": "Gain 8 Block.\nDraw 2 cards."},
		"si_dodge_and_roll": {"block": 6, "description": "Gain 6 Block this\nturn and next.", "actions": [{"type": "block"}, {"type": "next_turn", "effect": {"type": "block", "value": 6}}]},
		"si_cloak_and_dagger": {"block": 6, "description": "Gain 6 Block.\nAdd 2 Shivs to hand.", "actions": [{"type": "block"}, {"type": "add_shiv", "value": 2}]},
		"si_outmaneuver": {"description": "Gain 3 Energy\nnext turn.", "actions": [{"type": "next_turn", "effect": {"type": "gain_energy", "value": 3}}]},
		"si_acrobatics": {"draw": 4, "description": "Draw 4 cards.\nDiscard 1."},
		"si_blade_dance": {"description": "Add 4 Shivs to\nyour hand.", "actions": [{"type": "add_shiv", "value": 4}]},
		"si_escape_plan": {"block": 5, "description": "Draw 1 card. If it\nis a Skill, gain\n5 Block."},
		"si_calculated_gamble": {"description": "Discard your hand.\nDraw that many +1."},
		"si_concentrate": {"description": "Discard 2 cards.\nGain 2 Energy."},

		# =====================================================================
		# SILENT UNCOMMON ATTACKS
		# =====================================================================
		"si_predator": {"damage": 20, "description": "Deal 20 damage."},
		"si_masterful_stab": {"damage": 16, "description": "Innate.\nDeal 16 damage."},
		"si_skewer": {"damage": 10, "description": "Deal 10 damage X times.\n(X = current Energy)"},
		"si_die_die_die": {"damage": 17, "description": "Deal 17 damage to\nALL enemies. Exhaust."},
		"si_endless_agony": {"damage": 6, "description": "Deal 6 damage.\nExhaust. When drawn,\nadd copy to hand."},
		"si_eviscerate": {"damage": 9, "description": "Deal 9 damage\n3 times."},
		"si_finisher": {"damage": 8, "description": "Deal 8 damage for\neach Attack played\nthis turn."},
		"si_flying_knee": {"damage": 11, "description": "Deal 11 damage.\nGain 1 Energy\nnext turn."},
		"si_heel_hook": {"damage": 8, "description": "Deal 8 damage.\nIf enemy is Weak:\ngain 1 Energy, draw 1."},
		"si_glass_knife": {"damage": 12, "description": "Deal 12 damage twice.\nDamage decreases by 2\neach use."},
		"si_choke": {"damage": 16, "description": "Deal 16 damage.\nWhenever enemy plays\na card, take 4 damage."},
		"si_riddle_with_holes": {"damage": 4, "description": "Deal 4 damage\n5 times."},

		# =====================================================================
		# SILENT UNCOMMON SKILLS
		# =====================================================================
		"si_blur": {"block": 8, "description": "Gain 8 Block.\nBlock not removed\nnext turn."},
		"si_dash": {"damage": 13, "block": 13, "description": "Gain 13 Block.\nDeal 13 damage."},
		"si_terror": {"cost": 0, "description": "Apply 99 Vulnerable.\nExhaust."},
		"si_distraction": {"cost": 0, "description": "Add a random Skill\nto your hand.\nExhaust."},
		"si_expertise": {"description": "Draw cards until you\nhave 7 in hand."},
		"si_infinite_blades": {"description": "At start of turn,\nadd a Shiv+ to hand."},
		"si_leg_sweep": {"block": 14, "apply_status": {"type": "weak", "stacks": 3}, "description": "Apply 3 Weak.\nGain 14 Block."},
		"si_reflex": {"description": "Unplayable.\nWhen discarded,\ndraw 3 cards."},
		"si_setup": {"cost": 0, "description": "Put a card from hand\non top of draw pile."},
		"si_tactician": {"description": "Unplayable.\nWhen discarded,\ngain 2 Energy."},
		"si_bouncing_flask": {"apply_status": {"type": "poison", "stacks": 4}, "description": "Apply 4 Poison to\nrandom enemies 3x."},
		"si_catalyst": {"poison_mult": 3, "description": "Triple a target's\nPoison. Exhaust."},
		"si_crippling_cloud": {"apply_status": {"type": "poison", "stacks": 7}, "apply_status_2": {"type": "weak", "stacks": 3}, "description": "Apply 7 Poison and\n3 Weak to ALL enemies."},
		"si_deadly_poison": {"apply_status": {"type": "poison", "stacks": 7}, "description": "Apply 7 Poison."},
		"si_noxious_fumes": {"description": "At start of turn,\napply 3 Poison to\nALL enemies.", "power_effect": "noxious_fumes_plus"},

		# =====================================================================
		# SILENT UNCOMMON POWERS
		# =====================================================================
		"si_accuracy": {"description": "Shivs deal 6 more\ndamage.", "power_effect": "accuracy_plus"},
		"si_caltrops": {"description": "When attacked, deal\n5 damage back.", "power_effect": "caltrops_plus"},
		"si_a_thousand_cuts": {"description": "Whenever you play a\ncard, deal 2 damage\nto ALL enemies.", "power_effect": "a_thousand_cuts_plus"},
		"si_envenom": {"description": "Whenever you deal\nunblocked damage,\napply 2 Poison.", "power_effect": "envenom_plus"},
		"si_footwork": {"apply_self_status": {"type": "dexterity", "stacks": 3}, "description": "Gain 3 Dexterity."},
		"si_tools_of_the_trade": {"description": "At start of turn,\ndraw 1, discard 1."},

		# =====================================================================
		# SILENT RARE ATTACKS
		# =====================================================================
		"si_backstab": {"damage": 15, "description": "Deal 15 damage.\nInnate. Exhaust."},
		"si_grand_finale": {"damage": 60, "description": "Can only play if draw\npile is empty.\nDeal 60 damage."},
		"si_unload": {"damage": 18, "description": "Deal 18 damage.\nDiscard all non-Attack\ncards in hand."},

		# =====================================================================
		# SILENT RARE SKILLS
		# =====================================================================
		"si_adrenaline": {"draw": 3, "description": "Gain 2 Energy.\nDraw 3 cards.\nExhaust.", "energy_gain": 2},
		"si_alchemize": {"cost": 0, "description": "Obtain a random\npotion. Exhaust."},
		"si_bullet_time": {"cost": 2, "description": "Cards cost 0 this\nturn. No draw\nnext turn."},
		"si_burst": {"description": "Next 2 Skills are\nplayed twice."},
		"si_corpse_explosion": {"apply_status": {"type": "poison", "stacks": 9}, "description": "Apply 9 Poison.\nWhen enemy dies, deal\ndamage to ALL."},
		"si_malaise": {"description": "Enemy loses X+1\nStrength. Apply X+1\nWeak."},
		"si_nightmare": {"cost": 2, "description": "Choose a card. Add\n3 copies to hand\nnext turn."},
		"si_phantasmal_killer": {"description": "Next turn, deal\ndouble damage."},

		# =====================================================================
		# SILENT RARE POWERS
		# =====================================================================
		"si_after_image": {"description": "Whenever you play a\ncard, gain 1 Block."},
		"si_storm_of_steel": {"description": "Discard your hand.\nAdd a Shiv+ per card\ndiscarded."},
		"si_well_laid_plans": {"description": "At end of turn,\nRetain up to 2 cards.", "power_effect": "well_laid_plans_plus"},
		"si_wraith_form": {"description": "Gain 3 Intangible.\nLose 1 Dexterity\nper turn.", "power_effect": "wraith_form_plus"},
	}
