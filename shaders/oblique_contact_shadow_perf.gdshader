shader_type canvas_item;
render_mode blend_mul, unshaded;

// Perf experiment — linear sampling, hard masks (no pixel-grid mandate).
uniform vec4 shadow_tint : source_color = vec4(0.74, 0.72, 0.80, 1.0);
uniform float shadow_strength : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D map_oblique_tex : filter_linear, repeat_disable;
uniform vec2 map_oblique_origin = vec2(0.0);
uniform vec2 map_oblique_size = vec2(1.0);
uniform float has_map_oblique = 0.0;
uniform vec2 sprite_map_origin = vec2(0.0);
uniform vec2 sprite_scale = vec2(1.0);

const float ALPHA_CUTOFF = 0.04;

uniform float has_cloud_shadow = 0.0;
uniform vec2 cloud_drift_offset = vec2(0.0);

vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	float n00 = dot(hash22(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0));
	float n10 = dot(hash22(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float n01 = dot(hash22(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float n11 = dot(hash22(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));

	return mix(mix(n00, n10, u.x), mix(n01, n11, u.x), u.y) + 0.5;
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	// Rotate space at each octave to break up the value noise grid artifacts
	mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < 4; i++) {
		v += value_noise(p) * a;
		p = rot * p * 2.05;
		a *= 0.5;
	}
	return v;
}

float blob_field(vec2 p) {
	float a = fbm(p);
	float b = fbm(p * 1.73 + vec2(4.7, 2.1));
	return a * 0.62 + b * 0.38;
}

float shadow_mask(float field) {
	return smoothstep(0.58, 0.60, field);
}


void fragment() {
	float mask = texture(TEXTURE, UV).a;
	if (mask < ALPHA_CUTOFF) {
		discard;
	}
	
	vec3 tint = mix(vec3(1.0), shadow_tint.rgb, shadow_strength);
	
	if (has_map_oblique > 0.5) {
		vec2 map_local = sprite_map_origin + (UV / TEXTURE_PIXEL_SIZE) * sprite_scale;
		vec2 oblique_local = map_local - map_oblique_origin;
		if (
			oblique_local.x >= 0.0
			&& oblique_local.y >= 0.0
			&& oblique_local.x < map_oblique_size.x
			&& oblique_local.y < map_oblique_size.y
		) {
			vec2 oblique_uv = oblique_local / map_oblique_size;
			float oblique_a = texture(map_oblique_tex, oblique_uv).a;
			float yield_map = smoothstep(ALPHA_CUTOFF, 0.16, oblique_a);
			tint = mix(tint, vec3(1.0), yield_map);
		}
	}
	if (has_cloud_shadow > 0.5) {
		vec2 map_local = sprite_map_origin + (UV / TEXTURE_PIXEL_SIZE) * sprite_scale;
		// Perf: no floor/quantization on map_local
		// Scale up significantly (32 tiles instead of 9.5) for large, sweeping cloud banks
		vec2 p = map_local / (16.0 * 32.0); // tile_px = 16.0
		vec2 drift_uv = vec2(0.86 * p.x - 0.51 * p.y, 0.51 * p.x + 0.86 * p.y) + cloud_drift_offset;
		float field = blob_field(drift_uv);
		float cloud_mask = shadow_mask(field);
		if (cloud_mask > 0.01) {
			tint = vec3(1.0);
		}
	}

	COLOR = vec4(tint, 1.0);
}
