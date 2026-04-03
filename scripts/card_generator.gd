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
var trigger_buttons: Array[Button] = []
var preview_container: Control
var save_button: Button
var save_as_new_button: Button
var back_button: Button
var edit_button: Button
var custom_desc_edit: TextEdit

# Editing state — when non-empty, save overwrites this card instead of creating new
var _editing_card_id: String = ""
var _editing_art_path: String = ""
# Card browser overlay node (full-screen)
var _browser_overlay: Control = null

# Power trigger UI
var trigger_section_label: Label = null
var trigger_row: HBoxContainer = null

# Effect rows: {checkbox: CheckBox, spinbox: SpinBox or null, key: String, label: String}
# For custom spinbox replacement: {checkbox, value_label, minus_btn, plus_btn, min_val, max_val, current_value}
var effect_rows: Array[Dictionary] = []
# Custom spinbox values keyed by effect name
var _effect_values: Dictionary = {}

# Current selections
var selected_cost: int = 1
var selected_type: int = 0  # 0=Attack, 1=Skill, 2=Power
var selected_character: String = "ironclad"
var selected_power_trigger: String = "turn_end"  # "turn_start", "turn_end", "permanent"
var selected_version: String = "new"  # "new" or "old"
var version_buttons: Array[Button] = []
var selected_status: String = "active"  # "active", "incomplete", "deprecated"
var status_buttons: Array[Button] = []

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

# Text-to-Card mode UI
var _text_parse_edit: TextEdit = null
var _text_parse_button: Button = null

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

	# Left panel (65% - input controls)
	var left_panel = _build_left_panel()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.65
	hsplit.add_child(left_panel)

	# Separator line
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(2, 0)
	sep.color = BORDER_COLOR
	sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.add_child(sep)

	# Right panel (35% - card preview)
	var right_panel = _build_right_panel()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.35
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

	# "Select Card to Edit" button
	edit_button = _create_action_button("选择卡牌编辑", Color(0.3, 0.55, 0.8))
	edit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_button.pressed.connect(_show_card_browser)
	vbox.add_child(edit_button)

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

	# Power Trigger Timing (hidden by default, shown when type=Power)
	trigger_section_label = Label.new()
	trigger_section_label.text = "触发时机"
	trigger_section_label.add_theme_font_size_override("font_size", 24)
	trigger_section_label.add_theme_color_override("font_color", ACCENT_GOLD)
	trigger_section_label.visible = false
	vbox.add_child(trigger_section_label)

	trigger_row = HBoxContainer.new()
	trigger_row.add_theme_constant_override("separation", 8)
	trigger_row.visible = false
	var trigger_names = ["回合开始时", "回合结束时", "长期作用"]
	var trigger_ids = ["turn_start", "turn_end", "permanent"]
	for i in range(trigger_names.size()):
		var btn = _create_toggle_button(trigger_names[i], 120, 40)
		btn.pressed.connect(_on_trigger_selected.bind(trigger_ids[i], i))
		trigger_row.add_child(btn)
		trigger_buttons.append(btn)
	vbox.add_child(trigger_row)
	_highlight_button_group(trigger_buttons, 1)  # Default: turn_end

	_add_separator(vbox)

	# Character Selector
	_add_section_label(vbox, "角色")
	var char_row = HBoxContainer.new()
	char_row.add_theme_constant_override("separation", 8)
	var char_names = ["铁甲战士", "沉默猎手", "无色"]
	var char_ids = ["ironclad", "silent", "neutral"]
	for i in range(char_names.size()):
		var btn = _create_toggle_button(char_names[i], 140, 40)
		btn.pressed.connect(_on_char_selected.bind(char_ids[i], i))
		char_row.add_child(btn)
		char_buttons.append(btn)
	vbox.add_child(char_row)
	_highlight_button_group(char_buttons, 0)

	_add_separator(vbox)

	# Version Selector (新版/旧版)
	_add_section_label(vbox, "版本")
	var version_row = HBoxContainer.new()
	version_row.add_theme_constant_override("separation", 8)
	var ver_names = ["新版", "旧版"]
	var ver_ids = ["new", "old"]
	for i in range(ver_names.size()):
		var btn = _create_toggle_button(ver_names[i], 100, 40)
		btn.pressed.connect(_on_version_selected.bind(ver_ids[i], i))
		version_row.add_child(btn)
		version_buttons.append(btn)
	vbox.add_child(version_row)
	_highlight_button_group(version_buttons, 0)  # Default: "new"

	_add_separator(vbox)

	# Status Selector (可用/未完成/废弃)
	_add_section_label(vbox, "状态")
	var status_row = HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	var st_names = ["可用", "未完成", "废弃"]
	var st_ids = ["active", "incomplete", "deprecated"]
	for i in range(st_names.size()):
		var btn = _create_toggle_button(st_names[i], 100, 40)
		btn.pressed.connect(_on_status_selected.bind(st_ids[i], i))
		status_row.add_child(btn)
		status_buttons.append(btn)
	vbox.add_child(status_row)
	_highlight_button_group(status_buttons, 0)  # Default: "active"

	_add_separator(vbox)

	# Text-to-Card Mode (文本模式)
	_build_text_parse_section(vbox)

	_add_separator(vbox)

	# Effects Section
	_add_section_label(vbox, "效果")
	_build_effect_rows(vbox)

	_add_separator(vbox)

	# Custom Description Text Area
	_add_section_label(vbox, "特有功能描述（自定义）")
	custom_desc_edit = TextEdit.new()
	custom_desc_edit.placeholder_text = "输入卡牌特有效果描述..."
	custom_desc_edit.custom_minimum_size = Vector2(0, 80)
	custom_desc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_desc_edit.add_theme_font_size_override("font_size", 18)
	custom_desc_edit.add_theme_color_override("font_color", TEXT_COLOR)
	var desc_style = StyleBoxFlat.new()
	desc_style.bg_color = INPUT_BG
	desc_style.border_color = BORDER_COLOR
	desc_style.border_width_left = 1
	desc_style.border_width_right = 1
	desc_style.border_width_top = 1
	desc_style.border_width_bottom = 1
	desc_style.corner_radius_top_left = 4
	desc_style.corner_radius_top_right = 4
	desc_style.corner_radius_bottom_left = 4
	desc_style.corner_radius_bottom_right = 4
	desc_style.content_margin_left = 8
	desc_style.content_margin_right = 8
	desc_style.content_margin_top = 6
	desc_style.content_margin_bottom = 6
	custom_desc_edit.add_theme_stylebox_override("normal", desc_style)
	custom_desc_edit.text_changed.connect(_on_custom_desc_changed)
	vbox.add_child(custom_desc_edit)

	_add_separator(vbox)

	# Action buttons
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER

	back_button = _create_action_button("返回", Color(0.5, 0.4, 0.3))
	back_button.pressed.connect(_on_back_pressed)
	btn_row.add_child(back_button)

	save_button = _create_action_button("创建卡牌", ACCENT_GOLD)
	save_button.pressed.connect(_on_save_pressed)
	btn_row.add_child(save_button)

	save_as_new_button = _create_action_button("另存为新卡", Color(0.3, 0.55, 0.8))
	save_as_new_button.pressed.connect(_on_save_as_new_pressed)
	btn_row.add_child(save_as_new_button)
	save_as_new_button.visible = false

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
	preview_container.custom_minimum_size = Vector2(384, 594)
	preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(preview_container)

	return panel_container

func _build_text_parse_section(parent: VBoxContainer) -> void:
	_add_section_label(parent, "文本模式")
	var hint_label = Label.new()
	hint_label.text = "关键词模板：造成X伤害 | 全体 | 获得X格挡 | 抽X张牌 | 弃X张牌 | 失去X生命 | 施加X层易伤/虚弱/中毒 | 获得X力量/敏捷/能量 | 治疗X | 消耗 | 虚无 | 固有 | 奇巧 | X段攻击 | 添加X飞刀"
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.add_theme_color_override("font_color", DIM_TEXT)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(hint_label)

	_text_parse_edit = TextEdit.new()
	_text_parse_edit.placeholder_text = "造成10点伤害 加2层易伤 5层中毒 获得8格挡 抽2张牌 消耗..."
	_text_parse_edit.custom_minimum_size = Vector2(0, 60)
	_text_parse_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_parse_edit.add_theme_font_size_override("font_size", 18)
	_text_parse_edit.add_theme_color_override("font_color", TEXT_COLOR)
	var parse_style = StyleBoxFlat.new()
	parse_style.bg_color = INPUT_BG
	parse_style.border_color = Color(0.3, 0.55, 0.8, 0.8)
	parse_style.border_width_left = 1
	parse_style.border_width_right = 1
	parse_style.border_width_top = 1
	parse_style.border_width_bottom = 1
	parse_style.corner_radius_top_left = 4
	parse_style.corner_radius_top_right = 4
	parse_style.corner_radius_bottom_left = 4
	parse_style.corner_radius_bottom_right = 4
	parse_style.content_margin_left = 8
	parse_style.content_margin_right = 8
	parse_style.content_margin_top = 6
	parse_style.content_margin_bottom = 6
	_text_parse_edit.add_theme_stylebox_override("normal", parse_style)
	parent.add_child(_text_parse_edit)

	_text_parse_button = _create_action_button("解析", Color(0.3, 0.55, 0.8))
	_text_parse_button.custom_minimum_size = Vector2(120, 44)
	_text_parse_button.pressed.connect(_on_parse_text_pressed)
	parent.add_child(_text_parse_button)

func _on_parse_text_pressed() -> void:
	if _text_parse_edit == null:
		return
	var text: String = _text_parse_edit.text.strip_edges()
	if text.is_empty():
		return
	_parse_text_to_effects(text)

func _parse_text_to_effects(text: String) -> void:
	# Reset all effect checkboxes first
	for row in effect_rows:
		row["checkbox"].button_pressed = false

	# Use regex for number extraction
	var regex = RegEx.new()

	# --- damage: "造成X点伤害" or "X伤害" ---
	regex.compile("造成(\\d+)点伤害")
	var result = regex.search(text)
	if result:
		_set_effect("damage", true, int(result.get_string(1)))
	else:
		regex.compile("(\\d+)伤害")
		result = regex.search(text)
		if result:
			_set_effect("damage", true, int(result.get_string(1)))

	# --- vulnerable: "加X层易伤" or "X易伤" ---
	regex.compile("加(\\d+)层易伤")
	result = regex.search(text)
	if result:
		_set_effect("vulnerable", true, int(result.get_string(1)))
	else:
		regex.compile("(\\d+)易伤")
		result = regex.search(text)
		if result:
			_set_effect("vulnerable", true, int(result.get_string(1)))

	# --- weak: "加X层虚弱" or "X虚弱" ---
	regex.compile("加(\\d+)层虚弱")
	result = regex.search(text)
	if result:
		_set_effect("weak", true, int(result.get_string(1)))
	else:
		regex.compile("(\\d+)虚弱")
		result = regex.search(text)
		if result:
			_set_effect("weak", true, int(result.get_string(1)))

	# --- poison: "X层中毒" or "X中毒" ---
	regex.compile("(\\d+)层中毒")
	result = regex.search(text)
	if result:
		_set_effect("poison", true, int(result.get_string(1)))
	else:
		regex.compile("(\\d+)中毒")
		result = regex.search(text)
		if result:
			_set_effect("poison", true, int(result.get_string(1)))

	# --- block: "获得X格挡" or "X格挡" ---
	regex.compile("获得(\\d+)格挡")
	result = regex.search(text)
	if result:
		_set_effect("block", true, int(result.get_string(1)))
	else:
		regex.compile("(\\d+)格挡")
		result = regex.search(text)
		if result:
			_set_effect("block", true, int(result.get_string(1)))

	# --- draw: "抽X张牌" ---
	regex.compile("抽(\\d+)张牌")
	result = regex.search(text)
	if result:
		_set_effect("draw", true, int(result.get_string(1)))

	# --- strength: "获得X力量" or "X力量" ---
	regex.compile("获得(\\d+)力量")
	result = regex.search(text)
	if result:
		_set_effect("strength", true, int(result.get_string(1)))
	else:
		regex.compile("(\\d+)力量")
		result = regex.search(text)
		if result:
			_set_effect("strength", true, int(result.get_string(1)))

	# --- dexterity: "获得X敏捷" or "X敏捷" ---
	regex.compile("获得(\\d+)敏捷")
	result = regex.search(text)
	if result:
		_set_effect("dexterity", true, int(result.get_string(1)))
	else:
		regex.compile("(\\d+)敏捷")
		result = regex.search(text)
		if result:
			_set_effect("dexterity", true, int(result.get_string(1)))

	# --- exhaust: "消耗" ---
	if "消耗" in text:
		_set_effect("exhaust", true)

	# --- ethereal: "虚无" ---
	if "虚无" in text:
		_set_effect("ethereal", true)

	# --- self_damage: "自伤X" ---
	regex.compile("自伤(\\d+)")
	result = regex.search(text)
	if result:
		_set_effect("self_damage", true, int(result.get_string(1)))

	# --- damage_all: "全体" ---
	if "全体" in text:
		_set_effect("damage_all", true)

	# Flash feedback on the parse button
	_flash_parse_feedback()

	# Update preview
	_update_preview()

func _flash_parse_feedback() -> void:
	if _text_parse_button == null:
		return
	var original_text = _text_parse_button.text
	_text_parse_button.text = "已解析!"
	_text_parse_button.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func():
		_text_parse_button.text = original_text
		_text_parse_button.add_theme_color_override("font_color", Color.WHITE)
	)

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
		["target_all_enemies", "对所有怪物", false, 0, 0, 0],
		["target_all_heroes", "对所有英雄", false, 0, 0, 0],
	]

	# 2-column layout: use an HBoxContainer with two VBoxContainers
	var columns_hbox = HBoxContainer.new()
	columns_hbox.add_theme_constant_override("separation", 16)
	columns_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(columns_hbox)

	var col_left = VBoxContainer.new()
	col_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_left.add_theme_constant_override("separation", 6)
	columns_hbox.add_child(col_left)

	var col_right = VBoxContainer.new()
	col_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_right.add_theme_constant_override("separation", 6)
	columns_hbox.add_child(col_right)

	for i in range(effects_def.size()):
		var def_item = effects_def[i]
		var target_col = col_left if (i % 2 == 0) else col_right

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var cb = CheckBox.new()
		cb.text = def_item[1]
		cb.add_theme_font_size_override("font_size", 20)
		cb.add_theme_color_override("font_color", TEXT_COLOR)
		# Custom checkbox icons: white bg unchecked, green check on white bg checked
		cb.add_theme_icon_override("unchecked", _get_unchecked_icon())
		cb.add_theme_icon_override("checked", _get_checked_icon())
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.toggled.connect(_on_any_input_changed_bool)
		row.add_child(cb)

		var value_label: Label = null
		var minus_btn: Button = null
		var plus_btn: Button = null
		if def_item[2]:
			# Initialize value in dictionary
			_effect_values[def_item[0]] = 0  # Default to 0 = not set

			# Custom spinbox: [- button] [value label] [+ button]
			var spin_hbox = HBoxContainer.new()
			spin_hbox.add_theme_constant_override("separation", 2)

			minus_btn = Button.new()
			minus_btn.text = "-"
			minus_btn.custom_minimum_size = Vector2(40, 40)
			minus_btn.add_theme_font_size_override("font_size", 24)
			minus_btn.add_theme_color_override("font_color", TEXT_COLOR)
			_style_spin_button(minus_btn)
			minus_btn.pressed.connect(_on_spin_minus.bind(def_item[0], def_item[4], def_item[5]))
			spin_hbox.add_child(minus_btn)

			value_label = Label.new()
			value_label.text = "0"
			value_label.custom_minimum_size = Vector2(50, 40)
			value_label.add_theme_font_size_override("font_size", 22)
			value_label.add_theme_color_override("font_color", TEXT_COLOR)
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			# Background style for value label
			var val_style = StyleBoxFlat.new()
			val_style.bg_color = INPUT_BG
			val_style.border_color = BORDER_COLOR
			val_style.border_width_left = 1
			val_style.border_width_right = 1
			val_style.border_width_top = 1
			val_style.border_width_bottom = 1
			val_style.corner_radius_top_left = 3
			val_style.corner_radius_top_right = 3
			val_style.corner_radius_bottom_left = 3
			val_style.corner_radius_bottom_right = 3
			value_label.add_theme_stylebox_override("normal", val_style)
			spin_hbox.add_child(value_label)

			plus_btn = Button.new()
			plus_btn.text = "+"
			plus_btn.custom_minimum_size = Vector2(40, 40)
			plus_btn.add_theme_font_size_override("font_size", 24)
			plus_btn.add_theme_color_override("font_color", TEXT_COLOR)
			_style_spin_button(plus_btn)
			plus_btn.pressed.connect(_on_spin_plus.bind(def_item[0], def_item[4], def_item[5]))
			spin_hbox.add_child(plus_btn)

			row.add_child(spin_hbox)

		target_col.add_child(row)

		effect_rows.append({
			"key": def_item[0],
			"label": def_item[1],
			"checkbox": cb,
			"spinbox": null,
			"value_label": value_label,
			"minus_btn": minus_btn,
			"plus_btn": plus_btn,
			"default_value": def_item[3] if def_item[2] else 0,
			"min_val": def_item[4] if def_item[2] else 0,
			"max_val": def_item[5] if def_item[2] else 0,
		})

# =============================================================================
# UI HELPERS
# =============================================================================

func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", ACCENT_GOLD)
	parent.add_child(lbl)

var _cached_unchecked_icon: ImageTexture = null
var _cached_checked_icon: ImageTexture = null

func _get_unchecked_icon() -> ImageTexture:
	if _cached_unchecked_icon != null:
		return _cached_unchecked_icon
	var size := 28
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	# White filled square with dark border
	img.fill(Color(0.9, 0.9, 0.9, 1.0))
	# Draw border (2px)
	for i in range(size):
		for b in range(2):
			img.set_pixel(i, b, Color(0.4, 0.35, 0.25, 1.0))
			img.set_pixel(i, size - 1 - b, Color(0.4, 0.35, 0.25, 1.0))
			img.set_pixel(b, i, Color(0.4, 0.35, 0.25, 1.0))
			img.set_pixel(size - 1 - b, i, Color(0.4, 0.35, 0.25, 1.0))
	_cached_unchecked_icon = ImageTexture.create_from_image(img)
	return _cached_unchecked_icon

func _get_checked_icon() -> ImageTexture:
	if _cached_checked_icon != null:
		return _cached_checked_icon
	var size := 28
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	# White filled square with gold border
	img.fill(Color(0.9, 0.9, 0.9, 1.0))
	# Draw border (2px) in gold
	for i in range(size):
		for b in range(2):
			img.set_pixel(i, b, Color(0.85, 0.7, 0.15, 1.0))
			img.set_pixel(i, size - 1 - b, Color(0.85, 0.7, 0.15, 1.0))
			img.set_pixel(b, i, Color(0.85, 0.7, 0.15, 1.0))
			img.set_pixel(size - 1 - b, i, Color(0.85, 0.7, 0.15, 1.0))
	# Draw green checkmark (thick diagonal lines)
	var check_color := Color(0.1, 0.65, 0.1, 1.0)
	# Short leg: from (5,14) to (10,20)
	for t in range(30):
		var p := float(t) / 29.0
		var x := int(lerp(5.0, 11.0, p))
		var y := int(lerp(13.0, 21.0, p))
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var px := clampi(x + dx, 0, size - 1)
				var py := clampi(y + dy, 0, size - 1)
				img.set_pixel(px, py, check_color)
	# Long leg: from (10,20) to (23,6)
	for t in range(40):
		var p := float(t) / 39.0
		var x := int(lerp(11.0, 23.0, p))
		var y := int(lerp(21.0, 5.0, p))
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var px := clampi(x + dx, 0, size - 1)
				var py := clampi(y + dy, 0, size - 1)
				img.set_pixel(px, py, check_color)
	_cached_checked_icon = ImageTexture.create_from_image(img)
	return _cached_checked_icon

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

func _style_spin_button(btn: Button) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = BUTTON_NORMAL
	style.border_color = BORDER_COLOR
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate() as StyleBoxFlat
	hover.bg_color = BUTTON_HOVER
	btn.add_theme_stylebox_override("hover", hover)
	var pressed_style = style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = BUTTON_SELECTED
	btn.add_theme_stylebox_override("pressed", pressed_style)

func _on_spin_minus(effect_key: String, min_val: int, _max_val: int) -> void:
	if _effect_values.has(effect_key):
		_effect_values[effect_key] = maxi(min_val, _effect_values[effect_key] - 1)
		_refresh_value_label(effect_key)
		_auto_check_by_value(effect_key)
		_update_preview()

func _on_spin_plus(effect_key: String, _min_val: int, max_val: int) -> void:
	if _effect_values.has(effect_key):
		_effect_values[effect_key] = mini(max_val, _effect_values[effect_key] + 1)
		_refresh_value_label(effect_key)
		_auto_check_by_value(effect_key)
		_update_preview()

func _auto_check_by_value(effect_key: String) -> void:
	## Auto-check/uncheck based on value: non-zero = checked, zero = unchecked
	for row in effect_rows:
		if row["key"] == effect_key:
			var val: int = _effect_values.get(effect_key, 0)
			if val > 0 and not row["checkbox"].button_pressed:
				row["checkbox"].button_pressed = true
			elif val <= 0 and row["checkbox"].button_pressed:
				row["checkbox"].button_pressed = false
			break

func _refresh_value_label(effect_key: String) -> void:
	for row in effect_rows:
		if row["key"] == effect_key and row["value_label"] != null:
			row["value_label"].text = str(_effect_values[effect_key])
			break

# =============================================================================
# INPUT HANDLERS
# =============================================================================

func _on_any_input_changed_text(_text: String) -> void:
	_update_preview()

func _on_any_input_changed_bool(_val: bool) -> void:
	# When a checkbox is checked and its value is 0, auto-set default value
	if _val:
		for row in effect_rows:
			if row["checkbox"].button_pressed and row["value_label"] != null:
				var key: String = row["key"]
				if _effect_values.has(key) and _effect_values[key] <= 0:
					var def_val: int = row.get("default_value", 1)
					if def_val > 0:
						_effect_values[key] = def_val
						row["value_label"].text = str(def_val)
	_update_preview()

func _on_any_input_changed_float(_val: float) -> void:
	_update_preview()

func _on_custom_desc_changed() -> void:
	_update_preview()

func _on_cost_selected(cost_value: int, index: int) -> void:
	selected_cost = cost_value
	_highlight_button_group(cost_buttons, index)
	_update_preview()

func _on_type_selected(type_index: int) -> void:
	selected_type = type_index
	_highlight_button_group(type_buttons, type_index)
	# Show/hide power trigger timing UI
	var is_power: bool = (type_index == 2)
	if trigger_section_label:
		trigger_section_label.visible = is_power
	if trigger_row:
		trigger_row.visible = is_power
	# Update effect row visibility based on type and trigger
	_update_effect_visibility()
	_update_preview()

func _on_trigger_selected(trigger_id: String, index: int) -> void:
	selected_power_trigger = trigger_id
	_highlight_button_group(trigger_buttons, index)
	_update_effect_visibility()
	_update_preview()

## Permanent power effects: only strength, dexterity, extra_draw
## turn_start/turn_end: show same effects as Attack/Skill
const PERMANENT_ONLY_KEYS: Array = ["strength", "dexterity", "gain_energy"]

func _update_effect_visibility() -> void:
	var is_permanent_power: bool = (selected_type == 2 and selected_power_trigger == "permanent")
	for row in effect_rows:
		var key: String = row["key"]
		if is_permanent_power:
			# Only show strength, dexterity, gain_energy (extra draw mapped to gain_energy),
			# plus draw for extra_draw
			var visible_keys: Array = ["strength", "dexterity", "draw"]
			var visible: bool = key in visible_keys
			row["checkbox"].get_parent().visible = visible
			if not visible:
				row["checkbox"].button_pressed = false
		else:
			row["checkbox"].get_parent().visible = true

func _on_char_selected(char_id: String, index: int) -> void:
	selected_character = char_id
	_highlight_button_group(char_buttons, index)
	_update_preview()

func _on_version_selected(ver_id: String, index: int) -> void:
	selected_version = ver_id
	_highlight_button_group(version_buttons, index)

func _on_status_selected(st_id: String, index: int) -> void:
	selected_status = st_id
	_highlight_button_group(status_buttons, index)

# =============================================================================
# CARD DATA BUILDING
# =============================================================================

func _build_card_data() -> Dictionary:
	var card_name: String = name_edit.text.strip_edges()
	if card_name.is_empty():
		card_name = "自定义卡牌"

	# Use existing card ID when editing, otherwise generate a new one
	var card_id: String = ""
	if _editing_card_id != "":
		card_id = _editing_card_id
	else:
		card_id = "custom_" + card_name.to_lower().replace(" ", "_").replace("/", "_")

	var data: Dictionary = {
		"id": card_id,
		"name": card_name,
		"cost": selected_cost,
		"type": selected_type,
		"character": selected_character,
		"damage": 0,
		"block": 0,
		"description": "",
		"art": _editing_art_path,
		"target": "self",
		"actions": [],
	}

	# Add power_trigger field for Power cards
	if selected_type == 2:
		data["power_trigger"] = selected_power_trigger

	var actions: Array = []
	var desc_parts: Array = []
	var has_damage: bool = false
	var is_aoe: bool = false
	var target_enemy: bool = false

	for row in effect_rows:
		if not row["checkbox"].button_pressed:
			continue
		var key: String = row["key"]
		var value: int = _effect_values[key] if _effect_values.has(key) else 0
		# Skip effects with value 0 (for effects that have a spinbox/value control)
		var needs_value: bool = (row["value_label"] != null)
		if needs_value and value <= 0:
			continue

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

	# Handle target_all_enemies / target_all_heroes checkboxes
	for row in effect_rows:
		if not row["checkbox"].button_pressed:
			continue
		match row["key"]:
			"target_all_enemies":
				data["target"] = "all_enemies"
				desc_parts.append("（对所有怪物）")
			"target_all_heroes":
				data["target"] = "all_heroes"
				desc_parts.append("（对所有英雄）")

	# Set target based on effects
	if target_enemy and not is_aoe and data["target"] == "self":
		data["target"] = "enemy"

	data["actions"] = actions
	data["description"] = "\n".join(desc_parts)
	# Version and status from UI toggles
	data["version"] = selected_version
	data["status"] = selected_status

	# Append custom description text if provided
	var custom_text: String = ""
	if custom_desc_edit != null:
		custom_text = custom_desc_edit.text.strip_edges()
	if not custom_text.is_empty():
		data["custom_description"] = custom_text
		if data["description"].is_empty():
			data["description"] = custom_text
		else:
			data["description"] += "\n" + custom_text

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
	var preview_size = Vector2(384, 594)

	_preview_node = CardScript.create_card_visual(card_data, preview_size)
	preview_container.add_child(_preview_node)

	# Sync text parse area with current effects description
	if _text_parse_edit != null:
		_text_parse_edit.text = card_data["description"]

# =============================================================================
# SAVE / BACK
# =============================================================================

func _on_save_pressed() -> void:
	var card_data = _build_card_data()

	var gm = _get_game_manager()
	if gm == null or not (gm.card_database is Dictionary):
		return

	if _editing_card_id != "":
		# Overwrite existing card
		var card_id = _editing_card_id
		card_data["id"] = card_id
		# Preserve art from original if present
		if gm.card_database.has(card_id) and gm.card_database[card_id].has("art"):
			card_data["art"] = gm.card_database[card_id]["art"]
		gm.card_database[card_id] = card_data
		gm.save_custom_cards()
		_flash_save_feedback()
	else:
		# Generate unique ID with counter
		_card_counter += 1
		var card_id = "custom_%04d_%s" % [_card_counter, card_data["name"].to_lower().replace(" ", "_")]
		card_data["id"] = card_id
		gm.card_database[card_id] = card_data
		gm.save_custom_cards()
		_flash_save_feedback()

func _on_save_as_new_pressed() -> void:
	var card_data = _build_card_data()

	var gm = _get_game_manager()
	if gm == null or not (gm.card_database is Dictionary):
		return

	# Always create a new card with a new unique ID
	_card_counter += 1
	var card_id = "custom_%04d_%s" % [_card_counter, card_data["name"].to_lower().replace(" ", "_")]
	card_data["id"] = card_id
	# Do not carry over art from original
	card_data.erase("art")
	gm.card_database[card_id] = card_data
	gm.save_custom_cards()

	# Switch to editing the newly created card
	_editing_card_id = card_id
	_editing_art_path = ""
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

# =============================================================================
# CARD BROWSER (Select existing card for editing)
# =============================================================================

func _show_card_browser() -> void:
	if _browser_overlay != null:
		_browser_overlay.queue_free()
		_browser_overlay = null

	var gm = _get_game_manager()
	if gm == null or not (gm.card_database is Dictionary):
		return

	# Full-screen overlay
	_browser_overlay = Control.new()
	_browser_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_browser_overlay.z_index = 100
	add_child(_browser_overlay)

	# Dark background
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_browser_overlay.add_child(bg)

	# Main VBox
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	_browser_overlay.add_child(vbox)

	# Top bar with title + close button
	var top_bar = HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 60)
	top_bar.add_theme_constant_override("separation", 16)
	vbox.add_child(top_bar)

	var spacer_left = Control.new()
	spacer_left.custom_minimum_size = Vector2(20, 0)
	top_bar.add_child(spacer_left)

	var title_lbl = Label.new()
	title_lbl.text = "选择卡牌编辑"
	title_lbl.add_theme_font_size_override("font_size", 32)
	title_lbl.add_theme_color_override("font_color", ACCENT_GOLD)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_bar.add_child(title_lbl)

	var close_btn = _create_action_button("关闭", ACCENT_RED)
	close_btn.custom_minimum_size = Vector2(100, 44)
	close_btn.pressed.connect(_close_card_browser)
	top_bar.add_child(close_btn)

	var spacer_right = Control.new()
	spacer_right.custom_minimum_size = Vector2(20, 0)
	top_bar.add_child(spacer_right)

	# Scroll container with card grid
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	# Collect and sort all cards
	var cards: Array = []
	for card_id in gm.card_database:
		var card = gm.card_database[card_id]
		# Skip status cards (type 3)
		if card.get("type", 0) == 3:
			continue
		cards.append(card)

	cards.sort_custom(func(a, b):
		if a.get("character", "") != b.get("character", ""):
			return a.get("character", "") < b.get("character", "")
		if a.get("type", 0) != b.get("type", 0):
			return a.get("type", 0) < b.get("type", 0)
		return a.get("name", "") < b.get("name", "")
	)

	var card_size = Vector2(220, 341)
	for card in cards:
		var card_visual = CardScript.create_card_visual(card, card_size)
		card_visual.custom_minimum_size = card_size
		card_visual.mouse_filter = Control.MOUSE_FILTER_PASS
		# Make child panels pass-through for clicks
		for child in card_visual.get_children():
			if child is Panel or child is Control:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var card_id: String = card.get("id", "")
		card_visual.gui_input.connect(_on_browser_card_clicked.bind(card_id))
		grid.add_child(card_visual)

func _close_card_browser() -> void:
	if _browser_overlay != null:
		_browser_overlay.queue_free()
		_browser_overlay = null

func _on_browser_card_clicked(event: InputEvent, card_id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	var gm = _get_game_manager()
	if gm == null or not gm.card_database.has(card_id):
		return

	var card_data: Dictionary = gm.card_database[card_id]
	_close_card_browser()
	_load_card_for_edit(card_data)

# =============================================================================
# LOAD CARD FOR EDIT
# =============================================================================

func _load_card_for_edit(card_data: Dictionary) -> void:
	_editing_card_id = card_data.get("id", "")
	_editing_art_path = card_data.get("art", "")

	# --- Name ---
	name_edit.text = card_data.get("name", "")

	# --- Cost ---
	var cost_val: int = card_data.get("cost", 1)
	selected_cost = cost_val
	var cost_values = [0, 1, 2, 3, -1]
	var cost_idx: int = cost_values.find(cost_val)
	if cost_idx < 0:
		cost_idx = 1
	_highlight_button_group(cost_buttons, cost_idx)

	# --- Type ---
	var type_val: int = card_data.get("type", 0)
	selected_type = type_val
	_highlight_button_group(type_buttons, type_val)
	# Show/hide power trigger UI
	var is_power: bool = (type_val == 2)
	if trigger_section_label:
		trigger_section_label.visible = is_power
	if trigger_row:
		trigger_row.visible = is_power

	# --- Power Trigger ---
	if is_power and card_data.has("power_trigger"):
		var trigger_id: String = card_data["power_trigger"]
		selected_power_trigger = trigger_id
		var trigger_ids = ["turn_start", "turn_end", "permanent"]
		var trigger_idx = trigger_ids.find(trigger_id)
		if trigger_idx >= 0:
			_highlight_button_group(trigger_buttons, trigger_idx)

	# --- Character ---
	var char_id: String = card_data.get("character", "ironclad")
	selected_character = char_id
	var char_ids = ["ironclad", "silent", "neutral"]
	var char_idx = char_ids.find(char_id)
	if char_idx < 0:
		char_idx = 0
	_highlight_button_group(char_buttons, char_idx)

	# --- Version ---
	var ver_id: String = card_data.get("version", "old")
	selected_version = ver_id
	var ver_ids = ["new", "old"]
	var ver_idx = ver_ids.find(ver_id)
	if ver_idx < 0:
		ver_idx = 1  # Default to "old"
	_highlight_button_group(version_buttons, ver_idx)

	# --- Status ---
	var st_id: String = card_data.get("status", "active")
	selected_status = st_id
	var st_ids = ["active", "incomplete", "deprecated"]
	var st_idx = st_ids.find(st_id)
	if st_idx < 0:
		st_idx = 0
	_highlight_button_group(status_buttons, st_idx)

	# --- Reset all effect checkboxes and values to 0 ---
	for row in effect_rows:
		row["checkbox"].button_pressed = false
		var key: String = row["key"]
		if _effect_values.has(key):
			_effect_values[key] = 0
		if row["value_label"] != null:
			row["value_label"].text = "0"

	# --- Parse card data to set effects ---
	# Damage
	var damage_val: int = card_data.get("damage", 0)
	if damage_val > 0:
		_set_effect("damage", true, damage_val)

	# AOE (damage_all)
	var target: String = card_data.get("target", "self")
	if target == "all_enemies":
		_set_effect("damage_all", true)

	# Block
	var block_val: int = card_data.get("block", 0)
	if block_val > 0:
		_set_effect("block", true, block_val)

	# Draw
	var draw_val: int = card_data.get("draw", 0)
	if draw_val > 0:
		_set_effect("draw", true, draw_val)

	# Multi-hit
	var times_val: int = card_data.get("times", 0)
	if times_val >= 2:
		_set_effect("multi_hit", true, times_val)

	# Exhaust, Ethereal, Innate
	if card_data.get("exhaust", false):
		_set_effect("exhaust", true)
	if card_data.get("ethereal", false):
		_set_effect("ethereal", true)
	if card_data.get("innate", false):
		_set_effect("innate", true)

	# Sly
	if card_data.get("special", "") == "sly":
		_set_effect("sly", true)

	# Apply status effects (vulnerable, weak, poison)
	_parse_status_field(card_data, "apply_status")
	_parse_status_field(card_data, "apply_status_2")

	# Parse actions for self-applied statuses and other effects
	var uncovered_actions: Array = []
	var actions: Array = card_data.get("actions", [])
	for action in actions:
		var atype: String = action.get("type", "")
		match atype:
			"apply_self_status":
				var status: String = action.get("status", "")
				var stacks: int = action.get("stacks", 1)
				if status == "strength":
					_set_effect("strength", true, stacks)
				elif status == "dexterity":
					_set_effect("dexterity", true, stacks)
				else:
					uncovered_actions.append(action)
			"self_damage":
				_set_effect("self_damage", true, action.get("value", 2))
			"gain_energy":
				if action.get("next_turn", false):
					_set_effect("next_turn_energy", true, action.get("value", 1))
				else:
					_set_effect("gain_energy", true, action.get("value", 1))
			"heal":
				_set_effect("heal", true, action.get("value", 5))
			"add_shiv":
				_set_effect("add_shiv", true, action.get("value", 1))
			"block":
				if action.get("next_turn", false):
					_set_effect("next_turn_block", true, action.get("value", 5))
				# Normal block is handled by card_data["block"] above
			"damage", "damage_all", "draw", "apply_status":
				pass  # Handled above via card_data fields
			"call":
				uncovered_actions.append(action)
			_:
				uncovered_actions.append(action)

	# --- Custom description ---
	# Check for custom_description field, or build from uncovered actions / special fields
	var custom_text: String = card_data.get("custom_description", "")
	if custom_text.is_empty():
		# Detect special fields not covered by checkboxes
		var special_parts: Array = []
		var special: String = card_data.get("special", "")
		if special != "" and special != "sly":
			special_parts.append("special: %s" % special)
		for action in uncovered_actions:
			special_parts.append(str(action))
		# Check for other exotic fields
		for exotic_key in ["str_mult", "strike_bonus", "rampage_inc", "max_hp_gain", "unplayable"]:
			if card_data.has(exotic_key):
				special_parts.append("%s: %s" % [exotic_key, str(card_data[exotic_key])])
		custom_text = "\n".join(special_parts)
	if custom_desc_edit != null:
		custom_desc_edit.text = custom_text

	# --- Update visibility and preview ---
	_update_effect_visibility()
	_update_preview()

	# --- Switch buttons to edit mode ---
	save_button.text = "保存修改"
	save_as_new_button.visible = true

func _set_effect(key: String, enabled: bool, value: int = 0) -> void:
	for row in effect_rows:
		if row["key"] == key:
			row["checkbox"].button_pressed = enabled
			if value > 0 and _effect_values.has(key):
				_effect_values[key] = value
				if row["value_label"] != null:
					row["value_label"].text = str(value)
			break

func _parse_status_field(card_data: Dictionary, field_name: String) -> void:
	if not card_data.has(field_name):
		return
	var status_data: Dictionary = card_data[field_name]
	var status_type: String = status_data.get("type", "")
	var stacks: int = status_data.get("stacks", 1)
	match status_type:
		"vulnerable":
			_set_effect("vulnerable", true, stacks)
		"weak":
			_set_effect("weak", true, stacks)
		"poison":
			_set_effect("poison", true, stacks)

func _get_game_manager() -> Node:
	for child in get_tree().root.get_children():
		if child.name == "GameManager":
			return child
	return null
