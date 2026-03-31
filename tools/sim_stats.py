#!/usr/bin/env python3
"""
Card Statistics from Simulation Results
Analyzes CSV output from sim_runner.gd to rank individual card strength.

Usage:
  python3 tools/sim_stats.py sim_silent_4combo.csv
  python3 tools/sim_stats.py sim_silent_4combo.csv --csv card_stats.csv
"""

import csv
import sys
from collections import defaultdict
from pathlib import Path


def analyze(csv_path: str, output_csv: str = None):
    """Analyze simulation CSV and produce per-card statistics."""
    # Per-card aggregation
    card_stats = defaultdict(lambda: {
        "appearances": 0,
        "total_hp": 0,
        "total_turns": 0,
        "total_cards_played": 0,
        "total_max_dmg": 0,
        "wins": 0,
        "name": "",
    })

    total_rows = 0
    with open(csv_path, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            total_rows += 1
            # Parse combo IDs (semicolon-separated)
            ids_str = row.get("卡牌ID", row.get("card_ids", ""))
            names_str = row.get("卡牌名称", row.get("card_names", ""))
            card_ids = [x.strip() for x in ids_str.split(";") if x.strip()]
            card_names = [x.strip() for x in names_str.split(";") if x.strip()]

            hero_hp = int(row.get("剩余HP", row.get("hero_hp", 0)))
            turns = int(row.get("回合数", row.get("turns", 0)))
            cards_played = int(row.get("出牌数", row.get("total_cards", 0)))
            max_dmg = int(row.get("最大单轮伤害", row.get("max_turn_dmg", 0)))
            won = row.get("胜负", row.get("won", "")) in ("胜", "WIN", "True", "true", "1")

            for i, card_id in enumerate(card_ids):
                s = card_stats[card_id]
                s["appearances"] += 1
                s["total_hp"] += hero_hp
                s["total_turns"] += turns
                s["total_cards_played"] += cards_played
                s["total_max_dmg"] += max_dmg
                if won:
                    s["wins"] += 1
                if i < len(card_names):
                    s["name"] = card_names[i]

    # Calculate averages and sort
    results = []
    for card_id, s in card_stats.items():
        n = s["appearances"]
        if n == 0:
            continue
        results.append({
            "card_id": card_id,
            "name": s["name"],
            "appearances": n,
            "avg_hp": round(s["total_hp"] / n, 1),
            "avg_turns": round(s["total_turns"] / n, 1),
            "avg_cards": round(s["total_cards_played"] / n, 1),
            "avg_max_dmg": round(s["total_max_dmg"] / n, 1),
            "win_rate": round(s["wins"] / n * 100, 1),
        })

    results.sort(key=lambda x: x["avg_hp"], reverse=True)

    # Print table
    print(f"\n{'='*90}")
    print(f"Card Statistics from {total_rows} simulations")
    print(f"{'='*90}")
    print(f"{'排名':>4} {'卡牌ID':<25} {'卡牌名称':<18} {'出现':>6} {'平均HP':>7} {'平均回合':>8} {'平均出牌':>8} {'平均伤害':>8} {'胜率':>6}")
    print(f"{'-'*90}")
    for i, r in enumerate(results):
        print(f"{i+1:4d} {r['card_id']:<25} {r['name']:<18} {r['appearances']:6d} {r['avg_hp']:7.1f} {r['avg_turns']:8.1f} {r['avg_cards']:8.1f} {r['avg_max_dmg']:8.1f} {r['win_rate']:5.1f}%")

    # Output CSV if requested
    if output_csv:
        with open(output_csv, "w", newline="", encoding="utf-8-sig") as f:
            writer = csv.writer(f)
            writer.writerow(["排名", "卡牌ID", "卡牌名称", "出现次数", "平均剩余HP", "平均回合数", "平均出牌数", "平均最大伤害", "胜率%"])
            for i, r in enumerate(results):
                writer.writerow([i+1, r["card_id"], r["name"], r["appearances"],
                                r["avg_hp"], r["avg_turns"], r["avg_cards"],
                                r["avg_max_dmg"], r["win_rate"]])
        print(f"\nSaved to {output_csv}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 tools/sim_stats.py <simulation_results.csv> [--csv output.csv]")
        sys.exit(1)

    csv_file = sys.argv[1]
    output = None
    if "--csv" in sys.argv:
        idx = sys.argv.index("--csv")
        if idx + 1 < len(sys.argv):
            output = sys.argv[idx + 1]

    analyze(csv_file, output)
