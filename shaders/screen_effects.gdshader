shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float chromatic_aberration : hint_range(0.0, 0.1) = 0.0;
uniform float distortion : hint_range(-1.0, 1.0) = 0.05;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.8;

void fragment() {
	// Center UV coordinates to [-0.5, 0.5]
	vec2 uv = SCREEN_UV - 0.5;
	
	// Dynamically zoom in based on distortion to hide black borders
	float zoom = 1.0 + max(0.0, distortion) * 0.48;
	vec2 zoomed_uv = uv / zoom;
	
	// Radial lens barrel distortion
	float r2 = dot(zoomed_uv, zoomed_uv);
	vec2 distorted_uv = clamp(zoomed_uv * (1.0 + distortion * r2) + 0.5, 0.001, 0.999);
	
	// Shift RGB color channels radially for realistic chromatic aberration
	vec2 dir = distorted_uv - 0.5;
	float len = length(dir);
	vec2 radial_dir = len > 0.0001 ? dir / len : vec2(0.0);
	
	float r_shift = chromatic_aberration;
	float b_shift = -chromatic_aberration;
	
	float r = texture(screen_texture, distorted_uv + radial_dir * r_shift).r;
	float g = texture(screen_texture, distorted_uv).g;
	float b = texture(screen_texture, distorted_uv + radial_dir * b_shift).b;
	
	// Cinematic Vignette calculation
	float d = length(SCREEN_UV - 0.5);
	float vignette = smoothstep(0.8, 0.45, d * vignette_intensity);
	
	COLOR = vec4(r, g, b, 1.0) * vignette;
}


