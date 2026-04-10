#!/usr/bin/env python3
"""Generate Forger, Fire Mage, and Greatsword sprites using Gemini API."""

import json, urllib.request, base64, os, sys, time
from PIL import Image

# Load Gemini config
with open(os.path.expanduser('~/.genimg/config.json')) as f:
    config = json.load(f)
gemini = config['providers']['gemini']
API_KEY = gemini['api_key']
MODEL = gemini.get('model', 'gemini-2.0-flash-exp')

# Art direction matching existing sprites (ironclad/bloodfiend style)
STYLE = "full body character sprite, transparent background, dark fantasy 2D game art, clean flat-color digital illustration, bold outlines, detailed, centered in frame, character fills 80% of canvas height, 512x512 pixel art, no text, no labels"

FORGER_DESC = "a muscular armored blacksmith warrior in heavy dark steel plate armor with orange-amber forge fire accents, wearing a horned helmet with amber visor, thick leather apron over plate armor, holding a massive war hammer in one hand, dark brown and steel grey color scheme with glowing orange ember details on the armor edges"

FIRE_MAGE_DESC = "a dark sorcerer pyromancer in flowing dark red-black tattered robes with burning flame patterns, hood casting shadows over glowing orange eyes, hands wreathed in swirling flames and fire magic, fire runes on the robes, sinister and powerful stance"

GREATSWORD_DESC = "a massive ornate dark steel greatsword floating upright, glowing orange-amber ember veins running through the blade, elaborate cross guard with forge-fire motifs, the blade radiates heat with small embers floating around it, dark fantasy weapon"

SPRITES = {
    # Standing pose sprites
    "assets/img/forger.png": f"{FORGER_DESC}, standing in a heroic wide stance ready for battle, hammer resting on shoulder, {STYLE}",
    "assets/img/forger_fallen.png": f"{FORGER_DESC}, kneeling on one knee in defeated exhausted pose, hammer planted in ground for support, head bowed, armor cracked and dimmed, embers dying out, {STYLE}",
    "assets/img/fire_mage.png": f"{FIRE_MAGE_DESC}, standing in a powerful casting stance with both hands raised conjuring flames, robes flowing with magical energy, {STYLE}",
    "assets/img/fire_mage_fallen.png": f"{FIRE_MAGE_DESC}, collapsed to knees in defeated pose, flames extinguished, robes tattered, head bowed in exhaustion, {STYLE}",
    "assets/img/greatsword.png": f"{GREATSWORD_DESC}, {STYLE}",
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
                        target = (512, 512)
                        if "greatsword" in output_path:
                            target = (256, 512)
                        if img.size != target:
                            img = img.resize(target, Image.LANCZOS)
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
