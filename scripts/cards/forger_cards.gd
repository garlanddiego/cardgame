class_name ForgerCards
## res://scripts/cards/forger_cards.gd — Forger card pack (pluggable)
## 铸造者: Greatsword summoning, Forge mechanic, defensive support

enum CardType { ATTACK, SKILL, POWER, STATUS }

static func get_cards() -> Dictionary:
	var db: Dictionary = {}

	# =========================================================================
	# BASIC CARDS (2)
	# =========================================================================
	db["fg_strike"] = {"id": "fg_strike", "name": "锻击", "cost": 1, "type": CardType.ATTACK, "character": "forger", "damage": 6, "block": 0, "description": "造成6点伤害。", "art": "res://assets/img/card_art/fg_strike.png", "target": "enemy", "version": "new", "rarity": "basic", "actions": [{"type": "damage"}]}
	db["fg_defend"] = {"id": "fg_defend", "name": "防御", "cost": 1, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 5, "description": "目标英雄获得\n5点格挡。", "art": "res://assets/img/card_art/fg_defend.png", "target": "self", "version": "new", "hero_target": "target_hero", "rarity": "basic", "actions": [{"type": "block"}]}

	# =========================================================================
	# ATTACKS (13 cards)
	# =========================================================================
	db["fg_sword_crash"] = {"id": "fg_sword_crash", "name": "剑崩", "cost": 1, "type": CardType.ATTACK, "character": "forger", "damage": 0, "block": 0, "description": "造成等同于巨剑\n当前生命值的伤害。", "art": "res://assets/img/card_art/fg_sword_crash.png", "target": "enemy", "version": "new", "rarity": "common", "actions": [{"type": "call", "fn": "sword_crash"}]}
	db["fg_riposte_strike"] = {"id": "fg_riposte_strike", "name": "反击斩", "cost": 1, "type": CardType.ATTACK, "character": "forger", "damage": 6, "block": 0, "description": "造成6点伤害。\n额外造成所有英雄\n+巨剑荆棘×2\n的伤害。", "art": "res://assets/img/card_art/fg_riposte_strike.png", "target": "enemy", "version": "new", "rarity": "uncommon", "fg_thorns_mult": 2, "actions": [{"type": "call", "fn": "riposte_strike"}]}
	db["fg_shield_bash"] = {"id": "fg_shield_bash", "name": "盾击", "cost": 1, "type": CardType.ATTACK, "character": "forger", "damage": 0, "block": 0, "description": "造成等同于铸造者\n当前格挡值的伤害。", "art": "res://assets/img/card_art/fg_shield_bash.png", "target": "enemy", "version": "new", "rarity": "common", "actions": [{"type": "call", "fn": "fg_shield_bash"}]}
	db["fg_forge_slam"] = {"id": "fg_forge_slam", "name": "锻击猛击", "cost": 2, "type": CardType.ATTACK, "character": "forger", "damage": 6, "block": 0, "description": "巨剑对所有敌人\n造成6点伤害。\n巨剑获得未被\n格挡的生命值。", "art": "res://assets/img/card_art/fg_forge_slam.png", "target": "all_enemies", "version": "new", "rarity": "uncommon", "actions": [{"type": "call", "fn": "forge_slam"}]}
	db["fg_greatsword_cleave"] = {"id": "fg_greatsword_cleave", "name": "巨剑横扫", "cost": 2, "type": CardType.ATTACK, "character": "forger", "damage": 0, "block": 0, "description": "对所有敌人造成\n等同于巨剑\n生命值的伤害。", "art": "res://assets/img/card_art/fg_greatsword_cleave.png", "target": "all_enemies", "version": "new", "rarity": "uncommon", "actions": [{"type": "call", "fn": "greatsword_cleave"}]}
	db["fg_tempered_strike"] = {"id": "fg_tempered_strike", "name": "淬炼打击", "cost": 1, "type": CardType.ATTACK, "character": "forger", "damage": 6, "block": 6, "description": "造成6点伤害。\n获得6点格挡。", "art": "res://assets/img/card_art/fg_tempered_strike.png", "target": "enemy", "version": "new", "rarity": "common", "actions": [{"type": "damage"}, {"type": "block"}]}
	db["fg_magnetic_edge"] = {"id": "fg_magnetic_edge", "status": "pending", "name": "磁刃", "cost": 1, "type": CardType.ATTACK, "character": "forger", "damage": 5, "block": 0, "description": "造成5点伤害。\n铸造+4。\n若巨剑HP≥20，\n改为12点伤害。", "art": "res://assets/img/card_art/fg_magnetic_edge.png", "target": "enemy", "version": "new", "rarity": "uncommon", "fg_forge": 4, "fg_threshold": 20, "fg_threshold_damage": 12, "actions": [{"type": "call", "fn": "magnetic_edge"}]}
	db["fg_molten_core"] = {"id": "fg_molten_core", "status": "pending", "name": "熔核", "cost": 2, "type": CardType.ATTACK, "character": "forger", "damage": 8, "block": 0, "description": "造成8点伤害2次。\n铸造+6。", "art": "res://assets/img/card_art/fg_molten_core.png", "target": "enemy", "version": "new", "rarity": "uncommon", "times": 2, "fg_forge": 6, "actions": [{"type": "call", "fn": "molten_core"}]}
	db["fg_hardened_blade"] = {"id": "fg_hardened_blade", "status": "pending", "name": "硬化之刃", "cost": 1, "type": CardType.ATTACK, "character": "forger", "damage": 8, "block": 0, "description": "造成8点伤害。\n若巨剑存在，\n获得4点格挡。", "art": "res://assets/img/card_art/fg_hardened_blade.png", "target": "enemy", "version": "new", "rarity": "common", "fg_sword_block": 4, "actions": [{"type": "call", "fn": "hardened_blade"}]}
	db["fg_reforged_edge"] = {"id": "fg_reforged_edge", "status": "pending", "name": "重铸之锋", "cost": 1, "type": CardType.ATTACK, "character": "forger", "damage": 7, "block": 0, "description": "造成7点伤害。\n若本回合已铸造，\n额外造成7点。", "art": "res://assets/img/card_art/fg_reforged_edge.png", "target": "enemy", "version": "new", "rarity": "common", "fg_forged_bonus": 7, "actions": [{"type": "call", "fn": "reforged_edge"}]}
	db["fg_eruption_strike"] = {"id": "fg_eruption_strike", "status": "pending", "name": "爆裂打击", "cost": 2, "type": CardType.ATTACK, "character": "forger", "damage": 15, "block": 0, "description": "造成15点伤害。\n下回合+1能量。\n铸造+4。", "art": "res://assets/img/card_art/fg_eruption_strike.png", "target": "enemy", "version": "new", "rarity": "rare", "fg_forge": 4, "actions": [{"type": "call", "fn": "eruption_strike"}]}
	db["fg_blade_storm"] = {"id": "fg_blade_storm", "status": "pending", "name": "刃暴", "cost": 3, "type": CardType.ATTACK, "character": "forger", "damage": 0, "block": 0, "description": "对所有敌人造成\n巨剑HP 50%的\n伤害×3。消耗。", "art": "res://assets/img/card_art/fg_blade_storm.png", "target": "all_enemies", "version": "new", "rarity": "rare", "exhaust": true, "fg_sword_pct": 50, "fg_hits": 3, "actions": [{"type": "call", "fn": "blade_storm"}]}
	db["fg_thorn_burst"] = {"id": "fg_thorn_burst", "name": "荆棘爆发", "cost": 1, "type": CardType.ATTACK, "character": "forger", "damage": 6, "block": 0, "description": "对所有敌人造成\n6点伤害，额外造成\n所有英雄和巨剑\n荆棘总和×2伤害。\n移除所有荆棘。", "art": "res://assets/img/card_art/fg_thorn_burst.png", "target": "all_enemies", "version": "new", "rarity": "uncommon", "fg_thorns_mult": 2, "fg_remove_thorns": true, "actions": [{"type": "call", "fn": "thorn_burst"}]}
	db["fg_bulwark_slam"] = {"id": "fg_bulwark_slam", "name": "壁垒猛击", "cost": 1, "type": CardType.ATTACK, "character": "forger", "damage": 0, "block": 0, "description": "对所有敌人造成\n等同于铸造者\n格挡值的伤害。\n消耗所有格挡。", "art": "res://assets/img/card_art/fg_bulwark_slam.png", "target": "all_enemies", "version": "new", "rarity": "common", "fg_consume_block": true, "actions": [{"type": "call", "fn": "bulwark_slam"}]}

	# =========================================================================
	# SKILLS (22 cards)
	# =========================================================================
	db["fg_delay_charge"] = {"id": "fg_delay_charge", "name": "蓄力", "cost": 2, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 0, "description": "铸造10。\n下回合+1能量。", "art": "res://assets/img/card_art/fg_delay_charge.png", "target": "self", "version": "new", "hero_target": "self", "rarity": "common", "fg_forge": 10, "fg_next_energy": 1, "actions": [{"type": "call", "fn": "delay_charge"}]}
	db["fg_sharpen"] = {"id": "fg_sharpen", "status": "pending", "name": "磨砺", "cost": 1, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 0, "description": "铸造+8。\n抽1张牌。", "art": "res://assets/img/card_art/fg_sharpen.png", "target": "self", "version": "new", "hero_target": "self", "rarity": "common", "fg_forge": 8, "draw": 1, "actions": [{"type": "call", "fn": "sharpen"}]}
	db["fg_forge_armor"] = {"id": "fg_forge_armor", "status": "pending", "name": "锻甲", "cost": 2, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 10, "description": "获得10点格挡。\n铸造+5。", "art": "res://assets/img/card_art/fg_forge_armor.png", "target": "self", "version": "new", "hero_target": "target_hero", "rarity": "common", "fg_forge": 5, "actions": [{"type": "call", "fn": "forge_armor"}]}
	db["fg_impervious_wall"] = {"id": "fg_impervious_wall", "name": "不破之墙", "cost": 2, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 0, "description": "巨剑获得20点\n生命。消耗。", "art": "res://assets/img/card_art/fg_impervious_wall.png", "target": "self", "version": "new", "hero_target": "self", "rarity": "uncommon", "exhaust": true, "fg_forge": 20, "actions": [{"type": "call", "fn": "impervious_wall"}]}
	db["fg_block_transfer"] = {"id": "fg_block_transfer", "name": "格挡转移", "cost": 1, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 0, "description": "将所有英雄格挡\n转化为巨剑HP。", "art": "res://assets/img/card_art/fg_block_transfer.png", "target": "self", "version": "new", "hero_target": "self", "rarity": "uncommon", "actions": [{"type": "call", "fn": "block_transfer"}]}
	db["fg_summon_sword"] = {"id": "fg_summon_sword", "name": "召唤巨剑", "cost": 1, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 0, "description": "巨剑+6生命。", "art": "res://assets/img/card_art/fg_summon_sword.png", "target": "self", "version": "new", "hero_target": "self", "rarity": "common", "fg_summon_hp": 6, "actions": [{"type": "call", "fn": "summon_sword"}]}
	db["fg_reinforce"] = {"id": "fg_reinforce", "name": "加固", "cost": 2, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 0, "description": "巨剑获得等同于\n其当前生命100%\n的额外生命。\n消耗。", "art": "res://assets/img/card_art/fg_reinforce.png", "target": "self", "version": "new", "hero_target": "self", "rarity": "uncommon", "exhaust": true, "fg_reinforce_pct": 100, "actions": [{"type": "call", "fn": "reinforce"}]}
	db["fg_temper"] = {"id": "fg_temper", "name": "回火", "cost": 1, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 6, "description": "获得6点格挡。\n下回合获得6点\n格挡。", "art": "res://assets/img/card_art/fg_temper.png", "target": "self", "version": "new", "hero_target": "target_hero", "rarity": "common", "fg_next_block": 6, "actions": [{"type": "call", "fn": "temper"}]}
	db["fg_forge_shield"] = {"id": "fg_forge_shield", "name": "锻盾", "cost": 2, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 10, "description": "目标英雄获得\n10点格挡。\n下回合+2抽牌。", "art": "res://assets/img/card_art/fg_forge_shield.png", "target": "self", "version": "new", "hero_target": "target_hero", "rarity": "common", "fg_next_draw": 2, "actions": [{"type": "call", "fn": "forge_shield"}]}
	db["fg_melt_down"] = {"id": "fg_melt_down", "name": "熔炼", "cost": 1, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 0, "description": "消耗1张手牌。\n巨剑获得其费用×6\n的生命。\n下回合+2抽牌。", "art": "res://assets/img/card_art/fg_melt_down.png", "target": "self", "version": "new", "hero_target": "self", "rarity": "uncommon", "fg_cost_mult": 6, "fg_next_draw": 2, "actions": [{"type": "call", "fn": "melt_down"}]}
	db["fg_overcharge"] = {"id": "fg_overcharge", "name": "超载", "cost": 1, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 0, "description": "本回合巨剑\n造成双倍伤害。", "art": "res://assets/img/card_art/fg_overcharge.png", "target": "self", "version": "new", "hero_target": "self", "rarity": "common", "actions": [{"type": "call", "fn": "overcharge"}]}
	db["fg_absorb_impact"] = {"id": "fg_absorb_impact", "name": "吸收冲击", "cost": 1, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 0, "description": "目标英雄获得\n巨剑生命值的格挡。\n巨剑失去所有生命，\n本回合不能\n再召唤巨剑。", "art": "res://assets/img/card_art/fg_absorb_impact.png", "target": "self", "version": "new", "hero_target": "target_hero", "rarity": "common", "actions": [{"type": "call", "fn": "absorb_impact"}]}
	db["fg_heat_treat"] = {"id": "fg_heat_treat", "status": "pending", "name": "热处理", "cost": 1, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 0, "description": "铸造+6。\n获得1层荆棘。", "art": "res://assets/img/card_art/fg_heat_treat.png", "target": "self", "version": "new", "hero_target": "self", "rarity": "common", "fg_forge": 6, "fg_thorns": 1, "actions": [{"type": "call", "fn": "heat_treat"}]}
	db["fg_forge_barrier"] = {"id": "fg_forge_barrier", "status": "pending", "name": "锻造屏障", "cost": 2, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 0, "description": "获得等同于巨剑\nHP的格挡。", "art": "res://assets/img/card_art/fg_forge_barrier.png", "target": "self", "version": "new", "hero_target": "target_hero", "rarity": "rare", "actions": [{"type": "call", "fn": "forge_barrier"}]}
	db["fg_sword_sacrifice"] = {"id": "fg_sword_sacrifice", "name": "剑之牺牲", "cost": 1, "type": CardType.ATTACK, "character": "forger", "damage": 10, "block": 10, "description": "对所有敌人造成\n10点伤害。\n获得10点格挡。\n消耗巨剑。\n本回合不能召唤巨剑。", "art": "res://assets/img/card_art/fg_sword_sacrifice.png", "target": "all_enemies", "version": "new", "hero_target": "target_hero", "rarity": "uncommon", "fg_sacrifice_dmg": 10, "fg_sacrifice_block": 10, "actions": [{"type": "call", "fn": "sword_sacrifice"}]}
	db["fg_thorn_forge"] = {"id": "fg_thorn_forge", "name": "荆棘锻造", "cost": 1, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 0, "description": "铸造2。巨剑获得\n4层荆棘(本回合)。", "art": "res://assets/img/card_art/fg_thorn_forge.png", "target": "self", "version": "new", "hero_target": "target_hero", "rarity": "common", "fg_forge": 2, "fg_hero_thorns": 0, "fg_sword_thorns": 4, "actions": [{"type": "call", "fn": "thorn_forge"}]}
	db["fg_salvage"] = {"id": "fg_salvage", "name": "打捞", "cost": 1, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 6, "description": "获得6点格挡。\n从弃牌堆选择\n1张牌置于\n抽牌堆顶。", "art": "res://assets/img/card_art/fg_salvage.png", "target": "self", "version": "new", "hero_target": "target_hero", "rarity": "common", "actions": [{"type": "call", "fn": "salvage"}]}
	db["fg_thorn_wall"] = {"id": "fg_thorn_wall", "name": "荆棘之墙", "cost": 1, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 0, "description": "巨剑获得2层荆棘。", "art": "res://assets/img/card_art/fg_thorn_wall.png", "target": "self", "version": "new", "hero_target": "target_hero", "rarity": "uncommon", "fg_thorns": 2, "actions": [{"type": "call", "fn": "thorn_wall"}]}
	db["fg_sacrifice_fuel"] = {"id": "fg_sacrifice_fuel", "name": "献燃", "cost": 0, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 0, "description": "消耗巨剑8点生命\n或英雄8点格挡，\n获得1点能量。\n不足8则无法打出。", "art": "res://assets/img/card_art/fg_sacrifice_fuel.png", "target": "hero_or_sword", "version": "new", "hero_target": "target_hero", "rarity": "common", "fg_sacrifice_cost": 8, "fg_energy_gain": 1, "actions": [{"type": "call", "fn": "sacrifice_fuel"}]}
	db["fg_quick_temper"] = {"id": "fg_quick_temper", "status": "pending", "name": "急火", "cost": 0, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 0, "description": "铸造+3。\n消耗。", "art": "res://assets/img/card_art/fg_quick_temper.png", "target": "self", "version": "new", "hero_target": "self", "rarity": "common", "exhaust": true, "fg_forge": 3, "actions": [{"type": "call", "fn": "quick_temper"}]}
	db["fg_chain_forge"] = {"id": "fg_chain_forge", "status": "pending", "name": "连锻", "cost": 1, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 0, "description": "铸造+4。\n若本回合已铸造，\n改为+8。\n抽1张牌。", "art": "res://assets/img/card_art/fg_chain_forge.png", "target": "self", "version": "new", "hero_target": "self", "rarity": "common", "fg_forge_base": 4, "fg_forge_chain": 8, "actions": [{"type": "call", "fn": "chain_forge"}]}
	db["fg_repurpose"] = {"id": "fg_repurpose", "status": "pending", "name": "改造", "cost": 1, "type": CardType.SKILL, "character": "forger", "damage": 0, "block": 0, "description": "消耗1张手牌。\n获得其费用×4格挡。\n铸造+其费用×3。", "art": "res://assets/img/card_art/fg_repurpose.png", "target": "self", "version": "new", "hero_target": "self", "rarity": "uncommon", "fg_block_mult": 4, "fg_forge_mult": 3, "actions": [{"type": "call", "fn": "repurpose"}]}

	# =========================================================================
	# POWERS (12 cards)
	# =========================================================================
	db["fg_sword_mastery"] = {"id": "fg_sword_mastery", "name": "剑术精通", "cost": 2, "type": CardType.POWER, "character": "forger", "damage": 0, "block": 0, "description": "每打出攻击牌，\n铸造+2。", "art": "res://assets/img/card_art/fg_sword_mastery.png", "target": "self", "version": "new", "hero_target": "self", "rarity": "uncommon", "power_effect": "fg_sword_mastery", "power_stacks": 2, "actions": [{"type": "power_effect", "power": "fg_sword_mastery"}]}
	db["fg_barricade"] = {"id": "fg_barricade", "name": "壁垒", "cost": 3, "type": CardType.POWER, "character": "forger", "damage": 0, "block": 0, "description": "格挡不再在\n回合开始时移除。", "art": "res://assets/img/card_art/fg_barricade.png", "target": "self", "version": "new", "hero_target": "target_hero", "rarity": "rare", "power_effect": "barricade", "power_stacks": 0, "actions": [{"type": "power_effect", "power": "barricade"}]}
	db["fg_energy_reserve"] = {"id": "fg_energy_reserve", "status": "pending", "name": "能量储备", "cost": 1, "type": CardType.POWER, "character": "forger", "damage": 0, "block": 0, "description": "回合结束时，\n未使用的能量\n保留至下回合。", "art": "res://assets/img/card_art/fg_energy_reserve.png", "target": "self", "version": "new", "hero_target": "self", "rarity": "uncommon", "power_effect": "fg_energy_reserve", "power_stacks": 0, "actions": [{"type": "power_effect", "power": "fg_energy_reserve"}]}
	db["fg_living_sword"] = {"id": "fg_living_sword", "name": "活剑", "cost": 3, "type": CardType.POWER, "character": "forger", "damage": 0, "block": 0, "description": "回合结束时，\n巨剑对随机敌人\n造成自身HP 50%\n的伤害。", "art": "res://assets/img/card_art/fg_living_sword.png", "target": "self", "version": "new", "hero_target": "self", "rarity": "rare", "power_effect": "fg_living_sword", "power_stacks": 50, "actions": [{"type": "power_effect", "power": "fg_living_sword"}]}
	db["fg_thorn_aura"] = {"id": "fg_thorn_aura", "name": "荆棘光环", "cost": 1, "type": CardType.POWER, "character": "forger", "damage": 0, "block": 0, "description": "获得3层荆棘。\n巨剑获得3层荆棘。", "art": "res://assets/img/card_art/fg_thorn_aura.png", "target": "self", "version": "new", "hero_target": "target_hero", "rarity": "uncommon", "fg_hero_thorns": 3, "fg_sword_thorns": 3, "power_effect": "fg_thorn_aura", "power_stacks": 3, "actions": [{"type": "call", "fn": "thorn_aura"}]}
	db["fg_iron_will"] = {"id": "fg_iron_will", "name": "钢铁意志", "cost": 1, "type": CardType.POWER, "character": "forger", "damage": 0, "block": 0, "description": "每回合开始时，\n获得4点格挡。", "art": "res://assets/img/card_art/fg_iron_will.png", "target": "self", "version": "new", "hero_target": "target_hero", "rarity": "uncommon", "power_effect": "fg_iron_will", "power_stacks": 4, "actions": [{"type": "power_effect", "power": "fg_iron_will"}]}
	db["fg_forge_master"] = {"id": "fg_forge_master", "name": "锻造大师", "cost": 2, "type": CardType.POWER, "character": "forger", "damage": 0, "block": 0, "description": "每次铸造时，\n额外+2 HP。", "art": "res://assets/img/card_art/fg_forge_master.png", "target": "self", "version": "new", "hero_target": "self", "rarity": "uncommon", "power_effect": "fg_forge_master", "power_stacks": 2, "actions": [{"type": "power_effect", "power": "fg_forge_master"}]}
	db["fg_auto_forge"] = {"id": "fg_auto_forge", "name": "自动锻造", "cost": 1, "type": CardType.POWER, "character": "forger", "damage": 0, "block": 0, "description": "每回合开始时，\n铸造+4。", "art": "res://assets/img/card_art/fg_auto_forge.png", "target": "self", "version": "new", "hero_target": "self", "rarity": "uncommon", "power_effect": "fg_auto_forge", "power_stacks": 4, "actions": [{"type": "power_effect", "power": "fg_auto_forge"}]}
	db["fg_iron_skin"] = {"id": "fg_iron_skin", "name": "铁甲之肤", "cost": 2, "type": CardType.POWER, "character": "forger", "damage": 0, "block": 0, "description": "每当巨剑受到伤害，\n目标英雄获得\n等量格挡。", "art": "res://assets/img/card_art/fg_iron_skin.png", "target": "self", "version": "new", "hero_target": "target_hero", "rarity": "rare", "power_effect": "fg_iron_skin", "power_stacks": 1, "actions": [{"type": "power_effect", "power": "fg_iron_skin"}]}
	db["fg_resonance"] = {"id": "fg_resonance", "name": "共鸣", "cost": 1, "type": CardType.POWER, "character": "forger", "damage": 0, "block": 0, "description": "每当目标英雄\n获得格挡，\n铸造：巨剑+2。", "art": "res://assets/img/card_art/fg_resonance.png", "target": "self", "version": "new", "hero_target": "self", "rarity": "uncommon", "power_effect": "fg_resonance", "power_stacks": 2, "actions": [{"type": "power_effect", "power": "fg_resonance"}]}
	db["fg_sword_ward"] = {"id": "fg_sword_ward", "status": "pending", "name": "剑之守护", "cost": 1, "type": CardType.POWER, "character": "forger", "damage": 0, "block": 0, "description": "若巨剑存在，\n每回合开始时\n获得3点格挡。", "art": "res://assets/img/card_art/fg_sword_ward.png", "target": "self", "version": "new", "hero_target": "target_hero", "rarity": "common", "power_effect": "fg_sword_ward", "power_stacks": 3, "actions": [{"type": "power_effect", "power": "fg_sword_ward"}]}
	db["fg_counter_forge"] = {"id": "fg_counter_forge", "status": "pending", "name": "反击锻造", "cost": 2, "type": CardType.POWER, "character": "forger", "damage": 0, "block": 0, "description": "当巨剑被攻击时，\n铸造+3。", "art": "res://assets/img/card_art/fg_counter_forge.png", "target": "self", "version": "new", "hero_target": "self", "rarity": "uncommon", "power_effect": "fg_counter_forge", "power_stacks": 3, "actions": [{"type": "power_effect", "power": "fg_counter_forge"}]}

	return db

static func get_upgrade_overrides() -> Dictionary:
	return {
		# BASIC
		"fg_strike": {"damage": 9, "description": "造成9点伤害。"},
		"fg_defend": {"block": 8, "description": "目标英雄获得\n8点格挡。"},
		# ATTACKS
		"fg_sword_crash": {"fg_sword_mult": 1.5, "description": "造成巨剑当前\n生命值1.5倍\n的伤害。"},
		"fg_riposte_strike": {"damage": 9, "fg_thorns_mult": 3, "description": "造成9点伤害。\n额外造成所有英雄\n+巨剑荆棘×3\n的伤害。"},
		"fg_shield_bash": {"cost": 0, "description": "造成等同于铸造者\n当前格挡值的伤害。"},
		"fg_forge_slam": {"damage": 9, "description": "巨剑对所有敌人\n造成9点伤害。\n巨剑获得未被\n格挡的生命值。"},
		"fg_greatsword_cleave": {"fg_sword_mult": 1.5, "description": "对所有敌人造成\n巨剑生命值1.5倍\n伤害。"},
		"fg_tempered_strike": {"damage": 9, "block": 9, "description": "造成9点伤害。\n获得9点格挡。"},
		"fg_magnetic_edge": {"fg_forge": 6, "fg_threshold_damage": 16, "description": "造成5点伤害。\n铸造+6。\n若巨剑HP≥20，\n改为16点伤害。"},
		"fg_molten_core": {"damage": 10, "fg_forge": 8, "description": "造成10点伤害2次。\n铸造+8。"},
		"fg_hardened_blade": {"damage": 11, "fg_sword_block": 6, "description": "造成11点伤害。\n若巨剑存在，\n获得6点格挡。"},
		"fg_reforged_edge": {"damage": 10, "fg_forged_bonus": 10, "description": "造成10点伤害。\n若本回合已铸造，\n额外造成10点。"},
		"fg_eruption_strike": {"damage": 20, "fg_forge": 6, "description": "造成20点伤害。\n下回合+1能量。\n铸造+6。"},
		"fg_blade_storm": {"fg_hits": 4, "description": "对所有敌人造成\n巨剑HP 50%的\n伤害×4。消耗。"},
		"fg_thorn_burst": {"damage": 9, "fg_thorns_mult": 3, "description": "对所有敌人造成\n9点伤害，额外造成\n所有英雄和巨剑\n荆棘总和×3伤害。\n移除所有荆棘。"},
		"fg_bulwark_slam": {"cost": 0, "description": "对所有敌人造成\n等同于铸造者\n格挡值的伤害。\n消耗所有格挡。"},
		# SKILLS
		"fg_delay_charge": {"fg_forge": 14, "fg_next_energy": 2, "description": "铸造14。\n下回合+2能量。"},
		"fg_sharpen": {"fg_forge": 12, "description": "铸造+12。\n抽1张牌。"},
		"fg_forge_armor": {"block": 14, "fg_forge": 8, "description": "获得14点格挡。\n铸造+8。"},
		"fg_impervious_wall": {"fg_forge": 30, "description": "巨剑获得30点\n生命。消耗。"},
		"fg_block_transfer": {"cost": 0, "description": "将所有英雄格挡\n转化为巨剑HP。"},
		"fg_summon_sword": {"fg_summon_hp": 10, "description": "巨剑+10生命。"},
		"fg_reinforce": {"fg_reinforce_pct": 150, "description": "巨剑获得等同于\n其当前生命150%\n的额外生命。\n消耗。"},
		"fg_temper": {"block": 9, "fg_next_block": 9, "description": "获得9点格挡。\n下回合获得9点\n格挡。"},
		"fg_forge_shield": {"block": 15, "fg_next_draw": 3, "description": "目标英雄获得\n15点格挡。\n下回合+3抽牌。"},
		"fg_melt_down": {"fg_cost_mult": 8, "fg_next_draw": 3, "description": "消耗1张手牌。\n巨剑获得其费用×8\n的生命。\n下回合+3抽牌。"},
		"fg_overcharge": {"cost": 0, "description": "本回合巨剑\n造成双倍伤害。"},
		"fg_absorb_impact": {"cost": 0, "description": "目标英雄获得\n巨剑生命值的格挡。\n巨剑失去所有生命，\n本回合不能\n再召唤巨剑。"},
		"fg_heat_treat": {"fg_forge": 9, "fg_thorns": 2, "description": "铸造+9。\n获得2层荆棘。"},
		"fg_forge_barrier": {"fg_barrier_mult": 1.5, "description": "获得巨剑HP×1.5\n的格挡。"},
		"fg_sword_sacrifice": {"damage": 14, "block": 14, "fg_sacrifice_dmg": 14, "fg_sacrifice_block": 14, "description": "对所有敌人造成\n14点伤害。\n获得14点格挡。\n消耗巨剑。\n本回合不能召唤巨剑。"},
		"fg_thorn_forge": {"fg_hero_thorns": 0, "fg_sword_thorns": 6, "fg_forge": 3, "description": "铸造3。巨剑获得\n6层荆棘(本回合)。"},
		"fg_salvage": {"block": 9, "description": "获得9点格挡。\n从弃牌堆选择\n1张牌置于\n抽牌堆顶。"},
		"fg_thorn_wall": {"fg_sword_thorns": 3, "description": "巨剑获得3层荆棘。"},
		"fg_sacrifice_fuel": {"fg_sacrifice_cost": 8, "fg_energy_gain": 2, "description": "消耗巨剑8点生命\n或英雄8点格挡，\n获得2点能量。\n不足8则无法打出。"},
		"fg_quick_temper": {"fg_forge": 5, "draw": 1, "description": "铸造+5。\n抽1张牌。\n消耗。"},
		"fg_chain_forge": {"fg_forge_base": 5, "fg_forge_chain": 12, "description": "铸造+5。\n若本回合已铸造，\n改为+12。\n抽1张牌。"},
		"fg_repurpose": {"fg_block_mult": 5, "fg_forge_mult": 4, "description": "消耗1张手牌。\n获得其费用×5格挡。\n铸造+其费用×4。"},
		# POWERS
		"fg_sword_mastery": {"power_stacks": 3, "description": "每打出攻击牌，\n铸造+3。"},
		"fg_barricade": {"cost": 2, "description": "格挡不再在\n回合开始时移除。"},
		"fg_energy_reserve": {"fg_energy_bonus": 1, "description": "回合结束时，\n未使用的能量\n保留至下回合。\n额外+1能量。"},
		"fg_living_sword": {"power_stacks": 100, "description": "回合结束时，\n巨剑对随机敌人\n造成自身HP 100%\n的伤害。"},
		"fg_thorn_aura": {"fg_hero_thorns": 5, "fg_sword_thorns": 5, "power_stacks": 5, "description": "获得5层荆棘。\n巨剑获得5层荆棘。"},
		"fg_iron_will": {"power_stacks": 6, "description": "每回合开始时，\n获得6点格挡。"},
		"fg_forge_master": {"power_stacks": 3, "description": "每次铸造时，\n额外+3 HP。"},
		"fg_auto_forge": {"power_stacks": 6, "description": "每回合开始时，\n铸造+6。"},
		"fg_iron_skin": {"innate": true, "description": "固有。每当巨剑\n受到伤害，\n目标英雄获得\n等量格挡。"},
		"fg_resonance": {"power_stacks": 3, "description": "每当目标英雄\n获得格挡，\n铸造：巨剑+3。"},
		"fg_sword_ward": {"power_stacks": 5, "description": "若巨剑存在，\n每回合开始时\n获得5点格挡。"},
		"fg_counter_forge": {"power_stacks": 5, "description": "当巨剑被攻击时，\n铸造+5。"},
	}
