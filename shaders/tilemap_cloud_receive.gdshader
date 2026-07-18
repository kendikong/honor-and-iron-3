shader_type canvas_item;

// Cloud receive for TileMapLayer (trees / overlay props) when wind shader is off.

#include "res://shaders/environment_cloud_receive.gdshaderinc"

uniform vec2 map_origin_px = vec2(0.0);
uniform float map_scale = 1.0;
uniform float tile_px = 16.0;

varying vec2 v_map_local;

void vertex() {
	vec2 world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	v_map_local = (world_px - map_origin_px) / max(map_scale, 0.001);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.01) {
		discard;
	}
	COLOR = tex;
	COLOR.rgb = apply_environment_cloud_receive_rgb(COLOR.rgb, v_map_local);
}
