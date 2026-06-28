shader_type canvas_item;

uniform vec4 base_color : hint_color = vec4(0.6,0.6,0.6,1.0);
uniform vec4 emissive_color : hint_color = vec4(0.0,0.0,0.0,1.0);
uniform float emissive_strength = 0.0;
uniform float aura_strength = 0.0;
uniform sampler2D noise_tex : hint_albedo = null;
uniform float noise_speed = 1.0;
uniform float silhouette = 0.0; // 0 = normal, 1 = full dark silhouette

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 base = mix(tex.rgb, base_color.rgb, 0.35);
	vec2 uv = UV;
	float n = 1.0;
	if (noise_tex != null) {
		n = texture(noise_tex, uv * 2.0 + vec2(TIME * noise_speed, TIME * noise_speed)).r;
	}
	vec3 emissive = emissive_color.rgb * emissive_strength * n * aura_strength;
	vec3 outc = base + emissive;
	// silhouette mix
	outc = mix(outc, vec3(0.03,0.03,0.03), silhouette);
	COLOR = vec4(outc, tex.a * base_color.a);
}
