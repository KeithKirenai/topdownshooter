## hud_combat.gd
## Handles all combat-phase UI: countdown, round complete, game over,
## combo display, coin fly animation, and confetti.
class_name HudCombat
extends RefCounted

var _hud_node: CanvasLayer
var _control:  Control

# Sound refs (set externally)
var snd_round_start: AudioStream
var snd_round_win:   AudioStream
var snd_drum_tick:   AudioStream
var snd_kaching:     AudioStream
var snd_coin_tick:   AudioStream

# Combo nodes
var _combo_container:    Control
var _combo_label:        Label
var _combo_hype_label:   Label
var _combo_progress_bar: ProgressBar
var _combo_tween:        Tween

signal coin_anim_finished()

# ===================================================================
# init
# ===================================================================
func init(hud: CanvasLayer, ctrl: Control) -> void:
	_hud_node = hud
	_control  = ctrl


# ===================================================================
# build_combo_widget — must be called once from HUD._ready
# ===================================================================
func build_combo_widget() -> void:
	_combo_container = Control.new()
	_combo_container.name         = "ComboContainer"
	_combo_container.anchor_left  = 1.0
	_combo_container.anchor_top   = 0.5
	_combo_container.anchor_right = 1.0
	_combo_container.anchor_bottom= 0.5
	_combo_container.position     = Vector2(-170, -58)
	_combo_container.hide()
	_control.add_child(_combo_container)

	# Glass card bg
	var combo_bg := Panel.new()
	combo_bg.name         = "ComboBg"
	combo_bg.size         = Vector2(268, 96)
	combo_bg.position     = Vector2(-134, -48)
	combo_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := HudUiKit.make_glass_panel(
			Color(0.09, 0.04, 0.02, 0.88),
			Color(1.0, 0.50, 0.12, 0.62), 12)
	style.shadow_color = Color(1.0, 0.38, 0.0, 0.32)
	style.shadow_size  = 14
	combo_bg.add_theme_stylebox_override("panel", style)
	_combo_container.add_child(combo_bg)
	HudUiKit.add_rim_highlight(combo_bg, 268, Color(1.0, 0.80, 0.32, 0.16))

	_combo_label = Label.new()
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.add_theme_font_size_override("font_size",      44)
	_combo_label.add_theme_color_override("font_color",         HudUiKit.C_CORAL)
	_combo_label.add_theme_color_override("font_outline_color", HudUiKit.C_OUTLINE)
	_combo_label.add_theme_constant_override("outline_size",    11)
	_combo_label.add_theme_color_override("font_shadow_color",  Color(1.0, 0.22, 0.0, 0.40))
	_combo_label.add_theme_constant_override("shadow_offset_x", 0)
	_combo_label.add_theme_constant_override("shadow_offset_y", 4)
	_combo_label.size         = Vector2(268, 54)
	_combo_label.position     = Vector2(-134, -27)
	_combo_label.pivot_offset = Vector2(134, 27)
	_combo_container.add_child(_combo_label)

	_combo_hype_label = Label.new()
	_combo_hype_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_hype_label.add_theme_font_size_override("font_size",      22)
	_combo_hype_label.add_theme_color_override("font_color",         HudUiKit.C_GOLD)
	_combo_hype_label.add_theme_color_override("font_outline_color", HudUiKit.C_OUTLINE)
	_combo_hype_label.add_theme_constant_override("outline_size",    6)
	_combo_hype_label.size         = Vector2(268, 30)
	_combo_hype_label.position     = Vector2(-134, 28)
	_combo_hype_label.pivot_offset = Vector2(134, 15)
	_combo_container.add_child(_combo_hype_label)

	_combo_progress_bar = ProgressBar.new()
	_combo_progress_bar.show_percentage = false
	_combo_progress_bar.size         = Vector2(208, 6)
	_combo_progress_bar.position     = Vector2(-104, 64)
	_combo_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = HudUiKit.C_CORAL
	fill_sb.corner_radius_top_left     = 3; fill_sb.corner_radius_top_right    = 3
	fill_sb.corner_radius_bottom_left  = 3; fill_sb.corner_radius_bottom_right = 3
	_combo_progress_bar.add_theme_stylebox_override("fill", fill_sb)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.14, 0.07, 0.05, 0.82)
	bg_sb.corner_radius_top_left     = 3; bg_sb.corner_radius_top_right    = 3
	bg_sb.corner_radius_bottom_left  = 3; bg_sb.corner_radius_bottom_right = 3
	_combo_progress_bar.add_theme_stylebox_override("background", bg_sb)
	_combo_container.add_child(_combo_progress_bar)


# ===================================================================
# show_combo
# ===================================================================
func show_combo(count: int, player_node) -> void:
	if not _combo_container:
		return
	_combo_container.show()
	_combo_label.text = "COMBO ×" + str(count)

	var hype:  String = ""
	var color: Color  = HudUiKit.C_GOLD
	if count >= 20:
		hype  = "APOCALYPTIC!!!"
		color = HudUiKit.C_LAVENDER
	elif count >= 15:
		hype  = "GODLIKE!!"
		color = HudUiKit.C_CYAN
	elif count >= 10:
		hype  = "SAVAGE!"
		color = HudUiKit.C_SUCCESS
	elif count >= 7:
		hype  = "UNSTOPPABLE"
		color = HudUiKit.C_CORAL
	elif count >= 4:
		hype  = "DOUBLE KILL!" if count == 4 else ("TRIPLE KILL!" if count <= 5 else "RAMPAGE!")
		color = HudUiKit.C_GOLD

	var t_ratio: float = float(min(count, 20)) / 20.0
	_combo_label.add_theme_color_override("font_color", HudUiKit.C_CORAL.lerp(color, t_ratio))
	_combo_hype_label.text = hype
	_combo_hype_label.add_theme_color_override("font_color", color)

	var combo_bg := _combo_container.get_node_or_null("ComboBg") as Panel
	if combo_bg:
		var new_style := HudUiKit.make_glass_panel(
				Color(0.09, 0.04, 0.02, 0.88),
				Color(color.r, color.g, color.b, 0.72), 12)
		new_style.shadow_color = Color(color.r * 0.6, color.g * 0.28, color.b * 0.08, 0.38)
		new_style.shadow_size  = 16
		combo_bg.add_theme_stylebox_override("panel", new_style)

	if _combo_tween and _combo_tween.is_valid():
		_combo_tween.kill()
	_combo_tween = _hud_node.create_tween().set_parallel(true) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	_combo_label.scale    = Vector2(1.62, 0.62)
	_combo_label.rotation = randf_range(-0.20, 0.20)
	_combo_tween.tween_property(_combo_label, "scale",    Vector2.ONE, 0.46)
	_combo_tween.tween_property(_combo_label, "rotation", 0.0,         0.46)

	if hype != "":
		_combo_hype_label.scale    = Vector2(1.55, 1.55)
		_combo_hype_label.rotation = randf_range(-0.28, 0.28)
		_combo_tween.tween_property(_combo_hype_label, "scale",    Vector2.ONE, 0.46)
		_combo_tween.tween_property(_combo_hype_label, "rotation", 0.0,         0.46)

	if player_node and "shake_intensity" in player_node:
		player_node.shake_intensity = clampf(
				player_node.shake_intensity + 0.12 * count, 0.0, 5.0)


# ===================================================================
# hide_combo
# ===================================================================
func hide_combo() -> void:
	if _combo_container:
		_combo_container.hide()


# ===================================================================
# update_combo_timer
# ===================================================================
func update_combo_timer(progress: float) -> void:
	if not _combo_progress_bar:
		return
	_combo_progress_bar.value = progress * 100.0
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(
		lerpf(0.20, 1.0,  1.0 - progress),
		lerpf(1.0,  0.14, 1.0 - progress),
		0.22, 1.0)
	fill_style.corner_radius_top_left     = 3; fill_style.corner_radius_top_right    = 3
	fill_style.corner_radius_bottom_left  = 3; fill_style.corner_radius_bottom_right = 3
	_combo_progress_bar.add_theme_stylebox_override("fill", fill_style)


# ===================================================================
# run_countdown — async; drives the 3-2-1-GO! sequence
# ===================================================================
func run_countdown(overlay: ColorRect, lbl: Label, heal_flash: ColorRect,
		round_idx: int, on_done: Callable, play_sfx: Callable) -> void:
	overlay.show()
	lbl.show()
	lbl.text = "Round " + str(round_idx)

	var count_colors: Array[Color] = [HudUiKit.C_DANGER, HudUiKit.C_GOLD, HudUiKit.C_SUCCESS]

	for i in range(3, 0, -1):
		var c_col: Color = count_colors[3 - i]
		lbl.text = str(i)
		lbl.add_theme_color_override("font_color", c_col)
		lbl.scale        = Vector2(1.65, 0.65)
		lbl.pivot_offset = lbl.size / 2
		var ct := _hud_node.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		ct.tween_property(lbl, "scale", Vector2.ONE, 0.60)
		play_sfx.call(snd_drum_tick, 0.0, 1.0 + float(3 - i) * 0.15)
		_spawn_countdown_ring(c_col)
		await _hud_node.get_tree().create_timer(1.0).timeout
		if not _hud_node.is_node_ready():
			return

	# GO!
	lbl.text = "GO!"
	lbl.add_theme_color_override("font_color", HudUiKit.C_GOLD_BRIGHT)
	lbl.scale = Vector2(1.85, 0.58)
	play_sfx.call(snd_round_start, 0.0)
	_spawn_countdown_ring(HudUiKit.C_GOLD_BRIGHT)

	heal_flash.color = Color(1.0, 0.96, 0.7, 0.30)
	var flash_t := _hud_node.create_tween()
	flash_t.tween_property(heal_flash, "color", Color(1.0, 0.96, 0.7, 0.0), 0.28)
	var go_t := _hud_node.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	go_t.tween_property(lbl, "scale", Vector2.ONE, 0.42)
	await _hud_node.get_tree().create_timer(0.36).timeout
	if not _hud_node.is_node_ready():
		return
	overlay.hide()
	lbl.hide()
	on_done.call()


# ===================================================================
# _spawn_countdown_ring
# ===================================================================
func _spawn_countdown_ring(col: Color) -> void:
	var vp: Vector2 = _hud_node.get_viewport().get_visible_rect().size
	for ring_i in range(2):
		var ring := ColorRect.new()
		var init_size := 24.0
		ring.size         = Vector2(init_size, init_size)
		ring.color        = Color(col.r, col.g, col.b, 0.0)
		ring.pivot_offset = Vector2(init_size / 2, init_size / 2)
		ring.position     = vp / 2.0 - Vector2(init_size / 2, init_size / 2)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_control.add_child(ring)
		var delay_val: float = float(ring_i) * 0.09
		var t := _hud_node.create_tween().set_parallel(true)
		t.tween_property(ring, "scale", Vector2(16.0, 16.0), 0.58) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_delay(delay_val)
		t.tween_property(ring, "modulate:a", 0.72,  0.08).set_delay(delay_val)
		t.tween_property(ring, "modulate:a", 0.0,   0.58) \
			.set_ease(Tween.EASE_IN).set_delay(delay_val + 0.06)
		t.chain().tween_callback(ring.queue_free)


# ===================================================================
# spawn_round_complete_confetti
# ===================================================================
func spawn_round_complete_confetti() -> void:
	var p := CPUParticles2D.new()
	p.emitting        = false
	p.amount          = 45
	p.lifetime        = 2.4
	p.one_shot        = true
	p.explosiveness   = 0.88
	p.spread          = 65.0
	p.direction       = Vector2(0, -1)
	p.gravity         = Vector2(0, 130)
	p.initial_velocity_min = 210.0
	p.initial_velocity_max = 440.0
	p.scale_amount_min     = 3.0
	p.scale_amount_max     = 8.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	var g := Gradient.new()
	g.set_color(0, HudUiKit.C_GOLD)
	g.add_point(0.33, HudUiKit.C_SUCCESS)
	g.add_point(0.66, HudUiKit.C_CYAN)
	g.set_color(1,    HudUiKit.C_GOLD_BRIGHT)
	p.color_ramp = g
	var vp: Vector2 = _hud_node.get_viewport().get_visible_rect().size
	p.position    = Vector2(vp.x / 2.0, vp.y / 2.0 - 55.0)
	_control.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


# ===================================================================
# play_coin_fly — 10 coin arc animation into the score icon
# ===================================================================
func play_coin_fly(score_icon: TextureRect, prize: int,
		prev_score: int, target_score: int,
		score_lbl: Label, pulse_fn: Callable, chink_fn: Callable) -> void:
	var dest_pos: Vector2 = score_icon.position + score_icon.size / 2.0
	var vp: Vector2       = _hud_node.get_viewport().get_visible_rect().size
	score_lbl.text = str(prev_score)

	for i in range(10):
		var coin := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color     = Color(1.0, 0.88, 0.10)
		style.border_width_left   = 2; style.border_width_right  = 2
		style.border_width_top    = 2; style.border_width_bottom = 2
		style.border_color = Color(0.78, 0.52, 0.0)
		style.corner_radius_top_left     = 9; style.corner_radius_top_right    = 9
		style.corner_radius_bottom_left  = 9; style.corner_radius_bottom_right = 9
		coin.add_theme_stylebox_override("panel", style)
		coin.size         = Vector2(18, 18)
		coin.pivot_offset = Vector2(9, 9)

		var start_pos: Vector2 = vp / 2.0 + Vector2(randf_range(-32, 32), randf_range(-32, 32))
		coin.position = start_pos
		coin.scale    = Vector2.ZERO
		_control.add_child(coin)

		var t := _hud_node.create_tween().set_parallel(true)
		var delay_val: float = 0.14 + float(i) * 0.07
		t.tween_property(coin, "scale", Vector2(1.3, 1.3), 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay_val)
		t.tween_method(func(val: float):
				coin.position = start_pos.lerp(dest_pos, val) + Vector2(0, -210.0 * sin(val * PI)),
				0.0, 1.0, 0.68) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT).set_delay(delay_val)
		t.tween_property(coin, "rotation", randf_range(2.5, 7.0) * PI, 0.68).set_delay(delay_val)

		var ci := i
		t.chain().tween_callback(func():
			coin.queue_free()
			chink_fn.call(ci)
			pulse_fn.call(float(prize) / 10.0)
			if ci == 9:
				score_lbl.text = str(target_score)
				coin_anim_finished.emit()
		)


# ===================================================================
# play_kaching
# ===================================================================
func play_kaching() -> void:
	if not snd_kaching:
		return
	var sp := AudioStreamPlayer.new()
	sp.bus = "Standard"
	sp.stream = snd_kaching
	_hud_node.add_child(sp)
	sp.play()
	sp.finished.connect(sp.queue_free)
