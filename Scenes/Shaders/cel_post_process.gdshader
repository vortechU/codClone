shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float color_bands : hint_range(2.0, 8.0) = 5.0;
uniform float contrast_boost : hint_range(0.5, 2.5) = 1.0;
uniform float saturation_boost : hint_range(0.0, 2.0) = 1.05;
uniform float edge_threshold : hint_range(0.0, 0.35) = 0.17;
uniform float edge_softness : hint_range(0.001, 0.2) = 0.08;
uniform float color_edge_strength : hint_range(0.0, 4.0) = 1.05;
uniform vec4 outline_color : source_color = vec4(0.04, 0.04, 0.04, 0.58);

float luminance(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 apply_saturation(vec3 c, float amount) {
	float grey = luminance(c);
	return mix(vec3(grey), c, amount);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;

	vec4 src = texture(screen_texture, uv);
	vec3 graded = apply_saturation(src.rgb, saturation_boost);
	graded = clamp((graded - 0.5) * contrast_boost + 0.5, 0.0, 1.0);

	float bands = max(color_bands, 2.0);
	vec3 quantized = floor(graded * bands) / (bands - 1.0);
	float center_luma = luminance(src.rgb);

	float l_l = luminance(texture(screen_texture, uv - vec2(px.x, 0.0)).rgb);
	float l_r = luminance(texture(screen_texture, uv + vec2(px.x, 0.0)).rgb);
	float l_u = luminance(texture(screen_texture, uv - vec2(0.0, px.y)).rgb);
	float l_d = luminance(texture(screen_texture, uv + vec2(0.0, px.y)).rgb);
	float l_ul = luminance(texture(screen_texture, uv - px).rgb);
	float l_ur = luminance(texture(screen_texture, uv + vec2(px.x, -px.y)).rgb);
	float l_dl = luminance(texture(screen_texture, uv + vec2(-px.x, px.y)).rgb);
	float l_dr = luminance(texture(screen_texture, uv + px).rgb);

	float grad_x = (l_ur + 2.0 * l_r + l_dr) - (l_ul + 2.0 * l_l + l_dl);
	float grad_y = (l_dl + 2.0 * l_d + l_dr) - (l_ul + 2.0 * l_u + l_ur);
	float color_edge = sqrt(grad_x * grad_x + grad_y * grad_y);

	float shadow_suppression = mix(0.35, 1.0, smoothstep(0.14, 0.70, center_luma));
	float edge_metric = color_edge * color_edge_strength * shadow_suppression;
	float edge = smoothstep(edge_threshold, edge_threshold + edge_softness, edge_metric);

	vec3 final_rgb = mix(quantized, outline_color.rgb, edge * outline_color.a);
	COLOR = vec4(final_rgb, src.a);
}
