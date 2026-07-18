shader_type canvas_item;
render_mode blend_mul, unshaded;

// Moving cloud blobs — multiply only where mask > 0 (discard elsewhere = no map grade).

uniform vec2 map_size_px = vec2(256.0);
uniform vec2 cloud_drift_offset = vec2(0.0);
uniform float tile_px = 16.0;
uniform vec4 shadow_tint : source_color = vec4(0.75, 0.73, 0.82, 1.0);
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.72;

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

float field_at_pixel(vec2 map_local, vec2 drift_time) {
	// Scale up significantly (32 tiles instead of 9.5) for large, sweeping cloud banks
	vec2 p = map_local / (tile_px * 32.0);
	vec2 uv = vec2(0.86 * p.x - 0.51 * p.y, 0.51 * p.x + 0.86 * p.y) + drift_time;
	return blob_field(uv);
}

float shadow_mask(float field) {
	// Quantize to pixel depth for pixel art consistency.
	// Step is 0.58 to 0.60 to make edges sharper than before (was 0.56 to 0.60).
	float s = smoothstep(0.52, 0.58, field);
	return round(s * 8.0) / 8.0;
}

void fragment() {
	// Quantize to pixel grid to avoid sub-pixel motion smearing (Architect rule §5)
	vec2 map_local = floor(UV * map_size_px);
	float field = field_at_pixel(map_local, cloud_drift_offset);
	float mask = shadow_mask(field);
	float shade = shadow_strength * mask;
	
	// Skip draw entirely outside blobs — blend_mul must not touch clear sky pixels.
	if (shade < 0.01) {
		discard;
	}
	vec3 darken = mix(vec3(1.0), shadow_tint.rgb, shade);

	COLOR = vec4(darken, 1.0);
}
