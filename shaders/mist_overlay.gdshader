shader_type canvas_item;

// Dithered mist + vertical light shafts near ruins/trees — stepped, no soft blur.

uniform vec2 map_origin_px = vec2(0.0);
uniform vec2 map_size_px = vec2(256.0);
uniform vec2 map_size_cells = vec2(16.0);
uniform float map_scale = 1.0;
uniform float tile_px = 16.0;
uniform float mist_density = 0.12;
uniform float humidity = 0.0;
uniform float ruin_ratio = 0.0;
uniform sampler2D participation_tex : filter_nearest, repeat_disable;
uniform float has_participation = 0.0;

float bayer4(vec2 p) {
	int x = int(mod(floor(p.x), 4.0));
	int y = int(mod(floor(p.y), 4.0));
	const float m[16] = float[16](
		0.0, 8.0, 2.0, 10.0,
		12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0,
		15.0, 7.0, 13.0, 5.0
	);
	return m[y * 4 + x] / 16.0;
}

float _shaft_jitter(vec2 cell) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 map_local = UV * map_size_px;
	vec2 cell = floor(map_local / tile_px);

	float participate = 0.25;
	if (has_participation > 0.5) {
		vec2 uv = (cell + vec2(0.5)) / map_size_cells;
		if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
			participate = texture(participation_tex, uv).r;
		}
	}

	float stepped = floor(TIME * 3.0) / 3.0;
	float shaft_phase = fract(map_local.x / (tile_px * 6.7) + stepped * 0.23 + _shaft_jitter(cell) * 0.18);
	float shaft = smoothstep(0.52, 0.78, shaft_phase) * participate * 0.35;

	float mist_base = mist_density * (0.35 + participate * 0.65);
	float dither = bayer4(map_local);
	float mist = smoothstep(dither - 0.12, dither + 0.12, mist_base + humidity * 0.08);

	vec3 mist_rgb = vec3(0.88, 0.92, 0.98);
	vec3 shaft_rgb = vec3(1.04, 1.02, 0.94);
	float alpha = clamp(mist * 0.22 + shaft * 0.12, 0.0, 0.38);
	vec3 rgb = mix(mist_rgb, shaft_rgb, shaft * 0.6);
	COLOR = vec4(rgb, alpha);
}
