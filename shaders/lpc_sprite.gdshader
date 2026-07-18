shader_type canvas_item;

#include "res://shaders/lpc_selection_outline.gdshaderinc"

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec4 out_col = lpc_selection_outline(TEXTURE, UV, TEXTURE_PIXEL_SIZE, col);
	COLOR = out_col * COLOR;
}
