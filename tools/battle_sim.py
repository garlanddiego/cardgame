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
import sys
from copy import deepcopy
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Tuple

# =============================================================================
# CARD DEFINITIONS
# =============================================================================

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
# BATTLE STATE
# =============================================================================

@dataclass
class BattleState:
    hero_hp: int = 100
    hero_max_hp: int = 100
    hero_block: int = 0
    hero_strength: int = 0
    hero_temp_strength: int = 0  # Flex-style, removed at end of turn
    energy: int = 3
    max_energy: int = 3

    monster_hp: int = 100
    monster_base_damage: int = 10
    monster_damage_inc: int = 2
    monster_block: int = 0
    monster_vulnerable: int = 0
    monster_weak: int = 0
    monster_poison: int = 0

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
    blood_fury_active: bool = False  # Next attack doubles
    psi_surge: bool = False

    total_cards_played: int = 0
    max_turn_damage: int = 0
    current_turn_damage: int = 0
    log: list = field(default_factory=list)


def calc_damage(state: BattleState, base: int, str_mult: int = 1, times: int = 1) -> int:
    """Calculate total damage for an attack."""
    str_bonus = state.hero_strength * str_mult
    per_hit = max(0, base + str_bonus)
    if state.monster_weak > 0:  # Hero is weak (not implemented here)
        pass
    if state.monster_vulnerable > 0:
        per_hit = int(per_hit * 1.5)
    if state.blood_fury_active:
        per_hit *= 2
        state.blood_fury_active = False
    return per_hit * times


def apply_card(state: BattleState, card_id: str) -> None:
    """Apply a card's effects to the battle state."""
    card = CARDS[card_id]
    for effect in card["effects"]:
        etype = effect["type"]

        if etype == "damage":
            times = effect.get("times", 1)
            str_mult = effect.get("str_mult", 1)
            dmg = calc_damage(state, effect["value"], str_mult, times)
            state.monster_hp -= dmg
            state.current_turn_damage += dmg
            state.attacks_played += 1
            if state.envenom and times >= 1:
                state.monster_poison += times

        elif etype == "block":
            state.hero_block += effect["value"]

        elif etype == "apply_vulnerable":
            state.monster_vulnerable += effect["value"]

        elif etype == "apply_weak":
            state.monster_weak += effect["value"]

        elif etype == "apply_poison":
            state.monster_poison += effect["value"]

        elif etype == "double_poison":
            state.monster_poison *= 2

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
            draw_count = effect["value"]
            for _ in range(draw_count):
                if not state.draw_pile:
                    state.draw_pile = list(state.discard_pile)
                    state.discard_pile = []
                    import random
                    random.shuffle(state.draw_pile)
                if state.draw_pile:
                    state.hand.append(state.draw_pile.pop())

        elif etype == "power":
            power = effect["power"]
            if power == "demon_form":
                state.demon_form = True
            elif power == "metallicize":
                state.metallicize = 3
            elif power == "noxious_fumes":
                state.noxious_fumes = effect.get("value", 2)
            elif power == "envenom":
                state.envenom = True
            elif power == "accuracy":
                state.accuracy += effect.get("value", 4)
            elif power == "venomous_might":
                state.venomous_might = True
            elif power == "blood_fury":
                state.blood_fury = True
            elif power == "psi_surge":
                state.psi_surge = True

        elif etype == "x_damage_poison":
            # X cost: use all remaining energy
            x = state.energy
            base = effect["value"]
            for _ in range(x):
                dmg = calc_damage(state, base)
                state.monster_hp -= dmg
                state.monster_poison += 1
            state.energy = 0

        elif etype == "poison_to_block":
            state.hero_block += state.monster_poison

        elif etype == "hand_size_damage":
            dmg = len(state.hand) * effect["mult"]
            dmg += state.hero_strength
            if state.monster_vulnerable > 0:
                dmg = int(dmg * 1.5)
            state.monster_hp -= dmg

        elif etype == "all_in_draw":
            e = state.energy
            state.energy = 0
            for _ in range(e * 2):
                if not state.draw_pile:
                    state.draw_pile = list(state.discard_pile)
                    state.discard_pile = []
                    import random
                    random.shuffle(state.draw_pile)
                if state.draw_pile:
                    state.hand.append(state.draw_pile.pop())

    # Move to discard/exhaust
    if card.get("exhaust"):
        state.exhaust_pile.append(card_id)
    elif card["type"] != "power":
        state.discard_pile.append(card_id)


# =============================================================================
# GREEDY AI — picks best card each step
# =============================================================================

def score_card(state: BattleState, card_id: str) -> float:
    """Heuristic score for playing a card. Higher = better."""
    card = CARDS[card_id]
    cost = card["cost"]
    if cost == -1:
        cost = state.energy
    if cost > state.energy:
        return -999

    s = deepcopy(state)
    s.energy -= cost
    old_monster_hp = s.monster_hp
    old_hero_block = s.hero_block
    old_strength = s.hero_strength
    old_poison = s.monster_poison

    apply_card(s, card_id)

    damage_dealt = old_monster_hp - s.monster_hp
    block_gained = s.hero_block - old_hero_block
    strength_gained = s.hero_strength - old_strength
    poison_gained = s.monster_poison - old_poison
    hp_lost = state.hero_hp - s.hero_hp  # Self-damage

    # Monster damage this turn (for block value estimation)
    monster_dmg = state.monster_base_damage + state.monster_damage_inc * state.turn
    if state.monster_weak > 0:
        monster_dmg = int(monster_dmg * 0.75)

    # Score components
    score = 0.0
    score += damage_dealt * 1.0  # Direct damage is good
    score += min(block_gained, max(0, monster_dmg - state.hero_block)) * 0.8  # Block up to incoming damage
    score += strength_gained * 8.0  # Strength is very valuable long-term
    score += poison_gained * 2.0  # Poison has compounding value
    score -= hp_lost * 0.5  # Self-damage is a cost

    # Powers have long-term value
    if card["type"] == "power":
        for eff in card["effects"]:
            if eff["type"] == "power":
                if eff["power"] == "demon_form":
                    score += 30  # Huge long-term value
                elif eff["power"] == "noxious_fumes":
                    score += 15
                elif eff["power"] == "metallicize":
                    score += 10
                elif eff["power"] == "envenom":
                    score += 12
                elif eff["power"] == "venomous_might":
                    score += max(5, state.monster_poison * 2)
                elif eff["power"] == "blood_fury":
                    score += 10

    # Energy efficiency
    if cost > 0:
        score = score / cost  # Normalize by cost

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

def simulate_battle(deck: List[str], hero_hp=100, monster_hp=100,
                    monster_dmg=10, monster_inc=2, max_turns=20,
                    verbose=False) -> Dict:
    """Simulate a full battle and return results."""
    import random
    state = BattleState(
        hero_hp=hero_hp, hero_max_hp=hero_hp,
        monster_hp=monster_hp, monster_base_damage=monster_dmg,
        monster_damage_inc=monster_inc,
    )

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
        if state.venomous_might and state.monster_poison > 0:
            str_gain = state.monster_poison // 4
            if str_gain > 0:
                state.hero_strength += str_gain
        if state.metallicize > 0:
            state.hero_block += state.metallicize

        # Poison tick
        if state.monster_poison > 0:
            state.monster_hp -= state.monster_poison
            state.monster_poison -= 1
            if state.monster_hp <= 0:
                if verbose:
                    print(f"  Turn {turn}: Monster dies to poison! Hero HP: {state.hero_hp}")
                return {"turns": turn, "hero_hp": state.hero_hp, "won": True,
                        "total_cards": state.total_cards_played, "max_turn_dmg": state.max_turn_damage}

        # Noxious fumes
        if state.noxious_fumes > 0:
            state.monster_poison += state.noxious_fumes

        # Draw 4 cards per turn
        for _ in range(4):
            if not state.draw_pile:
                state.draw_pile = list(state.discard_pile)
                state.discard_pile = []
                random.shuffle(state.draw_pile)
            if state.draw_pile:
                state.hand.append(state.draw_pile.pop())

        # Play cards (greedy AI)
        played = greedy_play_turn(state)
        state.max_turn_damage = max(state.max_turn_damage, state.current_turn_damage)

        if verbose:
            card_names = [CARDS[c]["name"] for c in played]
            print(f"  Turn {turn}: Played {card_names} (dmg this turn: {state.current_turn_damage})")
            print(f"    Monster HP: {state.monster_hp}, Poison: {state.monster_poison}")

        # Check win
        if state.monster_hp <= 0:
            if verbose:
                print(f"    WIN! Hero HP: {state.hero_hp}, Cards played: {state.total_cards_played}, Max turn dmg: {state.max_turn_damage}")
            return {"turns": turn, "hero_hp": state.hero_hp, "won": True,
                    "total_cards": state.total_cards_played, "max_turn_dmg": state.max_turn_damage}

        # Monster attacks
        monster_dmg_val = state.monster_base_damage + state.monster_damage_inc * (turn - 1)
        if state.monster_weak > 0:
            monster_dmg_val = int(monster_dmg_val * 0.75)
        actual_dmg = max(0, monster_dmg_val - state.hero_block)
        state.hero_hp -= actual_dmg

        if verbose:
            print(f"    Monster attacks for {monster_dmg_val}, blocked {min(state.hero_block, monster_dmg_val)}, took {actual_dmg}")
            print(f"    Hero HP: {state.hero_hp}")

        # Status tick
        if state.monster_vulnerable > 0:
            state.monster_vulnerable -= 1
        if state.monster_weak > 0:
            state.monster_weak -= 1

        # Remove temp strength
        state.hero_strength -= state.hero_temp_strength
        state.hero_temp_strength = 0

        # Discard remaining hand
        state.discard_pile.extend(state.hand)
        state.hand = []

        if state.hero_hp <= 0:
            if verbose:
                print(f"    DEFEAT! Died on turn {turn}")
            return {"turns": turn, "hero_hp": 0, "won": False,
                    "total_cards": state.total_cards_played, "max_turn_dmg": state.max_turn_damage}

    return {"turns": max_turns, "hero_hp": state.hero_hp, "won": state.monster_hp <= 0,
            "total_cards": state.total_cards_played, "max_turn_dmg": state.max_turn_damage}


def evaluate_deck(custom_cards: List[str], n_sims=100, **kwargs) -> Dict:
    """Run multiple simulations and return average results."""
    # Build full deck: custom cards + 3 strikes + 3 defends
    deck = list(custom_cards) + ["strike", "strike", "strike", "defend", "defend", "defend"]

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

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Card Game Battle Simulator")
    parser.add_argument("--cards", type=str, help="Comma-separated card IDs to test")
    parser.add_argument("--all-combos", type=int, metavar="N", help="Test all N-card combos from pool")
    parser.add_argument("--pool", type=str, help="Comma-separated card pool for --all-combos")
    parser.add_argument("--sims", type=int, default=100, help="Simulations per combo (default: 100)")
    parser.add_argument("--monster-hp", type=int, default=100, help="Monster HP (default: 100)")
    parser.add_argument("--monster-dmg", type=int, default=10, help="Monster base damage (default: 10)")
    parser.add_argument("--monster-inc", type=int, default=2, help="Monster damage increase/turn (default: 2)")
    parser.add_argument("--hero-hp", type=int, default=100, help="Hero HP (default: 100)")
    parser.add_argument("--verbose", "-v", action="store_true", help="Show turn-by-turn log")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    args = parser.parse_args()

    sim_kwargs = {
        "hero_hp": args.hero_hp,
        "monster_hp": args.monster_hp,
        "monster_dmg": args.monster_dmg,
        "monster_inc": args.monster_inc,
    }

    if args.all_combos:
        # Test all combinations
        if args.pool:
            pool = args.pool.split(",")
        else:
            # Default pool: all non-basic cards
            pool = [k for k in CARDS if k not in ("strike", "defend", "si_strike", "si_defend")]

        results = find_best_combos(pool, pick=args.all_combos, n_sims=args.sims, **sim_kwargs)

        if args.json:
            print(json.dumps(results, indent=2))
        else:
            print(f"\n{'='*70}")
            print(f"TOP {len(results)} CARD COMBOS ({args.all_combos} picks + 3 Strike + 3 Defend)")
            print(f"vs Monster: {args.monster_hp}HP, {args.monster_dmg}+{args.monster_inc}/turn dmg")
            print(f"{'='*70}")
            for i, r in enumerate(results):
                names = ", ".join(r["combo_names"])
                print(f"{i+1:3d}. HP:{r['avg_remaining_hp']:5.1f}  Turns:{r['avg_turns']:4.1f}  Cards:{r['avg_cards_played']:4.1f}  MaxDmg:{r['avg_max_turn_dmg']:5.1f}  | {names}")

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
            names = [CARDS[c]["name"] for c in deck]
            print(f"  {', '.join(names):50s} → HP:{r['avg_remaining_hp']:5.1f}  Turns:{r['avg_turns']:.1f}  Cards:{r['avg_cards_played']:.1f}  MaxDmg:{r['avg_max_turn_dmg']:.1f}")
