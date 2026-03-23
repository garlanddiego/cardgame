extends SceneTree

var frame: int = 0
var main_scene: Node = null
var builder: Node = null
var battle: Node2D = null
var phase: String = "init"
var turn_count: int = 0

func _initialize() -> void:
  var main_packed = load("res://scenes/main.tscn")
  main_scene = main_packed.instantiate()
  root.add_child(main_scene)

func _process(_delta: float) -> bool:
  frame += 1
  
  match phase:
    "init":
      if frame == 5:
        builder = _find_child(main_scene, "DeckBuilder")
        if builder:
          _capture("screenshots/ui_improved/01_deck_builder_empty.png")
    
    "select":
      pass
    
    _:
      pass

  # At frame 10, select cards
  if frame == 10 and builder:
    var grid = _find_child(builder, "CardGrid")
    if grid:
      var count = 0
      for child in grid.get_children():
        if count >= 10:
          break
        # Simulate tap
        var ev = InputEventMouseButton.new()
        ev.button_index = MOUSE_BUTTON_LEFT
        ev.pressed = true
        ev.position = Vector2(50, 50)
        child.gui_input.emit(ev)
        count += 1
    _capture("screenshots/ui_improved/02_deck_builder_selected.png")
    phase = "confirm"

  if frame == 15 and phase == "confirm" and builder:
    if builder.has_method("_on_confirm"):
      builder._on_confirm()
    phase = "battle_wait"

  if frame == 30 and phase == "battle_wait":
    battle = _find_child(main_scene, "BattleInstance") as Node2D
    if battle == null:
      battle = _find_child(main_scene, "Battle") as Node2D
    if battle:
      _capture("screenshots/ui_improved/03_battle_start.png")
      phase = "battle"
    else:
      print("No battle found")
      quit(1)

  if frame == 40 and phase == "battle":
    _capture("screenshots/ui_improved/04_battle_hand.png")

  if frame == 60 and phase == "battle":
    _capture("screenshots/ui_improved/05_battle_mid.png")

  if frame == 70:
    quit(0)

  return false

func _capture(path: String) -> void:
  var dir_path = path.get_base_dir()
  DirAccess.make_dir_recursive_absolute(dir_path)
  var img = root.get_viewport().get_texture().get_image()
  if img:
    img.save_png(path)
    print("Captured: " + path)
  else:
    print("Failed to capture: " + path)

func _find_child(node: Node, child_name: String) -> Node:
  for c in node.get_children():
    if c.name == child_name:
      return c
    var found = _find_child(c, child_name)
    if found:
      return found
  return null
