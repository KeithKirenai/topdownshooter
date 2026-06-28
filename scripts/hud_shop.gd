## hud_shop.gd
## Repurposed as the Weapon Mastery Dashboard.
## Displays progression, achievements, and milestones to unlock weapons & passives.
class_name HudShop
extends RefCounted

# Keep the signal to avoid breaking connections in hud.gd
signal purchase_succeeded(key: String)

var _panel: ColorRect
var _textures: Dictionary
var _hud_node: CanvasLayer
var _main_node: Node

var _cards_container: Control
var _ambient_motes: CPUParticles2D
var _panel_gradients: Array[ColorRect] = []

const MILESTONES := {
	"shotgun": {
		"name": "Shotgun",
		"desc": "Master basic arms. Get 100 kills with the starting Pistol.",
		"source": "pistol",
		"target": 100,
		"type": "kills",
		"cost": 250,
		"category": "weapon"
	},
	"smg": {
		"name": "SMG",
		"desc": "Prove close-quarters mastery. Get 100 kills with the Shotgun.",
		"source": "shotgun",
		"target": 100,
		"type": "kills",
		"cost": 500,
		"category": "weapon"
	},
	"minigun": {
		"name": "Minigun",
		"desc": "Unleash rapid fire. Get 150 kills with the SMG.",
		"source": "smg",
		"target": 150,
		"type": "kills",
		"cost": 1000,
		"category": "weapon"
	},
	"sniper": {
		"name": "Sniper Rifle",
		"desc": "Achieve flawless survival. Survive 5 minutes without taking damage.",
		"source": "survival",
		"target": 300,
		"type": "time",
		"cost": 1500,
		"category": "weapon"
	},
	"missile": {
		"name": "Missile Launcher",
		"desc": "Master precision destruction. Get 50 kills with the Sniper Rifle.",
		"source": "sniper",
		"target": 50,
		"type": "kills",
		"cost": 2500,
		"category": "weapon"
	},
	"shield": {
		"name": "Shield Upgrade",
		"desc": "Absorbs damage and recharges. Survive 2 minutes in a single run.",
		"source": "run",
		"target": 120,
		"type": "time",
		"cost": 400,
		"category": "passive"
	},
	"speed_loader": {
		"name": "Speed Loader",
		"desc": "Reload weapons 30% faster. Fire 1,000 total bullets.",
		"source": "bullets",
		"target": 1000,
		"type": "bullets",
		"cost": 600,
		"category": "passive"
	},
	"golden_touch": {
		"name": "Golden Touch",
		"desc": "20% chance to drop double coins. Collect 500 total coins.",
		"source": "coins",
		"target": 500,
		"type": "coins",
		"cost": 800,
		"category": "passive"
	},
	"magnet_ring": {
		"name": "Magnet Ring",
		"desc": "+120% collection radius. Collect 100 pickup items.",
		"source": "items",
		"target": 100,
		"type": "items",
		"cost": 500,
		"category": "passive"
	},
	"toughness": {
		"name": "Toughness",
		"desc": "35% chance to ignore any damage. Defeat 250 total enemies.",
		"source": "total",
		"target": 250,
		"type": "kills",
		"cost": 750,
		"category": "passive"
	},
	"damage_boost": {
		"name": "Damage Boost",
		"desc": "Permanent +35% bullet damage. Achieve a 10x combo multiplier.",
		"source": "combo",
		"target": 10,
		"type": "combo",
		"cost": 1200,
		"category": "passive"
	}
}

func init(panel: ColorRect, textures: Dictionary, hud: CanvasLayer) -> void:
	_panel = panel
	_textures = textures
	_hud_node = hud
	_main_node = hud.get_parent()


func tick(_delta: float, _time: float) -> void:
	pass


func clear_cards() -> void:
	if _ambient_motes:
		_ambient_motes.queue_free()
		_ambient_motes = null
	for g in _panel_gradients:
		if is_instance_valid(g):
			g.queue_free()
	_panel_gradients.clear()
	
	if _cards_container:
		_cards_container.queue_free()
		_cards_container = null


func build_cards() -> void:
	clear_cards()

	# 1. Main container
	_cards_container = Control.new()
	_cards_container.name = "MasteryContainer"
	_cards_container.size = _panel.size
	_panel.add_child(_cards_container)

	# 3. Retro Header Title
	var title_lbl := Label.new()
	title_lbl.text = "🎯 WEAPON & PASSIVE MASTERY"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 32)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0)) # Retro Golden Yellow
	title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	title_lbl.add_theme_constant_override("outline_size", 10)
	title_lbl.position = Vector2(0, 20)
	title_lbl.size = Vector2(_panel.size.x, 50)
	_cards_container.add_child(title_lbl)

	# Subtitle description
	var sub_lbl := Label.new()
	sub_lbl.text = "COMPLETE MILESTONES TO UNLOCK ITEMS, THEN SPEND COINS TO PERMANENTLY ACTIVATE THEM."
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	sub_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	sub_lbl.add_theme_constant_override("outline_size", 4)
	sub_lbl.position = Vector2(0, 68)
	sub_lbl.size = Vector2(_panel.size.x, 30)
	_cards_container.add_child(sub_lbl)

	# 4. Scroll Container for two sections
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(840, 390)
	scroll.position = Vector2(25, 110)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_cards_container.add_child(scroll)

	var list_container := VBoxContainer.new()
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_container.add_theme_constant_override("separation", 20)
	scroll.add_child(list_container)

	# Weapons Section
	var weapons_title := Label.new()
	weapons_title.text = "⚔️ WEAPONS"
	weapons_title.add_theme_font_size_override("font_size", 20)
	weapons_title.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0))
	weapons_title.add_theme_color_override("font_outline_color", Color.BLACK)
	weapons_title.add_theme_constant_override("outline_size", 6)
	list_container.add_child(weapons_title)

	var weapons_grid := GridContainer.new()
	weapons_grid.columns = 3
	weapons_grid.add_theme_constant_override("h_separation", 24)
	weapons_grid.add_theme_constant_override("v_separation", 24)
	list_container.add_child(weapons_grid)

	# Passives Section
	var passives_title := Label.new()
	passives_title.text = "🛡️ PASSIVE UPGRADES"
	passives_title.add_theme_font_size_override("font_size", 20)
	passives_title.add_theme_color_override("font_color", Color(1.0, 0.0, 0.5))
	passives_title.add_theme_color_override("font_outline_color", Color.BLACK)
	passives_title.add_theme_constant_override("outline_size", 6)
	
	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	list_container.add_child(spacer)
	list_container.add_child(passives_title)

	var passives_grid := GridContainer.new()
	passives_grid.columns = 3
	passives_grid.add_theme_constant_override("h_separation", 24)
	passives_grid.add_theme_constant_override("v_separation", 24)
	list_container.add_child(passives_grid)

	var player = _hud_node.get_tree().get_first_node_in_group("player")

	var order := ["shotgun", "smg", "minigun", "sniper", "missile", "shield", "speed_loader", "golden_touch", "magnet_ring", "toughness", "damage_boost"]
	for item_key in order:
		var cfg = MILESTONES[item_key]
		var is_unlocked := false
		
		if player:
			if cfg["category"] == "weapon":
				is_unlocked = player.weapon_unlocks.get(item_key, false)
			else:
				is_unlocked = player.passive_unlocks.get(item_key, false)

		var current_val: float = 0.0
		if player:
			match cfg["type"]:
				"kills":
					if cfg["source"] == "total":
						current_val = float(player.total_kills)
					else:
						current_val = float(player.weapon_kills.get(cfg["source"], 0))
				"time":
					if cfg["source"] == "survival":
						current_val = player.time_without_damage
					elif cfg["source"] == "run":
						current_val = player.run_survival_time
				"bullets":
					current_val = float(player.total_bullets_fired)
				"coins":
					current_val = float(player.total_coins_collected)
				"items":
					current_val = float(player.total_items_collected)
				"combo":
					current_val = float(player.peak_combo)

		var target_val: float = float(cfg["target"])
		var pct := clampf(current_val / target_val, 0.0, 1.0)
		var milestone_met := pct >= 1.0

		# Build the card panel
		var card := Panel.new()
		card.custom_minimum_size = Vector2(250, 175)
		
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color.TRANSPARENT
		card_style.shadow_color = Color(0, 0, 0, 0.5)
		card_style.shadow_size = 6
		card_style.shadow_offset = Vector2(4, 4)
		card.add_theme_stylebox_override("panel", card_style)
		
		# Apply 16-bit console style border (active/bright gold if unlocked or ready to buy)
		HudUiKit.decorate_retro_item_card(card, is_unlocked or milestone_met)
		
		if cfg["category"] == "weapon":
			weapons_grid.add_child(card)
		else:
			passives_grid.add_child(card)

		# Icon
		var icon_rect := TextureRect.new()
		icon_rect.texture = _textures.get(item_key)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size = Vector2(64, 64)
		icon_rect.position = Vector2(12, 12)
		card.add_child(icon_rect)

		# Item name
		var name_lbl := Label.new()
		name_lbl.text = cfg["name"].to_upper()
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		name_lbl.add_theme_constant_override("outline_size", 6)
		name_lbl.position = Vector2(88, 14)
		name_lbl.size = Vector2(150, 25)
		card.add_child(name_lbl)

		# Status Badge
		var badge := Label.new()
		if is_unlocked:
			badge.text = "[ ACTIVE ]"
			badge.add_theme_color_override("font_color", Color(0.0, 1.0, 0.3))
		elif milestone_met:
			badge.text = "[ READY TO BUY ]"
			badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
		else:
			badge.text = "[ LOCKED ]"
			badge.add_theme_color_override("font_color", Color(1.0, 0.0, 0.4))
		badge.add_theme_font_size_override("font_size", 11)
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 4)
		badge.position = Vector2(88, 38)
		card.add_child(badge)

		# Description text
		var desc_lbl := Label.new()
		desc_lbl.text = cfg["desc"].to_upper()
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 9)
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		desc_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		desc_lbl.add_theme_constant_override("outline_size", 4)
		desc_lbl.position = Vector2(12, 82)
		desc_lbl.size = Vector2(226, 40)
		card.add_child(desc_lbl)

		# Progress / Purchase controls
		if not is_unlocked and milestone_met:
			# Render the BUY button
			var buy_btn := Button.new()
			var cost = cfg["cost"]
			buy_btn.text = "BUY - %d COINS" % cost
			buy_btn.size = Vector2(226, 28)
			buy_btn.position = Vector2(12, 135)
			buy_btn.add_theme_font_size_override("font_size", 11)
			
			var btn_style := StyleBoxFlat.new()
			btn_style.bg_color = Color(1.0, 0.85, 0.0) # Yellow
			btn_style.border_width_left = 2
			btn_style.border_width_right = 2
			btn_style.border_width_top = 2
			btn_style.border_width_bottom = 2
			btn_style.border_color = Color.BLACK
			buy_btn.add_theme_stylebox_override("normal", btn_style)
			buy_btn.add_theme_color_override("font_color", Color.BLACK)
			buy_btn.add_theme_color_override("font_hover_color", Color.WHITE)
			
			var coin_balance = _main_node.score if _main_node else 0
			if coin_balance >= cost:
				buy_btn.pressed.connect(func():
					if _main_node:
						_main_node.add_score(-cost)
						if player:
							if cfg["category"] == "weapon":
								player.unlock_weapon(item_key)
							else:
								player.unlock_passive(item_key)
						# Rebuild cards to update visual state
						build_cards()
				)
			else:
				# Disabled / cannot afford
				buy_btn.disabled = true
				buy_btn.modulate = Color(0.5, 0.5, 0.5, 0.8)
				buy_btn.text = "NEED %d COINS" % cost
				
			card.add_child(buy_btn)
		else:
			# Progress text
			var prog_lbl := Label.new()
			if cfg["type"] == "kills":
				prog_lbl.text = "%d / %d KILLS" % [mini(int(current_val), int(target_val)), int(target_val)]
			elif cfg["type"] == "time":
				var cur_sec := mini(int(current_val), int(target_val))
				var cur_m := cur_sec / 60
				var cur_s := cur_sec % 60
				var tar_m := int(target_val) / 60
				var tar_s := int(target_val) % 60
				prog_lbl.text = "%02d:%02d / %02d:%02d" % [cur_m, cur_s, tar_m, tar_s]
			elif cfg["type"] == "bullets":
				prog_lbl.text = "%d / %d BULLETS" % [mini(int(current_val), int(target_val)), int(target_val)]
			elif cfg["type"] == "coins":
				prog_lbl.text = "%d / %d COINS" % [mini(int(current_val), int(target_val)), int(target_val)]
			elif cfg["type"] == "items":
				prog_lbl.text = "%d / %d ITEMS" % [mini(int(current_val), int(target_val)), int(target_val)]
			elif cfg["type"] == "combo":
				prog_lbl.text = "%d / %d COMBO" % [mini(int(current_val), int(target_val)), int(target_val)]
				
			prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			prog_lbl.add_theme_font_size_override("font_size", 11)
			prog_lbl.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0) if not is_unlocked else Color(0.0, 1.0, 0.3))
			prog_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
			prog_lbl.add_theme_constant_override("outline_size", 4)
			prog_lbl.position = Vector2(12, 122)
			prog_lbl.size = Vector2(226, 15)
			card.add_child(prog_lbl)

			# Progress bar
			var prog_bar := ProgressBar.new()
			prog_bar.show_percentage = false
			prog_bar.min_value = 0.0
			prog_bar.max_value = 1.0
			prog_bar.value = pct
			prog_bar.size = Vector2(226, 10)
			prog_bar.position = Vector2(12, 142)
			
			var bg_style := StyleBoxFlat.new()
			bg_style.bg_color = Color(0.05, 0.05, 0.08, 1.0)
			bg_style.border_width_left = 2
			bg_style.border_width_right = 2
			bg_style.border_width_top = 2
			bg_style.border_width_bottom = 2
			bg_style.border_color = Color(0.2, 0.2, 0.25, 1.0)
			bg_style.corner_radius_top_left = 0
			bg_style.corner_radius_top_right = 0
			bg_style.corner_radius_bottom_left = 0
			bg_style.corner_radius_bottom_right = 0
			prog_bar.add_theme_stylebox_override("background", bg_style)
			
			var fg_style := StyleBoxFlat.new()
			fg_style.bg_color = Color(1.0, 0.85, 0.0) if not is_unlocked else Color(0.0, 1.0, 0.3)
			fg_style.corner_radius_top_left = 0
			fg_style.corner_radius_top_right = 0
			fg_style.corner_radius_bottom_left = 0
			fg_style.corner_radius_bottom_right = 0
			prog_bar.add_theme_stylebox_override("fill", fg_style)
			
			card.add_child(prog_bar)

		# 5. Hover animation (retro scale on hover)
		card.pivot_offset = card.custom_minimum_size / 2.0
		var make_hover_tween = func(hovering: bool):
			var t := card.create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
			var scale_target := Vector2(1.04, 1.04) if hovering else Vector2.ONE
			t.tween_property(card, "scale", scale_target, 0.12)
			
		card.mouse_entered.connect(make_hover_tween.bind(true))
		card.mouse_exited.connect(make_hover_tween.bind(false))
