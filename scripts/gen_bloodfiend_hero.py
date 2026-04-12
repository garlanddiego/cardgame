#!/usr/bin/env python3
"""Generate bloodfiend hero: wolf-helmet berserker armor warrior."""

import json, urllib.request, base64, os, time
from PIL import Image

with open(os.path.expanduser('~/.genimg/config.json')) as f:
    config = json.load(f)
gemini = config['providers']['gemini']
API_KEY = gemini['api_key']
MODEL = gemini.get('model', 'gemini-2.0-flash-exp')

REF_IMAGE = "/tmp/handoff/handoff-images/img_v3_0210l_838b010e-9ea1-460b-aa3e-2c29aefaf5hu.png"

with open(REF_IMAGE, "rb") as f:
    ref_b64 = base64.b64encode(f.read()).decode()

STYLE = "Slay the Spire character art style, very limited color palette only 2-3 main colors, flat cell shading with minimal highlights, hand-painted look, desaturated dark tones with blood red accent, 512x512, no text, no labels, character fully visible and CENTERED with space on all sides, transparent background"

HERO_DESC = "a tall muscular HUMAN warrior in dark heavy plate armor, wearing a WOLF-SHAPED HELMET like Guts Berserker Armor from Berserk manga — the helmet has wolf fangs and wolf ears but the body is clearly HUMAN not a wolf, dark black armor with blood red glowing cracks and blood dripping, one large serrated greatsword, menacing aggressive stance"


def generate_with_ref(output_path, prompt, retries=3):
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
    # Generate the base hero image
    print("=== Generating bloodfiend hero (wolf-helmet berserker) ===")
    ok = generate_with_ref(
        "assets/img/bloodfiend_hero_draft.png",
        f"Using this image as reference for the pose and dark armor style: redesign this character as a HUMAN WARRIOR (not a wolf/beast), wearing a WOLF-SHAPED HELMET — like Guts' Berserker Armor from Berserk. The helmet looks like a snarling wolf head with fangs and pointed ears, but the body underneath is clearly a muscular HUMAN in full plate armor. Keep the same aggressive crouching pose from the reference. Dark black armor with blood red glowing cracks and blood dripping from joints. One hand has sharp clawed gauntlets. Keep the same dark menacing atmosphere. {STYLE}"
    )
    if not ok:
        print("FAILED")
        exit(1)
