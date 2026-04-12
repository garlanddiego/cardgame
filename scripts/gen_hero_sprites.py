#!/usr/bin/env python3
"""Generate hero attack and fallen sprites using Gemini API."""

import json, urllib.request, base64, os, sys, time
from PIL import Image

# Load Gemini config
with open(os.path.expanduser('~/.genimg/config.json')) as f:
    config = json.load(f)
gemini = config['providers']['gemini']
API_KEY = gemini['api_key']
MODEL = gemini.get('model', 'gemini-2.0-flash-exp')

# Art direction matching existing sprites
STYLE = "full body character sprite, transparent background, dark fantasy 2D game art, clean flat-color digital illustration, bold outlines, detailed, centered in frame, character fills 80% of canvas height, 512x512 pixel art, no text, no labels"

IRONCLAD_DESC = "a dark armored knight warrior with red cape and dark steel plate armor, horned helmet, wielding a longsword"
SILENT_DESC = "a hooded assassin rogue in dark green-black leather armor and tattered cloak, dual wielding serrated daggers"

SPRITES = {
    # Attack sprites - dramatic forward-lunging attack poses
    "assets/img/anim/ironclad_attack_1.png": f"{IRONCLAD_DESC}, in a dramatic forward lunging sword slash attack pose, sword swinging horizontally, body leaning forward aggressively, dynamic action pose with motion, {STYLE}",
    "assets/img/anim/ironclad_attack_2.png": f"{IRONCLAD_DESC}, in a powerful overhead two-handed sword slam downward attack, body twisted mid-swing, cape flying, {STYLE}",
    "assets/img/anim/silent_attack_1.png": f"{SILENT_DESC}, in a fast forward stabbing attack pose, lunging forward with both daggers, cloak billowing behind, dynamic slashing motion, {STYLE}",

    # Fallen/death sprites - kneeling defeated pose, same scale as standing sprite
    "assets/img/ironclad_fallen.png": f"{IRONCLAD_DESC}, kneeling on one knee in defeated pose, sword planted in ground for support, head bowed, cape draped, exhausted and wounded but dignified, {STYLE}",
    "assets/img/silent_fallen.png": f"{SILENT_DESC}, collapsed to one knee in defeated pose, one dagger dropped on ground, other hand supporting body, hood fallen back slightly, exhausted, {STYLE}",
}


def generate_sprite(output_path, prompt, retries=2):
    """Generate a single sprite image."""
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
                        # Resize to 512x512 if needed
                        img = Image.open(output_path)
                        if img.size != (512, 512):
                            img = img.resize((512, 512), Image.LANCZOS)
                            img.save(output_path)
                        print(f"  OK {output_path} ({os.path.getsize(output_path)} bytes)")
                        return True

            print(f"  WARN: No image in response for {output_path}")
        except Exception as e:
            print(f"  ERR attempt {attempt+1}: {e}")
            if attempt < retries:
                time.sleep(3)
    return False


def main():
    targets = sys.argv[1:] if len(sys.argv) > 1 else list(SPRITES.keys())
    total = len(targets)
    for i, path in enumerate(targets):
        if path not in SPRITES:
            print(f"Unknown target: {path}")
            continue
        print(f"[{i+1}/{total}] Generating {path}...")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        generate_sprite(path, SPRITES[path])
        if i < total - 1:
            time.sleep(2)  # Rate limit
    print("Done!")


if __name__ == "__main__":
    main()
