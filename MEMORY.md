# Memory

## Task 1: Core Battle System

### Discoveries
- **TextureRect inside Node2D doesn't auto-size** — when the root scene is Node2D, Control children with anchor presets don't expand to fill the viewport. Use explicit `position` and `size` properties, or use Sprite2D for backgrounds.
- **Sprite2D for fullscreen backgrounds** — set `centered = false` and scale to fill viewport: `scale = Vector2(1920.0 / tex_size.x, 1080.0 / tex_size.y)`.
- **JPEG disguised as PNG** — some asset-generated "PNG" files are actually JPEG. Godot's importer may fail silently. Convert with `sips -s format png file.png --out fixed.png` on macOS.
- **Control anchors in Node2D** — `set_anchors_preset(PRESET_FULL_RECT)` doesn't work when parent is Node2D. Set `position = Vector2(0,0)` and `size = Vector2(1920, 1080)` explicitly.
- **Entity nodes created at runtime** — entities (player/enemies) are created programmatically in battle_manager.gd, not in the scene builder. This avoids needing a separate entity.tscn scene.
- **Recursive find_child_by_name** — when scene builders add intermediate containers (PanelContainer), the node paths change. Use recursive search by name instead of hardcoded paths.
- **Godot binary on macOS** — at `/Applications/Godot.app/Contents/MacOS/Godot`. No `timeout` command on macOS by default.
- **Card UI uses PanelContainer with StyleBoxFlat** — colored borders for card types (red=attack, green=skill, blue=power).
- **Enemy AI uses RefCounted** — instantiated via `load("res://scripts/enemy_ai.gd").new(type)` since it's not a Node.

### Architecture Decisions
- GameManager autoload holds card database (28 cards), character data, and run state.
- Entities are plain Node2D with entity.gd script, children created in code (Sprite2D, HP bars as ColorRect, Labels).
- Battle flow: start_battle() -> start_player_turn() -> draw_cards() -> [play cards] -> end_player_turn() -> start_enemy_turn() -> _process_enemy_actions() -> _end_enemy_turn() -> start_player_turn()
- Card targeting: two-step (click card to select, click target entity). Self/all_enemies targets auto-resolve.
- Status effects tracked in entity.status_effects Dictionary, decay in tick_status_effects() each turn.
