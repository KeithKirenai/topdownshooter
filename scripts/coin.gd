extends Area2D

const LIFETIME := 10.0

@onready var despawn_timer := $DespawnTimer

var score_value := 10
var time_accum: float = 0.0
var particles: CPUParticles2D

func _ready() -> void:
	if has_node("Sprite2D"):
		$Sprite2D.show()
		$Sprite2D.scale = Vector2(0.4, 0.4) # Meek/compact gameplay size
	time_accum = randf_range(0.0, 10.0)
	add_to_group("coins")
	body_entered.connect(_on_body_entered)
	despawn_timer.start(LIFETIME)

	# Setup premium gold sparkle trail particles
	particles = CPUParticles2D.new()
	particles.amount = 8
	particles.lifetime = 0.65
	particles.gravity = Vector2(0, 15)
	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 24.0
	particles.spread = 180.0
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.5
	particles.color = Color(1.0, 0.96, 0.50, 0.9)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.92, 0.4, 0.9))
	ramp.set_color(1, Color(1.0, 0.6, 0.0, 0.0))
	particles.color_ramp = ramp
	particles.show_behind_parent = true
	add_child(particles)

func _process(delta: float) -> void:
	time_accum += delta
	# Floating bobbing animation
	position.y += sin(time_accum * 5.0) * 0.12
	if HudUiKit.coin_frames.size() > 0:
		var idx := int(time_accum * 30.0) % HudUiKit.coin_frames.size()
		$Sprite2D.texture = HudUiKit.coin_frames[idx]
	else:
		queue_redraw()

func _draw() -> void:
	if HudUiKit.coin_frames.size() == 0:
		var radius := 8.5
		var rotation_y := time_accum * 3.8
		var width_factor := cos(rotation_y)
		HudUiKit.draw_coin_on_canvas(self, Vector2.ZERO, radius, width_factor)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	$PickupSound.play()
	var main: Node = get_tree().current_scene
	if main and main.has_method("add_score"):
		# Implement double coins passive check if main has method
		var coins_gained := score_value
		var player = get_tree().get_first_node_in_group("player")
		if player and player.get("passive_golden_touch") == true and randf() < 0.20:
			coins_gained *= 2
		main.call("add_score", coins_gained)
		
		if player:
			if "total_coins_collected" in player:
				player.total_coins_collected += coins_gained
			if "total_items_collected" in player:
				player.total_items_collected += 1
	
	if has_node("Sprite2D"):
		$Sprite2D.hide()
	$CollisionShape2D.set_deferred("disabled", true)
	if particles:
		particles.emitting = false
	# Spawn a small gold flash burst upon collection
	var burst_cols: Array[Color] = [Color(1, 0.92, 0.4), Color(1, 0.6, 0)]
	var burst_p := CPUParticles2D.new()
	burst_p.amount = 8
	burst_p.lifetime = 0.35
	burst_p.one_shot = true
	burst_p.explosiveness = 0.9
	burst_p.gravity = Vector2(0, 50)
	burst_p.initial_velocity_min = 25.0
	burst_p.initial_velocity_max = 50.0
	burst_p.spread = 180.0
	burst_p.scale_amount_min = 2.0
	burst_p.scale_amount_max = 4.0
	burst_p.color = Color(1.0, 0.85, 0.2)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.85, 0.2))
	ramp.set_color(1, Color(1, 0.5, 0, 0))
	burst_p.color_ramp = ramp
	add_child(burst_p)
	burst_p.emitting = true
	
	await $PickupSound.finished
	queue_free()

func _on_despawn_timer_timeout() -> void:
	queue_free()
