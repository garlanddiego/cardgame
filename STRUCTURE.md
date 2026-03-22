# Card Roguelike

## Dimension: 2D

## Input Actions

| Action | Keys |
|--------|------|
| click | Mouse Left |
| right_click | Mouse Right |
| end_turn | E |

## Scenes

### Main
- **File:** res://scenes/main.tscn
- **Root type:** Node2D
- **Children:** CharacterSelect (instantiated scene)
- **Description:** Entry point, manages scene switching between character select and battle

### CharacterSelect
- **File:** res://scenes/character_select.tscn
- **Root type:** Control
- **Description:** Character selection screen with Ironclad and Silent options

### Battle
- **File:** res://scenes/battle.tscn
- **Root type:** Node2D
- **Children:** Background (TextureRect), PlayerArea (Node2D), EnemyArea (Node2D), CardHand (Control), HUD (CanvasLayer > Control), EndTurnButton (Button)
- **Description:** Main battle scene with all combat UI

### CardUI
- **File:** res://scenes/card_ui.tscn
- **Root type:** Control
- **Description:** Individual card display with frame, art, name, cost, description

## Scripts

### GameManager (Autoload)
- **File:** res://scripts/game_manager.gd
- **Extends:** Node
- **Signals emitted:** character_selected(character_id), battle_started, battle_ended(won)
- **Description:** Global state — card database, character definitions, current run state

### BattleManager
- **File:** res://scripts/battle_manager.gd
- **Extends:** Node2D
- **Attaches to:** Battle:Battle
- **Signals emitted:** turn_started(is_player), turn_ended, card_played(card_data, target), enemy_died(enemy_index), player_died, battle_won
- **Signals received:** CardHand.card_played -> _on_card_played, EndTurnButton.pressed -> _on_end_turn

### CardHand
- **File:** res://scripts/card_hand.gd
- **Extends:** Control
- **Attaches to:** Battle:CardHand
- **Signals emitted:** card_played(card_data, target)
- **Description:** Fan layout of cards, hover zoom, two-step targeting

### CardUIScript
- **File:** res://scripts/card_ui.gd
- **Extends:** Control
- **Attaches to:** CardUI:CardUI
- **Signals emitted:** card_clicked(card_data), card_hovered(card_data), card_unhovered
- **Description:** Single card rendering and interaction

### Entity
- **File:** res://scripts/entity.gd
- **Extends:** Node2D
- **Signals emitted:** hp_changed(current, max_val), block_changed(amount), status_changed(status_type, stacks), died
- **Description:** Base class for player and enemies — HP, block, status effects

### EnemyAI
- **File:** res://scripts/enemy_ai.gd
- **Extends:** RefCounted
- **Description:** Enemy AI patterns — determines next action based on enemy type and state

### CharacterSelectScript
- **File:** res://scripts/character_select.gd
- **Extends:** Control
- **Attaches to:** CharacterSelect:CharacterSelect
- **Signals emitted:** character_chosen(character_id)

## Signal Map

- CardUI.card_clicked -> CardHand._on_card_clicked
- CardUI.card_hovered -> CardHand._on_card_hovered
- CardUI.card_unhovered -> CardHand._on_card_unhovered
- CardHand.card_played -> BattleManager._on_card_played
- EndTurnButton.pressed -> BattleManager._on_end_turn
- Entity.died -> BattleManager._on_entity_died
- Entity.hp_changed -> HUD._update_hp_bar
- CharacterSelect.character_chosen -> Main._on_character_chosen
- GameManager.battle_started -> BattleManager._on_battle_started

## Asset Hints

- Player sprite: Ironclad (armored warrior, red theme, ~200px tall, transparent background)
- Player sprite: Silent (hooded hunter, green theme, ~200px tall, transparent background)
- Enemy sprite: Slime (green blob creature, ~150px tall, transparent background)
- Enemy sprite: Cultist (robed figure with staff, ~180px tall, transparent background)
- Enemy sprite: Jaw Worm (insect/worm creature, ~150px tall, transparent background)
- Enemy sprite: Guardian (stone golem, ~200px tall, transparent background)
- Card frame: Attack (red border, ~120x180px)
- Card frame: Skill (green border, ~120x180px)
- Card frame: Power (grey/blue border, ~120x180px)
- 28 card art icons (~80x80px each, transparent background)
- Dungeon background (dark stone dungeon, 1920x1080)
- UI: Energy orb icon (~40x40px)
- UI: Intent icons — attack sword, defend shield, buff up-arrow, debuff down-arrow (~30x30px each)
- UI: Status effect icons — vulnerable, weak, strength, dexterity (~24x24px each)
