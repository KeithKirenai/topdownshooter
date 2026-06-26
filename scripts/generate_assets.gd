@tool
extends SceneTree


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/sprites")
	DirAccess.make_dir_recursive_absolute("res://assets/tiles")
	DirAccess.make_dir_recursive_absolute("res://assets/ui")
	DirAccess.make_dir_recursive_absolute("res://assets/sounds")
	DirAccess.make_dir_recursive_absolute("res://assets/music")

	var C := {
		transparent = Color(0, 0, 0, 0),
		blue = Color(0.184, 0.294, 0.859),
		dark_blue = Color(0.102, 0.184, 0.549),
		skin = Color(0.910, 0.788, 0.608),
		hair = Color(0.961, 0.843, 0.259),
		hair_dark = Color(0.769, 0.604, 0.071),
		enemy_red = Color(0.784, 0.227, 0.169),
		enemy_dark = Color(0.478, 0.114, 0.071),
		bullet_yellow = Color(0.961, 0.843, 0.259),
		bullet_dark = Color(0.769, 0.604, 0.071),
		white = Color.WHITE,
		black = Color.BLACK,
		grass = Color(0.231, 0.549, 0.231),
		grass_dark = Color(0.145, 0.380, 0.145),
		heart = Color(0.894, 0.000, 0.345),
		heart_dark = Color(0.659, 0.000, 0.125),
		metal_light = Color(0.65, 0.65, 0.70),
		metal = Color(0.40, 0.40, 0.45),
		metal_dark = Color(0.20, 0.20, 0.25),
		mag_body = Color(0.12, 0.12, 0.15),
		wood = Color(0.55, 0.35, 0.15),
		wood_dark = Color(0.35, 0.20, 0.08),
		scope = Color(0.15, 0.15, 0.30),
		scope_glass = Color(0.30, 0.35, 0.60),
		rocket_red = Color(0.78, 0.20, 0.15),
		rocket_tip = Color(0.85, 0.75, 0.20),
		flame = Color(1.0, 0.60, 0.10),
		flame_light = Color(1.0, 0.85, 0.30),
	}

	create_player_sheet(C)
	create_enemy_sheet(C)
	create_ground_tile(C)
	create_heart(C)
	create_bullet_pistol(C)
	create_bullet_smg(C)
	create_bullet_shotgun(C)
	create_bullet_minigun(C)
	create_bullet_sniper(C)
	create_bullet_missile(C)
	create_gun(C)
	create_smg(C)
	create_shotgun(C)
	create_minigun(C)
	create_sniper(C)
	create_missile_launcher(C)
	create_sounds()
	create_bgm()
	create_bgm_extended()
	create_intermission_bgm()
	create_ui_icons()

	print("Assets generated in assets/")
	quit()


func px(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, color)


func circle(img: Image, cx: int, cy: int, r: int, color: Color) -> void:
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			if x * x + y * y <= r * r + r * 0.5:
				px(img, cx + x, cy + y, color)


func rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for i in range(w):
		for j in range(h):
			px(img, x + i, y + j, color)


func draw_player_frame(img: Image, C: Dictionary, fx: int, fy: int, dir: int, frame: int) -> void:
	var cx: int = fx + 8
	var base_y: int = fy

	var leg_offset: int = 0
	if frame == 1:
		leg_offset = -1
	elif frame == 2:
		leg_offset = 1

	# Exaggerated huge head and hair
	circle(img, cx, base_y + 4, 5, C.hair)
	circle(img, cx, base_y + 6, 6, C.skin)
	circle(img, cx, base_y + 4, 6, C.hair)
	circle(img, cx - 2, base_y + 2, 2, C.hair_dark)
	circle(img, cx + 2, base_y + 2, 2, C.hair_dark)

	# Huge cartoon eyeballs with pupils!
	if dir != 2:
		px(img, cx - 2, base_y + 6, C.white)
		px(img, cx - 2, base_y + 7, C.white)
		px(img, cx - 3, base_y + 6, C.white)
		px(img, cx - 3, base_y + 7, C.white)
		px(img, cx - 2, base_y + 6, C.black) # pupil left

		px(img, cx + 2, base_y + 6, C.white)
		px(img, cx + 2, base_y + 7, C.white)
		px(img, cx + 1, base_y + 6, C.white)
		px(img, cx + 1, base_y + 7, C.white)
		px(img, cx + 2, base_y + 6, C.black) # pupil right

	px(img, cx - 2, base_y + 9, C.skin)
	px(img, cx - 1, base_y + 9, C.skin)
	px(img, cx, base_y + 9, C.skin)
	px(img, cx + 1, base_y + 9, C.skin)
	px(img, cx + 2, base_y + 9, C.skin)

	var body_x: int = fx + 3
	var body_y: int = fy + 11
	rect(img, body_x, body_y, 10, 6, C.blue)
	px(img, body_x + 1, body_y - 1, C.blue)
	px(img, body_x + 8, body_y - 1, C.blue)

	if dir == 0 or dir == 2 or dir == 3:
		rect(img, fx + 13, fy + 12, 3, 2, C.dark_blue)
		px(img, fx + 13, fy + 11, C.dark_blue)
	if dir == 1:
		rect(img, fx, fy + 12, 3, 2, C.dark_blue)
		px(img, fx + 2, fy + 11, C.dark_blue)

	var lx: int = fx + 5
	var rx: int = fx + 9
	var leg_y: int = fy + 18
	if frame == 0:
		rect(img, lx, leg_y, 2, 2, C.dark_blue)
		rect(img, rx, leg_y, 2, 2, C.dark_blue)
	elif frame == 1:
		rect(img, lx, leg_y - 1, 2, 2, C.dark_blue)
		rect(img, rx, leg_y + 1, 2, 1, C.dark_blue)
	else:
		rect(img, lx, leg_y + 1, 2, 1, C.dark_blue)
		rect(img, rx, leg_y - 1, 2, 2, C.dark_blue)


func draw_enemy_frame(img: Image, C: Dictionary, fx: int, fy: int, _dir: int, frame: int) -> void:
	var cx: int = fx + 8
	var cy: int = fy + 8

	circle(img, cx, cy, 7, C.enemy_red)
	circle(img, cx, cy - 1, 5, C.enemy_dark)

	# Crazy wide eyeballs with tiny pupils
	circle(img, cx - 3, cy - 1, 2, C.white)
	circle(img, cx + 3, cy - 1, 2, C.white)
	px(img, cx - 3, cy - 1, C.black) # pupil left
	px(img, cx + 3, cy - 1, C.black) # pupil right

	# Jagged eyebrows (black)
	px(img, cx - 4, cy - 3, C.black)
	px(img, cx - 3, cy - 3, C.black)
	px(img, cx - 2, cy - 2, C.black)
	px(img, cx + 4, cy - 3, C.black)
	px(img, cx + 3, cy - 3, C.black)
	px(img, cx + 2, cy - 2, C.black)

	# Insane jagged mouth
	rect(img, cx - 3, cy + 3, 7, 3, C.black)
	px(img, cx - 2, cy + 3, C.white) # top teeth
	px(img, cx, cy + 3, C.white)
	px(img, cx + 2, cy + 3, C.white)
	px(img, cx - 1, cy + 5, C.white) # bottom teeth
	px(img, cx + 1, cy + 5, C.white)

	var lx: int = fx + 5
	var rx: int = fx + 9
	rect(img, lx, fy + 13, 2, 2, C.enemy_dark)
	rect(img, rx, fy + 13, 2, 2, C.enemy_dark)
	if frame == 1:
		rect(img, lx - 1, fy + 13, 2, 2, C.enemy_dark)
		rect(img, rx + 1, fy + 13, 2, 2, C.enemy_dark)


func create_player_sheet(C: Dictionary) -> void:
	var fw := 16
	var fh := 20
	var cols := 3
	var rows := 4
	var img := Image.create(fw * cols, fh * rows, false, Image.FORMAT_RGBA8)
	img.fill(C.transparent)

	for dir in range(rows):
		for frame in range(cols):
			var fx := frame * fw
			var fy := dir * fh
			draw_player_frame(img, C, fx, fy, dir, frame)

	var err := img.save_png("res://assets/sprites/player.png")
	if err != OK:
		push_error("Failed to save player.png: ", err)


func create_enemy_sheet(C: Dictionary) -> void:
	var fw := 16
	var fh := 16
	var cols := 3
	var rows := 4
	var img := Image.create(fw * cols, fh * rows, false, Image.FORMAT_RGBA8)
	img.fill(C.transparent)

	for dir in range(rows):
		for frame in range(cols):
			var fx := frame * fw
			var fy := dir * fh
			draw_enemy_frame(img, C, fx, fy, dir, frame)

	var err := img.save_png("res://assets/sprites/enemy.png")
	if err != OK:
		push_error("Failed to save enemy.png: ", err)


func create_bullet_pistol(C: Dictionary) -> void:
	var img := Image.create(8, 6, false, Image.FORMAT_RGBA8)
	img.fill(C.transparent)
	# Casing (brass gold)
	rect(img, 1, 1, 4, 4, Color(0.85, 0.70, 0.25))
	# Base rim (darker brass)
	rect(img, 0, 1, 1, 4, Color(0.60, 0.45, 0.15))
	# Bullet projectile (copper copper-red)
	rect(img, 5, 1, 2, 4, Color(0.75, 0.45, 0.30))
	px(img, 7, 2, Color(0.75, 0.45, 0.30))
	px(img, 7, 3, Color(0.75, 0.45, 0.30))
	# Highlights
	px(img, 2, 1, C.white)
	save_png(img, "bullet_pistol.png")
	# Save duplicate as fallback
	save_png(img, "bullet.png")


func create_bullet_smg(C: Dictionary) -> void:
	var img := Image.create(6, 4, false, Image.FORMAT_RGBA8)
	img.fill(C.transparent)
	# SMG 9mm tracer bullet: smaller brass casing and copper tip with tracer green back
	rect(img, 1, 1, 3, 2, Color(0.85, 0.70, 0.25)) # casing
	rect(img, 4, 1, 2, 2, Color(0.75, 0.45, 0.30)) # projectile
	px(img, 0, 1, Color(0.2, 0.9, 0.3)) # tracer green highlight
	px(img, 0, 2, Color(0.2, 0.9, 0.3))
	save_png(img, "bullet_smg.png")


func create_bullet_shotgun(C: Dictionary) -> void:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(C.transparent)
	# Buckshot lead pellet: small circular dark grey lead ball with specular reflection
	rect(img, 1, 0, 2, 4, Color(0.35, 0.35, 0.40))
	rect(img, 0, 1, 4, 2, Color(0.35, 0.35, 0.40))
	# Shadow/edges
	px(img, 0, 0, Color(0.2, 0.2, 0.22))
	px(img, 3, 0, Color(0.2, 0.2, 0.22))
	px(img, 0, 3, Color(0.2, 0.2, 0.22))
	px(img, 3, 3, Color(0.2, 0.2, 0.22))
	# Reflection
	px(img, 1, 1, Color(0.8, 0.8, 0.85))
	save_png(img, "bullet_shotgun.png")


func create_bullet_minigun(C: Dictionary) -> void:
	var img := Image.create(10, 6, false, Image.FORMAT_RGBA8)
	img.fill(C.transparent)
	# 7.62mm NATO rifle round: long brass body, copper-pointed bullet
	rect(img, 1, 1, 6, 4, Color(0.90, 0.75, 0.30)) # casing
	rect(img, 0, 1, 1, 4, Color(0.65, 0.50, 0.20)) # rim
	rect(img, 7, 1, 2, 4, Color(0.80, 0.50, 0.35)) # projectile
	px(img, 9, 2, Color(0.80, 0.50, 0.35))
	px(img, 9, 3, Color(0.80, 0.50, 0.35))
	# Highlight
	px(img, 3, 1, C.white)
	save_png(img, "bullet_minigun.png")


func create_bullet_sniper(C: Dictionary) -> void:
	var img := Image.create(16, 6, false, Image.FORMAT_RGBA8)
	img.fill(C.transparent)
	# .50 BMG Sniper Bullet: long brass casing, copper projectile with black armor-piercing tip
	rect(img, 1, 1, 10, 4, Color(0.90, 0.75, 0.30)) # casing
	rect(img, 0, 1, 1, 4, Color(0.65, 0.50, 0.20)) # rim
	rect(img, 11, 1, 4, 4, Color(0.75, 0.45, 0.30)) # bullet
	px(img, 15, 2, Color(0.15, 0.15, 0.20)) # AP black tip
	px(img, 15, 3, Color(0.15, 0.15, 0.20))
	# Highlights
	px(img, 4, 1, C.white)
	px(img, 12, 1, C.white)
	save_png(img, "bullet_sniper.png")


func create_bullet_missile(C: Dictionary) -> void:
	var img := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	img.fill(C.transparent)
	# RPG PG-7V Rocket: olive drab warhead tip, black stabilizer fins
	rect(img, 8, 2, 5, 4, Color(0.35, 0.45, 0.30)) # bulbous warhead base
	rect(img, 13, 1, 2, 6, Color(0.40, 0.50, 0.40)) # warhead tip
	px(img, 15, 3, Color(0.70, 0.70, 0.75)) # fuse tip
	px(img, 15, 4, Color(0.70, 0.70, 0.75))
	rect(img, 3, 3, 5, 2, Color(0.40, 0.40, 0.45)) # rocket body
	rect(img, 1, 2, 2, 4, Color(0.20, 0.20, 0.25)) # fins
	px(img, 0, 2, Color(0.20, 0.20, 0.25))
	px(img, 0, 5, Color(0.20, 0.20, 0.25))
	save_png(img, "bullet_missile.png")


func save_png(img: Image, name: String) -> void:
	var err := img.save_png("res://assets/sprites/" + name)
	if err != OK:
		push_error("Failed to save " + name + ": ", err)


func create_ground_tile(C: Dictionary) -> void:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(C.grass)

	for i in range(8):
		var x := (i * 7 + 3) % 16
		var y := (i * 5 + 1) % 16
		px(img, x, y, C.grass_dark)

	rect(img, 0, 0, 16, 1, C.grass_dark)
	rect(img, 0, 15, 16, 1, C.grass_dark)
	rect(img, 0, 0, 1, 16, C.grass_dark)
	rect(img, 15, 0, 1, 16, C.grass_dark)
	px(img, 0, 0, C.grass)

	var err := img.save_png("res://assets/tiles/ground.png")
	if err != OK:
		push_error("Failed to save ground.png: ", err)


func create_heart(C: Dictionary) -> void:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(C.transparent)

	for x in range(6, 8): px(img, x, 4, C.heart)
	for x in range(9, 11): px(img, x, 4, C.heart)
	for x in range(4, 8): px(img, x, 5, C.heart)
	for x in range(9, 13): px(img, x, 5, C.heart)
	for x in range(4, 13): px(img, x, 6, C.heart)
	for x in range(4, 13): px(img, x, 7, C.heart)
	for x in range(5, 12): px(img, x, 8, C.heart)
	for x in range(6, 11): px(img, x, 9, C.heart)
	for x in range(7, 10): px(img, x, 10, C.heart)
	px(img, 8, 11, C.heart)

	px(img, 6, 4, C.heart_dark)
	px(img, 7, 4, C.heart_dark)
	px(img, 9, 4, C.heart_dark)
	px(img, 10, 4, C.heart_dark)
	px(img, 8, 6, C.heart_dark)

	var err := img.save_png("res://assets/ui/heart.png")
	if err != OK:
		push_error("Failed to save heart.png: ", err)


func create_gun(C: Dictionary) -> void:
	var w: int = 24
	var h: int = 12
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(C.transparent)

	# Exaggerated huge body of the pistol
	rect(img, 3, 1, 18, 5, C.metal_dark)
	rect(img, 3, 2, 17, 3, C.metal)
	rect(img, 4, 2, 15, 1, C.metal_light)

	# Front and Rear Sights
	px(img, 3, 0, C.metal_dark)
	px(img, 19, 0, C.metal_dark)

	# Tiny Grip / Handle
	rect(img, 5, 6, 2, 5, C.mag_body)
	rect(img, 6, 7, 1, 4, C.wood)

	# Trigger Guard and Trigger
	px(img, 8, 6, C.metal)
	px(img, 9, 6, C.metal_dark)
	px(img, 9, 7, C.metal_dark)
	px(img, 8, 7, C.metal_dark)
	px(img, 7, 6, C.metal_light)

	# Giant orange/red muzzle tip!
	rect(img, 21, 1, 3, 5, Color(0.9, 0.4, 0.1))
	px(img, 21, 1, C.white)

	save_png(img, "gun.png")


func create_smg(C: Dictionary) -> void:
	var w: int = 24
	var h: int = 12
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(C.transparent)

	# Receiver (Main body, MP5-style)
	rect(img, 4, 2, 13, 5, C.metal_dark)
	rect(img, 5, 3, 11, 3, C.metal)

	# Handguard
	rect(img, 11, 5, 5, 3, C.mag_body)

	# Oversized loop front sight and barrel
	rect(img, 16, 3, 6, 3, C.metal_dark)
	px(img, 19, 2, C.metal_dark)

	# Gigantic banana magazine going way down!
	for i in range(7):
		rect(img, 9 + i/2, 7 + i, 2, 2, Color(0.1, 0.1, 0.12))

	# Pistol Grip
	rect(img, 5, 7, 2, 4, C.mag_body)
	px(img, 7, 7, C.metal_dark)

	# Oversized wobbly stock
	rect(img, 0, 3, 4, 4, C.mag_body)
	px(img, 0, 2, C.mag_body)

	save_png(img, "smg.png")


func create_shotgun(C: Dictionary) -> void:
	var img: Image = Image.create(28, 12, false, Image.FORMAT_RGBA8)
	img.fill(C.transparent)

	# Receiver
	rect(img, 7, 2, 10, 5, C.metal_dark)
	rect(img, 8, 3, 8, 3, C.metal)

	# Giant double barrel (top) and mag tube (bottom)
	rect(img, 17, 2, 11, 4, C.metal)
	rect(img, 17, 3, 11, 2, C.metal_light)

	# Giant wooden pump action slider
	rect(img, 12, 6, 8, 3, C.wood)
	rect(img, 13, 7, 6, 1, C.wood_dark)

	# Very wobbly curved wooden stock
	rect(img, 3, 3, 4, 4, C.wood)
	rect(img, 0, 4, 3, 4, C.wood_dark)
	px(img, 4, 2, C.wood)

	px(img, 6, 7, C.metal_dark)

	save_png(img, "shotgun.png")


func create_minigun(C: Dictionary) -> void:
	var img: Image = Image.create(28, 14, false, Image.FORMAT_RGBA8)
	img.fill(C.transparent)

	# Main receiver body
	rect(img, 3, 2, 10, 8, C.metal_dark)
	rect(img, 4, 3, 8, 6, C.metal)

	# Massive circular ammo drum (bottom loader)
	circle(img, 8, 10, 4, Color(0.12, 0.12, 0.15))
	circle(img, 8, 10, 2, C.metal_dark)

	# Handles at back
	rect(img, 1, 3, 2, 6, C.metal_dark)
	px(img, 0, 3, C.metal_dark)
	px(img, 0, 8, C.metal_dark)

	# 4 giant rotating barrels!
	rect(img, 13, 2, 15, 1, C.metal)
	rect(img, 13, 4, 15, 1, C.metal)
	rect(img, 13, 6, 15, 1, C.metal)
	rect(img, 13, 8, 15, 1, C.metal)

	# Giant clamp rings
	rect(img, 17, 1, 2, 9, C.metal_dark)
	rect(img, 24, 1, 2, 9, C.metal_dark)

	save_png(img, "minigun.png")


func create_sniper(C: Dictionary) -> void:
	var img: Image = Image.create(32, 10, false, Image.FORMAT_RGBA8)
	img.fill(C.transparent)

	# Receiver & Action
	rect(img, 7, 3, 11, 4, C.metal_dark)
	rect(img, 8, 4, 9, 2, C.metal)

	# Giant barrel going off-screen
	rect(img, 18, 3, 14, 3, C.metal)
	rect(img, 18, 4, 14, 1, C.metal_light)

	# Gigantic scope with glowing green laser lens!
	rect(img, 8, 0, 9, 3, C.scope)
	rect(img, 9, 1, 7, 1, Color(0.2, 0.9, 0.3))
	px(img, 9, 2, C.scope)
	px(img, 15, 2, C.scope)

	# Huge box mag
	rect(img, 10, 7, 3, 3, C.mag_body)

	# Stock
	var stock_green: Color = Color(0.2, 0.4, 0.25)
	var stock_dark: Color = Color(0.12, 0.25, 0.15)
	rect(img, 2, 4, 5, 3, stock_green)
	rect(img, 0, 4, 2, 4, stock_dark)
	px(img, 4, 5, C.transparent)

	# Bolt
	px(img, 7, 2, C.metal_light)

	save_png(img, "sniper.png")


func create_missile_launcher(C: Dictionary) -> void:
	var img: Image = Image.create(26, 12, false, Image.FORMAT_RGBA8)
	img.fill(C.transparent)

	# RPG-7 Tube
	rect(img, 4, 3, 15, 4, C.metal_dark)
	rect(img, 6, 3, 9, 4, C.wood)
	rect(img, 7, 4, 7, 1, C.wood_dark)

	# Giant exhaust bell
	rect(img, 0, 2, 4, 6, C.metal_dark)
	rect(img, 1, 3, 2, 4, C.metal)

	# Handgrips
	rect(img, 13, 7, 2, 4, C.wood_dark)
	rect(img, 7, 7, 1, 3, C.wood_dark)

	# Scope
	rect(img, 11, 1, 3, 2, C.scope)

	# Gigantic warhead loaded in front!
	rect(img, 19, 4, 3, 2, C.rocket_red)
	rect(img, 22, 3, 2, 6, Color(0.35, 0.45, 0.35))
	rect(img, 24, 2, 2, 8, Color(0.4, 0.5, 0.4))
	px(img, 25, 5, C.rocket_tip)

	save_png(img, "missile.png")

	save_png(img, "missile.png")


func write_wav(filepath: String, samples: PackedFloat32Array, sample_rate: int) -> void:
	var data_size := samples.size() * 2
	var file_size := 36 + data_size
	var header := PackedByteArray()
	header.resize(44)
	header.encode_u32(0, 0x46464952) # "RIFF"
	header.encode_u32(4, file_size)
	header.encode_u32(8, 0x45564157) # "WAVE"
	header.encode_u32(12, 0x20746d66) # "fmt "
	header.encode_u32(16, 16)
	header.encode_u16(20, 1) # AudioFormat (1 = PCM)
	header.encode_u16(22, 1) # NumChannels (1 = Mono)
	header.encode_u32(24, sample_rate)
	header.encode_u32(28, sample_rate * 2) # ByteRate
	header.encode_u16(32, 2) # BlockAlign
	header.encode_u16(34, 16) # BitsPerSample (16)
	header.encode_u32(36, 0x61746164) # "data"
	header.encode_u32(40, data_size)

	var file := FileAccess.open(filepath, FileAccess.WRITE)
	if file:
		file.store_buffer(header)
		var sbuf := PackedByteArray()
		sbuf.resize(data_size)
		for i in range(samples.size()):
			sbuf.encode_s16(i * 2, clampi(int(samples[i] * 32767.0), -32768, 32767))
		file.store_buffer(sbuf)
		file.close()
	else:
		push_error("Failed to write WAV file: ", filepath)


func write_wav_16(path: String, samples: PackedFloat32Array, sr: int) -> void:
	var data_size := samples.size() * 2
	var buf := PackedByteArray()
	buf.resize(44)
	buf.encode_u32(0, 0x46464952)
	buf.encode_u32(4, 36 + data_size)
	buf.encode_u32(8, 0x45564157)
	buf.encode_u32(12, 0x20746d66)
	buf.encode_u32(16, 16)
	buf.encode_u16(20, 1)
	buf.encode_u16(22, 1)
	buf.encode_u32(24, sr)
	buf.encode_u32(28, sr * 2)
	buf.encode_u16(32, 2)
	buf.encode_u16(34, 16)
	buf.encode_u32(36, 0x61746164)
	buf.encode_u32(40, data_size)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Failed to write: ", path)
		return
	file.store_buffer(buf)
	var sbuf := PackedByteArray()
	sbuf.resize(data_size)
	for i in range(samples.size()):
		sbuf.encode_s16(i * 2, clampi(int(samples[i] * 32767.0), -32768, 32767))
	file.store_buffer(sbuf)
	file.close()


func m2f(note: float) -> float:
	if note <= 0.0: return 0.0
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


func add_note_to_mix(mix: PackedFloat32Array, type: String, freq: float, start_sample: int, duration_samples: int, volume: float, sr: int, slide_to_freq: float = 0.0, vibrato_rate: float = 0.0, vibrato_depth: float = 0.0) -> void:
	var total_samples: int = mix.size()
	var phase: float = 0.0
	for i in range(duration_samples):
		var idx: int = start_sample + i
		if idx >= total_samples: break
		var t: float = float(i) / duration_samples
		
		# Compute frequency
		var cur_freq: float = freq
		if slide_to_freq > 0.0:
			var slide_t: float = minf(float(i) / (sr * 0.12), 1.0)
			cur_freq = lerpf(freq, slide_to_freq, slide_t)
		
		# Add vibrato LFO
		if vibrato_depth > 0.0:
			var lfo: float = sin(float(i) / sr * vibrato_rate * 2.0 * PI)
			cur_freq = cur_freq * (1.0 + lfo * vibrato_depth)
		
		# Update phase
		phase += cur_freq / sr
		
		# Generate wave shape
		var wave: float = 0.0
		if type == "sine":
			wave = sin(phase * 2.0 * PI)
		elif type == "triangle" or type == "bass":
			wave = abs(fmod(phase, 1.0) * 4.0 - 2.0) - 1.0
		elif type == "square" or type == "brass" or type == "square_lead":
			wave = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		elif type == "pulse_25":
			wave = 1.0 if fmod(phase, 1.0) < 0.25 else -1.0
		elif type == "noise":
			wave = randf() * 2.0 - 1.0
		
		# Apply envelope
		var env: float = 1.0
		if type == "marimba" or type == "pluck":
			env = exp(-t * 20.0)
			wave = abs(fmod(phase, 1.0) * 4.0 - 2.0) - 1.0 # triangle pluck
		elif type == "music_box":
			env = exp(-t * 10.0)
			wave = sin(phase * 2.0 * PI) # sine pluck
		elif type == "whistle":
			env = exp(-t * 6.0)
			wave = sin(phase * 2.0 * PI)
		elif type == "bass":
			env = exp(-t * 4.5)
		elif type == "soft_pad":
			if t < 0.2:
				env = t / 0.2
			else:
				env = (1.0 - t) / 0.8
		else:
			env = 1.0 - t
		
		# Tiny fade-in (5ms) to prevent clicks
		var fade_in: float = minf(float(i) / (sr * 0.005), 1.0)
		env *= fade_in
		
		mix[idx] += wave * env * volume


func add_drum_to_mix(mix: PackedFloat32Array, type: String, start_sample: int, volume: float, sr: int, spb: float) -> void:
	var total_samples: int = mix.size()
	var duration_samples: int = 0
	if type == "kick":
		duration_samples = int(sr * 0.15)
	elif type == "snare":
		duration_samples = int(sr * 0.20)
	elif type == "hat":
		duration_samples = int(sr * 0.05)
	elif type == "woodblock":
		duration_samples = int(sr * 0.08)
	
	var phase: float = 0.0
	for i in range(duration_samples):
		var idx: int = start_sample + i
		if idx >= total_samples: break
		var t: float = float(i) / duration_samples
		var wave: float = 0.0
		var env: float = 1.0
		
		if type == "kick":
			var freq: float = lerpf(150.0, 45.0, t)
			phase += freq / sr
			wave = sin(phase * 2.0 * PI)
			env = exp(-t * 15.0)
		elif type == "snare":
			var noise: float = randf() * 2.0 - 1.0
			var freq: float = 180.0
			phase += freq / sr
			var body: float = sin(phase * 2.0 * PI)
			wave = lerpf(body, noise, 0.7)
			env = exp(-t * 16.0)
		elif type == "hat":
			wave = randf() * 2.0 - 1.0
			env = exp(-t * 80.0)
		elif type == "woodblock":
			var phase1: float = float(i) * 850.0 / sr
			var phase2: float = float(i) * 600.0 / sr
			wave = sin(phase1 * 2.0 * PI) * 0.6 + sin(phase2 * 2.0 * PI) * 0.4
			env = exp(-t * 25.0)
			
		mix[idx] += wave * env * volume


func create_bgm() -> void:
	var samples_c1 := generate_combat_bgm_1()
	write_wav_16("res://assets/music/bgm_combat_1.wav", samples_c1, 22050)
	write_wav_16("res://assets/music/bgm.wav", samples_c1, 22050)
	
	var samples_c2 := generate_combat_bgm_2()
	write_wav_16("res://assets/music/bgm_combat_2.wav", samples_c2, 22050)
	
	var samples_c3 := generate_combat_bgm_3()
	write_wav_16("res://assets/music/bgm_combat_3.wav", samples_c3, 22050)


func create_bgm_extended() -> void:
	var samples := generate_combat_bgm_1()
	write_wav_16("res://assets/music/bgm_extended.wav", samples, 22050)


func create_intermission_bgm() -> void:
	var samples_l1 := generate_lobby_bgm_1()
	write_wav_16("res://assets/music/bgm_lobby_1.wav", samples_l1, 22050)
	write_wav_16("res://assets/music/intermission_bgm.wav", samples_l1, 22050)
	
	var samples_l2 := generate_lobby_bgm_2()
	write_wav_16("res://assets/music/bgm_lobby_2.wav", samples_l2, 22050)
	
	var samples_l3 := generate_lobby_bgm_3()
	write_wav_16("res://assets/music/bgm_lobby_3.wav", samples_l3, 22050)


func generate_combat_bgm_1() -> PackedFloat32Array:
	var sr: int = 22050
	var bpm: float = 132.0
	var spb: float = sr * 60.0 / bpm
	var bars: int = 16
	var beats: int = bars * 4
	var total: int = int(beats * spb)
	var step_dur: float = spb / 2.0

	var mix: PackedFloat32Array = PackedFloat32Array()
	mix.resize(total)
	mix.fill(0.0)

	for bar in range(16):
		var scale_notes: Array[int] = [45, 48, 52, 55]
		if bar in [4, 5]:
			scale_notes = [38, 41, 45, 48]
		elif bar in [8, 9]:
			scale_notes = [41, 45, 48, 52]
		elif bar in [10, 11]:
			scale_notes = [40, 44, 47, 50]
		elif bar == 15:
			scale_notes = [45, 47, 48, 50]
		
		for step in range(8):
			var abs_step: int = bar * 8 + step
			var start_sample: int = int(abs_step * step_dur)
			var note_val: int = scale_notes[step % scale_notes.size()]
			if step == 7 and bar != 15:
				note_val = scale_notes[0] - 1
			add_note_to_mix(mix, "bass", m2f(note_val), start_sample, int(step_dur * 0.9), 0.15, sr)

			if step % 2 == 1:
				var chord_notes: Array[int] = [57, 60, 64]
				if bar in [4, 5]:
					chord_notes = [50, 53, 57]
				elif bar in [8, 9]:
					chord_notes = [53, 57, 60]
				elif bar in [10, 11]:
					chord_notes = [52, 56, 59]
				
				for cn in chord_notes:
					add_note_to_mix(mix, "marimba", m2f(cn), start_sample, int(step_dur * 0.8), 0.08, sr)

	var lead_melody: Array = [
		[69, 0, 2], [72, 2, 2], [76, 4, 3], [79, 7, 1],
		[81, 8, 4], [79, 12, 4],
		[76, 16, 2], [74, 18, 2], [72, 20, 3], [74, 23, 1],
		[76, 24, 8],
		[74, 32, 2], [77, 34, 2], [81, 36, 3], [84, 39, 1],
		[86, 40, 4], [84, 44, 4],
		[81, 48, 2], [79, 50, 2], [76, 52, 3], [72, 55, 1],
		[69, 56, 8],
		[77, 64, 2], [81, 66, 2], [84, 68, 4],
		[76, 72, 2], [80, 74, 2], [83, 76, 4],
		[84, 80, 2], [83, 82, 2], [81, 84, 2], [80, 86, 2],
		[76, 88, 4], [72, 92, 4],
		[69, 96, 2], [72, 98, 2], [76, 100, 3], [79, 103, 1],
		[81, 104, 4], [86, 108, 4],
		[88, 112, 6], [84, 118, 2],
		[81, 120, 4], [76, 124, 4]
	]
	for note in lead_melody:
		var note_val: float = note[0] as float
		var start_step: int = note[1] as int
		var duration_steps: int = note[2] as int
		var start_sample: int = int(start_step * step_dur)
		var dur_samples: int = int(duration_steps * step_dur)
		var freq_start: float = m2f(note_val - 2.0)
		var freq_end: float = m2f(note_val)
		add_note_to_mix(mix, "whistle", freq_start, start_sample, dur_samples, 0.12, sr, freq_end, 6.5, 0.020)

	for bar in range(16):
		for step in range(8):
			var abs_step: int = bar * 8 + step
			var start_sample: int = int(abs_step * step_dur)
			
			if step == 0 or step == 4:
				add_drum_to_mix(mix, "kick", start_sample, 0.22, sr, spb)
			if step == 2 or step == 6:
				add_drum_to_mix(mix, "snare", start_sample, 0.18, sr, spb)
			if step % 2 == 1:
				add_drum_to_mix(mix, "hat", start_sample, 0.05, sr, spb)
			if step == 3 or step == 5:
				if bar % 2 == 1:
					add_drum_to_mix(mix, "woodblock", start_sample, 0.08, sr, spb)

	# Normalize
	var peak: float = 0.0
	for i in range(total):
		var val: float = abs(mix[i])
		if val > peak: peak = val
	if peak > 0.0:
		for i in range(total): mix[i] /= peak

	return mix


func generate_combat_bgm_2() -> PackedFloat32Array:
	var sr: int = 22050
	var bpm: float = 126.0
	var spb: float = sr * 60.0 / bpm
	var bars: int = 16
	var beats: int = bars * 4
	var total: int = int(beats * spb)
	var step_dur: float = spb / 2.0

	var mix: PackedFloat32Array = PackedFloat32Array()
	mix.resize(total)
	mix.fill(0.0)

	for bar in range(16):
		var root: int = 48
		var fifth: int = 43
		if bar in [4, 5, 6, 7, 14]:
			root = 43
			fifth = 38
		elif bar in [12, 13]:
			root = 41
			fifth = 48
		
		for step in range(8):
			var abs_step: int = bar * 8 + step
			var start_sample: int = int(abs_step * step_dur)
			
			if step % 2 == 0:
				var note_val: int = root if step in [0, 4] else fifth
				add_note_to_mix(mix, "bass", m2f(note_val), start_sample, int(step_dur * 1.8), 0.16, sr)

			if step % 2 == 1:
				var chord_notes: Array[int] = [52, 55, 60]
				if bar in [4, 5, 6, 7, 14]:
					chord_notes = [50, 55, 59]
				elif bar in [12, 13]:
					chord_notes = [53, 57, 60]
				
				for cn in chord_notes:
					add_note_to_mix(mix, "brass", m2f(cn), start_sample, int(step_dur * 0.8), 0.06, sr)

	var lead_melody: Array = [
		[76, 0, 1], [77, 1, 1], [79, 2, 2], [79, 4, 2], [76, 6, 2],
		[79, 8, 1], [81, 9, 1], [83, 10, 2], [83, 12, 2], [79, 14, 2],
		[84, 16, 2], [83, 18, 2], [81, 20, 2], [79, 22, 2],
		[77, 24, 2], [76, 26, 2], [74, 28, 4],
		
		[74, 32, 1], [76, 33, 1], [77, 34, 2], [77, 36, 2], [74, 38, 2],
		[77, 40, 1], [79, 41, 1], [81, 42, 2], [81, 44, 2], [77, 46, 2],
		[83, 48, 2], [81, 50, 2], [79, 52, 2], [77, 54, 2],
		[76, 56, 2], [77, 58, 2], [79, 60, 4],
		
		[76, 64, 2], [79, 66, 2], [84, 68, 4],
		[81, 72, 2], [84, 74, 2], [89, 76, 4],
		[88, 80, 2], [86, 82, 2], [84, 84, 2], [83, 86, 2],
		[84, 88, 4], [72, 92, 4],
		[74, 96, 2], [76, 98, 2], [77, 100, 4],
		[79, 104, 2], [81, 106, 2], [83, 108, 4],
		[84, 112, 4], [79, 116, 4],
		[84, 120, 8]
	]
	for note in lead_melody:
		var note_val: float = note[0] as float
		var start_step: int = note[1] as int
		var duration_steps: int = note[2] as int
		var start_sample: int = int(start_step * step_dur)
		var dur_samples: int = int(duration_steps * step_dur)
		var freq_start: float = m2f(note_val - 3.0)
		var freq_end: float = m2f(note_val)
		add_note_to_mix(mix, "square_lead", freq_start, start_sample, dur_samples, 0.08, sr, freq_end, 7.0, 0.010)

	for bar in range(16):
		for step in range(8):
			var abs_step: int = bar * 8 + step
			var start_sample: int = int(abs_step * step_dur)
			
			if step % 2 == 0:
				add_drum_to_mix(mix, "kick", start_sample, 0.20, sr, spb)
			if step == 2 or step == 6:
				add_drum_to_mix(mix, "snare", start_sample, 0.16, sr, spb)
			elif step == 7 and bar % 2 == 1:
				add_drum_to_mix(mix, "snare", start_sample, 0.10, sr, spb)
				add_drum_to_mix(mix, "snare", start_sample + int(step_dur * 0.5), 0.10, sr, spb)
			if step % 2 == 1:
				add_drum_to_mix(mix, "hat", start_sample, 0.05, sr, spb)

	# Normalize
	var peak: float = 0.0
	for i in range(total):
		var val: float = abs(mix[i])
		if val > peak: peak = val
	if peak > 0.0:
		for i in range(total): mix[i] /= peak

	return mix


func generate_combat_bgm_3() -> PackedFloat32Array:
	var sr: int = 22050
	var bpm: float = 120.0
	var spb: float = sr * 60.0 / bpm
	var bars: int = 16
	var beats: int = bars * 4
	var total: int = int(beats * spb)
	var step_dur: float = spb / 2.0

	var mix: PackedFloat32Array = PackedFloat32Array()
	mix.resize(total)
	mix.fill(0.0)

	for bar in range(16):
		var root: int = 38
		if bar in [4, 5]: root = 43
		elif bar in [8, 9]: root = 46
		elif bar in [10, 11]: root = 45
		
		for step in range(8):
			var abs_step: int = bar * 8 + step
			var start_sample: int = int(abs_step * step_dur)
			
			if step in [0, 3, 5]:
				add_note_to_mix(mix, "bass", m2f(root), start_sample, int(step_dur * 0.8), 0.18, sr)
			elif step == 6:
				add_note_to_mix(mix, "bass", m2f(root + 12), start_sample, int(step_dur * 0.4), 0.12, sr)

			if step == 2 or step == 6:
				var chord_notes: Array[int] = [50, 53, 57]
				if bar in [4, 5]: chord_notes = [55, 58, 62]
				elif bar in [8, 9]: chord_notes = [58, 62, 65]
				elif bar in [10, 11]: chord_notes = [57, 61, 64]
				
				for cn in chord_notes:
					add_note_to_mix(mix, "marimba", m2f(cn), start_sample, int(step_dur * 0.5), 0.07, sr)

	var lead_melody: Array = [
		[50, 0, 1], [53, 1, 1], [57, 2, 1], [62, 3, 1], [65, 4, 2], [62, 6, 2],
		[50, 8, 1], [53, 9, 1], [57, 10, 1], [62, 11, 1], [65, 12, 2], [67, 14, 2],
		[55, 16, 1], [58, 17, 1], [62, 18, 1], [67, 19, 1], [70, 20, 2], [67, 22, 2],
		[50, 24, 1], [53, 25, 1], [57, 26, 1], [62, 27, 1], [65, 28, 4],
		[58, 32, 2], [62, 34, 2], [65, 36, 4],
		[57, 40, 2], [61, 42, 2], [64, 44, 4],
		[62, 48, 1], [65, 49, 1], [69, 50, 1], [74, 51, 1], [77, 52, 4], [76, 56, 4], [74, 60, 4]
	]
	
	for i in range(2):
		var step_offset: int = i * 64
		for note in lead_melody:
			var note_val: float = (note[0] + 12) as float
			var start_step: int = (note[1] + step_offset) as int
			var duration_steps: int = note[2] as int
			var start_sample: int = int(start_step * step_dur)
			var dur_samples: int = int(duration_steps * step_dur)
			add_note_to_mix(mix, "marimba", m2f(note_val), start_sample, dur_samples, 0.10, sr)

	for bar in range(16):
		for step in range(8):
			var abs_step: int = bar * 8 + step
			var start_sample: int = int(abs_step * step_dur)
			
			if step == 0 or step == 3 or (step == 5 and bar % 2 == 1):
				add_drum_to_mix(mix, "kick", start_sample, 0.22, sr, spb)
			if step == 2 or step == 6:
				add_drum_to_mix(mix, "snare", start_sample, 0.18, sr, spb)
			if step % 2 == 1:
				add_drum_to_mix(mix, "hat", start_sample, 0.05, sr, spb)
			if step == 7:
				add_drum_to_mix(mix, "hat", start_sample + int(step_dur * 0.5), 0.04, sr, spb)
			if step == 4 and bar % 2 == 0:
				add_drum_to_mix(mix, "woodblock", start_sample, 0.08, sr, spb)

	# Normalize
	var peak: float = 0.0
	for i in range(total):
		var val: float = abs(mix[i])
		if val > peak: peak = val
	if peak > 0.0:
		for i in range(total): mix[i] /= peak

	return mix


func generate_lobby_bgm_1() -> PackedFloat32Array:
	var sr: int = 22050
	var bpm: float = 92.0
	var spb: float = sr * 60.0 / bpm
	var bars: int = 16
	var beats: int = bars * 4
	var total: int = int(beats * spb)
	var step_dur: float = spb / 2.0

	var mix: PackedFloat32Array = PackedFloat32Array()
	mix.resize(total)
	mix.fill(0.0)

	for bar in range(16):
		var root: int = 35
		if bar in [4, 5, 12, 13]: root = 40
		elif bar in [6, 7, 14, 15]: root = 42
		
		for step in range(8):
			var abs_step: int = bar * 8 + step
			var start_sample: int = int(abs_step * step_dur)
			
			if step == 0 or step == 4:
				add_note_to_mix(mix, "bass", m2f(root), start_sample, int(step_dur * 1.8), 0.18, sr)

			if step % 2 == 1:
				var cn_notes: Array[int] = [47, 50, 55]
				if bar in [4, 5, 12, 13]: cn_notes = [43, 48, 52]
				elif bar in [6, 7, 14, 15]: cn_notes = [45, 50, 54]
				
				var note_idx: int = step / 2
				var cn: int = cn_notes[note_idx % cn_notes.size()]
				add_note_to_mix(mix, "music_box", m2f(cn + 12), start_sample, int(step_dur * 1.5), 0.07, sr)

	var lead_melody: Array = [
		[59, 0, 4], [62, 4, 4], [67, 8, 6], [66, 14, 2],
		[64, 16, 4], [67, 20, 4], [62, 24, 8],
		[60, 32, 4], [64, 36, 4], [59, 40, 6], [62, 46, 2],
		[57, 48, 8], [55, 56, 8]
	]
	
	for i in range(2):
		var step_offset: int = i * 64
		for note in lead_melody:
			var note_val: float = (note[0] + 12) as float
			var start_step: int = (note[1] + step_offset) as int
			var duration_steps: int = note[2] as int
			var start_sample: int = int(start_step * step_dur)
			var dur_samples: int = int(duration_steps * step_dur)
			add_note_to_mix(mix, "whistle", m2f(note_val), start_sample, dur_samples, 0.10, sr, 0.0, 5.0, 0.015)

	for bar in range(16):
		for step in range(8):
			if step == 2 or step == 6:
				var abs_step: int = bar * 8 + step
				var start_sample: int = int(abs_step * step_dur)
				add_drum_to_mix(mix, "hat", start_sample, 0.02, sr, spb)

	# Normalize
	var peak: float = 0.0
	for i in range(total):
		var val: float = abs(mix[i])
		if val > peak: peak = val
	if peak > 0.0:
		for i in range(total): mix[i] /= peak

	return mix


func generate_lobby_bgm_2() -> PackedFloat32Array:
	var sr: int = 22050
	var bpm: float = 96.0
	var spb: float = sr * 60.0 / bpm
	var bars: int = 16
	var beats: int = bars * 4
	var total: int = int(beats * spb)
	var step_dur: float = spb / 2.0

	var mix: PackedFloat32Array = PackedFloat32Array()
	mix.resize(total)
	mix.fill(0.0)

	for bar in range(16):
		var scale: Array[int] = [33, 37, 40, 41]
		if bar in [4, 5]: scale = [38, 41, 45, 46]
		elif bar in [8, 9]: scale = [35, 38, 42, 43]
		
		for step in range(8):
			var abs_step: int = bar * 8 + step
			var start_sample: int = int(abs_step * step_dur)
			
			if step % 2 == 0:
				var note_idx: int = step / 2
				var note_val: int = scale[note_idx % scale.size()]
				add_note_to_mix(mix, "bass", m2f(note_val), start_sample, int(step_dur * 1.5), 0.16, sr)

			if step == 1 or step == 5:
				var chord: Array[int] = [45, 48, 53]
				if bar in [4, 5]: chord = [46, 50, 53]
				elif bar in [8, 9]: chord = [48, 52, 55]
				
				for cn in chord:
					add_note_to_mix(mix, "soft_pad", m2f(cn), start_sample, int(step_dur * 1.8), 0.06, sr)

	var lead_melody: Array = [
		[65, 0, 3], [69, 3, 1], [72, 4, 4],
		[70, 8, 3], [74, 11, 1], [77, 12, 4],
		[79, 16, 2], [77, 18, 2], [74, 20, 2], [72, 22, 2],
		[69, 24, 8],
		[67, 32, 3], [70, 35, 1], [72, 36, 4],
		[65, 40, 3], [69, 43, 1], [70, 44, 4],
		[64, 48, 4], [67, 52, 4], [65, 56, 8]
	]
	
	for i in range(2):
		var step_offset: int = i * 64
		for note in lead_melody:
			var note_val: float = note[0] as float
			var start_step: int = (note[1] + step_offset) as int
			var duration_steps: int = note[2] as int
			var start_sample: int = int(start_step * step_dur)
			var dur_samples: int = int(duration_steps * step_dur)
			add_note_to_mix(mix, "whistle", m2f(note_val), start_sample, dur_samples, 0.09, sr, 0.0, 5.5, 0.012)

	for bar in range(16):
		for step in range(8):
			var abs_step: int = bar * 8 + step
			var start_sample: int = int(abs_step * step_dur)
			
			if step % 2 == 0:
				add_drum_to_mix(mix, "hat", start_sample, 0.03, sr, spb)
				var swing_sample: int = start_sample + int(step_dur * 0.66)
				add_drum_to_mix(mix, "hat", swing_sample, 0.015, sr, spb)
			if step == 0:
				add_drum_to_mix(mix, "kick", start_sample, 0.12, sr, spb)

	# Normalize
	var peak: float = 0.0
	for i in range(total):
		var val: float = abs(mix[i])
		if val > peak: peak = val
	if peak > 0.0:
		for i in range(total): mix[i] /= peak

	return mix


func generate_lobby_bgm_3() -> PackedFloat32Array:
	var sr: int = 22050
	var bpm: float = 88.0
	var spb: float = sr * 60.0 / bpm
	var bars: int = 16
	var beats: int = bars * 4
	var total: int = int(beats * spb)
	var step_dur: float = spb / 2.0

	var mix: PackedFloat32Array = PackedFloat32Array()
	mix.resize(total)
	mix.fill(0.0)

	for bar in range(16):
		var root: int = 33
		if bar in [4, 5]: root = 29
		elif bar in [8, 9]: root = 31
		
		for step in range(8):
			var abs_step: int = bar * 8 + step
			var start_sample: int = int(abs_step * step_dur)
			
			if step == 0 or step == 4:
				add_note_to_mix(mix, "bass", m2f(root), start_sample, int(step_dur * 1.5), 0.15, sr)

			if step == 2 or step == 6:
				var chord: Array[int] = [45, 48, 52]
				if bar in [4, 5]: chord = [41, 45, 48]
				elif bar in [8, 9]: chord = [43, 47, 50]
				
				for cn in chord:
					add_note_to_mix(mix, "music_box", m2f(cn + 12), start_sample, int(step_dur * 1.2), 0.06, sr)

	var lead_melody: Array = [
		[69, 0, 2], [71, 2, 2], [72, 4, 4], [76, 8, 4], [74, 12, 4],
		[72, 16, 2], [71, 18, 2], [69, 20, 4], [67, 24, 4], [69, 28, 4],
		[69, 32, 2], [72, 34, 2], [77, 36, 4], [76, 40, 4], [72, 44, 4],
		[71, 48, 2], [74, 50, 2], [79, 52, 4], [77, 56, 4], [74, 60, 4]
	]
	
	for i in range(2):
		var step_offset: int = i * 64
		for note in lead_melody:
			var note_val: float = (note[0] + 12) as float
			var start_step: int = (note[1] + step_offset) as int
			var duration_steps: int = note[2] as int
			var start_sample: int = int(start_step * step_dur)
			var dur_samples: int = int(duration_steps * step_dur)
			add_note_to_mix(mix, "music_box", m2f(note_val), start_sample, dur_samples, 0.08, sr)

	for bar in range(16):
		for step in range(8):
			var abs_step: int = bar * 8 + step
			var start_sample: int = int(abs_step * step_dur)
			
			if step % 2 == 0:
				add_drum_to_mix(mix, "hat", start_sample, 0.03, sr, spb)
			if step == 4:
				add_drum_to_mix(mix, "woodblock", start_sample, 0.04, sr, spb)

	# Normalize
	var peak: float = 0.0
	for i in range(total):
		var val: float = abs(mix[i])
		if val > peak: peak = val
	if peak > 0.0:
		for i in range(total): mix[i] /= peak

	return mix



func generate_shoot_sound() -> PackedFloat32Array:
	var sr := 22050
	var dur := 0.15
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / n
		var freq: float = lerpf(1200.0, 100.0, t)
		ph += freq / sr
		var wave: float = abs(fmod(ph, 1.0) - 0.5) * 4.0 - 1.0
		var env: float = 1.0 - t
		s[i] = wave * env * 0.8
	return s


func generate_hit_sound() -> PackedFloat32Array:
	var sr := 22050
	var dur := 0.08
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / n
		var freq: float = lerpf(200.0, 60.0, t)
		ph += freq / sr
		var sine: float = sin(ph * TAU)
		var noise: float = randf_range(-1.0, 1.0)
		var wave: float = lerpf(sine, noise, 0.4)
		var env: float = exp(-t * 25.0)
		s[i] = wave * env * 0.7
	return s


func generate_explosion_sound() -> PackedFloat32Array:
	var sr := 22050
	var dur := 0.75
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph1: float = 0.0
	var ph2: float = 0.0
	for i in range(n):
		var t := float(i) / n
		var freq1: float = lerpf(90.0, 15.0, t * t)
		ph1 += freq1 / sr
		var wave1: float = sin(ph1 * TAU)
		var freq2: float = lerpf(240.0, 40.0, t)
		ph2 += freq2 / sr
		var wave2: float = abs(fmod(ph2, 1.0) - 0.5) * 4.0 - 1.0
		var noise: float = randf_range(-1.0, 1.0)
		var raw_wave: float = wave1 * 0.55 + wave2 * 0.2 + noise * lerpf(0.85, 0.05, t * 2.0)
		var env: float
		if t < 0.015:
			env = t / 0.015
		else:
			env = exp(-(t - 0.015) * 4.5)
		var sig: float = raw_wave * env * 1.95
		s[i] = clampf(sig, -0.98, 0.98)
	return s


func generate_game_over_sound() -> PackedFloat32Array:
	var sr := 22050
	var dur := 0.8
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / n
		var freq: float = 130.81
		if t < 0.2:
			freq = 261.63
		elif t < 0.4:
			freq = 196.00
		elif t < 0.6:
			freq = 155.56
		else:
			freq = 130.81
		ph += freq / sr
		var wave: float = 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
		var env: float = 1.0 - t
		s[i] = wave * env * 0.4
	return s


func create_sounds() -> void:
	write_wav("res://assets/sounds/shoot.wav", generate_shoot_sound(), 22050)
	write_wav("res://assets/sounds/hit.wav", generate_hit_sound(), 22050)
	write_wav("res://assets/sounds/explosion.wav", generate_explosion_sound(), 22050)
	write_wav("res://assets/sounds/game_over.wav", generate_game_over_sound(), 22050)
	write_wav("res://assets/sounds/hurt.wav", generate_hurt_sound(), 22050)
	write_wav("res://assets/sounds/pickup.wav", generate_pickup_sound(), 22050)
	write_wav("res://assets/sounds/heal.wav", generate_heal_sound(), 22050)
	write_wav("res://assets/sounds/smg.wav", generate_smg_sound(), 22050)
	write_wav("res://assets/sounds/kaching.wav", generate_kaching_sound(), 22050)
	write_wav("res://assets/sounds/pistol_shoot.wav", generate_pistol_sound(), 22050)
	write_wav("res://assets/sounds/shotgun_shoot.wav", generate_shotgun_sound(), 22050)
	write_wav("res://assets/sounds/minigun_shoot.wav", generate_minigun_sound(), 22050)
	write_wav("res://assets/sounds/sniper_shoot.wav", generate_sniper_sound(), 22050)
	write_wav("res://assets/sounds/missile_launch.wav", generate_missile_sound(), 22050)
	write_wav("res://assets/sounds/weapon_switch.wav", generate_weapon_switch_sound(), 22050)
	write_wav("res://assets/sounds/sniper_reload.wav", generate_sniper_reload_sound(), 22050)
	write_wav("res://assets/sounds/walk_step.wav", generate_walk_step_sound(), 22050)
	write_wav("res://assets/sounds/round_start.wav", generate_round_start_sound(), 22050)
	write_wav("res://assets/sounds/round_win.wav", generate_round_win_sound(), 22050)
	write_wav("res://assets/sounds/menu_nav.wav", generate_menu_nav_sound(), 22050)
	write_wav("res://assets/sounds/drum_tick.wav", generate_drum_tick_sound(), 22050)
	write_wav("res://assets/sounds/hitmarker.wav", generate_hitmarker_sound(), 22050)
	write_wav("res://assets/sounds/lock_on.wav", generate_lock_on_sound(), 22050)
	write_wav("res://assets/sounds/coin_tick.wav", generate_coin_tick_sound(), 22050)


func generate_pickup_sound() -> PackedFloat32Array:
	var sr := 22050
	var dur := 0.08
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / n
		var freq: float = lerpf(600.0, 1200.0, t)
		ph += freq / sr
		var wave: float = 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
		var env: float = 1.0 - t
		s[i] = wave * env * 0.3
	return s


func generate_hurt_sound() -> PackedFloat32Array:
	var sr := 22050
	var dur := 0.15
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / n
		var freq: float = lerpf(120.0, 60.0, t)
		ph += freq / sr
		var sine: float = sin(ph * TAU)
		var noise: float = randf_range(-1.0, 1.0)
		var wave: float = lerpf(sine, noise, 0.6)
		var env: float = 1.0 - t * t
		s[i] = wave * env * 0.6
	return s


func generate_heal_sound() -> PackedFloat32Array:
	var sr := 22050
	var dur := 0.3
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / n
		var freq: float
		if t < 0.25:
			freq = 523.25
		elif t < 0.5:
			freq = 659.25
		elif t < 0.75:
			freq = 783.99
		else:
			freq = 1046.5
		ph += freq / sr
		var wave: float = sin(ph * TAU)
		var env: float = 1.0 - t * t
		s[i] = wave * env * 0.4
	return s


func generate_smg_sound() -> PackedFloat32Array:
	# Punchy SMG: mechanical click + short body thump
	var sr := 22050
	var dur := 0.13
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph_mech: float = 0.0
	var ph_body: float = 0.0
	for i in range(n):
		var t := float(i) / n
		# Sharp mechanical click at start
		var click: float = 0.0
		if t < 0.012:
			var tc := t / 0.012
			ph_mech += 6500.0 / sr
			click = sin(ph_mech * TAU) * pow(1.0 - tc, 3.0) * 0.95
		# Body: freq sweep + noise blend
		var freq_body: float = lerpf(1800.0, 180.0, pow(t, 0.5))
		ph_body += freq_body / sr
		var wave: float = abs(fmod(ph_body, 1.0) - 0.5) * 4.0 - 1.0  # triangle
		var noise: float = randf_range(-1.0, 1.0)
		var body: float = lerpf(wave, noise, 0.35)
		# Envelope: fast snap
		var env: float = exp(-t * 28.0)
		var sig: float = body * env * 0.75 + click
		s[i] = clampf(sig, -0.98, 0.98)
	return s


func create_ui_icons() -> void:
	create_xbox_a()
	create_xbox_b()
	create_xbox_y()
	create_xbox_lb()
	create_xbox_rb()
	create_key_space()
	create_key_esc()
	create_key_tab()
	create_xbox_rt()
	create_mouse_lmb()
	create_key_wasd()
	create_key_q()
	create_key_e()
	create_xbox_ls()
	create_xbox_dpad()
	create_xbox_select()
	create_crosshair()
	create_heart_plus()
	create_ammo_icon()


func draw_shaded_circle_button(img: Image, color: Color) -> void:
	var border := Color.BLACK
	var shadow_color = color.lerp(Color.BLACK, 0.45)
	var highlight_color = color.lerp(Color.WHITE, 0.45)
	var body_color = color
	circle(img, 10, 10, 9, border)
	circle(img, 10, 10, 8, shadow_color)
	circle(img, 10, 9, 8, body_color)
	# draw light reflection highlight
	for x in range(-5, 6):
		for y in range(-5, 6):
			if x*x + y*y <= 25 and x < 1 and y < 1:
				px(img, 10 + x, 9 + y, highlight_color)
	circle(img, 10, 10, 6, body_color) # center body

func draw_shaded_keycap(img: Image, ix: int, iy: int, w: int, h: int, color: Color) -> void:
	var border := Color.BLACK
	var dark = color.lerp(Color.BLACK, 0.45)
	var lit = color.lerp(Color.WHITE, 0.45)
	var face = color
	# draw border outline
	for y in range(iy, iy + h):
		for x in range(ix, ix + w):
			var is_edge := (y == iy or y == iy + h - 1 or x == ix or x == ix + w - 1)
			if is_edge:
				px(img, x, y, border)
	# draw 3D bevel base side
	for y in range(iy + 1, iy + h - 1):
		for x in range(ix + 1, ix + w - 1):
			if y >= iy + h - 4:
				px(img, x, y, dark)
			elif y == iy + 1 or x == ix + 1 or x == ix + w - 2:
				px(img, x, y, lit)
			else:
				px(img, x, y, face)

func create_xbox_a() -> void:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	draw_shaded_circle_button(img, Color(0.06, 0.55, 0.02))
	var a_data := [
		[0, 0, 1, 1, 0],
		[0, 1, 0, 0, 1],
		[0, 1, 0, 0, 1],
		[0, 1, 1, 1, 1],
		[0, 1, 0, 0, 1],
		[0, 1, 0, 0, 1],
		[0, 1, 0, 0, 1],
	]
	for y in range(7):
		for x in range(5):
			if a_data[y][x]:
				px(img, 7 + x, 7 + y, Color.BLACK) # shadow
				px(img, 7 + x, 6 + y, Color.WHITE) # letter
	var e := img.save_png("res://assets/ui/xbox_a.png")
	if e != OK: push_error("xbox_a.png: ", e)

func create_xbox_b() -> void:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	draw_shaded_circle_button(img, Color(0.70, 0.10, 0.06))
	var b_data := [
		[0, 1, 1, 1, 0],
		[0, 1, 0, 0, 1],
		[0, 1, 1, 1, 0],
		[0, 1, 0, 0, 1],
		[0, 1, 1, 1, 0],
		[0, 1, 0, 0, 1],
		[0, 1, 1, 1, 0],
	]
	for y in range(7):
		for x in range(5):
			if b_data[y][x]:
				px(img, 7 + x, 7 + y, Color.BLACK)
				px(img, 7 + x, 6 + y, Color.WHITE)
	var e := img.save_png("res://assets/ui/xbox_b.png")
	if e != OK: push_error("xbox_b.png: ", e)

func create_xbox_y() -> void:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	draw_shaded_circle_button(img, Color(0.85, 0.70, 0.02))
	var y_pixels := [
		[7, 5], [13, 5],
		[8, 6], [12, 6],
		[9, 7], [11, 7],
		[10, 8], [10, 9], [10, 10], [10, 11]
	]
	for p in y_pixels:
		px(img, p[0], p[1] + 1, Color.BLACK)
		px(img, p[0], p[1], Color.WHITE)
	var e := img.save_png("res://assets/ui/xbox_y.png")
	if e != OK: push_error("xbox_y.png: ", e)

func create_xbox_lb() -> void:
	var img := Image.create(22, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	draw_shaded_keycap(img, 0, 0, 22, 10, Color(0.35, 0.35, 0.38))
	var lb_pixels := [
		[5, 2], [5, 3], [5, 4], [5, 5], [6, 5], [7, 5],
		[10, 2], [10, 3], [10, 4], [10, 5], [11, 2], [12, 2], [11, 4], [12, 4], [11, 5], [12, 5], [13, 3]
	]
	for p in lb_pixels:
		px(img, int(p[0]), int(p[1]) + 1, Color.BLACK)
		px(img, int(p[0]), int(p[1]), Color.WHITE)
	var e := img.save_png("res://assets/ui/xbox_lb.png")
	if e != OK: push_error("xbox_lb.png: ", e)

func create_xbox_rb() -> void:
	var img := Image.create(22, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	draw_shaded_keycap(img, 0, 0, 22, 10, Color(0.35, 0.35, 0.38))
	var rb_pixels := [
		[5, 2], [5, 3], [5, 4], [5, 5], [6, 2], [7, 2], [6, 4], [7, 4], [8, 3], [8, 5],
		[11, 2], [11, 3], [11, 4], [11, 5], [12, 2], [13, 2], [12, 4], [13, 4], [12, 5], [13, 5], [14, 3]
	]
	for p in rb_pixels:
		px(img, int(p[0]), int(p[1]) + 1, Color.BLACK)
		px(img, int(p[0]), int(p[1]), Color.WHITE)
	var e := img.save_png("res://assets/ui/xbox_rb.png")
	if e != OK: push_error("xbox_rb.png: ", e)

func create_key_q() -> void:
	var img := Image.create(16, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	draw_shaded_keycap(img, 0, 0, 16, 14, Color(0.36, 0.36, 0.40))
	var q_pixels := [
		[5, 4], [6, 4], [7, 4],
		[4, 5], [8, 5],
		[4, 6], [8, 6],
		[4, 7], [8, 7],
		[5, 8], [6, 8], [7, 8], [9, 9], [8, 8]
	]
	for p in q_pixels:
		px(img, p[0], p[1] + 1, Color.BLACK)
		px(img, p[0], p[1], Color.WHITE)
	var e := img.save_png("res://assets/ui/key_q.png")
	if e != OK: push_error("key_q.png: ", e)

func create_key_e() -> void:
	var img := Image.create(16, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	draw_shaded_keycap(img, 0, 0, 16, 14, Color(0.36, 0.36, 0.40))
	var e_pixels := [
		[5, 4], [6, 4], [7, 4],
		[5, 5],
		[5, 6], [6, 6], [7, 6],
		[5, 7],
		[5, 8], [6, 8], [7, 8]
	]
	for p in e_pixels:
		px(img, p[0], p[1] + 1, Color.BLACK)
		px(img, p[0], p[1], Color.WHITE)
	var e_err := img.save_png("res://assets/ui/key_e.png")
	if e_err != OK: push_error("key_e.png: ", e_err)

func create_key_esc() -> void:
	var img := Image.create(16, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	draw_shaded_keycap(img, 0, 0, 16, 14, Color(0.36, 0.36, 0.40))
	var esc := [
		[5, 4], [6, 4], [7, 4],
		[5, 5],
		[5, 6], [6, 6],
		[5, 7],
		[5, 8], [6, 8], [7, 8]
	]
	for p in esc:
		px(img, p[0], p[1] + 1, Color.BLACK)
		px(img, p[0], p[1], Color.WHITE)
	var e := img.save_png("res://assets/ui/key_esc.png")
	if e != OK: push_error("key_esc.png: ", e)

func create_xbox_dpad() -> void:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var dark := Color.BLACK
	var face := Color(0.32, 0.32, 0.35)
	# Outline cross
	for y in range(5, 15):
		for x in range(7, 13):
			px(img, x, y, dark)
	for y in range(7, 13):
		for x in range(5, 15):
			px(img, x, y, dark)
	# Body cross
	for y in range(6, 14):
		for x in range(8, 12):
			px(img, x, y, face)
	for y in range(8, 12):
		for x in range(6, 14):
			px(img, x, y, face)
	# Center dot highlight
	px(img, 9, 9, Color(0.5, 0.5, 0.53))
	px(img, 10, 10, Color(0.2, 0.2, 0.22))
	var e := img.save_png("res://assets/ui/xbox_dpad.png")
	if e != OK: push_error("xbox_dpad.png: ", e)

func create_xbox_select() -> void:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	draw_shaded_circle_button(img, Color(0.35, 0.35, 0.38))
	# Draw hamburger menu button (Start/Menu) - three horizontal lines
	for y in [7, 10, 13]:
		for x in range(6, 14):
			px(img, x, y + 1, Color.BLACK)
			px(img, x, y, Color.WHITE)
	var e := img.save_png("res://assets/ui/xbox_select.png")
	if e != OK: push_error("xbox_select.png: ", e)

	# Locked variant: red X overlay
	var il := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	il.fill(Color.TRANSPARENT)
	draw_shaded_circle_button(il, Color(0.35, 0.35, 0.38))
	for y in [7, 10, 13]:
		for x in range(6, 14):
			px(il, x, y + 1, Color.BLACK)
			px(il, x, y, Color.WHITE)
	var xcol := Color(0.9, 0.1, 0.1)
	for i in range(4, 14):
		px(il, i - 4 + 3, i - 4 + 3, xcol)
		px(il, 17 - (i - 4), i - 4 + 3, xcol)
		px(il, i - 4 + 4, i - 4 + 3, xcol)
		px(il, 16 - (i - 4), i - 4 + 3, xcol)
	var el := il.save_png("res://assets/ui/xbox_select_locked.png")
	if el != OK: push_error("xbox_select_locked.png: ", el)

func create_key_space() -> void:
	var img := Image.create(36, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	draw_shaded_keycap(img, 0, 0, 36, 14, Color(0.32, 0.32, 0.36))
	# Draw space bar outline accent in center
	for i in range(8, 28):
		px(img, i, 6, Color.BLACK)
		px(img, i, 5, Color.WHITE)
	var e := img.save_png("res://assets/ui/key_space.png")
	if e != OK: push_error("key_space.png: ", e)

func create_key_tab() -> void:
	var img := Image.create(24, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	draw_shaded_keycap(img, 0, 0, 24, 14, Color(0.36, 0.36, 0.40))
	# Arrow icon
	for y in range(4, 10):
		px(img, 10, y, Color.WHITE)
		px(img, 11, y, Color.BLACK)
	px(img, 12, 5, Color.WHITE)
	px(img, 13, 6, Color.WHITE)
	px(img, 12, 8, Color.WHITE)
	px(img, 13, 7, Color.WHITE)
	
	var il := Image.create(24, 14, false, Image.FORMAT_RGBA8)
	il.fill(Color.TRANSPARENT)
	draw_shaded_keycap(il, 0, 0, 24, 14, Color(0.36, 0.36, 0.40))
	var xcol := Color(0.9, 0.1, 0.1)
	for i in range(2, 10):
		px(il, 2 + i, 2 + i, xcol)
		px(il, 21 - i, 2 + i, xcol)
	var e := img.save_png("res://assets/ui/key_tab.png")
	if e != OK: push_error("key_tab.png: ", e)
	var el := il.save_png("res://assets/ui/key_tab_locked.png")
	if el != OK: push_error("key_tab_locked.png: ", el)

func create_xbox_rt() -> void:
	var img := Image.create(24, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var dark := Color.BLACK
	var lit := Color(0.50, 0.50, 0.55)
	var face := Color(0.35, 0.35, 0.38)
	for y in range(0, 12):
		var w := int(lerpf(20, 14, y / 11.0))
		var off := (24 - w) / 2
		for x in range(off, off + w):
			if y == 0 or y == 11 or x == off or x == off + w - 1:
				px(img, x, y, dark)
			elif y == 1 or y == 10:
				px(img, x, y, lit)
			else:
				px(img, x, y, face)
	# Draw "RT" text in the center of the trigger button face
	var r_pixels := [
		[8, 3], [9, 3], [10, 3],
		[8, 4], [10, 4],
		[8, 5], [9, 5], [10, 5],
		[8, 6], [9, 6],
		[8, 7], [10, 7],
		[8, 8], [10, 8]
	]
	var t_pixels := [
		[12, 3], [13, 3], [14, 3],
		[13, 4],
		[13, 5],
		[13, 6],
		[13, 7],
		[13, 8]
	]
	for p in r_pixels:
		px(img, p[0], p[1] + 1, Color.BLACK)
		px(img, p[0], p[1], Color.WHITE)
	for p in t_pixels:
		px(img, p[0], p[1] + 1, Color.BLACK)
		px(img, p[0], p[1], Color.WHITE)
	var e := img.save_png("res://assets/ui/xbox_rt.png")
	if e != OK: push_error("xbox_rt.png: ", e)

func create_mouse_lmb() -> void:
	var img := Image.create(18, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var dark := Color.BLACK
	var lit := Color(0.55, 0.55, 0.60)
	var face := Color(0.38, 0.38, 0.42)
	# Mouse button shape: rounded rect, slightly wider at top
	for y in range(0, 14):
		var row_face := y > 0 and y < 13
		for x in range(0, 18):
			var on_edge := y == 0 or y == 13 or x == 0 or x == 17
			if row_face and not on_edge:
				if y == 1 or y == 12 or x == 1 or x == 16:
					px(img, x, y, lit)
				else:
					px(img, x, y, face)
			elif on_edge:
				px(img, x, y, dark)
	# Highlight left mouse click part
	for y in range(2, 6):
		for x in range(2, 8):
			px(img, x, y, Color(0.2, 0.7, 1.0))
	var e := img.save_png("res://assets/ui/mouse_lmb.png")
	if e != OK: push_error("mouse_lmb.png: ", e)

func create_key_wasd() -> void:
	var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var face := Color(0.36, 0.36, 0.40)
	draw_shaded_keycap(img, 10, 0, 8, 8, face)
	draw_shaded_keycap(img, 0, 10, 8, 8, face)
	draw_shaded_keycap(img, 10, 10, 8, 8, face)
	draw_shaded_keycap(img, 20, 10, 8, 8, face)
	var W := [ [1,0,1], [1,0,1], [1,1,1], [1,0,1] ]
	for y in 4:
		for x in 3:
			if W[y][x]: px(img, 12+x, 2+y, Color.WHITE)
	var A := [ [0,1,1], [1,0,1], [1,1,1], [1,0,1] ]
	for y in 4:
		for x in 3:
			if A[y][x]: px(img, 2+x, 12+y, Color.WHITE)
	var S := [ [1,1,1], [1,0,0], [1,1,1], [1,1,1] ]
	for y in 4:
		for x in 3:
			if S[y][x]: px(img, 12+x, 12+y, Color.WHITE)
	var D := [ [1,1,0], [1,0,1], [1,0,1], [1,1,0] ]
	for y in 4:
		for x in 3:
			if D[y][x]: px(img, 22+x, 12+y, Color.WHITE)
	var e := img.save_png("res://assets/ui/key_wasd.png")
	if e != OK: push_error("key_wasd.png: ", e)

func create_xbox_ls() -> void:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	draw_shaded_circle_button(img, Color(0.35, 0.35, 0.38))
	# Draw "LS" in the center of the stick button
	var l_pixels := [
		[6, 6], [6, 7], [6, 8], [6, 9], [6, 10], [6, 11], [6, 12],
		[7, 12], [8, 12]
	]
	var s_pixels := [
		[10, 6], [11, 6], [12, 6],
		[10, 7],
		[10, 8],
		[10, 9], [11, 9], [12, 9],
		[12, 10],
		[12, 11],
		[10, 12], [11, 12], [12, 12]
	]
	for p in l_pixels:
		px(img, p[0], p[1] + 1, Color.BLACK)
		px(img, p[0], p[1], Color.WHITE)
	for p in s_pixels:
		px(img, p[0], p[1] + 1, Color.BLACK)
		px(img, p[0], p[1], Color.WHITE)
	var e := img.save_png("res://assets/ui/xbox_ls.png")
	if e != OK: push_error("xbox_ls.png: ", e)


func generate_kaching_sound() -> PackedFloat32Array:
	var sr := 22050
	var dur := 0.25
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var pa: float = 0.0
	var pb: float = 0.0
	for i in range(n):
		var t := float(i) / n
		if t < 0.1:
			pa += 1200.0 / sr
			pb += 800.0 / sr
		else:
			pa += 600.0 / sr
			pb += 450.0 / sr
		var sa: float = 1.0 if fmod(pa, 1.0) < 0.5 else -1.0
		var sb: float = 1.0 if fmod(pb, 1.0) < 0.5 else -1.0
		var wave: float = sa * 0.6 + sb * 0.4
		var env: float = 1.0 - t * t
		s[i] = wave * env * 0.25
	return s


func generate_pistol_sound() -> PackedFloat32Array:
	# Punchy pistol: sharp transient crack + sub-bass boom + tail
	var sr := 22050
	var dur := 0.32
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph_crack: float = 0.0
	var ph_body: float = 0.0
	var ph_sub: float = 0.0
	for i in range(n):
		var t := float(i) / n
		# Crack transient: high-freq noise burst in first 5ms
		var crack: float = 0.0
		if t < 0.018:
			var tc := t / 0.018
			crack = randf_range(-1.0, 1.0) * pow(1.0 - tc, 2.0) * 1.1
		# Mid-freq body: sawtooth sweep from 2200 -> 120 Hz
		var freq_body: float = lerpf(2200.0, 120.0, pow(t, 0.45))
		ph_body += freq_body / sr
		var body: float = abs(fmod(ph_body, 1.0) - 0.5) * 4.0 - 1.0
		# Sub-bass punch: sine 85 -> 30 Hz
		var freq_sub: float = lerpf(85.0, 30.0, t)
		ph_sub += freq_sub / sr
		var sub: float = sin(ph_sub * TAU)
		# Extra harmonic sparkle on the crack
		var freq_crack: float = lerpf(4000.0, 800.0, t)
		ph_crack += freq_crack / sr
		var sparkle: float = sin(ph_crack * TAU)
		# Blend
		var raw: float = (body * 0.45 + sub * 0.35 + sparkle * 0.2)
		# Envelope: sharp attack, moderate decay
		var env: float
		if t < 0.004:
			env = t / 0.004
		else:
			env = exp(-(t - 0.004) * 10.5)
		var sig: float = raw * env + crack
		s[i] = clampf(sig, -0.98, 0.98)
	return s


func generate_shotgun_sound() -> PackedFloat32Array:
	var sr := 22050
	var dur := 0.5
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph1: float = 0.0
	var ph2: float = 0.0
	for i in range(n):
		var t := float(i) / n
		var click: float = 0.0
		if t < 0.025:
			click = randf_range(-1.0, 1.0) * (1.0 - t / 0.025) * 0.35
		var freq1: float = lerpf(350.0, 35.0, t * t)
		ph1 += freq1 / sr
		var wave1: float = sin(ph1 * TAU)
		var freq2: float = lerpf(900.0, 120.0, t)
		ph2 += freq2 / sr
		var wave2: float = abs(fmod(ph2, 1.0) - 0.5) * 4.0 - 1.0
		var noise: float = randf_range(-1.0, 1.0)
		var raw_wave: float = wave1 * 0.6 + wave2 * 0.25 + noise * lerpf(0.85, 0.01, t * 3.0)
		var env: float
		if t < 0.004:
			env = t / 0.004
		else:
			env = exp(-(t - 0.004) * 5.5)
		var sig: float = (raw_wave * env + click) * 1.8
		s[i] = clampf(sig, -0.98, 0.98)
	return s


func generate_minigun_sound() -> PackedFloat32Array:
	var sr := 22050
	var dur := 0.09
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph1: float = 0.0
	var ph2: float = 0.0
	for i in range(n):
		var t := float(i) / n
		var click: float = 0.0
		if t < 0.012:
			click = sin(t * 14000.0) * (1.0 - t / 0.012) * 0.3
		var freq1: float = lerpf(2400.0, 500.0, t)
		ph1 += freq1 / sr
		var wave1: float = fmod(ph1, 1.0) * 2.0 - 1.0
		var freq2: float = freq1 * 0.5
		ph2 += freq2 / sr
		var wave2: float = sin(ph2 * TAU)
		var noise: float = randf_range(-1.0, 1.0)
		var raw_wave: float = wave1 * 0.45 + wave2 * 0.35 + noise * lerpf(0.35, 0.02, t * 7.0)
		var env: float = exp(-t * 20.0)
		s[i] = (raw_wave * env + click) * 0.92
	return s


func generate_sniper_sound() -> PackedFloat32Array:
	var sr := 22050
	var dur := 0.95
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph1: float = 0.0
	var ph2: float = 0.0
	var delay_size: int = int(sr * 0.14)
	var delay_buf: PackedFloat32Array = PackedFloat32Array()
	delay_buf.resize(delay_size)
	delay_buf.fill(0.0)
	var delay_ptr: int = 0
	var prev_delayed: float = 0.0
	for i in range(n):
		var t := float(i) / n
		var click: float = 0.0
		if t < 0.008:
			click = randf_range(-1.0, 1.0) * (1.0 - t / 0.008) * 0.5
		var freq1: float = lerpf(3500.0, 600.0, t)
		ph1 += freq1 / sr
		var wave1: float = sin(ph1 * TAU)
		var freq2: float = lerpf(600.0, 20.0, t * t)
		ph2 += freq2 / sr
		var wave2: float = sin(ph2 * TAU)
		var noise: float = randf_range(-1.0, 1.0)
		var raw_wave: float = wave1 * 0.25 + wave2 * 0.55 + noise * lerpf(0.75, 0.01, t * 2.5)
		var env: float
		if t < 0.004:
			env = t / 0.004
		else:
			env = exp(-(t - 0.004) * 8.0)
		var dry: float = (raw_wave * env + click) * 1.5
		dry = clampf(dry, -1.0, 1.0)
		var delayed: float = delay_buf[delay_ptr]
		var filtered_delayed: float = (delayed + prev_delayed) * 0.5
		prev_delayed = delayed
		delay_buf[delay_ptr] = dry + filtered_delayed * 0.48
		delay_ptr = (delay_ptr + 1) % delay_size
		var sig: float = dry * 0.7 + filtered_delayed * 0.45
		s[i] = clampf(sig, -0.98, 0.98)
	return s


func generate_missile_sound() -> PackedFloat32Array:
	var sr := 22050
	var dur := 0.45
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph1: float = 0.0
	var ph2: float = 0.0
	for i in range(n):
		var t := float(i) / n
		var freq1: float = lerpf(55.0, 320.0, t * t)
		ph1 += freq1 / sr
		var wave1: float = 1.0 if fmod(ph1, 1.0) < 0.5 else -1.0
		var freq2: float = lerpf(80.0, 800.0, t)
		ph2 += freq2 / sr
		var wave2: float = sin(ph2 * TAU)
		var noise: float = randf_range(-1.0, 1.0)
		var raw_wave: float = wave1 * 0.45 + wave2 * 0.2 + noise * lerpf(0.65, 0.2, t)
		var env: float
		if t < 0.025:
			env = t / 0.025
		else:
			env = exp(-(t - 0.025) * 4.0)
		s[i] = raw_wave * env * 0.95
	return s


func generate_weapon_switch_sound() -> PackedFloat32Array:
	var sr := 22050
	var dur := 0.22
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph_mech := 0.0
	for i in range(n):
		var t := float(i) / n
		
		# Double mechanical click-clack (metal slide sound)
		var click1 := 0.0
		if t < 0.04:
			var tc := t / 0.04
			ph_mech += 440.0 / sr
			click1 = sin(ph_mech * TAU) * exp(-tc * 6.0)
			
		var click2 := 0.0
		if t > 0.07 and t < 0.12:
			var tc := (t - 0.07) / 0.05
			ph_mech += 280.0 / sr
			click2 = sin(ph_mech * TAU) * exp(-tc * 8.0)
			
		# Low frequency impact thump
		var thump := sin(2.0 * PI * 80.0 * t) * exp(-t * 18.0) * 0.3
		
		var sig: float = (click1 + click2 * 0.7 + thump) * 0.7
		s[i] = clampf(sig, -0.98, 0.98)
	return s


func generate_sniper_reload_sound() -> PackedFloat32Array:
	var sr := 22050
	var dur := 0.35
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph1 := 0.0
	var ph2 := 0.0
	for i in range(n):
		var t := float(i) / n
		var val: float = 0.0
		if t < 0.06:
			ph1 += 1200.0 / sr
			var click: float = (1.0 if fmod(ph1, 1.0) < 0.3 else -0.3)
			val += click * (1.0 - t * 16.0) * 0.4
		if t > 0.2 and t < 0.28:
			var lt: float = (t - 0.2) / 0.08
			ph2 += 900.0 / sr
			val += sin(ph2 * TAU * 2.0) * (1.0 - lt) * 0.5
		s[i] = val
	return s


func create_crosshair() -> void:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var c := Color(1, 0.2, 0.2, 1)
	pt(img, 8, 2, c); pt(img, 8, 3, c)
	pt(img, 8, 12, c); pt(img, 8, 13, c)
	pt(img, 2, 8, c); pt(img, 3, 8, c)
	pt(img, 12, 8, c); pt(img, 13, 8, c)
	circle(img, 8, 8, 1, c)
	px(img, 8, 8, Color.WHITE)
	var e := img.save_png("res://assets/ui/crosshair.png")
	if e != OK: push_error("crosshair.png: ", e)


func pt(img: Image, x: int, y: int, c: Color) -> void:
	px(img, x, y, c)


func create_heart_plus() -> void:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var heart := Color(0.894, 0.000, 0.345)
	for x in range(6, 8): px(img, x, 4, heart)
	for x in range(9, 11): px(img, x, 4, heart)
	for x in range(4, 8): px(img, x, 5, heart)
	for x in range(9, 13): px(img, x, 5, heart)
	for x in range(4, 13): px(img, x, 6, heart)
	for x in range(4, 13): px(img, x, 7, heart)
	for x in range(5, 12): px(img, x, 8, heart)
	for x in range(6, 11): px(img, x, 9, heart)
	for x in range(7, 10): px(img, x, 10, heart)
	px(img, 8, 11, heart)
	var green := Color(0.2, 1, 0.2, 1)
	px(img, 12, 3, green); px(img, 13, 3, green)
	px(img, 12, 4, green); px(img, 13, 4, green)
	px(img, 11, 3, green); px(img, 11, 4, green)
	px(img, 14, 3, green); px(img, 14, 4, green)
	var e := img.save_png("res://assets/ui/heart_plus.png")
	if e != OK: push_error("heart_plus.png: ", e)


func create_ammo_icon() -> void:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var ammo := Color(0.9, 0.7, 0.3, 1)
	# 3 small bullets stacked
	for x in range(5, 8): px(img, x, 10, ammo)
	px(img, 5, 9, ammo); px(img, 5, 11, ammo)
	for x in range(6, 9): px(img, x, 7, ammo)
	px(img, 6, 6, ammo); px(img, 6, 8, ammo)
	for x in range(7, 10): px(img, x, 4, ammo)
	px(img, 7, 3, ammo); px(img, 7, 5, ammo)
	# tips
	px(img, 6, 9, Color(0.95, 0.85, 0.4, 1))
	px(img, 7, 6, Color(0.95, 0.85, 0.4, 1))
	px(img, 8, 3, Color(0.95, 0.85, 0.4, 1))
	var e := img.save_png("res://assets/ui/ammo_icon.png")
	if e != OK: push_error("ammo_icon.png: ", e)


# --- New SFX Functions ---

func generate_walk_step_sound() -> PackedFloat32Array:
	# Quick organic thump: muffled bass thud + soft click
	var sr := 22050
	var dur := 0.09
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph_thud: float = 0.0
	var ph_click: float = 0.0
	for i in range(n):
		var t := float(i) / n
		# Low thud: sine 200 -> 60 Hz
		var freq_thud: float = lerpf(200.0, 60.0, t)
		ph_thud += freq_thud / sr
		var thud: float = sin(ph_thud * TAU)
		# Surface click: short noise burst
		var click: float = 0.0
		if t < 0.015:
			var tc := t / 0.015
			ph_click += 3000.0 / sr
			click = sin(ph_click * TAU) * pow(1.0 - tc, 4.0) * 0.5
		# Envelope
		var env: float = exp(-t * 35.0)
		s[i] = clampf(thud * env * 0.55 + click, -0.98, 0.98)
	return s


func generate_round_start_sound() -> PackedFloat32Array:
	# Dramatic rising fanfare: ascending chord stab
	var sr := 22050
	var dur := 0.55
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	# Three-note chord stab: C4, E4, G4 = 261.63, 329.63, 392.00
	var freqs := [261.63, 329.63, 392.00, 523.25]
	var phases := [0.0, 0.0, 0.0, 0.0]
	for i in range(n):
		var t := float(i) / n
		var mix: float = 0.0
		for fi in range(freqs.size()):
			phases[fi] += freqs[fi] / sr
			var wave: float = sin(phases[fi] * TAU)
			# Delay onset for chord spread
			var onset: float = float(fi) * 0.03
			if t > onset:
				mix += wave * 0.25
		var env: float
		if t < 0.04:
			env = t / 0.04
		else:
			env = exp(-(t - 0.04) * 4.0)
		s[i] = clampf(mix * env, -0.98, 0.98)
	return s


func generate_round_win_sound() -> PackedFloat32Array:
	# Triumphant ascending jingle: 4 quick notes
	var sr := 22050
	var dur := 0.75
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	# Notes: C5, E5, G5, C6 with short gaps
	var note_freqs := [523.25, 659.25, 783.99, 1046.50]
	var note_starts := [0.0, 0.15, 0.30, 0.48]
	var note_dur := 0.22
	var ph := [0.0, 0.0, 0.0, 0.0]
	for i in range(n):
		var t := float(i) / n
		var mix: float = 0.0
		for ni in range(note_freqs.size()):
			var ns: float = note_starts[ni]
			if t >= ns and t < ns + note_dur:
				ph[ni] += note_freqs[ni] / sr
				var lt: float = (t - ns) / note_dur
				var env: float = (1.0 - lt) * sin(PI * lt)
				var wave: float = sin(ph[ni] * TAU)
				mix += wave * env * 0.35
		s[i] = clampf(mix, -0.98, 0.98)
	return s


func generate_menu_nav_sound() -> PackedFloat32Array:
	# Crisp UI click: short tick
	var sr := 22050
	var dur := 0.06
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph: float = 0.0
	for i in range(n):
		var t := float(i) / n
		ph += lerpf(1800.0, 600.0, t) / sr
		var wave: float = sin(ph * TAU)
		var env: float = exp(-t * 60.0)
		s[i] = clampf(wave * env * 0.65, -0.98, 0.98)
	return s


func generate_drum_tick_sound() -> PackedFloat32Array:
	# Snare-like drum tick for countdown roll
	var sr := 22050
	var dur := 0.12
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph_body: float = 0.0
	for i in range(n):
		var t := float(i) / n
		# Noise burst (snare top)
		var noise: float = randf_range(-1.0, 1.0)
		# Short body tone
		var freq_body: float = lerpf(350.0, 100.0, t)
		ph_body += freq_body / sr
		var body: float = sin(ph_body * TAU)
		# Blend
		var mix: float = noise * 0.6 + body * 0.4
		var env: float
		if t < 0.005:
			env = t / 0.005
		else:
			env = exp(-(t - 0.005) * 30.0)
		s[i] = clampf(mix * env * 0.8, -0.98, 0.98)
	return s


func generate_hitmarker_sound() -> PackedFloat32Array:
	var sr := 22050
	var dur := 0.05
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / n
		var freq := lerpf(2000.0, 1000.0, t)
		ph += freq / sr
		var wave := sin(ph * TAU)
		var env := exp(-t * 20.0)
		s[i] = wave * env * 0.4
	return s


func generate_lock_on_sound() -> PackedFloat32Array:
	var sr := 22050
	var dur := 0.12
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / n
		var freq := lerpf(880.0, 1760.0, t)
		ph += freq / sr
		var wave := sin(ph * TAU)
		var env := 1.0 - t
		if t < 0.01:
			env = t / 0.01
		s[i] = wave * env * 0.35
	return s


func generate_coin_tick_sound() -> PackedFloat32Array:
	var sr := 22050
	var dur := 0.1
	var n := int(sr * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph1 := 0.0
	var ph2 := 0.0
	for i in range(n):
		var t := float(i) / n
		ph1 += 2200.0 / sr
		ph2 += 3400.0 / sr
		var wave := sin(ph1 * TAU) * 0.5 + sin(ph2 * TAU) * 0.5
		var env := exp(-t * 15.0)
		s[i] = wave * env * 0.3
	return s

