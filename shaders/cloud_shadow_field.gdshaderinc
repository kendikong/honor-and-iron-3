// Shared cloud shadow field — used by ground_shadow_composite.gdshader (single resolve pass).

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

float cloud_blob_field(vec2 p) {
	float a = cloud_fbm(p);
	float b = cloud_fbm(p * 1.73 + vec2(4.7, 2.1));
	return a * 0.62 + b * 0.38;
}

float cloud_field_at_pixel(vec2 map_local, vec2 drift_time, float tile_px) {
	vec2 p = map_local / (tile_px * 32.0);
	vec2 uv = vec2(0.86 * p.x - 0.51 * p.y, 0.51 * p.x + 0.86 * p.y) + drift_time;
	return cloud_blob_field(uv);
}

float cloud_shadow_mask(float field) {
	float s = smoothstep(0.58, 0.60, field);
	return round(s * 8.0) / 8.0;
}
