# Game Plan: Slay the Spire-style Card Roguelike

## Game Description

制作一款类杀戮尖塔的 2D 卡牌 Roguelike 游戏（Godot 4）。

核心需求：
1. **双角色系统**：铁甲战士（红色卡牌）+ 静默猎手（绿色卡牌）
2. **战斗系统**：回合制，3个怪物，能量+抽牌/弃牌机制
3. **28张卡牌**：攻击/技能/能力三种类型，能力卡使用后消耗
4. **状态效果**：易伤(+50%受伤)、虚弱(-25%攻击)、力量(+攻击)、敏捷(+格挡)，每回合-1层
5. **4种怪物**：史莱姆、邪教徒、颚虫、守护者，各有独立AI模式
6. **STS风格UI**：卡片悬停放大30%、两步出牌（选中→点击目标）、透明面板融合背景
7. **分辨率**：1920x1080
8. **素材**：用 Google Imagen 4 API 生成，STS简约风格+透明背景

## 1. Core Battle System
- **Status:** pending
- **Depends on:** (none)
- **Targets:** scenes/battle.tscn, scenes/main.tscn, scenes/card_ui.tscn, scenes/character_select.tscn, scripts/game_manager.gd, scripts/battle_manager.gd, scripts/card_hand.gd, scripts/card_ui.gd, scripts/entity.gd, scripts/enemy_ai.gd, scripts/character_select.gd
- **Goal:** Build the complete card battle game — all combat mechanics, UI, cards, enemies, and status effects in a single playable scene.
- **Requirements:**
  - Turn-based combat loop: player turn (draw 5 cards, 3 energy) → play cards → end turn → enemy turn → repeat
  - 28 cards split across two characters: Ironclad (red, 14 cards) and Silent (green, 14 cards). Types: Attack, Skill, Power (powers exhaust after use)
  - Card hand displayed as a fan at the bottom of screen. Hovering a card zooms it 30% larger. Two-step play: click card to select, then click target (enemy or self) to play
  - 3 enemy slots on the right side, player character on the left
  - 4 enemy types with distinct AI patterns: Slime (multi-attack), Cultist (buff-then-attack), Jaw Worm (aggressive/defensive cycle), Guardian (mode shift with thorns)
  - Enemy intent icons showing next action above each enemy
  - Status effects system: Vulnerable (+50% damage taken), Weak (-25% attack), Strength (+attack per stack), Dexterity (+block per stack). All decay by 1 stack per turn
  - HP bars for player and all enemies, energy counter, draw pile and discard pile counters
  - Block mechanic: block absorbs damage before HP, resets each turn
  - Death animation when HP reaches 0 (enemy or player)
  - Character selection screen before battle (choose Ironclad or Silent)
  - Dark dungeon background environment
  - Semi-transparent UI panels that blend with the background
- **Assets:**
  - `dungeon_bg` background (`assets/img/dungeon_bg.png`) — fullscreen 1920x1080
  - `ironclad` sprite (`assets/img/ironclad.png`) — scale to ~200px tall
  - `silent` sprite (`assets/img/silent.png`) — scale to ~200px tall
  - `slime` sprite (`assets/img/slime.png`) — scale to ~150px tall
  - `cultist` sprite (`assets/img/cultist.png`) — scale to ~180px tall
  - `jaw_worm` sprite (`assets/img/jaw_worm.png`) — scale to ~150px tall
  - `guardian` sprite (`assets/img/guardian.png`) — scale to ~200px tall
  - Card art icons in `assets/img/card_art_ironclad/` (16 icons) and `assets/img/card_art_silent/` (16 icons) — 80x80px each
  - UI icons in `assets/img/ui_icons/` — intent, status effect, energy icons
- **Verify:** Screenshot shows a battle in progress: player character on left with HP bar, 3 enemies on right with HP bars and intent icons, a hand of 5 cards fanned at the bottom, energy counter showing "3/3", draw and discard pile visible. Hovering a card makes it larger. Status effect icons visible on affected entities.

## 2. Presentation Video
- **Depends on:** 1
- **Goal:** Create a ~30-second cinematic video showcasing the completed game.
- **Requirements:**
  - Write test/presentation.gd — a SceneTree script (extends SceneTree)
  - Showcase representative gameplay via simulated input or scripted animations
  - Show character selection, then a full battle turn: drawing cards, hovering, playing attacks and skills, enemy actions, status effects applied, an enemy dying
  - ~900 frames at 30 FPS (30 seconds)
  - Use Video Capture from godot-capture (AVI via --write-movie, convert to MP4 with ffmpeg)
  - Output: screenshots/presentation/gameplay.mp4
  - 2D: camera pans and smooth scrolling, zoom transitions between overview and close-up, trigger representative gameplay sequences, tight viewport framing
- **Verify:** A smooth MP4 video showing polished gameplay with no visual glitches.
