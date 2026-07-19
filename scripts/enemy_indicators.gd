extends Node2D
class_name EnemyIndicators

# Constants - Define these as literal values or importable globals
const INDICATOR_RADIUS = 12.0
const RING_RADIUS = 16.0
const VISIBLE_MARGIN = 24.0
const COLOR_RED = Color.RED
const COLOR_WHITE = Color.WHITE
const HALO_ALPHA = 0.25

# Godot 4.x compatible DEG_TO_RAD constant (π / 180)
# Use direct float value instead of Math.PI
const DEG_TO_RAD = 0.017453292519943295

var main_node: Node
var player: Node2D

# Cache viewport rect if you have performance concerns
var _viewport_rect_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D

func initialize(p_main: Node) -> void:
	main_node = p_main
	z_index = 10

func _process(_delta: float) -> void:
	if not main_node or main_node.state != main_node.State.ACTIVE:
		return
	queue_redraw()

func _draw() -> void:
	if not main_node or not player or main_node.state != main_node.State.ACTIVE:
		return

	var viewport := get_viewport_rect().size
	var visible_size := viewport / 2.0
	var cam_pos: Vector2 = player.global_position
	
	# Define screen bounds (center of viewport based on camera/player position)
	var min_bound: Vector2 = cam_pos - visible_size / 2.0
	var max_bound: Vector2 = cam_pos + visible_size / 2.0

	# Iterate over all enemies in the scene
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.dying:
			continue

		var pos: Vector2 = enemy.global_position
		
		# Calculate distance from camera
		var dist_x: float = pos.x - cam_pos.x
		var dist_y: float = pos.y - cam_pos.y
		var is_offscreen = (dist_x < -visible_size.x / 2.0 or dist_x > visible_size.x / 2.0 or
							  dist_y < -visible_size.y / 2.0 or dist_y > visible_size.y / 2.0)

		if is_offscreen:
			var indicator_x: float = pos.x
			var indicator_y: float = pos.y
			
			# Clamp to visible margin (creates a "safe zone" buffer on screen edges)
			var clamp_min_x: float = min_bound.x + VISIBLE_MARGIN
			var clamp_max_x: float = max_bound.x - VISIBLE_MARGIN
			var clamp_min_y: float = min_bound.y + VISIBLE_MARGIN
			var clamp_max_y: float = max_bound.y - VISIBLE_MARGIN
			
			# Clamp logic
			indicator_x = clampf(indicator_x, clamp_min_x, clamp_max_x)
			indicator_y = clampf(indicator_y, clamp_min_y, clamp_max_y)
			
			var screen_indicator: Vector2 = Vector2(indicator_x, indicator_y)

			# Calculate direction from indicator to enemy (OUT OF SCREEN)
			var vec_to_enemy: Vector2 = pos - screen_indicator
			
			# FIX: Add magnitude check to prevent null from .normalized() if vec is zero-length
			var vec_len: float = vec_to_enemy.length()
			if vec_len == 0.0:
				continue # Skip drawing if indicator and enemy are at same position
			
			var dir: Vector2 = vec_to_enemy.normalized()

			var color := COLOR_RED
			match enemy.enemy_type:
				"green": color = Color.GREEN
				"purple": color = Color.MEDIUM_PURPLE
				"bat": color = Color(0.6, 0.4, 0.8)
				"skeleton": color = Color(0.9, 0.85, 0.7)
				"ghost": color = Color(0.3, 0.8, 1.0, 0.8)
				"zombie": color = Color(0.4, 0.6, 0.2)
				"werewolf": color = Color(0.8, 0.3, 0.0)

			# FIX: Godot 4 uses Color property assignment, not with_alpha()
			# Create new Color instance or modify existing
			var halo_color = Color.WHITE
			halo_color.alpha = HALO_ALPHA

			draw_circle(screen_indicator, RING_RADIUS, halo_color)

			# TIP POINTS TOWARD THE ENEMY (OUT OF SCREEN)
			var tip_dist: float = INDICATOR_RADIUS * 1.5
			var p_tip: Vector2 = screen_indicator + dir * tip_dist

			# PERPENDICULAR DIRECTION FOR BASE CORNERS
			var perp: Vector2 = dir.rotated(90.0 * DEG_TO_RAD).normalized()

			var perp_dist: float = INDICATOR_RADIUS
			var p_left: Vector2 = screen_indicator + perp * perp_dist
			var p_right: Vector2 = screen_indicator - perp * perp_dist

			var tri := [p_left, p_right, p_tip]
			# FIX: Godot 4 draw_polygon requires PackedColorArray, not Color
			draw_polygon(tri, PackedColorArray([color]))
