shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float chromatic_aberration : hint_range(0.0, 0.1) = 0.0;
uniform float distortion : hint_range(-1.0, 1.0) = 0.05;

void fragment() {
	// Center UV coordinates to [-0.5, 0.5]
	vec2 uv = SCREEN_UV - 0.5;
	
	// Radial lens barrel distortion
	float r2 = dot(uv, uv);
	vec2 distorted_uv = uv * (1.0 + distortion * r2) + 0.5;
	
	// Check if distorted coordinates fall outside the screen boundary
	if (distorted_uv.x < 0.0 || distorted_uv.x > 1.0 || distorted_uv.y < 0.0 || distorted_uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0); // Black outer border (letterbox look)
	} else {
		// Shift RGB color channels radially for realistic chromatic aberration
		vec2 dir = distorted_uv - 0.5;
		float len = length(dir);
		vec2 radial_dir = len > 0.0001 ? dir / len : vec2(0.0);
		
		float r_shift = chromatic_aberration;
		float b_shift = -chromatic_aberration;
		
		float r = texture(screen_texture, distorted_uv + radial_dir * r_shift).r;
		float g = texture(screen_texture, distorted_uv).g;
		float b = texture(screen_texture, distorted_uv + radial_dir * b_shift).b;
		
		COLOR = vec4(r, g, b, 1.0);
	}
}
