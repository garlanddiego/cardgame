extends Node
## scenes/build_draft_battle.gd — Builds the draft battle scene at runtime

func _ready() -> void:
	var root = get_parent()
	# Attach the draft battle script
	var script = load("res://scripts/draft_battle.gd")
	if script:
		root.set_script(script)
