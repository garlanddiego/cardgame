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
	"next_step": {"en": "Next", "zh": "下一步"},
	"back": {"en": "Back", "zh": "返回"},
	"confirm_deck_title": {"en": "Confirm Deck", "zh": "确认牌组"},
	"remove": {"en": "X", "zh": "X"},
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
	# SILENT BASIC
	"si_strike": "打击",
	"si_defend": "防御",
	"si_neutralize": "中和",
	"si_survivor": "求生者",
	# SILENT COMMON ATTACKS
	"si_slice": "切割",
	"si_dagger_spray": "匕首连射",
	"si_dagger_throw": "匕首投掷",
	"si_flick_flack": "抽打",
	"si_leading_strike": "先导打击",
	"si_poisoned_stab": "毒刺",
	"si_sucker_punch": "偷袭拳",
	"si_ricochet": "弹射",
	"si_quick_slash": "快速挥砍",
	# SILENT COMMON SKILLS
	"si_anticipate": "预判",
	"si_deflect": "偏转",
	"si_prepared": "准备",
	"si_backflip": "后空翻",
	"si_dodge_and_roll": "翻滚闪避",
	"si_cloak_and_dagger": "暗影匕首",
	"si_outmaneuver": "智取",
	"si_acrobatics": "杂技",
	"si_blade_dance": "刀刃之舞",
	"si_escape_plan": "逃跑计划",
	"si_calculated_gamble": "赌博",
	"si_concentrate": "集中",
	# SILENT UNCOMMON ATTACKS
	"si_predator": "掠食者",
	"si_masterful_stab": "巧刺",
	"si_skewer": "穿刺",
	"si_die_die_die": "死死死",
	"si_endless_agony": "无尽痛苦",
	"si_eviscerate": "开膛",
	"si_finisher": "终结者",
	"si_flying_knee": "飞膝",
	"si_heel_hook": "脚跟勾",
	"si_glass_knife": "玻璃匕首",
	"si_choke": "扼喉",
	"si_riddle_with_holes": "千疮百孔",
	# SILENT UNCOMMON SKILLS
	"si_blur": "模糊",
	"si_dash": "冲刺",
	"si_terror": "恐惧",
	"si_distraction": "分心",
	"si_expertise": "专注",
	"si_infinite_blades": "无尽飞刃",
	"si_leg_sweep": "扫堂腿",
	"si_reflex": "反射",
	"si_setup": "布置",
	"si_tactician": "战术家",
	"si_bouncing_flask": "弹跳药瓶",
	"si_catalyst": "催化剂",
	"si_crippling_cloud": "致残之云",
	"si_deadly_poison": "致命毒药",
	"si_noxious_fumes": "毒雾",
	# SILENT UNCOMMON POWERS
	"si_accuracy": "精准",
	"si_caltrops": "铁蒺藜",
	"si_a_thousand_cuts": "千刀万剐",
	"si_envenom": "淬毒",
	"si_footwork": "步法",
	"si_tools_of_the_trade": "行业工具",
	# SILENT RARE ATTACKS
	"si_backstab": "偷袭",
	"si_grand_finale": "终幕",
	"si_unload": "倾泻",
	# SILENT RARE SKILLS
	"si_adrenaline": "肾上腺素",
	"si_alchemize": "炼金术",
	"si_bullet_time": "子弹时间",
	"si_burst": "爆发",
	"si_corpse_explosion": "尸爆",
	"si_malaise": "萎靡",
	"si_nightmare": "噩梦",
	"si_phantasmal_killer": "幻影杀手",
	# SILENT RARE POWERS
	"si_after_image": "残影",
	"si_storm_of_steel": "钢铁风暴",
	"si_well_laid_plans": "周密计划",
	"si_wraith_form": "幽灵形态",
	# SILENT STATUS
	"si_shiv": "小刀",
	"si_shiv_plus": "小刀+",
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
	# SILENT BASIC
	"si_strike": "造成 6 点伤害。",
	"si_defend": "获得 5 点格挡。",
	"si_neutralize": "造成 3 点伤害。\n施加 1 层虚弱。",
	"si_survivor": "获得 8 点格挡。\n弃 1 张牌。",
	# SILENT COMMON ATTACKS
	"si_slice": "造成 6 点伤害。",
	"si_dagger_spray": "对所有敌人\n造成 4 点伤害两次。",
	"si_dagger_throw": "造成 9 点伤害。\n抽 1 张牌，弃 1 张牌。",
	"si_flick_flack": "奇巧。对所有敌人\n造成 7 点伤害。",
	"si_leading_strike": "造成 7 点伤害。\n将 1 张小刀加入手牌。",
	"si_poisoned_stab": "造成 6 点伤害。\n施加 3 层中毒。",
	"si_sucker_punch": "造成 8 点伤害。\n施加 1 层虚弱。",
	"si_ricochet": "奇巧。对随机敌人\n造成 3 点伤害 4 次。",
	"si_quick_slash": "造成 8 点伤害。\n抽 1 张牌。",
	# SILENT COMMON SKILLS
	"si_anticipate": "本回合获得\n3 点敏捷。",
	"si_deflect": "获得 4 点格挡。",
	"si_prepared": "抽 1 张牌，弃 1 张牌。",
	"si_backflip": "获得 5 点格挡。\n抽 2 张牌。",
	"si_dodge_and_roll": "本回合和下回合\n获得 4 点格挡。",
	"si_cloak_and_dagger": "获得 6 点格挡。\n将 1 张小刀加入手牌。",
	"si_outmaneuver": "下回合获得\n2 点能量。",
	"si_acrobatics": "抽 3 张牌。\n弃 1 张牌。",
	"si_blade_dance": "将 3 张小刀\n加入手牌。",
	"si_escape_plan": "抽 1 张牌。若为\n技能牌则获得\n3 点格挡。",
	"si_calculated_gamble": "弃掉所有手牌。\n抽等量的牌。",
	"si_concentrate": "弃 3 张牌。\n获得 2 点能量。",
	# SILENT UNCOMMON ATTACKS
	"si_predator": "造成 15 点伤害。",
	"si_masterful_stab": "固有。\n造成 12 点伤害。",
	"si_skewer": "造成 7 点伤害 X 次。\n（X = 当前能量）",
	"si_die_die_die": "对所有敌人\n造成 13 点伤害。消耗。",
	"si_endless_agony": "造成 4 点伤害。\n消耗。抽到时将复制\n加入手牌。",
	"si_eviscerate": "造成 7 点伤害 3 次。",
	"si_finisher": "本回合每打出一张\n攻击牌，造成\n6 点伤害。",
	"si_flying_knee": "造成 8 点伤害。\n下回合获得\n1 点能量。",
	"si_heel_hook": "造成 5 点伤害。\n若敌人处于虚弱状态：\n获得 1 点能量，抽 1 张牌。",
	"si_glass_knife": "造成 8 点伤害两次。\n每次使用伤害\n减少 2。",
	"si_choke": "造成 12 点伤害。\n敌人每打出一张牌\n受到 3 点伤害。",
	"si_riddle_with_holes": "造成 3 点伤害 5 次。",
	# SILENT UNCOMMON SKILLS
	"si_blur": "获得 5 点格挡。\n格挡不在下回合\n开始时移除。",
	"si_dash": "获得 10 点格挡。\n造成 10 点伤害。",
	"si_terror": "施加 99 层易伤。\n消耗。",
	"si_distraction": "将一张随机技能牌\n加入手牌。消耗。",
	"si_expertise": "抽牌直到手牌\n有 6 张。",
	"si_infinite_blades": "每回合开始时\n将一张小刀加入手牌。",
	"si_leg_sweep": "施加 2 层虚弱。\n获得 11 点格挡。",
	"si_reflex": "奇巧。抽 2 张牌。",
	"si_setup": "将一张手牌放到\n抽牌堆顶部。",
	"si_tactician": "奇巧。获得 1 点能量。",
	"si_bouncing_flask": "对随机敌人施加\n3 层中毒 3 次。",
	"si_catalyst": "使目标的中毒\n层数翻倍。消耗。",
	"si_crippling_cloud": "对所有敌人施加\n4 层中毒和\n2 层虚弱。",
	"si_deadly_poison": "施加 5 层中毒。",
	"si_noxious_fumes": "每回合开始时\n对所有敌人施加\n2 层中毒。",
	# SILENT UNCOMMON POWERS
	"si_accuracy": "小刀额外造成\n4 点伤害。",
	"si_caltrops": "每当你受到攻击时，\n反弹 3 点伤害。",
	"si_a_thousand_cuts": "每当你打出一张牌，\n对所有敌人造成\n1 点伤害。",
	"si_envenom": "每当你造成未被格挡\n的伤害时，施加\n1 层中毒。",
	"si_footwork": "获得 2 点敏捷。",
	"si_tools_of_the_trade": "每回合开始时\n抽 1 张牌，弃 1 张牌。",
	# SILENT RARE ATTACKS
	"si_backstab": "造成 11 点伤害。\n固有。消耗。",
	"si_grand_finale": "只能在抽牌堆为空时\n打出。造成 50 点伤害。",
	"si_unload": "造成 14 点伤害。\n弃掉手牌中所有\n非攻击牌。",
	# SILENT RARE SKILLS
	"si_adrenaline": "获得 1 点能量。\n抽 2 张牌。消耗。",
	"si_alchemize": "获得一瓶随机药水。\n消耗。",
	"si_bullet_time": "本回合牌费用\n变为 0。下回合\n不抽牌。",
	"si_burst": "下一张技能牌\n打出两次。",
	"si_corpse_explosion": "施加 6 层中毒。\n敌人死亡时对所有\n敌人造成伤害。",
	"si_malaise": "敌人失去 X 点力量。\n施加 X 层虚弱。",
	"si_nightmare": "选择一张牌。\n下回合将 3 张复制\n加入手牌。",
	"si_phantasmal_killer": "下回合造成\n双倍伤害。",
	# SILENT RARE POWERS
	"si_after_image": "每当你打出一张牌，\n获得 1 点格挡。",
	"si_storm_of_steel": "弃掉所有手牌。\n每弃一张牌将一张\n小刀加入手牌。",
	"si_well_laid_plans": "回合结束时\n保留最多 1 张牌。",
	"si_wraith_form": "获得 2 层无实体。\n每回合失去\n1 点敏捷。",
	# SILENT STATUS
	"si_shiv": "造成 4 点伤害。\n消耗。",
	"si_shiv_plus": "造成 6 点伤害。\n消耗。",
}

# Upgraded card description translations: base card_id -> zh description (upgraded values)
var _card_descs_zh_plus: Dictionary = {
	# IRONCLAD ATTACKS
	"ic_strike": "造成 9 点伤害。",
	"ic_bash": "造成 10 点伤害。\n施加 3 层易伤。",
	"ic_iron_wave": "造成 7 点伤害。\n获得 7 点格挡。",
	"ic_body_slam": "造成等同于你\n格挡值的伤害。",
	"ic_anger": "造成 8 点伤害。\n将一张本牌的复制\n加入弃牌堆。",
	"ic_cleave": "对所有敌人\n造成 11 点伤害。",
	"ic_twin_strike": "造成 7 点伤害两次。",
	"ic_wild_strike": "造成 17 点伤害。\n将一张创伤洗入\n抽牌堆。",
	"ic_pommel_strike": "造成 10 点伤害。\n抽 2 张牌。",
	"ic_headbutt": "造成 12 点伤害。",
	"ic_pummel": "造成 2 点伤害 x5。",
	"ic_uppercut": "造成 16 点伤害。\n施加 2 层虚弱。\n施加 2 层易伤。",
	"ic_immolate": "对所有敌人\n造成 28 点伤害。\n将一张灼伤加入弃牌堆。",
	"ic_fiend_fire": "消耗手牌。\n每消耗一张牌\n造成 10 点伤害。",
	"ic_reaper": "对所有敌人\n造成 5 点伤害。\n恢复等同于未被格挡\n伤害的生命值。",
	"ic_heavy_blade": "造成 18 点伤害。\n力量加成 x5。",
	"ic_thunderclap": "对所有敌人\n造成 7 点伤害。\n施加 1 层易伤。",
	"ic_hemokinesis": "失去 2 点生命。\n造成 20 点伤害。",
	"ic_reckless_charge": "造成 10 点伤害。\n将一张眩晕洗入\n抽牌堆。",
	"ic_clash": "只能在手牌全部\n为攻击牌时打出。\n造成 18 点伤害。",
	"ic_perfected_strike": "造成 6 点伤害。\n你牌组中每有一张\n\"打击\"牌，额外\n造成 3 点伤害。",
	"ic_bludgeon": "造成 42 点伤害。",
	"ic_sword_boomerang": "对随机敌人\n造成 3 点伤害 4 次。",
	"ic_searing_blow": "造成 16 点伤害。",
	"ic_whirlwind": "对所有敌人\n造成 8 点伤害 X 次。\n（X = 当前能量）",
	"ic_dropkick": "造成 8 点伤害。\n若敌人处于易伤状态：\n获得 1 点能量，抽 1 张牌。",
	"ic_carnage": "虚无。\n造成 28 点伤害。",
	"ic_clothesline": "造成 14 点伤害。\n施加 3 层虚弱。",
	"ic_feed": "造成 12 点伤害。\n若击杀则获得\n4 点最大生命。消耗。",
	"ic_rampage": "造成 8 点伤害。\n每次打出后\n伤害增加 8。",
	"ic_sever_soul": "消耗手牌中所有\n非攻击牌。\n造成 22 点伤害。",
	"ic_blood_for_blood": "你每失去一次生命，\n此牌费用减少 1。\n造成 22 点伤害。",
	# IRONCLAD SKILLS
	"ic_defend": "获得 8 点格挡。",
	"ic_shrug_it_off": "获得 11 点格挡。\n抽 1 张牌。",
	"ic_flame_barrier": "获得 16 点格挡。\n本回合受到攻击时，\n反弹 6 点伤害。",
	"ic_battle_trance": "抽 4 张牌。",
	"ic_bloodletting": "失去 3 点生命。\n获得 3 点能量。",
	"ic_flex": "获得 4 点力量。\n回合结束时，\n失去 4 点力量。",
	"ic_limit_break": "使你的力量翻倍。",
	"ic_entrench": "使你的格挡翻倍。",
	"ic_shockwave": "对所有敌人施加\n5 层虚弱和\n5 层易伤。消耗。",
	"ic_armaments": "获得 5 点格挡。\n升级手牌中所有牌。",
	"ic_power_through": "获得 20 点格挡。\n将 2 张创伤\n加入手牌。",
	"ic_offering": "失去 6 点生命。\n获得 2 点能量。\n抽 5 张牌。消耗。",
	"ic_war_cry": "抽 2 张牌。\n消耗。",
	"ic_burning_pact": "消耗 1 张牌。\n抽 3 张牌。",
	"ic_seeing_red": "获得 2 点能量。\n消耗。",
	"ic_second_wind": "消耗手牌中所有\n非攻击牌。每消耗\n一张获得 7 点格挡。",
	"ic_intimidate": "对所有敌人\n施加 2 层虚弱。消耗。",
	"ic_infernal_blade": "将一张随机攻击牌\n加入手牌，其费用\n变为 0。消耗。",
	"ic_dual_wield": "复制手牌中的一张\n攻击或能力牌 2 次。",
	"ic_ghostly_armor": "虚无。\n获得 13 点格挡。",
	"ic_havoc": "打出抽牌堆顶部\n的牌并消耗它。",
	"ic_impervious": "获得 40 点格挡。\n消耗。",
	"ic_exhume": "将消耗堆中的一张牌\n加入手牌。消耗。",
	"ic_sentinel": "获得 8 点格挡。\n若本牌被消耗，\n获得 3 点能量。",
	"ic_spot_weakness": "若敌人意图攻击，\n获得 4 点力量。",
	"ic_true_grit": "获得 9 点格挡。\n消耗手牌中一张牌。",
	"ic_disarm": "敌人失去 3 点\n力量。消耗。",
	"ic_double_tap": "本回合你打出的\n下 2 张攻击牌\n会被打出两次。",
	# IRONCLAD POWERS
	"ic_demon_form": "每回合开始时，\n获得 3 点力量。",
	"ic_corruption": "技能牌费用变为 0。\n打出技能牌时，\n将其消耗。",
	"ic_berserk": "获得 1 层易伤。\n每回合开始时，\n获得 2 点能量。",
	"ic_feel_no_pain": "每当有牌被消耗时，\n获得 4 点格挡。",
	"ic_juggernaut": "每当你获得格挡时，\n对随机敌人造成\n7 点伤害。",
	"ic_evolve": "每当你抽到状态牌时，\n抽 2 张牌。",
	"ic_rage": "本回合每当你打出\n攻击牌时，\n获得 5 点格挡。",
	"ic_barricade": "你的格挡不再在\n回合开始时移除。",
	"ic_inflame": "获得 3 点力量。",
	"ic_metallicize": "回合结束时，\n获得 4 点格挡。",
	"ic_brutality": "天赋。回合开始时，\n失去 1 点生命，\n抽 1 张牌。",
	"ic_combust": "回合结束时，\n失去 1 点生命，\n对所有敌人造成\n7 点伤害。",
	"ic_dark_embrace": "每当有牌被消耗时，\n抽 1 张牌。",
	"ic_rupture": "每当你因打牌\n而失去生命时，\n获得 2 点力量。",
	"ic_fire_breathing": "每当你抽到状态牌\n或诅咒牌时，对所有\n敌人造成 10 点伤害。",
	# SILENT BASIC
	"si_strike": "造成 9 点伤害。",
	"si_defend": "获得 8 点格挡。",
	"si_neutralize": "造成 4 点伤害。\n施加 2 层虚弱。",
	"si_survivor": "获得 11 点格挡。\n弃 1 张牌。",
	# SILENT COMMON ATTACKS
	"si_slice": "造成 9 点伤害。",
	"si_dagger_spray": "对所有敌人\n造成 6 点伤害两次。",
	"si_dagger_throw": "造成 12 点伤害。\n抽 1 张牌，弃 1 张牌。",
	"si_flick_flack": "奇巧。对所有敌人\n造成 10 点伤害。",
	"si_leading_strike": "造成 10 点伤害。\n将 1 张小刀加入手牌。",
	"si_poisoned_stab": "造成 8 点伤害。\n施加 4 层中毒。",
	"si_sucker_punch": "造成 11 点伤害。\n施加 2 层虚弱。",
	"si_ricochet": "奇巧。对随机敌人\n造成 4 点伤害 4 次。",
	"si_quick_slash": "造成 12 点伤害。\n抽 1 张牌。",
	# SILENT COMMON SKILLS
	"si_anticipate": "本回合获得\n5 点敏捷。",
	"si_deflect": "获得 7 点格挡。",
	"si_prepared": "抽 2 张牌，弃 1 张牌。",
	"si_backflip": "获得 8 点格挡。\n抽 2 张牌。",
	"si_dodge_and_roll": "本回合和下回合\n获得 6 点格挡。",
	"si_cloak_and_dagger": "获得 6 点格挡。\n将 2 张小刀加入手牌。",
	"si_outmaneuver": "下回合获得\n3 点能量。",
	"si_acrobatics": "抽 4 张牌。\n弃 1 张牌。",
	"si_blade_dance": "将 4 张小刀\n加入手牌。",
	"si_escape_plan": "抽 1 张牌。若为\n技能牌则获得\n5 点格挡。",
	"si_calculated_gamble": "弃掉所有手牌。\n抽等量 +1 的牌。",
	"si_concentrate": "弃 2 张牌。\n获得 2 点能量。",
	# SILENT UNCOMMON ATTACKS
	"si_predator": "造成 20 点伤害。",
	"si_masterful_stab": "固有。\n造成 16 点伤害。",
	"si_skewer": "造成 10 点伤害 X 次。\n（X = 当前能量）",
	"si_die_die_die": "对所有敌人\n造成 17 点伤害。消耗。",
	"si_endless_agony": "造成 6 点伤害。\n消耗。抽到时将复制\n加入手牌。",
	"si_eviscerate": "造成 9 点伤害 3 次。",
	"si_finisher": "本回合每打出一张\n攻击牌，造成\n8 点伤害。",
	"si_flying_knee": "造成 11 点伤害。\n下回合获得\n1 点能量。",
	"si_heel_hook": "造成 8 点伤害。\n若敌人处于虚弱状态：\n获得 1 点能量，抽 1 张牌。",
	"si_glass_knife": "造成 12 点伤害两次。\n每次使用伤害\n减少 2。",
	"si_choke": "造成 16 点伤害。\n敌人每打出一张牌\n受到 4 点伤害。",
	"si_riddle_with_holes": "造成 4 点伤害 5 次。",
	# SILENT UNCOMMON SKILLS
	"si_blur": "获得 8 点格挡。\n格挡不在下回合\n开始时移除。",
	"si_dash": "获得 13 点格挡。\n造成 13 点伤害。",
	"si_terror": "施加 99 层易伤。\n消耗。",
	"si_distraction": "将一张随机技能牌\n加入手牌。消耗。",
	"si_expertise": "抽牌直到手牌\n有 7 张。",
	"si_infinite_blades": "每回合开始时\n将一张小刀+加入手牌。",
	"si_leg_sweep": "施加 3 层虚弱。\n获得 14 点格挡。",
	"si_reflex": "奇巧。抽 3 张牌。",
	"si_setup": "将一张手牌放到\n抽牌堆顶部。",
	"si_tactician": "奇巧。获得 2 点能量。",
	"si_bouncing_flask": "对随机敌人施加\n4 层中毒 3 次。",
	"si_catalyst": "使目标的中毒\n层数变为三倍。消耗。",
	"si_crippling_cloud": "对所有敌人施加\n7 层中毒和\n3 层虚弱。",
	"si_deadly_poison": "施加 7 层中毒。",
	"si_noxious_fumes": "每回合开始时\n对所有敌人施加\n3 层中毒。",
	# SILENT UNCOMMON POWERS
	"si_accuracy": "小刀额外造成\n6 点伤害。",
	"si_caltrops": "每当你受到攻击时，\n反弹 5 点伤害。",
	"si_a_thousand_cuts": "每当你打出一张牌，\n对所有敌人造成\n2 点伤害。",
	"si_envenom": "每当你造成未被格挡\n的伤害时，施加\n2 层中毒。",
	"si_footwork": "获得 3 点敏捷。",
	"si_tools_of_the_trade": "每回合开始时\n抽 1 张牌，弃 1 张牌。",
	# SILENT RARE ATTACKS
	"si_backstab": "造成 15 点伤害。\n固有。消耗。",
	"si_grand_finale": "只能在抽牌堆为空时\n打出。造成 60 点伤害。",
	"si_unload": "造成 18 点伤害。\n弃掉手牌中所有\n非攻击牌。",
	# SILENT RARE SKILLS
	"si_adrenaline": "获得 2 点能量。\n抽 3 张牌。消耗。",
	"si_alchemize": "获得一瓶随机药水。\n消耗。",
	"si_bullet_time": "本回合牌费用\n变为 0。下回合\n不抽牌。",
	"si_burst": "下 2 张技能牌\n打出两次。",
	"si_corpse_explosion": "施加 9 层中毒。\n敌人死亡时对所有\n敌人造成伤害。",
	"si_malaise": "敌人失去 X+1 点力量。\n施加 X+1 层虚弱。",
	"si_nightmare": "选择一张牌。\n下回合将 3 张复制\n加入手牌。",
	"si_phantasmal_killer": "下回合造成\n双倍伤害。",
	# SILENT RARE POWERS
	"si_after_image": "每当你打出一张牌，\n获得 1 点格挡。",
	"si_storm_of_steel": "弃掉所有手牌。\n每弃一张牌将一张\n小刀+加入手牌。",
	"si_well_laid_plans": "回合结束时\n保留最多 2 张牌。",
	"si_wraith_form": "获得 3 层无实体。\n每回合失去\n1 点敏捷。",
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
	var desc: String = ""
	if current_lang == "zh":
		if card_data.get("upgraded", false) and _card_descs_zh_plus.has(base_id):
			desc = _card_descs_zh_plus[base_id]
		elif _card_descs_zh.has(base_id):
			desc = _card_descs_zh[base_id]
	if desc == "":
		desc = card_data.get("description", "")
	# Inject hero name for cards with hero_target
	if card_data.get("hero_target", "") != "" and current_lang == "zh":
		var hero_name: String = _hero_display_name(card_data.get("character", ""))
		if hero_name != "":
			desc = _inject_hero_name(desc, hero_name)
	return desc

func _hero_display_name(character_id: String) -> String:
	match character_id:
		"ironclad": return "铁甲战士"
		"silent": return "沉默猎手"
	return ""

func _inject_hero_name(desc: String, hero_name: String) -> String:
	## Insert hero name before the first hero-attribute verb in Chinese descriptions.
	## Only injects on lines about hero-specific attributes (HP, block, strength, etc.)
	## Skips universal mechanics (energy, draw, discard, exhaust, potions).
	var lines: PackedStringArray = desc.split("\n")
	var result: PackedStringArray = PackedStringArray()
	var injected: bool = false
	var hero_verbs: Array = ["造成", "获得", "失去", "恢复", "使你"]
	# Lines containing these keywords are universal, not hero-specific
	var skip_keywords: Array = ["能量", "张牌", "药水"]
	for line in lines:
		var trimmed: String = line.strip_edges()
		if not injected:
			var matched_verb: bool = false
			for verb in hero_verbs:
				if trimmed.begins_with(verb):
					matched_verb = true
					break
			if matched_verb:
				var is_universal: bool = false
				for kw in skip_keywords:
					if kw in trimmed:
						is_universal = true
						break
				if not is_universal:
					line = hero_name + trimmed
					injected = true
		result.append(line)
	return "\n".join(result)

func type_name(type_index: int) -> String:
	match type_index:
		0: return t("attack")
		1: return t("skill")
		2: return t("power")
		3: return t("status")
		_: return ""

func set_language(lang: String) -> void:
	current_lang = lang
