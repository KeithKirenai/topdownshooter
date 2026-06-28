shader_type canvas_item;

uniform vec4 base_color : hint_color = vec4(0.2,0.6,1.0,1.0);
uniform vec4 glow_color : hint_color = vec4(0.8,0.9,1.0,1.0);
uniform float pulse := 0.0;
uniform float fill := 0.0; // 0..1 radial completion

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    float dist = length(uv);
    // radial mask for rune circle
    float ring = smoothstep(0.28, 0.26, dist) - smoothstep(0.22, 0.20, dist);
    // inner fill based on 'fill' uniform
    float inner = smoothstep(0.45, 0.0, dist) * fill;
    // pulse-modulated glow
    float g = pow(max(0.0, 1.0 - dist), 2.0) * (0.5 + 0.5 * sin(pulse * 6.2831));
    vec3 color = mix(base_color.rgb, glow_color.rgb, g);
    float alpha = max(ring, inner) * (0.6 + 0.4 * g);
    COLOR = vec4(color, alpha);
}
