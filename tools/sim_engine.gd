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
		"hero_dexterity": 0, "hero_weak": 0, "hero_vulnerable": 0,
		"energy": 3, "max_energy": 3,
		"hand": [] as Array, "draw_pile": [] as Array,
		"discard_pile": [] as Array, "exhaust_pile": [] as Array,
		"monsters": [] as Array,
		"turn": 0, "attacks_played": 0, "total_cards": 0,
		"max_turn_dmg": 0, "current_turn_dmg": 0,
		# Powers
		"next_turn_effects": [] as Array,
		# Powers
		"demon_form": 0, "metallicize": 0, "noxious_fumes": 0,
		"envenom": false, "accuracy": 0, "venomous_might": false,
		"blood_fury": false, "blood_fury_active": false,
		"psi_surge": false, "rage": false, "rage_block": 3,
		"a_thousand_cuts": false, "after_image": false,
		"feel_no_pain": false, "feel_no_pain_block": 3,
		"dark_embrace": false, "fire_breathing": false,
		"corruption": false, "barricade": false,
		"double_tap": 0, "burst": 0,
		"infinite_blades": 0,
		"tools_of_the_trade": 0,
		"berserk": 0, "brutality": 0, "combust": 0,
		"blur": false, "caltrops": 0,
		"hero_temp_dexterity": 0,
		"_play_count": 0,  # Safety: cap card plays per turn to prevent runaway
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
		if state["barricade"] or state["blur"]:
			pass  # Block persists
		else:
			state["hero_block"] = 0
		state["blur"] = false  # Blur only lasts one turn
		state["attacks_played"] = 0
		state["current_turn_dmg"] = 0
		state["_play_count"] = 0

		# Process next-turn queued effects (Dodge and Roll, Outmaneuver, Flying Knee)
		for nte in state["next_turn_effects"]:
			var etype: String = nte.get("type", "")
			var evalue: int = nte.get("value", 0)
			match etype:
				"block":
					state["hero_block"] += evalue
				"gain_energy":
					state["energy"] += evalue
		state["next_turn_effects"].clear()

		# Start-of-turn powers
		if state["demon_form"] > 0:
			state["hero_strength"] += state["demon_form"]
		if state["berserk"] > 0:
			state["energy"] += state["berserk"]
		if state["brutality"] > 0:
			state["hero_hp"] -= state["brutality"]
			if state["hero_hp"] <= 0:
				state["hero_hp"] = 0
				return _result(state, false)
			_draw_cards(state, state["brutality"])
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

		# Combust: lose 1 HP, deal damage to ALL enemies
		if state["combust"] > 0:
			state["hero_hp"] -= 1
			if state["hero_hp"] <= 0:
				state["hero_hp"] = 0
				return _result(state, false)
			for m in _alive(state):
				m["hp"] -= state["combust"]
			if _all_dead(state):
				return _result(state, true)

		# Tools of the Trade — draw 1, discard 1 at turn start
		if state["tools_of_the_trade"] > 0:
			for _tt in range(state["tools_of_the_trade"]):
				_draw_cards(state, 1)
				if not state["hand"].is_empty():
					var tt_idx: int = _pick_discard_idx(state)
					var tt_cid: String = state["hand"][tt_idx]
					state["hand"].remove_at(tt_idx)
					_discard_with_sly(state, tt_cid)

		# Infinite Blades — generate shivs at turn start
		if state["infinite_blades"] > 0:
			for _ib in range(state["infinite_blades"]):
				if state["hand"].size() < 10:
					state["hand"].append("si_shiv")

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
			# Caltrops: deal damage back to each attacking monster
			if state["caltrops"] > 0:
				m["hp"] -= state["caltrops"]
		if state["caltrops"] > 0 and _all_dead(state):
			return _result(state, true)
		var after_block: int = maxi(0, total_dmg - state["hero_block"])
		# Hero vulnerable: take 50% more damage
		if state["hero_vulnerable"] > 0:
			after_block = int(after_block * 1.5)
		state["hero_hp"] -= after_block

		# Status tick — enemies
		for m in _alive(state):
			if m["vulnerable"] > 0: m["vulnerable"] -= 1
			if m["weak"] > 0: m["weak"] -= 1
		# Status tick — hero
		state["hero_strength"] -= state["hero_temp_strength"]
		state["hero_temp_strength"] = 0
		state["hero_dexterity"] -= state["hero_temp_dexterity"]
		state["hero_temp_dexterity"] = 0
		if state["hero_weak"] > 0: state["hero_weak"] -= 1
		if state["hero_vulnerable"] > 0: state["hero_vulnerable"] -= 1

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
	# Step 1: Play all affordable Power cards first (always beneficial)
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
			break

	# Step 2: Iterative best-card selection
	# Each iteration: try every playable card as the next play, simulate the
	# rest greedily, pick the one with the best score. After playing it the
	# hand may have changed (draws, shivs) — loop back and re-evaluate.
	for _safety in range(20):  # Max 20 card plays per turn
		if state["energy"] <= 0:
			break

		# Also pick up any new power cards that appeared (from draw effects)
		played_power = true
		while played_power and state["energy"] > 0:
			played_power = false
			for card_id in state["hand"]:
				var card: Dictionary = card_db.get(card_id, {})
				if card.is_empty() or card.get("type", 0) != 2:
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
				break

		# Collect playable non-power cards
		var playable: Array = []
		for card_id in state["hand"]:
			var card: Dictionary = card_db.get(card_id, {})
			if card.is_empty() or card.get("type", 0) == 2:
				continue
			if card.get("unplayable", false):
				continue
			var cost: int = _get_card_cost(state, card)
			if cost > state["energy"]:
				continue
			if not _can_play(state, card):
				continue
			playable.append(card_id)

		if playable.is_empty():
			break

		# Calculate incoming monster damage for scoring
		var incoming_dmg := 0
		for m in _alive(state):
			var d: int = m["base_dmg"] + m["dmg_inc"] * (state["turn"] - 1)
			if m["weak"] > 0: d = int(d * 0.75)
			incoming_dmg += d

		# Try each playable card as the NEXT card to play
		# For each candidate: simulate playing it, then greedily play the rest
		var best_card: String = ""
		var best_score: float = -999999.0
		for candidate_id in playable:
			var sim_state: Dictionary = _copy_state(state)
			sim_state["_play_count"] = 0
			var cand_card: Dictionary = card_db.get(candidate_id, {})
			var cand_cost: int = _get_card_cost(sim_state, cand_card)
			sim_state["energy"] -= cand_cost
			sim_state["hand"].erase(candidate_id)
			_play_card(sim_state, candidate_id)
			# Greedily play remaining cards in simulation
			_sim_play_remaining(sim_state)
			var score: float = _score_play(state, sim_state, incoming_dmg)
			if score > best_score:
				best_score = score
				best_card = candidate_id

		if best_card == "":
			break

		# Execute the best card
		var best_c: Dictionary = card_db.get(best_card, {})
		var best_cost: int = _get_card_cost(state, best_c)
		if best_cost > state["energy"]:
			break
		state["energy"] -= best_cost
		state["hand"].erase(best_card)
		_play_card(state, best_card)
		state["total_cards"] += 1
		# Loop back — hand may have changed from draws/shivs/etc.


func _sim_play_remaining(state: Dictionary) -> void:
	"""In a simulation, greedily play all remaining playable cards by score."""
	for _cap in range(15):
		if state["energy"] <= 0:
			break
		# Play any powers first
		var played_power := true
		while played_power and state["energy"] > 0:
			played_power = false
			for card_id in state["hand"]:
				var card: Dictionary = card_db.get(card_id, {})
				if card.is_empty() or card.get("type", 0) != 2:
					continue
				var cost: int = card.get("cost", 0)
				if cost > state["energy"]:
					continue
				if not _can_play(state, card):
					continue
				state["energy"] -= cost
				state["hand"].erase(card_id)
				_play_card(state, card_id)
				played_power = true
				break
		# Find best non-power card by _score_card
		var best_id: String = ""
		var best_val: float = -999.0
		for card_id in state["hand"]:
			var card: Dictionary = card_db.get(card_id, {})
			if card.is_empty() or card.get("type", 0) == 2:
				continue
			if card.get("unplayable", false):
				continue
			var cost: int = _get_card_cost(state, card)
			if cost > state["energy"]:
				continue
			if not _can_play(state, card):
				continue
			var val: float = _score_card(state, card_id, cost)
			if val > best_val:
				best_val = val
				best_id = card_id
		if best_id == "":
			break
		var bc: Dictionary = card_db.get(best_id, {})
		var bc_cost: int = _get_card_cost(state, bc)
		state["energy"] -= bc_cost
		state["hand"].erase(best_id)
		_play_card(state, best_id)


func _score_play(before: Dictionary, after: Dictionary, incoming_dmg: int) -> float:
	"""Estimate total HP loss for a play choice. Higher score = less HP lost = better.

	Formula: -(this_turn_hp_loss + estimated_future_hp_loss)
	- this_turn_hp_loss: actual damage that gets through block
	- estimated_future_hp_loss: remaining_enemy_hp / our_dmg_rate * future_dmg_per_turn
	- kill_bonus: eliminating an enemy saves all its future damage
	- poison_value: poison deals (n*(n+1))/2 total future damage
	"""
	# --- This turn's HP loss ---
	var hp_loss_now: float = float(maxi(0, incoming_dmg - after["hero_block"]))

	# --- Enemy state analysis ---
	var enemies_alive_before := 0
	var enemies_alive_after := 0
	var remaining_enemy_hp: float = 0.0
	var total_poison_after: float = 0.0
	var future_dmg_per_turn: float = 0.0
	var turn: int = after["turn"]

	for m in before["monsters"]:
		if m["hp"] > 0:
			enemies_alive_before += 1
	for m in after["monsters"]:
		if m["hp"] > 0:
			enemies_alive_after += 1
			remaining_enemy_hp += float(m["hp"])
			# Future damage this enemy will deal (grows each turn)
			var d: float = float(m["base_dmg"]) + float(m["dmg_inc"]) * float(turn)
			if m["weak"] > 0:
				d *= 0.75
			future_dmg_per_turn += d
		# Count poison value even on alive enemies
		if m["hp"] > 0 and m["poison"] > 0:
			# Poison deals p + (p-1) + ... + 1 = p*(p+1)/2 total, capped at enemy HP
			var p: float = float(m["poison"])
			var poison_total: float = minf(p * (p + 1.0) / 2.0, float(m["hp"]))
			total_poison_after += poison_total

	var enemies_killed: int = enemies_alive_before - enemies_alive_after

	# --- Estimate future turns to win ---
	# Base damage output per turn (strength × ~3 attacks + base)
	var our_dmg_per_turn: float = maxf(1.0, float(after["hero_strength"]) * 3.0 + 10.0)

	# --- Recurring power damage each future turn ---
	# Noxious fumes: adds poison stacks each turn to all enemies (cumulative)
	if after["noxious_fumes"] > 0:
		our_dmg_per_turn += float(after["noxious_fumes"]) * float(enemies_alive_after) * 1.5
	# Combust: flat damage to all enemies per turn
	if after["combust"] > 0:
		our_dmg_per_turn += float(after["combust"]) * float(enemies_alive_after)
	# Infinite blades: free shiv per turn = (4 + str) damage
	if after["infinite_blades"] > 0:
		our_dmg_per_turn += float(after["infinite_blades"]) * (4.0 + float(after["hero_strength"]))
	# Berserk: extra energy → roughly one more card played → ~6 more damage
	if after["berserk"] > 0:
		our_dmg_per_turn += float(after["berserk"]) * 6.0

	# Subtract poison's future contribution from remaining HP
	var effective_remaining_hp: float = maxf(0.0, remaining_enemy_hp - total_poison_after)
	var est_remaining_turns: float = effective_remaining_hp / maxf(1.0, our_dmg_per_turn)

	# Demon form: strength compounds each turn → average extra str over T turns = df*T/2
	if after["demon_form"] > 0:
		var avg_extra_str: float = float(after["demon_form"]) * est_remaining_turns / 2.0
		var boosted_dmg: float = our_dmg_per_turn + avg_extra_str * 3.0
		est_remaining_turns = effective_remaining_hp / maxf(1.0, boosted_dmg)

	# --- Total estimated HP loss (reduced by recurring block) ---
	var net_incoming: float = future_dmg_per_turn
	# Metallicize: free block each turn reduces net incoming damage
	if after["metallicize"] > 0:
		net_incoming = maxf(0.0, net_incoming - float(after["metallicize"]))
	# After image: ~3.5 block per turn (average cards played)
	if after["after_image"]:
		net_incoming = maxf(0.0, net_incoming - 3.5)
	# Caltrops: deals damage back to attackers, effectively killing them faster
	if after["caltrops"] > 0:
		our_dmg_per_turn += float(after["caltrops"]) * float(enemies_alive_after)
		est_remaining_turns = effective_remaining_hp / maxf(1.0, our_dmg_per_turn)
	var future_hp_loss: float = est_remaining_turns * net_incoming

	# --- Kill bonus: each kill saves ~(base_dmg + inc*avg_remaining_turns) per future turn ---
	var kill_bonus: float = 0.0
	if enemies_killed > 0:
		for m in before["monsters"]:
			if m["hp"] > 0:
				# Check if this enemy was killed (find matching alive in after)
				var still_alive := false
				for m2 in after["monsters"]:
					if m2["hp"] > 0:
						still_alive = true
						break
				if not still_alive or enemies_killed > 0:
					var saved_per_turn: float = float(m["base_dmg"]) + float(m["dmg_inc"]) * float(turn)
					kill_bonus += saved_per_turn * est_remaining_turns
					enemies_killed -= 1
					if enemies_killed <= 0:
						break

	# --- Block efficiency: excess block is less valuable (unless barricade) ---
	var block_waste: float = 0.0
	if not after["barricade"]:
		block_waste = float(maxi(0, after["hero_block"] - incoming_dmg)) * 0.3

	# --- Deck thinning bonus: exhausting weak cards improves future draw quality ---
	var thin_bonus: float = 0.0
	# Compare exhaust piles: cards exhausted this play
	var exhausted_now: int = after["exhaust_pile"].size() - before["exhaust_pile"].size()
	if exhausted_now > 0:
		# Count how many exhausted cards were low-value (status/basic)
		for i in range(before["exhaust_pile"].size(), after["exhaust_pile"].size()):
			if i < after["exhaust_pile"].size():
				var ex_id: String = after["exhaust_pile"][i]
				var ex_card: Dictionary = card_db.get(ex_id, {})
				if ex_card.get("unplayable", false) or ex_card.get("type", 0) == 3:
					thin_bonus += 4.0  # Removing a dead draw is very valuable
				elif ex_id.ends_with("_strike") or ex_id.ends_with("_defend"):
					thin_bonus += 2.0  # Removing basics is moderately valuable
				# High-value cards exhausted = not a bonus (already penalized by losing the card)

	# Score = negative total estimated HP loss (higher = better)
	return -(hp_loss_now + future_hp_loss - kill_bonus + block_waste) + thin_bonus


func _get_card_cost(state: Dictionary, card: Dictionary) -> int:
	var cost: int = card.get("cost", 0)
	if cost == -1:
		cost = state["energy"]
	if state["corruption"] and card.get("type", 0) == 1:
		cost = 0
	return cost


func _copy_state(state: Dictionary) -> Dictionary:
	"""Deep copy battle state for simulation."""
	var copy: Dictionary = state.duplicate(true)
	return copy


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

	# Status effects on enemy (reuse apply_status from above)
	if not apply_status.is_empty():
		var st: String = apply_status.get("type", "")
		var stacks: int = apply_status.get("stacks", 1)
		if st == "poison":
			score += stacks * 2.0
		elif st == "vulnerable":
			score += stacks * 5.0
		elif st == "weak":
			score += stacks * 3.0

	# Deck-thinning bonus: cards that exhaust themselves or others thin the deck
	if card.get("exhaust", false) or card.get("random_exhaust", false) or card.get("exhaust_non_attacks", false):
		# Count how many weak cards are in hand that could be exhausted
		var weak_in_hand := 0
		for other_id in state["hand"]:
			if other_id == card_id:
				continue
			var oc: Dictionary = card_db.get(other_id, {})
			if oc.get("unplayable", false) or oc.get("type", 0) == 3:
				weak_in_hand += 1
			elif other_id.ends_with("_strike") or other_id.ends_with("_defend"):
				weak_in_hand += 1
		if card.get("random_exhaust", false) or card.get("exhaust_non_attacks", false):
			score += mini(weak_in_hand, 3) * 3.0  # Bonus for having weak cards to exhaust
		elif card.get("exhaust", false) and card_type != 2:
			score += 1.5  # Self-exhaust at least thins the card itself

	if cost > 0:
		score = score / cost
	return score


func _play_card(state: Dictionary, card_id: String, is_replay: bool = false) -> void:
	var card: Dictionary = card_db.get(card_id, {})
	if card.is_empty():
		return
	# Safety cap: prevent runaway card-play cascades
	state["_play_count"] += 1
	if state["_play_count"] > 50:
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
					var actual_block: int = maxi(0, block + state["hero_dexterity"])
					state["hero_block"] += actual_block
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
					state["hero_dexterity"] += stacks
				elif status == "weak":
					state["hero_weak"] += stacks
				elif status == "vulnerable":
					state["hero_vulnerable"] += stacks
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
			"copy_to_discard":
				var copy_id: String = action.get("card_id", card_id)
				state["discard_pile"].append(copy_id)
			"add_card_to_draw":
				var draw_id: String = action.get("card_id", "")
				if draw_id != "":
					state["draw_pile"].insert(randi() % maxi(state["draw_pile"].size(), 1), draw_id)
			"add_card_to_discard":
				var discard_id: String = action.get("card_id", "")
				if discard_id != "":
					state["discard_pile"].append(discard_id)
			"add_card_to_hand":
				var hand_id: String = action.get("card_id", "")
				var hand_count: int = action.get("count", 1)
				for _h in range(hand_count):
					if hand_id != "" and state["hand"].size() < 10:
						state["hand"].append(hand_id)
			"power_effect":
				var power: String = action.get("power", "")
				_activate_power(state, power)
			"next_turn":
				# Queue effect for next turn (Dodge and Roll, Outmaneuver, Flying Knee)
				var nt_entry: Dictionary = {}
				if action.has("block"):
					nt_entry = {"type": "block", "value": action["block"] + state["hero_dexterity"]}
				elif action.has("energy"):
					nt_entry = {"type": "gain_energy", "value": action["energy"]}
				if not nt_entry.is_empty():
					state["next_turn_effects"].append(nt_entry)
			"blur":
				state["blur"] = true
			"burst":
				state["burst"] += 1
			"call":
				var fn: String = action.get("fn", "")
				_call_fn(state, card, fn, target_type)

	# Handle discard N (Survivor, Dagger Throw, Acrobatics, Prepared, etc.)
	var disc_count: int = card.get("discard", 0)
	if disc_count > 0 and not state["hand"].is_empty():
		for _d in range(mini(disc_count, state["hand"].size())):
			var disc_idx: int = _pick_discard_idx(state)
			var discarded_id: String = state["hand"][disc_idx]
			state["hand"].remove_at(disc_idx)
			_discard_with_sly(state, discarded_id)

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
		state["exhaust_pile"].append(card_id)  # Powers don't trigger feel_no_pain
	elif should_exhaust:
		_exhaust_card(state, card_id)  # Triggers feel_no_pain + dark_embrace
	else:
		state["discard_pile"].append(card_id)

	# Track attacks
	if card_type == 0:
		state["attacks_played"] += 1
		if state["rage"]:
			state["hero_block"] += state["rage_block"]
		# Double Tap: replay the attack (only on original play, not on replay)
		if not is_replay and state["double_tap"] > 0:
			state["double_tap"] -= 1
			_play_card(state, card_id, true)
	# Burst: replay the skill (only on original play)
	elif card_type == 1 and not is_replay and state["burst"] > 0:
		state["burst"] -= 1
		_play_card(state, card_id, true)


func _deal_damage(state: Dictionary, card: Dictionary, target_type: String) -> void:
	var base_dmg: int = card.get("damage", 0)
	# Accuracy boosts shiv damage
	var card_id_str: String = card.get("id", "")
	if card_id_str.begins_with("si_shiv") and state["accuracy"] > 0:
		base_dmg += state["accuracy"]
	var str_mult: int = card.get("str_mult", 1)
	var times_val: int = card.get("times", 1)
	var per_hit: int = base_dmg + state["hero_strength"] * str_mult
	# Hero weak: attacks deal 25% less damage
	if state["hero_weak"] > 0:
		per_hit = int(per_hit * 0.75)

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


func _pick_exhaust_idx(state: Dictionary, exclude_id: String = "") -> int:
	"""Pick the best card to exhaust — prioritize status/curse, then basics, then lowest value.
	Exhausting removes a card permanently, so prefer removing weak cards to thin the deck."""
	# 1st: status/curse cards (Wound, Dazed, Burn, Slimed) — pure dead weight
	for i in range(state["hand"].size()):
		var cid: String = state["hand"][i]
		if cid == exclude_id:
			continue
		var c: Dictionary = card_db.get(cid, {})
		if c.get("unplayable", false) or c.get("type", 0) == 3:
			return i
	# 2nd: basic Strike/Defend — low value, thinning them improves future draws
	for i in range(state["hand"].size()):
		var cid: String = state["hand"][i]
		if cid == exclude_id:
			continue
		if cid.ends_with("_strike") or cid.ends_with("_defend"):
			return i
	# 3rd: lowest-value card by simple heuristic
	var worst: int = -1
	var worst_val: float = 999.0
	for i in range(state["hand"].size()):
		var cid: String = state["hand"][i]
		if cid == exclude_id:
			continue
		var c: Dictionary = card_db.get(cid, {})
		var val: float = float(c.get("damage", 0)) + float(c.get("block", 0)) + float(c.get("draw", 0)) * 3.0 + float(c.get("type", 0) == 2) * 20.0
		if val < worst_val:
			worst_val = val
			worst = i
	return worst if worst >= 0 else 0


func _exhaust_card(state: Dictionary, card_id: String) -> void:
	"""Exhaust a card and trigger feel_no_pain / dark_embrace if active."""
	state["exhaust_pile"].append(card_id)
	if state["feel_no_pain"]:
		state["hero_block"] += state["feel_no_pain_block"]
	if state["dark_embrace"]:
		_draw_cards(state, 1)


func _pick_discard_idx(state: Dictionary) -> int:
	"""Pick the best card to discard — prioritize sly cards, then worst value."""
	# First: look for sly cards (they trigger effects when discarded)
	for i in range(state["hand"].size()):
		var cid: String = state["hand"][i]
		var c: Dictionary = card_db.get(cid, {})
		if c.get("special", "") == "sly":
			return i
	# Second: look for unplayable/status cards (wounds, dazed, burn)
	for i in range(state["hand"].size()):
		var cid: String = state["hand"][i]
		var c: Dictionary = card_db.get(cid, {})
		if c.get("unplayable", false) or c.get("type", 0) == 3:
			return i
	# Fallback: pick lowest-value card
	var worst: int = 0
	var worst_val: float = 999.0
	for i in range(state["hand"].size()):
		var cid: String = state["hand"][i]
		var c: Dictionary = card_db.get(cid, {})
		var val: float = float(c.get("damage", 0)) + float(c.get("block", 0)) + float(c.get("draw", 0)) * 2.0 - float(c.get("cost", 0)) * 0.5
		if val < worst_val:
			worst_val = val
			worst = i
	return worst


func _discard_with_sly(state: Dictionary, discarded_id: String) -> void:
	"""Discard a card and trigger sly effect if applicable."""
	var discarded_card: Dictionary = card_db.get(discarded_id, {})
	state["discard_pile"].append(discarded_id)
	# Trigger sly — execute the card's effects without spending energy
	if discarded_card.get("special", "") == "sly":
		var sly_target: String = discarded_card.get("target", "self")
		# Damage
		if discarded_card.get("damage", 0) > 0:
			_deal_damage(state, discarded_card, sly_target)
		# Draw
		var sly_draw: int = discarded_card.get("draw", 0)
		if sly_draw > 0:
			_draw_cards(state, sly_draw)
		# Energy gain
		for action in discarded_card.get("actions", []):
			if action.get("type", "") == "gain_energy":
				state["energy"] += action.get("value", 1)


func _activate_power(state: Dictionary, power: String) -> void:
	match power:
		"demon_form": state["demon_form"] += 2
		"demon_form_plus": state["demon_form"] += 3
		"metallicize": state["metallicize"] += 3
		"metallicize_plus": state["metallicize"] += 4
		"noxious_fumes": state["noxious_fumes"] += 2
		"noxious_fumes_plus": state["noxious_fumes"] += 3
		"envenom": state["envenom"] = true
		"accuracy": state["accuracy"] += 4  # Boosts shiv damage
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
		"infinite_blades": state["infinite_blades"] += 1
		"caltrops": state["caltrops"] += 3
		"caltrops_plus": state["caltrops"] += 5
		"evolve": pass  # Draw on status card drawn — niche, skip
		"well_laid_plans": pass  # Retain mechanic — complex, skip
		"tools_of_the_trade": state["tools_of_the_trade"] += 1
		"double_tap": state["double_tap"] += 1
		"burst": state["burst"] += 1
		"wraith_form": pass  # Intangible — complex, skip
		"brutality": state["brutality"] += 1
		"combust": state["combust"] += 5
		"combust_plus": state["combust"] += 7


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
		"calculated_gamble":
			var hand_size: int = state["hand"].size()
			for cid in state["hand"].duplicate():
				_discard_with_sly(state, cid)
			state["hand"].clear()
			# Upgraded version draws +1
			var draw_n: int = hand_size
			if card.get("upgraded", false):
				draw_n += 1
			_draw_cards(state, draw_n)
		"concentrate":
			var disc_n: int = card.get("discard_count", 3)
			var gain: int = card.get("energy_gain_val", 2)
			for _d in range(mini(disc_n, state["hand"].size())):
				var idx: int = _pick_discard_idx(state)
				var cid: String = state["hand"][idx]
				state["hand"].remove_at(idx)
				_discard_with_sly(state, cid)
			state["energy"] += gain
		"storm_of_steel":
			var hand_count: int = state["hand"].size()
			for cid in state["hand"].duplicate():
				_discard_with_sly(state, cid)
			state["hand"].clear()
			var shiv_dmg: int = card.get("generate_damage", 4)
			for _s in range(hand_count):
				if state["hand"].size() < 10:
					state["hand"].append("si_shiv")
		"anticipate":
			# Gain temporary dexterity this turn
			var ant_dex: int = card.get("dex_stacks", 1)
			state["hero_dexterity"] += ant_dex
			state["hero_temp_dexterity"] += ant_dex
		"escape_plan":
			# Draw 1 card; if drawn card is a Skill, gain block
			var ep_hand_before: int = state["hand"].size()
			_draw_cards(state, 1)
			if state["hand"].size() > ep_hand_before:
				var drawn_id: String = state["hand"].back()
				var drawn_card: Dictionary = card_db.get(drawn_id, {})
				if drawn_card.get("type", 0) == 1:  # SKILL
					var ep_block: int = card.get("block", 3) + state["hero_dexterity"]
					state["hero_block"] += maxi(0, ep_block)
		"finisher":
			# Deal damage × number of attacks played this turn
			var fin_target = _first_alive(state)
			if not fin_target.is_empty():
				var fin_per: int = card.get("damage", 6) + state["hero_strength"]
				if state["hero_weak"] > 0:
					fin_per = int(fin_per * 0.75)
				if fin_target["vulnerable"] > 0:
					fin_per = int(fin_per * 1.5)
				for _i in range(state["attacks_played"]):
					fin_target["hp"] -= fin_per
					state["current_turn_dmg"] += fin_per
		"heel_hook":
			# Deal damage; if enemy is Weak, gain energy + draw
			var hh_target = _first_alive(state)
			if not hh_target.is_empty():
				var hh_dmg: int = card.get("damage", 5) + state["hero_strength"]
				if state["hero_weak"] > 0:
					hh_dmg = int(hh_dmg * 0.75)
				if hh_target["vulnerable"] > 0:
					hh_dmg = int(hh_dmg * 1.5)
				hh_target["hp"] -= hh_dmg
				state["current_turn_dmg"] += hh_dmg
				if hh_target["weak"] > 0:
					state["energy"] += 1
					_draw_cards(state, 1)
		"glass_knife":
			# Deal damage twice; damage decreases by 2 each use
			if not state.has("glass_knife_loss"):
				state["glass_knife_loss"] = 0
			var gk_target = _first_alive(state)
			if not gk_target.is_empty():
				var gk_per: int = maxi(0, card.get("damage", 8) - state["glass_knife_loss"]) + state["hero_strength"]
				if state["hero_weak"] > 0:
					gk_per = int(gk_per * 0.75)
				if gk_target["vulnerable"] > 0:
					gk_per = int(gk_per * 1.5)
				for _i in range(2):
					gk_target["hp"] -= gk_per
					state["current_turn_dmg"] += gk_per
			state["glass_knife_loss"] += 2
		"expertise":
			# Draw until hand has 6 cards (or 7 upgraded)
			var ex_target_size: int = card.get("target_hand_size", 6)
			var ex_draw: int = maxi(0, ex_target_size - state["hand"].size())
			if ex_draw > 0:
				_draw_cards(state, ex_draw)
		"unload":
			# Deal damage, discard all non-Attack cards
			_deal_damage(state, card, target_type)
			var ul_to_discard: Array = []
			for cid in state["hand"]:
				var c: Dictionary = card_db.get(cid, {})
				if c.get("type", 0) != 0:  # Non-ATTACK
					ul_to_discard.append(cid)
			for cid in ul_to_discard:
				state["hand"].erase(cid)
				_discard_with_sly(state, cid)
		"malaise":
			# X-cost: spend all energy, apply X Weak + reduce X Strength
			var ml_x: int = state["energy"]
			state["energy"] = 0
			var ml_target = _first_alive(state)
			if not ml_target.is_empty():
				ml_target["weak"] += ml_x
				# Strength reduction (negative stacks)
				# Enemies don't track strength in sim, but reduce base_dmg
				ml_target["base_dmg"] = maxi(0, ml_target["base_dmg"] - ml_x)
		"true_grit":
			# Gain block + exhaust a card from hand (pick weakest)
			var tg_block: int = card.get("block", 7) + state["hero_dexterity"]
			state["hero_block"] += maxi(0, tg_block)
			if not state["hand"].is_empty():
				var tg_idx: int = _pick_exhaust_idx(state, card.get("id", ""))
				if tg_idx >= 0 and tg_idx < state["hand"].size():
					var tg_cid: String = state["hand"][tg_idx]
					state["hand"].remove_at(tg_idx)
					_exhaust_card(state, tg_cid)
		"burning_pact":
			# Exhaust 1 card, draw 2
			if not state["hand"].is_empty():
				var bp_idx: int = _pick_exhaust_idx(state, card.get("id", ""))
				if bp_idx >= 0 and bp_idx < state["hand"].size():
					var bp_cid: String = state["hand"][bp_idx]
					state["hand"].remove_at(bp_idx)
					_exhaust_card(state, bp_cid)
			_draw_cards(state, card.get("draw", 2))
		"second_wind":
			# Exhaust all non-Attack cards in hand, gain block_per for each
			var sw_block_per: int = card.get("block_per", 5) + state["hero_dexterity"]
			var sw_to_exhaust: Array = []
			for cid in state["hand"]:
				var c: Dictionary = card_db.get(cid, {})
				if c.get("type", 0) != 0:  # Not ATTACK
					sw_to_exhaust.append(cid)
			for cid in sw_to_exhaust:
				state["hand"].erase(cid)
				_exhaust_card(state, cid)
				state["hero_block"] += maxi(0, sw_block_per)
		"sever_soul":
			# Exhaust all non-Attack cards in hand, deal damage
			var ss_to_exhaust: Array = []
			for cid in state["hand"]:
				var c: Dictionary = card_db.get(cid, {})
				if c.get("type", 0) != 0:
					ss_to_exhaust.append(cid)
			for cid in ss_to_exhaust:
				state["hand"].erase(cid)
				_exhaust_card(state, cid)
			_deal_damage(state, card, target_type)
		"fiend_fire":
			# Exhaust entire hand, deal 7 damage per card exhausted
			var ff_count: int = state["hand"].size()
			for cid in state["hand"].duplicate():
				_exhaust_card(state, cid)
			state["hand"].clear()
			var ff_target = _first_alive(state)
			if not ff_target.is_empty():
				var ff_per: int = card.get("damage", 7) + state["hero_strength"]
				if state["hero_weak"] > 0:
					ff_per = int(ff_per * 0.75)
				if ff_target["vulnerable"] > 0:
					ff_per = int(ff_per * 1.5)
				for _i in range(ff_count):
					ff_target["hp"] -= ff_per
					state["current_turn_dmg"] += ff_per
		"reaper":
			# Deal damage to ALL, heal for unblocked damage
			var rp_base: int = card.get("damage", 4) + state["hero_strength"]
			if state["hero_weak"] > 0:
				rp_base = int(rp_base * 0.75)
			var rp_healed := 0
			for m in _alive(state):
				var rp_dmg: int = rp_base
				if m["vulnerable"] > 0:
					rp_dmg = int(rp_dmg * 1.5)
				var actual: int = mini(rp_dmg, m["hp"])
				m["hp"] -= rp_dmg
				state["current_turn_dmg"] += rp_dmg
				rp_healed += actual
			state["hero_hp"] = mini(state["hero_max_hp"], state["hero_hp"] + rp_healed)
		"feed":
			# Deal damage, if kills gain max HP
			var fd_target = _first_alive(state)
			if not fd_target.is_empty():
				var fd_dmg: int = card.get("damage", 10) + state["hero_strength"]
				if state["hero_weak"] > 0:
					fd_dmg = int(fd_dmg * 0.75)
				if fd_target["vulnerable"] > 0:
					fd_dmg = int(fd_dmg * 1.5)
				fd_target["hp"] -= fd_dmg
				state["current_turn_dmg"] += fd_dmg
				if fd_target["hp"] <= 0:
					var hp_gain: int = card.get("max_hp_gain", 3)
					state["hero_max_hp"] += hp_gain
					state["hero_hp"] += hp_gain
		"dropkick":
			# Deal damage, if enemy vulnerable: gain 1 energy + draw 1
			var dk_target = _first_alive(state)
			if not dk_target.is_empty():
				var dk_dmg: int = card.get("damage", 5) + state["hero_strength"]
				if state["hero_weak"] > 0:
					dk_dmg = int(dk_dmg * 0.75)
				if dk_target["vulnerable"] > 0:
					dk_dmg = int(dk_dmg * 1.5)
				dk_target["hp"] -= dk_dmg
				state["current_turn_dmg"] += dk_dmg
				if dk_target["vulnerable"] > 0:
					state["energy"] += 1
					_draw_cards(state, 1)
		"spot_weakness":
			# Enemy always assumed to attack in sim → gain strength
			state["hero_strength"] += card.get("spot_str", 3)
		"perfected_strike":
			# Deal 6 + 2 per "strike" card in entire deck
			var ps_count := 0
			for cid in state["hand"]:
				if "strike" in cid:
					ps_count += 1
			for cid in state["draw_pile"]:
				if "strike" in cid:
					ps_count += 1
			for cid in state["discard_pile"]:
				if "strike" in cid:
					ps_count += 1
			for cid in state["exhaust_pile"]:
				if "strike" in cid:
					ps_count += 1
			ps_count += 1  # Count self
			var ps_target = _first_alive(state)
			if not ps_target.is_empty():
				var ps_dmg: int = card.get("damage", 6) + card.get("strike_bonus", 2) * ps_count + state["hero_strength"]
				if state["hero_weak"] > 0:
					ps_dmg = int(ps_dmg * 0.75)
				if ps_target["vulnerable"] > 0:
					ps_dmg = int(ps_dmg * 1.5)
				ps_target["hp"] -= ps_dmg
				state["current_turn_dmg"] += ps_dmg
		"rampage":
			# Deal damage, increases by rampage_inc each play (track in state)
			if not state.has("rampage_bonus"):
				state["rampage_bonus"] = 0
			var rmp_target = _first_alive(state)
			if not rmp_target.is_empty():
				var rmp_dmg: int = card.get("damage", 8) + state["rampage_bonus"] + state["hero_strength"]
				if state["hero_weak"] > 0:
					rmp_dmg = int(rmp_dmg * 0.75)
				if rmp_target["vulnerable"] > 0:
					rmp_dmg = int(rmp_dmg * 1.5)
				rmp_target["hp"] -= rmp_dmg
				state["current_turn_dmg"] += rmp_dmg
			state["rampage_bonus"] += card.get("rampage_inc", 5)
		"havoc":
			# Play top card of draw pile and exhaust it
			if not state["draw_pile"].is_empty():
				var hv_id: String = state["draw_pile"].pop_back()
				_play_card(state, hv_id)
				_exhaust_card(state, hv_id)
		"exhume":
			# Put best card from exhaust pile into hand
			if not state["exhaust_pile"].is_empty():
				var best_idx: int = 0
				var best_val: float = -999.0
				for i in range(state["exhaust_pile"].size()):
					var ec: Dictionary = card_db.get(state["exhaust_pile"][i], {})
					var ev: float = float(ec.get("damage", 0)) + float(ec.get("block", 0)) + float(ec.get("draw", 0)) * 3.0 + float(ec.get("type", 0) == 2) * 20.0
					if ev > best_val:
						best_val = ev
						best_idx = i
				var ex_cid: String = state["exhaust_pile"][best_idx]
				state["exhaust_pile"].remove_at(best_idx)
				state["hand"].append(ex_cid)
		"dual_wield":
			# Copy best attack or power in hand
			var dw_best: String = ""
			var dw_val: float = -999.0
			for cid in state["hand"]:
				var c: Dictionary = card_db.get(cid, {})
				var ct: int = c.get("type", 0)
				if ct == 0 or ct == 2:  # ATTACK or POWER
					var v: float = float(c.get("damage", 0)) * float(c.get("times", 1)) + float(c.get("type", 0) == 2) * 20.0
					if v > dw_val:
						dw_val = v
						dw_best = cid
			if dw_best != "":
				var copies: int = card.get("copies", 1)
				for _c in range(copies):
					if state["hand"].size() < 10:
						state["hand"].append(dw_best)
		_:
			# Fallback: just deal damage if card has it
			if card.get("damage", 0) > 0:
				_deal_damage(state, card, target_type)
