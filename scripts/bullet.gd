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


func _physics_process(delta: float) -> void:
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
		var asp := AudioStreamPlayer.new()
		asp.stream = HITMARKER_SOUND
		asp.pitch_scale = randf_range(0.92, 1.08)
		asp.volume_db = -6.0
		get_tree().current_scene.add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)

		hit_enemies.append(body)
		if body.has_method("take_damage"):
			body.take_damage(damage)
		var target_velocity = (body.global_position - global_position).normalized() * KNOCKBACK_FORCE
		if bullet_type == "sniper":
			body.knockback_velocity = target_velocity * 0.2
		else:
			body.knockback_velocity = target_velocity * ENEMY_KNOCKBACK_PERCENT
		
		# Increase combo when hitting an enemy
		var main = get_tree().current_scene
		if main and main.has_method("increment_combo_on_hit"):
			main.increment_combo_on_hit()
		
		if not penetrate:
			queue_free()
	elif not penetrate:
		queue_free()


func _spawn_explosion(pos: Vector2) -> void:
	var explosion_instance := EXPLOSION_SCENE.instantiate()
	explosion_instance.global_position = pos
	get_tree().current_scene.add_child(explosion_instance)
