class_name BloodfiendCards
## res://scripts/cards/bloodfiend_cards.gd — Blood Fiend card pack (pluggable)
## 嗜血狂魔: Self-damage, Bloodlust stacks, Vulnerable synergy, Exhaust synergy

enum CardType { ATTACK, SKILL, POWER, STATUS }

static func get_cards() -> Dictionary:
	var db: Dictionary = {}

	# =========================================================================
	# ATTACKS (16 cards)
	# =========================================================================
	db["bf_strike"] = {"id": "bf_strike", "name": "血击", "cost": 1, "type": CardType.ATTACK, "character": "bloodfiend", "damage": 6, "block": 0, "description": "造成6点伤害。", "art": "res://assets/img/card_art/bf_strike.png", "target": "enemy", "version": "new", "actions": [{"type": "damage"}]}
	db["bf_crimson_slash"] = {"id": "bf_crimson_slash", "name": "绯红斩", "cost": 1, "type": CardType.ATTACK, "character": "bloodfiend", "damage": 12, "block": 0, "description": "失去2点HP。\n造成12点伤害。", "art": "res://assets/img/card_art/bf_crimson_slash.png", "target": "enemy", "version": "new", "actions": [{"type": "self_damage", "value": 2}, {"type": "damage"}]}
	db["bf_frenzy_claw"] = {"id": "bf_frenzy_claw", "name": "狂乱之爪", "cost": 1, "type": CardType.ATTACK, "character": "bloodfiend", "damage": 4, "block": 0, "description": "造成4点伤害2次。\n每次命中施加\n1层嗜血。", "art": "res://assets/img/card_art/bf_frenzy_claw.png", "target": "enemy", "version": "new", "times": 2, "bf_bloodlust_per_hit": 1, "actions": [{"type": "call", "fn": "frenzy_claw"}]}
	db["bf_gore"] = {"id": "bf_gore", "name": "穿刺", "cost": 2, "type": CardType.ATTACK, "character": "bloodfiend", "damage": 10, "block": 0, "description": "造成10点伤害。\n施加2层易伤。", "art": "res://assets/img/card_art/bf_gore.png", "target": "enemy", "version": "new", "apply_status": {"type": "vulnerable", "stacks": 2}, "actions": [{"type": "damage"}, {"type": "apply_status", "source": "apply_status"}]}
	db["bf_execution"] = {"id": "bf_execution", "name": "处决", "cost": 2, "type": CardType.ATTACK, "character": "bloodfiend", "damage": 8, "block": 0, "description": "造成8点伤害。\n使目标的嗜血\n层数翻倍。", "art": "res://assets/img/card_art/bf_execution.png", "target": "enemy", "version": "new", "actions": [{"type": "call", "fn": "execution"}]}
	db["bf_blood_whirl"] = {"id": "bf_blood_whirl", "name": "血旋", "cost": 1, "type": CardType.ATTACK, "character": "bloodfiend", "damage": 6, "block": 0, "description": "失去2点HP。\n对所有敌人\n造成6点伤害。\n施加1层嗜血。", "art": "res://assets/img/card_art/bf_blood_whirl.png", "target": "all_enemies", "version": "new", "actions": [{"type": "call", "fn": "blood_whirl"}]}
	db["bf_savage_strike"] = {"id": "bf_savage_strike", "name": "蛮击", "cost": 1, "type": CardType.ATTACK, "character": "bloodfiend", "damage": 6, "block": 0, "description": "造成6点伤害。\n本场战斗每失去\n1点HP，+1伤害。", "art": "res://assets/img/card_art/bf_savage_strike.png", "target": "enemy", "version": "new", "actions": [{"type": "call", "fn": "savage_strike"}]}
	db["bf_prey_on_weakness"] = {"id": "bf_prey_on_weakness", "name": "趁虚而入", "cost": 1, "type": CardType.ATTACK, "character": "bloodfiend", "damage": 6, "block": 0, "description": "造成6点伤害。\n若目标有易伤，\n额外攻击1次。", "art": "res://assets/img/card_art/bf_prey_on_weakness.png", "target": "enemy", "version": "new", "actions": [{"type": "call", "fn": "prey_on_weakness"}]}
	db["bf_exploit"] = {"id": "bf_exploit", "name": "痛击", "cost": 0, "type": CardType.ATTACK, "character": "bloodfiend", "damage": 3, "block": 0, "description": "造成3点伤害。\n若目标有易伤，\n抽1张牌。", "art": "res://assets/img/card_art/bf_exploit.png", "target": "enemy", "version": "new", "actions": [{"type": "call", "fn": "exploit"}]}
	db["bf_crushing_blow"] = {"id": "bf_crushing_blow", "name": "碾压", "cost": 2, "type": CardType.ATTACK, "character": "bloodfiend", "damage": 10, "block": 0, "description": "造成10点伤害。\n消耗目标所有易伤；\n每层+4伤害。", "art": "res://assets/img/card_art/bf_crushing_blow.png", "target": "enemy", "version": "new", "vuln_bonus": 4, "actions": [{"type": "call", "fn": "crushing_blow"}]}
	db["bf_flesh_rend"] = {"id": "bf_flesh_rend", "name": "撕裂血肉", "cost": 1, "type": CardType.ATTACK, "character": "bloodfiend", "damage": 0, "block": 0, "description": "消耗1张手牌。\n造成其费用×8\n点伤害。", "art": "res://assets/img/card_art/bf_flesh_rend.png", "target": "enemy", "version": "new", "cost_mult": 8, "actions": [{"type": "call", "fn": "flesh_rend"}]}
	db["bf_soul_harvest"] = {"id": "bf_soul_harvest", "name": "灵魂收割", "cost": 2, "type": CardType.ATTACK, "character": "bloodfiend", "damage": 7, "block": 0, "description": "消耗手中所有\n其他手牌。\n每消耗1张，\n造成7点伤害。", "art": "res://assets/img/card_art/bf_soul_harvest.png", "target": "enemy", "version": "new", "actions": [{"type": "call", "fn": "soul_harvest"}]}
	db["bf_relentless"] = {"id": "bf_relentless", "name": "不屈", "cost": 1, "type": CardType.ATTACK, "character": "bloodfiend", "damage": 6, "block": 0, "description": "造成6点伤害。\n本回合每消耗1张牌\n额外攻击1次。", "art": "res://assets/img/card_art/bf_relentless.png", "target": "enemy", "version": "new", "actions": [{"type": "call", "fn": "relentless"}]}
	db["bf_vampiric_embrace"] = {"id": "bf_vampiric_embrace", "name": "血族拥抱", "cost": 1, "type": CardType.ATTACK, "character": "bloodfiend", "damage": 4, "block": 0, "description": "对所有敌人\n造成4点伤害。\n治疗等量HP。\n消耗。", "art": "res://assets/img/card_art/bf_vampiric_embrace.png", "target": "all_enemies", "version": "new", "exhaust": true, "actions": [{"type": "call", "fn": "vampiric_embrace"}]}
	db["bf_leech"] = {"id": "bf_leech", "name": "吸血", "cost": 1, "type": CardType.ATTACK, "character": "bloodfiend", "damage": 6, "block": 0, "description": "造成6点伤害。\n若造成伤害，\n治疗2点HP。", "art": "res://assets/img/card_art/bf_leech.png", "target": "enemy", "version": "new", "heal_on_hit": 2, "actions": [{"type": "call", "fn": "leech"}]}
	db["bf_blood_feast"] = {"id": "bf_blood_feast", "name": "血宴", "cost": 1, "type": CardType.ATTACK, "character": "bloodfiend", "damage": 7, "block": 0, "description": "造成7点伤害。\n若击杀目标，\n获得3点最大HP。", "art": "res://assets/img/card_art/bf_blood_feast.png", "target": "enemy", "version": "new", "max_hp_gain": 3, "actions": [{"type": "call", "fn": "blood_feast"}]}

	# =========================================================================
	# SKILLS (14 cards + 1 basic defend)
	# =========================================================================
	db["bf_defend"] = {"id": "bf_defend", "name": "防御", "cost": 1, "type": CardType.SKILL, "character": "bloodfiend", "damage": 0, "block": 5, "description": "获得5点格挡。", "art": "res://assets/img/card_art/bf_defend.png", "target": "self", "version": "new", "hero_target": "target_hero", "actions": [{"type": "block"}]}
	db["bf_sanguine_shield"] = {"id": "bf_sanguine_shield", "name": "血盾", "cost": 1, "type": CardType.SKILL, "character": "bloodfiend", "damage": 0, "block": 11, "description": "失去2点HP。\n获得11点格挡。", "art": "res://assets/img/card_art/bf_sanguine_shield.png", "target": "self", "version": "new", "hero_target": "target_hero", "actions": [{"type": "self_damage", "value": 2}, {"type": "block"}]}
	db["bf_blood_offering"] = {"id": "bf_blood_offering", "name": "血祭", "cost": 0, "type": CardType.SKILL, "character": "bloodfiend", "damage": 0, "block": 0, "description": "失去5点HP。\n获得2点能量。\n抽2张牌。\n消耗。", "art": "res://assets/img/card_art/bf_blood_offering.png", "target": "self", "version": "new", "exhaust": true, "actions": [{"type": "self_damage", "value": 5}, {"type": "gain_energy", "value": 2}, {"type": "draw", "value": 2}]}
	db["bf_predator_instinct"] = {"id": "bf_predator_instinct", "name": "掠食本能", "cost": 1, "type": CardType.SKILL, "character": "bloodfiend", "damage": 0, "block": 0, "description": "本回合每打出\n1张攻击牌，\n获得3点格挡。\n抽1张牌。", "art": "res://assets/img/card_art/bf_predator_instinct.png", "target": "self", "version": "new", "draw": 1, "power_effect": "predator_instinct", "power_stacks": 3, "actions": [{"type": "draw"}, {"type": "power_effect", "power": "predator_instinct"}]}
	db["bf_bloodbath"] = {"id": "bf_bloodbath", "name": "血浴", "cost": 1, "type": CardType.SKILL, "character": "bloodfiend", "damage": 0, "block": 0, "description": "消耗1张手牌。\n施加2层嗜血\n和1层易伤。", "art": "res://assets/img/card_art/bf_bloodbath.png", "target": "enemy", "version": "new", "bf_bloodlust_apply": 2, "apply_status": {"type": "vulnerable", "stacks": 1}, "actions": [{"type": "call", "fn": "bloodbath"}]}
	db["bf_blood_pact"] = {"id": "bf_blood_pact", "name": "血契", "cost": 1, "type": CardType.SKILL, "character": "bloodfiend", "damage": 0, "block": 0, "description": "消耗1张手牌。\n抽2张牌。", "art": "res://assets/img/card_art/bf_blood_pact.png", "target": "self", "version": "new", "draw": 2, "actions": [{"type": "call", "fn": "blood_pact"}]}
	db["bf_sacrifice"] = {"id": "bf_sacrifice", "name": "献祭", "cost": 0, "type": CardType.SKILL, "character": "bloodfiend", "damage": 0, "block": 0, "description": "失去3点HP。\n获得2点能量。", "art": "res://assets/img/card_art/bf_sacrifice.png", "target": "self", "version": "new", "actions": [{"type": "self_damage", "value": 3}, {"type": "gain_energy", "value": 2}]}
	db["bf_bloodrage"] = {"id": "bf_bloodrage", "name": "嗜血狂怒", "cost": 1, "type": CardType.SKILL, "character": "bloodfiend", "damage": 0, "block": 0, "description": "失去2点HP。\n对所有敌人施加\n1层易伤。\n获得2点临时力量。", "art": "res://assets/img/card_art/bf_bloodrage.png", "target": "all_enemies", "version": "new", "flex_stacks": 2, "actions": [{"type": "call", "fn": "bloodrage"}]}
	db["bf_vital_guard"] = {"id": "bf_vital_guard", "name": "命脉守护", "cost": 1, "type": CardType.SKILL, "character": "bloodfiend", "damage": 0, "block": 6, "description": "获得6点格挡。\nHP低于28%时，\n额外获得6点。", "art": "res://assets/img/card_art/bf_vital_guard.png", "target": "self", "version": "new", "hero_target": "target_hero", "bonus_block": 6, "hp_threshold": 0.28, "actions": [{"type": "call", "fn": "vital_guard"}]}
	db["bf_blood_shell"] = {"id": "bf_blood_shell", "name": "血壳", "cost": 2, "type": CardType.SKILL, "character": "bloodfiend", "damage": 0, "block": 10, "description": "获得10点格挡。\n本回合受击时，\n对攻击者施加\n1层嗜血。", "art": "res://assets/img/card_art/bf_blood_shell.png", "target": "self", "version": "new", "hero_target": "target_hero", "power_effect": "blood_shell", "power_stacks": 1, "actions": [{"type": "block"}, {"type": "power_effect", "power": "blood_shell"}]}
	db["bf_blood_rush"] = {"id": "bf_blood_rush", "name": "血涌", "cost": 1, "type": CardType.SKILL, "character": "bloodfiend", "damage": 0, "block": 0, "description": "选择手中1张攻击牌\n本场战斗降低1费。\n消耗。", "art": "res://assets/img/card_art/bf_blood_rush.png", "target": "self", "version": "new", "exhaust": true, "actions": [{"type": "call", "fn": "blood_rush"}]}
	db["bf_bloodhound"] = {"id": "bf_bloodhound", "name": "猎血犬", "cost": 1, "type": CardType.SKILL, "character": "bloodfiend", "damage": 0, "block": 0, "description": "抽3张牌。\n弃置抽到的\n非攻击牌。", "art": "res://assets/img/card_art/bf_bloodhound.png", "target": "self", "version": "new", "bf_draw_count": 3, "actions": [{"type": "call", "fn": "bloodhound"}]}
	db["bf_berserker_resolve"] = {"id": "bf_berserker_resolve", "name": "狂战决心", "cost": 1, "type": CardType.SKILL, "character": "bloodfiend", "damage": 0, "block": 6, "description": "获得6点格挡。\n施加1层易伤。", "art": "res://assets/img/card_art/bf_berserker_resolve.png", "target": "enemy", "version": "new", "apply_status": {"type": "vulnerable", "stacks": 1}, "actions": [{"type": "block"}, {"type": "apply_status", "source": "apply_status"}]}
	db["bf_survival_instinct"] = {"id": "bf_survival_instinct", "name": "求生本能", "cost": 0, "type": CardType.SKILL, "character": "bloodfiend", "damage": 0, "block": 3, "description": "获得3点格挡。\nHP低于25%时，\n改为获得7点。", "art": "res://assets/img/card_art/bf_survival_instinct.png", "target": "self", "version": "new", "hero_target": "target_hero", "actions": [{"type": "call", "fn": "survival_instinct"}]}

	# =========================================================================
	# POWERS (11 cards)
	# =========================================================================
	db["bf_blood_frenzy"] = {"id": "bf_blood_frenzy", "name": "血之狂热", "cost": 3, "type": CardType.POWER, "character": "bloodfiend", "damage": 0, "block": 0, "description": "每回合开始时，\n获得2点力量，\n失去2点HP。", "art": "res://assets/img/card_art/bf_blood_frenzy.png", "target": "self", "version": "new", "hero_target": "target_hero", "power_effect": "blood_frenzy", "per_turn": {"strength": 2, "self_damage": 2}, "power_stacks": 2, "actions": [{"type": "power_effect", "power": "blood_frenzy"}]}
	db["bf_bloodlust"] = {"id": "bf_bloodlust", "name": "嗜血", "cost": 1, "type": CardType.POWER, "character": "bloodfiend", "damage": 0, "block": 0, "description": "每当你失去HP，\n获得1点力量。", "art": "res://assets/img/card_art/bf_bloodlust.png", "target": "self", "version": "new", "hero_target": "target_hero", "power_effect": "bf_bloodlust_power", "power_stacks": 1, "actions": [{"type": "power_effect", "power": "bf_bloodlust_power"}]}
	db["bf_sanguine_aura"] = {"id": "bf_sanguine_aura", "name": "血气光环", "cost": 2, "type": CardType.POWER, "character": "bloodfiend", "damage": 0, "block": 0, "description": "每当你造成攻击\n伤害，对目标\n施加1层嗜血。", "art": "res://assets/img/card_art/bf_sanguine_aura.png", "target": "self", "version": "new", "power_effect": "sanguine_aura", "power_stacks": 1, "actions": [{"type": "power_effect", "power": "sanguine_aura"}]}
	db["bf_crimson_pact"] = {"id": "bf_crimson_pact", "name": "绯红契约", "cost": 1, "type": CardType.POWER, "character": "bloodfiend", "damage": 0, "block": 0, "description": "每当一张牌被\n消耗，对随机\n敌人造成5点伤害。", "art": "res://assets/img/card_art/bf_crimson_pact.png", "target": "self", "version": "new", "power_effect": "crimson_pact", "power_stacks": 5, "actions": [{"type": "power_effect", "power": "crimson_pact"}]}
	db["bf_predators_mark"] = {"id": "bf_predators_mark", "name": "掠食者印记", "cost": 2, "type": CardType.POWER, "character": "bloodfiend", "damage": 0, "block": 0, "description": "每当你施加\n易伤，获得\n1点力量。", "art": "res://assets/img/card_art/bf_predators_mark.png", "target": "self", "version": "new", "hero_target": "target_hero", "power_effect": "predators_mark", "power_stacks": 1, "actions": [{"type": "power_effect", "power": "predators_mark"}]}
	db["bf_blood_scent"] = {"id": "bf_blood_scent", "name": "血之气息", "cost": 1, "type": CardType.POWER, "character": "bloodfiend", "damage": 0, "block": 0, "description": "每当你施加\n易伤，抽\n1张牌。", "art": "res://assets/img/card_art/bf_blood_scent.png", "target": "self", "version": "new", "power_effect": "blood_scent", "power_stacks": 1, "actions": [{"type": "power_effect", "power": "blood_scent"}]}
	db["bf_undying_rage"] = {"id": "bf_undying_rage", "name": "不灭之怒", "cost": 2, "type": CardType.POWER, "character": "bloodfiend", "damage": 0, "block": 0, "description": "每当一张牌被\n消耗，获得\n1点力量。", "art": "res://assets/img/card_art/bf_undying_rage.png", "target": "self", "version": "new", "hero_target": "target_hero", "power_effect": "undying_rage", "power_stacks": 1, "actions": [{"type": "power_effect", "power": "undying_rage"}]}
	db["bf_pain_threshold"] = {"id": "bf_pain_threshold", "name": "痛觉阈值", "cost": 1, "type": CardType.POWER, "character": "bloodfiend", "damage": 0, "block": 0, "description": "每当你失去HP，\n抽1张牌并\n获得2点格挡。", "art": "res://assets/img/card_art/bf_pain_threshold.png", "target": "self", "version": "new", "hero_target": "target_hero", "power_effect": "pain_threshold", "power_stacks": 2, "actions": [{"type": "power_effect", "power": "pain_threshold"}]}
	db["bf_blood_bond"] = {"id": "bf_blood_bond", "name": "血之纽带", "cost": 2, "type": CardType.POWER, "character": "bloodfiend", "damage": 0, "block": 0, "description": "每回合开始时，\n若HP低于25%，\n获得1点能量\n和1点力量。", "art": "res://assets/img/card_art/bf_blood_bond.png", "target": "self", "version": "new", "hero_target": "target_hero", "power_effect": "blood_bond", "per_turn": {"conditional": true}, "power_stacks": 1, "actions": [{"type": "power_effect", "power": "blood_bond"}]}
	db["bf_hemostasis"] = {"id": "bf_hemostasis", "name": "止血", "cost": 2, "type": CardType.POWER, "character": "bloodfiend", "damage": 0, "block": 0, "description": "每当你失去HP，\n获得等量格挡。", "art": "res://assets/img/card_art/bf_hemostasis.png", "target": "self", "version": "new", "hero_target": "target_hero", "power_effect": "hemostasis", "power_stacks": 1, "actions": [{"type": "power_effect", "power": "hemostasis"}]}
	db["bf_undying_will"] = {"id": "bf_undying_will", "name": "不死意志", "cost": 2, "type": CardType.POWER, "character": "bloodfiend", "damage": 0, "block": 0, "description": "HP降为0时，\n以1点HP存活。\n（触发2次）", "art": "res://assets/img/card_art/bf_undying_will.png", "target": "self", "version": "new", "hero_target": "target_hero", "power_effect": "undying_will", "power_stacks": 2, "actions": [{"type": "power_effect", "power": "undying_will"}]}

	return db

static func get_upgrade_overrides() -> Dictionary:
	return {
		# ATTACKS
		"bf_strike": {"damage": 9, "description": "造成9点伤害。"},
		"bf_crimson_slash": {"damage": 16, "description": "失去2点HP。\n造成16点伤害。"},
		"bf_frenzy_claw": {"times": 3, "description": "造成4点伤害3次。\n每次命中施加\n1层嗜血。"},
		"bf_gore": {"damage": 14, "apply_status": {"type": "vulnerable", "stacks": 3}, "description": "造成14点伤害。\n施加3层易伤。"},
		"bf_execution": {"damage": 12, "description": "造成12点伤害。\n使目标的嗜血\n层数翻倍。"},
		"bf_blood_whirl": {"damage": 10, "description": "失去2点HP。\n对所有敌人\n造成10点伤害。\n施加1层嗜血。"},
		"bf_savage_strike": {"damage": 9, "description": "造成9点伤害。\n本场战斗每失去\n1点HP，+1伤害。"},
		"bf_prey_on_weakness": {"damage": 9, "description": "造成9点伤害。\n若目标有易伤，\n额外攻击1次。"},
		"bf_exploit": {"damage": 5, "description": "造成5点伤害。\n若目标有易伤，\n抽2张牌。", "bf_exploit_draw": 2},
		"bf_crushing_blow": {"damage": 14, "vuln_bonus": 5, "description": "造成14点伤害。\n消耗目标所有易伤；\n每层+5伤害。"},
		"bf_flesh_rend": {"cost_mult": 12, "description": "消耗1张手牌。\n造成其费用×12\n点伤害。"},
		"bf_soul_harvest": {"damage": 10, "description": "消耗手中所有\n其他手牌。\n每消耗1张，\n造成10点伤害。"},
		"bf_relentless": {"damage": 9, "description": "造成9点伤害。\n本回合每消耗1张牌\n额外攻击1次。"},
		"bf_vampiric_embrace": {"damage": 6, "description": "对所有敌人\n造成6点伤害。\n治疗等量HP。\n消耗。"},
		"bf_leech": {"damage": 9, "description": "造成9点伤害。\n若造成伤害，\n治疗2点HP。"},
		"bf_blood_feast": {"damage": 10, "max_hp_gain": 4, "description": "造成10点伤害。\n若击杀目标，\n获得4点最大HP。"},
		# SKILLS
		"bf_defend": {"block": 8, "description": "获得8点格挡。"},
		"bf_sanguine_shield": {"block": 15, "description": "失去2点HP。\n获得15点格挡。"},
		"bf_blood_offering": {"actions": [{"type": "self_damage", "value": 5}, {"type": "gain_energy", "value": 3}, {"type": "draw", "value": 3}], "description": "失去5点HP。\n获得3点能量。\n抽3张牌。\n消耗。"},
		"bf_predator_instinct": {"cost": 0, "power_stacks": 4, "description": "本回合每打出\n1张攻击牌，\n获得4点格挡。\n抽1张牌。"},
		"bf_bloodbath": {"bf_bloodlust_apply": 3, "apply_status": {"type": "vulnerable", "stacks": 2}, "description": "消耗1张手牌。\n施加3层嗜血\n和2层易伤。"},
		"bf_blood_pact": {"draw": 3, "description": "消耗1张手牌。\n抽3张牌。"},
		"bf_sacrifice": {"actions": [{"type": "self_damage", "value": 3}, {"type": "gain_energy", "value": 3}], "description": "失去3点HP。\n获得3点能量。"},
		"bf_bloodrage": {"flex_stacks": 4, "description": "失去2点HP。\n对所有敌人施加\n1层易伤。\n获得4点临时力量。"},
		"bf_vital_guard": {"block": 9, "bonus_block": 9, "hp_threshold": 0.25, "description": "获得9点格挡。\nHP低于25%时，\n额外获得9点。"},
		"bf_blood_shell": {"block": 14, "power_stacks": 2, "description": "获得14点格挡。\n本回合受击时，\n对攻击者施加\n2层嗜血。"},
		"bf_blood_rush": {"cost": 0, "description": "选择手中1张攻击牌\n本场战斗降低1费。\n消耗。"},
		"bf_bloodhound": {"bf_draw_count": 4, "description": "抽4张牌。\n弃置抽到的\n非攻击牌。"},
		"bf_berserker_resolve": {"block": 9, "apply_status": {"type": "vulnerable", "stacks": 2}, "description": "获得9点格挡。\n施加2层易伤。"},
		"bf_survival_instinct": {"block": 5, "description": "获得5点格挡。\nHP低于25%时，\n改为获得10点。", "bf_low_hp_block": 10},
		# POWERS
		"bf_blood_frenzy": {"description": "每回合开始时，\n获得3点力量，\n失去2点HP。", "power_effect": "blood_frenzy_plus", "per_turn": {"strength": 3, "self_damage": 2}, "power_stacks": 3},
		"bf_bloodlust": {"description": "每当你失去HP，\n获得2点力量。", "power_effect": "bf_bloodlust_power_plus", "power_stacks": 2},
		"bf_sanguine_aura": {"cost": 1, "description": "每当你造成攻击\n伤害，对目标\n施加1层嗜血。"},
		"bf_crimson_pact": {"description": "每当一张牌被\n消耗，对随机\n敌人造成8点伤害。", "power_effect": "crimson_pact_plus", "power_stacks": 8},
		"bf_predators_mark": {"description": "固有。\n每当你施加\n易伤，获得\n1点力量。", "innate": true},
		"bf_blood_scent": {"description": "每当你施加\n易伤，抽\n2张牌。", "power_effect": "blood_scent_plus"},
		"bf_undying_rage": {"cost": 1, "description": "每当一张牌被\n消耗，获得\n1点力量。"},
		"bf_pain_threshold": {"description": "每当你失去HP，\n抽1张牌并\n获得4点格挡。", "power_effect": "pain_threshold_plus", "power_stacks": 4},
		"bf_blood_bond": {"description": "每回合开始时，\n若HP低于25%，\n获得1点能量\n和2点力量。", "power_effect": "blood_bond_plus"},
		"bf_hemostasis": {"cost": 1, "description": "每当你失去HP，\n获得等量格挡。"},
		"bf_undying_will": {"description": "HP降为0时，\n以1点HP存活。\n（触发3次）", "power_stacks": 3},
	}
