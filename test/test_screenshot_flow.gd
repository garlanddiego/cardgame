extends SceneTree

var frame: int = 0

func _initialize() -> void:
  var main = load("res://scenes/main.tscn").instantiate()
  root.add_child(main)

func _process(_delta: float) -> bool:
  frame += 1
  if frame == 10:
    DirAccess.make_dir_recursive_absolute("screenshots/flow")
    var img = root.get_viewport().get_texture().get_image()
    if img:
      img.save_png("screenshots/flow/01_character_select.png")
      print("Captured: character select")
  if frame == 12:
    quit(0)
  return false
