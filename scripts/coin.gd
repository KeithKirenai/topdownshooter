extends Area2D

const SPIN_SPEED := 3.0
const LIFETIME := 10.0

@onready var despawn_timer := $DespawnTimer

var score_value := 5


var time_accum: float = 0.0
var _base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_base_scale = $Sprite2D.scale
	time_accum = randf_range(0.0, 10.0)
	add_to_group("coins")
	body_entered.connect(_on_body_entered)
	despawn_timer.start(LIFETIME)


func _process(delta: float) -> void:
	time_accum += delta
	rotation += delta * SPIN_SPEED
	$Sprite2D.position.y = sin(time_accum * 5.0) * 3.0
	$Sprite2D.scale.x = _base_scale.x * (1.0 + sin(time_accum * 8.0) * 0.15)
	$Sprite2D.scale.y = _base_scale.y * (1.0 + cos(time_accum * 8.0) * 0.15)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	$PickupSound.play()
	var main: Node = get_tree().current_scene
	if main and main.has_method("add_score"):
		main.add_score(score_value)
	$Sprite2D.hide()
	$CollisionShape2D.set_deferred("disabled", true)
	await $PickupSound.finished
	queue_free()


func _on_despawn_timer_timeout() -> void:
	queue_free()
