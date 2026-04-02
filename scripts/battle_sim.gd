class_name BattleSim
## Pure-logic battle simulator — finds optimal card play sequence via DFS.
## Fully data-driven: reads card properties only, no hardcoded card IDs or names.
## Usage: BattleSim.solve(battle_manager) → {sequence, score, detail}

# ---------------------------------------------------------------------------
# Lightweight state copies (no scene tree dependencies)
# ---------------------------------------------------------------------------

class SimEnemy:
	var hp: int
	var max_hp: int
	var block: int
	var strength: int
	var vulnerable: int
	var weak: int
	var poison: int
	var intent: Dictionary
	var alive: bool
	func clone() -> SimEnemy:
		var e := SimEnemy.new()
		e.hp = hp; e.max_hp = max_hp; e.block = block
		e.strength = strength; e.vulnerable = vulnerable; e.weak = weak
		e.poison = poison; e.intent = intent.duplicate(); e.alive = alive
		return e

class SimState:
	var hand: Array
	var draw_pile: Array
	var discard_pile: Array
	var exhaust_pile: Array
	# Hero stats
	var hp: int
	var max_hp: int
	var block: int
	var strength: int
	var dexterity: int
	var weak: int
	var vulnerable: int
	var energy: int
	var max_energy: int
	var powers: Dictionary       # power_id → stacks (raw game state)
	# Per-turn effect accumulators (generic, not tied to card names)
	var pt_strength: int         # strength gained at turn start
	var pt_block: int            # block gained at turn end
	var pt_poison_all: int       # poison applied to all enemies per turn
	var pt_energy: int           # extra energy per turn
	var pt_self_damage: int      # self-damage per turn
	var pt_draw: int             # extra cards drawn per turn
	var pt_damage_all: int       # damage to all enemies per turn (e.g. combust)
	# Enemies
	var enemies: Array
	# Per-turn trackers
	var attacks_played: int
	var cards_played: int
	var flex_str_to_remove: int
	var anticipate_dex_to_remove: int
	var double_damage: bool
	var burst_active: bool
	var double_tap_active: bool
	var corruption_active: bool
	var bullet_time: bool
	var no_draw_next: bool
	var blur_active: bool
	var barricade: bool
	# Sequence so far
	var sequence: Array
	var self_damage_taken: int

	func clone() -> SimState:
		var s := SimState.new()
		s.hand = _dup_cards(hand)
		s.draw_pile = _dup_cards(draw_pile)
		s.discard_pile = _dup_cards(discard_pile)
		s.exhaust_pile = _dup_cards(exhaust_pile)
		s.hp = hp; s.max_hp = max_hp; s.block = block
		s.strength = strength; s.dexterity = dexterity
		s.weak = weak; s.vulnerable = vulnerable
		s.energy = energy; s.max_energy = max_energy
		s.powers = powers.duplicate()
		s.pt_strength = pt_strength; s.pt_block = pt_block
		s.pt_poison_all = pt_poison_all; s.pt_energy = pt_energy
		s.pt_self_damage = pt_self_damage; s.pt_draw = pt_draw
		s.pt_damage_all = pt_damage_all
		s.enemies = []
		for e in enemies:
			s.enemies.append(e.clone())
		s.attacks_played = attacks_played; s.cards_played = cards_played
		s.flex_str_to_remove = flex_str_to_remove
		s.anticipate_dex_to_remove = anticipate_dex_to_remove
		s.double_damage = double_damage
		s.burst_active = burst_active; s.double_tap_active = double_tap_active
		s.corruption_active = corruption_active
		s.bullet_time = bullet_time; s.no_draw_next = no_draw_next
		s.blur_active = blur_active; s.barricade = barricade
		s.sequence = sequence.duplicate()
		s.self_damage_taken = self_damage_taken
		return s

	static func _dup_cards(arr: Array) -> Array:
		var out: Array = []
		for c in arr:
			out.append(c.duplicate(true))
		return out

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
const MAX_HAND := 10
const MAX_FIGHT_TURNS := 25
const MAX_SEARCH_NODES := 80000

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

static func solve(bm) -> Dictionary:
	var state := _snapshot(bm)
	if state == null:
		return {"sequence": [], "score": 0.0, "detail": "无法读取战斗状态"}
	var ctx := {"best_score": -99999.0, "best_seq": [], "best_state": null, "nodes": 0}
	_dfs(state, ctx)
	var detail := _format_result(ctx)
	return {"sequence": ctx["best_seq"], "score": ctx["best_score"], "detail": detail}

# ---------------------------------------------------------------------------
# State snapshot from live battle_manager
# ---------------------------------------------------------------------------

static func _snapshot(bm) -> SimState:
	if bm == null:
		return null
	var s := SimState.new()
	var hero = bm.player
	if hero == null:
		return null
	s.hp = hero.current_hp
	s.max_hp = hero.max_hp
	s.block = hero.block
	s.strength = hero.get_status_stacks("strength") if hero.has_method("get_status_stacks") else hero.status_effects.get("strength", 0)
	s.dexterity = hero.status_effects.get("dexterity", 0)
	s.weak = hero.status_effects.get("weak", 0)
	s.vulnerable = hero.status_effects.get("vulnerable", 0)
	s.energy = bm.current_energy
	s.max_energy = bm.max_energy
	var pw: Dictionary = hero.active_powers.duplicate() if hero.get("active_powers") else {}
	s.powers = pw
	s.corruption_active = bm.get("corruption_active") == true
	s.double_damage = bm.get("_double_damage_this_turn") == true
	s.burst_active = bm.get("_burst_active") == true
	s.double_tap_active = bm.get("_double_tap_active") == true
	s.bullet_time = bm.get("_bullet_time_this_turn") == true
	s.no_draw_next = bm.get("_no_draw_next_turn") == true
	s.blur_active = bm.get("_blur_active") == true
	s.barricade = pw.get("barricade", 0) > 0
	s.attacks_played = bm.get("attacks_played_this_turn") if bm.get("attacks_played_this_turn") != null else 0
	s.cards_played = bm.get("cards_played_this_turn") if bm.get("cards_played_this_turn") != null else 0
	s.flex_str_to_remove = bm.get("flex_strength_to_remove") if bm.get("flex_strength_to_remove") != null else 0
	s.anticipate_dex_to_remove = bm.get("anticipate_dex_to_remove") if bm.get("anticipate_dex_to_remove") != null else 0
	# Capture per-turn effects from active powers generically.
	# These accumulate from power cards already played before this turn.
	# We read known power effect mappings from the BM if available, otherwise
	# scan the powers dict for any that have per_turn data attached.
	s.pt_strength = 0; s.pt_block = 0; s.pt_poison_all = 0
	s.pt_energy = 0; s.pt_self_damage = 0; s.pt_draw = 0; s.pt_damage_all = 0
	# Read per-turn data that BM may have stored on the hero
	if hero.has_method("get_meta") and hero.has_meta("sim_per_turn"):
		var pt: Dictionary = hero.get_meta("sim_per_turn")
		s.pt_strength = pt.get("strength", 0)
		s.pt_block = pt.get("block", 0)
		s.pt_poison_all = pt.get("poison_all", 0)
		s.pt_energy = pt.get("energy", 0)
		s.pt_self_damage = pt.get("self_damage", 0)
		s.pt_draw = pt.get("draw", 0)
		s.pt_damage_all = pt.get("damage_all", 0)
	else:
		# Fallback: scan all deck cards for power cards matching active power names,
		# read their per_turn data. Handles cases where sim_per_turn metadata wasn't set.
		var all_deck: Array = []
		all_deck.append_array(bm.hand)
		all_deck.append_array(bm.draw_pile)
		all_deck.append_array(bm.discard_pile)
		if bm.get("exhaust_pile"):
			all_deck.append_array(bm.exhaust_pile)
		var found_powers: Dictionary = {}  # power_base_name → per_turn dict
		for c in all_deck:
			var pe: String = c.get("power_effect", "")
			if pe == "":
				continue
			var base_pe: String = pe.trim_suffix("_plus")
			if pw.has(base_pe) and not found_powers.has(base_pe):
				var cpt: Dictionary = c.get("per_turn", {})
				if not cpt.is_empty():
					found_powers[base_pe] = cpt
		for pk in found_powers:
			var pt: Dictionary = found_powers[pk]
			s.pt_strength += pt.get("strength", 0)
			s.pt_block += pt.get("block", 0)
			s.pt_poison_all += pt.get("poison_all", 0)
			s.pt_energy += pt.get("energy", 0)
			s.pt_self_damage += pt.get("self_damage", 0)
			s.pt_draw += pt.get("draw", 0)
			s.pt_damage_all += pt.get("damage_all", 0)
	# Hand / piles
	s.hand = SimState._dup_cards(bm.hand)
	s.draw_pile = SimState._dup_cards(bm.draw_pile)
	s.discard_pile = SimState._dup_cards(bm.discard_pile)
	s.exhaust_pile = SimState._dup_cards(bm.exhaust_pile) if bm.get("exhaust_pile") else []
	# Enemies
	s.enemies = []
	for enemy in bm.enemies:
		if not enemy.alive:
			continue
		var se := SimEnemy.new()
		se.hp = enemy.current_hp; se.max_hp = enemy.max_hp; se.block = enemy.block
		se.strength = enemy.status_effects.get("strength", 0)
		se.vulnerable = enemy.status_effects.get("vulnerable", 0)
		se.weak = enemy.status_effects.get("weak", 0)
		se.poison = enemy.status_effects.get("poison", 0)
		se.intent = enemy.intent.duplicate() if enemy.intent else {}
		se.alive = true
		s.enemies.append(se)
	s.sequence = []
	s.self_damage_taken = 0
	return s

# ---------------------------------------------------------------------------
# DFS search
# ---------------------------------------------------------------------------

static func _dfs(state: SimState, ctx: Dictionary) -> void:
	ctx["nodes"] = ctx["nodes"] + 1
	if ctx["nodes"] > MAX_SEARCH_NODES:
		return
	var end_score: float = _evaluate(state)
	if end_score > ctx["best_score"]:
		ctx["best_score"] = end_score
		ctx["best_seq"] = state.sequence.duplicate()
		ctx["best_state"] = state.clone()
	var tried_ids := {}
	for i in range(state.hand.size()):
		var card: Dictionary = state.hand[i]
		var card_id: String = card.get("id", str(i))
		if tried_ids.has(card_id):
			continue
		tried_ids[card_id] = true
		if not _can_play(state, card):
			continue
		var cost: int = _get_cost(state, card)
		if cost < 0:
			continue
		if cost > state.energy and not state.bullet_time:
			continue
		var ns: SimState = state.clone()
		_sim_play_card(ns, i, cost)
		_dfs(ns, ctx)

# ---------------------------------------------------------------------------
# Playability / cost — data-driven via card properties
# ---------------------------------------------------------------------------

static func _can_play(s: SimState, card: Dictionary) -> bool:
	if card.get("unplayable", false):
		return false
	# "play_condition" field: generic conditions from card data
	var cond: String = card.get("play_condition", card.get("special", ""))
	if cond == "clash" or cond == "only_attacks":
		for c in s.hand:
			if c.get("type", 0) != 0:
				return false
	if cond == "grand_finale" or cond == "empty_draw":
		if not s.draw_pile.is_empty():
			return false
	return true

static func _get_cost(s: SimState, card: Dictionary) -> int:
	var cost: int = card.get("cost", 0)
	if cost == -1:
		return s.energy
	if cost < -1:
		return -999
	if s.bullet_time:
		return 0
	if s.corruption_active and card.get("type", 0) == 1:
		return 0
	return cost

# ---------------------------------------------------------------------------
# Simulate playing a card
# ---------------------------------------------------------------------------

static func _sim_play_card(s: SimState, hand_idx: int, cost: int) -> void:
	var card: Dictionary = s.hand[hand_idx]
	var energy_spent: int = cost
	s.energy -= cost
	s.hand.remove_at(hand_idx)
	s.sequence.append(card.get("id", "?"))

	var is_attack: bool = card.get("type", 0) == 0
	var is_skill: bool = card.get("type", 0) == 1
	var is_power: bool = card.get("type", 0) == 2

	_sim_execute(s, card, energy_spent)

	if s.burst_active and is_skill:
		s.burst_active = false
		_sim_execute(s, card, energy_spent)
	if s.double_tap_active and is_attack:
		s.double_tap_active = false
		_sim_execute(s, card, energy_spent)

	s.cards_played += 1
	if is_attack:
		s.attacks_played += 1

	# On-play triggers from powers
	if is_attack:
		var rage_val: int = s.powers.get("rage", 0)
		if rage_val > 0:
			_sim_add_block(s, rage_val)
	var atc: int = s.powers.get("a_thousand_cuts", 0)
	if atc > 0:
		for e in s.enemies:
			if e.alive:
				_sim_damage_enemy(s, e, atc)
	var ai_val: int = s.powers.get("after_image", 0)
	if ai_val > 0:
		_sim_add_block(s, ai_val)

	# Card destination
	if is_power or card.get("exhaust", false) or (s.corruption_active and is_skill):
		s.exhaust_pile.append(card)
		var fnp: int = s.powers.get("feel_no_pain", 0)
		if fnp > 0:
			_sim_add_block(s, fnp)
	else:
		s.discard_pile.append(card)

# ---------------------------------------------------------------------------
# Execute card actions — generic action interpreter
# ---------------------------------------------------------------------------

static func _sim_execute(s: SimState, card: Dictionary, energy_spent: int) -> void:
	var actions: Array = card.get("actions", [])
	var target_type: String = card.get("target", "enemy")
	for action in actions:
		var atype: String = action.get("type", "")
		match atype:
			"damage":
				var base: int = action.get("value", card.get("damage", 0))
				var times: int = action.get("times", card.get("times", 1))
				var dmg: int = _calc_attack_damage(s, base)
				if s.double_damage:
					dmg *= 2
				if dmg > 0:
					_deal_damage(s, dmg, times, target_type)
			"damage_all":
				var base: int = action.get("value", card.get("damage", 0))
				var times: int = action.get("times", card.get("times", 1))
				var dmg: int = _calc_attack_damage(s, base)
				if s.double_damage:
					dmg *= 2
				if dmg > 0:
					_deal_damage(s, dmg, times, "all_enemies")
			"block":
				var blk: int = action.get("value", card.get("block", 0))
				if blk > 0:
					_sim_add_block(s, blk)
			"draw":
				var count: int = action.get("value", card.get("draw", 1))
				if count > 0:
					_sim_draw(s, count)
			"apply_status":
				var source_key: String = action.get("source", "")
				var st: String = action.get("status", "")
				var stk: int = action.get("stacks", 1)
				if source_key != "" and card.has(source_key):
					var src = card[source_key]
					st = src.get("type", st)
					stk = src.get("stacks", stk)
				var st_times: int = action.get("times", card.get("times", 1))
				if st != "":
					for _t in range(st_times):
						_apply_status_to_target(s, target_type, st, stk)
			"apply_self_status":
				var st: String = action.get("status", "")
				var stk: int = action.get("stacks", 1)
				_apply_hero_status(s, st, stk)
			"gain_energy":
				s.energy += action.get("value", 1)
			"self_damage":
				var amount: int = action.get("value", 0)
				if amount > 0:
					s.hp -= amount
					s.self_damage_taken += amount
					# Rupture-like: if power grants strength on self-damage
					var rupt: int = s.powers.get("rupture", 0)
					if rupt > 0:
						s.strength += rupt
			"next_turn":
				pass
			"blur":
				s.blur_active = true
			"phantasmal_killer":
				pass
			"burst":
				s.burst_active = true
			"bullet_time":
				s.bullet_time = true
				s.no_draw_next = true
			"heal":
				s.hp = mini(s.hp + action.get("value", 0), s.max_hp)
			"add_shiv":
				var count: int = action.get("value", 1)
				var shiv_dmg: int = action.get("damage", 4) + s.powers.get("accuracy", 0)
				for _i in range(count):
					if s.hand.size() >= MAX_HAND:
						break
					s.hand.append({"id": "_shiv", "name": "Shiv", "cost": 0, "type": 0,
						"damage": shiv_dmg, "block": 0, "target": "enemy",
						"exhaust": true, "actions": [{"type": "damage"}]})
			"copy_to_discard":
				s.discard_pile.append(card.duplicate(true))
			"add_card_to_draw", "add_card_to_discard", "add_card_to_hand":
				pass  # Status card injection — minor, skip for sim accuracy
			"power_effect":
				_sim_activate_power(s, card, action)
			"call":
				_sim_call_generic(s, card, energy_spent)

# ---------------------------------------------------------------------------
# Generic "call" handler — infers card behavior from its data properties
# ---------------------------------------------------------------------------

static func _sim_call_generic(s: SimState, card: Dictionary, energy_spent: int) -> void:
	var target_type: String = card.get("target", "enemy")
	var base_dmg: int = card.get("damage", 0)
	var base_blk: int = card.get("block", 0)
	var draw_val: int = card.get("draw", 0)
	var times: int = card.get("times", 1)
	var is_x_cost: bool = card.get("cost", 0) == -1

	# --- Check special card properties (read from card data, not IDs) ---

	# Temporary strength (flex_stacks)
	var flex: int = card.get("flex_stacks", 0)
	if flex > 0:
		s.strength += flex
		s.flex_str_to_remove += flex

	# Temporary dexterity (temp_dex)
	var tdex: int = card.get("temp_dex", 0)
	if tdex > 0:
		s.dexterity += tdex
		s.anticipate_dex_to_remove += tdex

	# Poison multiplier (poison_mult) — multiply target's existing poison
	var pmult: int = card.get("poison_mult", 0)
	if pmult > 0:
		var te := _pick_target(s, target_type)
		if te and te.poison > 0:
			te.poison += te.poison * (pmult - 1)

	# Strength multiplier on damage (str_mult)
	var smult: int = card.get("str_mult", 0)
	if smult > 0 and base_dmg > 0:
		var dmg: int = base_dmg + s.strength * smult
		if s.weak > 0:
			dmg = int(dmg * 0.75)
		if s.double_damage:
			dmg *= 2
		dmg = maxi(0, dmg)
		_deal_damage(s, dmg, 1, target_type)
		return  # str_mult cards handle their own damage — done

	# Strength doubling (double_strength flag)
	if card.get("double_strength", false):
		if s.strength > 0:
			s.strength *= 2

	# Block doubling (double_block flag)
	if card.get("double_block", false):
		_sim_add_block(s, s.block)

	# Block from enemy poison (block_from_enemy_poison flag)
	if card.get("block_from_enemy_poison", false):
		var total_p: int = 0
		for e in s.enemies:
			if e.alive:
				total_p += e.poison
		if total_p > 0:
			_sim_add_block(s, total_p)

	# Block-as-damage (damage_from_block flag)
	if card.get("damage_from_block", false):
		var dmg: int = s.block
		if dmg > 0:
			_deal_damage(s, dmg, 1, target_type)
		return

	# Hand-size-as-damage (damage_per_hand)
	var dph: int = card.get("damage_per_hand", 0)
	if dph > 0:
		var dmg: int = _calc_attack_damage(s, s.hand.size() * dph)
		if s.double_damage:
			dmg *= 2
		_deal_damage(s, dmg, 1, target_type)

	# Exhaust hand + hit per card (exhaust_hand_damage flag)
	if card.get("exhaust_hand_damage", false):
		var n: int = s.hand.size()
		var per_hit: int = _calc_attack_damage(s, base_dmg)
		if s.double_damage:
			per_hit *= 2
		for c in s.hand:
			s.exhaust_pile.append(c)
			var fnp: int = s.powers.get("feel_no_pain", 0)
			if fnp > 0:
				_sim_add_block(s, fnp)
		s.hand.clear()
		if n > 0 and per_hit > 0:
			_deal_damage(s, per_hit, n, target_type)
		return

	# Exhaust non-attacks + block per card (exhaust_non_attack_block)
	var enab: int = card.get("exhaust_non_attack_block", card.get("block_per", 0))
	if enab > 0:
		var to_exhaust: Array = []
		for c in s.hand:
			if c.get("type", 0) != 0:
				to_exhaust.append(c)
		for c in to_exhaust:
			s.hand.erase(c)
			s.exhaust_pile.append(c)
			_sim_add_block(s, enab)
			var fnp: int = s.powers.get("feel_no_pain", 0)
			if fnp > 0:
				_sim_add_block(s, fnp)
		if base_dmg > 0:
			var dmg: int = _calc_attack_damage(s, base_dmg)
			if s.double_damage:
				dmg *= 2
			_deal_damage(s, dmg, 1, target_type)
		return

	# Exhaust non-attacks only (exhaust_non_attacks flag)
	if card.get("exhaust_non_attacks", false):
		var to_exhaust: Array = []
		for c in s.hand:
			if c.get("type", 0) != 0:
				to_exhaust.append(c)
		for c in to_exhaust:
			s.hand.erase(c)
			s.exhaust_pile.append(c)

	# Discard hand + draw same count (discard_hand_redraw flag)
	if card.get("discard_hand_redraw", false):
		var n: int = s.hand.size()
		for c in s.hand:
			s.discard_pile.append(c)
		s.hand.clear()
		_sim_draw(s, n)
		return

	# Discard hand + generate per card (discard_hand_generate)
	if card.get("discard_hand_generate", false):
		var n: int = s.hand.size()
		for c in s.hand:
			s.discard_pile.append(c)
		s.hand.clear()
		# Generate N shiv-like cards (accuracy applied via add_shiv action)
		var gen_dmg: int = card.get("generate_damage", 4) + s.powers.get("accuracy", 0)
		for _i in range(n):
			if s.hand.size() >= MAX_HAND:
				break
			s.hand.append({"id": "_gen", "cost": 0, "type": 0,
				"damage": gen_dmg, "block": 0, "target": "enemy",
				"exhaust": true, "actions": [{"type": "damage"}]})
		return

	# Spot weakness: conditional strength if enemy attacking (spot_str)
	var sstr: int = card.get("spot_str", 0)
	if sstr > 0:
		var te := _pick_target(s, target_type)
		if te:
			var itype: String = te.intent.get("type", "")
			if "attack" in itype:
				s.strength += sstr

	# Draw up to hand size (target_hand_size)
	var ths: int = card.get("target_hand_size", 0)
	if ths > 0:
		var to_draw: int = maxi(0, ths - s.hand.size())
		if to_draw > 0:
			_sim_draw(s, to_draw)

	# Discard N + gain energy (discard_count + energy_gain_val)
	var disc_n: int = card.get("discard_count", 0)
	var egain: int = card.get("energy_gain_val", 0)
	if disc_n > 0:
		var to_discard: int = mini(disc_n, s.hand.size())
		for _i in range(to_discard):
			if not s.hand.is_empty():
				var worst: int = _pick_worst_card_idx(s)
				s.discard_pile.append(s.hand[worst])
				s.hand.remove_at(worst)
		if egain > 0:
			s.energy += egain

	# Conditional energy + draw on target status (conditional_on_status)
	var cos: Dictionary = card.get("conditional_on_status", {})
	if not cos.is_empty():
		var te := _pick_target(s, target_type)
		if te:
			var cond_st: String = cos.get("status", "")
			if cond_st != "" and _enemy_has_status(te, cond_st):
				s.energy += cos.get("energy", 0)
				var cd: int = cos.get("draw", 0)
				if cd > 0:
					_sim_draw(s, cd)

	# Rampage-like scaling (rampage_inc → stored on card data)
	var rinc: int = card.get("rampage_inc", 0)
	if rinc > 0:
		var bonus: int = card.get("_rampage_bonus", 0)
		base_dmg += bonus
		card["_rampage_bonus"] = bonus + rinc

	# Damage degrade per use (damage_degrade)
	var ddegrade: int = card.get("damage_degrade", 0)

	# Attacks-played scaling (hits_per_attack)
	var hpa: bool = card.get("hits_per_attack", false)
	if hpa:
		times = maxi(1, s.attacks_played)

	# Kill bonus (max_hp_gain)
	var mhpg: int = card.get("max_hp_gain", 0)

	# Escape block: draw 1, maybe gain block (escape_block)
	var eblk: int = card.get("escape_block", 0)
	if eblk > 0 and base_dmg == 0 and base_blk == 0:
		_sim_draw(s, 1)
		_sim_add_block(s, int(eblk * 0.4))
		return

	# Consume all energy for effect (consume_energy)
	if card.get("consume_energy", false):
		var e_spent: int = s.energy
		s.energy = 0
		var draw_per_e: int = card.get("draw_per_energy", 0)
		if draw_per_e > 0:
			_sim_draw(s, e_spent * draw_per_e)
		return

	# Random exhaust 1 from hand (random_exhaust)
	if card.get("random_exhaust", false) and not s.hand.is_empty():
		var worst: int = _pick_worst_card_idx(s)
		s.exhaust_pile.append(s.hand[worst])
		s.hand.remove_at(worst)
		var fnp: int = s.powers.get("feel_no_pain", 0)
		if fnp > 0:
			_sim_add_block(s, fnp)

	# --- X-cost damage: use energy_spent as hit count ---
	if is_x_cost and base_dmg > 0 and energy_spent > 0:
		var dmg: int = _calc_attack_damage(s, base_dmg)
		if s.double_damage:
			dmg *= 2
		_deal_damage(s, dmg, energy_spent, target_type)
		# X-cost poison per hit
		var x_poison: int = card.get("poison_per_hit", 0)
		if x_poison > 0:
			for _t in range(energy_spent):
				for e in s.enemies:
					if e.alive:
						e.poison += x_poison
		return

	# --- Generic fallback: apply base stats ---
	if base_dmg > 0:
		var dmg: int = _calc_attack_damage(s, base_dmg)
		if s.double_damage:
			dmg *= 2
		_deal_damage(s, dmg, times, target_type)
		if mhpg > 0:
			var te := _pick_target(s, target_type)
			if te and not te.alive:
				s.max_hp += mhpg
				s.hp = mini(s.hp + mhpg, s.max_hp)
	if base_blk > 0:
		_sim_add_block(s, base_blk)
	if draw_val > 0:
		_sim_draw(s, draw_val)
	# Apply status from card data fields
	_apply_card_statuses(s, card, target_type)
	# Apply damage degrade
	if ddegrade > 0:
		card["damage"] = maxi(0, card.get("damage", 0) - ddegrade)

# ---------------------------------------------------------------------------
# Generic power activation — reads stacks from card data, stores in powers dict
# ---------------------------------------------------------------------------

static func _sim_activate_power(s: SimState, card: Dictionary, action: Dictionary) -> void:
	var power_name: String = action.get("power", card.get("power_effect", ""))
	if power_name == "":
		return
	# Determine stacks: read from card data or default to current + 1
	var stacks: int = action.get("stacks", card.get("power_stacks", 0))
	if stacks == 0:
		stacks = 1  # Default: 1 stack per play
	s.powers[power_name] = s.powers.get(power_name, 0) + stacks

	# Read per-turn effects from card data if present
	var pt: Dictionary = card.get("per_turn", {})
	if not pt.is_empty():
		s.pt_strength += pt.get("strength", 0)
		s.pt_block += pt.get("block", 0)
		s.pt_poison_all += pt.get("poison_all", 0)
		s.pt_energy += pt.get("energy", 0)
		s.pt_self_damage += pt.get("self_damage", 0)
		s.pt_draw += pt.get("draw", 0)
		s.pt_damage_all += pt.get("damage_all", 0)

	# Corruption-like: if card has "skills_cost_zero" flag
	if card.get("skills_cost_zero", false):
		s.corruption_active = true

	# Self-debuff from power (e.g. self-vulnerability)
	var self_debuff: Dictionary = card.get("power_self_debuff", {})
	if not self_debuff.is_empty():
		_apply_hero_status(s, self_debuff.get("type", ""), self_debuff.get("stacks", 0))

	# Barricade-like: block retention
	if card.get("retain_block", false):
		s.barricade = true

	# Double tap / burst via power
	if card.get("double_next_attack", false):
		s.double_tap_active = true

# ---------------------------------------------------------------------------
# Damage / block helpers
# ---------------------------------------------------------------------------

static func _calc_attack_damage(s: SimState, base: int) -> int:
	var dmg: int = base + s.strength
	if s.weak > 0:
		dmg = int(dmg * 0.75)
	return maxi(0, dmg)

static func _deal_damage(s: SimState, dmg: int, times: int, target_type: String) -> void:
	if target_type == "all_enemies":
		for _t in range(times):
			for e in s.enemies:
				if e.alive:
					_sim_damage_enemy(s, e, dmg)
	elif target_type == "random_enemy":
		var te := _pick_alive_enemy(s)
		if te:
			for _t in range(times):
				_sim_damage_enemy(s, te, dmg)
	else:
		var te := _pick_alive_enemy(s)
		if te:
			for _t in range(times):
				_sim_damage_enemy(s, te, dmg)

static func _sim_damage_enemy(s: SimState, e: SimEnemy, dmg: int) -> void:
	if not e.alive or dmg <= 0:
		return
	var actual: int = dmg
	if e.vulnerable > 0:
		actual = int(ceil(actual * 1.5))
	if e.block >= actual:
		e.block -= actual
	else:
		actual -= e.block
		e.block = 0
		e.hp -= actual
	if e.hp <= 0:
		e.alive = false
		e.hp = 0

static func _sim_add_block(s: SimState, amount: int) -> void:
	var actual: int = amount + s.dexterity
	actual = maxi(0, actual)
	s.block += actual
	var jug: int = s.powers.get("juggernaut", 0)
	if jug > 0:
		var te := _pick_alive_enemy(s)
		if te:
			_sim_damage_enemy(s, te, jug)

# ---------------------------------------------------------------------------
# Status helpers
# ---------------------------------------------------------------------------

static func _apply_status_to_target(s: SimState, target_type: String, st: String, stk: int) -> void:
	if st == "":
		return
	if target_type == "all_enemies":
		for e in s.enemies:
			if e.alive:
				_apply_enemy_status(e, st, stk)
	elif target_type == "random_enemy":
		var te := _pick_alive_enemy(s)
		if te:
			_apply_enemy_status(te, st, stk)
	else:
		var te := _pick_alive_enemy(s)
		if te:
			_apply_enemy_status(te, st, stk)

static func _apply_enemy_status(e: SimEnemy, st: String, stk: int) -> void:
	match st:
		"poison": e.poison += stk
		"vulnerable": e.vulnerable += stk
		"weak": e.weak += stk
		"strength": e.strength += stk

static func _apply_hero_status(s: SimState, st: String, stk: int) -> void:
	if st == "":
		return
	match st:
		"strength": s.strength += stk
		"dexterity": s.dexterity += stk
		"vulnerable": s.vulnerable += stk
		"weak": s.weak += stk

static func _apply_card_statuses(s: SimState, card: Dictionary, target_type: String) -> void:
	var as1 = card.get("apply_status", {})
	if as1 is Dictionary and as1.get("type", "") != "":
		_apply_status_to_target(s, target_type, as1["type"], as1.get("stacks", 1))
	var as2 = card.get("apply_status_2", {})
	if as2 is Dictionary and as2.get("type", "") != "":
		_apply_status_to_target(s, target_type, as2["type"], as2.get("stacks", 1))
	var ass = card.get("apply_self_status", {})
	if ass is Dictionary and ass.get("type", "") != "":
		_apply_hero_status(s, ass["type"], ass.get("stacks", 1))

static func _enemy_has_status(e: SimEnemy, st: String) -> bool:
	match st:
		"poison": return e.poison > 0
		"vulnerable": return e.vulnerable > 0
		"weak": return e.weak > 0
	return false

# ---------------------------------------------------------------------------
# Draw / target helpers
# ---------------------------------------------------------------------------

static func _sim_draw(s: SimState, count: int) -> void:
	for _i in range(count):
		if s.hand.size() >= MAX_HAND:
			break
		if s.draw_pile.is_empty():
			s.draw_pile = s.discard_pile.duplicate()
			s.discard_pile.clear()
		if s.draw_pile.is_empty():
			break
		s.hand.append(s.draw_pile.pop_back())
	if count >= 3 and s.powers.get("psi_surge", 0) > 0:
		s.energy += 1

static func _pick_alive_enemy(s: SimState) -> SimEnemy:
	for e in s.enemies:
		if e.alive:
			return e
	return null

static func _pick_target(s: SimState, target_type: String) -> SimEnemy:
	if target_type == "self" or target_type == "all_heroes":
		return null
	return _pick_alive_enemy(s)

static func _pick_worst_card_idx(s: SimState) -> int:
	var worst: int = 0
	var worst_val: float = 999.0
	for i in range(s.hand.size()):
		var c: Dictionary = s.hand[i]
		var val: float = _card_value(c)
		if val < worst_val:
			worst_val = val
			worst = i
	return worst

static func _card_value(card: Dictionary) -> float:
	if card.get("unplayable", false):
		return -10.0
	var cost: int = card.get("cost", 0)
	if cost < 0:
		return -5.0
	return float(card.get("damage", 0)) + float(card.get("block", 0)) + float(card.get("draw", 0)) * 2.0 - float(cost) * 0.5

# ---------------------------------------------------------------------------
# Deck statistics for future turn projection
# ---------------------------------------------------------------------------

class DeckStats:
	var avg_dmg_per_card: float
	var avg_blk_per_card: float
	var avg_draw_per_card: float
	var attack_ratio: float
	var poison_per_card: float
	var cards_per_turn: int
	var avg_cost: float

static func _compute_deck_stats(s: SimState) -> DeckStats:
	var all_cards: Array = []
	all_cards.append_array(s.hand)
	all_cards.append_array(s.draw_pile)
	all_cards.append_array(s.discard_pile)
	var ds := DeckStats.new()
	if all_cards.is_empty():
		ds.avg_dmg_per_card = 3.0; ds.avg_blk_per_card = 3.0
		ds.avg_draw_per_card = 0.0; ds.attack_ratio = 0.5
		ds.poison_per_card = 0.0; ds.cards_per_turn = 5; ds.avg_cost = 1.0
		return ds
	var total_dmg := 0.0; var total_blk := 0.0; var total_draw := 0.0
	var total_cost := 0.0; var total_poison := 0.0
	var attack_count := 0; var playable := 0
	for c in all_cards:
		if c.get("unplayable", false) or c.get("cost", 0) < 0:
			continue
		playable += 1
		total_dmg += float(c.get("damage", 0))
		total_blk += float(c.get("block", 0))
		total_draw += float(c.get("draw", 0))
		total_cost += float(c.get("cost", 0))
		if c.get("type", 0) == 0:
			attack_count += 1
		var as_data = c.get("apply_status", {})
		if as_data is Dictionary and as_data.get("type", "") == "poison":
			total_poison += float(as_data.get("stacks", 0))
	var n: float = float(maxi(1, playable))
	ds.avg_dmg_per_card = total_dmg / n
	ds.avg_blk_per_card = total_blk / n
	ds.avg_draw_per_card = total_draw / n
	ds.attack_ratio = float(attack_count) / n
	ds.poison_per_card = total_poison / n
	ds.cards_per_turn = mini(MAX_HAND, all_cards.size())
	ds.avg_cost = maxf(0.5, total_cost / n)
	return ds

# ---------------------------------------------------------------------------
# Full fight simulation
# ---------------------------------------------------------------------------

static func _evaluate(s: SimState) -> float:
	var ds: DeckStats = _compute_deck_stats(s)
	var hero_hp: float = float(s.hp)
	var hero_block: int = s.block
	var hero_str: int = s.strength - s.flex_str_to_remove
	var hero_dex: int = s.dexterity - s.anticipate_dex_to_remove
	var hero_weak: int = maxi(0, s.weak - 1)
	var hero_vuln: int = maxi(0, s.vulnerable - 1)
	var keep_block: bool = s.blur_active or s.barricade
	var max_energy: int = s.max_energy + s.pt_energy
	# Per-turn accumulators
	var pt_str: int = s.pt_strength
	var pt_blk: int = s.pt_block
	var pt_poison: int = s.pt_poison_all
	var pt_self_dmg: int = s.pt_self_damage
	var pt_dmg_all: int = s.pt_damage_all

	# Clone enemy state
	var sim_enemies: Array = []
	for e in s.enemies:
		sim_enemies.append({
			"hp": e.hp, "max_hp": e.max_hp, "block": e.block,
			"str": e.strength, "vuln": e.vulnerable, "weak": e.weak,
			"poison": e.poison, "alive": e.alive, "intent": e.intent.duplicate()
		})
	# Compute per-enemy avg damage
	for se in sim_enemies:
		var edmg: int = 0
		var itype: String = se["intent"].get("type", "")
		if "attack" in itype:
			var base: int = se["intent"].get("value", se["intent"].get("damage", 0))
			var times: int = se["intent"].get("times", 1)
			edmg = (base + se["str"]) * times
			if se["weak"] > 0:
				edmg = int(edmg * 0.75)
		se["avg_dmg"] = maxi(0, edmg)

	# === TURN 0: end current turn + enemy turn (exact) ===
	# End-of-turn: per-turn block
	if pt_blk > 0:
		hero_block += maxi(0, pt_blk + s.dexterity)
	# End-of-turn: per-turn poison
	if pt_poison > 0:
		for se in sim_enemies:
			if se["alive"]:
				se["poison"] += pt_poison
	# End-of-turn: per-turn damage to all enemies
	if pt_dmg_all > 0:
		for se in sim_enemies:
			if se["alive"]:
				se["hp"] -= pt_dmg_all
				if se["hp"] <= 0:
					se["alive"] = false
	# End-of-turn: self damage
	if pt_self_dmg > 0:
		hero_hp -= float(pt_self_dmg)

	# Enemy turn: tick poison
	for se in sim_enemies:
		if not se["alive"]:
			continue
		if se["poison"] > 0:
			se["hp"] -= se["poison"]
			se["poison"] = maxi(0, se["poison"] - 1)
			if se["hp"] <= 0:
				se["alive"] = false

	# Enemy turn: attacks
	var turn0_incoming: int = 0
	var caltrops_val: int = s.powers.get("caltrops", 0)
	var fb_val: int = s.powers.get("flame_barrier", 0)
	for se in sim_enemies:
		if not se["alive"]:
			continue
		var itype: String = se["intent"].get("type", "")
		if "attack" in itype:
			var base: int = se["intent"].get("value", se["intent"].get("damage", 0))
			var times: int = se["intent"].get("times", 1)
			var dmg_per: int = maxi(0, base + se["str"])
			if se["weak"] > 0:
				dmg_per = int(dmg_per * 0.75)
			turn0_incoming += dmg_per * times
			# Reactive powers
			se["hp"] -= (caltrops_val + fb_val) * times
			if se["hp"] <= 0:
				se["alive"] = false
		if itype == "attack_debuff":
			var ds_name: String = se["intent"].get("status", "")
			var ds_stk: int = se["intent"].get("stacks", 1)
			if ds_name == "vulnerable":
				hero_vuln += ds_stk
			elif ds_name == "weak":
				hero_weak += ds_stk

	var eff_incoming: int = turn0_incoming
	if hero_vuln > 0:
		eff_incoming = int(ceil(turn0_incoming * 1.5))
	hero_hp -= float(maxi(0, eff_incoming - hero_block))
	hero_block = maxi(0, hero_block - eff_incoming)
	hero_weak = maxi(0, hero_weak - 1)
	hero_vuln = maxi(0, hero_vuln - 1)
	for se in sim_enemies:
		se["vuln"] = maxi(0, se["vuln"] - 1)
		se["weak"] = maxi(0, se["weak"] - 1)

	var all_dead := true
	for se in sim_enemies:
		if se["alive"]:
			all_dead = false
			break
	if all_dead or hero_hp <= 0:
		return hero_hp

	# === FUTURE TURNS: simulate with deck stats ===
	var fight_turns: int = 0
	for turn in range(1, MAX_FIGHT_TURNS + 1):
		fight_turns = turn
		all_dead = true
		for se in sim_enemies:
			if se["alive"]:
				all_dead = false
				break
		if all_dead or hero_hp <= 0:
			break

		# Our turn start
		if not keep_block:
			hero_block = 0
		hero_str += pt_str

		# Cards playable this turn (include per-turn extra draws from powers)
		var base_draw: int = ds.cards_per_turn + s.pt_draw
		var cards_playable: int = mini(base_draw, int(float(max_energy) / ds.avg_cost))
		cards_playable = maxi(1, cards_playable)
		var extra_draws: float = float(cards_playable) * ds.avg_draw_per_card
		cards_playable = mini(MAX_HAND, cards_playable + int(extra_draws * 0.5))

		# Our damage
		var attack_cards: int = int(float(cards_playable) * ds.attack_ratio)
		var our_dmg: float = float(cards_playable) * ds.avg_dmg_per_card * ds.attack_ratio
		our_dmg += float(hero_str * attack_cards)
		if hero_weak > 0:
			our_dmg *= 0.75

		# Our block
		var our_blk: float = float(cards_playable) * ds.avg_blk_per_card * (1.0 - ds.attack_ratio)
		our_blk += float(hero_dex) * float(cards_playable) * (1.0 - ds.attack_ratio)
		our_blk = maxf(0.0, our_blk)
		if pt_blk > 0:
			our_blk += float(pt_blk + hero_dex)
		hero_block += int(our_blk)

		# Poison from our cards + per-turn poison
		var our_poison: float = float(cards_playable) * ds.poison_per_card
		for se in sim_enemies:
			if se["alive"]:
				se["poison"] += int(our_poison) + pt_poison

		# Per-turn effects
		if pt_self_dmg > 0:
			hero_hp -= float(pt_self_dmg)
		if pt_dmg_all > 0:
			for se in sim_enemies:
				if se["alive"]:
					se["hp"] -= pt_dmg_all

		# Deal our damage to enemies (focus first alive)
		var dmg_left: float = our_dmg
		for se in sim_enemies:
			if not se["alive"] or dmg_left <= 0:
				continue
			var actual: float = dmg_left
			if se["vuln"] > 0:
				actual *= 1.5
			if float(se["block"]) >= actual:
				se["block"] -= int(actual)
			else:
				actual -= float(se["block"])
				se["block"] = 0
				se["hp"] -= int(actual)
			dmg_left = 0.0
			if se["hp"] <= 0:
				se["alive"] = false

		# Enemy turn: tick poison
		for se in sim_enemies:
			if not se["alive"]:
				continue
			if se["poison"] > 0:
				se["hp"] -= se["poison"]
				se["poison"] = maxi(0, se["poison"] - 1)
				if se["hp"] <= 0:
					se["alive"] = false

		# Enemy attacks
		var incoming: int = 0
		for se in sim_enemies:
			if not se["alive"]:
				continue
			var itype: String = se["intent"].get("type", "")
			if "attack" in itype:
				var times: int = se["intent"].get("times", 1)
				se["hp"] -= (caltrops_val) * times
				if se["hp"] <= 0:
					se["alive"] = false
					continue
			incoming += se["avg_dmg"]
			se["block"] = 0

		var eff_inc: int = incoming
		if hero_vuln > 0:
			eff_inc = int(ceil(incoming * 1.5))
		hero_hp -= float(maxi(0, eff_inc - hero_block))
		hero_block = maxi(0, hero_block - eff_inc)
		if not keep_block:
			hero_block = 0
		hero_weak = maxi(0, hero_weak - 1)
		hero_vuln = maxi(0, hero_vuln - 1)
		for se in sim_enemies:
			se["vuln"] = maxi(0, se["vuln"] - 1)
			se["weak"] = maxi(0, se["weak"] - 1)

	var score: float = hero_hp
	for se in sim_enemies:
		if not se["alive"]:
			score += 5.0
		else:
			score -= float(se["hp"]) * 0.5
	score -= float(fight_turns) * 0.5
	return score

# ---------------------------------------------------------------------------
# Result formatting
# ---------------------------------------------------------------------------

static func _format_result(ctx: Dictionary) -> String:
	var best_state: SimState = ctx.get("best_state")
	if best_state == null:
		return "无解"
	var lines: Array = []
	lines.append("=== 最优出牌方案 ===")
	lines.append("搜索节点: %d" % ctx["nodes"])
	lines.append("")
	if ctx["best_seq"].is_empty():
		lines.append("建议: 不出牌，直接结束回合")
	else:
		lines.append("出牌顺序:")
		for i in range(ctx["best_seq"].size()):
			lines.append("  %d. %s" % [i + 1, ctx["best_seq"][i]])
	lines.append("")
	lines.append("本回合打完后:")
	lines.append("  英雄HP: %d  格挡: %d  费用剩余: %d" % [best_state.hp, best_state.block, best_state.energy])
	lines.append("  力量: %d  敏捷: %d" % [best_state.strength - best_state.flex_str_to_remove, best_state.dexterity - best_state.anticipate_dex_to_remove])
	for e in best_state.enemies:
		var st: String = ""
		if e.poison > 0: st += " 中毒:%d" % e.poison
		if e.vulnerable > 0: st += " 易伤:%d" % e.vulnerable
		if e.weak > 0: st += " 虚弱:%d" % e.weak
		lines.append("  敌人HP: %d/%d 格挡: %d%s%s" % [e.hp, e.max_hp, e.block, st, " [已死亡]" if not e.alive else ""])
	lines.append("")
	# Poison projection
	for e in best_state.enemies:
		if e.alive and e.poison > 0:
			var p: int = e.poison
			var total_pdmg: int = 0
			var remaining: int = e.hp
			var turns_to_die: int = -1
			for t in range(MAX_FIGHT_TURNS):
				p += best_state.pt_poison_all
				if p > 0:
					total_pdmg += p
					remaining -= p
					p -= 1
				if remaining <= 0:
					turns_to_die = t + 1
					break
			if turns_to_die > 0:
				lines.append("  毒杀敌人需 %d 回合 (毒伤总计: %d)" % [turns_to_die, total_pdmg])
			elif total_pdmg > 0:
				lines.append("  毒伤投影: %d (不足以毒杀)" % total_pdmg)
	lines.append("")
	lines.append("全局战斗投影:")
	lines.append("  预计战斗结束英雄HP: %.0f" % ctx["best_score"])
	var hp_loss: float = float(best_state.hp) - ctx["best_score"]
	if hp_loss > 0:
		lines.append("  预计总HP损失: %.0f" % hp_loss)
	else:
		lines.append("  预计无额外HP损失")
	return "\n".join(lines)
