extends Area2D

const LIFETIME := 10.0
const ANIM_SPEED = 4.0 # Consolidated speed for movement
const SCALE_FREQ = 6.0  # Frequency for scaling
const ROT_SPEED = 3.0  # Frequency for rotation

var time_accum: float = 0.0
var _base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_base_scale = $Sprite2D.scale
	# Initialize time randomly to prevent all pickups from starting in sync
	time_accum = randf_range(0.0, 5.0) 
	
	# Connect signals efficiently
	body_entered.connect(_on_body_entered)
	$DespawnTimer.start(LIFETIME)


func _process(delta: float) -> void:
	time_accum += delta
	var t = time_accum # Local variable for readability

	# 1. Movement (Vertical Oscillation)
	$Sprite2D.position.y = sin(t * ANIM_SPEED) * 2.0
	
	# 2. Scaling (Pulsating effect)
	$Sprite2D.scale = _base_scale * (1.0 + sin(t * SCALE_FREQ) * 0.1)
	
	# 3. Rotation
	$Sprite2D.rotation = sin(t * ROT_SPEED) * deg_to_rad(8.0)


func _on_body_entered(body: Node2D) -> void:
	# Check if the body is the player
	if not body.is_in_group("player"):
		return

	# Handle collection effects
	if body.has_method("refill_ammo"):
		body.refill_ammo(0.35) # Refill 35%
	
	if "total_items_collected" in body:
		body.total_items_collected += 1
		
	# Visual cleanup and feedback
	$PickupSound.play()
	$Sprite2D.hide()
	
	# Disable collision and wait for sound to finish playing
	$CollisionShape2D.set_deferred("disabled", true)
	await $PickupSound.finished
	
	# Final step
	queue_free()


func _on_despawn_timer_timeout() -> void:
	# Clean up if the player never collected it
	queue_free()
