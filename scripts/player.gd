extends CharacterBody2D

const SPEED = 150.0
const BULLET_SCENE = preload("res://scenes/bullet.tscn")
const JOYSTICK_DEADZONE := 0.15
const ANIM_SPEED := 0.12
const MAGNET_SPEED = 400.0
const MAGNET_RANGE = 120.0

const WEAPON_DATA := {
	"pistol": { "fire_rate": 0.4, "spread": 0.0, "bullets": 1, "penetrate": false, "explosive": false, "ammo_max": -1, "damage": 4, "bullet_type": "pistol", "reload_time": 0.0, "recoil": 0.0 },
	"smg": { "fire_rate": 0.12, "spread": 0.05, "bullets": 1, "penetrate": false, "explosive": false, "ammo_max": 120, "damage": 2, "bullet_type": "smg", "reload_time": 0.0, "recoil": 20.0 },
	"shotgun": { "fire_rate": 0.8, "spread": 0.3, "bullets": 8, "penetrate": false, "explosive": false, "ammo_max": 30, "damage": 1, "bullet_type": "shotgun", "reload_time": 0.0, "recoil": 80.0 },
	"minigun": { "fire_rate": 0.05, "spread": 0.1, "bullets": 1, "penetrate": false, "explosive": false, "ammo_max": 200, "damage": 1, "bullet_type": "minigun", "reload_time": 0.0, "recoil": 15.0 },
	"sniper": { "fire_rate": 1.2, "spread": 0.0, "bullets": 1, "penetrate": true, "explosive": false, "ammo_max": 5, "damage": 30, "bullet_type": "sniper", "reload_time": 0.0, "recoil": 45.0 },
	"missile": { "fire_rate": 1.2, "spread": 0.0, "bullets": 1, "penetrate": false, "explosive": true, "ammo_max": 8, "damage": 5, "bullet_type": "missile", "reload_time": 0.0, "recoil": 60.0 },
}

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
var inventory: Array = [["pistol", -1]]
var current_weapon_index := 0
var has_laser_sight := false
var frozen := false
var muzzle_flash_time := 0.0
var shake_intensity: float = 0.0
var shake_decay: float = 16.0
var _weapon_shakes := {
	"pistol": 1.5,
	"smg": 1.0,
	"shotgun": 6.5,
	"minigun": 1.3,
	"sniper": 9.0,
	"missile": 11.0,
}
var _weapon_scales := {
	"pistol": Vector2(1.6, 1.6),
	"smg": Vector2(2.0, 2.0),
	"shotgun": Vector2(2.2, 2.2),
	"minigun": Vector2(2.5, 2.5),
	"sniper": Vector2(2.5, 2.2),
	"missile": Vector2(2.6, 2.6),
}

var is_reloading := false
var reload_timer := 0.0
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

# Per-slot cooldown tracking: { slot_index: { current: float, max: float } }
var _slot_cooldowns: Dictionary = {}
var _walk_step_timer: float = 0.0
const WALK_STEP_INTERVAL := 0.30

var locked_enemy: Node2D = null
var post_proc_aberration: float = 0.0
var post_proc_distortion: float = 0.05

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
	# Attach walk step player
	var walk_sp := AudioStreamPlayer.new()
	walk_sp.name = "WalkStepSound"
	walk_sp.volume_db = -4.0
	walk_sp.bus = "Master"
	var wstream = load("res://assets/sounds/walk_step.wav")
	if wstream:
		walk_sp.stream = wstream
	add_child(walk_sp)

	# Attach lock on sound player
	var lock_sp := AudioStreamPlayer.new()
	lock_sp.name = "LockOnSound"
	lock_sp.volume_db = -6.0
	lock_sp.bus = "Master"
	var lstream = load("res://assets/sounds/lock_on.wav")
	if lstream:
		lock_sp.stream = lstream
	add_child(lock_sp)


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
		var slot := _key_to_slot(event.keycode)
		if slot >= 0:
			select_slot(slot)


func _process(delta: float) -> void:
	if shake_intensity > 0.0:
		camera.offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		shake_intensity = move_toward(shake_intensity, 0.0, shake_decay * delta)
	else:
		camera.offset = Vector2.ZERO

	# Decay post-processing shader effects
	post_proc_aberration = move_toward(post_proc_aberration, 0.0, 0.25 * delta)
	post_proc_distortion = move_toward(post_proc_distortion, 0.05, 0.45 * delta)
	
	# Apply to ScreenEffects shader material
	var main: Node = get_tree().current_scene
	if main and main.has_node("ScreenEffects"):
		var se = main.get_node("ScreenEffects") as ColorRect
		if se and se.material:
			se.material.set_shader_parameter("chromatic_aberration", post_proc_aberration)
			se.material.set_shader_parameter("distortion", post_proc_distortion)

	if _menu_open():
		return
	var aim_dir := get_aim_direction()
	if aim_dir.length() > 0.01:
		gun_pivot.rotation = aim_dir.angle()
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

	if is_reloading:
		reload_timer -= delta
		reload_ticking.emit(max(0.0, reload_timer))
		if reload_timer <= 0.0:
			_finish_reload()
		return

	var data = WEAPON_DATA.get(weapon, WEAPON_DATA["pistol"])
	if data["fire_rate"] < 0.3:
		if Input.is_action_pressed("shoot") and fire_cooldown <= 0.0:
			_shoot_weapon(data)
			fire_cooldown = data["fire_rate"]
	elif Input.is_action_just_pressed("shoot") and fire_cooldown <= 0.0:
		_shoot_weapon(data)
		fire_cooldown = data["fire_rate"]

	spread_decay_timer -= delta
	if spread_decay_timer <= 0.0:
		spread_accum = max(0.0, spread_accum - delta * 0.5)

	if recoil_velocity.length() > 0.0:
		recoil_velocity = recoil_velocity.move_toward(Vector2.ZERO, 600.0 * delta)

	muzzle_flash_time = max(0.0, muzzle_flash_time - delta)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if _menu_open():
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * SPEED + recoil_velocity
	move_and_slide()
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider and collider.is_in_group("enemy") and not collider.get("dying"):
			take_damage()


func pull_coins(delta: float) -> void:
	for coin in get_tree().get_nodes_in_group("coins"):
		if not is_instance_valid(coin):
			continue
		var dir = global_position - coin.global_position
		var dist = dir.length()
		if dist > MAGNET_RANGE or dist < 5:
			continue
		coin.global_position += dir.normalized() * MAGNET_SPEED * delta


func get_aim_direction() -> Vector2:
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


func _shoot_weapon(data: Dictionary) -> void:
	if is_reloading:
		return

	var ammo_idx := current_weapon_index
	var ammo = inventory[ammo_idx][1]
	if ammo != -1:
		if ammo <= 0:
			var click_sp := get_node_or_null("LockOnSound") as AudioStreamPlayer
			if click_sp:
				click_sp.pitch_scale = 2.0
				click_sp.play()
			return
		inventory[ammo_idx][1] = ammo - 1
	if not $GunPivot/Muzzle:
		return
	var base_dir := Vector2.RIGHT.rotated(gun_pivot.rotation)
	var used_spread = data["spread"] + spread_accum
	if weapon == "minigun":
		spread_accum = min(spread_accum + 0.02, 0.35)
		spread_decay_timer = 0.3
	for i in range(data["bullets"]):
		var bullet := BULLET_SCENE.instantiate()
		bullet.global_position = get_muzzle_global_position()
		var spread := randf_range(-used_spread, used_spread)
		bullet.direction = base_dir.rotated(spread)
		bullet.penetrate = data["penetrate"]
		bullet.explosive = data["explosive"]
		bullet.bullet_type = data["bullet_type"]
		bullet.damage = data["damage"]
		get_tree().current_scene.add_child(bullet)
		shoot_sound.play()
	var amt: float = _weapon_shakes.get(weapon, 1.5)
	shake_intensity = clampf(shake_intensity + amt, 0.0, 15.0)

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

	# Track per-slot cooldown for current weapon
	var max_cd: float = data["fire_rate"]
	_slot_cooldowns[current_weapon_index] = { "current": max_cd, "max": max_cd }

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
	if data["reload_time"] > 0.0:
		_start_reload(data["reload_time"])
	muzzle_flash_time = 0.07
	_broadcast_weapon()


func _start_reload(duration: float) -> void:
	is_reloading = true
	reload_timer = duration
	$SniperReloadSound.play()
	reload_started.emit(duration)


func _finish_reload() -> void:
	is_reloading = false
	reload_timer = 0.0
	var data = WEAPON_DATA.get(weapon, WEAPON_DATA["pistol"])
	var ammo_max = data["ammo_max"]
	if ammo_max != -1 and current_weapon_index < inventory.size():
		inventory[current_weapon_index][1] = ammo_max
	reload_finished.emit()
	_broadcast_weapon()


func _cancel_reload() -> void:
	if is_reloading:
		is_reloading = false
		reload_timer = 0.0
		$SniperReloadSound.stop()
		reload_finished.emit()


func update_laser(_delta: float, _aim_dir: Vector2) -> void:
	if laser:
		laser.hide()


func _draw() -> void:
	var aim_dir := get_aim_direction()
	var muzzle_pos := get_muzzle_local_position()

	# Draw lock-on visuals if target is active
	if is_instance_valid(locked_enemy) and not locked_enemy.get("dying") and not _menu_open():
		var to_enemy_local: Vector2 = locked_enemy.global_position - global_position
		
		# Draw a bright orange/red target dotted line directly to the enemy's center
		var current_dist := 0.0
		var line_vec: Vector2 = to_enemy_local - muzzle_pos
		var line_vec_len: float = line_vec.length()
		var line_vec_dir: Vector2 = line_vec.normalized()
		var dot_length := 4.0
		var gap_length := 6.0
		var color_line := Color(1.0, 0.4, 0.0, 0.8) # Bright orange/red
		
		while current_dist < line_vec_len:
			var p1 = muzzle_pos + line_vec_dir * current_dist
			var p2 = muzzle_pos + line_vec_dir * min(current_dist + dot_length, line_vec_len)
			draw_line(p1, p2, color_line, 2.0)
			current_dist += dot_length + gap_length
			
		# Draw a wiggling circular crosshair reticle with 4 outer bracket lines surrounding the locked enemy
		var time_scale = Time.get_ticks_msec() * 0.005
		var wiggle := sin(time_scale) * 2.0
		var radius := 24.0 + wiggle
		
		var enemy_pos: Vector2 = to_enemy_local
		var bracket_len := 8.0
		var bracket_color := Color(1.0, 0.2, 0.1, 0.9)
		
		# Top-Left Bracket
		draw_line(enemy_pos + Vector2(-radius, -radius), enemy_pos + Vector2(-radius + bracket_len, -radius), bracket_color, 2.0)
		draw_line(enemy_pos + Vector2(-radius, -radius), enemy_pos + Vector2(-radius, -radius + bracket_len), bracket_color, 2.0)
		
		# Top-Right Bracket
		draw_line(enemy_pos + Vector2(radius, -radius), enemy_pos + Vector2(radius - bracket_len, -radius), bracket_color, 2.0)
		draw_line(enemy_pos + Vector2(radius, -radius), enemy_pos + Vector2(radius, -radius + bracket_len), bracket_color, 2.0)
		
		# Bottom-Left Bracket
		draw_line(enemy_pos + Vector2(-radius, radius), enemy_pos + Vector2(-radius + bracket_len, radius), bracket_color, 2.0)
		draw_line(enemy_pos + Vector2(-radius, radius), enemy_pos + Vector2(-radius, radius - bracket_len), bracket_color, 2.0)
		
		# Bottom-Right Bracket
		draw_line(enemy_pos + Vector2(radius, radius), enemy_pos + Vector2(radius - bracket_len, radius), bracket_color, 2.0)
		draw_line(enemy_pos + Vector2(radius, radius), enemy_pos + Vector2(radius, radius - bracket_len), bracket_color, 2.0)
		
		# Inner circle and center dot
		draw_arc(enemy_pos, radius - 4.0, 0.0, TAU, 32, bracket_color, 1.5, true)
		draw_circle(enemy_pos, 2.0, bracket_color)

	if aim_dir.length() > 0.01 and not _menu_open():
		var line_length := 300.0
		var dot_length := 4.0
		var gap_length := 6.0
		var current_dist := 0.0
		var color := Color(1.0, 1.0, 1.0, 0.4) # Semi-transparent white dotted line
		
		# Draw the dots
		while current_dist < line_length:
			var p1 = muzzle_pos + aim_dir * current_dist
			var p2 = muzzle_pos + aim_dir * min(current_dist + dot_length, line_length)
			draw_line(p1, p2, color, 1.5)
			current_dist += dot_length + gap_length

	if muzzle_flash_time > 0.0 and not _menu_open():
		var flash_size := 14.0
		match weapon:
			"pistol": flash_size = 18.0
			"smg": flash_size = 20.0
			"shotgun": flash_size = 38.0
			"minigun": flash_size = 22.0
			"sniper": flash_size = 34.0
			"missile": flash_size = 44.0
			
		# Draw outer spiked halo with transparency
		var outer_points := PackedVector2Array()
		var num_spikes := 10
		for i in range(num_spikes * 2):
			var angle := float(i) * PI / float(num_spikes)
			var r := (flash_size * 1.3) if i % 2 == 0 else (flash_size * 0.3)
			r *= randf_range(0.8, 1.2)
			outer_points.append(muzzle_pos + Vector2(cos(angle), sin(angle)) * r)
		draw_colored_polygon(outer_points, Color(1.0, 0.3, 0.0, 0.4)) # Outer faint fire glow

		# Draw primary orange cartoon star
		var star_points := PackedVector2Array()
		for i in range(num_spikes * 2):
			var angle := float(i) * PI / float(num_spikes)
			var r := flash_size if i % 2 == 0 else (flash_size * 0.45)
			r *= randf_range(0.9, 1.1)
			star_points.append(muzzle_pos + Vector2(cos(angle), sin(angle)) * r)
		draw_colored_polygon(star_points, Color(1.0, 0.6, 0.0, 0.95)) # Vibrant orange-red spark base
		
		# Draw inner bright yellow core
		var core_points := PackedVector2Array()
		for i in range(num_spikes * 2):
			var angle := float(i) * PI / float(num_spikes)
			var r := (flash_size * 0.55) if i % 2 == 0 else (flash_size * 0.25)
			core_points.append(muzzle_pos + Vector2(cos(angle), sin(angle)) * r)
		draw_colored_polygon(core_points, Color(1.0, 0.98, 0.7, 0.98)) # Bright creamy yellow center
		
		# Draw extra funny cartoon sparks popping off
		for s in range(4):
			var spark_angle := randf_range(0, TAU)
			var spark_dist := randf_range(flash_size * 0.8, flash_size * 1.5)
			var spark_pos := muzzle_pos + Vector2(cos(spark_angle), sin(spark_angle)) * spark_dist
			var spark_r := randf_range(2.0, 4.0)
			draw_circle(spark_pos, spark_r, Color(1.0, 0.8, 0.1, 0.9))




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
	var max_ammo = WEAPON_DATA.get(type, WEAPON_DATA["pistol"])["ammo_max"]
	inventory.append([type, max_ammo])
	_broadcast_weapon()


func refill_ammo(percent: float = 1.0) -> void:
	for entry in inventory:
		var weapon_name := entry[0] as String
		if weapon_name == "pistol":
			continue
		var max_ammo = WEAPON_DATA.get(weapon_name, WEAPON_DATA["pistol"])["ammo_max"]
		if percent >= 1.0:
			entry[1] = max_ammo
		else:
			entry[1] = mini(entry[1] + int(ceil(max_ammo * percent)), max_ammo)
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


func take_damage() -> void:
	if invincible:
		return
	health -= 1
	update_health_display()
	$HurtSound.play()
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
	get_parent().add_child(label)
	
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
	player_sp.stream = preload("res://assets/sounds/weapon_switch.wav")
	player_sp.volume_db = -6.0
	get_parent().add_child(player_sp)
	player_sp.play()
	player_sp.finished.connect(player_sp.queue_free)
