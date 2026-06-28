extends Area2D

const DAMAGE := 15
var source_weapon := "missile"


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var main = get_tree().current_scene
	
	# Hide sprite initially for pre-delay anticipation
	$Sprite2D.visible = false
	
	# A. SOUND, SHAKE, AND HIT-STOP TRIGGER IMMEDIATELY (anticipation)
	if main and main.has_method("play_layered_explosion"):
		main.play_layered_explosion(global_position)
	else:
		$AudioStreamPlayer2D.play()
	
	if main and main.has_method("trigger_hit_stop"):
		main.trigger_hit_stop(0.18, 0.02, global_position)

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		if "shake_intensity" in p:
			p.shake_intensity = clampf(p.shake_intensity + 4.0, 0.0, 10.0)

	# B. DELAYED VISUALS, FLASH, PARTICLES, AND DAMAGE BY 25ms (Peak Transient synchronization)
	await get_tree().create_timer(0.025, true, false, true).timeout
	if is_queued_for_deletion():
		return
		
	$Sprite2D.visible = true
	$Sprite2D.scale = Vector2.ZERO
	$Sprite2D.modulate.a = 1.0
	
	# Expanding dynamic explosion light flash synced with peak transient
	if main and main.has_method("get_radial_light_texture"):
		var flash := PointLight2D.new()
		flash.texture = main.get_radial_light_texture()
		flash.texture_scale = 1.0
		flash.color = Color(1.0, 0.65, 0.15)
		flash.energy = 2.2
		add_child(flash)
		var ltween := create_tween().set_ease(Tween.EASE_OUT)
		ltween.set_parallel(true)
		ltween.tween_property(flash, "texture_scale", 6.8, 0.22)
		ltween.tween_property(flash, "energy", 0.0, 0.25)

	# Spawning particles synced with peak transient
	spawn_explosion_particles()

	var tween := create_tween().set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property($Sprite2D, "scale", Vector2(8, 8), 0.15)
	tween.tween_property($Sprite2D, "modulate:a", 0.0, 0.25).set_delay(0.1)
	
	# Apply damage synced with peak transient
	for body in get_overlapping_bodies():
		_on_body_entered(body)
		
	await tween.finished
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemy"):
		return
	if body.has_method("take_damage"):
		body.take_damage(DAMAGE, source_weapon)
	if body.has_method("knockback"):
		var kb_dir: Vector2 = (body.global_position - global_position).normalized()
		body.knockback_velocity = kb_dir * 600.0


func spawn_explosion_particles() -> void:
	var main = get_tree().current_scene
	if not main:
		return
		
	# A. Smoke puff particles
	var smoke := CPUParticles2D.new()
	smoke.emitting = false
	smoke.amount = 22
	smoke.lifetime = 0.5
	smoke.one_shot = true
	smoke.explosiveness = 0.92
	smoke.spread = 180.0
	smoke.gravity = Vector2.ZERO
	smoke.initial_velocity_min = 40.0
	smoke.initial_velocity_max = 90.0
	smoke.scale_amount_min = 5.0
	smoke.scale_amount_max = 11.0
	var s_ramp = Gradient.new()
	s_ramp.set_color(0, Color(0.28, 0.28, 0.28, 0.55))
	s_ramp.set_color(1, Color(0.28, 0.28, 0.28, 0.0))
	smoke.color_ramp = s_ramp
	smoke.global_position = global_position
	main.add_child(smoke)
	smoke.emitting = true
	smoke.finished.connect(smoke.queue_free)
	
	# B. Glowing embers particles
	var embers := CPUParticles2D.new()
	embers.emitting = false
	embers.amount = 18
	embers.lifetime = 0.45
	embers.one_shot = true
	embers.explosiveness = 0.95
	embers.spread = 180.0
	embers.gravity = Vector2(0, -35)
	embers.initial_velocity_min = 60.0
	embers.initial_velocity_max = 135.0
	embers.scale_amount_min = 2.0
	embers.scale_amount_max = 4.2
	var e_ramp = Gradient.new()
	e_ramp.set_color(0, Color(1.0, 0.68, 0.1, 0.95))
	e_ramp.set_color(1, Color(1.0, 0.2, 0.0, 0.0))
	embers.color_ramp = e_ramp
	embers.global_position = global_position
	main.add_child(embers)
	embers.emitting = true
	embers.finished.connect(embers.queue_free)
