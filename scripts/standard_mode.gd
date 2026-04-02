extends Control
## res://scripts/standard_mode.gd — Standard Mode: map, battles, rewards, rest, shop

const MonstersDB = preload("res://scripts/monsters.gd")
const CardScript = preload("res://scripts/card.gd")

enum Phase { DRAFT, MAP, BATTLE, REWARD, REST, SHOP, VICTORY, DEFEAT }
var phase: Phase = Phase.DRAFT

var run: Node = null  # RunManager
var gm: Node = null   # GameManager

# UI containers
var _map_layer: Control = null
var _overlay: Control = null
var _battle_instance: Node2D = null
var _current_monsters: Array = []  # [{id, hp}]
var _pending_node: Dictionary = {}

# Draft state
var _draft_round: int = 0
var _draft_total_rounds: int = 4
var _draft_hero_order: Array = ["ironclad", "silent", "ironclad", "silent"]
var _draft_picked_cards: Array = []  # card data dicts picked so far
var _draft_status_bar: HBoxContainer = null  # top status bar
var _draft_card_count_label: Button = null

func _ready() -> void:
  # Let input pass through to battle scene's Area2D cards
  mouse_filter = Control.MOUSE_FILTER_IGNORE
  run = get_node_or_null("/root/RunManager")
  gm = get_node_or_null("/root/GameManager")
  if run == null or gm == null:
    push_error("RunManager or GameManager missing")
    return
  _build_ui()
  _show_draft()

func _build_ui() -> void:
  # Dark background
  var bg := ColorRect.new()
  bg.color = Color(0.05, 0.04, 0.03)
  bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
  add_child(bg)
  # Map layer
  _map_layer = Control.new()
  _map_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _map_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
  add_child(_map_layer)
  # Overlay layer (for rewards, rest, shop popups) — on a CanvasLayer to render above battle
  var overlay_canvas := CanvasLayer.new()
  overlay_canvas.name = "OverlayCanvas"
  overlay_canvas.layer = 10  # Above battle's HUDLayer (layer 1)
  add_child(overlay_canvas)
  _overlay = Control.new()
  _overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
  _overlay.visible = false
  overlay_canvas.add_child(_overlay)

# ═══════════════════════════════════════════════════════════════════════════
# INITIAL DRAFT (3 rounds of card picking before map)
# ═══════════════════════════════════════════════════════════════════════════

func _show_draft() -> void:
  _draft_round += 1
  phase = Phase.DRAFT
  _map_layer.visible = false
  _overlay.visible = true
  _clear_children(_overlay)

  var bg := ColorRect.new()
  bg.color = Color(0, 0, 0, 0.9)
  bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
  _overlay.add_child(bg)

  var hero_id: String = _draft_hero_order[_draft_round - 1]
  var hero_color: Color = Color(0.85, 0.2, 0.2) if hero_id == "ironclad" else Color(0.2, 0.7, 0.3)

  # "My cards" button — top-right corner (card fly target)
  var my_cards_btn := Button.new()
  my_cards_btn.text = "我的卡牌 (%d)" % _draft_picked_cards.size()
  my_cards_btn.add_theme_font_size_override("font_size", 22)
  my_cards_btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
  var mcb_style := StyleBoxFlat.new()
  mcb_style.bg_color = Color(0.15, 0.12, 0.08, 0.8)
  mcb_style.border_color = Color(0.5, 0.4, 0.25, 0.6)
  mcb_style.set_border_width_all(1)
  mcb_style.set_corner_radius_all(6)
  mcb_style.content_margin_left = 12
  mcb_style.content_margin_right = 12
  my_cards_btn.add_theme_stylebox_override("normal", mcb_style)
  var mcb_hover := mcb_style.duplicate() as StyleBoxFlat
  mcb_hover.bg_color = Color(0.25, 0.2, 0.12, 0.9)
  my_cards_btn.add_theme_stylebox_override("hover", mcb_hover)
  my_cards_btn.pressed.connect(_show_draft_deck_viewer)
  my_cards_btn.position = Vector2(1700, 15)
  _overlay.add_child(my_cards_btn)
  _draft_card_count_label = my_cards_btn

  # === Round dots ===
  _draft_status_bar = HBoxContainer.new()
  _draft_status_bar.add_theme_constant_override("separation", 12)
  _draft_status_bar.position = Vector2(0, 70)
  _draft_status_bar.size = Vector2(1920, 30)
  _draft_status_bar.alignment = BoxContainer.ALIGNMENT_CENTER
  _overlay.add_child(_draft_status_bar)
  for i in range(_draft_total_rounds):
    var dot := Label.new()
    if i < _draft_round - 1:
      dot.text = "●"
      dot.add_theme_color_override("font_color", Color(0.4, 0.8, 0.3))
    elif i == _draft_round - 1:
      dot.text = "◉"
      dot.add_theme_color_override("font_color", hero_color)
    else:
      dot.text = "○"
      dot.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
    dot.add_theme_font_size_override("font_size", 22)
    _draft_status_bar.add_child(dot)

  # === Title ===
  var title := Label.new()
  title.text = "选择一张卡牌"
  title.add_theme_font_size_override("font_size", 36)
  title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
  title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  title.position = Vector2(0, 120)
  title.size = Vector2(1920, 50)
  _overlay.add_child(title)

  # === 3 card options (battle-style visuals) ===
  var cards := _random_cards_for_hero(hero_id, 3)
  var card_w: float = 280.0
  var card_h: float = 400.0
  var gap: float = 60.0
  var total_w: float = cards.size() * card_w + (cards.size() - 1) * gap
  var start_x: float = (1920.0 - total_w) / 2.0
  var card_y: float = 200.0
  var loc = get_node_or_null("/root/Loc")

  for i in range(cards.size()):
    var card_data: Dictionary = cards[i]
    var container := Control.new()
    container.position = Vector2(start_x + i * (card_w + gap), card_y)
    container.size = Vector2(card_w, card_h)
    container.mouse_filter = Control.MOUSE_FILTER_STOP
    container.gui_input.connect(_on_draft_card_clicked.bind(card_data, container))
    _overlay.add_child(container)
    # Render battle-style card visual
    var visual := CardScript.create_card_visual(card_data, Vector2(card_w, card_h), loc)
    container.add_child(visual)
    # Hover highlight
    container.mouse_entered.connect(func():
      container.modulate = Color(1.2, 1.2, 1.2)
    )
    container.mouse_exited.connect(func():
      container.modulate = Color(1, 1, 1)
    )

  # === Skip button ===
  var skip_btn := Button.new()
  skip_btn.text = "跳过本轮"
  skip_btn.custom_minimum_size = Vector2(180, 50)
  skip_btn.add_theme_font_size_override("font_size", 22)
  skip_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
  var skip_style := StyleBoxFlat.new()
  skip_style.bg_color = Color(0.15, 0.15, 0.15, 0.7)
  skip_style.set_border_width_all(1)
  skip_style.border_color = Color(0.3, 0.3, 0.3)
  skip_style.set_corner_radius_all(8)
  skip_btn.add_theme_stylebox_override("normal", skip_style)
  var skip_hover := skip_style.duplicate() as StyleBoxFlat
  skip_hover.bg_color = Color(0.25, 0.25, 0.25, 0.7)
  skip_btn.add_theme_stylebox_override("hover", skip_hover)
  skip_btn.position = Vector2((1920.0 - 180.0) / 2.0, card_y + card_h + 40.0)
  skip_btn.pressed.connect(_advance_draft)
  _overlay.add_child(skip_btn)

var _draft_picking: bool = false

func _on_draft_card_clicked(event: InputEvent, card_data: Dictionary, container: Control) -> void:
  if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
    return
  if _draft_picking:
    return
  _draft_picking = true

  var card_id: String = card_data.get("id", "")
  if card_id != "":
    run.add_card(card_id)
    _draft_picked_cards.append(card_data)

  # Update card count button
  if _draft_card_count_label:
    _draft_card_count_label.text = "我的卡牌 (%d)" % _draft_picked_cards.size()

  # Fly animation: card flies to "My Cards" button (top-right corner)
  var target_pos := Vector2(1920.0 - 120.0, 10.0)
  if _draft_card_count_label:
    target_pos = _draft_card_count_label.global_position
  var tween := create_tween()
  tween.set_ease(Tween.EASE_IN_OUT)
  tween.set_trans(Tween.TRANS_CUBIC)
  tween.tween_property(container, "position", target_pos, 0.4)
  tween.parallel().tween_property(container, "scale", Vector2(0.15, 0.15), 0.4)
  tween.parallel().tween_property(container, "modulate:a", 0.0, 0.35).set_delay(0.2)
  tween.tween_callback(_advance_draft)

func _show_draft_deck_viewer() -> void:
  # Show overlay with all picked cards so far
  var viewer := Control.new()
  viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _overlay.add_child(viewer)

  var vbg := ColorRect.new()
  vbg.color = Color(0, 0, 0, 0.85)
  vbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  vbg.mouse_filter = Control.MOUSE_FILTER_STOP
  viewer.add_child(vbg)

  var vtitle := Label.new()
  vtitle.text = "已选卡牌 (%d)" % _draft_picked_cards.size()
  vtitle.add_theme_font_size_override("font_size", 36)
  vtitle.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
  vtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  vtitle.position = Vector2(0, 30)
  vtitle.size = Vector2(1920, 50)
  viewer.add_child(vtitle)

  if _draft_picked_cards.is_empty():
    var empty_label := Label.new()
    empty_label.text = "还没有选择卡牌"
    empty_label.add_theme_font_size_override("font_size", 24)
    empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
    empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    empty_label.position = Vector2(0, 400)
    empty_label.size = Vector2(1920, 50)
    viewer.add_child(empty_label)
  else:
    var loc = get_node_or_null("/root/Loc")
    var card_w: float = 200.0
    var card_h: float = 280.0
    var gap: float = 20.0
    var cols: int = mini(_draft_picked_cards.size(), 6)
    var total_w: float = cols * card_w + (cols - 1) * gap
    var sx: float = (1920.0 - total_w) / 2.0
    for i in range(_draft_picked_cards.size()):
      var cd: Dictionary = _draft_picked_cards[i]
      var col: int = i % 6
      var row: int = i / 6
      var c := Control.new()
      c.position = Vector2(sx + col * (card_w + gap), 100.0 + row * (card_h + 20.0))
      c.size = Vector2(card_w, card_h)
      c.mouse_filter = Control.MOUSE_FILTER_IGNORE
      viewer.add_child(c)
      var vis := CardScript.create_card_visual(cd, Vector2(card_w, card_h), loc)
      c.add_child(vis)

  # Close button
  var close_btn := Button.new()
  close_btn.text = "返回"
  close_btn.custom_minimum_size = Vector2(160, 50)
  close_btn.add_theme_font_size_override("font_size", 24)
  var close_style := StyleBoxFlat.new()
  close_style.bg_color = Color(0.3, 0.3, 0.3, 0.7)
  close_style.set_corner_radius_all(8)
  close_btn.add_theme_stylebox_override("normal", close_style)
  close_btn.position = Vector2((1920.0 - 160.0) / 2.0, 1080.0 - 80.0)
  close_btn.pressed.connect(func(): viewer.queue_free())
  viewer.add_child(close_btn)

func _advance_draft() -> void:
  _draft_picking = false
  if _draft_round >= _draft_total_rounds:
    _show_map()
  else:
    _show_draft()

# ═══════════════════════════════════════════════════════════════════════════
# MAP
# ═══════════════════════════════════════════════════════════════════════════

var _map_scroll: ScrollContainer = null
var _map_canvas: Control = null
var _node_buttons: Dictionary = {}  # key -> Button
var _hud_gold_label: Label = null
var _hud_hp1_label: Label = null
var _hud_hp2_label: Label = null
var _hud_floor_label: Label = null
var _hud_deck_btn: Button = null

func _show_map() -> void:
  phase = Phase.MAP
  _map_layer.visible = true
  _overlay.visible = false
  if _battle_instance:
    _battle_instance.queue_free()
    _battle_instance = null
  _clear_children(_map_layer)
  _draw_map()

func _update_hud_labels() -> void:
  if _hud_gold_label:
    _hud_gold_label.text = "💰 %d" % run.gold
  if _hud_hp1_label:
    _hud_hp1_label.text = "♥ %s %d/%d" % [_hero_name(run.hero1_id), run.hero1_hp, run.hero1_max_hp]
  if _hud_hp2_label:
    _hud_hp2_label.text = "♥ %s %d/%d" % [_hero_name(run.hero2_id), run.hero2_hp, run.hero2_max_hp]

func _draw_map() -> void:
  # HUD bar at top
  var hud := PanelContainer.new()
  var hud_style := StyleBoxFlat.new()
  hud_style.bg_color = Color(0.1, 0.08, 0.06, 0.95)
  hud_style.border_color = Color(0.4, 0.3, 0.2)
  hud_style.border_width_bottom = 2
  hud.add_theme_stylebox_override("panel", hud_style)
  hud.offset_right = 1920
  hud.offset_bottom = 60
  _map_layer.add_child(hud)

  var hbox := HBoxContainer.new()
  hbox.add_theme_constant_override("separation", 40)
  hbox.alignment = BoxContainer.ALIGNMENT_CENTER
  hud.add_child(hbox)

  _hud_floor_label = _hud_label("第 %d 层" % run.floor_num if run.floor_num > 0 else "选择起点")
  hbox.add_child(_hud_floor_label)

  _hud_gold_label = _hud_label("💰 %d" % run.gold)
  hbox.add_child(_hud_gold_label)

  _hud_hp1_label = _hud_label("♥ %s %d/%d" % [_hero_name(run.hero1_id), run.hero1_hp, run.hero1_max_hp])
  hbox.add_child(_hud_hp1_label)

  _hud_hp2_label = _hud_label("♥ %s %d/%d" % [_hero_name(run.hero2_id), run.hero2_hp, run.hero2_max_hp])
  hbox.add_child(_hud_hp2_label)

  _hud_deck_btn = Button.new()
  _hud_deck_btn.text = "卡组 (%d)" % run.deck.size()
  _hud_deck_btn.add_theme_font_size_override("font_size", 20)
  _hud_deck_btn.pressed.connect(_show_deck_viewer)
  hbox.add_child(_hud_deck_btn)

  # Back button
  var back_btn := Button.new()
  back_btn.text = "放弃"
  back_btn.add_theme_font_size_override("font_size", 20)
  back_btn.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
  back_btn.pressed.connect(func():
    run.end_run(false)
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
  )
  hbox.add_child(back_btn)

  # Scrollable map area
  _map_scroll = ScrollContainer.new()
  _map_scroll.offset_top = 65
  _map_scroll.offset_right = 1920
  _map_scroll.offset_bottom = 1080
  _map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
  _map_layer.add_child(_map_scroll)

  # Map canvas — draw nodes and paths
  var node_size := 80
  var floor_height := 120
  var map_width := 1920
  var total_height: int = 11 * floor_height + 100
  _map_canvas = Control.new()
  _map_canvas.custom_minimum_size = Vector2(map_width, total_height)
  _map_scroll.add_child(_map_canvas)

  # Draw path lines first (behind nodes)
  var line_canvas := Control.new()
  line_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  line_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
  _map_canvas.add_child(line_canvas)

  # Calculate node positions
  var node_positions: Dictionary = {}  # key -> Vector2
  for key in run.map_nodes:
    var nd: Dictionary = run.map_nodes[key]
    var fl: int = nd["floor"]
    var col: int = nd["col"]
    var total_cols: int = nd["total_cols"]
    var x_spacing: float = map_width / (total_cols + 1)
    var x: float = x_spacing * (col + 1)
    var y: float = total_height - (fl * floor_height + 50)
    node_positions[key] = Vector2(x, y)

  # Draw paths
  for path in run.map_paths:
    var from_pos: Vector2 = node_positions.get(path[0], Vector2.ZERO)
    var to_pos: Vector2 = node_positions.get(path[1], Vector2.ZERO)
    var line := _create_path_line(from_pos, to_pos, path[0], path[1])
    line_canvas.add_child(line)

  # Draw nodes
  _node_buttons.clear()
  for key in run.map_nodes:
    var nd: Dictionary = run.map_nodes[key]
    var pos: Vector2 = node_positions[key]
    var btn := _create_map_node(key, nd, pos, node_size)
    _map_canvas.add_child(btn)
    _node_buttons[key] = btn

  # Scroll to current floor
  await get_tree().process_frame
  var scroll_y: int = maxi(0, total_height - int((run.floor_num + 2) * floor_height) - 500)
  _map_scroll.scroll_vertical = scroll_y

func _create_path_line(from: Vector2, to: Vector2, from_key: String, to_key: String) -> Line2D:
  var line := Line2D.new()
  line.add_point(from)
  line.add_point(to)
  line.width = 3.0
  # Color based on visited state
  var visited_from: bool = from_key in run.visited
  var visited_to: bool = to_key in run.visited
  if visited_from and visited_to:
    line.default_color = Color(0.6, 0.5, 0.3, 0.8)
  elif visited_from and to_key in run.available_nodes:
    line.default_color = Color(0.9, 0.8, 0.4, 0.9)
  else:
    line.default_color = Color(0.3, 0.25, 0.2, 0.5)
  return line

func _create_map_node(key: String, nd: Dictionary, pos: Vector2, size: int) -> Button:
  var btn := Button.new()
  btn.custom_minimum_size = Vector2(size, size)
  btn.offset_left = pos.x - size / 2
  btn.offset_top = pos.y - size / 2
  btn.offset_right = pos.x + size / 2
  btn.offset_bottom = pos.y + size / 2

  # Icon/text based on type
  var icon_text := ""
  var node_color := Color.WHITE
  match nd["type"]:
    "M":
      icon_text = "⚔"
      node_color = Color(0.9, 0.3, 0.2)
    "R":
      icon_text = "🔥"
      node_color = Color(0.3, 0.8, 0.3)
    "S":
      icon_text = "💰"
      node_color = Color(0.9, 0.8, 0.2)
    "B":
      icon_text = "💀"
      node_color = Color(0.8, 0.1, 0.1)

  btn.text = icon_text
  btn.add_theme_font_size_override("font_size", 32)

  # Style
  var style := StyleBoxFlat.new()
  style.corner_radius_top_left = size / 2
  style.corner_radius_top_right = size / 2
  style.corner_radius_bottom_left = size / 2
  style.corner_radius_bottom_right = size / 2

  var is_visited: bool = key in run.visited
  var is_available: bool = key in run.available_nodes
  var is_current: bool = key == run.current_node

  if is_current:
    style.bg_color = Color(node_color.r, node_color.g, node_color.b, 0.7)
    style.border_color = Color.WHITE
    style.border_width_left = 3
    style.border_width_right = 3
    style.border_width_top = 3
    style.border_width_bottom = 3
  elif is_available:
    style.bg_color = Color(node_color.r, node_color.g, node_color.b, 0.5)
    style.border_color = Color(0.9, 0.8, 0.4)
    style.border_width_left = 2
    style.border_width_right = 2
    style.border_width_top = 2
    style.border_width_bottom = 2
  elif is_visited:
    style.bg_color = Color(0.2, 0.2, 0.2, 0.6)
    style.border_color = Color(0.4, 0.4, 0.4)
    style.border_width_left = 1
    style.border_width_right = 1
    style.border_width_top = 1
    style.border_width_bottom = 1
  else:
    style.bg_color = Color(0.15, 0.12, 0.1, 0.7)
    style.border_color = Color(0.3, 0.25, 0.2)
    style.border_width_left = 1
    style.border_width_right = 1
    style.border_width_top = 1
    style.border_width_bottom = 1

  btn.add_theme_stylebox_override("normal", style)
  var hover_style := style.duplicate() as StyleBoxFlat
  if is_available:
    hover_style.bg_color = Color(node_color.r, node_color.g, node_color.b, 0.7)
  btn.add_theme_stylebox_override("hover", hover_style)
  btn.add_theme_stylebox_override("pressed", hover_style)

  btn.disabled = not is_available
  if is_available:
    btn.pressed.connect(_on_node_pressed.bind(key))

  # Floor label below node
  var fl_label := Label.new()
  fl_label.text = "F%d" % nd["floor"]
  fl_label.add_theme_font_size_override("font_size", 14)
  fl_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.7))
  fl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  fl_label.offset_top = size + 2
  fl_label.offset_right = size
  btn.add_child(fl_label)

  return btn

func _on_node_pressed(key: String) -> void:
  var nd: Dictionary = run.visit_node(key)
  _pending_node = nd
  match nd["type"]:
    "M", "B":
      _start_battle(nd)
    "R":
      _show_rest()
    "S":
      _show_shop()

# ═══════════════════════════════════════════════════════════════════════════
# BATTLE
# ═══════════════════════════════════════════════════════════════════════════

func _start_battle(nd: Dictionary) -> void:
  phase = Phase.BATTLE
  _map_layer.visible = false

  # Load battle scene
  var battle_scene := load("res://scenes/battle.tscn")
  _battle_instance = battle_scene.instantiate()
  add_child(_battle_instance)

  # Configure battle
  var bm: Node2D = _battle_instance
  bm.dual_hero_mode = true
  bm.second_character_id = run.hero2_id
  bm.config_player_hp = run.hero1_hp
  bm.max_energy = 3
  bm.cards_per_draw = 5

  # Set enemy config based on monster
  var monster_id: String = nd["monster_id"]
  var monsters_db: Dictionary = MonstersDB.get_all()
  var enemy_count: int = nd["enemy_count"]
  bm.enemy_count = enemy_count

  # Store monster info for enemy setup
  _current_monsters.clear()
  var available := MonstersDB.get_monsters_for_floor(nd["floor"])
  for i in range(enemy_count):
    var mid: String = monster_id if i == 0 else available[randi() % available.size()]
    var hp: int = MonstersDB.get_hp(mid, nd["floor"])
    _current_monsters.append({"id": mid, "hp": hp})

  # Configure standard mode monsters on battle manager
  bm.standard_mode_monsters = _current_monsters.duplicate()
  bm.enemy_count = _current_monsters.size()

  # Set deck from run
  if gm:
    gm.player_deck = run.deck.duplicate()
    gm.select_character(run.hero1_id)

  # Configure second hero HP
  # (hero1 HP is set via config_player_hp above)
  # hero2 HP needs to be passed — battle_manager reads it from config
  bm.set_meta("standard_hero2_hp", run.hero2_hp)

  # Connect signals
  bm.battle_won.connect(_on_battle_won)
  bm.player_died.connect(_on_battle_lost)

  # Start battle
  bm.start_battle(run.hero1_id)

func _on_battle_won() -> void:
  # Save HP back to run state
  if _battle_instance:
    var bm: Node2D = _battle_instance
    if bm.player:
      run.hero1_hp = bm.player.current_hp
    if bm.second_player:
      run.hero2_hp = bm.second_player.current_hp

  # Check if this was the boss
  if _pending_node.get("type", "") == "B":
    _show_victory()
    return

  _show_rewards()

func _on_battle_lost() -> void:
  if _battle_instance:
    _battle_instance.queue_free()
    _battle_instance = null
  _show_defeat()

# ═══════════════════════════════════════════════════════════════════════════
# REWARDS
# ═══════════════════════════════════════════════════════════════════════════

# Reward state
var _reward_gold_amount: int = 0
var _reward_dialog: PanelContainer = null
var _reward_btn_gold: Button = null
var _reward_btn_h1: Button = null
var _reward_btn_h2: Button = null
var _reward_card_overlay: Control = null
var _reward_skip_btn: Button = null
var _reward_gold_collected: bool = false
var _reward_h1_collected: bool = false
var _reward_h2_collected: bool = false

func _show_rewards() -> void:
  phase = Phase.REWARD
  _reward_gold_collected = false
  _reward_h1_collected = false
  _reward_h2_collected = false
  # Hide and destroy battle scene completely so reward overlay is clean
  if _battle_instance:
    _battle_instance.visible = false
    # Also hide the HUD CanvasLayer which renders above everything
    var hud_layer = _battle_instance.get_node_or_null("HUDLayer")
    if hud_layer:
      hud_layer.visible = false
    _battle_instance.queue_free()
    _battle_instance = null
  _map_layer.visible = false
  _overlay.visible = true
  _clear_children(_overlay)

  # Full-screen dark background (battle fully covered)
  var bg := ColorRect.new()
  bg.color = Color(0.05, 0.04, 0.03, 1.0)
  bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  bg.mouse_filter = Control.MOUSE_FILTER_STOP
  _overlay.add_child(bg)

  # Calculate gold reward (don't add yet — wait for click)
  _reward_gold_amount = 15 + randi() % 15 + run.floor_num * 3

  # === Title banner (parchment-style) ===
  var banner := PanelContainer.new()
  var banner_style := StyleBoxFlat.new()
  banner_style.bg_color = Color(0.65, 0.58, 0.42, 0.95)
  banner_style.border_color = Color(0.45, 0.38, 0.25)
  banner_style.set_border_width_all(2)
  banner_style.set_corner_radius_all(6)
  banner_style.content_margin_left = 40
  banner_style.content_margin_right = 40
  banner_style.content_margin_top = 8
  banner_style.content_margin_bottom = 8
  banner.add_theme_stylebox_override("panel", banner_style)
  banner.position = Vector2(660, 100)
  banner.size = Vector2(600, 60)
  _overlay.add_child(banner)

  var title := Label.new()
  title.text = "好好搜刮！"
  title.add_theme_font_size_override("font_size", 36)
  title.add_theme_color_override("font_color", Color(0.2, 0.15, 0.05))
  title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  banner.add_child(title)

  # === Reward panel (dark, centered) ===
  _reward_dialog = PanelContainer.new()
  var dialog_style := StyleBoxFlat.new()
  dialog_style.bg_color = Color(0.12, 0.12, 0.15, 0.92)
  dialog_style.border_color = Color(0.3, 0.3, 0.35)
  dialog_style.set_border_width_all(2)
  dialog_style.set_corner_radius_all(10)
  dialog_style.content_margin_left = 20
  dialog_style.content_margin_right = 20
  dialog_style.content_margin_top = 20
  dialog_style.content_margin_bottom = 20
  _reward_dialog.add_theme_stylebox_override("panel", dialog_style)
  _reward_dialog.position = Vector2(510, 180)
  _reward_dialog.size = Vector2(900, 450)
  _overlay.add_child(_reward_dialog)

  var vbox := VBoxContainer.new()
  vbox.add_theme_constant_override("separation", 12)
  _reward_dialog.add_child(vbox)

  # Gold reward row
  _reward_btn_gold = _reward_row("💰", "%d 金币" % _reward_gold_amount, Color(0.9, 0.8, 0.3))
  _reward_btn_gold.pressed.connect(_on_reward_gold_clicked)
  vbox.add_child(_reward_btn_gold)

  # Hero 1 card reward row
  _reward_btn_h1 = _reward_row("🃏", "将一张 %s 卡牌加入牌组" % _hero_name(run.hero1_id), _hero_color(run.hero1_id))
  _reward_btn_h1.pressed.connect(_on_reward_h1_clicked)
  vbox.add_child(_reward_btn_h1)

  # Hero 2 card reward row
  _reward_btn_h2 = _reward_row("🃏", "将一张 %s 卡牌加入牌组" % _hero_name(run.hero2_id), _hero_color(run.hero2_id))
  _reward_btn_h2.pressed.connect(_on_reward_h2_clicked)
  vbox.add_child(_reward_btn_h2)

  # === Skip/Continue button (bottom-right, STS style) ===
  _reward_skip_btn = Button.new()
  _reward_skip_btn.text = "跳过奖励 →"
  _reward_skip_btn.custom_minimum_size = Vector2(200, 50)
  _reward_skip_btn.add_theme_font_size_override("font_size", 22)
  _reward_skip_btn.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
  var skip_style := StyleBoxFlat.new()
  skip_style.bg_color = Color(0.3, 0.25, 0.1, 0.8)
  skip_style.border_color = Color(0.6, 0.5, 0.2)
  skip_style.set_border_width_all(1)
  skip_style.set_corner_radius_all(8)
  _reward_skip_btn.add_theme_stylebox_override("normal", skip_style)
  var skip_hover := skip_style.duplicate() as StyleBoxFlat
  skip_hover.bg_color = Color(0.4, 0.35, 0.15, 0.9)
  _reward_skip_btn.add_theme_stylebox_override("hover", skip_hover)
  _reward_skip_btn.position = Vector2(1620, 680)
  _reward_skip_btn.pressed.connect(_show_map)
  _overlay.add_child(_reward_skip_btn)

  # Card overlay (for showing 3 cards when a hero button is clicked)
  _reward_card_overlay = Control.new()
  _reward_card_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _reward_card_overlay.visible = false
  _reward_card_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
  _overlay.add_child(_reward_card_overlay)

func _reward_row(icon: String, text: String, color: Color) -> Button:
  """Create a reward row button (STS style — icon + text on a dark row)."""
  var btn := Button.new()
  btn.text = "  %s   %s" % [icon, text]
  btn.custom_minimum_size = Vector2(860, 52)
  btn.add_theme_font_size_override("font_size", 22)
  btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
  btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
  var style := StyleBoxFlat.new()
  style.bg_color = Color(0.18, 0.18, 0.22, 0.9)
  style.border_color = Color(0.3, 0.3, 0.35)
  style.set_border_width_all(1)
  style.set_corner_radius_all(6)
  style.content_margin_left = 12
  btn.add_theme_stylebox_override("normal", style)
  var hover := style.duplicate() as StyleBoxFlat
  hover.bg_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.9)
  hover.border_color = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6)
  btn.add_theme_stylebox_override("hover", hover)
  return btn

func _update_reward_skip_btn() -> void:
  if _reward_skip_btn == null:
    return
  if _reward_gold_collected and _reward_h1_collected and _reward_h2_collected:
    _reward_skip_btn.text = "前进 →"
  elif _reward_gold_collected and not _reward_h1_collected and not _reward_h2_collected:
    _reward_skip_btn.text = "跳过卡牌 →"
  elif _reward_gold_collected:
    _reward_skip_btn.text = "跳过剩余 →"
  else:
    _reward_skip_btn.text = "跳过奖励 →"

func _on_reward_gold_clicked() -> void:
  run.add_gold(_reward_gold_amount)
  _reward_gold_collected = true
  _reward_btn_gold.disabled = true
  _reward_btn_gold.text = "  💰   已获取 %d 金币 (总计: %d)" % [_reward_gold_amount, run.gold]
  _reward_btn_gold.modulate = Color(0.5, 0.5, 0.5, 0.7)
  # Animate gold fly to top-right
  var gold_fly := Label.new()
  gold_fly.text = "+%d" % _reward_gold_amount
  gold_fly.add_theme_font_size_override("font_size", 32)
  gold_fly.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
  gold_fly.position = _reward_btn_gold.global_position + Vector2(200, 0)
  _overlay.add_child(gold_fly)
  var tween := create_tween()
  tween.set_ease(Tween.EASE_OUT)
  tween.set_trans(Tween.TRANS_CUBIC)
  tween.tween_property(gold_fly, "position", Vector2(1800, 10), 0.6)
  tween.parallel().tween_property(gold_fly, "modulate:a", 0.0, 0.5).set_delay(0.3)
  tween.tween_callback(func(): gold_fly.queue_free())
  # Update HUD gold display
  _update_hud_labels()
  _update_reward_skip_btn()

func _on_reward_h1_clicked() -> void:
  _show_card_pick_overlay(run.hero1_id, _reward_btn_h1, "h1")

func _on_reward_h2_clicked() -> void:
  _show_card_pick_overlay(run.hero2_id, _reward_btn_h2, "h2")

func _show_card_pick_overlay(hero_id: String, btn: Button, hero_key: String = "") -> void:
  _reward_card_overlay.visible = true
  _reward_card_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
  _clear_children(_reward_card_overlay)

  # Fully opaque dark overlay bg
  var overlay_bg := ColorRect.new()
  overlay_bg.color = Color(0.05, 0.04, 0.03, 1.0)
  overlay_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  overlay_bg.mouse_filter = Control.MOUSE_FILTER_STOP
  _reward_card_overlay.add_child(overlay_bg)

  # Title
  var pick_title := Label.new()
  pick_title.text = "选择一张 %s 卡牌" % _hero_name(hero_id)
  pick_title.add_theme_font_size_override("font_size", 36)
  pick_title.add_theme_color_override("font_color", _hero_color(hero_id))
  pick_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  pick_title.position = Vector2(0, 100)
  pick_title.size = Vector2(1920, 50)
  _reward_card_overlay.add_child(pick_title)

  # 3 random cards
  var cards := _random_cards_for_hero(hero_id, 3)
  var card_w: float = 280.0
  var card_h: float = 400.0
  var gap: float = 60.0
  var total_w: float = cards.size() * card_w + (cards.size() - 1) * gap
  var start_x: float = (1920.0 - total_w) / 2.0
  var card_y: float = 200.0
  var loc = get_node_or_null("/root/Loc")

  for i in range(cards.size()):
    var card_data: Dictionary = cards[i]
    var container := Control.new()
    container.position = Vector2(start_x + i * (card_w + gap), card_y)
    container.size = Vector2(card_w, card_h)
    container.mouse_filter = Control.MOUSE_FILTER_STOP
    container.gui_input.connect(func(event: InputEvent):
      if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        run.add_card(card_data["id"])
        btn.disabled = true
        btn.text = "  ✓   已选择: %s" % _card_display_name(card_data)
        btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
        if hero_key == "h1":
          _reward_h1_collected = true
        elif hero_key == "h2":
          _reward_h2_collected = true
        _update_reward_skip_btn()
        _reward_card_overlay.visible = false
        _reward_card_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    )
    _reward_card_overlay.add_child(container)
    var visual := CardScript.create_card_visual(card_data, Vector2(card_w, card_h), loc)
    container.add_child(visual)
    container.mouse_entered.connect(func(): container.modulate = Color(1.2, 1.2, 1.2))
    container.mouse_exited.connect(func(): container.modulate = Color(1, 1, 1))

  # Skip button
  var skip_btn := Button.new()
  skip_btn.text = "跳过"
  skip_btn.custom_minimum_size = Vector2(180, 50)
  skip_btn.add_theme_font_size_override("font_size", 22)
  skip_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
  var skip_style := StyleBoxFlat.new()
  skip_style.bg_color = Color(0.15, 0.15, 0.15, 0.7)
  skip_style.set_border_width_all(1)
  skip_style.border_color = Color(0.3, 0.3, 0.3)
  skip_style.set_corner_radius_all(8)
  skip_btn.add_theme_stylebox_override("normal", skip_style)
  skip_btn.position = Vector2((1920.0 - 180.0) / 2.0, card_y + card_h + 40.0)
  skip_btn.pressed.connect(func():
    _reward_card_overlay.visible = false
    _reward_card_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
  )
  _reward_card_overlay.add_child(skip_btn)

func _card_display_name(card_data: Dictionary) -> String:
  var loc = get_node_or_null("/root/Loc")
  if loc:
    var cn: String = loc.card_name(card_data)
    if cn != "":
      return cn
  return card_data.get("name", card_data.get("id", "?"))

func _create_card_button(card_data: Dictionary) -> Button:
  var btn := Button.new()
  var card_name: String = card_data.get("name", card_data.get("id", "?"))
  var loc = get_node_or_null("/root/Loc")
  if loc:
    var cn: String = loc.card_name(card_data)
    if cn != "":
      card_name = cn
  var cost: int = card_data.get("cost", 0)
  var desc: String = card_data.get("description", "")
  btn.text = "[%d] %s\n%s" % [cost, card_name, desc]
  btn.custom_minimum_size = Vector2(220, 120)
  btn.add_theme_font_size_override("font_size", 18)

  var color: Color = _hero_color(card_data.get("character", "neutral"))
  var style := StyleBoxFlat.new()
  style.bg_color = Color(color.r, color.g, color.b, 0.25)
  style.border_color = color
  style.set_border_width_all(2)
  style.set_corner_radius_all(8)
  style.content_margin_left = 10
  style.content_margin_right = 10
  style.content_margin_top = 8
  style.content_margin_bottom = 8
  btn.add_theme_stylebox_override("normal", style)
  var hover := style.duplicate() as StyleBoxFlat
  hover.bg_color = Color(color.r, color.g, color.b, 0.45)
  btn.add_theme_stylebox_override("hover", hover)
  btn.add_theme_stylebox_override("pressed", hover)
  return btn

func _random_cards_for_hero(hero_id: String, count: int) -> Array:
  var result: Array = []
  var all_cards: Array = []
  for cid in gm.card_database:
    var cd: Dictionary = gm.card_database[cid]
    if cd.get("character", "") == hero_id and cd.get("status", "active") == "active":
      all_cards.append(cd)
  all_cards.shuffle()
  for i in range(mini(count, all_cards.size())):
    result.append(all_cards[i])
  return result

# ═══════════════════════════════════════════════════════════════════════════
# REST SITE
# ═══════════════════════════════════════════════════════════════════════════

func _show_rest() -> void:
  phase = Phase.REST
  _map_layer.visible = false
  _overlay.visible = true
  _clear_children(_overlay)

  var bg := ColorRect.new()
  bg.color = Color(0, 0, 0, 0.85)
  bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _overlay.add_child(bg)

  var center := CenterContainer.new()
  center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _overlay.add_child(center)

  var vbox := VBoxContainer.new()
  vbox.add_theme_constant_override("separation", 25)
  vbox.alignment = BoxContainer.ALIGNMENT_CENTER
  center.add_child(vbox)

  var title := Label.new()
  title.text = "🔥 休息处"
  title.add_theme_font_size_override("font_size", 48)
  title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
  title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  vbox.add_child(title)

  # HP status
  var hp_info := Label.new()
  hp_info.text = "%s: %d/%d HP    %s: %d/%d HP" % [
    _hero_name(run.hero1_id), run.hero1_hp, run.hero1_max_hp,
    _hero_name(run.hero2_id), run.hero2_hp, run.hero2_max_hp]
  hp_info.add_theme_font_size_override("font_size", 22)
  hp_info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
  hp_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  vbox.add_child(hp_info)

  vbox.add_child(_spacer(20))

  # Option 1: Rest (heal 30%)
  var heal1: int = int(run.hero1_max_hp * 0.3)
  var heal2: int = int(run.hero2_max_hp * 0.3)
  var rest_btn := _styled_button("休息 — 恢复30%%最大生命\n(%s +%d, %s +%d)" % [
    _hero_name(run.hero1_id), heal1, _hero_name(run.hero2_id), heal2],
    Color(0.3, 0.8, 0.3))
  rest_btn.custom_minimum_size = Vector2(500, 80)
  rest_btn.pressed.connect(func():
    run.heal_hero(0, heal1)
    run.heal_hero(1, heal2)
    _show_map()
  )
  vbox.add_child(rest_btn)

  # Option 2: Upgrade a card
  var upgrade_btn := _styled_button("升级 — 选择一张卡牌升级", Color(0.3, 0.5, 0.9))
  upgrade_btn.custom_minimum_size = Vector2(500, 80)
  upgrade_btn.pressed.connect(_show_upgrade_selection)
  vbox.add_child(upgrade_btn)

func _show_upgrade_selection() -> void:
  _clear_children(_overlay)

  var bg := ColorRect.new()
  bg.color = Color(0, 0, 0, 0.9)
  bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _overlay.add_child(bg)

  var title := Label.new()
  title.text = "选择一张卡牌升级"
  title.add_theme_font_size_override("font_size", 36)
  title.add_theme_color_override("font_color", Color(0.3, 0.5, 0.9))
  title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  title.offset_top = 30
  title.offset_right = 1920
  _overlay.add_child(title)

  # Scrollable card grid
  var scroll := ScrollContainer.new()
  scroll.offset_top = 80
  scroll.offset_right = 1920
  scroll.offset_bottom = 1020
  _overlay.add_child(scroll)

  var grid := GridContainer.new()
  grid.columns = 6
  grid.add_theme_constant_override("h_separation", 15)
  grid.add_theme_constant_override("v_separation", 15)
  scroll.add_child(grid)

  for card_id in run.deck:
    # Skip already-upgraded cards
    if card_id.ends_with("+"):
      continue
    if not gm.card_database.has(card_id):
      continue
    var cd: Dictionary = gm.card_database[card_id]
    # Check if upgradeable (has upgrade overrides)
    if not gm._upgrade_overrides_cache.has(card_id):
      continue
    # Show upgraded version preview
    var upgraded_cd: Dictionary = gm.get_upgraded_card(card_id)
    var btn := _create_card_button(upgraded_cd if not upgraded_cd.is_empty() else cd)
    btn.pressed.connect(_upgrade_card.bind(card_id))
    grid.add_child(btn)

  # Cancel button
  var cancel := _styled_button("取消", Color(0.5, 0.5, 0.5))
  cancel.offset_top = 1030
  cancel.offset_left = 860
  cancel.offset_right = 1060
  cancel.offset_bottom = 1070
  cancel.pressed.connect(_show_rest)
  _overlay.add_child(cancel)

# ═══════════════════════════════════════════════════════════════════════════
# SHOP
# ═══════════════════════════════════════════════════════════════════════════

func _show_shop() -> void:
  phase = Phase.SHOP
  _map_layer.visible = false
  _overlay.visible = true
  _clear_children(_overlay)

  var bg := ColorRect.new()
  bg.color = Color(0, 0, 0, 0.85)
  bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _overlay.add_child(bg)

  var title := Label.new()
  title.text = "💰 商店"
  title.add_theme_font_size_override("font_size", 48)
  title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
  title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  title.offset_top = 20
  title.offset_right = 1920
  _overlay.add_child(title)

  var gold_label := Label.new()
  gold_label.text = "金币: %d" % run.gold
  gold_label.name = "ShopGold"
  gold_label.add_theme_font_size_override("font_size", 28)
  gold_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
  gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  gold_label.offset_top = 75
  gold_label.offset_right = 1920
  _overlay.add_child(gold_label)

  # Generate shop cards: 20 cards, 10 per hero, 90% base / 10% upgraded
  var shop_cards: Array = []
  for hero_id in [run.hero1_id, run.hero2_id]:
    var hero_cards: Array = []
    for cid in gm.card_database:
      var cd: Dictionary = gm.card_database[cid]
      if cd.get("character", "") == hero_id and cd.get("status", "active") == "active":
        hero_cards.append(cd)
    hero_cards.shuffle()
    for i in range(mini(10, hero_cards.size())):
      var card: Dictionary = hero_cards[i].duplicate()
      card["_shop_upgraded"] = randf() < 0.1
      card["_shop_price"] = _card_price(card)
      shop_cards.append(card)

  # Scrollable grid
  var scroll := ScrollContainer.new()
  scroll.offset_top = 115
  scroll.offset_right = 1920
  scroll.offset_bottom = 1020
  _overlay.add_child(scroll)

  var grid := GridContainer.new()
  grid.columns = 5
  grid.add_theme_constant_override("h_separation", 15)
  grid.add_theme_constant_override("v_separation", 15)
  scroll.add_child(grid)

  for card in shop_cards:
    var card_id: String = card["id"]
    var price: int = card["_shop_price"]
    var is_upgraded: bool = card.get("_shop_upgraded", false)

    var btn := _create_card_button(card)
    # Add price label
    var price_label := Label.new()
    var suffix := " ★" if is_upgraded else ""
    price_label.text = "%d金%s" % [price, suffix]
    price_label.add_theme_font_size_override("font_size", 16)
    price_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
    btn.add_child(price_label)

    var add_id: String = card_id + "+" if is_upgraded else card_id
    btn.pressed.connect(func():
      if run.spend_gold(price):
        run.add_card(add_id)
        btn.disabled = true
        btn.modulate = Color(0.5, 0.5, 0.5, 0.5)
        var gl: Label = _overlay.get_node_or_null("ShopGold")
        if gl:
          gl.text = "金币: %d" % run.gold
    )
    grid.add_child(btn)

  # Leave button
  var leave := _styled_button("离开商店", Color(0.5, 0.5, 0.5))
  leave.offset_top = 1030
  leave.offset_left = 840
  leave.offset_right = 1080
  leave.offset_bottom = 1070
  leave.pressed.connect(_show_map)
  _overlay.add_child(leave)

func _card_price(card: Dictionary) -> int:
  var base: int = 50
  match card.get("type", 0):
    0: base = 50   # Attack
    1: base = 60   # Skill
    2: base = 75   # Power
  var cost: int = card.get("cost", 1)
  base += cost * 15
  if card.get("_shop_upgraded", false):
    base = int(base * 1.5)
  return base + randi() % 20

# ═══════════════════════════════════════════════════════════════════════════
# VICTORY / DEFEAT
# ═══════════════════════════════════════════════════════════════════════════

func _show_victory() -> void:
  phase = Phase.VICTORY
  if _battle_instance:
    _battle_instance.queue_free()
    _battle_instance = null
  _map_layer.visible = false
  _overlay.visible = true
  _clear_children(_overlay)

  var bg := ColorRect.new()
  bg.color = Color(0, 0, 0, 0.9)
  bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _overlay.add_child(bg)

  var center := CenterContainer.new()
  center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _overlay.add_child(center)

  var vbox := VBoxContainer.new()
  vbox.add_theme_constant_override("separation", 30)
  vbox.alignment = BoxContainer.ALIGNMENT_CENTER
  center.add_child(vbox)

  var title := Label.new()
  title.text = "胜利！"
  title.add_theme_font_size_override("font_size", 72)
  title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
  title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  vbox.add_child(title)

  var stats := Label.new()
  stats.text = "击败了远古巨龙！\n最终层数: %d\n金币: %d\n卡组: %d张" % [run.floor_num, run.gold, run.deck.size()]
  stats.add_theme_font_size_override("font_size", 28)
  stats.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
  stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  vbox.add_child(stats)

  var back := _styled_button("返回主菜单", Color(0.4, 0.6, 0.9))
  back.pressed.connect(func():
    run.end_run(true)
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
  )
  vbox.add_child(back)

func _show_defeat() -> void:
  phase = Phase.DEFEAT
  _map_layer.visible = false
  _overlay.visible = true
  _clear_children(_overlay)

  var bg := ColorRect.new()
  bg.color = Color(0, 0, 0, 0.9)
  bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _overlay.add_child(bg)

  var center := CenterContainer.new()
  center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _overlay.add_child(center)

  var vbox := VBoxContainer.new()
  vbox.add_theme_constant_override("separation", 30)
  vbox.alignment = BoxContainer.ALIGNMENT_CENTER
  center.add_child(vbox)

  var title := Label.new()
  title.text = "败北..."
  title.add_theme_font_size_override("font_size", 72)
  title.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
  title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  vbox.add_child(title)

  var stats := Label.new()
  stats.text = "到达第 %d 层\n金币: %d\n卡组: %d张" % [run.floor_num, run.gold, run.deck.size()]
  stats.add_theme_font_size_override("font_size", 28)
  stats.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
  stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  vbox.add_child(stats)

  var back := _styled_button("返回主菜单", Color(0.4, 0.6, 0.9))
  back.pressed.connect(func():
    run.end_run(false)
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
  )
  vbox.add_child(back)

# ═══════════════════════════════════════════════════════════════════════════
# DECK VIEWER
# ═══════════════════════════════════════════════════════════════════════════

func _show_deck_viewer() -> void:
  _overlay.visible = true
  _clear_children(_overlay)

  var bg := ColorRect.new()
  bg.color = Color(0, 0, 0, 0.9)
  bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _overlay.add_child(bg)

  var title := Label.new()
  title.text = "卡组 (%d张)" % run.deck.size()
  title.add_theme_font_size_override("font_size", 36)
  title.add_theme_color_override("font_color", Color.WHITE)
  title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  title.offset_top = 20
  title.offset_right = 1920
  _overlay.add_child(title)

  var scroll := ScrollContainer.new()
  scroll.offset_top = 70
  scroll.offset_right = 1920
  scroll.offset_bottom = 1020
  _overlay.add_child(scroll)

  var grid := GridContainer.new()
  grid.columns = 6
  grid.add_theme_constant_override("h_separation", 10)
  grid.add_theme_constant_override("v_separation", 10)
  scroll.add_child(grid)

  for card_id in run.deck:
    var display_cd: Dictionary = {}
    if card_id.ends_with("+"):
      var base_id: String = card_id.trim_suffix("+")
      display_cd = gm.get_upgraded_card(base_id)
    elif gm.card_database.has(card_id):
      display_cd = gm.card_database[card_id]
    if not display_cd.is_empty():
      var lbl := _create_card_button(display_cd)
      lbl.disabled = true
      grid.add_child(lbl)

  var close := _styled_button("关闭", Color(0.5, 0.5, 0.5))
  close.offset_top = 1030
  close.offset_left = 860
  close.offset_right = 1060
  close.offset_bottom = 1070
  close.pressed.connect(func():
    _overlay.visible = false
    _clear_children(_overlay)
  )
  _overlay.add_child(close)

# ═══════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════

func _upgrade_card(card_id: String) -> void:
  run.upgrade_card(card_id)
  _show_map()

func _hero_name(hero_id: String) -> String:
  match hero_id:
    "ironclad": return "铁甲战士"
    "silent": return "沉默猎手"
  return hero_id

func _hero_color(hero_id: String) -> Color:
  match hero_id:
    "ironclad": return Color(0.8, 0.2, 0.2)
    "silent": return Color(0.2, 0.7, 0.3)
    "neutral": return Color(0.5, 0.5, 0.5)
  return Color.WHITE

func _hud_label(text: String) -> Label:
  var l := Label.new()
  l.text = text
  l.add_theme_font_size_override("font_size", 22)
  l.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
  return l

func _styled_button(text: String, color: Color) -> Button:
  var btn := Button.new()
  btn.text = text
  btn.custom_minimum_size = Vector2(300, 60)
  btn.add_theme_font_size_override("font_size", 24)
  btn.add_theme_color_override("font_color", Color.WHITE)
  var style := StyleBoxFlat.new()
  style.bg_color = Color(color.r, color.g, color.b, 0.35)
  style.border_color = color
  style.set_border_width_all(2)
  style.set_corner_radius_all(8)
  btn.add_theme_stylebox_override("normal", style)
  var hover := style.duplicate() as StyleBoxFlat
  hover.bg_color = Color(color.r, color.g, color.b, 0.55)
  btn.add_theme_stylebox_override("hover", hover)
  btn.add_theme_stylebox_override("pressed", hover)
  return btn

func _spacer(h: int) -> Control:
  var s := Control.new()
  s.custom_minimum_size = Vector2(0, h)
  return s

func _clear_children(node: Node) -> void:
  for child in node.get_children():
    child.queue_free()
