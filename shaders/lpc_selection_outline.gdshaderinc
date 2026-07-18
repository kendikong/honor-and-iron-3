// Shared selection outline uniforms + helpers (include from LPC sprite shaders).

uniform float selection_active : hint_range(0.0, 1.0) = 0.0;
uniform vec4 selection_color : source_color = vec4(0.36, 0.62, 0.92, 1.0);
uniform float selection_inner_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float selection_outer_alpha : hint_range(0.0, 1.0) = 0.42;
uniform int selection_inner_px : hint_range(1, 4) = 2;
uniform int selection_outer_px : hint_range(1, 4) = 4;

float lpc_neighbor_tex_alpha(sampler2D tex, vec2 uv, vec2 texel_size, float px) {
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

vec4 lpc_selection_outline(sampler2D tex, vec2 uv, vec2 texel_size, vec4 sprite_color) {
	if (selection_active < 0.5) {
		return sprite_color;
	}
	if (sprite_color.a > 0.01) {
		return sprite_color;
	}
	float inner_a = lpc_neighbor_tex_alpha(tex, uv, texel_size, float(selection_inner_px));
	if (inner_a > 0.08) {
		return vec4(selection_color.rgb, selection_color.a * selection_inner_alpha);
	}
	float outer_a = lpc_neighbor_tex_alpha(tex, uv, texel_size, float(selection_outer_px));
	if (outer_a > 0.08) {
		return vec4(selection_color.rgb, selection_color.a * selection_outer_alpha);
	}
	return vec4(0.0);
}
