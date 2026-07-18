shader_type canvas_item;
render_mode blend_mix;

uniform vec4 outline_color : source_color = vec4(0.36, 0.62, 0.92, 1.0);
uniform float outline_alpha : hint_range(0.0, 1.0) = 1.0;
uniform int outline_px : hint_range(1, 3) = 2;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (col.a > 0.01) {
		COLOR = vec4(0.0);
		return;
	}
	vec2 ps = TEXTURE_PIXEL_SIZE * float(outline_px);
	float max_a = 0.0;
	max_a = max(max_a, texture(TEXTURE, UV + vec2(ps.x, 0.0)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2(-ps.x, 0.0)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2(0.0, ps.y)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2(0.0, -ps.y)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2(ps.x, ps.y)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2(-ps.x, ps.y)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2(ps.x, -ps.y)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2(-ps.x, -ps.y)).a);
	if (max_a > 0.08) {
		COLOR = vec4(outline_color.rgb, outline_color.a * outline_alpha);
	} else {
		COLOR = vec4(0.0);
	}
}
