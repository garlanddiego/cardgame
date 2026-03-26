extends Control
## res://scripts/card_generator.gd — Card Generator (卡牌制作器)
## Allows creating custom cards that match the game_manager card_database format.
## Uses Card.create_card_visual() for consistent preview rendering.

const CardScript = preload("res://scripts/card.gd")

# UI References (built programmatically)
var name_edit: LineEdit
var cost_buttons: Array[Button] = []
var type_buttons: Array[Button] = []
var char_buttons: Array[Button] = []
var preview_container: Control
var save_button: Button
var back_button: Button

# Effect rows: {checkbox: CheckBox, spinbox: SpinBox or null, key: String, label: String}
var effect_rows: Array[Dictionary] = []

# Current selections
var selected_cost: int = 1
var selected_type: int = 0  # 0=Attack, 1=Skill, 2=Power
var selected_character: String = "ironclad"

# Colors matching the STS dark theme
const BG_COLOR := Color(0.08, 0.06, 0.05, 1.0)
const PANEL_BG := Color(0.12, 0.10, 0.09, 1.0)
const ACCENT_GOLD := Color(0.85, 0.7, 0.15, 1.0)
const ACCENT_RED := Color(0.85, 0.2, 0.2, 1.0)
const TEXT_COLOR := Color(0.95, 0.92, 0.85, 1.0)
const DIM_TEXT := Color(0.6, 0.58, 0.52, 1.0)
const INPUT_BG := Color(0.18, 0.15, 0.13, 1.0)
const BUTTON_NORMAL := Color(0.2, 0.17, 0.14, 1.0)
const BUTTON_HOVER := Color(0.3, 0.25, 0.2, 1.0)
const BUTTON_SELECTED := Color(0.5, 0.35, 0.1, 1.0)
const BORDER_COLOR := Color(0.4, 0.32, 0.2, 0.8)

# Current preview node
var _preview_node: Control = null
# Counter for unique card IDs
var _card_counter: int = 0

func _ready() -> void:
	_build_ui()
	_update_preview()

# =============================================================================
# UI CONSTRUCTION
# =============================================================================

func _build_ui() -> void:
	# Root background
	var bg = ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Main horizontal split
	var hsplit = HBoxContainer.new()
	hsplit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hsplit.add_theme_constant_override("separation", 0)
	add_child(hsplit)

	# Left panel (40% - input controls)
	var left_panel = _build_left_panel()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.4
	hsplit.add_child(left_panel)

	# Separator line
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(2, 0)
	sep.color = BORDER_COLOR
	sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.add_child(sep)

	# Right panel (60% - card preview)
	var right_panel = _build_right_panel()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.6
	hsplit.add_child(right_panel)

func _build_left_panel() -> PanelContainer:
	var panel_container = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	panel_container.add_theme_stylebox_override("panel", panel_style)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "卡牌制作器"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_add_separator(vbox)

	# Card Name
	_add_section_label(vbox, "卡牌名称")
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "输入卡牌名称..."
	name_edit.add_theme_font_size_override("font_size", 20)
	name_edit.add_theme_color_override("font_color", TEXT_COLOR)
	name_edit.add_theme_color_override("font_placeholder_color", DIM_TEXT)
	var name_style = StyleBoxFlat.new()
	name_style.bg_color = INPUT_BG
	name_style.border_color = BORDER_COLOR
	name_style.border_width_left = 1
	name_style.border_width_right = 1
	name_style.border_width_top = 1
	name_style.border_width_bottom = 1
	name_style.corner_radius_top_left = 4
	name_style.corner_radius_top_right = 4
	name_style.corner_radius_bottom_left = 4
	name_style.corner_radius_bottom_right = 4
	name_style.content_margin_left = 8
	name_style.content_margin_right = 8
	name_style.content_margin_top = 6
	name_style.content_margin_bottom = 6
	name_edit.add_theme_stylebox_override("normal", name_style)
	name_edit.text_changed.connect(_on_any_input_changed_text)
	vbox.add_child(name_edit)

	_add_separator(vbox)

	# Cost Selector
	_add_section_label(vbox, "费用")
	var cost_row = HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 8)
	var cost_values = [0, 1, 2, 3, -1]  # -1 = X
	var cost_labels = ["0", "1", "2", "3", "X"]
	for i in range(cost_values.size()):
		var btn = _create_toggle_button(cost_labels[i], 60, 40)
		btn.pressed.connect(_on_cost_selected.bind(cost_values[i], i))
		cost_row.add_child(btn)
		cost_buttons.append(btn)
	vbox.add_child(cost_row)
	# Default: cost 1 selected
	_highlight_button_group(cost_buttons, 1)

	_add_separator(vbox)

	# Type Selector
	_add_section_label(vbox, "类型")
	var type_row = HBoxContainer.new()
	type_row.add_theme_constant_override("separation", 8)
	var type_names = ["攻击", "技能", "能力"]
	for i in range(type_names.size()):
		var btn = _create_toggle_button(type_names[i], 100, 40)
		btn.pressed.connect(_on_type_selected.bind(i))
		type_row.add_child(btn)
		type_buttons.append(btn)
	vbox.add_child(type_row)
	_highlight_button_group(type_buttons, 0)

	_add_separator(vbox)

	# Character Selector
	_add_section_label(vbox, "角色")
	var char_row = HBoxContainer.new()
	char_row.add_theme_constant_override("separation", 8)
	var char_names = ["铁甲战士", "沉默猎手"]
	var char_ids = ["ironclad", "silent"]
	for i in range(char_names.size()):
		var btn = _create_toggle_button(char_names[i], 140, 40)
		btn.pressed.connect(_on_char_selected.bind(char_ids[i], i))
		char_row.add_child(btn)
		char_buttons.append(btn)
	vbox.add_child(char_row)
	_highlight_button_group(char_buttons, 0)

	_add_separator(vbox)

	# Effects Section
	_add_section_label(vbox, "效果")
	_build_effect_rows(vbox)

	_add_separator(vbox)

	# Action buttons
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER

	back_button = _create_action_button("返回", Color(0.5, 0.4, 0.3))
	back_button.pressed.connect(_on_back_pressed)
	btn_row.add_child(back_button)

	save_button = _create_action_button("保存卡牌", ACCENT_GOLD)
	save_button.pressed.connect(_on_save_pressed)
	btn_row.add_child(save_button)

	vbox.add_child(btn_row)

	# Spacer at bottom
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	return panel_container

func _build_right_panel() -> PanelContainer:
	var panel_container = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.05, 0.04, 1.0)
	panel_container.add_theme_stylebox_override("panel", panel_style)

	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_container.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var preview_label = Label.new()
	preview_label.text = "卡牌预览"
	preview_label.add_theme_font_size_override("font_size", 24)
	preview_label.add_theme_color_override("font_color", DIM_TEXT)
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(preview_label)

	# Container for the card visual — sized to hold a large card
	preview_container = Control.new()
	preview_container.custom_minimum_size = Vector2(384, 516)
	preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(preview_container)

	return panel_container

func _build_effect_rows(parent: VBoxContainer) -> void:
	# Define all effects: [key, label, has_spinbox, default_value, min_val, max_val]
	var effects_def: Array = [
		["damage", "伤害", true, 6, 1, 999],
		["damage_all", "全体伤害", false, 0, 0, 0],
		["block", "格挡", true, 5, 1, 999],
		["draw", "抽牌", true, 1, 1, 10],
		["vulnerable", "施加易伤", true, 1, 1, 10],
		["weak", "施加虚弱", true, 1, 1, 10],
		["poison", "施加中毒", true, 1, 1, 99],
		["strength", "获得力量", true, 1, 1, 20],
		["dexterity", "获得敏捷", true, 1, 1, 20],
		["multi_hit", "多段攻击", true, 2, 2, 10],
		["exhaust", "消耗", false, 0, 0, 0],
		["ethereal", "虚无", false, 0, 0, 0],
		["innate", "天生", false, 0, 0, 0],
		["sly", "奇巧 (Sly)", false, 0, 0, 0],
		["self_damage", "自伤", true, 2, 1, 99],
		["gain_energy", "获得能量", true, 1, 1, 5],
		["next_turn_energy", "下回合+能量", true, 1, 1, 5],
		["next_turn_block", "下回合+格挡", true, 5, 1, 99],
		["heal", "治疗", true, 5, 1, 99],
		["add_shiv", "添加小刀", true, 1, 1, 5],
	]

	for def in effects_def:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var cb = CheckBox.new()
		cb.text = def[1]
		cb.add_theme_font_size_override("font_size", 16)
		cb.add_theme_color_override("font_color", TEXT_COLOR)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.toggled.connect(_on_any_input_changed_bool)
		row.add_child(cb)

		var spinbox: SpinBox = null
		if def[2]:
			spinbox = SpinBox.new()
			spinbox.min_value = def[4]
			spinbox.max_value = def[5]
			spinbox.value = def[3]
			spinbox.custom_minimum_size = Vector2(90, 0)
			spinbox.add_theme_font_size_override("font_size", 16)
			spinbox.value_changed.connect(_on_any_input_changed_float)
			# Style the spinbox line edit
			var sb_style = StyleBoxFlat.new()
			sb_style.bg_color = INPUT_BG
			sb_style.border_color = BORDER_COLOR
			sb_style.border_width_left = 1
			sb_style.border_width_right = 1
			sb_style.border_width_top = 1
			sb_style.border_width_bottom = 1
			sb_style.corner_radius_top_left = 3
			sb_style.corner_radius_top_right = 3
			sb_style.corner_radius_bottom_left = 3
			sb_style.corner_radius_bottom_right = 3
			spinbox.get_line_edit().add_theme_stylebox_override("normal", sb_style)
			row.add_child(spinbox)

		parent.add_child(row)

		effect_rows.append({
			"key": def[0],
			"label": def[1],
			"checkbox": cb,
			"spinbox": spinbox,
		})

# =============================================================================
# UI HELPERS
# =============================================================================

func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", ACCENT_GOLD)
	parent.add_child(lbl)

func _add_separator(parent: VBoxContainer) -> void:
	var sep = HSeparator.new()
	var style = StyleBoxFlat.new()
	style.bg_color = BORDER_COLOR
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	sep.add_theme_stylebox_override("separator", style)
	parent.add_child(sep)

func _create_toggle_button(text: String, min_w: float, min_h: float) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(min_w, min_h)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	_style_toggle_button(btn, false)
	return btn

func _style_toggle_button(btn: Button, selected: bool) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = BUTTON_SELECTED if selected else BUTTON_NORMAL
	style.border_color = ACCENT_GOLD if selected else BORDER_COLOR
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
	hover.bg_color = BUTTON_HOVER if not selected else BUTTON_SELECTED
	btn.add_theme_stylebox_override("hover", hover)
	var pressed_style = style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = BUTTON_SELECTED
	btn.add_theme_stylebox_override("pressed", pressed_style)

func _highlight_button_group(buttons: Array[Button], index: int) -> void:
	for i in range(buttons.size()):
		_style_toggle_button(buttons[i], i == index)

func _create_action_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(160, 50)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.5)
	style.border_color = color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(color.r, color.g, color.b, 0.7)
	btn.add_theme_stylebox_override("hover", hover)
	return btn

# =============================================================================
# INPUT HANDLERS
# =============================================================================

func _on_any_input_changed_text(_text: String) -> void:
	_update_preview()

func _on_any_input_changed_bool(_val: bool) -> void:
	_update_preview()

func _on_any_input_changed_float(_val: float) -> void:
	_update_preview()

func _on_cost_selected(cost_value: int, index: int) -> void:
	selected_cost = cost_value
	_highlight_button_group(cost_buttons, index)
	_update_preview()

func _on_type_selected(type_index: int) -> void:
	selected_type = type_index
	_highlight_button_group(type_buttons, type_index)
	_update_preview()

func _on_char_selected(char_id: String, index: int) -> void:
	selected_character = char_id
	_highlight_button_group(char_buttons, index)
	_update_preview()

# =============================================================================
# CARD DATA BUILDING
# =============================================================================

func _build_card_data() -> Dictionary:
	var card_name: String = name_edit.text.strip_edges()
	if card_name.is_empty():
		card_name = "自定义卡牌"

	# Generate a unique ID
	var card_id: String = "custom_" + card_name.to_lower().replace(" ", "_").replace("/", "_")

	var data: Dictionary = {
		"id": card_id,
		"name": card_name,
		"cost": selected_cost,
		"type": selected_type,
		"character": selected_character,
		"damage": 0,
		"block": 0,
		"description": "",
		"art": "",
		"target": "self",
		"actions": [],
	}

	var actions: Array = []
	var desc_parts: Array = []
	var has_damage: bool = false
	var is_aoe: bool = false
	var target_enemy: bool = false

	for row in effect_rows:
		if not row["checkbox"].button_pressed:
			continue
		var key: String = row["key"]
		var value: int = int(row["spinbox"].value) if row["spinbox"] != null else 0

		match key:
			"damage":
				data["damage"] = value
				has_damage = true
				target_enemy = true
				desc_parts.append("造成 %d 伤害。" % value)
			"damage_all":
				is_aoe = true
				desc_parts.append("（全体）")

			"block":
				data["block"] = value
				actions.append({"type": "block"})
				desc_parts.append("获得 %d 格挡。" % value)

			"draw":
				data["draw"] = value
				actions.append({"type": "draw", "value": value})
				desc_parts.append("抽 %d 张牌。" % value)

			"vulnerable":
				data["apply_status"] = {"type": "vulnerable", "stacks": value}
				actions.append({"type": "apply_status", "source": "apply_status"})
				target_enemy = true
				desc_parts.append("施加 %d 易伤。" % value)

			"weak":
				if data.has("apply_status"):
					data["apply_status_2"] = {"type": "weak", "stacks": value}
					actions.append({"type": "apply_status", "source": "apply_status_2"})
				else:
					data["apply_status"] = {"type": "weak", "stacks": value}
					actions.append({"type": "apply_status", "source": "apply_status"})
				target_enemy = true
				desc_parts.append("施加 %d 虚弱。" % value)

			"poison":
				if data.has("apply_status"):
					if data.has("apply_status_2"):
						# Use inline status for third status
						actions.append({"type": "apply_status", "status": "poison", "stacks": value})
					else:
						data["apply_status_2"] = {"type": "poison", "stacks": value}
						actions.append({"type": "apply_status", "source": "apply_status_2"})
				else:
					data["apply_status"] = {"type": "poison", "stacks": value}
					actions.append({"type": "apply_status", "source": "apply_status"})
				target_enemy = true
				desc_parts.append("施加 %d 中毒。" % value)

			"strength":
				actions.append({"type": "apply_self_status", "status": "strength", "stacks": value})
				desc_parts.append("获得 %d 力量。" % value)

			"dexterity":
				actions.append({"type": "apply_self_status", "status": "dexterity", "stacks": value})
				desc_parts.append("获得 %d 敏捷。" % value)

			"multi_hit":
				data["times"] = value
				desc_parts.append("（%d 次攻击）" % value)

			"exhaust":
				data["exhaust"] = true
				desc_parts.append("消耗。")

			"ethereal":
				data["ethereal"] = true
				desc_parts.append("虚无。")

			"innate":
				data["innate"] = true
				desc_parts.append("天生。")

			"sly":
				data["special"] = "sly"
				desc_parts.append("奇巧。")

			"self_damage":
				actions.append({"type": "self_damage", "value": value})
				desc_parts.append("失去 %d HP。" % value)

			"gain_energy":
				actions.append({"type": "gain_energy", "value": value})
				desc_parts.append("获得 %d 能量。" % value)

			"next_turn_energy":
				actions.append({"type": "gain_energy", "value": value, "next_turn": true})
				desc_parts.append("下回合获得 %d 能量。" % value)

			"next_turn_block":
				actions.append({"type": "block", "value": value, "next_turn": true})
				desc_parts.append("下回合获得 %d 格挡。" % value)

			"heal":
				actions.append({"type": "heal", "value": value})
				desc_parts.append("治疗 %d HP。" % value)

			"add_shiv":
				actions.append({"type": "add_shiv", "value": value})
				desc_parts.append("添加 %d 把小刀。" % value)

	# Add damage action at the beginning if damage is enabled
	if has_damage:
		if is_aoe:
			actions.insert(0, {"type": "damage_all"})
			data["target"] = "all_enemies"
		else:
			actions.insert(0, {"type": "damage"})

	# Set target based on effects
	if target_enemy and not is_aoe:
		data["target"] = "enemy"

	data["actions"] = actions
	data["description"] = "\n".join(desc_parts)

	return data

# =============================================================================
# PREVIEW
# =============================================================================

func _update_preview() -> void:
	if preview_container == null:
		return

	# Remove old preview
	if _preview_node != null:
		_preview_node.queue_free()
		_preview_node = null

	var card_data = _build_card_data()
	var preview_size = Vector2(384, 516)

	_preview_node = CardScript.create_card_visual(card_data, preview_size)
	preview_container.add_child(_preview_node)

# =============================================================================
# SAVE / BACK
# =============================================================================

func _on_save_pressed() -> void:
	var card_data = _build_card_data()

	# Generate unique ID with counter
	_card_counter += 1
	var card_id = "custom_%04d_%s" % [_card_counter, card_data["name"].to_lower().replace(" ", "_")]
	card_data["id"] = card_id

	# Add to GameManager's card_database
	var gm = _get_game_manager()
	if gm and gm.card_database is Dictionary:
		gm.card_database[card_id] = card_data
		# Visual feedback: flash the save button
		_flash_save_feedback()

func _flash_save_feedback() -> void:
	var original_text = save_button.text
	save_button.text = "已保存!"
	save_button.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func():
		save_button.text = original_text
		save_button.add_theme_color_override("font_color", Color.WHITE)
	)

func _on_back_pressed() -> void:
	# Navigate back to main menu
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _get_game_manager() -> Node:
	for child in get_tree().root.get_children():
		if child.name == "GameManager":
			return child
	return null
