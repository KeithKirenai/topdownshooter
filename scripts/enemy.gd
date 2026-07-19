extends CharacterBody2D

# Enemy entity with type-specific stats, movement behaviors, animations, damage, and loot drops.
# Supports 8 enemy types (red, green, purple, bat, skeleton, ghost, zombie, werewolf) each
# with unique speed, health, size, sprite, and movement patterns.

const SPEED := 50.0
const ANIM_SPEED := 0.2
const MAX_HEALTH := 3
const COIN_SCENE := preload("res://scenes/coin.tscn")
const HEART_SCENE := preload("res://scenes/heart.tscn")
const AMMO_SCENE := preload("res://scenes/ammo.tscn")

@onready var sprite := $Sprite2D

var enemy_type: String = "red"
var max_health := MAX_HEALTH
var speed := SPEED
var health := MAX_HEALTH
var anim_frame := 0
var anim_time := 0.0
var dying := false
var knockback_velocity := Vector2.ZERO
var health_label: Label
var walk_bounce_phase: float = 0.0
var hit_wobble_time: float = 0.0
var _base_sprite_scale: Vector2 = Vector2(1.0, 1.0)
var shadow_sprite: Sprite2D
var walk_dust: CPUParticles2D
var clump_rot_offset: float = 0.0

# Per-type custom behavior state
# - werewolf: charges the player in bursts
# - skeleton: moves in stop-start steps
# - bat: sinusoidal wave flight path
var werewolf_charge_timer := 0.0
var werewolf_charge_cooldown := 0.0
var werewolf_is_charging := false
var skeleton_step_timer := 0.0
var skeleton_is_stepping := true
var bat_wave_time := 0.0

var last_hit_by_weapon := ""

signal killed(by_weapon: String)

# Cached references to avoid repeated get_tree() calls
var _tree: SceneTree = null
var _player_node: Node2D = null

# Clump detection timer (check every 0.5s instead of every frame)
var _clump_timer: float = 0.0
const _CLUMP_UPDATE_INTERVAL: float = 0.5


func _ready() -> void:
	add_to_group("enemy")
	_tree = get_tree()
	
	# Apply per-type stats, sprites, and colors
	match enemy_type:
		"green":
			max_health = 25
			speed = 25.0
			scale = Vector2(2.0, 2.0)
			sprite.modulate = Color(0.2, 0.8, 0.2)
		"purple":
			max_health = 60
			speed = 12.5
			scale = Vector2(3.0, 3.0)
			sprite.modulate = Color(0.7, 0.1, 0.85)
		"red":
			max_health = 10
			speed = 50.0
			scale = Vector2(1.0, 1.0)
		"bat":
			max_health = 4
			speed = 85.0
			scale = Vector2(0.75, 0.75)
			sprite.texture = load("res://assets/sprites/enemy_bat.png")
			sprite.modulate = Color.WHITE
		"skeleton":
			max_health = 12
			speed = 45.0
			scale = Vector2(0.95, 0.95)
			sprite.texture = load("res://assets/sprites/enemy_skeleton.png")
			sprite.modulate = Color.WHITE
		"ghost":
			max_health = 8
			speed = 30.0
			scale = Vector2(1.1, 1.1)
			sprite.texture = load("res://assets/sprites/enemy_ghost.png")
			sprite.modulate = Color.WHITE
		"zombie":
			max_health = 20
			speed = 20.0
			scale = Vector2(1.15, 1.15)
			sprite.texture = load("res://assets/sprites/enemy_zombie.png")
			sprite.modulate = Color.WHITE
		"werewolf":
			max_health = 80
			speed = 40.0
			scale = Vector2(1.6, 1.6)
			sprite.texture = load("res://assets/sprites/enemy_werewolf.png")
			sprite.modulate = Color.WHITE
	
	health = max_health
	
	# Floating health label above enemy
	health_label = Label.new()
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.add_theme_font_size_override("font_size", 24)
	health_label.scale = Vector2(0.3, 0.3)
	health_label.size = Vector2(166, 30)
	health_label.position = Vector2(-25, -28)
	add_child(health_label)
	update_health_label()
	
	# Cache player node once
	if _tree:
		_player_node = _tree.get_first_node_in_group("player") as Node2D

	# Create Stylized Shadow Sprite
	var main_scene = get_tree().current_scene
	shadow_sprite = Sprite2D.new()
	if main_scene and main_scene.has_method("_create_shadow_texture"):
		shadow_sprite.texture = main_scene._create_shadow_texture()
	shadow_sprite.position = Vector2(0, 7)
	shadow_sprite.show_behind_parent = true
	add_child(shadow_sprite)
	
	# Start 16-bit cartoon drop-in spawn animation
	var target_pos: Vector2 = sprite.position
	sprite.position.y = target_pos.y - 100.0
	sprite.scale = Vector2(_base_sprite_scale.x * 0.1, _base_sprite_scale.y * 3.0)
	
	var spawn_tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	spawn_tween.tween_property(sprite, "position:y", target_pos.y, 0.20)
	spawn_tween.tween_property(sprite, "scale", _base_sprite_scale, 0.20)
	
	spawn_tween.chain().tween_callback(func():
		_spawn_slam_dust()
	)
	
	# Create walk dust for enemies (except ghosts who float)
	if enemy_type != "ghost":
		walk_dust = CPUParticles2D.new()
		walk_dust.emitting = false
		walk_dust.amount = 8
		walk_dust.lifetime = 0.35
		walk_dust.randomness = 0.5
		walk_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		walk_dust.emission_rect_extents = Vector2(4, 1.5)
		walk_dust.direction = Vector2.DOWN
		walk_dust.gravity = Vector2.ZERO
		walk_dust.initial_velocity_min = 4.0
		walk_dust.initial_velocity_max = 10.0
		walk_dust.scale_amount_min = 1.0
		walk_dust.scale_amount_max = 2.5
		
		var dust_ramp := Gradient.new()
		dust_ramp.set_color(0, Color(0.85, 0.80, 0.75, 0.35))
		dust_ramp.set_color(1, Color(0.92, 0.88, 0.85, 0.0))
		walk_dust.color_ramp = dust_ramp
		walk_dust.position = Vector2(0, 6)
		add_child(walk_dust)


func _physics_process(delta: float) -> void:
	if dying:
		return
	
	# Use cached player node
	if not is_instance_valid(_player_node):
		return

	var dir := (_player_node.global_position - global_position).normalized()
	var move_vel := dir * speed
	
	# Apply custom movement behaviors

	# Throttled clump detection (check every 0.5s instead of every frame)
	_clump_timer += delta
	var close_count := 0 # Initialize here so it exists every frame
	var my_pos := global_position
	if _clump_timer >= _CLUMP_UPDATE_INTERVAL:
		_clump_timer = 0.0
		# Check if clumped with another enemy (only runs every 0.5s)
		for other in get_tree().get_nodes_in_group("enemy"):
			if other != self and is_instance_valid(other) and not other.dying:
				if my_pos.distance_squared_to(other.global_position) < 900.0:
					close_count += 1
					if close_count >= 2:
						break
		
		# Apply squirm rotation offset when clumped with 2+ nearby enemies
		if close_count >= 2:
			clump_rot_offset = lerpf(clump_rot_offset, randf_range(deg_to_rad(-15.0), deg_to_rad(15.0)), delta * 6.0)
			anim_time += delta * randf_range(0.12, 0.42)
		else:
			clump_rot_offset = lerpf(clump_rot_offset, 0.0, delta * 6.0)
	
	if not is_instance_valid(_player_node):
		return

	# Per-type movement modifiers
	if enemy_type == "bat":
		bat_wave_time += delta * 6.0
		var perp := Vector2(-dir.y, dir.x)
		move_vel += perp * sin(bat_wave_time) * 35.0
	elif enemy_type == "skeleton":
		skeleton_step_timer += delta
		if skeleton_step_timer >= 0.6:
			skeleton_step_timer = 0.0
			skeleton_is_stepping = not skeleton_is_stepping
		if not skeleton_is_stepping:
			move_vel = Vector2.ZERO
	elif enemy_type == "werewolf":
		if werewolf_charge_cooldown > 0.0:
			werewolf_charge_cooldown -= delta
		
		if werewolf_is_charging:
			werewolf_charge_timer -= delta
			move_vel = dir * 110.0
			sprite.self_modulate = Color(1.0, 0.2, 0.2)
			if werewolf_charge_timer <= 0.0:
				werewolf_is_charging = false
				werewolf_charge_cooldown = 3.5
				sprite.self_modulate = Color.WHITE
		elif werewolf_charge_cooldown <= 0.0 and global_position.distance_to(_player_node.global_position) <= 160.0:
			werewolf_is_charging = true
			werewolf_charge_timer = 1.5
	
	# Knockback resistance per type
	var final_knockback := knockback_velocity
	if enemy_type == "ghost":
		final_knockback = Vector2.ZERO
	elif enemy_type == "zombie":
		final_knockback = knockback_velocity * 0.25
		
	velocity = move_vel + final_knockback

	# Walk dust particle emission
	if walk_dust:
		var moving := velocity.length() > 5.0
		walk_dust.emitting = moving
		if moving:
			walk_dust.direction = -velocity.normalized()
				
	if close_count >= 2:
		# Squirm organically and desync animation frame time
		clump_rot_offset = lerpf(clump_rot_offset, randf_range(deg_to_rad(-15.0), deg_to_rad(15.0)), delta * 6.0)
		anim_time += delta * randf_range(0.12, 0.42)
	else:
		clump_rot_offset = lerpf(clump_rot_offset, 0.0, delta * 6.0)
			
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500.0 * delta)
	update_animation(delta, dir)
 
 
func get_sprite_dir(dir: Vector2) -> int:
	# Maps movement direction to one of 4 sprite orientation indices (0=down, 1=left, 2=up, 3=right)
	var a := fmod(dir.angle() + TAU, TAU)
	if a < PI * 0.25 or a >= PI * 1.75:
		return 3
	elif a < PI * 0.75:
		return 0
	elif a < PI * 1.25:
		return 1
	else:
		return 2
 
 
func update_animation(delta: float, move_dir: Vector2) -> void:
	if dying:
		return
	anim_time += delta
	if anim_time >= ANIM_SPEED:
		anim_time = 0.0
		anim_frame = (anim_frame + 1) % 2
	var dir := get_sprite_dir(move_dir)
	sprite.frame = dir * 3 + anim_frame

	# --- Don't Starve / Cartoon Style Enemy Bouncy Walk & Wobble ---
	var rot_mod := 0.0
	var bounce_y := 0.0
	var bounce_x := 0.0
	
	if enemy_type == "ghost":
		walk_bounce_phase += delta * 8.0
		bounce_y = sin(walk_bounce_phase) * 0.08
		rot_mod = sin(walk_bounce_phase * 0.5) * deg_to_rad(4.0)
		bounce_x = 0.0
	else:
		var speed_factor := speed
		if enemy_type == "zombie":
			speed_factor = speed * 0.5
		elif enemy_type == "werewolf" and werewolf_is_charging:
			speed_factor = 110.0
		walk_bounce_phase += delta * (speed_factor / 50.0) * 16.0
		rot_mod = sin(walk_bounce_phase) * deg_to_rad(10.0)
		bounce_y = sin(walk_bounce_phase * 2.0) * 0.15
		bounce_x = -bounce_y * 0.5
	
	# Hit wobble — decaying oscillation after taking damage
	var hit_bounce_x := 0.0
	var hit_bounce_y := 0.0
	var hit_rot := 0.0
	if hit_wobble_time > 0.0:
		hit_wobble_time -= delta
		var wobble_val := sin(hit_wobble_time * 40.0) * exp(-hit_wobble_time * 5.0) * 0.35
		hit_bounce_y = wobble_val
		hit_bounce_x = -wobble_val * 0.7
		hit_rot = sin(hit_wobble_time * 30.0) * exp(-hit_wobble_time * 4.0) * deg_to_rad(20.0)
		
	var fx := _base_sprite_scale.x * (1.0 + bounce_x + hit_bounce_x)
	var fy := _base_sprite_scale.y * (1.0 + bounce_y + hit_bounce_y)
	sprite.scale = Vector2(fx, fy)
	sprite.rotation = rot_mod + hit_rot + clump_rot_offset
	
	# Vertical offset to keep sprite feet planted during squash/stretch
	var scale_y_factor := (1.0 + bounce_y + hit_bounce_y)
	if scale_y_factor < 1.0:
		sprite.position.y = 8.0 * (1.0 - scale_y_factor)
	elif scale_y_factor > 1.0:
		sprite.position.y = -8.0 * (scale_y_factor - 1.0)
	else:
		sprite.position.y = 0.0
		
	# Shadow scales and fades with vertical bounce height
	if shadow_sprite:
		var base_s_x := fx * 0.55
		var base_s_y := fy * 0.28
		var height := maxf(0.0, -sprite.position.y)
		var height_factor := clampf(1.0 - (height / 120.0), 0.1, 1.0)
		shadow_sprite.scale = Vector2(base_s_x * height_factor, base_s_y * height_factor)
		shadow_sprite.self_modulate.a = height_factor


func take_damage(amount: int = 1, source_weapon: String = "") -> void:
	if dying:
		return
		
	# A. Trigger sound and hit-stop IMMEDIATELY (anticipation)
	var next_health: int = int(max(0, health - amount))
	var health_ratio: float = float(next_health) / float(max_health)
	$HitSound.pitch_scale = lerpf(1.75, 1.0, health_ratio)
	$HitSound.play()
	
	var main = get_tree().current_scene
	if main and main.has_method("trigger_hit_stop"):
		var duration = 0.06
		if amount >= 15: # heavy hit
			duration = 0.11
		main.trigger_hit_stop(duration, 0.04, global_position)

	# B. Delay visual damage number, particles, and flash by 25ms (Peak Transient synchronization)
	await get_tree().create_timer(0.025, true, false, true).timeout
	if dying or is_queued_for_deletion():
		return
		
	if source_weapon != "":
		last_hit_by_weapon = source_weapon
	health -= amount
	spawn_damage_number(amount)
	update_health_label()
	
	# Spawn dynamic directional splatter particles synced with peak transient
	var kb_dir = knockback_velocity.normalized()
	spawn_splatter_particles(6, kb_dir)
	
	if health <= 0:
		die()
		return
		
	hit_wobble_time = 0.5
	sprite.self_modulate = Color.RED
	queue_redraw()
	await get_tree().create_timer(0.1).timeout
	if not is_queued_for_deletion():
		sprite.self_modulate = Color.WHITE


func die() -> void:
	dying = true
	collision_layer = 0
	collision_mask = 0
	update_health_label()
	$ExplosionSound.play()
	spawn_coin()
	
	# Massive splatter burst on death
	spawn_splatter_particles(16)
	
	# Slightly stronger hit stop on death
	var main = get_tree().current_scene
	if main and main.has_method("trigger_hit_stop"):
		var duration = 0.10
		if enemy_type in ["green", "purple", "werewolf"]:
			duration = 0.18 # Elite/Tank death feels heavier
		main.trigger_hit_stop(duration, 0.03, global_position)
		
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.4)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.4)
	tween.tween_property(sprite, "rotation", sprite.rotation + randf_range(-PI * 3.5, PI * 3.5), 0.4)
	killed.emit(last_hit_by_weapon)
	await tween.finished
	queue_free()


func spawn_coin() -> void:
	# Loot table per enemy type — spawns coins, hearts, or ammo based on drop rates
	var current_scene = get_tree().current_scene
	if not current_scene:
		return

	# Helper to spawn a single pickup at a slightly offset position
	var spawn_one = func(type_str: String, is_gold: bool = false) -> void:
		var pickup
		if type_str == "heart":
			pickup = HEART_SCENE.instantiate()
		elif type_str == "ammo":
			pickup = AMMO_SCENE.instantiate()
		else:
			pickup = COIN_SCENE.instantiate()
			if is_gold:
				pickup.score_value = 50
				pickup.modulate = Color(1.0, 0.85, 0.15, 1.0) # Golden glow
		# Spawn with slight random offset
		var offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
		pickup.global_position = global_position + offset
		current_scene.call_deferred("add_child", pickup)

	# Decide drop rates and quantities based on enemy type
	match enemy_type:
		"bat", "ghost":
			# 35% chance to drop 1 standard coin, otherwise small chance for ammo/health
			var r = randf()
			if r < 0.01: spawn_one.call("heart")
			elif r < 0.05: spawn_one.call("ammo")
			elif r < 0.35: spawn_one.call("coin")
		"red", "skeleton":
			# 50% chance to drop 1 standard coin
			var r = randf()
			if r < 0.02: spawn_one.call("heart")
			elif r < 0.08: spawn_one.call("ammo")
			elif r < 0.50: spawn_one.call("coin")
			else: pass

		"zombie", "green":
			# Guaranteed 1-2 standard coins or 15% chance for a gold coin instead
			var r = randf()
			if r < 0.04: spawn_one.call("heart")
			elif r < 0.12: spawn_one.call("ammo")
			elif r < 0.27: spawn_one.call("coin", true) # Gold coin
			else:
				var count = randi_range(1, 2)
				for i in range(count):
					spawn_one.call("coin")
		"purple":
			# Drops 2 standard coins guaranteed, plus 30% chance for a gold coin
			var r = randf()
			if r < 0.05: spawn_one.call("heart")
			if r < 0.15: spawn_one.call("ammo")
			
			# Drops 2 standard coins
			spawn_one.call("coin")
			spawn_one.call("coin")
			
			if r < 0.30:
				spawn_one.call("coin", true) # Plus a Gold coin
		"werewolf":
			# Drops 2 gold coins guaranteed! And maybe a heart/ammo
			var r = randf()
			if r < 0.15: spawn_one.call("heart")
			if r < 0.25: spawn_one.call("ammo")
			
			spawn_one.call("coin", true)
			spawn_one.call("coin", true)



func _spawn_slam_dust() -> void:
	# Dust burst on spawn landing
	var burst := CPUParticles2D.new()
	burst.emitting = false
	burst.amount = 8
	burst.lifetime = 0.25
	burst.one_shot = true
	burst.explosiveness = 0.85
	burst.spread = 180.0
	burst.gravity = Vector2(0, 50)
	burst.initial_velocity_min = 20.0
	burst.initial_velocity_max = 50.0
	burst.scale_amount_min = 1.5
	burst.scale_amount_max = 3.0
	
	var dust_ramp := Gradient.new()
	dust_ramp.set_color(0, Color(0.85, 0.80, 0.75, 0.4))
	dust_ramp.set_color(1, Color(0.92, 0.88, 0.85, 0.0))
	burst.color_ramp = dust_ramp
	burst.position = Vector2(0, 8)
	
	add_child(burst)
	burst.emitting = true
	burst.finished.connect(burst.queue_free)


func _draw() -> void:
	# Health bar drawn above enemy when damaged
	if health >= max_health or health <= 0:
		return
	var bar_w := 16.0
	var bar_h := 3.0
	var x := -bar_w / 2.0
	var y := -18.0
	var fill_w := bar_w * float(health) / float(max_health)
	draw_rect(Rect2(x, y, bar_w, bar_h), Color.DARK_RED)
	draw_rect(Rect2(x, y, fill_w, bar_h), Color.GREEN_YELLOW)


func update_health_label() -> void:
	if health_label:
		if health <= 0 or health >= max_health:
			health_label.text = ""
		else:
			health_label.text = str(health) + "/" + str(max_health)


func spawn_damage_number(amount: int) -> void:
	# Floating damage popup with color-coded tiers and elastic scale animation
	var label := Label.new()
	label.text = str(amount)
	if amount >= 15:
		label.text = str(amount) + "!! CRIT !!"
	
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	
	var color := Color(1.0, 0.2, 0.2)
	if amount >= 30:
		color = Color(1.0, 0.1, 0.8) # Neon pink
	elif amount >= 15:
		color = Color(1.0, 0.9, 0.1) # Bright yellow
	elif amount >= 5:
		color = Color(1.0, 0.5, 0.0) # Neon orange
	
	label.modulate = color
	label.pivot_offset = Vector2(50, 15)
	label.position = position + Vector2(randf_range(-25, 25), -20)
	label.scale = Vector2(0.1, 0.1)
	if get_parent():
		get_parent().add_child(label)
	else:
		label.queue_free()
		return
	
	var tween := label.create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
	var target_scale = Vector2(0.8, 0.8) if amount < 15 else Vector2(1.2, 1.2)
	tween.tween_property(label, "scale", target_scale, 0.45).set_trans(Tween.TRANS_ELASTIC)
	
	var drift := randf_range(-30, 30)
	tween.tween_property(label, "position", label.position + Vector2(drift, -60), 0.75).set_trans(Tween.TRANS_QUAD)
	
	var fade_tween := label.create_tween().set_ease(Tween.EASE_IN)
	fade_tween.tween_interval(0.4)
	fade_tween.tween_property(label, "modulate:a", 0.0, 0.35)
	fade_tween.finished.connect(label.queue_free)


func spawn_splatter_particles(amount: int, dir: Vector2 = Vector2.ZERO) -> void:
	# Color-matched splatter burst on hit/death per enemy type
	var parts := CPUParticles2D.new()
	parts.emitting = false
	parts.amount = amount
	parts.lifetime = 0.36
	parts.one_shot = true
	parts.explosiveness = 0.92
	parts.spread = 45.0
	parts.gravity = Vector2.ZERO
	parts.initial_velocity_min = 50.0
	parts.initial_velocity_max = 110.0
	parts.scale_amount_min = 2.0
	parts.scale_amount_max = 5.0
	
	# Color coordinated based on enemy type
	var col := Color.RED
	match enemy_type:
		"green":
			col = Color(0.2, 0.8, 0.2)
		"purple":
			col = Color(0.7, 0.15, 0.85)
		"red":
			col = Color(0.9, 0.15, 0.15)
		"bat":
			col = Color(0.5, 0.2, 0.6)
		"skeleton":
			col = Color(0.9, 0.86, 0.8) # Bone white chunks
		"ghost":
			col = Color(0.3, 0.8, 1.0, 0.55) # Ethereal mist
		"zombie":
			col = Color(0.35, 0.55, 0.18) # Rotting green
		"werewolf":
			col = Color(0.52, 0.28, 0.12) # Brown fur/blood
			
	parts.color = col
	var ramp = Gradient.new()
	ramp.set_color(0, col)
	ramp.set_color(1, Color(col.r, col.g, col.b, 0.0))
	parts.color_ramp = ramp
	
	parts.global_position = global_position
	if dir != Vector2.ZERO:
		parts.direction = dir
	else:
		parts.direction = Vector2.UP.rotated(randf_range(-PI, PI))
		
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(parts)
		parts.emitting = true
		parts.finished.connect(parts.queue_free)
	else:
		parts.queue_free()
