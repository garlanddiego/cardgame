extends SceneTree

var frame: int = 0
var main_scene: Node = null
var battle: Node2D = null
var bash_played: bool = false

func _initialize() -> void:
  main_scene = load("res://scenes/main.tscn").instantiate()
  root.add_child(main_scene)

func _process(_delta: float) -> bool:
  frame += 1
  
  # Frame 3: Set deck and confirm
  if frame == 3:
    var gm = _auto("GameManager")
    if gm:
      gm.player_deck = ["ic_bash", "ic_strike", "ic_strike", "ic_defend", "ic_defend", "ic_shrug_it_off", "ic_anger", "ic_cleave", "ic_twin_strike", "ic_pommel_strike"]
    var b = _fc(main_scene, "DeckBuilder")
    if b:
      # Set selected so confirm works
      b.selected_card_ids = {"ic_bash": true, "ic_strike": true, "ic_defend": true}
      b._on_confirm()
  
  # Frame 15-40: Find battle
  if frame >= 15 and frame <= 40 and battle == null:
    battle = _fc(main_scene, "BattleInstance") as Node2D
    if battle and battle.battle_active:
      print("Battle active at frame %d" % frame)
  
  if frame == 45 and battle:
    _cap("screenshots/inspect_bash/01_before.png")
    _print_state("BEFORE Bash")
  
  if frame == 50 and battle and not bash_played:
    # Find and play Bash
    for i in range(battle.hand.size()):
      if battle.hand[i].get("id") == "ic_bash":
        var cd = battle.hand[i]
        var tgt = battle.enemies[0] if not battle.enemies.is_empty() else null
        if tgt and battle.card_hand and i < battle.card_hand.cards.size():
          battle.card_hand.play_card_on(battle.card_hand.cards[i], tgt)
          battle.play_card(cd, tgt)
          bash_played = true
          print(">>> Bash played!")
        break
    if not bash_played:
      print("Bash not in hand!")
  
  if frame == 60:
    _cap("screenshots/inspect_bash/02_after.png")
    if bash_played:
      _print_state("AFTER Bash")
  
  if frame == 65:
    quit(0)
  
  return false

func _print_state(label: String) -> void:
  if battle == null: return
  print("--- %s ---" % label)
  print("Hand (%d): %s" % [battle.hand.size(), ", ".join(battle.hand.map(func(c): return c.get("id","?")))])
  print("Energy: %d/%d" % [battle.current_energy, battle.max_energy])
  if not battle.enemies.is_empty():
    var e = battle.enemies[0]
    print("Enemy: HP=%d/%d Block=%d Vuln=%d Weak=%d" % [e.current_hp, e.max_hp, e.block, e.get_status_stacks("vulnerable"), e.get_status_stacks("weak")])

func _fc(n: Node, name: String) -> Node:
  for c in n.get_children():
    if c.name == name: return c
    var f = _fc(c, name)
    if f: return f
  return null

func _auto(name: String) -> Node:
  for c in root.get_children():
    if c.name == name: return c
  return null

func _cap(p: String) -> void:
  DirAccess.make_dir_recursive_absolute(p.get_base_dir())
  var img = root.get_viewport().get_texture().get_image()
  if img:
    img.save_png(p)
    print("Captured: %s" % p.get_file())
