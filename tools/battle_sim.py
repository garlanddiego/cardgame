#!/usr/bin/env python3
"""
Card Game Battle Simulator — finds optimal play strategy for any card combination.
Simulates hero vs monster battles, evaluates card strength by remaining HP.

Usage:
  python3 tools/battle_sim.py                    # Run default simulation
  python3 tools/battle_sim.py --all-combos 4     # Test all 4-card combos from pool
  python3 tools/battle_sim.py --cards bash,inflame,heavy_blade,shrug_it_off
"""

import itertools
import json
import os
import sys
from copy import deepcopy
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Tuple
from pathlib import Path

# =============================================================================
# CARD DEFINITIONS
# =============================================================================

# =============================================================================
# LOAD CARDS FROM GODOT EXPORT (single source of truth)
# =============================================================================

def load_cards_from_export():
    """Load card database from Godot's exported JSON. Returns (cards_dict, zh_names)."""
    export_path = Path(__file__).parent / "cards_export.json"
    if not export_path.exists():
        return None, None

    with open(export_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    cards = {}
    zh_names = {}
    raw_cards = data.get("cards", {})

    for card_id, card in raw_cards.items():
        card_type = card.get("type", 0)
        # Skip status cards (type 3)
        if card_type == 3:
            continue
        # Skip incomplete/deprecated
        if card.get("status", "active") != "active":
            continue

        type_map = {0: "attack", 1: "skill", 2: "power"}
        sim_card = {
            "name": card.get("name", card_id),
            "cost": card.get("cost", 1),
            "type": type_map.get(card_type, "skill"),
            "char": card.get("character", "neutral"),
            "effects": _convert_actions(card),
        }
        if card.get("exhaust", False):
            sim_card["exhaust"] = True
        if card.get("ethereal", False):
            sim_card["ethereal"] = True

        cards[card_id] = sim_card
        zh_names[card_id] = card.get("name", card_id)

    return cards, zh_names


def _convert_actions(card):
    """Convert Godot card actions to simulator effects."""
    effects = []
    actions = card.get("actions", [])
    damage = card.get("damage", 0)
    block = card.get("block", 0)
    draw = card.get("draw", 0)
    times = card.get("times", 1)

    for action in actions:
        atype = action.get("type", "")

        if atype == "damage" or atype == "damage_all":
            eff = {"type": "damage", "value": damage}
            if times > 1:
                eff["times"] = times
            str_mult = card.get("str_mult", 0)
            if str_mult > 1:
                eff["str_mult"] = str_mult
            effects.append(eff)

        elif atype == "block":
            if block > 0:
                effects.append({"type": "block", "value": block})

        elif atype == "draw":
            if draw > 0:
                effects.append({"type": "draw", "value": draw})

        elif atype == "apply_status":
            source = action.get("source", "apply_status")
            status_data = card.get(source, {})
            if isinstance(status_data, dict):
                st = status_data.get("type", "")
                stacks = status_data.get("stacks", 1)
                if st == "vulnerable":
                    effects.append({"type": "apply_vulnerable", "value": stacks})
                elif st == "weak":
                    effects.append({"type": "apply_weak", "value": stacks})
                elif st == "poison":
                    effects.append({"type": "apply_poison", "value": stacks})

        elif atype == "apply_self_status":
            status = action.get("status", "")
            stacks = action.get("stacks", 1)
            if status == "strength":
                effects.append({"type": "gain_strength", "value": stacks})
            elif status == "dexterity":
                pass  # Dexterity not fully simulated

        elif atype == "self_damage":
            effects.append({"type": "self_damage", "value": action.get("value", 0)})

        elif atype == "gain_energy":
            effects.append({"type": "gain_energy", "value": action.get("value", 1)})

        elif atype == "add_shiv":
            pass  # Shivs not simulated yet

        elif atype == "power_effect":
            power = action.get("power", "")
            eff = {"type": "power", "power": power}
            if power == "noxious_fumes":
                eff["value"] = 2
            elif power == "accuracy":
                eff["value"] = 4
            effects.append(eff)

        elif atype == "call":
            fn = action.get("fn", "")
            # Map known call functions to effects
            if fn == "whirlwind":
                effects.append({"type": "x_damage_poison", "value": damage})
            elif fn == "toxic_storm":
                effects.append({"type": "x_damage_poison", "value": damage})
            elif fn == "poison_shield":
                effects.append({"type": "poison_to_block"})
            elif fn == "gamblers_blade":
                effects.append({"type": "hand_size_damage", "mult": 3})
            elif fn == "all_in":
                effects.append({"type": "all_in_draw"})
            elif fn == "limit_break":
                effects.append({"type": "double_strength"})
            elif fn == "catalyst":
                effects.append({"type": "double_poison"})
            elif fn == "body_slam":
                effects.append({"type": "damage", "value": 0})  # Block-based (simplified)
            else:
                # Fallback: treat as damage if card has damage
                if damage > 0:
                    eff = {"type": "damage", "value": damage}
                    if times > 1:
                        eff["times"] = times
                    effects.append(eff)

    # If no effects parsed but card has basic values, add them
    if not effects:
        if damage > 0:
            eff = {"type": "damage", "value": damage}
            if times > 1:
                eff["times"] = times
            effects.append(eff)
        if block > 0:
            effects.append({"type": "block", "value": block})
        if draw > 0:
            effects.append({"type": "draw", "value": draw})

    return effects


# Chinese name lookup for output
ZH_NAMES = {
    "strike": "打击", "bash": "重击", "iron_wave": "铁浪", "twin_strike": "双击",
    "pommel_strike": "柄击", "heavy_blade": "重刃", "cleave": "劈砍", "headbutt": "头槌",
    "uppercut": "上勾拳", "pummel": "连击", "bludgeon": "痛殴", "hemokinesis": "血动力学",
    "carnage": "大屠杀", "clothesline": "过肩摔", "defend": "防御", "shrug_it_off": "耸肩",
    "battle_trance": "战斗冥想", "bloodletting": "献血", "offering": "供奉",
    "impervious": "坚不可摧", "flame_barrier": "火焰屏障", "flex": "屈伸",
    "seeing_red": "目赤", "limit_break": "极限爆发", "inflame": "燃烧",
    "demon_form": "恶魔形态", "metallicize": "金属化",
    "si_strike": "打击", "neutralize": "中和", "poisoned_stab": "毒刺",
    "quick_slash": "快斩", "dagger_spray": "飞刀喷", "eviscerate": "剜心",
    "glass_knife": "玻璃刀", "riddle_with_holes": "千疮百孔",
    "si_defend": "防御", "backflip": "后空翻", "deadly_poison": "致命毒",
    "leg_sweep": "扫腿", "catalyst": "催化",
    "noxious_fumes": "毒雾", "envenom": "淬毒", "accuracy": "精准",
    "venomous_might": "毒化之力", "toxic_storm": "毒风暴", "poison_shield": "毒雾护盾",
    "gamblers_blade": "赌徒之刃", "echo_slash": "回声斩", "all_in": "全力以赴",
    "blood_fury": "血怒", "psi_surge": "灵能涌动", "tactical_retreat": "战术撤退",
}

CARDS = {
    # --- Ironclad Attacks ---
    "strike": {"name": "Strike", "cost": 1, "type": "attack", "char": "ironclad",
               "effects": [{"type": "damage", "value": 6}]},
    "bash": {"name": "Bash", "cost": 2, "type": "attack", "char": "ironclad",
             "effects": [{"type": "damage", "value": 8}, {"type": "apply_vulnerable", "value": 2}]},
    "iron_wave": {"name": "Iron Wave", "cost": 1, "type": "attack", "char": "ironclad",
                  "effects": [{"type": "damage", "value": 5}, {"type": "block", "value": 5}]},
    "twin_strike": {"name": "Twin Strike", "cost": 1, "type": "attack", "char": "ironclad",
                    "effects": [{"type": "damage", "value": 5, "times": 2}]},
    "pommel_strike": {"name": "Pommel Strike", "cost": 1, "type": "attack", "char": "ironclad",
                      "effects": [{"type": "damage", "value": 9}, {"type": "draw", "value": 1}]},
    "heavy_blade": {"name": "Heavy Blade", "cost": 2, "type": "attack", "char": "ironclad",
                    "effects": [{"type": "damage", "value": 14, "str_mult": 3}]},
    "cleave": {"name": "Cleave", "cost": 1, "type": "attack", "char": "ironclad",
               "effects": [{"type": "damage", "value": 8}]},
    "headbutt": {"name": "Headbutt", "cost": 1, "type": "attack", "char": "ironclad",
                 "effects": [{"type": "damage", "value": 9}]},
    "uppercut": {"name": "Uppercut", "cost": 2, "type": "attack", "char": "ironclad",
                 "effects": [{"type": "damage", "value": 13}, {"type": "apply_weak", "value": 1}, {"type": "apply_vulnerable", "value": 1}]},
    "pummel": {"name": "Pummel", "cost": 1, "type": "attack", "char": "ironclad",
               "effects": [{"type": "damage", "value": 2, "times": 4}]},
    "bludgeon": {"name": "Bludgeon", "cost": 3, "type": "attack", "char": "ironclad",
                 "effects": [{"type": "damage", "value": 32}]},
    "hemokinesis": {"name": "Hemokinesis", "cost": 1, "type": "attack", "char": "ironclad",
                    "effects": [{"type": "self_damage", "value": 2}, {"type": "damage", "value": 15}]},
    "carnage": {"name": "Carnage", "cost": 2, "type": "attack", "char": "ironclad",
                "effects": [{"type": "damage", "value": 20}], "ethereal": True},
    "clothesline": {"name": "Clothesline", "cost": 2, "type": "attack", "char": "ironclad",
                    "effects": [{"type": "damage", "value": 12}, {"type": "apply_weak", "value": 2}]},

    # --- Ironclad Skills ---
    "defend": {"name": "Defend", "cost": 1, "type": "skill", "char": "ironclad",
               "effects": [{"type": "block", "value": 5}]},
    "shrug_it_off": {"name": "Shrug It Off", "cost": 1, "type": "skill", "char": "ironclad",
                     "effects": [{"type": "block", "value": 8}, {"type": "draw", "value": 1}]},
    "battle_trance": {"name": "Battle Trance", "cost": 0, "type": "skill", "char": "ironclad",
                      "effects": [{"type": "draw", "value": 3}]},
    "bloodletting": {"name": "Bloodletting", "cost": 0, "type": "skill", "char": "ironclad",
                     "effects": [{"type": "self_damage", "value": 3}, {"type": "gain_energy", "value": 2}]},
    "offering": {"name": "Offering", "cost": 0, "type": "skill", "char": "ironclad",
                 "effects": [{"type": "self_damage", "value": 6}, {"type": "gain_energy", "value": 2}, {"type": "draw", "value": 3}],
                 "exhaust": True},
    "impervious": {"name": "Impervious", "cost": 2, "type": "skill", "char": "ironclad",
                   "effects": [{"type": "block", "value": 30}], "exhaust": True},
    "flame_barrier": {"name": "Flame Barrier", "cost": 2, "type": "skill", "char": "ironclad",
                      "effects": [{"type": "block", "value": 12}]},
    "flex": {"name": "Flex", "cost": 0, "type": "skill", "char": "ironclad",
             "effects": [{"type": "temp_strength", "value": 2}]},
    "seeing_red": {"name": "Seeing Red", "cost": 1, "type": "skill", "char": "ironclad",
                   "effects": [{"type": "gain_energy", "value": 2}], "exhaust": True},
    "limit_break": {"name": "Limit Break", "cost": 1, "type": "skill", "char": "ironclad",
                    "effects": [{"type": "double_strength"}], "exhaust": True},

    # --- Ironclad Powers ---
    "inflame": {"name": "Inflame", "cost": 1, "type": "power", "char": "ironclad",
                "effects": [{"type": "gain_strength", "value": 2}]},
    "demon_form": {"name": "Demon Form", "cost": 3, "type": "power", "char": "ironclad",
                   "effects": [{"type": "power", "power": "demon_form"}]},
    "metallicize": {"name": "Metallicize", "cost": 1, "type": "power", "char": "ironclad",
                    "effects": [{"type": "power", "power": "metallicize"}]},

    # --- Silent Attacks ---
    "si_strike": {"name": "Strike", "cost": 1, "type": "attack", "char": "silent",
                  "effects": [{"type": "damage", "value": 6}]},
    "neutralize": {"name": "Neutralize", "cost": 0, "type": "attack", "char": "silent",
                   "effects": [{"type": "damage", "value": 3}, {"type": "apply_weak", "value": 1}]},
    "poisoned_stab": {"name": "Poisoned Stab", "cost": 1, "type": "attack", "char": "silent",
                      "effects": [{"type": "damage", "value": 6}, {"type": "apply_poison", "value": 3}]},
    "quick_slash": {"name": "Quick Slash", "cost": 1, "type": "attack", "char": "silent",
                    "effects": [{"type": "damage", "value": 8}, {"type": "draw", "value": 1}]},
    "dagger_spray": {"name": "Dagger Spray", "cost": 1, "type": "attack", "char": "silent",
                     "effects": [{"type": "damage", "value": 4, "times": 2}]},
    "eviscerate": {"name": "Eviscerate", "cost": 3, "type": "attack", "char": "silent",
                   "effects": [{"type": "damage", "value": 7, "times": 3}]},
    "glass_knife": {"name": "Glass Knife", "cost": 1, "type": "attack", "char": "silent",
                    "effects": [{"type": "damage", "value": 8, "times": 2}]},
    "riddle_with_holes": {"name": "Riddle with Holes", "cost": 2, "type": "attack", "char": "silent",
                          "effects": [{"type": "damage", "value": 3, "times": 5}]},

    # --- Silent Skills ---
    "si_defend": {"name": "Defend", "cost": 1, "type": "skill", "char": "silent",
                  "effects": [{"type": "block", "value": 5}]},
    "backflip": {"name": "Backflip", "cost": 1, "type": "skill", "char": "silent",
                 "effects": [{"type": "block", "value": 5}, {"type": "draw", "value": 2}]},
    "deadly_poison": {"name": "Deadly Poison", "cost": 1, "type": "skill", "char": "silent",
                      "effects": [{"type": "apply_poison", "value": 5}]},
    "leg_sweep": {"name": "Leg Sweep", "cost": 2, "type": "skill", "char": "silent",
                  "effects": [{"type": "block", "value": 11}, {"type": "apply_weak", "value": 2}]},
    "catalyst": {"name": "Catalyst", "cost": 1, "type": "skill", "char": "silent",
                 "effects": [{"type": "double_poison"}], "exhaust": True},

    # --- Silent Powers ---
    "noxious_fumes": {"name": "Noxious Fumes", "cost": 1, "type": "power", "char": "silent",
                      "effects": [{"type": "power", "power": "noxious_fumes", "value": 2}]},
    "envenom": {"name": "Envenom", "cost": 2, "type": "power", "char": "silent",
                "effects": [{"type": "power", "power": "envenom"}]},
    "accuracy": {"name": "Accuracy", "cost": 1, "type": "power", "char": "silent",
                 "effects": [{"type": "power", "power": "accuracy", "value": 4}]},

    # --- New Cards ---
    "venomous_might": {"name": "Venomous Might", "cost": 1, "type": "power", "char": "neutral",
                       "effects": [{"type": "power", "power": "venomous_might"}]},
    "toxic_storm": {"name": "Toxic Storm", "cost": -1, "type": "attack", "char": "silent",
                    "effects": [{"type": "x_damage_poison", "value": 3}]},
    "poison_shield": {"name": "Poison Shield", "cost": 1, "type": "skill", "char": "silent",
                      "effects": [{"type": "poison_to_block"}]},
    "gamblers_blade": {"name": "Gambler's Blade", "cost": 0, "type": "attack", "char": "silent",
                       "effects": [{"type": "hand_size_damage", "mult": 3}]},
    "echo_slash": {"name": "Echo Slash", "cost": 2, "type": "attack", "char": "neutral",
                   "effects": [{"type": "damage", "value": 5, "scale_with_attacks": True}]},
    "all_in": {"name": "All In", "cost": 0, "type": "skill", "char": "neutral",
               "effects": [{"type": "all_in_draw"}], "exhaust": True},
    "blood_fury": {"name": "Blood Fury", "cost": 1, "type": "power", "char": "ironclad",
                   "effects": [{"type": "power", "power": "blood_fury"}]},
    "psi_surge": {"name": "Psi Surge", "cost": 2, "type": "power", "char": "neutral",
                  "effects": [{"type": "power", "power": "psi_surge"}]},
    "tactical_retreat": {"name": "Tactical Retreat", "cost": 1, "type": "skill", "char": "neutral",
                         "effects": [{"type": "block", "value": 6}, {"type": "draw", "value": 2}]},
}


# =============================================================================
# BATTLE STATE (multi-monster support)
# =============================================================================

def make_monster(hp, base_dmg, dmg_inc):
    return {"hp": hp, "vulnerable": 0, "weak": 0, "poison": 0,
            "base_dmg": base_dmg, "dmg_inc": dmg_inc}

@dataclass
class BattleState:
    hero_hp: int = 200
    hero_max_hp: int = 200
    hero_block: int = 0
    hero_strength: int = 0
    hero_temp_strength: int = 0
    energy: int = 3
    max_energy: int = 3

    monsters: list = field(default_factory=list)  # list of monster dicts

    turn: int = 0
    hand: list = field(default_factory=list)
    draw_pile: list = field(default_factory=list)
    discard_pile: list = field(default_factory=list)
    exhaust_pile: list = field(default_factory=list)
    attacks_played: int = 0

    # Powers
    demon_form: bool = False
    metallicize: int = 0
    noxious_fumes: int = 0
    envenom: bool = False
    accuracy: int = 0
    venomous_might: bool = False
    blood_fury: bool = False
    blood_fury_active: bool = False
    psi_surge: bool = False

    total_cards_played: int = 0
    max_turn_damage: int = 0
    current_turn_damage: int = 0

    def alive_monsters(self):
        return [m for m in self.monsters if m["hp"] > 0]

    def first_alive(self):
        for m in self.monsters:
            if m["hp"] > 0:
                return m
        return None

    def total_poison(self):
        return sum(m["poison"] for m in self.alive_monsters())

    def all_dead(self):
        return all(m["hp"] <= 0 for m in self.monsters)


def calc_hit(state, base, target, str_mult=1):
    """Calculate single-hit damage against a target monster."""
    per_hit = max(0, base + state.hero_strength * str_mult)
    if target["vulnerable"] > 0:
        per_hit = int(per_hit * 1.5)
    if state.blood_fury_active:
        per_hit *= 2
        state.blood_fury_active = False
    return per_hit


def apply_card(state, card_id):
    """Apply card effects. Single-target effects hit first alive monster."""
    card = CARDS[card_id]
    target = state.first_alive()
    if target is None:
        return

    for effect in card["effects"]:
        etype = effect["type"]

        if etype == "damage":
            times = effect.get("times", 1)
            str_mult = effect.get("str_mult", 1)
            for _ in range(times):
                t = state.first_alive()
                if t is None:
                    break
                dmg = calc_hit(state, effect["value"], t, str_mult)
                t["hp"] -= dmg
                state.current_turn_damage += dmg
                if state.envenom:
                    t["poison"] += 1
            state.attacks_played += 1

        elif etype == "block":
            state.hero_block += effect["value"]

        elif etype == "apply_vulnerable":
            t = state.first_alive()
            if t: t["vulnerable"] += effect["value"]

        elif etype == "apply_weak":
            t = state.first_alive()
            if t: t["weak"] += effect["value"]

        elif etype == "apply_poison":
            t = state.first_alive()
            if t: t["poison"] += effect["value"]

        elif etype == "double_poison":
            t = state.first_alive()
            if t: t["poison"] *= 2

        elif etype == "self_damage":
            state.hero_hp -= effect["value"]
            if state.blood_fury:
                state.blood_fury_active = True

        elif etype == "gain_energy":
            state.energy += effect["value"]

        elif etype == "gain_strength":
            state.hero_strength += effect["value"]

        elif etype == "temp_strength":
            state.hero_strength += effect["value"]
            state.hero_temp_strength += effect["value"]

        elif etype == "double_strength":
            state.hero_strength *= 2

        elif etype == "draw":
            for _ in range(effect["value"]):
                if not state.draw_pile:
                    state.draw_pile = list(state.discard_pile)
                    state.discard_pile = []
                    import random; random.shuffle(state.draw_pile)
                if state.draw_pile:
                    state.hand.append(state.draw_pile.pop())

        elif etype == "power":
            p = effect["power"]
            if p == "demon_form": state.demon_form = True
            elif p == "metallicize": state.metallicize = 3
            elif p == "noxious_fumes": state.noxious_fumes = effect.get("value", 2)
            elif p == "envenom": state.envenom = True
            elif p == "accuracy": state.accuracy += effect.get("value", 4)
            elif p == "venomous_might": state.venomous_might = True
            elif p == "blood_fury": state.blood_fury = True
            elif p == "psi_surge": state.psi_surge = True

        elif etype == "x_damage_poison":
            x = state.energy
            base = effect["value"]
            for _ in range(x):
                for m in state.alive_monsters():
                    dmg = calc_hit(state, base, m)
                    m["hp"] -= dmg
                    m["poison"] += 1
                    state.current_turn_damage += dmg
            state.energy = 0

        elif etype == "poison_to_block":
            state.hero_block += state.total_poison()

        elif etype == "hand_size_damage":
            t = state.first_alive()
            if t:
                dmg = len(state.hand) * effect["mult"] + state.hero_strength
                if t["vulnerable"] > 0: dmg = int(dmg * 1.5)
                t["hp"] -= dmg
                state.current_turn_damage += dmg

        elif etype == "all_in_draw":
            e = state.energy; state.energy = 0
            for _ in range(e * 2):
                if not state.draw_pile:
                    state.draw_pile = list(state.discard_pile)
                    state.discard_pile = []
                    import random; random.shuffle(state.draw_pile)
                if state.draw_pile:
                    state.hand.append(state.draw_pile.pop())

    if card.get("exhaust"):
        state.exhaust_pile.append(card_id)
    elif card["type"] != "power":
        state.discard_pile.append(card_id)


# =============================================================================
# GREEDY AI — picks best card each step
# =============================================================================

def score_card(state, card_id):
    """Heuristic score for playing a card. Higher = better."""
    card = CARDS[card_id]
    cost = card["cost"]
    if cost == -1: cost = state.energy
    if cost > state.energy: return -999

    s = deepcopy(state)
    s.energy -= cost
    old_total_hp = sum(m["hp"] for m in s.alive_monsters())
    old_block = s.hero_block
    old_str = s.hero_strength
    old_poison = s.total_poison()

    apply_card(s, card_id)

    new_total_hp = sum(max(0, m["hp"]) for m in s.monsters)
    damage_dealt = old_total_hp - new_total_hp
    block_gained = s.hero_block - old_block
    strength_gained = s.hero_strength - old_str
    poison_gained = s.total_poison() - old_poison
    hp_lost = state.hero_hp - s.hero_hp

    # Total incoming damage from all alive monsters
    total_incoming = 0
    for m in state.alive_monsters():
        d = m["base_dmg"] + m["dmg_inc"] * (state.turn - 1)
        if m["weak"] > 0: d = int(d * 0.75)
        total_incoming += d

    score = 0.0
    score += damage_dealt * 1.0
    score += min(block_gained, max(0, total_incoming - state.hero_block)) * 0.8
    score += strength_gained * 8.0
    score += poison_gained * 2.0
    score -= hp_lost * 0.5

    if card["type"] == "power":
        for eff in card["effects"]:
            if eff["type"] == "power":
                p = eff["power"]
                if p == "demon_form": score += 30
                elif p == "noxious_fumes": score += 15 * len(state.alive_monsters())
                elif p == "metallicize": score += 10
                elif p == "envenom": score += 12
                elif p == "venomous_might": score += max(5, state.total_poison() * 2)
                elif p == "blood_fury": score += 10

    if cost > 0: score = score / cost
    return score


def greedy_play_turn(state: BattleState) -> List[str]:
    """Play cards greedily until out of energy or no good plays."""
    played = []
    while state.energy > 0 and state.hand:
        best_id = None
        best_score = -999
        for card_id in state.hand:
            card = CARDS[card_id]
            cost = card["cost"]
            if cost == -1:
                cost = state.energy
            if cost > state.energy:
                continue
            sc = score_card(state, card_id)
            if sc > best_score:
                best_score = sc
                best_id = card_id

        if best_id is None or best_score <= 0:
            break

        card = CARDS[best_id]
        cost = card["cost"]
        if cost == -1:
            cost = state.energy
        state.energy -= cost
        state.hand.remove(best_id)
        apply_card(state, best_id)
        state.total_cards_played += 1
        played.append(best_id)

    return played


# =============================================================================
# SIMULATION
# =============================================================================

def simulate_battle(deck, hero_hp=200, monster_hp=100,
                    monster_dmg=8, monster_inc=2, monster_count=2,
                    max_turns=20, verbose=False):
    """Simulate a full battle with multiple monsters."""
    import random
    state = BattleState(hero_hp=hero_hp, hero_max_hp=hero_hp)
    state.monsters = [make_monster(monster_hp, monster_dmg, monster_inc) for _ in range(monster_count)]
    state.draw_pile = list(deck)
    random.shuffle(state.draw_pile)

    for turn in range(1, max_turns + 1):
        state.turn = turn
        state.energy = state.max_energy
        state.hero_block = 0
        state.attacks_played = 0
        state.current_turn_damage = 0

        # Start-of-turn powers
        if state.demon_form:
            state.hero_strength += 2
        if state.venomous_might and state.total_poison() > 0:
            sg = state.total_poison() // 4
            if sg > 0: state.hero_strength += sg
        if state.metallicize > 0:
            state.hero_block += state.metallicize

        # Poison tick on all monsters
        for m in state.alive_monsters():
            if m["poison"] > 0:
                m["hp"] -= m["poison"]
                m["poison"] = max(0, m["poison"] - 1)
        if state.all_dead():
            if verbose: print(f"  Turn {turn}: All monsters die to poison! Hero HP: {state.hero_hp}")
            return {"turns": turn, "hero_hp": state.hero_hp, "won": True,
                    "total_cards": state.total_cards_played, "max_turn_dmg": state.max_turn_damage}

        # Noxious fumes: apply to all alive monsters
        if state.noxious_fumes > 0:
            for m in state.alive_monsters():
                m["poison"] += state.noxious_fumes

        # Draw 4 cards
        for _ in range(4):
            if not state.draw_pile:
                state.draw_pile = list(state.discard_pile)
                state.discard_pile = []
                random.shuffle(state.draw_pile)
            if state.draw_pile:
                state.hand.append(state.draw_pile.pop())

        # Play cards
        played = greedy_play_turn(state)
        state.max_turn_damage = max(state.max_turn_damage, state.current_turn_damage)

        if verbose:
            names = [CARDS[c]["name"] for c in played]
            m_status = ", ".join(f"M{i+1}:{m['hp']}hp p{m['poison']}" for i, m in enumerate(state.monsters))
            print(f"  Turn {turn}: {names} (dmg:{state.current_turn_damage}) | {m_status}")

        if state.all_dead():
            if verbose: print(f"    WIN! HP:{state.hero_hp} Cards:{state.total_cards_played} MaxDmg:{state.max_turn_damage}")
            return {"turns": turn, "hero_hp": state.hero_hp, "won": True,
                    "total_cards": state.total_cards_played, "max_turn_dmg": state.max_turn_damage}

        # All alive monsters attack
        total_monster_dmg = 0
        for m in state.alive_monsters():
            d = m["base_dmg"] + m["dmg_inc"] * (turn - 1)
            if m["weak"] > 0: d = int(d * 0.75)
            total_monster_dmg += d
        actual = max(0, total_monster_dmg - state.hero_block)
        state.hero_hp -= actual

        if verbose:
            print(f"    Monsters attack total {total_monster_dmg}, block {state.hero_block}, took {actual} → HP:{state.hero_hp}")

        # Status tick
        for m in state.alive_monsters():
            if m["vulnerable"] > 0: m["vulnerable"] -= 1
            if m["weak"] > 0: m["weak"] -= 1

        state.hero_strength -= state.hero_temp_strength
        state.hero_temp_strength = 0
        state.discard_pile.extend(state.hand)
        state.hand = []

        if state.hero_hp <= 0:
            if verbose: print(f"    DEFEAT on turn {turn}")
            return {"turns": turn, "hero_hp": 0, "won": False,
                    "total_cards": state.total_cards_played, "max_turn_dmg": state.max_turn_damage}

    return {"turns": max_turns, "hero_hp": state.hero_hp, "won": state.all_dead(),
            "total_cards": state.total_cards_played, "max_turn_dmg": state.max_turn_damage}


def evaluate_deck(custom_cards: List[str], n_sims=100, **kwargs) -> Dict:
    """Run multiple simulations and return average results."""
    # Build full deck: custom cards + 3 strikes + 3 defends
    # Determine correct strike/defend IDs based on what's available
    strike_id = "ic_strike" if "ic_strike" in CARDS else "strike"
    defend_id = "ic_defend" if "ic_defend" in CARDS else "defend"
    deck = list(custom_cards) + [strike_id]*3 + [defend_id]*3

    results = []
    for _ in range(n_sims):
        r = simulate_battle(deck, **kwargs)
        results.append(r)

    wins = sum(1 for r in results if r["won"])
    avg_hp = sum(r["hero_hp"] for r in results) / len(results)
    avg_turns = sum(r["turns"] for r in results) / len(results)
    avg_cards = sum(r.get("total_cards", 0) for r in results) / len(results)
    avg_max_dmg = sum(r.get("max_turn_dmg", 0) for r in results) / len(results)

    return {
        "deck": deck,
        "custom_cards": custom_cards,
        "win_rate": wins / len(results),
        "avg_remaining_hp": round(avg_hp, 1),
        "avg_turns": round(avg_turns, 1),
        "avg_cards_played": round(avg_cards, 1),
        "avg_max_turn_dmg": round(avg_max_dmg, 1),
        "n_sims": n_sims,
    }


def find_best_combos(pool: List[str], pick: int = 4, n_sims=50, top_n=20, **kwargs) -> List[Dict]:
    """Test all combinations of `pick` cards from pool, rank by avg remaining HP."""
    combos = list(itertools.combinations(pool, pick))
    print(f"Testing {len(combos)} combinations of {pick} cards...")

    results = []
    for i, combo in enumerate(combos):
        r = evaluate_deck(list(combo), n_sims=n_sims, **kwargs)
        r["combo_names"] = [CARDS[c]["name"] for c in combo]
        results.append(r)
        if (i + 1) % 100 == 0:
            print(f"  Progress: {i+1}/{len(combos)}")

    results.sort(key=lambda x: x["avg_remaining_hp"], reverse=True)
    return results[:top_n]


# =============================================================================
# MAIN
# =============================================================================

# Try to load cards from Godot export, fall back to hardcoded
_exported_cards, _exported_zh = load_cards_from_export()
if _exported_cards:
    CARDS = _exported_cards
    ZH_NAMES = _exported_zh
    print(f"[Loaded {len(CARDS)} cards from cards_export.json]", file=sys.stderr)

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Card Game Battle Simulator")
    parser.add_argument("--cards", type=str, help="Comma-separated card IDs to test")
    parser.add_argument("--all-combos", type=int, metavar="N", help="Test all N-card combos from pool")
    parser.add_argument("--pool", type=str, help="Comma-separated card pool for --all-combos")
    parser.add_argument("--sims", type=int, default=1, help="Simulations per combo (default: 1)")
    parser.add_argument("--monster-hp", type=int, default=100, help="Monster HP (default: 100)")
    parser.add_argument("--monster-dmg", type=int, default=8, help="Monster base damage (default: 8)")
    parser.add_argument("--monster-inc", type=int, default=2, help="Monster damage increase/turn (default: 2)")
    parser.add_argument("--hero-hp", type=int, default=200, help="Hero HP (default: 200)")
    parser.add_argument("--monsters", type=int, default=2, help="Number of monsters (default: 2)")
    parser.add_argument("--char", type=str, help="Filter cards by character: ironclad, silent, neutral")
    parser.add_argument("--upgraded", action="store_true", default=True, help="Use upgraded card versions (default: True)")
    parser.add_argument("--no-upgraded", dest="upgraded", action="store_false", help="Use base card versions")
    parser.add_argument("--version", type=str, choices=["all", "new", "old"], default="all",
                        help="Filter by card version: all, new, old")
    parser.add_argument("--verbose", "-v", action="store_true", help="Show turn-by-turn log")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    parser.add_argument("--csv", type=str, metavar="FILE", help="Output results as CSV file")
    args = parser.parse_args()

    sim_kwargs = {
        "hero_hp": args.hero_hp,
        "monster_hp": args.monster_hp,
        "monster_dmg": args.monster_dmg,
        "monster_inc": args.monster_inc,
        "monster_count": args.monsters,
    }

    if args.all_combos:
        # Test all combinations
        if args.pool:
            pool = args.pool.split(",")
        else:
            # Build pool from available cards
            basic_ids = {"strike", "defend", "ic_strike", "ic_defend", "si_strike", "si_defend",
                         "status_wound", "status_burn", "status_dazed"}
            pool = []
            # Load version info from export if available
            version_info = {}
            export_path = Path(__file__).parent / "cards_export.json"
            if export_path.exists():
                with open(export_path, "r", encoding="utf-8") as f:
                    raw = json.load(f)
                for cid, cd in raw.get("cards", {}).items():
                    version_info[cid] = cd.get("version", "old")

            for k, v in CARDS.items():
                if k in basic_ids:
                    continue
                if args.char and v.get("char", "") != args.char:
                    continue
                if args.version != "all":
                    ver = version_info.get(k, "old")
                    if ver != args.version:
                        continue
                pool.append(k)
            filters = []
            if args.char: filters.append(f"char={args.char}")
            if args.version != "all": filters.append(f"version={args.version}")
            print(f"Card pool: {len(pool)} cards" + (f" ({', '.join(filters)})" if filters else ""))

        results = find_best_combos(pool, pick=args.all_combos, n_sims=args.sims, **sim_kwargs)

        if args.csv:
            import csv, os
            file_exists = os.path.exists(args.csv) and os.path.getsize(args.csv) > 0
            with open(args.csv, 'a', newline='', encoding='utf-8-sig') as f:
                writer = csv.writer(f)
                if not file_exists:
                    writer.writerow(["排名", "卡牌ID", "卡牌中文名", "剩余HP", "回合数", "出牌数", "最大单轮伤害", "胜率"])
                for i, r in enumerate(results):
                    ids = ", ".join(r["custom_cards"])
                    zh = ", ".join(ZH_NAMES.get(c, c) for c in r["custom_cards"])
                    writer.writerow([i+1, ids, zh, r["avg_remaining_hp"], r["avg_turns"],
                                    r["avg_cards_played"], r["avg_max_turn_dmg"],
                                    f"{r['win_rate']*100:.1f}%"])
            mode = "appended to" if file_exists else "saved to"
            print(f"Results {mode} {args.csv} ({len(results)} rows)")
        elif args.json:
            print(json.dumps(results, indent=2))
        else:
            print(f"\n{'='*70}")
            print(f"TOP {len(results)} CARD COMBOS ({args.all_combos} picks + 3 Strike + 3 Defend)")
            print(f"vs Monster: {args.monster_hp}HP, {args.monster_dmg}+{args.monster_inc}/turn dmg")
            print(f"{'='*70}")
            for i, r in enumerate(results):
                en_names = ", ".join(r["combo_names"])
                zh_names = ", ".join(ZH_NAMES.get(c, c) for c in r["custom_cards"])
                print(f"{i+1:3d}. HP:{r['avg_remaining_hp']:5.1f}  Turns:{r['avg_turns']:4.1f}  Cards:{r['avg_cards_played']:4.1f}  MaxDmg:{r['avg_max_turn_dmg']:5.1f}  | {en_names}  | {zh_names}")

    elif args.cards:
        # Test specific cards
        cards = args.cards.split(",")
        for c in cards:
            if c not in CARDS:
                print(f"Unknown card: {c}")
                print(f"Available: {', '.join(sorted(CARDS.keys()))}")
                sys.exit(1)

        if args.verbose:
            print(f"Simulating: {[CARDS[c]['name'] for c in cards]} + 3 Strike + 3 Defend")
            print(f"vs Monster: {args.monster_hp}HP, {args.monster_dmg}+{args.monster_inc}/turn")
            print()
            r = simulate_battle(cards + ["strike", "strike", "defend", "defend"],
                              verbose=True, **sim_kwargs)
            print(f"\nResult: {'WIN' if r['won'] else 'LOSS'} in {r['turns']} turns, Hero HP: {r['hero_hp']}")
        else:
            r = evaluate_deck(cards, n_sims=args.sims, **sim_kwargs)
            if args.json:
                print(json.dumps(r, indent=2))
            else:
                names = [CARDS[c]["name"] for c in cards]
                print(f"Deck: {names} + 3 Strike + 3 Defend")
                print(f"Win rate: {r['win_rate']*100:.1f}%")
                print(f"Avg remaining HP: {r['avg_remaining_hp']:.1f}")
                print(f"Avg turns: {r['avg_turns']:.1f}")
                print(f"({r['n_sims']} simulations)")

    else:
        # Default demo
        print("=== Card Game Battle Simulator ===\n")
        test_decks = [
            ["bash", "inflame", "heavy_blade", "shrug_it_off"],
            ["bash", "demon_form", "heavy_blade", "impervious"],
            ["poisoned_stab", "deadly_poison", "catalyst", "noxious_fumes"],
            ["poisoned_stab", "noxious_fumes", "venomous_might", "heavy_blade"],
            ["bash", "offering", "bludgeon", "flex"],
        ]

        print(f"Hero: {args.hero_hp}HP | Monster: {args.monster_hp}HP, {args.monster_dmg}+{args.monster_inc}/turn")
        print(f"Each deck: 4 custom + 3 Strike + 3 Defend | {args.sims} sims each\n")

        for deck in test_decks:
            r = evaluate_deck(deck, n_sims=args.sims, **sim_kwargs)
            en_names = [CARDS[c]["name"] for c in deck]
            zh_names = [ZH_NAMES.get(c, c) for c in deck]
            print(f"  {', '.join(en_names):50s} → HP:{r['avg_remaining_hp']:5.1f}  Turns:{r['avg_turns']:.1f}  Cards:{r['avg_cards_played']:.1f}  MaxDmg:{r['avg_max_turn_dmg']:.1f}  | {', '.join(zh_names)}")
