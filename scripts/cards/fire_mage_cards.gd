class_name FireMageCards
## res://scripts/cards/fire_mage_cards.gd — Fire Mage card pack (pluggable)
## 火法师: Exhaust synergy, consume cards for power

enum CardType { ATTACK, SKILL, POWER, STATUS }

static func get_cards() -> Dictionary:
	var db: Dictionary = {}

	# =========================================================================
	# BASIC CARDS
	# =========================================================================
	db["fm_strike"] = {"id": "fm_strike", "name": "火击", "cost": 1, "type": CardType.ATTACK, "character": "fire_mage", "damage": 6, "block": 0, "description": "造成6点伤害。", "art": "res://assets/img/card_art/fm_strike.png", "target": "enemy", "version": "new", "actions": [{"type": "damage"}]}
	db["fm_defend"] = {"id": "fm_defend", "name": "防御", "cost": 1, "type": CardType.SKILL, "character": "fire_mage", "damage": 0, "block": 5, "description": "获得5点格挡。", "art": "res://assets/img/card_art/fm_defend.png", "target": "self", "version": "new", "hero_target": "target_hero", "actions": [{"type": "block"}]}

	# =========================================================================
	# ATTACKS (3 cards)
	# =========================================================================
	db["fm_flesh_rend"] = {"id": "fm_flesh_rend", "name": "撕裂血肉", "cost": 1, "type": CardType.ATTACK, "character": "fire_mage", "damage": 0, "block": 0, "description": "消耗1张手牌。\n造成其费用×8\n点伤害。", "art": "res://assets/img/card_art/fm_flesh_rend.png", "target": "enemy", "version": "new", "rarity": "common", "cost_mult": 8, "actions": [{"type": "call", "fn": "flesh_rend"}]}
	db["fm_soul_harvest"] = {"id": "fm_soul_harvest", "name": "灵魂收割", "cost": 2, "type": CardType.ATTACK, "character": "fire_mage", "damage": 7, "block": 0, "description": "消耗手中所有\n其他手牌。\n每消耗1张，\n造成7点伤害。", "art": "res://assets/img/card_art/fm_soul_harvest.png", "target": "enemy", "version": "new", "rarity": "rare", "actions": [{"type": "call", "fn": "soul_harvest"}]}
	db["fm_relentless"] = {"id": "fm_relentless", "name": "不屈", "cost": 1, "type": CardType.ATTACK, "character": "fire_mage", "damage": 6, "block": 0, "description": "造成6点伤害。\n本回合每消耗1张牌\n额外攻击1次。", "art": "res://assets/img/card_art/fm_relentless.png", "target": "enemy", "version": "new", "rarity": "common", "actions": [{"type": "call", "fn": "relentless"}]}

	# =========================================================================
	# SKILLS (2 cards)
	# =========================================================================
	db["fm_bloodbath"] = {"id": "fm_bloodbath", "name": "血浴", "cost": 1, "type": CardType.SKILL, "character": "fire_mage", "damage": 0, "block": 0, "description": "消耗1张手牌。\n施加2层嗜血\n和1层易伤。", "art": "res://assets/img/card_art/fm_bloodbath.png", "target": "enemy", "version": "new", "rarity": "uncommon", "bf_bloodlust_apply": 2, "apply_status": {"type": "vulnerable", "stacks": 1}, "actions": [{"type": "call", "fn": "bloodbath"}]}
	db["fm_blood_pact"] = {"id": "fm_blood_pact", "name": "血契", "cost": 1, "type": CardType.SKILL, "character": "fire_mage", "damage": 0, "block": 0, "description": "消耗1张手牌。\n抽2张牌。", "art": "res://assets/img/card_art/fm_blood_pact.png", "target": "self", "version": "new", "rarity": "uncommon", "hero_target": "self", "draw": 2, "actions": [{"type": "call", "fn": "blood_pact"}]}

	# =========================================================================
	# POWERS (2 cards)
	# =========================================================================
	db["fm_crimson_pact"] = {"id": "fm_crimson_pact", "name": "绯红契约", "cost": 1, "type": CardType.POWER, "character": "fire_mage", "damage": 0, "block": 0, "description": "每当一张牌被\n消耗，对随机\n敌人造成5点伤害。", "art": "res://assets/img/card_art/fm_crimson_pact.png", "target": "self", "version": "new", "rarity": "uncommon", "hero_target": "self", "power_effect": "crimson_pact", "power_stacks": 5, "actions": [{"type": "power_effect", "power": "crimson_pact"}]}
	db["fm_undying_rage"] = {"id": "fm_undying_rage", "name": "不灭之怒", "cost": 2, "type": CardType.POWER, "character": "fire_mage", "damage": 0, "block": 0, "description": "每当一张牌被\n消耗，获得\n1点力量。", "art": "res://assets/img/card_art/fm_undying_rage.png", "target": "self", "version": "new", "rarity": "uncommon", "hero_target": "target_hero", "power_effect": "undying_rage", "power_stacks": 1, "actions": [{"type": "power_effect", "power": "undying_rage"}]}

	return db

static func get_upgrade_overrides() -> Dictionary:
	return {
		# BASIC
		"fm_strike": {"damage": 9, "description": "造成9点伤害。"},
		"fm_defend": {"block": 8, "description": "获得8点格挡。"},
		# ATTACKS
		"fm_flesh_rend": {"cost_mult": 12, "description": "消耗1张手牌。\n造成其费用×12\n点伤害。"},
		"fm_soul_harvest": {"damage": 10, "description": "消耗手中所有\n其他手牌。\n每消耗1张，\n造成10点伤害。"},
		"fm_relentless": {"damage": 9, "description": "造成9点伤害。\n本回合每消耗1张牌\n额外攻击1次。"},
		# SKILLS
		"fm_bloodbath": {"bf_bloodlust_apply": 3, "apply_status": {"type": "vulnerable", "stacks": 2}, "description": "消耗1张手牌。\n施加3层嗜血\n和2层易伤。"},
		"fm_blood_pact": {"draw": 3, "description": "消耗1张手牌。\n抽3张牌。"},
		# POWERS
		"fm_crimson_pact": {"description": "每当一张牌被\n消耗，对随机\n敌人造成8点伤害。", "power_effect": "crimson_pact_plus", "power_stacks": 8},
		"fm_undying_rage": {"cost": 1, "description": "每当一张牌被\n消耗，获得\n1点力量。"},
	}
