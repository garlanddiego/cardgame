extends Node2D
## res://scripts/entity.gd — Base class for player and enemies: HP, block, status effects

signal hp_changed(current: int, max_val: int)
signal block_changed(amount: int)
signal status_changed(status_type: String, stacks: int)
signal died

@export var max_hp: int = 80
@export var is_enemy: bool = false
@export var damage_number_font_size: int = 48  ## Font size for floating damage numbers
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
var poison_preview: ColorRect = null
var hp_label: Label = null
var block_label: Label = null
var _shield_icon: TextureRect = null
var _shield_tex: Texture2D = null
var _shield_dim_tex: Texture2D = null
var _target_highlight: Node2D = null  # Yellow border when targeted
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
	poison_preview = get_node_or_null("HPBarBG/PoisonPreview") as ColorRect
	hp_label = get_node_or_null("HPLabel") as Label
	block_label = get_node_or_null("BlockLabel") as Label
	intent_icon = get_node_or_null("IntentIcon") as TextureRect
	intent_label = get_node_or_null("IntentLabel") as Label
	status_container = get_node_or_null("StatusContainer") as HBoxContainer
	name_label = get_node_or_null("NameLabel") as Label
	# Shield icon and textures — use scene node if available, or load textures
	_shield_icon = get_node_or_null("ShieldIcon") as TextureRect
	if ResourceLoader.exists("res://assets/img/ui_icons/shield.png"):
		_shield_tex = load("res://assets/img/ui_icons/shield.png")
	if ResourceLoader.exists("res://assets/img/ui_icons/shield_dim.png"):
		_shield_dim_tex = load("res://assets/img/ui_icons/shield_dim.png")
	# Create target highlight border (hidden by default)
	_target_highlight = Node2D.new()
	_target_highlight.name = "TargetHighlight"
	_target_highlight.visible = false
	_target_highlight.z_index = -1
	add_child(_target_highlight)
	_update_hp_bar()
	_update_block_display()
	# Start idle breathing animation
	_start_idle_animation()

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
	# Intangible: cap all damage at 1
	if status_effects.get("intangible", 0) > 0:
		actual_damage = mini(actual_damage, 1)
	# Check vulnerable
	elif status_effects.has("vulnerable") and status_effects["vulnerable"] > 0:
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
	var actual: int = amount
	if status_effects.get("intangible", 0) > 0:
		actual = mini(actual, 1)
	current_hp -= actual
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
	# Apply dexterity (can be positive or negative)
	if status_effects.has("dexterity"):
		actual_block += status_effects["dexterity"]
	actual_block = maxi(0, actual_block)  # Block can't be negative
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
		if status_type in ["vulnerable", "weak", "intangible"]:
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
	# Apply strength (can be positive or negative)
	if status_effects.has("strength"):
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
	_update_poison_preview()

func _update_poison_preview() -> void:
	if poison_preview == null or hp_bar_bg == null:
		return
	var poison_stacks: int = status_effects.get("poison", 0)
	if poison_stacks <= 0 or current_hp <= 0:
		poison_preview.visible = false
		return
	poison_preview.visible = true
	var preview_hp: int = mini(poison_stacks, current_hp)
	var bar_width: float = hp_bar_bg.size.x
	var hp_ratio: float = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
	var preview_ratio: float = float(preview_hp) / float(max_hp) if max_hp > 0 else 0.0
	# Green bar starts at the LEFT edge of current HP fill and extends inward (right-to-left from fill end)
	# It shows the portion of HP that poison will remove
	var fill_width: float = bar_width * hp_ratio
	var preview_width: float = bar_width * preview_ratio
	# Position: starts where HP fill would be after poison damage
	poison_preview.position.x = fill_width - preview_width
	poison_preview.size.x = preview_width

func _update_block_display() -> void:
	if block_label == null:
		return
	block_label.visible = true
	block_label.text = str(block)
	block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Remove any old background style (shield icon replaces it)
	block_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	if _shield_icon:
		_shield_icon.visible = true
	# Always use bright shield icon (not dim)
	if _shield_icon and _shield_tex:
		_shield_icon.texture = _shield_tex
		_shield_icon.modulate = Color.WHITE
	if block > 0:
		block_label.add_theme_color_override("font_color", Color.WHITE)
		block_label.add_theme_font_size_override("font_size", 20)
		if _previous_block <= 0:
			_flash_block()
		_previous_block = block
	else:
		block_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 0.9))
		block_label.add_theme_font_size_override("font_size", 18)
		if _previous_block > 0:
			_flash_block_break()
		_previous_block = 0

func _update_status_display() -> void:
	_update_poison_preview()
	if status_container == null:
		return
	# Clear existing status icons (not PowerIcon_ — those are managed by _update_power_display)
	var status_to_remove: Array = []
	for child in status_container.get_children():
		if not child.name.begins_with("PowerIcon_"):
			status_to_remove.append(child)
	for child in status_to_remove:
		status_container.remove_child(child)
		child.free()
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
	# Power icons are handled by _update_power_display() — not duplicated here

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

var _highlight_visible: bool = false

func show_target_highlight() -> void:
	_highlight_visible = true
	queue_redraw()
	if sprite_node:
		sprite_node.modulate = Color(1.15, 1.1, 0.9, 1.0)

func hide_target_highlight() -> void:
	_highlight_visible = false
	queue_redraw()
	if sprite_node:
		sprite_node.modulate = Color.WHITE

func _draw() -> void:
	if _highlight_visible and sprite_node:
		# Draw yellow border around entity
		var tex = sprite_node.texture
		if tex:
			var h: float = tex.get_height() * sprite_node.scale.y
			var w: float = tex.get_width() * sprite_node.scale.x
			var rect = Rect2(-w/2 - 8, -h/2 - 8, w + 16, h + 16)
			# Yellow border
			draw_rect(rect, Color(1.0, 0.85, 0.2, 0.9), false, 4.0)
			# Inner glow
			var inner = Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4))
			draw_rect(inner, Color(1.0, 0.9, 0.4, 0.3), false, 2.0)

func _flash_damage(damage_amount: int = 0) -> void:
	if sprite_node == null:
		return
	# Swap to hit pose if available
	_swap_to_hit_pose()
	# White flash → red flash → shake → recover
	var orig_pos: Vector2 = sprite_node.position
	var tween = create_tween()
	# Bright white flash on impact
	tween.tween_property(sprite_node, "modulate", Color(3.0, 3.0, 3.0), 0.04)
	tween.tween_property(sprite_node, "modulate", Color(1.0, 0.2, 0.2), 0.06)
	# Shake with larger amplitude
	tween.tween_property(sprite_node, "position", orig_pos + Vector2(12, -3), 0.03)
	tween.tween_property(sprite_node, "position", orig_pos + Vector2(-12, 3), 0.03)
	tween.tween_property(sprite_node, "position", orig_pos + Vector2(8, -2), 0.03)
	tween.tween_property(sprite_node, "position", orig_pos + Vector2(-6, 1), 0.03)
	tween.tween_property(sprite_node, "position", orig_pos + Vector2(3, 0), 0.03)
	tween.tween_property(sprite_node, "position", orig_pos, 0.03)
	tween.tween_property(sprite_node, "modulate", Color.WHITE, 0.25)
	# Floating damage number with scale punch
	if damage_amount <= 0:
		return
	var dmg_label = Label.new()
	dmg_label.text = "-" + str(damage_amount)
	dmg_label.add_theme_font_size_override("font_size", damage_number_font_size)
	dmg_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	dmg_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	dmg_label.add_theme_constant_override("shadow_offset_x", 2)
	dmg_label.add_theme_constant_override("shadow_offset_y", 3)
	dmg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dmg_label.position = Vector2(-40, -120)
	dmg_label.scale = Vector2(1.8, 1.8)
	dmg_label.pivot_offset = Vector2(40, 20)
	add_child(dmg_label)
	var float_tween = create_tween()
	# Scale punch: big → normal → float up → fade
	float_tween.tween_property(dmg_label, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	float_tween.set_parallel(true)
	float_tween.tween_property(dmg_label, "position:y", dmg_label.position.y - 90, 1.8).set_ease(Tween.EASE_OUT)
	float_tween.tween_property(dmg_label, "modulate:a", 0.0, 1.2).set_delay(0.6)
	float_tween.set_parallel(false)
	float_tween.tween_callback(dmg_label.queue_free)

func _flash_poison_damage(damage_amount: int) -> void:
	if sprite_node == null:
		return
	var tween = create_tween()
	tween.tween_property(sprite_node, "modulate", Color(0.3, 1.0, 0.3), 0.2)
	tween.tween_property(sprite_node, "modulate", Color.WHITE, 0.3)
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
	float_tween.tween_property(dmg_label, "position:y", dmg_label.position.y - 80, 1.4)
	float_tween.tween_property(dmg_label, "modulate:a", 0.0, 1.4).set_delay(0.4)
	float_tween.set_parallel(false)
	float_tween.tween_callback(dmg_label.queue_free)

var _idle_tween: Tween = null
var _hit_tex: Texture2D = null

func _swap_to_hit_pose() -> void:
	if sprite_node == null:
		return
	if _hit_tex == null:
		# Try to load hit pose texture
		var tex_path: String = sprite_node.texture.resource_path if sprite_node.texture else ""
		var hit_path: String = ""
		if "slime" in tex_path: hit_path = "res://assets/img/anim/slime_hit.png"
		elif "cultist" in tex_path: hit_path = "res://assets/img/anim/cultist_hit.png"
		elif "jaw_worm" in tex_path: hit_path = "res://assets/img/anim/jaw_worm_hit.png"
		elif "guardian" in tex_path: hit_path = "res://assets/img/anim/guardian_hit.png"
		if hit_path != "" and ResourceLoader.exists(hit_path):
			_hit_tex = load(hit_path)
	if _hit_tex and _idle_tex_normal:
		sprite_node.texture = _hit_tex
		var tw = create_tween()
		tw.tween_interval(0.6)
		tw.tween_callback(func():
			if is_instance_valid(sprite_node) and _idle_tex_normal:
				sprite_node.texture = _idle_tex_normal
		)

func _start_idle_animation() -> void:
	"""Breathing animation — sprite bobs up and down + scale pulse."""
	if sprite_node == null:
		print("[IDLE] sprite_node is null for %s" % name)
		return
	print("[IDLE] Starting idle animation for %s (enemy=%s)" % [name, is_enemy])
	_idle_loop()

var _idle_tex_normal: Texture2D = null
var _idle_tex_alt: Texture2D = null

func _idle_loop() -> void:
	if not is_inside_tree() or not alive:
		return
	# Try to load alternate idle frame for texture-swap animation
	if sprite_node and sprite_node.texture:
		_idle_tex_normal = sprite_node.texture
		var tex_path: String = _idle_tex_normal.resource_path if _idle_tex_normal else ""
		var alt_path: String = ""
		if "ironclad" in tex_path:
			alt_path = "res://assets/img/anim/ironclad_idle_2.png"
		elif "silent" in tex_path:
			alt_path = "res://assets/img/anim/silent_idle_2.png"
		if alt_path != "" and ResourceLoader.exists(alt_path):
			_idle_tex_alt = load(alt_path)

	_idle_tween = create_tween()
	_idle_tween.set_loops()
	var speed: float = 1.2 + randf() * 0.3
	# Breathing animation: scale pulse + vertical bob (larger amplitude)
	var base_scale: Vector2 = sprite_node.scale
	var breathe_y: float = 8.0 if not is_enemy else 5.0  # Vertical bob pixels
	var breathe_scale: float = 0.03 if not is_enemy else 0.02  # Scale pulse
	var base_y: float = sprite_node.position.y
	var inhale_scale: Vector2 = base_scale * (1.0 + breathe_scale)
	var exhale_scale: Vector2 = base_scale
	# Inhale: scale up slightly + move up
	_idle_tween.tween_property(sprite_node, "scale", inhale_scale, speed).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_idle_tween.set_parallel(true)
	_idle_tween.tween_property(sprite_node, "position:y", base_y - breathe_y, speed).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_idle_tween.set_parallel(false)
	# Exhale: scale back down + move back
	_idle_tween.tween_property(sprite_node, "scale", exhale_scale, speed).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_idle_tween.set_parallel(true)
	_idle_tween.tween_property(sprite_node, "position:y", base_y, speed).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_idle_tween.set_parallel(false)

func _flash_block() -> void:
	# Blue tint on sprite
	if sprite_node:
		var tween = create_tween()
		tween.tween_property(sprite_node, "modulate", Color(0.6, 0.7, 1.3), 0.1)
		tween.tween_property(sprite_node, "modulate", Color.WHITE, 0.2)
	# Shield pop animation
	if _shield_icon:
		_shield_icon.scale = Vector2(1.6, 1.6)
		_shield_icon.modulate = Color(1.2, 1.2, 1.5, 1.0)
		var pop_tween = create_tween()
		pop_tween.set_parallel(true)
		pop_tween.tween_property(_shield_icon, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		pop_tween.tween_property(_shield_icon, "modulate", Color.WHITE, 0.3)

func _flash_block_break() -> void:
	## Shield break animation: orange flash + shake + scale down
	# Shield icon shake and flash orange
	if _shield_icon:
		var orig_pos: Vector2 = _shield_icon.position
		_shield_icon.modulate = Color(1.0, 0.5, 0.1, 1.0)
		var tween = create_tween()
		tween.tween_property(_shield_icon, "position", orig_pos + Vector2(5, 0), 0.04)
		tween.tween_property(_shield_icon, "position", orig_pos + Vector2(-5, 0), 0.04)
		tween.tween_property(_shield_icon, "position", orig_pos + Vector2(3, 0), 0.04)
		tween.tween_property(_shield_icon, "position", orig_pos + Vector2(-2, 0), 0.04)
		tween.tween_property(_shield_icon, "position", orig_pos, 0.04)
		tween.tween_property(_shield_icon, "modulate", Color.WHITE, 0.2)
	# Sprite orange flash
	if sprite_node:
		var sprite_tween = create_tween()
		sprite_tween.tween_property(sprite_node, "modulate", Color(1.0, 0.6, 0.2), 0.1)
		sprite_tween.tween_property(sprite_node, "modulate", Color.WHITE, 0.2)
	# Block label doesn't hide anymore (always visible)

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
	# Remove old power icons (they have "PowerIcon_" prefix) — use free() not queue_free()
	var to_remove: Array = []
	for child in status_container.get_children():
		if child.name.begins_with("PowerIcon_"):
			to_remove.append(child)
	for child in to_remove:
		status_container.remove_child(child)
		child.free()
	# Add power icons
	for power_id in active_powers:
		var stacks: int = active_powers[power_id]
		if stacks <= 0:
			continue
		var container = HBoxContainer.new()
		container.name = "PowerIcon_" + power_id
		container.mouse_filter = Control.MOUSE_FILTER_PASS
		container.focus_mode = Control.FOCUS_NONE
		var power_name: String = POWER_NAMES.get(power_id, power_id)
		container.gui_input.connect(_on_power_icon_clicked.bind(container, power_name, power_id, stacks))
		container.mouse_entered.connect(_on_icon_hover_enter.bind(container, power_name, power_id, stacks))
		container.mouse_exited.connect(_on_icon_hover_exit)
		# Try loading power-specific icon
		var icon_path: String = "res://assets/img/power_icons/" + power_id + ".png"
		var tex = load(icon_path) if ResourceLoader.exists(icon_path) else null
		if tex:
			var icon = TextureRect.new()
			icon.texture = tex
			icon.custom_minimum_size = Vector2(28, 28)
			icon.size = Vector2(28, 28)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
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
		# Show stack number for all powers with stacks >= 1
		if stacks >= 1:
			var lbl = Label.new()
			lbl.text = str(stacks)
			lbl.add_theme_font_size_override("font_size", 16)
			lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(lbl)
		status_container.add_child(container)

var _tooltip_hover: bool = false
var _tooltip_hide_tween: Tween = null

func _on_icon_hover_enter(icon_container: Control, power_name: String, power_id: String, stacks: int) -> void:
	_tooltip_hover = true
	# Cancel any pending hide
	if _tooltip_hide_tween and _tooltip_hide_tween.is_valid():
		_tooltip_hide_tween.kill()
		_tooltip_hide_tween = null
	# Look up description
	var desc_text: String = ""
	var gm = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if gm and gm.card_database:
		for card_id in gm.card_database:
			var card = gm.card_database[card_id]
			if card.get("power_effect", "") == power_id and card.get("type", 0) == 2:
				desc_text = card.get("description", "")
				break
	_show_icon_tooltip(icon_container, power_name, stacks, desc_text)

func _on_icon_hover_exit() -> void:
	_tooltip_hover = false
	# Delayed hide after mouse leaves
	if _active_tooltip and is_instance_valid(_active_tooltip):
		_tooltip_hide_tween = create_tween()
		_tooltip_hide_tween.tween_interval(1.0)
		_tooltip_hide_tween.tween_callback(func():
			if not _tooltip_hover and _active_tooltip and is_instance_valid(_active_tooltip):
				var tw = create_tween()
				tw.tween_property(_active_tooltip, "modulate:a", 0.0, 0.3)
				tw.tween_callback(func():
					if is_instance_valid(_active_tooltip):
						_active_tooltip.queue_free()
					_active_tooltip = null
				)
		)

func _on_power_icon_clicked(event: InputEvent, icon_container: Control, power_name: String, power_id: String, stacks: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	# Look up the card description from game manager
	var desc_text: String = ""
	var gm = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if gm and gm.card_database:
		# Find the card with matching power_effect
		for card_id in gm.card_database:
			var card = gm.card_database[card_id]
			if card.get("power_effect", "") == power_id and card.get("type", 0) == 2:
				desc_text = card.get("description", "")
				break
	# Show tooltip with name + description
	_show_icon_tooltip(icon_container, power_name, stacks, desc_text)

func _on_status_icon_clicked(event: InputEvent, icon_container: Control, status_name: String, stacks: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_show_icon_tooltip(icon_container, status_name, stacks, "")

func _show_icon_tooltip(icon_container: Control, name_text: String, stacks: int, description: String) -> void:
	# Remove existing tooltip if any
	if _active_tooltip and is_instance_valid(_active_tooltip):
		_active_tooltip.queue_free()
		_active_tooltip = null
	# Build tooltip text: name + stacks, then description below
	var tip_text: String = "%s x%d" % [name_text, stacks]
	if description != "":
		tip_text += "\n" + description
	# Create tooltip label above the icon
	var tooltip = Label.new()
	tooltip.text = tip_text
	tooltip.add_theme_font_size_override("font_size", 18)
	tooltip.add_theme_color_override("font_color", Color(1.0, 1.0, 0.85))
	tooltip.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	tooltip.add_theme_constant_override("shadow_offset_x", 1)
	tooltip.add_theme_constant_override("shadow_offset_y", 1)
	tooltip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip.custom_minimum_size = Vector2(220, 0)
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
	bg.content_margin_top = 6
	bg.content_margin_bottom = 6
	tooltip.add_theme_stylebox_override("normal", bg)
	tooltip.z_index = 200
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Position above status container
	tooltip.position = Vector2(icon_container.position.x - 20, -65 if description != "" else -45)
	if status_container:
		status_container.add_child(tooltip)
	else:
		add_child(tooltip)
	_active_tooltip = tooltip
	# Auto-hide only if not in hover mode
	if not _tooltip_hover:
		var duration: float = 3.0 if description != "" else 1.6
		var tw = create_tween()
		tw.tween_interval(duration)
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
	# Death flash: briefly turn red, then shatter into fragments
	var tween = create_tween()
	# Flash red
	tween.tween_property(self, "modulate", Color(1.0, 0.2, 0.1, 1.0), 0.1)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
	# Spawn fragment particles
	tween.tween_callback(_spawn_death_fragments)
	# Fade out and collapse
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_property(self, "scale", Vector2(0.3, 0.3), 0.4).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): visible = false)

func _spawn_death_fragments() -> void:
	## Scatter colored fragments outward from entity position
	var frag_count: int = 12
	var death_color: Color = Color(0.8, 0.2, 0.15) if is_enemy else Color(0.3, 0.6, 0.9)
	for i in range(frag_count):
		var frag = ColorRect.new()
		frag.size = Vector2(8 + randf() * 12, 6 + randf() * 10)
		frag.color = death_color.lerp(Color(0.9, 0.8, 0.3), randf() * 0.4)
		frag.position = global_position + Vector2(randf_range(-30, 30), randf_range(-60, 20))
		frag.z_index = 250
		get_parent().get_parent().add_child(frag)  # Add to battle scene
		var angle: float = (float(i) / frag_count) * TAU + randf_range(-0.4, 0.4)
		var dist: float = 80 + randf() * 140
		var target_pos: Vector2 = frag.position + Vector2(cos(angle), sin(angle)) * dist
		# Fall downward with gravity feel
		target_pos.y += 40 + randf() * 60
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(frag, "position", target_pos, 0.5 + randf() * 0.3).set_ease(Tween.EASE_OUT)
		t.tween_property(frag, "rotation", randf_range(-3.0, 3.0), 0.6)
		t.tween_property(frag, "modulate:a", 0.0, 0.6).set_delay(0.15)
		t.tween_property(frag, "scale", Vector2(0.2, 0.2), 0.6)
		t.set_parallel(false)
		t.tween_callback(frag.queue_free)
