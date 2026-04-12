#!/usr/bin/env python3
"""Batch generate card art for all Blood Fiend cards using Gemini API."""

import json, urllib.request, base64, os, time, sys

# Load Gemini config
with open(os.path.expanduser('~/.genimg/config.json')) as f:
    config = json.load(f)
gemini = config['providers']['gemini']
API_KEY = gemini['api_key']
MODEL = gemini.get('model', 'gemini-2.0-flash-exp')

OUTPUT_DIR = "assets/img/card_art"
HERO_DIR = "assets/img"
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(HERO_DIR, exist_ok=True)

# Base style for all cards
BASE_STYLE = "dark fantasy card game art, Slay the Spire style, simple bold composition, dark moody background with blood red accents, no text, no labels, no words, square format"
BLOODFIEND = "a demonic blood berserker with dark spiked armor, glowing crimson eyes, and clawed gauntlets dripping blood"

# Card prompts: card_id -> description
CARDS = {
    # ATTACKS
    "bf_strike": f"{BLOODFIEND} slashing with blood-stained claws, {BASE_STYLE}",
    "bf_crimson_slash": f"{BLOODFIEND} cutting own palm, blood energy flowing into weapon strike, {BASE_STYLE}",
    "bf_frenzy_claw": f"{BLOODFIEND} rapid triple claw attack, slash marks in the air, {BASE_STYLE}",
    "bf_gore": f"{BLOODFIEND} brutal impaling charge with horns and spikes, {BASE_STYLE}",
    "bf_execution": f"{BLOODFIEND} standing over prey, doubling blood curse, {BASE_STYLE}",
    "bf_blood_whirl": f"{BLOODFIEND} spinning in blood tornado hitting all around, {BASE_STYLE}",
    "bf_savage_strike": f"{BLOODFIEND} berserker rage, wounds on body fueling attack, {BASE_STYLE}",
    "bf_prey_on_weakness": f"{BLOODFIEND} pouncing on wounded enemy, {BASE_STYLE}",
    "bf_exploit": f"{BLOODFIEND} quick precise strike at a vulnerability, {BASE_STYLE}",
    "bf_crushing_blow": f"{BLOODFIEND} massive overhead slam shattering the ground, {BASE_STYLE}",
    "bf_flesh_rend": f"{BLOODFIEND} tearing apart a card into shards, energy released, {BASE_STYLE}",
    "bf_soul_harvest": f"{BLOODFIEND} dark ritual, consuming souls from multiple victims, {BASE_STYLE}",
    "bf_relentless": f"{BLOODFIEND} relentless assault, multiple afterimages attacking, {BASE_STYLE}",
    "bf_vampiric_embrace": f"{BLOODFIEND} draining life from multiple enemies, blood streams flowing back, {BASE_STYLE}",
    "bf_leech": f"{BLOODFIEND} biting and draining single enemy, healing glow, {BASE_STYLE}",
    "bf_blood_feast": f"{BLOODFIEND} devouring defeated foe, growing stronger, {BASE_STYLE}",

    # SKILLS
    "bf_defend": f"{BLOODFIEND} defensive blood barrier stance, {BASE_STYLE}",
    "bf_sanguine_shield": f"{BLOODFIEND} blood crystallizing into a shield, HP draining, {BASE_STYLE}",
    "bf_blood_offering": f"{BLOODFIEND} ritual sacrifice, cutting own veins for power, {BASE_STYLE}",
    "bf_predator_instinct": f"{BLOODFIEND} eyes glowing, predatory awareness aura, {BASE_STYLE}",
    "bf_bloodbath": f"{BLOODFIEND} bathing in pool of blood, curse radiating out, {BASE_STYLE}",
    "bf_blood_pact": f"{BLOODFIEND} burning a card in blood fire, drawing new cards, {BASE_STYLE}",
    "bf_sacrifice": f"{BLOODFIEND} offering own blood to dark altar, {BASE_STYLE}",
    "bf_bloodrage": f"{BLOODFIEND} screaming berserker entering blood rage state, {BASE_STYLE}",
    "bf_vital_guard": f"{BLOODFIEND} desperate defensive crouch, blood barrier at low health, {BASE_STYLE}",
    "bf_blood_shell": f"{BLOODFIEND} encased in hardened blood armor, thorns growing, {BASE_STYLE}",
    "bf_blood_rush": f"{BLOODFIEND} marking an enemy weapon with blood rune, {BASE_STYLE}",
    "bf_bloodhound": f"{BLOODFIEND} sniffing blood trail, hunting prey, {BASE_STYLE}",
    "bf_berserker_resolve": f"{BLOODFIEND} gritting teeth behind blood-splattered shield, {BASE_STYLE}",
    "bf_survival_instinct": f"{BLOODFIEND} cornered beast, desperate defensive stance, {BASE_STYLE}",

    # POWERS
    "bf_blood_frenzy": f"{BLOODFIEND} permanent transformation, blood power surging every turn, {BASE_STYLE}",
    "bf_bloodlust": f"{BLOODFIEND} eyes blazing, getting stronger from every wound, {BASE_STYLE}",
    "bf_sanguine_aura": f"{BLOODFIEND} dark red aura emanating, infecting enemies on contact, {BASE_STYLE}",
    "bf_crimson_pact": f"{BLOODFIEND} dark contract symbol, flames on exhaust, {BASE_STYLE}",
    "bf_predators_mark": f"{BLOODFIEND} wolf-eye mark glowing on forehead, {BASE_STYLE}",
    "bf_blood_scent": f"{BLOODFIEND} nose bleeding, sensing weakness, {BASE_STYLE}",
    "bf_undying_rage": f"{BLOODFIEND} muscles bulging with fury on exhaust, {BASE_STYLE}",
    "bf_pain_threshold": f"{BLOODFIEND} meditating in pain, converting suffering to power, {BASE_STYLE}",
    "bf_blood_bond": f"{BLOODFIEND} blood chains connecting to life force, {BASE_STYLE}",
    "bf_hemostasis": f"{BLOODFIEND} wounds sealing with crystallized blood armor, {BASE_STYLE}",
    "bf_undying_will": f"{BLOODFIEND} glowing defiantly at death's door, refusing to die, {BASE_STYLE}",
}

# Hero sprites
HERO_SPRITES = {
    "bloodfiend": f"full character portrait of {BLOODFIEND} standing in battle pose, dark spiked armor with crimson accents, glowing red eyes, full body visible, dark fantasy art style, Slay the Spire style, dark background, no text, no labels, portrait orientation, tall format",
    "bloodfiend_fallen": f"full character portrait of {BLOODFIEND} fallen and defeated, slumped on ground, armor cracked and broken, dark fantasy art style, Slay the Spire style, dark background, no text, no labels, portrait orientation, tall format",
}


def generate_one(card_id, prompt, output_path, retries=2):
    if os.path.exists(output_path) and os.path.getsize(output_path) > 10000:
        print(f"  SKIP {card_id} (exists)")
        return True

    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={API_KEY}"
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]}
    }

    for attempt in range(retries + 1):
        try:
            req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                        headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=90) as resp:
                data = json.load(resp)

            for candidate in data.get("candidates", []):
                for part in candidate.get("content", {}).get("parts", []):
                    if "inlineData" in part:
                        img_data = base64.b64decode(part["inlineData"]["data"])
                        with open(output_path, "wb") as f:
                            f.write(img_data)
                        print(f"  OK {card_id} ({len(img_data)//1024}KB)", flush=True)
                        return True
            print(f"  WARN {card_id}: no image in response", flush=True)
            return False
        except Exception as e:
            if attempt < retries:
                wait = 2 * (attempt + 1)
                print(f"  RETRY {card_id}: {e} (waiting {wait}s)", flush=True)
                time.sleep(wait)
            else:
                print(f"  FAIL {card_id}: {e}", flush=True)
                return False


if __name__ == "__main__":
    # Allow specifying a subset via command line
    if len(sys.argv) > 1:
        subset = sys.argv[1:]
        cards_to_gen = {k: v for k, v in CARDS.items() if k in subset}
    else:
        cards_to_gen = CARDS

    total = len(cards_to_gen) + len(HERO_SPRITES)
    done = 0
    failed = []

    print(f"Generating {total} Blood Fiend images ({len(cards_to_gen)} cards + {len(HERO_SPRITES)} hero sprites)...")

    # Generate card art
    for card_id, prompt in cards_to_gen.items():
        output_path = os.path.join(OUTPUT_DIR, f"{card_id}.png")
        success = generate_one(card_id, prompt, output_path)
        if not success:
            failed.append(card_id)
        done += 1
        if done % 10 == 0:
            print(f"Progress: {done}/{total}", flush=True)
        # Rate limit: ~2 requests per second for Gemini
        time.sleep(1.5)

    # Generate hero sprites
    for sprite_id, prompt in HERO_SPRITES.items():
        output_path = os.path.join(HERO_DIR, f"{sprite_id}.png")
        success = generate_one(sprite_id, prompt, output_path)
        if not success:
            failed.append(sprite_id)
        done += 1
        time.sleep(1.5)

    print(f"\nDone! {done - len(failed)}/{total} succeeded, {len(failed)} failed")
    if failed:
        print(f"Failed: {', '.join(failed)}")
