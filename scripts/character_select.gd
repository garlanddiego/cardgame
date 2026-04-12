extends Control
## res://scripts/character_select.gd — Hero selection screen
## 5 hero portrait cards side by side horizontally, bottom bar with slots + start + mode toggle

signal character_chosen(character_id: String)
signal dual_battle_chosen(hero1_id: String, hero2_id: String)
signal back_pressed

const HEROES := ["ironclad", "silent", "bloodfiend", "fire_mage", "forger"]
const HERO_NAMES := {"ironclad": "铁甲战士", "silent": "静默猎手", "bloodfiend": "嗜血狂魔", "fire_mage": "火法师", "forger": "铸造者"}
const HERO_COLORS := {
  "ironclad": Color(0.8, 0.2, 0.2),
  "silent": Color(0.2, 0.7, 0.3),
  "bloodfiend": Color(0.7, 0.1, 0.2),
  "fire_mage": Color(0.9, 0.4, 0.1),
  "forger": Color(0.7, 0.5, 0.2),
}
const HERO_PORTRAITS := {
  "ironclad": "res://assets/img/hero_portraits/ironclad.png",
  "silent": "res://assets/img/hero_portraits/silent.png",
  "bloodfiend": "res://assets/img/hero_portraits/bloodfiend.png",
  "fire_mage": "res://assets/img/hero_portraits/fire_mage.png",
  "forger": "res://assets/img/hero_portraits/forger.png",
}

var _dual_mode: bool = false
var _selected_hero1: String = ""
var _selected_hero2: String = ""

# UI references
var _slot1_tex: TextureRect = null
var _slot1_label: Label = null
var _slot2_tex: TextureRect = null
var _slot2_label: Label = null
var _slot2_container: Control = null
var _mode_btn: Button = null
var _start_btn: Button = null
var _hero_panels: Dictionary = {}  # hero_id -> PanelContainer

func _ready() -> void:
  _build_ui()

func _build_ui() -> void:
  for c in get_children():
    c.queue_free()

  # Background
  var bg = ColorRect.new()
  bg.color = Color(0.06, 0.05, 0.04)
  bg.set_anchors_preset(Control.PRESET_FULL_RECT)
  bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
  add_child(bg)

  # Main vertical layout
  var main_vbox = VBoxContainer.new()
  main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
  main_vbox.offset_left = 10
  main_vbox.offset_right = -10
  main_vbox.offset_top = 8
  main_vbox.offset_bottom = -8
  main_vbox.add_theme_constant_override("separation", 6)
  add_child(main_vbox)

  # === HERO CARD ROW (5 cards side by side, fills most of the screen) ===
  var card_row = HBoxContainer.new()
  card_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
  card_row.add_theme_constant_override("separation", 4)
  main_vbox.add_child(card_row)

  for hero_id in HEROES:
    var panel = _create_hero_card(hero_id)
    card_row.add_child(panel)
    _hero_panels[hero_id] = panel

  # === BOTTOM BAR: slots + start button + mode toggle + exit ===
  var bottom_bar = HBoxContainer.new()
  bottom_bar.add_theme_constant_override("separation", 15)
  bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
  bottom_bar.custom_minimum_size = Vector2(0, 72)
  main_vbox.add_child(bottom_bar)

  # Slot 1
  var slot1 = _create_slot("英雄1")
  _slot1_tex = slot1[0]
  _slot1_label = slot1[1]
  bottom_bar.add_child(slot1[2])

  # Slot 2 (hidden in single mode)
  var slot2 = _create_slot("英雄2")
  _slot2_tex = slot2[0]
  _slot2_label = slot2[1]
  _slot2_container = slot2[2]
  _slot2_container.visible = _dual_mode
  bottom_bar.add_child(_slot2_container)

  # Start button
  _start_btn = Button.new()
  _start_btn.text = "开始战斗"
  _start_btn.custom_minimum_size = Vector2(140, 50)
  _start_btn.add_theme_font_size_override("font_size", 22)
  _style_button(_start_btn, Color(0.8, 0.2, 0.2))
  _start_btn.pressed.connect(_on_start)
  _start_btn.disabled = true
  bottom_bar.add_child(_start_btn)

  # Spacer
  var spacer = Control.new()
  spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  bottom_bar.add_child(spacer)

  # Mode toggle
  _mode_btn = Button.new()
  _mode_btn.custom_minimum_size = Vector2(140, 40)
  _mode_btn.add_theme_font_size_override("font_size", 18)
  _update_mode_button()
  _mode_btn.pressed.connect(_toggle_mode)
  bottom_bar.add_child(_mode_btn)

  # Exit button
  var exit_btn = Button.new()
  exit_btn.text = "退出"
  exit_btn.custom_minimum_size = Vector2(80, 40)
  exit_btn.add_theme_font_size_override("font_size", 18)
  _style_button(exit_btn, Color(0.4, 0.35, 0.3))
  exit_btn.pressed.connect(func(): back_pressed.emit())
  bottom_bar.add_child(exit_btn)

  _update_slots_display()

func _create_hero_card(hero_id: String) -> PanelContainer:
  var panel = PanelContainer.new()
  panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

  var color: Color = HERO_COLORS.get(hero_id, Color.WHITE)
  var style = StyleBoxFlat.new()
  style.bg_color = Color(color.r * 0.1, color.g * 0.1, color.b * 0.1, 0.9)
  style.border_color = Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 0.5)
  style.border_width_left = 2
  style.border_width_right = 2
  style.border_width_top = 2
  style.border_width_bottom = 2
  style.corner_radius_top_left = 6
  style.corner_radius_top_right = 6
  style.corner_radius_bottom_left = 6
  style.corner_radius_bottom_right = 6
  panel.add_theme_stylebox_override("panel", style)

  var vbox = VBoxContainer.new()
  vbox.add_theme_constant_override("separation", 4)
  panel.add_child(vbox)

  # Portrait (fills card)
  var portrait = TextureRect.new()
  portrait.name = "Portrait"
  portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
  portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
  var portrait_path: String = HERO_PORTRAITS.get(hero_id, "")
  if ResourceLoader.exists(portrait_path):
    portrait.texture = load(portrait_path)
  else:
    var sprite_path: String = "res://assets/img/" + hero_id + ".png"
    if ResourceLoader.exists(sprite_path):
      portrait.texture = load(sprite_path)
  vbox.add_child(portrait)

  # Name label at bottom
  var name_label = Label.new()
  name_label.text = HERO_NAMES.get(hero_id, hero_id)
  name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  name_label.add_theme_font_size_override("font_size", 20)
  name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
  vbox.add_child(name_label)

  # Clickable overlay
  var btn_overlay = Button.new()
  btn_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
  btn_overlay.flat = true
  btn_overlay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
  var empty_style = StyleBoxEmpty.new()
  btn_overlay.add_theme_stylebox_override("normal", empty_style)
  btn_overlay.add_theme_stylebox_override("hover", empty_style)
  btn_overlay.add_theme_stylebox_override("pressed", empty_style)
  btn_overlay.add_theme_stylebox_override("focus", empty_style)
  btn_overlay.pressed.connect(func(): _on_hero_clicked(hero_id))
  panel.add_child(btn_overlay)

  return panel

func _create_slot(label_text: String) -> Array:
  var container = VBoxContainer.new()
  container.add_theme_constant_override("separation", 2)
  container.alignment = BoxContainer.ALIGNMENT_CENTER

  var label = Label.new()
  label.text = label_text
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  label.add_theme_font_size_override("font_size", 12)
  label.add_theme_color_override("font_color", Color(0.5, 0.48, 0.42))
  container.add_child(label)

  var slot_bg = PanelContainer.new()
  var slot_style = StyleBoxFlat.new()
  slot_style.bg_color = Color(0.1, 0.08, 0.06)
  slot_style.border_color = Color(0.35, 0.3, 0.2)
  slot_style.border_width_left = 2
  slot_style.border_width_right = 2
  slot_style.border_width_top = 2
  slot_style.border_width_bottom = 2
  slot_style.corner_radius_top_left = 5
  slot_style.corner_radius_top_right = 5
  slot_style.corner_radius_bottom_left = 5
  slot_style.corner_radius_bottom_right = 5
  slot_bg.add_theme_stylebox_override("panel", slot_style)
  slot_bg.custom_minimum_size = Vector2(50, 50)
  container.add_child(slot_bg)

  var tex = TextureRect.new()
  tex.custom_minimum_size = Vector2(46, 46)
  tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
  slot_bg.add_child(tex)

  var name_lbl = Label.new()
  name_lbl.text = ""
  name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  name_lbl.add_theme_font_size_override("font_size", 11)
  name_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.55))
  container.add_child(name_lbl)

  return [tex, name_lbl, container]

# ===========================================================================
# SELECTION LOGIC
# ===========================================================================

func _on_hero_clicked(hero_id: String) -> void:
  if _dual_mode:
    _on_hero_clicked_dual(hero_id)
  else:
    _on_hero_clicked_single(hero_id)
  _update_slots_display()
  _update_hero_highlights()

func _on_hero_clicked_single(hero_id: String) -> void:
  if hero_id == _selected_hero1:
    _selected_hero1 = ""
  else:
    _selected_hero1 = hero_id
  _selected_hero2 = ""

func _on_hero_clicked_dual(hero_id: String) -> void:
  if hero_id == _selected_hero1:
    _selected_hero1 = _selected_hero2
    _selected_hero2 = ""
    return
  if hero_id == _selected_hero2:
    _selected_hero2 = ""
    return
  if _selected_hero1 == "":
    _selected_hero1 = hero_id
  elif _selected_hero2 == "":
    _selected_hero2 = hero_id
  else:
    _selected_hero1 = _selected_hero2
    _selected_hero2 = hero_id

func _toggle_mode() -> void:
  _dual_mode = not _dual_mode
  _selected_hero1 = ""
  _selected_hero2 = ""
  _slot2_container.visible = _dual_mode
  _update_mode_button()
  _update_slots_display()
  _update_hero_highlights()

func _update_mode_button() -> void:
  if _dual_mode:
    _mode_btn.text = "单英雄模式"
    _style_button(_mode_btn, Color(0.2, 0.6, 0.8))
  else:
    _mode_btn.text = "双英雄模式"
    _style_button(_mode_btn, Color(0.5, 0.4, 0.2))

func _update_slots_display() -> void:
  if _selected_hero1 != "":
    var path: String = HERO_PORTRAITS.get(_selected_hero1, "")
    if not ResourceLoader.exists(path):
      path = "res://assets/img/" + _selected_hero1 + ".png"
    if ResourceLoader.exists(path):
      _slot1_tex.texture = load(path)
    _slot1_label.text = HERO_NAMES.get(_selected_hero1, "")
  else:
    _slot1_tex.texture = null
    _slot1_label.text = ""

  if _selected_hero2 != "":
    var path: String = HERO_PORTRAITS.get(_selected_hero2, "")
    if not ResourceLoader.exists(path):
      path = "res://assets/img/" + _selected_hero2 + ".png"
    if ResourceLoader.exists(path):
      _slot2_tex.texture = load(path)
    _slot2_label.text = HERO_NAMES.get(_selected_hero2, "")
  else:
    _slot2_tex.texture = null
    _slot2_label.text = ""

  if _dual_mode:
    _start_btn.disabled = _selected_hero1 == "" or _selected_hero2 == ""
  else:
    _start_btn.disabled = _selected_hero1 == ""

func _update_hero_highlights() -> void:
  for hero_id in _hero_panels:
    var panel: PanelContainer = _hero_panels[hero_id]
    var color: Color = HERO_COLORS.get(hero_id, Color.WHITE)
    var style = StyleBoxFlat.new()
    var is_selected: bool = hero_id == _selected_hero1 or hero_id == _selected_hero2
    if is_selected:
      style.bg_color = Color(color.r * 0.25, color.g * 0.25, color.b * 0.25, 0.95)
      style.border_color = Color(0.95, 0.85, 0.4, 1.0)
      style.border_width_left = 3
      style.border_width_right = 3
      style.border_width_top = 3
      style.border_width_bottom = 3
    else:
      style.bg_color = Color(color.r * 0.1, color.g * 0.1, color.b * 0.1, 0.9)
      style.border_color = Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 0.5)
      style.border_width_left = 2
      style.border_width_right = 2
      style.border_width_top = 2
      style.border_width_bottom = 2
    style.corner_radius_top_left = 6
    style.corner_radius_top_right = 6
    style.corner_radius_bottom_left = 6
    style.corner_radius_bottom_right = 6
    panel.add_theme_stylebox_override("panel", style)

func _on_start() -> void:
  if _dual_mode and _selected_hero1 != "" and _selected_hero2 != "":
    dual_battle_chosen.emit(_selected_hero1, _selected_hero2)
  elif not _dual_mode and _selected_hero1 != "":
    character_chosen.emit(_selected_hero1)

func _style_button(btn: Button, color: Color) -> void:
  var style = StyleBoxFlat.new()
  style.bg_color = Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 0.8)
  style.border_color = color
  style.border_width_left = 2
  style.border_width_right = 2
  style.border_width_top = 2
  style.border_width_bottom = 2
  style.corner_radius_top_left = 6
  style.corner_radius_top_right = 6
  style.corner_radius_bottom_left = 6
  style.corner_radius_bottom_right = 6
  btn.add_theme_stylebox_override("normal", style)
  var hover = style.duplicate() as StyleBoxFlat
  hover.bg_color = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 0.9)
  btn.add_theme_stylebox_override("hover", hover)
