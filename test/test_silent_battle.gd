extends SceneTree

var frame: int = 0
var main_scene: Node = null
var battle: Node2D = null

func _initialize() -> void:
  main_scene = load("res://scenes/main.tscn").instantiate()
  root.add_child(main_scene)

func _process(_delta: float) -> bool:
  frame += 1
  
  if frame == 3:
    var gm = _auto("GameManager")
    if gm:
      gm.current_character = "silent"
      gm.player_deck = [
        "si_strike", "si_strike", "si_strike", "si_strike", "si_strike",
        "si_defend", "si_defend", "si_defend", "si_defend", "si_defend",
        "si_neutralize", "si_survivor",
        "si_blade_dance", "si_backflip", "si_deadly_poison", "si_leg_sweep",
        "si_predator", "si_footwork", "si_poisoned_stab", "si_slice"
      ]
    # Skip deck builder, load battle directly
    var old = _fc(main_scene, "DeckBuilder")
    if old: old.queue_free()
    var battle_scene = load("res://scenes/battle.tscn")
    var b = battle_scene.instantiate()
    b.name = "BattleInstance"
    main_scene.add_child(b)
    b.start_battle("silent")
  
  if frame >= 10 and frame <= 30 and battle == null:
    battle = _fc(main_scene, "BattleInstance") as Node2D
  
  if frame == 35 and battle:
    DirAccess.make_dir_recursive_absolute("screenshots/silent_test")
    var img = root.get_viewport().get_texture().get_image()
    if img:
      img.save_png("screenshots/silent_test/battle.png")
      print("Captured!")
    print("Hand: %d cards, Energy: %d/%d" % [battle.hand.size(), battle.current_energy, battle.max_energy])
  
  if frame == 40: quit(0)
  return false

func _fc(n: Node, nm: String) -> Node:
  for c in n.get_children():
    if c.name == nm: return c
    var f = _fc(c, nm)
    if f: return f
  return null

func _auto(nm: String) -> Node:
  for c in root.get_children():
    if c.name == nm: return c
  return null
