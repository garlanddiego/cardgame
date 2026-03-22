# Visual Design Specification — Card Roguelike (Godot 4)
## Art Director Reference · Viewport 1920×1080

---

## Table of Contents

1. [Color Palette](#1-color-palette)
2. [Typography](#2-typography)
3. [Card Visual Treatment](#3-card-visual-treatment)
4. [Battle HUD Visual Treatment](#4-battle-hud-visual-treatment)
5. [Targeting Arrow](#5-targeting-arrow)
6. [Animation Specifications](#6-animation-specifications)
7. [Asset Requirements](#7-asset-requirements)

---

## 1. Color Palette

### 1.1 Master Palette — Godot Color() Values

All colors listed as `Color(r, g, b, a)` for direct use in GDScript. Hex equivalents included for reference.

| Token | Color() | Hex | Usage |
|---|---|---|---|
| `bg_dungeon` | `Color(0.051, 0.039, 0.027, 1.0)` | `#0D0A07` | Fullscreen background fallback |
| `surface_panel` | `Color(0.102, 0.071, 0.031, 0.80)` | `#1A1208 CC` | HUD panels, top/bottom bars |
| `surface_card` | `Color(0.067, 0.051, 0.031, 0.949)` | `#110D08 F2` | Card background fallback when no frame |
| `border_gold` | `Color(0.902, 0.722, 0.290, 1.0)` | `#E6B84A` | Panel borders, selected ring, highlights |
| `border_gold_dim` | `Color(0.902, 0.722, 0.290, 0.5)` | `#E6B84A 80` | Subtle borders, inactive states |
| `accent_orange` | `Color(1.0, 0.400, 0.141, 1.0)` | `#FF6624` | End Turn button, targeting arrow tip |
| `accent_green` | `Color(0.267, 0.800, 0.400, 1.0)` | `#44CC66` | Selected card highlight, Confirm button |
| `accent_red` | `Color(0.800, 0.133, 0.133, 1.0)` | `#CC2222` | HP bars, defeat overlay, attack type |
| `text_primary` | `Color(0.949, 0.929, 0.847, 1.0)` | `#F2EDD8` | Card names, HUD values, button text |
| `text_secondary` | `Color(0.749, 0.722, 0.604, 1.0)` | `#BFB89A` | Card descriptions, type labels |
| `text_muted` | `Color(0.478, 0.447, 0.376, 0.80)` | `#7A7260 CC` | Pile counts, floor labels, disabled text |
| `intent_attack` | `Color(1.0, 0.267, 0.267, 0.80)` | `#FF4444 CC` | Enemy attack intent |
| `intent_defend` | `Color(0.267, 0.533, 1.0, 0.80)` | `#4488FF CC` | Enemy block intent |
| `intent_unknown` | `Color(0.667, 0.667, 0.667, 0.60)` | `#AAAAAA 99` | Unknown/buff intent |
| `energy_blue` | `Color(0.200, 0.600, 1.0, 1.0)` | `#3399FF` | Energy orb base color |
| `energy_glow` | `Color(0.200, 0.600, 1.0, 0.40)` | `#3399FF 66` | Energy orb radial glow |
| `hp_bar_fill` | `Color(0.800, 0.133, 0.133, 1.0)` | `#CC2222` | Player and enemy HP bar fill |
| `hp_bar_bg` | `Color(0.200, 0.059, 0.059, 1.0)` | `#330F0F` | HP bar background trough |
| `block_blue` | `Color(0.267, 0.533, 1.0, 1.0)` | `#4488FF` | Block counter orb |
| `victory_gold` | `Color(0.902, 0.722, 0.290, 1.0)` | `#E6B84A` | Victory title text |
| `defeat_red` | `Color(0.800, 0.200, 0.200, 1.0)` | `#CC3333` | Defeat title text |
| `defeat_vignette` | `Color(0.300, 0.0, 0.0, 0.85)` | `#4D0000 D9` | Defeat fullscreen overlay |

### 1.2 Card Type Colors

| Type | Frame Gem Color | Frame Primary | Frame Secondary | Name Text |
|---|---|---|---|---|
| Attack | `Color(1.0, 0.533, 0.533, 1.0)` `#FF8888` | Deep red/crimson `#8B1A1A` | Gold `#C9922A` | `Color(1.0, 0.949, 0.847, 1.0)` |
| Skill | `Color(0.533, 1.0, 0.667, 1.0)` `#88FFAA` | Steel grey-green `#3A5A3A` | Silver `#9AB09A` | `Color(1.0, 0.949, 0.847, 1.0)` |
| Power | `Color(0.733, 0.533, 1.0, 1.0)` `#BB88FF` | Deep purple `#3A1A5A` | Purple-gold `#9A7AB0` | `Color(1.0, 0.949, 0.847, 1.0)` |

### 1.3 STS Reference Analysis vs. Current Implementation

Observed from STS reference images:

**Background:** STS uses a warm amber-toned stone dungeon with reddish torchlight. Current `dungeon_bg.png` should have similar warm stone. The scene background color `#0D0A07` is appropriate as a fallback.

**Card backs in hand:** STS cards show strong colored borders (red/orange for attack) with dark interiors. The current `frame_attack_v2` achieves this with deep crimson frame and black art window — correct direction. The `frame_skill_v2` uses steel/silver-grey which aligns with STS's green/teal Ironclad skill frame. The `frame_power_v2` purple is accurate to STS.

**Energy orb:** STS uses a large glowing blue orb in the bottom-left corner with the fraction "3/3" prominently displayed. Current `energy_orb.png` (40×40) is undersized — the HUD spec calls for 72×72. The generated asset needs to be redrawn at 72×72.

**HP bars:** STS places HP bars directly below entity sprites, narrow (~12px tall), red fill on dark background. Green text "80/80" above or beside. Current implementation matches this intent.

---

## 2. Typography

### 2.1 Font Recommendations

**Primary recommendation: Use Godot's built-in system font fallback with these settings.**

For shipping quality, generate or source these free fonts compatible with Godot 4:

| Role | Recommended Font | Godot Resource |
|---|---|---|
| All UI text | **Cinzel** (display/headings) | Import `.ttf` → `res://assets/fonts/cinzel_bold.ttf` |
| Card body text | **Lato** or **Open Sans** (body) | Import `.ttf` → `res://assets/fonts/lato_regular.ttf` |
| Cost numbers | Cinzel Bold | Same as display font |
| Fallback (no custom fonts) | `SystemFont` with `font_names=["Arial", "Helvetica"]` | Built-in Godot |

**If using system fonts only**, use `ThemeDB.fallback_font` and rely on `Label.add_theme_font_size_override()` for sizing. The bold variant is accessed via `Label.add_theme_font_override("font", preload("res://assets/fonts/bold.tres"))`.

### 2.2 Font Size Table

| Role | Size (px) | Weight | Color Token | Notes |
|---|---|---|---|---|
| Screen title ("Build Your Deck") | 36 | Bold | `text_primary` | Deck builder header, centered |
| Victory/Defeat title | 52 | Bold | `victory_gold` / `defeat_red` | Overlay center |
| Button text (End Turn, Confirm) | 20 | Bold | `Color(1,1,1,1)` white | All primary action buttons |
| HUD values (HP, block, energy) | 22 | Bold | `text_primary` | Live numeric readouts |
| HUD labels ("HP", "Block") | 13 | Regular | `text_secondary` | Static descriptor labels |
| Card name — hand (220×310) | 15 | SemiBold | `Color(1.0, 0.949, 0.847, 1.0)` | Fits in 196px-wide label |
| Card name — grid (290×390) | 14 | SemiBold | `Color(1.0, 0.949, 0.847, 1.0)` | Fits in 250px-wide label |
| Card description — hand | 12 | Regular | `text_secondary` | RichTextLabel, bbcode on |
| Card description — grid | 14 | Regular | `text_secondary` | Larger for readability |
| Card type badge | 11 | Regular | `text_muted` | Uppercase: "ATTACK", "SKILL", "POWER" |
| Cost number | 24 | Bold | `Color(1,1,1,1)` white | Inside orb gem, drop shadow |
| Pile count | 16 | Bold | `text_primary` | Below draw/discard icon |
| Intent damage value | 18 | Bold | `intent_attack` red | Right of enemy intent icon |
| Floor label | 18 | Regular | `text_muted` | Top-right of battle HUD |
| Tooltip text | 13 | Regular | `text_secondary` | Keyword explanation popups |

### 2.3 Text Rendering Settings

```gdscript
# Apply to all Label nodes that render card text:
label.add_theme_constant_override("line_spacing", 4)  # ~1.3× line height at 12px
label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# For cost number on card gem:
cost_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
cost_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
cost_label.add_theme_constant_override("shadow_offset_x", 1)
cost_label.add_theme_constant_override("shadow_offset_y", 2)
cost_label.add_theme_constant_override("shadow_outline_size", 2)
```

---

## 3. Card Visual Treatment

### 3.1 Frame Asset Analysis

The three `frame_*_v2.png` files (896×1200) are the master frames. The `frame_*_v2_card.png` files (290×390) are pre-scaled for the deck builder grid.

**Attack frame (frame_attack_v2.png):**
- Dark crimson/black interior art window
- Ornate gold-trimmed red border with baroque filigree
- Cost gem: upper-left corner, circular, red stone with gold ring, displays number "2"
- Bottom section: horizontal banner reading "ATTACK" in gothic serif
- Below banner: darker recessed area with placeholder text "Card Name / Title empty space / Description & Effects"
- Art window occupies roughly top 58% of card (y=0 to y=695 at 896px scale)

**Skill frame (frame_skill_v2.png):**
- Steel grey-green tone, silver/iron filigree
- Cost gem: upper-left, green glowing orb
- Banner reads "SKILL TITLE" in the displayed text
- Art window similar proportion to attack frame

**Power frame (frame_power_v2.png):**
- Deep purple with violet filigree
- Cost gem: upper-left, purple gem
- Same structural layout as attack frame

### 3.2 Card Layout — Pixel-Precise Positions

#### Battle Hand Card (220×310 pixels)

The frame texture is scaled to fill 220×310. All child node positions are in the card's local coordinate space.

```
Card root (Control, 220×310)
├── FrameTexture (TextureRect)
│     rect: (0, 0, 220, 310)
│     stretch_mode: SCALE (fill entire card)
│     texture: frame_attack_v2_card.png / frame_skill_v2_card.png / frame_power_v2_card.png
│
├── CardArtRect (TextureRect)
│     rect: (22, 42, 176, 122)      ← art window within frame's black interior
│     stretch_mode: KEEP_ASPECT_CENTERED
│     texture: assets/img/card_art_ironclad/[card_id].png
│     modulate: Color(1,1,1,1)      ← no tint; frame provides color identity
│
├── CostOrb (Control, positioned over frame's built-in gem)
│     rect: (7, 5, 36, 36)
│     └── CostLabel (Label)
│           text: str(card.cost)    ← "0", "1", "2", "3", or "X"
│           horizontal_alignment: CENTER
│           vertical_alignment: CENTER
│           font_size: 24
│           font_color: Color(1,1,1,1)
│           shadow enabled (see §2.3)
│           NOTE: Do NOT draw a new circle here. The frame already has a gem.
│                 Just overlay the label centered on the gem position.
│
├── NameLabel (Label)
│     rect: (12, 168, 196, 26)
│     font_size: 15, SemiBold
│     font_color: Color(1.0, 0.949, 0.847, 1.0)
│     horizontal_alignment: LEFT
│     clip_contents: true
│
├── TypeLabel (Label)
│     rect: (12, 194, 196, 18)
│     text: "ATTACK" / "SKILL" / "POWER"  (uppercase)
│     font_size: 11, Regular
│     font_color: text_muted = Color(0.478, 0.447, 0.376, 0.80)
│
└── DescriptionLabel (RichTextLabel)
      rect: (17, 216, 186, 84)
      font_size: 12, Regular
      font_color: text_secondary = Color(0.749, 0.722, 0.604, 1.0)
      bbcode_enabled: true
      fit_content: false
      clip_contents: true
```

**Art window calibration:** The frame's visible black interior begins at approximately x=22, y=42 in the 220×310 scaled card. The art image (80×80 source) should be scaled to fill 176×122, centered. Use `stretch_mode = KEEP_ASPECT_CENTERED` so portrait or landscape art does not distort.

#### Deck Builder Grid Card (290×390 pixels)

Same structure, different scale. Use the `frame_*_v2_card.png` directly (already 290×390).

```
Card root (Control, 290×390)
├── FrameTexture (TextureRect, 290×390)
├── CardArtRect  rect: (26, 32, 238, 160)   ← proportionally scaled art window
├── CostOrb      rect: (8, 5, 42, 42)        ← slightly larger at grid scale
│     CostLabel  font_size: 24
├── NameLabel    rect: (20, 200, 250, 24)    font_size: 14
├── TypeLabel    rect: (20, 226, 250, 16)    font_size: 11
└── DescriptionLabel  rect: (20, 248, 250, 130)  font_size: 14
```

### 3.3 Cost Number — Special Cases

| card.cost | Display | Color |
|---|---|---|
| 0 | "0" | `Color(0.9, 0.9, 0.9, 1)` grey-white |
| 1–3 | "1", "2", "3" | `Color(1, 1, 1, 1)` white |
| -1 (X cost) | "X" | `Color(1, 0.8, 0.2, 1)` gold |
| < -1 (unplayable) | "—" | `text_muted` |
| Unaffordable (energy < cost) | same number | `Color(1, 0.3, 0.3, 1)` red tint |

When the player cannot afford a card (energy < cost), apply `modulate = Color(0.7, 0.7, 0.7, 0.85)` to the entire card node — do NOT hide it, just dim it.

### 3.4 Selection State Visuals

#### In Deck Builder Grid

| State | modulate | Outline | Scale |
|---|---|---|---|
| Normal | `Color(1, 1, 1, 1)` | None | 1.0 |
| Hovered | `Color(1.05, 1.05, 1.0, 1.0)` | 2px `Color(1,1,1,0.25)` | 1.02 |
| Selected | `Color(0.7, 1.0, 0.7, 1.0)` | 4px `border_gold` | 1.0 |
| Selected + Hovered | `Color(0.75, 1.0, 0.75, 1.0)` | 4px `border_gold` + outer glow | 1.02 |
| Maxed out (not selected) | `Color(0.6, 0.6, 0.6, 0.4)` | None | 1.0 |

**Implementing the outline:** Use a `StyleBoxFlat` on a `Panel` overlay behind the card, or draw with `draw_rect()` in `_draw()`:
```gdscript
# In card's _draw():
if is_selected:
    draw_rect(Rect2(0, 0, size.x, size.y), Color(0.902, 0.722, 0.290, 1.0), false, 4.0)
elif is_hovered:
    draw_rect(Rect2(0, 0, size.x, size.y), Color(1, 1, 1, 0.25), false, 2.0)
```

#### In Battle Hand

| State | modulate | Lift (y offset) | Scale | z_index |
|---|---|---|---|---|
| Resting | `Color(1,1,1,1)` | 0 | 1.0 | position in hand |
| Hovered | `Color(1.05, 1.05, 1.0, 1.0)` | -100px | 1.3 | 100 |
| Selected (targeting) | `Color(1.1, 1.0, 0.7, 1.0)` golden | -200px | 1.3 | 200 |
| Played | — | flies to target | — | 300 |
| Cancelled | `Color(1,1,1,1)` | returns to fan | 1.0 | original |

**Golden selection modulate detail:** `Color(1.1, 1.0, 0.7, 1.0)` gives a warm gold cast without oversaturating the frame colors. This is more subtle than STS's full golden glow but readable.

**Green selection ring for targeted card:** Draw a 3px `Color(0.267, 0.800, 0.400, 1.0)` outline around the card when in targeting mode, matching the `accent_green` token.

---

## 4. Battle HUD Visual Treatment

### 4.1 Energy Orb

**Position:** x=24, y=822 (absolute screen coordinates, bottom-left, overlapping the hand zone)
**Size:** 72×72px

**Visual construction (drawn or textured):**
- Background circle: `Color(0.200, 0.600, 1.0, 1.0)` `#3399FF`
- Outer ring: 3px stroke, `Color(0.5, 0.8, 1.0, 0.9)`
- Inner radial glow: `Color(0.200, 0.600, 1.0, 0.40)` spreading 20px outward from orb edge
- Number text: "3/3" format, 28px bold, `Color(1, 1, 1, 1)` white, centered
- When energy = 0: bg dims to `Color(0.2, 0.2, 0.3, 1.0)`, text color becomes `text_muted`
- Shine: small white ellipse `Color(1,1,1,0.3)` at (18, 14, 24, 12) within the orb circle

**Generating as asset vs. drawing procedurally:** Generate `energy_orb_bg.png` at 72×72 as the decorative ring/glow background. Overlay the text label in Godot. Regenerate the existing `energy_orb.png` (40×40) at correct size 72×72.

### 4.2 HP Bars

**Player HP bar:**
- Position: below player sprite, centered on sprite x (~280px), y=~710
- Size: 160×12px
- Background trough: `Color(0.200, 0.059, 0.059, 1.0)` `#330F0F`, `border_radius=6`
- Fill: `Color(0.800, 0.133, 0.133, 1.0)` `#CC2222`, `border_radius=6`
- Fill width: `(current_hp / max_hp) * 160` pixels
- HP text: "80/80" displayed as Label directly above the bar at y=-18 relative to bar
  - font_size=22, Bold, `text_primary`
- When HP < 25%: fill color shifts to `Color(1.0, 0.4, 0.1, 1.0)` orange-red (critical warning)

**Enemy HP bars:**
- Size: 80×12px
- Same color treatment as player bar
- Position: centered below each enemy sprite
- HP text: "45/45" at font_size=16 above bar

**HP bar damage flash:** On damage received:
- Bar fill briefly flashes `Color(1.0, 1.0, 1.0, 0.8)` for 0.08s then returns to red
- The sprite flashes white modulate for 0.15s

**Block overlay:** When block > 0, draw a second layer over the HP bar's left portion:
- Color: `Color(0.267, 0.533, 1.0, 0.85)` blue
- Width: clamped to bar width, represents block amount relative to max_hp
- Block counter label: displayed as separate node to the left of the HP bar, font_size=16 bold, blue

### 4.3 Player Status Panel

**Position:** x=20, y=760, as HBoxContainer, h=60
**Gap between orb icons:** 12px
**Orb icon size:** 52×52px each

| Orb | Icon asset | Background | Text format | When visible |
|---|---|---|---|---|
| HP | `ui_icons/attack_intent.png` (use heart icon — regenerate) | `Color(0.5, 0.1, 0.1, 0.85)` | "80/80" | Always |
| Block | `ui_icons/defend_intent.png` (shield) | `Color(0.1, 0.2, 0.5, 0.85)` | "12" | Only when block > 0 |
| Strength | `ui_icons/strength.png` (fist) | `Color(0.5, 0.3, 0.1, 0.85)` | "+2" | Only when strength > 0 |

Each orb: circular container, icon at left, text label at right, same row.

### 4.4 Turn Indicator

No dedicated turn-indicator widget is specified in UX_SPEC, but visual distinction between player turn and enemy turn must be clear:

**Player turn:** End Turn button is `Color(0.600, 0.298, 0.102, 0.851)` `#994C1A D9` — warm orange, fully lit
**Enemy turn:** End Turn button dims to `Color(0.200, 0.133, 0.067, 0.60)` `#332211 99`, text = `text_muted`

Additionally during enemy turn:
- Draw a subtle dark vignette `Color(0, 0, 0, 0.25)` over the entire hand area (y=820 to y=1080) to visually indicate no card interaction is possible

### 4.5 Draw / Discard Pile Counters

**Draw pile:** x=1790, y=830
**Discard pile:** x=1860, y=830
**Icon size:** 52×52px each

- Draw pile icon: stack-of-cards appearance, `text_primary` color, slight 3D angle
- Discard pile icon: same but with slight grey/muted tint `modulate = Color(0.8, 0.8, 0.8, 0.85)`
- Count label: below icon, centered, font_size=16 Bold, `text_primary`
- Tooltip (on hover, 0.5s delay): Panel with `surface_panel` bg, `border_gold` 1px border, font_size=13

**Icon generation:** Generate `pile_draw.png` and `pile_discard.png` at 52×52. Show 3 overlapping card backs in isometric-style stack. Draw pile is brighter; discard pile is desaturated.

### 4.6 End Turn Button

**Position:** x=1680, y=762
**Size:** 220×56px
**Corner radius:** 8px

| State | Background Color | Border | Text Color |
|---|---|---|---|
| Normal | `Color(0.600, 0.298, 0.102, 0.851)` | 2px `border_gold` | `Color(1,1,1,1)` |
| Hovered | `Color(0.702, 0.361, 0.133, 0.902)` `#B35C22 E6` | 2px `border_gold` | `Color(1,1,1,1)` |
| Pressed | `Color(0.478, 0.239, 0.078, 1.0)` `#7A3D14` | 2px `border_gold` | `Color(1,1,1,1)` |
| Disabled | `Color(0.200, 0.133, 0.067, 0.60)` `#332211 99` | 1px `border_gold_dim` | `text_muted` |

Text: "END TURN" / "结束回合", 20px Bold, centered. Add 2px drop shadow `Color(0,0,0,0.6)`.

**Pressed animation:** `Tween` scale to `Vector2(0.96, 0.96)` over 0.06s, return over 0.10s.

### 4.7 Top HUD Bar

**Position:** y=0, height=64
**Background:** `surface_panel` = `Color(0.102, 0.071, 0.031, 0.80)` with no bottom border (dungeon bg bleeds through)

| Element | Position | Size | Font | Color |
|---|---|---|---|---|
| Floor label ("Floor 1") | x=20, y=22 | — | 18px Regular | `text_muted` |
| Map icon button | x=950, centered | 48×48 | — | `text_secondary` tint |
| Potion slot 1 | x=1700, y=8 | 48×48 | — | — |
| Potion slot 2 | x=1756, y=8 | 48×48 | — | — |
| Settings icon | x=1880, y=10 | 44×44 | — | `text_secondary` |

---

## 5. Targeting Arrow

### 5.1 Reference Analysis

The STS targeting arrow (from reference image) is a chain of dark red filled chevron/arrow shapes arranged along a bezier curve. Each chevron points toward the target. The chain animates — segments scroll along the curve giving a "flowing toward target" motion. At the terminus, a solid triangular arrowhead larger than the chain segments provides a clear endpoint.

### 5.2 Implementation Spec

**Type:** `Line2D` node for the spine + `Polygon2D` arrowhead + animated texture scroll

**Architecture:**
```
TargetingArrow (Node2D, z_index=200, visible=false)
├── ArrowLine (Line2D)
└── ArrowHead (Polygon2D)
```

**ArrowLine properties:**
```gdscript
arrow_line.width = 5.0
arrow_line.width_curve = Curve  # tapers: 0.4 at start → 1.0 at end
arrow_line.default_color = Color(1.0, 0.25, 0.05, 0.85)  # deep red-orange
arrow_line.texture_mode = Line2D.LINE_TEXTURE_TILE
arrow_line.texture = preload("res://assets/img/ui/arrow_segment.png")  # 24×10px chevron
arrow_line.joint_mode = Line2D.LINE_JOINT_ROUND
arrow_line.begin_cap_mode = Line2D.LINE_CAP_NONE
arrow_line.end_cap_mode = Line2D.LINE_CAP_NONE
```

**Arrow segment texture (`arrow_segment.png` — to be generated):**
- Size: 24×10 pixels
- Content: a single filled chevron ">" shape in dark red `#CC2010` on transparent bg
- The Line2D tiles this texture along the curve
- Animate by offsetting `uv_offset.x` each frame to create scrolling motion:
  ```gdscript
  func _process(delta):
      arrow_line.uv_offset.x -= delta * 48.0  # scroll speed: 48px/sec
  ```

**ArrowHead (Polygon2D):**
```gdscript
arrow_head.polygon = PackedVector2Array([
    Vector2(0, 0),      # tip
    Vector2(-18, -10),  # left base
    Vector2(-12, 0),    # inner notch
    Vector2(-18, 10),   # right base
])
arrow_head.color = Color(1.0, 0.15, 0.05, 1.0)  # solid bright red
# Position and rotate to match the arrow terminus direction each frame
```

**Bezier curve generation:**
```gdscript
func update_arrow(origin: Vector2, terminus: Vector2):
    var mid = (origin + terminus) * 0.5
    var control = mid + Vector2(0, -200)  # lift arc 200px upward
    var points := PackedVector2Array()
    var segments := 24
    for i in range(segments + 1):
        var t = float(i) / float(segments)
        var p = _bezier(origin, control, terminus, t)
        points.append(p)
    arrow_line.points = points
    # Position and rotate arrowhead at terminus
    var dir = (terminus - points[segments - 1]).normalized()
    arrow_head.position = terminus
    arrow_head.rotation = dir.angle()

func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
    return (1 - t) * (1 - t) * p0 + 2 * (1 - t) * t * p1 + t * t * p2
```

**Color gradient override:** Use `gradient` property on Line2D for color fade:
```gdscript
var grad = Gradient.new()
grad.add_point(0.0, Color(1.0, 0.5, 0.15, 0.55))  # orange, semi-transparent at origin
grad.add_point(1.0, Color(1.0, 0.15, 0.05, 1.0))   # red, opaque at terminus
arrow_line.gradient = grad
```

**Enemy highlight when cursor within 80px:**
```gdscript
# Apply to enemy sprite node:
enemy.modulate = Color(1.2, 1.1, 0.6, 1.0)  # warm yellow highlight
# Snap arrow terminus to enemy center:
if origin.distance_to(enemy.global_position) < 80:
    terminus = enemy.global_position
```

**Visibility:** `arrow_node.visible = targeting_mode`

---

## 6. Animation Specifications

### 6.1 Card Hover — Hand

| Property | From | To | Duration | Easing |
|---|---|---|---|---|
| position.y | resting_y | resting_y - 100 | 0.12s | EASE_OUT |
| scale | Vector2(1,1) | Vector2(1.3,1.3) | 0.12s | EASE_OUT |
| rotation | arc_rotation | 0.0 | 0.12s | EASE_OUT |
| z_index | hand_position | 100 | immediate | — |

```gdscript
var tween = create_tween().set_parallel(true)
tween.tween_property(card, "position:y", resting_y - 100, 0.12).set_ease(Tween.EASE_OUT)
tween.tween_property(card, "scale", Vector2(1.3, 1.3), 0.12).set_ease(Tween.EASE_OUT)
tween.tween_property(card, "rotation", 0.0, 0.12).set_ease(Tween.EASE_OUT)
```

**Return to resting (mouse leave):**
Same properties, same duration 0.12s, reversed values, `EASE_IN_OUT`.

### 6.2 Card Selection (targeting mode)

| Property | Value | Duration | Easing |
|---|---|---|---|
| position.y | resting_y - 200 | 0.15s | EASE_OUT |
| modulate | `Color(1.1, 1.0, 0.7, 1.0)` golden | 0.10s | LINEAR |
| scale | Vector2(1.3, 1.3) | held from hover | — |
| z_index | 200 | immediate | — |

### 6.3 Card Play — Fly to Target

When a card is played, it must travel from its current position to the target (enemy or player center), then disappear into the discard pile.

**Phase 1: Fly to target (0.25s)**
```gdscript
var tween = create_tween().set_parallel(true)
tween.tween_property(card, "global_position", target_position, 0.25).set_ease(Tween.EASE_IN)
tween.tween_property(card, "scale", Vector2(0.5, 0.5), 0.25).set_ease(Tween.EASE_IN)
tween.tween_property(card, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
```

**Phase 2: Snap to discard pile icon (0.0s — invisible)**
After phase 1 completes, teleport card (now invisible) to discard pile counter position (x=1860, y=830), briefly flash the discard pile counter number with a scale pulse.

**Discard pile counter pulse:**
```gdscript
# On card entering discard:
var t = discard_label.create_tween()
t.tween_property(discard_label, "scale", Vector2(1.4, 1.4), 0.08).set_ease(Tween.EASE_OUT)
t.tween_property(discard_label, "scale", Vector2(1.0, 1.0), 0.12).set_ease(Tween.EASE_IN)
```

Total card play animation: **0.30s**

### 6.4 Damage Number Popup

Floating damage numbers appear above the entity that took damage.

**Properties:**
```gdscript
# DamageLabel (Label) spawned at entity position
damage_label.text = str(damage_amount)
damage_label.font_size = 36           # large, readable
damage_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))  # bright red
damage_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
damage_label.add_theme_constant_override("shadow_outline_size", 3)
```

**Animation (total 0.9s):**
```gdscript
var tween = create_tween().set_parallel(true)
# Rise upward
tween.tween_property(damage_label, "position:y", start_y - 80, 0.5).set_ease(Tween.EASE_OUT)
# Slight horizontal drift (randomized ±20px)
tween.tween_property(damage_label, "position:x", start_x + randf_range(-20, 20), 0.5)
# Scale punch: grow then shrink
var scale_tween = create_tween()
scale_tween.tween_property(damage_label, "scale", Vector2(1.4, 1.4), 0.08).set_ease(Tween.EASE_OUT)
scale_tween.tween_property(damage_label, "scale", Vector2(1.0, 1.0), 0.12)
# Fade out after 0.4s hold
await get_tree().create_timer(0.4).timeout
var fade = create_tween()
fade.tween_property(damage_label, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
fade.tween_callback(damage_label.queue_free)
```

**Block numbers:** Same behavior but color `Color(0.4, 0.6, 1.0, 1.0)` blue. Text prefixed with "🛡" or just the number.

**Heal numbers:** Color `Color(0.3, 1.0, 0.4, 1.0)` green, text prefixed with "+".

### 6.5 Turn Transition

**Player Turn Start:**
1. Draw cards animate from draw pile position (x=1790, y=830) to their hand positions
2. Each card: `duration=0.15s + (card_index * 0.05s)` stagger delay
3. Cards scale from `Vector2(0.1, 0.1)` at draw pile to `Vector2(1, 1)` at hand position
4. Total for 5 cards: 0.15 + 4×0.05 = 0.35s stagger → last card arrives at 0.50s

**Enemy Turn Start (End Turn pressed):**
1. Hand cards animate to discard pile: fly from hand positions to x=1860, y=830
2. Duration 0.20s each, stagger 0.03s per card (fast sweep)
3. Brief screen-edge vignette darkens `Color(0,0,0,0.2)` for 0.3s indicating enemy control
4. Enemy intent icons pulse: scale 1.0 → 1.2 → 1.0 over 0.4s

**Victory Overlay Entry:**
1. Fade-in from transparent: `modulate.a` 0→1 over 0.4s
2. Title "Victory!" scales in from `Vector2(0.5, 0.5)` to `Vector2(1, 1)` with `EASE_OUT` spring (overshoot 1.05 then settle)
3. Gold particle burst: 30 particles, color `border_gold`, emitted from title center, spread 360°

**Defeat Overlay Entry:**
1. Red vignette `Color(0.3, 0.0, 0.0, 0.85)` fades in over 0.5s
2. "Defeated" title fades in 0.3s delay after vignette starts

### 6.6 Deck Builder Card Selection

```gdscript
# On select:
var tween = create_tween()
tween.tween_property(card, "modulate", Color(0.7, 1.0, 0.7, 1.0), 0.12).set_ease(Tween.EASE_OUT)
card.queue_redraw()  # triggers outline draw

# Counter label number animation:
var count_tween = create_tween()
count_tween.tween_property(counter_label, "scale", Vector2(1.2, 1.2), 0.08)
count_tween.tween_property(counter_label, "scale", Vector2(1.0, 1.0), 0.12)
```

Screen transition to battle (Confirm pressed):
```gdscript
# Fade to black over 0.4s:
var overlay = ColorRect.new()  # full screen, Color(0,0,0,1), starts alpha=0
add_child(overlay)
var t = overlay.create_tween()
t.tween_property(overlay, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_IN)
t.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/battle.tscn"))
```

---

## 7. Asset Requirements

### 7.1 New Assets to Generate

| Asset | Path | Size | Description | Priority |
|---|---|---|---|---|
| Energy orb (regenerate) | `assets/img/ui_icons/energy_orb.png` | 72×72 | Blue glowing orb with decorative ring, shine highlight. No text — text overlaid in Godot. Match STS blue orb aesthetic. | HIGH |
| Arrow segment | `assets/img/ui/arrow_segment.png` | 24×10 | Single dark-red chevron ">" on transparent background, for tiling along targeting arrow Line2D | HIGH |
| Draw pile icon | `assets/img/ui/pile_draw.png` | 52×52 | Stack of 3 overlapping card backs, slight 3D angle, warm gold-brown tones | HIGH |
| Discard pile icon | `assets/img/ui/pile_discard.png` | 52×52 | Same stack, desaturated/greyed to indicate used cards | HIGH |
| Heart icon (HP) | `assets/img/ui_icons/hp_heart.png` | 32×32 | Simple bold heart shape, deep red `#CC2222`, white outline 2px | HIGH |
| Selection glow | `assets/img/ui/card_selected_glow.png` | 240×330 | Soft green glow/halo for selected card in hand, RGBA. Drawn around card edges. | MEDIUM |
| Victory particle | `assets/img/ui/victory_spark.png` | 16×16 | Star/spark shape in gold, for particle system | MEDIUM |

### 7.2 Existing Assets to Modify

| Asset | Current Issue | Required Change |
|---|---|---|
| `assets/img/ui_icons/energy_orb.png` | 40×40px, too small | Regenerate at 72×72 — full size as per HUD spec |
| Card art (`card_art_ironclad/*.png`, `card_art_silent/*.png`) | 80×80px | These are adequate. Do NOT regenerate at larger size — 80×80 will be scaled to fill the 176×122 art window in the card frame. The frame context provides quality. |
| `assets/img/dungeon_bg.png` | Unknown quality | Verify it reads as warm stone dungeon at 1920×1080. Should have atmospheric depth with darker foreground floor. If generated as flat tile, regenerate as single drawn scene. |

### 7.3 Assets to Leave Unchanged

| Asset | Reason |
|---|---|
| `frame_attack_v2.png` / `frame_skill_v2.png` / `frame_power_v2.png` | High-quality 896×1200 master frames. Use as source of truth. |
| `frame_attack_v2_card.png` / `frame_skill_v2_card.png` / `frame_power_v2_card.png` | 290×390 pre-scaled versions are correct for deck builder grid. |
| All sprite assets (`ironclad.png`, `slime.png`, etc.) | Character sprites at correct sizes for battle arena. |
| All intent icons (32×32 and 24×24 series) | Already generated at correct sizes. |

### 7.4 Font Assets

| Font File | Usage | Source |
|---|---|---|
| `assets/fonts/cinzel_bold.ttf` | Headings, card names, cost numbers | Google Fonts: Cinzel (OFL license) |
| `assets/fonts/lato_regular.ttf` | Card descriptions, HUD labels | Google Fonts: Lato (OFL license) |
| `assets/fonts/lato_bold.ttf` | HUD values, button text | Google Fonts: Lato Bold |

If font loading fails, fall back to Godot's built-in `ThemeDB.fallback_font` — the sizing overrides still apply.

---

## 8. Implementation Notes for Programmer

### 8.1 Frame Texture Scaling

The `frame_*_v2_card.png` files are 290×390. For the **battle hand** (220×310), scale the same texture down using `TextureRect.stretch_mode = SCALE`. Do not generate separate 220×310 frame textures — the scaling is imperceptible at game resolution.

### 8.2 Card Art Positioning

Card art (80×80 source) is scaled to fill a 176×122 (hand) or 238×160 (grid) window. These art windows are centered within the frame's interior black area. The exact pixel positions given in §3.2 are calibrated to the visual frame boundaries visible in `frame_attack_v2.png`. If art overflow occurs, set `clip_contents = true` on the art TextureRect.

### 8.3 Cost Orb — Do Not Double-Draw

The frame textures already include a decorative gem/orb shape at the upper-left corner. Only overlay a `Label` node — do not add any additional circle, panel, or background behind the cost label. The frame provides the gem.

The gem center in the 290×390 frame is approximately at pixel (29, 27) from top-left. In 220×310 scaled: approximately (22, 21). Center the Label over this point.

### 8.4 Z-Index Reference

| Layer | z_index | Contents |
|---|---|---|
| Background | -10 | dungeon_bg TextureRect |
| Sprites | 0 | Player, enemies |
| HP bars | 10 | Entity HP/status overlays |
| Hand resting | 20–29 | Cards in fan arc (by position) |
| Hand hovered | 100 | Hovered card |
| Hand selected | 200 | Card in targeting mode |
| Targeting arrow | 150 | Arrow Line2D |
| Damage numbers | 250 | Spawned damage labels |
| HUD overlays | 300 | Energy, end turn, piles |
| Victory/Defeat overlay | 400 | Full-screen modals |

### 8.5 RichTextLabel BBCode Tags in Descriptions

Card descriptions support these tags:
```
[color=#FF8888]6 damage[/color]   ← attack values in red
[color=#88FFAA]5 block[/color]    ← block values in green
[b]Keyword[/b]                     ← keywords bold for tooltip trigger
```

The `DescriptionLabel` node must have `bbcode_enabled = true` and `fit_content = false` with `clip_contents = true` on its container.
