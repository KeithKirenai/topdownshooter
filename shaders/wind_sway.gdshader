shader_type canvas_item;

uniform float wind_speed : hint_range(0.0, 10.0) = 3.0;
uniform float wind_strength : hint_range(0.0, 50.0) = 4.0;
uniform float wind_scale : hint_range(0.0, 1.0) = 0.05;

void vertex() {
	// Sway top vertices more than bottom vertices (UV.y ranges from 0.0 at top to 1.0 at bottom)
	float sway_factor = pow(1.0 - UV.y, 1.5);
	float offset = sin(TIME * wind_speed + (MODEL_MATRIX[3].x + MODEL_MATRIX[3].y) * wind_scale);
	VERTEX.x += offset * wind_strength * sway_factor;
}
