shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float columns : hint_range(32.0, 220.0) = 128.0;
uniform float rain_speed : hint_range(0.2, 4.5) = 2.2;
uniform float glitch_strength : hint_range(0.0, 0.2) = 0.08;
uniform float darkness : hint_range(0.0, 1.0) = 0.95;
uniform vec4 matrix_color : source_color = vec4(0.08, 0.95, 0.25, 1.0);
uniform float seed : hint_range(0.0, 64.0) = 17.0;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float binary_cell(vec2 cell_id, vec2 cell_uv, float flicker_tick) {
	float digit = step(0.5, hash21(cell_id + vec2(flicker_tick, seed)));
	float body = step(0.16, cell_uv.x) * step(cell_uv.x, 0.84) * step(0.10, cell_uv.y) * step(cell_uv.y, 0.90);

	float vertical = step(abs(cell_uv.x - 0.5), 0.09) * step(0.16, cell_uv.y) * step(cell_uv.y, 0.88);
	float top = step(0.76, cell_uv.y) * step(0.22, cell_uv.x) * step(cell_uv.x, 0.78);
	float mid = step(abs(cell_uv.y - 0.50), 0.07) * step(0.26, cell_uv.x) * step(cell_uv.x, 0.74);
	float bottom = step(0.24, 1.0 - cell_uv.y) * step(0.22, cell_uv.x) * step(cell_uv.x, 0.78);
	float one_shape = vertical;
	float zero_shape = top + mid + bottom + step(abs(cell_uv.x - 0.22), 0.06) * step(0.24, cell_uv.y) * step(cell_uv.y, 0.76) + step(abs(cell_uv.x - 0.78), 0.06) * step(0.24, cell_uv.y) * step(cell_uv.y, 0.76);

	float glyph = mix(zero_shape, one_shape, digit) * body;
	return clamp(glyph, 0.0, 1.0);
}

void fragment() {
	float clamped_progress = clamp(progress, 0.0, 1.0);
	if (clamped_progress <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec2 uv = UV;
		float time_tick = TIME * rain_speed;

		float glitch_row = floor(uv.y * 120.0 + time_tick * 9.0);
		float row_gate = step(0.79, hash11(glitch_row + seed));
		float jitter = (hash11(glitch_row + time_tick * 13.0 + seed * 2.7) - 0.5) * 2.0;
		uv.x = fract(uv.x + jitter * glitch_strength * clamped_progress * row_gate);

		vec2 grid = vec2(columns, floor(columns * 0.62));
		vec2 cell = floor(uv * grid);
		vec2 cell_uv = fract(uv * grid);

		float column_seed = hash11(cell.x + seed);
		float head = fract(column_seed * 8.0 + time_tick * (0.30 + column_seed * 1.45));
		float trail_length = mix(0.08, 0.34, column_seed);
		float dist = abs(uv.y - head);
		dist = min(dist, 1.0 - dist);
		float rain_mask = smoothstep(trail_length, 0.0, dist);

		float flicker_tick = floor(time_tick * 24.0 + column_seed * 40.0);
		float glyph = binary_cell(cell, cell_uv, flicker_tick) * rain_mask;
		float bloom = smoothstep(0.0, 0.15, rain_mask) * (0.35 + column_seed * 0.9);

		float wipe_noise = (hash21(vec2(floor(uv.x * columns), floor(time_tick * 8.0))) - 0.5) * 0.35;
		float wipe = smoothstep(clamped_progress - 0.52, clamped_progress + 0.12, uv.y + wipe_noise);

		float base_black_alpha = smoothstep(0.04, 0.9, clamped_progress) * darkness;
		float glyph_alpha = glyph * (0.45 + clamped_progress * 0.75) * wipe;
		float alpha = clamp(base_black_alpha + glyph_alpha, 0.0, 1.0);

		vec3 glyph_color = matrix_color.rgb * (glyph + bloom * 0.5) * wipe;
		vec3 rgb = mix(vec3(0.0), glyph_color, clamp(glyph + bloom, 0.0, 1.0));

		COLOR = vec4(rgb, alpha);
	}
}
