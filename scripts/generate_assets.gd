@tool
extends SceneTree

func _initialize() -> void:
	# All game assets (sprites, sounds, music, ui icons) have already been generated and saved to the res://assets/ directory.
	# The generation code has been removed to reduce project file size and codebase bloat.
	print("Assets already exist. Skipping asset generation.")
	quit()
