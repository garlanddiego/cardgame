#!/usr/bin/env python3
"""Generate Blood Fiend power icons using Gemini image generation API."""

import json, urllib.request, base64, os, time, sys
from PIL import Image
from io import BytesIO

# Load Gemini config
with open(os.path.expanduser('~/.genimg/config.json')) as f:
    config = json.load(f)
gemini = config['providers']['gemini']
API_KEY = gemini['api_key']
MODEL = gemini.get('model', 'gemini-2.5-flash-image')

OUTPUT_DIR = "assets/img/power_icons"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Base style for all power icons
BASE_STYLE = (
    "64x64 pixel game icon, dark fantasy power icon, "
    "crimson red and blood tones on dark background, "
    "bold simple symbolic design, thick outlines, "
    "glowing effect, no text, no letters, no words, "
    "single centered symbol, game UI icon style, "
    "Slay the Spire power icon style, square format"
)

# Blood Fiend power icons
ICONS = {
    "blood_frenzy": f"Swirling blood energy vortex with rage aura, crimson spiral of blood droplets radiating power, {BASE_STYLE}",
    "bf_bloodlust_power": f"Fanged vampire mouth dripping with fresh blood, crimson fangs and blood drops, {BASE_STYLE}",
    "sanguine_aura": f"Red glowing aura radiating outward from center, crimson energy waves expanding, {BASE_STYLE}",
    "crimson_pact": f"Blood contract scroll with red wax seal, dark parchment with crimson sigil, {BASE_STYLE}",
    "predators_mark": f"Three diagonal claw scratch marks dripping with blood, predator claw marks, {BASE_STYLE}",
    "blood_scent": f"Blood droplets with scent trail wisps, tracking blood drops floating in air, {BASE_STYLE}",
    "undying_rage": f"Skull wreathed in crimson fire and fury flames, burning skull with red flames, {BASE_STYLE}",
    "pain_threshold": f"Shield with blood drops on it, protective barrier stained with crimson blood, {BASE_STYLE}",
    "blood_bond": f"Two blood drops connected by a glowing red chain link, blood chain bond, {BASE_STYLE}",
    "hemostasis": f"Bandage cross symbol with blood drops, medical cross made of bloody bandages, {BASE_STYLE}",
    "undying_will": f"Glowing crimson heart refusing to break, cracked but unbroken heart with red glow, {BASE_STYLE}",
    "predator_instinct": f"Menacing eye with vertical slit predator pupil, glowing red predator eye, {BASE_STYLE}",
    "blood_shell": f"Blood-red crystalline shell barrier, crimson protective dome shield, {BASE_STYLE}",
}


def generate_one(icon_id, prompt, retries=2):
    output_path = os.path.join(OUTPUT_DIR, f"{icon_id}.png")
    if os.path.exists(output_path) and os.path.getsize(output_path) > 500:
        print(f"  SKIP {icon_id} (exists)")
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
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = json.load(resp)

            for candidate in data.get("candidates", []):
                for part in candidate.get("content", {}).get("parts", []):
                    if "inlineData" in part:
                        img_data = base64.b64decode(part["inlineData"]["data"])
                        # Open image, resize to 64x64 with high quality
                        img = Image.open(BytesIO(img_data))
                        img = img.resize((64, 64), Image.LANCZOS)
                        img.save(output_path, "PNG")
                        final_size = os.path.getsize(output_path)
                        print(f"  OK {icon_id} (original {img.size} -> 64x64, {final_size//1024}KB)")
                        return True
            print(f"  WARN {icon_id}: no image in response")
            if attempt < retries:
                time.sleep(3)
                continue
            return False
        except Exception as e:
            if attempt < retries:
                print(f"  RETRY {icon_id}: {e}")
                time.sleep(3)
            else:
                print(f"  FAIL {icon_id}: {e}")
                return False


if __name__ == "__main__":
    # Allow specifying a subset via command line
    if len(sys.argv) > 1:
        subset = sys.argv[1:]
        icons_to_gen = {k: v for k, v in ICONS.items() if k in subset}
    else:
        icons_to_gen = ICONS

    total = len(icons_to_gen)
    done = 0
    failed = []

    print(f"Generating {total} Blood Fiend power icons...")
    for icon_id, prompt in icons_to_gen.items():
        success = generate_one(icon_id, prompt)
        if not success:
            failed.append(icon_id)
        done += 1
        print(f"  Progress: {done}/{total}")
        # Rate limit
        time.sleep(2)

    print(f"\nDone! {done - len(failed)}/{total} succeeded, {len(failed)} failed")
    if failed:
        print(f"Failed: {', '.join(failed)}")
