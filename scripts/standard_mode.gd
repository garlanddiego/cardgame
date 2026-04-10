extends Control
## res://scripts/standard_mode.gd — Standard Mode: map, battles, rewards, rest, shop

const MonstersDB = preload("res://scripts/monsters.gd")
const CardScript = preload("res://scripts/card.gd")

enum Phase { HERO_SELECT, DRAFT, MAP, BATTLE, REWARD, REST, SHOP, VICTORY, DEFEAT }
var phase: Phase = Phase.HERO_SELECT

var run: Node = null  # RunManager
var gm: Node = null   # GameManager

# UI containers
var _map_layer: Control = null
var _overlay: Control = null
var _battle_instance: Node2D = null
var _current_monsters: Array = []  # [{id, hp}]
var _pending_node: Dictionary = {}
var _persistent_hud_canvas: CanvasLayer = null
var _deck_viewer_canvas: CanvasLayer = null
var _main_bg: ColorRect = null

# Draft state
var _draft_round: int = 0
var _draft_total_rounds: int = 6
var _draft_hero_order: Array = ["ironclad", "silent", "ironclad", "silent", "ironclad", "silent"]
var _draft_picked_cards: Array = []  # card data dicts picked so far
var _draft_status_bar: HBoxContainer = null  # top status bar
var _draft_card_count_label: Button = null

# Solo/Dual hero mode
var _solo_mode: bool = false

var _hero_select_container: Control = null

func _ready() -> void:
	# Let input pass through to battle scene's Area2D cards
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	run = get_node_or_null("/root/RunManager")
	gm = get_node_or_null("/root/GameManager")
	if run == null or gm == null:
		push_error("RunManager or GameManager missing")
		return
	_build_ui()
	_show_hero_select()

func _build_ui() -> void:
	# Dark background (hidden during battle so battle's own bg shows)
	_main_bg = ColorRect.new()
	_main_bg.color = Color(0.05, 0.04, 0.03)
	_main_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_main_bg)
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
	# Deck viewer layer — above overlay but below persistent HUD
	_deck_viewer_canvas = CanvasLayer.new()
	_deck_viewer_canvas.name = "DeckViewerCanvas"
	_deck_viewer_canvas.layer = 15
	add_child(_deck_viewer_canvas)
	# Persistent HUD — always visible across all phases (CanvasLayer above everything)
	_persistent_hud_canvas = CanvasLayer.new()
	_persistent_hud_canvas.name = "PersistentHUD"
	_persistent_hud_canvas.layer = 20  # Above overlay (10) and battle HUD (1)
	_persistent_hud_canvas.visible = true  # Always visible across all phases
	add_child(_persistent_hud_canvas)
	_build_persistent_hud(_persistent_hud_canvas)

func _build_persistent_hud(canvas: CanvasLayer) -> void:
	var vw: float = get_viewport_rect().size.x
	var hud := PanelContainer.new()
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(0.04, 0.035, 0.025, 0.92)
	hud_style.border_color = Color(0.5, 0.4, 0.22)
	hud_style.border_width_bottom = 3
	hud_style.content_margin_left = 30
	hud_style.content_margin_right = 30
	hud_style.content_margin_top = 10
	hud_style.content_margin_bottom = 10
	hud_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	hud_style.shadow_size = 5
	hud_style.shadow_offset = Vector2(0, 3)
	hud.add_theme_stylebox_override("panel", hud_style)
	hud.offset_right = vw
	hud.offset_bottom = 75
	canvas.add_child(hud)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 30)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_child(hbox)

	_hud_hp1_label = _hud_label("♥ %s %d/%d" % [_hero_name(run.hero1_id), run.hero1_hp, run.hero1_max_hp])
	hbox.add_child(_hud_hp1_label)

	_hud_hp2_label = _hud_label("♥ %s %d/%d" % [_hero_name(run.hero2_id), run.hero2_hp, run.hero2_max_hp])
	hbox.add_child(_hud_hp2_label)

	_hud_gold_label = _hud_label("$ %d" % run.gold)
	hbox.add_child(_hud_gold_label)

	# Backpack button — shows backpack card count and battle uses
	_hud_backpack_btn = Button.new()
	_hud_backpack_btn.text = "[包] %d/4" % run.backpack.size()
	_hud_backpack_btn.add_theme_font_size_override("font_size", 20)
	_hud_backpack_btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	var bp_style := StyleBoxFlat.new()
	bp_style.bg_color = Color(0.12, 0.1, 0.06, 0.75)
	bp_style.border_color = Color(0.5, 0.4, 0.25, 0.65)
	bp_style.set_border_width_all(1)
	bp_style.set_corner_radius_all(8)
	bp_style.content_margin_left = 10
	bp_style.content_margin_right = 10
	bp_style.content_margin_top = 4
	bp_style.content_margin_bottom = 4
	_hud_backpack_btn.add_theme_stylebox_override("normal", bp_style)
	var bp_hover := bp_style.duplicate() as StyleBoxFlat
	bp_hover.bg_color = Color(0.22, 0.18, 0.1, 0.9)
	bp_hover.border_color = Color(0.65, 0.5, 0.3, 0.8)
	_hud_backpack_btn.add_theme_stylebox_override("hover", bp_hover)
	var bp_pressed := bp_style.duplicate() as StyleBoxFlat
	bp_pressed.bg_color = Color(0.08, 0.06, 0.04, 0.85)
	_hud_backpack_btn.add_theme_stylebox_override("pressed", bp_pressed)
	_hud_backpack_btn.pressed.connect(_show_backpack)
	hbox.add_child(_hud_backpack_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	_hud_floor_label = _hud_label("")
	hbox.add_child(_hud_floor_label)

	_hud_deck_btn = Button.new()
	_hud_deck_btn.text = "卡组 (%d)" % run.deck.size()
	_hud_deck_btn.add_theme_font_size_override("font_size", 20)
	_hud_deck_btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	var deck_style := StyleBoxFlat.new()
	deck_style.bg_color = Color(0.12, 0.1, 0.06, 0.75)
	deck_style.border_color = Color(0.5, 0.4, 0.25, 0.65)
	deck_style.set_border_width_all(1)
	deck_style.set_corner_radius_all(8)
	deck_style.content_margin_left = 10
	deck_style.content_margin_right = 10
	deck_style.content_margin_top = 4
	deck_style.content_margin_bottom = 4
	_hud_deck_btn.add_theme_stylebox_override("normal", deck_style)
	var deck_hover := deck_style.duplicate() as StyleBoxFlat
	deck_hover.bg_color = Color(0.22, 0.18, 0.1, 0.9)
	deck_hover.border_color = Color(0.65, 0.5, 0.3, 0.8)
	_hud_deck_btn.add_theme_stylebox_override("hover", deck_hover)
	var deck_pressed := deck_style.duplicate() as StyleBoxFlat
	deck_pressed.bg_color = Color(0.08, 0.06, 0.04, 0.85)
	_hud_deck_btn.add_theme_stylebox_override("pressed", deck_pressed)
	_hud_deck_btn.pressed.connect(_show_deck_viewer)
	hbox.add_child(_hud_deck_btn)

	# Map viewer button with map icon
	_hud_map_btn = Button.new()
	_hud_map_btn.custom_minimum_size = Vector2(44, 44)
	var map_tex = load("res://assets/img/ui_icons/map.png")
	if map_tex:
		var map_icon := TextureRect.new()
		map_icon.texture = map_tex
		map_icon.custom_minimum_size = Vector2(36, 36)
		map_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		map_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		map_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_map_btn.add_child(map_icon)
	else:
		_hud_map_btn.text = "🗺"
	var map_btn_style := StyleBoxFlat.new()
	map_btn_style.bg_color = Color(0.12, 0.1, 0.06, 0.75)
	map_btn_style.border_color = Color(0.5, 0.4, 0.25, 0.65)
	map_btn_style.set_border_width_all(1)
	map_btn_style.set_corner_radius_all(8)
	map_btn_style.content_margin_left = 4
	map_btn_style.content_margin_right = 4
	map_btn_style.content_margin_top = 4
	map_btn_style.content_margin_bottom = 4
	_hud_map_btn.add_theme_stylebox_override("normal", map_btn_style)
	var map_btn_hover := map_btn_style.duplicate() as StyleBoxFlat
	map_btn_hover.bg_color = Color(0.22, 0.18, 0.1, 0.9)
	map_btn_hover.border_color = Color(0.65, 0.5, 0.3, 0.8)
	_hud_map_btn.add_theme_stylebox_override("hover", map_btn_hover)
	var map_btn_pressed := map_btn_style.duplicate() as StyleBoxFlat
	map_btn_pressed.bg_color = Color(0.08, 0.06, 0.04, 0.85)
	_hud_map_btn.add_theme_stylebox_override("pressed", map_btn_pressed)
	_hud_map_btn.pressed.connect(_show_map_viewer)
	hbox.add_child(_hud_map_btn)

	# Exit button — rightmost, return to main menu
	var exit_btn := Button.new()
	exit_btn.text = "退出"
	exit_btn.add_theme_font_size_override("font_size", 20)
	exit_btn.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
	var exit_style := StyleBoxFlat.new()
	exit_style.bg_color = Color(0.35, 0.08, 0.08, 0.75)
	exit_style.border_color = Color(0.6, 0.2, 0.2, 0.65)
	exit_style.set_border_width_all(1)
	exit_style.set_corner_radius_all(8)
	exit_style.content_margin_left = 10
	exit_style.content_margin_right = 10
	exit_style.content_margin_top = 4
	exit_style.content_margin_bottom = 4
	exit_btn.add_theme_stylebox_override("normal", exit_style)
	var exit_hover := exit_style.duplicate() as StyleBoxFlat
	exit_hover.bg_color = Color(0.55, 0.12, 0.12, 0.9)
	exit_hover.border_color = Color(0.75, 0.3, 0.3, 0.8)
	exit_btn.add_theme_stylebox_override("hover", exit_hover)
	var exit_pressed := exit_style.duplicate() as StyleBoxFlat
	exit_pressed.bg_color = Color(0.25, 0.05, 0.05, 0.85)
	exit_btn.add_theme_stylebox_override("pressed", exit_pressed)
	exit_btn.pressed.connect(func():
		run.end_run(false)
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	hbox.add_child(exit_btn)

# ═══════════════════════════════════════════════════════════════════════════
# INITIAL DRAFT (4 rounds of card picking before map)
# ═══════════════════════════════════════════════════════════════════════════

func _show_hero_select() -> void:
	phase = Phase.HERO_SELECT
	_map_layer.visible = false
	_overlay.visible = true
	for c in _overlay.get_children():
		c.queue_free()
	if _persistent_hud_canvas:
		_persistent_hud_canvas.visible = false

	var vw: float = get_viewport_rect().size.x
	var heroes := [
		{"id": "ironclad", "name": "铁甲战士", "color": Color(0.8, 0.2, 0.2), "hp": 70},
		{"id": "silent", "name": "沉默猎手", "color": Color(0.2, 0.7, 0.3), "hp": 60},
		{"id": "bloodfiend", "name": "嗜血狂魔", "color": Color(0.7, 0.1, 0.2), "hp": 65},
		{"id": "fire_mage", "name": "火法师", "color": Color(0.9, 0.4, 0.1), "hp": 60},
		{"id": "forger", "name": "铸造者", "color": Color(0.7, 0.5, 0.2), "hp": 75},
	]

	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.03)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(bg)

	# State
	var state := {"h1": "", "h2": "", "pick_count": 0}
	var hero_containers: Array = []  # [{container, id, name_lbl, sprite_rect}]

	# --- Mode toggle (单英雄 / 双英雄) ---
	var mode_btn := Button.new()
	mode_btn.text = "双英雄模式" if not _solo_mode else "单英雄模式"
	mode_btn.custom_minimum_size = Vector2(180, 40)
	mode_btn.add_theme_font_size_override("font_size", 22)
	var mode_style := StyleBoxFlat.new()
	mode_style.bg_color = Color(0.2, 0.2, 0.3, 0.7)
	mode_style.border_color = Color(0.5, 0.5, 0.6)
	mode_style.set_border_width_all(1)
	mode_style.set_corner_radius_all(8)
	mode_btn.add_theme_stylebox_override("normal", mode_style)
	mode_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	mode_btn.position = Vector2(vw - 210, 25)
	mode_btn.pressed.connect(func():
		_solo_mode = not _solo_mode
		_show_hero_select()  # Rebuild UI with new mode
	)
	_overlay.add_child(mode_btn)

	# --- Title ---
	var title := Label.new()
	title.text = "选择一位英雄" if _solo_mode else "选择两位英雄"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 30)
	title.size = Vector2(vw, 50)
	_overlay.add_child(title)

	# --- Hero sprites standing on ground ---
	var sprite_h: float = 440.0  # Same as battle height
	var sprite_w: float = 220.0
	var gap: float = 40.0
	var total_w: float = heroes.size() * sprite_w + (heroes.size() - 1) * gap
	var start_x: float = (vw - total_w) / 2.0
	var ground_y: float = 580.0  # Where heroes' feet touch
	var sprite_y: float = ground_y - sprite_h

	# Ground line
	var ground := ColorRect.new()
	ground.color = Color(0.18, 0.15, 0.12, 1.0)
	ground.position = Vector2(0, ground_y)
	ground.size = Vector2(vw, 4)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(ground)

	for i in range(heroes.size()):
		var hero: Dictionary = heroes[i]
		var color: Color = hero["color"]
		var container := Control.new()
		container.position = Vector2(start_x + i * (sprite_w + gap), sprite_y)
		container.size = Vector2(sprite_w, sprite_h + 80)
		container.mouse_filter = Control.MOUSE_FILTER_STOP
		_overlay.add_child(container)

		# Sprite (no frame, just the character)
		var sprite_path: String = gm.character_data[hero["id"]]["sprite"]
		var sprite_rect := TextureRect.new()
		if ResourceLoader.exists(sprite_path):
			sprite_rect.texture = load(sprite_path)
		sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite_rect.size = Vector2(sprite_w, sprite_h)
		sprite_rect.position = Vector2.ZERO
		sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(sprite_rect)

		# Name label below feet
		var name_lbl := Label.new()
		name_lbl.text = hero["name"]
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.add_theme_color_override("font_color", color)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.position = Vector2(0, sprite_h + 10)
		name_lbl.size = Vector2(sprite_w, 30)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(name_lbl)

		# HP label
		var hp_lbl := Label.new()
		hp_lbl.text = "HP: %d" % hero["hp"]
		hp_lbl.add_theme_font_size_override("font_size", 18)
		hp_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_lbl.position = Vector2(0, sprite_h + 38)
		hp_lbl.size = Vector2(sprite_w, 25)
		hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(hp_lbl)

		# Hover: brighten sprite
		container.mouse_entered.connect(func():
			if container.modulate.r > 0.4:
				container.modulate = Color(1.2, 1.2, 1.2)
		)
		container.mouse_exited.connect(func():
			if container.modulate.r > 0.4:
				container.modulate = Color(1, 1, 1)
		)

		hero_containers.append({"container": container, "id": hero["id"], "sprite_rect": sprite_rect, "color": color, "sprite_path": sprite_path})

	# --- Bottom bar: [slot1] [slot2] [start_btn] [back_btn] ---
	var bar_y: float = ground_y + 50
	var slot_size: float = 80.0
	var btn_h: float = 65.0
	var bar_gap: float = 16.0

	# Slot 1 frame
	var slot1 := Control.new()
	slot1.size = Vector2(slot_size, slot_size)
	slot1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(slot1)

	var slot1_bg := ColorRect.new()
	slot1_bg.color = Color(0.15, 0.15, 0.15, 0.8)
	slot1_bg.size = Vector2(slot_size, slot_size)
	slot1_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot1.add_child(slot1_bg)

	var slot1_border := ReferenceRect.new()
	slot1_border.size = Vector2(slot_size, slot_size)
	slot1_border.border_color = Color(0.5, 0.5, 0.5)
	slot1_border.border_width = 2.0
	slot1_border.editor_only = false
	slot1_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot1.add_child(slot1_border)

	var slot1_label := Label.new()
	slot1_label.text = "英雄1"
	slot1_label.add_theme_font_size_override("font_size", 14)
	slot1_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	slot1_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot1_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot1_label.size = Vector2(slot_size, slot_size)
	slot1_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot1.add_child(slot1_label)

	var slot1_sprite := TextureRect.new()
	slot1_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot1_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot1_sprite.size = Vector2(slot_size - 8, slot_size - 8)
	slot1_sprite.position = Vector2(4, 4)
	slot1_sprite.visible = false
	slot1_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot1.add_child(slot1_sprite)

	# Slot 2 frame (hidden in solo mode)
	var slot2 := Control.new()
	slot2.size = Vector2(slot_size, slot_size)
	slot2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot2.visible = not _solo_mode
	_overlay.add_child(slot2)

	var slot2_bg := ColorRect.new()
	slot2_bg.color = Color(0.15, 0.15, 0.15, 0.8)
	slot2_bg.size = Vector2(slot_size, slot_size)
	slot2_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot2.add_child(slot2_bg)

	var slot2_border := ReferenceRect.new()
	slot2_border.size = Vector2(slot_size, slot_size)
	slot2_border.border_color = Color(0.5, 0.5, 0.5)
	slot2_border.border_width = 2.0
	slot2_border.editor_only = false
	slot2_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot2.add_child(slot2_border)

	var slot2_label := Label.new()
	slot2_label.text = "英雄2"
	slot2_label.add_theme_font_size_override("font_size", 14)
	slot2_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	slot2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot2_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot2_label.size = Vector2(slot_size, slot_size)
	slot2_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot2.add_child(slot2_label)

	var slot2_sprite := TextureRect.new()
	slot2_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot2_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot2_sprite.size = Vector2(slot_size - 8, slot_size - 8)
	slot2_sprite.position = Vector2(4, 4)
	slot2_sprite.visible = false
	slot2_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot2.add_child(slot2_sprite)

	# Start button
	var start_btn := Button.new()
	start_btn.text = "开始爬塔"
	start_btn.custom_minimum_size = Vector2(240, btn_h)
	start_btn.add_theme_font_size_override("font_size", 28)
	start_btn.disabled = true
	var dis_style := StyleBoxFlat.new()
	dis_style.bg_color = Color(0.25, 0.25, 0.25, 0.6)
	dis_style.border_color = Color(0.4, 0.4, 0.4)
	dis_style.set_border_width_all(2)
	dis_style.set_corner_radius_all(10)
	start_btn.add_theme_stylebox_override("normal", dis_style)
	start_btn.add_theme_stylebox_override("disabled", dis_style)
	start_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	start_btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
	start_btn.pressed.connect(func():
		if state["h1"] == "":
			return
		if not _solo_mode and state["h2"] == "":
			return
		_begin_run_after_select(state["h1"], state["h2"])
	)
	_overlay.add_child(start_btn)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.custom_minimum_size = Vector2(100, btn_h)
	back_btn.add_theme_font_size_override("font_size", 22)
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	back_style.border_color = Color(0.4, 0.4, 0.4)
	back_style.set_border_width_all(1)
	back_style.set_corner_radius_all(8)
	back_btn.add_theme_stylebox_override("normal", back_style)
	back_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	_overlay.add_child(back_btn)

	# Layout bottom bar centered
	var bar_items_w: float
	var slot_y_offset: float = (btn_h - slot_size) / 2.0
	if _solo_mode:
		bar_items_w = slot_size + bar_gap + 240 + bar_gap + 100
	else:
		bar_items_w = slot_size + bar_gap + slot_size + bar_gap + 240 + bar_gap + 100
	var bar_x: float = (vw - bar_items_w) / 2.0
	slot1.position = Vector2(bar_x, bar_y + slot_y_offset)
	if _solo_mode:
		start_btn.position = Vector2(bar_x + slot_size + bar_gap, bar_y)
		back_btn.position = Vector2(bar_x + slot_size + bar_gap + 240 + bar_gap, bar_y)
	else:
		slot2.position = Vector2(bar_x + slot_size + bar_gap, bar_y + slot_y_offset)
		start_btn.position = Vector2(bar_x + 2 * (slot_size + bar_gap), bar_y)
		back_btn.position = Vector2(bar_x + 2 * (slot_size + bar_gap) + 240 + bar_gap, bar_y)

	# --- Wire up hero clicks ---
	for entry in hero_containers:
		var hero_id: String = entry["id"]
		var container: Control = entry["container"]
		var color: Color = entry["color"]
		var sprite_path: String = entry["sprite_path"]
		container.gui_input.connect(func(event: InputEvent):
			if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
				return
			if container.modulate.r < 0.4:
				return  # already grayed out
			var max_picks: int = 1 if _solo_mode else 2
			if state["pick_count"] >= max_picks:
				return
			state["pick_count"] += 1
			if state["pick_count"] == 1:
				state["h1"] = hero_id
				# Fill slot 1
				if ResourceLoader.exists(sprite_path):
					slot1_sprite.texture = load(sprite_path)
				slot1_sprite.visible = true
				slot1_label.visible = false
				slot1_border.border_color = color
				slot1_bg.color = Color(color.r, color.g, color.b, 0.2)
			elif state["pick_count"] == 2:
				state["h2"] = hero_id
				# Fill slot 2
				if ResourceLoader.exists(sprite_path):
					slot2_sprite.texture = load(sprite_path)
				slot2_sprite.visible = true
				slot2_label.visible = false
				slot2_border.border_color = color
				slot2_bg.color = Color(color.r, color.g, color.b, 0.2)
			# Enable start button when enough heroes are picked
			if state["pick_count"] >= max_picks:
				start_btn.disabled = false
				var green_style := StyleBoxFlat.new()
				green_style.bg_color = Color(0.1, 0.5, 0.15, 0.7)
				green_style.border_color = Color(0.2, 0.8, 0.3)
				green_style.set_border_width_all(3)
				green_style.set_corner_radius_all(10)
				start_btn.add_theme_stylebox_override("normal", green_style)
				var hover_green := green_style.duplicate() as StyleBoxFlat
				hover_green.bg_color = Color(0.15, 0.6, 0.2, 0.85)
				start_btn.add_theme_stylebox_override("hover", hover_green)
				start_btn.add_theme_color_override("font_color", Color.WHITE)
			# Gray out selected hero in center
			container.modulate = Color(0.3, 0.3, 0.3)
		)

func _begin_run_after_select(h1: String, h2: String) -> void:
	if _solo_mode:
		h2 = ""
	if run:
		run.solo_mode = _solo_mode
		run.start_run(h1, h2)
	if gm:
		gm.select_character(h1)
	var h1id: String = run.hero1_id if run else h1
	if _solo_mode:
		_draft_total_rounds = 4
		_draft_hero_order = [h1id, h1id, h1id, h1id]
	else:
		var h2id: String = run.hero2_id if run else h2
		_draft_total_rounds = 6
		_draft_hero_order = [h1id, h2id, h1id, h2id, h1id, h2id]
	_draft_round = 0
	# Update HUD with actual hero names/HP
	_update_hud_labels()
	# Transition to draft
	_show_draft()
	if _persistent_hud_canvas:
		_persistent_hud_canvas.visible = true

func _show_draft() -> void:
	_draft_round += 1
	phase = Phase.DRAFT
	_map_layer.visible = false
	_overlay.visible = true
	_clear_children(_overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.03, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.offset_top = 55  # Below persistent HUD
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(bg)

	var hero_id: String = _draft_hero_order[_draft_round - 1]
	var hero_color: Color = _hero_color(hero_id)

	# Use persistent HUD deck button as card fly target
	# Update the deck button text for draft phase
	if _hud_deck_btn:
		_hud_deck_btn.text = "卡组 (%d)" % run.deck.size()
	_draft_card_count_label = _hud_deck_btn

	# === Round dots ===
	var vw: float = get_viewport_rect().size.x
	_draft_status_bar = HBoxContainer.new()
	_draft_status_bar.add_theme_constant_override("separation", 12)
	_draft_status_bar.position = Vector2(0, 85)
	_draft_status_bar.size = Vector2(vw, 30)
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
	title.size = Vector2(vw, 50)
	_overlay.add_child(title)

	# === 3 card options (battle-style visuals, ~2x area) ===
	var cards := _random_cards_for_hero(hero_id, 3)
	var card_w: float = 400.0
	var card_h: float = 560.0
	var gap: float = 50.0
	var total_w: float = cards.size() * card_w + (cards.size() - 1) * gap
	var start_x: float = (vw - total_w) / 2.0
	var card_y: float = 170.0
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

	# No skip button during draft — player must pick a card each round

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
		_draft_card_count_label.text = "卡组 (%d)" % run.deck.size()

	# Fly animation: card flies to "My Cards" button (top-right corner)
	var vw: float = get_viewport_rect().size.x
	var target_pos := Vector2(vw - 120.0, 10.0)
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
	var vw: float = get_viewport_rect().size.x
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
	vtitle.size = Vector2(vw, 50)
	viewer.add_child(vtitle)

	if _draft_picked_cards.is_empty():
		var empty_label := Label.new()
		empty_label.text = "还没有选择卡牌"
		empty_label.add_theme_font_size_override("font_size", 24)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.position = Vector2(0, 400)
		empty_label.size = Vector2(vw, 50)
		viewer.add_child(empty_label)
	else:
		var loc = get_node_or_null("/root/Loc")
		var card_w: float = 200.0
		var card_h: float = 280.0
		var gap: float = 20.0
		var cols: int = mini(_draft_picked_cards.size(), 5)
		var total_w: float = cols * card_w + (cols - 1) * gap
		var sx: float = (vw - total_w) / 2.0
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
	close_btn.position = Vector2((vw - 160.0) / 2.0, 1080.0 - 80.0)
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
var _hud_backpack_btn: Button = null
var _hud_map_btn: Button = null
var _backpack_uses_in_battle: int = 0  # 1 at battle start, 0 after use

func _show_map() -> void:
	phase = Phase.MAP
	_map_layer.visible = true
	_overlay.visible = false
	if _main_bg:
		_main_bg.visible = true
	if _persistent_hud_canvas:
		_persistent_hud_canvas.visible = true
	if _battle_instance:
		_battle_instance.queue_free()
		_battle_instance = null
	_clear_children(_map_layer)
	_draw_map()

func _update_hud_labels() -> void:
	if _hud_gold_label:
		_hud_gold_label.text = "$ %d" % run.gold
	if _hud_hp1_label:
		_hud_hp1_label.text = "♥ %s %d/%d" % [_hero_name(run.hero1_id), run.hero1_hp, run.hero1_max_hp]
	if _hud_hp2_label:
		if _solo_mode:
			_hud_hp2_label.visible = false
		else:
			_hud_hp2_label.visible = true
			_hud_hp2_label.text = "♥ %s %d/%d" % [_hero_name(run.hero2_id), run.hero2_hp, run.hero2_max_hp]
	_update_backpack_btn_text()

func _draw_map() -> void:
	# Update persistent HUD for map phase
	_update_hud_labels()
	if _hud_floor_label:
		_hud_floor_label.text = "第 %d 层" % run.floor_num if run.floor_num > 0 else "选择起点"
	if _hud_deck_btn:
		_hud_deck_btn.text = "卡组 (%d)" % run.deck.size()

	# Scrollable map area (below persistent HUD)
	var vw: float = get_viewport_rect().size.x
	_map_scroll = ScrollContainer.new()
	_map_scroll.offset_top = 55
	_map_scroll.offset_right = vw
	_map_scroll.offset_bottom = 1080
	_map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_map_layer.add_child(_map_scroll)

	# Map canvas — draw nodes and paths
	var node_size := 80
	var floor_height := 120
	var map_width := int(vw)
	var total_height: int = 11 * floor_height + 100
	_map_canvas = Control.new()
	_map_canvas.custom_minimum_size = Vector2(map_width, total_height)
	_map_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
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

func _create_path_line(from: Vector2, to: Vector2, from_key: String, to_key: String) -> Control:
	var container := Control.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var visited_from: bool = from_key in run.visited
	var visited_to: bool = to_key in run.visited
	var is_available_path: bool = visited_from and to_key in run.available_nodes
	# Glow line behind main line for available paths
	if is_available_path:
		var glow := Line2D.new()
		glow.add_point(from)
		glow.add_point(to)
		glow.width = 8.0
		glow.default_color = Color(0.9, 0.75, 0.3, 0.25)
		container.add_child(glow)
	# Main path line
	var line := Line2D.new()
	line.add_point(from)
	line.add_point(to)
	if visited_from and visited_to:
		line.width = 3.5
		line.default_color = Color(0.55, 0.45, 0.28, 0.75)
	elif is_available_path:
		line.width = 4.0
		line.default_color = Color(0.9, 0.78, 0.35, 0.9)
	else:
		line.width = 2.5
		line.default_color = Color(0.25, 0.2, 0.15, 0.4)
	container.add_child(line)
	return container

func _create_map_node(key: String, nd: Dictionary, pos: Vector2, size: int) -> Button:
	var btn := Button.new()
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.custom_minimum_size = Vector2(size, size)
	btn.offset_left = pos.x - size / 2
	btn.offset_top = pos.y - size / 2
	btn.offset_right = pos.x + size / 2
	btn.offset_bottom = pos.y + size / 2

	# Icon based on type
	var icon_path := ""
	var node_color := Color.WHITE
	match nd["type"]:
		"M":
			icon_path = "res://assets/img/ui_icons/map_battle.png"
			node_color = Color(0.85, 0.28, 0.18)
		"R":
			icon_path = "res://assets/img/ui_icons/map_rest.png"
			node_color = Color(0.25, 0.7, 0.3)
		"S":
			icon_path = "res://assets/img/ui_icons/map_shop.png"
			node_color = Color(0.85, 0.75, 0.2)
		"B":
			icon_path = "res://assets/img/ui_icons/map_boss.png"
			node_color = Color(0.75, 0.12, 0.12)

	if icon_path != "" and ResourceLoader.exists(icon_path):
		btn.icon = load(icon_path)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.expand_icon = true
	btn.text = ""

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
		style.bg_color = Color(node_color.r, node_color.g, node_color.b, 0.65)
		style.border_color = Color(1.0, 1.0, 1.0, 0.9)
		style.set_border_width_all(3)
		style.shadow_color = Color(node_color.r, node_color.g, node_color.b, 0.4)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 0)
	elif is_available:
		style.bg_color = Color(node_color.r, node_color.g, node_color.b, 0.45)
		style.border_color = Color(0.95, 0.82, 0.35)
		style.set_border_width_all(2)
		style.shadow_color = Color(0.9, 0.75, 0.2, 0.3)
		style.shadow_size = 6
		style.shadow_offset = Vector2(0, 0)
	elif is_visited:
		style.bg_color = Color(0.18, 0.16, 0.14, 0.55)
		style.border_color = Color(0.4, 0.35, 0.3, 0.6)
		style.set_border_width_all(1)
	else:
		style.bg_color = Color(0.12, 0.1, 0.08, 0.65)
		style.border_color = Color(0.28, 0.22, 0.16, 0.5)
		style.set_border_width_all(1)

	btn.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate() as StyleBoxFlat
	if is_available:
		hover_style.bg_color = Color(node_color.r, node_color.g, node_color.b, 0.65)
		hover_style.border_color = Color(1.0, 0.9, 0.5)
		hover_style.shadow_size = 10
	btn.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := hover_style.duplicate() as StyleBoxFlat
	if is_available:
		pressed_style.bg_color = Color(node_color.r * 0.7, node_color.g * 0.7, node_color.b * 0.7, 0.7)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.disabled = not is_available
	if is_available:
		btn.pressed.connect(_on_node_pressed.bind(key))

	# Floor label below node
	var fl_label := Label.new()
	fl_label.text = "F%d" % nd["floor"]
	fl_label.add_theme_font_size_override("font_size", 13)
	fl_label.add_theme_color_override("font_color", Color(0.55, 0.48, 0.38, 0.6))
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
	_overlay.visible = false  # Hide any overlay from previous phase
	_clear_children(_overlay)
	if _main_bg:
		_main_bg.visible = false  # Hide so battle's own background shows
	# Keep persistent HUD visible during battle — unified status bar across all phases

	# Load battle scene
	var battle_scene := load("res://scenes/battle.tscn")
	_battle_instance = battle_scene.instantiate()
	add_child(_battle_instance)

	# Configure battle
	var bm: Node2D = _battle_instance
	bm.dual_hero_mode = not _solo_mode
	bm.second_character_id = run.hero2_id if not _solo_mode else ""
	bm.config_player_hp = run.hero1_hp
	bm.config_player_max_hp = run.hero1_max_hp
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

	# Set backpack uses for this battle
	_backpack_uses_in_battle = 1
	_update_backpack_btn_text()

	# Set deck from run (exclude backpack cards — handle duplicate IDs)
	if gm:
		var bp_remaining: Array = run.backpack.duplicate()
		var battle_deck: Array = []
		for cid in run.deck:
			var bp_idx := bp_remaining.find(cid)
			if bp_idx >= 0:
				bp_remaining.remove_at(bp_idx)  # skip this copy
			else:
				battle_deck.append(cid)
		gm.player_deck = battle_deck
		gm.select_character(run.hero1_id)

	# Configure second hero HP (skip in solo mode)
	if not _solo_mode:
		bm.set_meta("standard_hero2_hp", run.hero2_hp)
		bm.set_meta("standard_hero2_max_hp", run.hero2_max_hp)

	# Connect signals
	bm.battle_won.connect(_on_battle_won)
	bm.player_died.connect(_on_battle_lost)

	# Start battle
	bm.start_battle(run.hero1_id)

	# Connect battle entity HP signals to update persistent HUD in real-time
	# Use signal params directly (not bm.player/second_player refs which swap)
	if bm.player:
		bm.player.hp_changed.connect(func(cur: int, max_val: int):
			if _hud_hp1_label:
				_hud_hp1_label.text = "♥ %s %d/%d" % [_hero_name(run.hero1_id), cur, max_val]
		)
	if bm.second_player:
		bm.second_player.hp_changed.connect(func(cur: int, max_val: int):
			if _hud_hp2_label:
				_hud_hp2_label.text = "♥ %s %d/%d" % [_hero_name(run.hero2_id), cur, max_val]
		)

func _on_battle_won() -> void:
	# Save HP back to run state; revive dead hero with 1 HP
	# player/second_player may have been swapped during battle,
	# so match by character ID to save to the correct hero slot.
	if _battle_instance:
		var bm: Node2D = _battle_instance
		var heroes: Array = []
		if bm.player:
			heroes.append({"node": bm.player, "char_id": bm._player_character_id})
		if bm.second_player:
			heroes.append({"node": bm.second_player, "char_id": bm._second_character_id})
		for h in heroes:
			var hp: int = h["node"].current_hp if h["node"].alive else 1
			if h["char_id"] == run.hero1_id:
				run.hero1_hp = hp
			elif h["char_id"] == run.hero2_id:
				run.hero2_hp = hp

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
	if _persistent_hud_canvas:
		_persistent_hud_canvas.visible = true
	_update_hud_labels()
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
	var vw: float = get_viewport_rect().size.x
	banner.position = Vector2((vw - 600) / 2.0, 100)
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
	_reward_dialog.position = Vector2((vw - 450) / 2.0, 180)
	_reward_dialog.size = Vector2(450, 450)
	_overlay.add_child(_reward_dialog)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_reward_dialog.add_child(vbox)

	# Gold reward row
	_reward_btn_gold = _reward_row("$", "%d 金币" % _reward_gold_amount, Color(0.9, 0.8, 0.3))
	_reward_btn_gold.pressed.connect(_on_reward_gold_clicked)
	vbox.add_child(_reward_btn_gold)

	# Hero 1 card reward row
	_reward_btn_h1 = _reward_row("[卡]", "%s 卡牌" % _hero_name(run.hero1_id), _hero_color(run.hero1_id))
	_reward_btn_h1.pressed.connect(_on_reward_h1_clicked)
	vbox.add_child(_reward_btn_h1)

	# Hero 2 card reward row (hidden in solo mode)
	_reward_btn_h2 = _reward_row("[卡]", "%s 卡牌" % _hero_name(run.hero2_id), _hero_color(run.hero2_id))
	_reward_btn_h2.pressed.connect(_on_reward_h2_clicked)
	vbox.add_child(_reward_btn_h2)
	if _solo_mode:
		_reward_btn_h2.visible = false
		_reward_h2_collected = true

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
	_reward_skip_btn.position = Vector2(vw - 220, 680)
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
	btn.custom_minimum_size = Vector2(400, 52)
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
	_reward_btn_gold.text = "  $   已获取 %d 金币 (总计: %d)" % [_reward_gold_amount, run.gold]
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
	var vw: float = get_viewport_rect().size.x
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
	pick_title.size = Vector2(vw, 50)
	_reward_card_overlay.add_child(pick_title)

	# 3 random cards
	var cards := _random_cards_for_hero(hero_id, 3)
	var card_w: float = 400.0
	var card_h: float = 560.0
	var gap: float = 50.0
	var total_w: float = cards.size() * card_w + (cards.size() - 1) * gap
	var start_x: float = (vw - total_w) / 2.0
	var card_y: float = 170.0
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
	skip_btn.position = Vector2((vw - 180.0) / 2.0, card_y + card_h + 40.0)
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
	return gm.get_random_cards_for_hero(hero_id, count)

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
	if _solo_mode:
		hp_info.text = "%s: %d/%d HP" % [
			_hero_name(run.hero1_id), run.hero1_hp, run.hero1_max_hp]
	else:
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
	var heal2: int = int(run.hero2_max_hp * 0.3) if not _solo_mode else 0
	var rest_text: String
	if _solo_mode:
		rest_text = "休息 — 恢复30%%最大生命\n(%s +%d)" % [_hero_name(run.hero1_id), heal1]
	else:
		rest_text = "休息 — 恢复30%%最大生命\n(%s +%d, %s +%d)" % [
			_hero_name(run.hero1_id), heal1, _hero_name(run.hero2_id), heal2]
	var rest_btn := _styled_button(rest_text, Color(0.3, 0.8, 0.3))
	rest_btn.custom_minimum_size = Vector2(500, 80)
	rest_btn.pressed.connect(func():
		run.heal_hero(0, heal1)
		if not _solo_mode:
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
	var vw: float = get_viewport_rect().size.x
	_clear_children(_overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.03, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(bg)

	var title := Label.new()
	title.text = "选择一张卡牌升级"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.3, 0.5, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.offset_top = 60
	title.offset_right = vw
	_overlay.add_child(title)

	# Card grid with full card visuals
	var loc = get_node_or_null("/root/Loc")
	var card_w: float = 280.0
	var card_h: float = 400.0

	var upgradeable_cards: Array = []
	for card_id in run.deck:
		if card_id.ends_with("+"):
			continue
		if not gm.card_database.has(card_id):
			continue
		if not gm._upgrade_overrides_cache.has(card_id):
			continue
		upgradeable_cards.append(card_id)

	# Scrollable card area
	var scroll := ScrollContainer.new()
	scroll.offset_top = 105
	scroll.offset_right = vw
	scroll.offset_bottom = 980
	_overlay.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scroll.add_child(grid)

	for card_id in upgradeable_cards:
		var cd: Dictionary = gm.card_database[card_id]
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(card_w, card_h)
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		slot.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_show_upgrade_detail(card_id)
		)
		grid.add_child(slot)
		var visual := CardScript.create_card_visual(cd, Vector2(card_w, card_h), loc)
		slot.add_child(visual)
		slot.mouse_entered.connect(func(): slot.modulate = Color(1.2, 1.2, 1.2))
		slot.mouse_exited.connect(func(): slot.modulate = Color(1, 1, 1))

	# Cancel button
	var cancel := Button.new()
	cancel.text = "返回"
	cancel.custom_minimum_size = Vector2(160, 50)
	cancel.add_theme_font_size_override("font_size", 24)
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.3, 0.3, 0.3, 0.7)
	cancel_style.set_corner_radius_all(8)
	cancel.add_theme_stylebox_override("normal", cancel_style)
	cancel.position = Vector2((vw - 160.0) / 2.0, 990.0)
	cancel.pressed.connect(_show_rest)
	_overlay.add_child(cancel)

func _show_upgrade_detail(card_id: String) -> void:
	"""Show upgrade detail: before/after with confirm/cancel."""
	# Use _deck_viewer_canvas (layer 15) to guarantee coverage over overlay (layer 10)
	if _deck_viewer_canvas == null:
		return
	var old_detail = _deck_viewer_canvas.get_node_or_null("UpgradeDetailPanel")
	if old_detail:
		old_detail.queue_free()

	var vw: float = get_viewport_rect().size.x
	var detail := Control.new()
	detail.name = "UpgradeDetailPanel"
	detail.offset_right = vw
	detail.offset_bottom = 1080
	detail.mouse_filter = Control.MOUSE_FILTER_STOP
	_deck_viewer_canvas.add_child(detail)

	var dbg := ColorRect.new()
	dbg.color = Color(0.05, 0.04, 0.03, 1.0)
	dbg.offset_right = vw
	dbg.offset_bottom = 1080
	dbg.mouse_filter = Control.MOUSE_FILTER_STOP
	detail.add_child(dbg)

	var loc = get_node_or_null("/root/Loc")
	var cd: Dictionary = gm.card_database[card_id]
	var upgraded_cd: Dictionary = gm.get_upgraded_card(card_id)

	# Before card (left)
	var before_label := Label.new()
	before_label.text = "当前"
	before_label.add_theme_font_size_override("font_size", 24)
	before_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	before_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	before_label.position = Vector2(480, 120)
	before_label.size = Vector2(280, 30)
	detail.add_child(before_label)

	var before_card := Control.new()
	before_card.position = Vector2(480, 160)
	before_card.size = Vector2(280, 400)
	detail.add_child(before_card)
	before_card.add_child(CardScript.create_card_visual(cd, Vector2(280, 400), loc))

	# Arrow
	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_font_size_override("font_size", 60)
	arrow.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	arrow.position = Vector2(910, 300)
	detail.add_child(arrow)

	# After card (right, upgraded)
	var after_label := Label.new()
	after_label.text = "升级后"
	after_label.add_theme_font_size_override("font_size", 24)
	after_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	after_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	after_label.position = Vector2(1100, 120)
	after_label.size = Vector2(280, 30)
	detail.add_child(after_label)

	var after_card := Control.new()
	after_card.position = Vector2(1100, 160)
	after_card.size = Vector2(280, 400)
	detail.add_child(after_card)
	var display_cd: Dictionary = upgraded_cd if not upgraded_cd.is_empty() else cd
	after_card.add_child(CardScript.create_card_visual(display_cd, Vector2(280, 400), loc))

	# Confirm button
	var btn_w: float = 200.0
	var confirm := Button.new()
	confirm.text = "确认"
	confirm.custom_minimum_size = Vector2(btn_w, 56)
	confirm.add_theme_font_size_override("font_size", 26)
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.15, 0.5, 0.15, 0.9)
	confirm_style.set_corner_radius_all(8)
	confirm.add_theme_stylebox_override("normal", confirm_style)
	var confirm_hover := confirm_style.duplicate() as StyleBoxFlat
	confirm_hover.bg_color = Color(0.2, 0.65, 0.2, 0.95)
	confirm.add_theme_stylebox_override("hover", confirm_hover)
	confirm.position = Vector2(760, 620)
	confirm.pressed.connect(func():
		_upgrade_card(card_id)
		detail.queue_free()
	)
	detail.add_child(confirm)

	# Back button
	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(btn_w, 56)
	back.add_theme_font_size_override("font_size", 26)
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.3, 0.3, 0.3, 0.7)
	back_style.set_corner_radius_all(8)
	back.add_theme_stylebox_override("normal", back_style)
	back.position = Vector2(760 + btn_w + 20, 620)
	back.pressed.connect(func(): detail.queue_free())
	detail.add_child(back)

# ═══════════════════════════════════════════════════════════════════════════
# SHOP
# ═══════════════════════════════════════════════════════════════════════════

func _show_shop() -> void:
	var vw: float = get_viewport_rect().size.x
	phase = Phase.SHOP
	_map_layer.visible = false
	_overlay.visible = true
	_clear_children(_overlay)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(bg)

	var title := Label.new()
	title.text = "$ 商店"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.offset_top = 60
	title.offset_right = vw
	_overlay.add_child(title)

	var gold_label := Label.new()
	gold_label.text = "金币: %d" % run.gold
	gold_label.name = "ShopGold"
	gold_label.add_theme_font_size_override("font_size", 28)
	gold_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.offset_top = 115
	gold_label.offset_right = vw
	_overlay.add_child(gold_label)

	# Generate shop cards: 10 per hero, rarity-weighted + 20% upgrade chance
	var shop_cards: Array = []
	var shop_hero_ids: Array = [run.hero1_id] if _solo_mode else [run.hero1_id, run.hero2_id]
	for hero_id in shop_hero_ids:
		var hero_shop: Array = gm.get_random_cards_for_hero(hero_id, 10)
		for card in hero_shop:
			card["_shop_upgraded"] = card.get("upgraded", false)
			card["_shop_price"] = _card_price(card)
			shop_cards.append(card)

	# Scrollable grid
	var scroll := ScrollContainer.new()
	scroll.name = "ShopScroll"
	scroll.offset_top = 155
	scroll.offset_right = vw
	scroll.offset_bottom = 1020
	_overlay.add_child(scroll)

	var loc = get_node_or_null("/root/Loc")
	var card_w: float = 364.0  # 280 * 1.3
	var card_h: float = 520.0  # 400 * 1.3
	var cols: int = 5
	var h_sep: float = 16.0
	var grid_total_w: float = cols * card_w + (cols - 1) * h_sep
	var grid_margin: float = maxf((vw - grid_total_w) / 2.0, 10.0)

	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", int(h_sep))
	grid.add_theme_constant_override("v_separation", 20)
	grid.offset_left = grid_margin
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scroll.add_child(grid)

	for card in shop_cards:
		var card_id: String = card["id"]
		var price: int = card["_shop_price"]
		var is_upgraded: bool = card.get("_shop_upgraded", false)
		var display_cd: Dictionary = card
		if is_upgraded:
			var upg: Dictionary = gm.get_upgraded_card(card_id)
			if not upg.is_empty():
				display_cd = upg

		var slot := Control.new()
		slot.custom_minimum_size = Vector2(card_w, card_h + 30)
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(slot)

		var container := Control.new()
		container.position = Vector2(0, 0)
		container.size = Vector2(card_w, card_h)
		container.mouse_filter = Control.MOUSE_FILTER_PASS
		var add_id: String = card_id + "+" if is_upgraded else card_id
		container.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if run.gold >= price:
					_show_shop_buy_detail(display_cd, price, add_id, slot)
		)
		slot.add_child(container)
		var visual := CardScript.create_card_visual(display_cd, Vector2(card_w, card_h), loc)
		container.add_child(visual)
		container.mouse_entered.connect(func(): container.modulate = Color(1.2, 1.2, 1.2))
		container.mouse_exited.connect(func(): container.modulate = Color(1, 1, 1))

		# Price tag below card
		var price_label := Label.new()
		price_label.name = "PriceLabel"
		price_label.text = "$ %d" % price
		price_label.set_meta("price", price)
		price_label.add_theme_font_size_override("font_size", 18)
		price_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2) if run.gold >= price else Color(0.9, 0.2, 0.2))
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.position = Vector2(0, card_h + 4)
		price_label.size = Vector2(card_w, 24)
		slot.add_child(price_label)

	# Leave button — bottom-right corner
	var leave := _styled_button("离开商店", Color(0.5, 0.5, 0.5))
	leave.custom_minimum_size = Vector2(180, 50)
	leave.offset_left = vw - 180 - 20
	leave.offset_top = 1080 - 50 - 20
	leave.offset_right = vw - 20
	leave.offset_bottom = 1080 - 20
	leave.pressed.connect(_show_map)
	_overlay.add_child(leave)

func _show_shop_buy_detail(card_data: Dictionary, price: int, add_id: String, slot: Control) -> void:
	# Render on DeckViewerCanvas (layer 15) to cover shop panel (overlay layer 10)
	if _deck_viewer_canvas == null:
		return
	var old_detail = _deck_viewer_canvas.get_node_or_null("ShopBuyDetail")
	if old_detail:
		old_detail.queue_free()

	var vw: float = get_viewport_rect().size.x
	var detail := Control.new()
	detail.name = "ShopBuyDetail"
	detail.offset_right = vw
	detail.offset_bottom = 1080
	detail.mouse_filter = Control.MOUSE_FILTER_STOP
	_deck_viewer_canvas.add_child(detail)

	var dbg := ColorRect.new()
	dbg.color = Color(0.05, 0.04, 0.03, 1.0)
	dbg.offset_right = vw
	dbg.offset_bottom = 1080
	dbg.mouse_filter = Control.MOUSE_FILTER_STOP
	detail.add_child(dbg)

	var loc = get_node_or_null("/root/Loc")

	# Large card preview (centered)
	var big_card := Control.new()
	big_card.position = Vector2(720, 100)
	big_card.size = Vector2(320, 450)
	detail.add_child(big_card)
	big_card.add_child(CardScript.create_card_visual(card_data, Vector2(320, 450), loc))

	# Buy button
	var shop_btn_w: float = 180.0
	var buy_btn := Button.new()
	buy_btn.text = "确认" if run.gold >= price else "金币不足"
	buy_btn.disabled = run.gold < price
	buy_btn.custom_minimum_size = Vector2(shop_btn_w, 56)
	buy_btn.add_theme_font_size_override("font_size", 26)
	var buy_style := StyleBoxFlat.new()
	buy_style.bg_color = Color(0.15, 0.5, 0.15, 0.9)
	buy_style.set_corner_radius_all(8)
	buy_btn.add_theme_stylebox_override("normal", buy_style)
	var buy_hover := buy_style.duplicate() as StyleBoxFlat
	buy_hover.bg_color = Color(0.2, 0.65, 0.2, 0.95)
	buy_btn.add_theme_stylebox_override("hover", buy_hover)
	buy_btn.position = Vector2(760, 680)
	buy_btn.pressed.connect(func():
		if run.spend_gold(price):
			run.add_card(add_id)
			slot.modulate = Color(0.3, 0.3, 0.3, 0.5)
			for child in slot.get_children():
				if child is Control:
					child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_update_hud_labels()
			_refresh_shop_prices()
		detail.queue_free()
	)
	detail.add_child(buy_btn)

	# Cancel button
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size = Vector2(shop_btn_w, 56)
	cancel.add_theme_font_size_override("font_size", 26)
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.3, 0.3, 0.3, 0.7)
	cancel_style.set_corner_radius_all(8)
	cancel.add_theme_stylebox_override("normal", cancel_style)
	cancel.position = Vector2(760 + shop_btn_w + 20, 680)
	cancel.pressed.connect(func(): detail.queue_free())
	detail.add_child(cancel)

func _card_price(card: Dictionary) -> int:
	var base: int = 50
	match card.get("rarity", "common"):
		"common": base = 50
		"uncommon": base = 75
		"rare": base = 150
	var cost: int = card.get("cost", 1)
	base += cost * 10
	if card.get("_shop_upgraded", false):
		base = int(base * 1.5)
	return base + randi() % 20

func _refresh_shop_prices() -> void:
	## Update shop gold display and all price label colors after a purchase
	var gold_lbl = _overlay.get_node_or_null("ShopGold") as Label
	if gold_lbl:
		gold_lbl.text = "金币: %d" % run.gold
	# Update all price labels — red if unaffordable
	var scroll = _overlay.get_node_or_null("ShopScroll")
	if scroll == null:
		return
	var grid = scroll.get_child(0) if scroll.get_child_count() > 0 else null
	if grid == null:
		return
	for slot in grid.get_children():
		var plbl = slot.get_node_or_null("PriceLabel") as Label
		if plbl and plbl.has_meta("price"):
			var p: int = plbl.get_meta("price")
			plbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2) if run.gold >= p else Color(0.9, 0.2, 0.2))

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
	if _persistent_hud_canvas:
		_persistent_hud_canvas.visible = true
	_update_hud_labels()

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
	if _persistent_hud_canvas:
		_persistent_hud_canvas.visible = true
	_update_hud_labels()

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
	# Render on DeckViewerCanvas (layer 15) — below PersistentHUD (20), above overlay (10)
	if _deck_viewer_canvas == null:
		return
	# Close any existing overlays first
	for panel_name in ["DeckViewerPanel", "BackpackPanel", "MapViewerPanel", "UpgradeDetailPanel", "ShopBuyDetail"]:
		var old = _deck_viewer_canvas.get_node_or_null(panel_name)
		if old:
			old.queue_free()

	var vw: float = get_viewport_rect().size.x
	var viewer := Control.new()
	viewer.name = "DeckViewerPanel"
	viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewer.mouse_filter = Control.MOUSE_FILTER_STOP
	_deck_viewer_canvas.add_child(viewer)

	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(_event: InputEvent): pass)
	viewer.add_child(bg)

	var loc = get_node_or_null("/root/Loc")
	var card_size := Vector2(220, 314)

	# Split: left 75% = deck cards (excluding backpack), right 25% = backpack cards
	var left_w: float = vw * 0.75
	var right_w: float = vw * 0.25

	# Separate deck into non-backpack and backpack cards
	var bp_ids: Array = run.backpack.duplicate()
	var deck_cards: Array = []
	var bp_cards: Array = []
	var bp_remaining: Array = bp_ids.duplicate()
	for card_id in run.deck:
		var idx := bp_remaining.find(card_id)
		if idx >= 0:
			bp_remaining.remove_at(idx)
			bp_cards.append(card_id)
		else:
			deck_cards.append(card_id)

	# Sort both lists
	var sort_fn = func(a, b):
		var cd_a: Dictionary = _get_card_display(a)
		var cd_b: Dictionary = _get_card_display(b)
		if cd_a.get("type", 0) != cd_b.get("type", 0):
			return cd_a.get("type", 0) < cd_b.get("type", 0)
		return cd_a.get("name", "") < cd_b.get("name", "")
	deck_cards.sort_custom(sort_fn)
	bp_cards.sort_custom(sort_fn)

	# === LEFT: Deck cards ===
	var left_title := Label.new()
	left_title.text = "卡组 (%d张)" % deck_cards.size()
	left_title.add_theme_font_size_override("font_size", 30)
	left_title.add_theme_color_override("font_color", Color(1, 1, 0.8))
	left_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_title.position = Vector2(0, 85)
	left_title.size = Vector2(left_w, 40)
	left_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewer.add_child(left_title)

	var left_scroll := ScrollContainer.new()
	left_scroll.position = Vector2(10, 130)
	left_scroll.size = Vector2(left_w - 20, 895)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	viewer.add_child(left_scroll)

	var left_grid := GridContainer.new()
	left_grid.columns = 5
	left_grid.add_theme_constant_override("h_separation", 12)
	left_grid.add_theme_constant_override("v_separation", 12)
	left_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(left_grid)

	for card_id in deck_cards:
		var display_cd: Dictionary = _get_card_display(card_id)
		if not display_cd.is_empty():
			var card_visual := CardScript.create_card_visual(display_cd, card_size, loc)
			card_visual.custom_minimum_size = card_size
			card_visual.mouse_filter = Control.MOUSE_FILTER_STOP
			left_grid.add_child(card_visual)

	# === RIGHT: Backpack cards ===
	# Separator line
	var sep := ColorRect.new()
	sep.color = Color(0.5, 0.5, 0.7, 0.5)
	sep.position = Vector2(left_w, 85)
	sep.size = Vector2(2, 955)
	viewer.add_child(sep)

	var right_title := Label.new()
	right_title.text = "背包 (%d/4)" % bp_cards.size()
	right_title.add_theme_font_size_override("font_size", 28)
	right_title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	right_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_title.position = Vector2(left_w, 85)
	right_title.size = Vector2(right_w, 40)
	right_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewer.add_child(right_title)

	var right_scroll := ScrollContainer.new()
	right_scroll.position = Vector2(left_w + 10, 130)
	right_scroll.size = Vector2(right_w - 20, 895)
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	viewer.add_child(right_scroll)

	var right_grid := GridContainer.new()
	right_grid.columns = 2
	right_grid.add_theme_constant_override("h_separation", 10)
	right_grid.add_theme_constant_override("v_separation", 10)
	right_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right_grid)

	for card_id in bp_cards:
		var display_cd: Dictionary = _get_card_display(card_id)
		if not display_cd.is_empty():
			var card_visual := CardScript.create_card_visual(display_cd, card_size, loc)
			card_visual.custom_minimum_size = card_size
			card_visual.mouse_filter = Control.MOUSE_FILTER_STOP
			right_grid.add_child(card_visual)

	# Close button (X) top-right — below persistent HUD bar
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.position = Vector2(vw - 70, 85)
	close_btn.custom_minimum_size = Vector2(55, 55)
	close_btn.add_theme_font_size_override("font_size", 30)
	close_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	var close_sb := StyleBoxFlat.new()
	close_sb.bg_color = Color(0.5, 0.1, 0.1, 0.9)
	close_sb.set_corner_radius_all(8)
	close_btn.add_theme_stylebox_override("normal", close_sb)
	var close_hover := close_sb.duplicate() as StyleBoxFlat
	close_hover.bg_color = Color(0.7, 0.15, 0.15, 0.95)
	close_btn.add_theme_stylebox_override("hover", close_hover)
	close_btn.pressed.connect(func(): viewer.queue_free())
	viewer.add_child(close_btn)

func _show_map_viewer() -> void:
	# Render on DeckViewerCanvas (layer 15) — below PersistentHUD (20)
	if _deck_viewer_canvas == null:
		return
	# Remove previous viewer if open
	var old_viewer = _deck_viewer_canvas.get_node_or_null("MapViewerPanel")
	if old_viewer:
		old_viewer.queue_free()

	var vw: float = get_viewport_rect().size.x
	var viewer := Control.new()
	viewer.name = "MapViewerPanel"
	viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewer.mouse_filter = Control.MOUSE_FILTER_STOP
	_deck_viewer_canvas.add_child(viewer)

	# Dark background — visual only, doesn't block scroll
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewer.add_child(bg)

	# Title
	var title := Label.new()
	title.text = "地图 — 第 %d 层" % run.floor_num if run.floor_num > 0 else "地图"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 1, 0.8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 85)
	title.size = Vector2(vw, 50)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewer.add_child(title)

	# Scroll container for map
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(60, 140)
	scroll.size = Vector2(vw - 120, 890)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	viewer.add_child(scroll)

	# Map canvas
	var node_size := 80
	var floor_height := 120
	var map_width := int(vw - 120)
	var total_height: int = 11 * floor_height + 100
	var map_canvas := Control.new()
	map_canvas.custom_minimum_size = Vector2(map_width, total_height)
	map_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(map_canvas)

	# Draw lines canvas
	var line_canvas := Control.new()
	line_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_canvas.add_child(line_canvas)

	# Calculate node positions
	var node_positions: Dictionary = {}
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

	# Draw nodes (read-only, no click handlers)
	for key in run.map_nodes:
		var nd: Dictionary = run.map_nodes[key]
		var pos: Vector2 = node_positions[key]
		var btn := _create_map_node(key, nd, pos, node_size)
		btn.disabled = true  # All nodes non-interactive in viewer
		btn.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow scroll-through on touch
		map_canvas.add_child(btn)

	# Auto-scroll to current floor
	await get_tree().process_frame
	var scroll_y: int = maxi(0, total_height - int((run.floor_num + 2) * floor_height) - 400)
	scroll.scroll_vertical = scroll_y

	# Close button (X) top-right — below persistent HUD bar
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.position = Vector2(vw - 80, 85)
	close_btn.custom_minimum_size = Vector2(60, 60)
	close_btn.add_theme_font_size_override("font_size", 32)
	close_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	var close_sb := StyleBoxFlat.new()
	close_sb.bg_color = Color(0.5, 0.1, 0.1, 0.9)
	close_sb.set_corner_radius_all(8)
	close_btn.add_theme_stylebox_override("normal", close_sb)
	var close_hover := close_sb.duplicate() as StyleBoxFlat
	close_hover.bg_color = Color(0.7, 0.15, 0.15, 0.95)
	close_btn.add_theme_stylebox_override("hover", close_hover)
	close_btn.pressed.connect(func(): viewer.queue_free())
	viewer.add_child(close_btn)

# ═══════════════════════════════════════════════════════════════════════════
# BACKPACK SYSTEM
# ═══════════════════════════════════════════════════════════════════════════

func _update_backpack_btn_text() -> void:
	if _hud_backpack_btn == null:
		return
	if phase == Phase.BATTLE:
		_hud_backpack_btn.text = "[包] %d/4 (%d)" % [run.backpack.size(), _backpack_uses_in_battle]
	else:
		_hud_backpack_btn.text = "[包] %d/4" % run.backpack.size()

func _show_backpack() -> void:
	# In battle, check uses
	if phase == Phase.BATTLE and _backpack_uses_in_battle <= 0:
		return
	if _deck_viewer_canvas == null:
		return
	# Close any existing overlays first
	for panel_name in ["DeckViewerPanel", "BackpackPanel", "MapViewerPanel", "UpgradeDetailPanel", "ShopBuyDetail"]:
		var old = _deck_viewer_canvas.get_node_or_null(panel_name)
		if old:
			old.queue_free()

	var vw: float = get_viewport_rect().size.x
	var panel := Control.new()
	panel.name = "BackpackPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_deck_viewer_canvas.add_child(panel)

	# Track pending changes for battle confirm
	var pending_add: Array = []  # card_ids moved INTO backpack this session
	var pending_remove: Array = []  # card_ids moved OUT of backpack this session

	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(_event: InputEvent):
		pass  # Don't close on background click — use Cancel button
	)
	panel.add_child(bg)

	var loc = get_node_or_null("/root/Loc")
	# Compute uniform card size so left (5 cols) and right (2 cols) cards match
	var left_cols: int = 5
	var right_cols: int = 2
	var gap: float = 12.0
	var margin: float = 40.0
	# Total gaps + margins: left(margin + 4*gap) + divider(20) + right(margin + 1*gap)
	var total_spacing: float = margin + gap * (left_cols - 1) + 20.0 + margin + gap * (right_cols - 1)
	var card_w: float = floorf((vw - total_spacing) / (left_cols + right_cols))
	var card_size := Vector2(card_w, floorf(card_w * 1.4))
	var left_card_size := card_size
	var right_card_size := card_size
	var divider_x: float = margin + left_cols * card_w + (left_cols - 1) * gap + 10.0

	# === LEFT: All deck cards (excluding ones currently in backpack) ===
	var left_title := Label.new()
	left_title.text = "卡组"
	left_title.add_theme_font_size_override("font_size", 28)
	left_title.add_theme_color_override("font_color", Color(1, 1, 0.8))
	left_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_title.position = Vector2(0, 85)
	left_title.size = Vector2(divider_x, 40)
	left_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(left_title)

	var left_scroll := ScrollContainer.new()
	left_scroll.name = "LeftScroll"
	left_scroll.position = Vector2(20, 130)
	left_scroll.size = Vector2(divider_x - 40, 855)
	left_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(left_scroll)

	var left_grid := GridContainer.new()
	left_grid.name = "LeftGrid"
	left_grid.columns = left_cols
	left_grid.add_theme_constant_override("h_separation", 12)
	left_grid.add_theme_constant_override("v_separation", 12)
	left_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(left_grid)

	# === RIGHT: Backpack slots (4 max) ===
	var right_title := Label.new()
	right_title.text = "背包 (%d/4)" % run.backpack.size()
	right_title.name = "RightTitle"
	right_title.add_theme_font_size_override("font_size", 28)
	right_title.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
	right_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_title.position = Vector2(divider_x, 85)
	right_title.size = Vector2(vw - divider_x, 40)
	right_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(right_title)

	var right_scroll := ScrollContainer.new()
	right_scroll.position = Vector2(divider_x + 20, 130)
	right_scroll.size = Vector2(vw - divider_x - 40, 855)
	right_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(right_scroll)

	var right_container := GridContainer.new()
	right_container.name = "RightContainer"
	right_container.columns = 2
	right_container.add_theme_constant_override("h_separation", 12)
	right_container.add_theme_constant_override("v_separation", 12)
	right_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right_container)

	# Divider line
	var divider := ColorRect.new()
	divider.color = Color(0.4, 0.35, 0.25, 0.8)
	divider.position = Vector2(divider_x - 1, 85)
	divider.size = Vector2(2, 920)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(divider)

	# === Bottom buttons: Confirm + Cancel ===
	var btn_w: float = 200.0
	var btn_gap: float = 40.0
	var btn_y: float = 1000.0

	# Confirm button — starts disabled (grey), turns green when changes exist
	var confirm_btn := Button.new()
	confirm_btn.name = "ConfirmBtn"
	confirm_btn.text = "确定"
	confirm_btn.custom_minimum_size = Vector2(btn_w, 60)
	confirm_btn.add_theme_font_size_override("font_size", 28)
	confirm_btn.disabled = true
	# Disabled style (grey)
	var cb_disabled := StyleBoxFlat.new()
	cb_disabled.bg_color = Color(0.25, 0.25, 0.25, 0.7)
	cb_disabled.border_color = Color(0.4, 0.4, 0.4, 0.5)
	cb_disabled.set_border_width_all(2)
	cb_disabled.set_corner_radius_all(8)
	confirm_btn.add_theme_stylebox_override("disabled", cb_disabled)
	confirm_btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
	# Active style (green)
	var cb_style := StyleBoxFlat.new()
	cb_style.bg_color = Color(0.15, 0.5, 0.2, 0.9)
	cb_style.border_color = Color(0.3, 0.8, 0.4)
	cb_style.set_border_width_all(2)
	cb_style.set_corner_radius_all(8)
	confirm_btn.add_theme_stylebox_override("normal", cb_style)
	confirm_btn.add_theme_color_override("font_color", Color.WHITE)
	var cb_hover := cb_style.duplicate() as StyleBoxFlat
	cb_hover.bg_color = Color(0.2, 0.65, 0.3, 0.95)
	confirm_btn.add_theme_stylebox_override("hover", cb_hover)
	confirm_btn.position = Vector2(vw / 2.0 - btn_w - btn_gap / 2.0, btn_y)
	panel.add_child(confirm_btn)

	# Cancel button
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(btn_w, 60)
	cancel_btn.add_theme_font_size_override("font_size", 28)
	cancel_btn.add_theme_color_override("font_color", Color.WHITE)
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.4, 0.15, 0.15, 0.9)
	cancel_style.border_color = Color(0.7, 0.3, 0.3)
	cancel_style.set_border_width_all(2)
	cancel_style.set_corner_radius_all(8)
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	var cancel_hover := cancel_style.duplicate() as StyleBoxFlat
	cancel_hover.bg_color = Color(0.55, 0.2, 0.2, 0.95)
	cancel_btn.add_theme_stylebox_override("hover", cancel_hover)
	cancel_btn.position = Vector2(vw / 2.0 + btn_gap / 2.0, btn_y)
	panel.add_child(cancel_btn)

	# Store original backpack state for cancel/revert
	var original_backpack: Array = run.backpack.duplicate()

	# --- Rebuild functions (use Array wrapper so lambdas share the reference) ---
	var _rebuild_ref: Array = [null]
	_rebuild_ref[0] = func():
		# Rebuild left grid — remove immediately to avoid layout glitches
		for child in left_grid.get_children():
			left_grid.remove_child(child)
			child.queue_free()
		var bp_left: Array = run.backpack.duplicate()
		var deck_cards: Array = []
		for cid in run.deck:
			var bi := bp_left.find(cid)
			if bi >= 0:
				bp_left.remove_at(bi)
			else:
				deck_cards.append(cid)
		deck_cards.sort_custom(func(a, b):
			var ca: Dictionary = _get_card_display(a)
			var cb2: Dictionary = _get_card_display(b)
			if ca.get("type", 0) != cb2.get("type", 0):
				return ca.get("type", 0) < cb2.get("type", 0)
			return ca.get("name", "") < cb2.get("name", "")
		)
		for cid in deck_cards:
			var cd: Dictionary = _get_card_display(cid)
			if cd.is_empty():
				continue
			var card_vis := CardScript.create_card_visual(cd, left_card_size, loc)
			card_vis.custom_minimum_size = left_card_size
			card_vis.mouse_filter = Control.MOUSE_FILTER_STOP
			var captured_id: String = cid
			card_vis.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					if run.backpack.size() < 4:
						run.backpack.append(captured_id)
						pending_add.append(captured_id)
						# If this card was previously removed this session, cancel it out
						var ri := pending_remove.find(captured_id)
						if ri >= 0:
							pending_remove.remove_at(ri)
						_rebuild_ref[0].call()
			)
			left_grid.add_child(card_vis)

		# Rebuild right container — remove immediately
		for child in right_container.get_children():
			right_container.remove_child(child)
			child.queue_free()
		for i in 4:
			if i < run.backpack.size():
				var bp_cid: String = run.backpack[i]
				var bp_cd: Dictionary = _get_card_display(bp_cid)
				if bp_cd.is_empty():
					continue
				var bp_vis := CardScript.create_card_visual(bp_cd, right_card_size, loc)
				bp_vis.custom_minimum_size = right_card_size
				bp_vis.mouse_filter = Control.MOUSE_FILTER_STOP
				var captured_bp_id: String = bp_cid
				var captured_idx: int = i
				bp_vis.gui_input.connect(func(event: InputEvent):
					if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
						run.backpack.remove_at(captured_idx)
						pending_remove.append(captured_bp_id)
						# If this card was previously added this session, cancel it out
						var ai := pending_add.find(captured_bp_id)
						if ai >= 0:
							pending_add.remove_at(ai)
						_rebuild_ref[0].call()
				)
				right_container.add_child(bp_vis)
			else:
				# Empty slot placeholder
				var slot := PanelContainer.new()
				slot.custom_minimum_size = right_card_size
				var slot_style := StyleBoxFlat.new()
				slot_style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
				slot_style.border_color = Color(0.3, 0.3, 0.3, 0.5)
				slot_style.set_border_width_all(2)
				slot_style.set_corner_radius_all(8)
				slot.add_theme_stylebox_override("panel", slot_style)
				var slot_lbl := Label.new()
				slot_lbl.text = "空位"
				slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				slot_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				slot_lbl.add_theme_font_size_override("font_size", 22)
				slot_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
				slot.add_child(slot_lbl)
				right_container.add_child(slot)

		# Update title
		var rt = panel.get_node_or_null("RightTitle")
		if rt:
			rt.text = "背包 (%d/4)" % run.backpack.size()

		# Enable/disable confirm button based on changes
		var has_changes: bool = not pending_add.is_empty() or not pending_remove.is_empty()
		confirm_btn.disabled = not has_changes
		_update_backpack_btn_text()

	# Initial build
	_rebuild_ref[0].call()

	# Confirm action
	confirm_btn.pressed.connect(func():
		if confirm_btn.disabled:
			return
		if phase == Phase.BATTLE:
			_apply_backpack_changes_in_battle(pending_add.duplicate(), pending_remove.duplicate())
			_backpack_uses_in_battle -= 1
		_update_backpack_btn_text()
		_update_hud_labels()
		panel.queue_free()
	)

	# Cancel action — revert backpack to original state
	cancel_btn.pressed.connect(func():
		run.backpack = original_backpack.duplicate()
		_update_backpack_btn_text()
		panel.queue_free()
	)

func _apply_backpack_changes_in_battle(added_to_bp: Array, removed_from_bp: Array) -> void:
	if _battle_instance == null:
		return
	var bm: Node2D = _battle_instance

	# Cards added to backpack: remove from draw_pile, discard_pile, hand
	for cid in added_to_bp:
		var found := false
		# Remove from hand (check card_hand.cards for visual nodes)
		if bm.card_hand:
			for card_node in bm.card_hand.cards.duplicate():
				if card_node.card_data.get("id", "") == cid:
					# Remove from bm.hand array too
					var hi := -1
					for i in range(bm.hand.size() - 1, -1, -1):
						if bm.hand[i].get("id", "") == cid:
							hi = i
							break
					if hi >= 0:
						bm.hand.remove_at(hi)
					bm.card_hand.remove_card(card_node)
					found = true
					break
		if found:
			continue
		# Remove from draw_pile
		for i in range(bm.draw_pile.size() - 1, -1, -1):
			if bm.draw_pile[i].get("id", "") == cid:
				bm.draw_pile.remove_at(i)
				found = true
				break
		if found:
			continue
		# Remove from discard_pile
		for i in range(bm.discard_pile.size() - 1, -1, -1):
			if bm.discard_pile[i].get("id", "") == cid:
				bm.discard_pile.remove_at(i)
				break

	# Cards removed from backpack: add to draw_pile at random positions
	for cid in removed_from_bp:
		var cd: Dictionary = _get_card_display(cid)
		if cd.is_empty():
			continue
		var insert_pos: int = randi() % (bm.draw_pile.size() + 1)
		bm.draw_pile.insert(insert_pos, cd)

	# Update pile labels and hand layout
	bm._update_pile_labels()
	if bm.card_hand:
		bm.card_hand.update_layout()

func _get_card_display(card_id: String) -> Dictionary:
	if card_id.ends_with("+"):
		var base_id: String = card_id.trim_suffix("+")
		return gm.get_upgraded_card(base_id)
	elif gm.card_database.has(card_id):
		return gm.card_database[card_id]
	return {}

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
		"bloodfiend": return "嗜血狂魔"
		"fire_mage": return "火法师"
		"forger": return "铸造者"
	return hero_id

func _hero_color(hero_id: String) -> Color:
	match hero_id:
		"ironclad": return Color(0.8, 0.2, 0.2)
		"silent": return Color(0.2, 0.7, 0.3)
		"bloodfiend": return Color(0.7, 0.1, 0.2)
		"fire_mage": return Color(0.9, 0.4, 0.1)
		"forger": return Color(0.7, 0.5, 0.2)
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
