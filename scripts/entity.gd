extends Node2D
## res://scripts/entity.gd — Base class for player and enemies: HP, block, status effects

signal hp_changed(current: int, max_val: int)
signal block_changed(amount: int)
signal status_changed(status_type: String, stacks: int)
signal died

@export var max_hp: int = 80
@export var is_enemy: bool = false

var current_hp: int = 80
var block: int = 0
var status_effects: Dictionary = {}
var enemy_type: String = ""
var intent: Dictionary = {}
var alive: bool = true
var power_effects: Array = []

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
	_update_status_display()

func reset_block() -> void:
	block = 0
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
	else:
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
		var icon = TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		container.add_child(icon)
		var lbl = Label.new()
		lbl.text = str(status_effects[status_type])
		lbl.add_theme_font_size_override("font_size", 14)
		if status_type == "poison":
			lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		else:
			lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.7))
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
	dmg_label.add_theme_font_size_override("font_size", 36)
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
	dmg_label.add_theme_font_size_override("font_size", 36)
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

func _play_death() -> void:
	if sprite_node == null:
		visible = false
		return
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(func(): visible = false)
