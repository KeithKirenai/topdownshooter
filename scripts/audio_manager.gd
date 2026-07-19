extends Node
class_name AudioManager

const COMBAT_TRACKS: Array[AudioStream] = [
	preload("res://assets/music/bgm_combat_1.wav"),
	preload("res://assets/music/bgm_combat_2.wav"),
	preload("res://assets/music/bgm_combat_3.wav")
]
const LOBBY_TRACKS: Array[AudioStream] = [
	preload("res://assets/music/bgm_lobby_1.wav"),
	preload("res://assets/music/bgm_lobby_2.wav"),
	preload("res://assets/music/bgm_lobby_3.wav")
]

const SHOOT_SOUNDS := {
	"pistol": preload("res://assets/sounds/pistol_shoot.wav"),
	"smg": preload("res://assets/sounds/smg.wav"),
	"shotgun": preload("res://assets/sounds/shotgun_shoot.wav"),
	"minigun": preload("res://assets/sounds/minigun_shoot.wav"),
	"sniper": preload("res://assets/sounds/sniper_shoot.wav"),
	"missile": preload("res://assets/sounds/missile_launch.wav"),
}

var _combat_playlist: Array[AudioStream] = []
var _lobby_playlist: Array[AudioStream] = []
var _current_combat_idx := 0
var _current_lobby_idx := 0

var bgm: AudioStreamPlayer
var intermission_bgm: AudioStreamPlayer
var main_node: Node

func initialize(p_main: Node, p_bgm: AudioStreamPlayer, p_intermission_bgm: AudioStreamPlayer) -> void:
	main_node = p_main
	bgm = p_bgm
	intermission_bgm = p_intermission_bgm
	
	_combat_playlist = COMBAT_TRACKS.duplicate()
	_combat_playlist.shuffle()
	_lobby_playlist = LOBBY_TRACKS.duplicate()
	_lobby_playlist.shuffle()
	_current_combat_idx = 0
	_current_lobby_idx = 0
	
	_setup_ambience()

func _setup_ambience() -> void:
	# 1. Rushing wind using a pitched down missile launch loop
	var wind := AudioStreamPlayer.new()
	wind.bus = "Standard"
	wind.stream = preload("res://assets/sounds/missile_launch.wav")
	wind.pitch_scale = 0.08
	wind.volume_db = -18.0
	add_child(wind)
	wind.play()
	wind.finished.connect(func():
		if is_instance_valid(wind):
			wind.play()
	)
	
	# Periodically fade wind volume to simulate gusts
	var wind_timer = Timer.new()
	wind_timer.wait_time = 4.0
	wind_timer.autostart = true
	wind_timer.timeout.connect(func():
		var tween = create_tween()
		tween.tween_property(wind, "volume_db", randf_range(-24.0, -14.0), 3.0)
	)
	add_child(wind_timer)
	
	# 2. Periodic bird chirps / crickets using high pitched coin/lock ticks
	var bird_timer = Timer.new()
	bird_timer.wait_time = 2.5
	bird_timer.autostart = true
	bird_timer.timeout.connect(func():
		if randf() < 0.45:
			var chirp := AudioStreamPlayer.new()
			chirp.bus = "Standard"
			if randf() < 0.5:
				chirp.stream = preload("res://assets/sounds/coin_tick.wav")
				chirp.pitch_scale = randf_range(3.2, 4.2)
			else:
				chirp.stream = preload("res://assets/sounds/lock_on.wav")
				chirp.pitch_scale = randf_range(2.8, 3.5)
			chirp.volume_db = -24.0
			add_child(chirp)
			chirp.play()
			chirp.finished.connect(chirp.queue_free)
	)
	add_child(bird_timer)

func play_next_combat_track() -> void:
	if _combat_playlist.is_empty() or not bgm:
		return
	var stream: AudioStream = _combat_playlist[_current_combat_idx]
	bgm.stream = stream
	var round_count = main_node.round_count if main_node else 1
	bgm.pitch_scale = 1.0 + minf((round_count - 1) * 0.04, 0.4)
	bgm.play()
	_current_combat_idx = (_current_combat_idx + 1) % _combat_playlist.size()
	if _current_combat_idx == 0:
		_combat_playlist.shuffle()

func play_next_lobby_track() -> void:
	if _lobby_playlist.is_empty() or not intermission_bgm:
		return
	var stream: AudioStream = _lobby_playlist[_current_lobby_idx]
	intermission_bgm.stream = stream
	var round_count = main_node.round_count if main_node else 1
	intermission_bgm.pitch_scale = 1.0 + minf((round_count - 1) * 0.04, 0.4)
	intermission_bgm.play()
	_current_lobby_idx = (_current_lobby_idx + 1) % _lobby_playlist.size()
	if _current_lobby_idx == 0:
		_lobby_playlist.shuffle()

func play_layered_shoot(weapon_type: String, pos: Vector2) -> void:
	var stream = SHOOT_SOUNDS.get(weapon_type, SHOOT_SOUNDS["pistol"])
	var primary := AudioStreamPlayer2D.new()
	primary.bus = "Standard"
	primary.stream = stream
	primary.global_position = pos
	
	var vol := 0.0
	var pitch := randf_range(0.92, 1.08)
	match weapon_type:
		"pistol":
			vol = 4.6
		"smg":
			vol = 4.0
			pitch = randf_range(1.06, 1.22)
		"shotgun":
			vol = 1.5
		"minigun":
			vol = 4.2
			pitch = randf_range(0.95, 1.1)
		"sniper":
			vol = 4.0
			pitch = randf_range(0.88, 0.98)
		"missile":
			vol = 3.5
			pitch = randf_range(0.9, 1.05)
			
	primary.volume_db = vol
	primary.pitch_scale = pitch
	add_child(primary)
	primary.play()
	primary.finished.connect(primary.queue_free)

	# 2. Mechanical transient click
	var click := AudioStreamPlayer2D.new()
	click.bus = "Standard"
	click.stream = preload("res://assets/sounds/hitmarker.wav")
	click.pitch_scale = randf_range(1.4, 1.7)
	click.volume_db = -9.0
	click.global_position = pos
	add_child(click)
	click.play()
	click.finished.connect(click.queue_free)
	
	# 3. Sub-bass thump for all weapons
	var thump := AudioStreamPlayer2D.new()
	thump.bus = "Standard"
	thump.stream = preload("res://assets/sounds/explosion.wav")
	thump.global_position = pos
	
	if weapon_type in ["shotgun", "sniper", "missile"]:
		thump.pitch_scale = randf_range(0.32, 0.38)
		thump.volume_db = -5.0
		add_child(thump)
		thump.play()
		thump.finished.connect(thump.queue_free)
	else:
		thump.pitch_scale = randf_range(0.48, 0.58)
		thump.volume_db = -16.0
		add_child(thump)
		thump.play()
		thump.finished.connect(thump.queue_free)

func play_layered_hit(pos: Vector2, is_heavy: bool) -> void:
	# 1. Flesh squish
	var squish := AudioStreamPlayer2D.new()
	squish.bus = "Standard"
	squish.stream = preload("res://assets/sounds/hit.wav")
	squish.pitch_scale = randf_range(0.85, 1.15)
	squish.volume_db = 1.2
	squish.global_position = pos
	add_child(squish)
	squish.play()
	squish.finished.connect(squish.queue_free)
	
	# 2. Sharp transient click
	var click := AudioStreamPlayer2D.new()
	click.bus = "Standard"
	click.stream = preload("res://assets/sounds/hitmarker.wav")
	click.pitch_scale = randf_range(1.0, 1.2)
	click.volume_db = -1.8
	click.global_position = pos
	add_child(click)
	click.play()
	click.finished.connect(click.queue_free)
	
	# 3. Sub-bass thump for heavy/critical hits
	if is_heavy:
		var thump := AudioStreamPlayer2D.new()
		thump.bus = "Standard"
		thump.stream = preload("res://assets/sounds/drum_tick.wav")
		thump.pitch_scale = randf_range(0.4, 0.6)
		thump.volume_db = -2.5
		thump.global_position = pos
		add_child(thump)
		thump.play()
		thump.finished.connect(thump.queue_free)

func play_layered_explosion(pos: Vector2) -> void:
	# 1. High-frequency crack
	var crack := AudioStreamPlayer2D.new()
	crack.bus = "Standard"
	crack.stream = preload("res://assets/sounds/explosion.wav")
	crack.pitch_scale = randf_range(1.2, 1.35)
	crack.volume_db = -0.5
	crack.global_position = pos
	add_child(crack)
	crack.play()
	crack.finished.connect(crack.queue_free)
	
	# 2. Sub-bass thump
	var sub := AudioStreamPlayer2D.new()
	sub.bus = "Standard"
	sub.stream = preload("res://assets/sounds/explosion.wav")
	sub.pitch_scale = randf_range(0.32, 0.38)
	sub.volume_db = 5.2
	sub.global_position = pos
	add_child(sub)
	sub.play()
	sub.finished.connect(sub.queue_free)
	
	# 3. Cascading shrapnel/sparks hitting ground
	for i in range(4):
		var delay = randf_range(0.04, 0.18)
		get_tree().create_timer(delay, false).timeout.connect(func():
			if not is_inside_tree():
				return
			var tick := AudioStreamPlayer2D.new()
			tick.bus = "Standard"
			tick.stream = preload("res://assets/sounds/hitmarker.wav")
			tick.pitch_scale = randf_range(1.2, 1.6)
			tick.volume_db = -12.0
			tick.global_position = pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))
			add_child(tick)
			tick.play()
			tick.finished.connect(tick.queue_free)
		)
