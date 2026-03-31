#!/usr/bin/env python3
"""Parse GDScript card pack files and export card database as JSON.
This avoids needing to run Godot to generate the export."""

import json
import re
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
CARD_PACKS = [
    PROJECT_ROOT / "scripts/cards/ironclad_cards.gd",
    PROJECT_ROOT / "scripts/cards/silent_cards.gd",
    PROJECT_ROOT / "scripts/cards/neutral_cards.gd",
    PROJECT_ROOT / "scripts/cards/new_cards.gd",
]
OUTPUT = PROJECT_ROOT / "tools/cards_export.json"


def parse_gdscript_dict(text):
    """Convert GDScript dictionary literal to Python dict (best effort)."""
    # Replace GDScript-specific syntax
    text = text.strip()
    # Replace CardType.ATTACK etc with integers
    text = re.sub(r'CardType\.ATTACK', '0', text)
    text = re.sub(r'CardType\.SKILL', '1', text)
    text = re.sub(r'CardType\.POWER', '2', text)
    text = re.sub(r'CardType\.STATUS', '3', text)
    # Replace true/false
    text = text.replace('true', 'True').replace('false', 'False')
    # Remove trailing commas before closing braces/brackets
    text = re.sub(r',\s*}', '}', text)
    text = re.sub(r',\s*]', ']', text)
    try:
        return eval(text)
    except Exception as e:
        print(f"  Parse error: {e}", file=sys.stderr)
        return None


def extract_balanced_braces(text, start):
    """Extract text from start position until balanced braces."""
    depth = 0
    i = start
    while i < len(text):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                return text[start:i+1]
        i += 1
    return None

def extract_cards(filepath):
    """Extract card definitions from a GDScript card pack file."""
    cards = {}
    content = filepath.read_text(encoding='utf-8')

    # Find all db["xxx"] = { patterns and extract balanced braces
    for match in re.finditer(r'db\["([^"]+)"\]\s*=\s*', content):
        card_id = match.group(1)
        brace_start = content.index('{', match.end() - 1)
        dict_text = extract_balanced_braces(content, brace_start)
        if dict_text:
            card_data = parse_gdscript_dict(dict_text)
            if card_data:
                cards[card_id] = card_data

    return cards


def extract_upgrades(filepath):
    """Extract upgrade overrides from a card pack file."""
    upgrades = {}
    content = filepath.read_text(encoding='utf-8')

    # Find the get_upgrade_overrides function and its return dict
    match = re.search(r'func get_upgrade_overrides.*?return\s*\{(.*?)\n\t\}', content, re.DOTALL)
    if not match:
        return {}

    block = match.group(1)
    # Match: "card_id": {...}
    pattern = r'"([^"]+)":\s*(\{[^}]+(?:\{[^}]*\}[^}]*)*\})'
    for m in re.finditer(pattern, block):
        card_id = m.group(1)
        dict_text = m.group(2)
        data = parse_gdscript_dict(dict_text)
        if data:
            upgrades[card_id] = data

    return upgrades


def main():
    all_cards = {}
    all_upgrades = {}

    for pack_path in CARD_PACKS:
        if not pack_path.exists():
            print(f"Skipping {pack_path} (not found)", file=sys.stderr)
            continue
        cards = extract_cards(pack_path)
        upgrades = extract_upgrades(pack_path)
        all_cards.update(cards)
        all_upgrades.update(upgrades)
        print(f"  {pack_path.name}: {len(cards)} cards, {len(upgrades)} upgrades", file=sys.stderr)

    # Set defaults
    for card_id, card in all_cards.items():
        if "version" not in card:
            card["version"] = "old"
        if "status" not in card:
            card["status"] = "active"

    export = {"cards": all_cards, "upgrades": all_upgrades}

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT, 'w', encoding='utf-8') as f:
        json.dump(export, f, indent='\t', ensure_ascii=False)

    print(f"\nExported {len(all_cards)} cards + {len(all_upgrades)} upgrades to {OUTPUT}", file=sys.stderr)


if __name__ == "__main__":
    main()
