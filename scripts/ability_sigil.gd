extends Control

@onready var sigil := $Sigil
@onready var anim := $AnimationPlayer

func _ready():
	# prepare default shader params
	if sigil.material and sigil.material is ShaderMaterial:
		sigil.material.set_shader_param("pulse", 0.0)
		sigil.material.set_shader_param("fill", 0.0)

func play_pulse():
	# quick expand pulse + fill animation
	if sigil.material and sigil.material is ShaderMaterial:
		if anim.has_animation("pulse_fill"):
			anim.remove_animation("pulse_fill")
			
		var a = Animation.new()
		a.length = 0.9
		
		# 1. Pulse track
		var pulse_track := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(pulse_track, "Sigil:material:shader_parameter/pulse")
		a.track_insert_key(pulse_track, 0.0, 0.0)
		a.track_insert_key(pulse_track, 0.15, 1.0)
		a.track_insert_key(pulse_track, 0.5, 0.4)
		a.track_insert_key(pulse_track, 0.9, 0.0)
		
		# 2. Fill track
		var fill_track := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(fill_track, "Sigil:material:shader_parameter/fill")
		a.track_insert_key(fill_track, 0.0, 0.0)
		a.track_insert_key(fill_track, 0.6, 1.0)
		
		anim.add_animation("pulse_fill", a)
		anim.play("pulse_fill")