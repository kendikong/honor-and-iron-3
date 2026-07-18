shader_type canvas_item;

#include "res://shaders/lpc_shadow_receive.gdshaderinc"
#include "res://shaders/lpc_selection_outline.gdshaderinc"

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec4 out_col = lpc_selection_outline(TEXTURE, UV, TEXTURE_PIXEL_SIZE, col);
	vec2 map_local = lpc_sprite_map_local(UV, TEXTURE_PIXEL_SIZE);
	out_col = lpc_apply_shadow_receive(out_col, map_local);
	COLOR = out_col * COLOR;
}
