#!/usr/bin/env python3
"""Fix forger hero: regenerate complete image, generate poses, flip to face right."""

import json, urllib.request, base64, os, time
from PIL import Image

with open(os.path.expanduser('~/.genimg/config.json')) as f:
    config = json.load(f)
gemini = config['providers']['gemini']
API_KEY = gemini['api_key']
MODEL = gemini.get('model', 'gemini-2.0-flash-exp')

REF_IMAGE = "assets/img/forger.png"
STYLE = "same character, same art style, same color palette, same proportions, same level of detail, 512x512, dark muted background, no text, no labels, character fully visible and CENTERED with space on all sides, no cropping"


def generate_with_ref(output_path, prompt, ref_path=REF_IMAGE, retries=3):
    with open(ref_path, "rb") as f:
        ref_b64 = base64.b64encode(f.read()).decode()
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


def flip_horizontal(path):
    """Flip image left-right."""
    img = Image.open(path)
    img = img.transpose(Image.FLIP_LEFT_RIGHT)
    img.save(path)
    print(f"  FLIPPED {path}")


if __name__ == "__main__":
    os.makedirs("assets/img/anim", exist_ok=True)

    # Step 1: Fix base hero — regenerate with full body, no cropping
    print("=== Step 1: Regenerate complete hero image ===")
    ok = generate_with_ref(
        "assets/img/forger.png",
        f"Redraw this exact character with the COMPLETE FULL BODY visible. Both arms and hands must be fully visible. The character must be CENTERED in the frame with enough margin on all sides — nothing should be cropped or cut off at any edge. Keep everything else identical: same face, scars, outfit, short-handled hammer, art style, colors. {STYLE}"
    )
    if not ok:
        print("FAILED base hero")
        exit(1)
    time.sleep(3)

    # Step 2: Generate pose variants from fixed hero
    print("\n=== Step 2: Generate pose variants ===")
    poses = {
        "assets/img/anim/forger_attack_1.png":
            f"Redraw this character in an ATTACK pose: right arm extended forward having just THROWN the short hammer telekinetically — the hammer flying away with a glowing orange energy trail, spinning like a boomerang. Left hand glows with telekinetic magic. Body leaning forward aggressively. FULL BODY visible, CENTERED, nothing cropped. {STYLE}",
        "assets/img/anim/forger_skill.png":
            f"Redraw this character in a CASTING/CHANNELING pose: both hands raised with magical forge energy glowing between them, orange runes and sparks swirling. The short hammer floats beside him. Standing upright, concentrated expression. FULL BODY visible, CENTERED, nothing cropped. {STYLE}",
        "assets/img/anim/forger_hit.png":
            f"Redraw this character in a HIT/RECOILING pose: upper body twisting backward from an impact, one arm raised defensively, grimacing in pain, hammer slipping. FULL BODY visible, CENTERED, nothing cropped. {STYLE}",
        "assets/img/forger_fallen.png":
            f"Redraw this character in a DEFEATED pose: down on one knee, hammer dropped on ground beside him, one hand on ground for support, exhausted but alive. FULL BODY visible, CENTERED, nothing cropped. {STYLE}",
    }

    failed = []
    for i, (path, prompt) in enumerate(poses.items(), 1):
        print(f"[{i}/4] {path}")
        if not generate_with_ref(path, prompt):
            failed.append(path)
        time.sleep(3)

    # Step 3: Flip standing, attack, skill horizontally (face right toward enemies)
    print("\n=== Step 3: Flip standing/attack/skill to face right ===")
    for path in ["assets/img/forger.png", "assets/img/anim/forger_attack_1.png", "assets/img/anim/forger_skill.png"]:
        flip_horizontal(path)

    print(f"\n=== Done: {4 - len(failed)}/4 poses OK ===")
    if failed:
        print("Failed:", failed)
