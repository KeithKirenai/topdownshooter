## hud.gd — Orchestrator
## Thin coordinator: owns scene-tree nodes, delegates all logic to
## HudShop, HudHotbar, HudCombat (in their respective .gd files),
## and reads shared tokens from HudUiKit.
extends CanvasLayer

# ===================================================================
# LOCAL ALIASES (keeps call sites readable without losing the module)
# ===================================================================
const C_GOLD        := HudUiKit.C_GOLD
const C_GOLD_BRIGHT := HudUiKit.C_GOLD_BRIGHT
const C_CYAN        := HudUiKit.C_CYAN
const C_CORAL       := HudUiKit.C_CORAL
const C_DANGER      := HudUiKit.C_DANGER
const C_SUCCESS     := HudUiKit.C_SUCCESS
const C_LAVENDER    := HudUiKit.C_LAVENDER
const C_PANEL_BG    := HudUiKit.C_PANEL_BG
const C_PANEL_BORDER:= HudUiKit.C_PANEL_BORDER
const C_TEXT_PRI    := HudUiKit.C_TEXT_PRI
const C_TEXT_SEC    := HudUiKit.C_TEXT_SEC
const C_TEXT_DIM    := HudUiKit.C_TEXT_DIM
const C_OUTLINE     := HudUiKit.C_OUTLINE

# ===================================================================
# MODULE INSTANCES
# ===================================================================
var _shop:   HudShop
var _hotbar: HudHotbar
var _combat: HudCombat

# ===================================================================
# STATE
# ===================================================================
var can_restart:   bool  = false
var _animating_coins: bool  = false
var _displayed_score: int   = 0
var _time:          float = 0.0
var _score_glow_time: float = 0.0
var _reload_ui_total_duration: float = 0.0

# Autohide slide vars
var _hud_container_offset:    float = 0.0
var _hearts_container_offset: float = 0.0
var _hud_hide_timer:          float = 0.0
var _hearts_hide_timer:       float = 0.0
var _hud_target_opacity:      float = 0.0
var _hearts_target_opacity:   float = 0.0

# Title particles
var _title_particles: CPUParticles2D = null

# Pause
var _pause_panel: ColorRect
var _pause_label: Label
var _touch_layer: Control = null

# Sounds
var _menu_nav_sound:    AudioStream
var _round_start_sound: AudioStream
var _round_win_sound:   AudioStream
var _drum_tick_sound:   AudioStream

# Weapon textures (shared with modules)
var _weapon_textures := {
	"pistol":       preload("res://assets/sprites/gun.png"),
	"smg":          preload("res://assets/sprites/smg.png"),
	"shotgun":      preload("res://assets/sprites/shotgun.png"),
	"minigun":      preload("res://assets/sprites/minigun.png"),
	"sniper":       preload("res://assets/sprites/sniper.png"),
	"missile":      preload("res://assets/sprites/missile.png"),
	"heart":        preload("res://assets/ui/heart.png"),
	"heart_plus":   preload("res://assets/ui/heart_plus.png"),
	"laser":        preload("res://assets/ui/crosshair.png"),
	"ammo":         preload("res://assets/ui/ammo_icon.png"),
	"shield":       load("res://assets/ui/passive_shield.jpg"),
	"speed_loader": load("res://assets/ui/passive_speed_loader.jpg"),
	"golden_touch": load("res://assets/ui/passive_golden_touch.jpg"),
	"magnet_ring":  load("res://assets/ui/passive_magnet_ring.jpg"),
	"toughness":    load("res://assets/ui/passive_toughness.jpg"),
	"damage_boost": load("res://assets/ui/passive_damage_boost.jpg"),
}


# ===================================================================
# _ready
# ===================================================================
func _ready() -> void:
	layer        = 2
	process_mode = PROCESS_MODE_ALWAYS
	_pre_render_coin_textures()

	# Load sounds
	_menu_nav_sound    = load("res://assets/sounds/menu_nav.wav")
	_round_start_sound = load("res://assets/sounds/round_start.wav")
	_round_win_sound   = load("res://assets/sounds/round_win.wav")
	_drum_tick_sound   = load("res://assets/sounds/drum_tick.wav")

	# ── Modules ──────────────────────────────────────────────────────
	_shop = HudShop.new()
	_shop.init($Control/ShopPanel, _weapon_textures, self)

	_hotbar = HudHotbar.new()
	_hotbar.init(self, $Control, _weapon_textures)

	_combat = HudCombat.new()
	_combat.init(self, $Control)
	_combat.snd_round_start = _round_start_sound
	_combat.snd_round_win   = _round_win_sound
	_combat.snd_drum_tick   = _drum_tick_sound
	_combat.snd_kaching     = load("res://assets/sounds/kaching.wav")
	_combat.snd_coin_tick   = load("res://assets/sounds/coin_tick.wav")
	_combat.coin_anim_finished.connect(_on_coin_anim_finished)
	_combat.build_combo_widget()

	# ── Layout: Restart Prompt ────────────────────────────────────────
	var restart_prompt := $Control/RestartPrompt as RichTextLabel
	if restart_prompt:
		restart_prompt.anchor_left   = 0.5;  restart_prompt.anchor_right  = 0.5
		restart_prompt.anchor_top    = 0.5;  restart_prompt.anchor_bottom = 0.5
		restart_prompt.offset_left   = -300; restart_prompt.offset_right  = 300
		restart_prompt.offset_top    = 155;  restart_prompt.offset_bottom = 220
		restart_prompt.size = Vector2(600, 65)
		restart_prompt.add_theme_color_override("default_color",      C_TEXT_PRI)
		restart_prompt.add_theme_font_size_override("normal_font_size", 28)

	# ── Layout: Final Score ───────────────────────────────────────────
	var fsl := $Control/FinalScoreLabel as Label
	if fsl:
		fsl.anchor_left   = 0.5;  fsl.anchor_right  = 0.5
		fsl.anchor_top    = 0.5;  fsl.anchor_bottom = 0.5
		fsl.offset_left   = -300; fsl.offset_right  = 300
		fsl.offset_top    = 55;   fsl.offset_bottom = 130
		fsl.size = Vector2(600, 75)
		fsl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fsl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		fsl.add_theme_font_size_override("font_size",        42)
		fsl.add_theme_constant_override("outline_size",      12)
		fsl.add_theme_color_override("font_color",           C_GOLD_BRIGHT)
		fsl.add_theme_color_override("font_outline_color",   C_OUTLINE)
		fsl.add_theme_color_override("font_shadow_color",    Color(0, 0, 0, 0.5))
		fsl.add_theme_constant_override("shadow_offset_x",   3)
		fsl.add_theme_constant_override("shadow_offset_y",   3)

	# ── Layout: Shop Panel ────────────────────────────────────────────
	_setup_shop_panel_layout()

	# ── Layout: Title Panel ───────────────────────────────────────────
	_setup_title_panel_layout()

	# ── Layout: HUD Labels ────────────────────────────────────────────
	_setup_hud_labels()
	_ensure_reload_ui()

	# ── Layout: Pause Glass Card ──────────────────────────────────────
	_build_pause_panel()

	# ── Initial offsets (everything hidden off-screen) ────────────────
	_hud_container_offset    = -130.0
	_hearts_container_offset =  130.0
	_hud_target_opacity      = 0.0
	_hearts_target_opacity   = 0.0
	_hud_hide_timer          = 0.0
	_hearts_hide_timer       = 0.0

	# Dynamic mobile touch control layer instantiation
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		_touch_layer = TouchControlLayer.new()
		_touch_layer.init(self)
		$Control.add_child(_touch_layer)

	# Style RoundCompletePanel as a pixel-art panel
	var rcp = $Control/RoundCompletePanel as ColorRect
	if rcp:
		rcp.color = Color.TRANSPARENT
		var rcp_bg := Panel.new()
		rcp_bg.name = "RoundCompletePixelBg"
		rcp_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		rcp_bg.add_theme_stylebox_override("panel", HudUiKit.make_pixel_panel(Color(0.02, 0.02, 0.04, 0.96), Color(0.0, 1.0, 0.3), 5))
		rcp.add_child(rcp_bg)
		rcp.move_child(rcp_bg, 0)
		HudUiKit.decorate_retro_panel(rcp_bg, Color(0.0, 1.0, 0.3))

	call_deferred("_find_player")


# ===================================================================
# _setup_shop_panel_layout
# ===================================================================
func _setup_shop_panel_layout() -> void:
	var sp: ColorRect = $Control/ShopPanel as ColorRect
	if not sp:
		return
		
	# Create overlay behind the ShopPanel
	var overlay := ColorRect.new()
	overlay.name = "ShopOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.45)
	overlay.anchor_left = 0.0; overlay.anchor_right = 1.0
	overlay.anchor_top = 0.0; overlay.anchor_bottom = 1.0
	overlay.hide()
	$Control.add_child(overlay)
	$Control.move_child(overlay, sp.get_index())
	
	overlay.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
			var main = get_tree().current_scene
			if main and main.has_method("close_shop"):
				main.close_shop()
			else:
				hide_shop()
	)

	# Responsive size and anchoring
	if OS.has_feature("mobile"):
		sp.set_anchors_preset(Control.PRESET_FULL_RECT)
		sp.offset_left   = 24
		sp.offset_right  = -24
		sp.offset_top    = 24
		sp.offset_bottom = -24
	else:
		sp.custom_minimum_size = Vector2(890, 565)
		sp.size = Vector2(890, 565)
		sp.set_anchors_preset(Control.PRESET_CENTER)
		sp.offset_left   = -445
		sp.offset_right  = 445
		sp.offset_top    = -282
		sp.offset_bottom = 282
		
	# Change sp color to transparent and add a pixel-art background Panel
	sp.color = Color.TRANSPARENT
	var bg_panel := Panel.new()
	bg_panel.name = "ShopPixelBg"
	bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_panel.add_theme_stylebox_override("panel", HudUiKit.make_pixel_panel(Color(0.02, 0.02, 0.04, 0.96), Color(1.0, 0.85, 0.0), 6))
	sp.add_child(bg_panel)
	sp.move_child(bg_panel, 0)
	HudUiKit.decorate_retro_panel(bg_panel, Color(1.0, 0.85, 0.0))

	var rim := ColorRect.new()
	rim.name = "ShopRim"
	rim.color = Color(0.38, 0.58, 1.0, 0.14)
	rim.anchor_left = 0.0; rim.anchor_right = 1.0
	rim.offset_left = 10; rim.offset_right = -10
	rim.offset_top = 2; rim.offset_bottom = 4
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.add_child(rim)

	var bot := ColorRect.new()
	bot.name = "ShopBot"
	bot.color = Color(0, 0, 0, 0.22)
	bot.anchor_left = 0.0; bot.anchor_right = 1.0
	bot.anchor_top = 1.0; bot.anchor_bottom = 1.0
	bot.offset_left = 0; bot.offset_right = 0
	bot.offset_top = -5; bot.offset_bottom = 0
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.add_child(bot)

	var st := sp.get_node_or_null("ShopTitle") as Label
	if st:
		st.hide()

	var sc := sp.get_node_or_null("ShopCoins") as Label
	if sc:
		sc.hide()

	var sprom := sp.get_node_or_null("ShopPrompt") as RichTextLabel
	if sprom:
		sprom.anchor_left   = 0.0; sprom.anchor_right  = 1.0
		sprom.anchor_top    = 1.0; sprom.anchor_bottom = 1.0
		sprom.offset_left   = 10; sprom.offset_right = -10
		sprom.offset_top    = -46
		sprom.add_theme_color_override("default_color",        C_TEXT_DIM)
		sprom.add_theme_font_size_override("normal_font_size", 13)


# ===================================================================
# _setup_title_panel_layout
# ===================================================================
func _setup_title_panel_layout() -> void:
	var tp: ColorRect = $Control/TitlePanel as ColorRect
	if not tp:
		return
	tp.anchor_left   = 0.0; tp.anchor_right  = 1.0
	tp.anchor_top    = 0.0; tp.anchor_bottom = 1.0
	tp.offset_left   = 0;   tp.offset_right  = 0
	tp.offset_top    = 0;   tp.offset_bottom = 0
	tp.size  = Vector2(1280, 720)
	tp.color = Color(0.04, 0.06, 0.12, 1.0)

	var grad := ColorRect.new()
	grad.color       = Color(0.10, 0.16, 0.30, 0.55)
	grad.size        = Vector2(1280, 380)
	grad.position    = Vector2(0, 0)
	grad.mouse_filter= Control.MOUSE_FILTER_IGNORE
	tp.add_child(grad)

	var bg := tp.get_node_or_null("Bg") as TextureRect
	if bg:
		bg.anchor_left   = 0.0; bg.anchor_right  = 1.0
		bg.anchor_top    = 0.0; bg.anchor_bottom = 1.0
		bg.offset_left   = 0;   bg.offset_right  = 0
		bg.offset_top    = 0;   bg.offset_bottom = 0
		bg.size    = Vector2(1280, 720)
		bg.modulate= Color(0.55, 0.60, 0.78, 0.22)

	var tl := tp.get_node_or_null("TitleLabel") as Label
	if tl:
		tl.anchor_left  = 0.5; tl.anchor_right = 0.5; tl.anchor_top = 0.0
		tl.offset_left  = -520; tl.offset_right = 520; tl.offset_top = 105
		tl.size = Vector2(1040, 135)
		tl.pivot_offset = Vector2(520, 67)
		tl.add_theme_font_size_override("font_size",       108)
		tl.add_theme_color_override("font_color",          C_GOLD_BRIGHT)
		tl.add_theme_color_override("font_outline_color",  Color(0.18, 0.10, 0.0, 1.0))
		tl.add_theme_constant_override("outline_size",     11)
		tl.add_theme_color_override("font_shadow_color",   Color(1.0, 0.60, 0.0, 0.38))
		tl.add_theme_constant_override("shadow_offset_x",  0)
		tl.add_theme_constant_override("shadow_offset_y",  7)

	var sl := tp.get_node_or_null("SubtitleLabel") as Label
	if sl:
		sl.anchor_left  = 0.5; sl.anchor_right = 0.5
		sl.offset_left  = -520; sl.offset_right = 520; sl.offset_top = 248
		sl.size = Vector2(1040, 55)
		sl.add_theme_font_size_override("font_size",       30)
		sl.add_theme_color_override("font_color",          C_TEXT_SEC)
		sl.add_theme_constant_override("outline_size",     4)
		sl.add_theme_color_override("font_outline_color",  C_OUTLINE)

	var tprom := tp.get_node_or_null("TitlePrompt") as RichTextLabel
	if tprom:
		tprom.anchor_left   = 0.5; tprom.anchor_right  = 0.5
		tprom.anchor_top    = 0.5; tprom.anchor_bottom = 0.5
		tprom.offset_left   = -520; tprom.offset_right = 520
		tprom.offset_top    = 42;   tprom.offset_bottom= 115
		tprom.size = Vector2(1040, 73)
		tprom.add_theme_font_size_override("normal_font_size", 36)
		tprom.add_theme_font_size_override("bold_font_size",   36)
		tprom.add_theme_color_override("default_color",        C_TEXT_PRI)

	var ctrl_lbl := tp.get_node_or_null("ControlsLabel") as RichTextLabel
	if ctrl_lbl:
		ctrl_lbl.anchor_left   = 0.5; ctrl_lbl.anchor_right  = 0.5
		ctrl_lbl.anchor_top    = 1.0; ctrl_lbl.anchor_bottom = 1.0
		ctrl_lbl.offset_left   = -520; ctrl_lbl.offset_right = 520
		ctrl_lbl.offset_top    = -215
		ctrl_lbl.size = Vector2(1040, 190)
		ctrl_lbl.add_theme_font_size_override("normal_font_size", 22)
		ctrl_lbl.add_theme_font_size_override("bold_font_size",   22)
		ctrl_lbl.add_theme_color_override("default_color",        C_TEXT_DIM)


# ===================================================================
# _setup_hud_labels
# ===================================================================
func _setup_hud_labels() -> void:
	var score_lbl := $Control/ScoreLabel as Label
	if score_lbl:
		score_lbl.add_theme_font_size_override("font_size",       40)
		score_lbl.add_theme_constant_override("outline_size",     10)
		score_lbl.add_theme_color_override("font_color",          C_GOLD_BRIGHT)
		score_lbl.add_theme_color_override("font_outline_color",  C_OUTLINE)
		score_lbl.add_theme_color_override("font_shadow_color",   Color(1.0, 0.72, 0.0, 0.28))
		score_lbl.add_theme_constant_override("shadow_offset_x",  0)
		score_lbl.add_theme_constant_override("shadow_offset_y",  5)

	var score_icon := $Control/ScoreIcon as TextureRect
	if score_icon:
		score_icon.size     = Vector2(42, 42)
		score_icon.modulate = Color.WHITE

	var passives_shelf := HBoxContainer.new()
	passives_shelf.name = "PassivesShelf"
	passives_shelf.position = Vector2(20, 72)
	passives_shelf.size = Vector2(400, 30)
	$Control.add_child(passives_shelf)

	var ecl := $Control/EnemyCountLabel as Label
	if ecl:
		ecl.anchor_left  = 0.5; ecl.anchor_right = 0.5
		ecl.offset_left  = -200; ecl.offset_right = 200; ecl.offset_top = 70
		ecl.size = Vector2(400, 28)
		ecl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ecl.add_theme_font_size_override("font_size",       18)
		ecl.add_theme_constant_override("outline_size",     5)
		ecl.add_theme_color_override("font_color",          C_TEXT_SEC)
		ecl.add_theme_color_override("font_outline_color",  C_OUTLINE)

	var cdl := $Control/CountdownLabel as Label
	if cdl:
		cdl.anchor_left   = 0.5; cdl.anchor_right  = 0.5
		cdl.anchor_top    = 0.5; cdl.anchor_bottom = 0.5
		cdl.offset_left   = -300; cdl.offset_right = 300
		cdl.offset_top    = -72;  cdl.offset_bottom= 72
		cdl.size = Vector2(600, 144)
		cdl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cdl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		cdl.pivot_offset = Vector2(300, 72)
		cdl.add_theme_font_size_override("font_size",       82)
		cdl.add_theme_constant_override("outline_size",     18)
		cdl.add_theme_color_override("font_outline_color",  C_OUTLINE)
		cdl.add_theme_color_override("font_shadow_color",   Color(0, 0, 0, 0.65))
		cdl.add_theme_constant_override("shadow_offset_x",  4)
		cdl.add_theme_constant_override("shadow_offset_y",  4)

	var rcl := $Control/RoundCompleteLabel as Label
	if rcl:
		rcl.anchor_left   = 0.5; rcl.anchor_right  = 0.5
		rcl.anchor_top    = 0.5; rcl.anchor_bottom = 0.5
		rcl.offset_left   = -460; rcl.offset_right = 460
		rcl.offset_top    = -135; rcl.offset_bottom= -52
		rcl.size = Vector2(920, 83)
		rcl.pivot_offset = Vector2(460, 41)
		rcl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rcl.add_theme_font_size_override("font_size",       54)
		rcl.add_theme_constant_override("outline_size",     14)
		rcl.add_theme_color_override("font_color",          C_SUCCESS)
		rcl.add_theme_color_override("font_outline_color",  Color(0.02, 0.14, 0.07, 1.0))
		rcl.add_theme_color_override("font_shadow_color",   Color(0, 0, 0, 0.55))
		rcl.add_theme_constant_override("shadow_offset_x",  3)
		rcl.add_theme_constant_override("shadow_offset_y",  3)

	var pl := $Control/PrizeLabel as Label
	if pl:
		pl.anchor_left   = 0.5; pl.anchor_right  = 0.5
		pl.anchor_top    = 0.5; pl.anchor_bottom = 0.5
		pl.offset_left   = -300; pl.offset_right = 300
		pl.offset_top    = -22;  pl.offset_bottom= 52
		pl.size = Vector2(600, 74)
		pl.pivot_offset = Vector2(300, 37)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pl.add_theme_font_size_override("font_size",        38)
		pl.add_theme_constant_override("outline_size",      10)
		pl.add_theme_color_override("font_color",           C_GOLD_BRIGHT)
		pl.add_theme_color_override("font_outline_color",   Color(0.15, 0.10, 0.0, 1.0))
		pl.add_theme_color_override("font_shadow_color",    Color(0, 0, 0, 0.45))
		pl.add_theme_constant_override("shadow_offset_x",   2)
		pl.add_theme_constant_override("shadow_offset_y",   2)

	var gol := $Control/GameOverLabel as Label
	if gol:
		gol.add_theme_font_size_override("font_size",        82)
		gol.add_theme_constant_override("outline_size",      12)
		gol.add_theme_color_override("font_color",           C_DANGER)
		gol.add_theme_color_override("font_outline_color",   Color(0.08, 0.0, 0.0, 1.0))
		gol.add_theme_color_override("font_shadow_color",    Color(1.0, 0.0, 0.0, 0.45))
		gol.add_theme_constant_override("shadow_offset_x",   0)
		gol.add_theme_constant_override("shadow_offset_y",   9)

	var gp := $Control/GameplayPrompt as RichTextLabel
	if gp:
		gp.anchor_left   = 0.0; gp.anchor_top    = 1.0
		gp.anchor_right  = 0.0; gp.anchor_bottom = 1.0
		gp.offset_left   = 20;  gp.offset_right  = 620
		gp.offset_top    = -310; gp.offset_bottom = -18
		gp.size = Vector2(600, 292)
		gp.add_theme_color_override("default_color",        C_TEXT_DIM)
		gp.add_theme_font_size_override("normal_font_size", 13)

	var ip := $Control/IntermissionPrompt as RichTextLabel
	if ip:
		ip.anchor_left   = 0.5; ip.anchor_right  = 0.5
		ip.anchor_top    = 1.0; ip.anchor_bottom = 1.0
		ip.offset_left   = -520; ip.offset_right = 520
		ip.offset_top    = -172
		ip.size = Vector2(1040, 100)
		ip.add_theme_color_override("default_color", C_TEXT_PRI)

	var rl := $Control/ReloadLabel as Label
	if rl:
		rl.add_theme_font_size_override("font_size",       22)
		rl.add_theme_color_override("font_color",          C_GOLD)
		rl.add_theme_constant_override("outline_size",     6)
		rl.add_theme_color_override("font_outline_color",  C_OUTLINE)
		rl.add_theme_color_override("font_shadow_color",   Color(0, 0, 0, 0.5))
		rl.add_theme_constant_override("shadow_offset_x",  2)
		rl.add_theme_constant_override("shadow_offset_y",  2)
		rl.anchor_left   = 0.5; rl.anchor_right  = 0.5
		rl.anchor_top    = 0.5; rl.anchor_bottom = 0.5
		rl.offset_left   = -65; rl.offset_right  = 65
		rl.offset_top    = -105; rl.offset_bottom= -70
		rl.size = Vector2(130, 35)
		rl.pivot_offset = Vector2(65, 17)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER

func _ensure_reload_ui() -> void:
	var control = $Control
	if control.has_node("ReloadPanel"):
		return

	var panel := ColorRect.new()
	panel.name = "ReloadPanel"
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -180; panel.offset_right = 180
	panel.offset_top = -110; panel.offset_bottom = -78
	panel.color = Color(0, 0, 0, 0.55)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	control.add_child(panel)

	var good_zone := ColorRect.new()
	good_zone.name = "ReloadGoodZone"
	good_zone.color = Color(1.0, 1.0, 1.0, 0.16)
	good_zone.position = Vector2(4, 4)
	good_zone.size = Vector2(232, 20)
	panel.add_child(good_zone)

	var perfect_zone := ColorRect.new()
	perfect_zone.name = "ReloadPerfectZone"
	perfect_zone.color = Color(1.0, 0.85, 0.2, 0.28)
	perfect_zone.position = Vector2(4, 4)
	perfect_zone.size = Vector2(46, 20)
	panel.add_child(perfect_zone)

	var fill := ColorRect.new()
	fill.name = "ReloadFill"
	fill.color = Color(0.95, 0.75, 0.2, 0.92)
	fill.position = Vector2(4, 4)
	fill.size = Vector2(0, 20)
	panel.add_child(fill)

	var marker := ColorRect.new()
	marker.name = "ReloadMarker"
	marker.color = Color(1, 1, 1, 0.9)
	marker.position = Vector2(4, 2)
	marker.size = Vector2(4, 24)
	panel.add_child(marker)

	var text := Label.new()
	text.name = "ReloadText"
	text.anchor_left = 0.5; text.anchor_right = 0.5
	text.anchor_top = 0.0; text.anchor_bottom = 1.0
	text.offset_left = -40; text.offset_right = 40
	text.offset_top = 2; text.offset_bottom = -2
	text.text = ""
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_color_override("font_color", C_GOLD_BRIGHT)
	text.add_theme_color_override("font_outline_color", C_OUTLINE)
	text.add_theme_constant_override("outline_size", 3)
	text.add_theme_font_size_override("font_size", 18)
	panel.add_child(text)

	_update_reload_zones()

func _update_reload_zones() -> void:
	var panel := $Control.get_node_or_null("ReloadPanel") as ColorRect
	if not panel:
		return
	var width = panel.size.x - 8
	var perfect_min := 0.45
	var perfect_max := 0.58
	var good_min := 0.32
	var good_max := 0.70
	panel.get_node("ReloadGoodZone").size.x = width * (good_max - good_min)
	panel.get_node("ReloadGoodZone").position.x = 4 + width * good_min
	panel.get_node("ReloadPerfectZone").size.x = width * (perfect_max - perfect_min)
	panel.get_node("ReloadPerfectZone").position.x = 4 + width * perfect_min

func _set_reload_panel_visible(visible: bool) -> void:
	var panel := $Control.get_node_or_null("ReloadPanel") as ColorRect
	if panel:
		panel.visible = visible

func _update_reload_progress(time_left: float, duration: float) -> void:
	var panel := $Control.get_node_or_null("ReloadPanel") as ColorRect
	if not panel:
		return
	var fill := panel.get_node("ReloadFill") as ColorRect
	var marker := panel.get_node("ReloadMarker") as ColorRect
	var label := panel.get_node("ReloadText") as Label
	var width = panel.size.x - 8
	var progress = 1.0 - clampf(time_left / duration, 0.0, 1.0)
	fill.size.x = width * progress
	marker.position.x = clamp(4 + width * progress - marker.size.x * 0.5, 4, 4 + width - marker.size.x)
	label.text = str(snapped(time_left, 0.01)) + "s"


# ===================================================================
# _build_pause_panel — glassmorphism pause overlay
# ===================================================================
func _build_pause_panel() -> void:
	_pause_panel = ColorRect.new()
	_pause_panel.name         = "PausePanel"
	_pause_panel.color        = Color(0.0, 0.02, 0.06, 0.62)
	_pause_panel.anchor_left  = 0.0; _pause_panel.anchor_right  = 1.0
	_pause_panel.anchor_top   = 0.0; _pause_panel.anchor_bottom = 1.0
	_pause_panel.hide()
	$Control.add_child(_pause_panel)

	# Tap outside pause card to resume
	_pause_panel.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
			var main = get_tree().current_scene
			if main:
				main.paused = false
				main.call("_freeze_player", false)
			get_tree().paused = false
	)

	var card := Panel.new()
	card.name         = "PauseCard"
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(380, 380)
	card.size         = Vector2(380, 380)
	card.pivot_offset = Vector2(190, 190)
	var style := HudUiKit.make_pixel_panel(
			Color(0.02, 0.02, 0.04, 0.96),
			Color(0.0, 1.0, 1.0), 6)
	card.add_theme_stylebox_override("panel", style)
	_pause_panel.add_child(card)
	HudUiKit.decorate_retro_panel(card, Color(0.0, 1.0, 1.0))

	var card_vbox := VBoxContainer.new()
	card_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 14)
	card_vbox.offset_left = 30
	card_vbox.offset_right = -30
	card_vbox.offset_top = 15
	card_vbox.offset_bottom = -15
	card.add_child(card_vbox)

	_pause_label = Label.new()
	_pause_label.text = "PAUSED"
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_pause_label.add_theme_font_size_override("font_size",       40)
	_pause_label.add_theme_color_override("font_color",          C_GOLD_BRIGHT)
	_pause_label.add_theme_color_override("font_outline_color",  C_OUTLINE)
	_pause_label.add_theme_constant_override("outline_size",     10)
	_pause_label.add_theme_color_override("font_shadow_color",   Color(1.0, 0.82, 0.0, 0.28))
	_pause_label.add_theme_constant_override("shadow_offset_x",  0)
	_pause_label.add_theme_constant_override("shadow_offset_y",  4)
	_pause_label.custom_minimum_size = Vector2(320, 50)
	card_vbox.add_child(_pause_label)

	# Reusable button style box creators
	var make_btn_style := func(border_color: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.08, 0.11, 0.20, 0.88)
		s.border_width_left = 3; s.border_width_right = 3
		s.border_width_top = 3; s.border_width_bottom = 3
		s.border_color = border_color
		s.corner_radius_top_left = 0; s.corner_radius_top_right = 0
		s.corner_radius_bottom_left = 0; s.corner_radius_bottom_right = 0
		return s

	var make_btn_hover := func(border_color: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.12, 0.16, 0.30, 0.92)
		s.border_width_left = 3; s.border_width_right = 3
		s.border_width_top = 3; s.border_width_bottom = 3
		s.border_color = C_GOLD_BRIGHT
		s.corner_radius_top_left = 0; s.corner_radius_top_right = 0
		s.corner_radius_bottom_left = 0; s.corner_radius_bottom_right = 0
		return s

	var setup_btn := func(btn: Button, btn_text: String, border: Color) -> void:
		btn.text = btn_text
		btn.custom_minimum_size = Vector2(300, 55) # Touch target: 55px height
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", C_TEXT_PRI)
		btn.add_theme_color_override("font_hover_color", C_GOLD_BRIGHT)
		btn.add_theme_stylebox_override("normal", make_btn_style.call(border))
		btn.add_theme_stylebox_override("hover", make_btn_hover.call(border))
		btn.add_theme_stylebox_override("pressed", make_btn_hover.call(border))
		btn.add_theme_stylebox_override("focus", make_btn_style.call(border))

	# 1. Resume Button
	var btn_resume := Button.new()
	setup_btn.call(btn_resume, "RESUME", Color(0.22, 1.00, 0.55, 0.62))
	btn_resume.pressed.connect(func():
		var main = get_tree().current_scene
		if main:
			main.paused = false
			main.call("_freeze_player", false)
		get_tree().paused = false
	)
	card_vbox.add_child(btn_resume)

	# 2. Restart Button
	var btn_restart := Button.new()
	setup_btn.call(btn_restart, "RESTART", Color(1.00, 0.85, 0.20, 0.62))
	btn_restart.pressed.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene()
	)
	card_vbox.add_child(btn_restart)

	# 3. Quit Button
	var btn_quit := Button.new()
	setup_btn.call(btn_quit, "QUIT GAME", Color(1.00, 0.20, 0.20, 0.62))
	btn_quit.pressed.connect(func():
		get_tree().quit()
	)
	card_vbox.add_child(btn_quit)

	var hint := Label.new()
	hint.name = "PauseHint"
	hint.text = "Press ESC to resume"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size",       13)
	hint.add_theme_color_override("font_color",          C_TEXT_DIM)
	hint.add_theme_constant_override("outline_size",     3)
	hint.add_theme_color_override("font_outline_color",  C_OUTLINE)
	hint.custom_minimum_size = Vector2(320, 20)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox.add_child(hint)
	if OS.has_feature("mobile"):
		hint.hide()


# ===================================================================
# _find_player
# ===================================================================
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
	_hotbar.build(inv, idx)
	var main = get_tree().current_scene
	var hide_desc := false
	if main:
		var sv = main.get("state"); var mo = main.get("menu_open")
		hide_desc = (sv == 0 or sv == 4 or mo)
	_hotbar.update_weapon_description(inv, idx, not hide_desc)
	_hotbar.refresh_cooldown_bars(cooldowns)


func _on_reload_started(duration: float) -> void:
	_reload_ui_total_duration = duration
	# HUD reload panel disabled — diegetic bar on player character is used instead

func _on_reload_ticking(time_left: float) -> void:
	# HUD reload panel disabled — diegetic bar on player character is used instead
	pass

func _on_reload_finished() -> void:
	_reload_ui_total_duration = 0.0
	# HUD reload panel disabled — diegetic bar on player character is used instead

func _on_coin_anim_finished() -> void:
	_animating_coins = false


# ===================================================================
# PUBLIC API — Score / Health
# ===================================================================
func update_score(val: int) -> void:
	if not _animating_coins:
		_displayed_score = val
		var label := $Control/ScoreLabel
		label.text = str(val)
		var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		tween.tween_property(label, "scale", Vector2(1.35, 0.75), 0.07)
		tween.tween_property(label, "scale", Vector2(0.92, 1.08), 0.1)
		tween.tween_property(label, "scale", Vector2(1.0,  1.0),  0.14)
	
	var shop_coins := $Control/ShopPanel/ShopCoins as Label
	if shop_coins:
		shop_coins.text = "COINS: " + str(val)
		
	_hud_hide_timer  = 2.0
	_score_glow_time = 0.55


func flash_heal() -> void:
	var flash := $Control/HealFlash as ColorRect
	flash.color = Color(0, 1, 0.2, 0.35)
	var tween := create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "color", Color(0, 1, 0.2, 0), 0.42)
	_hearts_hide_timer = 2.0


func update_health(val: int, max_val: int = 3) -> void:
	var hearts_node := $Control/Hearts
	while hearts_node.get_child_count() < max_val:
		var hr := TextureRect.new()
		hr.texture     = preload("res://assets/ui/heart.png")
		hr.custom_minimum_size = Vector2(52, 52)
		hr.size        = Vector2(52, 52)
		hr.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		hr.stretch_mode= TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hr.mouse_filter= Control.MOUSE_FILTER_IGNORE
		hr.pivot_offset= Vector2(26, 26)
		hr.set_meta("active", true)
		hearts_node.add_child(hr)
	while hearts_node.get_child_count() > max_val:
		hearts_node.get_child(hearts_node.get_child_count() - 1).queue_free()
	for i in range(hearts_node.get_child_count()):
		var heart := hearts_node.get_child(i) as TextureRect
		heart.pivot_offset = Vector2(26, 26)
		var was_active: bool = heart.get_meta("active", true)
		var is_active:  bool = i < val
		heart.set_meta("active", is_active)
		heart.modulate = Color.WHITE if is_active else Color(0.28, 0.28, 0.28, 0.35)
		if was_active != is_active:
			var tween := heart.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
			heart.scale    = Vector2(1.75, 1.75) if is_active else Vector2(0.28, 0.28)
			heart.rotation = randf_range(-0.42, 0.42)
			tween.tween_property(heart, "scale",    Vector2.ONE, 0.50)
			tween.parallel().tween_property(heart, "rotation", 0.0, 0.50)
	_hearts_hide_timer = 2.0


# ===================================================================
# PUBLIC API — Shop
# ===================================================================
func show_shop() -> void:
	_hotbar.set_desc_visible(false)
	# Ensure OS cursor is visible when interacting with shop UI
	if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	var sprom := $Control/ShopPanel/ShopPrompt as RichTextLabel
	if sprom:
		if OS.has_feature("mobile"):
			sprom.text = "[center]Tap outside the panel to close[/center]"
		else:
			sprom.text = ("[center]  " + _close_icon() + " Close  |  Press TAB or click Close to return to Intermission[/center]")
	
	var shop_coins := $Control/ShopPanel/ShopCoins as Label
	if shop_coins:
		shop_coins.hide()
		
	var overlay = $Control.get_node_or_null("ShopOverlay") as ColorRect
	if overlay:
		overlay.show()
		overlay.color.a = 0.0
		var ot := create_tween()
		ot.tween_property(overlay, "color:a", 0.45, 0.28)
		
	$Control/ShopPanel.show()
	_shop.build_cards()
	var panel := $Control/ShopPanel as ColorRect
	if panel:
		panel.modulate.a  = 0.0
		panel.pivot_offset= panel.size / 2.0
		panel.scale = Vector2(0.88, 0.88)
		var t := create_tween().set_parallel(true) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.tween_property(panel, "modulate:a", 1.0,       0.28)
		t.tween_property(panel, "scale",      Vector2.ONE, 0.38)


func hide_shop() -> void:
	_hotbar.set_desc_visible(true)
	_shop.clear_cards()
	var panel := $Control/ShopPanel as ColorRect
	
	var overlay = $Control.get_node_or_null("ShopOverlay") as ColorRect
	if overlay:
		var ot := create_tween()
		ot.tween_property(overlay, "color:a", 0.0, 0.18)
		ot.tween_callback(overlay.hide)
		
	if panel and panel.visible:
		panel.pivot_offset = panel.size / 2.0
		var t := create_tween().set_parallel(true).set_ease(Tween.EASE_IN)
		t.tween_property(panel, "modulate:a", 0.0,           0.18)
		t.tween_property(panel, "scale",      Vector2(0.92, 0.92), 0.18)
		t.chain().tween_callback(func():
			panel.hide(); panel.modulate.a = 1.0; panel.scale = Vector2.ONE)
	elif panel:
		panel.hide()


func handle_shop_confirm() -> bool:
	return false


func navigate_shop(_event: InputEvent) -> void:
	pass




# ===================================================================
# PUBLIC API — Title Screen
# ===================================================================
func show_title() -> void:
	_hotbar.set_desc_visible(false)
	$Control/TitlePanel/SubtitleLabel.text = _random_subtitle()
	if OS.has_feature("mobile"):
		$Control/TitlePanel/TitlePrompt.text = "[center]Tap Screen to Start[/center]"
	else:
		$Control/TitlePanel/TitlePrompt.text = "[center]" + _confirm_icon() + "  Press to Start[/center]"
	var ctrl := $Control/TitlePanel/ControlsLabel as RichTextLabel
	if ctrl:
		if OS.has_feature("mobile"):
			ctrl.hide()
		else:
			ctrl.text = ("[center]" + _move_icon() + "  Move    " + _shoot_icon() + "  Shoot    "
				+ _switch_prev_icon() + _switch_next_icon() + "  Switch[/center]")
	$Control/TitlePanel.show()
	var title_panel := $Control/TitlePanel as ColorRect
	if title_panel:
		title_panel.modulate.a = 0.0
		var ft := create_tween()
		ft.tween_property(title_panel, "modulate:a", 1.0, 0.55)
	var prompt := $Control/TitlePanel/TitlePrompt as RichTextLabel
	if prompt:
		prompt.modulate = Color(1, 1, 1, 1)
		var tween := create_tween().set_loops().set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(prompt, "modulate:a", 0.32, 0.68)
		tween.tween_property(prompt, "modulate:a", 1.0,  0.68)
	_start_title_particles()


func hide_title() -> void:
	_hotbar.set_desc_visible(true)
	if _title_particles and is_instance_valid(_title_particles):
		_title_particles.emitting = false
		_title_particles = null
	var panel := $Control/TitlePanel as ColorRect
	if panel:
		var t := create_tween().set_ease(Tween.EASE_IN)
		t.tween_property(panel, "modulate:a", 0.0, 0.2)
		t.tween_callback(func(): panel.hide(); panel.modulate.a = 1.0)


func _start_title_particles() -> void:
	if _title_particles and is_instance_valid(_title_particles):
		return
	var tp := $Control/TitlePanel as ColorRect
	if not tp:
		return
	_title_particles = CPUParticles2D.new()
	_title_particles.emitting          = true
	_title_particles.amount            = 65
	_title_particles.lifetime          = 5.0
	_title_particles.one_shot          = false
	_title_particles.explosiveness     = 0.0
	_title_particles.spread            = 180.0
	_title_particles.gravity           = Vector2(0, -16)
	_title_particles.initial_velocity_min = 6.0
	_title_particles.initial_velocity_max = 26.0
	_title_particles.scale_amount_min  = 1.5
	_title_particles.scale_amount_max  = 7.0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.92, 0.55, 0.0))
	g.add_point(0.15, Color(1.0, 0.92, 0.55, 0.60))
	g.add_point(0.50, Color(0.45, 0.72, 1.00, 0.42))
	g.set_color(1,    Color(0.45, 0.72, 1.00, 0.0))
	_title_particles.color_ramp           = g
	_title_particles.emission_shape       = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_title_particles.emission_rect_extents= Vector2(640, 360)
	_title_particles.position             = Vector2(640, 360)
	_title_particles.z_index              = 0
	tp.add_child(_title_particles)


# ===================================================================
# PUBLIC API — Intermission / Rounds
# ===================================================================
func show_intermission(round_idx: int) -> void:
	$Control/RoundLabel.text = ""
	$Control/EnemyCountLabel.text = ""
	$Control/RoundCompletePanel.hide()
	$Control/RoundCompleteLabel.hide()
	$Control/PrizeLabel.hide()
	$Control/IntermissionPrompt.text = ("[center][font_size=32]"
		+ _confirm_icon() + "  Start Round " + str(round_idx)
		+ "    " + _shop_icon() + "  Mastery[/font_size][/center]")
	$Control/IntermissionPrompt.show()
	hide_gameplay_prompt()


func show_countdown(round_idx: int) -> void:
	hide_shop()
	$Control/RoundCompletePanel.hide()
	$Control/RoundCompleteLabel.hide()
	$Control/PrizeLabel.hide()
	$Control/IntermissionPrompt.hide()
	var main := get_tree().current_scene
	if not main or not main.has_method("_on_countdown_done"):
		return
	_combat.run_countdown(
		$Control/CountdownOverlay as ColorRect,
		$Control/CountdownLabel as Label,
		$Control/HealFlash as ColorRect,
		round_idx,
		Callable(main, "_on_countdown_done"),
		_play_sfx)


func show_round_active(round_idx: int, count: int) -> void:
	$Control/RoundCompletePanel.hide()
	$Control/RoundCompleteLabel.hide()
	$Control/PrizeLabel.hide()
	$Control/IntermissionPrompt.hide()
	$Control/RoundLabel.text = "Round " + str(round_idx)
	update_enemies_remaining(count)
	show_gameplay_prompt()


func update_enemies_remaining(count: int) -> void:
	$Control/EnemyCountLabel.text = "☠ " + str(count) + " left"


func show_round_complete(round_idx: int, prize: int) -> void:
	$Control/RoundLabel.text      = ""
	$Control/EnemyCountLabel.text = ""

	var rcl := $Control/RoundCompleteLabel as Label
	rcl.text = "Round " + str(round_idx) + " Complete!"
	rcl.show(); rcl.scale = Vector2(2.4, 2.4); rcl.modulate.a = 0.0
	var rl_t := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	rl_t.tween_property(rcl, "scale",      Vector2.ONE, 0.58)
	rl_t.tween_property(rcl, "modulate:a", 1.0,         0.30)

	var pl := $Control/PrizeLabel as Label
	pl.text = "⬡  +" + str(prize)
	pl.show(); pl.scale = Vector2(0.5, 0.5); pl.modulate.a = 0.0
	var pl_t := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	pl_t.tween_property(pl, "scale",      Vector2.ONE, 0.38).set_delay(0.20)
	pl_t.tween_property(pl, "modulate:a", 1.0,         0.30).set_delay(0.20)

	$Control/RoundCompletePanel.show()
	hide_gameplay_prompt()
	_play_sfx(_round_win_sound, 0.0)
	_combat.spawn_round_complete_confetti()

	var main := get_tree().current_scene
	var target_score: int = main.get("score") if main and "score" in main else 0
	var prev_score:   int = target_score - prize
	$Control/ScoreLabel.text = str(prev_score)
	_displayed_score  = prev_score
	_animating_coins  = true
	_hud_hide_timer   = 3.5
	_hearts_hide_timer= 3.5

	_combat.play_coin_fly(
		$Control/ScoreIcon as TextureRect,
		prize, prev_score, target_score,
		$Control/ScoreLabel as Label,
		_pulse_score_label,
		_play_coin_chink)


func _play_coin_chink(index: int) -> void:
	var asp := AudioStreamPlayer.new()
	asp.bus = "Standard"
	asp.stream      = load("res://assets/sounds/coin_tick.wav")
	asp.pitch_scale = 1.0 + float(index) * 0.07
	asp.volume_db   = -7.0
	add_child(asp)
	asp.play()
	asp.finished.connect(asp.queue_free)


func _pulse_score_label(amount: float) -> void:
	var main := get_tree().current_scene
	if not main: return
	var target_score: int = main.get("score") if "score" in main else 0
	var score_lbl := $Control/ScoreLabel as Label
	if score_lbl:
		var current_val: int = int(score_lbl.text)
		var next_val: int    = int(min(current_val + int(amount), target_score))
		score_lbl.text = str(next_val)
		score_lbl.pivot_offset = score_lbl.size / 2.0
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(score_lbl, "scale", Vector2(1.35, 1.35), 0.07)
		tween.tween_property(score_lbl, "scale", Vector2(1.0,  1.0),  0.14)


# ===================================================================
# PUBLIC API — Game Over
# ===================================================================
func show_game_over() -> void:
	_hotbar.set_desc_visible(false)
	can_restart = false
	hide_shop()
	hide_gameplay_prompt()
	for node_path in [
		"$Control/RoundLabel", "$Control/EnemyCountLabel",
		"$Control/CountdownOverlay", "$Control/CountdownLabel",
		"$Control/RoundCompletePanel", "$Control/RoundCompleteLabel",
		"$Control/PrizeLabel", "$Control/IntermissionPrompt",
	]:
		var n := get_node_or_null(node_path.trim_prefix("$"))
		if n: n.hide()
	$Control/RoundLabel.text      = ""
	$Control/EnemyCountLabel.text = ""
	$Control/CountdownOverlay.hide()
	$Control/CountdownLabel.hide()
	$Control/RoundCompletePanel.hide()
	$Control/RoundCompleteLabel.hide()
	$Control/PrizeLabel.hide()
	$Control/IntermissionPrompt.hide()

	var go_bg := $Control/GameOverBg as ColorRect
	go_bg.color = Color(0.55, 0.0, 0.0, 0.0)
	go_bg.show()
	var bg_t := create_tween()
	bg_t.tween_property(go_bg, "color", Color(0.50, 0.0, 0.0, 0.80), 0.22)
	bg_t.tween_property(go_bg, "color", Color(0.04, 0.0, 0.0, 0.74), 0.88)

	var label := $Control/GameOverLabel as Label
	label.show()
	label.modulate = Color(1, 0.12, 0.12, 0)
	label.scale    = Vector2(0.28, 0.28)
	label.pivot_offset = label.size / 2.0
	var tween := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", Color(1, 0.12, 0.12, 1), 0.68)
	tween.parallel().tween_property(label, "scale", Vector2(1.05, 1.05), 0.68)
	tween.tween_property(label, "scale", Vector2.ONE, 0.22)
	await tween.finished

	var main := get_tree().current_scene
	if main and main.has_method("add_score"):
		var fs_lbl := $Control/FinalScoreLabel as Label
		fs_lbl.text = "Score: 0"
		fs_lbl.show()
		var target_s: int = main.score
		for si in range(23):
			fs_lbl.text = "Score: " + str(int(float(target_s) * float(si) / 22.0))
			if si < 22:
				_play_coin_chink(si % 9)
				await get_tree().create_timer(0.038).timeout
		fs_lbl.text = "Score: " + str(target_s)

	await get_tree().create_timer(0.80).timeout
	show_restart_prompt()


func show_restart_prompt() -> void:
	var prompt := $Control/RestartPrompt as RichTextLabel
	prompt.text = "[center][font_size=32]" + _confirm_icon() + "  Press to restart[/font_size][/center]"
	prompt.show()
	prompt.modulate = Color(1, 1, 1, 0)
	prompt.scale    = Vector2(0.78, 0.78)
	var tween := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(prompt, "modulate", Color.WHITE, 0.42)
	tween.tween_property(prompt, "scale",    Vector2.ONE, 0.42)
	await tween.finished
	can_restart = true
	var pt := create_tween().set_loops()
	pt.tween_property(prompt, "modulate:a", 0.45, 0.62)
	pt.tween_property(prompt, "modulate:a", 1.0,  0.62)


func handle_game_over_input(event: InputEvent) -> void:
	if can_restart and event.is_action_pressed("confirm"):
		get_tree().reload_current_scene()


# ===================================================================
# PUBLIC API — Gameplay Prompt
# ===================================================================
func show_gameplay_prompt() -> void:
	if OS.has_feature("mobile"):
		$Control/GameplayPrompt.hide()
		return
	var p := $Control/GameplayPrompt as RichTextLabel
	p.text = ("[font_size=26]" + _move_icon()        + "  Move\n"
		+ _shoot_icon()      + "  Shoot\n"
		+ _switch_prev_icon() + _switch_next_icon() + "  Switch[/font_size]")
	p.show()

func hide_gameplay_prompt() -> void:
	$Control/GameplayPrompt.hide()

func show_lock_on_msg() -> void:
	pass  # hook for future use


# ===================================================================
# PUBLIC API — Combo (delegates to _combat)
# ===================================================================
func show_combo(count: int) -> void:
	var player := get_tree().get_first_node_in_group("player")
	_combat.show_combo(count, player)

func hide_combo() -> void:
	_combat.hide_combo()

func update_combo_timer(progress: float) -> void:
	_combat.update_combo_timer(progress)

func play_kaching() -> void:
	_combat.play_kaching()


# ===================================================================
# Icon helpers
# ===================================================================
func _is_gamepad() -> bool:
	return Input.get_connected_joypads().size() > 0

func _icon(icon_name: String) -> String:
	return _icon_tag(icon_name) + "res://assets/ui/" + icon_name + "[/img]"

func _confirm_icon()     -> String: return _icon("xbox_a.png"             if _is_gamepad() else "key_space.png")
func _close_icon()       -> String: return _icon("xbox_b.png"             if _is_gamepad() else "key_esc.png")
func _move_icon()        -> String: return _icon("xbox_ls.png"            if _is_gamepad() else "key_wasd.png")
func _shoot_icon()       -> String: return _icon("xbox_rt.png"            if _is_gamepad() else "mouse_lmb.png")
func _interact_icon()    -> String: return _icon("xbox_a.png"             if _is_gamepad() else "key_space.png")
func _shop_icon()        -> String: return _icon("xbox_select.png"        if _is_gamepad() else "key_tab.png")
func _shop_locked_icon() -> String: return _icon("xbox_select_locked.png" if _is_gamepad() else "key_tab_locked.png")
func _leftright_icon()   -> String: return _icon("xbox_dpad.png"          if _is_gamepad() else "key_wasd.png")
func _switch_prev_icon() -> String: return _icon("xbox_lb.png"            if _is_gamepad() else "key_q.png")
func _switch_next_icon() -> String: return _icon("xbox_rb.png"            if _is_gamepad() else "key_e.png")

func _icon_tag(icon_name: String) -> String:
	match icon_name:
		"xbox_a.png":            return "[img=36x36]"
		"xbox_b.png":            return "[img=36x36]"
		"key_space.png":         return "[img=64x28]"
		"key_esc.png":           return "[img=36x28]"
		"key_tab.png":           return "[img=44x28]"
		"key_tab_locked.png":    return "[img=44x28]"
		"xbox_rt.png":           return "[img=40x24]"
		"mouse_lmb.png":         return "[img=36x28]"
		"xbox_ls.png":           return "[img=36x36]"
		"xbox_dpad.png":         return "[img=36x36]"
		"xbox_select.png":       return "[img=36x36]"
		"xbox_select_locked.png":return "[img=36x36]"
		"key_wasd.png":          return "[img=56x56]"
		"key_q.png":             return "[img=36x28]"
		"key_e.png":             return "[img=36x28]"
		"xbox_y.png":            return "[img=36x36]"
		"xbox_lb.png":           return "[img=44x20]"
		"xbox_rb.png":           return "[img=44x20]"
	return "[img=36x36]"


# ===================================================================
# Subtitles
# ===================================================================
const SUBTITLES: Array[String] = [
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
	return SUBTITLES[randi() % SUBTITLES.size()]


# ===================================================================
# _play_sfx
# ===================================================================
func _play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not stream:
		return
	var sp := AudioStreamPlayer.new()
	sp.bus = "Priority" if (stream == _round_start_sound or stream == _round_win_sound) else "Standard"
	sp.stream      = stream
	sp.volume_db   = volume_db
	sp.pitch_scale = pitch
	add_child(sp)
	sp.play()
	sp.finished.connect(sp.queue_free)


# ===================================================================
# _process — animation ticks
# ===================================================================
func _process(delta: float) -> void:
	_time += delta
	
	var score_icon := $Control/ScoreIcon as TextureRect
	if score_icon and HudUiKit.coin_frames.size() > 0:
		var idx := int(_time * 30.0) % HudUiKit.coin_frames.size()
		score_icon.texture = HudUiKit.coin_frames[idx]

	# ── 1. Title animations ──────────────────────────────────────────
	var tp := $Control/TitlePanel as ColorRect
	if tp and tp.visible:
		var tl := tp.get_node("TitleLabel") as Label
		if tl:
			tl.scale       = Vector2(1.0 + sin(_time * 3.75) * 0.078, 1.0 - sin(_time * 3.75) * 0.078)
			tl.pivot_offset= tl.size / 2
			tl.rotation    = sin(_time * 2.75) * 0.038
			var b: float   = 1.0 + sin(_time * 2.15) * 0.09
			tl.modulate    = Color(b, b * 0.94, b * 0.68, 1.0)
		var sub := tp.get_node("SubtitleLabel") as Label
		if sub:
			sub.position.y = 248.0 + sin(_time * 5.4) * 5.5
			sub.rotation   = cos(_time * 3.8) * 0.024
		var bg_rect := tp.get_node("Bg") as TextureRect
		if bg_rect:
			bg_rect.scale        = Vector2(1.0 + sin(_time * 0.58) * 0.022, 1.0 + cos(_time * 0.80) * 0.022)
			bg_rect.pivot_offset = bg_rect.size / 2

	# ── 2. Pause panel ───────────────────────────────────────────────
	var is_paused: bool = get_tree().paused
	if _pause_panel:
		if is_paused and not _pause_panel.visible:
			_pause_panel.show()
			var pause_card := _pause_panel.get_node_or_null("PauseCard") as Panel
			if pause_card:
				pause_card.scale = Vector2.ZERO
				var pt: Tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				pt.tween_property(pause_card, "scale", Vector2.ONE, 0.52)
		elif not is_paused and _pause_panel.visible:
			_pause_panel.hide()
		if _pause_panel.visible and _pause_label:
			_pause_label.rotation   = sin(_time * 4.4) * 0.068
			var p_sc: float = 1.0 + sin(_time * 6.8) * 0.048
			_pause_label.scale      = Vector2(p_sc, p_sc)
			_pause_label.pivot_offset = _pause_label.size / 2

	# ── 3. Autohide timers ───────────────────────────────────────────
	var main_scene = get_tree().current_scene
	var is_menu: bool = false
	if main_scene:
		var sv = main_scene.get("state")
		is_menu = (sv == 0 or sv == 1)

	if _animating_coins:
		_hud_hide_timer    = 2.0
		_hearts_hide_timer = 2.0

	if not is_menu:
		if _hud_hide_timer    > 0.0: _hud_hide_timer    -= delta
		if _hearts_hide_timer > 0.0: _hearts_hide_timer -= delta
	else:
		_hud_hide_timer    = 2.0
		_hearts_hide_timer = 2.0

	# ── 4. Slide offsets ─────────────────────────────────────────────
	if _hud_hide_timer > 0.0:
		_hud_container_offset = lerpf(_hud_container_offset, 0.0,    delta * 9.5)
		_hud_target_opacity   = lerpf(_hud_target_opacity,   1.0,    delta * 9.5)
	else:
		_hud_container_offset = lerpf(_hud_container_offset, -130.0, delta * 5.5)
		_hud_target_opacity   = lerpf(_hud_target_opacity,   0.0,    delta * 5.5)

	if _hearts_hide_timer > 0.0:
		_hearts_container_offset = lerpf(_hearts_container_offset, 0.0,   delta * 9.5)
		_hearts_target_opacity   = lerpf(_hearts_target_opacity,   1.0,   delta * 9.5)
	else:
		_hearts_container_offset = lerpf(_hearts_container_offset, 130.0, delta * 5.5)
		_hearts_target_opacity   = lerpf(_hearts_target_opacity,   0.0,   delta * 5.5)

	# ── 5. Score / coin positions ────────────────────────────────────
	var score_icon_node := $Control/ScoreIcon as TextureRect
	var score_lbl       := $Control/ScoreLabel as Label
	if score_icon_node and score_lbl:
		var bob: float = sin(_time * 3.15) * 3.8
		score_icon_node.position.x = 20.0 + _hud_container_offset
		score_icon_node.position.y = 15.0 + bob
		score_icon_node.size       = Vector2(42, 42)
		score_icon_node.modulate   = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, _hud_target_opacity)
		score_lbl.position.x = 70.0 + _hud_container_offset
		score_lbl.position.y = 12.0 + bob
		score_lbl.rotation   = cos(_time * 2.15) * 0.016
		score_lbl.modulate.a = _hud_target_opacity
		if _score_glow_time > 0.0:
			_score_glow_time -= delta

	# ── 6. Round / enemy labels ──────────────────────────────────────
	var round_lbl := $Control/RoundLabel as Label
	var enemy_lbl := $Control/EnemyCountLabel as Label
	if round_lbl and enemy_lbl:
		round_lbl.scale        = Vector2(1.0 + sin(_time * 2.75) * 0.048, 1.0 - sin(_time * 2.75) * 0.048)
		round_lbl.pivot_offset = round_lbl.size / 2
		enemy_lbl.position.y   = 70.0 + cos(_time * 4.15) * 2.2

	# ── 7. Hearts heartbeat ──────────────────────────────────────────
	var hearts := $Control/Hearts as HBoxContainer
	if hearts:
		var vw: float = get_viewport().get_visible_rect().size.x
		hearts.position.x = (vw - hearts.size.x - 20.0) + _hearts_container_offset
		hearts.position.y = 18.0
		hearts.modulate.a = _hearts_target_opacity
		for i in range(hearts.get_child_count()):
			var h := hearts.get_child(i) as TextureRect
			if h:
				var h_time: float = _time * 1.75 + float(i) * 0.42
				var pulse:  float = 0.0
				if fmod(h_time, 2.0) < 0.68:
					pulse = sin(fmod(h_time, 2.0) / 0.68 * PI) * 0.22
				h.scale        = Vector2(1.0 + pulse, 1.0 + pulse)
				h.pivot_offset = h.size / 2
				h.rotation     = sin(_time * 3.4 + float(i)) * 0.033

	# ── 8. Hotbar + weapon desc ───────────────────────────────────────
	var player := get_tree().get_first_node_in_group("player")
	
	# Update Passives Shelf
	var passives_shelf := $Control.get_node_or_null("PassivesShelf") as HBoxContainer
	if passives_shelf and player and is_instance_valid(player):
		for child in passives_shelf.get_children():
			child.queue_free()
			
		var add_passive_badge := func(label_text: String, bg_color: Color) -> void:
			var badge := Panel.new()
			badge.custom_minimum_size = Vector2(80, 22)
			badge.size = Vector2(80, 22)
			var bs := StyleBoxFlat.new()
			bs.bg_color = Color(bg_color.r, bg_color.g, bg_color.b, 0.22)
			bs.border_width_left = 1; bs.border_width_right = 1
			bs.border_width_top = 1; bs.border_width_bottom = 1
			bs.border_color = bg_color
			bs.corner_radius_top_left = 4; bs.corner_radius_top_right = 4
			bs.corner_radius_bottom_left = 4; bs.corner_radius_bottom_right = 4
			badge.add_theme_stylebox_override("panel", bs)
			
			var lbl := Label.new()
			lbl.text = label_text
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 9)
			lbl.add_theme_color_override("font_color", Color.WHITE)
			lbl.size = Vector2(80, 22)
			badge.add_child(lbl)
			passives_shelf.add_child(badge)
			
		if player.get("passive_shield_max") > 0:
			add_passive_badge.call("SHIELD x" + str(player.get("passive_shield")), C_CYAN)
		if player.get("passive_speed_loader") < 1.0:
			add_passive_badge.call("RELOAD+", C_GOLD)
		if player.get("passive_golden_touch") == true:
			add_passive_badge.call("MIDAS+", C_GOLD_BRIGHT)
		if player.get("passive_magnet_ring") > 1.0:
			add_passive_badge.call("MAGNET+", C_LAVENDER)
		if player.get("passive_toughness") > 0:
			add_passive_badge.call("ARMOR+", C_SUCCESS)
		if player.get("passive_damage_boost") > 1.0:
			add_passive_badge.call("DAMAGE+", C_DANGER)

	_hotbar.tick(_time, player)
	_hotbar.tick_description(delta, _time, true)

	# ── 9. Shop float ─────────────────────────────────────────────────
	var shop_panel := $Control/ShopPanel as ColorRect
	if shop_panel and shop_panel.visible:
		var shop_title := shop_panel.get_node("ShopTitle") as Label
		if shop_title:
			shop_title.rotation    = sin(_time * 2.15) * 0.038
			var st_sc: float = 1.0 + sin(_time * 2.95) * 0.032
			shop_title.scale       = Vector2(st_sc, st_sc)
			shop_title.pivot_offset= shop_title.size / 2
			var sb: float = 1.0 + sin(_time * 2.4) * 0.075
			shop_title.modulate    = Color(sb, sb * 0.96, sb * 0.72, 1.0)
		_shop.tick(delta, _time)

	# ── 10. Reload label shake ────────────────────────────────────────
	var reload_lbl := $Control/ReloadLabel as Label
	if reload_lbl and reload_lbl.visible:
		reload_lbl.rotation     = sin(_time * 14.0) * 0.072
		var r_sc: float = 1.0 + sin(_time * 16.0) * 0.12
		reload_lbl.scale        = Vector2(r_sc, r_sc)
		reload_lbl.pivot_offset = reload_lbl.size / 2
		var r_t: float = (sin(_time * 7.5) + 1.0) / 2.0
		reload_lbl.add_theme_color_override("font_color",
			Color(1.0, lerpf(0.38, 0.95, r_t), 0.08, 1.0))


func _pre_render_coin_textures() -> void:
	if HudUiKit.coin_frames.size() > 0:
		return
	var size_px := 64
	var frames_count := 30
	var vp := SubViewport.new()
	vp.size = Vector2i(size_px * frames_count, size_px)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	
	var drawer := Control.new()
	drawer.custom_minimum_size = Vector2(size_px * frames_count, size_px)
	drawer.size = Vector2(size_px * frames_count, size_px)
	drawer.draw.connect(func():
		for i in range(frames_count):
			var angle := float(i) * PI / float(frames_count)
			var center := Vector2(i * size_px + size_px / 2.0, size_px / 2.0)
			HudUiKit.draw_coin_on_canvas(drawer, center, 24.0, cos(angle))
	)
	vp.add_child(drawer)
	
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	var img := vp.get_texture().get_image()
	for i in range(frames_count):
		var rect := Rect2i(i * size_px, 0, size_px, size_px)
		var frame_img := img.get_region(rect)
		var tex := ImageTexture.create_from_image(frame_img)
		HudUiKit.coin_frames.append(tex)
	vp.queue_free()


func get_virtual_aim_vector() -> Vector2:
	if _touch_layer and is_instance_valid(_touch_layer) and _touch_layer.right_joystick.active:
		return _touch_layer.right_joystick.joystick_vector
	return Vector2.ZERO


func show_unlock_notification(weapon_name: String) -> void:
	# Epic celebration sound
	_play_sfx(_round_win_sound, 1.0, 1.1)
	
	# Create a gorgeous notification panel
	var notif := Panel.new()
	notif.size = Vector2(420, 120)
	var screen_size = $Control.size
	notif.position = Vector2((screen_size.x - 420) / 2.0, 80)
	notif.pivot_offset = Vector2(210, 60)
	notif.scale = Vector2.ZERO
	
	# Pixel-art stylebox
	var notif_style = HudUiKit.make_pixel_panel(Color(0.02, 0.02, 0.04, 0.96), Color(0.0, 1.0, 1.0), 5)
	notif.add_theme_stylebox_override("panel", notif_style)
	$Control.add_child(notif)
	HudUiKit.decorate_retro_panel(notif, Color(0.0, 1.0, 1.0))
	
	# Icon
	var icon := TextureRect.new()
	icon.texture = _weapon_textures.get(weapon_name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(64, 64)
	icon.position = Vector2(20, 28)
	notif.add_child(icon)
	
	# Title
	var title := Label.new()
	title.text = "WEAPON UNLOCKED!"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 6)
	title.position = Vector2(100, 20)
	title.size = Vector2(300, 30)
	notif.add_child(title)
	
	# Subtitle/Weapon Name
	var desc := Label.new()
	var weapon_display_name = weapon_name.capitalize()
	if weapon_name == "smg":
		weapon_display_name = "SMG"
	desc.text = weapon_display_name + " added to your inventory."
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	desc.position = Vector2(100, 52)
	desc.size = Vector2(300, 25)
	notif.add_child(desc)
	
	# micro-desc
	var slot_lbl := Label.new()
	slot_lbl.text = "Scroll mouse or press Q/E to equip"
	slot_lbl.add_theme_font_size_override("font_size", 10)
	slot_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	slot_lbl.position = Vector2(100, 75)
	slot_lbl.size = Vector2(300, 20)
	notif.add_child(slot_lbl)
	
	# Animate the entrance
	var tween := notif.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(notif, "scale", Vector2.ONE, 0.4)
	
	# Subtle bounce wobble
	var wobble := notif.create_tween().set_loops(2)
	wobble.tween_property(notif, "rotation", 0.03, 0.25).set_trans(Tween.TRANS_SINE)
	wobble.tween_property(notif, "rotation", -0.03, 0.25).set_trans(Tween.TRANS_SINE)
	wobble.chain().tween_property(notif, "rotation", 0.0, 0.15)
	
	# Auto fade out and queue_free
	var fade_tween := notif.create_tween().set_ease(Tween.EASE_IN)
	fade_tween.tween_interval(3.2)
	fade_tween.tween_property(notif, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK)
	fade_tween.finished.connect(notif.queue_free)


func show_milestone_completed_notification(item_name: String) -> void:
	# Alert sound (nice high pitched drum win / tick)
	_play_sfx(_round_win_sound, 0.0, 1.25)
	
	# Create a gorgeous notification panel
	var notif := Panel.new()
	notif.size = Vector2(460, 90)
	var screen_size = $Control.size
	notif.position = Vector2((screen_size.x - 460) / 2.0, 80)
	notif.pivot_offset = Vector2(230, 45)
	notif.scale = Vector2.ZERO
	
	# Pixel-art stylebox with a gold-tinted border
	var notif_style = HudUiKit.make_pixel_panel(Color(0.02, 0.02, 0.04, 0.96), Color(1.0, 0.85, 0.0), 5)
	notif.add_theme_stylebox_override("panel", notif_style)
	$Control.add_child(notif)
	HudUiKit.decorate_retro_panel(notif, Color(1.0, 0.85, 0.0))
	
	# Title
	var title := Label.new()
	title.text = "🎯 MILESTONE COMPLETED!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 5)
	title.position = Vector2(0, 15)
	title.size = Vector2(460, 25)
	notif.add_child(title)
	
	# Subtitle/Description
	var desc := Label.new()
	desc.text = "%s is now ready to buy in the Mastery Dashboard!" % item_name.to_upper()
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	desc.add_theme_color_override("font_outline_color", Color.BLACK)
	desc.add_theme_constant_override("outline_size", 4)
	desc.position = Vector2(0, 45)
	desc.size = Vector2(460, 20)
	notif.add_child(desc)
	
	# Tip text
	var tip := Label.new()
	tip.text = "Press TAB or SELECT to open the Dashboard"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 9)
	tip.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	tip.position = Vector2(0, 65)
	tip.size = Vector2(460, 15)
	notif.add_child(tip)
	
	# Animate the entrance
	var tween := notif.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(notif, "scale", Vector2.ONE, 0.35)
	
	# Auto fade out and queue_free
	var fade_tween := notif.create_tween().set_ease(Tween.EASE_IN)
	fade_tween.tween_interval(3.5)
	fade_tween.tween_property(notif, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK)
	fade_tween.finished.connect(notif.queue_free)


# ===================================================================
# TOUCH CONTROLS INNER CLASSES
# ===================================================================
class TouchJoystick extends Control:
	var base_radius := 60.0
	var handle_radius := 25.0
	var joystick_vector := Vector2.ZERO
	var active := false
	var touch_index := -1
	var base_pos := Vector2.ZERO
	var handle_pos := Vector2.ZERO
	
	func _ready() -> void:
		custom_minimum_size = Vector2(120, 120)
		size = Vector2(120, 120)
		hide()
		
	func start_joystick(pos: Vector2, idx: int) -> void:
		base_pos = pos
		handle_pos = pos
		touch_index = idx
		active = true
		position = pos - size / 2.0
		show()
		queue_redraw()
		
	func update_joystick(pos: Vector2) -> void:
		var offset := pos - base_pos
		var dist := offset.length()
		if dist > base_radius:
			offset = offset.normalized() * base_radius
		handle_pos = base_pos + offset
		joystick_vector = offset / base_radius
		queue_redraw()
		
	func stop_joystick() -> void:
		active = false
		touch_index = -1
		joystick_vector = Vector2.ZERO
		hide()
		
	func _draw() -> void:
		if not active:
			return
		var center := size / 2.0
		var handle_offset := handle_pos - base_pos
		draw_circle(center, base_radius, Color(1, 1, 1, 0.04))
		draw_arc(center, base_radius, 0, TAU, 32, Color(1, 1, 1, 0.14), 2.0, true)
		draw_circle(center + handle_offset, handle_radius, Color(1, 1, 1, 0.22))
		draw_arc(center + handle_offset, handle_radius, 0, TAU, 16, Color(1, 1, 1, 0.45), 1.5, true)


class TouchControlLayer extends Control:
	var left_joystick: TouchJoystick
	var right_joystick: TouchJoystick
	var weapon_prev_btn: Button
	var weapon_next_btn: Button
	var pause_btn: Button
	var hud_ref: CanvasLayer

	func init(hud: CanvasLayer) -> void:
		hud_ref = hud
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_PASS
		
		left_joystick = TouchJoystick.new()
		add_child(left_joystick)
		
		right_joystick = TouchJoystick.new()
		add_child(right_joystick)
		
		# Pause Button
		pause_btn = Button.new()
		pause_btn.text = "⏸"
		pause_btn.custom_minimum_size = Vector2(60, 60)
		pause_btn.size = Vector2(60, 60)
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.06, 0.09, 0.18, 0.75)
		btn_style.border_width_left = 1; btn_style.border_width_right = 1
		btn_style.border_width_top = 1; btn_style.border_width_bottom = 1
		btn_style.border_color = Color(0.40, 0.55, 1.0,  0.5)
		btn_style.corner_radius_top_left = 30
		btn_style.corner_radius_top_right = 30
		btn_style.corner_radius_bottom_left = 30
		btn_style.corner_radius_bottom_right = 30
		
		pause_btn.add_theme_stylebox_override("normal", btn_style)
		pause_btn.add_theme_stylebox_override("hover", btn_style)
		pause_btn.add_theme_stylebox_override("pressed", btn_style)
		pause_btn.add_theme_font_size_override("font_size", 24)
		pause_btn.pressed.connect(func():
			var ev := InputEventAction.new()
			ev.action = "pause"
			ev.pressed = true
			Input.parse_input_event(ev)
		)
		add_child(pause_btn)
		
		# Weapon Switch buttons
		var wp_style := StyleBoxFlat.new()
		wp_style.bg_color = Color(0.06, 0.09, 0.18, 0.75)
		wp_style.border_width_left = 1; wp_style.border_width_right = 1
		wp_style.border_width_top = 1; wp_style.border_width_bottom = 1
		wp_style.border_color = Color(1.0, 0.85, 0.20, 0.5)
		wp_style.corner_radius_top_left = 32
		wp_style.corner_radius_top_right = 32
		wp_style.corner_radius_bottom_left = 32
		wp_style.corner_radius_bottom_right = 32
		
		weapon_prev_btn = Button.new()
		weapon_prev_btn.text = "◀"
		weapon_prev_btn.custom_minimum_size = Vector2(65, 65)
		weapon_prev_btn.size = Vector2(65, 65)
		weapon_prev_btn.add_theme_stylebox_override("normal", wp_style)
		weapon_prev_btn.add_theme_stylebox_override("hover", wp_style)
		weapon_prev_btn.add_theme_stylebox_override("pressed", wp_style)
		weapon_prev_btn.add_theme_font_size_override("font_size", 24)
		weapon_prev_btn.pressed.connect(func():
			var ev := InputEventAction.new()
			ev.action = "switch_weapon_prev"
			ev.pressed = true
			Input.parse_input_event(ev)
		)
		add_child(weapon_prev_btn)
		
		weapon_next_btn = Button.new()
		weapon_next_btn.text = "▶"
		weapon_next_btn.custom_minimum_size = Vector2(65, 65)
		weapon_next_btn.size = Vector2(65, 65)
		weapon_next_btn.add_theme_stylebox_override("normal", wp_style)
		weapon_next_btn.add_theme_stylebox_override("hover", wp_style)
		weapon_next_btn.add_theme_stylebox_override("pressed", wp_style)
		weapon_next_btn.add_theme_font_size_override("font_size", 24)
		weapon_next_btn.pressed.connect(func():
			var ev := InputEventAction.new()
			ev.action = "switch_weapon_next"
			ev.pressed = true
			Input.parse_input_event(ev)
		)
		add_child(weapon_next_btn)
		
		_update_button_positions()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_update_button_positions()
			
	func _update_button_positions() -> void:
		var sz = size
		if sz.x == 0 or sz.y == 0:
			sz = get_viewport_rect().size
		if pause_btn:
			pause_btn.position = Vector2(sz.x - 80, 20)
		if weapon_prev_btn:
			weapon_prev_btn.position = Vector2(sz.x - 160, sz.y - 120)
		if weapon_next_btn:
			weapon_next_btn.position = Vector2(sz.x - 80, sz.y - 120)

	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree():
			return
			
		var main = get_tree().current_scene
		if main and main.get("menu_open"):
			if left_joystick.active: left_joystick.stop_joystick()
			if right_joystick.active: right_joystick.stop_joystick()
			_update_movement_actions(Vector2.ZERO)
			_update_shooting_action(false)
			pause_btn.hide()
			weapon_prev_btn.hide()
			weapon_next_btn.hide()
			return
		else:
			pause_btn.show()
			weapon_prev_btn.show()
			weapon_next_btn.show()

		if event is InputEventScreenTouch:
			var touch_event := event as InputEventScreenTouch
			if touch_event.pressed:
				var screen_width := get_viewport_rect().size.x
				var is_left := touch_event.position.x < (screen_width / 2.0)
				
				if pause_btn.get_global_rect().has_point(touch_event.position) or \
				   weapon_prev_btn.get_global_rect().has_point(touch_event.position) or \
				   weapon_next_btn.get_global_rect().has_point(touch_event.position):
					return
					
				# If on title screen or intermission, any tap starts the game / round
				if main:
					var st = main.get("state")
					if st == 0: # State.TITLE
						var ev := InputEventAction.new()
						ev.action = "confirm"
						ev.pressed = true
						Input.parse_input_event(ev)
						return
					elif st == 1: # State.INTERMISSION
						var ev := InputEventAction.new()
						ev.action = "confirm"
						ev.pressed = true
						Input.parse_input_event(ev)
						return
					
				if is_left and not left_joystick.active:
					left_joystick.start_joystick(touch_event.position, touch_event.index)
				elif not is_left and not right_joystick.active:
					right_joystick.start_joystick(touch_event.position, touch_event.index)
			else:
				if left_joystick.active and left_joystick.touch_index == touch_event.index:
					left_joystick.stop_joystick()
					_update_movement_actions(Vector2.ZERO)
				elif right_joystick.active and right_joystick.touch_index == touch_event.index:
					right_joystick.stop_joystick()
					_update_shooting_action(false)
					
		elif event is InputEventScreenDrag:
			var drag_event := event as InputEventScreenDrag
			if left_joystick.active and left_joystick.touch_index == drag_event.index:
				left_joystick.update_joystick(drag_event.position)
				_update_movement_actions(left_joystick.joystick_vector)
			elif right_joystick.active and right_joystick.touch_index == drag_event.index:
				right_joystick.update_joystick(drag_event.position)
				_update_shooting_action(right_joystick.joystick_vector.length() > 0.15)
				
	func _update_movement_actions(vector: Vector2) -> void:
		_set_action_strength("move_left", clampf(-vector.x, 0.0, 1.0))
		_set_action_strength("move_right", clampf(vector.x, 0.0, 1.0))
		_set_action_strength("move_up", clampf(-vector.y, 0.0, 1.0))
		_set_action_strength("move_down", clampf(vector.y, 0.0, 1.0))
		
	func _set_action_strength(action: String, strength: float) -> void:
		if strength > 0.15:
			if not Input.is_action_pressed(action):
				var ev := InputEventAction.new()
				ev.action = action
				ev.pressed = true
				Input.parse_input_event(ev)
			Input.action_press(action, strength)
		else:
			if Input.is_action_pressed(action):
				var ev := InputEventAction.new()
				ev.action = action
				ev.pressed = false
				Input.parse_input_event(ev)
			Input.action_release(action)

	func _update_shooting_action(shoot: bool) -> void:
		if shoot:
			if not Input.is_action_pressed("shoot"):
				var ev := InputEventAction.new()
				ev.action = "shoot"
				ev.pressed = true
				Input.parse_input_event(ev)
		else:
			if Input.is_action_pressed("shoot"):
				var ev := InputEventAction.new()
				ev.action = "shoot"
				ev.pressed = false
				Input.parse_input_event(ev)
