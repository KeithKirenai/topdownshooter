extends Node2D

# Core game manager — handles game states, round flow, combo, shop, and input routing.
# Attached to the root scene, orchestrates subsystems (world gen, audio, wave spawner, HUD).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

enum State { TITLE, INTERMISSION, COUNTDOWN, ACTIVE, GAME_OVER }

var score := 0
var round_count := 0
var state := State.TITLE
var enemies_to_kill := 0
var menu_open := false
var combo_count := 0
var combo_timer := 0.0
const COMBO_LIFETIME := 5.0

var paused := false
var round_start_time: float = 0.0

var world_gen: WorldGenerator
var audio_manager: AudioManager
var wave_spawner: WaveSpawner
var enemy_indicators: EnemyIndicators

@onready var bgm := $BGM
@onready var intermission_bgm := $IntermissionBGM
@onready var spawn_timer := $SpawnTimer


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	
	# Setup World Generation
	world_gen = WorldGenerator.new()
	add_child(world_gen)
	world_gen.generate_world()
	
	# Setup Audio Manager
	audio_manager = AudioManager.new()
	add_child(audio_manager)
	audio_manager.initialize(self, bgm, intermission_bgm)
	
	# Setup Wave Spawner
	wave_spawner = WaveSpawner.new()
	add_child(wave_spawner)
	wave_spawner.initialize(self)
	
	# Setup Enemy Indicators
	enemy_indicators = EnemyIndicators.new()
	enemy_indicators.name = "EnemyIndicators"
	add_child(enemy_indicators)
	enemy_indicators.initialize(self)
	
	spawn_player()
	$HUD.show_title()
	_freeze_player(true)
	
	bgm.volume_db = 2.0
	intermission_bgm.volume_db = 2.0
	# Play lobby music on the title screen right away
	audio_manager.play_next_lobby_track()


func _unhandled_input(event: InputEvent) -> void:
	# Input priority: shop > pause > title > intermission > game over
	if menu_open:
		if event.is_action_pressed("confirm"):
			if $HUD.handle_shop_confirm():
				get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel") or _is_joy_button(event, JOY_BUTTON_B):
			close_shop()
			return
		if event.is_action_pressed("shop"):
			close_shop()
			return
		if _is_nav_event(event):
			$HUD.navigate_shop(event)
			get_viewport().set_input_as_handled()
			return
		return
	if event.is_action_pressed("pause"):
		if not menu_open and state not in [State.TITLE, State.GAME_OVER]:
			paused = not paused
			_freeze_player(paused)
			get_tree().paused = paused
			return
	if state == State.TITLE:
		if event.is_action_pressed("confirm"):
			start_intermission()
		return
	if event.is_action_pressed("shop"):
		if state == State.INTERMISSION and not paused:
			open_shop()
		return
	if state == State.INTERMISSION:
		if event.is_action_pressed("confirm"):
			start_round()
		return
	if state == State.GAME_OVER:
		var hud := $HUD
		if hud and hud.has_method("handle_game_over_input"):
			hud.handle_game_over_input(event)


func trigger_hit_stop(duration: float = 0.08, time_scale: float = 0.05, pos: Vector2 = Vector2.ZERO) -> void:
	# Freezes time briefly for impact feel, spawns shockwave + particles
	Engine.time_scale = time_scale
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.post_proc_aberration = clampf(player.post_proc_aberration + 0.005, 0.0, 0.02)
		player.post_proc_distortion = clampf(player.post_proc_distortion - 0.02, -0.02, 0.15)
		
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	
	# Play high-energy kinetic release sound (pitched-up explosion crackle)
	var release_sp := AudioStreamPlayer.new()
	release_sp.bus = "Standard"
	release_sp.stream = preload("res://assets/sounds/explosion.wav")
	release_sp.pitch_scale = randf_range(1.6, 2.0)
	release_sp.volume_db = -10.0
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(release_sp)
		release_sp.play()
		release_sp.finished.connect(release_sp.queue_free)
	else:
		release_sp.queue_free()

	if pos != Vector2.ZERO:
		_spawn_release_shockwave(pos)


func _spawn_release_shockwave(pos: Vector2) -> void:
	# An expanding arc ring + spark burst at the hit point
	var wave := Node2D.new()
	wave.global_position = pos
	wave.z_index = 5
	
	var draw_script := GDScript.new()
	draw_script.source_code = """extends Node2D
var radius := 6.0
var max_radius := 44.0
var color := Color(1.0, 0.95, 0.7, 0.85)

func _process(delta: float) -> void:
	radius = move_toward(radius, max_radius, 240.0 * delta)
	color.a = clampf(1.0 - (radius / max_radius), 0.0, 1.0)
	queue_redraw()
	if radius >= max_radius:
		queue_free()

func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, color, 3.5, true)
"""
	wave.set_script(draw_script)
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(wave)
	else:
		wave.queue_free()
	
	# Release spark particles radiating outwards
	var release_parts := CPUParticles2D.new()
	release_parts.emitting = false
	release_parts.amount = 10
	release_parts.lifetime = 0.22
	release_parts.one_shot = true
	release_parts.explosiveness = 0.95
	release_parts.spread = 180.0
	release_parts.gravity = Vector2.ZERO
	release_parts.initial_velocity_min = 130.0
	release_parts.initial_velocity_max = 260.0
	release_parts.scale_amount_min = 2.0
	release_parts.scale_amount_max = 4.0
	release_parts.color = Color(1.0, 0.82, 0.45, 0.9)
	var ramp = Gradient.new()
	ramp.set_color(0, Color(1.0, 0.82, 0.45, 0.9))
	ramp.set_color(1, Color(1.0, 0.3, 0.0, 0.0))
	release_parts.color_ramp = ramp
	release_parts.global_position = pos
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(release_parts)
		release_parts.emitting = true
		release_parts.finished.connect(release_parts.queue_free)
	else:
		release_parts.queue_free()


func get_radial_light_texture() -> Texture2D:
	# Delegated to WorldGenerator
	if world_gen:
		return world_gen.get_radial_light_texture()
	return null


func play_layered_shoot(weapon_type: String, pos: Vector2) -> void:
	if audio_manager:
		audio_manager.play_layered_shoot(weapon_type, pos)


func play_layered_hit(pos: Vector2, is_heavy: bool) -> void:
	if audio_manager:
		audio_manager.play_layered_hit(pos, is_heavy)


func play_layered_explosion(pos: Vector2) -> void:
	if audio_manager:
		audio_manager.play_layered_explosion(pos)


func spawn_player() -> void:
	var player := PLAYER_SCENE.instantiate()
	player.position = get_viewport_rect().size / 2
	player.died.connect(_on_player_died)
	add_child(player)


func start_intermission() -> void:
	# Transitions from title to the buy phase between rounds
	$HUD.hide_title()
	_freeze_player(false)
	round_count += 1
	state = State.INTERMISSION
	spawn_timer.stop()
	bgm.stop()
	if audio_manager:
		audio_manager.play_next_lobby_track()
	$HUD.show_intermission(round_count)


func start_round() -> void:
	# Starts the 3-2-1 countdown before combat
	if state != State.INTERMISSION:
		return
	if menu_open:
		return
	state = State.COUNTDOWN
	intermission_bgm.stop()
	$HUD.show_countdown(round_count)


func _on_countdown_done() -> void:
	# Called by HUD after countdown animation finishes; begins the active round
	if state != State.COUNTDOWN:
		return
	state = State.ACTIVE
	enemies_to_kill = 12 + (round_count - 1) * 6
	round_start_time = float(Time.get_ticks_msec())
	$HUD.show_round_active(round_count, enemies_to_kill)
	if audio_manager:
		audio_manager.play_next_combat_track()
	if wave_spawner:
		wave_spawner.spawn_wave(round_count, enemies_to_kill)


func increment_combo_on_hit() -> void:
	# Called by enemy hit signals; increases combo and tracks peak on player
	if state != State.ACTIVE:
		return
	combo_count += 1
	combo_timer = COMBO_LIFETIME
	$HUD.show_combo(combo_count)
	
	var player = get_tree().get_first_node_in_group("player")
	if player and "peak_combo" in player:
		player.peak_combo = max(player.peak_combo, combo_count)


func _on_enemy_killed(by_weapon: String = "") -> void:
	# Decrements remaining enemy count, awards combo bonus, checks round completion
	if state != State.ACTIVE:
		return
		
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("record_kill"):
		player.record_kill(by_weapon)
		
	enemies_to_kill -= 1
	$HUD.update_enemies_remaining(enemies_to_kill)
	
	if combo_count >= 5:
		add_score(combo_count * 2)
		
	if enemies_to_kill <= 0:
		complete_round()


func complete_round() -> void:
	# Awards prize and loops back to intermission
	state = State.INTERMISSION
	bgm.stop()
	var prize := 100 + round_count * 50
	add_score(prize)
	$HUD.show_round_complete(round_count, prize)
	await get_tree().create_timer(1.5).timeout
	if state == State.INTERMISSION:
		start_intermission()





func heal_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player or not player.has_method("heal"):
		return
	player.heal()
	$HUD.flash_heal()




func add_score(amount: int) -> void:
	score += amount
	$HUD.update_score(score)
	if amount > 0:
		var player = get_tree().get_first_node_in_group("player")
		if player and "total_coins_collected" in player:
			player.total_coins_collected += amount


func open_shop() -> void:
	menu_open = true
	$HUD.show_shop()


func close_shop() -> void:
	menu_open = false
	$HUD.hide_shop()


func get_menu_open() -> bool:
	return menu_open


func is_game_started() -> bool:
	return state != State.TITLE


func _freeze_player(frozen_val: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_frozen"):
		player.set_frozen(frozen_val)


func _is_nav_event(event: InputEvent) -> bool:
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right") or event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		return true
	return false


func _is_joy_button(event: InputEvent, button: int) -> bool:
	return event is InputEventJoypadButton and event.button_index == button


func _on_bgm_finished() -> void:
	if state == State.ACTIVE and audio_manager:
		audio_manager.play_next_combat_track()


func _on_intermission_bgm_finished() -> void:
	if state == State.INTERMISSION and audio_manager:
		audio_manager.play_next_lobby_track()


func _on_player_died() -> void:
	state = State.GAME_OVER
	spawn_timer.stop()
	bgm.stop()
	intermission_bgm.stop()
	$HUD.show_game_over()
	$GameOverSound.play()


func _process(delta: float) -> void:
	# Ticks down the combo timer during active play
	if state == State.ACTIVE and combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_count = 0
			$HUD.hide_combo()
		else:
			$HUD.update_combo_timer(combo_timer / COMBO_LIFETIME)
