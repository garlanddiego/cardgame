# UX Specification — Card Roguelike (Godot 4)
## Slay the Spire-style · Viewport 1920×1080 · Touch + Mouse

---

## Table of Contents

1. [Design System](#1-design-system)
2. [Deck Builder Screen](#2-deck-builder-screen)
3. [Battle Screen](#3-battle-screen)
4. [Card Component](#4-card-component)
5. [Interaction Patterns](#5-interaction-patterns)
6. [Accessibility](#6-accessibility)
7. [Data Contracts](#7-data-contracts)
8. [State Machines](#8-state-machines)

---

## 1. Design System

### 1.1 Color Palette

| Token              | Hex / RGBA             | Usage                                  |
|--------------------|------------------------|----------------------------------------|
| `bg-dungeon`       | `#0D0A07`              | Fullscreen scene background            |
| `surface-panel`    | `#1A1208 CC`           | HUD panels, bottom bar                 |
| `surface-card`     | `#110D08 F2`           | Card background fallback               |
| `border-gold`      | `#E6B84A`              | Panel borders, selected ring           |
| `accent-orange`    | `#FF6624`              | End Turn button, targeting arrow       |
| `accent-green`     | `#44CC66`              | Selected card highlight, confirm btn   |
| `accent-red`       | `#CC2222`              | HP bars, defeat overlay                |
| `text-primary`     | `#F2EDD8`              | Card names, HUD values                 |
| `text-secondary`   | `#BFB89A`              | Card descriptions, type labels         |
| `text-muted`       | `#7A7260 CC`           | Pile counts, floor labels              |
| `intent-attack`    | `#FF4444 CC`           | Enemy attack intent icon               |
| `intent-defend`    | `#4488FF CC`           | Enemy block intent icon                |
| `intent-unknown`   | `#AAAAAA 99`           | Unknown/buff intent icon               |
| `energy-orb`       | `#3399FF`              | Energy orb background                  |

### 1.2 Typography

| Role               | Size (px) | Weight   | Notes                                     |
|--------------------|-----------|----------|-------------------------------------------|
| Screen title       | 36        | Bold     | "Build Your Deck" header                  |
| Card name (hand)   | 15        | SemiBold | Card name label in 220×310 card           |
| Card name (grid)   | 14        | SemiBold | Card name label in 290×390 grid card      |
| Card description   | 12–14     | Regular  | RichText, bbcode enabled                  |
| Card type badge    | 10–12     | Regular  | Muted, uppercase recommended              |
| Cost number        | 22–24     | Bold     | Inside orb, white/gold                    |
| HUD values         | 22        | Bold     | HP, block, energy readouts                |
| HUD labels         | 13        | Regular  | "HP", "Block", pile counts                |
| Button text        | 20        | Bold     | End Turn, Confirm                         |
| Tooltip text       | 13        | Regular  | Keyword explanations                      |

### 1.3 Spacing & Sizing

| Token              | Value    | Notes                                   |
|--------------------|----------|-----------------------------------------|
| `touch-min`        | 44 px    | Minimum interactive target (WCAG 2.5.8) |
| `touch-comfortable`| 60 px    | Preferred for primary actions           |
| `card-hand`        | 220×310  | Battle hand card size                   |
| `card-grid`        | 290×390  | Deck builder grid card size             |
| `card-grid-gap`    | 32 px    | Gap between grid columns                |
| `panel-padding`    | 16 px    | Inner padding for HUD panels            |
| `border-radius`    | 8 px     | Buttons, panels                         |
| `hp-bar-h`         | 12 px    | HP bar height under entity              |

---

## 2. Deck Builder Screen

### 2.1 User Flow

```
Game Launch
    │
    ▼
[DECK BUILDER SCREEN]
    │
    ├─ Character pre-selected: Ironclad (character_id = "ironclad")
    │
    ├─ Grid populated: all cards where card["character"] == character_id
    │   sorted by type (Attack → Skill → Power) then alphabetically
    │
    ├─ User browses → scrolls grid → taps card
    │   ├─ Not selected → SELECT (green modulate, counter +1)
    │   └─ Already selected → DESELECT (white modulate, counter -1)
    │
    ├─ Counter shows "Selected: N / 10" (localized)
    │
    ├─ Confirm button
    │   ├─ DISABLED when 0 cards selected
    │   └─ ENABLED when ≥ 1 card selected
    │       └─ Tap → emit deck_confirmed(deck) → transition to BattleScene
    │
    └─ Language toggle: [中文] [English]
        └─ All card text + UI labels hot-swap immediately (no reload)
```

### 2.2 Layout — 1920×1080

```
┌────────────────────────────────────────────────────────────────────────────────┐
│ TOP BAR  y=0..72  h=72                                                         │
│  ┌──────────────────────────────────────────────────────────────────────────┐  │
│  │  [Title: "Build Your Deck"]  x=960 center  │  [中文] [English]  x=1780  │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│  bg: surface-panel, border-bottom: 1px border-gold                             │
├────────────────────────────────────────────────────────────────────────────────┤
│ SCROLL AREA  y=72..988  h=916                                                  │
│  ScrollContainer fills this zone, ClipContent=true                             │
│                                                                                │
│  CardGrid (GridContainer)                                                      │
│    columns = 6                                                                 │
│    separation = 32px horizontal, 32px vertical                                 │
│    margin: left=10px, right=10px, top=16px, bottom=16px                        │
│                                                                                │
│  Card cell size = 290×390 px                                                   │
│  Grid row height = 390+32 = 422px  (shows ~2 full rows at 1080)               │
│                                                                                │
│  75 cards → 13 rows max → total scroll height ≈ 5486px                        │
│                                                                                │
│  CARD CELL LAYOUT (290×390):                                                   │
│    [0,0]─────────[290,0]                                                       │
│    │  Frame texture (full bleed)                │                              │
│    │  ┌─[26,32]──────────[264,192]─┐            │                              │
│    │  │  Card Art   238×160        │            │                              │
│    │  └────────────────────────────┘            │                              │
│    │  Cost circle [8,5] 32×32                   │                              │
│    │  Name label  [20,200] 250×24  font=14      │                              │
│    │  Type badge  [20,226] 250×16  font=10      │                              │
│    │  Desc text   [20,248] 250×130 font=14      │                              │
│    [0,390]──────[290,390]                                                      │
│                                                                                │
│  SELECTION STATE:                                                              │
│    Unselected: modulate = Color(1,1,1,1)                                       │
│    Selected:   modulate = Color(0.7,1.0,0.7,1.0)  +  4px border-gold ring    │
│                                                                                │
├────────────────────────────────────────────────────────────────────────────────┤
│ BOTTOM BAR  y=988..1080  h=92                                                  │
│  bg: surface-panel, border-top: 2px border-gold                                │
│                                                                                │
│  ┌────────────────────────────────────────────────────────────────────────┐    │
│  │ [Selected: N/10 label]  x=40   │   [CONFIRM DECK button]  x=1680     │    │
│  │  font=22 bold  text-primary    │   w=200 h=60  accent-green           │    │
│  └────────────────────────────────────────────────────────────────────────┘    │
│  HBoxContainer, anchored full-width, padding=16px                              │
└────────────────────────────────────────────────────────────────────────────────┘
```

### 2.3 Element Specifications

#### Top Bar (y=0, h=72)
- Background: `surface-panel` with 1px bottom border `border-gold`
- **Title Label** — "Build Your Deck" / "选择卡牌"
  - Position: centered horizontally, y=18
  - Font: 36px bold, `text-primary`
- **Language Toggle Group** — right-aligned
  - Position: x=1740, y=14
  - [中文] button: w=72 h=44, `surface-panel` bg, `border-gold` border 2px
  - [English] button: w=90 h=44, same style
  - Active language: `border-gold` border + slightly brighter bg
  - Gap between buttons: 8px

#### Scroll Area (y=72 to y=988)
- `ScrollContainer` with `SCROLL_HORIZONTAL_DISABLED`
- Vertical scrollbar: w=8px, styled gold-on-dark, auto-hide after 1.5s idle
- Scroll physics: friction deceleration for touch swipe feel

#### Card Grid
- `GridContainer`, columns=6, h_separation=32, v_separation=32
- Left/right margin=10px (so usable width = 1900px → 6×290+5×32=1900 exact fit)
- Cards sorted: Attack (red frames) → Skill (green frames) → Power (purple frames)
- Optional: type section divider labels "Attack" / "Skill" / "Power" as full-width row headers

#### Card Selection Visual
| State       | Modulate                | Outline                     | Scale  |
|-------------|-------------------------|-----------------------------|--------|
| Normal      | `Color(1,1,1,1)`        | None                        | 1.0    |
| Hovered     | `Color(1.05,1.05,1,1)`  | 2px `#FFFFFF40`             | 1.02   |
| Selected    | `Color(0.7,1.0,0.7,1)`  | 4px `border-gold`           | 1.0    |
| Sel+Hover   | `Color(0.75,1.0,0.75,1)`| 4px `border-gold` + glow    | 1.02   |

#### Bottom Bar (y=988, h=92)
- **Counter Label** — "Selected: N / 10" / "已选: N/10"
  - x=40, vertically centered in bar
  - Font: 22px bold, `text-primary`
  - Animates number with tween when count changes
- **Confirm Button**
  - Size: 200×60px (touch-comfortable ≥44px)
  - Anchored: right edge at x=1880, vertically centered
  - Disabled state: bg=`#333`, text=`#666`, no interaction
  - Enabled state: bg=`accent-green`, border=`border-gold` 2px, text=white
  - Hover: bg brightens +10%
  - Pressed: bg darkens -10%, scales to 0.96

### 2.4 Deck Builder Interaction Flow

```
Mouse/Touch Enter card
    → modulate brighten (0.12s tween)

Click/Tap card
    → if NOT selected:
        → selected_card_ids[card_id] = true
        → modulate = Color(0.7, 1.0, 0.7, 1.0)
        → counter animates +1
        → haptic pulse (mobile, 10ms)
    → if IS selected:
        → selected_card_ids.erase(card_id)
        → modulate = Color(1,1,1,1)
        → counter animates -1

Counter reaches 10 (MAX_DECK_SIZE)
    → remaining unselected cards dim to 0.4 alpha
    → tooltip: "Deck full — deselect a card to swap"

Click/Tap Confirm
    → disabled if count == 0 (should not reach — button hidden)
    → collect selected_card_ids.keys() → Array
    → gm.player_deck = deck
    → emit deck_confirmed(deck)
    → screen transition: fade-to-black 0.4s → load BattleScene

Language Toggle
    → loc.set_language("zh" or "en")
    → _refresh_all_localized_text() — hot-swap in-place, no scroll reset
```

---

## 3. Battle Screen

### 3.1 User Flow — Turn Cycle

```
[BATTLE SCREEN ENTRY]
    │
    ├─ start_battle(character_id) called
    ├─ _setup_player() — entity node at PlayerArea
    ├─ _setup_enemies() — 1–3 enemies at EnemyArea
    ├─ _build_deck() — shuffle player deck
    │
    ▼
[PLAYER TURN START]
    ├─ turn_number += 1
    ├─ current_energy = max_energy (3)
    ├─ draw cards_per_draw (5) from draw_pile → hand
    │   └─ if draw_pile empty → shuffle discard_pile → draw_pile
    ├─ Update HUD: energy, draw count, discard count
    ├─ Enemy intents update (AI pre-plans next action)
    ├─ End Turn button ENABLED
    │
    ▼
[PLAYER ACTION PHASE]  ←──────────────────────────────────────────────┐
    │                                                                   │
    ├─ Hover card → ZOOM + LIFT (no click yet)                         │
    │                                                                   │
    ├─ Click card (targeted spell)                                      │
    │   ├─ card enters SELECTED state (golden modulate)                 │
    │   ├─ targeting_mode = true                                        │
    │   ├─ targeting arrow appears (orange bezier from card to cursor)  │
    │   ├─ hover enemy → enemy highlights                               │
    │   ├─ click enemy → play card on enemy                             │
    │   │   ├─ energy -= card.cost                                      │
    │   │   ├─ card removed from hand                                   │
    │   │   ├─ effect applied                                           │
    │   │   └─ card moves to discard pile (visual)                      │
    │   └─ click empty space / click card again → CANCEL targeting     │
    │                                                                   │
    ├─ Click card (non-targeted: self/all_enemies)                      │
    │   ├─ card enters SELECTED state                                   │
    │   ├─ targeting_mode = true                                        │
    │   ├─ click anywhere valid → play immediately                      │
    │   └─ right-click / click card again → CANCEL                     │
    │                                                                   │
    ├─ Energy reaches 0 → remaining cards dim but remain playable       │
    │   (energy cards show red cost number)                             │
    │                                                                   │
    └─ [End Turn Button] pressed ─────────────────────────────────────▶│
                                                                        │
[PLAYER TURN END]                                                       │
    ├─ Discard remaining hand                                           │
    ├─ Apply end-of-turn effects (flex, barricade check, etc.)         │
    ├─ End Turn button DISABLED                                         │
    │                                                                   │
    ▼                                                                   │
[ENEMY TURN]                                                            │
    ├─ Each enemy executes intent sequentially                          │
    ├─ Attack: animate lunge → player takes damage → HP bar updates     │
    ├─ Defend: enemy gains block (shield icon flash)                    │
    ├─ Buff: particle effect on enemy                                   │
    ├─ AI plans next intent → intent icons update                       │
    │                                                                   │
    ▼                                                                   │
[CHECK WIN/LOSE]                                                        │
    ├─ All enemies dead → VICTORY                                       │
    └─ Player HP ≤ 0 → DEFEAT                                          │
    │                                                                   │
    └─ Otherwise → back to PLAYER TURN START ──────────────────────────┘

[VICTORY OVERLAY]
    ├─ Golden rays particle effect
    ├─ "Victory!" title (52px, bold, gold)
    ├─ Loot display (future: relic/card reward)
    └─ [Continue] button → next room or main menu

[DEFEAT OVERLAY]
    ├─ Red vignette fade-in
    ├─ "Defeated" title (52px, bold, red)
    └─ [Retry] / [Main Menu] buttons
```

### 3.2 Layout — 1920×1080

```
┌────────────────────────────────────────────────────────────────────────────────┐
│ TOP HUD BAR  y=0..64  h=64                                                     │
│  bg: surface-panel 80% opacity, no bottom border needed (dungeon bg shows)     │
│                                                                                │
│  [Floor Label]     [Map icon]       [Potion slots]    [Settings icon]          │
│   x=20 y=20         x=950            x=1700            x=1880                  │
│   font=18 muted     48×48 btn        2× 48×48 slots    44×44 btn               │
├────────────────────────────────────────────────────────────────────────────────┤
│ BATTLE ARENA  y=64..760  h=696                                                 │
│  Full dungeon background art                                                   │
│                                                                                │
│  PLAYER AREA  x=80..480  anchored bottom of arena                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  Player sprite                  Enemy Area  x=800..1840                 │   │
│  │    ~320px tall                                                          │   │
│  │    grounded at y=700            Enemy 0    Enemy 1    Enemy 2           │   │
│  │                                 x=900      x=1120     x=1340            │   │
│  │  [Name label]                   each ~200-320px tall, grounded y=700   │   │
│  │   below sprite                                                          │   │
│  │                                 [Intent icon above each enemy]          │   │
│  │  [HP bar]  160×12px             [HP bar]   [HP bar]   [HP bar]         │   │
│  │   below name                    80×12px each                           │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                │
│  TARGETING ARROW  (Line2D overlay, z=200)                                      │
│    Origin: selected card center                                                │
│    Terminus: mouse/finger position                                             │
│    Style: orange bezier, width=4px, arrowhead at terminus                      │
│    Visible only when targeting_mode=true                                       │
│                                                                                │
├────────────────────────────────────────────────────────────────────────────────┤
│ STATUS / ENERGY ROW  y=760..820  h=60                                          │
│                                                                                │
│  PLAYER STATS (left)  x=20..300                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │ [♥ HP orb] 52×52   [🛡 Shield orb] 52×52                               │   │
│  │  80/80             0                                                    │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                │
│  ENERGY ORB (center-left)  x=20..100  y=820 (overlaps hand)                  │
│  ┌──────────┐                                                                  │
│  │  ③ / ③  │  72×72 circle, blue glow, bold 28px                            │
│  └──────────┘                                                                  │
│                                                                                │
│  PILE COUNTS  right side  x=1780..1920  y=760..820                            │
│  ┌──────────────────────────────────────────────────────────────────────────┐  │
│  │ [Draw pile icon + count]  [Discard icon + count]                         │  │
│  │    x=1780 52×52              x=1860 52×52                                │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│                                                                                │
│  END TURN BUTTON  x=1680..1900  y=762..818                                    │
│  ┌──────────────────┐                                                          │
│  │   END TURN       │  220×56px, accent-orange bg, border-gold border 2px    │
│  │                  │  font=20 bold white                                     │
│  └──────────────────┘                                                          │
│                                                                                │
├────────────────────────────────────────────────────────────────────────────────┤
│ HAND AREA  y=820..1080  h=260                                                  │
│  Node2D CardHand, positioned at y=1080 (cards hang off bottom in resting)     │
│                                                                                │
│  Cards in fan arc:                                                             │
│    CARD_WIDTH=220  CARD_HEIGHT=310  CARD_OVERLAP=80                           │
│    step = 220-80 = 140px between card origins                                 │
│    5 cards: total_width = 4×140+220 = 780px                                   │
│    start_x = (1920-780)/2 = 570px  →  cards span x=570..1350                 │
│    Arc: MAX_ROTATION=8°, cards curve up at edges, center card flat            │
│    ARC_HEIGHT=20px droop at edges                                              │
│                                                                                │
│  Resting position: card tops visible at ~y=840 (270px of card shows)         │
│  Hover position: card lifts 100px → card top at ~y=740                       │
│  Scale on hover: 1.3× → effective size 286×403                                │
│  z_index: leftmost=0, rightmost=N, hovered=100 (always on top)               │
└────────────────────────────────────────────────────────────────────────────────┘
```

### 3.3 HUD Element Specifications

#### Player Status Panel (y=760, left)
- Container: HBoxContainer, x=20, y=760, h=60
- **HP Orb** — circular icon w=52 h=52
  - Icon: heart, `accent-red`
  - Label: "80/80", font=22 bold, `text-primary`
  - Label position: right of icon
- **Block Orb** — w=52 h=52
  - Icon: shield, `#4488FF`
  - Count: appears when block > 0, hidden or shows "0" when none
  - Clears at start of each player turn (unless Barricade)
- **Strength Orb** (if active) — w=52 h=52
  - Icon: fist, `#FF8844`
  - Count: permanent strength bonus

#### Energy Orb (y=820, overlaps hand zone)
- Position: x=24, y=822 (bottom-left corner, above hand)
- Size: 72×72px circle
- BG: `energy-orb` blue, radial glow
- Text: "3/3" or "2/3" format, 28px bold, white
- When energy=0: bg dims to grey, text turns muted

#### Draw/Discard Pile Counters (bottom-right, y=830)
- Two stacked-card icon buttons, each 52×52
- **Draw Pile** — x=1790, y=830
  - Stack-of-cards icon
  - Count label below: font=16, `text-primary`
  - Tooltip on hover: "Draw Pile: N cards"
  - Click: show draw pile contents (modal, future feature)
- **Discard Pile** — x=1860, y=830
  - Same visual, muted tint
  - Tooltip: "Discard: N cards"

#### Intent Display (above each enemy)
- Positioned 40px above enemy sprite's top edge
- Icon: 36×36px sprite
  - Sword = attack (red), shield = block (blue), star = buff/unknown
- Damage amount label: font=18 bold, red, right of icon
- Horizontal layout: [icon][space][value]
- Minimum touch target: 44×44 (icon + label combined)

#### End Turn Button
- Position: x=1680, y=762, size=220×56px
- Normal: bg=`#994C1A D9`, border=`border-gold` 2px, text="End Turn" white 20px bold
- Hover: bg=`#B35C22 E6`
- Pressed: bg=`#7A3D14`, scale=0.96 (12ms)
- Disabled (enemy turn): bg=`#332211 99`, text=muted, pointer-events=none
- Corner radius: 8px

### 3.4 Card Hand Interaction

#### Card States in Hand

| State             | Visual Change                                          | Duration  |
|-------------------|--------------------------------------------------------|-----------|
| Resting           | Fan arc, slight rotation, natural z-order              | —         |
| Hovered (mouse)   | Lifts 100px, scale 1.3×, rotation=0, z=100            | 0.12s     |
| Selected          | Lifts to y-200 (above others), golden modulate         | 0.15s     |
| Targeting mode    | Selected card stays raised, arrow follows cursor       | realtime  |
| Played            | Flies toward target then fades to discard, 0.3s tween | 0.3s      |
| Cancelled         | Springs back to fan position                           | 0.12s     |

#### Two-Step Play Flow (Targeted Cards)

```
Step 1 — Selection
  Mouse: hover to inspect → click to select
  Touch: tap card to select (no hover state)
  Result: card lifts, golden tint, targeting_mode=true, arrow appears

Step 2 — Target Confirmation
  Mouse: move cursor to enemy (arrow tracks) → click enemy
  Touch: tap enemy directly
  Result: card_played.emit(card_data, target) → card removed from hand

Cancel
  Mouse: right-click anywhere, or click selected card again
  Touch: tap selected card again, or tap empty arena space
  Result: targeting_mode=false, arrow hides, card returns to fan
```

#### Non-Targeted Cards (target="self" or target="all_enemies")

```
Step 1 — Selection (same as above)
  targeting_mode=true, no arrow shown (or show a pulse glow on valid targets)

Step 2 — Confirmation
  Mouse: click anywhere in the arena (not a card)
  Touch: tap anywhere in arena
  Result: play immediately (target = player for self, or all enemies)

  Alternative: show a [Play] confirmation button above the hand
  after selection for clarity on mobile.
```

### 3.5 Targeting Arrow Specification

Referencing the STS targeting arrow image — the arrow is a bezier curve with red/orange chevron segments, not a straight line:

- **Type**: Line2D with gradient + arrowhead polygon
- **Origin**: center of selected card's current position
- **Terminus**: mouse cursor or finger position
- **Style**:
  - Start color: `Color(1.0, 0.5, 0.15, 0.7)` orange, translucent
  - End color: `Color(1.0, 0.2, 0.05, 1.0)` red, opaque
  - Width: 4px, tapers from 2px at origin to 6px at tip
- **Arrowhead**: 3-point polygon at terminus, 20×14px, same red
- **Curve**: bezier — control point is 200px above the midpoint, creating a natural arc
- **Enemy highlight on approach**: when cursor within 80px of enemy center:
  - Enemy gets yellow outline shader or modulate `Color(1.2, 1.1, 0.6)`
  - Arrow tip "snaps" to enemy center (magnetic, within 80px radius)

### 3.6 Victory / Defeat Overlays

#### Victory Overlay
```
Centered modal, 800×500px, bg surface-panel, border-gold 3px
├─ Title: "Victory!" — 52px bold, border-gold color, centered, y=60
├─ Subtitle: "Enemies defeated" — 22px, text-secondary, centered, y=120
├─ [Gold reward or relic art] — future feature placeholder, y=160..320
├─ [Continue →] button — 240×60, accent-green, centered x, y=400
└─ Gold particle burst animation behind modal
```

#### Defeat Overlay
```
Full-screen dark red vignette (Color(0.3, 0, 0, 0.85)) fades in over 0.5s
├─ Title: "Defeated" — 52px bold, #CC3333, centered, y=400
├─ [Retry] button — 180×60, accent-orange, x=760, y=500
└─ [Main Menu] button — 180×60, surface-panel+border, x=980, y=500
```

---

## 4. Card Component

### 4.1 Card Anatomy (220×310 — battle hand size)

```
[0,0]──────────────[220,0]
│  ┌──[7,5]──────────────┐  │
│  │ Cost   36×36        │  │
│  └─────────────────────┘  │
│                           │
│  ┌──[22,42]────────────┐  │
│  │ Card Art  176×122   │  │
│  └─────────────────────┘  │
│                           │
│  ┌──[12,168]───────────┐  │
│  │ Name  196×26  15px  │  │
│  └─────────────────────┘  │
│  ┌──[12,194]───────────┐  │
│  │ Type  196×18  12px  │  │
│  └─────────────────────┘  │
│  ┌──[17,216]───────────┐  │
│  │ Desc  186×84  12px  │  │
│  └─────────────────────┘  │
[0,310]────────────[220,310]
```

### 4.2 Card Type Color Coding

| Type    | Frame Texture                           | Cost Orb Color | Name Color        |
|---------|-----------------------------------------|----------------|-------------------|
| Attack  | `card_frame_attack_clean.png` (red)     | `#FF8888`      | `Color(1,.95,.85)`|
| Skill   | `card_frame_skill.png` (green/teal)     | `#88FFAA`      | `Color(1,.95,.85)`|
| Power   | `card_frame_power_clean.png` (purple)   | `#BB88FF`      | `Color(1,.95,.85)`|
| Status  | `card_frame_skill.png` (fallback)       | White          | Muted             |

### 4.3 Card Data Fields Read by UI

```gdscript
{
  "id":          String,   # unique key, used in selected_card_ids dict
  "character":   String,   # "ironclad" — filters cards for current character
  "type":        int,      # 0=Attack, 1=Skill, 2=Power, 3=Status
  "name":        String,   # EN name, overridden by Loc.card_name(card)
  "description": String,   # EN desc, overridden by Loc.card_desc(card)
  "cost":        int,      # -1 = X cost, <-1 = no cost (unplayable/innate)
  "target":      String,   # "enemy", "self", "all_enemies"
  "art":         String,   # res:// path to art texture (optional)
  "damage":      int,      # used by description template
  "block":       int,      # used by description template
}
```

---

## 5. Interaction Patterns

### 5.1 Mouse (Desktop 1920×1080)

| Action              | Trigger                         | Feedback                                  |
|---------------------|---------------------------------|-------------------------------------------|
| Browse cards        | Move cursor over grid           | Card brightens, cursor=pointer            |
| Select card (deck)  | Left-click                      | Green modulate, counter updates           |
| Deselect card       | Left-click selected card        | Modulate resets                           |
| Scroll grid         | Mouse wheel or drag scrollbar   | Smooth momentum scroll                    |
| Hover hand card     | Move cursor over card           | Card lifts 100px, scale 1.3×, 0.12s ease |
| Select hand card    | Left-click hovered card         | Golden tint, targeting arrow appears      |
| Target enemy        | Move cursor → click enemy       | Arrow tracks, enemy highlights, card plays|
| Cancel targeting    | Right-click or click card again | Arrow hides, card returns to hand         |
| End turn            | Left-click End Turn button      | Button press anim, enemy turn begins      |
| Confirm deck        | Left-click Confirm button       | Screen transition                         |

### 5.2 Touch (Mobile / Tablet)

| Action              | Trigger                         | Feedback                                  |
|---------------------|---------------------------------|-------------------------------------------|
| Browse cards        | Swipe up/down on grid           | Momentum scroll, snap behavior            |
| Select card (deck)  | Tap                             | Green modulate + haptic pulse             |
| Deselect card       | Tap selected card               | Modulate resets + haptic                  |
| Inspect card        | Long-press (400ms)              | Large card preview modal, 1.5× size       |
| Select hand card    | Tap                             | Card lifts, targeting mode activates      |
| Target enemy        | Tap enemy                       | Card plays, no arrow needed (tap-to-play) |
| Cancel targeting    | Tap selected card again         | Card returns to fan                       |
| End turn            | Tap End Turn (220×56 target)    | Ripple animation                          |
| Scroll hand         | Swipe left/right on hand area   | Reveals hidden cards if count > 7         |

### 5.3 Keyboard / Gamepad (future)

| Key              | Action                          |
|------------------|---------------------------------|
| `1`–`5`          | Select card by hand position    |
| `Enter` / `A`    | Confirm selection / play        |
| `Escape` / `B`   | Cancel targeting                |
| `Tab`            | Cycle through enemies           |
| `E`              | End turn                        |
| Arrow keys       | Scroll deck grid                |

---

## 6. Accessibility

### 6.1 Touch Target Sizes

All interactive elements meet WCAG 2.5.5 (AAA, 44×44px minimum). Primary actions meet the recommended 60px.

| Element                  | Actual Size  | Min Required | Status |
|--------------------------|--------------|--------------|--------|
| Grid card (deck builder) | 290×390      | 44×44        | PASS   |
| Hand card (battle)       | 220×310      | 44×44        | PASS   |
| End Turn button          | 220×56       | 44×44        | PASS   |
| Confirm button           | 200×60       | 44×44        | PASS   |
| Language toggle (中文)   | 72×44        | 44×44        | PASS   |
| Language toggle (English)| 90×44        | 44×44        | PASS   |
| Energy orb (info only)   | 72×72        | N/A (info)   | —      |
| Draw/Discard counters    | 52×52        | 44×44        | PASS   |
| Intent icon + label      | ~80×44       | 44×44        | PASS   |
| Settings icon            | 44×44        | 44×44        | PASS   |

### 6.2 Text Readability

- **Minimum font size**: 12px (card description at 220×310 size). At 1920×1080 this is readable. On mobile (720p equivalent), description text should increase to 14px minimum.
- **Line height**: 1.4× for all body text labels.
- **Card description contrast**: `Color(0.85, 0.82, 0.75)` on `Color(0.08, 0.06, 0.04)` = approx 9:1 contrast ratio — WCAG AAA (7:1 required).
- **Card name contrast**: `Color(0.95, 0.92, 0.85)` on dark frame — approx 8:1 — WCAG AAA.
- **HP values**: `text-primary` on `surface-panel` — approx 10:1 — WCAG AAA.
- **Cost number**: white on colored orb — minimum 4.5:1 ensured by orb darkness — WCAG AA.

### 6.3 Color Differentiation

- Card type differentiation relies on both frame color AND type label text — not color alone.
- Selection state uses green modulate AND a gold border ring — not color alone.
- Enemy intent uses icon shape AND color AND damage number — not color alone.
- HP bars use red color AND numerical label — not color alone.

### 6.4 Motion Sensitivity

- All tweens use `EASE_OUT` / `TRANS_CUBIC` (no jarring linear motion).
- Card lift animation: 0.12s — below the 500ms threshold for vestibular sensitivity.
- Consider adding "Reduce Motion" setting that disables arc rotations and lift, replaces with instant highlight only.
- Targeting arrow animation: static bezier line with arrowhead, no looping particle animation unless opted in.

### 6.5 Localization (中文/English)

- All string literals flow through `Loc.t()`, `Loc.card_name()`, `Loc.card_desc()`, `Loc.type_name()`.
- Language switch is instant, no scene reload: `_refresh_all_localized_text()` updates every tracked label dict.
- Chinese characters require a CJK-compatible font (e.g., Source Han Sans / Noto Sans SC) — ensure Godot project font resource includes CJK subset.
- Chinese text is ~30% shorter in character count but uses full-width characters — test all label sizes with Chinese strings to ensure no overflow. RichTextLabel with `fit_content=false` and a fixed size rect is the right approach (already implemented).
- Language toggle buttons: always show both options simultaneously (不 toggling between them) so user can switch back easily. Active language gets a gold underline or brighter background.

---

## 7. Data Contracts

### 7.1 Data the Deck Builder UI Reads

```
GameManager.card_database: Dictionary
  key: card_id (String)
  value: card data Dictionary (see §4.3)
  → Filters by card["character"] == character_id
  → Excludes card["type"] == 3 (Status cards not selectable)

GameManager.player_deck: Array
  → Written on confirm: player_deck = selected_card_ids.keys()

Loc node (autoload)
  → Loc.t(key: String) → String
  → Loc.card_name(card: Dictionary) → String
  → Loc.card_desc(card: Dictionary) → String
  → Loc.type_name(type_idx: int) → String
  → Loc.tf(key: String, args: Array) → String (formatted)
  → Loc.set_language(lang: String)
```

### 7.2 Data the Battle HUD Reads

```
BattleManager (scene root)
  .current_energy: int        → Energy orb numerator
  .max_energy: int            → Energy orb denominator
  .draw_pile: Array           → Draw pile count label
  .discard_pile: Array        → Discard pile count label
  .hand: Array                → Used by CardHand node
  .is_player_turn: bool       → End Turn button enabled/disabled
  .turn_number: int           → Turn label (if shown)

Entity node (player + each enemy)
  .current_hp: int            → HP bar fill + label "N/MAX"
  .max_hp: int                → HP bar max
  .current_block: int         → Block orb value (hides when 0)
  .strength: int              → Strength buff display
  .is_enemy: bool             → Determines which side of field
  .name: String               → NameLabel below sprite

EnemyAI per enemy
  .intent: String             → "attack_N", "block_N", "buff"
  → Displayed as icon+value above enemy sprite
  → intent display updated at start of each enemy turn

CardHand node
  .cards: Array[Area2D]       → Current hand contents
  .selected_card: Area2D      → Which card is in targeting mode
  .targeting_mode: bool       → Whether arrow should be visible
```

### 7.3 Signals the UI Emits

```
DeckBuilder:
  deck_confirmed(deck: Array)     → triggers scene transition to battle

BattleManager:
  turn_started(is_player: bool)   → HUD updates energy + draw
  turn_ended                      → enemy turn begins
  card_played_signal(card_data, target)  → effect resolution
  enemy_died(enemy_index: int)    → remove enemy from field
  player_died                     → show defeat overlay
  battle_won                      → show victory overlay

CardHand:
  card_played(card_data, target)  → battle_manager._on_card_played()
```

---

## 8. State Machines

### 8.1 Deck Builder Screen State

```
States: LOADING → IDLE → CONFIRMING → TRANSITIONING

LOADING:   grid not yet populated, show spinner or blank
IDLE:      user browses, selects/deselects cards freely
           sub-states:
             IDLE_EMPTY     (0 cards, confirm disabled)
             IDLE_PARTIAL   (1-9 cards, confirm enabled)
             IDLE_FULL      (10 cards, unselected cards dim)
CONFIRMING: confirm button pressed, brief pause before transition
TRANSITIONING: fade-out, scene change
```

### 8.2 Battle Screen State

```
States: SETUP → PLAYER_TURN → TARGETING → ENEMY_TURN → VICTORY → DEFEAT

SETUP:
  Entry: start_battle() called
  Exit:  start_player_turn() completes

PLAYER_TURN:
  Entry: draw 5 cards, reset energy, enable End Turn button
  Events:
    card_selected   → TARGETING (if card requires target)
    card_auto_play  → stay in PLAYER_TURN (self/all target, immediate)
    end_turn_pressed → ENEMY_TURN
  Exit: discard hand, apply end-of-turn effects

TARGETING:
  Entry: selected_card set, targeting_arrow visible
  Events:
    valid_target_clicked  → card plays, → PLAYER_TURN
    cancel               → → PLAYER_TURN (card stays in hand)
    right_click          → → PLAYER_TURN
  Exit: targeting_arrow hidden, selected_card = null

ENEMY_TURN:
  Entry: disable End Turn, execute each enemy AI sequentially
  Events:
    all_enemies_acted    → check win/lose
      all_enemies_dead   → VICTORY
      player_dead        → DEFEAT
      otherwise          → PLAYER_TURN
  Exit: update intents for next round

VICTORY:
  Entry: battle_won signal, show overlay, play particles
  Exit:  [Continue] button → scene change

DEFEAT:
  Entry: player_died signal, red vignette, show overlay
  Exit:  [Retry] → restart battle | [Menu] → main menu
```

### 8.3 Card State Machine (card.gd CardState enum)

```
IN_HAND → FOCUSED_IN_HAND (hover) → IN_HAND (unhover)
IN_HAND → DRAGGED (drag start, future)
IN_HAND → DROPPING_TO_BOARD (played, animates to target)
DROPPING_TO_BOARD → IN_PILE (discard complete)
```

---

## 9. Implementation Notes for Godot 4

### 9.1 Coordinate System

- **Deck Builder**: Control nodes, anchored layout, viewport 1920×1080. All positions are in Control space (y=0 at top).
- **Battle Screen**: Node2D scene, y-axis inverted (y=0 at top in Godot 2D). CardHand is positioned at y=1080 (bottom edge); cards hang upward into the viewport. All sprite positions in world-space 2D.
- **HUD Layer**: CanvasLayer (z_index applied) over the 2D battle scene so it always renders on top.

### 9.2 Z-Index Strategy (Battle)

| Layer                      | z_index | Notes                           |
|----------------------------|---------|---------------------------------|
| Background / dungeon art   | 0       | SubViewport or Sprite2D         |
| Enemy sprites              | 10      | Behind player                   |
| Player sprite              | 20      | In front of enemies             |
| Targeting arrow            | 200     | Above all entities              |
| Card hand cards            | 50 + i  | i=card position in hand         |
| Hovered/selected card      | 100     | Always on top in hand           |
| HUD Layer                  | CanvasLayer | Above all 2D content         |
| Overlay (victory/defeat)   | CanvasLayer+1 | Topmost                   |

### 9.3 Performance Considerations

- Grid 75 cards: 75 Control nodes with TextureRect children. Load art textures lazily using `ResourceLoader.load_threaded_request` to avoid frame spike on grid build. Show placeholder frame while art loads.
- Hand cards: max 10 cards, each is an Area2D with ~8 child nodes. Tween-based animation is GPU-efficient. Avoid `_process` polling; use signal-driven layout updates (`update_layout()` called only on state change).
- Targeting arrow: Line2D with 2 points is trivial. Add bezier curve by subdividing into 8 points per frame (still cheap). Do not use particles for the arrow itself.

### 9.4 Scroll Behavior (Deck Builder)

```gdscript
# Recommended ScrollContainer settings
scroll_horizontal_enabled = false
follow_focus = false  # don't auto-scroll on card focus (cards aren't focusable)

# Physics-based scrolling for mobile feel
# Godot 4 ScrollContainer has built-in physics scrolling
# Set scroll_deadzone = 10px for touch vs tap disambiguation
```

### 9.5 Responsive Scaling

At non-1920×1080 resolutions, use Godot's viewport stretch:
- `stretch_mode = "canvas_items"` — scales all content proportionally
- `stretch_aspect = "keep"` — maintains 16:9 with letterboxing
- HUD font sizes are absolute px values that scale with the viewport — no manual adjustment needed at common resolutions (1280×720, 2560×1440).

---

*Spec version: 1.0 · Viewport: 1920×1080 · Engine: Godot 4 · Game: Card Roguelike (STS-style)*
