# Scripts Documentation — Top Down Shooter (Godot 4.7)

## Project Overview

Godot 4.7 top-down shooter. Main scene: `scenes/main.tscn`, 1280x720 viewport, GL Compatibility renderer, Jolt Physics 3D. Singleton autoload: `input_actions.gd`.

---

## Core Game Loop

| Script | Role |
|---|---|
| `main.gd` | Global game state machine, orchestrates rounds, score, UI flow |
| `player.gd` | Player character — movement, aiming, weapons, reload system, passives |
| `enemy.gd` | Enemy character — 8 types with unique AI, damage, loot drops |
| `bullet.gd` | Projectile — travel, collision, hit effects, penetration, explosions |
| `wave_spawner.gd` | Round-based weighted enemy spawning with Vampire Survivors-style pool |

---

## Player Systems

### `player.gd` (CharacterBody2D, ~1790 lines)
- **Movement**: WASD/joystick, speed 150, recoil velocity, collision pushback
- **Aiming**: Mouse or right-stick with spring-interpolated visual crosshair + aim assist (lock-on within 55°, 350px range)
- **Weapons**: Inventory-based slot system (`[name, reserve, clip]`), switch via Q/E/scroll/1-9
- **Shooting**: Per-weapon fire rate, spread accumulation (minigun), recoil, muzzle flash, shell casings
- **Reload**: Gears-of-War active reload system with perfect/good/fail zones, gun jamming, bolt-rack animation
- **Passive Upgrades**: Shield (absorb), Speed Loader (30% faster), Golden Touch (20% double coins), Magnet Ring (2.2x range), Toughness (35% block), Damage Boost (+35%)
- **Visual FX**: Procedural walk cycle (squash/stretch), damage wobble, camera shake, gun kickback, diegetic gun LED, shadow sprite, walk dust, muzzle smoke, jam vent smoke, weather embers, post-processing (chromatic aberration, distortion, vignette)
- **Crosshair**: Spring-physics-driven with velocity-based squash/stretch
- **Cheat code**: `WWSSWWDD` unlocks all weapons

### `player_canvas_renderer.gd` (Node2D, ~258 lines)
- Renders crosshair, muzzle flash (starburst), lock-on bracket, segmented ammo bar, active reload timing bar, shield bubble, aim dotted line

### `weapon_db.gd` (RefCounted, ~131 lines)
- `WEAPON_DATA`: Stats for pistol, smg, shotgun, minigun, sniper, missile
- `WEAPON_SHAKES` / `WEAPON_SCALES`: Per-weapon visual parameters
- `MILESTONES`: 11 unlock milestones (weapons + passives) with type, target, cost

---

## Enemy Systems

### `enemy.gd` (CharacterBody2D, ~607 lines)
- 8 types: **red** (basic), **green** (tank), **purple** (elite), **bat** (fast/swerving), **skeleton** (stutter-step), **ghost** (ignores KB, floats), **zombie** (slow, reduced KB), **werewolf** (charges)
- Bouncy walk animation, drop-in spawn, shadow sprite, walk dust
- Damage numbers, directional splatter particles, health bar, health label
- Loot drops vary by enemy type (coins, hearts, ammo, gold coins)
- Clump detection for organic crowd movement

### `wave_spawner.gd` (Node, ~118 lines)
- Weighted random enemy pool per round (rounds 1-5+ with increasing complexity)
- Off-screen spawning clamped to world bounds, minimum 200px from player

---

## Projectile & Explosion

### `bullet.gd` (Area2D, ~209 lines)
- Travels at speed 500, 3s lifetime, screen-exit cleanup
- Per-weapon textures, scales, colors, trails (Line2D with gradient), glow (PointLight2D)
- Piercing (sniper), explosive (missile → spawns explosion), knockback
- Hit sparks, combo increment, professional layered hit sounds

### `explosion.gd` (Area2D, ~124 lines)
- 25ms delayed visual/aural sync (anticipation → peak transient)
- Expanding dynamic light flash, smoke + ember particles
- 15 damage to all overlapping enemies, heavy knockback

---

## Pickups

| Script | Behavior |
|---|---|
| `ammo.gd` | Refills 35% ammo, 10s lifetime, floating/bobbing animation |
| `coin.gd` | 10 score, animated coin sprite (pre-rendered 30-frame spritesheet), 20% double with Golden Touch, 10s lifetime |
| `heart.gd` | Heals 1 HP, procedurally generated ascending chime sound, 10s lifetime |

---

## HUD System

The HUD is split into modular components:

| Script | Responsibility |
|---|---|
| `hud.gd` (~2177 lines) | Orchestrator — owns scene tree nodes, delegates to modules. Handles shop, title screen, intermission, game over, restart, coin animation, touch controls, pause, score/health updates |
| `hud_combat.gd` (~353 lines) | Countdown (3-2-1-GO!), combo widget with hype labels, round complete confetti, coin fly animation, kaching |
| `hud_hotbar.gd` (~387 lines) | Weapon hotbar with retro pixel-art border, ammo counters, cooldown bars, weapon description card |
| `hud_shop.gd` (~345 lines) | Weapon Mastery Dashboard — grid of 11 milestones with progress bars, buy buttons with cost/affordability |
| `hud_ui_kit.gd` (~899 lines) | Shared design tokens (colors, rarity system), style builders (glass panels, pixel panels, buttons, sliders), decorators for retro 8-bit/16-bit panels, RetroProgressBar, TouchJoystick/TouchControlLayer, coin frame generator |

### UI Design Tokens (`hud_ui_kit.gd`)
- Colors: C_GOLD, C_CYAN, C_CORAL, C_DANGER, C_SUCCESS, C_LAVENDER, etc.
- Gacha rarity: common → rare → epic → legendary → ultra (with weights and colors)
- WEAPON_DETAILS: name/desc/damage/color for each weapon

---

## Audio

### `audio_manager.gd` (Node, ~252 lines)
- **BGM**: Shuffled combat (3 tracks) and lobby (3 tracks) playlists, pitch increases per round
- **Ambience**: Procedural wind (missile launch pitched down 0.08), periodic bird chirps (coin_tick/lock_on pitched up)
- **Layered Sounds**: 3-layer shoot (primary + click + sub-bass), 3-layer hit (squish + click + optional thump), 3-layer explosion (crack + sub + shrapnel ticks)

### `procedural_audio_helper.gd` (RefCounted, ~62 lines)
- 13 procedural sound types (mag_out, mag_in, bolt_rack, perfect_ping, failed_jam, etc.) — all created by re-pitching existing assets

### `audio_manager.gd` (also handles shoot/hit/explosion layered sounds)
- `play_layered_shoot()`: 3 layers (primary weapon sound + mechanical click + sub-bass thump)
- `play_layered_hit()`: 2-3 layers (flesh squish + transient click + optional drum thump for heavy)
- `play_layered_explosion()`: 3 layers (high crack + sub-bass + 4 delayed shrapnel ticks)

---

## Progression

### `progression_manager.gd` (RefCounted, ~74 lines)
- Static singleton tracking: kills, coins, items, bullets, combo, survival time
- Centralized storage for weapon_kills, weapon_unlocks, passive_unlocks
- `check_milestone_status()`: returns current progress value for any milestone ID
- `record_kill()`: tracks per-weapon and total kills

### Milestone System (in `player.gd` + `weapon_db.gd`)
- 11 milestones: 5 weapons (Shotgun → SMG → Minigun → Sniper → Missile) + 6 passives
- Each has a tracking type (kills/time/bullets/coins/items/combo) and a target value
- When milestone is met → item is "ready to buy" in Mastery Dashboard
- Purchase deducts coins from score, triggers unlock notification

---

## World & Environment

### `world_generator.gd` (Node2D, ~382 lines)
- Procedural world with TileMap (grass/dirt via simplex noise), wall boundaries
- Dynamically generated textures: grass tufts, rocks, trees, bushes (all pixel-art drawn in code)
- Wind-sway shader applied to grass/trees/bushes
- Environment with glow/bloom, PointLight2D textures for dynamic lighting
- Collision for rocks/trees/bushes (obstacle layer 4)

### `generate_assets.gd` (SceneTree tool)
- Legacy asset generator — all assets are already committed; this script just quits

---

## Input

### `input_actions.gd` (Autoload Node, ~76 lines)
- Defines all input actions: movement (WASD/left stick/DPAD), shoot (LMB/right trigger), confirm (Space/A), shop (Tab/Select), pause (Esc/Start), weapon switch (Q/E/LB/RB/Y)
- Fallback for missing InputMap entries

---

## Miscellaneous

| Script | Purpose |
|---|---|
| `shell_casing.gd` | Ejected brass casing physics (gravity, bounce, tink sound), max 120 on floor, fades after 12s |
| `enemy_indicators.gd` | Off-screen enemy triangle indicators at screen edges, color-coded by type |
| `weapon_card.gd` | Hover/click animation for weapon card UI controls (scale tween) |

---

## Visual Effects Stack

1. **Shadow** — Programmatic radial-gradient shadow beneath all characters/decor
2. **Lighting** — PointLight2D on player (warm aura + directional flashlight), bullets (colored glow), explosions (expanding flash)
3. **Particles** — CPUParticles2D for: walk dust, muzzle smoke, hit splatter, explosion smoke/embers, confetti, coin sparkles, shield aura, title floaters
4. **Screen Shader** (`screen_effects.gdshader`) — Chromatic aberration, distortion, vignette (low-health heartbeat pulse)
5. **Hit Stop** — Time-scale manipulation (0.05x for 80ms) for impactful hits
6. **Post-Processing** — Glow/bloom via WorldEnvironment
