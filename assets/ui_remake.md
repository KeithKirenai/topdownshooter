UI Remake - Weapon/Ability Showcase (scaffolded)

Files added:
- scenes/showcase.tscn : Control-based showcase scene with `WeaponSprite` and `AnimationPlayer`.
- scripts/showcase.gd : lightweight script for continuous rotation + breathing animation.
- shaders/rarity_material.gdshader : canvas shader for material/emissive/aura parameters.

Notes:
- The scene uses a TextureRect so it works in 2D HUD contexts without requiring 3D models.
- `rarity_material.gdshader` exposes uniforms for base/emissive colors, noise texture and aura strength.
- Next steps: hook `WeaponSprite.texture` to item art, provide a noise texture asset, create background variants, and build the full reveal timeline in `AnimationPlayer`.
