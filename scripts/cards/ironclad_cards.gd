class_name IroncladCards
## res://scripts/cards/ironclad_cards.gd — Ironclad card pack (pluggable)
## All Ironclad card definitions and upgrade overrides.

enum CardType { ATTACK, SKILL, POWER, STATUS }

static func get_cards() -> Dictionary:
	var db: Dictionary = {}

	# =========================================================================
	# ATTACKS (27 cards)
	# =========================================================================
	db["ic_strike"] = {"id": "ic_strike", "name": "Strike", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 6, "block": 0, "description": "Deal 6 damage.", "art": "", "target": "enemy", "actions": [{"type": "damage"}]}
	db["ic_bash"] = {"id": "ic_bash", "name": "Bash", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 8, "block": 0, "description": "Deal 8 damage.\nApply 2 Vulnerable.", "art": "", "target": "enemy", "apply_status": {"type": "vulnerable", "stacks": 2}, "actions": [{"type": "damage"}, {"type": "apply_status", "source": "apply_status"}]}
	db["ic_iron_wave"] = {"id": "ic_iron_wave", "name": "Iron Wave", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 5, "block": 5, "description": "Deal 5 damage.\nGain 5 Block.", "art": "", "target": "enemy", "actions": [{"type": "damage"}, {"type": "block"}]}
	db["ic_body_slam"] = {"id": "ic_body_slam", "name": "Body Slam", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 0, "block": 0, "description": "Deal damage equal\nto your Block.", "art": "", "target": "enemy", "actions": [{"type": "call", "fn": "body_slam"}]}
	db["ic_anger"] = {"id": "ic_anger", "name": "Anger", "cost": 0, "type": CardType.ATTACK, "character": "ironclad", "damage": 6, "block": 0, "description": "Deal 6 damage.\nAdd a copy to\nyour discard pile.", "art": "", "target": "enemy", "actions": [{"type": "damage"}, {"type": "copy_to_discard", "card_id": "ic_anger"}]}
	db["ic_cleave"] = {"id": "ic_cleave", "name": "Cleave", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 8, "block": 0, "description": "Deal 8 damage to\nALL enemies.", "art": "", "target": "all_enemies", "actions": [{"type": "damage_all"}]}
	db["ic_twin_strike"] = {"id": "ic_twin_strike", "name": "Twin Strike", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 5, "block": 0, "description": "Deal 5 damage twice.", "art": "", "target": "enemy", "times": 2, "actions": [{"type": "damage"}]}
	db["ic_wild_strike"] = {"id": "ic_wild_strike", "name": "Wild Strike", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 12, "block": 0, "description": "Deal 12 damage.\nShuffle a Wound into\nyour draw pile.", "art": "", "target": "enemy", "actions": [{"type": "damage"}, {"type": "add_card_to_draw", "card_id": "status_wound"}]}
	db["ic_pommel_strike"] = {"id": "ic_pommel_strike", "name": "Pommel Strike", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 9, "block": 0, "description": "Deal 9 damage.\nDraw 1 card.", "art": "", "target": "enemy", "draw": 1, "actions": [{"type": "damage"}, {"type": "draw"}]}
	db["ic_headbutt"] = {"id": "ic_headbutt", "name": "Headbutt", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 9, "block": 0, "description": "Deal 9 damage.", "art": "", "target": "enemy", "actions": [{"type": "damage"}]}
	db["ic_pummel"] = {"id": "ic_pummel", "name": "Pummel", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 2, "block": 0, "description": "Deal 2 damage x4.", "art": "", "target": "enemy", "times": 4, "actions": [{"type": "damage"}]}
	db["ic_uppercut"] = {"id": "ic_uppercut", "name": "Uppercut", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 13, "block": 0, "description": "Deal 13 damage.\nApply 1 Weak.\nApply 1 Vulnerable.", "art": "", "target": "enemy", "apply_status": {"type": "vulnerable", "stacks": 1}, "apply_status_2": {"type": "weak", "stacks": 1}, "actions": [{"type": "damage"}, {"type": "apply_status", "source": "apply_status"}, {"type": "apply_status", "source": "apply_status_2"}]}
	db["ic_immolate"] = {"id": "ic_immolate", "name": "Immolate", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 21, "block": 0, "description": "Deal 21 damage to\nALL enemies.\nAdd a Burn to discard.", "art": "", "target": "all_enemies", "actions": [{"type": "damage_all"}, {"type": "add_card_to_discard", "card_id": "status_burn"}]}
	db["ic_fiend_fire"] = {"id": "ic_fiend_fire", "name": "Fiend Fire", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 7, "block": 0, "description": "Exhaust your hand.\nDeal 7 damage for\neach card exhausted.", "art": "", "target": "enemy", "exhaust": true, "actions": [{"type": "call", "fn": "fiend_fire"}]}
	db["ic_reaper"] = {"id": "ic_reaper", "name": "Reaper", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 4, "block": 0, "description": "Deal 4 damage to\nALL enemies.\nHeal for unblocked damage.", "art": "", "target": "all_enemies", "exhaust": true, "actions": [{"type": "call", "fn": "reaper"}]}
	db["ic_heavy_blade"] = {"id": "ic_heavy_blade", "name": "Heavy Blade", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 14, "block": 0, "description": "Deal 14 damage.\nStrength applies x3.", "art": "", "target": "enemy", "str_mult": 3, "actions": [{"type": "call", "fn": "heavy_blade"}]}
	db["ic_thunderclap"] = {"id": "ic_thunderclap", "name": "Thunderclap", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 4, "block": 0, "description": "Deal 4 damage to\nALL enemies.\nApply 1 Vulnerable.", "art": "", "target": "all_enemies", "apply_status": {"type": "vulnerable", "stacks": 1}, "actions": [{"type": "damage_all"}, {"type": "apply_status", "source": "apply_status"}]}
	db["ic_hemokinesis"] = {"id": "ic_hemokinesis", "name": "Hemokinesis", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 15, "block": 0, "description": "Lose 2 HP.\nDeal 15 damage.", "art": "", "target": "enemy", "actions": [{"type": "self_damage", "value": 2}, {"type": "damage"}]}
	db["ic_reckless_charge"] = {"id": "ic_reckless_charge", "name": "Reckless Charge", "cost": 0, "type": CardType.ATTACK, "character": "ironclad", "damage": 7, "block": 0, "description": "Deal 7 damage.\nShuffle a Dazed into\nyour draw pile.", "art": "", "target": "enemy", "actions": [{"type": "damage"}, {"type": "add_card_to_draw", "card_id": "status_dazed"}]}
	db["ic_clash"] = {"id": "ic_clash", "name": "Clash", "cost": 0, "type": CardType.ATTACK, "character": "ironclad", "damage": 14, "block": 0, "description": "Can only be played if\nevery card in hand\nis an Attack.\nDeal 14 damage.", "art": "", "target": "enemy", "special": "clash", "actions": [{"type": "damage"}]}
	db["ic_perfected_strike"] = {"id": "ic_perfected_strike", "name": "Perfected Strike", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 6, "block": 0, "description": "Deal 6 damage. Deals\n2 additional damage\nfor each \"Strike\" card\nin your deck.", "art": "", "target": "enemy", "strike_bonus": 2, "actions": [{"type": "call", "fn": "perfected_strike"}]}
	db["ic_bludgeon"] = {"id": "ic_bludgeon", "name": "Bludgeon", "cost": 3, "type": CardType.ATTACK, "character": "ironclad", "damage": 32, "block": 0, "description": "Deal 32 damage.", "art": "", "target": "enemy", "actions": [{"type": "damage"}]}
	db["ic_sword_boomerang"] = {"id": "ic_sword_boomerang", "name": "Sword Boomerang", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 3, "block": 0, "description": "Deal 3 damage to a\nrandom enemy 3 times.", "art": "", "target": "random_enemy", "times": 3, "actions": [{"type": "damage"}]}
	db["ic_searing_blow"] = {"id": "ic_searing_blow", "name": "Searing Blow", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 12, "block": 0, "description": "Deal 12 damage.", "art": "", "target": "enemy", "actions": [{"type": "damage"}]}
	db["ic_whirlwind"] = {"id": "ic_whirlwind", "name": "Whirlwind", "cost": -1, "type": CardType.ATTACK, "character": "ironclad", "damage": 5, "block": 0, "description": "Deal 5 damage to ALL\nenemies X times.\n(X = current Energy)", "art": "", "target": "all_enemies", "actions": [{"type": "call", "fn": "whirlwind"}]}
	db["ic_dropkick"] = {"id": "ic_dropkick", "name": "Dropkick", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 5, "block": 0, "description": "Deal 5 damage.\nIf enemy is Vulnerable:\ngain 1 Energy, draw 1.", "art": "", "target": "enemy", "actions": [{"type": "call", "fn": "dropkick"}]}
	db["ic_carnage"] = {"id": "ic_carnage", "name": "Carnage", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 20, "block": 0, "description": "Ethereal.\nDeal 20 damage.", "art": "", "target": "enemy", "ethereal": true, "actions": [{"type": "damage"}]}
	db["ic_clothesline"] = {"id": "ic_clothesline", "name": "Clothesline", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 12, "block": 0, "description": "Deal 12 damage.\nApply 2 Weak.", "art": "", "target": "enemy", "apply_status": {"type": "weak", "stacks": 2}, "actions": [{"type": "damage"}, {"type": "apply_status", "source": "apply_status"}]}
	db["ic_feed"] = {"id": "ic_feed", "name": "Feed", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 10, "block": 0, "description": "Deal 10 damage.\nIf this kills, gain\n3 Max HP. Exhaust.", "art": "", "target": "enemy", "exhaust": true, "max_hp_gain": 3, "actions": [{"type": "call", "fn": "feed"}]}
	db["ic_rampage"] = {"id": "ic_rampage", "name": "Rampage", "cost": 1, "type": CardType.ATTACK, "character": "ironclad", "damage": 8, "block": 0, "description": "Deal 8 damage.\nIncreases by 5\neach time played.", "art": "", "target": "enemy", "rampage_inc": 5, "actions": [{"type": "call", "fn": "rampage"}]}
	db["ic_sever_soul"] = {"id": "ic_sever_soul", "name": "Sever Soul", "cost": 2, "type": CardType.ATTACK, "character": "ironclad", "damage": 16, "block": 0, "description": "Exhaust all non-Attack\ncards in hand.\nDeal 16 damage.", "art": "", "target": "enemy", "actions": [{"type": "call", "fn": "sever_soul"}]}
	db["ic_blood_for_blood"] = {"id": "ic_blood_for_blood", "name": "Blood for Blood", "cost": 4, "type": CardType.ATTACK, "character": "ironclad", "damage": 18, "block": 0, "description": "Costs 1 less for each\ntime you lose HP this\ncombat. Deal 18 dmg.", "art": "", "target": "enemy", "status": "incomplete", "actions": [{"type": "call", "fn": "blood_for_blood"}]}

	# =========================================================================
	# SKILLS (27 cards)
	# =========================================================================
	db["ic_defend"] = {"id": "ic_defend", "name": "Defend", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 5, "description": "Gain 5 Block.", "art": "", "target": "self", "actions": [{"type": "block"}]}
	db["ic_shrug_it_off"] = {"id": "ic_shrug_it_off", "name": "Shrug It Off", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 8, "description": "Gain 8 Block.\nDraw 1 card.", "art": "", "target": "self", "draw": 1, "actions": [{"type": "block"}, {"type": "draw"}]}
	db["ic_flame_barrier"] = {"id": "ic_flame_barrier", "name": "Flame Barrier", "cost": 2, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 12, "description": "Gain 12 Block.\nWhen attacked this turn,\ndeal 4 damage back.", "art": "", "target": "self", "power_effect": "flame_barrier", "actions": [{"type": "block"}, {"type": "power_effect", "power": "flame_barrier"}]}
	db["ic_battle_trance"] = {"id": "ic_battle_trance", "name": "Battle Trance", "cost": 0, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Draw 3 cards.", "art": "", "target": "self", "draw": 3, "actions": [{"type": "draw"}]}
	db["ic_bloodletting"] = {"id": "ic_bloodletting", "name": "Bloodletting", "cost": 0, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Lose 3 HP.\nGain 2 Energy.", "art": "", "target": "self", "actions": [{"type": "self_damage", "value": 3}, {"type": "gain_energy", "value": 2}]}
	db["ic_flex"] = {"id": "ic_flex", "name": "Flex", "cost": 0, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Gain 2 Strength.\nAt end of turn,\nlose 2 Strength.", "art": "", "target": "self", "flex_stacks": 2, "actions": [{"type": "call", "fn": "flex"}]}
	db["ic_limit_break"] = {"id": "ic_limit_break", "name": "Limit Break", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Double your Strength.\nExhaust.", "art": "", "target": "self", "exhaust": true, "actions": [{"type": "call", "fn": "limit_break"}]}
	db["ic_entrench"] = {"id": "ic_entrench", "name": "Entrench", "cost": 2, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Double your Block.", "art": "", "target": "self", "actions": [{"type": "call", "fn": "entrench"}]}
	db["ic_shockwave"] = {"id": "ic_shockwave", "name": "Shockwave", "cost": 2, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Apply 3 Weak and\n3 Vulnerable to\nALL enemies. Exhaust.", "art": "", "target": "all_enemies", "apply_status": {"type": "weak", "stacks": 3}, "apply_status_2": {"type": "vulnerable", "stacks": 3}, "exhaust": true, "actions": [{"type": "apply_status", "source": "apply_status"}, {"type": "apply_status", "source": "apply_status_2"}]}
	db["ic_armaments"] = {"id": "ic_armaments", "name": "Armaments", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 5, "description": "Gain 5 Block.", "art": "", "target": "self", "actions": [{"type": "block"}]}
	db["ic_power_through"] = {"id": "ic_power_through", "name": "Power Through", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 15, "description": "Gain 15 Block.\nAdd 2 Wounds to\nyour hand.", "art": "", "target": "self", "actions": [{"type": "block"}, {"type": "add_card_to_hand", "card_id": "status_wound", "count": 2}]}
	db["ic_offering"] = {"id": "ic_offering", "name": "Offering", "cost": 0, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Lose 6 HP.\nGain 2 Energy.\nDraw 3 cards.\nExhaust.", "art": "", "target": "self", "exhaust": true, "actions": [{"type": "self_damage", "value": 6}, {"type": "gain_energy", "value": 2}, {"type": "draw", "value": 3}]}
	db["ic_war_cry"] = {"id": "ic_war_cry", "name": "War Cry", "cost": 0, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Draw 1 card.\nExhaust.", "art": "", "target": "self", "draw": 1, "exhaust": true, "actions": [{"type": "draw"}]}
	db["ic_burning_pact"] = {"id": "ic_burning_pact", "name": "Burning Pact", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Exhaust 1 card.\nDraw 2 cards.", "art": "", "target": "self", "draw": 2, "actions": [{"type": "call", "fn": "burning_pact"}]}
	db["ic_seeing_red"] = {"id": "ic_seeing_red", "name": "Seeing Red", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Gain 2 Energy.\nExhaust.", "art": "", "target": "self", "energy_gain": 2, "exhaust": true, "actions": [{"type": "gain_energy", "value": 2}]}
	db["ic_second_wind"] = {"id": "ic_second_wind", "name": "Second Wind", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Exhaust all non-Attack\ncards in hand. Gain\n5 Block for each.", "art": "", "target": "self", "block_per": 5, "actions": [{"type": "call", "fn": "second_wind"}]}
	db["ic_intimidate"] = {"id": "ic_intimidate", "name": "Intimidate", "cost": 0, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Apply 1 Weak to\nALL enemies. Exhaust.", "art": "", "target": "all_enemies", "apply_status": {"type": "weak", "stacks": 1}, "exhaust": true, "actions": [{"type": "apply_status", "source": "apply_status"}]}
	db["ic_infernal_blade"] = {"id": "ic_infernal_blade", "name": "Infernal Blade", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Add a random Attack\nto your hand. It\ncosts 0. Exhaust.", "art": "", "target": "self", "exhaust": true, "actions": [{"type": "call", "fn": "infernal_blade"}]}
	db["ic_dual_wield"] = {"id": "ic_dual_wield", "name": "Dual Wield", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Copy an Attack or\nPower card in hand.", "art": "", "target": "self", "copies": 1, "actions": [{"type": "call", "fn": "dual_wield"}]}
	db["ic_ghostly_armor"] = {"id": "ic_ghostly_armor", "name": "Ghostly Armor", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 10, "description": "Ethereal.\nGain 10 Block.", "art": "", "target": "self", "ethereal": true, "actions": [{"type": "block"}]}
	db["ic_havoc"] = {"id": "ic_havoc", "name": "Havoc", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Play the top card of\nyour draw pile and\nExhaust it.", "art": "", "target": "self", "exhaust": true, "actions": [{"type": "call", "fn": "havoc"}]}
	db["ic_impervious"] = {"id": "ic_impervious", "name": "Impervious", "cost": 2, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 30, "description": "Gain 30 Block.\nExhaust.", "art": "", "target": "self", "exhaust": true, "actions": [{"type": "block"}]}
	db["ic_exhume"] = {"id": "ic_exhume", "name": "Exhume", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Put a card from your\nexhaust pile into\nyour hand. Exhaust.", "art": "", "target": "self", "exhaust": true, "actions": [{"type": "call", "fn": "exhume"}]}
	db["ic_sentinel"] = {"id": "ic_sentinel", "name": "Sentinel", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 5, "description": "Gain 5 Block.\nIf this card is\nExhausted, gain\n2 Energy.", "art": "", "target": "self", "status": "incomplete", "actions": [{"type": "block"}]}
	db["ic_spot_weakness"] = {"id": "ic_spot_weakness", "name": "Spot Weakness", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "If the enemy intends\nto attack, gain\n3 Strength.", "art": "", "target": "enemy", "spot_str": 3, "actions": [{"type": "call", "fn": "spot_weakness"}]}
	db["ic_true_grit"] = {"id": "ic_true_grit", "name": "True Grit", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 7, "description": "Gain 7 Block.\nExhaust a random\ncard in your hand.", "art": "", "target": "self", "actions": [{"type": "block"}, {"type": "call", "fn": "true_grit"}]}
	db["ic_disarm"] = {"id": "ic_disarm", "name": "Disarm", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "Enemy loses 2\nStrength. Exhaust.", "art": "", "target": "enemy", "apply_status": {"type": "strength", "stacks": -2}, "exhaust": true, "actions": [{"type": "apply_status", "source": "apply_status"}]}
	db["ic_double_tap"] = {"id": "ic_double_tap", "name": "Double Tap", "cost": 1, "type": CardType.SKILL, "character": "ironclad", "damage": 0, "block": 0, "description": "This turn, your next\nAttack is played twice.", "art": "", "target": "self", "power_effect": "double_tap", "actions": [{"type": "power_effect", "power": "double_tap"}]}

	# =========================================================================
	# POWERS (14 cards)
	# =========================================================================
	db["ic_demon_form"] = {"id": "ic_demon_form", "name": "Demon Form", "cost": 3, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "At the start of\neach turn, gain 2\nStrength.", "art": "", "target": "self", "power_effect": "demon_form", "actions": [{"type": "power_effect", "power": "demon_form"}]}
	db["ic_corruption"] = {"id": "ic_corruption", "name": "Corruption", "cost": 3, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Skills cost 0.\nWhenever you play a\nSkill, Exhaust it.", "art": "", "target": "self", "power_effect": "corruption", "actions": [{"type": "power_effect", "power": "corruption"}]}
	db["ic_berserk"] = {"id": "ic_berserk", "name": "Berserk", "cost": 0, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Gain 1 Vulnerable.\nAt the start of each\nturn, gain 1 Energy.", "art": "", "target": "self", "power_effect": "berserk", "actions": [{"type": "power_effect", "power": "berserk"}]}
	db["ic_feel_no_pain"] = {"id": "ic_feel_no_pain", "name": "Feel No Pain", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever a card is\nExhausted, gain\n3 Block.", "art": "", "target": "self", "power_effect": "feel_no_pain", "actions": [{"type": "power_effect", "power": "feel_no_pain"}]}
	db["ic_juggernaut"] = {"id": "ic_juggernaut", "name": "Juggernaut", "cost": 2, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever you gain\nBlock, deal 5 damage\nto a random enemy.", "art": "", "target": "self", "power_effect": "juggernaut", "actions": [{"type": "power_effect", "power": "juggernaut"}]}
	db["ic_evolve"] = {"id": "ic_evolve", "name": "Evolve", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever you draw a\nStatus card, draw 1.", "art": "", "target": "self", "power_effect": "evolve", "actions": [{"type": "power_effect", "power": "evolve"}]}
	db["ic_rage"] = {"id": "ic_rage", "name": "Rage", "cost": 0, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever you play an\nAttack this turn,\ngain 3 Block.", "art": "", "target": "self", "power_effect": "rage", "actions": [{"type": "power_effect", "power": "rage"}]}
	db["ic_barricade"] = {"id": "ic_barricade", "name": "Barricade", "cost": 3, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Block is not removed\nat the start of\nyour turn.", "art": "", "target": "self", "power_effect": "barricade", "actions": [{"type": "power_effect", "power": "barricade"}]}
	db["ic_inflame"] = {"id": "ic_inflame", "name": "Inflame", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Gain 2 Strength.", "art": "", "target": "self", "apply_self_status": {"type": "strength", "stacks": 2}, "actions": [{"type": "apply_self_status", "status": "strength", "stacks": 2}]}
	db["ic_metallicize"] = {"id": "ic_metallicize", "name": "Metallicize", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "At the end of your\nturn, gain 3 Block.", "art": "", "target": "self", "power_effect": "metallicize", "actions": [{"type": "power_effect", "power": "metallicize"}]}
	db["ic_brutality"] = {"id": "ic_brutality", "name": "Brutality", "cost": 0, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "At the start of your\nturn, lose 1 HP and\ndraw 1 card.", "art": "", "target": "self", "power_effect": "brutality", "actions": [{"type": "power_effect", "power": "brutality"}]}
	db["ic_combust"] = {"id": "ic_combust", "name": "Combust", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "At the end of your\nturn, lose 1 HP and\ndeal 5 damage to ALL\nenemies.", "art": "", "target": "self", "power_effect": "combust", "actions": [{"type": "power_effect", "power": "combust"}]}
	db["ic_dark_embrace"] = {"id": "ic_dark_embrace", "name": "Dark Embrace", "cost": 2, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever a card is\nExhausted, draw 1.", "art": "", "target": "self", "power_effect": "dark_embrace", "actions": [{"type": "power_effect", "power": "dark_embrace"}]}
	db["ic_rupture"] = {"id": "ic_rupture", "name": "Rupture", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever you lose HP\nfrom a card, gain\n1 Strength.", "art": "", "target": "self", "power_effect": "rupture", "actions": [{"type": "power_effect", "power": "rupture"}]}
	db["ic_fire_breathing"] = {"id": "ic_fire_breathing", "name": "Fire Breathing", "cost": 1, "type": CardType.POWER, "character": "ironclad", "damage": 0, "block": 0, "description": "Whenever you draw a\nStatus or Curse, deal\n6 damage to ALL.", "art": "", "target": "self", "power_effect": "fire_breathing", "actions": [{"type": "power_effect", "power": "fire_breathing"}]}

	return db

static func get_upgrade_overrides() -> Dictionary:
	return {
		# ATTACKS
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
		"ic_blood_for_blood": {"damage": 22, "description": "Costs 1 less for each\ntime you lose HP.\nDeal 22 damage."},
		# SKILLS
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
		"ic_double_tap": {"description": "This turn, your next\n2 Attacks are played\ntwice."},
		# POWERS
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
		"ic_fire_breathing": {"description": "Whenever you draw a\nStatus or Curse, deal\n10 damage to ALL."},
	}
