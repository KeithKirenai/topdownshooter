class_name ProceduralAudioHelper
extends RefCounted

static func play_procedural_sound(node: Node, type: String) -> void:
	if not node or not node.is_inside_tree():
		return
	var asp := AudioStreamPlayer.new()
	asp.bus = "Priority" if type in ["perfect_ping", "failed_jam"] else "Standard"
	node.add_child(asp)
	asp.finished.connect(asp.queue_free)
	
	match type:
		"mag_out":
			asp.stream = load("res://assets/sounds/weapon_switch.wav")
			asp.pitch_scale = 1.6
			asp.volume_db = 3.5
		"mag_in":
			asp.stream = load("res://assets/sounds/walk_step.wav")
			asp.pitch_scale = 0.65
			asp.volume_db = 6.5
		"bolt_rack":
			asp.stream = load("res://assets/sounds/weapon_switch.wav")
			asp.pitch_scale = 1.3
			asp.volume_db = 5.5
		"ui_tick":
			asp.stream = load("res://assets/sounds/lock_on.wav")
			asp.pitch_scale = 2.5
			asp.volume_db = -1.5
		"blocked":
			asp.stream = load("res://assets/sounds/lock_on.wav")
			asp.pitch_scale = 0.45
			asp.volume_db = 5.0
		"voice":
			asp.stream = load("res://assets/sounds/walk_step.wav")
			asp.pitch_scale = 0.75
			asp.volume_db = 6.0
		"low_ammo_warning":
			asp.stream = load("res://assets/sounds/lock_on.wav")
			asp.pitch_scale = 2.2
			asp.volume_db = -1.0
		"empty_warning":
			asp.stream = load("res://assets/sounds/lock_on.wav")
			asp.pitch_scale = 1.6
			asp.volume_db = 4.5
		"perfect_ping":
			asp.stream = load("res://assets/sounds/round_win.wav")
			asp.pitch_scale = 2.0
			asp.volume_db = 1.0
		"perfect_clack":
			asp.stream = load("res://assets/sounds/weapon_switch.wav")
			asp.pitch_scale = 0.82
			asp.volume_db = 7.0
		"good_click":
			asp.stream = load("res://assets/sounds/weapon_switch.wav")
			asp.pitch_scale = 1.5
			asp.volume_db = 2.0
		"failed_jam":
			asp.stream = load("res://assets/sounds/hurt.wav")
			asp.pitch_scale = 0.5
			asp.volume_db = 5.0
			
	asp.play()
