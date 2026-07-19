extends Area2D

# Imports and Constants
const HudUiKit = preload("res://scripts/hud_ui_kit.gd")
const LIFETIME := 10.0

# Node References
@onready var despawn_timer := $DespawnTimer

# Game Variables
var score_value := 10
var time_accum: float = 0.0

func _ready() -> void:
	# Initialize Sprite and Physics Setup
	if has_node("Sprite2D"):
		$Sprite2D.show()
		$Sprite2D.scale = Vector2(0.4, 0.4) # Meek/compact gameplay size
		time_accum = randf_range(0.0, 10.0)
	
	add_to_group("coins")
	body_entered.connect(_on_body_entered)
	despawn_timer.start(LIFETIME)

func _process(delta: float) -> void:
	time_accum += delta
	
	# Floating bobbing animation
	if has_node("Sprite2D"):
		$Sprite2D.position.y += sin(time_accum * 5.0) * 0.12
	
	# Texture cycling for animation
	if HudUiKit.coin_frames.size() > 0:
		var idx: int = int(time_accum * 30.0) % HudUiKit.coin_frames.size()
		if has_node("Sprite2D"):
			$Sprite2D.texture = HudUiKit.coin_frames[idx]

func _draw() -> void:
	# Fallback drawing for when textures are missing
	if HudUiKit.coin_frames.size() == 0:
		var radius := 8.5
		var rotation_y := time_accum * 3.8
		var width_factor := cos(rotation_y)
		HudUiKit.draw_coin_on_canvas(self, Vector2.ZERO, radius, width_factor)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	# Pickup Logic
	$PickupSound.play()
	
	var main: Node = get_tree().current_scene
	
	# Calculate Score
	var coins_gained := score_value
	var player = get_tree().get_first_node_in_group("player")
	
	# Check for passive bonus
	if player and player.has_method("get") and player.get("passive_golden_touch") == true and randf() < 0.20:
		coins_gained *= 2
	
	if main and main.has_method("add_score"):
		main.call("add_score", coins_gained)
	
	if player:
		if "total_coins_collected" in player:
			player.total_coins_collected += coins_gained
		if "total_items_collected" in player:
			player.total_items_collected += 1
	
	# Cleanup
	if has_node("Sprite2D"):
		$Sprite2D.hide()
	$CollisionShape2D.set_deferred("disabled", true)
	
	# Remove sound node if needed to free memory after it finishes, 
	# but usually we free the parent coin node.
	# Wait for sound to finish before freeing the coin.
	await $PickupSound.finished
	queue_free()

func _on_despawn_timer_timeout() -> void:
	queue_free()
