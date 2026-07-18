shader_type canvas_item;

// ULPC palette swap — tolerance ~2/255 per channel (chargen CPU uses 1/255).
uniform vec4 source_colors[12];
uniform vec4 target_colors[12];
uniform int pair_count = 0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec4 out_col = col;
	if (col.a >= 0.01 && pair_count > 0) {
		for (int i = 0; i < 12; i++) {
			if (i >= pair_count) {
				break;
			}
			vec3 diff = abs(col.rgb - source_colors[i].rgb);
			if (diff.r < 0.008 && diff.g < 0.008 && diff.b < 0.008) {
				out_col = vec4(target_colors[i].rgb, col.a);
				break;
			}
		}
	}
	COLOR = out_col * COLOR;
}
