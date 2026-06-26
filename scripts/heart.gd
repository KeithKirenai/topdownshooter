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
	$PickupSound.stream = create_heal_stream()
	$PickupSound.volume_db = -12.0


func _process(delta: float) -> void:
	time_accum += delta
	var period := 1.2
	var local_t := fmod(time_accum, period)
	var scale_factor := 1.0
	
	if local_t < 0.15:
		scale_factor = 1.0 + sin((local_t / 0.15) * PI) * 0.25
	elif local_t >= 0.15 and local_t < 0.3:
		scale_factor = 1.0 + sin(((local_t - 0.15) / 0.15) * PI) * 0.1
	else:
		scale_factor = 1.0
		
	$Sprite2D.position.y = sin(time_accum * 4.0) * 2.0
	$Sprite2D.scale = _base_scale * scale_factor
	$Sprite2D.rotation = sin(time_accum * 3.0) * deg_to_rad(8.0)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	$PickupSound.play()
	var main: Node = get_tree().current_scene
	if main:
		if main.has_method("heal_player"):
			main.heal_player()
	$Sprite2D.hide()
	$CollisionShape2D.set_deferred("disabled", true)
	await $PickupSound.finished
	queue_free()


func _on_despawn_timer_timeout() -> void:
	queue_free()


static func create_heal_stream() -> AudioStreamWAV:
	var sr := 22050
	var dur := 0.3
	var n := int(sr * dur)
	var data := PackedByteArray()
	data.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / n
		var freq := 523.25
		if t < 0.25:
			freq = 523.25
		elif t < 0.5:
			freq = 659.25
		elif t < 0.75:
			freq = 783.99
		else:
			freq = 1046.5
		phase += freq / sr
		var wave: float = sin(phase * TAU)
		var env := 1.0 - t * t
		data[i] = clampi(int((wave * env * 100.0) + 128.0), 0, 255)
	var s := AudioStreamWAV.new()
	s.data = data
	s.format = AudioStreamWAV.FORMAT_8_BITS
	s.mix_rate = sr
	return s
