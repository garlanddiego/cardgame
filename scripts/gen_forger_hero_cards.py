#!/usr/bin/env python3
"""Regenerate the 7 hero-featured card art with updated hammer hero reference."""

import json, urllib.request, base64, os, time
from PIL import Image

with open(os.path.expanduser('~/.genimg/config.json')) as f:
    config = json.load(f)
gemini = config['providers']['gemini']
API_KEY = gemini['api_key']
MODEL = gemini.get('model', 'gemini-2.0-flash-exp')

REF_IMAGE = "assets/img/forger.png"
CARD_ART_DIR = "assets/img/card_art"

with open(REF_IMAGE, "rb") as f:
    ref_b64 = base64.b64encode(f.read()).decode()

S = "Slay the Spire card art style, very limited desaturated color palette, flat cell shading, hand-painted look, simple bold composition, dark muted background, no text, no labels, no words, square format"

HERO_CARDS = {
    "fg_blade_storm": f"Redraw this character seen FROM BEHIND in a wide shot, arms raised commanding a massive tornado of dozens of swords and daggers swirling in front of him, his short hammer glowing in his raised right hand, metal debris flying everywhere, epic scale. {S}",
    "fg_shield_bash": f"Redraw this character from a LOW ANGLE side view, lunging forward smashing a heavy iron shield into an unseen enemy, short hammer strapped to his belt, impact shockwave visible, aggressive motion blur. {S}",
    "fg_forge_master": f"Redraw this character as a DISTANT SILHOUETTE with arms spread wide, short hammer held high in right hand, dozens of floating weapons orbiting around him in a perfect circle, dramatic backlight, godlike pose, wide shot. {S}",
    "fg_iron_skin": f"Redraw this character's LEFT ARM in EXTREME CLOSE-UP, the forearm and hand transforming from scarred flesh into gleaming polished steel plates, halfway between flesh and metal, veins of orange glow at the seam. {S}",
    "fg_forge_slam": f"Redraw this character seen from a HIGH BIRD'S EYE VIEW, slamming his short-handled hammer down onto a glowing anvil, shockwave radiating outward in a circle on the ground, dust and debris. {S}",
    "fg_iron_will": f"Redraw this character's FACE in extreme close-up portrait, eyes glowing bright orange with inner fire, jaw clenched with absolute determination, scars visible, dramatic chiaroscuro lighting. {S}",
    "fg_overcharge": f"Redraw this character from a THREE-QUARTER REAR VIEW, holding his short hammer up high with both hands, pouring unstable blue lightning energy into it, the hammer cracking with overloaded power, dangerous energy arcing. {S}",
}


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
    total = len(HERO_CARDS)
    done = 0
    failed = []

    print(f"=== Regenerating {total} hero-featured cards with hammer version ===\n")
    for card_id, prompt in HERO_CARDS.items():
        path = f"{CARD_ART_DIR}/{card_id}.png"
        done += 1
        print(f"[{done}/{total}] {path}")
        if not generate_with_ref(path, prompt):
            failed.append(path)
        time.sleep(2)

    print(f"\n=== Done: {total - len(failed)}/{total} OK ===")
    if failed:
        print("Failed:", failed)
