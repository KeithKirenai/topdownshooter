# Weapon/Ability Gacha UI — Implementation Spec

This document condenses the UI remake you provided into an actionable Godot integration plan and a minimal prototype API.

Goals
- Replace character-centric gacha with weapon/ability showcase stage.
- Express rarity via material + energy (no text required).
- Always animated central presentation, animated cards, reveal sequence, and conversion flow.

Prototype files included
- `scripts/showcase.gd` — lightweight Control-based Showcase controller (2D). Attach to a `Control` node.
- `shaders/rarity_material.gdshader` — CanvasItem shader used to give items material+emissive/aura effects.

Showcase node tree (recommended)
- Showcase (Control) [attach `scripts/showcase.gd`]
  - ItemSprite (TextureRect) — item artwork; set `texture` or `region`.
  - Glow (TextureRect) — optional glow layer using `rarity_material.gdshader`.
  - AnimationPlayer — for sequenced camera/scale/timing.
  - Tween — for tweens (or use AnimationPlayer only).
  - AudioStreamPlayer — for reveal SFX.
  - Particles2D (optional) — reveal sparks.

Usage (high-level)
1. Assign the item artwork to `ItemSprite.texture`.
2. Set `rarity` (`common`,`rare`,`epic`,`legendary`) on the script or via exported property.
3. Call `play_reveal_sequence()` to run pull animation: charge → silhouette → material reveal → shine burst.

Integration notes
- The prototype is 2D/CanvasItem-friendly so it's easy to drop into existing HUD scenes.
- For 3D models, port the material logic to `SpatialMaterial`/`StandardMaterial3D` or a `ShaderMaterial` for 3D meshes.
- Replace placeholder audio with project SFX (`assets/sounds/`), and fine-tune particle textures.
- Add post-process (screen shake, distortion) via `CanvasLayer` or `Viewport` transforms.

Performance
- Use `GPUParticles` in Godot 4 or optimized `Particles2D` in Godot 3.
- Provide sprite fallbacks for lower-end devices.

Next steps you can request
- Scaffold a ready-made `scenes/showcase.tscn` with nodes pre-wired.
- Add particle textures and sample audio files.
- Create a `Item` Resource type (JSON or `.tres`) for weapon/ability data.
