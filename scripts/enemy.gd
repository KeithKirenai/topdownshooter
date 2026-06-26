extends CharacterBody2D

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

signal killed


func _ready() -> void:
	add_to_group("enemy")
	_base_sprite_scale = sprite.scale
	
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
	
	health = max_health
	
	health_label = Label.new()
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.add_theme_font_size_override("font_size", 24)
	health_label.scale = Vector2(0.3, 0.3)
	health_label.size = Vector2(166, 30)
	health_label.position = Vector2(-25, -28)
	add_child(health_label)
	update_health_label()


func _physics_process(delta: float) -> void:
	if dying:
		return
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * speed + knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500.0 * delta)
	update_animation(delta, dir)


func get_sprite_dir(dir: Vector2) -> int:
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
	walk_bounce_phase += delta * (speed / 50.0) * 16.0
	var rot_mod := sin(walk_bounce_phase) * deg_to_rad(10.0)
	var bounce_y := sin(walk_bounce_phase * 2.0) * 0.15
	var bounce_x := -bounce_y * 0.5
	
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
	sprite.rotation = rot_mod + hit_rot
	
	var scale_y_factor := (1.0 + bounce_y + hit_bounce_y)
	if scale_y_factor < 1.0:
		sprite.position.y = 8.0 * (1.0 - scale_y_factor)
	elif scale_y_factor > 1.0:
		sprite.position.y = -8.0 * (scale_y_factor - 1.0)
	else:
		sprite.position.y = 0.0


func take_damage(amount: int = 1) -> void:
	if dying:
		return
	health -= amount
	spawn_damage_number(amount)
	update_health_label()
	if health <= 0:
		die()
		return
	$HitSound.play()
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
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.4)
	tween.parallel().tween_property(self, "scale", Vector2.ZERO, 0.4)
	killed.emit()
	await tween.finished
	queue_free()


func spawn_coin() -> void:
	var r := randf()
	var pickup
	if r < 0.02:
		pickup = HEART_SCENE.instantiate()
	elif r < 0.15:
		pickup = AMMO_SCENE.instantiate()
	elif r < 0.30:
		pickup = COIN_SCENE.instantiate()
		pickup.score_value = 20
		pickup.modulate = Color(1, 0.85, 0.15, 1)
	else:
		pickup = COIN_SCENE.instantiate()
	pickup.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", pickup)


func _draw() -> void:
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
	get_parent().add_child(label)
	
	var tween := label.create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
	var target_scale = Vector2(0.8, 0.8) if amount < 15 else Vector2(1.2, 1.2)
	tween.tween_property(label, "scale", target_scale, 0.45).set_trans(Tween.TRANS_ELASTIC)
	
	var drift := randf_range(-30, 30)
	tween.tween_property(label, "position", label.position + Vector2(drift, -60), 0.75).set_trans(Tween.TRANS_QUAD)
	
	var fade_tween := label.create_tween().set_ease(Tween.EASE_IN)
	fade_tween.tween_interval(0.4)
	fade_tween.tween_property(label, "modulate:a", 0.0, 0.35)
	fade_tween.finished.connect(label.queue_free)
