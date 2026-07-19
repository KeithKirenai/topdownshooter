# 🔫 Pewtopia (Godot 4.7)

A feature-rich, highly polished 2D Top-Down Shooter prototype built in **Godot Engine 4.7** using **GDScript**, utilizing a **GL Compatibility** renderer and advanced programmatic visual/audio effects.

---

## 🎮 Key Features

### 🌟 Player Mechanics & Weapons System
*   **Physics-Based Movement & Combat:** Dynamic WASD/Joystick movement with customizable recoil velocities, weapon kickback, and enemy pushback.
*   **Advanced Aim Assist:** Mouse or right-stick aiming with spring-interpolated crosshair movement, aim assistance, and lock-on brackets within a $55^\circ$ cone.
*   **Gears of War-Style Active Reload:** Interactive reload mechanic with Perfect (bonus fire-rate/damage), Good, and Jammed states (gun venting smoke and jamming).
*   **Weapon Arsenal & Progression:** 6 unique weapons (Pistol, SMG, Shotgun, Minigun, Sniper, Missile) unlocked via a modular milestone system.
*   **Passive Upgrades:** Custom passive perks including Shield Bubbles, Speed Loader, Golden Touch (double coins), Magnet Ring (vacuum pickups), Toughness (damage block), and Damage Boost.

### 👾 Enemy System (Vampire Survivors-Inspired)
*   **8 Diverse AI Archetypes:** Red (basic), Green (tank), Purple (elite), Bat (fast/weaving), Skeleton (stutter-step), Ghost (ignores knockback/floats), Zombie (slow/resilient), and Werewolf (aggro charging).
*   **Dynamic Spawn Director:** Wave spawner that controls weighted spawn pools, scaling complexity, off-screen spawning clamping, and crowd clump-avoidance behavior.
*   **Diegetic Feedback:** Health bars, damage numbers, and directional splatters.

### 🎨 Retro Visual FX & Shaders Stack
*   **Dynamic Lighting:** PointLight2D configurations for warm ambient player auras, flashlight cones, colored bullet glows, and expanding explosion flashes.
*   **Custom Shaders:** 
    *   `wind_sway.gdshader` for organic movement of grass, trees, and bushes.
    *   `screen_effects.gdshader` providing chromatic aberration, low-health vignette pulsing, and CRT distortion.
    *   `rarity_material.gdshader` for gacha-style item color highlighting.
*   **Hit Stop Interaction:** Brief time-scale manipulation (0.05x speed for 80ms) on heavy impacts to maximize combat feedback.
*   **Procedural Animations:** Procedural walking squash/stretch cycles, crosshair velocity stretching, and weapon recoil tweens.

### 🔊 Procedural & Layered Audio Engine
*   **Adaptive Playlists:** Shuffled background tracks for combat and lobbies with pitch speedups scaling with current rounds.
*   **Procedural Ambience:** Generates real-time wind sounds and periodic bird chirps using pitch-shifted sound files.
*   **Multi-Layered Sound FX:** 
    *   *Shooting:* Combines primary weapon fire, mechanical clicks, and sub-bass thumps.
    *   *Hits:* Layered flesh squishes, transient clicks, and heavy drum thumps.
    *   *Explosions:* Crackling highs, deep sub-bass drops, and delayed shrapnel/debris ticks.

---

## 🛠️ Project Structure

```
pewtopia/
├── project.godot             # Godot Engine project settings
├── default_bus_layout.tres   # Audio bus mapping (BGM, SFX, Ambience)
├── icon.svg                  # Project icon asset
│
├── scenes/                   # Scene Node configurations (.tscn)
│   ├── main.tscn             # Main game loop orchestrator
│   ├── player.tscn           # Player scene, cameras, and collision setup
│   ├── enemy.tscn            # Instantiated enemy character configurations
│   ├── bullet.tscn           # Projectile & tail trails
│   ├── explosion.tscn        # Explosive particle radii & timing
│   ├── coin.tscn / ammo.tscn # Pickups and collectible drops
│   └── hud.tscn              # Modular UI viewport container
│
├── scripts/                  # Core GDScript Logic
│   ├── main.gd               # Master game controller & state machine
│   ├── player.gd             # Player physics, reload, and passives
│   ├── player_canvas_renderer.gd # In-game crosshair & HUD overlay
│   ├── enemy.gd              # State-driven enemy behaviors
│   ├── wave_spawner.gd       # Weighted wave spawning system
│   ├── weapon_db.gd          # Database of gun statistics & progression milestones
│   ├── progression_manager.gd# Global stats tracker (kills, coins, time)
│   ├── hud.gd / hud_ui_kit.gd# Modular glass-morphism/retro UI kit
│   ├── audio_manager.gd      # Dynamic background music & layered sound mixer
│   └── world_generator.gd    # Procedural tilemap terrain & scenery
│
└── shaders/                  # Custom Godot Shading Language files
    ├── wind_sway.gdshader    # Vertex displacement for vegetation
    ├── screen_effects.gdshader # Post-processing canvas shader
    └── rarity_material.gdshader # Color-graded item outlines
```

---

## 🎮 Controls

| Action | Keyboard / Mouse | Gamepad |
| :--- | :--- | :--- |
| **Move** | `W` `A` `S` `D` | Left Analog Stick / D-Pad |
| **Aim** | Mouse Cursor | Right Analog Stick |
| **Shoot** | `Left Click` | Right Trigger (`R2`) |
| **Reload** | `R` | Face Button West (`X` / `□`) |
| **Next Weapon** | `E` / Scroll Down | Right Bumper (`R1`) |
| **Prev Weapon** | `Q` / Scroll Up | Left Bumper (`L1`) |
| **Select Slot** | `1` - `6` keys | - |
| **Open Shop** | `Tab` | View/Select Button |
| **Pause** | `Escape` | Menu/Start Button |

> [!TIP]
> **Cheat Code:** Enter the classic sequence `W` `W` `S` `S` `W` `W` `D` `D` during gameplay to instantly unlock all weapons and maximize upgrades!

---

## 🚀 Getting Started

1. Download and install **Godot Engine 4.7** (Standard version).
2. Clone or download this repository.
3. Open Godot project manager and click **Import**.
4. Browse to the root of the project, select `project.godot`, and open it.
5. Click **Run** (F5) to play!
