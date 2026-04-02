extends SceneTree
## tools/sim_runner.gd — Headless GDScript battle simulator
## Uses actual game card database + battle logic.
## Run: godot --headless --path . --script tools/sim_runner.gd -- --char silent --combo 4 --csv results.csv

const BattleSimEngine = preload("res://tools/sim_engine.gd")

func _init() -> void:
	# Wait one frame for autoloads to init
	await process_frame

	var args := OS.get_cmdline_user_args()
	var char_filter := ""
	var version_filter := "all"
	var combo_size := 4
	var csv_path := "sim_results.csv"
	var monster_count := 2
	var monster_hp := 50
	var monster_dmg := 6
	var monster_inc := 3
	var hero_hp := 200
	var draw_per_turn := 4
	var top_n := 50

	var i := 0
	while i < args.size():
		match args[i]:
			"--char": i += 1; char_filter = args[i] if i < args.size() else ""
			"--version": i += 1; version_filter = args[i] if i < args.size() else "all"
			"--combo": i += 1; combo_size = int(args[i]) if i < args.size() else 5
			"--csv": i += 1; csv_path = args[i] if i < args.size() else "sim_results.csv"
			"--monsters": i += 1; monster_count = int(args[i]) if i < args.size() else 2
			"--monster-hp": i += 1; monster_hp = int(args[i]) if i < args.size() else 100
			"--monster-dmg": i += 1; monster_dmg = int(args[i]) if i < args.size() else 8
			"--monster-inc": i += 1; monster_inc = int(args[i]) if i < args.size() else 4
			"--hero-hp": i += 1; hero_hp = int(args[i]) if i < args.size() else 200
			"--draw": i += 1; draw_per_turn = int(args[i]) if i < args.size() else 4
			"--top": i += 1; top_n = int(args[i]) if i < args.size() else 50
		i += 1

	print("=== GDScript Battle Simulator ===")

	# Access GameManager autoload
	var gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("ERROR: GameManager autoload not found")
		quit()
		return

	# Build card pool
	var pool: Array = []
	var basic_ids := ["ic_strike", "ic_defend", "si_strike", "si_defend",
					  "status_wound", "status_burn", "status_dazed",
					  "si_shiv", "si_shiv_plus"]  # Exclude tokens
	for card_id in gm.card_database:
		if card_id in basic_ids:
			continue
		var card: Dictionary = gm.card_database[card_id]
		if card.get("status", "active") != "active":
			continue
		if card.get("type", 0) == 3:  # Skip status cards
			continue
		if char_filter != "" and card.get("character", "") != char_filter:
			continue
		if version_filter != "all" and card.get("version", "old") != version_filter:
			continue
		pool.append(card_id)

	# Apply upgrades to card database if requested (default: true)
	var upgraded_db: Dictionary = gm.card_database.duplicate(true)
	# By default, upgrade all cards that have upgrade overrides
	for card_id in pool:
		var upgraded: Dictionary = gm.get_upgraded_card(card_id)
		if not upgraded.is_empty() and gm._upgrade_overrides_cache.has(card_id):
			upgraded_db[card_id] = upgraded

	print("Card pool: %d cards (char=%s, version=%s, upgraded)" % [pool.size(), char_filter if char_filter else "all", version_filter])

	# Generate combinations
	var combos := _generate_combinations(pool, combo_size)
	print("Combinations: %d (C(%d,%d))" % [combos.size(), pool.size(), combo_size])

	if combos.is_empty():
		print("No combinations to test")
		quit()
		return

	# Open CSV for incremental writing
	var file := FileAccess.open(csv_path, FileAccess.WRITE)
	if file == null:
		print("ERROR: Cannot open %s for writing" % csv_path)
		quit()
		return
	file.store_line("序号,卡牌ID,卡牌名称,剩余HP,回合数,出牌数,最大单轮伤害,胜负")

	# Run simulations (write each result immediately)
	var engine := BattleSimEngine.new()
	var results: Array = []
	var progress_interval := maxi(1, combos.size() / 20)

	for ci in range(combos.size()):
		var combo: Array = combos[ci]
		# Build full deck: combo + 3 strike + 3 defend
		var deck: Array = combo.duplicate()
		deck.append_array(["ic_strike", "ic_strike", "ic_strike", "ic_defend", "ic_defend", "ic_defend"])

		var result := engine.simulate(deck, upgraded_db, hero_hp, monster_hp, monster_dmg, monster_inc, monster_count, draw_per_turn)
		result["combo"] = combo
		var combo_names: Array = []
		for card_id in combo:
			combo_names.append(upgraded_db[card_id].get("name", card_id))
		result["combo_names"] = combo_names

		# Write to CSV immediately
		var ids := "; ".join(PackedStringArray(combo))
		var names := "; ".join(PackedStringArray(combo_names))
		var won := "胜" if result["won"] else "败"
		file.store_line("%d,\"%s\",\"%s\",%d,%d,%d,%d,%s" % [
			ci + 1, ids, names, result["hero_hp"], result["turns"],
			result["total_cards"], result["max_turn_dmg"], won
		])
		file.flush()

		results.append(result)

		if (ci + 1) % progress_interval == 0:
			print("  Progress: %d/%d (%.0f%%)" % [ci + 1, combos.size(), float(ci + 1) / combos.size() * 100])

	file.close()
	print("\nAll %d results saved to %s" % [combos.size(), csv_path])

	# Sort and print top 10
	results.sort_custom(func(a, b): return a["hero_hp"] > b["hero_hp"])
	print("\nTOP 10:")
	for ri in range(mini(10, results.size())):
		var r: Dictionary = results[ri]
		var names := ", ".join(PackedStringArray(r["combo_names"]))
		var won := "WIN" if r["won"] else "LOSS"
		print("  %d. HP:%d  Turns:%d  Cards:%d  MaxDmg:%d  %s  | %s" % [
			ri + 1, r["hero_hp"], r["turns"], r["total_cards"], r["max_turn_dmg"], won, names
		])

	quit()


func _generate_combinations(pool: Array, size: int) -> Array:
	"""Generate all combinations of `size` elements from pool."""
	var result: Array = []
	var indices: Array = []
	for k in range(size):
		indices.append(k)
	while true:
		# Emit current combination
		var combo: Array = []
		for k in range(size):
			combo.append(pool[indices[k]])
		result.append(combo)
		# Find rightmost index that can be incremented
		var i: int = size - 1
		while i >= 0 and indices[i] == pool.size() - size + i:
			i -= 1
		if i < 0:
			break
		indices[i] += 1
		for j in range(i + 1, size):
			indices[j] = indices[j - 1] + 1
	return result
