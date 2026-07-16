shader_type canvas_item;

// OverlayLayer TREE stubs — whole-sprite integer shift, slower stepped clock (~5 fps).

uniform vec2 wind_dir = vec2(1.0, 0.0);
uniform float wind_turbulence = 0.0;
uniform float gust_strength = 0.0;
uniform float gust_front = 0.0;
uniform float gust_band_px = 48.0;
uniform vec2 map_origin_px = vec2(0.0);
uniform vec2 map_size_cells = vec2(16.0);
uniform float tile_px = 16.0;
uniform float map_scale = 1.0;
uniform sampler2D participation_tex : filter_nearest, repeat_disable;
uniform float has_participation = 0.0;

float cell_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(269.5, 183.3))) * 43758.5453);
}

void vertex() {
	vec2 world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vec2 map_local = (world_px - map_origin_px) / max(map_scale, 0.001);
	vec2 cell = floor(map_local / tile_px);
	float stepped = floor(TIME * 5.0) / 5.0;

	float participate = 0.0;
	if (has_participation > 0.5) {
		vec2 uv = (cell + vec2(0.5)) / map_size_cells;
		if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
			participate = texture(participation_tex, uv).r;
		}
	}

	vec2 dir = normalize(wind_dir + vec2(0.0001, 0.0));
	float along = dot(map_local, dir);
	float dist = abs(along - gust_front);
	float envelope = 1.0 - clamp(dist / gust_band_px, 0.0, 1.0);
	envelope *= envelope;

	float phase = cell_hash(cell);
	float sway = step(0.64, fract(stepped * 0.6 + phase));
	float amount = clamp(sway * wind_turbulence * 0.22 + envelope * gust_strength, 0.0, 1.0) * participate;

	float shift = round(amount);
	vec2 delta = vec2(round(shift * dir.x), round(shift * dir.y));
	VERTEX.xy += delta;
}

void fragment() {
	COLOR = texture(TEXTURE, UV);
}
