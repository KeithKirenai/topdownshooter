extends Node2D
class_name WorldGenerator

# Cache textures to avoid Recreating
var _light_tex: Texture2D = null
var _shadow_tex: Texture2D = null
var _grass_tex: Texture2D = null
var _rock_tex: Texture2D = null
var _tree_tex: Texture2D = null
var _bush_tex: Texture2D = null

func generate_world() -> void:
	setup_ground()
	setup_world_environment()
	spawn_decor()

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
	tilemap.z_index = -5

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
	
	var sway_mat := ShaderMaterial.new()
	sway_mat.shader = sway_shader
	sway_mat.set_shader_parameter("wind_speed", 2.6)
	sway_mat.set_shader_parameter("wind_strength", 4.0)
	sway_mat.set_shader_parameter("wind_scale", 0.06)

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
