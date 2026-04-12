#!/usr/bin/env python3
"""Generate ALL art assets for Forger and Fire Mage characters."""

import os
import math
import random
from PIL import Image, ImageDraw, ImageFilter, ImageChops

random.seed(42)

BASE = "/Users/neojenkins/cardgame-new/assets/img"
CARD_ART = os.path.join(BASE, "card_art")
os.makedirs(CARD_ART, exist_ok=True)

# Color palettes
BG_COLOR = (18, 18, 28, 255)
FORGER_STEEL = (160, 170, 185)
FORGER_STEEL_LIGHT = (200, 210, 225)
FORGER_STEEL_DARK = (90, 95, 105)
FORGER_ORANGE = (255, 150, 40)
FORGER_AMBER = (255, 190, 60)
FORGER_EMBER = (255, 100, 20)
FORGER_BROWN = (80, 55, 35)
FORGER_BROWN_LIGHT = (120, 85, 55)

FIRE_RED = (220, 50, 30)
FIRE_ORANGE = (255, 140, 30)
FIRE_YELLOW = (255, 220, 60)
FIRE_DARK_RED = (150, 20, 10)
FIRE_GLOW = (255, 180, 80)


def draw_glow(img, cx, cy, radius, color, max_alpha=80):
    """Draw a soft glow by compositing a blurred circle onto the image.
    Creates a separate layer, draws a filled circle, blurs it, then
    alpha-composites it onto img. This avoids the stacking opacity problem."""
    r = int(radius)
    if r < 2:
        return
    # Create glow layer same size as img
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color[:3] + (max_alpha,))
    # Blur it for softness
    blur_radius = max(1, r // 2)
    glow = glow.filter(ImageFilter.GaussianBlur(radius=blur_radius))
    # Composite onto image
    img.alpha_composite(glow)


def draw_star(draw, cx, cy, outer_r, inner_r, points, color, rotation=0):
    """Draw a star shape."""
    pts = []
    for i in range(points * 2):
        angle = math.pi * i / points - math.pi / 2 + rotation
        r = outer_r if i % 2 == 0 else inner_r
        pts.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    draw.polygon(pts, fill=color)


def draw_flame(draw, cx, cy, width, height, colors=None):
    """Draw a stylized flame."""
    if colors is None:
        colors = [FIRE_RED, FIRE_ORANGE, FIRE_YELLOW]
    pts = [
        (cx - width * 0.5, cy + height * 0.3),
        (cx - width * 0.35, cy - height * 0.1),
        (cx - width * 0.15, cy - height * 0.35),
        (cx, cy - height * 0.5),
        (cx + width * 0.15, cy - height * 0.35),
        (cx + width * 0.35, cy - height * 0.1),
        (cx + width * 0.5, cy + height * 0.3),
        (cx + width * 0.2, cy + height * 0.5),
        (cx - width * 0.2, cy + height * 0.5),
    ]
    draw.polygon(pts, fill=colors[0])
    scale = 0.65
    pts2 = [(cx + (x - cx) * scale, cy + (y - cy) * scale + height * 0.1) for x, y in pts]
    draw.polygon(pts2, fill=colors[1])
    scale2 = 0.35
    pts3 = [(cx + (x - cx) * scale2, cy + (y - cy) * scale2 + height * 0.15) for x, y in pts]
    draw.polygon(pts3, fill=colors[2])


def draw_shield(draw, cx, cy, w, h, color, border_color=None):
    """Draw a shield shape."""
    pts = [
        (cx - w / 2, cy - h * 0.4),
        (cx, cy - h / 2),
        (cx + w / 2, cy - h * 0.4),
        (cx + w / 2, cy + h * 0.1),
        (cx + w * 0.3, cy + h * 0.35),
        (cx, cy + h / 2),
        (cx - w * 0.3, cy + h * 0.35),
        (cx - w / 2, cy + h * 0.1),
    ]
    draw.polygon(pts, fill=color)
    if border_color:
        draw.polygon(pts, outline=border_color, width=3)


def draw_sword_shape(draw, cx, cy, length, width, color, hilt_color=None, angle=0):
    """Draw a sword at given angle."""
    cos_a = math.cos(angle)
    sin_a = math.sin(angle)
    tip = (cx + length / 2 * cos_a, cy + length / 2 * sin_a)
    base = (cx - length * 0.15 * cos_a, cy - length * 0.15 * sin_a)
    perp_x = -sin_a * width / 2
    perp_y = cos_a * width / 2
    blade_pts = [
        tip,
        (base[0] + perp_x, base[1] + perp_y),
        (base[0] - perp_x, base[1] - perp_y),
    ]
    draw.polygon(blade_pts, fill=color)
    if hilt_color:
        hilt_start = (cx - length * 0.15 * cos_a, cy - length * 0.15 * sin_a)
        hilt_end = (cx - length * 0.3 * cos_a, cy - length * 0.3 * sin_a)
        draw.line([hilt_start, hilt_end], fill=hilt_color, width=max(3, int(width * 0.6)))
        cg_cx = hilt_start[0]
        cg_cy = hilt_start[1]
        cg_len = width * 1.5
        draw.line(
            [(cg_cx - cg_len * sin_a, cg_cy + cg_len * cos_a),
             (cg_cx + cg_len * sin_a, cg_cy - cg_len * cos_a)],
            fill=hilt_color, width=max(2, int(width * 0.4))
        )


def draw_hammer(draw, cx, cy, size, color, handle_color):
    """Draw a hammer shape."""
    draw.rectangle([cx - size * 0.06, cy - size * 0.1, cx + size * 0.06, cy + size * 0.55], fill=handle_color)
    draw.rectangle([cx - size * 0.3, cy - size * 0.25, cx + size * 0.3, cy + size * 0.05], fill=color)
    highlight = tuple(min(255, c + 40) for c in color[:3])
    draw.rectangle([cx - size * 0.28, cy - size * 0.23, cx + size * 0.28, cy - size * 0.15], fill=highlight)


def draw_anvil(draw, cx, cy, size, color):
    """Draw an anvil."""
    draw.rectangle([cx - size * 0.35, cy - size * 0.15, cx + size * 0.35, cy + size * 0.05], fill=color)
    pts_horn = [
        (cx - size * 0.35, cy - size * 0.15),
        (cx - size * 0.55, cy - size * 0.05),
        (cx - size * 0.35, cy + size * 0.05),
    ]
    draw.polygon(pts_horn, fill=color)
    darker = tuple(max(0, c - 30) for c in color[:3])
    draw.polygon([
        (cx - size * 0.3, cy + size * 0.05),
        (cx + size * 0.3, cy + size * 0.05),
        (cx + size * 0.4, cy + size * 0.3),
        (cx - size * 0.4, cy + size * 0.3),
    ], fill=darker)


def draw_lightning_bolt(draw, cx, cy, size, color):
    """Draw a lightning bolt."""
    pts = [
        (cx - size * 0.15, cy - size * 0.5),
        (cx + size * 0.2, cy - size * 0.5),
        (cx + size * 0.05, cy - size * 0.05),
        (cx + size * 0.25, cy - size * 0.05),
        (cx - size * 0.1, cy + size * 0.5),
        (cx + size * 0.05, cy + size * 0.1),
        (cx - size * 0.15, cy + size * 0.1),
    ]
    draw.polygon(pts, fill=color)


def draw_circle_pattern(draw, cx, cy, radius, color, segments=8, width=3):
    """Draw a decorative circle with segments."""
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], outline=color, width=width)
    for i in range(segments):
        angle = 2 * math.pi * i / segments
        x1 = cx + radius * 0.7 * math.cos(angle)
        y1 = cy + radius * 0.7 * math.sin(angle)
        x2 = cx + radius * math.cos(angle)
        y2 = cy + radius * math.sin(angle)
        draw.line([(x1, y1), (x2, y2)], fill=color, width=width)


def draw_sparks(draw, cx, cy, count, spread, colors):
    """Draw spark particles."""
    for _ in range(count):
        sx = cx + random.randint(-spread, spread)
        sy = cy + random.randint(-spread, spread)
        sz = random.randint(2, 5)
        c = random.choice(colors)
        draw.ellipse([sx - sz, sy - sz, sx + sz, sy + sz], fill=c)


def draw_chain_links(draw, x1, y1, x2, y2, count, color, size=8):
    """Draw chain between two points."""
    for i in range(count):
        t = i / max(1, count - 1)
        cx = x1 + (x2 - x1) * t
        cy = y1 + (y2 - y1) * t
        draw.ellipse([cx - size, cy - size, cx + size, cy + size], outline=color, width=2)


def draw_armor_plate(draw, cx, cy, w, h, color, highlight):
    """Draw an armor plate with highlights."""
    pts = [
        (cx - w/2, cy - h/2),
        (cx + w/2, cy - h/2),
        (cx + w/2 - w*0.1, cy + h/2),
        (cx - w/2 + w*0.1, cy + h/2),
    ]
    draw.polygon(pts, fill=color)
    draw.line([(cx - w*0.3, cy - h*0.3), (cx + w*0.3, cy - h*0.3)], fill=highlight, width=2)


def draw_rune(draw, cx, cy, size, color):
    """Draw a simple rune symbol."""
    s = size
    draw.line([(cx, cy - s), (cx, cy + s)], fill=color, width=3)
    draw.line([(cx - s*0.5, cy - s*0.3), (cx + s*0.5, cy + s*0.3)], fill=color, width=2)
    draw.line([(cx - s*0.5, cy + s*0.3), (cx + s*0.5, cy - s*0.3)], fill=color, width=2)
    draw.ellipse([cx - s*0.3, cy - s*0.3, cx + s*0.3, cy + s*0.3], outline=color, width=2)


# ============================================================
# CHARACTER SPRITES
# ============================================================

def generate_forger():
    """Generate the Forger character sprite (512x512)."""
    img = Image.new("RGBA", (512, 512), BG_COLOR)
    draw = ImageDraw.Draw(img)

    # Ground shadow
    draw.ellipse([140, 440, 370, 490], fill=(10, 10, 15, 180))

    # Forge glow from below (subtle)
    draw_glow(img, 256, 480, 160, FORGER_ORANGE, 35)

    # Legs - armored boots
    draw.rectangle([195, 380, 235, 450], fill=FORGER_STEEL_DARK)
    draw.rectangle([275, 380, 315, 450], fill=FORGER_STEEL_DARK)
    # Knee guards
    draw.ellipse([190, 365, 240, 395], fill=FORGER_STEEL)
    draw.ellipse([270, 365, 320, 395], fill=FORGER_STEEL)

    # Body - armored torso
    body_pts = [
        (200, 370), (180, 240), (200, 190), (310, 190), (330, 240), (310, 370)
    ]
    draw.polygon(body_pts, fill=FORGER_STEEL_DARK)
    # Chest plate
    chest_pts = [
        (210, 350), (195, 250), (215, 210), (295, 210), (315, 250), (300, 350)
    ]
    draw.polygon(chest_pts, fill=FORGER_STEEL)
    # Center line on chest
    draw.line([(255, 220), (255, 340)], fill=FORGER_STEEL_LIGHT, width=2)
    # Chest plate highlight
    draw.polygon([
        (220, 250), (255, 220), (290, 250), (280, 270), (230, 270)
    ], fill=FORGER_STEEL_LIGHT)

    # Belt with forge emblem
    draw.rectangle([195, 340, 315, 365], fill=FORGER_BROWN)
    draw.rectangle([235, 343, 275, 362], fill=FORGER_AMBER)
    draw_flame(draw, 255, 352, 20, 15, [FORGER_EMBER, FORGER_ORANGE, FORGER_AMBER])

    # Arms
    # Left arm (holding hammer down)
    draw.polygon([(180, 200), (155, 210), (135, 310), (155, 320), (175, 310), (195, 210)], fill=FORGER_STEEL_DARK)
    # Left shoulder pad
    draw.ellipse([160, 185, 210, 225], fill=FORGER_STEEL)
    draw.ellipse([165, 190, 205, 220], fill=FORGER_STEEL_LIGHT)

    # Right arm (raised with hammer)
    draw.polygon([(310, 200), (340, 180), (365, 120), (380, 115), (375, 135), (350, 200), (325, 215)], fill=FORGER_STEEL_DARK)
    # Right shoulder pad
    draw.ellipse([295, 185, 345, 225], fill=FORGER_STEEL)
    draw.ellipse([300, 190, 340, 220], fill=FORGER_STEEL_LIGHT)

    # Hammer in right hand
    draw.line([(370, 120), (400, 60)], fill=FORGER_BROWN_LIGHT, width=8)
    draw.rectangle([375, 35, 435, 75], fill=FORGER_STEEL)
    draw.rectangle([378, 38, 432, 50], fill=FORGER_STEEL_LIGHT)
    draw_glow(img, 405, 55, 25, FORGER_ORANGE, 50)

    # Neck
    draw.rectangle([240, 175, 270, 195], fill=FORGER_STEEL_DARK)

    # Head/Helmet
    draw.ellipse([220, 120, 290, 180], fill=FORGER_STEEL)
    draw.rectangle([233, 148, 277, 158], fill=(20, 20, 30, 255))
    draw.ellipse([240, 150, 252, 156], fill=FORGER_ORANGE)
    draw.ellipse([258, 150, 270, 156], fill=FORGER_ORANGE)
    draw.polygon([(255, 100), (248, 125), (262, 125)], fill=FORGER_AMBER)
    draw.line([(255, 105), (255, 170)], fill=FORGER_STEEL_LIGHT, width=3)

    # Forge sparks around hammer
    spark_colors = [FORGER_ORANGE, FORGER_AMBER, FORGER_EMBER, (255, 255, 200)]
    draw_sparks(draw, 405, 50, 15, 40, spark_colors)

    # Subtle ember particles floating
    for _ in range(20):
        ex = random.randint(150, 380)
        ey = random.randint(80, 420)
        es = random.randint(1, 3)
        ea = random.randint(60, 180)
        ec = random.choice(spark_colors)
        draw.ellipse([ex - es, ey - es, ex + es, ey + es], fill=ec[:3] + (ea,))

    img.save(os.path.join(BASE, "forger.png"))
    print("Generated forger.png")


def generate_forger_fallen():
    """Generate fallen Forger sprite."""
    img = Image.new("RGBA", (512, 512), BG_COLOR)
    draw = ImageDraw.Draw(img)

    # Ground shadow
    draw.ellipse([100, 350, 420, 420], fill=(10, 10, 15, 200))

    # Collapsed body
    draw.polygon([
        (150, 320), (170, 280), (350, 300), (360, 340), (340, 370), (160, 360)
    ], fill=(60, 63, 70, 255))

    # Chest plate dimmed
    draw.polygon([
        (170, 310), (180, 285), (330, 300), (340, 330), (325, 350), (175, 345)
    ], fill=(100, 105, 115, 255))

    # Helmet on ground
    draw.ellipse([130, 270, 190, 320], fill=(100, 105, 115, 255))
    draw.rectangle([140, 288, 180, 296], fill=(20, 20, 30, 255))

    # Arms sprawled
    draw.polygon([(170, 300), (120, 340), (110, 360), (130, 370), (150, 350), (175, 320)], fill=(60, 63, 70, 255))
    draw.polygon([(340, 310), (390, 330), (410, 360), (395, 375), (370, 350), (340, 330)], fill=(60, 63, 70, 255))

    # Legs
    draw.rectangle([310, 340, 340, 410], fill=(55, 58, 65, 255))
    draw.rectangle([350, 340, 380, 400], fill=(55, 58, 65, 255))

    # Hammer fallen nearby
    draw.line([(380, 350), (430, 310)], fill=(80, 55, 35, 200), width=6)
    draw.rectangle([420, 290, 460, 320], fill=(100, 105, 115, 200))

    # Dying ember glow (very faint)
    draw_glow(img, 255, 330, 50, (255, 100, 20), 15)

    # A few fading sparks
    for _ in range(5):
        sx = random.randint(180, 380)
        sy = random.randint(250, 380)
        draw.ellipse([sx - 1, sy - 1, sx + 1, sy + 1], fill=(255, 150, 40, 60))

    img.save(os.path.join(BASE, "forger_fallen.png"))
    print("Generated forger_fallen.png")


def generate_fire_mage():
    """Generate Fire Mage character sprite (512x512)."""
    img = Image.new("RGBA", (512, 512), BG_COLOR)
    draw = ImageDraw.Draw(img)

    # Ground shadow
    draw.ellipse([150, 440, 360, 490], fill=(10, 10, 15, 180))

    # Fire aura glow (subtle)
    draw_glow(img, 256, 300, 150, FIRE_DARK_RED, 25)

    # Robe bottom (flowing)
    robe_pts = [
        (170, 350), (160, 460), (140, 470), (180, 465), (220, 460),
        (256, 455), (290, 460), (330, 465), (370, 470), (350, 460), (340, 350)
    ]
    draw.polygon(robe_pts, fill=(120, 30, 15, 255))
    draw.line([(200, 360), (190, 460)], fill=(90, 20, 10, 255), width=2)
    draw.line([(256, 350), (256, 455)], fill=(150, 40, 20, 255), width=2)
    draw.line([(310, 360), (320, 460)], fill=(90, 20, 10, 255), width=2)

    # Torso robe
    draw.polygon([
        (195, 350), (185, 220), (205, 190), (305, 190), (325, 220), (315, 350)
    ], fill=(140, 35, 18, 255))

    # Robe collar/neckline
    draw.polygon([
        (220, 200), (255, 185), (290, 200), (285, 215), (255, 205), (225, 215)
    ], fill=(160, 45, 25, 255))

    # Robe trim (golden/orange)
    draw.line([(195, 350), (185, 220)], fill=FIRE_ORANGE, width=2)
    draw.line([(315, 350), (325, 220)], fill=FIRE_ORANGE, width=2)
    draw.line([(255, 205), (255, 350)], fill=FIRE_ORANGE, width=2)

    # Fire rune on chest
    draw.ellipse([235, 240, 275, 280], outline=FIRE_ORANGE, width=2)
    draw_flame(draw, 255, 255, 20, 20, [FIRE_RED, FIRE_ORANGE, FIRE_YELLOW])

    # Left arm (pointing outward with fire)
    draw.polygon([
        (185, 210), (145, 230), (110, 280), (100, 275), (130, 220), (175, 200)
    ], fill=(130, 32, 16, 255))
    # Left hand fire
    draw_flame(draw, 95, 265, 50, 70, [FIRE_RED, FIRE_ORANGE, FIRE_YELLOW])
    draw_glow(img, 95, 265, 45, FIRE_ORANGE, 40)
    draw_sparks(draw, 95, 240, 8, 30, [FIRE_YELLOW, FIRE_ORANGE, (255, 255, 200)])

    # Right arm (raised with fire)
    draw.polygon([
        (325, 210), (355, 195), (380, 140), (395, 135), (385, 155), (360, 210), (330, 225)
    ], fill=(130, 32, 16, 255))
    # Right hand fire
    draw_flame(draw, 390, 120, 60, 80, [FIRE_RED, FIRE_ORANGE, FIRE_YELLOW])
    draw_glow(img, 390, 120, 50, FIRE_ORANGE, 45)
    draw_sparks(draw, 390, 95, 10, 35, [FIRE_YELLOW, FIRE_ORANGE, (255, 255, 200)])

    # Head
    draw.ellipse([228, 130, 282, 185], fill=(200, 150, 120, 255))
    draw.ellipse([240, 152, 252, 160], fill=FIRE_ORANGE)
    draw.ellipse([258, 152, 270, 160], fill=FIRE_ORANGE)
    draw_glow(img, 246, 156, 8, FIRE_ORANGE, 30)
    draw_glow(img, 264, 156, 8, FIRE_ORANGE, 30)
    draw.line([(248, 170), (262, 170)], fill=(160, 100, 80, 255), width=1)

    # Hair (fiery)
    hair_pts = [
        (225, 145), (230, 110), (240, 100), (255, 90), (270, 100), (280, 110), (285, 145)
    ]
    draw.polygon(hair_pts, fill=FIRE_RED)
    draw_flame(draw, 245, 105, 25, 35, [FIRE_RED, FIRE_ORANGE, FIRE_YELLOW])
    draw_flame(draw, 265, 100, 20, 30, [FIRE_RED, FIRE_ORANGE, FIRE_YELLOW])
    draw_flame(draw, 255, 95, 15, 25, [FIRE_ORANGE, FIRE_YELLOW, (255, 255, 200)])

    # Floating fire particles
    for _ in range(25):
        fx = random.randint(100, 420)
        fy = random.randint(60, 440)
        fs = random.randint(1, 4)
        fa = random.randint(40, 160)
        fc = random.choice([FIRE_RED, FIRE_ORANGE, FIRE_YELLOW, (255, 200, 100)])
        draw.ellipse([fx - fs, fy - fs, fx + fs, fy + fs], fill=fc[:3] + (fa,))

    img.save(os.path.join(BASE, "fire_mage.png"))
    print("Generated fire_mage.png")


def generate_fire_mage_fallen():
    """Generate fallen Fire Mage sprite."""
    img = Image.new("RGBA", (512, 512), BG_COLOR)
    draw = ImageDraw.Draw(img)

    # Ground shadow
    draw.ellipse([100, 340, 420, 410], fill=(10, 10, 15, 200))

    # Collapsed robe
    draw.polygon([
        (140, 310), (130, 370), (120, 400), (400, 390), (390, 350), (370, 310)
    ], fill=(80, 20, 10, 255))

    # Robe folds
    draw.line([(200, 320), (190, 390)], fill=(60, 15, 8, 255), width=2)
    draw.line([(300, 315), (310, 385)], fill=(60, 15, 8, 255), width=2)

    # Head/face on ground
    draw.ellipse([125, 280, 170, 320], fill=(160, 120, 95, 200))
    draw.line([(137, 298), (145, 298)], fill=(100, 60, 40, 200), width=1)
    draw.line([(150, 298), (158, 298)], fill=(100, 60, 40, 200), width=1)

    # Arms sprawled
    draw.polygon([(160, 320), (110, 350), (100, 370), (115, 375), (135, 355), (165, 335)], fill=(80, 20, 10, 255))
    draw.polygon([(360, 320), (400, 340), (420, 370), (405, 380), (385, 355), (355, 335)], fill=(80, 20, 10, 255))

    # Dying embers (very faint)
    draw_glow(img, 255, 350, 40, FIRE_DARK_RED, 12)

    # A few dying sparks
    for _ in range(4):
        sx = random.randint(150, 380)
        sy = random.randint(300, 380)
        draw.ellipse([sx - 1, sy - 1, sx + 1, sy + 1], fill=(200, 80, 20, 40))

    img.save(os.path.join(BASE, "fire_mage_fallen.png"))
    print("Generated fire_mage_fallen.png")


def generate_greatsword():
    """Generate the Greatsword entity (256x512)."""
    img = Image.new("RGBA", (256, 512), BG_COLOR)
    draw = ImageDraw.Draw(img)

    # Ember glow behind sword (subtle)
    draw_glow(img, 128, 220, 80, FORGER_ORANGE, 25)

    # Blade
    blade_pts = [
        (128, 30),
        (100, 80),
        (95, 320),
        (105, 340),
        (151, 340),
        (161, 320),
        (156, 80),
    ]
    draw.polygon(blade_pts, fill=FORGER_STEEL)

    # Blade center fuller (groove)
    draw.polygon([
        (128, 60),
        (118, 90),
        (115, 310),
        (120, 330),
        (136, 330),
        (141, 310),
        (138, 90),
    ], fill=FORGER_STEEL_DARK)

    # Blade edge highlights
    draw.line([(100, 80), (95, 320)], fill=FORGER_STEEL_LIGHT, width=2)
    draw.line([(156, 80), (161, 320)], fill=FORGER_STEEL_LIGHT, width=2)
    draw.line([(128, 35), (100, 80)], fill=FORGER_STEEL_LIGHT, width=2)
    draw.line([(128, 35), (156, 80)], fill=FORGER_STEEL_LIGHT, width=2)

    # Ember veins on blade
    draw.line([(115, 150), (128, 180), (140, 150)], fill=FORGER_EMBER[:3] + (120,), width=2)
    draw.line([(118, 220), (128, 250), (138, 220)], fill=FORGER_EMBER[:3] + (100,), width=2)
    draw_glow(img, 128, 180, 15, FORGER_EMBER, 20)
    draw_glow(img, 128, 240, 15, FORGER_EMBER, 18)

    # Cross guard
    draw.polygon([
        (55, 340), (55, 360), (200, 360), (200, 340),
    ], fill=FORGER_AMBER)
    draw.polygon([(60, 342), (60, 358), (75, 358), (75, 342)], fill=FORGER_ORANGE)
    draw.polygon([(181, 342), (181, 358), (196, 358), (196, 342)], fill=FORGER_ORANGE)
    draw.ellipse([118, 342, 138, 358], fill=FORGER_EMBER)
    draw_glow(img, 128, 350, 10, FORGER_AMBER, 40)

    # Handle/Grip
    draw.rectangle([115, 360, 141, 440], fill=FORGER_BROWN)
    for y in range(365, 435, 10):
        draw.line([(115, y), (141, y + 5)], fill=FORGER_BROWN_LIGHT, width=2)

    # Pommel
    draw.ellipse([110, 435, 146, 465], fill=FORGER_STEEL)
    draw.ellipse([118, 442, 138, 458], fill=FORGER_AMBER)
    draw_glow(img, 128, 450, 8, FORGER_ORANGE, 35)

    # Floating ember particles
    spark_colors = [FORGER_ORANGE, FORGER_AMBER, FORGER_EMBER, (255, 255, 200)]
    for _ in range(15):
        sx = random.randint(70, 186)
        sy = random.randint(50, 350)
        ss = random.randint(1, 3)
        sa = random.randint(50, 180)
        sc = random.choice(spark_colors)
        draw.ellipse([sx - ss, sy - ss, sx + ss, sy + ss], fill=sc[:3] + (sa,))

    img.save(os.path.join(BASE, "greatsword.png"))
    print("Generated greatsword.png")


# ============================================================
# CARD ART GENERATION
# ============================================================

def make_card(size=256, palette="forger"):
    """Create a card image + draw context. Returns (img, draw)."""
    img = Image.new("RGBA", (size, size), BG_COLOR)
    draw = ImageDraw.Draw(img)
    return img, draw


# ---- Forger Attack Cards ----

def gen_fg_strike():
    img, draw = make_card()
    draw_sword_shape(draw, 128, 140, 180, 20, FORGER_STEEL, FORGER_BROWN_LIGHT, -0.3)
    draw_glow(img, 180, 90, 30, FORGER_ORANGE, 50)
    draw_sparks(draw, 180, 90, 6, 25, [FORGER_AMBER, (255, 255, 200)])
    draw.arc([40, 30, 220, 200], 200, 340, fill=FORGER_STEEL_LIGHT, width=3)
    img.save(os.path.join(CARD_ART, "fg_strike.png"))

def gen_fg_sword_crash():
    img, draw = make_card()
    draw_sword_shape(draw, 100, 128, 160, 18, FORGER_STEEL, FORGER_BROWN_LIGHT, 0.5)
    draw_sword_shape(draw, 156, 128, 160, 18, FORGER_STEEL_LIGHT, FORGER_BROWN_LIGHT, -0.5)
    draw_glow(img, 128, 110, 35, FORGER_AMBER, 60)
    draw_sparks(draw, 128, 110, 12, 35, [FORGER_ORANGE, FORGER_AMBER, (255, 255, 200)])
    for angle in range(0, 360, 45):
        rad = math.radians(angle)
        draw.line([(128 + 20 * math.cos(rad), 110 + 20 * math.sin(rad)),
                    (128 + 50 * math.cos(rad), 110 + 50 * math.sin(rad))],
                   fill=FORGER_AMBER, width=2)
    img.save(os.path.join(CARD_ART, "fg_sword_crash.png"))

def gen_fg_riposte_strike():
    img, draw = make_card()
    draw_shield(draw, 100, 140, 80, 100, FORGER_STEEL_DARK, FORGER_STEEL_LIGHT)
    draw_sword_shape(draw, 160, 120, 150, 16, FORGER_STEEL_LIGHT, FORGER_BROWN_LIGHT, -0.6)
    for i in range(4):
        y = 90 + i * 20
        draw.line([(170, y), (220, y - 10)], fill=FORGER_STEEL_LIGHT[:3] + (120,), width=1)
    draw_glow(img, 200, 80, 20, FORGER_ORANGE, 40)
    img.save(os.path.join(CARD_ART, "fg_riposte_strike.png"))

def gen_fg_shield_bash():
    img, draw = make_card()
    draw_shield(draw, 128, 130, 120, 140, FORGER_STEEL, FORGER_AMBER)
    draw_glow(img, 128, 130, 40, FORGER_ORANGE, 35)
    for i in range(5):
        x = 50 + i * 8
        draw.line([(x, 80), (x - 20, 180)], fill=FORGER_STEEL_LIGHT[:3] + (80,), width=2)
    draw_sparks(draw, 128, 100, 8, 40, [FORGER_AMBER, (255, 255, 200)])
    draw.ellipse([108, 110, 148, 150], outline=FORGER_AMBER, width=3)
    img.save(os.path.join(CARD_ART, "fg_shield_bash.png"))

def gen_fg_forge_slam():
    img, draw = make_card()
    draw_hammer(draw, 128, 100, 120, FORGER_STEEL, FORGER_BROWN_LIGHT)
    draw.line([(50, 200), (206, 200)], fill=FORGER_STEEL_DARK, width=4)
    for angle in [-30, -15, 0, 15, 30]:
        rad = math.radians(angle + 90)
        draw.line([(128, 200), (128 + 60 * math.cos(rad), 200 + 60 * math.sin(rad))],
                   fill=FORGER_ORANGE, width=2)
    draw_glow(img, 128, 200, 45, FORGER_ORANGE, 45)
    draw_sparks(draw, 128, 195, 10, 50, [FORGER_AMBER, FORGER_ORANGE, (255, 255, 200)])
    img.save(os.path.join(CARD_ART, "fg_forge_slam.png"))

def gen_fg_greatsword_cleave():
    img, draw = make_card()
    draw_sword_shape(draw, 128, 128, 220, 28, FORGER_STEEL, FORGER_AMBER, -0.2)
    draw.arc([10, 20, 250, 240], 180, 350, fill=FORGER_AMBER, width=4)
    draw.arc([20, 30, 240, 230], 185, 345, fill=FORGER_ORANGE[:3] + (120,), width=2)
    draw_glow(img, 200, 70, 25, FORGER_EMBER, 40)
    draw_sparks(draw, 60, 180, 6, 30, [FORGER_ORANGE, FORGER_AMBER])
    img.save(os.path.join(CARD_ART, "fg_greatsword_cleave.png"))

def gen_fg_tempered_strike():
    img, draw = make_card()
    draw_sword_shape(draw, 128, 130, 180, 20, FORGER_STEEL, FORGER_BROWN_LIGHT, -0.4)
    draw_glow(img, 160, 90, 30, FORGER_ORANGE, 35)
    draw_glow(img, 140, 110, 22, FORGER_AMBER, 30)
    for i in range(3):
        y_off = i * 15
        draw.arc([90 + y_off, 70 + y_off, 170 + y_off, 120 + y_off], 0, 180, fill=FORGER_ORANGE[:3] + (60,), width=2)
    img.save(os.path.join(CARD_ART, "fg_tempered_strike.png"))

def gen_fg_magnetic_edge():
    img, draw = make_card()
    draw_sword_shape(draw, 128, 130, 170, 18, FORGER_STEEL_LIGHT, FORGER_BROWN_LIGHT, -0.3)
    for r in [40, 60, 80]:
        draw.arc([128 - r, 100 - r, 128 + r, 100 + r], 220, 320, fill=(100, 150, 255, 100), width=2)
    for _ in range(6):
        mx = random.randint(60, 200)
        my = random.randint(60, 200)
        ms = random.randint(3, 8)
        draw.rectangle([mx, my, mx + ms, my + int(ms * 0.5)], fill=FORGER_STEEL_LIGHT)
    draw_glow(img, 128, 100, 22, (100, 150, 255), 30)
    img.save(os.path.join(CARD_ART, "fg_magnetic_edge.png"))

def gen_fg_molten_core():
    img, draw = make_card()
    draw_glow(img, 128, 128, 70, FORGER_EMBER, 30)
    draw.ellipse([78, 78, 178, 178], fill=FORGER_EMBER)
    draw.ellipse([88, 88, 168, 168], fill=FORGER_ORANGE)
    draw.ellipse([103, 103, 153, 153], fill=FORGER_AMBER)
    draw.ellipse([113, 113, 143, 143], fill=(255, 255, 200))
    for angle in range(0, 360, 40):
        rad = math.radians(angle)
        draw.line([(128, 128), (128 + 55 * math.cos(rad), 128 + 55 * math.sin(rad))],
                   fill=FORGER_AMBER[:3] + (150,), width=2)
    for i in range(3):
        dx = 100 + i * 28
        draw.ellipse([dx - 4, 180, dx + 4, 195], fill=FORGER_ORANGE)
        draw.line([(dx, 178), (dx, 188)], fill=FORGER_EMBER, width=3)
    img.save(os.path.join(CARD_ART, "fg_molten_core.png"))

def gen_fg_hardened_blade():
    img, draw = make_card()
    draw_sword_shape(draw, 128, 128, 200, 30, FORGER_STEEL_DARK, FORGER_BROWN_LIGHT, -0.3)
    hard_color = (180, 210, 240)
    draw.line([(170, 55), (200, 170)], fill=hard_color, width=3)
    draw_glow(img, 185, 80, 15, hard_color, 30)
    for _ in range(4):
        cx2 = random.randint(150, 200)
        cy2 = random.randint(60, 160)
        draw_star(draw, cx2, cy2, 6, 3, 4, hard_color[:3] + (100,))
    img.save(os.path.join(CARD_ART, "fg_hardened_blade.png"))

def gen_fg_reforged_edge():
    img, draw = make_card()
    draw.polygon([(60, 80), (80, 70), (120, 140), (110, 150)], fill=FORGER_STEEL)
    draw.polygon([(140, 110), (200, 80), (210, 90), (150, 160)], fill=FORGER_STEEL)
    draw_flame(draw, 128, 130, 50, 60, [FORGER_EMBER, FORGER_ORANGE, FORGER_AMBER])
    draw_glow(img, 128, 130, 35, FORGER_ORANGE, 40)
    draw_anvil(draw, 128, 200, 100, FORGER_STEEL_DARK)
    draw_sparks(draw, 128, 120, 8, 40, [FORGER_AMBER, (255, 255, 200)])
    img.save(os.path.join(CARD_ART, "fg_reforged_edge.png"))

def gen_fg_eruption_strike():
    img, draw = make_card()
    draw_sword_shape(draw, 128, 90, 160, 22, FORGER_STEEL, FORGER_BROWN_LIGHT, -math.pi / 4)
    draw.line([(40, 200), (216, 200)], fill=FORGER_STEEL_DARK, width=3)
    for i in range(5):
        x = 80 + i * 24
        h = random.randint(30, 70)
        draw_flame(draw, x, 200 - h // 2, 20, h, [FORGER_EMBER, FORGER_ORANGE, FORGER_AMBER])
    draw_glow(img, 128, 180, 50, FORGER_EMBER, 30)
    for _ in range(6):
        rx = random.randint(60, 200)
        ry = random.randint(120, 190)
        rs = random.randint(4, 10)
        draw.polygon([(rx, ry - rs), (rx + rs, ry), (rx, ry + int(rs * 0.5)), (rx - rs, ry)], fill=FORGER_STEEL_DARK)
    img.save(os.path.join(CARD_ART, "fg_eruption_strike.png"))

def gen_fg_blade_storm():
    img, draw = make_card()
    for angle_deg in range(0, 360, 60):
        angle = math.radians(angle_deg)
        cx2 = 128 + 50 * math.cos(angle)
        cy2 = 128 + 50 * math.sin(angle)
        draw_sword_shape(draw, cx2, cy2, 80, 10, FORGER_STEEL_LIGHT, None, angle + math.pi / 4)
    draw_glow(img, 128, 128, 30, FORGER_AMBER, 45)
    draw.ellipse([108, 108, 148, 148], outline=FORGER_ORANGE, width=3)
    draw.arc([48, 48, 208, 208], 0, 360, fill=FORGER_STEEL_LIGHT[:3] + (80,), width=2)
    draw.arc([68, 68, 188, 188], 0, 360, fill=FORGER_AMBER[:3] + (60,), width=2)
    draw_sparks(draw, 128, 128, 10, 80, [FORGER_AMBER, FORGER_ORANGE, (255, 255, 200)])
    img.save(os.path.join(CARD_ART, "fg_blade_storm.png"))


# ---- Forger Skill Cards ----

def gen_fg_defend():
    img, draw = make_card()
    draw_shield(draw, 128, 128, 140, 170, FORGER_STEEL, FORGER_STEEL_LIGHT)
    draw_hammer(draw, 128, 115, 50, FORGER_AMBER, FORGER_BROWN)
    draw_glow(img, 128, 128, 40, FORGER_STEEL_LIGHT, 18)
    img.save(os.path.join(CARD_ART, "fg_defend.png"))

def gen_fg_delay_charge():
    img, draw = make_card()
    draw.polygon([(90, 60), (166, 60), (136, 128), (166, 196), (90, 196), (120, 128)], fill=FORGER_STEEL_DARK, outline=FORGER_STEEL_LIGHT)
    draw.polygon([(100, 70), (156, 70), (135, 118)], fill=FORGER_AMBER[:3] + (80,))
    draw.polygon([(100, 186), (156, 186), (121, 138)], fill=FORGER_ORANGE)
    draw_glow(img, 128, 128, 22, FORGER_ORANGE, 30)
    draw_circle_pattern(draw, 128, 128, 100, FORGER_STEEL_LIGHT[:3] + (60,), 12, 1)
    img.save(os.path.join(CARD_ART, "fg_delay_charge.png"))

def gen_fg_sharpen():
    img, draw = make_card()
    draw.polygon([(60, 180), (80, 160), (200, 140), (210, 160), (200, 180), (70, 195)], fill=(120, 120, 110))
    draw_sword_shape(draw, 140, 120, 170, 16, FORGER_STEEL_LIGHT, FORGER_BROWN_LIGHT, -0.2)
    draw_sparks(draw, 140, 155, 10, 30, [FORGER_AMBER, FORGER_ORANGE, (255, 255, 200)])
    draw_glow(img, 140, 155, 18, FORGER_AMBER, 35)
    draw.line([(170, 65), (210, 140)], fill=(255, 255, 255, 180), width=2)
    img.save(os.path.join(CARD_ART, "fg_sharpen.png"))

def gen_fg_forge_armor():
    img, draw = make_card()
    draw_anvil(draw, 128, 180, 120, FORGER_STEEL_DARK)
    draw_armor_plate(draw, 128, 140, 80, 60, FORGER_STEEL, FORGER_STEEL_LIGHT)
    draw_flame(draw, 128, 80, 80, 80, [FORGER_EMBER, FORGER_ORANGE, FORGER_AMBER])
    draw_glow(img, 128, 100, 35, FORGER_ORANGE, 30)
    draw_sparks(draw, 128, 130, 6, 30, [FORGER_AMBER, (255, 255, 200)])
    img.save(os.path.join(CARD_ART, "fg_forge_armor.png"))

def gen_fg_impervious_wall():
    img, draw = make_card()
    for row in range(3):
        for col in range(3):
            x = 48 + col * 60
            y = 48 + row * 65
            draw_shield(draw, x + 30, y + 30, 50, 60, FORGER_STEEL, FORGER_STEEL_LIGHT)
    draw_glow(img, 128, 128, 50, FORGER_AMBER, 18)
    img.save(os.path.join(CARD_ART, "fg_impervious_wall.png"))

def gen_fg_block_transfer():
    img, draw = make_card()
    draw_shield(draw, 90, 128, 80, 100, FORGER_STEEL, FORGER_STEEL_LIGHT)
    draw.polygon([(160, 128), (200, 108), (200, 148)], fill=FORGER_AMBER)
    draw.rectangle([140, 120, 165, 136], fill=FORGER_AMBER)
    draw_shield(draw, 210, 128, 50, 60, FORGER_STEEL_DARK, FORGER_STEEL)
    draw_glow(img, 180, 128, 20, FORGER_ORANGE, 28)
    img.save(os.path.join(CARD_ART, "fg_block_transfer.png"))

def gen_fg_summon_sword():
    img, draw = make_card()
    draw_circle_pattern(draw, 128, 128, 90, FORGER_AMBER, 8, 2)
    draw.ellipse([58, 58, 198, 198], outline=FORGER_ORANGE, width=2)
    draw_sword_shape(draw, 128, 100, 200, 22, FORGER_STEEL_LIGHT, FORGER_AMBER, -math.pi / 2)
    draw_glow(img, 128, 128, 45, FORGER_ORANGE, 25)
    draw_sparks(draw, 128, 80, 8, 40, [FORGER_AMBER, FORGER_ORANGE, (255, 255, 200)])
    for i in range(4):
        angle = math.pi / 2 * i + math.pi / 4
        rx = 128 + 75 * math.cos(angle)
        ry = 128 + 75 * math.sin(angle)
        draw_rune(draw, rx, ry, 10, FORGER_AMBER)
    img.save(os.path.join(CARD_ART, "fg_summon_sword.png"))

def gen_fg_reinforce():
    img, draw = make_card()
    draw_shield(draw, 128, 128, 100, 130, FORGER_STEEL_DARK, FORGER_STEEL)
    draw_shield(draw, 128, 128, 80, 105, FORGER_STEEL, FORGER_STEEL_LIGHT)
    draw_shield(draw, 128, 128, 55, 75, FORGER_STEEL_LIGHT, FORGER_AMBER)
    draw_glow(img, 128, 128, 22, FORGER_AMBER, 35)
    for dx, dy in [(-50, -30), (50, -30), (-50, 50), (50, 50)]:
        draw.line([(128 + dx - 8, 128 + dy), (128 + dx + 8, 128 + dy)], fill=FORGER_AMBER, width=3)
        draw.line([(128 + dx, 128 + dy - 8), (128 + dx, 128 + dy + 8)], fill=FORGER_AMBER, width=3)
    img.save(os.path.join(CARD_ART, "fg_reinforce.png"))

def gen_fg_temper():
    img, draw = make_card()
    draw.rectangle([50, 150, 206, 220], fill=(30, 50, 70))
    draw.arc([50, 140, 206, 160], 0, 180, fill=(40, 65, 90), width=3)
    draw_sword_shape(draw, 128, 100, 140, 16, FORGER_ORANGE, FORGER_BROWN_LIGHT, -math.pi / 2)
    for i in range(5):
        sx = 90 + i * 20
        for j in range(3):
            sy = 140 - j * 15
            draw.arc([sx - 8, sy - 8, sx + 8, sy + 8], 180, 360, fill=(200, 200, 220, 80 - j * 20), width=2)
    draw_glow(img, 128, 150, 25, (100, 150, 200), 22)
    img.save(os.path.join(CARD_ART, "fg_temper.png"))

def gen_fg_forge_shield():
    img, draw = make_card()
    draw_shield(draw, 128, 135, 110, 130, FORGER_STEEL, FORGER_STEEL_LIGHT)
    draw_hammer(draw, 128, 50, 70, FORGER_STEEL, FORGER_BROWN_LIGHT)
    draw_glow(img, 128, 100, 28, FORGER_ORANGE, 32)
    draw_sparks(draw, 128, 95, 6, 25, [FORGER_AMBER, (255, 255, 200)])
    img.save(os.path.join(CARD_ART, "fg_forge_shield.png"))

def gen_fg_melt_down():
    img, draw = make_card()
    draw.polygon([(70, 100), (60, 180), (80, 200), (176, 200), (196, 180), (186, 100)], fill=FORGER_STEEL_DARK)
    draw.ellipse([75, 95, 181, 130], fill=FORGER_ORANGE)
    draw.ellipse([80, 100, 176, 125], fill=FORGER_AMBER)
    draw_glow(img, 128, 110, 35, FORGER_ORANGE, 35)
    for i in range(4):
        y = 80 - i * 15
        draw.arc([100 + i * 5, y, 156 - i * 5, y + 20], 0, 180, fill=FORGER_ORANGE[:3] + (80 - i * 15,), width=2)
    draw.ellipse([60, 195, 76, 215], fill=FORGER_ORANGE)
    img.save(os.path.join(CARD_ART, "fg_melt_down.png"))

def gen_fg_overcharge():
    img, draw = make_card()
    draw_glow(img, 128, 128, 60, FORGER_ORANGE, 28)
    draw_lightning_bolt(draw, 100, 128, 80, FORGER_AMBER)
    draw_lightning_bolt(draw, 156, 128, 60, FORGER_ORANGE)
    draw.ellipse([103, 103, 153, 153], fill=FORGER_AMBER)
    draw.ellipse([113, 113, 143, 143], fill=(255, 255, 200))
    draw.arc([48, 48, 208, 208], 0, 90, fill=FORGER_AMBER, width=3)
    draw.arc([48, 48, 208, 208], 180, 270, fill=FORGER_ORANGE, width=3)
    img.save(os.path.join(CARD_ART, "fg_overcharge.png"))

def gen_fg_absorb_impact():
    img, draw = make_card()
    draw_shield(draw, 128, 128, 110, 140, FORGER_STEEL, FORGER_STEEL_LIGHT)
    for i in range(3):
        ax = 40 + i * 30
        ay = 80 + i * 25
        draw.line([(ax, ay), (ax + 40, ay + 15)], fill=(180, 100, 60), width=3)
        draw.polygon([(ax + 40, ay + 15), (ax + 35, ay + 8), (ax + 35, ay + 22)], fill=(180, 100, 60))
    draw_glow(img, 128, 128, 30, FORGER_AMBER, 22)
    for r in [20, 35, 50]:
        draw.arc([128 - r, 128 - r, 128 + r, 128 + r], 160, 200, fill=FORGER_AMBER[:3] + (80,), width=2)
    img.save(os.path.join(CARD_ART, "fg_absorb_impact.png"))

def gen_fg_heat_treat():
    img, draw = make_card()
    draw.rectangle([60, 80, 196, 200], fill=(60, 30, 20))
    draw.rectangle([70, 85, 186, 90], fill=FORGER_STEEL_DARK)
    draw_flame(draw, 128, 150, 80, 80, [FORGER_EMBER, FORGER_ORANGE, FORGER_AMBER])
    draw_glow(img, 128, 150, 35, FORGER_ORANGE, 35)
    draw.rectangle([100, 130, 156, 145], fill=(255, 180, 100))
    draw_glow(img, 128, 137, 18, FORGER_AMBER, 30)
    img.save(os.path.join(CARD_ART, "fg_heat_treat.png"))

def gen_fg_forge_barrier():
    img, draw = make_card()
    for row in range(2):
        for col in range(3):
            x = 30 + col * 70
            y = 60 + row * 80
            draw_armor_plate(draw, x + 35, y + 35, 60, 70, FORGER_STEEL, FORGER_STEEL_LIGHT)
    for y in [95, 175]:
        for x in [65, 128, 191]:
            draw.ellipse([x - 4, y - 4, x + 4, y + 4], fill=FORGER_AMBER)
    draw_glow(img, 128, 128, 45, FORGER_ORANGE, 14)
    img.save(os.path.join(CARD_ART, "fg_forge_barrier.png"))

def gen_fg_sword_sacrifice():
    img, draw = make_card()
    draw.polygon([(80, 60), (95, 55), (128, 128), (118, 135)], fill=FORGER_STEEL)
    draw.polygon([(138, 121), (128, 128), (175, 55), (185, 60)], fill=FORGER_STEEL_LIGHT)
    draw_glow(img, 128, 128, 35, FORGER_AMBER, 50)
    for angle in range(0, 360, 30):
        rad = math.radians(angle)
        r = random.randint(30, 60)
        px = 128 + r * math.cos(rad)
        py = 128 + r * math.sin(rad)
        draw.ellipse([px - 3, py - 3, px + 3, py + 3], fill=FORGER_AMBER[:3] + (150,))
    img.save(os.path.join(CARD_ART, "fg_sword_sacrifice.png"))

def gen_fg_thorn_forge():
    img, draw = make_card()
    draw.ellipse([78, 78, 178, 178], fill=FORGER_STEEL_DARK)
    for angle in range(0, 360, 40):
        rad = math.radians(angle)
        cx2, cy2 = 128, 128
        tip = (cx2 + 70 * math.cos(rad), cy2 + 70 * math.sin(rad))
        base1 = (cx2 + 40 * math.cos(rad - 0.2), cy2 + 40 * math.sin(rad - 0.2))
        base2 = (cx2 + 40 * math.cos(rad + 0.2), cy2 + 40 * math.sin(rad + 0.2))
        draw.polygon([tip, base1, base2], fill=FORGER_STEEL)
    draw_glow(img, 128, 128, 25, FORGER_ORANGE, 28)
    draw.ellipse([108, 108, 148, 148], fill=FORGER_ORANGE[:3] + (80,))
    img.save(os.path.join(CARD_ART, "fg_thorn_forge.png"))

def gen_fg_salvage():
    img, draw = make_card()
    draw.polygon([(60, 80), (80, 70), (100, 100), (70, 110)], fill=FORGER_STEEL)
    draw.polygon([(140, 70), (170, 80), (160, 110), (135, 100)], fill=FORGER_STEEL_DARK)
    draw.polygon([(90, 140), (120, 130), (130, 160), (100, 165)], fill=FORGER_STEEL)
    draw.polygon([(150, 140), (180, 145), (175, 170), (145, 165)], fill=FORGER_STEEL_DARK)
    draw_glow(img, 128, 128, 35, FORGER_AMBER, 22)
    for angle in [45, 135, 225, 315]:
        rad = math.radians(angle)
        sx = 128 + 60 * math.cos(rad)
        sy = 128 + 60 * math.sin(rad)
        ex = 128 + 30 * math.cos(rad)
        ey = 128 + 30 * math.sin(rad)
        draw.line([(sx, sy), (ex, ey)], fill=FORGER_AMBER, width=2)
    img.save(os.path.join(CARD_ART, "fg_salvage.png"))

def gen_fg_thorn_wall():
    img, draw = make_card()
    draw.rectangle([40, 60, 216, 200], fill=FORGER_STEEL_DARK)
    draw.rectangle([45, 65, 211, 195], fill=FORGER_STEEL)
    for i in range(5):
        for j in range(3):
            tx = 60 + i * 35
            ty = 80 + j * 40
            draw.polygon([(tx, ty), (tx - 6, ty + 10), (tx + 6, ty + 10)], fill=FORGER_STEEL_LIGHT)
            draw.polygon([(tx, ty - 15), (tx - 4, ty), (tx + 4, ty)], fill=FORGER_STEEL_LIGHT)
    draw_glow(img, 128, 128, 25, FORGER_STEEL_LIGHT, 10)
    img.save(os.path.join(CARD_ART, "fg_thorn_wall.png"))

def gen_fg_quick_temper():
    img, draw = make_card()
    for i in range(8):
        y = 60 + i * 20
        draw.line([(30, y), (100, y)], fill=FORGER_STEEL_LIGHT[:3] + (60,), width=1)
    draw_sword_shape(draw, 140, 128, 140, 16, FORGER_STEEL, FORGER_BROWN_LIGHT, -0.1)
    draw_glow(img, 140, 128, 30, FORGER_ORANGE, 28)
    draw.arc([160, 60, 220, 120], 0, 270, fill=FORGER_AMBER, width=3)
    draw.line([(190, 90), (190, 70)], fill=FORGER_AMBER, width=2)
    draw.line([(190, 90), (205, 90)], fill=FORGER_AMBER, width=2)
    img.save(os.path.join(CARD_ART, "fg_quick_temper.png"))

def gen_fg_chain_forge():
    img, draw = make_card()
    draw_chain_links(draw, 50, 80, 206, 80, 8, FORGER_STEEL, 10)
    draw_chain_links(draw, 50, 128, 206, 128, 8, FORGER_STEEL_LIGHT, 10)
    draw_chain_links(draw, 50, 176, 206, 176, 8, FORGER_STEEL, 10)
    draw_flame(draw, 128, 128, 40, 40, [FORGER_EMBER, FORGER_ORANGE, FORGER_AMBER])
    draw_glow(img, 128, 128, 25, FORGER_ORANGE, 28)
    draw_hammer(draw, 128, 60, 50, FORGER_STEEL, FORGER_BROWN_LIGHT)
    img.save(os.path.join(CARD_ART, "fg_chain_forge.png"))

def gen_fg_repurpose():
    img, draw = make_card()
    draw.rectangle([40, 90, 90, 170], fill=FORGER_STEEL_DARK)
    draw.line([(65, 90), (65, 170)], fill=(80, 60, 40), width=2)
    draw.polygon([(128, 110), (128, 146), (160, 128)], fill=FORGER_AMBER)
    draw.rectangle([100, 120, 130, 136], fill=FORGER_AMBER)
    draw_sword_shape(draw, 200, 128, 100, 14, FORGER_STEEL_LIGHT, FORGER_AMBER, -math.pi / 2)
    draw_glow(img, 145, 128, 25, FORGER_ORANGE, 28)
    draw_sparks(draw, 145, 128, 5, 25, [FORGER_AMBER, (255, 255, 200)])
    img.save(os.path.join(CARD_ART, "fg_repurpose.png"))


# ---- Forger Power Cards ----

def gen_fg_sword_mastery():
    img, draw = make_card()
    draw_glow(img, 128, 128, 70, FORGER_AMBER, 18)
    draw_sword_shape(draw, 128, 110, 190, 24, FORGER_STEEL_LIGHT, FORGER_AMBER, -math.pi / 2)
    draw.arc([78, 20, 178, 70], 0, 360, fill=FORGER_AMBER, width=3)
    draw.arc([88, 25, 168, 65], 0, 360, fill=(255, 255, 200), width=2)
    for angle in range(0, 360, 30):
        rad = math.radians(angle)
        draw.line([(128 + 65 * math.cos(rad), 128 + 65 * math.sin(rad)),
                    (128 + 85 * math.cos(rad), 128 + 85 * math.sin(rad))],
                   fill=FORGER_AMBER[:3] + (100,), width=2)
    img.save(os.path.join(CARD_ART, "fg_sword_mastery.png"))

def gen_fg_barricade():
    img, draw = make_card()
    draw_glow(img, 128, 128, 65, FORGER_AMBER, 15)
    for i in range(4):
        offset = i * 8
        draw_shield(draw, 128, 128 + offset, 140 - i * 20, 170 - i * 25,
                   tuple(min(255, v + i * 15) for v in FORGER_STEEL[:3]), FORGER_STEEL_LIGHT)
    draw_glow(img, 128, 128, 25, FORGER_AMBER, 35)
    draw.arc([28, 28, 228, 228], 0, 360, fill=FORGER_AMBER[:3] + (60,), width=2)
    img.save(os.path.join(CARD_ART, "fg_barricade.png"))

def gen_fg_energy_reserve():
    img, draw = make_card()
    draw_glow(img, 128, 128, 60, FORGER_ORANGE, 22)
    draw.ellipse([73, 73, 183, 183], fill=FORGER_STEEL_DARK)
    draw.ellipse([83, 83, 173, 173], outline=FORGER_AMBER, width=3)
    draw.ellipse([93, 93, 163, 163], fill=FORGER_ORANGE)
    draw.ellipse([108, 108, 148, 148], fill=FORGER_AMBER)
    draw.ellipse([118, 118, 138, 138], fill=(255, 255, 200))
    for r in [40, 55, 70]:
        angle_start = random.randint(0, 180)
        draw.arc([128 - r, 128 - r, 128 + r, 128 + r], angle_start, angle_start + 120, fill=FORGER_AMBER[:3] + (100,), width=2)
    img.save(os.path.join(CARD_ART, "fg_energy_reserve.png"))

def gen_fg_living_sword():
    img, draw = make_card()
    draw_glow(img, 128, 128, 55, FORGER_AMBER, 18)
    draw_sword_shape(draw, 128, 110, 200, 24, FORGER_STEEL, FORGER_BROWN_LIGHT, -math.pi / 2)
    draw.ellipse([113, 100, 143, 120], fill=(20, 20, 30))
    draw.ellipse([120, 105, 136, 115], fill=FORGER_AMBER)
    draw.ellipse([125, 108, 131, 112], fill=(20, 20, 30))
    draw.arc([58, 38, 198, 218], 0, 360, fill=FORGER_AMBER[:3] + (60,), width=2)
    for _ in range(8):
        px = random.randint(70, 186)
        py = random.randint(40, 220)
        ps = random.randint(2, 5)
        draw.ellipse([px - ps, py - ps, px + ps, py + ps], fill=FORGER_AMBER[:3] + (80,))
    img.save(os.path.join(CARD_ART, "fg_living_sword.png"))

def gen_fg_thorn_aura():
    img, draw = make_card()
    draw_glow(img, 128, 128, 65, FORGER_ORANGE, 15)
    draw.ellipse([108, 90, 148, 130], fill=FORGER_STEEL_DARK)
    draw.rectangle([115, 130, 141, 180], fill=FORGER_STEEL_DARK)
    for angle in range(0, 360, 25):
        rad = math.radians(angle)
        cx2, cy2 = 128, 128
        tip = (cx2 + 90 * math.cos(rad), cy2 + 90 * math.sin(rad))
        base1 = (cx2 + 50 * math.cos(rad - 0.15), cy2 + 50 * math.sin(rad - 0.15))
        base2 = (cx2 + 50 * math.cos(rad + 0.15), cy2 + 50 * math.sin(rad + 0.15))
        draw.polygon([tip, base1, base2], fill=FORGER_STEEL)
    for angle in range(0, 360, 25):
        rad = math.radians(angle)
        tx = 128 + 85 * math.cos(rad)
        ty = 128 + 85 * math.sin(rad)
        draw_glow(img, tx, ty, 6, FORGER_ORANGE, 30)
    img.save(os.path.join(CARD_ART, "fg_thorn_aura.png"))

def gen_fg_iron_will():
    img, draw = make_card()
    draw_glow(img, 128, 128, 55, FORGER_ORANGE, 14)
    draw.rectangle([90, 80, 166, 170], fill=FORGER_STEEL)
    draw.rectangle([85, 90, 95, 155], fill=FORGER_STEEL_LIGHT)
    for i in range(4):
        x = 100 + i * 18
        draw.arc([x, 75, x + 15, 95], 180, 360, fill=FORGER_STEEL_LIGHT, width=2)
    for y in range(100, 160, 10):
        draw.line([(95, y), (161, y)], fill=FORGER_STEEL_DARK[:3] + (60,), width=1)
    draw.arc([50, 50, 206, 206], 0, 360, fill=FORGER_AMBER[:3] + (80,), width=3)
    img.save(os.path.join(CARD_ART, "fg_iron_will.png"))

def gen_fg_forge_master():
    img, draw = make_card()
    draw_glow(img, 128, 128, 60, FORGER_ORANGE, 18)
    draw_anvil(draw, 128, 170, 100, FORGER_STEEL)
    draw_hammer(draw, 128, 80, 80, FORGER_STEEL_LIGHT, FORGER_BROWN_LIGHT)
    for i in range(5):
        x = 80 + i * 24
        draw_flame(draw, x, 40, 18, 30, [FORGER_EMBER, FORGER_ORANGE, FORGER_AMBER])
    draw.arc([38, 38, 218, 218], 0, 360, fill=FORGER_AMBER, width=3)
    draw_sparks(draw, 128, 100, 8, 50, [FORGER_AMBER, (255, 255, 200)])
    img.save(os.path.join(CARD_ART, "fg_forge_master.png"))

def gen_fg_auto_forge():
    img, draw = make_card()
    draw_glow(img, 128, 128, 45, FORGER_ORANGE, 14)
    draw_circle_pattern(draw, 85, 100, 40, FORGER_STEEL, 8, 3)
    draw.ellipse([65, 80, 105, 120], outline=FORGER_STEEL_LIGHT, width=3)
    draw_circle_pattern(draw, 170, 140, 35, FORGER_STEEL, 8, 3)
    draw.ellipse([145, 115, 195, 165], outline=FORGER_STEEL_LIGHT, width=3)
    draw_hammer(draw, 128, 60, 50, FORGER_STEEL, FORGER_BROWN_LIGHT)
    draw_flame(draw, 128, 200, 60, 50, [FORGER_EMBER, FORGER_ORANGE, FORGER_AMBER])
    draw.arc([28, 28, 228, 228], 0, 360, fill=FORGER_AMBER[:3] + (50,), width=2)
    img.save(os.path.join(CARD_ART, "fg_auto_forge.png"))

def gen_fg_iron_skin():
    img, draw = make_card()
    draw_glow(img, 128, 128, 50, FORGER_STEEL_LIGHT, 10)
    draw.ellipse([103, 50, 153, 100], fill=FORGER_STEEL)
    draw.rectangle([108, 95, 148, 170], fill=FORGER_STEEL)
    draw.rectangle([95, 160, 115, 220], fill=FORGER_STEEL)
    draw.rectangle([141, 160, 161, 220], fill=FORGER_STEEL)
    draw.rectangle([85, 100, 108, 150], fill=FORGER_STEEL)
    draw.rectangle([148, 100, 171, 150], fill=FORGER_STEEL)
    for y in range(60, 210, 12):
        draw.line([(100, y), (156, y)], fill=FORGER_STEEL_LIGHT[:3] + (50,), width=1)
    draw_glow(img, 128, 100, 20, FORGER_STEEL_LIGHT, 18)
    draw.arc([48, 30, 208, 230], 0, 360, fill=FORGER_AMBER[:3] + (60,), width=2)
    img.save(os.path.join(CARD_ART, "fg_iron_skin.png"))

def gen_fg_resonance():
    img, draw = make_card()
    draw_sword_shape(draw, 128, 128, 140, 18, FORGER_STEEL_LIGHT, FORGER_AMBER, -math.pi / 2)
    for r in range(20, 110, 15):
        alpha = max(20, 100 - r)
        draw.ellipse([128 - r, 128 - r, 128 + r, 128 + r], outline=FORGER_AMBER[:3] + (alpha,), width=2)
    for i in range(5):
        dx = (i - 2) * 4
        draw.line([(128 + dx, 50), (128 + dx, 210)], fill=FORGER_AMBER[:3] + (40,), width=1)
    draw_glow(img, 128, 128, 20, FORGER_AMBER, 30)
    img.save(os.path.join(CARD_ART, "fg_resonance.png"))

def gen_fg_sword_ward():
    img, draw = make_card()
    for angle_deg in [0, 72, 144, 216, 288]:
        angle = math.radians(angle_deg)
        cx2 = 128 + 55 * math.cos(angle)
        cy2 = 128 + 55 * math.sin(angle)
        draw_sword_shape(draw, cx2, cy2, 70, 10, FORGER_STEEL, None, angle + math.pi / 2)
    draw.ellipse([48, 48, 208, 208], outline=FORGER_AMBER, width=3)
    draw_glow(img, 128, 128, 30, FORGER_AMBER, 22)
    draw_rune(draw, 128, 128, 20, FORGER_AMBER)
    img.save(os.path.join(CARD_ART, "fg_sword_ward.png"))

def gen_fg_counter_forge():
    img, draw = make_card()
    draw_shield(draw, 90, 128, 80, 100, FORGER_STEEL, FORGER_STEEL_LIGHT)
    draw_hammer(draw, 180, 90, 70, FORGER_STEEL, FORGER_BROWN_LIGHT)
    draw.arc([80, 80, 200, 200], 300, 420, fill=FORGER_AMBER, width=3)
    draw_glow(img, 140, 110, 22, FORGER_ORANGE, 38)
    draw_sparks(draw, 140, 110, 5, 20, [FORGER_AMBER, (255, 255, 200)])
    draw.arc([28, 28, 228, 228], 0, 360, fill=FORGER_AMBER[:3] + (40,), width=2)
    img.save(os.path.join(CARD_ART, "fg_counter_forge.png"))


# ---- Fire Mage Cards ----

def gen_fm_strike():
    img, draw = make_card()
    draw_glow(img, 128, 128, 55, FIRE_RED, 22)
    draw_flame(draw, 128, 100, 80, 100, [FIRE_RED, FIRE_ORANGE, FIRE_YELLOW])
    draw.line([(50, 180), (206, 60)], fill=FIRE_YELLOW, width=4)
    draw.line([(52, 178), (204, 62)], fill=(255, 255, 200), width=2)
    draw_glow(img, 128, 120, 25, FIRE_ORANGE, 35)
    draw_sparks(draw, 128, 100, 10, 50, [FIRE_YELLOW, FIRE_ORANGE, (255, 255, 200)])
    img.save(os.path.join(CARD_ART, "fm_strike.png"))

def gen_fm_defend():
    img, draw = make_card()
    draw_glow(img, 128, 128, 55, FIRE_RED, 18)
    draw_shield(draw, 128, 128, 120, 150, FIRE_DARK_RED, FIRE_RED)
    for angle in range(0, 360, 30):
        rad = math.radians(angle)
        fx = 128 + 65 * math.cos(rad)
        fy = 128 + 65 * math.sin(rad)
        draw_flame(draw, fx, fy, 12, 20, [FIRE_RED, FIRE_ORANGE, FIRE_YELLOW])
    draw.ellipse([108, 108, 148, 148], outline=FIRE_ORANGE, width=2)
    draw_flame(draw, 128, 128, 25, 30, [FIRE_RED, FIRE_ORANGE, FIRE_YELLOW])
    img.save(os.path.join(CARD_ART, "fm_defend.png"))

def gen_fm_flesh_rend():
    img, draw = make_card()
    draw_glow(img, 128, 128, 45, FIRE_RED, 22)
    for i in range(3):
        x_off = -30 + i * 30
        draw.line([(90 + x_off, 50), (140 + x_off, 200)], fill=FIRE_RED, width=6)
        draw.line([(92 + x_off, 52), (138 + x_off, 198)], fill=FIRE_ORANGE, width=3)
    draw_sparks(draw, 128, 128, 10, 60, [FIRE_RED, FIRE_DARK_RED, (180, 30, 20)])
    draw_glow(img, 128, 128, 25, FIRE_RED, 30)
    img.save(os.path.join(CARD_ART, "fm_flesh_rend.png"))

def gen_fm_soul_harvest():
    img, draw = make_card()
    draw_glow(img, 128, 128, 55, FIRE_DARK_RED, 18)
    for i in range(4):
        angle = math.pi / 2 * i
        sx = 128 + 70 * math.cos(angle)
        sy = 128 + 70 * math.sin(angle)
        draw.ellipse([sx - 12, sy - 15, sx + 12, sy + 5], fill=(200, 60, 40, 120))
        draw.ellipse([sx - 8, sy - 10, sx + 8, sy + 2], fill=(255, 100, 60, 80))
        draw.ellipse([sx - 6, sy - 8, sx - 2, sy - 4], fill=FIRE_YELLOW[:3] + (150,))
        draw.ellipse([sx + 2, sy - 8, sx + 6, sy - 4], fill=FIRE_YELLOW[:3] + (150,))
    draw.ellipse([98, 98, 158, 158], fill=FIRE_DARK_RED)
    draw.ellipse([108, 108, 148, 148], fill=FIRE_RED)
    draw_glow(img, 128, 128, 18, FIRE_ORANGE, 35)
    for r in range(20, 70, 10):
        draw.arc([128 - r, 128 - r, 128 + r, 128 + r], r * 3, r * 3 + 120, fill=FIRE_ORANGE[:3] + (80,), width=2)
    img.save(os.path.join(CARD_ART, "fm_soul_harvest.png"))

def gen_fm_relentless():
    img, draw = make_card()
    draw_glow(img, 128, 128, 55, FIRE_RED, 20)
    draw_flame(draw, 128, 100, 100, 120, [FIRE_RED, FIRE_ORANGE, FIRE_YELLOW])
    for i in range(6):
        y = 60 + i * 25
        draw.line([(20, y), (80, y)], fill=FIRE_ORANGE[:3] + (80,), width=2)
    draw.polygon([(180, 128), (220, 100), (220, 156)], fill=FIRE_YELLOW)
    draw.rectangle([140, 115, 185, 141], fill=FIRE_YELLOW)
    draw_glow(img, 180, 128, 20, FIRE_YELLOW, 30)
    img.save(os.path.join(CARD_ART, "fm_relentless.png"))

def gen_fm_bloodbath():
    img, draw = make_card()
    draw_glow(img, 128, 170, 55, FIRE_DARK_RED, 22)
    draw.ellipse([40, 140, 216, 220], fill=FIRE_DARK_RED)
    draw.ellipse([55, 148, 201, 212], fill=FIRE_RED)
    for i in range(5):
        x = 70 + i * 25
        h = random.randint(30, 80)
        draw.ellipse([x - 5, 150 - h, x + 5, 155], fill=FIRE_RED[:3] + (180,))
        draw.ellipse([x - 3, 150 - h - 8, x + 3, 150 - h + 2], fill=FIRE_ORANGE[:3] + (150,))
    draw_glow(img, 128, 160, 30, FIRE_RED, 28)
    draw_sparks(draw, 128, 120, 8, 50, [FIRE_RED, FIRE_DARK_RED, (200, 40, 30)])
    img.save(os.path.join(CARD_ART, "fm_bloodbath.png"))

def gen_fm_blood_pact():
    img, draw = make_card()
    draw_glow(img, 128, 128, 55, FIRE_DARK_RED, 14)
    draw.ellipse([48, 48, 208, 208], outline=FIRE_RED, width=3)
    draw_star(draw, 128, 128, 70, 30, 5, FIRE_DARK_RED)
    draw_star(draw, 128, 128, 60, 25, 5, FIRE_RED)
    for i in range(5):
        angle = 2 * math.pi * i / 5 - math.pi / 2
        rx = 128 + 85 * math.cos(angle)
        ry = 128 + 85 * math.sin(angle)
        draw_rune(draw, rx, ry, 10, FIRE_ORANGE)
    for _ in range(5):
        bx = random.randint(80, 176)
        by = random.randint(80, 176)
        draw.ellipse([bx - 3, by - 3, bx + 3, by + 3], fill=FIRE_RED)
    draw_glow(img, 128, 128, 22, FIRE_ORANGE, 30)
    img.save(os.path.join(CARD_ART, "fm_blood_pact.png"))

def gen_fm_crimson_pact():
    img, draw = make_card()
    draw_glow(img, 128, 128, 55, (180, 20, 20), 18)
    draw.polygon([(40, 140), (50, 110), (80, 100), (100, 120), (100, 150), (60, 155)], fill=(200, 150, 120))
    draw.polygon([(216, 140), (206, 110), (176, 100), (156, 120), (156, 150), (196, 155)], fill=(200, 150, 120))
    draw_glow(img, 128, 128, 28, FIRE_RED, 40)
    draw.ellipse([108, 108, 148, 148], fill=FIRE_DARK_RED)
    draw.ellipse([115, 115, 141, 141], fill=FIRE_RED)
    for i in range(3):
        x = 115 + i * 13
        draw.line([(x, 148), (x, 170)], fill=FIRE_RED, width=2)
        draw.ellipse([x - 3, 168, x + 3, 175], fill=FIRE_RED)
    draw.ellipse([68, 68, 188, 188], outline=FIRE_ORANGE[:3] + (80,), width=2)
    img.save(os.path.join(CARD_ART, "fm_crimson_pact.png"))

def gen_fm_undying_rage():
    img, draw = make_card()
    draw_glow(img, 128, 128, 75, FIRE_RED, 30)
    for angle in range(0, 360, 20):
        rad = math.radians(angle)
        length = random.randint(60, 100)
        w = random.randint(8, 15)
        ex = 128 + length * math.cos(rad)
        ey = 128 + length * math.sin(rad)
        draw.line([(128, 128), (ex, ey)], fill=FIRE_ORANGE, width=w)
    draw.ellipse([88, 88, 168, 168], fill=FIRE_RED)
    draw.ellipse([98, 98, 158, 158], fill=FIRE_ORANGE)
    draw.ellipse([108, 108, 148, 148], fill=FIRE_YELLOW)
    draw.ellipse([118, 118, 138, 138], fill=(255, 255, 200))
    draw.line([(110, 110), (120, 118)], fill=(20, 20, 30), width=3)
    draw.line([(146, 110), (136, 118)], fill=(20, 20, 30), width=3)
    draw.arc([115, 125, 141, 140], 0, 180, fill=(20, 20, 30), width=3)
    draw_sparks(draw, 128, 128, 20, 100, [FIRE_YELLOW, FIRE_ORANGE, (255, 255, 200), FIRE_RED])
    img.save(os.path.join(CARD_ART, "fm_undying_rage.png"))


# ============================================================
# MAIN
# ============================================================

def main():
    print("=" * 60)
    print("Generating all art assets...")
    print("=" * 60)

    print("\n--- Character Sprites ---")
    generate_forger()
    generate_forger_fallen()
    generate_fire_mage()
    generate_fire_mage_fallen()
    generate_greatsword()

    print("\n--- Forger Attack Cards (13) ---")
    for fn in [gen_fg_strike, gen_fg_sword_crash, gen_fg_riposte_strike, gen_fg_shield_bash,
               gen_fg_forge_slam, gen_fg_greatsword_cleave, gen_fg_tempered_strike,
               gen_fg_magnetic_edge, gen_fg_molten_core, gen_fg_hardened_blade,
               gen_fg_reforged_edge, gen_fg_eruption_strike, gen_fg_blade_storm]:
        fn()
        print(f"  {fn.__name__[4:]}.png")

    print("\n--- Forger Skill Cards (22) ---")
    for fn in [gen_fg_defend, gen_fg_delay_charge, gen_fg_sharpen, gen_fg_forge_armor,
               gen_fg_impervious_wall, gen_fg_block_transfer, gen_fg_summon_sword,
               gen_fg_reinforce, gen_fg_temper, gen_fg_forge_shield, gen_fg_melt_down,
               gen_fg_overcharge, gen_fg_absorb_impact, gen_fg_heat_treat, gen_fg_forge_barrier,
               gen_fg_sword_sacrifice, gen_fg_thorn_forge, gen_fg_salvage, gen_fg_thorn_wall,
               gen_fg_quick_temper, gen_fg_chain_forge, gen_fg_repurpose]:
        fn()
        print(f"  {fn.__name__[4:]}.png")

    print("\n--- Forger Power Cards (12) ---")
    for fn in [gen_fg_sword_mastery, gen_fg_barricade, gen_fg_energy_reserve, gen_fg_living_sword,
               gen_fg_thorn_aura, gen_fg_iron_will, gen_fg_forge_master, gen_fg_auto_forge,
               gen_fg_iron_skin, gen_fg_resonance, gen_fg_sword_ward, gen_fg_counter_forge]:
        fn()
        print(f"  {fn.__name__[4:]}.png")

    print("\n--- Fire Mage Cards (9) ---")
    for fn in [gen_fm_strike, gen_fm_defend, gen_fm_flesh_rend, gen_fm_soul_harvest,
               gen_fm_relentless, gen_fm_bloodbath, gen_fm_blood_pact, gen_fm_crimson_pact,
               gen_fm_undying_rage]:
        fn()
        print(f"  {fn.__name__[4:]}.png")

    print("\n" + "=" * 60)
    print("All assets generated successfully!")
    print("=" * 60)


if __name__ == "__main__":
    main()
