#!/usr/bin/env python3
"""Regenerate Blood Fiend idle sprite with WIDER stance.

Current bloodfiend.png only fills ~49% canvas width.
Target: 70-85% width (matching ironclad at ~89%).
"""

import json, urllib.request, base64, os, time, sys, shutil
from PIL import Image
import numpy as np
import io

# Load Gemini config
with open(os.path.expanduser('~/.genimg/config.json')) as f:
    config = json.load(f)
gemini = config['providers']['gemini']
API_KEY = gemini['api_key']
MODEL = "gemini-2.5-flash-image"

OUTPUT_PATH = "assets/img/bloodfiend.png"
BACKUP_PATH = "assets/img/bloodfiend_narrow_backup.png"

# Load reference images
def load_image_as_base64(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")

# Load ironclad as width reference
ironclad_b64 = load_image_as_base64("assets/img/ironclad.png")
# Load original narrow bloodfiend for character design reference
ref_path = BACKUP_PATH if os.path.exists(BACKUP_PATH) else OUTPUT_PATH
bloodfiend_b64 = load_image_as_base64(ref_path)

PROMPT = """Generate a single 2D game character sprite. SOLID BRIGHT GREEN (#00FF00) background color filling the entire canvas behind the character.

CHARACTER: Dark vampire blood warrior. Heavy dark crimson spiked plate armor. Two large demon horns curving upward from helmet. Glowing crimson red eyes behind visor. Large clawed gauntlets. Flowing dark red cape draped from shoulders, spreading outward to both sides.

COMPOSITION - CRITICALLY IMPORTANT:
- The character must be TALL - head/horns near the TOP edge, feet near the BOTTOM edge
- The character must be WIDE - cape tips and arms reaching near LEFT and RIGHT edges
- Character fills approximately 80% of the canvas HEIGHT and 75-85% of the canvas WIDTH
- The character should have NORMAL human proportions - tall and broad, NOT squat or compressed
- Standing upright, full body from head to toe, centered in the square canvas
- Think of the character as tall as they are wide in the cape spread

POSE: Powerful idle stance facing the viewer. Legs shoulder-width apart in a stable stance. Arms held slightly away from body with clawed fingers visible. Cape/cloak flowing outward behind and to both sides, creating a wide triangular silhouette. Horns pointing upward add to height.

STYLE:
- 2D cartoon game character sprite, Slay the Spire card game aesthetic
- Clean bold BLACK outlines around every shape
- Simple cel-shading with 2-3 tones per color
- Dark crimson and blood-red color palette for armor
- Glowing red eye slits and accents
- 512x512 pixels
- SOLID GREEN #00FF00 background (important: pure bright green, not olive or muted)
- Game sprite style, clean readable silhouette

The first reference image shows the character design (dark crimson armor, horned helmet, claws, cape).
The second reference image shows a character that fills the frame well - match this coverage.

REMEMBER: Character must be TALL (fills vertical space) AND WIDE (cape spread fills horizontal space). Normal standing proportions, not compressed or squat."""


def measure_content_bounds(img):
    """Measure content fill percentages."""
    arr = np.array(img.convert("RGBA"))
    alpha = arr[:, :, 3]
    rows = np.any(alpha > 10, axis=1)
    cols = np.any(alpha > 10, axis=0)
    if not rows.any() or not cols.any():
        return 0.0, 0.0
    rmin, rmax = np.where(rows)[0][[0, -1]]
    cmin, cmax = np.where(cols)[0][[0, -1]]
    h, w = arr.shape[:2]
    width_pct = (cmax - cmin + 1) / w * 100
    height_pct = (rmax - rmin + 1) / h * 100
    return width_pct, height_pct


def remove_background_adaptive(img):
    """Remove background by detecting the dominant corner color and removing similar pixels."""
    arr = np.array(img.convert("RGBA")).astype(np.float64)

    # Sample corners to find background color
    samples = []
    for y in [0, 1, 2, 3, 4]:
        for x in [0, 1, 2, 3, 4]:
            samples.append(arr[y, x, :3])
        for x in [-1, -2, -3, -4, -5]:
            samples.append(arr[y, x, :3])
    for y in [-1, -2, -3, -4, -5]:
        for x in [0, 1, 2, 3, 4]:
            samples.append(arr[y, x, :3])
        for x in [-1, -2, -3, -4, -5]:
            samples.append(arr[y, x, :3])

    bg_color = np.median(samples, axis=0)
    print(f"  Detected background color: RGB({bg_color[0]:.0f}, {bg_color[1]:.0f}, {bg_color[2]:.0f})")

    # Calculate color distance from background
    diff = arr[:, :, :3] - bg_color
    dist = np.sqrt(np.sum(diff ** 2, axis=2))

    # Hard threshold for definite background
    hard_threshold = 35
    # Soft threshold for anti-aliased edges
    soft_threshold = 55

    result = arr.copy()

    # Fully transparent for pixels close to bg color
    bg_mask = dist < hard_threshold
    result[bg_mask, 3] = 0

    # Partial transparency for edge pixels
    edge_mask = (dist >= hard_threshold) & (dist < soft_threshold)
    if edge_mask.any():
        edge_alpha = ((dist[edge_mask] - hard_threshold) / (soft_threshold - hard_threshold) * 255)
        result[edge_mask, 3] = edge_alpha.clip(0, 255)

    return Image.fromarray(result.astype(np.uint8))


def rescale_to_fill(img, target_width_pct=80, target_height_pct=82):
    """Rescale content to fill the target percentage of the 512x512 canvas."""
    arr = np.array(img.convert("RGBA"))
    alpha = arr[:, :, 3]
    rows = np.any(alpha > 10, axis=1)
    cols = np.any(alpha > 10, axis=0)
    if not rows.any() or not cols.any():
        return img

    rmin, rmax = np.where(rows)[0][[0, -1]]
    cmin, cmax = np.where(cols)[0][[0, -1]]

    # Crop to content with 1px padding
    content = img.crop((max(0, cmin - 1), max(0, rmin - 1),
                        min(512, cmax + 2), min(512, rmax + 2)))
    cw, ch = content.size

    # Calculate target dimensions
    target_w = int(512 * target_width_pct / 100)
    target_h = int(512 * target_height_pct / 100)

    # Scale to fit within target, maintaining aspect ratio
    scale = min(target_w / cw, target_h / ch)

    # Don't downscale if already good
    if 0.95 <= scale <= 1.05:
        return img

    new_w = int(cw * scale)
    new_h = int(ch * scale)

    print(f"  Rescaling content: {cw}x{ch} -> {new_w}x{new_h} (scale={scale:.2f})")

    content_resized = content.resize((new_w, new_h), Image.LANCZOS)

    # Place on new 512x512 canvas
    canvas = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
    x_offset = (512 - new_w) // 2
    # Bottom-align with small margin
    y_offset = 512 - new_h - 12
    canvas.paste(content_resized, (x_offset, y_offset), content_resized)

    return canvas


def generate_wide_bloodfiend(max_attempts=5):
    """Generate bloodfiend sprite, retrying until width >= 70% AND height >= 70%."""

    # Backup current sprite
    if os.path.exists(OUTPUT_PATH) and not os.path.exists(BACKUP_PATH):
        shutil.copy2(OUTPUT_PATH, BACKUP_PATH)
        print(f"Backed up current sprite to {BACKUP_PATH}")

    parts = [
        {"text": "Here is the character design reference - match this character's dark crimson armor, horned helmet, red eyes, and clawed gauntlets:"},
        {"inlineData": {"mimeType": "image/png", "data": bloodfiend_b64}},
        {"text": "Here is the WIDTH and HEIGHT reference - the new sprite must fill the frame similarly, both tall and wide:"},
        {"inlineData": {"mimeType": "image/png", "data": ironclad_b64}},
        {"text": PROMPT},
    ]

    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={API_KEY}"
    payload = {
        "contents": [{"parts": parts}],
        "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]}
    }

    best_img = None
    best_score = 0  # Combined width+height score

    for attempt in range(max_attempts):
        print(f"\n[Attempt {attempt + 1}/{max_attempts}] Generating wide Blood Fiend sprite...")

        try:
            req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                        headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=180) as resp:
                data = json.load(resp)

            for candidate in data.get("candidates", []):
                for part in candidate.get("content", {}).get("parts", []):
                    if "inlineData" in part:
                        img_data = base64.b64decode(part["inlineData"]["data"])
                        img = Image.open(io.BytesIO(img_data))

                        if img.mode != "RGBA":
                            img = img.convert("RGBA")
                        if img.size != (512, 512):
                            img = img.resize((512, 512), Image.LANCZOS)

                        # Remove background adaptively
                        img = remove_background_adaptive(img)

                        # Measure bounds
                        width_pct, height_pct = measure_content_bounds(img)
                        print(f"  Raw content: width={width_pct:.1f}%, height={height_pct:.1f}%")

                        # If proportions are off, try rescaling
                        if width_pct > 50 and height_pct > 40:
                            img = rescale_to_fill(img, target_width_pct=82, target_height_pct=85)
                            width_pct, height_pct = measure_content_bounds(img)
                            print(f"  After rescale: width={width_pct:.1f}%, height={height_pct:.1f}%")

                        score = min(width_pct, 90) + min(height_pct, 90)  # Balanced score

                        if score > best_score:
                            best_score = score
                            best_img = img.copy()
                            print(f"  New best! (score={score:.1f})")

                        if width_pct >= 70 and height_pct >= 70:
                            print(f"  Both targets met! (w={width_pct:.1f}%, h={height_pct:.1f}%)")
                            img.save(OUTPUT_PATH, "PNG")
                            print(f"  Saved to {OUTPUT_PATH}")
                            return True, width_pct, height_pct

            print(f"  No image in response or targets not met")

        except Exception as e:
            print(f"  Error: {e}")
            import traceback
            traceback.print_exc()

        if attempt < max_attempts - 1:
            wait = 5 * (attempt + 1)
            print(f"  Waiting {wait}s before retry...")
            time.sleep(wait)

    # Use best result
    if best_img is not None:
        width_pct, height_pct = measure_content_bounds(best_img)
        print(f"\nUsing best result: width={width_pct:.1f}%, height={height_pct:.1f}%")
        best_img.save(OUTPUT_PATH, "PNG")
        print(f"Saved to {OUTPUT_PATH}")
        return width_pct >= 65, width_pct, height_pct

    print("FAILED: No images generated")
    return False, 0, 0


if __name__ == "__main__":
    print("=== Blood Fiend Wide Idle Sprite Generator ===")
    print(f"Model: {MODEL}")
    print(f"Output: {OUTPUT_PATH}")
    print()

    # Measure current width/height
    current = Image.open(OUTPUT_PATH)
    w_pct, h_pct = measure_content_bounds(current)
    print(f"Current bloodfiend: width={w_pct:.1f}%, height={h_pct:.1f}%")

    # Measure ironclad reference
    ironclad = Image.open("assets/img/ironclad.png")
    iw, ih = measure_content_bounds(ironclad)
    print(f"Ironclad reference: width={iw:.1f}%, height={ih:.1f}%")
    print(f"Target: 70-85% width, 70-85% height")
    print()

    success, final_w, final_h = generate_wide_bloodfiend(max_attempts=5)

    print(f"\n{'SUCCESS' if success else 'PARTIAL'}: Final width={final_w:.1f}%, height={final_h:.1f}%")
    if not success:
        sys.exit(1)
