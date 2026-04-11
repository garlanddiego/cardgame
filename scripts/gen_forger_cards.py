#!/usr/bin/env python3
"""Generate ALL 47 forger card art. Hero-featured cards use reference image."""

import json, urllib.request, base64, os, time
from PIL import Image

with open(os.path.expanduser('~/.genimg/config.json')) as f:
    config = json.load(f)
gemini = config['providers']['gemini']
API_KEY = gemini['api_key']
MODEL = gemini.get('model', 'gemini-2.0-flash-exp')

REF_IMAGE = "assets/img/forger.png"
CARD_ART_DIR = "assets/img/card_art"
os.makedirs(CARD_ART_DIR, exist_ok=True)

# Read reference image
with open(REF_IMAGE, "rb") as f:
    ref_b64 = base64.b64encode(f.read()).decode()

S = "Slay the Spire card art style, very limited desaturated color palette, flat cell shading, hand-painted look, simple bold composition, dark muted background, no text, no labels, no words, square format"

# ══════════════════════════════════════════════════════════
# Cards that USE hero reference image (different angles!)
# ══════════════════════════════════════════════════════════
HERO_CARDS = {
    # hero from BEHIND, commanding blade tornado — wide shot
    "fg_blade_storm": f"Redraw this character seen FROM BEHIND in a wide shot, arms raised commanding a massive tornado of dozens of swords and daggers swirling in front of him, metal debris flying everywhere, epic scale. {S}",
    # hero CLOSE-UP from side, slamming shield
    "fg_shield_bash": f"Redraw this character from a LOW ANGLE side view, lunging forward smashing a heavy iron shield into an unseen enemy, impact shockwave visible, aggressive motion blur. {S}",
    # hero SILHOUETTE from far, arms spread, weapons orbiting
    "fg_forge_master": f"Redraw this character as a DISTANT SILHOUETTE with arms spread wide, dozens of floating weapons orbiting around him in a perfect circle, dramatic backlight, godlike pose, wide shot. {S}",
    # hero ARM CLOSE-UP, flesh turning to metal
    "fg_iron_skin": f"Redraw this character's LEFT ARM in EXTREME CLOSE-UP, the forearm and hand transforming from scarred flesh into gleaming polished steel plates, halfway between flesh and metal, veins of orange glow at the seam. {S}",
    # hero from ABOVE looking down, kneeling at anvil
    "fg_forge_slam": f"Redraw this character seen from a HIGH BIRD'S EYE VIEW, slamming a massive hammer down onto an anvil, shockwave radiating outward in a circle on the ground, dust and debris. {S}",
    # hero FACE CLOSE-UP, eyes glowing with determination
    "fg_iron_will": f"Redraw this character's FACE in extreme close-up portrait, eyes glowing bright orange with inner fire, jaw clenched with absolute determination, scars visible, dramatic chiaroscuro lighting. {S}",
    # hero from 3/4 rear, channeling energy into greatsword
    "fg_overcharge": f"Redraw this character from a THREE-QUARTER REAR VIEW, both hands pressed against a floating greatsword, pouring unstable blue lightning energy into it, the sword cracking with overloaded power, dangerous. {S}",
}

# ══════════════════════════════════════════════════════════
# Cards that do NOT use hero — pure object/scene/abstract
# ══════════════════════════════════════════════════════════
TEXT_CARDS = {
    # ATTACKS
    "fg_strike": f"a single forge hammer mid-swing smashing red-hot iron on an anvil, orange sparks exploding outward, close-up, {S}",
    "fg_eruption_strike": f"a cracked stone floor erupting with molten lava and metal shrapnel from below, explosive upward force, {S}",
    "fg_greatsword_cleave": f"a giant glowing orange greatsword in a wide horizontal slash, motion blur trail of embers, no person visible, {S}",
    "fg_hardened_blade": f"a single katana-like blade submerged in ice water, steam cloud rising, blade edge glowing cold blue, close-up, {S}",
    "fg_magnetic_edge": f"a longsword crackling with purple lightning pulling hundreds of tiny metal shards toward it like a magnet, {S}",
    "fg_reforged_edge": f"fragments of a broken sword floating in mid-air fusing back together in bright orange forge fire, {S}",
    "fg_riposte_strike": f"two crossed swords clashing with a bright spark at the intersection point, close-up of the clash moment, {S}",
    "fg_sword_crash": f"a greatsword blade snapping in half at the moment of impact, metal shards frozen in explosive pattern, {S}",
    "fg_tempered_strike": f"a perfectly glowing red-hot chisel being struck by a small hammer, precise controlled sparks, workshop close-up, {S}",
    "fg_molten_core": f"a sphere of swirling molten lava and liquid metal at the center, radiating extreme heat waves and orange glow, {S}",
    # SKILLS
    "fg_defend": f"a tall kite shield planted firmly in the ground with forge runes glowing blue on its surface, {S}",
    "fg_absorb_impact": f"a thick breastplate with a deep arrow embedded in it, cracks spreading but not penetrating through, close-up, {S}",
    "fg_block_transfer": f"two shields connected by a flowing blue energy stream, one fading transparent as the other brightens, {S}",
    "fg_chain_forge": f"an anvil with five hammers frozen mid-strike in a rapid sequence, ghostly afterimage effect, {S}",
    "fg_counter_forge": f"a glowing hot anvil deflecting an incoming sword, the sword bending on contact, sparks flying backward, {S}",
    "fg_delay_charge": f"a war hammer head surrounded by swirling golden energy vortex, charging up power, suspended in darkness, {S}",
    "fg_forge_armor": f"a complete suit of plate armor assembled piece by piece on a wooden mannequin, warm forge glow behind, {S}",
    "fg_forge_barrier": f"a wall of overlapping iron plates rising from the ground like tectonic plates, glowing orange seams between, {S}",
    "fg_forge_shield": f"a round shield on an anvil still glowing from fresh forging, hammer resting beside it, {S}",
    "fg_heat_treat": f"a sword blade inside a roaring furnace glowing white-hot, heat waves warping the air around it, close-up, {S}",
    "fg_impervious_wall": f"an enormous fortress gate of black iron with dozens of sword tips broken off stuck in its surface, unbreakable, {S}",
    "fg_melt_down": f"a crucible overflowing with bright orange liquid metal, old swords and shields dissolving inside, {S}",
    "fg_quick_temper": f"a forge bellows blasting air into flames that shoot three meters high, aggressive intense fire, {S}",
    "fg_reinforce": f"iron rivets being hammered into layered steel plates, close-up of metalwork craftsmanship, {S}",
    "fg_repurpose": f"a workbench covered with disassembled weapon parts being rearranged into a new weapon design, top-down view, {S}",
    "fg_salvage": f"a pile of broken rusted weapons and armor with one gleaming usable piece being pulled out from the heap, {S}",
    "fg_sharpen": f"a spinning grindstone with a blade pressed against it, shower of bright sparks trailing downward, {S}",
    "fg_summon_sword": f"a massive greatsword assembling itself from floating molten metal droplets in mid-air, glowing orange, {S}",
    "fg_sword_sacrifice": f"a greatsword exploding into a burst of protective golden light shards radiating outward like a supernova, {S}",
    "fg_sword_ward": f"three swords orbiting in a circle like a protective barrier, trails of glowing light connecting them, {S}",
    "fg_temper": f"a blade transitioning colors from glowing red on left to cool blue-grey on right, gradient of tempering process, {S}",
    "fg_thorn_forge": f"a shield covered in freshly forged sharp iron spikes, menacing and brutal looking, on an anvil, {S}",
    "fg_thorn_wall": f"a barrier of jagged metal spikes and barbed wire stretching across the entire frame, intimidating, {S}",
    # POWERS
    "fg_auto_forge": f"a ghostly translucent hammer striking an anvil by itself with no one holding it, magical blue runes floating around, {S}",
    "fg_barricade": f"an impossibly thick fortress wall of stacked iron ingots with golden light seeping through the cracks, {S}",
    "fg_energy_reserve": f"a glowing crystal orb containing swirling molten metal energy inside, pulsing with stored power, {S}",
    "fg_living_sword": f"a greatsword floating vertically with a single glowing eye on its crossguard, alive and sentient, eerie atmosphere, {S}",
    "fg_resonance": f"a sword a shield and a helmet vibrating with connected blue energy waves between them, harmonic resonance visualization, {S}",
    "fg_sword_mastery": f"a single perfect greatsword hovering vertically in a beam of white light, flawless craftsmanship, {S}",
    "fg_thorn_aura": f"a ring of sharp iron thorns and spikes radiating outward from a central point like a deadly halo, {S}",
}


def generate_text_only(output_path, prompt, retries=2):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={API_KEY}"
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]}
    }
    return _do_generate(url, payload, output_path, retries)


def generate_with_ref(output_path, prompt, retries=2):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={API_KEY}"
    payload = {
        "contents": [{
            "parts": [
                {"inlineData": {"mimeType": "image/png", "data": ref_b64}},
                {"text": prompt}
            ]
        }],
        "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]}
    }
    return _do_generate(url, payload, output_path, retries)


def _do_generate(url, payload, output_path, retries):
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
                        img = Image.open(output_path)
                        if img.size != (512, 512):
                            img = img.resize((512, 512), Image.LANCZOS)
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
    total = len(HERO_CARDS) + len(TEXT_CARDS)
    done = 0
    failed = []

    print(f"=== Generating {total} forger card art ({len(HERO_CARDS)} with hero ref, {len(TEXT_CARDS)} text-only) ===\n")

    # Hero-referenced cards first
    print("--- Hero-referenced cards ---")
    for card_id, prompt in HERO_CARDS.items():
        path = f"{CARD_ART_DIR}/{card_id}.png"
        done += 1
        print(f"[{done}/{total}] {path} (with ref)")
        if not generate_with_ref(path, prompt):
            failed.append(path)
        time.sleep(2)

    # Text-only cards
    print("\n--- Object/scene cards ---")
    for card_id, prompt in TEXT_CARDS.items():
        path = f"{CARD_ART_DIR}/{card_id}.png"
        done += 1
        print(f"[{done}/{total}] {path}")
        if not generate_text_only(path, prompt):
            failed.append(path)
        time.sleep(2)

    print(f"\n=== Done: {total - len(failed)}/{total} OK ===")
    if failed:
        print("Failed:")
        for f in failed:
            print(f"  {f}")
