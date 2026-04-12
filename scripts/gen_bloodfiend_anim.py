#!/usr/bin/env python3
"""Generate 3 animation sprites for Blood Fiend character using Gemini API.

Uses the existing bloodfiend.png as design reference and matches the art style
of existing ironclad/silent animation sprites (512x512 RGBA, transparent bg,
clean 2D cartoon illustration style).
"""

import json, urllib.request, base64, os, time, sys
from PIL import Image
import io

# Load Gemini config
with open(os.path.expanduser('~/.genimg/config.json')) as f:
    config = json.load(f)
gemini = config['providers']['gemini']
API_KEY = gemini['api_key']
MODEL = "gemini-2.5-flash-image"

OUTPUT_DIR = "assets/img/anim"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Load the reference bloodfiend image to include in the prompt
def load_image_as_base64(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")

# Load reference images
bloodfiend_b64 = load_image_as_base64("assets/img/bloodfiend.png")
ironclad_attack_b64 = load_image_as_base64("assets/img/anim/ironclad_attack_1.png")
ironclad_hit_b64 = load_image_as_base64("assets/img/anim/ironclad_hit.png")
ironclad_skill_b64 = load_image_as_base64("assets/img/anim/ironclad_skill.png")

# Character description matching the base design
BLOODFIEND = "a blood-crazed berserker in dark spiked plate armor with jagged edges, glowing crimson red eyes behind a horned helmet, clawed gauntlets dripping blood, dark crimson cape/cloak, blood pooling at feet"

# Common style instructions
STYLE = """2D game character sprite, clean cartoon illustration style like Slay the Spire.
CRITICAL REQUIREMENTS:
- Transparent/empty background (NO scenery, NO ground, NO effects behind character)
- Character only, full body visible, centered in frame
- Clean bold outlines, simple cel-shading
- Dark armor with crimson/blood-red accents and glowing red details
- 512x512 pixel image
- The character MUST match the design from the reference image (first image): dark spiked armor, horned helmet, crimson eyes, clawed gauntlets
- The STYLE must match the other reference images (2D cartoon sprite, NOT detailed painting)
- PNG with transparency"""

# Define the 3 animation sprites
SPRITES = {
    "bloodfiend_attack_1": {
        "prompt": f"""Generate a 2D game character attack animation sprite.

CHARACTER: {BLOODFIEND}

POSE: Aggressive attack pose - lunging forward with right arm extended, claws slashing. Body leaning forward aggressively, left arm pulled back. Dynamic action pose with forward momentum. Weight on front foot.

{STYLE}""",
        "ref_anim": ironclad_attack_b64,
    },
    "bloodfiend_hit": {
        "prompt": f"""Generate a 2D game character hit/hurt animation sprite.

CHARACTER: {BLOODFIEND}

POSE: Recoiling from taking damage - upper body leaning backward, arms raised defensively, head tilted back from impact. Staggering stance, one foot lifted. Pain reaction pose.

{STYLE}""",
        "ref_anim": ironclad_hit_b64,
    },
    "bloodfiend_skill": {
        "prompt": f"""Generate a 2D game character skill/casting animation sprite.

CHARACTER: {BLOODFIEND}

POSE: Channeling blood magic - arms raised or extended outward with palms open, slight crouch. Dark red energy/blood aura around hands. Casting stance, powerful and controlled. Body slightly crouched with arms extended.

{STYLE}""",
        "ref_anim": ironclad_skill_b64,
    },
}


def generate_sprite(sprite_id, sprite_info, retries=3):
    output_path = os.path.join(OUTPUT_DIR, f"{sprite_id}.png")

    # Build the multi-part request with reference images
    parts = [
        # Reference: the bloodfiend character design
        {"text": "Here is the character design reference (match this character's appearance - dark spiked armor, horned helmet, crimson eyes, claws):"},
        {"inlineData": {"mimeType": "image/png", "data": bloodfiend_b64}},
        # Reference: the style/pose reference from ironclad
        {"text": "Here is a style reference showing the exact art style to match (clean 2D cartoon sprite, transparent background, bold outlines):"},
        {"inlineData": {"mimeType": "image/png", "data": sprite_info["ref_anim"]}},
        # The actual prompt
        {"text": sprite_info["prompt"]},
    ]

    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={API_KEY}"
    payload = {
        "contents": [{"parts": parts}],
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

                        # Load, ensure RGBA, resize to 512x512
                        img = Image.open(io.BytesIO(img_data))
                        if img.mode != "RGBA":
                            img = img.convert("RGBA")
                        if img.size != (512, 512):
                            img = img.resize((512, 512), Image.LANCZOS)

                        img.save(output_path, "PNG")
                        file_size = os.path.getsize(output_path)
                        print(f"  OK {sprite_id} ({file_size // 1024}KB, {img.size})", flush=True)
                        return True

            print(f"  WARN {sprite_id}: no image in response", flush=True)
            if attempt < retries:
                wait = 3 * (attempt + 1)
                print(f"  Retrying in {wait}s...", flush=True)
                time.sleep(wait)
        except Exception as e:
            if attempt < retries:
                wait = 3 * (attempt + 1)
                print(f"  RETRY {sprite_id}: {e} (waiting {wait}s)", flush=True)
                time.sleep(wait)
            else:
                print(f"  FAIL {sprite_id}: {e}", flush=True)
                return False

    return False


if __name__ == "__main__":
    # Allow generating a subset
    if len(sys.argv) > 1:
        subset = sys.argv[1:]
        sprites_to_gen = {k: v for k, v in SPRITES.items() if k in subset}
    else:
        sprites_to_gen = SPRITES

    total = len(sprites_to_gen)
    done = 0
    failed = []

    print(f"Generating {total} Blood Fiend animation sprites...")
    print(f"Using model: {MODEL}")
    print()

    for sprite_id, sprite_info in sprites_to_gen.items():
        print(f"[{done + 1}/{total}] Generating {sprite_id}...")
        success = generate_sprite(sprite_id, sprite_info)
        if not success:
            failed.append(sprite_id)
        done += 1
        if done < total:
            time.sleep(2)  # Rate limit between requests

    print(f"\nDone! {done - len(failed)}/{total} succeeded, {len(failed)} failed")
    if failed:
        print(f"Failed: {', '.join(failed)}")
        sys.exit(1)
