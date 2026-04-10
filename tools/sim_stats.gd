extends SceneTree
## tools/sim_stats.gd — Card statistics from simulation results
## Reads simulation CSV, aggregates per-card stats using game card database for names.
## Run: godot --headless --path . --script tools/sim_stats.gd -- --input sim_results.csv --csv card_stats.csv

func _init() -> void:
	await process_frame

	var args := OS.get_cmdline_user_args()
	var input_csv := "sim_silent_4combo.csv"
	var output_csv := ""
	var max_hp_loss := -1  # -1 = no filter
	var hero_max_hp := 200

	var i := 0
	while i < args.size():
		match args[i]:
			"--input": i += 1; input_csv = args[i] if i < args.size() else input_csv
			"--csv": i += 1; output_csv = args[i] if i < args.size() else ""
			"--max-hp-loss": i += 1; max_hp_loss = int(args[i]) if i < args.size() else -1
			"--hero-hp": i += 1; hero_max_hp = int(args[i]) if i < args.size() else 200
		i += 1

	# Access GameManager for card names
	var gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("ERROR: GameManager not found")
		quit()
		return

	# Load localization for Chinese names
	var loc_script = load("res://scripts/localization.gd")
	var loc = loc_script.new() if loc_script else null
	if loc:
		loc.current_lang = "zh"

	print("=== Card Statistics ===")
	print("Reading: %s" % input_csv)

	# Read CSV
	var file := FileAccess.open(input_csv, FileAccess.READ)
	if file == null:
		print("ERROR: Cannot open %s" % input_csv)
		quit()
		return

	# Skip header
	var header := file.get_csv_line()

	# Per-card aggregation
	var card_data: Dictionary = {}  # card_id -> {appearances, total_hp, ...}
	var total_rows := 0

	var filtered_rows := 0

	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < 7:
			continue
		total_rows += 1

		var ids_str: String = line[1]  # 卡牌ID column
		var hp: int = int(line[3])     # 剩余HP

		# Filter by max HP loss
		if max_hp_loss >= 0:
			var hp_loss := hero_max_hp - hp
			if hp_loss >= max_hp_loss:
				continue
		filtered_rows += 1
		var turns: int = int(line[4])  # 回合数
		var cards_played: int = int(line[5])  # 出牌数
		var max_dmg: int = int(line[6])  # 最大单轮伤害
		var won: bool = line[7].strip_edges() == "胜" if line.size() > 7 else false

		var card_ids := ids_str.split(";")
		for card_id_raw in card_ids:
			var card_id := card_id_raw.strip_edges()
			if card_id.is_empty():
				continue
			if not card_data.has(card_id):
				card_data[card_id] = {
					"appearances": 0, "total_hp": 0, "total_turns": 0,
					"total_cards": 0, "total_max_dmg": 0, "wins": 0,
					"rows": [] as Array,
				}
			var s: Dictionary = card_data[card_id]
			s["appearances"] += 1
			s["total_hp"] += hp
			s["total_turns"] += turns
			s["total_cards"] += cards_played
			s["total_max_dmg"] += max_dmg
			if won:
				s["wins"] += 1
			if s["rows"].size() < 100:
				s["rows"].append(total_rows)

	file.close()
	if max_hp_loss >= 0:
		print("Processed %d rows, filtered %d (HP loss < %d)" % [total_rows, filtered_rows, max_hp_loss])
	else:
		print("Processed %d rows" % total_rows)

	# Build results with card names from game database
	var results: Array = []
	for card_id in card_data:
		var s: Dictionary = card_data[card_id]
		var n: int = s["appearances"]
		if n == 0:
			continue
		# Get card name (Chinese if available, English fallback)
		var card_name_en: String = card_id
		var card_name_zh: String = ""
		if gm.card_database.has(card_id):
			var cd: Dictionary = gm.card_database[card_id]
			card_name_en = cd.get("name", card_id)
			if loc:
				card_name_zh = loc.card_name(cd)
		var card_name: String = card_name_zh if card_name_zh != "" else card_name_en
		results.append({
			"card_id": card_id,
			"name": card_name,
			"name_en": card_name_en,
			"appearances": n,
			"avg_hp": snapped(float(s["total_hp"]) / n, 0.1),
			"avg_turns": snapped(float(s["total_turns"]) / n, 0.1),
			"avg_cards": snapped(float(s["total_cards"]) / n, 0.1),
			"avg_max_dmg": snapped(float(s["total_max_dmg"]) / n, 0.1),
			"win_rate": snapped(float(s["wins"]) / n * 100, 0.1),
			"rows": s["rows"],
		})

	# Sort by avg HP descending
	results.sort_custom(func(a, b): return a["avg_hp"] > b["avg_hp"])

	# Print table
	var display_count := filtered_rows if max_hp_loss >= 0 else total_rows
	print("\n%s" % ("=" .repeat(95)))
	if max_hp_loss >= 0:
		print("Card Statistics from %d/%d simulations (HP loss < %d)" % [filtered_rows, total_rows, max_hp_loss])
	else:
		print("Card Statistics from %d simulations" % total_rows)
	print("%s" % ("=" .repeat(95)))
	print("%4s %-25s %-18s %6s %7s %8s %8s %8s %6s" % ["排名", "卡牌ID", "名称", "出现", "平均HP", "平均回合", "平均出牌", "平均伤害", "胜率"])
	print("%s" % ("-" .repeat(95)))

	for ri in range(results.size()):
		var r: Dictionary = results[ri]
		print("%4d %-25s %-18s %6d %7.1f %8.1f %8.1f %8.1f %5.1f%%" % [
			ri + 1, r["card_id"], r["name"], r["appearances"],
			r["avg_hp"], r["avg_turns"], r["avg_cards"], r["avg_max_dmg"], r["win_rate"]
		])

	# Output CSV if requested
	if output_csv != "":
		var out := FileAccess.open(output_csv, FileAccess.WRITE)
		if out:
			out.store_line("排名,卡牌ID,中文名,英文名,出现次数,平均剩余HP,平均回合数,平均出牌数,平均最大伤害,胜率%")
			for ri in range(results.size()):
				var r: Dictionary = results[ri]
				out.store_line("%d,\"%s\",\"%s\",\"%s\",%d,%.1f,%.1f,%.1f,%.1f,%.1f%%" % [
					ri + 1, r["card_id"], r["name"], r["name_en"], r["appearances"],
					r["avg_hp"], r["avg_turns"], r["avg_cards"], r["avg_max_dmg"],
					r["win_rate"]
				])
			out.close()
			print("\nSaved to %s" % output_csv)

	quit()
