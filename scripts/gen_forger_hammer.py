#!/usr/bin/env python3
"""Modify forger hero: replace weapon with short-handled hammer, regenerate poses."""

import json, urllib.request, base64, os, time
from PIL import Image

with open(os.path.expanduser('~/.genimg/config.json')) as f:
    config = json.load(f)
gemini = config['providers']['gemini']
API_KEY = gemini['api_key']
MODEL = gemini.get('model', 'gemini-2.0-flash-exp')

REF_IMAGE = "assets/img/forger.png"

with open(REF_IMAGE, "rb") as f:
    ref_b64 = base64.b64encode(f.read()).decode()

STYLE = "same art style, same color palette, same proportions, same level of detail, 512x512, dark muted background, no text, no labels"


def generate_with_ref(output_path, prompt, retries=3):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={API_KEY}"
    # Re-read ref image each time (in case forger.png was updated)
    with open(REF_IMAGE, "rb") as f:
        current_ref = base64.b64encode(f.read()).decode()
    payload = {
        "contents": [{
            "parts": [
                {"inlineData": {"mimeType": "image/png", "data": current_ref}},
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
    os.makedirs("assets/img/anim", exist_ok=True)

    # Step 1: Modify base hero image — replace weapons with short-handled hammer
    print("=== Step 1: Modify hero — weapon → short-handled hammer ===")
    ok = generate_with_ref(
        "assets/img/forger.png",
        f"Edit this character image: REPLACE all weapons (swords, daggers, greatsword) with a SINGLE SHORT-HANDLED FORGE HAMMER held in his right hand. The hammer has a heavy iron head and a short wooden handle, like a blacksmith's war hammer. Remove the floating greatsword — instead show faint magical energy around his free left hand (ready to throw the hammer telekinetically). Keep everything else EXACTLY the same — same character, same pose, same outfit, same scars, same art style, same colors, same background. Only change the weapon to a short hammer. {STYLE}"
    )
    if not ok:
        print("FAILED to modify base hero. Aborting.")
        exit(1)
    time.sleep(3)

    # Step 2: Generate pose variants from the updated hero
    print("\n=== Step 2: Generate pose variants ===")
    poses = {
        "assets/img/anim/forger_attack_1.png":
            f"Redraw this character in an ATTACK pose: his right arm extended forward having just THROWN the short hammer telekinetically — the hammer is flying away from him with a glowing orange energy trail, spinning like a boomerang. His left hand glows with telekinetic magic controlling the hammer's path. Body leaning forward aggressively, muscles tensed. Keep EVERYTHING about the character identical. Only change the pose to throwing the hammer. {STYLE}",
        "assets/img/anim/forger_skill.png":
            f"Redraw this character in a CASTING/CHANNELING pose: both hands raised with magical forge energy glowing between them, orange runes and sparks swirling around. The short hammer floats beside him surrounded by energy. Standing upright with concentrated expression. Keep EVERYTHING identical. Only change to spellcasting pose. {STYLE}",
        "assets/img/anim/forger_hit.png":
            f"Redraw this character in a HIT/RECOILING pose: upper body twisting backward from an impact to the chest, one arm raised defensively, grimacing in pain, the short hammer slipping from his grip slightly. Keep EVERYTHING identical. Only change to taking a hit. {STYLE}",
        "assets/img/forger_fallen.png":
            f"Redraw this character in a DEFEATED/COLLAPSED pose: down on one knee, the short hammer dropped on the ground beside him, one hand on the ground for support, exhausted but alive. Keep EVERYTHING identical. Only change to defeated kneeling. {STYLE}",
    }

    failed = []
    total = len(poses)
    for i, (path, prompt) in enumerate(poses.items(), 1):
        print(f"[{i}/{total}] {path}")
        if not generate_with_ref(path, prompt):
            failed.append(path)
        time.sleep(3)

    print(f"\n=== Done: {total - len(failed)}/{total} poses OK ===")
    if failed:
        print("Failed:", failed)
