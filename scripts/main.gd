extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

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

enum State { TITLE, INTERMISSION, COUNTDOWN, ACTIVE, GAME_OVER }

var score := 0
var round_count := 0
var state := State.TITLE
var enemies_to_kill := 0
var menu_open := false
var combo_count := 0
var combo_timer := 0.0
const COMBO_LIFETIME := 5.0

var _konami_buffer: Array[int] = []
var _konami_seq := [KEY_W, KEY_W, KEY_S, KEY_S, KEY_W, KEY_W, KEY_A, KEY_A]
var _konami_triggered_this_frame := false
var paused := false

var _combat_playlist: Array[AudioStream] = []
var _lobby_playlist: Array[AudioStream] = []
var _current_combat_idx := 0
var _current_lobby_idx := 0

@onready var bgm := $BGM
@onready var intermission_bgm := $IntermissionBGM
@onready var spawn_timer := $SpawnTimer


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	setup_ground()
	setup_world_environment()
	spawn_decor()
	_setup_ambience()
	spawn_player()
	$HUD.show_title()
	_freeze_player(true)
	_init_playlists()
	
	# Create indicators node so they draw on top of all ground/elements
	var indicators := Node2D.new()
	indicators.name = "EnemyIndicators"
	indicators.z_index = 10
	indicators.draw.connect(_draw_indicators)
	add_child(indicators)
	bgm.volume_db = 2.0
	intermission_bgm.volume_db = 2.0
	# Play lobby music on the title screen right away
	_play_next_lobby_track()



func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_check_konami(event.keycode)
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
			print("TITLE state: Konami flag before confirm check: ", _konami_triggered_this_frame)
			if not _konami_triggered_this_frame:
				start_intermission()
			_konami_triggered_this_frame = false
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


func setup_world_environment() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.28
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.environment = environment
	add_child(env)


func trigger_hit_stop(duration: float = 0.08, time_scale: float = 0.05, pos: Vector2 = Vector2.ZERO) -> void:
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



# Cache textures to avoid recreating
static var _light_tex: Texture2D = null
static var _shadow_tex: Texture2D = null
static var _grass_tex: Texture2D = null
static var _rock_tex: Texture2D = null
static var _tree_tex: Texture2D = null
static var _bush_tex: Texture2D = null

func get_radial_light_texture() -> Texture2D:
	if _light_tex:
		return _light_tex
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for x in range(64):
		for y in range(64):
			var dx := x - 32.0
			var dy := y - 32.0
			var dist := sqrt(dx*dx + dy*dy) / 32.0
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			alpha = alpha * alpha
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_light_tex = ImageTexture.create_from_image(img)
	return _light_tex


func _create_shadow_texture() -> Texture2D:
	if _shadow_tex:
		return _shadow_tex
	var img := Image.create(48, 24, false, Image.FORMAT_RGBA8)
	for x in range(48):
		for y in range(24):
			var dx := (x - 24.0) / 24.0
			var dy := (y - 12.0) / 12.0
			var dist := sqrt(dx*dx + dy*dy)
			if dist <= 1.0:
				var falloff := pow(1.0 - dist, 1.3)
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, falloff * 0.55))
	_shadow_tex = ImageTexture.create_from_image(img)
	return _shadow_tex


func _create_grass_texture() -> Texture2D:
	if _grass_tex:
		return _grass_tex
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var col1 := Color(0.28, 0.68, 0.18)
	var col2 := Color(0.45, 0.82, 0.32)
	
	img.set_pixel(4, 15, col1); img.set_pixel(4, 14, col1); img.set_pixel(3, 13, col1)
	img.set_pixel(3, 12, col1); img.set_pixel(2, 11, col2); img.set_pixel(1, 10, col2)
	
	img.set_pixel(8, 15, col1); img.set_pixel(8, 14, col1); img.set_pixel(8, 13, col1)
	img.set_pixel(8, 12, col2); img.set_pixel(7, 11, col2); img.set_pixel(7, 10, col2)
	img.set_pixel(6, 9, col2)
	
	img.set_pixel(11, 15, col1); img.set_pixel(11, 14, col1); img.set_pixel(12, 13, col1)
	img.set_pixel(12, 12, col2); img.set_pixel(13, 11, col2); img.set_pixel(14, 10, col2)
	
	_grass_tex = ImageTexture.create_from_image(img)
	return _grass_tex


func _create_rock_texture() -> Texture2D:
	if _rock_tex:
		return _rock_tex
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	var border := Color(0.22, 0.22, 0.24)
	var fill := Color(0.42, 0.42, 0.45)
	var shadow := Color(0.28, 0.28, 0.31)
	var highlight := Color(0.58, 0.58, 0.61)
	
	for x in range(24):
		for y in range(24):
			var dx := x - 12.0
			var dy := y - 12.0
			var dist := sqrt(dx*dx + dy*dy)
			if dist < 11.0:
				if dist >= 9.5:
					img.set_pixel(x, y, border)
				else:
					if dx < -2.0 and dy < -2.0:
						img.set_pixel(x, y, highlight)
					elif dx > 2.0 or dy > 2.0:
						img.set_pixel(x, y, shadow)
					else:
						img.set_pixel(x, y, fill)
	_rock_tex = ImageTexture.create_from_image(img)
	return _rock_tex


func _create_tree_texture() -> Texture2D:
	if _tree_tex:
		return _tree_tex
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	var trunk_col := Color(0.45, 0.28, 0.18)
	var trunk_shadow := Color(0.32, 0.18, 0.12)
	var leaf_col := Color(0.18, 0.52, 0.22)
	var leaf_highlight := Color(0.32, 0.68, 0.32)
	var leaf_shadow := Color(0.12, 0.38, 0.15)
	
	for x in range(13, 19):
		for y in range(30, 48):
			if x == 18 or y > 44:
				img.set_pixel(x, y, trunk_shadow)
			else:
				img.set_pixel(x, y, trunk_col)
				
	for x in range(32):
		for y in range(34):
			var dx := x - 16.0
			var dy := y - 16.0
			var dist := sqrt(dx*dx + dy*dy)
			if dist < 15.0:
				if dist >= 13.5:
					img.set_pixel(x, y, Color(0.1, 0.3, 0.12))
				else:
					if dx < -3.0 and dy < -3.0:
						img.set_pixel(x, y, leaf_highlight)
					elif dx > 3.0 or dy > 3.0:
						img.set_pixel(x, y, leaf_shadow)
					else:
						img.set_pixel(x, y, leaf_col)
						
	_tree_tex = ImageTexture.create_from_image(img)
	return _tree_tex


func setup_ground() -> void:
	var tilemap := TileMap.new()
	var tileset := TileSet.new()

	tileset.add_physics_layer(0)
	tileset.set_physics_layer_collision_layer(0, 4)
	tileset.set_physics_layer_collision_mask(0, 0)

	var ground_src := TileSetAtlasSource.new()
	ground_src.texture = preload("res://assets/tiles/ground.png")
	ground_src.texture_region_size = Vector2i(16, 16)
	ground_src.create_tile(Vector2i(0, 0))
	tileset.add_source(ground_src, 0)

	# Dynamic Dirt Tile atlas source (ID 2)
	var dirt_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	dirt_img.fill(Color(0.32, 0.25, 0.18)) # Warm dirt brown
	for i in range(12):
		dirt_img.set_pixel(randi() % 16, randi() % 16, Color(0.26, 0.20, 0.14))
		dirt_img.set_pixel(randi() % 16, randi() % 16, Color(0.38, 0.30, 0.22))
	var dirt_tex := ImageTexture.create_from_image(dirt_img)
	var dirt_src := TileSetAtlasSource.new()
	dirt_src.texture = dirt_tex
	dirt_src.texture_region_size = Vector2i(16, 16)
	dirt_src.create_tile(Vector2i(0, 0))
	tileset.add_source(dirt_src, 2)

	var wall_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	wall_img.fill(Color(0.35, 0.35, 0.38))
	for i in range(15):
		wall_img.set_pixel(randi() % 16, randi() % 16, Color(0.25, 0.25, 0.28))
		wall_img.set_pixel(randi() % 16, randi() % 16, Color(0.45, 0.45, 0.48))
	var wall_tex := ImageTexture.create_from_image(wall_img)

	var wall_src := TileSetAtlasSource.new()
	wall_src.texture = wall_tex
	wall_src.texture_region_size = Vector2i(16, 16)
	wall_src.create_tile(Vector2i(0, 0))
	tileset.add_source(wall_src, 1)
	var wall_tile_data := wall_src.get_tile_data(Vector2i(0, 0), 0)
	wall_tile_data.add_collision_polygon(0)
	wall_tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16),
	]))

	tilemap.tile_set = tileset

	# Generate Ground with Simplex Noise Dirt Paths
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.075

	tilemap.add_layer(0)
	for x in range(-19, 99):
		for y in range(-14, 54):
			var n_val = noise.get_noise_2d(x, y)
			if n_val > 0.16:
				tilemap.set_cell(0, Vector2i(x, y), 2, Vector2i(0, 0)) # Dirt
			else:
				tilemap.set_cell(0, Vector2i(x, y), 0, Vector2i(0, 0)) # Grass

	tilemap.add_layer(1)
	for x in range(-20, 100):
		tilemap.set_cell(1, Vector2i(x, -15), 1, Vector2i(0, 0))
		tilemap.set_cell(1, Vector2i(x, 54), 1, Vector2i(0, 0))
	for y in range(-15, 55):
		tilemap.set_cell(1, Vector2i(-20, y), 1, Vector2i(0, 0))
		tilemap.set_cell(1, Vector2i(99, y), 1, Vector2i(0, 0))

	add_child(tilemap)
	move_child(tilemap, 0)


func _create_bush_texture() -> Texture2D:
	if _bush_tex:
		return _bush_tex
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	var leaf_col := Color(0.22, 0.58, 0.28)
	var leaf_highlight := Color(0.35, 0.72, 0.38)
	var leaf_shadow := Color(0.15, 0.42, 0.2)
	
	for x in range(20):
		for y in range(20):
			var dx := x - 10.0
			var dy := y - 10.0
			var dist := sqrt(dx*dx + dy*dy)
			if dist < 9.0:
				if dist >= 7.5:
					img.set_pixel(x, y, Color(0.12, 0.35, 0.16))
				else:
					if dx < -2.0 and dy < -2.0:
						img.set_pixel(x, y, leaf_highlight)
					elif dx > 2.0 or dy > 2.0:
						img.set_pixel(x, y, leaf_shadow)
					else:
						img.set_pixel(x, y, leaf_col)
	_bush_tex = ImageTexture.create_from_image(img)
	return _bush_tex


func spawn_decor() -> void:
	# Load materials
	var sway_shader = preload("res://shaders/wind_sway.gdshader")
	var water_shader = preload("res://shaders/shimmer_water.gdshader")
	
	var sway_mat := ShaderMaterial.new()
	sway_mat.shader = sway_shader
	sway_mat.set_shader_parameter("wind_speed", 2.6)
	sway_mat.set_shader_parameter("wind_strength", 4.0)
	sway_mat.set_shader_parameter("wind_scale", 0.06)

	var water_mat := ShaderMaterial.new()
	water_mat.shader = water_shader
	water_mat.set_shader_parameter("water_color", Color(0.12, 0.4, 0.65, 0.5))
	water_mat.set_shader_parameter("shimmer_color", Color(0.5, 0.78, 1.0, 0.82))
	water_mat.set_shader_parameter("speed", 1.3)

	var shadow_t = _create_shadow_texture()
	var grass_t = _create_grass_texture()
	var rock_t = _create_rock_texture()
	var tree_t = _create_tree_texture()
	var bush_t = _create_bush_texture()

	# Create static decorations container
	var decor_container := Node2D.new()
	decor_container.name = "Decorations"
	add_child(decor_container)

	var rng := RandomNumberGenerator.new()
	rng.seed = randi()

	# Bounds in pixels (excluding boundaries)
	var x_min := -18.0 * 16.0
	var x_max := 98.0 * 16.0
	var y_min := -13.0 * 16.0
	var y_max := 53.0 * 16.0

	# 1. Puddles (background decoration)
	for p in range(22):
		var puddle := Sprite2D.new()
		var p_img := Image.create(48, 32, false, Image.FORMAT_RGBA8)
		p_img.fill(Color.WHITE)
		puddle.texture = ImageTexture.create_from_image(p_img)
		puddle.material = water_mat
		puddle.position = Vector2(rng.randf_range(x_min, x_max), rng.randf_range(y_min, y_max))
		puddle.scale = Vector2(rng.randf_range(0.8, 1.3), rng.randf_range(0.8, 1.3))
		puddle.z_index = -1
		decor_container.add_child(puddle)

	# 2. Swaying Grass Tufts
	for g in range(120):
		var grass := Sprite2D.new()
		grass.texture = grass_t
		grass.material = sway_mat
		grass.position = Vector2(rng.randf_range(x_min, x_max), rng.randf_range(y_min, y_max))
		grass.scale = Vector2(1.2, 1.2)
		
		# Add shadow sprite underneath
		var shadow := Sprite2D.new()
		shadow.texture = shadow_t
		shadow.position = Vector2(2, 6)
		shadow.scale = Vector2(0.25, 0.2)
		shadow.show_behind_parent = true
		grass.add_child(shadow)
		
		decor_container.add_child(grass)

	# 3. Boulders (Static Obstacles with Circular Collisions & Shadows)
	for r in range(35):
		var rock_body := StaticBody2D.new()
		rock_body.collision_layer = 4 # Obstacle layer
		rock_body.collision_mask = 0
		rock_body.position = Vector2(rng.randf_range(x_min, x_max), rng.randf_range(y_min, y_max))
		
		# Shadow
		var shadow := Sprite2D.new()
		shadow.texture = shadow_t
		shadow.position = Vector2(4, 8)
		shadow.scale = Vector2(0.55, 0.4)
		shadow.show_behind_parent = true
		rock_body.add_child(shadow)
		
		# Sprite
		var sprite := Sprite2D.new()
		sprite.texture = rock_t
		rock_body.add_child(sprite)
		
		# Collision Shape
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 10.0
		col.shape = shape
		rock_body.add_child(col)
		
		decor_container.add_child(rock_body)

	# 4. Trees (Swaying static obstacles with shadows)
	for t in range(40):
		var tree_body := StaticBody2D.new()
		tree_body.collision_layer = 4
		tree_body.collision_mask = 0
		tree_body.position = Vector2(rng.randf_range(x_min, x_max), rng.randf_range(y_min, y_max))
		
		# Huge Shadow offset to bottom right
		var shadow := Sprite2D.new()
		shadow.texture = shadow_t
		shadow.position = Vector2(4, 10)
		shadow.scale = Vector2(0.9, 0.55)
		shadow.show_behind_parent = true
		tree_body.add_child(shadow)
		
		# Swaying tree sprite
		var sprite := Sprite2D.new()
		sprite.texture = tree_t
		sprite.material = sway_mat
		sprite.offset = Vector2(0, -18) # pivot at trunk base
		tree_body.add_child(sprite)
		
		# Trunk base collision
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 6.0
		col.shape = shape
		col.position = Vector2(0, 0)
		tree_body.add_child(col)
		
		decor_container.add_child(tree_body)

	# 5. Swaying Bushes (Static Obstacles with shadows)
	for b in range(50):
		var bush_body := StaticBody2D.new()
		bush_body.collision_layer = 4
		bush_body.collision_mask = 0
		bush_body.position = Vector2(rng.randf_range(x_min, x_max), rng.randf_range(y_min, y_max))
		
		# Shadow
		var shadow := Sprite2D.new()
		shadow.texture = shadow_t
		shadow.position = Vector2(3, 6)
		shadow.scale = Vector2(0.425, 0.25)
		shadow.show_behind_parent = true
		bush_body.add_child(shadow)
		
		# Sprite
		var sprite := Sprite2D.new()
		sprite.texture = bush_t
		sprite.material = sway_mat
		sprite.offset = Vector2(0, -4) # slight offset
		bush_body.add_child(sprite)
		
		# Collision
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 5.0
		col.shape = shape
		bush_body.add_child(col)
		
		decor_container.add_child(bush_body)


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


const SHOOT_SOUNDS := {
	"pistol": preload("res://assets/sounds/pistol_shoot.wav"),
	"smg": preload("res://assets/sounds/smg.wav"),
	"shotgun": preload("res://assets/sounds/shotgun_shoot.wav"),
	"minigun": preload("res://assets/sounds/minigun_shoot.wav"),
	"sniper": preload("res://assets/sounds/sniper_shoot.wav"),
	"missile": preload("res://assets/sounds/missile_launch.wav"),
}

func play_layered_shoot(weapon_type: String, pos: Vector2) -> void:
	# 1. Play the primary weapon sound
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
	
	# 3. Sub-bass thump for all weapons (Secret Sauce: Low-frequency meatiness)
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
		# Subtle sub-bass thump for light weapons to give them a satisfying, heavy punch
		thump.pitch_scale = randf_range(0.48, 0.58)
		thump.volume_db = -16.0
		add_child(thump)
		thump.play()
		thump.finished.connect(thump.queue_free)


func play_layered_hit(pos: Vector2, is_heavy: bool) -> void:
	# 1. Flesh squish (slightly louder)
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


func spawn_player() -> void:
	var player := PLAYER_SCENE.instantiate()
	player.position = get_viewport_rect().size / 2
	player.died.connect(_on_player_died)
	add_child(player)


func start_intermission() -> void:
	$HUD.hide_title()
	_freeze_player(false)
	round_count += 1
	state = State.INTERMISSION
	spawn_timer.stop()
	bgm.stop()
	_play_next_lobby_track()
	$HUD.show_intermission(round_count)


func start_round() -> void:
	if state != State.INTERMISSION:
		return
	if menu_open:
		return
	state = State.COUNTDOWN
	intermission_bgm.stop()
	$HUD.show_countdown(round_count)


func _on_countdown_done() -> void:
	if state != State.COUNTDOWN:
		return
	state = State.ACTIVE
	enemies_to_kill = 12 + (round_count - 1) * 6
	$HUD.show_round_active(round_count, enemies_to_kill)
	_play_next_combat_track()
	for i in range(enemies_to_kill):
		spawn_enemy()


func spawn_enemy() -> void:
	var enemy := ENEMY_SCENE.instantiate()
	# Dynamic Vampire Survivors style spawning pool based on the round number
	var pool := []
	if round_count <= 1:
		# Round 1: Swarms of bats, skeletons, and standard red enemies
		pool = [
			{"type": "bat", "weight": 0.45},
			{"type": "red", "weight": 0.40},
			{"type": "skeleton", "weight": 0.15}
		]
	elif round_count == 2:
		# Round 2: Introduce ghosts and zombies
		pool = [
			{"type": "bat", "weight": 0.25},
			{"type": "red", "weight": 0.25},
			{"type": "skeleton", "weight": 0.15},
			{"type": "ghost", "weight": 0.15},
			{"type": "zombie", "weight": 0.20}
		]
	elif round_count == 3:
		# Round 3: Introduce green tanks
		pool = [
			{"type": "bat", "weight": 0.15},
			{"type": "red", "weight": 0.20},
			{"type": "skeleton", "weight": 0.15},
			{"type": "ghost", "weight": 0.15},
			{"type": "zombie", "weight": 0.20},
			{"type": "green", "weight": 0.15}
		]
	elif round_count == 4:
		# Round 4: Introduce purple mega-tanks and elite werewolves
		pool = [
			{"type": "bat", "weight": 0.10},
			{"type": "red", "weight": 0.15},
			{"type": "skeleton", "weight": 0.10},
			{"type": "ghost", "weight": 0.15},
			{"type": "zombie", "weight": 0.20},
			{"type": "green", "weight": 0.12},
			{"type": "purple", "weight": 0.08},
			{"type": "werewolf", "weight": 0.10}
		]
	else:
		# Round 5+: Extreme chaotic mixture of all 8 enemy types
		pool = [
			{"type": "bat", "weight": 0.12},
			{"type": "red", "weight": 0.13},
			{"type": "skeleton", "weight": 0.12},
			{"type": "ghost", "weight": 0.13},
			{"type": "zombie", "weight": 0.15},
			{"type": "green", "weight": 0.12},
			{"type": "purple", "weight": 0.11},
			{"type": "werewolf", "weight": 0.12}
		]
	
	# Select type based on weights
	var total_weight := 0.0
	for item in pool:
		total_weight += item["weight"]
	
	var roll := randf() * total_weight
	var selected_type := "red"
	var current_sum := 0.0
	for item in pool:
		current_sum += item["weight"]
		if roll <= current_sum:
			selected_type = item["type"]
			break
			
	enemy.enemy_type = selected_type
		
	var viewport := get_viewport_rect().size
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var visible_size := viewport / 2.0 # 640x360 logical viewport size under 2x zoom
	var spawn_pos := Vector2.ZERO
	var attempts := 0
	while attempts < 10:
		if not player:
			break
		var side := randi() % 4
		var px := player.global_position.x
		var py := player.global_position.y
		match side:
			0:
				spawn_pos = Vector2(randf_range(px - visible_size.x/2.0, px + visible_size.x/2.0), py - visible_size.y/2.0 - 32)
			1:
				spawn_pos = Vector2(randf_range(px - visible_size.x/2.0, px + visible_size.x/2.0), py + visible_size.y/2.0 + 32)
			2:
				spawn_pos = Vector2(px - visible_size.x/2.0 - 32, randf_range(py - visible_size.y/2.0, py + visible_size.y/2.0))
			3:
				spawn_pos = Vector2(px + visible_size.x/2.0 + 32, randf_range(py - visible_size.y/2.0, py + visible_size.y/2.0))
		
		spawn_pos.x = clampf(spawn_pos.x, -290.0, 1570.0)
		spawn_pos.y = clampf(spawn_pos.y, -210.0, 850.0)
		
		if not player:
			break
		if spawn_pos.distance_to(player.global_position) > 200.0:
			break
		attempts += 1
		
	enemy.position = spawn_pos
	enemy.killed.connect(_on_enemy_killed)
	add_child(enemy)


func increment_combo_on_hit() -> void:
	if state != State.ACTIVE:
		return
	combo_count += 1
	combo_timer = COMBO_LIFETIME
	$HUD.show_combo(combo_count)
	
	var player = get_tree().get_first_node_in_group("player")
	if player and "peak_combo" in player:
		player.peak_combo = max(player.peak_combo, combo_count)


func _on_enemy_killed(by_weapon: String = "") -> void:
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
	state = State.INTERMISSION
	bgm.stop()
	var prize := 100 + round_count * 50
	add_score(prize)
	$HUD.show_round_complete(round_count, prize)
	await get_tree().create_timer(1.5).timeout
	if state == State.INTERMISSION:
		start_intermission()




func _check_konami(keycode: int) -> void:
	var mapped := keycode
	if keycode == KEY_UP: mapped = KEY_W
	elif keycode == KEY_DOWN: mapped = KEY_S
	elif keycode == KEY_LEFT: mapped = KEY_A
	elif keycode == KEY_RIGHT: mapped = KEY_D

	_konami_buffer.append(mapped)
	if _konami_buffer.size() > _konami_seq.size():
		_konami_buffer.pop_front()
	if _konami_buffer.size() == _konami_seq.size():
		var match_all := true
		for i in range(_konami_seq.size()):
			if _konami_buffer[i] != _konami_seq[i]:
				match_all = false
				break
		if match_all:
			add_score(999999)
			_konami_triggered_this_frame = true
			_konami_buffer.clear()
			print("Cheat code matched! Flag set to: ", _konami_triggered_this_frame)
			
			# Play high-pitch victory chime
			var sp := AudioStreamPlayer.new()
			sp.bus = "Standard"
			sp.stream = preload("res://assets/sounds/round_win.wav")
			sp.pitch_scale = 1.8
			sp.volume_db = -5.0
			add_child(sp)
			sp.play()
			sp.finished.connect(sp.queue_free)
			
			# Spawn a gold floating text announcement above the player
			var player = get_tree().get_first_node_in_group("player")
			if player:
				var label := Label.new()
				label.text = "CHEAT: 999,999 COINS!"
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				label.add_theme_font_size_override("font_size", 13)
				label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2)) # Gold
				label.add_theme_constant_override("outline_size", 4)
				label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1))
				label.position = Vector2(-100, -80)
				player.add_child(label)
				
				# Animate float & fade
				var t = create_tween().set_parallel(true)
				t.tween_property(label, "position:y", -120.0, 1.4)
				t.tween_property(label, "modulate:a", 0.0, 1.4)
				t.chain().tween_callback(label.queue_free)


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


func _init_playlists() -> void:
	_combat_playlist = COMBAT_TRACKS.duplicate()
	_combat_playlist.shuffle()
	_lobby_playlist = LOBBY_TRACKS.duplicate()
	_lobby_playlist.shuffle()
	_current_combat_idx = 0
	_current_lobby_idx = 0


func _play_next_combat_track() -> void:
	if _combat_playlist.is_empty():
		return
	var stream: AudioStream = _combat_playlist[_current_combat_idx]
	bgm.stream = stream
	bgm.pitch_scale = 1.0 + minf((round_count - 1) * 0.04, 0.4)
	bgm.play()
	_current_combat_idx = (_current_combat_idx + 1) % _combat_playlist.size()
	if _current_combat_idx == 0:
		_combat_playlist.shuffle()


func _play_next_lobby_track() -> void:
	if _lobby_playlist.is_empty():
		return
	var stream: AudioStream = _lobby_playlist[_current_lobby_idx]
	intermission_bgm.stream = stream
	intermission_bgm.pitch_scale = 1.0 + minf((round_count - 1) * 0.04, 0.4)
	intermission_bgm.play()
	_current_lobby_idx = (_current_lobby_idx + 1) % _lobby_playlist.size()
	if _current_lobby_idx == 0:
		_lobby_playlist.shuffle()


func _on_bgm_finished() -> void:
	if state == State.ACTIVE:
		_play_next_combat_track()


func _on_intermission_bgm_finished() -> void:
	if state == State.INTERMISSION:
		_play_next_lobby_track()


func _on_player_died() -> void:
	state = State.GAME_OVER
	spawn_timer.stop()
	bgm.stop()
	intermission_bgm.stop()
	$HUD.show_game_over()
	$GameOverSound.play()


func _process(delta: float) -> void:
	if state == State.ACTIVE and combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_count = 0
			$HUD.hide_combo()
		else:
			$HUD.update_combo_timer(combo_timer / COMBO_LIFETIME)
	
	var ind := get_node_or_null("EnemyIndicators")
	if ind:
		ind.queue_redraw()


func _draw_indicators() -> void:
	var ind := get_node_or_null("EnemyIndicators") as Node2D
	if not ind:
		return
	if state != State.ACTIVE:
		return
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	var viewport := get_viewport_rect().size
	var visible_size := viewport / 2.0 # 640x360 logical viewport under 2x zoom
	var cam_pos: Vector2 = player.global_position
	var min_bound: Vector2 = cam_pos - visible_size / 2.0
	var max_bound: Vector2 = cam_pos + visible_size / 2.0
	var margin := 24.0
	
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.dying:
			continue
		
		var pos: Vector2 = enemy.global_position
		var is_offscreen = (pos.x < min_bound.x or pos.x > max_bound.x or pos.y < min_bound.y or pos.y > max_bound.y)
		
		if is_offscreen:
			var indicator_pos := Vector2(
				clampf(pos.x, min_bound.x + margin, max_bound.x - margin),
				clampf(pos.y, min_bound.y + margin, max_bound.y - margin)
			)
			var to_enemy := (pos - indicator_pos).normalized()
			var size := 12.0
			var p1 := indicator_pos + to_enemy * size
			var p2 := indicator_pos + to_enemy.rotated(2.2) * size
			var p3 := indicator_pos + to_enemy.rotated(-2.2) * size
			
			var color := Color.RED
			match enemy.enemy_type:
				"green":
					color = Color.GREEN
				"purple":
					color = Color.MEDIUM_PURPLE
				"bat":
					color = Color(0.6, 0.4, 0.8)
				"skeleton":
					color = Color(0.9, 0.85, 0.7)
				"ghost":
					color = Color(0.3, 0.8, 1.0, 0.8)
				"zombie":
					color = Color(0.4, 0.6, 0.2)
				"werewolf":
					color = Color(0.8, 0.3, 0.0)
				
			ind.draw_polygon(PackedVector2Array([p1, p2, p3]), [color])
