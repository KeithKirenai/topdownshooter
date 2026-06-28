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
		var style := HudUiKit.make_glass_panel(
				Color(0.06, 0.08, 0.15, 0.90),
				Color(0.26, 0.40, 0.78, 0.55), 8)
		style.shadow_size = 7
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
		var has_ammo := true # All weapons show ammo (either clip/reserve or clip/∞)
		var ammo_count: int = inv[i][1] if (inv[i] is Array and inv[i].size() > 1) else -1
		var clip_count: int = inv[i][2] if (inv[i] is Array and inv[i].size() > 2) else -1
		_build_slot(i, weapon_name, is_active, has_ammo, ammo_count, clip_count, SLOT_SIZE, GAP, PAD)


# ===================================================================
# _build_slot
# ===================================================================
func _build_slot(i: int, weapon_name: String, is_active: bool,
		has_ammo: bool, ammo_count: int, clip_count: int,
		slot_size: int, gap: int, pad: int) -> void:
	var slot := Panel.new()
	slot.size         = Vector2(slot_size, slot_size)
	slot.position     = Vector2(pad + i * (slot_size + gap), pad)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.pivot_offset = slot.size / 2
	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color.TRANSPARENT
	slot_style.shadow_color = Color(0, 0, 0, 0.45)
	slot_style.shadow_size = 8
	slot_style.shadow_offset = Vector2(3, 3)
	slot.add_theme_stylebox_override("panel", slot_style)
	
	HudUiKit.decorate_retro_item_card(slot, is_active)

	if is_active:
		var border_rect := ColorRect.new()
		border_rect.name         = "ActiveBorder"
		border_rect.color        = Color(1.0, 0.85, 0.20, 0.85)
		border_rect.size         = Vector2(slot_size + 4, slot_size + 4)
		border_rect.position     = Vector2(-2, -2)
		border_rect.z_index      = -1
		border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(border_rect)

	# Icon
	var icon := TextureRect.new()
	icon.texture      = _textures.get(weapon_name)
	icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	icon.size         = Vector2(slot_size - 10, slot_size - 10)
	icon.position     = Vector2(5, 5)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate     = Color(1.22, 1.16, 0.88, 1.0) if is_active else Color.WHITE
	slot.add_child(icon)

	# Slot number badge
	var num_lbl := Label.new()
	num_lbl.text     = str(i + 1) if i < 9 else "0"
	num_lbl.size     = Vector2(20, 16)
	num_lbl.position = Vector2(4, slot_size - 18)
	num_lbl.add_theme_color_override("font_color",         HudUiKit.C_TEXT_DIM)
	num_lbl.add_theme_font_size_override("font_size",      11)
	num_lbl.add_theme_constant_override("outline_size",    2)
	num_lbl.add_theme_color_override("font_outline_color", HudUiKit.C_OUTLINE)
	num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(num_lbl)

	# Ammo badge
	if has_ammo:
		var ammo_bg := ColorRect.new()
		ammo_bg.color       = Color(0.0, 0.0, 0.0, 0.58)
		ammo_bg.size        = Vector2(46, 16)
		ammo_bg.position    = Vector2(slot_size - 48, 2)
		ammo_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(ammo_bg)
		
		var ammo_lbl := Label.new()
		ammo_lbl.name = "AmmoLabel"
		if ammo_count == -1:
			ammo_lbl.text = str(clip_count) + "/∞" if clip_count != -1 else "∞"
		else:
			ammo_lbl.text = str(clip_count) + "/" + str(ammo_count)
		ammo_lbl.size     = Vector2(46, 16)
		ammo_lbl.position = Vector2(slot_size - 48, 2)
		ammo_lbl.add_theme_color_override("font_color",         HudUiKit.C_TEXT_PRI)
		ammo_lbl.add_theme_font_size_override("font_size",      9)
		ammo_lbl.add_theme_constant_override("outline_size",    2)
		ammo_lbl.add_theme_color_override("font_outline_color", HudUiKit.C_OUTLINE)
		ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ammo_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(ammo_lbl)

	# Cooldown bar
	var cd_bg := ColorRect.new()
	cd_bg.name        = "CooldownBg"
	cd_bg.color       = Color(0, 0, 0, 0.62)
	cd_bg.size        = Vector2(slot_size, 5)
	cd_bg.position    = Vector2(0, slot_size - 5)
	cd_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(cd_bg)
	var cd_bar := ColorRect.new()
	cd_bar.name        = "CooldownBar"
	cd_bar.color       = HudUiKit.C_SUCCESS
	cd_bar.size        = Vector2(0, 5)
	cd_bar.position    = Vector2(0, slot_size - 5)
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
			var sz: float = slot.size.x
			if cooldowns.has(i):
				var cd: Dictionary = cooldowns[i]
				var ratio: float = 1.0 - (cd.current / cd.max) if cd.max > 0.0 else 1.0
				cd_bar.size.x = sz * ratio
			else:
				cd_bar.size.x = sz


# ===================================================================
# tick — call from _process each frame
# ===================================================================
func tick(time: float, player_node) -> void:
	if not _bg or not _bg.visible:
		return
	var vp_h: float = _bg.get_viewport_rect().size.y
	_bg.position.y = vp_h - _bg.size.y - 5.0 + sin(time * 1.78) * 2.8

	for i in range(_slots.size()):
		var slot   := _slots[i]
		var active := (i == _active_idx)
		
		# Dynamic ammo counting and color updates
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
			var pulse: float = sin(time * 7.0) * 0.088
			slot.scale        = Vector2(1.17 + pulse, 1.17 + pulse)
			slot.pivot_offset = slot.size / 2
			slot.rotation     = sin(time * 6.0) * 0.04
			var ab := slot.get_node_or_null("ActiveBorder") as ColorRect
			if ab:
				var ab_b: float = 0.82 + sin(time * 5.5) * 0.14
				ab.color = Color(1.0, 0.85 + sin(time * 6.0) * 0.11, 0.20, ab_b)
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
				var sz: float = slot.size.x
				if cds.has(i):
					var cd: Dictionary = cds[i]
					var ratio: float = 1.0 - (cd.current / cd.max) if cd.max > 0.0 else 1.0
					cd_bar.size.x = sz * ratio
					cd_bar.color  = Color(lerpf(1.0, 0.15, ratio), lerpf(0.15, 1.0, ratio), 0.22, 0.94)
				else:
					cd_bar.size.x = sz
					cd_bar.color  = HudUiKit.C_SUCCESS


# ===================================================================
# update_weapon_description — premium card with typed locals (no inference errors)
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
		var style := HudUiKit.make_glass_panel(
				Color(0.06, 0.08, 0.16, 0.90),
				Color(0.26, 0.40, 0.78, 0.52), 10)
		_desc_bg.add_theme_stylebox_override("panel", style)
		_control.add_child(_desc_bg)

		_desc_lbl = RichTextLabel.new()
		_desc_lbl.name          = "WeaponDescLbl"
		_desc_lbl.bbcode_enabled = true
		_desc_lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		_desc_lbl.scroll_active = false
		_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		_desc_bg.add_child(_desc_lbl)

	# Accent color bar — use typed local to avoid inference error
	var color_bar := _desc_bg.get_node_or_null("AccentBar") as ColorRect
	if not color_bar:
		color_bar = ColorRect.new()
		color_bar.name        = "AccentBar"
		color_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_desc_bg.add_child(color_bar)
	var detail_color: Color = details.get("color", Color.WHITE)
	color_bar.color    = Color(detail_color.r, detail_color.g, detail_color.b, 0.92)
	color_bar.size     = Vector2(4, 80)
	color_bar.position = Vector2(6, 10)

	const W := 780
	const H := 100
	_desc_bg.offset_left   = -float(W) / 2.0
	_desc_bg.offset_right  = float(W) / 2.0
	_desc_bg.offset_top    = -225
	_desc_bg.offset_bottom = -125
	_desc_lbl.size         = Vector2(W - 22, H)
	_desc_lbl.position     = Vector2(16, 0)

	# Build BBCode text — all vars explicitly typed (no inference errors)
	var tc_hex:       String = detail_color.to_html(false)
	var gold_hex:     String = HudUiKit.C_GOLD.to_html(false)
	var sec_hex:      String = HudUiKit.C_TEXT_SEC.to_html(false)
	var detail_name:  String = details.get("name",   "")
	var detail_dmg:   String = details.get("damage", "")
	var detail_desc:  String = details.get("desc",   "")
	var bb_text: String = (
		"[center][font_size=25][b][color=#" + tc_hex + "]" + detail_name
		+ "[/color][/b]  [color=#" + gold_hex + "]" + detail_dmg
		+ "[/color][/font_size]\n"
		+ "[font_size=18][color=#" + sec_hex + "]" + detail_desc
		+ "[/color][/font_size][/center]")
	_desc_lbl.text = bb_text

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
	var decay: float = exp(-_desc_anim_progress * 4.0)
	var sc_t: float  = 1.0 + sin((1.0 - _desc_anim_progress) * PI * 4.0) * 0.18 * decay
	_desc_lbl.scale        = Vector2(sc_t, sc_t)
	_desc_lbl.pivot_offset = _desc_lbl.size / 2.0
	_desc_lbl.rotation     = sin((1.0 - _desc_anim_progress) * PI * 3.0) \
							  * 0.052 * exp(-_desc_anim_progress * 3.0)
	# Accent bar shimmer
	var accent_bar := _desc_bg.get_node_or_null("AccentBar") as ColorRect
	if accent_bar:
		var ab: Color = accent_bar.color
		accent_bar.color = Color(ab.r, ab.g, ab.b, 0.68 + sin(time * 3.4) * 0.26)
