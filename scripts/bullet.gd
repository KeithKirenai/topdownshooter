extends Area2D

const SPEED := 500.0
const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")
const KNOCKBACK_FORCE := 500.0
const ENEMY_KNOCKBACK_PERCENT := 0.5

var direction := Vector2.RIGHT
var penetrate := false
var explosive := false
var hit_enemies: Array = []
var bullet_type := "pistol"
var damage := 1
var time_accum: float = 0.0

var trail_points: Array[Vector2] = []
var trail_line: Line2D
const MAX_TRAIL_POINTS := 7

var _bullet_textures := {
	"pistol": preload("res://assets/sprites/bullet_pistol.png"),
	"smg": preload("res://assets/sprites/bullet_smg.png"),
	"shotgun": preload("res://assets/sprites/bullet_shotgun.png"),
	"minigun": preload("res://assets/sprites/bullet_minigun.png"),
	"sniper": preload("res://assets/sprites/bullet_sniper.png"),
	"missile": preload("res://assets/sprites/bullet_missile.png"),
}

var _bullet_scales := {
	"pistol": Vector2(1.2, 1.2),
	"smg": Vector2(1.5, 1.5),
	"shotgun": Vector2(1.6, 1.6),
	"minigun": Vector2(1.1, 1.1),
	"sniper": Vector2(1.8, 1.2),
	"missile": Vector2(2.2, 2.2),
}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)
	get_tree().create_timer(3.0).timeout.connect(queue_free)
	$Sprite2D.texture = _bullet_textures.get(bullet_type, _bullet_textures["pistol"])
	rotation = direction.angle()
	scale = _bullet_scales.get(bullet_type, Vector2(1.0, 1.0))
	if bullet_type == "missile":
		$Trail.show()
		
	# Attach colored glowing light source
	var main = get_tree().current_scene
	if main and main.has_method("get_radial_light_texture"):
		var light := PointLight2D.new()
		light.texture = main.get_radial_light_texture()
		light.texture_scale = 1.3
		var col := Color(0.5, 0.8, 1.0)
		match bullet_type:
			"pistol":
				col = Color(0.3, 0.7, 1.0)
			"smg":
				col = Color(0.2, 0.9, 0.4)
			"shotgun":
				col = Color(1.0, 0.55, 0.15)
			"minigun":
				col = Color(1.0, 0.85, 0.2)
			"sniper":
				col = Color(0.8, 0.25, 1.0)
			"missile":
				col = Color(1.0, 0.2, 0.1)
		light.color = col
		light.energy = 0.7
		add_child(light)
		
	# Initialize glowing motion trail Line2D (Secret Sauce: Motion Trails)
	trail_line = Line2D.new()
	trail_line.width = 2.8
	trail_line.top_level = true
	
	var trail_col := Color(0.5, 0.8, 1.0)
	match bullet_type:
		"pistol":
			trail_col = Color(0.3, 0.7, 1.0, 0.5)
		"smg":
			trail_col = Color(0.2, 0.9, 0.4, 0.5)
		"shotgun":
			trail_col = Color(1.0, 0.55, 0.15, 0.5)
		"minigun":
			trail_col = Color(1.0, 0.85, 0.2, 0.5)
		"sniper":
			trail_col = Color(0.8, 0.25, 1.0, 0.6)
		"missile":
			trail_col = Color(1.0, 0.2, 0.1, 0.6)
			
	var grad := Gradient.new()
	grad.set_color(0, Color(trail_col.r, trail_col.g, trail_col.b, 0.0))
	grad.set_color(1, trail_col)
	trail_line.gradient = grad
	add_child(trail_line)


func _physics_process(delta: float) -> void:
	# Track bullet position history in world space for the trail
	trail_points.append(global_position)
	if trail_points.size() > MAX_TRAIL_POINTS:
		trail_points.pop_front()
		
	if trail_line:
		trail_line.clear_points()
		for pt in trail_points:
			trail_line.add_point(pt)

	global_position += direction * SPEED * delta
	time_accum += delta
	var wave := sin(time_accum * 40.0) * 0.15
	$Sprite2D.scale.x = 1.0 + wave
	$Sprite2D.scale.y = 1.0 - wave


const HITMARKER_SOUND = preload("res://assets/sounds/hitmarker.wav")

func _on_body_entered(body: Node2D) -> void:
	if explosive:
		var pos := global_position
		call_deferred("_spawn_explosion", pos)
		queue_free()
		return

	if body.is_in_group("enemy"):
		# Play professional layered hit sound in main
		var main = get_tree().current_scene
		if main and main.has_method("play_layered_hit"):
			main.play_layered_hit(global_position, bullet_type in ["sniper", "missile"])

		hit_enemies.append(body)
		if body.has_method("take_damage"):
			body.take_damage(damage, bullet_type)
		var target_velocity = (body.global_position - global_position).normalized() * KNOCKBACK_FORCE
		if bullet_type == "sniper":
			body.knockback_velocity = target_velocity * 0.2
		else:
			body.knockback_velocity = target_velocity * ENEMY_KNOCKBACK_PERCENT
		
		# Increase combo when hitting an enemy
		if main and main.has_method("increment_combo_on_hit"):
			main.increment_combo_on_hit()
			
		# Spawn bright hit sparks flying opposite of bullet trajectory
		spawn_sparks(global_position, -direction)
		
		if not penetrate:
			queue_free()
	elif not penetrate:
		queue_free()


func _spawn_explosion(pos: Vector2) -> void:
	var explosion_instance := EXPLOSION_SCENE.instantiate()
	explosion_instance.global_position = pos
	if "source_weapon" in explosion_instance:
		explosion_instance.source_weapon = bullet_type
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(explosion_instance)
	else:
		explosion_instance.queue_free()


func spawn_sparks(pos: Vector2, spark_dir: Vector2) -> void:
	var parts := CPUParticles2D.new()
	parts.emitting = false
	parts.amount = 8
	parts.lifetime = 0.22
	parts.one_shot = true
	parts.explosiveness = 0.95
	parts.spread = 32.0
	parts.gravity = Vector2.ZERO
	parts.initial_velocity_min = 90.0
	parts.initial_velocity_max = 200.0
	parts.scale_amount_min = 1.8
	parts.scale_amount_max = 3.6
	
	# Match color to bullet type
	var col := Color(1.0, 0.7, 0.2)
	match bullet_type:
		"pistol":
			col = Color(0.4, 0.8, 1.0)
		"smg":
			col = Color(0.3, 1.0, 0.5)
		"shotgun":
			col = Color(1.0, 0.6, 0.2)
		"minigun":
			col = Color(1.0, 0.9, 0.3)
		"sniper":
			col = Color(0.85, 0.3, 1.0)
		"missile":
			col = Color(1.0, 0.3, 0.1)
			
	parts.color = col
	var ramp = Gradient.new()
	ramp.set_color(0, col)
	ramp.set_color(1, Color(col.r, col.g, col.b, 0.0))
	parts.color_ramp = ramp
	
	parts.global_position = pos
	parts.direction = spark_dir
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(parts)
		parts.emitting = true
		parts.finished.connect(parts.queue_free)
	else:
		parts.queue_free()
