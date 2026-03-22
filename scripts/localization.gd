extends Node
## res://scripts/localization.gd — Localization singleton: Chinese/English translations

var current_lang: String = "zh"

# UI string translations
var _ui_strings: Dictionary = {
	"build_your_deck": {"en": "Build Your Deck", "zh": "构建牌组"},
	"selected_x_of_y": {"en": "Selected: %d / %d", "zh": "已选: %d / %d"},
	"confirm_deck": {"en": "Confirm Deck", "zh": "确认牌组"},
	"upgrade": {"en": "Upgrade", "zh": "升级"},
	"upgraded_check": {"en": "Upgraded ✓", "zh": "已升级 ✓"},
	"your_turn": {"en": "Your Turn", "zh": "你的回合"},
	"enemy_turn": {"en": "Enemy Turn", "zh": "敌人回合"},
	"end_turn": {"en": "End Turn", "zh": "结束回合"},
	"draw_pile": {"en": "Draw: %d", "zh": "抽牌堆: %d"},
	"discard_pile": {"en": "Discard: %d", "zh": "弃牌堆: %d"},
	"victory": {"en": "VICTORY!", "zh": "胜利！"},
	"defeat": {"en": "DEFEAT", "zh": "战败"},
	"attack": {"en": "Attack", "zh": "攻击"},
	"skill": {"en": "Skill", "zh": "技能"},
	"power": {"en": "Power", "zh": "能力"},
	"status": {"en": "Status", "zh": "状态"},
	"cost_type": {"en": "Cost: %d | %s", "zh": "费用: %d | %s"},
	"cost_x_type": {"en": "Cost: X | %s", "zh": "费用: X | %s"},
}

# Card name translations: card_id -> zh name
var _card_names_zh: Dictionary = {
	# IRONCLAD ATTACKS
	"ic_strike": "打击",
	"ic_bash": "痛击",
	"ic_iron_wave": "铁波",
	"ic_body_slam": "以攻代守",
	"ic_anger": "愤怒",
	"ic_cleave": "顺劈",
	"ic_twin_strike": "双刃斩",
	"ic_wild_strike": "蛮力打击",
	"ic_pommel_strike": "连击",
	"ic_headbutt": "头锤",
	"ic_pummel": "连续拳",
	"ic_uppercut": "上勾拳",
	"ic_immolate": "冥火",
	"ic_fiend_fire": "恶魔之火",
	"ic_reaper": "死神收割",
	"ic_heavy_blade": "重刃",
	"ic_thunderclap": "雷鸣",
	"ic_hemokinesis": "噬血术",
	"ic_reckless_charge": "鲁莽冲锋",
	"ic_clash": "冲突",
	"ic_perfected_strike": "完美打击",
	"ic_bludgeon": "重锤",
	"ic_sword_boomerang": "剑刃飞旋",
	"ic_searing_blow": "炙火",
	"ic_whirlwind": "旋风斩",
	"ic_dropkick": "飞踢",
	"ic_carnage": "大屠杀",
	"ic_clothesline": "晾衣绳",
	"ic_feed": "馈食",
	"ic_rampage": "暴走",
	"ic_sever_soul": "断魂",
	"ic_blood_for_blood": "以血还血",
	# IRONCLAD SKILLS
	"ic_defend": "防御",
	"ic_shrug_it_off": "坚韧",
	"ic_flame_barrier": "火焰护盾",
	"ic_battle_trance": "战斗恍惚",
	"ic_bloodletting": "放血",
	"ic_flex": "屈伸",
	"ic_limit_break": "极限突破",
	"ic_entrench": "固若金汤",
	"ic_shockwave": "冲击波",
	"ic_armaments": "强化",
	"ic_power_through": "硬撑",
	"ic_offering": "献祭",
	"ic_war_cry": "战吼",
	"ic_burning_pact": "燃烧契约",
	"ic_seeing_red": "怒目而视",
	"ic_second_wind": "再接再厉",
	"ic_intimidate": "恐吓",
	"ic_infernal_blade": "地狱之刃",
	"ic_dual_wield": "双持",
	"ic_ghostly_armor": "幽灵铠甲",
	"ic_havoc": "浩劫",
	"ic_impervious": "刀枪不入",
	"ic_exhume": "掘墓",
	"ic_sentinel": "哨兵",
	"ic_spot_weakness": "弱点侦测",
	"ic_true_grit": "坚毅",
	"ic_disarm": "缴械",
	"ic_double_tap": "双击",
	# IRONCLAD POWERS
	"ic_demon_form": "恶魔化",
	"ic_corruption": "腐化",
	"ic_berserk": "狂暴",
	"ic_feel_no_pain": "无痛",
	"ic_juggernaut": "巨力战士",
	"ic_evolve": "进化",
	"ic_rage": "暴怒",
	"ic_barricade": "不动如山",
	"ic_inflame": "点燃",
	"ic_metallicize": "金属化",
	"ic_brutality": "残忍",
	"ic_combust": "燃烧",
	"ic_dark_embrace": "黑暗拥抱",
	"ic_rupture": "断裂",
	"ic_fire_breathing": "火焰吐息",
	# STATUS CARDS
	"status_wound": "创伤",
	"status_burn": "灼伤",
	"status_dazed": "眩晕",
	# SILENT CARDS
	"si_dagger_throw": "匕首投掷",
	"si_quick_slash": "快速挥砍",
	"si_poisoned_stab": "毒刺",
	"si_dash": "冲刺",
	"si_backstab": "偷袭",
	"si_fan_of_knives": "飞刀",
	"si_blade_dance": "刀刃之舞",
	"si_predator_strike": "掠食者",
	"si_dodge": "翻滚闪避",
	"si_cloak": "暗影斗篷",
	"si_caltrops": "铁蒺藜",
	"si_envenom": "淬毒",
	"si_adrenaline": "肾上腺素",
	"si_accuracy": "精准",
}

# Card description translations: card_id -> zh description
var _card_descs_zh: Dictionary = {
	# IRONCLAD ATTACKS
	"ic_strike": "造成 6 点伤害。",
	"ic_bash": "造成 8 点伤害。\n施加 2 层易伤。",
	"ic_iron_wave": "造成 5 点伤害。\n获得 5 点格挡。",
	"ic_body_slam": "造成等同于你\n格挡值的伤害。",
	"ic_anger": "造成 6 点伤害。\n将一张本牌的复制\n加入弃牌堆。",
	"ic_cleave": "对所有敌人\n造成 8 点伤害。",
	"ic_twin_strike": "造成 5 点伤害两次。",
	"ic_wild_strike": "造成 12 点伤害。\n将一张创伤洗入\n抽牌堆。",
	"ic_pommel_strike": "造成 9 点伤害。\n抽 1 张牌。",
	"ic_headbutt": "造成 9 点伤害。",
	"ic_pummel": "造成 2 点伤害 x4。",
	"ic_uppercut": "造成 13 点伤害。\n施加 1 层虚弱。\n施加 1 层易伤。",
	"ic_immolate": "对所有敌人\n造成 21 点伤害。\n将一张灼伤加入弃牌堆。",
	"ic_fiend_fire": "消耗手牌。\n每消耗一张牌\n造成 7 点伤害。",
	"ic_reaper": "对所有敌人\n造成 4 点伤害。\n恢复等同于未被格挡\n伤害的生命值。",
	"ic_heavy_blade": "造成 14 点伤害。\n力量加成 x3。",
	"ic_thunderclap": "对所有敌人\n造成 4 点伤害。\n施加 1 层易伤。",
	"ic_hemokinesis": "失去 2 点生命。\n造成 15 点伤害。",
	"ic_reckless_charge": "造成 7 点伤害。\n将一张眩晕洗入\n抽牌堆。",
	"ic_clash": "只能在手牌全部\n为攻击牌时打出。\n造成 14 点伤害。",
	"ic_perfected_strike": "造成 6 点伤害。\n你牌组中每有一张\n\"打击\"牌，额外\n造成 2 点伤害。",
	"ic_bludgeon": "造成 32 点伤害。",
	"ic_sword_boomerang": "对随机敌人\n造成 3 点伤害 3 次。",
	"ic_searing_blow": "造成 12 点伤害。",
	"ic_whirlwind": "对所有敌人\n造成 5 点伤害 X 次。\n（X = 当前能量）",
	"ic_dropkick": "造成 5 点伤害。\n若敌人处于易伤状态：\n获得 1 点能量，抽 1 张牌。",
	"ic_carnage": "虚无。\n造成 20 点伤害。",
	"ic_clothesline": "造成 12 点伤害。\n施加 2 层虚弱。",
	"ic_feed": "造成 10 点伤害。\n若击杀则获得\n3 点最大生命。消耗。",
	"ic_rampage": "造成 8 点伤害。\n每次打出后\n伤害增加 5。",
	"ic_sever_soul": "消耗手牌中所有\n非攻击牌。\n造成 16 点伤害。",
	"ic_blood_for_blood": "你每失去一次生命，\n此牌费用减少 1。\n造成 18 点伤害。",
	# IRONCLAD SKILLS
	"ic_defend": "获得 5 点格挡。",
	"ic_shrug_it_off": "获得 8 点格挡。\n抽 1 张牌。",
	"ic_flame_barrier": "获得 12 点格挡。\n本回合受到攻击时，\n反弹 4 点伤害。",
	"ic_battle_trance": "抽 3 张牌。",
	"ic_bloodletting": "失去 3 点生命。\n获得 2 点能量。",
	"ic_flex": "获得 2 点力量。\n回合结束时，\n失去 2 点力量。",
	"ic_limit_break": "使你的力量翻倍。\n消耗。",
	"ic_entrench": "使你的格挡翻倍。",
	"ic_shockwave": "对所有敌人施加\n3 层虚弱和\n3 层易伤。消耗。",
	"ic_armaments": "获得 5 点格挡。",
	"ic_power_through": "获得 15 点格挡。\n将 2 张创伤\n加入手牌。",
	"ic_offering": "失去 6 点生命。\n获得 2 点能量。\n抽 3 张牌。消耗。",
	"ic_war_cry": "抽 1 张牌。\n消耗。",
	"ic_burning_pact": "消耗 1 张牌。\n抽 2 张牌。",
	"ic_seeing_red": "获得 2 点能量。\n消耗。",
	"ic_second_wind": "消耗手牌中所有\n非攻击牌。每消耗\n一张获得 5 点格挡。",
	"ic_intimidate": "对所有敌人\n施加 1 层虚弱。消耗。",
	"ic_infernal_blade": "将一张随机攻击牌\n加入手牌，其费用\n变为 0。消耗。",
	"ic_dual_wield": "复制手牌中的一张\n攻击或能力牌。",
	"ic_ghostly_armor": "虚无。\n获得 10 点格挡。",
	"ic_havoc": "打出抽牌堆顶部\n的牌并消耗它。",
	"ic_impervious": "获得 30 点格挡。\n消耗。",
	"ic_exhume": "将消耗堆中的一张牌\n加入手牌。消耗。",
	"ic_sentinel": "获得 5 点格挡。\n若本牌被消耗，\n获得 2 点能量。",
	"ic_spot_weakness": "若敌人意图攻击，\n获得 3 点力量。",
	"ic_true_grit": "获得 7 点格挡。\n随机消耗手牌中\n一张牌。",
	"ic_disarm": "敌人失去 2 点\n力量。消耗。",
	"ic_double_tap": "本回合你打出的\n下一张攻击牌\n会被打出两次。",
	# IRONCLAD POWERS
	"ic_demon_form": "每回合开始时，\n获得 2 点力量。",
	"ic_corruption": "技能牌费用变为 0。\n打出技能牌时，\n将其消耗。",
	"ic_berserk": "获得 1 层易伤。\n每回合开始时，\n获得 1 点能量。",
	"ic_feel_no_pain": "每当有牌被消耗时，\n获得 3 点格挡。",
	"ic_juggernaut": "每当你获得格挡时，\n对随机敌人造成\n5 点伤害。",
	"ic_evolve": "每当你抽到状态牌时，\n抽 1 张牌。",
	"ic_rage": "本回合每当你打出\n攻击牌时，\n获得 3 点格挡。",
	"ic_barricade": "你的格挡不再在\n回合开始时移除。",
	"ic_inflame": "获得 2 点力量。",
	"ic_metallicize": "回合结束时，\n获得 3 点格挡。",
	"ic_brutality": "回合开始时，\n失去 1 点生命，\n抽 1 张牌。",
	"ic_combust": "回合结束时，\n失去 1 点生命，\n对所有敌人造成\n5 点伤害。",
	"ic_dark_embrace": "每当有牌被消耗时，\n抽 1 张牌。",
	"ic_rupture": "每当你因打牌\n而失去生命时，\n获得 1 点力量。",
	"ic_fire_breathing": "每当你抽到状态牌\n或诅咒牌时，对所有\n敌人造成 6 点伤害。",
	# STATUS CARDS
	"status_wound": "无法打出。",
	"status_burn": "无法打出。\n回合结束时\n受到 2 点伤害。",
	"status_dazed": "无法打出。\n虚无。",
	# SILENT CARDS
	"si_dagger_throw": "造成 9 点伤害。\n抽 1 张牌。",
	"si_quick_slash": "造成 8 点伤害。\n抽 1 张牌。",
	"si_poisoned_stab": "造成 5 点伤害。\n施加 3 层易伤。",
	"si_dash": "获得 10 点格挡。",
	"si_backstab": "造成 11 点伤害。",
	"si_fan_of_knives": "对所有敌人\n造成 4 点伤害。\n抽 1 张牌。",
	"si_blade_dance": "将 3 张小刀\n加入手牌。",
	"si_predator_strike": "造成 15 点伤害。",
	"si_dodge": "获得 4 点格挡。\n下回合获得 4 点\n敏捷。",
	"si_cloak": "获得 6 点格挡。",
	"si_caltrops": "每当你受到攻击时，\n反弹 3 点伤害。",
	"si_envenom": "每当你造成未被格挡\n的伤害时，施加\n1 层易伤。",
	"si_adrenaline": "获得 1 点能量。\n抽 2 张牌。",
	"si_accuracy": "获得 3 点敏捷。",
}

func t(key: String) -> String:
	if _ui_strings.has(key):
		var entry: Dictionary = _ui_strings[key]
		if entry.has(current_lang):
			return entry[current_lang]
		return entry.get("en", key)
	return key

func tf(key: String, args: Array) -> String:
	var template: String = t(key)
	return template % args

func card_name(card_data: Dictionary) -> String:
	var card_id: String = card_data.get("id", "")
	# Handle upgraded card ids (strip + suffix for lookup)
	var base_id: String = card_id.trim_suffix("+") if card_id.ends_with("+") else card_id
	if current_lang == "zh" and _card_names_zh.has(base_id):
		var name_zh: String = _card_names_zh[base_id]
		if card_data.get("upgraded", false) or card_id.ends_with("+"):
			return name_zh + "+"
		return name_zh
	return card_data.get("name", "")

func card_desc(card_data: Dictionary) -> String:
	var card_id: String = card_data.get("id", "")
	var base_id: String = card_id.trim_suffix("+") if card_id.ends_with("+") else card_id
	if current_lang == "zh" and _card_descs_zh.has(base_id):
		# For upgraded cards we still use the English description since
		# upgrade overrides change numbers; the base zh description is a
		# reasonable fallback. A full solution would store upgraded zh descs too.
		if card_data.get("upgraded", false):
			# Return the base description – upgraded stats are shown in the
			# English description field from game_manager upgrade overrides.
			# We keep zh base desc as best-effort.
			return _card_descs_zh[base_id]
		return _card_descs_zh[base_id]
	return card_data.get("description", "")

func type_name(type_index: int) -> String:
	match type_index:
		0: return t("attack")
		1: return t("skill")
		2: return t("power")
		3: return t("status")
		_: return ""

func set_language(lang: String) -> void:
	current_lang = lang
