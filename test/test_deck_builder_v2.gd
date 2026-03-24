extends SceneTree

var frame: int = 0

func _initialize() -> void:
  # Select character before loading
  var gm = null
  for c in root.get_children():
    if c.name == "GameManager":
      gm = c
      break
  if gm:
    gm.current_character = "silent"
  
  var main = load("res://scenes/main.tscn").instantiate()
  root.add_child(main)

func _process(_delta: float) -> bool:
  frame += 1
  
  if frame == 3:
    # Simulate clicking Silent button
    var main = root.get_node_or_null("Main")
    if main and main.has_method("_on_character_chosen"):
      main._on_character_chosen("silent")
  
  if frame == 20:
    DirAccess.make_dir_recursive_absolute("screenshots/deck_review")
    var img = root.get_viewport().get_texture().get_image()
    if img:
      img.save_png("screenshots/deck_review/deck_builder.png")
      print("Captured deck builder!")
  
  if frame == 22:
    quit(0)
  return false
