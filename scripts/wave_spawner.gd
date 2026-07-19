extends Node
class_name WaveSpawner

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

var main_node: Node2D

func initialize(p_main: Node2D) -> void:
	main_node = p_main

func spawn_wave(round_count: int, count: int) -> void:
	for i in range(count):
		spawn_enemy(round_count)

func spawn_enemy(round_count: int) -> void:
	if not main_node:
		return
		
	var enemy := ENEMY_SCENE.instantiate()
	
	# Dynamic Vampire Survivors style spawning pool based on the round number
	var pool := []
	if round_count <= 1:
		pool = [
			{"type": "bat", "weight": 0.45},
			{"type": "red", "weight": 0.40},
			{"type": "skeleton", "weight": 0.15}
		]
	elif round_count == 2:
		pool = [
			{"type": "bat", "weight": 0.25},
			{"type": "red", "weight": 0.25},
			{"type": "skeleton", "weight": 0.15},
			{"type": "ghost", "weight": 0.15},
			{"type": "zombie", "weight": 0.20}
		]
	elif round_count == 3:
		pool = [
			{"type": "bat", "weight": 0.15},
			{"type": "red", "weight": 0.20},
			{"type": "skeleton", "weight": 0.15},
			{"type": "ghost", "weight": 0.15},
			{"type": "zombie", "weight": 0.20},
			{"type": "green", "weight": 0.15}
		]
	elif round_count == 4:
		pool = [
			{"type": "bat", "weight": 0.10},
			{"type": "red", "weight": 0.15},
			{"type": "skeleton", "weight": 0.10},
			{"type": "ghost", "weight": 0.15},
			{"type": "zombie", "weight": 0.20},
			{"type": "green", "weight": 0.12},
			{"type": "purple", "weight": 0.08},
			{"type": "werewolf", "weight": 0.10}
		]
	else:
		pool = [
			{"type": "bat", "weight": 0.12},
			{"type": "red", "weight": 0.13},
			{"type": "skeleton", "weight": 0.12},
			{"type": "ghost", "weight": 0.13},
			{"type": "zombie", "weight": 0.15},
			{"type": "green", "weight": 0.12},
			{"type": "purple", "weight": 0.11},
			{"type": "werewolf", "weight": 0.12}
		]
	
	# Select type based on weights
	var total_weight := 0.0
	for item in pool:
		total_weight += item["weight"]
	
	var roll := randf() * total_weight
	var selected_type := "red"
	var current_sum := 0.0
	for item in pool:
		current_sum += item["weight"]
		if roll <= current_sum:
			selected_type = item["type"]
			break
			
	enemy.enemy_type = selected_type
		
	var viewport: Vector2 = main_node.get_viewport_rect().size
	var player: Node2D = main_node.get_tree().get_first_node_in_group("player") as Node2D
	var visible_size: Vector2 = viewport / 2.0 # 640x360 logical viewport size under 2x zoom
	var spawn_pos := Vector2.ZERO
	var attempts := 0
	while attempts < 10:
		if not player:
			break
		var side := randi() % 4
		var px := player.global_position.x
		var py := player.global_position.y
		match side:
			0:
				spawn_pos = Vector2(randf_range(px - visible_size.x/2.0, px + visible_size.x/2.0), py - visible_size.y/2.0 - 32)
			1:
				spawn_pos = Vector2(randf_range(px - visible_size.x/2.0, px + visible_size.x/2.0), py + visible_size.y/2.0 + 32)
			2:
				spawn_pos = Vector2(px - visible_size.x/2.0 - 32, randf_range(py - visible_size.y/2.0, py + visible_size.y/2.0))
			3:
				spawn_pos = Vector2(px + visible_size.x/2.0 + 32, randf_range(py - visible_size.y/2.0, py + visible_size.y/2.0))
		
		spawn_pos.x = clampf(spawn_pos.x, -290.0, 1570.0)
		spawn_pos.y = clampf(spawn_pos.y, -210.0, 850.0)
		
		if not player:
			break
		if spawn_pos.distance_to(player.global_position) > 200.0:
			break
		attempts += 1
		
	enemy.position = spawn_pos
	if main_node.has_method("_on_enemy_killed"):
		enemy.killed.connect(main_node._on_enemy_killed)
	main_node.add_child(enemy)
