shader_type canvas_item;

// Combined GroundLayer — wind (GRASS/DIRT) + water ripples (WATER mask).

uniform vec2 wind_dir = vec2(1.0, 0.0);
uniform float wind_turbulence = 0.0;
uniform float gust_strength = 0.0;
uniform float gust_front = 0.0;
uniform float gust_band_px = 44.0;
uniform vec2 ripple_dir = vec2(1.0, 0.0);
uniform float ripple_multiplier = 1.0;
uniform float ripple_strength = 1.0;
uniform float enable_wind = 1.0;
uniform float enable_water = 1.0;
uniform vec2 map_origin_px = vec2(0.0);
uniform vec2 map_size_cells = vec2(16.0);
uniform float tile_px = 16.0;
uniform float map_scale = 1.0;
uniform sampler2D wind_participation_tex : filter_nearest, repeat_disable;
uniform sampler2D water_participation_tex : filter_nearest, repeat_disable;
uniform float has_wind_participation = 0.0;
uniform float has_water_participation = 0.0;

varying vec2 v_map_local;
varying float v_wind_participate;
varying float v_water_participate;

float cell_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec2 world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	v_map_local = (world_px - map_origin_px) / max(map_scale, 0.001);
	vec2 cell = floor(v_map_local / tile_px);
	v_wind_participate = 0.0;
	v_water_participate = 0.0;
	vec2 uv = (cell + vec2(0.5)) / map_size_cells;
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		if (has_wind_participation > 0.5) {
			v_wind_participate = texture(wind_participation_tex, uv).r;
		}
		if (has_water_participation > 0.5) {
			v_water_participate = texture(water_participation_tex, uv).r;
		}
	}

	vec2 delta = vec2(0.0);
	if (enable_wind > 0.5) {
		float stepped_w = floor(TIME * 6.0) / 6.0;
		vec2 dir = normalize(wind_dir + vec2(0.0001, 0.0));
		float along = dot(v_map_local, dir);
		float dist = abs(along - gust_front);
		float envelope = 1.0 - clamp(dist / gust_band_px, 0.0, 1.0);
		envelope *= envelope;
		float phase = cell_hash(cell);
		float osc = step(0.58, fract(stepped_w * 0.9 + phase));
		float ambient = osc * wind_turbulence;
		float amount = clamp(ambient * 0.5 + envelope * gust_strength, 0.0, 1.0) * v_wind_participate;
		float shift = round(amount);
		delta += vec2(round(shift * dir.x), round(shift * dir.y));
	}
	VERTEX.xy += delta;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (enable_water > 0.5 && v_water_participate >= 0.5) {
		float stepped = floor(TIME * 3.0);
		vec2 cell = floor(v_map_local / tile_px);
		float phase = mod(stepped + floor(cell_hash(cell) * 3.0), 3.0);
		vec3 tint = vec3(1.0);
		if (phase < 1.0) {
			tint = vec3(0.86, 0.95, 1.14);
		} else if (phase < 2.0) {
			tint = vec3(0.94, 0.99, 1.06);
		} else {
			tint = vec3(0.78, 0.9, 1.2);
		}
		float strength = clamp(v_water_participate * ripple_strength * ripple_multiplier, 0.0, 1.0);
		COLOR = vec4(mix(col.rgb, col.rgb * tint, strength), col.a);
	} else {
		COLOR = col;
	}
}
