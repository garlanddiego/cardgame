#!/usr/bin/env python3
"""Generate ALL bloodfiend images: hero sprites + card art."""

import json, urllib.request, base64, os, time
from PIL import Image

with open(os.path.expanduser('~/.genimg/config.json')) as f:
    config = json.load(f)
gemini = config['providers']['gemini']
API_KEY = gemini['api_key']
MODEL = gemini.get('model', 'gemini-2.0-flash-exp')

REF_IMAGE = "assets/img/bloodfiend_merge_2.png"
CARD_ART_DIR = "assets/img/card_art"
os.makedirs(CARD_ART_DIR, exist_ok=True)
os.makedirs("assets/img/anim", exist_ok=True)

with open(REF_IMAGE, "rb") as f:
    ref_b64 = base64.b64encode(f.read()).decode()

HERO_STYLE = "same character, same art style, same color palette, same proportions, 512x512, dark muted background, no text, no labels, character fully visible CENTERED with margin on all sides"
S = "Slay the Spire card art style, very limited desaturated color palette with dark red and steel grey, flat cell shading, hand-painted look, simple bold composition, dark muted background, no text, no labels, no words, square format"

# ═══ HERO SPRITES ═══
HERO_POSES = {
    "assets/img/bloodfiend.png":
        f"Redraw this exact character in a STANDING IDLE pose — weight on both feet, slightly hunched forward, claws at the sides ready, menacing but still. FULL BODY visible head to feet. {HERO_STYLE}",
    "assets/img/anim/bloodfiend_attack_1.png":
        f"Redraw this character in a CLAW ATTACK pose — lunging forward with right arm extended, long wolverine claws slashing forward, left arm pulled back ready to strike next, aggressive momentum. FULL BODY visible. {HERO_STYLE}",
    "assets/img/anim/bloodfiend_skill.png":
        f"Redraw this character in a CHANNELING pose — both clawed hands raised, dark red blood energy swirling between the claws, eyes glowing intensely, standing upright gathering power. FULL BODY visible. {HERO_STYLE}",
    "assets/img/anim/bloodfiend_hit.png":
        f"Redraw this character in a HIT/RECOILING pose — upper body twisting backward from impact, one arm raised defensively, snarling in pain. FULL BODY visible. {HERO_STYLE}",
    "assets/img/bloodfiend_fallen.png":
        f"Redraw this character in a DEFEATED pose — collapsed on the ground on one side, claws splayed out, armor cracked, barely alive. FULL BODY visible. {HERO_STYLE}",
}

# ═══ CARD ART — hero-featured (different angles) ═══
HERO_CARDS = {
    "bf_frenzy_claw": f"Redraw this character from a LOW ANGLE, both arms slashing wildly with wolverine claws in a frenzied flurry, multiple claw afterimages showing rapid strikes, blood spatters flying. {S}",
    "bf_execution": f"Redraw this character from ABOVE looking down, standing over a fallen enemy, one clawed hand raised for a killing blow, dramatic shadow, executioner pose. {S}",
    "bf_blood_feast": f"Redraw this character CLOSE-UP from chest up, jaws open devouring blood energy, red glow streaming into the mouth, eyes wild with hunger, ecstatic expression. {S}",
    "bf_bloodlust": f"Redraw this character as a SILHOUETTE with arms spread wide, surrounded by a crimson aura of blood energy, eyes and armor cracks glowing bright red, power emanating outward. {S}",
    "bf_savage_strike": f"Redraw this character from a SIDE VIEW mid-leap, entire body stretched horizontally in a flying claw strike, trailing blood-red energy, pure momentum. {S}",
    "bf_desperate_duel": f"Redraw this character FACE TO FACE with a shadowy opponent, both clashing, sparks at the point of contact between claws, extreme tension, close combat. {S}",
}

# ═══ CARD ART — pure scene/object/effect (no hero) ═══
TEXT_CARDS = {
    # ATTACKS
    "bf_strike": f"a single claw mark freshly torn across dark metal, three parallel deep scratches glowing red-hot at the edges, close-up, {S}",
    "bf_crimson_slash": f"a diagonal crimson energy slash cutting through the air, blood droplets trailing the arc, vivid red against darkness, {S}",
    "bf_gore": f"a sharp bone spike impaling through a shield, cracks spreading from the impact point, blood dripping down, {S}",
    "bf_blood_whirl": f"a vortex of spinning blood energy in a circle, dark red tornado with sharp fragments inside, wide shot, {S}",
    "bf_prey_on_weakness": f"a wounded prey animal with glowing weak points visible, predator's shadow looming over it, {S}",
    "bf_exploit": f"a cracked armor piece with a glowing red weak spot exposed, a single claw tip touching the gap precisely, {S}",
    "bf_crushing_blow": f"a massive armored fist slamming down with shockwave, ground cracking beneath, overwhelming force, {S}",
    "bf_vampiric_embrace": f"two dark arms embracing a glowing red orb of life energy, blood tendrils flowing from the orb into the arms, {S}",
    "bf_leech": f"a leech-like tendril of dark blood energy attached between two points, draining glowing red life force, {S}",
    "bf_blood_rage": f"a heart on fire with dark red flames, veins pulsing with rage energy, cracking under pressure, {S}",
    "bf_blood_fang": f"two enormous wolf fangs dripping blood, crossed like an X, each fang glowing with crimson energy, {S}",
    "bf_blood_wave": f"a tidal wave of dark blood crashing forward, forming sharp shapes at the crest, overwhelming flood, {S}",
    # SKILLS
    "bf_defend": f"a battered round shield with blood runes glowing red on its surface, dented and scratched but holding, {S}",
    "bf_sanguine_shield": f"a translucent barrier made of solidified blood, crystalline red surface deflecting an incoming attack, {S}",
    "bf_blood_offering": f"a chalice overflowing with dark blood, an open wound on a wrist dripping into it, ritual offering, {S}",
    "bf_crimson_pact": f"two hands clasped together with blood flowing between them, a binding red contract seal glowing, {S}",
    "bf_sacrifice": f"a dagger plunged into an altar with blood pooling outward, dark ritual energy rising as smoke, {S}",
    "bf_bloodrage": f"shattered chains with blood dripping from broken links, rage energy exploding outward from the center, {S}",
    "bf_vital_guard": f"a beating heart encased in a protective cage of bone and dark metal, pulsing with red light, {S}",
    "bf_blood_pact": f"a scroll written in blood with a glowing red seal, dark binding contract, ominous, {S}",
    "bf_blood_rush": f"blood vessels pulsing with accelerated flow, veins glowing bright red in a dark arm, adrenaline surge, {S}",
    "bf_bloodhound": f"a spectral wolf nose sniffing a trail of blood droplets on the ground, tracking scent, ghostly, {S}",
    "bf_transfusion": f"two connected vessels with blood flowing between them through a glowing tube, one filling as other empties, {S}",
    "bf_survival_instinct": f"a pair of glowing red eyes in complete darkness, alert and watchful, survival mode activated, {S}",
    "bf_siphon_life": f"a dark hand reaching into a glowing red pool of energy, pulling life force upward in streams, draining, {S}",
    "bf_blood_mirror": f"a mirror made of dark liquid blood reflecting a distorted face, rippling surface, eerie, {S}",
    # POWERS
    "bf_sanguine_aura": f"a dark red aura radiating outward in concentric rings, pulsing energy field, blood mist particles, {S}",
    "bf_blood_scent": f"wisps of red mist curling in the air like scent trails, leading toward an unseen target, ethereal, {S}",
    "bf_blood_bond": f"two red hearts connected by pulsing blood vessels, symbiotic bond, glowing in darkness, {S}",
    "bf_crimson_rage": f"a cracked red gem exploding with crimson energy, rage incarnate, shards flying outward, {S}",
    "bf_undying_will": f"a skeleton hand clawing up from dark ground, refusing to die, faint red glow in the bones, {S}",
    "bf_blood_tithe": f"drops of blood falling upward defying gravity into a dark void above, tribute to darkness, {S}",
    "bf_hemophilia": f"blood droplets suspended in mid-air glowing like rubies, each one pulsing with stolen life, {S}",
}


def _do_generate(url_str, payload, output_path, retries=2):
    for attempt in range(retries + 1):
        try:
            req = urllib.request.Request(url_str, data=json.dumps(payload).encode(),
                                        headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = json.load(resp)
            for c in data.get("candidates", []):
                for p in c.get("content", {}).get("parts", []):
                    if "inlineData" in p:
                        img_data = base64.b64decode(p["inlineData"]["data"])
                        with open(output_path, "wb") as f:
                            f.write(img_data)
                        img = Image.open(output_path)
                        if img.size != (512, 512):
                            img = img.resize((512, 512), Image.LANCZOS)
                            img.save(output_path)
                        print(f"  OK {output_path}")
                        return True
            print(f"  No image in response")
        except Exception as e:
            print(f"  Attempt {attempt+1} failed: {e}")
            if attempt < retries:
                time.sleep(5)
    print(f"  FAILED {output_path}")
    return False


def generate_with_ref(output_path, prompt):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={API_KEY}"
    payload = {
        "contents": [{"parts": [
            {"inlineData": {"mimeType": "image/png", "data": ref_b64}},
            {"text": prompt}
        ]}],
        "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]}
    }
    return _do_generate(url, payload, output_path)


def generate_text(output_path, prompt):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={API_KEY}"
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]}
    }
    return _do_generate(url, payload, output_path)


def remove_bg(path):
    from rembg import remove as rembg_remove
    img = Image.open(path)
    out = rembg_remove(img)
    out.save(path)
    print(f"  BG_REMOVED {path}")


def flip_h(path):
    img = Image.open(path)
    img = img.transpose(Image.FLIP_LEFT_RIGHT)
    img.save(path)
    print(f"  FLIPPED {path}")


if __name__ == "__main__":
    total = len(HERO_POSES) + len(HERO_CARDS) + len(TEXT_CARDS)
    done = 0
    failed = []

    print(f"=== Generating {total} bloodfiend images ===\n")

    # Hero sprites
    print("--- Hero Sprites ---")
    for path, prompt in HERO_POSES.items():
        done += 1
        print(f"[{done}/{total}] {path}")
        if not generate_with_ref(path, prompt):
            failed.append(path)
        time.sleep(2)

    # Remove background + flip heroes to face right
    print("\n--- Post-processing hero sprites ---")
    hero_files = list(HERO_POSES.keys())
    for f in hero_files:
        if os.path.exists(f):
            remove_bg(f)
    # Flip standing, attack, skill to face right
    for f in ["assets/img/bloodfiend.png", "assets/img/anim/bloodfiend_attack_1.png", "assets/img/anim/bloodfiend_skill.png"]:
        if os.path.exists(f):
            flip_h(f)

    # Hero-featured cards
    print("\n--- Hero-featured card art ---")
    for card_id, prompt in HERO_CARDS.items():
        path = f"{CARD_ART_DIR}/{card_id}.png"
        done += 1
        print(f"[{done}/{total}] {path} (with ref)")
        if not generate_with_ref(path, prompt):
            failed.append(path)
        time.sleep(2)

    # Text-only cards
    print("\n--- Scene/effect card art ---")
    for card_id, prompt in TEXT_CARDS.items():
        path = f"{CARD_ART_DIR}/{card_id}.png"
        done += 1
        print(f"[{done}/{total}] {path}")
        if not generate_text(path, prompt):
            failed.append(path)
        time.sleep(2)

    print(f"\n=== Done: {total - len(failed)}/{total} OK ===")
    if failed:
        print("Failed:")
        for f in failed:
            print(f"  {f}")
