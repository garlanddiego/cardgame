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
  
  match phase:
    "init":
      if frame == 10:
        _capture("screenshots/ui_review/01_deck_builder.png")
        builder = _find_child(main_scene, "DeckBuilder")
        if builder:
          # Select 10 cards
          var grid = _find_child(builder, "CardGrid")
          if grid:
            var count = 0
            for child in grid.get_children():
              if count >= 10:
                break
              if child is TextureButton or child is Control:
                child.emit_signal("pressed") if child.has_signal("pressed") else null
                count += 1
          phase = "deck_selected"
    
    "deck_selected":
      if frame == 20:
        _capture("screenshots/ui_review/02_deck_selected.png")
        if builder and builder.has_method("_on_confirm"):
          builder._on_confirm()
        phase = "battle_init"
    
    "battle_init":
      if frame == 40:
        battle = _find_child(main_scene, "BattleInstance") as Node2D
        if battle == null:
          battle = _find_child(main_scene, "Battle") as Node2D
        _capture("screenshots/ui_review/03_battle_start.png")
        phase = "battle_hand"
    
    "battle_hand":
      if frame == 50:
        _capture("screenshots/ui_review/04_battle_hand.png")
        phase = "done"
    
    "done":
      if frame == 55:
        quit(0)
  
  return false

func _capture(path: String) -> void:
  var dir = path.get_base_dir()
  DirAccess.make_dir_recursive_absolute(dir)
  var img = root.get_viewport().get_texture().get_image()
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
