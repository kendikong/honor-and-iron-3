shader_type canvas_item;

// Deep interior WATER — palette cycle only (no vertex shift; shore wang excluded via mask).

uniform vec2 ripple_dir = vec2(1.0, 0.0);
uniform float ripple_multiplier = 1.0;
uniform float ripple_strength = 1.0;
uniform vec2 map_origin_px = vec2(0.0);
uniform vec2 map_size_cells = vec2(16.0);
uniform float tile_px = 16.0;
uniform float map_scale = 1.0;
uniform sampler2D participation_tex : filter_nearest, repeat_disable;
uniform float has_participation = 0.0;

varying vec2 v_map_local;
varying float v_participate;

float cell_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec2 world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	v_map_local = (world_px - map_origin_px) / max(map_scale, 0.001);
	vec2 cell = floor(v_map_local / tile_px);
	v_participate = 0.0;
	if (has_participation > 0.5) {
		vec2 uv = (cell + vec2(0.5)) / map_size_cells;
		if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
			v_participate = texture(participation_tex, uv).r;
		}
	}
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (v_participate < 0.5) {
		COLOR = col;
	} else {
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
		float strength = clamp(v_participate * ripple_strength * ripple_multiplier, 0.0, 1.0);
		COLOR = vec4(mix(col.rgb, col.rgb * tint, strength), col.a);
	}
}
