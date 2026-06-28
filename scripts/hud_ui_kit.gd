## hud_ui_kit.gd
## Shared design-token constants and primitive node-builder helpers.
## Extended by every other HUD module so they all share the same palette.
class_name HudUiKit
extends RefCounted

# Pre-rendered coin animation frames (populated at startup by HUD)
static var coin_frames: Array[Texture2D] = []

static func draw_coin_on_canvas(canvas: CanvasItem, center: Vector2, radius: float, width_factor: float) -> void:
	var thick_offset := Vector2(2.8 * (radius / 14.5) * sign(width_factor), 0)
	if abs(width_factor) < 0.08:
		thick_offset = Vector2.ZERO

	var points: PackedVector2Array = []
	var dark_points: PackedVector2Array = []
	for i in range(6):
		var angle := float(i) * PI / 3.0
		var pt := center + Vector2(cos(angle) * radius * width_factor, sin(angle) * radius)
		points.append(pt)
		dark_points.append(pt + thick_offset)

	if thick_offset != Vector2.ZERO:
		var edge_color := Color(0.68, 0.42, 0.0)
		for i in range(6):
			var next := (i + 1) % 6
			var normal := (points[next] - points[i]).orthogonal().normalized()
			if normal.dot(thick_offset) > 0:
				var quad := PackedVector2Array([
					points[i], points[next],
					dark_points[next], dark_points[i]
				])
				canvas.draw_polygon(quad, [edge_color, edge_color, edge_color, edge_color])

	var face_color := Color(1.0, 0.85, 0.20)
	canvas.draw_polygon(points, [face_color, face_color, face_color, face_color, face_color, face_color])

	for i in range(6):
		var next := (i + 1) % 6
		canvas.draw_line(points[i], points[next], Color(0.82, 0.58, 0.0), 1.3 * (radius / 14.5))

	var inner_points := PackedVector2Array()
	for i in range(6):
		var angle := float(i) * PI / 3.0
		inner_points.append(center + Vector2(cos(angle) * radius * 0.42 * width_factor, sin(angle) * radius * 0.42))
	canvas.draw_polygon(inner_points, [Color(0.85, 0.62, 0.0), Color(0.85, 0.62, 0.0), Color(0.85, 0.62, 0.0), Color(0.85, 0.62, 0.0), Color(0.85, 0.62, 0.0), Color(0.85, 0.62, 0.0)])


# ===================================================================
# DESIGN TOKENS — Premium Mobile / Gacha UI Color System
# ===================================================================
const C_GOLD         := Color(1.00, 0.85, 0.20, 1.0)
const C_GOLD_BRIGHT  := Color(1.00, 0.96, 0.50, 1.0)
const C_CYAN         := Color(0.25, 0.82, 1.00, 1.0)
const C_CORAL        := Color(1.00, 0.42, 0.22, 1.0)
const C_DANGER       := Color(1.00, 0.20, 0.20, 1.0)
const C_SUCCESS      := Color(0.22, 1.00, 0.55, 1.0)
const C_LAVENDER     := Color(0.65, 0.48, 1.00, 1.0)
const C_PANEL_BG     := Color(0.06, 0.09, 0.17, 0.90)
const C_PANEL_BORDER := Color(0.28, 0.48, 0.82, 0.75)
const C_TEXT_PRI     := Color(1.00, 1.00, 1.00, 1.0)
const C_TEXT_SEC     := Color(0.62, 0.70, 0.85, 1.0)
const C_TEXT_DIM     := Color(0.38, 0.44, 0.58, 0.85)
const C_OUTLINE      := Color(0.04, 0.06, 0.12, 1.0)

# ===================================================================
# JAPANESE GACHA RARITY COLORS (Uma Musume / Cygames palette)
# ===================================================================
const RARITY_COLORS := {
	"common":    Color(0.50, 0.55, 0.65, 1.0),
	"rare":      Color(0.25, 0.82, 1.00, 1.0),
	"epic":      Color(0.65, 0.48, 1.00, 1.0),
	"legendary": Color(1.00, 0.85, 0.20, 1.0),
	"ultra":     Color(1.00, 0.42, 0.22, 1.0),
}
const RARITY_NAMES := {
	"common":    "COMMON",
	"rare":      "RARE",
	"epic":      "EPIC",
	"legendary": "LEGENDARY",
	"ultra":     "ULTRA RARE",
}
const RARITY_GLOW_COLORS := {
	"common":    Color(0.50, 0.55, 0.65, 0.30),
	"rare":      Color(0.25, 0.82, 1.00, 0.35),
	"epic":      Color(0.65, 0.48, 1.00, 0.40),
	"legendary": Color(1.00, 0.85, 0.20, 0.50),
	"ultra":     Color(1.00, 0.42, 0.22, 0.55),
}
# Rarity pull costs and rates
const RARITY_WEIGHTS := {
	"common":    0.50,
	"rare":      0.30,
	"epic":      0.12,
	"legendary": 0.06,
	"ultra":     0.02,
}
const PULL_COST := 100  # coins per single pull

# ===================================================================
# WEAPON DETAIL CATALOGUE
# ===================================================================
const WEAPON_DETAILS: Dictionary = {
	"pistol":  {"name": "Pistol",           "desc": "Standard backup sidearm. Infinite ammo.",            "damage": "2 DMG",            "color": Color(0.8, 0.8, 0.8)},
	"smg":     {"name": "SMG",              "desc": "Rapid-fire submachine gun. Fast but inaccurate.",     "damage": "1 DMG",            "color": Color(0.4, 0.8, 1.0)},
	"shotgun": {"name": "Shotgun",          "desc": "Short-range burst. Fires 8 spreading pellets.",      "damage": "1 DMG x8",         "color": Color(1.0, 0.6, 0.2)},
	"minigun": {"name": "Minigun",          "desc": "Extreme fire rate. Accuracy decays as you fire.",    "damage": "1 DMG",            "color": Color(1.0, 0.4, 0.4)},
	"sniper":  {"name": "Sniper Rifle",     "desc": "Armor-piercing rail shot. Pierces all enemies.",     "damage": "30 DMG (Piercing)","color": Color(0.2, 0.6, 1.0)},
	"missile": {"name": "Missile Launcher", "desc": "Fires explosive rockets. Large splash radius.",      "damage": "5+15 splash DMG",  "color": Color(0.8, 0.2, 1.0)},
}

# Weapon accent colors used by both the shop cards and the weapon description bar
const WEAPON_ACCENT_COLORS: Dictionary = {
	"smg":          Color(0.25, 0.82, 1.00, 1.0),  # cyan
	"shotgun":      Color(1.00, 0.42, 0.22, 1.0),  # coral
	"minigun":      Color(1.00, 0.20, 0.20, 1.0),  # danger red
	"sniper":       Color(0.20, 0.60, 1.00, 1.0),  # blue
	"missile":      Color(0.65, 0.48, 1.00, 1.0),  # lavender
	"ammo":         Color(1.00, 0.85, 0.20, 1.0),  # gold
	"heal":         Color(0.22, 1.00, 0.55, 1.0),  # success green
	"extend_heart": Color(1.00, 0.40, 0.75, 1.0),  # pink
}

# ===================================================================
# make_glass_panel — rounded glass-style StyleBoxFlat
# ===================================================================
static func make_glass_panel(
		bg: Color = C_PANEL_BG,
		border: Color = C_PANEL_BORDER,
		radius: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	s.border_width_left   = 1
	s.border_width_right  = 1
	s.border_width_top    = 1
	s.border_width_bottom = 1
	s.border_color = border
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size  = 8
	s.shadow_offset = Vector2(0, 4)
	return s


# ===================================================================
# make_pixel_panel — pixel-art style panel with thick solid borders & hard shadow
# ===================================================================
static func make_pixel_panel(
		bg: Color = Color(0.02, 0.02, 0.04, 0.96),
		border: Color = Color(1.0, 0.85, 0.0, 1.0),
		border_width: int = 5,
		shadow_offset: Vector2 = Vector2(8, 8)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_left   = border_width
	s.border_width_right  = border_width
	s.border_width_top    = border_width
	s.border_width_bottom = border_width
	s.border_color = border
	s.corner_radius_top_left     = 0
	s.corner_radius_top_right    = 0
	s.corner_radius_bottom_left  = 0
	s.corner_radius_bottom_right = 0
	s.shadow_color = Color(0, 0, 0, 1.0)
	s.shadow_size  = 0
	s.shadow_offset = shadow_offset
	return s


# ===================================================================
# make_button_style — tactile pressable button style variants
# ===================================================================
static func make_button_style(accent: Color, base: Color = Color(0.08, 0.12, 0.22, 0.95), radius: int = 14) -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = base
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_color = accent.lerp(Color(1, 1, 1, 1), 0.40)
	normal.corner_radius_top_left = radius
	normal.corner_radius_top_right = radius
	normal.corner_radius_bottom_left = radius
	normal.corner_radius_bottom_right = radius
	normal.shadow_color = Color(0, 0, 0, 0.30)
	normal.shadow_size = 9
	normal.shadow_offset = Vector2(0, 4)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = base.lightened(0.08)
	hover.border_color = accent

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = base.darkened(0.16)
	pressed.border_color = accent.darkened(0.22)
	pressed.shadow_size = 4
	pressed.shadow_offset = Vector2(0, 1)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.12, 0.14, 0.18, 0.80)
	disabled.border_color = Color(0.22, 0.24, 0.30, 0.50)
	disabled.shadow_size = 0

	return {
		"normal": normal,
		"hover": hover,
		"pressed": pressed,
		"disabled": disabled,
	}


# ===================================================================
# style_button — apply tactile button styles and text token overrides
# ===================================================================
static func style_button(btn: Button, accent: Color, font_size: int = 15) -> void:
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", C_TEXT_PRI)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6, 0.65))

	var style := make_button_style(accent)
	btn.add_theme_stylebox_override("normal", style["normal"])
	btn.add_theme_stylebox_override("hover", style["hover"])
	btn.add_theme_stylebox_override("pressed", style["pressed"])
	btn.add_theme_stylebox_override("disabled", style["disabled"])
	btn.add_theme_stylebox_override("focus", style["normal"])


# ===================================================================
# add_rim_highlight — top-edge highlight strip inside a panel
# ===================================================================
static func add_rim_highlight(
		parent: Control, w: float,
		col: Color = Color(1, 1, 1, 0.12)) -> ColorRect:
	var rim := ColorRect.new()
	rim.color       = col
	rim.size        = Vector2(maxf(w - 20.0, 4.0), 2)
	rim.position    = Vector2(10, 2)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rim)
	return rim


# ===================================================================
# spawn_ui_burst — one-shot CPUParticles2D burst anchored to a Control
# ===================================================================
static func spawn_ui_burst(
		parent: Control,
		count: int,
		cols: Array[Color],
		speed_min: float = 40.0,
		speed_max: float = 130.0,
		lifetime: float = 0.7) -> void:
	var p := CPUParticles2D.new()
	p.emitting          = false
	p.amount            = count
	p.lifetime          = lifetime
	p.one_shot          = true
	p.explosiveness     = 0.90
	p.spread            = 180.0
	p.gravity           = Vector2(0, 70)
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.scale_amount_min  = 2.0
	p.scale_amount_max  = 5.0
	if cols.size() > 0:
		p.color = cols[0]
	if cols.size() >= 2:
		var g := Gradient.new()
		g.set_color(0, cols[0])
		g.set_color(1, cols[1])
		p.color_ramp = g
	p.position    = parent.size / 2.0
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


# ===================================================================
# make_glow_ring — aura glow behind a control
# ===================================================================
static func make_glow_ring(
		parent: Control,
		size: float,
		color: Color,
		alpha: float = 0.30) -> ColorRect:
	var g := ColorRect.new()
	g.color       = color
	g.color.a     = alpha
	g.size        = Vector2(size, size)
	g.position    = (parent.size - g.size) / 2.0
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.self_modulate.a = 0.0  # start invisible for tween-in
	parent.add_child(g)
	parent.move_child(g, 0)
	return g


# ===================================================================
# make_gradient_overlay — subtle vertical gradient overlay
# ===================================================================
static func make_gradient_overlay(
		parent: Control,
		top_color: Color = Color(1, 1, 1, 0.08),
		bottom_color: Color = Color(0, 0, 0, 0.15)) -> ColorRect:
	# Using a simple two-color approach with a ColorRect + modulate trick:
	# In Godot 4 CanvasItem, we stack two ColorRects at half opacity each.
	var top := ColorRect.new()
	top.color       = top_color
	top.size        = Vector2(parent.size.x, parent.size.y * 0.5)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(top)

	var bot := ColorRect.new()
	bot.color       = bottom_color
	bot.position    = Vector2(0, parent.size.y * 0.5)
	bot.size        = Vector2(parent.size.x, parent.size.y * 0.5)
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bot)
	return top


# ===================================================================
# make_premium_card — layered card with shadow, border, and rim
# ===================================================================
static func make_premium_card(
		parent: Control,
		w: float, h: float,
		accent: Color = C_PANEL_BORDER,
		depth: int = 0) -> Control:
	# Outer drop-shadow
	var shadow := ColorRect.new()
	shadow.color        = Color(0, 0, 0, 0.35 + depth * 0.08)
	shadow.size         = Vector2(w + 4, h + 4)
	shadow.position     = Vector2(-2 + 1 + depth, 3 + depth)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shadow)

	# Main card bg
	var card := ColorRect.new()
	card.color       = Color(0.08, 0.10, 0.20, 0.92)
	card.size        = Vector2(w, h)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(card)

	# Colored top border strip
	var strip := ColorRect.new()
	strip.color       = accent
	strip.size        = Vector2(w, 3)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(strip)

	# Rim highlight
	add_rim_highlight(parent, w, Color(1, 1, 1, 0.10))

	return card


# ===================================================================
# spawn_floating_motes — ambient floating particles (always-on)
# ===================================================================
static func spawn_floating_motes(
		parent: Control,
		col: Color = Color(1, 1, 1, 0.30),
		count: int = 15) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting             = true
	p.amount               = count
	p.lifetime             = 6.0
	p.one_shot             = false
	p.explosiveness        = 0.50
	p.spread               = 360.0
	p.gravity              = Vector2(0, -8)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 8.0
	p.scale_amount_min     = 0.5
	p.scale_amount_max     = 2.0
	# `hue_variation` is not available on CPUParticles2D in this engine version.
	# Use `color` and a gentle `color_ramp` based on the provided `col`.
	p.color                = col
	# create a subtle two-stop ramp using a slightly darker variant
	var g2 := Gradient.new()
	var darker := Color(clamp(col.r * 0.9, 0, 1), clamp(col.g * 0.9, 0, 1), clamp(col.b * 0.9, 0, 1), col.a * 0.85)
	g2.set_color(0, col)
	g2.set_color(1, darker)
	p.color_ramp = g2
	p.position             = parent.size / 2.0
	# Use rectangle emission extents to spread motes across the parent area.
	# CPUParticles2D supports `emission_shape` and `emission_rect_extents`.
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	# set extents to half the parent size for even spread
	p.emission_rect_extents = parent.size * 0.5
	parent.add_child(p)
	parent.move_child(p, 0)
	return p


# ===================================================================
# make_gacha_pull_button — big premium pull button with glow cap
# ===================================================================
static func make_gacha_pull_button(
		parent: Control,
		label: String = "PULL",
		sub_label: String = "★ 100 coins",
		cost: int = 100) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(240, 88)
	btn.size = Vector2(240, 88)
	btn.text = ""
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	style_button(btn, C_GOLD_BRIGHT, 24)

	# Add a bright gloss highlight at the top
	var gloss := ColorRect.new()
	gloss.color = Color(1, 1, 1, 0.08)
	gloss.size = Vector2(220, 32)
	gloss.position = Vector2(10, 10)
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(gloss)

	# Label
	var lbl := Label.new()
	lbl.text = label
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", C_GOLD_BRIGHT)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.80))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(0, 4)
	lbl.size = Vector2(240, 48)
	btn.add_child(lbl)

	# Sub-label (cost)
	var slbl := Label.new()
	slbl.text = sub_label
	slbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slbl.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
	slbl.add_theme_font_size_override("font_size", 14)
	slbl.add_theme_color_override("font_color", C_TEXT_SEC)
	slbl.position = Vector2(0, 52)
	slbl.size = Vector2(240, 26)
	btn.add_child(slbl)

	parent.add_child(btn)
	return btn


# ===================================================================
# decorate_retro_panel — programmatically draw retro pixel-art panel details
# ===================================================================
static func decorate_retro_panel(panel: Control, accent_color: Color = Color(1, 1, 0)) -> void:
	var decorator := Control.new()
	decorator.name = "RetroPanelDecorator"
	decorator.set_anchors_preset(Control.PRESET_FULL_RECT)
	decorator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(decorator)
	
	decorator.draw.connect(func():
		var W := decorator.size.x
		var H := decorator.size.y
		if W <= 0 or H <= 0:
			return
			
		# 1. Royal Blue to Deep Indigo vertical gradient fill (classic SNES menu style)
		var top_color := Color(0.04, 0.08, 0.28, 0.95)  # Royal Blue
		var bot_color := Color(0.01, 0.02, 0.08, 0.98)  # Deep Indigo/Black
		var bg_points := PackedVector2Array([
			Vector2(4, 4),
			Vector2(W - 4, 4),
			Vector2(W - 4, H - 4),
			Vector2(4, H - 4)
		])
		var bg_colors := PackedColorArray([
			top_color, top_color,
			bot_color, bot_color
		])
		decorator.draw_polygon(bg_points, bg_colors)
		
		# 2. Draw Repeating Carved Golden Rope Borders (NES/SNES Console style)
		# Top border
		var draw_h_border := func(y: float):
			var x_start := 16.0
			var x_end := W - 16.0
			decorator.draw_rect(Rect2(x_start, y, x_end - x_start, 8), Color(0.08, 0.06, 0.03)) # dark border
			decorator.draw_rect(Rect2(x_start, y + 1, x_end - x_start, 6), Color(0.82, 0.60, 0.12)) # gold fill
			
			# Carved rope details (alternating diagonal highlights and shadows)
			var step := 8.0
			for x in range(int(x_start), int(x_end), int(step)):
				decorator.draw_line(Vector2(x + 2, y + 1), Vector2(x + 5, y + 4), Color(1.0, 0.90, 0.45), 1.0)
				decorator.draw_line(Vector2(x + 3, y + 5), Vector2(x + 6, y + 5), Color(0.48, 0.32, 0.05), 1.0)
				
		# Left border
		var draw_v_border := func(x: float):
			var y_start := 16.0
			var y_end := H - 16.0
			decorator.draw_rect(Rect2(x, y_start, 8, y_end - y_start), Color(0.08, 0.06, 0.03)) # dark border
			decorator.draw_rect(Rect2(x + 1, y_start, 6, y_end - y_start), Color(0.82, 0.60, 0.12)) # gold fill
			
			var step := 8.0
			for y in range(int(y_start), int(y_end), int(step)):
				decorator.draw_line(Vector2(x + 1, y + 2), Vector2(x + 4, y + 5), Color(1.0, 0.90, 0.45), 1.0)
				decorator.draw_line(Vector2(x + 5, y + 3), Vector2(x + 5, y + 6), Color(0.48, 0.32, 0.05), 1.0)
				
		draw_h_border.call(4.0)
		draw_h_border.call(H - 12.0)
		draw_v_border.call(4.0)
		draw_v_border.call(W - 12.0)
		
		# 3. Draw Ornate 16x16 Golden Corner Plaques with Ruby Gems
		var draw_corner := func(x: float, y: float):
			# Dark outline
			decorator.draw_rect(Rect2(x, y, 16, 16), Color(0.08, 0.06, 0.03))
			# Gold metal plate
			decorator.draw_rect(Rect2(x + 1, y + 1, 14, 14), Color(0.85, 0.64, 0.15))
			# Bevel Highlights (Top and Left)
			decorator.draw_rect(Rect2(x + 1, y + 1, 13, 1), Color(1.0, 0.92, 0.55))
			decorator.draw_rect(Rect2(x + 1, y + 2, 1, 12), Color(1.0, 0.92, 0.55))
			# Bevel Shadows (Bottom and Right)
			decorator.draw_rect(Rect2(x + 2, y + 14, 13, 1), Color(0.48, 0.32, 0.05))
			decorator.draw_rect(Rect2(x + 14, y + 2, 1, 12), Color(0.48, 0.32, 0.05))
			
			# ruby gemstone in center (6x6)
			decorator.draw_rect(Rect2(x + 5, y + 5, 6, 6), Color(0.22, 0.02, 0.02)) # gem border
			decorator.draw_rect(Rect2(x + 6, y + 6, 4, 4), Color(0.92, 0.12, 0.20)) # ruby red
			decorator.draw_rect(Rect2(x + 6, y + 6, 1, 1), Color(1.0, 0.75, 0.80)) # specular glint
			
		draw_corner.call(0, 0)
		draw_corner.call(W - 16, 0)
		draw_corner.call(0, H - 16)
		draw_corner.call(W - 16, H - 16)
	)


# ===================================================================
# decorate_retro_item_card — 16-bit console style for smaller weapon cards / hotbar slots
# ===================================================================
static func decorate_retro_item_card(card: Control, is_active: bool = false) -> void:
	var decorator := Control.new()
	decorator.name = "RetroItemDecorator"
	decorator.set_anchors_preset(Control.PRESET_FULL_RECT)
	decorator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(decorator)
	
	decorator.draw.connect(func():
		var W := decorator.size.x
		var H := decorator.size.y
		if W <= 0 or H <= 0:
			return
			
		# 1. Royal Blue to Deep Indigo vertical gradient fill (classic SNES menu style)
		var top_color := Color(0.04, 0.10, 0.32, 0.94) if is_active else Color(0.02, 0.05, 0.18, 0.90)
		var bot_color := Color(0.01, 0.03, 0.10, 0.96) if is_active else Color(0.005, 0.01, 0.04, 0.94)
		var bg_points := PackedVector2Array([
			Vector2(2, 2),
			Vector2(W - 2, 2),
			Vector2(W - 2, H - 2),
			Vector2(2, H - 2)
		])
		var bg_colors := PackedColorArray([
			top_color, top_color,
			bot_color, bot_color
		])
		decorator.draw_polygon(bg_points, bg_colors)
		
		# 2. Draw 16-bit Gold Border
		var border_color := Color(1.0, 0.85, 0.20) if is_active else Color(0.70, 0.52, 0.10)
		var dark_border   := Color(0.08, 0.06, 0.03)
		var light_highlight := Color(1.0, 0.95, 0.65) if is_active else Color(0.90, 0.80, 0.45)
		
		# Outer dark rim
		decorator.draw_rect(Rect2(0, 0, W, H), dark_border, false, 1.0)
		
		# Gold border line (2 pixels wide, inset by 1 pixel)
		decorator.draw_rect(Rect2(1, 1, W - 2, H - 2), border_color, false, 1.0)
		decorator.draw_rect(Rect2(2, 2, W - 4, H - 4), border_color, false, 1.0)
		
		# Bevel highlights (Top and Left inner edges)
		decorator.draw_line(Vector2(2, 2), Vector2(W - 3, 2), light_highlight, 1.0)
		decorator.draw_line(Vector2(2, 2), Vector2(2, H - 3), light_highlight, 1.0)
		
		# Bevel shadows (Bottom and Right inner edges)
		decorator.draw_line(Vector2(3, H - 3), Vector2(W - 3, H - 3), Color(0.38, 0.25, 0.02), 1.0)
		decorator.draw_line(Vector2(W - 3, 3), Vector2(W - 3, H - 3), Color(0.38, 0.25, 0.02), 1.0)
		
		# 3. Draw 4x4 Corner Studs/Rivet Details
		var draw_stud := func(x: float, y: float):
			# 4x4 dark box
			decorator.draw_rect(Rect2(x, y, 4, 4), dark_border)
			# Gold center
			decorator.draw_rect(Rect2(x + 1, y + 1, 2, 2), border_color)
			# Shiny glint pixel
			decorator.draw_rect(Rect2(x + 1, y + 1, 1, 1), Color.WHITE if is_active else light_highlight)
			
		draw_stud.call(1, 1)
		draw_stud.call(W - 5, 1)
		draw_stud.call(1, H - 5)
		draw_stud.call(W - 5, H - 5)
	)
