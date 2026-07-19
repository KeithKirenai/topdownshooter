extends Node2D

var player: CharacterBody2D

func _ready() -> void:
	# Ensure it draws on top
	z_index = 5
	queue_redraw()

func _process(_delta: float) -> void:
	if player:
		queue_redraw()

func _draw() -> void:
	if not player or not is_instance_valid(player):
		return
		
	if player._menu_open():
		if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	else:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_HIDDEN:
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	# Draw passive shield bubble if equipped & active
	if player.passive_shield > 0:
		var pulse := 0.85 + sin(Time.get_ticks_msec() * 0.005) * 0.15
		var shield_color := Color(0.0, 0.75, 1.0, 0.12 * pulse)
		var border_color := Color(0.3, 0.9, 1.0, 0.75)
		
		draw_circle(Vector2.ZERO, 30.0, shield_color)
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 32, border_color, 1.5, true)
		
		var rot = Time.get_ticks_msec() * 0.001
		draw_arc(Vector2.ZERO, 32.0, rot, rot + PI * 0.6, 16, Color(0.0, 0.75, 1.0, 0.35), 1.0)
		draw_arc(Vector2.ZERO, 32.0, rot + PI, rot + PI * 1.6, 16, Color(0.0, 0.75, 1.0, 0.35), 1.0)

	var crosshair_pos: Vector2 = player.visual_crosshair_pos
	
	var ch_color := Color(0.1, 0.9, 1.0, 0.8)
	var _ch_radius := 6.0
	
	# Get current clip info to draw warnings
	var clip := 0
	var _reserve := 0
	if player.current_weapon_index < player.inventory.size():
		var entry = player.inventory[player.current_weapon_index]
		clip = entry[2]
		_reserve = entry[1]
	
	# Calculate velocity-based squash and stretch transform
	var speed: float = player.crosshair_velocity.length()
	var stretch_factor := 1.0 + clampf(speed * 0.0006, 0.0, 0.40)
	var velocity_dir: Vector2 = player.crosshair_velocity.normalized() if speed > 0.1 else Vector2.RIGHT
	
	# Draw the shapes in a transformed canvas coordinate system centered at crosshair_pos
	draw_set_transform(crosshair_pos, velocity_dir.angle(), Vector2(stretch_factor, 2.0 - stretch_factor))
	
	# Color-code standard clean crosshair based on state
	if player.is_reloading:
		ch_color = Color(1.0, 0.72, 0.15, 0.9) # Orange/yellow during reload
	elif clip == 0:
		ch_color = Color(1.0, 0.1, 0.1, 0.9) # Red when empty/warning
	else:
		ch_color = Color(0.1, 0.9, 1.0, 0.8) # Neon cyan when ready
		
	# Draw standard clean crosshair (circle + ticks)
	draw_circle(Vector2.ZERO, 2.0, ch_color)
	var tick_len := 4.0
	var tick_offset := 5.0
	draw_line(Vector2(-tick_offset, 0), Vector2(-tick_offset - tick_len, 0), ch_color, 1.5)
	draw_line(Vector2(tick_offset, 0), Vector2(tick_offset + tick_len, 0), ch_color, 1.5)
	draw_line(Vector2(0, -tick_offset), Vector2(0, -tick_offset - tick_len), ch_color, 1.5)
	draw_line(Vector2(0, tick_offset), Vector2(0, tick_offset + tick_len), ch_color, 1.5)
	
	# Reset the transform back to identity
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var aim_dir: Vector2 = player.get_aim_direction()
	var muzzle_pos: Vector2 = player.get_muzzle_local_position()

	if is_instance_valid(player.locked_enemy) and not player.locked_enemy.get("dying"):
		var to_enemy_local: Vector2 = player.locked_enemy.global_position - player.global_position
		
		var current_dist := 0.0
		var line_vec: Vector2 = to_enemy_local - muzzle_pos
		var line_vec_len: float = line_vec.length()
		var line_vec_dir: Vector2 = line_vec.normalized()
		var dot_length := 4.0
		var gap_length := 6.0
		var color_line := Color(1.0, 0.4, 0.0, 0.8)
		
		while current_dist < line_vec_len:
			var p1 = muzzle_pos + line_vec_dir * current_dist
			var p2 = muzzle_pos + line_vec_dir * min(current_dist + dot_length, line_vec_len)
			draw_line(p1, p2, color_line, 2.0)
			current_dist += dot_length + gap_length
			
		var time_scale = Time.get_ticks_msec() * 0.005
		var wiggle := sin(time_scale) * 2.0
		var radius := 24.0 + wiggle
		
		var enemy_pos: Vector2 = to_enemy_local
		var bracket_len := 8.0
		var bracket_color := Color(1.0, 0.2, 0.1, 0.9)
		
		draw_line(enemy_pos + Vector2(-radius, -radius), enemy_pos + Vector2(-radius + bracket_len, -radius), bracket_color, 2.0)
		draw_line(enemy_pos + Vector2(-radius, -radius), enemy_pos + Vector2(-radius, -radius + bracket_len), bracket_color, 2.0)
		
		draw_line(enemy_pos + Vector2(radius, -radius), enemy_pos + Vector2(radius - bracket_len, -radius), bracket_color, 2.0)
		draw_line(enemy_pos + Vector2(radius, -radius), enemy_pos + Vector2(radius, -radius + bracket_len), bracket_color, 2.0)
		
		draw_line(enemy_pos + Vector2(-radius, radius), enemy_pos + Vector2(-radius + bracket_len, radius), bracket_color, 2.0)
		draw_line(enemy_pos + Vector2(-radius, radius), enemy_pos + Vector2(-radius, radius - bracket_len), bracket_color, 2.0)
		
		draw_line(enemy_pos + Vector2(radius, radius), enemy_pos + Vector2(radius - bracket_len, radius), bracket_color, 2.0)
		draw_line(enemy_pos + Vector2(radius, radius), enemy_pos + Vector2(radius, radius - bracket_len), bracket_color, 2.0)
		
		draw_arc(enemy_pos, radius - 4.0, 0.0, TAU, 32, bracket_color, 1.5, true)
		draw_circle(enemy_pos, 2.0, bracket_color)

	if aim_dir.length() > 0.01:
		var line_length := 300.0
		var dot_length := 4.0
		var gap_length := 6.0
		var current_dist := 0.0
		var color := Color(1.0, 1.0, 1.0, 0.4)
		
		while current_dist < line_length:
			var p1 = muzzle_pos + aim_dir * current_dist
			var p2 = muzzle_pos + aim_dir * min(current_dist + dot_length, line_length)
			draw_line(p1, p2, color, 1.5)
			current_dist += dot_length + gap_length

	if player.muzzle_flash_time > 0.0:
		var flash_size := 14.0
		match player.weapon:
			"pistol": flash_size = 18.0
			"smg": flash_size = 20.0
			"shotgun": flash_size = 38.0
			"minigun": flash_size = 22.0
			"sniper": flash_size = 34.0
			"missile": flash_size = 44.0
			
		var outer_points := PackedVector2Array()
		var num_spikes := 10
		for i in range(num_spikes * 2):
			var angle := float(i) * PI / float(num_spikes)
			var r := (flash_size * 1.3) if i % 2 == 0 else (flash_size * 0.3)
			r *= randf_range(0.8, 1.2)
			outer_points.append(muzzle_pos + Vector2(cos(angle), sin(angle)) * r)
		draw_colored_polygon(outer_points, Color(1.0, 0.3, 0.0, 0.4))

		var star_points := PackedVector2Array()
		for i in range(num_spikes * 2):
			var angle := float(i) * PI / float(num_spikes)
			var r := flash_size if i % 2 == 0 else (flash_size * 0.45)
			r *= randf_range(0.9, 1.1)
			star_points.append(muzzle_pos + Vector2(cos(angle), sin(angle)) * r)
		draw_colored_polygon(star_points, Color(1.0, 0.6, 0.0, 0.95))
		
		var core_points := PackedVector2Array()
		for i in range(num_spikes * 2):
			var angle := float(i) * PI / float(num_spikes)
			var r := (flash_size * 0.55) if i % 2 == 0 else (flash_size * 0.25)
			core_points.append(muzzle_pos + Vector2(cos(angle), sin(angle)) * r)
		draw_colored_polygon(core_points, Color(1.0, 0.98, 0.7, 0.98))
		
		for s in range(4):
			var spark_angle := randf_range(0, TAU)
			var spark_dist := randf_range(flash_size * 0.8, flash_size * 1.5)
			var spark_pos: Vector2 = muzzle_pos + Vector2(cos(spark_angle), sin(spark_angle)) * spark_dist
			var spark_r := randf_range(2.0, 4.0)
			draw_circle(spark_pos, spark_r, Color(1.0, 0.8, 0.1, 0.9))

	# Dynamic, High-End Ammo UI centered below the player
	if player.current_weapon_index < player.inventory.size():
		var entry = player.inventory[player.current_weapon_index]
		var clip_max = WeaponDB.WEAPON_DATA.get(player.weapon, WeaponDB.WEAPON_DATA["pistol"]).get("clip_max", 1)
		
		# Supercell Style Segmented Ammo Display centered under player
		if entry.size() > 2:
			var clip_shown = roundi(player.visual_clip_count)
			var ratio = clampf(float(clip_shown) / float(clip_max), 0.0, 1.0)
			
			var num_segs = mini(clip_max, 8)
			var bar_w := 36.0
			var bar_h := 5.0
			var bar_x := -bar_w / 2.0
			var bar_y := 32.0
			var spacing := 2.0
			
			var seg_w = (bar_w - (spacing * (num_segs - 1))) / num_segs
			
			draw_rect(Rect2(bar_x - 2, bar_y - 2, bar_w + 4, bar_h + 4), Color(0.02, 0.04, 0.08, 0.65), true)
			
			var filled_segs := 0
			if player.is_reloading and player.reload_duration > 0.0:
				var progress := clampf((player.reload_duration - player.reload_timer) / player.reload_duration, 0.0, 1.0)
				filled_segs = roundi(progress * num_segs)
			else:
				if clip_max <= 8:
					filled_segs = clip_shown
				else:
					filled_segs = roundi(ratio * num_segs)
			
			var seg_color = Color(0.2, 0.85, 1.0, 0.9)
			if player.is_reloading:
				seg_color = Color(1.0, 0.72, 0.15, 0.9)
			elif clip_shown == 0:
				seg_color = Color(1.0, 0.25, 0.25, 0.95)
			elif ratio <= 0.33:
				seg_color = Color(1.0, 0.72, 0.22, 0.9)
				
			for i in range(num_segs):
				var seg_x = bar_x + i * (seg_w + spacing)
				var is_filled = i < filled_segs
				var c = seg_color if is_filled else Color(0.12, 0.15, 0.22, 0.6)
				draw_rect(Rect2(seg_x, bar_y, seg_w, bar_h), c, true)
				
				if is_filled:
					draw_rect(Rect2(seg_x, bar_y, seg_w, 1.5), Color(1.0, 1.0, 1.0, 0.45), true)

		# Gears of War Active Reload Timing Bar centered below segmented ammo
		if player.is_reloading and player.reload_duration > 0.0:
			var bar_w := 60.0
			var bar_h := 7.0
			var bar_x := -bar_w / 2.0
			var bar_y := 40.0
			
			# Draw outer border for visibility
			draw_rect(Rect2(bar_x - 2, bar_y - 2, bar_w + 4, bar_h + 4), Color(0.0, 0.0, 0.0, 0.85), true)
			
			# Draw background track
			var bg_color = Color(0.5, 0.1, 0.1, 0.8) if player.is_jammed else Color(0.08, 0.08, 0.12, 0.8)
			draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), bg_color, true)
			
			if not player.is_jammed:
				# Good zone: 0.32 to 0.70 progress
				var good_min := 0.32
				var good_max := 0.70
				var good_x = bar_x + good_min * bar_w
				var good_w = (good_max - good_min) * bar_w
				draw_rect(Rect2(good_x, bar_y, good_w, bar_h), Color(0.15, 0.65, 0.3, 0.6), true)
				
				# Perfect zone: 0.45 to 0.58 progress
				var perf_min := 0.45
				var perf_max := 0.58
				var perf_x = bar_x + perf_min * bar_w
				var perf_w = (perf_max - perf_min) * bar_w
				draw_rect(Rect2(perf_x, bar_y, perf_w, bar_h), Color(1.0, 0.85, 0.2, player.perfect_flash_opacity), true)
				draw_rect(Rect2(perf_x, bar_y, perf_w, bar_h), Color.WHITE, false, 1.0)
				
			# Moving indicator marker — thick white line
			var progress := clampf((player.reload_duration - player.reload_timer) / player.reload_duration, 0.0, 1.0)
			var ind_x = bar_x + progress * bar_w
			draw_line(Vector2(ind_x, bar_y - 3.0), Vector2(ind_x, bar_y + bar_h + 3.0), Color.WHITE, 2.5)
