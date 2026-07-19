## hud_hotbar.gd
## Builds and animates the weapon hotbar at the bottom of the screen.
## Also manages the floating weapon description card.
class_name HudHotbar
extends RefCounted

var _hud_node:    CanvasLayer
var _control:     Control
var _textures:    Dictionary

var _bg:      Panel
var _slots:   Array[Panel] = []
var _active_idx: int = 0

var _desc_bg:  Panel
var _desc_lbl: RichTextLabel
var _last_weapon_name: String = ""
var _desc_timer:    float = 0.0
var _desc_opacity:  float = 0.0
var _desc_anim_progress: float = 0.0

# ===================================================================
# init
# ===================================================================
func init(hud: CanvasLayer, ctrl: Control, textures: Dictionary) -> void:
	_hud_node = hud
	_control  = ctrl
	_textures = textures


# ===================================================================
# build — rebuild all slots for the given inventory
# ===================================================================
func build(inv: Array, idx: int) -> void:
	_active_idx = idx
	_clear_slots()
	
	if not _bg:
		_bg = Panel.new()
		_bg.name          = "HotbarBg"
		_bg.anchor_left   = 0.5
		_bg.anchor_top    = 1.0
		_bg.anchor_right  = 0.5
		_bg.anchor_bottom = 1.0
		_bg.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		_bg.clip_contents = true
		
		var style := HudUiKit.make_pixel_panel(
			Color(0.04, 0.04, 0.08, 0.95),
			Color(0.62, 0.70, 0.85, 1.0),
			3,
			Vector2.ZERO
		)
		_bg.add_theme_stylebox_override("panel", style)
		_control.add_child(_bg)

	const SLOT_SIZE := 72
	const GAP       := 7
	const PAD       := 10
	var total_w: int = inv.size() * SLOT_SIZE + (inv.size() - 1) * GAP + PAD * 2
	var bar_h:   int = SLOT_SIZE + PAD * 2
	_bg.offset_left = -float(total_w) / 2.0
	_bg.offset_top  = -(bar_h + 6)
	_bg.size        = Vector2(total_w, bar_h)

	for i in range(inv.size()):
		var is_active    := (i == idx)
		var weapon_name: String = inv[i][0] if inv[i] is Array else inv[i]
		var ammo_count: int = inv[i][1] if (inv[i] is Array and inv[i].size() > 1) else -1
		var clip_count: int = inv[i][2] if (inv[i] is Array and inv[i].size() > 2) else -1
		_build_slot(i, weapon_name, is_active, ammo_count, clip_count, SLOT_SIZE, GAP, PAD)


# ===================================================================
# _build_slot — creates a single weapon slot with icon, ammo badge, cooldown bar
# ===================================================================
func _build_slot(i: int, weapon_name: String, is_active: bool,
		ammo_count: int, clip_count: int, slot_size: int, gap: int, pad: int) -> void:
	var slot := Panel.new()
	slot.size         = Vector2(slot_size, slot_size)
	slot.position     = Vector2(pad + i * (slot_size + gap), pad)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.pivot_offset = slot.size / 2
	
	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color.TRANSPARENT
	slot.add_theme_stylebox_override("panel", slot_style)
	
	HudUiKit.decorate_retro_item_card(slot, is_active)

	# Active slot gold frame indicator
	if is_active:
		var active_frame := ReferenceRect.new()
		active_frame.name         = "ActiveFrame"
		active_frame.editor_only  = false
		active_frame.border_color = Color(1.0, 0.85, 0.20, 1.0)
		active_frame.border_width = 3.0
		active_frame.size         = slot.size
		active_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(active_frame)

	# Weapon icon
	var icon := TextureRect.new()
	icon.texture      = _textures.get(weapon_name)
	icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	icon.size         = Vector2(slot_size - 16, slot_size - 16)
	icon.position     = Vector2(8, 8)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate     = Color(1.2, 1.15, 0.9, 1.0) if is_active else Color.WHITE
	slot.add_child(icon)

	# Slot number badge
	var num_lbl := Label.new()
	num_lbl.text     = str(i + 1) if i < 9 else "0"
	num_lbl.size     = Vector2(24, 22)
	num_lbl.position = Vector2(6, slot_size - 24)
	num_lbl.add_theme_color_override("font_color",         Color.WHITE)
	num_lbl.add_theme_font_size_override("font_size",      15)
	num_lbl.add_theme_constant_override("outline_size",    3)
	num_lbl.add_theme_color_override("font_outline_color", HudUiKit.C_OUTLINE)
	num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(num_lbl)

	# Ammo badge
	var ammo_bg := ColorRect.new()
	ammo_bg.color       = Color(0.0, 0.0, 0.0, 0.85)
	ammo_bg.size        = Vector2(52, 20)
	ammo_bg.position    = Vector2(slot_size - 54, 2)
	ammo_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(ammo_bg)
	
	var ammo_lbl := Label.new()
	ammo_lbl.name = "AmmoLabel"
	if ammo_count == -1:
		ammo_lbl.text = str(clip_count) + "/∞" if clip_count != -1 else "∞"
	else:
		ammo_lbl.text = str(clip_count) + "/" + str(ammo_count)
	ammo_lbl.size     = Vector2(52, 20)
	ammo_lbl.position = Vector2(slot_size - 54, 2)
	ammo_lbl.add_theme_color_override("font_color",         Color.WHITE)
	ammo_lbl.add_theme_font_size_override("font_size",      13)
	ammo_lbl.add_theme_constant_override("outline_size",    3)
	ammo_lbl.add_theme_color_override("font_outline_color", HudUiKit.C_OUTLINE)
	ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ammo_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ammo_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(ammo_lbl)

	# Cooldown bar
	var cd_bg := ColorRect.new()
	cd_bg.name        = "CooldownBg"
	cd_bg.color       = Color(0.1, 0.1, 0.1, 0.8)
	cd_bg.size        = Vector2(slot_size - 6, 4)
	cd_bg.position    = Vector2(3, slot_size - 8)
	cd_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(cd_bg)
	
	var cd_bar := ColorRect.new()
	cd_bar.name        = "CooldownBar"
	cd_bar.color       = HudUiKit.C_SUCCESS
	cd_bar.size        = Vector2(0, 4)
	cd_bar.position    = Vector2(3, slot_size - 8)
	cd_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(cd_bar)

	_bg.add_child(slot)
	_slots.append(slot)


# ===================================================================
# _clear_slots
# ===================================================================
func _clear_slots() -> void:
	for s in _slots:
		s.queue_free()
	_slots.clear()


# ===================================================================
# refresh_cooldown_bars — call on weapon_changed signal
# ===================================================================
func refresh_cooldown_bars(cooldowns: Dictionary) -> void:
	for i in range(_slots.size()):
		var slot   := _slots[i]
		var cd_bar := slot.get_node_or_null("CooldownBar") as ColorRect
		if cd_bar:
			var max_w: float = slot.size.x - 6.0
			if cooldowns.has(i):
				var cd: Dictionary = cooldowns[i]
				var ratio: float = 1.0 - (cd.current / cd.max) if cd.max > 0.0 else 1.0
				cd_bar.size.x = max_w * ratio
			else:
				cd_bar.size.x = max_w


# ===================================================================
# tick — call from _process each frame
# Animates slot bobbing, active slot scale/rotation, ammo labels, cooldown bars
# ===================================================================
func tick(time: float, player_node) -> void:
	if not _bg or not _bg.visible:
		return
		
	# Stepped bobbing animation for retro grid alignment
	var vp_h: float = _bg.get_viewport_rect().size.y
	var bobbing := floori(sin(time * 1.78) * 3.0)
	_bg.position.y = vp_h - _bg.size.y - 5.0 + bobbing

	var step_time := floorf(time * 12.0) / 12.0
	var pulse     := sin(step_time * 6.0) * 0.06
	var step_rot  := sin(step_time * 5.0) * 0.03

	for i in range(_slots.size()):
		var slot   := _slots[i]
		var active := (i == _active_idx)
		
		var ammo_lbl := slot.get_node_or_null("AmmoLabel") as Label
		if ammo_lbl and player_node and "inventory" in player_node and i < player_node.inventory.size():
			var entry = player_node.inventory[i]
			var ammo_count: int = entry[1]
			var clip_shown: int = roundi(player_node.visual_clip_count) if active else int(entry[2])
			
			if ammo_count == -1:
				ammo_lbl.text = str(clip_shown) + "/∞"
			else:
				ammo_lbl.text = str(clip_shown) + "/" + str(ammo_count)
				
			var clip_max = player_node.WEAPON_DATA.get(entry[0], {}).get("clip_max", 1)
			var ratio = float(clip_shown) / float(clip_max)
			if clip_shown == 0:
				ammo_lbl.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
			elif ratio <= 0.33:
				ammo_lbl.add_theme_color_override("font_color", Color(1.0, 0.72, 0.22))
			else:
				ammo_lbl.add_theme_color_override("font_color", HudUiKit.C_TEXT_PRI)

		if active:
			slot.scale    = Vector2(1.1 + pulse, 1.1 + pulse)
			slot.rotation = step_rot
		else:
			slot.scale    = Vector2.ONE
			slot.rotation = 0.0

	# Live cooldown bar updates from player
	if player_node and "_slot_cooldowns" in player_node:
		var cds: Dictionary = player_node._slot_cooldowns
		for i in range(_slots.size()):
			var slot   := _slots[i]
			var cd_bar := slot.get_node_or_null("CooldownBar") as ColorRect
			if cd_bar:
				var max_w: float = slot.size.x - 6.0
				if cds.has(i):
					var cd: Dictionary = cds[i]
					var ratio: float = 1.0 - (cd.current / cd.max) if cd.max > 0.0 else 1.0
					cd_bar.size.x = max_w * ratio
					if ratio < 0.35:
						cd_bar.color = Color(1.0, 0.25, 0.25)
					elif ratio < 0.7:
						cd_bar.color = Color(1.0, 0.72, 0.22)
					else:
						cd_bar.color = HudUiKit.C_SUCCESS
				else:
					cd_bar.size.x = max_w
					cd_bar.color  = HudUiKit.C_SUCCESS


# ===================================================================
# update_weapon_description — simplified 8-bit text card
# ===================================================================
func update_weapon_description(inv: Array, idx: int, visible_now: bool) -> void:
	if idx < 0 or idx >= inv.size():
		return
	var weapon_name: String = inv[idx][0] if inv[idx] is Array else str(inv[idx])
	if weapon_name == _last_weapon_name:
		return
	_last_weapon_name = weapon_name

	var details: Dictionary = HudUiKit.WEAPON_DETAILS.get(
			weapon_name, HudUiKit.WEAPON_DETAILS["pistol"])

	if not _desc_bg:
		_desc_bg = Panel.new()
		_desc_bg.name          = "WeaponDescBg"
		_desc_bg.anchor_left   = 0.5
		_desc_bg.anchor_top    = 1.0
		_desc_bg.anchor_right  = 0.5
		_desc_bg.anchor_bottom = 1.0
		_desc_bg.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		
		var style := HudUiKit.make_pixel_panel(
				Color(0.04, 0.04, 0.08, 0.95),
				Color(0.62, 0.70, 0.85, 1.0),
				3,
				Vector2.ZERO)
		_desc_bg.add_theme_stylebox_override("panel", style)
		_control.add_child(_desc_bg)

		_desc_lbl = RichTextLabel.new()
		_desc_lbl.name          = "WeaponDescLbl"
		_desc_lbl.bbcode_enabled = true
		_desc_lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		_desc_lbl.scroll_active = false
		_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		_desc_bg.add_child(_desc_lbl)

	# Accent color indicator bar
	var color_bar := _desc_bg.get_node_or_null("AccentBar") as ColorRect
	if not color_bar:
		color_bar = ColorRect.new()
		color_bar.name        = "AccentBar"
		color_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_desc_bg.add_child(color_bar)
	var detail_color: Color = details.get("color", Color.WHITE)
	color_bar.color    = Color(detail_color.r, detail_color.g, detail_color.b, 1.0)
	color_bar.size     = Vector2(6, 80)
	color_bar.position = Vector2(8, 10)

	const W := 780
	const H := 100
	_desc_bg.offset_left   = -float(W) / 2.0
	_desc_bg.offset_right  = float(W) / 2.0
	_desc_bg.offset_top    = -225
	_desc_bg.offset_bottom = -125
	_desc_lbl.size         = Vector2(W - 24, H)
	_desc_lbl.position     = Vector2(18, 0)

	var tc_hex:       String = detail_color.to_html(false)
	var gold_hex:     String = HudUiKit.C_GOLD.to_html(false)
	var sec_hex:      String = HudUiKit.C_TEXT_SEC.to_html(false)
	var detail_name:  String = details.get("name",   "")
	var detail_dmg:   String = details.get("damage", "")
	var detail_desc:  String = details.get("desc",   "")
	
	_desc_lbl.text = (
		"[center][font_size=28][b][color=#" + tc_hex + "]" + detail_name
		+ "[/color][/b]  [color=#" + gold_hex + "]" + detail_dmg
		+ "[/color][/font_size]\n"
		+ "[font_size=19][color=#" + sec_hex + "]" + detail_desc
		+ "[/color][/font_size][/center]")

	_desc_timer        = 0.5
	_desc_opacity      = 1.0
	_desc_anim_progress = 0.0
	_desc_bg.visible   = visible_now
	_desc_bg.modulate.a = 1.0 if visible_now else 0.0


# ===================================================================
# set_desc_visible
# ===================================================================
func set_desc_visible(is_visible: bool) -> void:
	if _desc_bg:
		_desc_bg.visible = is_visible


# ===================================================================
# tick_description — call from _process each frame
# Animates the description card opacity and stepped scale/rotation
# ===================================================================
func tick_description(delta: float, time: float,
		timer_active: bool) -> void:
	if not _desc_bg or not _desc_lbl:
		return

	if timer_active:
		_desc_timer  = maxf(_desc_timer - delta, 0.0)
	_desc_opacity = lerpf(_desc_opacity,
		1.0 if _desc_timer > 0.0 else 0.0,
		delta * (9.5 if _desc_timer > 0.0 else 4.5))

	_desc_bg.modulate.a = _desc_opacity
	_desc_anim_progress = minf(_desc_anim_progress + delta * 3.5, 1.0)
	
	var step_progress := floorf(_desc_anim_progress * 10.0) / 10.0
	var decay: float = exp(-step_progress * 4.0)
	var sc_t: float  = 1.0 + sin((1.0 - step_progress) * PI * 4.0) * 0.15 * decay
	
	_desc_lbl.scale        = Vector2(sc_t, sc_t)
	_desc_lbl.pivot_offset = _desc_lbl.size / 2.0
	_desc_lbl.rotation     = sin((1.0 - step_progress) * PI * 3.0) * 0.04 * exp(-step_progress * 3.0)
