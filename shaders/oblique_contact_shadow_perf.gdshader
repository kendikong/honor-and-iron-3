shader_type canvas_item;
render_mode blend_mul, unshaded;

// Perf experiment — linear sampling, hard masks (no pixel-grid mandate).
uniform vec4 shadow_tint : source_color = vec4(0.74, 0.72, 0.80, 1.0);
uniform float shadow_strength : hint_range(0.0, 1.0) = 1.0;

const float ALPHA_CUTOFF = 0.04;

void fragment() {
	float mask = texture(TEXTURE, UV).a;
	if (mask < ALPHA_CUTOFF) {
		discard;
	}
	vec3 tint = mix(vec3(1.0), shadow_tint.rgb, shadow_strength);
	COLOR = vec4(tint, 1.0);
}
