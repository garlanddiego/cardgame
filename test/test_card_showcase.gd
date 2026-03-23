extends SceneTree

var frame: int = 0
var cards_to_show: Array = []
var current_index: int = 0
var card_node: Node2D = null
var card_script: GDScript = null

func _initialize() -> void:
  card_script = load("res://scripts/card.gd")
  
  # Dark background
  var bg = ColorRect.new()
  bg.color = Color(0.12, 0.10, 0.08, 1.0)
  bg.size = Vector2(1920, 1080)
  root.add_child(bg)

func _process(_delta: float) -> bool:
  frame += 1
  
  # On frame 5, load card database (autoloads should be ready)
  if frame == 5 and cards_to_show.is_empty():
    var gm = _find_autoload("GameManager")
    if gm == null:
      print("ERROR: GameManager not found, card_database empty")
      quit(1)
      return false
    
    for card_id in gm.card_database:
      var card = gm.card_database[card_id]
      if card["character"] == "ironclad" and card.get("type", 0) != 3:
        cards_to_show.append(card)
    
    cards_to_show.sort_custom(func(a, b):
      if a["type"] != b["type"]:
        return a["type"] < b["type"]
      return a["name"] < b["name"]
    )
    print("Found %d cards" % cards_to_show.size())
    return false
  
  if frame < 6:
    return false
  
  if current_index >= cards_to_show.size():
    print("All %d cards captured!" % current_index)
    quit(0)
    return false
  
  var phase = (frame - 6) % 3
  
  if phase == 0:
    var card_data = cards_to_show[current_index]
    card_node = Area2D.new()
    card_node.set_script(card_script)
    card_node.card_data = card_data
    card_node.position = Vector2(830, 200)
    card_node.scale = Vector2(1.8, 1.8)
    root.add_child(card_node)
  
  elif phase == 2:
    var card_data = cards_to_show[current_index]
    var card_id = card_data.get("id", "unknown")
    _capture("screenshots/cards/%s.png" % card_id)
    if card_node:
      card_node.queue_free()
      card_node = null
    current_index += 1
  
  return false

func _find_autoload(aname: String) -> Node:
  for c in root.get_children():
    if c.name == aname:
      return c
  return null

func _capture(path: String) -> void:
  DirAccess.make_dir_recursive_absolute(path.get_base_dir())
  var img = root.get_viewport().get_texture().get_image()
  if img:
    img.save_png(path)
    print("  %s" % path.get_file())
