class_name SilentCards
## res://scripts/cards/silent_cards.gd — Silent card pack (pluggable)
## All Silent card definitions and upgrade overrides.

enum CardType { ATTACK, SKILL, POWER, STATUS }

static func get_cards() -> Dictionary:
	var db: Dictionary = {}

	# =========================================================================
	# BASIC CARDS (4 cards)
	# =========================================================================
	db["si_strike"] = {"id": "si_strike", "name": "Strike", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 6, "block": 0, "description": "Deal 6 damage.", "art": "", "target": "enemy", "actions": [{"type": "damage"}]}
	db["si_defend"] = {"id": "si_defend", "name": "Defend", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 5, "description": "Gain 5 Block.", "art": "", "target": "self", "hero_target": "target_hero", "actions": [{"type": "block"}]}
	db["si_neutralize"] = {"id": "si_neutralize", "name": "Neutralize", "cost": 0, "type": CardType.ATTACK, "character": "silent", "damage": 3, "block": 0, "description": "Deal 3 damage.\nApply 1 Weak.", "art": "", "target": "enemy", "apply_status": {"type": "weak", "stacks": 1}, "actions": [{"type": "damage"}, {"type": "apply_status", "source": "apply_status"}]}
	db["si_survivor"] = {"id": "si_survivor", "name": "Survivor", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 8, "description": "Gain 8 Block.\nDiscard 1 card.", "art": "", "target": "self", "discard": 1, "actions": [{"type": "block"}]}

	# =========================================================================
	# COMMON ATTACKS (9 cards)
	# =========================================================================
	db["si_slice"] = {"id": "si_slice", "name": "Slice", "cost": 0, "type": CardType.ATTACK, "character": "silent", "damage": 6, "block": 0, "description": "Deal 6 damage.", "art": "", "target": "enemy", "actions": [{"type": "damage"}]}
	db["si_dagger_spray"] = {"id": "si_dagger_spray", "name": "Dagger Spray", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 4, "block": 0, "description": "Deal 4 damage to ALL\nenemies twice.", "art": "", "target": "all_enemies", "times": 2, "actions": [{"type": "damage_all"}]}
	db["si_dagger_throw"] = {"id": "si_dagger_throw", "name": "Dagger Throw", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 9, "block": 0, "description": "Deal 9 damage.\nDraw 1, Discard 1.", "art": "", "target": "enemy", "draw": 1, "discard": 1, "actions": [{"type": "damage"}, {"type": "draw"}]}
	db["si_flick_flack"] = {"id": "si_flick_flack", "name": "Flick-Flack", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 7, "block": 0, "description": "Sly. Deal 7 damage\nto ALL enemies.", "art": "", "target": "all_enemies", "special": "sly", "actions": [{"type": "damage_all"}]}
	db["si_leading_strike"] = {"id": "si_leading_strike", "name": "Leading Strike", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 7, "block": 0, "description": "Deal 7 damage.\nAdd 1 Shiv to hand.", "art": "", "target": "enemy", "actions": [{"type": "damage"}, {"type": "add_shiv", "value": 1}]}
	db["si_poisoned_stab"] = {"id": "si_poisoned_stab", "name": "Poisoned Stab", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 6, "block": 0, "description": "Deal 6 damage.\nApply 3 Poison.", "art": "", "target": "enemy", "apply_status": {"type": "poison", "stacks": 3}, "actions": [{"type": "damage"}, {"type": "apply_status", "source": "apply_status"}]}
	db["si_sucker_punch"] = {"id": "si_sucker_punch", "name": "Sucker Punch", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 8, "block": 0, "description": "Deal 8 damage.\nApply 1 Weak.", "art": "", "target": "enemy", "apply_status": {"type": "weak", "stacks": 1}, "actions": [{"type": "damage"}, {"type": "apply_status", "source": "apply_status"}]}
	db["si_ricochet"] = {"id": "si_ricochet", "name": "Ricochet", "cost": 2, "type": CardType.ATTACK, "character": "silent", "damage": 3, "block": 0, "description": "Sly. Deal 3 damage\nto random enemy 4x.", "art": "", "target": "random_enemy", "times": 4, "special": "sly", "actions": [{"type": "damage"}]}
	db["si_quick_slash"] = {"id": "si_quick_slash", "name": "Quick Slash", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 8, "block": 0, "description": "Deal 8 damage.\nDraw 1 card.", "art": "", "target": "enemy", "draw": 1, "actions": [{"type": "damage"}, {"type": "draw"}]}

	# =========================================================================
	# COMMON SKILLS (12 cards)
	# =========================================================================
	db["si_anticipate"] = {"id": "si_anticipate", "name": "Anticipate", "cost": 0, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Gain 3 Dexterity\nthis turn.", "art": "", "target": "self", "hero_target": "all_heroes", "temp_dex": 3, "actions": [{"type": "call", "fn": "anticipate"}]}
	db["si_deflect"] = {"id": "si_deflect", "name": "Deflect", "cost": 0, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 4, "description": "Gain 4 Block.", "art": "", "target": "self", "actions": [{"type": "block"}]}
	db["si_prepared"] = {"id": "si_prepared", "name": "Prepared", "cost": 0, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Draw 1, Discard 1.", "art": "", "target": "self", "draw": 1, "discard": 1, "actions": [{"type": "draw"}]}
	db["si_backflip"] = {"id": "si_backflip", "name": "Backflip", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 5, "description": "Gain 5 Block.\nDraw 2 cards.", "art": "", "target": "self", "draw": 2, "actions": [{"type": "block"}, {"type": "draw"}]}
	db["si_dodge_and_roll"] = {"id": "si_dodge_and_roll", "name": "Dodge and Roll", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 4, "description": "Gain 4 Block this\nturn and next.", "art": "", "target": "self", "actions": [{"type": "block"}, {"type": "next_turn", "effect": {"type": "block", "value": 4}}]}
	db["si_cloak_and_dagger"] = {"id": "si_cloak_and_dagger", "name": "Cloak and Dagger", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 6, "description": "Gain 6 Block.\nAdd 1 Shiv to hand.", "art": "", "target": "self", "actions": [{"type": "block"}, {"type": "add_shiv", "value": 1}]}
	db["si_outmaneuver"] = {"id": "si_outmaneuver", "name": "Outmaneuver", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Gain 2 Energy\nnext turn.", "art": "", "target": "self", "actions": [{"type": "next_turn", "effect": {"type": "gain_energy", "value": 2}}]}
	db["si_acrobatics"] = {"id": "si_acrobatics", "name": "Acrobatics", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Draw 3 cards.\nDiscard 1.", "art": "", "target": "self", "draw": 3, "discard": 1, "actions": [{"type": "draw"}]}
	db["si_blade_dance"] = {"id": "si_blade_dance", "name": "Blade Dance", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Add 3 Shivs to\nyour hand.", "art": "", "target": "self", "actions": [{"type": "add_shiv", "value": 3}]}
	db["si_escape_plan"] = {"id": "si_escape_plan", "name": "Escape Plan", "cost": 0, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Draw 1 card. If it\nis a Skill, gain\n3 Block.", "art": "", "target": "self", "escape_block": 3, "actions": [{"type": "call", "fn": "escape_plan"}]}
	db["si_calculated_gamble"] = {"id": "si_calculated_gamble", "name": "Calculated Gamble", "cost": 0, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Discard your hand.\nDraw that many cards.", "art": "", "target": "self", "discard_hand_redraw": true, "actions": [{"type": "call", "fn": "calculated_gamble"}]}
	db["si_concentrate"] = {"id": "si_concentrate", "name": "Concentrate", "cost": 0, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Discard 3 cards.\nGain 2 Energy.", "art": "", "target": "self", "discard_count": 3, "energy_gain_val": 2, "actions": [{"type": "call", "fn": "concentrate"}]}

	# =========================================================================
	# UNCOMMON ATTACKS (12 cards)
	# =========================================================================
	db["si_predator"] = {"id": "si_predator", "name": "Predator", "cost": 2, "type": CardType.ATTACK, "character": "silent", "damage": 15, "block": 0, "description": "Deal 15 damage.", "art": "", "target": "enemy", "actions": [{"type": "damage"}]}
	db["si_masterful_stab"] = {"id": "si_masterful_stab", "name": "Masterful Stab", "cost": 0, "type": CardType.ATTACK, "character": "silent", "damage": 12, "block": 0, "description": "Innate.\nDeal 12 damage.", "art": "", "target": "enemy", "innate": true, "actions": [{"type": "damage"}]}
	db["si_skewer"] = {"id": "si_skewer", "name": "Skewer", "cost": -1, "type": CardType.ATTACK, "character": "silent", "damage": 7, "block": 0, "description": "Deal 7 damage X times.\n(X = current Energy)", "art": "", "target": "enemy", "actions": [{"type": "call", "fn": "skewer"}]}
	db["si_die_die_die"] = {"id": "si_die_die_die", "name": "Die Die Die", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 13, "block": 0, "description": "Deal 13 damage to\nALL enemies. Exhaust.", "art": "", "target": "all_enemies", "exhaust": true, "actions": [{"type": "damage_all"}]}
	db["si_endless_agony"] = {"id": "si_endless_agony", "name": "Endless Agony", "cost": 0, "type": CardType.ATTACK, "character": "silent", "damage": 4, "block": 0, "description": "Deal 4 damage.\nExhaust. When drawn,\nadd copy to hand.", "art": "", "target": "enemy", "exhaust": true, "status": "incomplete", "actions": [{"type": "damage"}]}
	db["si_eviscerate"] = {"id": "si_eviscerate", "name": "Eviscerate", "cost": 3, "type": CardType.ATTACK, "character": "silent", "damage": 7, "block": 0, "description": "Deal 7 damage\n3 times.", "art": "", "target": "enemy", "times": 3, "actions": [{"type": "damage"}]}
	db["si_finisher"] = {"id": "si_finisher", "name": "Finisher", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 6, "block": 0, "description": "Deal 6 damage for\neach Attack played\nthis turn.", "art": "", "target": "enemy", "hits_per_attack": true, "actions": [{"type": "call", "fn": "finisher"}]}
	db["si_flying_knee"] = {"id": "si_flying_knee", "name": "Flying Knee", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 8, "block": 0, "description": "Deal 8 damage.\nGain 1 Energy\nnext turn.", "art": "", "target": "enemy", "actions": [{"type": "damage"}, {"type": "next_turn", "effect": {"type": "gain_energy", "value": 1}}]}
	db["si_heel_hook"] = {"id": "si_heel_hook", "name": "Heel Hook", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 5, "block": 0, "description": "Deal 5 damage.\nIf enemy is Weak:\ngain 1 Energy, draw 1.", "art": "", "target": "enemy", "conditional_on_status": {"status": "weak", "energy": 1, "draw": 1}, "actions": [{"type": "call", "fn": "heel_hook"}]}
	db["si_glass_knife"] = {"id": "si_glass_knife", "name": "Glass Knife", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 8, "block": 0, "description": "Deal 8 damage twice.\nDamage decreases by 2\neach use.", "art": "", "target": "enemy", "times": 2, "damage_degrade": 2, "actions": [{"type": "call", "fn": "glass_knife"}]}
	db["si_choke"] = {"id": "si_choke", "name": "Choke", "cost": 2, "type": CardType.ATTACK, "character": "silent", "damage": 12, "block": 0, "description": "Deal 12 damage.\nWhenever enemy plays\na card, take 3 damage.", "art": "", "target": "enemy", "choke_stacks": 3, "status": "incomplete", "actions": [{"type": "call", "fn": "choke"}]}
	db["si_riddle_with_holes"] = {"id": "si_riddle_with_holes", "name": "Riddle with Holes", "cost": 2, "type": CardType.ATTACK, "character": "silent", "damage": 3, "block": 0, "description": "Deal 3 damage\n5 times.", "art": "", "target": "enemy", "times": 5, "actions": [{"type": "damage"}]}

	# =========================================================================
	# UNCOMMON SKILLS (15 cards)
	# =========================================================================
	db["si_blur"] = {"id": "si_blur", "name": "Blur", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 5, "description": "Gain 5 Block.\nBlock not removed\nnext turn.", "art": "", "target": "self", "actions": [{"type": "block"}, {"type": "blur"}]}
	db["si_dash"] = {"id": "si_dash", "name": "Dash", "cost": 2, "type": CardType.SKILL, "character": "silent", "damage": 10, "block": 10, "description": "Front hero gains\n10 Block.\nDeal 10 damage.", "art": "", "target": "enemy", "actions": [{"type": "block"}, {"type": "damage"}]}
	db["si_terror"] = {"id": "si_terror", "name": "Terror", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Apply 99 Vulnerable.\nExhaust.", "art": "", "target": "enemy", "apply_status": {"type": "vulnerable", "stacks": 99}, "exhaust": true, "actions": [{"type": "apply_status", "source": "apply_status"}]}
	db["si_distraction"] = {"id": "si_distraction", "name": "Distraction", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Add a random Skill\nto your hand.\nExhaust.", "art": "", "target": "self", "exhaust": true, "actions": [{"type": "call", "fn": "distraction"}]}
	db["si_expertise"] = {"id": "si_expertise", "name": "Expertise", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Draw cards until you\nhave 6 in hand.", "art": "", "target": "self", "target_hand_size": 6, "actions": [{"type": "call", "fn": "expertise"}]}
	db["si_leg_sweep"] = {"id": "si_leg_sweep", "name": "Leg Sweep", "cost": 2, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 11, "description": "Apply 2 Weak.\nAll heroes gain\n11 Block.", "art": "", "target": "enemy", "apply_status": {"type": "weak", "stacks": 2}, "actions": [{"type": "apply_status", "source": "apply_status"}, {"type": "block", "buff_target": "all_heroes"}]}
	db["si_reflex"] = {"id": "si_reflex", "name": "Reflex", "cost": 2, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Sly. Draw 2 cards.", "art": "", "target": "self", "special": "sly", "draw": 2, "actions": [{"type": "draw"}]}
	db["si_setup"] = {"id": "si_setup", "name": "Setup", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Put a card from hand\non top of draw pile.", "art": "", "target": "self", "status": "active", "actions": [{"type": "call", "fn": "setup"}]}
	db["si_tactician"] = {"id": "si_tactician", "name": "Tactician", "cost": 3, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Sly. Gain 1 Energy.", "art": "", "target": "self", "special": "sly", "actions": [{"type": "gain_energy", "value": 1}]}
	db["si_bouncing_flask"] = {"id": "si_bouncing_flask", "name": "Bouncing Flask", "cost": 2, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Apply 3 Poison to\nrandom enemies 3x.", "art": "", "target": "random_enemy", "apply_status": {"type": "poison", "stacks": 3}, "times": 3, "actions": [{"type": "apply_status", "source": "apply_status"}]}
	db["si_catalyst"] = {"id": "si_catalyst", "name": "Catalyst", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Double a target's\nPoison. Exhaust.", "art": "", "target": "enemy", "exhaust": true, "poison_mult": 2, "actions": [{"type": "call", "fn": "catalyst"}]}
	db["si_crippling_cloud"] = {"id": "si_crippling_cloud", "name": "Crippling Cloud", "cost": 2, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Apply 4 Poison and\n2 Weak to ALL enemies.", "art": "", "target": "all_enemies", "apply_status": {"type": "poison", "stacks": 4}, "apply_status_2": {"type": "weak", "stacks": 2}, "actions": [{"type": "apply_status", "source": "apply_status"}, {"type": "apply_status", "source": "apply_status_2"}]}
	db["si_deadly_poison"] = {"id": "si_deadly_poison", "name": "Deadly Poison", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Apply 5 Poison.", "art": "", "target": "enemy", "apply_status": {"type": "poison", "stacks": 5}, "actions": [{"type": "apply_status", "source": "apply_status"}]}
	db["si_noxious_fumes"] = {"id": "si_noxious_fumes", "name": "Noxious Fumes", "cost": 1, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "At start of turn,\napply 2 Poison to\nALL enemies.", "art": "", "target": "self", "power_effect": "noxious_fumes", "per_turn": {"poison_all": 2}, "power_stacks": 2, "actions": [{"type": "power_effect", "power": "noxious_fumes"}]}
	db["si_infinite_blades"] = {"id": "si_infinite_blades", "name": "Infinite Blades", "cost": 1, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "At start of turn,\nadd a Shiv to hand.", "art": "", "target": "self", "power_effect": "infinite_blades", "power_stacks": 1, "actions": [{"type": "power_effect", "power": "infinite_blades"}]}

	# =========================================================================
	# UNCOMMON POWERS (6 cards)
	# =========================================================================
	db["si_accuracy"] = {"id": "si_accuracy", "name": "Accuracy", "cost": 1, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "Shivs deal 4 more\ndamage.", "art": "", "target": "self", "power_effect": "accuracy", "power_stacks": 4, "actions": [{"type": "power_effect", "power": "accuracy"}]}
	db["si_caltrops"] = {"id": "si_caltrops", "name": "Caltrops", "cost": 1, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "When attacked, deal\n3 damage back.", "art": "", "target": "self", "hero_target": "target_hero", "power_effect": "caltrops", "power_stacks": 3, "actions": [{"type": "power_effect", "power": "caltrops"}]}
	db["si_a_thousand_cuts"] = {"id": "si_a_thousand_cuts", "name": "A Thousand Cuts", "cost": 2, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "Whenever you play a\ncard, deal 1 damage\nto ALL enemies.", "art": "", "target": "self", "power_effect": "a_thousand_cuts", "power_stacks": 1, "actions": [{"type": "power_effect", "power": "a_thousand_cuts"}]}
	db["si_envenom"] = {"id": "si_envenom", "name": "Envenom", "cost": 2, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "Whenever you deal\nunblocked damage,\napply 1 Poison.", "art": "", "target": "self", "hero_target": "target_hero", "power_effect": "envenom", "power_stacks": 1, "actions": [{"type": "power_effect", "power": "envenom"}]}
	db["si_footwork"] = {"id": "si_footwork", "name": "Footwork", "cost": 1, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "Gain 2 Dexterity.", "art": "", "target": "self", "hero_target": "all_heroes", "apply_self_status": {"type": "dexterity", "stacks": 2}, "actions": [{"type": "apply_self_status", "status": "dexterity", "stacks": 2}]}
	db["si_tools_of_the_trade"] = {"id": "si_tools_of_the_trade", "name": "Tools of the Trade", "cost": 1, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "At start of turn,\ndraw 1, discard 1.", "art": "", "target": "self", "power_effect": "tools_of_the_trade", "power_stacks": 1, "actions": [{"type": "power_effect", "power": "tools_of_the_trade"}]}

	# =========================================================================
	# RARE ATTACKS (3 cards)
	# =========================================================================
	db["si_backstab"] = {"id": "si_backstab", "name": "Backstab", "cost": 0, "type": CardType.ATTACK, "character": "silent", "damage": 11, "block": 0, "description": "Deal 11 damage.\nInnate. Exhaust.", "art": "", "target": "enemy", "innate": true, "exhaust": true, "actions": [{"type": "damage"}]}
	db["si_grand_finale"] = {"id": "si_grand_finale", "name": "Grand Finale", "cost": 0, "type": CardType.ATTACK, "character": "silent", "damage": 50, "block": 0, "description": "Can only play if draw\npile is empty.\nDeal 50 damage.", "art": "", "target": "enemy", "special": "grand_finale", "actions": [{"type": "call", "fn": "grand_finale"}]}
	db["si_unload"] = {"id": "si_unload", "name": "Unload", "cost": 1, "type": CardType.ATTACK, "character": "silent", "damage": 14, "block": 0, "description": "Deal 14 damage.\nDiscard all non-Attack\ncards in hand.", "art": "", "target": "enemy", "exhaust_non_attacks": true, "actions": [{"type": "call", "fn": "unload"}]}

	# =========================================================================
	# RARE SKILLS (8 cards)
	# =========================================================================
	db["si_adrenaline"] = {"id": "si_adrenaline", "name": "Adrenaline", "cost": 0, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Gain 1 Energy.\nDraw 2 cards.\nExhaust.", "art": "", "target": "self", "draw": 2, "energy_gain": 1, "exhaust": true, "actions": [{"type": "gain_energy", "value": 1}, {"type": "draw"}]}
	db["si_alchemize"] = {"id": "si_alchemize", "name": "Alchemize", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Obtain a random\npotion. Exhaust.", "art": "", "target": "self", "exhaust": true, "status": "incomplete", "actions": [{"type": "call", "fn": "alchemize"}]}
	db["si_bullet_time"] = {"id": "si_bullet_time", "name": "Bullet Time", "cost": 3, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Cards cost 0 this\nturn. No draw\nnext turn.", "art": "", "target": "self", "actions": [{"type": "bullet_time"}]}
	db["si_burst"] = {"id": "si_burst", "name": "Burst", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Next Skill is played\ntwice.", "art": "", "target": "self", "actions": [{"type": "burst"}]}
	db["si_corpse_explosion"] = {"id": "si_corpse_explosion", "name": "Corpse Explosion", "cost": 2, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Apply 6 Poison.\nWhen enemy dies, deal\ndamage to ALL.\nExhaust.", "art": "", "target": "enemy", "apply_status": {"type": "poison", "stacks": 6}, "exhaust": true, "status": "incomplete", "actions": [{"type": "apply_status", "source": "apply_status"}, {"type": "call", "fn": "corpse_explosion"}]}
	db["si_malaise"] = {"id": "si_malaise", "name": "Malaise", "cost": -1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Enemy loses X Strength.\nApply X Weak. Exhaust.", "art": "", "target": "enemy", "exhaust": true, "actions": [{"type": "call", "fn": "malaise"}]}
	db["si_nightmare"] = {"id": "si_nightmare", "name": "Nightmare", "cost": 3, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Choose a card. Add\n3 copies to hand\nnext turn. Exhaust.", "art": "", "target": "self", "exhaust": true, "status": "incomplete", "actions": [{"type": "draw", "value": 0}]}
	db["si_phantasmal_killer"] = {"id": "si_phantasmal_killer", "name": "Phantasmal Killer", "cost": 1, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Next turn, deal\ndouble damage.", "art": "", "target": "self", "actions": [{"type": "phantasmal_killer"}]}

	# =========================================================================
	# RARE POWERS (4 cards)
	# =========================================================================
	db["si_after_image"] = {"id": "si_after_image", "name": "After Image", "cost": 1, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "Whenever you play a\ncard, gain 1 Block.", "art": "", "target": "self", "hero_target": "target_hero", "power_effect": "after_image", "power_stacks": 1, "actions": [{"type": "power_effect", "power": "after_image"}]}
	db["si_well_laid_plans"] = {"id": "si_well_laid_plans", "name": "Well-Laid Plans", "cost": 1, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "At end of turn,\nRetain up to 1 card.", "art": "", "target": "self", "power_effect": "well_laid_plans", "power_stacks": 1, "actions": [{"type": "power_effect", "power": "well_laid_plans"}]}
	db["si_wraith_form"] = {"id": "si_wraith_form", "name": "Wraith Form", "cost": 3, "type": CardType.POWER, "character": "silent", "damage": 0, "block": 0, "description": "Gain 2 Intangible.\nLose 1 Dexterity\nper turn.", "art": "", "target": "self", "hero_target": "target_hero", "power_effect": "wraith_form", "power_stacks": 2, "status": "incomplete", "actions": [{"type": "power_effect", "power": "wraith_form"}]}

	# =========================================================================
	# SPECIAL CARDS (3 cards)
	# =========================================================================
	db["si_storm_of_steel"] = {"id": "si_storm_of_steel", "name": "Storm of Steel", "cost": 0, "type": CardType.SKILL, "character": "silent", "damage": 0, "block": 0, "description": "Discard your hand.\nAdd a Shiv per card\ndiscarded.", "art": "", "target": "self", "discard_hand_generate": true, "generate_damage": 4, "actions": [{"type": "call", "fn": "storm_of_steel"}]}
	db["si_shiv"] = {"id": "si_shiv", "name": "Shiv", "cost": 0, "type": CardType.ATTACK, "character": "silent", "damage": 4, "block": 0, "description": "Deal 4 damage.\nExhaust.", "art": "", "target": "enemy", "exhaust": true, "actions": [{"type": "damage"}]}
	db["si_shiv_plus"] = {"id": "si_shiv_plus", "name": "Shiv+", "cost": 0, "type": CardType.ATTACK, "character": "silent", "damage": 6, "block": 0, "description": "Deal 6 damage.\nExhaust.", "art": "", "target": "enemy", "exhaust": true, "upgraded": true, "actions": [{"type": "damage"}]}

	return db

static func get_upgrade_overrides() -> Dictionary:
	return {
		# BASIC
		"si_strike": {"damage": 9, "description": "Deal 9 damage."},
		"si_defend": {"block": 8, "description": "Gain 8 Block."},
		"si_neutralize": {"damage": 4, "apply_status": {"type": "weak", "stacks": 2}, "description": "Deal 4 damage.\nApply 2 Weak."},
		"si_survivor": {"block": 11, "description": "Gain 11 Block.\nDiscard 1 card."},
		# COMMON ATTACKS
		"si_slice": {"damage": 9, "description": "Deal 9 damage."},
		"si_dagger_spray": {"damage": 6, "description": "Deal 6 damage to ALL\nenemies twice."},
		"si_dagger_throw": {"damage": 12, "description": "Deal 12 damage.\nDraw 1, Discard 1."},
		"si_flick_flack": {"damage": 10, "description": "Sly. Deal 10 damage\nto ALL enemies."},
		"si_leading_strike": {"damage": 10, "description": "Deal 10 damage.\nAdd 1 Shiv to hand."},
		"si_poisoned_stab": {"damage": 8, "apply_status": {"type": "poison", "stacks": 4}, "description": "Deal 8 damage.\nApply 4 Poison."},
		"si_sucker_punch": {"damage": 11, "apply_status": {"type": "weak", "stacks": 2}, "description": "Deal 11 damage.\nApply 2 Weak."},
		"si_ricochet": {"damage": 4, "description": "Sly. Deal 4 damage\nto random enemy 4x."},
		"si_quick_slash": {"damage": 12, "description": "Deal 12 damage.\nDraw 1 card."},
		# COMMON SKILLS
		"si_anticipate": {"temp_dex": 5, "description": "Gain 5 Dexterity\nthis turn."},
		"si_deflect": {"block": 7, "description": "Gain 7 Block."},
		"si_prepared": {"draw": 2, "description": "Draw 2, Discard 1."},
		"si_backflip": {"block": 8, "description": "Gain 8 Block.\nDraw 2 cards."},
		"si_dodge_and_roll": {"block": 6, "description": "Gain 6 Block this\nturn and next.", "actions": [{"type": "block"}, {"type": "next_turn", "effect": {"type": "block", "value": 6}}]},
		"si_cloak_and_dagger": {"block": 6, "description": "Gain 6 Block.\nAdd 2 Shivs to hand.", "actions": [{"type": "block"}, {"type": "add_shiv", "value": 2}]},
		"si_outmaneuver": {"description": "Gain 3 Energy\nnext turn.", "actions": [{"type": "next_turn", "effect": {"type": "gain_energy", "value": 3}}]},
		"si_acrobatics": {"draw": 4, "description": "Draw 4 cards.\nDiscard 1."},
		"si_blade_dance": {"description": "Add 4 Shivs to\nyour hand.", "actions": [{"type": "add_shiv", "value": 4}]},
		"si_escape_plan": {"escape_block": 5, "description": "Draw 1 card. If it\nis a Skill, gain\n5 Block."},
		"si_calculated_gamble": {"description": "Discard your hand.\nDraw that many +1."},
		"si_concentrate": {"discard_count": 2, "description": "Discard 2 cards.\nGain 2 Energy."},
		# UNCOMMON ATTACKS
		"si_predator": {"damage": 20, "description": "Deal 20 damage."},
		"si_masterful_stab": {"damage": 16, "description": "Innate.\nDeal 16 damage."},
		"si_skewer": {"damage": 10, "description": "Deal 10 damage X times.\n(X = current Energy)"},
		"si_die_die_die": {"damage": 17, "description": "Deal 17 damage to\nALL enemies. Exhaust."},
		"si_endless_agony": {"damage": 6, "description": "Deal 6 damage.\nExhaust. When drawn,\nadd copy to hand."},
		"si_eviscerate": {"damage": 9, "description": "Deal 9 damage\n3 times."},
		"si_finisher": {"damage": 8, "description": "Deal 8 damage for\neach Attack played\nthis turn."},
		"si_flying_knee": {"damage": 11, "description": "Deal 11 damage.\nGain 1 Energy\nnext turn."},
		"si_heel_hook": {"damage": 8, "description": "Deal 8 damage.\nIf enemy is Weak:\ngain 1 Energy, draw 1."},
		"si_glass_knife": {"damage": 12, "description": "Deal 12 damage twice.\nDamage decreases by 2\neach use.", "damage_degrade": 2},
		"si_choke": {"damage": 16, "choke_stacks": 4, "description": "Deal 16 damage.\nWhenever enemy plays\na card, take 4 damage."},
		"si_riddle_with_holes": {"damage": 4, "description": "Deal 4 damage\n5 times."},
		# UNCOMMON SKILLS
		"si_blur": {"block": 8, "description": "Gain 8 Block.\nBlock not removed\nnext turn."},
		"si_dash": {"damage": 13, "block": 13, "description": "Front hero gains\n13 Block.\nDeal 13 damage."},
		"si_terror": {"cost": 0, "description": "Apply 99 Vulnerable.\nExhaust."},
		"si_distraction": {"cost": 0, "description": "Add a random Skill\nto your hand.\nExhaust."},
		"si_expertise": {"target_hand_size": 7, "description": "Draw cards until you\nhave 7 in hand."},
		"si_infinite_blades": {"description": "At start of turn,\nadd a Shiv+ to hand."},
		"si_leg_sweep": {"block": 14, "apply_status": {"type": "weak", "stacks": 3}, "description": "Apply 3 Weak.\nAll heroes gain\n14 Block.", "actions": [{"type": "apply_status", "source": "apply_status"}, {"type": "block", "buff_target": "all_heroes"}]},
		"si_reflex": {"draw": 3, "description": "Sly. Draw 3 cards."},
		"si_setup": {"cost": 0, "description": "Put a card from hand\non top of draw pile."},
		"si_tactician": {"description": "Sly. Gain 2 Energy.", "actions": [{"type": "gain_energy", "value": 2}]},
		"si_bouncing_flask": {"apply_status": {"type": "poison", "stacks": 4}, "description": "Apply 4 Poison to\nrandom enemies 3x."},
		"si_catalyst": {"poison_mult": 3, "description": "Triple a target's\nPoison. Exhaust."},
		"si_crippling_cloud": {"apply_status": {"type": "poison", "stacks": 7}, "apply_status_2": {"type": "weak", "stacks": 3}, "description": "Apply 7 Poison and\n3 Weak to ALL enemies."},
		"si_deadly_poison": {"apply_status": {"type": "poison", "stacks": 7}, "description": "Apply 7 Poison."},
		"si_noxious_fumes": {"description": "At start of turn,\napply 3 Poison to\nALL enemies.", "power_effect": "noxious_fumes_plus", "per_turn": {"poison_all": 3}, "power_stacks": 3},
		# UNCOMMON POWERS
		"si_accuracy": {"description": "Shivs deal 6 more\ndamage.", "power_effect": "accuracy_plus", "power_stacks": 6},
		"si_caltrops": {"description": "When attacked, deal\n5 damage back.", "power_effect": "caltrops_plus", "power_stacks": 5},
		"si_a_thousand_cuts": {"description": "Whenever you play a\ncard, deal 2 damage\nto ALL enemies.", "power_effect": "a_thousand_cuts_plus", "power_stacks": 2},
		"si_envenom": {"description": "Whenever you deal\nunblocked damage,\napply 2 Poison.", "power_effect": "envenom_plus", "power_stacks": 2},
		"si_footwork": {"apply_self_status": {"type": "dexterity", "stacks": 3}, "description": "Gain 3 Dexterity."},
		"si_tools_of_the_trade": {"description": "At start of turn,\ndraw 1, discard 1."},
		# RARE ATTACKS
		"si_backstab": {"damage": 15, "description": "Deal 15 damage.\nInnate. Exhaust."},
		"si_grand_finale": {"damage": 60, "description": "Can only play if draw\npile is empty.\nDeal 60 damage."},
		"si_unload": {"damage": 18, "description": "Deal 18 damage.\nDiscard all non-Attack\ncards in hand."},
		# RARE SKILLS
		"si_adrenaline": {"draw": 3, "description": "Gain 2 Energy.\nDraw 3 cards.\nExhaust.", "energy_gain": 2, "actions": [{"type": "gain_energy", "value": 2}, {"type": "draw"}]},
		"si_alchemize": {"cost": 0, "description": "Obtain a random\npotion. Exhaust."},
		"si_bullet_time": {"cost": 2, "description": "Cards cost 0 this\nturn. No draw\nnext turn."},
		"si_burst": {"description": "Next 2 Skills are\nplayed twice."},
		"si_corpse_explosion": {"apply_status": {"type": "poison", "stacks": 9}, "description": "Apply 9 Poison.\nWhen enemy dies, deal\ndamage to ALL."},
		"si_malaise": {"description": "Enemy loses X+1\nStrength. Apply X+1\nWeak."},
		"si_nightmare": {"cost": 2, "description": "Choose a card. Add\n3 copies to hand\nnext turn."},
		"si_phantasmal_killer": {"description": "Next turn, deal\ndouble damage."},
		# RARE POWERS
		"si_after_image": {"description": "Whenever you play a\ncard, gain 1 Block."},
		"si_storm_of_steel": {"description": "Discard your hand.\nAdd a Shiv+ per card\ndiscarded.", "generate_damage": 6},
		"si_well_laid_plans": {"description": "At end of turn,\nRetain up to 2 cards.", "power_effect": "well_laid_plans_plus"},
		"si_wraith_form": {"description": "Gain 3 Intangible.\nLose 1 Dexterity\nper turn.", "power_effect": "wraith_form_plus", "power_stacks": 3},
	}
