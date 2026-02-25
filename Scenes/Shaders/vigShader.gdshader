shader_type canvas_item;

uniform float vignette_intensity = 0.4;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.5;
uniform vec4 vignette_rgb : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	float color = distance(vec2(0.5, 0.5), UV) * vignette_intensity;
	COLOR = vec4(vignette_rgb.rgb, color * vignette_opacity);
}