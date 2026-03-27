extends SceneTree
var frame: int = 0
var battle: Node2D = null
var played: bool = false

func _initialize() -> void:
  var gm = _auto("GameManager")
  if gm:
    gm.current_character = "silent"
    gm.player_deck = ["si_acrobatics", "si_strike", "si_strike", "si_defend", "si_defend", "si_neutralize", "si_survivor", "si_poisoned_stab", "si_blade_dance", "si_backflip", "si_deadly_poison", "si_leg_sweep", "si_predator", "si_footwork", "si_quick_slash", "si_deflect", "si_sucker_punch", "si_cloak_and_dagger", "si_slice", "si_dagger_throw"]
  var main = load("res://scenes/main.tscn").instantiate()
  root.add_child(main)

func _process(_delta) -> bool:
  frame += 1
  if frame == 5:
    # Skip deck builder, start battle
    var main = root.get_node_or_null("Main")
    if main:
      var db = main.get_node_or_null("DeckBuilder")
      if db: db.queue_free()
      var b = load("res://scenes/battle.tscn").instantiate()
      b.name = "BattleInstance"
      main.add_child(b)
      b.start_battle("silent")

  if frame >= 10 and battle == null:
    var main = root.get_node_or_null("Main")
    if main: battle = main.get_node_or_null("BattleInstance") as Node2D

  # After battle starts, inject Acrobatics into hand slot 0
  if frame == 15 and battle and battle.battle_active:
    var gm = _auto("GameManager")
    if gm:
      var acro_data = gm.get_card_data("si_acrobatics")
      if not acro_data.is_empty():
        # Replace first card in hand with Acrobatics
        if battle.hand.size() > 0:
          battle.hand[0] = acro_data
          # Also update the visual card
          if battle.card_hand and battle.card_hand.cards.size() > 0:
            var old_card = battle.card_hand.cards[0]
            old_card.card_data = acro_data
            old_card._apply_card_data()
            print("Injected Acrobatics at position 0!")

  if frame == 20 and battle:
    DirAccess.make_dir_recursive_absolute("screenshots/acrobatics")
    _cap("screenshots/acrobatics/01_before.png")
    print("Hand[0]: %s, Energy: %d" % [battle.hand[0].get("id","?"), battle.current_energy])

  # Play card at index 0 (should be Acrobatics)
  if frame == 25 and battle and not played:
    if battle.hand.size() > 0 and battle.hand[0].get("id","") == "si_acrobatics":
      var cd = battle.hand[0]
      if battle.card_hand and battle.card_hand.cards.size() > 0:
        battle.card_hand.play_card_on(battle.card_hand.cards[0], battle.player)
        battle.play_card(cd, battle.player)
        played = true
        print("Played Acrobatics!")

  if frame == 30:
    _cap("screenshots/acrobatics/02_discard_ui.png")
    if battle:
      print("After play: Hand=%d Energy=%d" % [battle.hand.size(), battle.current_energy])

  if frame == 40:
    _cap("screenshots/acrobatics/03_final.png")

  if frame == 45: quit(0)
  return false

func _auto(nm: String) -> Node:
  for c in root.get_children():
    if c.name == nm: return c
  return null

func _cap(p: String) -> void:
  var img = root.get_viewport().get_texture().get_image()
  if img: img.save_png(p); print("Cap: " + p)
