extends Node2D
## res://scripts/entity.gd — Base class for player and enemies: HP, block, status effects

signal hp_changed(current: int, max_val: int)
signal block_changed(amount: int)
signal status_changed(status_type: String, stacks: int)
signal died

@export var max_hp: int = 80
@export var is_enemy: bool = false
@export var damage_number_font_size: int = 36  ## Font size for floating damage numbers
@export var status_float_font_size: int = 28  ## Font size for floating status text

var current_hp: int = 80
var block: int = 0
var status_effects: Dictionary = {}
var enemy_type: String = ""
var intent: Dictionary = {}
var alive: bool = true
var power_effects: Array = []
var active_powers: Dictionary = {}  # power_id -> stack count
var _previous_block: int = 0  # Track previous block value for break detection

# Node references
var sprite_node: Sprite2D = null
var hp_bar_bg: ColorRect = null
var hp_bar_fill: ColorRect = null
var hp_label: Label = null
var block_label: Label = null
var intent_icon: TextureRect = null
var intent_label: Label = null
var status_container: HBoxContainer = null
var name_label: Label = null
var _active_tooltip: Label = null  # Currently shown status tooltip

# Chinese names for status effects and powers
const STATUS_NAMES: Dictionary = {
	"strength": "力量",
	"dexterity": "敏捷",
	"vulnerable": "易伤",
	"weak": "虚弱",
	"poison": "中毒",
}
const POWER_NAMES: Dictionary = {
	"demon_form": "恶魔形态",
	"caltrops": "蒺藜",
	"envenom": "淬毒",
	"flame_barrier": "烈焰屏障",
	"corruption": "腐化",
	"berserk": "狂暴",
	"feel_no_pain": "无痛",
	"juggernaut": "主宰",
	"evolve": "进化",
	"rage": "怒火",
	"barricade": "壁垒",
	"metallicize": "金属化",
	"accuracy": "精准",
	"infinite_blades": "无限刀刃",
	"noxious_fumes": "剧毒烟雾",
	"a_thousand_cuts": "千刀万剐",
	"after_image": "残影",
}

func _ready() -> void:
	current_hp = max_hp
	_setup_visuals()

func _setup_visuals() -> void:
	# Find child nodes by name
	sprite_node = get_node_or_null("Sprite") as Sprite2D
	hp_bar_bg = get_node_or_null("HPBarBG") as ColorRect
	hp_bar_fill = get_node_or_null("HPBarBG/HPBarFill") as ColorRect
	hp_label = get_node_or_null("HPLabel") as Label
	block_label = get_node_or_null("BlockLabel") as Label
	intent_icon = get_node_or_null("IntentIcon") as TextureRect
	intent_label = get_node_or_null("IntentLabel") as Label
	status_container = get_node_or_null("StatusContainer") as HBoxContainer
	name_label = get_node_or_null("NameLabel") as Label
	_update_hp_bar()
	_update_block_display()

func init_entity(hp: int, enemy: bool, etype: String = "") -> void:
	max_hp = hp
	current_hp = hp
	is_enemy = enemy
	enemy_type = etype
	alive = true
	block = 0
	status_effects = {}
	power_effects = []
	active_powers = {}

func take_damage(amount: int) -> void:
	if not alive:
		return
	var actual_damage: int = amount
	# Check vulnerable
	if status_effects.has("vulnerable") and status_effects["vulnerable"] > 0:
		actual_damage = int(ceil(float(actual_damage) * 1.5))
	# Block absorbs damage first
	if block > 0:
		if block >= actual_damage:
			block -= actual_damage
			actual_damage = 0
		else:
			actual_damage -= block
			block = 0
		block_changed.emit(block)
		_update_block_display()
	current_hp -= actual_damage
	if current_hp <= 0:
		current_hp = 0
		alive = false
		hp_changed.emit(current_hp, max_hp)
		_update_hp_bar()
		_play_death()
		died.emit()
	else:
		hp_changed.emit(current_hp, max_hp)
		_update_hp_bar()
		_flash_damage(actual_damage)

func take_damage_direct(amount: int) -> void:
	## Deal damage bypassing block (e.g. self-harm effects like Offering, Hemokinesis)
	if not alive:
		return
	current_hp -= amount
	if current_hp <= 0:
		current_hp = 0
		alive = false
		hp_changed.emit(current_hp, max_hp)
		_update_hp_bar()
		_play_death()
		died.emit()
	else:
		hp_changed.emit(current_hp, max_hp)
		_update_hp_bar()

func get_status_stacks(status_type: String) -> int:
	if status_effects.has(status_type):
		return status_effects[status_type]
	return 0

func heal(amount: int) -> void:
	if not alive:
		return
	current_hp = mini(current_hp + amount, max_hp)
	hp_changed.emit(current_hp, max_hp)
	_update_hp_bar()

func add_block(amount: int) -> void:
	if not alive:
		return
	var actual_block: int = amount
	# Add dexterity bonus
	if status_effects.has("dexterity") and status_effects["dexterity"] > 0:
		actual_block += status_effects["dexterity"]
	block += actual_block
	block_changed.emit(block)
	_update_block_display()
	_flash_block()

func apply_status(status_type: String, stacks: int) -> void:
	if not alive:
		return
	if status_effects.has(status_type):
		status_effects[status_type] += stacks
	else:
		status_effects[status_type] = stacks
	status_changed.emit(status_type, status_effects[status_type])
	_update_status_display()
	# Floating status text animation (like STS "Vulnerable" text)
	_show_status_float(status_type, stacks)

func tick_poison() -> void:
	## Tick poison: deal poison damage (bypass block), reduce by 1, show float
	if not alive:
		return
	if not status_effects.has("poison") or status_effects["poison"] <= 0:
		return
	var poison_dmg: int = status_effects["poison"]
	# Deal damage bypassing block
	current_hp -= poison_dmg
	# Show floating poison damage (green)
	_flash_poison_damage(poison_dmg)
	if current_hp <= 0:
		current_hp = 0
		alive = false
		hp_changed.emit(current_hp, max_hp)
		_update_hp_bar()
		_play_death()
		died.emit()
	else:
		hp_changed.emit(current_hp, max_hp)
		_update_hp_bar()
	# Reduce poison by 1
	status_effects["poison"] -= 1
	if status_effects["poison"] <= 0:
		status_effects.erase("poison")
		status_changed.emit("poison", 0)
	else:
		status_changed.emit("poison", status_effects["poison"])
	_update_status_display()

func tick_status_effects() -> void:
	var to_remove: Array = []
	for status_type in status_effects:
		if status_type in ["vulnerable", "weak"]:
			status_effects[status_type] -= 1
			if status_effects[status_type] <= 0:
				to_remove.append(status_type)
			else:
				status_changed.emit(status_type, status_effects[status_type])
	for s in to_remove:
		status_effects.erase(s)
		status_changed.emit(s, 0)
		_show_status_wear_off(s)
	_update_status_display()

func reset_block() -> void:
	block = 0
	_previous_block = 0  # Skip shatter effect on turn-start reset
	block_changed.emit(block)
	_update_block_display()

func get_attack_damage(base_damage: int) -> int:
	var dmg: int = base_damage
	# Add strength bonus
	if status_effects.has("strength") and status_effects["strength"] > 0:
		dmg += status_effects["strength"]
	# Apply weak penalty
	if status_effects.has("weak") and status_effects["weak"] > 0:
		dmg = int(floor(float(dmg) * 0.75))
	return maxi(0, dmg)

func _update_hp_bar() -> void:
	if hp_bar_fill == null or hp_bar_bg == null:
		return
	var ratio: float = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
	hp_bar_fill.size.x = hp_bar_bg.size.x * ratio
	# Color gradient per spec: red base, orange-red when critical (<25%)
	if ratio > 0.5:
		hp_bar_fill.color = Color(0.800, 0.133, 0.133, 1.0)  # Standard red
	elif ratio > 0.25:
		hp_bar_fill.color = Color(0.9, 0.5, 0.1, 1.0)  # Yellow-orange warning
	else:
		hp_bar_fill.color = Color(1.0, 0.4, 0.1, 1.0)  # Orange-red critical per spec
	if hp_label:
		hp_label.text = str(current_hp) + "/" + str(max_hp)

func _update_block_display() -> void:
	if block_label == null:
		return
	if block > 0:
		block_label.text = " " + str(block) + " "
		block_label.visible = true
		# Ensure blue background panel is applied for visibility
		if not block_label.has_theme_stylebox_override("normal"):
			var block_bg = StyleBoxFlat.new()
			block_bg.bg_color = Color(0.15, 0.3, 0.7, 0.9)
			block_bg.border_color = Color(0.4, 0.6, 1.0, 1.0)
			block_bg.border_width_left = 2
			block_bg.border_width_right = 2
			block_bg.border_width_top = 2
			block_bg.border_width_bottom = 2
			block_bg.corner_radius_top_left = 6
			block_bg.corner_radius_top_right = 6
			block_bg.corner_radius_bottom_left = 6
			block_bg.corner_radius_bottom_right = 6
			block_bg.content_margin_left = 4
			block_bg.content_margin_right = 4
			block_bg.content_margin_top = 2
			block_bg.content_margin_bottom = 2
			block_label.add_theme_stylebox_override("normal", block_bg)
		_previous_block = block
	else:
		# Block just broke — trigger shatter effect if it was > 0 before
		if _previous_block > 0:
			_flash_block_break()
		_previous_block = 0
		block_label.visible = false

func _update_status_display() -> void:
	if status_container == null:
		return
	# Clear existing
	for child in status_container.get_children():
		child.queue_free()
	# Add status icons
	for status_type in status_effects:
		if status_effects[status_type] <= 0:
			continue
		var icon_path: String = "res://assets/img/ui_icons/" + status_type + ".png"
		var tex = load(icon_path)
		if tex == null:
			continue
		var container = HBoxContainer.new()
		container.mouse_filter = Control.MOUSE_FILTER_PASS
		var status_name: String = STATUS_NAMES.get(status_type, status_type)
		var stacks: int = status_effects[status_type]
		container.gui_input.connect(_on_status_icon_clicked.bind(container, status_name, stacks))
		var icon = TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(icon)
		var lbl = Label.new()
		lbl.text = str(status_effects[status_type])
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if status_type == "poison":
			lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		else:
			lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.7))
		container.add_child(lbl)
		status_container.add_child(container)
	# Add active power icons
	var power_icon_map: Dictionary = {
		"demon_form": "fire",
		"caltrops": "lightning",
		"envenom": "poison",
		"flame_barrier": "fire",
		"corruption": "death",
		"berserk": "fire",
		"feel_no_pain": "dexterity",
		"juggernaut": "strength",
		"evolve": "eye",
		"rage": "fire",
		"barricade": "dexterity",
		"metallicize": "strength",
		"accuracy": "lightning",
		"infinite_blades": "lightning",
		"noxious_fumes": "poison",
		"a_thousand_cuts": "lightning",
		"after_image": "dexterity",
	}
	for power_id in active_powers:
		if active_powers[power_id] <= 0:
			continue
		var icon_name: String = power_icon_map.get(power_id, "hourglass")
		var icon_path: String = "res://assets/img/ui_icons/" + icon_name + ".png"
		var tex = load(icon_path)
		if tex == null:
			continue
		var container = HBoxContainer.new()
		# Power background badge
		var badge = Panel.new()
		var badge_style = StyleBoxFlat.new()
		badge_style.bg_color = Color(0.4, 0.15, 0.6, 0.85)
		badge_style.corner_radius_top_left = 6
		badge_style.corner_radius_top_right = 6
		badge_style.corner_radius_bottom_left = 6
		badge_style.corner_radius_bottom_right = 6
		badge_style.content_margin_left = 2
		badge_style.content_margin_right = 2
		badge_style.content_margin_top = 2
		badge_style.content_margin_bottom = 2
		badge.add_theme_stylebox_override("panel", badge_style)
		badge.custom_minimum_size = Vector2(36, 36)
		var icon = TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(4, 4)
		badge.add_child(icon)
		container.add_child(badge)
		var lbl = Label.new()
		if active_powers[power_id] > 1:
			lbl.text = str(active_powers[power_id])
		else:
			lbl.text = ""
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
		container.add_child(lbl)
		status_container.add_child(container)

func update_intent_display() -> void:
	if intent.is_empty():
		if intent_icon:
			intent_icon.visible = false
		if intent_label:
			intent_label.visible = false
		return
	if intent_icon:
		var icon_name: String = intent.get("intent", "attack")
		var tex = load("res://assets/img/ui_icons/" + icon_name + "_intent.png")
		if tex:
			intent_icon.texture = tex
			intent_icon.visible = true
	if intent_label:
		var desc: String = intent.get("desc", "")
		intent_label.text = desc
		intent_label.visible = true

func _flash_damage(damage_amount: int = 0) -> void:
	if sprite_node == null:
		return
	var tween = create_tween()
	tween.tween_property(sprite_node, "modulate", Color(1.0, 0.3, 0.3), 0.1)
	tween.tween_property(sprite_node, "modulate", Color.WHITE, 0.2)
	# Floating damage number
	if damage_amount <= 0:
		return
	var dmg_label = Label.new()
	dmg_label.text = "-" + str(damage_amount)
	dmg_label.add_theme_font_size_override("font_size", damage_number_font_size)
	dmg_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	dmg_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	dmg_label.add_theme_constant_override("shadow_offset_x", 1)
	dmg_label.add_theme_constant_override("shadow_offset_y", 2)
	dmg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dmg_label.position = Vector2(-40, -100)
	add_child(dmg_label)
	var float_tween = create_tween()
	float_tween.set_parallel(true)
	float_tween.tween_property(dmg_label, "position:y", dmg_label.position.y - 80, 0.8)
	float_tween.tween_property(dmg_label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	float_tween.set_parallel(false)
	float_tween.tween_callback(dmg_label.queue_free)

func _flash_poison_damage(damage_amount: int) -> void:
	if sprite_node == null:
		return
	var tween = create_tween()
	tween.tween_property(sprite_node, "modulate", Color(0.3, 1.0, 0.3), 0.1)
	tween.tween_property(sprite_node, "modulate", Color.WHITE, 0.2)
	if damage_amount <= 0:
		return
	var dmg_label = Label.new()
	dmg_label.text = "-" + str(damage_amount)
	dmg_label.add_theme_font_size_override("font_size", damage_number_font_size)
	dmg_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
	dmg_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	dmg_label.add_theme_constant_override("shadow_offset_x", 1)
	dmg_label.add_theme_constant_override("shadow_offset_y", 2)
	dmg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dmg_label.position = Vector2(-40, -100)
	add_child(dmg_label)
	var float_tween = create_tween()
	float_tween.set_parallel(true)
	float_tween.tween_property(dmg_label, "position:y", dmg_label.position.y - 80, 0.8)
	float_tween.tween_property(dmg_label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	float_tween.set_parallel(false)
	float_tween.tween_callback(dmg_label.queue_free)

func _flash_block() -> void:
	if sprite_node == null:
		return
	var tween = create_tween()
	tween.tween_property(sprite_node, "modulate", Color(0.6, 0.7, 1.3), 0.1)
	tween.tween_property(sprite_node, "modulate", Color.WHITE, 0.2)

func _flash_block_break() -> void:
	## Brief orange flash + shake when block breaks (goes to 0)
	if block_label == null:
		return
	# Briefly show the label with orange flash before hiding
	block_label.text = " 0 "
	block_label.visible = true
	var break_bg = StyleBoxFlat.new()
	break_bg.bg_color = Color(1.0, 0.5, 0.1, 0.95)
	break_bg.border_color = Color(1.0, 0.8, 0.3, 1.0)
	break_bg.border_width_left = 2
	break_bg.border_width_right = 2
	break_bg.border_width_top = 2
	break_bg.border_width_bottom = 2
	break_bg.corner_radius_top_left = 6
	break_bg.corner_radius_top_right = 6
	break_bg.corner_radius_bottom_left = 6
	break_bg.corner_radius_bottom_right = 6
	break_bg.content_margin_left = 4
	break_bg.content_margin_right = 4
	break_bg.content_margin_top = 2
	break_bg.content_margin_bottom = 2
	block_label.add_theme_stylebox_override("normal", break_bg)
	# Shake + fade out
	var orig_pos: Vector2 = block_label.position
	var tween = create_tween()
	tween.tween_property(block_label, "position", orig_pos + Vector2(4, 0), 0.04)
	tween.tween_property(block_label, "position", orig_pos + Vector2(-4, 0), 0.04)
	tween.tween_property(block_label, "position", orig_pos + Vector2(3, 0), 0.04)
	tween.tween_property(block_label, "position", orig_pos + Vector2(-2, 0), 0.04)
	tween.tween_property(block_label, "position", orig_pos, 0.04)
	tween.tween_property(block_label, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		block_label.visible = false
		block_label.modulate.a = 1.0
		block_label.position = orig_pos
		# Remove the orange override so blue returns next time block is gained
		block_label.remove_theme_stylebox_override("normal")
	)
	# Also flash the sprite orange briefly
	if sprite_node:
		var sprite_tween = create_tween()
		sprite_tween.tween_property(sprite_node, "modulate", Color(1.0, 0.6, 0.2), 0.1)
		sprite_tween.tween_property(sprite_node, "modulate", Color.WHITE, 0.2)

func _show_status_float(status_type: String, stacks: int) -> void:
	## Show floating status name when applied (STS-style "Vulnerable" text)
	var display_name: String = STATUS_NAMES.get(status_type, status_type)
	var color: Color
	match status_type:
		"vulnerable": color = Color(0.2, 0.9, 0.3)
		"weak": color = Color(0.2, 0.9, 0.3)
		"strength": color = Color(1.0, 0.4, 0.2)
		"dexterity": color = Color(0.3, 0.6, 1.0)
		"poison": color = Color(0.2, 0.85, 0.2)
		_: color = Color(0.8, 0.8, 0.3)
	var lbl = Label.new()
	lbl.text = display_name
	if stacks > 1:
		lbl.text += " " + str(stacks)
	lbl.add_theme_font_size_override("font_size", status_float_font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-60, -160)
	add_child(lbl)
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(lbl, "position:y", lbl.position.y - 60, 1.0)
	t.tween_property(lbl, "modulate:a", 0.0, 1.0).set_delay(0.4)
	t.set_parallel(false)
	t.tween_callback(lbl.queue_free)

func _show_status_wear_off(status_type: String) -> void:
	## Show "X Wears Off" text when status expires
	var display_name: String = STATUS_NAMES.get(status_type, status_type)
	var lbl = Label.new()
	lbl.text = display_name + "\nWears Off"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.5))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-50, -140)
	add_child(lbl)
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(lbl, "position:y", lbl.position.y - 50, 1.2)
	t.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.5)
	t.set_parallel(false)
	t.tween_callback(lbl.queue_free)

func show_speech(text: String, duration: float = 1.5) -> void:
	## Show a temporary speech bubble above the entity
	var panel = PanelContainer.new()
	panel.name = "SpeechBubble"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.95)
	style.border_color = Color(0.3, 0.3, 0.3, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(lbl)
	panel.position = Vector2(-80, -280)
	panel.z_index = 100
	add_child(panel)
	# Fade out after duration
	var tween = create_tween()
	tween.tween_interval(duration)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(panel.queue_free)

func add_power(power_id: String, stacks: int = 1) -> void:
	if active_powers.has(power_id):
		active_powers[power_id] += stacks
	else:
		active_powers[power_id] = stacks
	_update_status_display()
	_update_power_display()

func _update_power_display() -> void:
	if status_container == null:
		return
	# Remove old power icons (they have "PowerIcon_" prefix)
	for child in status_container.get_children():
		if child.name.begins_with("PowerIcon_"):
			child.queue_free()
	# Add power icons
	for power_id in active_powers:
		var stacks: int = active_powers[power_id]
		if stacks <= 0:
			continue
		var container = HBoxContainer.new()
		container.name = "PowerIcon_" + power_id
		container.mouse_filter = Control.MOUSE_FILTER_PASS
		var power_name: String = POWER_NAMES.get(power_id, power_id)
		container.gui_input.connect(_on_status_icon_clicked.bind(container, power_name, stacks))
		# Try loading power-specific icon
		var icon_path: String = "res://assets/img/power_icons/" + power_id + ".png"
		var tex = load(icon_path) if ResourceLoader.exists(icon_path) else null
		if tex:
			var icon = TextureRect.new()
			icon.texture = tex
			icon.custom_minimum_size = Vector2(28, 28)
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(icon)
		else:
			# Fallback: purple square
			var fallback = ColorRect.new()
			fallback.custom_minimum_size = Vector2(28, 28)
			fallback.color = Color(0.6, 0.3, 0.8, 0.8)
			fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(fallback)
		var lbl = Label.new()
		lbl.text = str(stacks)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(lbl)
		status_container.add_child(container)

func _on_status_icon_clicked(event: InputEvent, icon_container: Control, status_name: String, stacks: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	# Remove existing tooltip if any
	if _active_tooltip and is_instance_valid(_active_tooltip):
		_active_tooltip.queue_free()
		_active_tooltip = null
	# Create tooltip label above the icon
	var tooltip = Label.new()
	tooltip.text = "%s x%d" % [status_name, stacks]
	tooltip.add_theme_font_size_override("font_size", 18)
	tooltip.add_theme_color_override("font_color", Color(1.0, 1.0, 0.85))
	tooltip.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	tooltip.add_theme_constant_override("shadow_offset_x", 1)
	tooltip.add_theme_constant_override("shadow_offset_y", 1)
	tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Style background
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.15, 0.92)
	bg.border_color = Color(0.5, 0.5, 0.6, 0.8)
	bg.border_width_left = 1
	bg.border_width_right = 1
	bg.border_width_top = 1
	bg.border_width_bottom = 1
	bg.corner_radius_top_left = 6
	bg.corner_radius_top_right = 6
	bg.corner_radius_bottom_left = 6
	bg.corner_radius_bottom_right = 6
	bg.content_margin_left = 10
	bg.content_margin_right = 10
	bg.content_margin_top = 4
	bg.content_margin_bottom = 4
	tooltip.add_theme_stylebox_override("normal", bg)
	tooltip.z_index = 200
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Position above status container
	tooltip.position = Vector2(icon_container.position.x - 20, -45)
	if status_container:
		status_container.add_child(tooltip)
	else:
		add_child(tooltip)
	_active_tooltip = tooltip
	# Auto-hide after 2 seconds
	var tw = create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(tooltip, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		if is_instance_valid(tooltip):
			tooltip.queue_free()
		if _active_tooltip == tooltip:
			_active_tooltip = null
	)

func _play_death() -> void:
	if sprite_node == null:
		visible = false
		return
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(func(): visible = false)
