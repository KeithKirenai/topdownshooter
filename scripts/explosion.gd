extends Area2D

const DAMAGE := 15


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$AudioStreamPlayer2D.play()
	
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		if "shake_intensity" in p:
			p.shake_intensity = clampf(p.shake_intensity + 7.5, 0.0, 18.0)

	$Sprite2D.scale = Vector2.ZERO
	$Sprite2D.modulate.a = 1.0
	var tween := create_tween().set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property($Sprite2D, "scale", Vector2(8, 8), 0.15)
	tween.tween_property($Sprite2D, "modulate:a", 0.0, 0.25).set_delay(0.1)
	for body in get_overlapping_bodies():
		_on_body_entered(body)
	await tween.finished
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemy"):
		return
	if body.has_method("take_damage"):
		body.take_damage(DAMAGE)
	if body.has_method("knockback"):
		var kb_dir: Vector2 = (body.global_position - global_position).normalized()
		body.knockback_velocity = kb_dir * 600.0
