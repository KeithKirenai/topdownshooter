extends Area2D

const SPIN_SPEED := 3.0
const LIFETIME := 10.0

@onready var despawn_timer := $DespawnTimer

var time_accum: float = 0.0
var _base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_base_scale = $Sprite2D.scale
	time_accum = randf_range(0.0, 5.0)
	body_entered.connect(_on_body_entered)
	despawn_timer.start(LIFETIME)


func _process(delta: float) -> void:
	time_accum += delta
	$Sprite2D.position.y = sin(time_accum * 4.0) * 2.0
	$Sprite2D.scale = _base_scale * (1.0 + sin(time_accum * 6.0) * 0.1)
	$Sprite2D.rotation = sin(time_accum * 3.0) * deg_to_rad(8.0)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("refill_ammo"):
		body.refill_ammo(0.35) # refill 35% ammo for all weapons
	if "total_items_collected" in body:
		body.total_items_collected += 1
	$PickupSound.play()
	$Sprite2D.hide()
	$CollisionShape2D.set_deferred("disabled", true)
	await $PickupSound.finished
	queue_free()


func _on_despawn_timer_timeout() -> void:
	queue_free()
