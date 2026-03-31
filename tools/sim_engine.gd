class_name SimBattleEngine
## tools/sim_engine.gd — Headless battle simulation engine
## Replicates battle_manager combat logic without any UI.

var card_db: Dictionary = {}  # Reference to game_manager.card_database

func simulate(deck: Array, card_database: Dictionary,
			  hero_hp: int = 200, monster_hp: int = 50,
			  monster_dmg: int = 6, monster_inc: int = 3,
			  monster_count: int = 2, draw_per_turn: int = 4) -> Dictionary:
	card_db = card_database
	var state := {
		"hero_hp": hero_hp, "hero_max_hp": hero_hp, "hero_block": 0,
		"hero_strength": 0, "hero_temp_strength": 0,
		"energy": 3, "max_energy": 3,
		"hand": [] as Array, "draw_pile": [] as Array,
		"discard_pile": [] as Array, "exhaust_pile": [] as Array,
		"monsters": [] as Array,
		"turn": 0, "attacks_played": 0, "total_cards": 0,
		"max_turn_dmg": 0, "current_turn_dmg": 0,
		# Powers
		"demon_form": false, "metallicize": 0, "noxious_fumes": 0,
		"envenom": false, "accuracy": 0, "venomous_might": false,
		"blood_fury": false, "blood_fury_active": false,
		"psi_surge": false, "rage": false, "rage_block": 3,
		"a_thousand_cuts": false, "after_image": false,
		"feel_no_pain": false, "feel_no_pain_block": 3,
		"dark_embrace": false, "fire_breathing": false,
		"corruption": false, "barricade": false,
		"double_tap": false, "burst": false,
	}
	# Init monsters
	for _m in range(monster_count):
		state["monsters"].append({
			"hp": monster_hp, "vulnerable": 0, "weak": 0, "poison": 0,
			"base_dmg": monster_dmg, "dmg_inc": monster_inc
		})
	# Init draw pile
	state["draw_pile"] = deck.duplicate()
	state["draw_pile"].shuffle()

	for turn in range(1, 30):
		state["turn"] = turn
		state["energy"] = state["max_energy"]
		state["hero_block"] = 0 if not state["barricade"] else state["hero_block"]
		state["attacks_played"] = 0
		state["current_turn_dmg"] = 0

		# Start-of-turn powers
		if state["demon_form"]:
			state["hero_strength"] += 2
		if state["venomous_might"]:
			var total_p := 0
			for m in _alive(state):
				total_p += m["poison"]
			var sg := total_p / 4
			if sg > 0:
				state["hero_strength"] += sg
		if state["metallicize"] > 0:
			state["hero_block"] += state["metallicize"]

		# Poison tick
		for m in _alive(state):
			if m["poison"] > 0:
				m["hp"] -= m["poison"]
				m["poison"] = maxi(0, m["poison"] - 1)
		if _all_dead(state):
			return _result(state, true)

		# Noxious fumes
		if state["noxious_fumes"] > 0:
			for m in _alive(state):
				m["poison"] += state["noxious_fumes"]

		# Draw cards
		_draw_cards(state, draw_per_turn)

		# Play cards (greedy AI)
		_greedy_play(state)
		state["max_turn_dmg"] = maxi(state["max_turn_dmg"], state["current_turn_dmg"])

		if _all_dead(state):
			return _result(state, true)

		# Monster attacks
		var total_dmg := 0
		for m in _alive(state):
			var d: int = m["base_dmg"] + m["dmg_inc"] * (turn - 1)
			if m["weak"] > 0:
				d = int(d * 0.75)
			total_dmg += d
		var actual := maxi(0, total_dmg - state["hero_block"])
		state["hero_hp"] -= actual

		# Status tick
		for m in _alive(state):
			if m["vulnerable"] > 0: m["vulnerable"] -= 1
			if m["weak"] > 0: m["weak"] -= 1
		state["hero_strength"] -= state["hero_temp_strength"]
		state["hero_temp_strength"] = 0

		# Discard hand
		state["discard_pile"].append_array(state["hand"])
		state["hand"].clear()

		if state["hero_hp"] <= 0:
			state["hero_hp"] = 0
			return _result(state, false)

	return _result(state, _all_dead(state))


func _alive(state: Dictionary) -> Array:
	var result: Array = []
	for m in state["monsters"]:
		if m["hp"] > 0:
			result.append(m)
	return result

func _all_dead(state: Dictionary) -> bool:
	for m in state["monsters"]:
		if m["hp"] > 0:
			return false
	return true

func _first_alive(state: Dictionary) -> Dictionary:
	for m in state["monsters"]:
		if m["hp"] > 0:
			return m
	return {}

func _result(state: Dictionary, won: bool) -> Dictionary:
	return {
		"hero_hp": state["hero_hp"],
		"turns": state["turn"],
		"total_cards": state["total_cards"],
		"max_turn_dmg": state["max_turn_dmg"],
		"won": won,
	}

func _draw_cards(state: Dictionary, count: int) -> void:
	for _i in range(count):
		if state["draw_pile"].is_empty():
			state["draw_pile"] = state["discard_pile"].duplicate()
			state["discard_pile"].clear()
			state["draw_pile"].shuffle()
		if not state["draw_pile"].is_empty():
			state["hand"].append(state["draw_pile"].pop_back())
			# Fire Breathing
			if state["fire_breathing"]:
				var drawn_id: String = state["hand"].back()
				var drawn_card: Dictionary = card_db.get(drawn_id, {})
				if drawn_card.get("type", 0) == 3:  # STATUS
					for m in _alive(state):
						m["hp"] -= 6


func _greedy_play(state: Dictionary) -> void:
	# Priority 1: Play all affordable Power cards first (long-term value)
	var played_power := true
	while played_power and state["energy"] > 0:
		played_power = false
		for card_id in state["hand"]:
			var card: Dictionary = card_db.get(card_id, {})
			if card.is_empty() or card.get("type", 0) != 2:  # Not POWER
				continue
			var cost: int = card.get("cost", 0)
			if cost > state["energy"]:
				continue
			if not _can_play(state, card):
				continue
			state["energy"] -= cost
			state["hand"].erase(card_id)
			_play_card(state, card_id)
			state["total_cards"] += 1
			played_power = true
			break  # Restart loop (hand changed)

	# Priority 2: Play other cards greedily by score
	while state["energy"] > 0 and not state["hand"].is_empty():
		var best_id: String = ""
		var best_score: float = -999.0
		for card_id in state["hand"]:
			var card: Dictionary = card_db.get(card_id, {})
			if card.is_empty():
				continue
			var cost: int = card.get("cost", 0)
			if cost == -1:
				cost = state["energy"]
			if cost < 0:
				continue  # Unplayable
			if cost > state["energy"]:
				continue
			# Corruption: skills cost 0
			if state["corruption"] and card.get("type", 0) == 1:
				cost = 0

			# Check playability conditions
			if not _can_play(state, card):
				continue

			var score: float = _score_card(state, card_id, cost)
			if score > best_score:
				best_score = score
				best_id = card_id

		if best_id == "" or best_score <= 0:
			break

		var card: Dictionary = card_db.get(best_id, {})
		var cost: int = card.get("cost", 0)
		if cost == -1:
			cost = state["energy"]
		if state["corruption"] and card.get("type", 0) == 1:
			cost = 0
		state["energy"] -= cost
		state["hand"].erase(best_id)
		_play_card(state, best_id)
		state["total_cards"] += 1


func _can_play(state: Dictionary, card: Dictionary) -> bool:
	"""Check if a card can be played (special conditions)."""
	if card.get("unplayable", false):
		return false
	var special: String = card.get("special", "")
	if special == "grand_finale":
		return state["draw_pile"].is_empty()
	if special == "clash":
		for c_id in state["hand"]:
			var c: Dictionary = card_db.get(c_id, {})
			if c.get("type", 0) != 0:  # Not ATTACK
				return false
	return true

func _score_card(state: Dictionary, card_id: String, cost: int) -> float:
	var card: Dictionary = card_db.get(card_id, {})
	var damage: int = card.get("damage", 0)
	var block: int = card.get("block", 0)
	var draw: int = card.get("draw", 0)
	var card_type: int = card.get("type", 0)

	var score: float = 0.0

	# Priority bonus: debuffs (vulnerable/weak) should be played before attacks
	var apply_status: Dictionary = card.get("apply_status", {})
	if not apply_status.is_empty():
		var st: String = apply_status.get("type", "")
		if st == "vulnerable":
			# Bonus: remaining attack damage in hand benefits from vulnerable
			var remaining_dmg := 0
			for other_id in state["hand"]:
				if other_id == card_id:
					continue
				var oc: Dictionary = card_db.get(other_id, {})
				if oc.get("type", 0) == 0:  # ATTACK
					remaining_dmg += oc.get("damage", 0) * oc.get("times", 1)
			score += remaining_dmg * 0.5  # 50% more damage from vulnerable

	# Estimate damage value
	if damage > 0:
		var str_bonus: int = state["hero_strength"]
		var str_mult: int = card.get("str_mult", 1)
		var per_hit: int = damage + str_bonus * str_mult
		var times: int = card.get("times", 1)
		var target = _first_alive(state)
		if not target.is_empty() and target["vulnerable"] > 0:
			per_hit = int(per_hit * 1.5)
		score += per_hit * times * 1.0

	# Block value
	if block > 0:
		var incoming := 0
		for m in _alive(state):
			incoming += m["base_dmg"] + m["dmg_inc"] * (state["turn"] - 1)
		score += mini(block, maxi(0, incoming - state["hero_block"])) * 0.8

	# Draw value
	score += draw * 3.0

	# Power value
	if card_type == 2:  # POWER
		var power_name: String = card.get("power_effect", "")
		match power_name:
			"demon_form": score += 30
			"noxious_fumes": score += 15 * _alive(state).size()
			"metallicize": score += 10
			"envenom": score += 12
			_: score += 8  # Generic power value

	# Strength gain
	for action in card.get("actions", []):
		if action.get("type", "") == "apply_self_status":
			if action.get("status", "") == "strength":
				score += action.get("stacks", 1) * 8.0

	# Status effects on enemy
	var apply_status: Dictionary = card.get("apply_status", {})
	if not apply_status.is_empty():
		var st: String = apply_status.get("type", "")
		var stacks: int = apply_status.get("stacks", 1)
		if st == "poison":
			score += stacks * 2.0
		elif st == "vulnerable":
			score += stacks * 5.0
		elif st == "weak":
			score += stacks * 3.0

	if cost > 0:
		score = score / cost
	return score


func _play_card(state: Dictionary, card_id: String) -> void:
	var card: Dictionary = card_db.get(card_id, {})
	if card.is_empty():
		return

	var card_type: int = card.get("type", 0)
	var target_type: String = card.get("target", "self")

	# Execute actions
	var actions: Array = card.get("actions", [])
	var damage: int = card.get("damage", 0)
	var block: int = card.get("block", 0)
	var draw_count: int = card.get("draw", 0)
	var times: int = card.get("times", 1)

	for action in actions:
		var atype: String = action.get("type", "")
		match atype:
			"damage":
				_deal_damage(state, card, target_type)
			"damage_all":
				_deal_damage(state, card, "all_enemies")
			"block":
				if block > 0:
					state["hero_block"] += block
			"draw":
				if draw_count > 0:
					_draw_cards(state, draw_count)
			"apply_status":
				var source: String = action.get("source", "apply_status")
				var status_data: Dictionary = card.get(source, {})
				if not status_data.is_empty():
					var st: String = status_data.get("type", "")
					var stacks: int = status_data.get("stacks", 1)
					if target_type == "all_enemies":
						for m in _alive(state):
							_apply_monster_status(m, st, stacks)
					else:
						var target = _first_alive(state)
						if not target.is_empty():
							_apply_monster_status(target, st, stacks)
			"apply_self_status":
				var status: String = action.get("status", "")
				var stacks: int = action.get("stacks", 1)
				if status == "strength":
					state["hero_strength"] += stacks
				elif status == "dexterity":
					pass  # Simplified
			"self_damage":
				var amount: int = action.get("value", 0)
				state["hero_hp"] -= amount
				if state["blood_fury"]:
					state["blood_fury_active"] = true
			"gain_energy":
				state["energy"] += action.get("value", 1)
			"add_shiv":
				var shiv_count: int = action.get("value", 1)
				for _s in range(shiv_count):
					if state["hand"].size() < 10:
						state["hand"].append("si_shiv")
			"power_effect":
				var power: String = action.get("power", "")
				_activate_power(state, power)
			"call":
				var fn: String = action.get("fn", "")
				_call_fn(state, card, fn, target_type)

	# A Thousand Cuts
	if state["a_thousand_cuts"]:
		for m in _alive(state):
			m["hp"] -= 1
	# After Image
	if state["after_image"]:
		state["hero_block"] += 1

	# Card destination
	var should_exhaust: bool = card.get("exhaust", false)
	if state["corruption"] and card_type == 1:
		should_exhaust = true
	if card_type == 2:
		state["exhaust_pile"].append(card_id)
	elif should_exhaust:
		state["exhaust_pile"].append(card_id)
		if state["feel_no_pain"]:
			state["hero_block"] += state["feel_no_pain_block"]
		if state["dark_embrace"]:
			_draw_cards(state, 1)
	else:
		state["discard_pile"].append(card_id)

	# Track attacks
	if card_type == 0:
		state["attacks_played"] += 1
		if state["rage"]:
			state["hero_block"] += state["rage_block"]


func _deal_damage(state: Dictionary, card: Dictionary, target_type: String) -> void:
	var base_dmg: int = card.get("damage", 0)
	var str_mult: int = card.get("str_mult", 1)
	var times_val: int = card.get("times", 1)
	var per_hit: int = base_dmg + state["hero_strength"] * str_mult

	if state["blood_fury_active"]:
		per_hit *= 2
		state["blood_fury_active"] = false

	if target_type == "all_enemies":
		for m in _alive(state):
			var dmg: int = per_hit
			if m["vulnerable"] > 0:
				dmg = int(dmg * 1.5)
			for _t in range(times_val):
				m["hp"] -= dmg
				state["current_turn_dmg"] += dmg
				if state["envenom"]:
					m["poison"] += 1
	else:
		for _t in range(times_val):
			var target = _first_alive(state)
			if target.is_empty():
				break
			var dmg: int = per_hit
			if target["vulnerable"] > 0:
				dmg = int(dmg * 1.5)
			target["hp"] -= dmg
			state["current_turn_dmg"] += dmg
			if state["envenom"]:
				target["poison"] += 1


func _apply_monster_status(m: Dictionary, status: String, stacks: int) -> void:
	match status:
		"vulnerable": m["vulnerable"] += stacks
		"weak": m["weak"] += stacks
		"poison": m["poison"] += stacks


func _activate_power(state: Dictionary, power: String) -> void:
	match power:
		"demon_form": state["demon_form"] = true
		"metallicize": state["metallicize"] = 3
		"noxious_fumes": state["noxious_fumes"] = 2
		"envenom": state["envenom"] = true
		"accuracy": state["accuracy"] += 4
		"venomous_might": state["venomous_might"] = true
		"blood_fury": state["blood_fury"] = true
		"psi_surge": state["psi_surge"] = true
		"rage": state["rage"] = true
		"barricade": state["barricade"] = true
		"corruption": state["corruption"] = true
		"a_thousand_cuts": state["a_thousand_cuts"] = true
		"after_image": state["after_image"] = true
		"feel_no_pain": state["feel_no_pain"] = true
		"dark_embrace": state["dark_embrace"] = true
		"fire_breathing": state["fire_breathing"] = true
		"infinite_blades": pass  # Simplified
		"caltrops": pass
		"evolve": pass
		"well_laid_plans": pass
		"tools_of_the_trade": pass
		"wraith_form": pass
		"brutality": pass
		"combust": pass


func _call_fn(state: Dictionary, card: Dictionary, fn: String, target_type: String) -> void:
	match fn:
		"whirlwind", "toxic_storm":
			var base: int = card.get("damage", 5)
			var x: int = state["energy"]
			state["energy"] = 0
			for _hit in range(x):
				for m in _alive(state):
					var dmg: int = base + state["hero_strength"]
					if m["vulnerable"] > 0:
						dmg = int(dmg * 1.5)
					m["hp"] -= dmg
					state["current_turn_dmg"] += dmg
					if fn == "toxic_storm":
						m["poison"] += 1
		"skewer":
			var base: int = card.get("damage", 7)
			var x: int = state["energy"]
			state["energy"] = 0
			var target = _first_alive(state)
			if not target.is_empty():
				for _hit in range(x):
					var dmg: int = base + state["hero_strength"]
					if target["vulnerable"] > 0:
						dmg = int(dmg * 1.5)
					target["hp"] -= dmg
					state["current_turn_dmg"] += dmg
		"heavy_blade":
			var base: int = card.get("damage", 14)
			var mult: int = card.get("str_mult", 3)
			var target = _first_alive(state)
			if not target.is_empty():
				var dmg: int = base + state["hero_strength"] * mult
				if target["vulnerable"] > 0:
					dmg = int(dmg * 1.5)
				target["hp"] -= dmg
				state["current_turn_dmg"] += dmg
		"body_slam":
			var target = _first_alive(state)
			if not target.is_empty():
				var dmg: int = state["hero_block"]
				if target["vulnerable"] > 0:
					dmg = int(dmg * 1.5)
				target["hp"] -= dmg
				state["current_turn_dmg"] += dmg
		"limit_break":
			state["hero_strength"] *= 2
		"catalyst":
			var target = _first_alive(state)
			if not target.is_empty():
				target["poison"] *= 2
		"poison_shield":
			var total_p := 0
			for m in _alive(state):
				total_p += m["poison"]
			state["hero_block"] += total_p
		"gamblers_blade":
			var target = _first_alive(state)
			if not target.is_empty():
				var dmg: int = state["hand"].size() * 3 + state["hero_strength"]
				if target["vulnerable"] > 0:
					dmg = int(dmg * 1.5)
				target["hp"] -= dmg
				state["current_turn_dmg"] += dmg
		"all_in":
			var e: int = state["energy"]
			state["energy"] = 0
			_draw_cards(state, e * 2)
		"flex":
			state["hero_strength"] += card.get("flex_stacks", 2)
			state["hero_temp_strength"] += card.get("flex_stacks", 2)
		"entrench":
			state["hero_block"] *= 2
		_:
			# Fallback: just deal damage if card has it
			if card.get("damage", 0) > 0:
				_deal_damage(state, card, target_type)
