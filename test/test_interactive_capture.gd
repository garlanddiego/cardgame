extends SceneTree

var frame: int = 0
var main_scene: Node = null
var builder: Node = null
var battle: Node2D = null
var phase: String = "init"

func _initialize() -> void:
  var main_packed = load("res://scenes/main.tscn")
  main_scene = main_packed.instantiate()
  root.add_child(main_scene)

func _process(_delta: float) -> bool:
  frame += 1
  
  # Phase: Deck building
  if frame == 5:
    builder = _find_child(main_scene, "DeckBuilder")
    if builder:
      _capture("screenshots/interactive/01_deck_empty.png")
  
  if frame == 8 and builder:
    # Select 10 cards by simulating taps
    var grid = _find_child(builder, "CardGrid")
    if grid:
      var count = 0
      for child in grid.get_children():
        if count >= 10:
          break
        var ev = InputEventMouseButton.new()
        ev.button_index = MOUSE_BUTTON_LEFT
        ev.pressed = true
        ev.position = Vector2(50, 50)
        child.gui_input.emit(ev)
        count += 1
  
  if frame == 12 and builder:
    _capture("screenshots/interactive/02_deck_selected.png")
  
  if frame == 15 and builder:
    builder._on_confirm()
    phase = "battle_wait"
  
  if frame == 30 and phase == "battle_wait":
    battle = _find_child(main_scene, "BattleInstance") as Node2D
    if not battle:
      battle = _find_child(main_scene, "Battle") as Node2D
    if battle:
      phase = "battle"
      _capture("screenshots/interactive/03_battle_your_turn.png")
  
  # Battle phase - capture various states
  if frame == 45 and phase == "battle":
    _capture("screenshots/interactive/04_battle_hand_close.png")
  
  # Simulate playing cards by calling battle methods
  if frame == 50 and phase == "battle" and battle:
    # Try to play the first card in hand
    if not battle.hand.is_empty() and battle.is_player_turn:
      var card_data = battle.hand[0]
      var target_type = card_data.get("target", "enemy")
      var target = null
      if target_type == "self" or target_type == "all_enemies":
        target = battle.player
      elif not battle.enemies.is_empty():
        target = battle.enemies[0]
      if target and battle.card_hand:
        var card_nodes = battle.card_hand.cards
        if not card_nodes.is_empty():
          battle.card_hand.play_card_on(card_nodes[0], target)
          battle.play_card(card_data, target)
    _capture("screenshots/interactive/05_after_play_card.png")
  
  if frame == 55 and phase == "battle" and battle:
    _capture("screenshots/interactive/06_mid_battle.png")
  
  # Play another card
  if frame == 60 and phase == "battle" and battle:
    if not battle.hand.is_empty() and battle.is_player_turn:
      var card_data = battle.hand[0]
      var target = null
      var target_type = card_data.get("target", "enemy")
      if target_type == "self" or target_type == "all_enemies":
        target = battle.player
      elif not battle.enemies.is_empty():
        target = battle.enemies[0]
      if target and battle.card_hand:
        var card_nodes = battle.card_hand.cards
        if not card_nodes.is_empty():
          battle.card_hand.play_card_on(card_nodes[0], target)
          battle.play_card(card_data, target)
    _capture("screenshots/interactive/07_after_second_card.png")
  
  if frame == 70 and phase == "battle":
    _capture("screenshots/interactive/08_battle_state.png")
  
  if frame == 80:
    quit(0)
  
  return false

func _capture(path: String) -> void:
  var dir_path = path.get_base_dir()
  DirAccess.make_dir_recursive_absolute(dir_path)
  var img = root.get_viewport().get_texture().get_image()
  if img:
    img.save_png(path)
    print("Captured: " + path)

func _find_child(node: Node, child_name: String) -> Node:
  for c in node.get_children():
    if c.name == child_name:
      return c
    var found = _find_child(c, child_name)
    if found:
      return found
  return null
