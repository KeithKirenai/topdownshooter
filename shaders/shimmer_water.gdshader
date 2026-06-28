shader_type canvas_item;

uniform vec4 water_color : source_color = vec4(0.15, 0.45, 0.7, 0.55);
uniform vec4 shimmer_color : source_color = vec4(0.5, 0.75, 1.0, 0.85);
uniform float speed = 1.2;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), f.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	
	// circular puddle shape
	vec2 center_dist = uv - 0.5;
	float dist_sq = dot(center_dist, center_dist) * 4.0;
	if (dist_sq > 1.0) {
		discard;
	}
	
	// scrolling dual wave noise
	float wave1 = noise(uv * 8.0 + vec2(TIME * speed * 0.5, TIME * speed * 0.3));
	float wave2 = noise(uv * 12.0 - vec2(TIME * speed * 0.4, TIME * speed * 0.6));
	float shimmer = (wave1 + wave2) * 0.5;
	
	// blend colors
	vec4 base = mix(water_color, shimmer_color, step(0.58, shimmer) * 0.4);
	
	// reflection glow at the edges
	float edge_glow = smoothstep(0.4, 0.95, dist_sq) * 0.2;
	base.rgb += shimmer_color.rgb * edge_glow;
	
	// soft edge alpha fade
	base.a *= smoothstep(1.0, 0.85, dist_sq);
	
	COLOR = base;
}
