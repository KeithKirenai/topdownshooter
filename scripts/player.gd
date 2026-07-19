extends CharacterBody2D

const SPEED = 150.0
const BULLET_SCENE = preload("res://scenes/bullet.tscn")
const JOYSTICK_DEADZONE := 0.15
const ANIM_SPEED := 0.12
const MAGNET_SPEED = 400.0
const MAGNET_RANGE = 120.0

const WEAPON_DATA = WeaponDB.WEAPON_DATA

@onready var sprite := $Sprite2D
@onready var gun_pivot := $GunPivot
@onready var gun_sprite := $GunPivot/GunSprite
@onready var shoot_sound := $ShootSound
@onready var laser := $GunPivot/Laser
@onready var camera := $Camera2D

var health := 3
var max_health := 3
var invincible := false
var _last_input := "mouse"
var anim_frame := 0
var anim_time := 0.0
var weapon := "pistol"
var fire_cooldown := 0.0
var inventory: Array = [["pistol", -1, 8]]
var current_weapon_index := 0
var has_laser_sight := false
var frozen := false
var muzzle_flash_time := 0.0
var shake_intensity: float = 0.0
var shake_decay: float = 16.0
const _weapon_shakes = WeaponDB.WEAPON_SHAKES
const _weapon_scales = WeaponDB.WEAPON_SCALES

var is_reloading := false
var reload_timer := 0.0
var reload_duration := 0.0
var is_empty_reload := false
var _reload_events_triggered := {}
var visual_clip_count: float = 8.0
var active_reload_attempted := false
var active_reload_buff_time := 0.0
var is_jammed := false
var active_reload_status := "none"
var spread_accum := 0.0
var spread_decay_timer := 0.0
var spread_decay_rate := 0.5
var recoil_velocity := Vector2.ZERO

var anim_bounce_time: float = 0.0
var walk_bounce_phase: float = 0.0
var recoil_tilt: float = 0.0
var recoil_squash: float = 0.0
var damage_wobble_time: float = 0.0
var _base_sprite_scale: Vector2 = Vector2(2.0, 2.0)
var visual_gun_kickback: float = 0.0
var _perfect_zone_flashed: bool = false
var perfect_flash_opacity: float = 0.9
var _led_flash_intensity: float = 0.0
var visual_crosshair_pos: Vector2 = Vector2.ZERO
var crosshair_velocity: Vector2 = Vector2.ZERO
var _out_of_ammo_popup_cooldown: float = 0.0

# Per-slot cooldown tracking: { slot_index: { current: float, max: float } }
var _slot_cooldowns: Dictionary = {}
var _walk_step_timer: float = 0.0
const WALK_STEP_INTERVAL := 0.30

var locked_enemy: Node2D = null
var post_proc_aberration: float = 0.0
var post_proc_distortion: float = 0.05

var shadow_sprite: Sprite2D
var player_light: PointLight2D
var flashlight: PointLight2D
var walk_dust: CPUParticles2D
var muzzle_smoke: CPUParticles2D
var jam_vent_smoke: CPUParticles2D

# --- GACHA ARCADE PASSIVE UPGRADES ---
var passive_shield: int = 0
var passive_shield_max: int = 0
var passive_shield_recharge_timer: float = 0.0
var passive_speed_loader: float = 1.0       # e.g., 0.70 for +30% speed
var passive_golden_touch: bool = false       # 20% chance to drop double coins
var passive_magnet_ring: float = 1.0        # e.g., 2.0 for +100% radius
var passive_toughness: int = 0             # 1 if unlocked (chance to block)
var passive_damage_boost: float = 1.0       # e.g., 1.35 for +35% damage
var _cheat_buffer := ""

# Weapon Mastery/Milestone systems
var weapon_unlocks: Dictionary:
	get: return ProgressionManager.weapon_unlocks
	set(val): ProgressionManager.weapon_unlocks = val

# Passive Upgrade unlocks (purchased status)
var passive_unlocks: Dictionary:
	get: return ProgressionManager.passive_unlocks
	set(val): ProgressionManager.passive_unlocks = val

# New stats for milestone tracking
var total_bullets_fired: int:
	get: return ProgressionManager.total_bullets_fired
	set(val): ProgressionManager.total_bullets_fired = val
var total_coins_collected: int:
	get: return ProgressionManager.total_coins_collected
	set(val): ProgressionManager.total_coins_collected = val
var total_items_collected: int:
	get: return ProgressionManager.total_items_collected
	set(val): ProgressionManager.total_items_collected = val
var total_kills: int:
	get: return ProgressionManager.total_kills
	set(val): ProgressionManager.total_kills = val
var peak_combo: int:
	get: return ProgressionManager.peak_combo
	set(val): ProgressionManager.peak_combo = val
var run_survival_time: float:
	get: return ProgressionManager.run_survival_time
	set(val): ProgressionManager.run_survival_time = val

# Keep track of announced milestone completions to prevent spamming
var announced_milestones: Array:
	get: return ProgressionManager.announced_milestones
	set(val): ProgressionManager.announced_milestones = val

var weapon_kills: Dictionary:
	get: return ProgressionManager.weapon_kills
	set(val): ProgressionManager.weapon_kills = val

var time_without_damage := 0.0

var _pistol_texture: Texture2D
var _pistol_sound: AudioStream
var _smg_sound := preload("res://assets/sounds/smg.wav")
var _pistol_shoot := preload("res://assets/sounds/pistol_shoot.wav")
var _shotgun_shoot := preload("res://assets/sounds/shotgun_shoot.wav")
var _minigun_shoot := preload("res://assets/sounds/minigun_shoot.wav")
var _sniper_shoot := preload("res://assets/sounds/sniper_shoot.wav")
var _missile_launch := preload("res://assets/sounds/missile_launch.wav")
var _weapon_switch_sound := preload("res://assets/sounds/weapon_switch.wav")
var SMG_TEXTURE: Texture2D
var _shotgun_texture: Texture2D
var _minigun_texture: Texture2D
var _sniper_texture: Texture2D
var _missile_texture: Texture2D

signal died
signal weapon_changed(inventory: Array, index: int, cooldowns: Dictionary)
signal reload_started(duration: float)
signal reload_ticking(time_left: float)
signal reload_finished


func _ready() -> void:
	add_to_group("player")
	_base_sprite_scale = sprite.scale
	_pistol_texture = gun_sprite.texture
	_pistol_sound = shoot_sound.stream
	SMG_TEXTURE = load("res://assets/sprites/smg.png")
	if not SMG_TEXTURE:
		SMG_TEXTURE = _pistol_texture
	_shotgun_texture = load("res://assets/sprites/shotgun.png")
	if not _shotgun_texture:
		_shotgun_texture = _pistol_texture
	_minigun_texture = load("res://assets/sprites/minigun.png")
	if not _minigun_texture:
		_minigun_texture = _pistol_texture
	_sniper_texture = load("res://assets/sprites/sniper.png")
	if not _sniper_texture:
		_sniper_texture = _pistol_texture
	_missile_texture = load("res://assets/sprites/missile.png")
	if not _missile_texture:
		_missile_texture = _pistol_texture
	shoot_sound.volume_db = 0.0
	update_health_display()
	laser.hide()
	_apply_weapon("pistol")
	_broadcast_weapon()
	
	var renderer = load("res://scripts/player_canvas_renderer.gd").new()
	renderer.player = self
	add_child(renderer)
	
	var main_scene = get_tree().current_scene

	# 1. Stylized Shadow Sprite
	shadow_sprite = Sprite2D.new()
	if main_scene and main_scene.has_method("_create_shadow_texture"):
		shadow_sprite.texture = main_scene._create_shadow_texture()
	shadow_sprite.position = Vector2(0, 10)
	shadow_sprite.show_behind_parent = true
	add_child(shadow_sprite)

	# 2. Player Warm Light Aura & Directional Flashlight
	if main_scene and main_scene.has_method("get_radial_light_texture"):
		var light_tex = main_scene.get_radial_light_texture()
		
		player_light = PointLight2D.new()
		player_light.texture = light_tex
		player_light.texture_scale = 3.5
		player_light.color = Color(1.0, 0.88, 0.68, 0.4)
		player_light.energy = 0.55
		add_child(player_light)
		
		flashlight = PointLight2D.new()
		flashlight.texture = light_tex
		flashlight.texture_scale = 5.2
		flashlight.color = Color(1.0, 0.95, 0.85, 0.55)
		flashlight.energy = 0.8
		flashlight.offset = Vector2(80, 0)
		gun_pivot.add_child(flashlight)

	# 3. Walk Dust CPUParticles2D
	walk_dust = CPUParticles2D.new()
	walk_dust.emitting = false
	walk_dust.amount = 14
	walk_dust.lifetime = 0.38
	walk_dust.randomness = 0.5
	walk_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	walk_dust.emission_rect_extents = Vector2(5, 2)
	walk_dust.direction = Vector2.DOWN
	walk_dust.gravity = Vector2.ZERO
	walk_dust.initial_velocity_min = 5.0
	walk_dust.initial_velocity_max = 12.0
	walk_dust.scale_amount_min = 1.8
	walk_dust.scale_amount_max = 3.8
	var dust_ramp = Gradient.new()
	dust_ramp.set_color(0, Color(0.75, 0.75, 0.75, 0.35))
	dust_ramp.set_color(1, Color(0.75, 0.75, 0.75, 0.0))
	walk_dust.color_ramp = dust_ramp
	walk_dust.position = Vector2(0, 10)
	add_child(walk_dust)

	# 4. Muzzle Smoke CPUParticles2D
	muzzle_smoke = CPUParticles2D.new()
	muzzle_smoke.emitting = false
	muzzle_smoke.amount = 8
	muzzle_smoke.lifetime = 0.25
	muzzle_smoke.one_shot = true
	muzzle_smoke.explosiveness = 0.88
	muzzle_smoke.gravity = Vector2.ZERO
	muzzle_smoke.initial_velocity_min = 25.0
	muzzle_smoke.initial_velocity_max = 45.0
	muzzle_smoke.spread = 32.0
	muzzle_smoke.scale_amount_min = 2.0
	muzzle_smoke.scale_amount_max = 4.5
	var smoke_ramp = Gradient.new()
	smoke_ramp.set_color(0, Color(0.82, 0.82, 0.82, 0.42))
	smoke_ramp.set_color(1, Color(0.82, 0.82, 0.82, 0.0))
	muzzle_smoke.color_ramp = smoke_ramp
	$GunPivot/Muzzle.add_child(muzzle_smoke)

	# Attach walk step player
	var walk_sp := AudioStreamPlayer.new()
	walk_sp.name = "WalkStepSound"
	walk_sp.volume_db = -4.0
	walk_sp.bus = "Standard"
	var wstream: AudioStream = load("res://assets/sounds/walk_step.wav")
	if wstream:
		walk_sp.stream = wstream
	add_child(walk_sp)

	# Attach lock on sound player
	var lock_sp := AudioStreamPlayer.new()
	lock_sp.name = "LockOnSound"
	lock_sp.volume_db = -6.0
	lock_sp.bus = "Standard"
	var lstream: AudioStream = load("res://assets/sounds/lock_on.wav")
	if lstream:
		lock_sp.stream = lstream
	add_child(lock_sp)

	# 5. Dynamic Weather Embers CPUParticles2D (Secret Sauce: World Atmosphere)
	var weather := CPUParticles2D.new()
	weather.name = "WeatherEmbers"
	weather.amount = 45
	weather.lifetime = 4.5
	weather.preprocess = 4.5
	weather.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	weather.emission_rect_extents = Vector2(500, 320)
	weather.direction = Vector2(-1.0, 0.45).normalized()
	weather.spread = 12.0
	weather.gravity = Vector2.ZERO
	weather.initial_velocity_min = 25.0
	weather.initial_velocity_max = 65.0
	weather.scale_amount_min = 1.0
	weather.scale_amount_max = 2.5
	weather.color = Color(1.0, 0.72, 0.4, 0.28) # Soft glowing orange/yellow embers
	var w_ramp = Gradient.new()
	w_ramp.set_color(0, Color(1.0, 0.72, 0.4, 0.0))
	w_ramp.add_point(0.2, Color(1.0, 0.72, 0.4, 0.28))
	w_ramp.add_point(0.8, Color(1.0, 0.45, 0.15, 0.28))
	w_ramp.set_color(1, Color(1.0, 0.45, 0.15, 0.0))
	weather.color_ramp = w_ramp
	add_child(weather)

	# 6. Diegetic Hardware Readout (Gun LED) on Gun Sprite Chassis
	var led := Node2D.new()
	led.name = "GunLed"
	led.position = Vector2(-2.0, -1.5)
	led.draw.connect(_draw_gun_led.bind(led))
	gun_sprite.add_child(led)

	# 7. Jam Vent Smoke CPUParticles2D
	jam_vent_smoke = CPUParticles2D.new()
	jam_vent_smoke.name = "JamVentSmoke"
	jam_vent_smoke.emitting = false
	jam_vent_smoke.amount = 25
	jam_vent_smoke.lifetime = 0.6
	jam_vent_smoke.one_shot = true
	jam_vent_smoke.explosiveness = 0.95
	jam_vent_smoke.gravity = Vector2(0, -40.0)
	jam_vent_smoke.direction = Vector2(-0.8, -0.6).normalized()
	jam_vent_smoke.spread = 25.0
	jam_vent_smoke.initial_velocity_min = 40.0
	jam_vent_smoke.initial_velocity_max = 80.0
	jam_vent_smoke.scale_amount_min = 3.0
	jam_vent_smoke.scale_amount_max = 6.0
	jam_vent_smoke.color = Color(0.12, 0.12, 0.12, 0.85)
	
	var smoke_ramp_jam = Gradient.new()
	smoke_ramp_jam.set_color(0, Color(0.12, 0.12, 0.12, 0.85))
	smoke_ramp_jam.set_color(1, Color(0.2, 0.2, 0.2, 0.0))
	jam_vent_smoke.color_ramp = smoke_ramp_jam
	
	jam_vent_smoke.position = Vector2(-2.0, -1.5)
	gun_sprite.add_child(jam_vent_smoke)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.relative.length() > 0:
		_last_input = "mouse"
	elif event is InputEventJoypadMotion and abs(event.axis_value) > JOYSTICK_DEADZONE:
		_last_input = "gamepad"
	if _menu_open():
		return
	if event.is_action_pressed("switch_weapon_prev"):
		switch_weapon(-1)
	elif event.is_action_pressed("switch_weapon_next"):
		switch_weapon(1)
	elif event is InputEventKey and event.pressed and not event.echo:
		# Capture cheat keys
		var key_char := ""
		match event.keycode:
			KEY_W: key_char = "w"
			KEY_S: key_char = "s"
			KEY_A: key_char = "a"
			KEY_D: key_char = "d"
		if key_char != "":
			_cheat_buffer += key_char
			if _cheat_buffer.length() > 8:
				_cheat_buffer = _cheat_buffer.right(8)
			if _cheat_buffer == "wwsswwdd":
				_cheat_buffer = ""
				_trigger_all_weapons_cheat()
				
		if event.keycode == KEY_R:
			if is_reloading:
				if is_jammed:
					_clear_jam()
				else:
					_attempt_active_reload()
			else:
				_manual_reload()
		else:
			var slot := _key_to_slot(event.keycode)
			if slot >= 0:
				select_slot(slot)


func _process(delta: float) -> void:
	run_survival_time += delta
	_check_milestone_announcements()
	
	# Compute target crosshair position
	var target_crosshair := get_local_mouse_position()
	if _last_input == "gamepad":
		target_crosshair = get_aim_direction() * 140.0
		
	# Initialize on first frame to prevent fly-in transition
	if visual_crosshair_pos == Vector2.ZERO:
		visual_crosshair_pos = target_crosshair
		
	# Hooke's Law spring physics: F = -k * x - c * v
	var displacement := visual_crosshair_pos - target_crosshair
	var stiffness := 380.0
	var damping := 22.0
	var spring_force := -stiffness * displacement - damping * crosshair_velocity
	crosshair_velocity += spring_force * delta
	visual_crosshair_pos += crosshair_velocity * delta
	
	# Decay LED flash intensity, out of ammo popup cooldown, and queue redraw
	_led_flash_intensity = move_toward(_led_flash_intensity, 0.0, delta * 4.0)
	_out_of_ammo_popup_cooldown = max(0.0, _out_of_ammo_popup_cooldown - delta)
	var led_node = gun_sprite.get_node_or_null("GunLed")
	if led_node:
		led_node.queue_redraw()
	if shake_intensity > 0.0:
		camera.offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		shake_intensity = move_toward(shake_intensity, 0.0, shake_decay * delta)
	else:
		camera.offset = Vector2.ZERO

	# Shield recharge tick
	if passive_shield_max > 0 and passive_shield < passive_shield_max:
		passive_shield_recharge_timer -= delta
		if passive_shield_recharge_timer <= 0.0:
			passive_shield = passive_shield_max
			var sp := AudioStreamPlayer.new()
			sp.bus = "Priority"
			sp.stream = preload("res://assets/sounds/lock_on.wav")
			sp.pitch_scale = 2.4
			sp.volume_db = -8.0
			add_child(sp)
			sp.play()
			sp.finished.connect(sp.queue_free)

	# Decay active reload buff
	if active_reload_buff_time > 0.0:
		active_reload_buff_time -= delta
		var pulse = 0.85 + sin(Time.get_ticks_msec() * 0.018) * 0.15
		modulate = Color(1.0, 0.9 * pulse, 0.5 * pulse)
	else:
		if modulate != Color.WHITE and not invincible:
			modulate = Color.WHITE

	# Decay post-processing shader effects
	post_proc_aberration = move_toward(post_proc_aberration, 0.0, 0.25 * delta)
	post_proc_distortion = move_toward(post_proc_distortion, 0.05, 0.45 * delta)
	
	# Apply to ScreenEffects shader material
	var main: Node = get_tree().current_scene
	if main and main.has_node("ScreenShaderLayer/ScreenEffects"):
		var se = main.get_node("ScreenShaderLayer/ScreenEffects") as ColorRect
		if se and se.material:
			se.material.set_shader_parameter("chromatic_aberration", post_proc_aberration)
			se.material.set_shader_parameter("distortion", post_proc_distortion)
			
			# Premium low-health pulsing heartbeat vignette or damage spikes
			var target_vignette = 0.8
			if health == 1:
				target_vignette = 1.35 + sin(Time.get_ticks_msec() * 0.006) * 0.18
			elif damage_wobble_time > 0.0:
				target_vignette = 1.22
			se.material.set_shader_parameter("vignette_intensity", target_vignette)

	if _menu_open():
		return
	var aim_dir := get_aim_direction()
	if aim_dir.length() > 0.01:
		var r_angle := 0.0
		var r_offset := Vector2.ZERO
		if is_reloading and reload_duration > 0.0:
			var progress := 1.0 - clampf(reload_timer / reload_duration, 0.0, 1.0)
			if is_empty_reload:
				if progress < 0.2:
					var t = progress / 0.2
					r_angle = lerpf(0.0, deg_to_rad(-20.0), t)
					r_offset = lerp(Vector2.ZERO, Vector2(-4.0, 3.0), t)
				elif progress < 0.55:
					r_angle = deg_to_rad(-20.0)
					r_offset = Vector2(-4.0, 3.0)
				elif progress < 0.75:
					var t = (progress - 0.55) / 0.2
					r_angle = lerpf(deg_to_rad(-20.0), deg_to_rad(-10.0), t)
					r_offset = lerp(Vector2(-4.0, 3.0), Vector2(-8.0, 1.0), t)
				else:
					var t = (progress - 0.75) / 0.25
					var spring = sin(t * PI * 1.5) * exp(-t * 3.0)
					r_angle = lerpf(deg_to_rad(-10.0), 0.0, t) + spring * deg_to_rad(10.0)
					r_offset = lerp(Vector2(-8.0, 1.0), Vector2.ZERO, t)
			else:
				if progress < 0.25:
					var t = progress / 0.25
					r_angle = lerpf(0.0, deg_to_rad(-15.0), t)
					r_offset = lerp(Vector2.ZERO, Vector2(-3.0, 2.0), t)
				elif progress < 0.65:
					r_angle = deg_to_rad(-15.0)
					r_offset = Vector2(-3.0, 2.0)
				else:
					var t = (progress - 0.65) / 0.35
					var spring = sin(t * PI * 1.5) * exp(-t * 3.0)
					r_angle = lerpf(deg_to_rad(-15.0), 0.0, t) + spring * deg_to_rad(8.0)
					r_offset = lerp(Vector2(-3.0, 2.0), Vector2.ZERO, t)

		gun_pivot.rotation = aim_dir.angle() + (r_angle if aim_dir.x >= 0 else -r_angle)
		gun_sprite.position = r_offset - Vector2(visual_gun_kickback, 0)
		
		var w_scale: Vector2 = _weapon_scales.get(weapon, Vector2(2.0, 2.0))
		if aim_dir.x >= 0:
			gun_sprite.scale = Vector2(w_scale.x, w_scale.y)
			gun_sprite.offset.y = 1
		else:
			gun_sprite.scale = Vector2(w_scale.x, -w_scale.y)
			gun_sprite.offset.y = -1
	update_animation(delta)
	pull_coins(delta)
	# Decay per-slot cooldowns
	for slot_idx in _slot_cooldowns.keys():
		var cd: Dictionary = _slot_cooldowns[slot_idx]
		if cd.current > 0.0:
			cd.current = max(0.0, cd.current - delta)
	fire_cooldown = max(0.0, fire_cooldown - delta)

	# Smoothly animate visual clip count towards the actual clip count
	if current_weapon_index < inventory.size():
		var actual_clip = float(inventory[current_weapon_index][2])
		if visual_clip_count != actual_clip:
			visual_clip_count = move_toward(visual_clip_count, actual_clip, delta * 30.0)

	if is_reloading:
		if Input.is_action_just_pressed("shoot"):
			if is_jammed:
				_play_procedural_sound("blocked")
				_spawn_text_popup("JAMMED! PRESS R", Color(1.0, 0.25, 0.25))
			else:
				_play_procedural_sound("blocked")
				_spawn_text_popup("RELOADING...", Color(1.0, 0.85, 0.2))
			
		if not is_jammed:
			reload_timer -= delta
			var progress := 1.0 - clampf(reload_timer / reload_duration, 0.0, 1.0)
			
			# Perfect zone flash trigger (enters [0.45, 0.58])
			if progress >= 0.45 and progress <= 0.58 and not _perfect_zone_flashed:
				_perfect_zone_flashed = true
				perfect_flash_opacity = 2.2
				var flash_tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
				flash_tween.tween_property(self, "perfect_flash_opacity", 0.9, 0.12)
				
			reload_ticking.emit(max(0.0, reload_timer))
			_tick_reload_sequence(progress, delta)
			if reload_timer <= 0.0:
				_finish_reload()
		return

	var data = WEAPON_DATA.get(weapon, WEAPON_DATA["pistol"])
	if weapon == "pistol":
		if Input.is_action_just_pressed("shoot") and fire_cooldown <= 0.0:
			_shoot_weapon(data)
	elif data["fire_rate"] < 0.3:
		if Input.is_action_pressed("shoot") and fire_cooldown <= 0.0:
			_shoot_weapon(data)
	elif Input.is_action_just_pressed("shoot") and fire_cooldown <= 0.0:
		_shoot_weapon(data)

	spread_decay_timer -= delta
	if spread_decay_timer <= 0.0:
		spread_accum = max(0.0, spread_accum - delta * 0.5)

	muzzle_flash_time = max(0.0, muzzle_flash_time - delta)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if _menu_open():
		return
	
	# Update time without taking damage
	time_without_damage += _delta
	
	if recoil_velocity.length() > 0.0:
		recoil_velocity = recoil_velocity.move_toward(Vector2.ZERO, 600.0 * _delta)
		
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * SPEED + recoil_velocity
	move_and_slide()
	
	if active_reload_buff_time > 0.0 and Engine.get_physics_frames() % 2 == 0:
		var led_node = gun_sprite.get_node_or_null("GunLed")
		if led_node:
			_spawn_led_trail_particle(led_node.global_position)
			
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider and collider.is_in_group("enemy") and not collider.get("dying"):
			take_damage(collider)


func pull_coins(delta: float) -> void:
	for coin in get_tree().get_nodes_in_group("coins"):
		if not is_instance_valid(coin):
			continue
		var dir = global_position - coin.global_position
		var dist = dir.length()
		var pull_range := MAGNET_RANGE * passive_magnet_ring
		if dist > pull_range or dist < 5:
			continue
		coin.global_position += dir.normalized() * MAGNET_SPEED * delta


func get_aim_direction() -> Vector2:
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_node("HUD"):
		var hud = main_scene.get_node("HUD")
		if hud.has_method("get_virtual_aim_vector"):
			var v_aim: Vector2 = hud.get_virtual_aim_vector()
			if v_aim.length() > 0.05:
				_last_input = "gamepad"
				return v_aim.normalized()

	var right_stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	var base_aim := Vector2.ZERO
	
	if right_stick.length() > JOYSTICK_DEADZONE:
		base_aim = right_stick.normalized()
	elif _last_input == "gamepad":
		base_aim = Vector2.RIGHT.rotated(gun_pivot.rotation)
	else:
		var mouse_pos := get_global_mouse_position()
		base_aim = (mouse_pos - global_position).normalized()

	# Aim Assist: check if we should maintain lock on current locked enemy
	var keep_lock := false
	if is_instance_valid(locked_enemy) and not locked_enemy.get("dying"):
		var to_enemy := locked_enemy.global_position - global_position
		var dist := to_enemy.length()
		if dist <= 450.0:
			var enemy_dir := to_enemy.normalized()
			var angle_diff: float = abs(base_aim.angle_to(enemy_dir))
			if angle_diff < 0.96: # generally within 55 degrees of current target
				keep_lock = true

	var best_enemy: Node2D = locked_enemy if keep_lock else null
	# Stricter angle difference threshold (12 degrees / 0.22 rad) to break lock and switch targets, otherwise 35 degrees
	var best_angle_diff: float = 0.22 if keep_lock else 0.61
	var best_score: float = 999999.0
	
	if keep_lock and is_instance_valid(locked_enemy):
		var to_enemy: Vector2 = locked_enemy.global_position - global_position
		var dist: float = to_enemy.length()
		var enemy_dir: Vector2 = to_enemy.normalized()
		var angle_diff: float = abs(base_aim.angle_to(enemy_dir))
		best_score = dist * (1.0 + angle_diff * 2.0)
	
	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		var enemy := enemy_node as Node2D
		if not is_instance_valid(enemy) or enemy.get("dying") == true or enemy == locked_enemy:
			continue
		var to_enemy: Vector2 = enemy.global_position - global_position
		var dist: float = to_enemy.length()
		if dist > 350.0:
			continue
		var enemy_dir: Vector2 = to_enemy.normalized()
		var angle_diff: float = abs(base_aim.angle_to(enemy_dir))
		if angle_diff < best_angle_diff:
			# Proximity prioritizes shorter distance, slightly offset by angle differences
			var score: float = dist * (1.0 + angle_diff * 2.0)
			if score < best_score:
				best_score = score
				best_enemy = enemy
			
	if best_enemy:
		var enemy_dir: Vector2 = (best_enemy.global_position - global_position).normalized()
		base_aim = base_aim.lerp(enemy_dir, 0.45).normalized()
		
	if best_enemy != locked_enemy:
		locked_enemy = best_enemy
		if locked_enemy != null:
			var lock_sp = get_node_or_null("LockOnSound") as AudioStreamPlayer
			if lock_sp:
				lock_sp.play()
			var main: Node = get_tree().current_scene
			if main and main.has_node("HUD"):
				var hud = main.get_node("HUD")
				if hud.has_method("show_lock_on_msg"):
					hud.show_lock_on_msg()
		
	return base_aim


func get_sprite_dir_from_vec(vec: Vector2) -> int:
	if vec.length() < 0.01:
		return 3
	var a := fmod(vec.angle() + TAU, TAU)
	if a < PI * 0.25 or a >= PI * 1.75:
		return 3
	elif a < PI * 0.75:
		return 0
	elif a < PI * 1.25:
		return 1
	else:
		return 2


func update_animation(delta: float) -> void:
	var moving := velocity.length() > 10.0
	var body_dir := velocity if moving else Vector2.RIGHT.rotated(gun_pivot.rotation)
	var dir := get_sprite_dir_from_vec(body_dir)
	
	if walk_dust:
		walk_dust.emitting = moving
		if moving:
			walk_dust.direction = -velocity.normalized()
		
	if moving:
		anim_time += delta
		if anim_time >= ANIM_SPEED:
			anim_time = 0.0
			anim_frame = (anim_frame + 1) % 2
		sprite.frame = dir * 3 + anim_frame + 1
		# Walk step sound
		_walk_step_timer -= delta
		if _walk_step_timer <= 0.0:
			_walk_step_timer = WALK_STEP_INTERVAL
			var wsp := get_node_or_null("WalkStepSound") as AudioStreamPlayer
			if wsp and wsp.stream:
				wsp.pitch_scale = randf_range(0.88, 1.12)
				wsp.play()
	else:
		anim_frame = 0
		sprite.frame = dir * 3
		_walk_step_timer = 0.0

	# --- Don't Starve / Cartoon Style Bouncy Animation ---
	anim_bounce_time += delta
	
	var scale_x_mod := 0.0
	var scale_y_mod := 0.0
	var rot_mod := 0.0
	
	if moving:
		# Fast step rocking and vertical squishing walking cycle
		walk_bounce_phase += delta * 16.0
		# Rocking rotation (angle back and forth like cardboard cutout)
		rot_mod = sin(walk_bounce_phase) * deg_to_rad(9.0)
		# Double-frequency bounce (squash-stretch on every step)
		scale_y_mod = sin(walk_bounce_phase * 2.0) * 0.12
		scale_x_mod = -scale_y_mod * 0.5
	else:
		# Return walking phase smoothly to 0
		walk_bounce_phase = move_toward(walk_bounce_phase, 0.0, delta * 10.0)
		# Gentle idle breathing cycle
		scale_y_mod = sin(anim_bounce_time * 4.5) * 0.035
		scale_x_mod = -scale_y_mod * 0.5
		rot_mod = sin(anim_bounce_time * 2.2) * deg_to_rad(1.5)
		
	# Firing recoil tilt & squash decay
	if recoil_squash != 0.0 or recoil_tilt != 0.0:
		recoil_squash = move_toward(recoil_squash, 0.0, delta * 2.0)
		recoil_tilt = move_toward(recoil_tilt, 0.0, delta * 5.0)
	
	# Firing wobble effect
	var shoot_bounce_y := recoil_squash
	var shoot_bounce_x := -recoil_squash * 0.6
	
	# Damage wobble springy oscillation
	var damage_bounce_x := 0.0
	var damage_bounce_y := 0.0
	var damage_rot := 0.0
	if damage_wobble_time > 0.0:
		damage_wobble_time -= delta
		var wobble_val := sin(damage_wobble_time * 35.0) * exp(-damage_wobble_time * 3.5) * 0.35
		damage_bounce_y = wobble_val
		damage_bounce_x = -wobble_val * 0.7
		damage_rot = sin(damage_wobble_time * 30.0) * exp(-damage_wobble_time * 3.0) * deg_to_rad(20.0)

	# Apply scale
	var fx := _base_sprite_scale.x * (1.0 + scale_x_mod + shoot_bounce_x + damage_bounce_x)
	var fy := _base_sprite_scale.y * (1.0 + scale_y_mod + shoot_bounce_y + damage_bounce_y)
	sprite.scale = Vector2(fx, fy)
	
	# Apply rotation
	sprite.rotation = rot_mod + recoil_tilt + damage_rot
	
	# Keep feet on ground by offsetting Y position based on vertical scaling
	var scale_y_factor := (1.0 + scale_y_mod + shoot_bounce_y + damage_bounce_y)
	if scale_y_factor < 1.0:
		sprite.position.y = 8.0 * (1.0 - scale_y_factor)
	elif scale_y_factor > 1.0:
		sprite.position.y = -8.0 * (scale_y_factor - 1.0)
	else:
		sprite.position.y = 0.0
		
	if shadow_sprite:
		var base_s_x := fx * 0.55
		var base_s_y := fy * 0.28
		var height := maxf(0.0, -sprite.position.y)
		var height_factor := clampf(1.0 - (height / 120.0), 0.1, 1.0)
		shadow_sprite.scale = Vector2(base_s_x * height_factor, base_s_y * height_factor)
		shadow_sprite.self_modulate.a = height_factor


func _shoot_weapon(data: Dictionary) -> void:
	if is_reloading:
		return

	if muzzle_smoke:
		muzzle_smoke.restart()
		muzzle_smoke.emitting = true

	var ammo_idx := current_weapon_index
	if ammo_idx < 0 or ammo_idx >= inventory.size():
		return
	var entry = inventory[ammo_idx]
	var clip = entry[2]
	var clip_max = data.get("clip_max", 8)
	var reserve = entry[1]
	
	if clip <= 0:
		if reserve == -1 or reserve > 0:
			if _out_of_ammo_popup_cooldown <= 0.0:
				_spawn_text_popup("RELOADING...", Color(1.0, 0.85, 0.2))
				_out_of_ammo_popup_cooldown = 1.0
			_manual_reload()
		else:
			if _out_of_ammo_popup_cooldown <= 0.0:
				_play_procedural_sound("blocked")
				_spawn_text_popup("OUT OF AMMO!", Color(1.0, 0.2, 0.2))
				_out_of_ammo_popup_cooldown = 1.0
				var click_sp := get_node_or_null("LockOnSound") as AudioStreamPlayer
				if click_sp:
					click_sp.pitch_scale = 2.0
					click_sp.play()
		return
		
	entry[2] = clip - 1
	var new_clip = entry[2]
	var ratio = float(new_clip) / float(clip_max)
	if new_clip == 0:
		_play_procedural_sound("empty_warning")
	elif ratio <= 0.33:
		_play_procedural_sound("low_ammo_warning")
	if not $GunPivot/Muzzle:
		return
	var base_dir := Vector2.RIGHT.rotated(gun_pivot.rotation)
	var used_spread = data["spread"] + spread_accum
	if weapon == "minigun":
		spread_accum = min(spread_accum + 0.008, 0.08)
		spread_decay_timer = 0.3
	for i in range(data["bullets"]):
		total_bullets_fired += 1
		var bullet := BULLET_SCENE.instantiate()
		bullet.global_position = get_muzzle_global_position()
		var spread := randf_range(-used_spread, used_spread)
		bullet.direction = base_dir.rotated(spread)
		bullet.penetrate = data["penetrate"]
		bullet.explosive = data["explosive"]
		bullet.bullet_type = data["bullet_type"]
		var active_reload_dmg_mult = 1.35 if active_reload_buff_time > 0.0 else 1.0
		bullet.damage = int(roundf(float(data["damage"]) * passive_damage_boost * active_reload_dmg_mult))
		if get_tree() and get_tree().current_scene:
			get_tree().current_scene.add_child(bullet)
		else:
			bullet.queue_free()
	
	# Procedural shell casing ejection
	_spawn_shell_casing()
	
	# Trigger professional layered shoot sound in main (once per shot, not per bullet)
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("play_layered_shoot"):
		main_scene.play_layered_shoot(weapon, get_muzzle_global_position())
	else:
		shoot_sound.play()
	var amt: float = _weapon_shakes.get(weapon, 0.6)
	shake_intensity = clampf(shake_intensity + amt, 0.0, 10.0)

	var ab_sp := 0.012
	var ds_sp := 0.08
	match weapon:
		"shotgun":
			ab_sp = 0.035
			ds_sp = 0.25
		"sniper":
			ab_sp = 0.04
			ds_sp = 0.3
		"missile":
			ab_sp = 0.045
			ds_sp = 0.32
		"smg", "minigun":
			ab_sp = 0.008
			ds_sp = 0.05
	post_proc_aberration = clampf(post_proc_aberration + ab_sp, 0.0, 0.065)
	post_proc_distortion = clampf(post_proc_distortion + ds_sp, -0.3, 0.4)

	# Track per-slot cooldown for current weapon with active reload fire rate buff
	var active_reload_fr_mult = 0.75 if active_reload_buff_time > 0.0 else 1.0
	var applied_cooldown = data["fire_rate"] * active_reload_fr_mult
	fire_cooldown = applied_cooldown
	_slot_cooldowns[current_weapon_index] = { "current": applied_cooldown, "max": applied_cooldown }

	# Visual gun kickback and tween recovery (the "punch")
	var kick_amt := 12.0
	match weapon:
		"pistol": kick_amt = 8.0
		"smg": kick_amt = 6.0
		"shotgun": kick_amt = 18.0
		"minigun": kick_amt = 5.0
		"sniper": kick_amt = 30.0
		"missile": kick_amt = 26.0
	
	visual_gun_kickback = kick_amt
	var kick_tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	kick_tween.tween_property(self, "visual_gun_kickback", 0.0, applied_cooldown)

	var tilt_amt := deg_to_rad(12.0)
	var squash_amt := -0.15
	if weapon == "sniper" or weapon == "missile" or weapon == "shotgun":
		tilt_amt = deg_to_rad(24.0)
		squash_amt = -0.3
	elif weapon == "smg" or weapon == "minigun":
		tilt_amt = deg_to_rad(7.0)
		squash_amt = -0.08
	if base_dir.x >= 0:
		recoil_tilt = -tilt_amt
	else:
		recoil_tilt = tilt_amt
	recoil_squash = squash_amt

	if data["recoil"] > 0.0:
		recoil_velocity -= base_dir * data["recoil"]
	muzzle_flash_time = 0.07
	_broadcast_weapon()


func _manual_reload() -> void:
	if is_reloading:
		return
	var data = WEAPON_DATA.get(weapon, WEAPON_DATA["pistol"])
	var clip_max = data.get("clip_max", 1)
	
	var ammo_idx := current_weapon_index
	if ammo_idx >= inventory.size():
		return
	var entry = inventory[ammo_idx]
	if entry.size() <= 2:
		entry.append(clip_max)
		
	var current_clip = entry[2]
	var reserve = entry[1]
	
	if current_clip >= clip_max:
		_play_procedural_sound("blocked")
		_spawn_text_popup("FULL MAGAZINE", Color(0.3, 0.8, 1.0))
		return
		
	if reserve != -1 and reserve <= 0:
		_play_procedural_sound("blocked")
		_spawn_text_popup("NO AMMO", Color(1.0, 0.3, 0.3))
		return
		
	_start_reload(data.get("reload_time", 1.0) * passive_speed_loader)


func _start_reload(duration: float) -> void:
	is_reloading = true
	reload_duration = duration
	reload_timer = duration
	if current_weapon_index < 0 or current_weapon_index >= inventory.size():
		is_reloading = false
		return
	var entry = inventory[current_weapon_index]
	is_empty_reload = true
	_reload_events_triggered.clear()
	
	active_reload_attempted = false
	active_reload_status = "none"
	is_jammed = false
	_perfect_zone_flashed = false
	perfect_flash_opacity = 0.9
	
	if $SniperReloadSound.playing:
		$SniperReloadSound.stop()
		
	reload_started.emit(duration)


func _finish_reload() -> void:
	is_reloading = false
	reload_timer = 0.0
	
	var data = WEAPON_DATA.get(weapon, WEAPON_DATA["pistol"])
	var clip_max = data.get("clip_max", 1)
	
	var ammo_idx := current_weapon_index
	if ammo_idx < inventory.size():
		var entry = inventory[ammo_idx]
		if entry.size() <= 2:
			entry.append(clip_max)
			
		var current_clip = entry[2]
		var reserve = entry[1]
		var needed = clip_max - current_clip
		
		_play_procedural_sound("ui_tick")
		
		if reserve == -1:
			entry[2] = clip_max
		else:
			var transfer = mini(needed, reserve)
			entry[2] = current_clip + transfer
			entry[1] = reserve - transfer
			
	reload_finished.emit()
	_broadcast_weapon()


func _cancel_reload() -> void:
	if is_reloading:
		is_reloading = false
		reload_timer = 0.0
		$SniperReloadSound.stop()
		
		var t = gun_sprite.create_tween()
		t.tween_property(gun_sprite, "scale", Vector2.ZERO, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(gun_sprite, "scale", _weapon_scales.get(weapon, Vector2(2.0, 2.0)), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		reload_finished.emit()


func _tick_reload_sequence(progress: float, delta: float) -> void:
	if progress >= 0.05 and not _reload_events_triggered.has("voice"):
		_reload_events_triggered["voice"] = true
		_play_procedural_sound("voice")
		_spawn_text_popup("RELOADING!", Color(1.0, 0.85, 0.2))
		
	if progress >= 0.15 and not _reload_events_triggered.has("mag_out"):
		_reload_events_triggered["mag_out"] = true
		_play_procedural_sound("mag_out")
		_spawn_physical_magazine()
		visual_clip_count = 0.0
		camera.offset += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 2.0
		_led_flash_intensity = 1.8
		
	var mag_in_trigger = 0.45 if is_empty_reload else 0.50
	if progress >= mag_in_trigger and not _reload_events_triggered.has("mag_in"):
		_reload_events_triggered["mag_in"] = true
		_play_procedural_sound("mag_in")
		shake_intensity = clampf(shake_intensity + 1.2, 0.0, 5.0)
		camera.offset += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 3.0
		_led_flash_intensity = 1.8
		
		var main = get_tree().current_scene
		if main and main.has_method("trigger_hit_stop"):
			main.trigger_hit_stop(0.04, 0.01, global_position)
			
	if is_empty_reload and progress >= 0.75 and not _reload_events_triggered.has("bolt_rack"):
		_reload_events_triggered["bolt_rack"] = true
		_play_procedural_sound("bolt_rack")
		shake_intensity = clampf(shake_intensity + 1.8, 0.0, 5.0)
		camera.offset += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 4.0
		_led_flash_intensity = 1.8


func _attempt_active_reload() -> void:
	if active_reload_attempted:
		return
	active_reload_attempted = true
	
	var progress := 1.0 - clampf(reload_timer / reload_duration, 0.0, 1.0)
	
	var perfect_min := 0.45
	var perfect_max := 0.58
	var good_min := 0.32
	var good_max := 0.70
	
	if progress >= perfect_min and progress <= perfect_max:
		_trigger_perfect_reload()
	elif progress >= good_min and progress <= good_max:
		_trigger_good_reload()
	else:
		_trigger_failed_reload()


func _trigger_perfect_reload() -> void:
	active_reload_status = "perfect"
	_play_procedural_sound("perfect_ping")
	_play_procedural_sound("perfect_clack") # Sharp, heavy mechanical bolt snap!
	_spawn_text_popup("PERFECT!", Color(1.0, 0.85, 0.2))
	
	active_reload_buff_time = 6.0
	
	var tween := create_tween()
	modulate = Color(2.0, 1.8, 1.0)
	tween.tween_property(self, "modulate", Color.WHITE, 0.35)
	
	_spawn_sparkle_particles()
	_spawn_ui_reload_particles() # Burst of golden sparks from the bar!
	
	var main = get_tree().current_scene
	if main and main.has_method("trigger_hit_stop"):
		main.trigger_hit_stop(0.05, 0.01, global_position)
		
	# Rhythm Game snap: freeze the UI indicator for 50 milliseconds before finishing
	await get_tree().create_timer(0.05, true, false, true).timeout
	_finish_reload()


func _trigger_good_reload() -> void:
	active_reload_status = "good"
	_play_procedural_sound("good_click")
	_spawn_text_popup("GOOD", Color(0.8, 1.0, 0.8))
	_finish_reload()


func _trigger_failed_reload() -> void:
	active_reload_status = "failed"
	is_jammed = true
	_play_procedural_sound("failed_jam")
	_spawn_text_popup("JAMMED", Color(1.0, 0.25, 0.25))
	
	var tween := create_tween()
	modulate = Color(1.0, 0.2, 0.2)
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)
	
	if jam_vent_smoke:
		jam_vent_smoke.restart()
		jam_vent_smoke.emitting = true
		
	_spawn_smoke_particles()


func _clear_jam() -> void:
	is_jammed = false
	_play_procedural_sound("bolt_rack")
	_spawn_text_popup("CLEARED", Color(0.3, 1.0, 0.3))
	
	# Apply a violent visual kickback to represent racking the bolt
	visual_gun_kickback = 12.0
	var kick_tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	kick_tween.tween_property(self, "visual_gun_kickback", 0.0, 0.25)
	
	# Trigger camera shake and visual recoil tilt
	shake_intensity = clampf(shake_intensity + 1.5, 0.0, 4.0)
	recoil_tilt = deg_to_rad(-12.0) if gun_sprite.scale.y >= 0 else deg_to_rad(12.0)


func _spawn_sparkle_particles() -> void:
	for i in range(12):
		var p := ColorRect.new()
		p.size = Vector2(2.5, 2.5)
		p.color = Color(1.0, 0.9, 0.3)
		p.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		if get_parent():
			get_parent().add_child(p)
		else:
			p.queue_free()
		
		var angle := randf_range(0, TAU)
		var dist := randf_range(15.0, 30.0)
		var target := p.global_position + Vector2(cos(angle), sin(angle)) * dist
		
		var t := p.create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		t.tween_property(p, "global_position", target, 0.55)
		t.tween_property(p, "modulate:a", 0.0, 0.55)
		t.chain().tween_callback(p.queue_free)


func _spawn_smoke_particles() -> void:
	for i in range(8):
		var p := ColorRect.new()
		p.size = Vector2(4.0, 4.0)
		p.color = Color(0.3, 0.3, 0.3, 0.8)
		p.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		if get_parent():
			get_parent().add_child(p)
		else:
			p.queue_free()
		
		var target := p.global_position + Vector2(randf_range(-12, 12), randf_range(-25, -10))
		
		var t := p.create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		t.tween_property(p, "global_position", target, 0.7)
		t.tween_property(p, "scale", Vector2(1.8, 1.8), 0.7)
		t.tween_property(p, "modulate:a", 0.0, 0.7)
		t.chain().tween_callback(p.queue_free)


func _play_procedural_sound(type: String) -> void:
	ProceduralAudioHelper.play_procedural_sound(self, type)


func _spawn_physical_magazine() -> void:
	var mag := ColorRect.new()
	mag.size = Vector2(3, 7)
	mag.color = Color(0.2, 0.22, 0.25)
	mag.pivot_offset = mag.size / 2.0
	mag.global_position = global_position + gun_pivot.position + Vector2(8, 0).rotated(gun_pivot.rotation)
	
	if get_parent():
		get_parent().add_child(mag)
	else:
		mag.queue_free()
	
	var eject_dir := Vector2.DOWN.rotated(gun_pivot.rotation)
	if gun_sprite.scale.y < 0:
		eject_dir = Vector2.UP.rotated(gun_pivot.rotation)
		
	var vel := eject_dir * randf_range(60.0, 100.0) + velocity * 0.5
	var rot_vel := randf_range(-15.0, 15.0)
	
	var t := mag.create_tween().set_parallel(true)
	t.tween_property(mag, "global_position:x", mag.global_position.x + vel.x * 0.8, 0.8)
	
	var floor_y := mag.global_position.y + randf_range(30.0, 50.0)
	var vert_tween := mag.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	vert_tween.tween_property(mag, "global_position:y", floor_y, 0.35)
	vert_tween.tween_property(mag, "global_position:y", floor_y - 12.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	vert_tween.tween_property(mag, "global_position:y", floor_y, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	t.tween_property(mag, "rotation", mag.rotation + rot_vel * 0.8, 0.8)
	t.chain().tween_property(mag, "modulate:a", 0.0, 0.4)
	t.chain().tween_callback(mag.queue_free)


func _spawn_text_popup(txt: String, color: Color) -> void:
	var label := Label.new()
	label.text = txt
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.modulate = color
	label.pivot_offset = Vector2(50, 10)
	label.position = global_position + Vector2(randf_range(-15, 15), -35)
	label.scale = Vector2(0.8, 0.8)
	if get_parent():
		get_parent().add_child(label)
	else:
		label.queue_free()
		return
	
	var tween := label.create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.1, 1.1), 0.25).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "position", label.position + Vector2(0, -30), 0.5)
	
	var fade := label.create_tween().set_ease(Tween.EASE_IN)
	fade.tween_interval(0.3)
	fade.tween_property(label, "modulate:a", 0.0, 0.2)
	fade.finished.connect(label.queue_free)


func update_laser(_delta: float, _aim_dir: Vector2) -> void:
	if laser:
		laser.hide()


func _draw() -> void:
	if _menu_open():
		if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_HIDDEN:
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)



func _draw_gun_led(led: Node2D) -> void:
	var led_color := Color.CYAN
	var is_on := true
	
	if active_reload_buff_time > 0.0:
		# Blinding white
		led_color = Color(2.0, 2.0, 2.0, 1.0)
	elif is_reloading:
		# Flashes yellow in sync with audio ticks
		var pulse := 0.4 + 0.6 * sin(Time.get_ticks_msec() * 0.035)
		var val = clampf(pulse + _led_flash_intensity, 0.0, 2.0)
		led_color = Color(1.0, 0.85, 0.0) * val
	else:
		var clip := 0
		if current_weapon_index < inventory.size():
			clip = inventory[current_weapon_index][2]
		
		if clip == 0:
			# Blinks harsh red
			var blink := sin(Time.get_ticks_msec() * 0.02) > 0.0
			is_on = blink
			led_color = Color(1.0, 0.1, 0.1)
		else:
			# Firing or ready: cyan. Ready is normal, firing is brighter
			if fire_cooldown > 0.0:
				led_color = Color(0.2, 1.5, 2.0)
			else:
				led_color = Color(0.0, 0.8, 1.0)
	
	if is_on:
		# Draw a tiny black border/bezel
		led.draw_rect(Rect2(-2.0, -1.25, 4.0, 2.5), Color.BLACK, true)
		# Draw the LED itself (3.0 x 1.5)
		led.draw_rect(Rect2(-1.5, -0.75, 3.0, 1.5), led_color, true)
		# Draw a translucent glow circle around it
		var glow_color = Color(led_color.r, led_color.g, led_color.b, 0.3)
		led.draw_circle(Vector2.ZERO, 3.5, glow_color)


func _spawn_led_trail_particle(global_pos: Vector2) -> void:
	var particle := Node2D.new()
	particle.global_position = global_pos
	particle.draw.connect(func():
		particle.draw_circle(Vector2.ZERO, 2.5, Color.WHITE)
		particle.draw_circle(Vector2.ZERO, 4.5, Color(1.0, 1.0, 1.0, 0.25))
	)
	if get_parent():
		get_parent().add_child(particle)
	else:
		particle.queue_free()
	
	var tween := particle.create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(particle, "scale", Vector2.ZERO, 0.28)
	tween.tween_property(particle, "modulate:a", 0.0, 0.28)
	tween.chain().tween_callback(particle.queue_free)


func _trigger_all_weapons_cheat() -> void:
	# Unlock all weapons from WEAPON_DATA
	for w_name in WEAPON_DATA.keys():
		add_weapon(w_name)
	
	# Refill ammo to maximum
	refill_ammo(1.0)
	
	# Play high-pitch victory chime
	var sp := AudioStreamPlayer.new()
	sp.bus = "Standard"
	sp.stream = preload("res://assets/sounds/round_win.wav")
	sp.pitch_scale = 1.8
	sp.volume_db = -5.0
	add_child(sp)
	sp.play()
	sp.finished.connect(sp.queue_free)
	
	# Spawn a gold floating text announcement
	var label := Label.new()
	label.text = "CHEAT: ALL WEAPONS UNLOCKED!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", HudUiKit.C_GOLD_BRIGHT)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", HudUiKit.C_OUTLINE)
	label.position = Vector2(-120, -55)
	add_child(label)
	
	# Animate float & fade
	var t = create_tween().set_parallel(true)
	t.tween_property(label, "position:y", -95.0, 1.4)
	t.tween_property(label, "modulate:a", 0.0, 1.4)
	t.chain().tween_callback(label.queue_free)


func get_muzzle_local_position() -> Vector2:
	var w_scale: Vector2 = _weapon_scales.get(weapon, Vector2(2.0, 2.0))
	var offset := Vector2(20.0, -1.0)
	match weapon:
		"pistol": offset = Vector2(20.0, -1.0)
		"smg": offset = Vector2(20.0, -1.0)
		"shotgun": offset = Vector2(24.0, -1.0)
		"minigun": offset = Vector2(26.0, -1.0)
		"sniper": offset = Vector2(30.0, -2.0)
		"missile": offset = Vector2(24.0, -1.0)
		
	var scaled_offset := Vector2(offset.x * w_scale.x, offset.y * w_scale.y)
	var aim_dir := get_aim_direction()
	if aim_dir.x < 0:
		scaled_offset.y = -scaled_offset.y
		
	return gun_pivot.position + scaled_offset.rotated(gun_pivot.rotation)


func get_muzzle_global_position() -> Vector2:
	return global_position + get_muzzle_local_position()


func _menu_open() -> bool:
	if frozen:
		return true
	var main := get_tree().current_scene
	return main and main.has_method("get_menu_open") and main.get_menu_open()


func set_frozen(val: bool) -> void:
	frozen = val


func add_weapon(type: String) -> void:
	for entry in inventory:
		if entry[0] == type:
			return
	var data = WEAPON_DATA.get(type, WEAPON_DATA["pistol"])
	var max_ammo = data["ammo_max"]
	var clip_max = data.get("clip_max", 1)
	inventory.append([type, max_ammo, clip_max])
	_broadcast_weapon()


func refill_ammo(percent: float = 1.0) -> void:
	for entry in inventory:
		var weapon_name := entry[0] as String
		if weapon_name == "pistol":
			var clip_max = WEAPON_DATA.get(weapon_name, WEAPON_DATA["pistol"]).get("clip_max", 1)
			if entry.size() > 2:
				entry[2] = clip_max
			continue
		var data = WEAPON_DATA.get(weapon_name, WEAPON_DATA["pistol"])
		var max_ammo = data["ammo_max"]
		var clip_max = data.get("clip_max", 1)
		if percent >= 1.0:
			entry[1] = max_ammo
		else:
			entry[1] = mini(entry[1] + int(ceil(max_ammo * percent)), max_ammo)
		if entry.size() > 2:
			entry[2] = clip_max
	spawn_ammo_popup()
	play_ammo_pickup_sound()
	_broadcast_weapon()


func switch_weapon(dir: int) -> void:
	if inventory.size() < 2:
		return
	_cancel_reload()
	current_weapon_index = wrapi(current_weapon_index + dir, 0, inventory.size())
	_apply_weapon(inventory[current_weapon_index][0])
	_play_switch_sound()
	_broadcast_weapon()


func select_slot(slot: int) -> void:
	if slot < 0 or slot >= inventory.size():
		return
	if slot == current_weapon_index:
		return
	_cancel_reload()
	current_weapon_index = slot
	_apply_weapon(inventory[current_weapon_index][0])
	_play_switch_sound()
	_broadcast_weapon()


func _play_switch_sound() -> void:
	var player := AudioStreamPlayer.new()
	player.bus = "Standard"
	player.stream = _weapon_switch_sound
	player.volume_db = -6.0
	add_child(player)
	player.play()
	await player.finished
	player.queue_free()


func _key_to_slot(keycode: int) -> int:
	match keycode:
		KEY_1: return 0
		KEY_2: return 1
		KEY_3: return 2
		KEY_4: return 3
		KEY_5: return 4
		KEY_6: return 5
		KEY_7: return 6
		KEY_8: return 7
		KEY_9: return 8
		KEY_0: return 9
	return -1


func _apply_weapon(type: String) -> void:
	weapon = type
	fire_cooldown = 0.0
	is_reloading = false
	reload_timer = 0.0
	spread_accum = 0.0
	if current_weapon_index < inventory.size():
		visual_clip_count = float(inventory[current_weapon_index][2])
	match type:
		"smg":
			gun_sprite.texture = SMG_TEXTURE
			shoot_sound.stream = _smg_sound
		"shotgun":
			gun_sprite.texture = _shotgun_texture
			shoot_sound.stream = _shotgun_shoot
		"minigun":
			gun_sprite.texture = _minigun_texture
			shoot_sound.stream = _minigun_shoot
		"sniper":
			gun_sprite.texture = _sniper_texture
			shoot_sound.stream = _sniper_shoot
		"missile":
			gun_sprite.texture = _missile_texture
			shoot_sound.stream = _missile_launch
		_:
			gun_sprite.texture = _pistol_texture
			shoot_sound.stream = _pistol_shoot


func _broadcast_weapon() -> void:
	weapon_changed.emit(inventory, current_weapon_index, _slot_cooldowns)


func heal(amount := 1) -> void:
	health = mini(health + amount, max_health)
	update_health_display()


func increase_max_health() -> void:
	max_health += 1
	health = mini(health + 1, max_health)
	update_health_display()


func take_damage(enemy_collider: Node2D = null) -> void:
	if invincible:
		return
	
	# Reset damage-free survival timer
	time_without_damage = 0.0
		
	# 1. Passive Shield check
	if passive_shield > 0:
		passive_shield -= 1
		passive_shield_recharge_timer = 15.0 # recharge cooldown
		var block_sound := AudioStreamPlayer.new()
		block_sound.bus = "Priority"
		block_sound.stream = preload("res://assets/sounds/lock_on.wav")
		block_sound.pitch_scale = 0.6
		block_sound.volume_db = 2.0
		add_child(block_sound)
		block_sound.play()
		block_sound.finished.connect(block_sound.queue_free)
		
		# Shield deflection knockback / bump enemies
		if enemy_collider and is_instance_valid(enemy_collider) and not enemy_collider.get("dying"):
			var kb_dir: Vector2 = (enemy_collider.global_position - global_position).normalized()
			if kb_dir.length() < 0.01:
				kb_dir = Vector2.UP
			enemy_collider.knockback_velocity = kb_dir * 550.0
			
		# Shield shockwave radial bump to other nearby enemies
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(enemy) and not enemy.dying and enemy != enemy_collider:
				var dist := global_position.distance_to(enemy.global_position)
				if dist < 70.0:
					var kb_dir: Vector2 = (enemy.global_position - global_position).normalized()
					if kb_dir.length() < 0.01:
						kb_dir = Vector2.UP
					enemy.knockback_velocity = kb_dir * 350.0
		
		# Flash blue instead of red
		invincible = true
		damage_wobble_time = 0.4
		modulate = Color(0.3, 0.6, 1.0)
		post_proc_aberration = 0.04
		post_proc_distortion = 0.1
		await get_tree().create_timer(0.35).timeout
		if not is_queued_for_deletion():
			modulate = Color.WHITE
			invincible = false
		return

	# 2. Toughness passive (35% chance to block damage entirely)
	if passive_toughness > 0 and randf() < 0.35:
		var block_sound := AudioStreamPlayer.new()
		block_sound.bus = "Priority"
		block_sound.stream = preload("res://assets/sounds/drum_tick.wav")
		block_sound.pitch_scale = 1.8
		add_child(block_sound)
		block_sound.play()
		block_sound.finished.connect(block_sound.queue_free)
		
		invincible = true
		modulate = Color(0.8, 0.8, 0.8)
		await get_tree().create_timer(0.25).timeout
		if not is_queued_for_deletion():
			modulate = Color.WHITE
			invincible = false
		return

	health -= 1
	update_health_display()
	$HurtSound.play()
	
	# Trigger strong hit stop on player damage
	var main = get_tree().current_scene
	if main and main.has_method("trigger_hit_stop"):
		main.trigger_hit_stop(0.16, 0.03, global_position)
		
	post_proc_aberration = 0.08
	post_proc_distortion = -0.22
	if health <= 0:
		died.emit()
		queue_free()
		return
	invincible = true
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and not enemy.dying:
			var epos: Vector2 = (enemy as Node2D).global_position
			var kb_dir: Vector2 = (epos - global_position).normalized()
			enemy.knockback_velocity = kb_dir * 400.0
	damage_wobble_time = 0.65
	modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.5).timeout
	if not is_queued_for_deletion():
		modulate = Color.WHITE
		invincible = false


func update_health_display() -> void:
	var main: Node = get_tree().current_scene
	if main and main.has_node("HUD"):
		main.get_node("HUD").update_health(health, max_health)


func spawn_ammo_popup() -> void:
	var label := Label.new()
	label.text = "+AMMO"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	
	var color := Color(0.1, 0.9, 1.0) # Neon cyan
	label.modulate = color
	label.pivot_offset = Vector2(50, 15)
	label.position = global_position + Vector2(randf_range(-20, 20), -40)
	label.scale = Vector2(0.1, 0.1)
	if get_parent():
		get_parent().add_child(label)
	else:
		label.queue_free()
		return
	
	var tween := label.create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.45).set_trans(Tween.TRANS_ELASTIC)
	
	var drift := randf_range(-20, 20)
	tween.tween_property(label, "position", label.position + Vector2(drift, -70), 0.75).set_trans(Tween.TRANS_QUAD)
	
	var fade_tween := label.create_tween().set_ease(Tween.EASE_IN)
	fade_tween.tween_interval(0.4)
	fade_tween.tween_property(label, "modulate:a", 0.0, 0.35)
	fade_tween.finished.connect(label.queue_free)


func play_ammo_pickup_sound() -> void:
	var player_sp := AudioStreamPlayer.new()
	player_sp.bus = "Standard"
	player_sp.stream = preload("res://assets/sounds/weapon_switch.wav")
	player_sp.volume_db = -6.0
	if get_parent():
		get_parent().add_child(player_sp)
	else:
		player_sp.queue_free()
	player_sp.play()
	player_sp.finished.connect(player_sp.queue_free)


func record_kill(weapon_name: String) -> void:
	total_kills += 1
	if weapon_name not in weapon_kills:
		weapon_kills[weapon_name] = 0
	weapon_kills[weapon_name] += 1


func unlock_weapon(weapon_name: String) -> void:
	if weapon_unlocks.get(weapon_name, false):
		return
	weapon_unlocks[weapon_name] = true
	add_weapon(weapon_name)
	
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_node("HUD"):
		var hud = main_scene.get_node("HUD")
		if hud.has_method("show_unlock_notification"):
			hud.show_unlock_notification(weapon_name)


func unlock_passive(passive_name: String) -> void:
	if passive_unlocks.get(passive_name, false):
		return
	passive_unlocks[passive_name] = true
	
	# Apply passive effect immediately
	match passive_name:
		"shield":
			passive_shield_max = mini(passive_shield_max + 1, 3)
			passive_shield = passive_shield_max
		"speed_loader":
			passive_speed_loader = 0.70
		"golden_touch":
			passive_golden_touch = true
		"magnet_ring":
			passive_magnet_ring = 2.2
		"toughness":
			passive_toughness = 1
		"damage_boost":
			passive_damage_boost = 1.35
			
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_node("HUD"):
		var hud = main_scene.get_node("HUD")
		if hud.has_method("show_unlock_notification"):
			hud.show_unlock_notification(passive_name)


func _check_milestone_announcements() -> void:
	var milestones = {
		"shotgun": {"val": weapon_kills.get("pistol", 0), "target": 100, "name": "Shotgun (Weapon)"},
		"smg": {"val": weapon_kills.get("shotgun", 0), "target": 100, "name": "SMG (Weapon)"},
		"minigun": {"val": weapon_kills.get("smg", 0), "target": 150, "name": "Minigun (Weapon)"},
		"sniper": {"val": time_without_damage, "target": 300.0, "name": "Sniper Rifle (Weapon)"},
		"missile": {"val": weapon_kills.get("sniper", 0), "target": 50, "name": "Missile Launcher (Weapon)"},
		"shield": {"val": run_survival_time, "target": 120.0, "name": "Shield (Passive)"},
		"speed_loader": {"val": total_bullets_fired, "target": 1000, "name": "Speed Loader (Passive)"},
		"golden_touch": {"val": total_coins_collected, "target": 500, "name": "Golden Touch (Passive)"},
		"magnet_ring": {"val": total_items_collected, "target": 100, "name": "Magnet Ring (Passive)"},
		"toughness": {"val": total_kills, "target": 250, "name": "Toughness (Passive)"},
		"damage_boost": {"val": peak_combo, "target": 10, "name": "Damage Boost (Passive)"}
	}

	for key in milestones:
		var m = milestones[key]
		if m["val"] >= m["target"]:
			var is_purchased = false
			if key in weapon_unlocks:
				is_purchased = weapon_unlocks[key]
			else:
				is_purchased = passive_unlocks.get(key, false)
				
			if not is_purchased and not key in announced_milestones:
				announced_milestones.append(key)
				var main_scene = get_tree().current_scene
				if main_scene and main_scene.has_node("HUD"):
					var hud = main_scene.get_node("HUD")
					if hud.has_method("show_milestone_completed_notification"):
						hud.show_milestone_completed_notification(m["name"])


func _spawn_shell_casing() -> void:
	var shell_script := load("res://scripts/shell_casing.gd")
	if not shell_script:
		return
		
	var shell = Node2D.new()
	shell.set_script(shell_script)
	
	# Position at the gun pivot, offset slightly backward and upward
	var aim_dir := Vector2.RIGHT.rotated(gun_pivot.rotation)
	var ejection_offset := -aim_dir * 8.0 + aim_dir.orthogonal() * -3.0
	shell.global_position = gun_pivot.global_position + ejection_offset
	
	# Eject mostly upwards and backwards
	var backward_dir := -aim_dir
	var eject_dir := (backward_dir * randf_range(0.3, 0.6) + Vector2.UP * randf_range(0.8, 1.3)).normalized()
	var eject_speed := randf_range(110.0, 160.0)
	
	shell.velocity = eject_dir * eject_speed
	shell.floor_y = global_position.y + randf_range(5.0, 14.0)
	
	# Add to main scene so it stays stationary on the ground
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(shell)
	else:
		shell.queue_free()


func _spawn_ui_reload_particles() -> void:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.amount = 16
	p.lifetime = 0.28
	p.one_shot = true
	p.explosiveness = 0.95
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 75.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.92, 0.45, 0.95)) # Bright gold
	g.set_color(1, Color(1.0, 0.42, 0.12, 0.0))  # Intense orange fade
	p.color_ramp = g
	
	# Centered on active reload bar
	p.position = Vector2(0, 39.0)
	
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
