shader_type canvas_item;
render_mode blend_mix;

uniform vec4 outline_color : source_color = vec4(0.36, 0.62, 0.92, 1.0);
uniform float inner_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float outer_alpha : hint_range(0.0, 1.0) = 0.42;
uniform int inner_px : hint_range(1, 4) = 2;
uniform int outer_px : hint_range(1, 4) = 4;

float _neighbor_max_alpha(sampler2D tex, vec2 uv, vec2 texel_size, float px) {
	vec2 ps = texel_size * px;
	float max_a = 0.0;
	max_a = max(max_a, texture(tex, uv + vec2(ps.x, 0.0)).a);
	max_a = max(max_a, texture(tex, uv + vec2(-ps.x, 0.0)).a);
	max_a = max(max_a, texture(tex, uv + vec2(0.0, ps.y)).a);
	max_a = max(max_a, texture(tex, uv + vec2(0.0, -ps.y)).a);
	max_a = max(max_a, texture(tex, uv + vec2(ps.x, ps.y)).a);
	max_a = max(max_a, texture(tex, uv + vec2(-ps.x, ps.y)).a);
	max_a = max(max_a, texture(tex, uv + vec2(ps.x, -ps.y)).a);
	max_a = max(max_a, texture(tex, uv + vec2(-ps.x, -ps.y)).a);
	return max_a;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (col.a > 0.01) {
		COLOR = vec4(0.0);
	} else {
		float inner_a = _neighbor_max_alpha(TEXTURE, UV, TEXTURE_PIXEL_SIZE, float(inner_px));
		if (inner_a > 0.08) {
			COLOR = vec4(outline_color.rgb, outline_color.a * inner_alpha);
		} else {
			float outer_a = _neighbor_max_alpha(TEXTURE, UV, TEXTURE_PIXEL_SIZE, float(outer_px));
			if (outer_a > 0.08) {
				COLOR = vec4(outline_color.rgb, outline_color.a * outer_alpha);
			} else {
				COLOR = vec4(0.0);
			}
		}
	}
}
