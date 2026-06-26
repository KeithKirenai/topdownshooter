extends CanvasLayer

var can_restart := false
var _kaching_sound := preload("res://assets/sounds/kaching.wav")
var _pulse_tween: Tween
var _card_selection_tween: Tween
var _card_entrance_tween: Tween
var _time: float = 0.0
var _active_hotbar_idx: int = 0
var _pause_panel: ColorRect
var _pause_label: Label
var _menu_nav_sound: AudioStream
var _round_start_sound: AudioStream
var _round_win_sound: AudioStream
var _drum_tick_sound: AudioStream
var _drum_roll_active: bool = false

var _combo_container: Control
var _combo_label: Label
var _combo_hype_label: Label
var _combo_progress_bar: ProgressBar
var _combo_tween: Tween

var _hotbar_bg: Panel
var _hotbar_slots: Array[ColorRect] = []

# Autohide and transition animation variables
var _hud_hide_timer := 0.0
var _hearts_hide_timer := 0.0
var _weapon_desc_timer := 0.0
var _last_weapon_name := ""

var _hud_container_offset := 0.0 # Score/Coins slide-in offset
var _hearts_container_offset := 0.0 # Hearts slide-in offset
var _weapon_desc_anim_progress := 0.0 # For bouncy letter layout

var _hud_target_opacity := 0.0
var _hearts_target_opacity := 0.0
var _weapon_desc_opacity := 0.0
var _animating_coins := false
var _displayed_score := 0
var _weapon_textures := {
	"pistol": preload("res://assets/sprites/gun.png"),
	"smg": preload("res://assets/sprites/smg.png"),
	"shotgun": preload("res://assets/sprites/shotgun.png"),
	"minigun": preload("res://assets/sprites/minigun.png"),
	"sniper": preload("res://assets/sprites/sniper.png"),
	"missile": preload("res://assets/sprites/missile.png"),
	"heart": preload("res://assets/ui/heart.png"),
	"heart_plus": preload("res://assets/ui/heart_plus.png"),
	"laser": preload("res://assets/ui/crosshair.png"),
	"ammo": preload("res://assets/ui/ammo_icon.png"),
}

var _shop_items := [
	{"name": "SMG", "price": 20, "key": "smg", "type": "weapon", "icon": "smg"},
	{"name": "Shotgun", "price": 40, "key": "shotgun", "type": "weapon", "icon": "shotgun"},
	{"name": "Minigun", "price": 75, "key": "minigun", "type": "weapon", "icon": "minigun"},
	{"name": "Sniper", "price": 50, "key": "sniper", "type": "weapon", "icon": "sniper"},
	{"name": "Missile", "price": 90, "key": "missile", "type": "weapon", "icon": "missile"},
	{"name": "Ammo", "price": 10, "key": "ammo", "type": "refill", "icon": "ammo"},
	{"name": "Heal", "price": 5, "key": "heal", "type": "heal", "icon": "heart"},
	{"name": "+HP", "price": 25, "key": "extend_heart", "type": "upgrade2", "icon": "heart_plus"},
]
var _shop_purchased: Dictionary = {}
var _shop_cards: Array[ColorRect] = []
var _shop_borders: Array[ColorRect] = []
var shop_selection := 0
var SHOP_COLS := 3
var SHOP_ROWS := 3

var _weapon_desc_bg: Panel
var _weapon_desc_lbl: RichTextLabel
var _weapon_details := {
	"pistol": {
		"name": "Pistol",
		"desc": "Standard backup sidearm. Infinite ammo.",
		"damage": "2 DMG",
		"color": Color(0.8, 0.8, 0.8)
	},
	"smg": {
		"name": "SMG",
		"desc": "Rapid-fire submachine gun. Fast but inaccurate.",
		"damage": "1 DMG",
		"color": Color(0.4, 0.8, 1.0)
	},
	"shotgun": {
		"name": "Shotgun",
		"desc": "Short-range burst. Fires 8 spreading pellets.",
		"damage": "1 DMG x 8",
		"color": Color(1.0, 0.6, 0.2)
	},
	"minigun": {
		"name": "Minigun",
		"desc": "Extreme fire rate. Accuracy decays as you fire.",
		"damage": "1 DMG",
		"color": Color(1.0, 0.4, 0.4)
	},
	"sniper": {
		"name": "Sniper Rifle",
		"desc": "Armor-piercing rail shot. Pierces all enemies in path.",
		"damage": "30 DMG (Piercing)",
		"color": Color(0.2, 0.6, 1.0)
	},
	"missile": {
		"name": "Missile Launcher",
		"desc": "Fires explosive rockets. Large splash radius.",
		"damage": "5 direct + 15 splash DMG",
		"color": Color(0.8, 0.2, 1.0)
	}
}


func update_score(val: int) -> void:
	if not _animating_coins:
		_displayed_score = val
		var label := $Control/ScoreLabel
		label.text = str(val)
		var tween := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "scale", Vector2(1.15, 1.15), 0.1)
		tween.tween_property(label, "scale", Vector2(1, 1), 0.2)
	_hud_hide_timer = 2.0


func flash_heal() -> void:
	var flash := $Control/HealFlash
	flash.color = Color(0, 1, 0.2, 0.3)
	var tween := create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "color", Color(0, 1, 0.2, 0), 0.35)
	_hearts_hide_timer = 2.0


func show_shop() -> void:
	_toggle_weapon_desc(false)
	var main: Node = get_tree().current_scene
	var coins: int = main.score if main else 0
	$Control/ShopPanel/ShopCoins.text = "Coins: " + str(coins)
	$Control/ShopPanel.show()
	$Control/ShopPanel/ShopPrompt.text = "[center]  " + _close_icon() + " Close  |  " + _confirm_icon() + " Buy  |  Arrows " + _leftright_icon() + " Navigate[/center]"
	shop_selection = 0
	_build_shop_cards()
	_highlight_shop_selection()


func show_title() -> void:
	_toggle_weapon_desc(false)
	_last_weapon_name = ""
	$Control/TitlePanel/SubtitleLabel.text = _random_subtitle()
	$Control/TitlePanel/TitlePrompt.text = "[center]" + _confirm_icon() + "  Press to Start[/center]"
	var ctrl := $Control/TitlePanel/ControlsLabel
	ctrl.text = ("[center]" + _move_icon() + "  Move    " + _shoot_icon() + "  Shoot    "
		+ _switch_prev_icon() + _switch_next_icon() + "  Switch    " + _shop_locked_icon() + "  Shop[/center]")
	$Control/TitlePanel.show()
	var prompt := $Control/TitlePanel/TitlePrompt
	prompt.modulate = Color(1, 1, 1, 1)
	var tween := create_tween().set_loops().set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(prompt, "modulate:a", 0.4, 0.6)
	tween.tween_property(prompt, "modulate:a", 1.0, 0.6)


func hide_title() -> void:
	_toggle_weapon_desc(true)
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	$Control/TitlePanel.hide()


func hide_shop() -> void:
	_toggle_weapon_desc(true)
	_stop_selection_pulse()
	$Control/ShopPanel.hide()


func handle_shop_confirm() -> bool:
	var main := get_tree().current_scene as Node
	if not main:
		return false
	if shop_selection < 0 or shop_selection >= _shop_items.size():
		return false
	var item = _shop_items[shop_selection]
	var key: String = item.key
	if _shop_purchased.get(key, false):
		return false
	var bought := false
	match item.type:
		"weapon":
			if main.has_method("buy_" + key):
				if main.call("buy_" + key):
					_shop_purchased[key] = true
					bought = true
		"upgrade":
			if main.has_method("buy_" + key):
				if main.call("buy_" + key):
					_shop_purchased[key] = true
					bought = true
		"upgrade2":
			if main.has_method("buy_" + key):
				if main.call("buy_" + key):
					_shop_purchased[key] = true
					bought = true
		"refill":
			if main.buy_ammo():
				bought = true
		"heal":
			if main.buy_heal():
				bought = true
	if bought:
		_update_shop_coins(main.score)
		_highlight_shop_selection()
		play_kaching()
		return true
	return false


func navigate_shop(event: InputEvent) -> void:
	var total := _shop_items.size()
	if event.is_action_pressed("move_left"):
		shop_selection = wrapi(shop_selection - 1, 0, total)
	elif event.is_action_pressed("move_right"):
		shop_selection = wrapi(shop_selection + 1, 0, total)
	elif event.is_action_pressed("move_up"):
		shop_selection = wrapi(shop_selection - SHOP_COLS, 0, total)
	elif event.is_action_pressed("move_down"):
		shop_selection = wrapi(shop_selection + SHOP_COLS, 0, total)
	_highlight_shop_selection()
	_play_sfx(_menu_nav_sound, -2.0)


func _highlight_shop_selection() -> void:
	var main := get_tree().current_scene
	var coins: int = main.score if main else 0
	for i in range(_shop_items.size()):
		var item = _shop_items[i]
		var card := _shop_cards[i] as ColorRect
		var border := _shop_borders[i] as ColorRect
		var key: String = item.key
		var price: int = item.price
		var affordable: bool = coins >= price
		var owned: bool = _shop_purchased.get(key, false)
		var status_lbl := card.get_node_or_null("StatusLabel") as Label

		border.visible = (i == shop_selection)
		border.modulate = Color.WHITE

		if owned:
			card.modulate = Color(0.4, 0.4, 0.4, 0.5)
			if status_lbl:
				status_lbl.text = "✓"
				status_lbl.add_theme_color_override("font_color", Color(0.3, 1, 0.3, 1))
		elif not affordable:
			card.modulate = Color(0.45, 0.45, 0.48, 0.5)
			if status_lbl:
				status_lbl.text = "✗"
				status_lbl.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 1))
		else:
			card.modulate = Color.WHITE
			if status_lbl:
				status_lbl.text = ""
	_start_selection_pulse()


func _start_selection_pulse() -> void:
	_stop_selection_pulse()
	if shop_selection < 0 or shop_selection >= _shop_borders.size():
		return
	var border := _shop_borders[shop_selection]
	if not border or not border.visible:
		return
	_pulse_tween = create_tween().set_loops().set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(border, "modulate:a", 0.5, 0.6)
	_pulse_tween.tween_property(border, "modulate:a", 1.0, 0.6)

	var card := _shop_cards[shop_selection]
	if card:
		card.scale = Vector2(1.25, 0.8) # Squash wide
		_card_entrance_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		_card_entrance_tween.tween_property(card, "scale", Vector2(1.08, 1.08), 0.4)
		_card_entrance_tween.finished.connect(func():
			if is_instance_valid(card) and shop_selection >= 0 and shop_selection < _shop_cards.size() and _shop_cards[shop_selection] == card:
				_card_selection_tween = create_tween().set_loops().set_ease(Tween.EASE_IN_OUT)
				_card_selection_tween.tween_property(card, "scale", Vector2(1.08, 1.08), 0.5)
				_card_selection_tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.5)
		)


func _stop_selection_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	if _card_selection_tween and _card_selection_tween.is_valid():
		_card_selection_tween.kill()
	_card_selection_tween = null
	if _card_entrance_tween and _card_entrance_tween.is_valid():
		_card_entrance_tween.kill()
	_card_entrance_tween = null
	for c in _shop_cards:
		if is_instance_valid(c):
			c.scale = Vector2(1, 1)


func _update_shop_coins(coins: int) -> void:
	$Control/ShopPanel/ShopCoins.text = "Coins: " + str(coins)


func _build_shop_cards() -> void:
	_clear_shop_cards()
	var panel := $Control/ShopPanel
	var card_w := 200
	var card_h := 120
	var gap_x := 30
	var gap_y := 20
	var start_x := 95
	var start_y := 110
	var cols := SHOP_COLS

	for i in range(_shop_items.size()):
		var row := i / cols
		var col := i % cols
		var x := start_x + col * (card_w + gap_x)
		var y := start_y + row * (card_h + gap_y)

		var border := ColorRect.new()
		border.size = Vector2(card_w + 4, card_h + 4)
		border.position = Vector2(x - 2, y - 2)
		border.color = Color(0.2, 0.6, 1.0, 1.0)
		border.pivot_offset = border.size / 2
		border.visible = false
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shop_borders.append(border)
		panel.add_child(border)

		var card := ColorRect.new()
		card.size = Vector2(card_w, card_h)
		card.position = Vector2(x, y)
		card.color = Color(0.12, 0.12, 0.16, 0.85)
		card.pivot_offset = card.size / 2
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shop_cards.append(card)
		panel.add_child(card)

		var item = _shop_items[i]
		var icon_tex: Texture2D = _weapon_textures.get(item.icon) if item.icon else null
		if icon_tex:
			var icon_rect := TextureRect.new()
			icon_rect.texture = icon_tex
			icon_rect.size = Vector2(64, 64)
			icon_rect.position = Vector2(float(card_w) / 2.0 - 32.0, 10.0)
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(icon_rect)

		var name_lbl := Label.new()
		name_lbl.text = item.name
		name_lbl.size = Vector2(card_w, 20)
		name_lbl.position = Vector2(0, 76)
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(name_lbl)

		var price_lbl := Label.new()
		price_lbl.text = str(item.price)
		price_lbl.size = Vector2(card_w, 16)
		price_lbl.position = Vector2(0, 94)
		price_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
		price_lbl.add_theme_font_size_override("font_size", 12)
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(price_lbl)

		var status_lbl := Label.new()
		status_lbl.name = "StatusLabel"
		status_lbl.size = Vector2(24, 24)
		status_lbl.position = Vector2(card_w - 28, 4)
		status_lbl.add_theme_font_size_override("font_size", 18)
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(status_lbl)


func _clear_shop_cards() -> void:
	for c in _shop_cards:
		c.queue_free()
	for b in _shop_borders:
		b.queue_free()
	_shop_cards.clear()
	_shop_borders.clear()


func play_kaching() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = _kaching_sound
	add_child(player)
	player.play()
	await player.finished
	player.queue_free()


func update_health(val: int, max_val: int = 3) -> void:
	var hearts_node := $Control/Hearts
	while hearts_node.get_child_count() < max_val:
		var hr := TextureRect.new()
		hr.texture = preload("res://assets/ui/heart.png")
		hr.custom_minimum_size = Vector2(64, 64)
		hr.size = Vector2(64, 64)
		hr.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		hr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hr.pivot_offset = Vector2(32, 32)
		hr.set_meta("active", true)
		hearts_node.add_child(hr)
	while hearts_node.get_child_count() > max_val:
		hearts_node.get_child(hearts_node.get_child_count() - 1).queue_free()
	for i in range(hearts_node.get_child_count()):
		var heart := hearts_node.get_child(i) as TextureRect
		heart.pivot_offset = Vector2(32, 32)
		var was_active = heart.get_meta("active", true)
		var is_active = i < val
		heart.set_meta("active", is_active)
		if i < val:
			heart.modulate = Color.WHITE
		else:
			heart.modulate = Color(0.3, 0.3, 0.3, 0.4)
		
		if was_active != is_active:
			var tween := heart.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
			heart.scale = Vector2(1.6, 1.6) if is_active else Vector2(0.4, 0.4)
			heart.rotation = randf_range(-0.3, 0.3)
			tween.tween_property(heart, "scale", Vector2.ONE, 0.45)
			tween.parallel().tween_property(heart, "rotation", 0.0, 0.45)
	_hearts_hide_timer = 2.0


func show_intermission(round_idx: int) -> void:
	$Control/RoundLabel.text = ""
	$Control/EnemyCountLabel.text = ""
	$Control/RoundCompletePanel.hide()
	$Control/RoundCompleteLabel.hide()
	$Control/PrizeLabel.hide()
	$Control/IntermissionPrompt.text = "[center][font_size=32]" + _confirm_icon() + "  Start Round " + str(round_idx) + "    " + _shop_icon() + "  Shop[/font_size][/center]"
	$Control/IntermissionPrompt.show()
	hide_gameplay_prompt()


func show_countdown(round_idx: int) -> void:
	hide_shop()
	$Control/RoundCompletePanel.hide()
	$Control/RoundCompleteLabel.hide()
	$Control/PrizeLabel.hide()
	$Control/IntermissionPrompt.hide()
	$Control/CountdownOverlay.show()
	$Control/CountdownLabel.show()
	$Control/CountdownLabel.text = "Round " + str(round_idx)
	var main: Node = get_tree().current_scene
	if not main or not main.has_method("_on_countdown_done"):
		return
	# Drum roll: accelerating ticks before each count
	_drum_roll_active = true
	for i in range(3, 0, -1):
		$Control/CountdownLabel.text = str(i)
		$Control/CountdownLabel.scale = Vector2(1.3, 1.3)
		var count_tween := create_tween().set_ease(Tween.EASE_OUT)
		count_tween.tween_property($Control/CountdownLabel, "scale", Vector2(1, 1), 0.8)
		_play_sfx(_drum_tick_sound, 0.0, 1.0 + float(3 - i) * 0.15)
		await get_tree().create_timer(1.0).timeout
		if not is_node_ready():
			return
	_drum_roll_active = false
	$Control/CountdownLabel.text = "GO!"
	$Control/CountdownLabel.scale = Vector2(1.5, 1.5)
	_play_sfx(_round_start_sound, 0.0)
	var go_tween := create_tween().set_ease(Tween.EASE_OUT)
	go_tween.tween_property($Control/CountdownLabel, "scale", Vector2(0.8, 0.8), 0.3)
	await get_tree().create_timer(0.3).timeout
	if not is_node_ready():
		return
	$Control/CountdownOverlay.hide()
	$Control/CountdownLabel.hide()
	main._on_countdown_done()


func show_round_active(round_idx: int, count: int) -> void:
	$Control/RoundCompletePanel.hide()
	$Control/RoundCompleteLabel.hide()
	$Control/PrizeLabel.hide()
	$Control/IntermissionPrompt.hide()
	$Control/RoundLabel.text = "Round " + str(round_idx)
	update_enemies_remaining(count)
	show_gameplay_prompt()


func update_enemies_remaining(count: int) -> void:
	$Control/EnemyCountLabel.text = "Enemies: " + str(count)


func show_lock_on_msg() -> void:
	# Satisfying lock beep message / lock overlay
	var main := get_tree().current_scene
	if main:
		var p = main.get_node_or_null("Player")
		if p:
			# Visual message can be pushed, or we just play sound via player (done in player.gd)
			pass

func _play_coin_chink(index: int) -> void:
	var asp := AudioStreamPlayer.new()
	asp.stream = preload("res://assets/sounds/coin_tick.wav")
	asp.pitch_scale = 1.0 + float(index) * 0.06
	asp.volume_db = -8.0
	add_child(asp)
	asp.play()
	asp.finished.connect(asp.queue_free)

func _pulse_score_label(amount: float) -> void:
	var main: Node = get_tree().current_scene
	if not main: return
	var target_score: int = main.get("score") if "score" in main else 0
	var score_lbl := $Control/ScoreLabel as Label
	if score_lbl:
		var current_val := int(score_lbl.text)
		var next_val: int = int(min(current_val + int(amount), target_score))
		score_lbl.text = str(next_val)
		score_lbl.pivot_offset = score_lbl.size / 2.0
		var tween := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_property(score_lbl, "scale", Vector2(1.25, 1.25), 0.08)
		tween.tween_property(score_lbl, "scale", Vector2(1.0, 1.0), 0.12)

func show_round_complete(round_idx: int, prize: int) -> void:
	$Control/RoundLabel.text = ""
	$Control/EnemyCountLabel.text = ""
	$Control/RoundCompleteLabel.text = "Round " + str(round_idx) + " Complete!"
	$Control/PrizeLabel.text = "+" + str(prize) + " coins"
	$Control/RoundCompletePanel.show()
	$Control/RoundCompleteLabel.show()
	$Control/PrizeLabel.show()
	hide_gameplay_prompt()
	_play_sfx(_round_win_sound, 0.0)

	var main: Node = get_tree().current_scene
	var target_score: int = main.get("score") if main and "score" in main else 0
	var prev_score: int = target_score - prize
	$Control/ScoreLabel.text = str(prev_score)
	_displayed_score = prev_score
	_animating_coins = true
	_hud_hide_timer = 3.5
	_hearts_hide_timer = 3.5

	var score_icon: TextureRect = $Control/ScoreIcon as TextureRect
	var dest_pos: Vector2 = score_icon.position + score_icon.size / 2.0

	for i in range(8):
		var coin := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.85, 0.1) # gold yellow
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0, 0, 0) # black outline
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		coin.add_theme_stylebox_override("panel", style)
		coin.size = Vector2(16, 16)
		coin.pivot_offset = Vector2(8, 8)

		var start_pos: Vector2 = Vector2(640, 360) + Vector2(randf_range(-25, 25), randf_range(-25, 25))
		coin.position = start_pos
		coin.scale = Vector2.ZERO
		$Control.add_child(coin)

		var t := create_tween().set_parallel(true)
		var delay_val: float = 0.2 + float(i) * 0.08
		t.tween_property(coin, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay_val)
		t.tween_method(func(val: float): coin.position = start_pos.lerp(dest_pos, val) + Vector2(0, -180.0 * sin(val * PI)), 0.0, 1.0, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT).set_delay(delay_val)
		t.tween_property(coin, "rotation", randf_range(2.0, 6.0) * PI, 0.65).set_delay(delay_val)
		
		# Set up completion callbacks in chain
		t.chain().tween_callback(func():
			coin.queue_free()
			_play_coin_chink(i)
			_pulse_score_label(float(prize) / 8.0)
			if i == 7:
				_animating_coins = false
				$Control/ScoreLabel.text = str(target_score)
				_displayed_score = target_score
		)


func show_game_over() -> void:
	_toggle_weapon_desc(false)
	can_restart = false
	hide_shop()
	hide_gameplay_prompt()
	$Control/RoundLabel.text = ""
	$Control/EnemyCountLabel.text = ""
	$Control/CountdownOverlay.hide()
	$Control/CountdownLabel.hide()
	$Control/RoundCompletePanel.hide()
	$Control/RoundCompleteLabel.hide()
	$Control/PrizeLabel.hide()
	$Control/IntermissionPrompt.hide()
	$Control/GameOverBg.show()
	var label := $Control/GameOverLabel
	label.show()
	label.modulate = Color(1, 0.2, 0.2, 0)
	label.scale = Vector2(0.5, 0.5)
	var tween := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", Color(1, 0.2, 0.2, 1), 0.6)
	tween.parallel().tween_property(label, "scale", Vector2(1, 1), 0.6)
	await tween.finished
	var main: Node = get_tree().current_scene
	if main and main.has_method("add_score"):
		$Control/FinalScoreLabel.text = "Score: " + str(main.score)
		$Control/FinalScoreLabel.show()
	await get_tree().create_timer(0.8).timeout
	show_restart_prompt()


func show_restart_prompt() -> void:
	var prompt := $Control/RestartPrompt
	prompt.text = "[center][font_size=32]" + _confirm_icon() + "  Press to restart[/font_size][/center]"
	prompt.show()
	prompt.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(prompt, "modulate", Color.WHITE, 0.3)
	await tween.finished
	can_restart = true


func handle_game_over_input(event: InputEvent) -> void:
	if not can_restart:
		return
	if event.is_action_pressed("confirm"):
		get_tree().reload_current_scene()


func show_gameplay_prompt() -> void:
	var p := $Control/GameplayPrompt
	p.text = "[font_size=28]" + _move_icon() + "  Move\n" + _shoot_icon() + "  Shoot\n" + _switch_prev_icon() + _switch_next_icon() + "  Switch\n" + _shop_locked_icon() + "  Shop[/font_size]"
	p.show()


func hide_gameplay_prompt() -> void:
	$Control/GameplayPrompt.hide()


func _is_gamepad() -> bool:
	return Input.get_connected_joypads().size() > 0


func _icon(icon_name: String) -> String:
	return _icon_tag(icon_name) + "res://assets/ui/" + icon_name + "[/img]"


func _confirm_icon() -> String:
	return _icon("xbox_a.png" if _is_gamepad() else "key_space.png")


func _close_icon() -> String:
	return _icon("xbox_b.png" if _is_gamepad() else "key_esc.png")


func _move_icon() -> String:
	return _icon("xbox_ls.png" if _is_gamepad() else "key_wasd.png")


func _shoot_icon() -> String:
	return _icon("xbox_rt.png" if _is_gamepad() else "mouse_lmb.png")


func _interact_icon() -> String:
	return _icon("xbox_a.png" if _is_gamepad() else "key_space.png")


func _shop_icon() -> String:
	return _icon("xbox_select.png" if _is_gamepad() else "key_tab.png")


func _shop_locked_icon() -> String:
	return _icon("xbox_select_locked.png" if _is_gamepad() else "key_tab_locked.png")


func _leftright_icon() -> String:
	return _icon("xbox_dpad.png" if _is_gamepad() else "key_wasd.png")


func _switch_prev_icon() -> String:
	return _icon("xbox_lb.png" if _is_gamepad() else "key_q.png")


func _switch_next_icon() -> String:
	return _icon("xbox_rb.png" if _is_gamepad() else "key_e.png")


func _icon_tag(icon_name: String) -> String:
	match icon_name:
		"xbox_a.png": return "[img=36x36]"
		"xbox_b.png": return "[img=36x36]"
		"key_space.png": return "[img=64x28]"
		"key_esc.png": return "[img=36x28]"
		"key_tab.png": return "[img=44x28]"
		"key_tab_locked.png": return "[img=44x28]"
		"xbox_rt.png": return "[img=40x24]"
		"mouse_lmb.png": return "[img=36x28]"
		"xbox_ls.png": return "[img=36x36]"
		"xbox_dpad.png": return "[img=36x36]"
		"xbox_select.png": return "[img=36x36]"
		"xbox_select_locked.png": return "[img=36x36]"
		"key_wasd.png": return "[img=56x56]"
		"key_q.png": return "[img=36x28]"
		"key_e.png": return "[img=36x28]"
		"xbox_y.png": return "[img=36x36]"
		"xbox_lb.png": return "[img=44x20]"
		"xbox_rb.png": return "[img=44x20]"
	return "[img=36x36]"


var _subtitle_list := [
	"Probably Not a War Crime",
	"Chibi Mayhem",
	"Bullet? I Hardly Know Her",
	"Pew Pew Pew",
	"It's a Shooter in 2D",
	"Top-Down. Bottom-Up. Sideways.",
	"No Microtransactions (Yet)",
	"Touch Grass Edition",
	"Keyboard Not Included",
	"Rated P for Pew",
	"Explosions Sold Separately",
	"Please Aim at the Enemies",
	"Sorry About the Balance",
	"I Made This in Godot",
	"Bullets: Not Just for Breakfast",
	"The Pistol is Free",
	"The Konami Code Does Nothing",
]

func _random_subtitle() -> String:
	return _subtitle_list[randi() % _subtitle_list.size()]


func _ready() -> void:
	layer = 2
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_find_player")
	# Load SFX
	_menu_nav_sound = load("res://assets/sounds/menu_nav.wav")
	_round_start_sound = load("res://assets/sounds/round_start.wav")
	_round_win_sound = load("res://assets/sounds/round_win.wav")
	_drum_tick_sound = load("res://assets/sounds/drum_tick.wav")

	var restart_prompt: RichTextLabel = $Control/RestartPrompt as RichTextLabel
	if restart_prompt:
		restart_prompt.anchor_left = 0.5
		restart_prompt.anchor_right = 0.5
		restart_prompt.anchor_top = 0.5
		restart_prompt.anchor_bottom = 0.5
		restart_prompt.offset_left = -300
		restart_prompt.offset_right = 300
		restart_prompt.offset_top = 160
		restart_prompt.offset_bottom = 220
		restart_prompt.size = Vector2(600, 60)

	var final_score_label: Label = $Control/FinalScoreLabel as Label
	if final_score_label:
		final_score_label.anchor_left = 0.5
		final_score_label.anchor_right = 0.5
		final_score_label.anchor_top = 0.5
		final_score_label.anchor_bottom = 0.5
		final_score_label.offset_left = -300
		final_score_label.offset_right = 300
		final_score_label.offset_top = 80
		final_score_label.offset_bottom = 140
		final_score_label.size = Vector2(600, 60)
		final_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		final_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		final_score_label.add_theme_font_size_override("font_size", 36)
		final_score_label.add_theme_constant_override("outline_size", 10)

	# Align ShopPanel programmatically
	var shop_panel: ColorRect = $Control/ShopPanel as ColorRect
	if shop_panel:
		shop_panel.custom_minimum_size = Vector2(850, 550)
		shop_panel.size = Vector2(850, 550)
		shop_panel.anchor_left = 0.5
		shop_panel.anchor_right = 0.5
		shop_panel.anchor_top = 0.5
		shop_panel.anchor_bottom = 0.5
		shop_panel.offset_left = -425
		shop_panel.offset_right = 425
		shop_panel.offset_top = -275
		shop_panel.offset_bottom = 275
		
		var shop_title = shop_panel.get_node_or_null("ShopTitle")
		if shop_title:
			shop_title.anchor_left = 0.5
			shop_title.anchor_right = 0.5
			shop_title.offset_left = -300
			shop_title.offset_right = 300
			shop_title.offset_top = 15
			shop_title.size = Vector2(600, 45)
		
		var shop_coins = shop_panel.get_node_or_null("ShopCoins")
		if shop_coins:
			shop_coins.anchor_left = 0.5
			shop_coins.anchor_right = 0.5
			shop_coins.offset_left = -300
			shop_coins.offset_right = 300
			shop_coins.offset_top = 70
			shop_coins.size = Vector2(600, 25)
			
		var shop_prompt = shop_panel.get_node_or_null("ShopPrompt")
		if shop_prompt:
			shop_prompt.anchor_left = 0.5
			shop_prompt.anchor_right = 0.5
			shop_prompt.anchor_top = 1.0
			shop_prompt.anchor_bottom = 1.0
			shop_prompt.offset_left = -400
			shop_prompt.offset_right = 400
			shop_prompt.offset_top = -50
			shop_prompt.size = Vector2(800, 40)

	# Align TitlePanel programmatically to cover full screen
	var title_panel: ColorRect = $Control/TitlePanel as ColorRect
	if title_panel:
		title_panel.anchor_left = 0.0
		title_panel.anchor_top = 0.0
		title_panel.anchor_right = 1.0
		title_panel.anchor_bottom = 1.0
		title_panel.offset_left = 0
		title_panel.offset_right = 0
		title_panel.offset_top = 0
		title_panel.offset_bottom = 0
		title_panel.size = Vector2(1280, 720)
		
		var bg = title_panel.get_node_or_null("Bg")
		if bg:
			bg.anchor_left = 0.0
			bg.anchor_top = 0.0
			bg.anchor_right = 1.0
			bg.anchor_bottom = 1.0
			bg.offset_left = 0
			bg.offset_right = 0
			bg.offset_top = 0
			bg.offset_bottom = 0
			bg.size = Vector2(1280, 720)
			
		var title_label = title_panel.get_node_or_null("TitleLabel") as Label
		if title_label:
			title_label.anchor_left = 0.5
			title_label.anchor_right = 0.5
			title_label.offset_left = -500
			title_label.offset_right = 500
			title_label.offset_top = 100
			title_label.size = Vector2(1000, 120)
			title_label.add_theme_font_size_override("font_size", 96)
			
		var subtitle_label = title_panel.get_node_or_null("SubtitleLabel") as Label
		if subtitle_label:
			subtitle_label.anchor_left = 0.5
			subtitle_label.anchor_right = 0.5
			subtitle_label.offset_left = -500
			subtitle_label.offset_right = 500
			subtitle_label.offset_top = 230
			subtitle_label.size = Vector2(1000, 50)
			subtitle_label.add_theme_font_size_override("font_size", 36)
			
		var title_prompt = title_panel.get_node_or_null("TitlePrompt") as RichTextLabel
		if title_prompt:
			title_prompt.anchor_left = 0.5
			title_prompt.anchor_right = 0.5
			title_prompt.anchor_top = 0.5
			title_prompt.anchor_bottom = 0.5
			title_prompt.offset_left = -500
			title_prompt.offset_right = 500
			title_prompt.offset_top = 20
			title_prompt.offset_bottom = 90
			title_prompt.size = Vector2(1000, 70)
			title_prompt.add_theme_font_size_override("normal_font_size", 32)
			title_prompt.add_theme_font_size_override("bold_font_size", 32)
			
		var controls_label = title_panel.get_node_or_null("ControlsLabel") as RichTextLabel
		if controls_label:
			controls_label.anchor_left = 0.5
			controls_label.anchor_right = 0.5
			controls_label.anchor_top = 1.0
			controls_label.anchor_bottom = 1.0
			controls_label.offset_left = -500
			controls_label.offset_right = 500
			controls_label.offset_top = -250
			controls_label.size = Vector2(1000, 200)
			controls_label.add_theme_font_size_override("normal_font_size", 24)
			controls_label.add_theme_font_size_override("bold_font_size", 24)

	# Align and scale UI elements programmatically for 720p
	var score_lbl: Label = $Control/ScoreLabel as Label
	if score_lbl:
		score_lbl.add_theme_font_size_override("font_size", 36)
		score_lbl.add_theme_constant_override("outline_size", 8)
		
	var round_label: Label = $Control/RoundLabel as Label
	if round_label:
		round_label.anchor_left = 0.5
		round_label.anchor_right = 0.5
		round_label.offset_left = -300
		round_label.offset_right = 300
		round_label.offset_top = 20
		round_label.size = Vector2(600, 45)
		round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		round_label.add_theme_font_size_override("font_size", 36)
		round_label.add_theme_constant_override("outline_size", 10)
		
	var enemy_count_label: Label = $Control/EnemyCountLabel as Label
	if enemy_count_label:
		enemy_count_label.anchor_left = 0.5
		enemy_count_label.anchor_right = 0.5
		enemy_count_label.offset_left = -200
		enemy_count_label.offset_right = 200
		enemy_count_label.offset_top = 70
		enemy_count_label.size = Vector2(400, 30)
		enemy_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		enemy_count_label.add_theme_font_size_override("font_size", 20)
		enemy_count_label.add_theme_constant_override("outline_size", 6)

	var countdown_label: Label = $Control/CountdownLabel as Label
	if countdown_label:
		countdown_label.anchor_left = 0.5
		countdown_label.anchor_right = 0.5
		countdown_label.anchor_top = 0.5
		countdown_label.anchor_bottom = 0.5
		countdown_label.offset_left = -300
		countdown_label.offset_right = 300
		countdown_label.offset_top = -60
		countdown_label.offset_bottom = 60
		countdown_label.size = Vector2(600, 120)
		countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		countdown_label.pivot_offset = Vector2(300, 60)
		countdown_label.add_theme_font_size_override("font_size", 72)
		countdown_label.add_theme_constant_override("outline_size", 16)
		
	var round_complete_label: Label = $Control/RoundCompleteLabel as Label
	if round_complete_label:
		round_complete_label.add_theme_font_size_override("font_size", 48)
		round_complete_label.add_theme_constant_override("outline_size", 12)
		round_complete_label.anchor_left = 0.5
		round_complete_label.anchor_right = 0.5
		round_complete_label.offset_left = -400
		round_complete_label.offset_right = 400
		round_complete_label.offset_top = -120
		round_complete_label.offset_bottom = -40
		round_complete_label.size = Vector2(800, 80)
		round_complete_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
	var prize_label: Label = $Control/PrizeLabel as Label
	if prize_label:
		prize_label.add_theme_font_size_override("font_size", 32)
		prize_label.add_theme_constant_override("outline_size", 8)
		prize_label.anchor_left = 0.5
		prize_label.anchor_right = 0.5
		prize_label.offset_left = -300
		prize_label.offset_right = 300
		prize_label.offset_top = 0
		prize_label.offset_bottom = 50
		prize_label.size = Vector2(600, 50)
		prize_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
	var gameplay_prompt: RichTextLabel = $Control/GameplayPrompt as RichTextLabel
	if gameplay_prompt:
		gameplay_prompt.anchor_left = 0.0
		gameplay_prompt.anchor_top = 1.0
		gameplay_prompt.anchor_right = 0.0
		gameplay_prompt.anchor_bottom = 1.0
		gameplay_prompt.offset_left = 24
		gameplay_prompt.offset_right = 624
		gameplay_prompt.offset_top = -320
		gameplay_prompt.offset_bottom = -20
		gameplay_prompt.size = Vector2(600, 300)
		
	var intermission_prompt: RichTextLabel = $Control/IntermissionPrompt as RichTextLabel
	if intermission_prompt:
		intermission_prompt.anchor_left = 0.5
		intermission_prompt.anchor_right = 0.5
		intermission_prompt.anchor_top = 1.0
		intermission_prompt.anchor_bottom = 1.0
		intermission_prompt.offset_left = -500
		intermission_prompt.offset_right = 500
		intermission_prompt.offset_top = -180
		intermission_prompt.size = Vector2(1000, 100)

	# Initial off-screen positions for slide transitions
	_hud_container_offset = -120.0 # Slide off-screen to the left
	_hearts_container_offset = 120.0 # Slide off-screen to the right
	_hud_target_opacity = 0.0
	_hearts_target_opacity = 0.0
	_weapon_desc_opacity = 0.0
	_hud_hide_timer = 0.0
	_hearts_hide_timer = 0.0

	_combo_container = Control.new()
	_combo_container.name = "ComboContainer"
	_combo_container.anchor_left = 1.0
	_combo_container.anchor_top = 0.5
	_combo_container.anchor_right = 1.0
	_combo_container.anchor_bottom = 0.5
	_combo_container.position = Vector2(-150, -40)
	_combo_container.hide()
	$Control.add_child(_combo_container)
	
	_combo_label = Label.new()
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.add_theme_font_size_override("font_size", 42)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.0))
	_combo_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_combo_label.add_theme_constant_override("outline_size", 10)
	_combo_label.size = Vector2(250, 50)
	_combo_label.position = Vector2(-125, -25)
	_combo_label.pivot_offset = Vector2(125, 25)
	_combo_container.add_child(_combo_label)
	
	_combo_hype_label = Label.new()
	_combo_hype_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_hype_label.add_theme_font_size_override("font_size", 22)
	_combo_hype_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))
	_combo_hype_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_combo_hype_label.add_theme_constant_override("outline_size", 6)
	_combo_hype_label.size = Vector2(250, 30)
	_combo_hype_label.position = Vector2(-125, 25)
	_combo_hype_label.pivot_offset = Vector2(125, 15)
	_combo_container.add_child(_combo_hype_label)
	
	_combo_progress_bar = ProgressBar.new()
	_combo_progress_bar.show_percentage = false
	_combo_progress_bar.size = Vector2(160, 8)
	_combo_progress_bar.position = Vector2(-80, 60)
	_combo_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.1, 0.2)
	sb.corner_radius_top_left = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	_combo_progress_bar.add_theme_stylebox_override("fill", sb)
	_combo_container.add_child(_combo_progress_bar)

	# Programmatic Pause Panel
	_pause_panel = ColorRect.new()
	_pause_panel.name = "PausePanel"
	_pause_panel.color = Color(0.0, 0.0, 0.0, 0.5)
	_pause_panel.anchor_left = 0.0
	_pause_panel.anchor_top = 0.0
	_pause_panel.anchor_right = 1.0
	_pause_panel.anchor_bottom = 1.0
	_pause_panel.hide()
	$Control.add_child(_pause_panel)
	
	_pause_label = Label.new()
	_pause_label.text = "PAUSED"
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pause_label.add_theme_font_size_override("font_size", 48)
	_pause_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2))
	_pause_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_pause_label.add_theme_constant_override("outline_size", 10)
	_pause_label.anchor_left = 0.5
	_pause_label.anchor_top = 0.5
	_pause_label.anchor_right = 0.5
	_pause_label.anchor_bottom = 0.5
	_pause_label.offset_left = -200
	_pause_label.offset_top = -50
	_pause_label.size = Vector2(400, 100)
	_pause_label.pivot_offset = Vector2(200, 50)
	_pause_panel.add_child(_pause_label)


func _find_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player or not player.has_signal("weapon_changed"):
		return
	player.weapon_changed.connect(_on_player_weapon_changed)
	player.reload_started.connect(_on_reload_started)
	player.reload_ticking.connect(_on_reload_ticking)
	player.reload_finished.connect(_on_reload_finished)
	_on_player_weapon_changed(player.inventory, player.current_weapon_index, player._slot_cooldowns)


func _on_player_weapon_changed(inv: Array, idx: int, cooldowns: Dictionary) -> void:
	_build_hotbar(inv, idx)
	_update_weapon_description(inv, idx)
	# Refresh cooldown bar values immediately
	_refresh_cooldown_bars(cooldowns)


func _build_hotbar(inv: Array, idx: int) -> void:
	_active_hotbar_idx = idx
	_clear_hotbar()
	if not _hotbar_bg:
		_hotbar_bg = Panel.new()
		_hotbar_bg.name = "HotbarBg"
		_hotbar_bg.anchor_left = 0.5
		_hotbar_bg.anchor_top = 1.0
		_hotbar_bg.anchor_right = 0.5
		_hotbar_bg.anchor_bottom = 1.0
		_hotbar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hotbar_bg.clip_contents = true
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.08, 0.12, 0.85)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		_hotbar_bg.add_theme_stylebox_override("panel", style)
		$Control.add_child(_hotbar_bg)
	var slot_size := 64
	var gap := 6
	var pad := 8
	var total_w := inv.size() * slot_size + (inv.size() - 1) * gap + pad * 2
	var bar_h := slot_size + pad * 2
	_hotbar_bg.offset_left = -float(total_w) / 2.0
	_hotbar_bg.offset_top = -(bar_h + 4)
	_hotbar_bg.size = Vector2(total_w, bar_h)
	for i in range(inv.size()):
		var slot := ColorRect.new()
		slot.size = Vector2(slot_size, slot_size)
		slot.position = Vector2(pad + i * (slot_size + gap), pad)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.color = Color(0.3, 0.25, 0.1, 0.8) if i == idx else Color(0.15, 0.15, 0.2, 0.6)
		var weapon_name: String = inv[i][0] if inv[i] is Array else inv[i]
		var has_ammo: bool = weapon_name != "pistol"
		var ammo_count: int = inv[i][1] if inv[i] is Array and inv[i].size() > 1 else -1

		var icon := TextureRect.new()
		icon.texture = _weapon_textures.get(weapon_name)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = Vector2(slot_size, slot_size)
		icon.position = Vector2(0, 0)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)

		var num_lbl := Label.new()
		num_lbl.text = str(i + 1) if i < 9 else "0"
		num_lbl.size = Vector2(slot_size - 8, 14)
		num_lbl.position = Vector2(4, slot_size - 18)
		num_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.6))
		num_lbl.add_theme_font_size_override("font_size", 12)
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(num_lbl)

		if has_ammo:
			var ammo_lbl := Label.new()
			ammo_lbl.text = str(ammo_count)
			ammo_lbl.size = Vector2(slot_size - 8, 16)
			ammo_lbl.position = Vector2(4, 4)
			ammo_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
			ammo_lbl.add_theme_font_size_override("font_size", 14)
			ammo_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(ammo_lbl)

		# --- Cooldown bar overlay ---
		var cd_bg := ColorRect.new()
		cd_bg.name = "CooldownBg"
		cd_bg.color = Color(0, 0, 0, 0.55)
		cd_bg.size = Vector2(slot_size, 6)
		cd_bg.position = Vector2(0, slot_size - 6)
		cd_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(cd_bg)

		var cd_bar := ColorRect.new()
		cd_bar.name = "CooldownBar"
		cd_bar.color = Color(0.2, 1.0, 0.4, 0.9)
		cd_bar.size = Vector2(0, 6)
		cd_bar.position = Vector2(0, slot_size - 6)
		cd_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(cd_bar)

		_hotbar_bg.add_child(slot)
		_hotbar_slots.append(slot)


func _clear_hotbar() -> void:
	for slot in _hotbar_slots:
		slot.queue_free()
	_hotbar_slots.clear()


func _on_reload_started(duration: float) -> void:
	var lbl := $Control/ReloadLabel
	lbl.text = str(snapped(duration, 0.01)) + "s"
	lbl.show()


func _on_reload_ticking(time_left: float) -> void:
	var lbl := $Control/ReloadLabel
	if time_left <= 0.0:
		lbl.hide()
		return
	lbl.text = str(snapped(time_left, 0.01)) + "s"


func _on_reload_finished() -> void:
	$Control/ReloadLabel.hide()


func _update_weapon_description(inv: Array, idx: int) -> void:
	if idx < 0 or idx >= inv.size():
		return
	var weapon_name: String = inv[idx][0] if inv[idx] is Array else inv[idx]
	if weapon_name == _last_weapon_name:
		return
	_last_weapon_name = weapon_name
	var details = _weapon_details.get(weapon_name, _weapon_details["pistol"])
	
	if not _weapon_desc_bg:
		_weapon_desc_bg = Panel.new()
		_weapon_desc_bg.name = "WeaponDescBg"
		_weapon_desc_bg.anchor_left = 0.5
		_weapon_desc_bg.anchor_top = 1.0
		_weapon_desc_bg.anchor_right = 0.5
		_weapon_desc_bg.anchor_bottom = 1.0
		_weapon_desc_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Transparent style to remove outline block and visual bloat
		var style := StyleBoxEmpty.new()
		_weapon_desc_bg.add_theme_stylebox_override("panel", style)
		$Control.add_child(_weapon_desc_bg)
		
		_weapon_desc_lbl = RichTextLabel.new()
		_weapon_desc_lbl.name = "WeaponDescLbl"
		_weapon_desc_lbl.bbcode_enabled = true
		_weapon_desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_weapon_desc_lbl.scroll_active = false  # Disable scrollbars completely
		_weapon_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF # Prevent accidental vertical truncation
		_weapon_desc_bg.add_child(_weapon_desc_lbl)
		
	var w := 800
	var h := 160
	_weapon_desc_bg.offset_left = -float(w) / 2.0
	_weapon_desc_bg.offset_right = float(w) / 2.0
	_weapon_desc_bg.offset_top = -240
	_weapon_desc_bg.offset_bottom = -80
	
	_weapon_desc_lbl.size = Vector2(w, h)
	_weapon_desc_lbl.position = Vector2(0, 0)
	
	var text_color_hex = details.color.to_html(false)
	var bb_text = "[center][font_size=28][b][color=#" + text_color_hex + "][wave amp=20 freq=5]" + details.name + "[/wave][/color][/b] - [color=#ffdd44]" + details.damage + "[/color][/font_size]\n[font_size=20][color=#eeeeee]" + details.desc + "[/color][/font_size][/center]"
	_weapon_desc_lbl.text = bb_text
	
	# Start vanishing fade out timer and letter wobbly bounce progress
	_weapon_desc_timer = 0.5
	_weapon_desc_opacity = 1.0
	_weapon_desc_anim_progress = 0.0
	
	var main = get_tree().current_scene
	var hide_desc = false
	if main:
		var state = main.get("state")
		var menu_open = main.get("menu_open")
		if state == 0 or state == 4 or menu_open:
			hide_desc = true
			
	_weapon_desc_bg.visible = not hide_desc
	_weapon_desc_bg.modulate.a = 1.0 if not hide_desc else 0.0


func _toggle_weapon_desc(is_visible: bool) -> void:
	if _weapon_desc_bg:
		_weapon_desc_bg.visible = is_visible


func show_combo(count: int) -> void:
	if not _combo_container:
		return
	_combo_container.show()
	_combo_label.text = "COMBO x" + str(count)
	
	var hype := ""
	var color := Color(1.0, 0.9, 0.1)
	if count >= 20:
		hype = "APOCALYPTIC!!!"
		color = Color(1.0, 0.1, 0.8)
	elif count >= 15:
		hype = "GODLIKE!!"
		color = Color(0.1, 0.9, 1.0)
	elif count >= 10:
		hype = "SAVAGE!"
		color = Color(0.2, 1.0, 0.2)
	elif count >= 7:
		hype = "UNSTOPPABLE"
		color = Color(1.0, 0.5, 0.0)
	elif count >= 4:
		hype = "DOUBLE KILL!" if count == 4 else ("RAMPAGE!" if count <= 5 else "TRIPLE KILL!")
		color = Color(1.0, 0.8, 0.2)
	
	_combo_hype_label.text = hype
	_combo_hype_label.add_theme_color_override("font_color", color)
	
	if _combo_tween and _combo_tween.is_valid():
		_combo_tween.kill()
	_combo_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	_combo_label.scale = Vector2(1.5, 0.7)
	_combo_label.rotation = randf_range(-0.15, 0.15)
	_combo_tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.4)
	_combo_tween.tween_property(_combo_label, "rotation", 0.0, 0.4)
	
	if hype != "":
		_combo_hype_label.scale = Vector2(1.4, 1.4)
		_combo_hype_label.rotation = randf_range(-0.2, 0.2)
		_combo_tween.tween_property(_combo_hype_label, "scale", Vector2.ONE, 0.4)
		_combo_tween.tween_property(_combo_hype_label, "rotation", 0.0, 0.4)
		
	var player = get_tree().get_first_node_in_group("player")
	if player and "shake_intensity" in player:
		player.shake_intensity = clampf(player.shake_intensity + 0.8 * count, 0.0, 15.0)


func hide_combo() -> void:
	if _combo_container:
		_combo_container.hide()


func update_combo_timer(progress: float) -> void:
	if _combo_progress_bar:
		_combo_progress_bar.value = progress * 100.0


func _process(delta: float) -> void:
	_time += delta
	
	# 1. Main Menu / Title Screen Animations
	var title_panel: ColorRect = $Control/TitlePanel as ColorRect
	if title_panel and title_panel.visible:
		var title_label: Label = title_panel.get_node("TitleLabel") as Label
		if title_label:
			# Heartbeat style scale pulse and waddle rotation
			var t_scale_x: float = 1.0 + sin(_time * 4.0) * 0.10
			var t_scale_y: float = 1.0 - sin(_time * 4.0) * 0.10
			title_label.scale = Vector2(t_scale_x, t_scale_y)
			title_label.pivot_offset = title_label.size / 2
			title_label.rotation = sin(_time * 3.0) * 0.05
			
		var sub_label: Label = title_panel.get_node("SubtitleLabel") as Label
		if sub_label:
			sub_label.position.y = 230.0 + sin(_time * 6.0) * 4.0
			sub_label.rotation = cos(_time * 4.0) * 0.03
			
		var bg_rect: TextureRect = title_panel.get_node("Bg") as TextureRect
		if bg_rect:
			bg_rect.scale = Vector2(1.0 + sin(_time * 0.7) * 0.03, 1.0 + cos(_time * 0.9) * 0.03)
			bg_rect.pivot_offset = bg_rect.size / 2

	# 2. Pause Menu Overlay Bounces
	var is_paused: bool = get_tree().paused
	if _pause_panel:
		if is_paused and not _pause_panel.visible:
			_pause_panel.show()
			_pause_label.scale = Vector2.ZERO
			var t: Tween = create_tween()
			t.tween_property(_pause_label, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		elif not is_paused and _pause_panel.visible:
			_pause_panel.hide()
			
		if _pause_panel.visible and _pause_label:
			_pause_label.rotation = sin(_time * 5.0) * 0.08
			var p_scale: float = 1.0 + sin(_time * 8.0) * 0.06
			_pause_label.scale = Vector2(p_scale, p_scale)

	# Determine if we are in intermission or combat state to apply autohide
	var main_scene = get_tree().current_scene
	var is_intermission_or_title: bool = false
	if main_scene:
		var state_val = main_scene.get("state")
		# TITLE (0) or INTERMISSION (1) state keep UI always present
		is_intermission_or_title = (state_val == 0 or state_val == 1)

	# Decay autohide timers
	if _animating_coins:
		_hud_hide_timer = 2.0
		_hearts_hide_timer = 2.0
	
	if not is_intermission_or_title:
		if _hud_hide_timer > 0.0:
			_hud_hide_timer -= delta
		if _hearts_hide_timer > 0.0:
			_hearts_hide_timer -= delta
	else:
		# Keep them alive during intermission or titles
		_hud_hide_timer = 2.0
		_hearts_hide_timer = 2.0
		
	# Weapon description ALWAYS decays and disappears after a second or two
	if _weapon_desc_timer > 0.0:
		_weapon_desc_timer -= delta

	# Calculate Target Positions & Modulates
	# HUD Score/Coins (Left side)
	if _hud_hide_timer > 0.0:
		_hud_container_offset = lerpf(_hud_container_offset, 0.0, delta * 8.0)
		_hud_target_opacity = lerpf(_hud_target_opacity, 1.0, delta * 8.0)
	else:
		_hud_container_offset = lerpf(_hud_container_offset, -120.0, delta * 5.0)
		_hud_target_opacity = lerpf(_hud_target_opacity, 0.0, delta * 5.0)

	# Hearts (Right side)
	if _hearts_hide_timer > 0.0:
		_hearts_container_offset = lerpf(_hearts_container_offset, 0.0, delta * 8.0)
		_hearts_target_opacity = lerpf(_hearts_target_opacity, 1.0, delta * 8.0)
	else:
		_hearts_container_offset = lerpf(_hearts_container_offset, 120.0, delta * 5.0)
		_hearts_target_opacity = lerpf(_hearts_target_opacity, 0.0, delta * 5.0)

	# Weapon Description (Center)
	if _weapon_desc_timer > 0.0:
		_weapon_desc_opacity = lerpf(_weapon_desc_opacity, 1.0, delta * 8.0)
	else:
		_weapon_desc_opacity = lerpf(_weapon_desc_opacity, 0.0, delta * 4.0)

	# Apply positions and modulates
	var score_icon: TextureRect = $Control/ScoreIcon as TextureRect
	var score_lbl: Label = $Control/ScoreLabel as Label
	if score_icon and score_lbl:
		var bob: float = sin(_time * 3.5) * 3.0
		# Align offset on the X axis to slide from left, moved to the right (x=24, x=56)
		score_icon.position.x = 24.0 + _hud_container_offset
		score_icon.position.y = 14.0 + bob
		score_icon.size = Vector2(36, 36)
		score_icon.modulate.a = _hud_target_opacity
		
		score_lbl.position.x = 68.0 + _hud_container_offset
		score_lbl.position.y = 16.0 + bob
		score_lbl.rotation = cos(_time * 2.5) * 0.02
		score_lbl.modulate.a = _hud_target_opacity

	var round_lbl: Label = $Control/RoundLabel as Label
	var enemy_lbl: Label = $Control/EnemyCountLabel as Label
	if round_lbl and enemy_lbl:
		round_lbl.scale = Vector2(1.0 + sin(_time * 3.0) * 0.06, 1.0 - sin(_time * 3.0) * 0.06)
		round_lbl.pivot_offset = round_lbl.size / 2
		enemy_lbl.position.y = 30.0 + cos(_time * 4.5) * 2.0

	# Align Hearts HBoxContainer and slide from right side
	var hearts_container: HBoxContainer = $Control/Hearts as HBoxContainer
	if hearts_container:
		# Centering hearts vertically on offset-top and sliding right on offset_left
		var viewport_w = get_viewport().get_visible_rect().size.x
		hearts_container.position.x = (viewport_w - hearts_container.size.x - 24.0) + _hearts_container_offset
		hearts_container.position.y = 16.0 # Center aligned with score label
		hearts_container.modulate.a = _hearts_target_opacity
		
		var hearts_list: Array[Node] = hearts_container.get_children()
		for i in range(hearts_list.size()):
			var h: TextureRect = hearts_list[i] as TextureRect
			if h:
				var h_time: float = _time * 2.0 + float(i) * 0.35
				var pulse: float = 0.0
				if fmod(h_time, 2.0) < 0.6:
					pulse = sin(fmod(h_time, 2.0) / 0.6 * PI) * 0.18
				h.scale = Vector2(1.0 + pulse, 1.0 + pulse)
				h.pivot_offset = h.size / 2
				h.rotation = sin(_time * 4.0 + float(i)) * 0.04

	# Apply Weapon Description modulate and bouncy animation layout
	if _weapon_desc_bg and _weapon_desc_lbl:
		_weapon_desc_bg.modulate.a = _weapon_desc_opacity
		
		# Animate wobbly text bounce per letter
		_weapon_desc_anim_progress = minf(_weapon_desc_anim_progress + delta * 3.5, 1.0)
		var scale_t := 1.0 + sin((1.0 - _weapon_desc_anim_progress) * PI * 4.0) * 0.20 * exp(-_weapon_desc_anim_progress * 4.0)
		_weapon_desc_lbl.scale = Vector2(scale_t, scale_t)
		_weapon_desc_lbl.pivot_offset = _weapon_desc_lbl.size / 2.0
		_weapon_desc_lbl.rotation = sin((1.0 - _weapon_desc_anim_progress) * PI * 3.0) * 0.06 * exp(-_weapon_desc_anim_progress * 3.0)

	# 5. Shop Menu & Asynchronous floating cards
	var shop_panel: ColorRect = $Control/ShopPanel as ColorRect
	if shop_panel and shop_panel.visible:
		var shop_title: Label = shop_panel.get_node("ShopTitle") as Label
		if shop_title:
			shop_title.rotation = sin(_time * 2.5) * 0.05
			shop_title.scale = Vector2(1.0 + sin(_time * 3.5) * 0.04, 1.0 + cos(_time * 3.5) * 0.04)
			shop_title.pivot_offset = shop_title.size / 2
			
		var card_w: int = 200
		var card_h: int = 120
		var gap_x: int = 30
		var gap_y: int = 20
		var start_x: int = 95
		var start_y: int = 110
		var cols: int = SHOP_COLS

		for i in range(_shop_cards.size()):
			var card: ColorRect = _shop_cards[i]
			var border: ColorRect = _shop_borders[i]
			var row := i / cols
			var col := i % cols
			var base_x: float = float(start_x) + float(col) * float(card_w + gap_x)
			var base_y: float = float(start_y) + float(row) * float(card_h + gap_y)
			
			var phase: float = float(i) * 1.25
			var offset_y: float = sin(_time * 4.0 + phase) * 4.5
			var offset_rot: float = cos(_time * 3.0 + phase) * 0.035
			
			card.position = Vector2(base_x, base_y + offset_y)
			card.rotation = offset_rot
			
			border.position = Vector2(base_x - 2, base_y - 2 + offset_y)
			border.rotation = offset_rot

	# 6. Hotbar slot floats and Selected wiggle/dance
	if _hotbar_bg and _hotbar_bg.visible:
		_hotbar_bg.position.y = get_viewport().get_visible_rect().size.y - _hotbar_bg.size.y - 4.0 + sin(_time * 2.0) * 3.0
		
		for i in range(_hotbar_slots.size()):
			var slot: ColorRect = _hotbar_slots[i]
			var is_active: bool = (i == _active_hotbar_idx)
			if is_active:
				var pulse: float = sin(_time * 7.5) * 0.10
				slot.scale = Vector2(1.18 + pulse, 1.18 + pulse)
				slot.pivot_offset = slot.size / 2
				slot.rotation = sin(_time * 6.5) * 0.04
			else:
				slot.scale = Vector2.ONE
				slot.rotation = 0.0

		# Live cooldown bar updates from player
		var player_node = get_tree().get_first_node_in_group("player")
		if player_node and "_slot_cooldowns" in player_node:
			var cds: Dictionary = player_node._slot_cooldowns
			for i in range(_hotbar_slots.size()):
				var slot: ColorRect = _hotbar_slots[i]
				var cd_bar := slot.get_node_or_null("CooldownBar") as ColorRect
				if cd_bar:
					var slot_size: float = slot.size.x
					if cds.has(i):
						var cd: Dictionary = cds[i]
						var ratio: float = 1.0 - (cd.current / cd.max) if cd.max > 0.0 else 1.0
						cd_bar.size.x = slot_size * ratio
						# Color: red when cooling down -> green when ready
						cd_bar.color = Color(lerpf(1.0, 0.2, ratio), lerpf(0.2, 1.0, ratio), 0.3, 0.9)
					else:
						cd_bar.size.x = slot_size  # Full bar = ready
						cd_bar.color = Color(0.2, 1.0, 0.4, 0.9)

	# 7. Frantic reloading label shake
	var reload_lbl: Label = $Control/ReloadLabel as Label
	if reload_lbl and reload_lbl.visible:
		reload_lbl.rotation = sin(_time * 14.0) * 0.07
		var r_scale: float = 1.0 + sin(_time * 16.0) * 0.12
		reload_lbl.scale = Vector2(r_scale, r_scale)
		reload_lbl.pivot_offset = reload_lbl.size / 2


# Plays a one-shot SFX without blocking
func _play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not stream:
		return
	var sp := AudioStreamPlayer.new()
	sp.stream = stream
	sp.volume_db = volume_db
	sp.pitch_scale = pitch
	add_child(sp)
	sp.play()
	sp.finished.connect(sp.queue_free)


func _refresh_cooldown_bars(cooldowns: Dictionary) -> void:
	for i in range(_hotbar_slots.size()):
		var slot: ColorRect = _hotbar_slots[i]
		var cd_bar := slot.get_node_or_null("CooldownBar") as ColorRect
		if cd_bar:
			var slot_size: float = slot.size.x
			if cooldowns.has(i):
				var cd: Dictionary = cooldowns[i]
				var ratio: float = 1.0 - (cd.current / cd.max) if cd.max > 0.0 else 1.0
				cd_bar.size.x = slot_size * ratio
			else:
				cd_bar.size.x = slot_size
