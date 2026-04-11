#!/usr/bin/env python3
"""Generate ALL forger images: hero sprites + card art using Gemini API."""

import json, urllib.request, base64, os, time, sys
from PIL import Image

with open(os.path.expanduser('~/.genimg/config.json')) as f:
    config = json.load(f)
gemini = config['providers']['gemini']
API_KEY = gemini['api_key']
MODEL = gemini.get('model', 'gemini-2.0-flash-exp')

CARD_ART_DIR = "assets/img/card_art"
HERO_DIR = "assets/img"
os.makedirs(CARD_ART_DIR, exist_ok=True)

# Style constants
HERO_STYLE = "full body character sprite, dark muted background, Slay the Spire character art style, very limited color palette only 2-3 main colors, flat cell shading with minimal highlights, hand-painted look, desaturated earth tones with warm orange accent, centered in frame, character fills 80% of canvas, 512x512, no text, no labels"
CARD_STYLE = "Slay the Spire card art style, very limited desaturated color palette, flat cell shading, hand-painted look, simple bold composition, dark muted background, no text, no labels, no words, square format"

FORGER_DESC = "a muscular bearded bare-chested warrior blacksmith with one shoulder pauldron, exposed scarred torso, leather belt with multiple weapons strapped on: daggers swords axes, dark torn pants and boots, one hand holding a sword and the other hand glowing with telekinetic magic to control a floating greatsword, rough tough guy, comic book ink line art style, desaturated muted colors on light grey-blue background"

# ═══════ HERO SPRITES (skip forger.png — user provided) ═══════
HERO_SPRITES = {
    "assets/img/forger_fallen.png": f"{FORGER_DESC}, collapsed on one knee, weapons scattered on ground, bloody greatsword stuck in ground beside him, exhausted defeated but still alive, {HERO_STYLE}",
    "assets/img/anim/forger_attack_1.png": f"{FORGER_DESC}, thrusting glowing hand forward launching the floating greatsword telekinetically at the enemy, aggressive forward attack pose, muscles tensed, {HERO_STYLE}",
    "assets/img/anim/forger_hit.png": f"{FORGER_DESC}, recoiling from a hit to the chest, grimacing in pain, one arm raised defensively, floating greatsword wobbling in mid-air, {HERO_STYLE}",
}

# ═══════ CARD ART ═══════
S = CARD_STYLE  # desaturated STS style
CARDS = {
    # ═══ ATTACKS (12) — focus on weapons, impacts, destruction ═══
    "fg_strike": f"a single forge hammer mid-swing smashing red-hot iron on an anvil, orange sparks exploding, close-up, {S}",
    "fg_blade_storm": f"a tornado of dozens of different blades daggers and swords swirling in mid-air, metal debris flying, wide shot, {S}",
    "fg_eruption_strike": f"a cracked stone floor erupting with molten lava and metal shrapnel from below, explosive upward force, {S}",
    "fg_forge_slam": f"a massive iron anvil crashing down from above onto cracked ground, dust and shockwave radiating outward, {S}",
    "fg_greatsword_cleave": f"a giant glowing orange greatsword in a wide horizontal slash, motion blur trail of embers, no person, {S}",
    "fg_hardened_blade": f"a single katana-like blade submerged in ice water, steam cloud rising, blade edge glowing cold blue, close-up, {S}",
    "fg_magnetic_edge": f"a longsword crackling with purple lightning pulling hundreds of tiny metal shards toward it like a magnet, {S}",
    "fg_reforged_edge": f"fragments of a broken sword floating in mid-air fusing back together in bright orange forge fire, {S}",
    "fg_riposte_strike": f"two crossed swords clashing with a bright spark at the intersection point, close-up of the clash, {S}",
    "fg_shield_bash": f"a dented iron shield with a massive fist-shaped imprint, cracks spreading from center of impact, {S}",
    "fg_sword_crash": f"a greatsword blade snapping in half at the moment of impact, metal shards frozen in explosion, {S}",
    "fg_tempered_strike": f"a perfectly glowing red-hot chisel being struck by a small hammer, precise controlled sparks, workshop close-up, {S}",
    # ═══ SKILLS (25) — focus on objects, environments, abstract effects ═══
    "fg_defend": f"a tall kite shield planted in the ground with forge runes glowing blue on its surface, {S}",
    "fg_absorb_impact": f"a thick breastplate with a deep arrow embedded in it, cracks spreading but not penetrating, close-up, {S}",
    "fg_block_transfer": f"two shields connected by a flowing blue energy stream, one fading as the other brightens, {S}",
    "fg_chain_forge": f"an anvil with five hammers frozen mid-strike in a rapid sequence, afterimage effect, {S}",
    "fg_counter_forge": f"a glowing hot anvil deflecting an incoming sword, the sword bending on contact, sparks flying backward, {S}",
    "fg_delay_charge": f"a war hammer head surrounded by swirling golden energy vortex, charging up, suspended in darkness, {S}",
    "fg_forge_armor": f"a complete suit of plate armor assembled piece by piece on a wooden mannequin, warm forge glow behind, {S}",
    "fg_forge_barrier": f"a wall of overlapping iron plates rising from the ground like tectonic plates, glowing orange seams, {S}",
    "fg_forge_shield": f"a round shield on an anvil still glowing from fresh forging, hammer resting beside it, {S}",
    "fg_heat_treat": f"a sword blade inside a roaring furnace glowing white-hot, heat waves warping the view, close-up, {S}",
    "fg_impervious_wall": f"an enormous fortress gate of black iron with dozens of sword tips broken off stuck in its surface, unbreakable, {S}",
    "fg_iron_skin": f"a bare muscular arm transforming into polished steel plates from fingertips upward, half flesh half metal, {S}",
    "fg_melt_down": f"a crucible overflowing with bright orange liquid metal, old swords and shields dissolving inside, {S}",
    "fg_overcharge": f"an anvil cracking apart from too much energy, blue lightning arcing wildly in all directions, unstable, {S}",
    "fg_quick_temper": f"a forge bellows blasting air into flames that shoot three meters high, aggressive intense fire, {S}",
    "fg_reinforce": f"iron rivets being hammered into layered steel plates, close-up of metalwork craftsmanship, {S}",
    "fg_repurpose": f"a workbench covered with disassembled weapon parts being rearranged into a new weapon design, top-down view, {S}",
    "fg_salvage": f"a pile of broken rusted weapons and armor with one gleaming usable piece being pulled out, {S}",
    "fg_sharpen": f"a spinning grindstone with a blade pressed against it, shower of bright sparks trailing downward, {S}",
    "fg_summon_sword": f"a massive greatsword assembling itself from floating molten metal droplets in mid-air, glowing orange, {S}",
    "fg_sword_sacrifice": f"a greatsword exploding into a burst of protective golden light shards radiating outward, {S}",
    "fg_sword_ward": f"three swords orbiting in a circle like a protective barrier, trails of light connecting them, {S}",
    "fg_temper": f"a blade transitioning colors from glowing red on left to cool blue-grey on right, gradient of tempering, {S}",
    "fg_thorn_forge": f"a shield covered in freshly forged sharp iron spikes, menacing and brutal, on an anvil, {S}",
    "fg_thorn_wall": f"a barrier of jagged metal spikes and barbed wire stretching across the frame, intimidating, {S}",
    # ═══ POWERS (10) — iconic symbols, auras, abstract concepts ═══
    "fg_auto_forge": f"a ghostly translucent hammer striking an anvil by itself, magical blue runes floating around, no person, {S}",
    "fg_barricade": f"an impossibly thick fortress wall of stacked iron ingots with golden light seeping through cracks, {S}",
    "fg_energy_reserve": f"a glowing crystal orb containing swirling molten metal energy, pulsing with stored power, {S}",
    "fg_forge_master": f"a scarred bare-chested blacksmith silhouette with arms spread, dozens of weapons floating around him in a circle, {S}",
    "fg_iron_will": f"an anatomical iron heart with veins of glowing orange metal, burning with inner determination, {S}",
    "fg_living_sword": f"a greatsword floating vertically with a single glowing eye on its crossguard, alive and sentient, eerie, {S}",
    "fg_molten_core": f"a sphere of swirling molten lava and liquid metal at the center of the image, radiating extreme heat waves, {S}",
    "fg_resonance": f"a sword a shield and a helmet vibrating with connected blue energy waves between them, harmonic resonance, {S}",
    "fg_sword_mastery": f"a single perfect greatsword hovering vertically in a beam of white light, flawless craftsmanship, {S}",
    "fg_thorn_aura": f"a ring of sharp iron thorns and spikes radiating outward from a central point like a deadly halo, {S}",
}


def generate_image(output_path, prompt, size=None, retries=2):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={API_KEY}"
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]}
    }
    for attempt in range(retries + 1):
        try:
            req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                        headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = json.load(resp)
            for candidate in data.get("candidates", []):
                for part in candidate.get("content", {}).get("parts", []):
                    if "inlineData" in part:
                        img_data = base64.b64decode(part["inlineData"]["data"])
                        with open(output_path, "wb") as f:
                            f.write(img_data)
                        if size:
                            img = Image.open(output_path)
                            if img.size != size:
                                img = img.resize(size, Image.LANCZOS)
                                img.save(output_path)
                        print(f"  OK {output_path}")
                        return True
            print(f"  No image in response for {output_path}")
        except Exception as e:
            print(f"  Attempt {attempt+1} failed: {e}")
            if attempt < retries:
                time.sleep(5)
    print(f"  FAILED {output_path}")
    return False


if __name__ == "__main__":
    total = len(HERO_SPRITES) + len(CARDS)
    done = 0
    failed = []

    print(f"=== Generating {total} forger images ===\n")

    # Hero sprites (512x512)
    print("--- Hero Sprites ---")
    for path, prompt in HERO_SPRITES.items():
        done += 1
        print(f"[{done}/{total}] {path}")
        if not generate_image(path, prompt, size=(512, 512)):
            failed.append(path)
        time.sleep(2)

    # Card art (512x512)
    print("\n--- Card Art ---")
    for card_id, prompt in CARDS.items():
        path = f"{CARD_ART_DIR}/{card_id}.png"
        done += 1
        print(f"[{done}/{total}] {path}")
        if not generate_image(path, prompt, size=(512, 512)):
            failed.append(path)
        time.sleep(2)

    print(f"\n=== Done: {total - len(failed)}/{total} OK ===")
    if failed:
        print("Failed:")
        for f in failed:
            print(f"  {f}")
