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
	spawn_player()
	$HUD.show_title()
	_freeze_player(true)
	_init_playlists()
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

	tilemap.add_layer(0)
	for x in range(-19, 99):
		for y in range(-14, 54):
			tilemap.set_cell(0, Vector2i(x, y), 0, Vector2i(0, 0))

	tilemap.add_layer(1)
	for x in range(-20, 100):
		tilemap.set_cell(1, Vector2i(x, -15), 1, Vector2i(0, 0))
		tilemap.set_cell(1, Vector2i(x, 54), 1, Vector2i(0, 0))
	for y in range(-15, 55):
		tilemap.set_cell(1, Vector2i(-20, y), 1, Vector2i(0, 0))
		tilemap.set_cell(1, Vector2i(99, y), 1, Vector2i(0, 0))

	add_child(tilemap)
	move_child(tilemap, 0)


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
	enemies_to_kill = 3 + (round_count - 1) * 2
	$HUD.show_round_active(round_count, enemies_to_kill)
	_play_next_combat_track()
	for i in range(enemies_to_kill):
		spawn_enemy()


func spawn_enemy() -> void:
	var enemy := ENEMY_SCENE.instantiate()
	var r := randf()
	if r < 0.10:
		enemy.enemy_type = "purple"
	elif r < 0.30:
		enemy.enemy_type = "green"
	else:
		enemy.enemy_type = "red"
		
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


func _on_enemy_killed() -> void:
	if state != State.ACTIVE:
		return
	enemies_to_kill -= 1
	$HUD.update_enemies_remaining(enemies_to_kill)
	
	if combo_count >= 5:
		add_score(combo_count * 2)
		
	if enemies_to_kill <= 0:
		complete_round()


func complete_round() -> void:
	state = State.INTERMISSION
	bgm.stop()
	var prize := 5 + round_count * 2
	add_score(prize)
	$HUD.show_round_complete(round_count, prize)
	await get_tree().create_timer(1.5).timeout
	if state == State.INTERMISSION:
		start_intermission()


func buy_smg() -> bool:
	if score < 20:
		return false
	score -= 20
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_weapon"):
		player.add_weapon("smg")
	$HUD.update_score(score)
	$HUD.show_intermission(round_count)
	return true


func buy_shotgun() -> bool:
	if score < 40:
		return false
	score -= 40
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_weapon"):
		player.add_weapon("shotgun")
	$HUD.update_score(score)
	$HUD.show_intermission(round_count)
	return true


func buy_minigun() -> bool:
	if score < 75:
		return false
	score -= 75
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_weapon"):
		player.add_weapon("minigun")
	$HUD.update_score(score)
	$HUD.show_intermission(round_count)
	return true


func buy_sniper() -> bool:
	if score < 50:
		return false
	score -= 50
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_weapon"):
		player.add_weapon("sniper")
	$HUD.update_score(score)
	$HUD.show_intermission(round_count)
	return true


func buy_missile() -> bool:
	if score < 90:
		return false
	score -= 90
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_weapon"):
		player.add_weapon("missile")
	$HUD.update_score(score)
	$HUD.show_intermission(round_count)
	return true


func buy_laser_sight() -> bool:
	if score < 30:
		return false
	score -= 30
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("has_laser_sight"):
		player.has_laser_sight = true
	$HUD.update_score(score)
	$HUD.show_intermission(round_count)
	return true


func buy_ammo() -> bool:
	if score < 10:
		return false
	score -= 10
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("refill_ammo"):
		player.refill_ammo()
	$HUD.update_score(score)
	$HUD.show_intermission(round_count)
	return true


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


func heal_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player or not player.has_method("heal"):
		return
	player.heal()
	$HUD.flash_heal()


func buy_heal() -> bool:
	if score < 5:
		return false
	score -= 5
	heal_player()
	$HUD.update_score(score)
	return true


func buy_extend_heart() -> bool:
	if score < 25:
		return false
	score -= 25
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("increase_max_health"):
		player.increase_max_health()
	$HUD.update_score(score)
	return true


func add_score(amount: int) -> void:
	score += amount
	$HUD.update_score(score)


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
	queue_redraw()


func _draw() -> void:
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
			if enemy.enemy_type == "green":
				color = Color.GREEN
			elif enemy.enemy_type == "purple":
				color = Color.MEDIUM_PURPLE
				
			draw_polygon(PackedVector2Array([p1, p2, p3]), [color])
