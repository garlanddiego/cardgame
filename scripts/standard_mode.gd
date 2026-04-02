extends Control
## res://scripts/standard_mode.gd — Standard Mode: map, battles, rewards, rest, shop

const MonstersDB = preload("res://scripts/monsters.gd")

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
var _draft_total_rounds: int = 3

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
  # Overlay layer (for rewards, rest, shop popups)
  _overlay = Control.new()
  _overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
  _overlay.visible = false
  add_child(_overlay)

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
  _overlay.add_child(bg)

  var center := CenterContainer.new()
  center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _overlay.add_child(center)

  var vbox := VBoxContainer.new()
  vbox.add_theme_constant_override("separation", 20)
  vbox.alignment = BoxContainer.ALIGNMENT_CENTER
  center.add_child(vbox)

  # Title
  var title := Label.new()
  title.text = "初始选牌  第 %d/%d 轮" % [_draft_round, _draft_total_rounds]
  title.add_theme_font_size_override("font_size", 42)
  title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
  title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  vbox.add_child(title)

  var deck_info := Label.new()
  deck_info.text = "当前卡组: %d 张" % run.deck.size()
  deck_info.add_theme_font_size_override("font_size", 20)
  deck_info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
  deck_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  vbox.add_child(deck_info)

  vbox.add_child(_spacer(10))

  # Ironclad cards row
  var ic_label := Label.new()
  ic_label.text = "铁甲战士 — 选择一张 (或跳过)"
  ic_label.add_theme_font_size_override("font_size", 24)
  ic_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
  ic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  vbox.add_child(ic_label)

  var ic_cards := _random_cards_for_hero("ironclad", 3)
  var ic_row := _create_draft_row(ic_cards, "ironclad")
  vbox.add_child(ic_row)

  vbox.add_child(_spacer(10))

  # Silent cards row
  var si_label := Label.new()
  si_label.text = "沉默猎手 — 选择一张 (或跳过)"
  si_label.add_theme_font_size_override("font_size", 24)
  si_label.add_theme_color_override("font_color", Color(0.2, 0.7, 0.3))
  si_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  vbox.add_child(si_label)

  var si_cards := _random_cards_for_hero("silent", 3)
  var si_row := _create_draft_row(si_cards, "silent")
  vbox.add_child(si_row)

  vbox.add_child(_spacer(10))

  # Skip both button
  var skip_btn := _styled_button("两组都跳过 →", Color(0.4, 0.4, 0.4))
  skip_btn.pressed.connect(_on_draft_skip.bind(null, null))
  vbox.add_child(skip_btn)

var _draft_ic_done: bool = false
var _draft_si_done: bool = false
var _draft_ic_row: HBoxContainer = null
var _draft_si_row: HBoxContainer = null

func _create_draft_row(cards: Array, hero_id: String) -> HBoxContainer:
  var row := HBoxContainer.new()
  row.add_theme_constant_override("separation", 20)
  row.alignment = BoxContainer.ALIGNMENT_CENTER
  for card_data in cards:
    var btn := _create_card_button(card_data)
    btn.custom_minimum_size = Vector2(260, 140)
    var cid: String = card_data["id"]
    btn.pressed.connect(_on_draft_card_picked.bind(hero_id, cid))
    row.add_child(btn)
  # Skip button for this hero
  var skip := Button.new()
  skip.text = "跳过"
  skip.custom_minimum_size = Vector2(80, 60)
  skip.add_theme_font_size_override("font_size", 20)
  skip.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
  var skip_style := StyleBoxFlat.new()
  skip_style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
  skip_style.set_border_width_all(1)
  skip_style.border_color = Color(0.4, 0.4, 0.4)
  skip_style.set_corner_radius_all(6)
  skip.add_theme_stylebox_override("normal", skip_style)
  skip.pressed.connect(_on_draft_card_picked.bind(hero_id, ""))
  row.add_child(skip)
  if hero_id == "ironclad":
    _draft_ic_row = row
  else:
    _draft_si_row = row
  return row

func _on_draft_card_picked(hero_id: String, card_id: String) -> void:
  # Prevent double-pick from same row
  if hero_id == "ironclad" and _draft_ic_done:
    return
  if hero_id == "silent" and _draft_si_done:
    return
  # Add card to deck (skip if empty = user chose skip)
  if card_id != "":
    run.add_card(card_id)
  # Dim the row to show selection made
  if hero_id == "ironclad":
    _draft_ic_done = true
    if _draft_ic_row:
      for child in _draft_ic_row.get_children():
        child.modulate = Color(0.4, 0.4, 0.4, 0.6)
        if child is Button:
          (child as Button).disabled = true
  else:
    _draft_si_done = true
    if _draft_si_row:
      for child in _draft_si_row.get_children():
        child.modulate = Color(0.4, 0.4, 0.4, 0.6)
        if child is Button:
          (child as Button).disabled = true
  # Both done? Advance
  if _draft_ic_done and _draft_si_done:
    _advance_draft()

func _on_draft_skip(_ic: Variant, _si: Variant) -> void:
  if not _draft_ic_done:
    _draft_ic_done = true
    if _draft_ic_row:
      for child in _draft_ic_row.get_children():
        child.modulate = Color(0.4, 0.4, 0.4, 0.6)
        if child is Button:
          (child as Button).disabled = true
  if not _draft_si_done:
    _draft_si_done = true
    if _draft_si_row:
      for child in _draft_si_row.get_children():
        child.modulate = Color(0.4, 0.4, 0.4, 0.6)
        if child is Button:
          (child as Button).disabled = true
  _advance_draft()

func _advance_draft() -> void:
  _draft_ic_done = false
  _draft_si_done = false
  _draft_ic_row = null
  _draft_si_row = null
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

func _show_rewards() -> void:
  phase = Phase.REWARD
  if _battle_instance:
    _battle_instance.queue_free()
    _battle_instance = null

  _map_layer.visible = false
  _overlay.visible = true
  _clear_children(_overlay)

  # Dark background
  var bg := ColorRect.new()
  bg.color = Color(0, 0, 0, 0.85)
  bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _overlay.add_child(bg)

  var center := CenterContainer.new()
  center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _overlay.add_child(center)

  var vbox := VBoxContainer.new()
  vbox.add_theme_constant_override("separation", 20)
  vbox.alignment = BoxContainer.ALIGNMENT_CENTER
  center.add_child(vbox)

  # Title
  var title := Label.new()
  title.text = "战斗胜利！"
  title.add_theme_font_size_override("font_size", 48)
  title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
  title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  vbox.add_child(title)

  # Gold reward
  var gold_amount: int = 15 + randi() % 15 + run.floor_num * 3
  run.add_gold(gold_amount)
  var gold_label := Label.new()
  gold_label.text = "获得 %d 金币 (总计: %d)" % [gold_amount, run.gold]
  gold_label.add_theme_font_size_override("font_size", 28)
  gold_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
  gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  vbox.add_child(gold_label)

  # Spacer
  vbox.add_child(_spacer(20))

  # Card rewards — Hero 1
  var h1_label := Label.new()
  h1_label.text = "%s 卡牌奖励:" % _hero_name(run.hero1_id)
  h1_label.add_theme_font_size_override("font_size", 24)
  h1_label.add_theme_color_override("font_color", _hero_color(run.hero1_id))
  h1_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  vbox.add_child(h1_label)

  var h1_cards := _random_cards_for_hero(run.hero1_id, 3)
  var h1_row := _create_card_reward_row(h1_cards)
  vbox.add_child(h1_row)

  # Card rewards — Hero 2
  var h2_label := Label.new()
  h2_label.text = "%s 卡牌奖励:" % _hero_name(run.hero2_id)
  h2_label.add_theme_font_size_override("font_size", 24)
  h2_label.add_theme_color_override("font_color", _hero_color(run.hero2_id))
  h2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  vbox.add_child(h2_label)

  var h2_cards := _random_cards_for_hero(run.hero2_id, 3)
  var h2_row := _create_card_reward_row(h2_cards)
  vbox.add_child(h2_row)

  # Skip button
  vbox.add_child(_spacer(10))
  var skip_btn := _styled_button("跳过 → 继续", Color(0.5, 0.5, 0.5))
  skip_btn.pressed.connect(_show_map)
  vbox.add_child(skip_btn)

func _create_card_reward_row(cards: Array) -> HBoxContainer:
  var row := HBoxContainer.new()
  row.add_theme_constant_override("separation", 20)
  row.alignment = BoxContainer.ALIGNMENT_CENTER
  for card_data in cards:
    var btn := _create_card_button(card_data)
    btn.pressed.connect(func():
      run.add_card(card_data["id"])
      _show_map()
    )
    row.add_child(btn)
  return row

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
