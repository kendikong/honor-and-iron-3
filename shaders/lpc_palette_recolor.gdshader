shader_type canvas_item;

#include "res://shaders/lpc_shadow_receive.gdshaderinc"

// ULPC palette swap — tolerance matches chargen WebGL (~1/255 per channel).
uniform vec4 source_colors[8];
uniform vec4 target_colors[8];
uniform int pair_count = 0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec4 out_col = col;
	if (col.a >= 0.01 && pair_count > 0) {
		for (int i = 0; i < 8; i++) {
			if (i >= pair_count) {
				break;
			}
			vec3 diff = abs(col.rgb - source_colors[i].rgb);
			if (diff.r < 0.004 && diff.g < 0.004 && diff.b < 0.004) {
				out_col = vec4(target_colors[i].rgb, col.a);
				break;
			}
		}
	}
	vec2 map_local = lpc_sprite_map_local(UV, TEXTURE_PIXEL_SIZE);
	out_col = lpc_apply_shadow_receive(out_col, map_local);
	COLOR = out_col * COLOR;
}
