#!/usr/bin/env python3
"""Generate forger hero pose variants using reference image + Gemini."""

import json, urllib.request, base64, os, time
from PIL import Image

with open(os.path.expanduser('~/.genimg/config.json')) as f:
    config = json.load(f)
gemini = config['providers']['gemini']
API_KEY = gemini['api_key']
MODEL = gemini.get('model', 'gemini-2.0-flash-exp')

REF_IMAGE = "assets/img/forger.png"

# Read and base64-encode the reference image
with open(REF_IMAGE, "rb") as f:
    ref_b64 = base64.b64encode(f.read()).decode()

STYLE = "same character, same art style, same color palette, same proportions, same outfit, same level of detail, 512x512, dark muted background, no text, no labels"

POSES = {
    "assets/img/anim/forger_attack_1.png": f"Redraw this exact character in an aggressive forward attack pose: thrusting his glowing hand forward to telekinetically launch the floating greatsword at an enemy, body leaning forward, muscles tensed, other arm pulling back. Keep EVERYTHING about the character identical — face, scars, body build, outfit, weapons, colors. Only change the body pose to attacking. {STYLE}",
    "assets/img/anim/forger_skill.png": f"Redraw this exact character in a casting/channeling pose: both hands raised with magical energy glowing between them, forging runes and sparks swirling around his hands, standing upright with concentrated expression, floating greatsword orbiting around him. Keep EVERYTHING about the character identical — face, scars, body build, outfit, weapons, colors. Only change the body pose to spellcasting. {STYLE}",
    "assets/img/anim/forger_hit.png": f"Redraw this exact character in a hit/recoiling pose: upper body twisting backward from an impact to the chest, one arm raised defensively, grimacing in pain, the floating greatsword wobbling in mid-air. Keep EVERYTHING about the character identical — face, scars, body build, outfit, weapons, colors. Only change the body pose to taking a hit. {STYLE}",
    "assets/img/forger_fallen.png": f"Redraw this exact character in a defeated/collapsed pose: down on one knee, weapons scattered on the ground beside him, one hand on the ground for support, exhausted but alive, the greatsword stuck in the ground beside him. Keep EVERYTHING about the character identical — face, scars, body build, outfit, weapons, colors. Only change the body pose to defeated/kneeling. {STYLE}",
}


def generate_with_ref(output_path, prompt, retries=2):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={API_KEY}"
    payload = {
        "contents": [{
            "parts": [
                {
                    "inlineData": {
                        "mimeType": "image/png",
                        "data": ref_b64
                    }
                },
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
                        # Resize to 512x512
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
    total = len(POSES)
    done = 0
    failed = []

    print(f"=== Generating {total} forger pose variants from reference ===\n")

    for path, prompt in POSES.items():
        done += 1
        print(f"[{done}/{total}] {path}")
        if not generate_with_ref(path, prompt):
            failed.append(path)
        time.sleep(3)

    print(f"\n=== Done: {total - len(failed)}/{total} OK ===")
    if failed:
        print("Failed:")
        for f in failed:
            print(f"  {f}")
