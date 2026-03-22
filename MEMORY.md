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

## Task 2: Presentation Video

### Discoveries
- **AVI capture is fast, PNG capture is very slow** — `--write-movie output.avi` captures 900 frames in ~17s. PNG frame capture is ~10x slower and may timeout.
- **No ffmpeg on macOS** — used `opencv-python-headless` (cv2.VideoWriter with `mp4v` codec) to convert AVI to MP4. Works well: 1280x720, ~25MB for 30s.
- **`avconvert` can't read Godot's MJPEG AVI** — macOS built-in `avconvert` refuses to open Godot's AVI output. Use OpenCV instead.
- **Camera2D in SceneTree scripts** — `make_current()` errors if called before the camera is in the scene tree. Camera2D added to root doesn't affect CanvasLayer children (HUD stays fixed, which is actually desired). Camera zoom/pan effects are subtle in 2D.
- **Tween "Target object freed" warnings** — when cards are removed from CardHand after playing, any active scale tweens on them warn about freed targets. Harmless but noisy.
- **Simulating card play in SceneTree scripts** — call `card_hand._on_card_clicked(card)` to select, then `card_hand.play_selected_on(target)` to play. Must check `battle_active`, `is_player_turn`, and energy before playing.
- **No `timeout` on macOS** — use background process + sleep + kill pattern instead.
