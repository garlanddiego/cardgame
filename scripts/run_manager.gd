extends Node
## Run state manager for Standard Mode — persists across scenes

const MonstersDB = preload("res://scripts/monsters.gd")

signal run_started
signal floor_changed(floor_num: int)
signal gold_changed(amount: int)
signal hp_changed(hero_idx: int, hp: int, max_hp: int)
signal deck_changed
signal run_ended(victory: bool)

var active: bool = false
var floor_num: int = 0  # Current floor (0 = not started, 1-10 = floors)
var gold: int = 100

# Hero state
var hero1_id: String = "ironclad"
var hero2_id: String = "silent"
var hero1_hp: int = 80
var hero2_hp: int = 70
var hero1_max_hp: int = 80
var hero2_max_hp: int = 70

# Deck (card IDs)
var deck: Array = []

# Backpack — cards stored here are excluded from battle draw pile (max 4)
var backpack: Array = []

# Map
var map_nodes: Dictionary = {}  # "floor_col" -> {type, connections, ...}
var map_paths: Array = []       # List of [from_key, to_key]
var visited: Array = []         # Visited node keys
var current_node: String = ""   # Current node key
var available_nodes: Array = [] # Nodes player can pick next

func start_run(h1: String, h2: String) -> void:
  active = true
  floor_num = 0
  gold = 100
  hero1_id = h1
  hero2_id = h2
  hero1_hp = 70
  hero2_hp = 60
  hero1_max_hp = 70
  hero2_max_hp = 60
  deck = _build_starting_deck(h1, h2)
  backpack = []
  _generate_map()
  # Available nodes = all nodes on floor 1
  available_nodes = []
  for key in map_nodes:
    if map_nodes[key]["floor"] == 1:
      available_nodes.append(key)
  run_started.emit()

func visit_node(key: String) -> Dictionary:
  ## Mark node as visited, return node data
  current_node = key
  visited.append(key)
  var node: Dictionary = map_nodes[key]
  floor_num = node["floor"]
  # Compute next available nodes
  available_nodes = []
  for path in map_paths:
    if path[0] == key:
      available_nodes.append(path[1])
  floor_changed.emit(floor_num)
  return node

func add_gold(amount: int) -> void:
  gold += amount
  gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
  if gold < amount:
    return false
  gold -= amount
  gold_changed.emit(gold)
  return true

func heal_hero(hero_idx: int, amount: int) -> void:
  if hero_idx == 0:
    hero1_hp = mini(hero1_hp + amount, hero1_max_hp)
    hp_changed.emit(0, hero1_hp, hero1_max_hp)
  else:
    hero2_hp = mini(hero2_hp + amount, hero2_max_hp)
    hp_changed.emit(1, hero2_hp, hero2_max_hp)

func damage_hero(hero_idx: int, amount: int) -> void:
  if hero_idx == 0:
    hero1_hp = maxi(0, hero1_hp - amount)
    hp_changed.emit(0, hero1_hp, hero1_max_hp)
  else:
    hero2_hp = maxi(0, hero2_hp - amount)
    hp_changed.emit(1, hero2_hp, hero2_max_hp)

func add_card(card_id: String) -> void:
  deck.append(card_id)
  deck_changed.emit()

func remove_card(card_id: String) -> void:
  var idx := deck.find(card_id)
  if idx >= 0:
    deck.remove_at(idx)
    deck_changed.emit()

func upgrade_card(card_id: String) -> bool:
  ## Upgrade a card in deck. Appends "+" suffix to mark it as upgraded.
  if card_id.ends_with("+"):
    return false  # Already upgraded
  var gm = get_node_or_null("/root/GameManager")
  if gm == null:
    return false
  if not gm._upgrade_overrides_cache.has(card_id):
    return false  # No upgrade available
  var idx := deck.find(card_id)
  if idx < 0:
    return false
  deck[idx] = card_id + "+"
  deck_changed.emit()
  return true

func end_run(victory: bool) -> void:
  active = false
  run_ended.emit(victory)

func _build_starting_deck(_h1: String, _h2: String) -> Array:
  var d: Array = []
  for i in 2: d.append("ic_strike")
  for i in 2: d.append("ic_defend")
  for i in 2: d.append("si_strike")
  for i in 2: d.append("si_defend")
  return d

func _generate_map() -> void:
  ## Generate a 10-floor map with paths converging to boss
  map_nodes.clear()
  map_paths.clear()

  var rng := RandomNumberGenerator.new()
  rng.randomize()

  # Floor 1: 3-4 monster nodes
  var floor_counts: Array = [0, 4, 4, 3, 4, 3, 4, 3, 3, 3, 1]  # index = floor

  # Node type distribution per floor
  # M=monster, R=rest, S=shop
  var floor_types: Dictionary = {
    1: ["M", "M", "M", "M"],
    2: ["M", "M", "M", "S"],
    3: ["M", "M", "R", "M"],
    4: ["M", "M", "S", "R"],
    5: ["M", "M", "M"],
    6: ["M", "R", "M", "S"],
    7: ["M", "M", "R"],
    8: ["M", "M", "M"],
    9: ["M", "R", "M"],
    10: ["B"],  # Boss
  }

  # Create nodes
  for floor_i in range(1, 11):
    var types: Array = floor_types[floor_i]
    types.shuffle()
    for col in range(types.size()):
      var key := "%d_%d" % [floor_i, col]
      var node_type: String = types[col]
      var monster_id := ""
      var enemy_count := 1
      if node_type == "M":
        var available: Array = MonstersDB.get_monsters_for_floor(floor_i)
        if available.size() > 0:
          monster_id = available[rng.randi() % available.size()]
        enemy_count = MonstersDB.get_enemy_count_for_floor(floor_i)
      elif node_type == "B":
        monster_id = "ancient_dragon"
        enemy_count = 1
      map_nodes[key] = {
        "floor": floor_i,
        "col": col,
        "type": node_type,
        "monster_id": monster_id,
        "enemy_count": enemy_count,
        "total_cols": types.size(),
      }

  # Create paths between floors
  for floor_i in range(1, 10):
    var current_cols: Array = []
    var next_cols: Array = []
    for key in map_nodes:
      if map_nodes[key]["floor"] == floor_i:
        current_cols.append(key)
      elif map_nodes[key]["floor"] == floor_i + 1:
        next_cols.append(key)
    # Sort by column
    current_cols.sort_custom(func(a, b): return map_nodes[a]["col"] < map_nodes[b]["col"])
    next_cols.sort_custom(func(a, b): return map_nodes[a]["col"] < map_nodes[b]["col"])

    if current_cols.is_empty() or next_cols.is_empty():
      continue

    # Each current node connects to 1-2 next nodes
    # Ensure every next node has at least one incoming connection
    var next_connected: Dictionary = {}
    for nk in next_cols:
      next_connected[nk] = false

    for ci in range(current_cols.size()):
      var ck: String = current_cols[ci]
      # Map position ratio to pick corresponding next nodes
      var ratio: float = float(ci) / maxf(current_cols.size() - 1, 1)
      var target_idx: int = roundi(ratio * (next_cols.size() - 1))
      # Connect to target and optionally a neighbor
      map_paths.append([ck, next_cols[target_idx]])
      next_connected[next_cols[target_idx]] = true
      # Sometimes connect to adjacent node too
      if rng.randf() < 0.4:
        var alt := clampi(target_idx + (1 if rng.randf() < 0.5 else -1), 0, next_cols.size() - 1)
        if alt != target_idx:
          map_paths.append([ck, next_cols[alt]])
          next_connected[next_cols[alt]] = true

    # Ensure all next nodes are reachable
    for nk in next_cols:
      if not next_connected[nk]:
        # Connect from nearest current node
        var best_ck: String = current_cols[0]
        var nc: int = map_nodes[nk]["col"]
        var best_dist := 999
        for ck in current_cols:
          var d: int = absi(map_nodes[ck]["col"] - nc)
          if d < best_dist:
            best_dist = d
            best_ck = ck
        map_paths.append([best_ck, nk])
