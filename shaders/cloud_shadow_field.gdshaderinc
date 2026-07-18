// Shared cloud shadow field — functions only (uniforms live in parent .gdshader files).

vec2 cloud_hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float cloud_value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	float n00 = dot(cloud_hash22(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0));
	float n10 = dot(cloud_hash22(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float n01 = dot(cloud_hash22(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float n11 = dot(cloud_hash22(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));

	return mix(mix(n00, n10, u.x), mix(n01, n11, u.x), u.y) + 0.5;
}

float cloud_fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < 4; i++) {
		v += cloud_value_noise(p) * a;
		p = rot * p * 2.05;
		a *= 0.5;
	}
	return v;
}

float cloud_blob_field(vec2 p, float shape_mix, float shape_scale) {
	float a = cloud_fbm(p);
	float b = cloud_fbm(p * shape_scale + vec2(4.7, 2.1));
	float mix_b = 1.0 - shape_mix;
	return a * shape_mix + b * mix_b;
}

float cloud_field_at_pixel(
	vec2 map_local,
	vec2 drift_time,
	float tile_px,
	float scale_tiles,
	float shape_mix,
	float shape_scale
) {
	vec2 p = map_local / (tile_px * max(scale_tiles, 1.0));
	vec2 uv = vec2(0.86 * p.x - 0.51 * p.y, 0.51 * p.x + 0.86 * p.y) + drift_time;
	return cloud_blob_field(uv, shape_mix, shape_scale);
}

float cloud_shadow_mask(float field, float mask_low, float mask_high, float mask_steps) {
	float lo = min(mask_low, mask_high - 0.001);
	float hi = max(mask_high, lo + 0.001);
	float s = smoothstep(lo, hi, field);
	float steps = max(mask_steps, 1.0);
	return round(s * steps) / steps;
}
