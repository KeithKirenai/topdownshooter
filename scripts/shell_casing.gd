extends Node2D

var velocity := Vector2.ZERO
var gravity := 450.0
var rot_speed := 0.0
var floor_y := 0.0
var landed := false
var age := 0.0

func _ready() -> void:
	add_to_group("shell_casings")
	# Maintain performance by capping total casings on the floor
	var casings = get_tree().get_nodes_in_group("shell_casings")
	if casings.size() > 120:
		var oldest = casings[0]
		if is_instance_valid(oldest):
			oldest.queue_free()
		
	rot_speed = randf_range(-18.0, 18.0)

func _physics_process(delta: float) -> void:
	if landed:
		# Slowly fade out after staying on the floor for 12 seconds
		age += delta
		if age > 12.0:
			modulate.a = move_toward(modulate.a, 0.0, delta * 0.5)
			if modulate.a <= 0.0:
				queue_free()
		return
		
	# Physics simulation
	velocity.y += gravity * delta
	position += velocity * delta
	rotation += rot_speed * delta
	
	# Land on virtual floor
	if position.y >= floor_y:
		position.y = floor_y
		landed = true
		_play_tink_sound()

func _play_tink_sound() -> void:
	var ap := AudioStreamPlayer2D.new()
	# Load and highly pitch up drum_tick.wav to sound like a brass casing clinking
	ap.stream = load("res://assets/sounds/drum_tick.wav")
	ap.volume_db = -26.0
	ap.pitch_scale = randf_range(2.8, 3.5)
	ap.global_position = global_position
	if get_parent():
		get_parent().add_child(ap)
		ap.play()
		ap.finished.connect(ap.queue_free)
	else:
		ap.queue_free()

func _draw() -> void:
	# Brass shell casing rectangle (3x1.5 pixels)
	draw_rect(Rect2(-1.5, -0.75, 3.0, 1.5), Color(0.86, 0.65, 0.12))
	# Highlight stripe
	draw_rect(Rect2(-1.5, -0.75, 2.0, 0.75), Color(1.0, 0.92, 0.50))
