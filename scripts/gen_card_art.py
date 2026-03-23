#!/usr/bin/env python3
"""Batch generate card art for all Ironclad cards using Gemini API."""

import json, urllib.request, base64, os, time, sys

# Load Gemini config
with open(os.path.expanduser('~/.genimg/config.json')) as f:
    config = json.load(f)
gemini = config['providers']['gemini']
API_KEY = gemini['api_key']
MODEL = gemini.get('model', 'gemini-2.0-flash-exp')

OUTPUT_DIR = "assets/img/card_art"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Base style for all cards
BASE_STYLE = "dark fantasy card game art, Slay the Spire style, simple bold composition, dark moody background, no text, no labels, no words, square format"
IRONCLAD = "an armored warrior with red tabard and horned helmet"

# Card prompts: card_id -> description
CARDS = {
    # ATTACKS
    "ic_strike": f"{IRONCLAD} slashing with a sword, {BASE_STYLE}",
    "ic_bash": f"{IRONCLAD} smashing down with an armored fist, {BASE_STYLE}",
    "ic_anger": f"{IRONCLAD} consumed by rage with glowing red eyes, {BASE_STYLE}",
    "ic_twin_strike": f"{IRONCLAD} striking twice with dual blades, {BASE_STYLE}",
    "ic_pommel_strike": f"{IRONCLAD} striking with sword pommel, {BASE_STYLE}",
    "ic_headbutt": f"{IRONCLAD} headbutting with horned helmet, {BASE_STYLE}",
    "ic_clothesline": f"{IRONCLAD} clothesline arm attack, {BASE_STYLE}",
    "ic_carnage": f"{IRONCLAD} devastating axe swing, {BASE_STYLE}",
    "ic_bludgeon": f"{IRONCLAD} crushing with a massive mace, {BASE_STYLE}",
    "ic_cleave": f"{IRONCLAD} wide sword sweep hitting multiple targets, {BASE_STYLE}",
    "ic_rampage": f"{IRONCLAD} charging in berserker rampage, {BASE_STYLE}",
    "ic_heavy_blade": f"{IRONCLAD} raising enormous greatsword overhead, {BASE_STYLE}",
    "ic_perfected_strike": f"{IRONCLAD} executing a perfect sword technique, {BASE_STYLE}",
    "ic_hemokinesis": f"{IRONCLAD} channeling blood magic into weapon, {BASE_STYLE}",
    "ic_sever_soul": f"{IRONCLAD} cutting through ghostly spirit, {BASE_STYLE}",
    "ic_whirlwind": f"{IRONCLAD} spinning with sword in whirlwind, {BASE_STYLE}",
    "ic_fiend_fire": f"{IRONCLAD} unleashing demonic flames from hands, {BASE_STYLE}",
    "ic_reaper": f"{IRONCLAD} wielding death scythe in shadows, {BASE_STYLE}",
    "ic_immolate": f"{IRONCLAD} surrounded by massive fire explosion, {BASE_STYLE}",
    "ic_body_slam": f"{IRONCLAD} body slamming with full armor weight, {BASE_STYLE}",
    "ic_iron_wave": f"{IRONCLAD} releasing wave of iron and steel, {BASE_STYLE}",
    "ic_clash": f"{IRONCLAD} charging into direct combat clash, {BASE_STYLE}",
    "ic_pummel": f"{IRONCLAD} rapid fist barrage, {BASE_STYLE}",
    "ic_dropkick": f"{IRONCLAD} flying dropkick with armored boots, {BASE_STYLE}",
    "ic_uppercut": f"{IRONCLAD} devastating uppercut, {BASE_STYLE}",
    "ic_thunderclap": f"{IRONCLAD} clapping hands creating thunder, {BASE_STYLE}",
    "ic_searing_blow": f"{IRONCLAD} striking with red-hot glowing fist, {BASE_STYLE}",
    "ic_feed": f"{IRONCLAD} devouring enemy life energy, {BASE_STYLE}",
    "ic_reckless_charge": f"{IRONCLAD} reckless forward charge, {BASE_STYLE}",
    "ic_wild_strike": f"{IRONCLAD} wild untamed sword swing, {BASE_STYLE}",
    "ic_sword_boomerang": f"A spinning sword flying through air like boomerang, {BASE_STYLE}",
    "ic_blood_for_blood": f"{IRONCLAD} wounded and bleeding onto blade, {BASE_STYLE}",

    # SKILLS
    "ic_defend": f"{IRONCLAD} raising shield to block attack, {BASE_STYLE}",
    "ic_shrug_it_off": f"{IRONCLAD} shrugging off damage indifferently, {BASE_STYLE}",
    "ic_flame_barrier": f"{IRONCLAD} surrounded by protective fire wall, {BASE_STYLE}",
    "ic_ghostly_armor": f"Ghostly translucent armor materializing around {IRONCLAD}, {BASE_STYLE}",
    "ic_impervious": f"{IRONCLAD} behind impenetrable fortress shield, {BASE_STYLE}",
    "ic_power_through": f"{IRONCLAD} powering through pain gritting teeth, {BASE_STYLE}",
    "ic_entrench": f"{IRONCLAD} digging in behind heavy fortifications, {BASE_STYLE}",
    "ic_battle_trance": f"{IRONCLAD} in deep battle meditation, {BASE_STYLE}",
    "ic_offering": f"{IRONCLAD} making blood sacrifice on altar, {BASE_STYLE}",
    "ic_flex": f"{IRONCLAD} flexing muscles with power surge, {BASE_STYLE}",
    "ic_infernal_blade": f"Demonic sword appearing from hellfire before {IRONCLAD}, {BASE_STYLE}",
    "ic_dual_wield": f"{IRONCLAD} holding two weapons, {BASE_STYLE}",
    "ic_war_cry": f"{IRONCLAD} screaming fierce battle cry, {BASE_STYLE}",
    "ic_bloodletting": f"{IRONCLAD} cutting self to release power, {BASE_STYLE}",
    "ic_exhume": f"{IRONCLAD} reaching into grave pulling something out, {BASE_STYLE}",
    "ic_havoc": f"Chaos and destruction around {IRONCLAD}, {BASE_STYLE}",
    "ic_intimidate": f"{IRONCLAD} in terrifying stance making enemies cower, {BASE_STYLE}",
    "ic_disarm": f"{IRONCLAD} knocking weapon from enemy hands, {BASE_STYLE}",
    "ic_sentinel": f"{IRONCLAD} standing guard as sentinel, {BASE_STYLE}",
    "ic_double_tap": f"{IRONCLAD} striking twice in rapid succession, {BASE_STYLE}",
    "ic_limit_break": f"{IRONCLAD} breaking power limits with explosive aura, {BASE_STYLE}",
    "ic_armaments": f"{IRONCLAD} sharpening weapons at forge, {BASE_STYLE}",
    "ic_burning_pact": f"{IRONCLAD} signing burning contract in flames, {BASE_STYLE}",
    "ic_true_grit": f"{IRONCLAD} enduring pain with stoic determination, {BASE_STYLE}",
    "ic_second_wind": f"{IRONCLAD} catching second breath renewed vigor, {BASE_STYLE}",
    "ic_seeing_red": f"{IRONCLAD} eyes glowing red with anger, {BASE_STYLE}",
    "ic_shockwave": f"{IRONCLAD} stomping ground sending shockwaves, {BASE_STYLE}",
    "ic_spot_weakness": f"{IRONCLAD} analyzing enemy finding weak point, {BASE_STYLE}",

    # POWERS
    "ic_demon_form": f"{IRONCLAD} transforming into demon form, {BASE_STYLE}",
    "ic_corruption": f"Dark corruption spreading through {IRONCLAD}, {BASE_STYLE}",
    "ic_berserk": f"{IRONCLAD} in berserker rage transformation, {BASE_STYLE}",
    "ic_barricade": f"Unbreakable barrier of shields around {IRONCLAD}, {BASE_STYLE}",
    "ic_feel_no_pain": f"{IRONCLAD} injured but feeling nothing, {BASE_STYLE}",
    "ic_juggernaut": f"{IRONCLAD} as unstoppable juggernaut, {BASE_STYLE}",
    "ic_dark_embrace": f"{IRONCLAD} embracing darkness and shadows, {BASE_STYLE}",
    "ic_fire_breathing": f"{IRONCLAD} breathing fire from mouth, {BASE_STYLE}",
    "ic_brutality": f"{IRONCLAD} in savage brutal stance, {BASE_STYLE}",
    "ic_rupture": f"{IRONCLAD} body rupturing with power, {BASE_STYLE}",
    "ic_inflame": f"{IRONCLAD} body catching fire, {BASE_STYLE}",
    "ic_metallicize": f"{IRONCLAD} body turning to solid metal, {BASE_STYLE}",
    "ic_rage": f"{IRONCLAD} glowing with rage energy, {BASE_STYLE}",
    "ic_evolve": f"{IRONCLAD} evolving to higher form, {BASE_STYLE}",
    "ic_combust": f"{IRONCLAD} spontaneously combusting with fire, {BASE_STYLE}",
}


def generate_one(card_id, prompt, retries=2):
    output_path = os.path.join(OUTPUT_DIR, f"{card_id}.png")
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
                        print(f"  OK {card_id} ({len(img_data)//1024}KB)")
                        return True
            print(f"  WARN {card_id}: no image in response")
            return False
        except Exception as e:
            if attempt < retries:
                print(f"  RETRY {card_id}: {e}")
                time.sleep(2)
            else:
                print(f"  FAIL {card_id}: {e}")
                return False


if __name__ == "__main__":
    # Allow specifying a subset via command line
    if len(sys.argv) > 1:
        subset = sys.argv[1:]
        cards_to_gen = {k: v for k, v in CARDS.items() if k in subset}
    else:
        cards_to_gen = CARDS

    total = len(cards_to_gen)
    done = 0
    failed = []

    print(f"Generating {total} card art images...")
    for card_id, prompt in cards_to_gen.items():
        success = generate_one(card_id, prompt)
        if not success:
            failed.append(card_id)
        done += 1
        if done % 10 == 0:
            print(f"Progress: {done}/{total}")
        # Rate limit: ~2 requests per second for Gemini
        time.sleep(1.5)

    print(f"\nDone! {done - len(failed)}/{total} succeeded, {len(failed)} failed")
    if failed:
        print(f"Failed: {', '.join(failed)}")
