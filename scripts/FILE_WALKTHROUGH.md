# File-by-File Code Walkthrough — Pewtopia

All 25 `.gd` files broken down line-by-line (or section-by-section) explaining what each piece of code does.

---

## `main.gd` (375 lines) — Game State Machine / Orchestrator

### Constants & State (lines 1-28)
- `ENEMY_SCENE`, `PLAYER_SCENE`: preloads for instancing
- `State` enum: `TITLE → INTERMISSION → COUNTDOWN → ACTIVE → GAME_OVER`
- `score`, `round_count`, `state`, `enemies_to_kill`, `menu_open`, `combo_count`, `combo_timer`, `COMBO_LIFETIME`
- `paused`, `round_start_time`
- References: `world_gen`, `audio_manager`, `wave_spawner`, `enemy_indicators`
- `@onready bgm`, `intermission_bgm`, `spawn_timer`

### `_ready()` (lines 30-62)
- Creates `WorldGenerator` → generates world
- Creates `AudioManager` → initializes with BGM nodes
- Creates `WaveSpawner` → initializes
- Creates `EnemyIndicators` → initializes
- Spawns player at screen center
- Shows title screen via `$HUD.show_title()`
- Freezes player, sets BGM volume, starts lobby music

### `_unhandled_input(event)` (lines 64-102)
- **Menu open**: handles shop confirm/navigation/cancel
- **Pause** (Esc/Start): toggles pause only when not in menu/title/game-over
- **Title**: confirm starts intermission
- **Intermission**: Tab opens shop, confirm starts round
- **Game Over**: delegates to `HUD.handle_game_over_input()`

### `trigger_hit_stop()` (lines 105-131)
- Sets `Engine.time_scale` to 0.05 for given duration
- Applies chromatic aberration + distortion on player
- After delay, restores time scale to 1.0
- Plays a high-pitched kinetic release sound (pitched explosion.wav)
- Optionally spawns release shockwave at position

### `_spawn_release_shockwave(pos)` (lines 133-184)
- Creates a `Node2D` with inline GDScript that draws an expanding arc (ring)
- Also spawns `CPUParticles2D` with radiating spark particles

### Delegates (lines 186-206)
- `get_radial_light_texture()`: from world_gen
- `play_layered_shoot()` / `play_layered_hit()` / `play_layered_explosion()`: from audio_manager

### `spawn_player()` (lines 208-212)
- Instantiates player at viewport center, connects `died` signal

### Navigation (lines 215-226)
- `start_intermission()`: hides title, unfreezes player, increments round, sets INTERMISSION state, plays lobby BGM, shows intermission prompt
- `start_round()`: transitions from INTERMISSION → COUNTDOWN, starts countdown HUD

### `_on_countdown_done()` (lines 237-248)
- Transitions COUNTDOWN → ACTIVE
- Calculates `enemies_to_kill` (12 + (round-1)*6)
- Shows round active HUD, plays combat BGM, triggers wave spawn

### `increment_combo_on_hit()` (lines 250-259)
- Increments combo counter, resets timer, shows combo widget, tracks peak_combo

### `_on_enemy_killed()` (lines 262-277)
- Records kill on player (tracks per-weapon stats)
- Decrements `enemies_to_kill`, updates HUD
- If combo ≥ 5, adds bonus score (combo×2)
- If 0 enemies left → `complete_round()`

### `complete_round()` (lines 280-288)
- Transitions → INTERMISSION
- Awards prize (100 + round*50)
- Shows round complete HUD
- After 1.5s delay, auto-starts next intermission

### Utility (lines 296-346)
- `heal_player()`: heals player, flashes HUD green
- `add_score()`: increments score, updates HUD
- `open_shop()` / `close_shop()`: toggle menu + HUD
- `get_menu_open()`: inspect, `is_game_started()`: state check
- `_freeze_player()`: toggles frozen on player
- `_is_nav_event()`: checks move actions
- `_is_joy_button()`: checks joypad button

### Signal handlers (lines 349-366)
- `_on_bgm_finished()`: plays next combat track
- `_on_intermission_bgm_finished()`: plays next lobby track
- `_on_player_died()`: sets GAME_OVER, stops all audio, shows game over, plays death sound

### `_process(delta)` (lines 368-375)
- If ACTIVE and combo > 0: counts down combo timer, hides combo when expired, updates combo progress bar

---

## `player.gd` (1790 lines) — Player Character

### Constants & Variables (lines 1-91)
- `SPEED = 150`, `JOYSTICK_DEADZONE = 0.15`, `ANIM_SPEED = 0.12`
- `MAGNET_SPEED = 400`, `MAGNET_RANGE = 120`
- References `WEAPON_DATA` from WeaponDB
- Health: 3 hearts, invincibility toggle
- Input mode tracking: `_last_input`
- Weapon state: `weapon`, `fire_cooldown`, `inventory`, `current_weapon_index`
- Visual arrays: `muzzle_flash_time`, `shake_intensity`, `shake_decay`
- Reload system: `is_reloading`, `reload_*`, `active_reload_*`, `is_jammed`, `spread_accum`
- Animation: `anim_bounce_time`, `walk_bounce_phase`, `recoil_tilt/squash`, `damage_wobble_time`, `visual_gun_kickback`
- Gamepad crosshair spring physics: `visual_crosshair_pos`, `crosshair_velocity`
- Walk step timer, lock-on target
- Post-processing: `post_proc_aberration`, `post_proc_distortion`
- Visual FX nodes: `shadow_sprite`, `player_light`, `flashlight`, `walk_dust`, `muzzle_smoke`, `jam_vent_smoke`

### Passive Upgrades (lines 82-91)
- `passive_shield` (max 3, recharge timer), `passive_speed_loader` (0.70 = +30%), `passive_golden_touch` (bool), `passive_magnet_ring` (2.2 = +120%), `passive_toughness` (35% block), `passive_damage_boost` (1.35 = +35%)

### Milestone/Stats properties (lines 93-131)
- Delegates to `ProgressionManager` static vars: `weapon_unlocks`, `passive_unlocks`, `total_bullets_fired`, `total_coins_collected`, `total_items_collected`, `total_kills`, `peak_combo`, `run_survival_time`, `announced_milestones`, `weapon_kills`

### Texture/sound preloads (lines 134-153)
- Per-weapon textures (pistol, smg, shotgun, minigun, sniper, missile) and sounds
- `SMG_TEXTURE`, `_shotgun_texture`, etc. with fallback to pistol

### Signals (lines 149-153)
- `died`, `weapon_changed(inventory, index, cooldowns)`, `reload_started(duration)`, `reload_ticking(time_left)`, `reload_finished`

### `_ready()` (lines 156-329)
- Loads weapon textures with fallback
- Applies pistol, broadcasts weapon
- Creates `player_canvas_renderer.gd` as child
- **Shadow Sprite**: created from main's `_create_shadow_texture()`
- **Lighting**: PointLight2D warm aura (player) + directional flashlight (gun_pivot)
- **Walk Dust**: CPUParticles2D emitting behind player when moving
- **Muzzle Smoke**: CPUParticles2D one-shot burst at muzzle
- **Walk Step Sound**: AudioStreamPlayer with walk_step.wav
- **Lock On Sound**: AudioStreamPlayer with lock_on.wav
- **Weather Embers**: CPUParticles2D ambient ember particles across full screen
- **Gun LED**: Node2D with custom `_draw_gun_led` on gun_sprite
- **Jam Vent Smoke**: CPUParticles2D one-shot for failed reload

### `_input(event)` (lines 332-370)
- Tracks last input type (mouse/gamepad)
- Weapon switching (Q/E or shoulder buttons)
- **Cheat code**: `WWSSWWDD` unlocks all weapons
- **R key**: manual reload or active reload (if already reloading) or clear jam
- **1-9 keys**: select weapon slot

### `_process(delta)` (lines 373-557)
- Ticks `run_survival_time` and milestone announcements
- **Crosshair spring physics**: Hooke's law spring on `visual_crosshair_pos` toward target
- Decays LED flash, out-of-ammo popup cooldown
- **Camera shake**: moves camera.offset randomly, decays intensity
- **Shield recharge**: after 15s, restores shield to max with lock_on pitched-up sound
- **Active reload buff**: golden modulate pulse, decays after 6s
- **Post-processing**: applies aberration/distortion/vignette to ScreenShader material
  - Low health (1 HP): pulsing vignette heartbeat
- **Gun pivot rotation**: reload animation sequence with spring physics
  - Empty reload: extends magazine drop → insert → bolt rack
  - Tactical reload: shorter animation
- Per-slot cooldown decay, fire cooldown decay
- **Visual clip count**: smoothly animates toward actual clip count
- **Reload input blocking**: if reloading, pressing shoot shows "JAMMED!" or "RELOADING..." popup
- **Reload ticking**: decrements timer, triggers perfect zone flash, emits `reload_ticking`, triggers visual/audio sequence
- **Shooting logic**: pistol = press, fast weapons (fire_rate < 0.3) = hold, others = press
- **Spread decay**: timer-based
- Queue redraw for canvas renderer

### `_physics_process(delta)` (lines 560-583)
- Tracks time without damage
- Decays recoil velocity
- Reads input, applies velocity (SPEED + recoil)
- If active reload buff active: spawns LED trail particles every 2 frames
- **Collision damage**: if sliding into enemy, calls `take_damage()`

### `pull_coins(delta)` (lines 585-594)
- Magnet effect: pulls coins toward player within `MAGNET_RANGE * passive_magnet_ring`

### `get_aim_direction()` (lines 597-677)
- Checks virtual aim from touch controls first
- Falls back to right stick → gamepad last direction → mouse
- **Aim Assist**: lock-on within 55°, 350px range
  - Maintains lock if angle < 55° and distance < 450
  - Scans enemies with angle < 35° (new) or 12° (existing lock)
  - Proximity prioritization score = dist * (1 + angle*2)
  - Lerps aim toward locked enemy (45%)
  - Plays lock-on sound on new target

### `update_animation(delta)` (lines 694-790)
- **Sprite direction**: 4-directional based on velocity/aim
- Walk dust emitting when moving
- **Walk animation**: 2-frame cycle, walk step sound every 0.3s
- **Don't Starve bouncy animation**: walk bounce phase, rocking rotation (9°), squash-stretch on steps
- **Idle**: gentle breathing cycle (rotation 1.5°, scale 3.5%)
- Firing recoil tilt & squash decay
- **Damage wobble**: springy oscillation on hit
- **Shadow sprite**: scales dynamically based on vertical height

### `_shoot_weapon(data)` (lines 792-922)
- Checks ammo: if empty → auto-reload or "OUT OF AMMO" popup
- Decrements clip, checks low/empty ammo thresholds
- Calculates spread (minigun accumulates up to 0.08)
- **Bullet spawning**: instantiates per-data bullets with spread, penetrate, explosive, damage (including passive_damage_boost + active_reload 1.35x bonus)
- **Shell casing**: calls `_spawn_shell_casing()`
- **Layered shoot sound**: delegates to main.play_layered_shoot()
- **Camera shake**: per-weapon intensity
- **Post-processing burst**: per-weapon aberration/distortion values
- **Fire cooldown**: applied with active reload fire rate buff (0.75x)
- **Visual kickback**: per-weapon kick amounts, tweened recovery
- **Recoil tilt + squash**: per-weapon values
- **Recoil velocity**: for weapons with recoil > 0 (knocks player backward)
- Muzzle flash trigger

### `_manual_reload()` (lines 925-952)
- Checks full magazine / no ammo → blocked sound + popup
- Starts reload with `passive_speed_loader` multiplier

### `_start_reload(duration)` (lines 954-974)
- Sets reload state, tracks events, resets active reload state
- Emits `reload_started`

### `_finish_reload()` (lines 977-1004)
- Transfers ammo from reserve to clip (or infinite for pistol)
- Emits `reload_finished`, broadcasts weapon

### `_cancel_reload()` (lines 1007-1018)
- Stops reload sound, plays shrink/grow tween on gun sprite

### `_tick_reload_sequence(progress, delta)` (lines 1020-1051)
- **0.05**: voice "RELOADING!"
- **0.15**: mag_out sound + physical magazine drop + visual_clip_count → 0 + camera micro-shake + LED flash
- **0.45/0.50**: mag_in sound + camera shake + LED flash + hit-stop
- **0.75** (empty only): bolt_rack sound + camera shake + LED flash

### `_attempt_active_reload()` (lines 1054-1071)
- Checks progress against perfect zone [0.45, 0.58], good zone [0.32, 0.70], else failed

### `_trigger_perfect_reload()` (lines 1074-1095)
- perfect_ping sound + perfect_clack sound + "PERFECT!" popup
- Grants 6s active reload buff (1.35x damage, 0.75x fire rate)
- Golden modulate flash, sparkle particles, UI reload burst particles
- Hit-stop then 50ms rhythm-game freeze before finishing

### `_trigger_good_reload()` (lines 1098-1102)
- good_click sound + "GOOD" popup, immediate finish

### `_trigger_failed_reload()` (lines 1105-1119)
- failed_jam sound + "JAMMED" popup + red flash
- Sets `is_jammed = true`, spawns jam vent smoke

### `_clear_jam()` (lines 1122-1135)
- bolt_rack sound + "CLEARED" popup
- Violent kickback tween + camera shake + recoil tilt

### Particle helpers (lines 1137-1175)
- `_spawn_sparkle_particles()`: 12 golden rects tween outward
- `_spawn_smoke_particles()`: 8 dark grey rects float upward

### `_play_procedural_sound(type)` (lines 1178-1179)
- Delegates to `ProceduralAudioHelper.play_procedural_sound()`

### `_spawn_physical_magazine()` (lines 1182-1212)
- Creates ColorRect magazine, ejects with velocity + rotation + floor bounce tween

### `_spawn_text_popup(txt, color)` (lines 1215-1240)
- Creates Label, animates scale up + float up + fade out

### `_draw()` / `_draw_gun_led()` (lines 1248-1294)
- Mouse mode management (hide during gameplay, show in menu)
- **Gun LED**: Colors vary by state:
  - Active reload buff → blinding white
  - Reloading → yellow pulse + flash intensity
  - Empty clip → red blink
  - Firing → bright cyan, ready → dim cyan
  - Draws bezel + LED + glow circle

### `_spawn_led_trail_particle()` (lines 1297-1312)
- White circle particle with glow, tweens to zero scale

### `_trigger_all_weapons_cheat()` (lines 1315-1348)
- Unlocks all weapons from WEAPON_DATA, refills ammo, plays victory chime, shows gold floating text

### `get_muzzle_local/global_position()` (lines 1351-1371)
- Per-weapon muzzle offset from gun pivot, adjusted for scaling and aim direction

### Inventory management (lines 1374-1496)
- `_menu_open()`: checks frozen + main menu state
- `set_frozen(val)`: toggles frozen
- `add_weapon(type)`: adds to inventory if not duplicate
- `refill_ammo(percent)`: refills reserve + clip, plays sound + popup
- `switch_weapon(dir)`: wraps index, cancels reload, applies weapon
- `select_slot(slot)`: direct slot selection
- `_play_switch_sound()`: weapon_switch.wav
- `_key_to_slot()`: 1-9, 0 → indices
- `_apply_weapon(type)`: sets texture + shoot sound, resets state
- `_broadcast_weapon()`: emits weapon_changed signal

### Health (lines 1499-1603)
- `heal(amount)`: increments health, updates display
- `increase_max_health()`: +1 max health
- **`take_damage(enemy_collider)`**: 
  1. Shield passive → blocks damage, deflects enemies, blue flash
  2. Toughness → 35% block, grey flash
  3. Normal damage → -1 HP, red flash, strong hit-stop, post-processing spike
  4. Death → emits `died` signal, queue_free
  5. Invincibility frames → pushes nearby enemies away

### `update_health_display()` (lines 1606-1609)
- Calls HUD.update_health()

### `spawn_ammo_popup()` / `play_ammo_pickup_sound()` (lines 1612-1654)
- "+AMMO" label with elastic scale + drift + fade
- weapon_switch.wav pitched slightly

### `record_kill(weapon_name)` (lines 1657-1661)
- Increments total_kills + per-weapon kill counter

### `unlock_weapon(weapon_name)` (lines 1664-1674)
- Sets unlock flag, adds to inventory, shows HUD notification

### `unlock_passive(passive_name)` (lines 1677-1702)
- Sets unlock flag, applies passive effect immediately, shows HUD notification

### `_check_milestone_announcements()` (lines 1705-1735)
- Checks all 11 milestones against current stats
- Once milestone target is met AND not yet purchased AND not announced → adds to announced_milestones, shows notification via HUD

### `_spawn_shell_casing()` (lines 1738-1763)
- Instantiates shell_casing.gd script on Node2D
- Calculates ejection direction/velocity based on gun aim
- Adds to main scene

### `_spawn_ui_reload_particles()` (lines 1766-1790)
- Golden CPUParticles2D burst for perfect reload celebration

---

## `enemy.gd` (607 lines) — Enemy Entity

### Constants & Variables (lines 1-46)
- `SPEED = 50`, `ANIM_SPEED = 0.2`, `MAX_HEALTH = 3`
- Pickup scene preloads: `COIN_SCENE`, `HEART_SCENE`, `AMMO_SCENE`
- `enemy_type`, `health`, `dying`, `knockback_velocity`
- Visual: `health_label`, `walk_bounce_phase`, `hit_wobble_time`, `_base_sprite_scale`, `shadow_sprite`, `walk_dust`, `clump_rot_offset`
- Custom behaviors: werewolf charge/cooldown, skeleton step, bat wave
- `last_hit_by_weapon` tracked for kill attribution
- Cached `_tree` and `_player_node` references
- Throttled clump detection with `_clump_timer` (0.5s interval)

### `_ready()` (lines 49-157)
- Adds to "enemy" group
- **Type setup**: green (25 HP, 25 speed, 2x scale), purple (60 HP, 12.5 speed, 3x), red (10 HP, 50), bat (4, 85, 0.75x, enemy_bat.png), skeleton (12, 45, 0.95x), ghost (8, 30, 1.1x), zombie (20, 20, 1.15x), werewolf (80, 40, 1.6x)
- Health label for debug display
- Shadow sprite from main scene
- **Drop-in spawn animation**: from 100px above with squash-stretch → slam dust burst
- Walk dust CPUParticles2D (not for ghosts)

### `_physics_process(delta)` (lines 160-247)
- Cached player node check
- Move toward player
- **Clump detection** (throttled every 0.5s): if 2+ enemies within 30px, apply random rotation offset + desync animation
- **Bat**: sinusoidal perpendicular movement
- **Skeleton**: stutter-step every 0.6s
- **Werewolf**: charge when ≤ 160px away (1.5s duration, 110 speed, 3.5s cooldown, red self-modulate)
- Knockback: ghost = none, zombie = 25%, others = full
- Dust emitting when moving
- Move and slide, decay knockback

### Animation (lines 250-322)
- `get_sprite_dir()`: 4-directional from angle
- `update_animation()`: frame cycling, bouncy walk (ghost floats differently), hit wobble spring, shadow scaling

### `take_damage(amount, source_weapon)` (lines 325-366)
- **Anticipation**: immediate hit sound + hit-stop
- **Peak transient sync**: 25ms delay before visual effects
- Damage number popup, health label update, directional splatter
- Death → `die()`
- Hit wobble + red self-modulate → white after 0.1s

### `die()` (lines 369-394)
- Sets dying, disables collision
- Explosion sound, coin drop, massive splatter burst
- Extra hit-stop for elite/tank enemies
- Shrink + spin + fade out tween
- Emits `killed(last_hit_by_weapon)`

### `spawn_coin()` (lines 397-464)
- Weighted loot tables per enemy type:
  - **bat/ghost**: 1% heart, 4% ammo, 35% 1 coin
  - **red/skeleton**: 2% heart, 6% ammo, 50% 1 coin
  - **zombie/green**: 4% heart, 8% ammo, 15% gold coin, else 1-2 coins
  - **purple**: 5% heart, 15% ammo, 2 coins guaranteed + 30% gold coin
  - **werewolf**: 15% heart, 25% ammo, 2 gold coins guaranteed

### `_spawn_slam_dust()` (lines 468-490)
- Dust burst when enemy lands from spawn drop-in

### `_draw()` (lines 493-502)
- Health bar (16×3) drawn above enemy when damaged

### `spawn_damage_number()` (lines 513-553)
- Damage label with elastic scale, drift, fade
- Color scaling: ≥30 = neon pink, ≥15 = yellow, ≥5 = orange, else red
- CRIT label for ≥15 damage

### `spawn_splatter_particles(amount, dir)` (lines 556-607)
- Per-type color: red, green, purple, bone white, ethereal mist, rotting green, brown
- CPUParticles2D burst added to main scene

---

## `bullet.gd` (209 lines) — Projectile

### Constants & Variables (lines 1-36)
- `SPEED = 500`, `KNOCKBACK_FORCE = 500`, `ENEMY_KNOCKBACK_PERCENT = 0.5`
- `direction`, `penetrate`, `explosive`, `hit_enemies`, `bullet_type`, `damage`, `time_accum`
- Trail: `trail_points[]`, `trail_line`, `MAX_TRAIL_POINTS = 7`
- Per-type textures and scales

### `_ready()` (lines 39-97)
- Connect body_entered + screen_exited + 3s timeout
- Set sprite texture/rotation/scale per type
- Missile shows explicit trail sprite
- **Colored PointLight2D**: per-weapon color (pistol=blue, smg=green, shotgun=orange, minigun=yellow, sniper=purple, missile=red)
- **Glowing motion trail**: Line2D with per-weapon colored gradient

### `_physics_process(delta)` (lines 100-115)
- Tracks position history for trail
- Moves along direction at SPEED
- Wavy scale oscillation (sin wave)

### `_on_body_entered()` (lines 120-152)
- **Explosive**: spawn explosion via deferred call, queue_free
- **Enemy hit**: layered hit sound, append to hit_enemies, deal damage, apply knockback (sniper = 0.2x, others = 0.5x), increment combo, spawn sparks
- If not penetrate → queue_free after hit

### `_spawn_explosion(pos)` (lines 155-163)
- Instantiates `EXPLOSION_SCENE` at position, passes source_weapon

### `spawn_sparks(pos, spark_dir)` (lines 166-209)
- Per-weapon colored spark CPUParticles2D burst

---

## `wave_spawner.gd` (118 lines) — Enemy Spawning

### Structure
- `class_name WaveSpawner`, extends Node
- `initialize(p_main)` / `spawn_wave(round_count, count)` / `spawn_enemy(round_count)`

### Weighted Enemy Pools (lines 23-67)
- **Round 1**: bat 0.45, red 0.40, skeleton 0.15
- **Round 2**: +ghost 0.15, zombie 0.20
- **Round 3**: +green 0.15
- **Round 4**: +purple 0.08, werewolf 0.10
- **Round 5+**: balanced pool ~0.12 each

### Spawning (lines 85-118)
- Weighted random type selection
- Edge-of-screen spawning (4 sides, min 200px from player)
- Clamped to world bounds [-290,1570]x[-210,850]
- Up to 10 attempts to find valid spot
- Connects `killed` signal to `main._on_enemy_killed`

---

## `progression_manager.gd` (74 lines) — Static Stats Tracker

### Static Variables (lines 4-38)
- `total_bullets_fired`, `total_coins_collected`, `total_items_collected`, `total_kills`, `peak_combo`, `run_survival_time`
- `announced_milestones[]`
- `weapon_kills{}`: per-weapon kill counts
- `weapon_unlocks{}`: bool per weapon
- `passive_unlocks{}`: bool per passive

### Methods
- `reset_run_stats()`: clears run-based stats
- `record_kill(weapon_name)`: increments per-weapon + total
- `check_milestone_status(id)`: returns current progress for any of 11 milestones

---

## `audio_manager.gd` (252 lines) — Audio System

### Constants (lines 4-22)
- `COMBAT_TRACKS[3]`, `LOBBY_TRACKS[3]`
- `SHOOT_SOUNDS{}`: per-weapon shoot sounds

### Playlists (lines 24-31)
- Shuffled copies, round-robin via `_current_combat_idx/lobby_idx`

### `initialize()` (lines 33-43)
- Stores BGM references, shuffles playlists, calls `_setup_ambience()`

### `_setup_ambience()` (lines 47-90)
- **Wind**: missile_launch.wav pitched to 0.08, looping, with volume gusts (every 4s, -24 to -14 dB)
- **Birds/crickets**: every 2.5s, 45% chance, coin_tick.wav (3.2-4.2 pitch) or lock_on.wav (2.8-3.5 pitch), -24 dB

### `play_next_combat_track()` (lines 92-102)
- Applies pitch scaling (+0.04 per round, max +0.4)

### `play_next_lobby_track()` (lines 104-114)
- Same pitch scaling

### `play_layered_shoot(weapon_type, pos)` (lines 116-177)
- **Layer 1**: Primary weapon sound (AudioStreamPlayer2D, spatial)
- **Layer 2**: Mechanical click (hitmarker.wav, pitch 1.4-1.7)
- **Layer 3**: Sub-bass thump (explosion.wav, pitch 0.32-0.58 depending on weapon)

### `play_layered_hit(pos, is_heavy)` (lines 179-212)
- **Layer 1**: Flesh squish (hit.wav, pitch 0.85-1.15)
- **Layer 2**: Sharp transient (hitmarker.wav, pitch 1.0-1.2)
- **Layer 3** (heavy): Drum thump (drum_tick.wav, pitch 0.4-0.6)

### `play_layered_explosion(pos)` (lines 214-252)
- **Layer 1**: High crack (explosion.wav, pitch 1.2-1.35)
- **Layer 2**: Sub-bass thump (explosion.wav, pitch 0.32-0.38)
- **Layer 3**: 4 delayed shrapnel ticks (hitmarker.wav, pitch 1.2-1.6, delayed 0.04-0.18s)

---

## `procedural_audio_helper.gd` (62 lines) — Sound Effect Generator

### `play_procedural_sound(node, type)` (lines 4-62)
- Creates AudioStreamPlayer on given node
- 13 sound types, all made by repitching existing assets:
  - `mag_out`: weapon_switch.wav ×1.6
  - `mag_in`: walk_step.wav ×0.65
  - `bolt_rack`: weapon_switch.wav ×1.3
  - `ui_tick`: lock_on.wav ×2.5
  - `blocked`: lock_on.wav ×0.45
  - `voice`: walk_step.wav ×0.75
  - `low_ammo_warning`: lock_on.wav ×2.2
  - `empty_warning`: lock_on.wav ×1.6
  - `perfect_ping`: round_win.wav ×2.0
  - `perfect_clack`: weapon_switch.wav ×0.82
  - `good_click`: weapon_switch.wav ×1.5
  - `failed_jam`: hurt.wav ×0.5

---

## `hud.gd` (~2177 lines) — HUD Orchestrator

### Module Instances (lines 27-29)
- `_shop: HudShop`, `_hotbar: HudHotbar`, `_combat: HudCombat`

### State (lines 34-47)
- `can_restart`, `_animating_coins`, `_displayed_score`, `_time`, `_score_glow_time`
- Autohide slide: `_hud_container_offset`, `_hearts_container_offset`, timers, target opacities
- `_title_particles`, `_pause_panel`, `_touch_layer`
- Round Complete/Failed card components
- Sound refs, weapon textures dictionary

### `_ready()` (lines 98-411)
- Sets layer=2, PROCESS_MODE_ALWAYS
- Pre-renders coin textures, loads sounds
- **Module init**: creates HudShop/HudHotbar/HudCombat, passes references
- **Restart/Final Score labels**: layout + styling
- **Shop panel layout** via `_setup_shop_panel_layout()`
- **Title panel layout** via `_setup_title_panel_layout()`
- **HUD labels** via `_setup_hud_labels()`
- **Reload UI** via `_ensure_reload_ui()`
- **Pause panel** via `_build_pause_panel()`
- Sets initial offsets (hidden)
- Creates mobile touch controls if needed
- **Round Complete Card**: 8-bit menu panel with lives bar, time bar, score, next/shop/home buttons
- **Game Over Card**: same structure with red accent, restart/shop/home buttons
- Calls `_find_player()`

### `_setup_shop_panel_layout()` (lines 417-503)
- Shop overlay (click-to-close), responsive sizing (mobile vs desktop)
- "ARMORY" 8-bit menu panel decor, rim glow, bottom shadow

### `_setup_title_panel_layout()` (lines 508-580)
- Full-screen dark background with gradient overlay
- Title label (gold, 108px), subtitle, prompt, controls display

### `_setup_hud_labels()` (lines 585-715)
- Styles all HUD text nodes: ScoreLabel, ScoreIcon, CountdownLabel, RoundCompleteLabel, PrizeLabel, GameOverLabel, GameplayPrompt, IntermissionPrompt, ReloadLabel, EnemyCountLabel, PassivesShelf

### Reload UI (lines 716-807)
- `_ensure_reload_ui()`: creates ReloadPanel with good/perfect zones, fill bar, marker, timer label
- `_update_reload_zones()`: calculates zone widths from percentage
- `_set_reload_panel_visible()`: toggle
- `_update_reload_progress()`: updates fill + marker + countdown text

### `_build_pause_panel()` (lines 813-973)
- Glass overlay with tap-to-resume
- PAUSED 8-bit menu card with sound/music sliders (retro styled)
- Resume, Restart, Quit buttons (circular retro icons)

### `_find_player()` (lines 979-987)
- Connects weapon_changed / reload_started / reload_ticking / reload_finished signals

### `_on_player_weapon_changed()` (lines 990-998)
- Rebuilds hotbar, updates weapon description, refreshes cooldowns

### Score/Health API (lines 1017-1074)
- `update_score(val)`: elastic scale tween on score label, updates shop coin display
- `flash_heal()`: green flash tween
- `update_health(val, max_val)`: manages heart TextureRects, animated transitions on add/remove hearts

### Shop API (lines 1080-1144)
- `show_shop()`: hides hotbar description, shows overlay with fade-in, builds shop cards, scale-in animation
- `hide_shop()`: reverse animation, clears cards
- `handle_shop_confirm()` / `navigate_shop()`: stubs

### Title Screen (lines 1152-1221)
- `show_title()`: random subtitle, platform-specific prompts (mobile vs desktop), fade-in, blinking prompt, title particles (rising embers)
- `hide_title()`: fade-out, stops particles
- `_start_title_particles()`: CPUParticles2D emitter across full screen area

### Intermission / Rounds (lines 1227-1329)
- `show_intermission(round_idx)`: clears previous labels, shows prompt with Start/Mastery buttons
- `show_countdown(round_idx)`: delegates to `_combat.run_countdown()` with 3-2-1-GO!
- `show_round_active(round_idx, count)`: shows round label + enemy count + gameplay prompt
- `update_enemies_remaining(count)`: updates ☠ counter
- `show_round_complete(round_idx, prize)`: calculates health/time percentages, shows Round Complete card with confetti + coin fly animation

### Coin Fly Animation (lines 1331-1380)
- `_play_coin_chink(index)`: escalating pitch coin_tick sounds
- `_pulse_score_label(amount)`: incremental score counter during coin fly
- `_play_coin_fly()` / `_play_coin_fly_2()`: 10 coin arc animation into score icon with tween chaining

*(More HUD sections continue — game over, gameplay prompts, autohide, combo forwarders, etc.)*

---

## `hud_combat.gd` (353 lines) — Combat-phase UI Module

### Variables (lines 7-23)
- `_hud_node`, `_control` references
- Sound refs (set externally): snd_round_start, snd_round_win, snd_drum_tick, snd_kaching, snd_coin_tick
- Combo widget nodes: `_combo_container`, `_combo_label`, `_combo_hype_label`, `_combo_progress_bar`, `_combo_tween`
- `signal coin_anim_finished()`

### `init()` (lines 29-31)
- Stores HUD + Control references

### `build_combo_widget()` (lines 37-103)
- Creates combo card anchored to right side
- Glass panel bg with orange border + shadow
- Combo count label (coral, 44px)
- Hype label (gold, 22px) for titles like "GODLIKE!!"
- Progress bar for combo timer

### `show_combo(count, player_node)` (lines 109-164)
- Sets combo text, determines hype tier:
  - ≥20: "APOCALYPTIC!!" lavender
  - ≥15: "GODLIKE!!" cyan
  - ≥10: "SAVAGE!" green
  - ≥7: "UNSTOPPABLE" coral
  - ≥4: "DOUBLE KILL!" / "TRIPLE KILL!" / "RAMPAGE!" gold
- Updates glass panel color to match hype tier
- Elastic scale-in animation for labels
- Adds camera shake scaling with combo count

### `hide_combo()` / `update_combo_timer()` (lines 170-189)
- Hides container, updates bar fill + color (green→red)

### `run_countdown()` (lines 195-234)
- 3-2-1-GO! sequence with elastic scale per number
- Drum tick per count, round_start sound on GO!
- Expanding ring effects per count (2 rings each, tweened)
- Heal flash on GO!

### `spawn_round_complete_confetti()` (lines 264-290)
- CPUParticles2D with gold/green/cyan/white color ramp

### `play_coin_fly()` (lines 296-339)
- 10 coin panels, each flying in arc from center to score icon
- Arc: lerp position + sin-based vertical offset
- Sequential chink sounds + score pulse per coin
- Emits `coin_anim_finished` after last coin

---

## `hud_hotbar.gd` (387 lines) — Weapon Hotbar Module

### Variables (lines 7-20)
- `_hud_node`, `_control`, `_textures` references
- `_bg: Panel`, `_slots: Array[Panel]`, `_active_idx`
- Description card: `_desc_bg`, `_desc_lbl`, `_last_weapon_name`, timers/opacity

### `init()` / `build(inv, idx)` (lines 25-72)
- Stores refs, clears old slots
- Creates pixel-art bg panel if needed (dark bg, slate outline)
- Calculates total width based on inventory count (72px per slot + 7px gaps + 10px padding)
- Builds each slot via `_build_slot()`

### `_build_slot()` (lines 78-170)
- Creates slot panel with transparent bg
- Decorates with `HudUiKit.decorate_retro_item_card()`
- Active slot: golden ReferenceRect frame overlay
- Weapon icon + slot number badge + ammo badge (clip/reserve) + cooldown bar (bg + fill)

### `refresh_cooldown_bars(cooldowns)` (lines 185-196)
- Updates cooldown fill widths per slot

### `tick(time, player_node)` (lines 202-270)
- Stepped bobbing animation (retro grid alignment)
- Active slot: stepped pulse scale/rotation
- Live ammo counting with color thresholds (red empty, yellow low, white normal)
- Live cooldown bar updates with 8-bit color thresholds (red <35%, yellow <70%, green)

### `update_weapon_description(inv, idx, visible_now)` (lines 276-352)
- Creates/finds description card (pixel panel)
- Accent color bar per weapon
- RichTextLabel with weapon name, damage, description in corresponding colors
- Starts fade timer

### `set_desc_visible()` / `tick_description()` (lines 358-387)
- Toggle visibility, animate opacity fade
- Stepped retro text card scale animation (decaying bounce)

---

## `hud_shop.gd` (345 lines) — Weapon Mastery Dashboard Module

### Variables (lines 7-19)
- `signal purchase_succeeded(key)`
- `_panel`, `_textures`, `_hud_node`, `_main_node`
- `_cards_container`, `_ambient_motes`, `_panel_gradients[]`
- References `MILESTONES` from WeaponDB

### `init()` / `clear_cards()` (lines 21-43)
- Stores refs, clears ambient particles + grid container

### `build_cards()` (lines 46-345)
- Creates scrollable grid with:
  - Header "WEAPON & PASSIVE MASTERY" (32px gold)
  - Subtitle instructions
  - **Weapons section** (cyan header): 3-column grid
  - **Passives section** (pink header): 3-column grid
- 11 milestone cards ordered: shotgun→smg→minigun→sniper→missile→shield→speed_loader→golden_touch→magnet_ring→toughness→damage_boost
- Each card shows: icon, name, status badge ([ACTIVE]/[READY TO BUY]/[LOCKED]), description, progress bar + text
  - If milestone met AND not purchased → BUY button with cost (checks coin balance, enables/disables)
  - On purchase → deducts coins, calls player.unlock_weapon() or unlock_passive(), rebuilds cards
- Hover scale animation (1.04x)

---

## `hud_ui_kit.gd` (899 lines) — Design Tokens & Helpers

### Coin Drawing (lines 8-46)
- `draw_coin_on_canvas()`: procedural hexagonal coin with 3D rotation effect (width_factor for perspective), gold fill + orange edge lines + inner hex shadow

### Design Tokens (lines 52-64)
- `C_GOLD` (1.0, 0.85, 0.20), `C_GOLD_BRIGHT`, `C_CYAN`, `C_CORAL`, `C_DANGER`, `C_SUCCESS`, `C_LAVENDER`, `C_PANEL_BG`, `C_PANEL_BORDER`, `C_TEXT_PRI`, `C_TEXT_SEC`, `C_TEXT_DIM`, `C_OUTLINE`

### Gacha Rarity System (lines 69-98)
- 5 tiers: common (grey), rare (cyan), epic (purple), legendary (gold), ultra (coral)
- Each with: color, name, glow color, weight (50/30/12/6/2%)
- `PULL_COST = 100`

### Weapon Details (lines 103-110)
- `WEAPON_DETAILS{}`: name, desc, damage, color for all 6 weapons

### Style Builders (lines 127-661)
- `make_glass_panel()`: rounded StyleBoxFlat with shadow
- `make_pixel_panel()`: sharp pixel-art panel with hard shadow
- `make_button_style()`: normal/hover/pressed/disabled states
- `style_button()`: applies button styles + cursor
- `add_rim_highlight()`: top-edge highlight strip
- `spawn_ui_burst()`: one-shot CPUParticles2D burst
- `make_glow_ring()`: aura glow behind control
- `make_gradient_overlay()`: subtle vertical gradient
- `make_premium_card()`: layered card with shadow, border, rim
- `spawn_floating_motes()`: ambient floating particles
- `make_gacha_pull_button()`: big premium pull button with gloss + label
- `decorate_retro_panel()`: SNES-style royal blue gradient + gold rope borders + ruby corner plaques
- `decorate_retro_item_card()`: 16-bit gold border + corner studs for small cards
- `decorate_8bit_menu_panel()`: dark bg + colored outline + capsule title banner

### `RetroProgressBar` (lines 667-691)
- Custom Control: 8-bit tick-style progress bar with accent color

### `make_retro_slider()` (lines 696-741)
- Draws retro tick track + circle grabber with glint

### `make_retro_circular_button()` (lines 747-847)
- Circular button with shadow, border rings, custom icons (play, restart, home, next, menu — all vector-drawn)

### `decorate_with_retro_icon()` (lines 853-899)
- Vector icons for heart, clock, musical note, treble clef

---

## `weapon_db.gd` (131 lines) — Weapon Data

### `WEAPON_DATA` (lines 4-11)
- 6 weapons with: fire_rate, spread, bullets, penetrate (bool), explosive (bool), ammo_max, damage, bullet_type, reload_time, recoil, clip_max

### `WEAPON_SHAKES` (lines 13-20)
- Per-weapon camera shake amounts

### `WEAPON_SCALES` (lines 22-29)
- Per-weapon gun sprite scales

### `MILESTONES` (lines 31-131)
- 11 milestones: 5 weapons + 6 passives
- Each: name, desc, source, target, type (kills/time/bullets/coins/items/combo), cost, category (weapon/passive)

---

## `weapon_card.gd` (30 lines) — UI Card Hover Animation

### Structure
- Extends Control, `@onready var icon`
- Mouse enter: scale 1.02x, icon opacity 1.0
- Mouse exit: scale 1.0x, icon opacity 0.85
- Click press: scale 0.98x → release: scale 1.02x → 1.0x

---

## `input_actions.gd` (76 lines) — Input Mapping

### Actions defined (lines 4-46)
- `move_left/right/up/down`: WASD + left stick + DPAD
- `shoot`: LMB + right trigger
- `confirm`: Space + A button
- `shop`: Tab + button 6
- `pause`: Esc + button 7
- `switch_weapon_prev/next`: Q/E + shoulder buttons + Y

### Helpers (lines 49-76)
- `_ensure_action()`: creates InputMap action with deadzone
- `_add_key_event()`: keyboard
- `_add_mouse_event()`: mouse button
- `_add_joy_axis_event()`: analog axis
- `_add_joy_button_event()`: digital button

---

## `world_generator.gd` (382 lines) — Procedural World

### Texture Cache (lines 5-10)
- `_light_tex`, `_shadow_tex`, `_grass_tex`, `_rock_tex`, `_tree_tex`, `_bush_tex`

### `generate_world()` (lines 12-15)
- `setup_ground()` → `setup_world_environment()` → `spawn_decor()`

### `setup_world_environment()` (lines 17-27)
- WorldEnvironment with glow (intensity 0.55, bloom 0.28, screen blend)

### `get_radial_light_texture()` (lines 29-42)
- 64×64 radial gradient (white center → transparent edge), squared falloff

### `_create_shadow_texture()` (lines 44-57)
- 48×24 oval shadow with pow(1.0-dist, 1.3) falloff, 0.55 alpha

### `_create_grass_texture()` (lines 59-77)
- 16×16 three grass blade sprites

### `_create_rock_texture()` (lines 79-104)
- 24×24 circular rock with border, fill, shadow, highlight shading

### `_create_tree_texture()` (lines 106-140)
- 32×48 tree: 13-18px trunk (brown) + circular canopy (green with highlight/shadow)

### `setup_ground()` (lines 142-214)
- TileMap with: grass sheet, procedural dirt tile (brown with speckles), procedural wall tile (grey)
- Simplex noise determines grass vs dirt distribution
- Wall boundary layer

### `_create_bush_texture()` (lines 216-240)
- 20×20 circular bush with highlight/shadow

### `spawn_decor()` (lines 242-382)
- Wind sway shader material
- **120 grass tufts**: Sprite2D with shadow, distributed across map
- **35 boulders**: StaticBody2D with CircleShape2D collision, shadow
- **40 trees**: StaticBody2D with trunk collision, sway shader, shadow
- **50 bushes**: StaticBody2D with sway shader, collision, shadow

---

## `player_canvas_renderer.gd` (258 lines) — Canvas Overlay

### Structure
- `var player: CharacterBody2D`, z_index = 5

### `_draw()` (lines 14-258)
- **Shield bubble**: pulsing cyan circle with rotating arc segments
- **Crosshair**: velocity-based squash/stretch transform (stretch_factor 1.0-1.4)
  - Color: neon cyan (ready), orange (reloading), red (empty)
  - Circle center + 4 tick marks
- **Lock-on bracket**: dotted line from muzzle to target + pulsing corner brackets + arc circle + center dot
- **Aim dotted line**: from muzzle outward
- **Muzzle flash**: multi-layered starburst:
  - Outer glow (10 spikes × 1.3x/0.3x alternating, random variation)
  - Mid star (10 spikes × full/half alternating)
  - Core (bright white-yellow)
  - Random spark particles
- **Ammo display**: segmented bar (up to 8 segments) below player
  - Colors: cyan (normal), orange (reloading), red (empty), yellow (low)
  - White highlight on filled segments
- **Active reload bar**: timing bar below ammo
  - Dark border, Good zone (green, 0.32-0.70), Perfect zone (gold, 0.45-0.58)
  - Moving white marker
  - Jam state: red background

---

## `enemy_indicators.gd` (115 lines) — Off-screen Indicators

### Structure
- `class_name EnemyIndicators`, extends Node2D, z_index = 10

### `_draw()` (lines 34-115)
- Only when state == ACTIVE
- For each enemy:
  - If on-screen: skip
  - If off-screen: clamp position to viewport edges with VISIBLE_MARGIN buffer
  - Directional triangle (arrow) pointing toward enemy position
  - White halo circle behind indicator
  - Color-coded by enemy type (red, green, purple, bat=purple-ish, skeleton=bones, ghost=cyan, zombie=olive, werewolf=orange)

---

## `shell_casing.gd` (60 lines) — Ejected Brass

### Variables
- `velocity`, `gravity = 450`, `rot_speed`, `floor_y`, `landed`, `age`

### `_ready()` (lines 10-19)
- Adds to "shell_casings" group
- Caps at 120 casings (removes oldest)
- Random rotation speed

### `_physics_process()` (lines 21-29)
- While airborne: gravity + movement + rotation
- On landing: set `landed`, play tink sound
- After 12s on floor: fade out → queue_free

### `_play_tink_sound()` (lines 42-54)
- drum_tick.wav pitched 2.8-3.5x to sound like brass

### `_draw()` (lines 56-60)
- 3×1.5px brass-colored rectangle with highlight stripe

---

## `ammo.gd` (62 lines) — Ammo Pickup

### Variables
- `LIFETIME = 10`, oscillation constants

### `_ready()` (lines 12-19)
- Random initial phase, connect body_entered, start despawn timer

### `_process(delta)` (lines 22-33)
- Vertical oscillation, pulsating scale, gentle rotation

### `_on_body_entered()` (lines 36-57)
- If player: `refill_ammo(0.35)`, increment items collected, hide sprite, disable collision, wait for sound → queue_free

---

## `coin.gd` (84 lines) — Coin Pickup

### Variables
- `score_value = 10`, references HudUiKit for coin frames

### `_ready()` (lines 14-23)
- Sets scale 0.4, adds to "coins" group, random phase, start despawn

### `_process(delta)` (lines 25-36)
- Bobbing animation, coin frame cycling (30 fps through pre-rendered frames)

### `_draw()` (lines 38-44)
- Fallback: procedural hexagonal coin via `HudUiKit.draw_coin_on_canvas()`

### `_on_body_entered()` (lines 46-81)
- If player: play sound, calculate score (20% double with Golden Touch), add_score, track stats, hide, disable, wait → queue_free

---

## `heart.gd` (86 lines) — Health Pickup

### Variables
- `SPIN_SPEED = 3`, `LIFETIME = 10`

### `_ready()` (lines 13-19)
- Random phase, connect signals, sets procedurally generated heal sound

### `_process(delta)` (lines 22-37)
- Heartbeat pulse animation: quick double-beat scale (1.0→1.25→1.1→1.0) every 1.2s, floating + rotation

### `_on_body_entered()` (lines 40-53)
- If player: increment items, play heal sound, call main.heal_player(), hide → queue_free

### `create_heal_stream()` (lines 60-86)
- Procedural ascending chime: 523.25Hz → 659.25Hz → 783.99Hz → 1046.5Hz over 0.3s
- 8-bit unsigned WAV at 22050Hz, quadratic amplitude envelope

---

## `generate_assets.gd` (8 lines) — Asset Generator Stub

### Structure
- `@tool`, extends SceneTree
- Prints "Assets already exist. Skipping asset generation." and quits
