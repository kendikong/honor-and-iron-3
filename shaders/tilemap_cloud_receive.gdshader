shader_type canvas_item;

// Cloud receive for TileMapLayer (trees / overlay props).

#include "res://shaders/cloud_shadow_field.gdshaderinc"

uniform float enable_cloud_shadows = 0.0;
uniform vec2 cloud_drift_offset = vec2(0.0);
uniform vec4 cloud_shadow_tint : source_color = vec4(0.75, 0.73, 0.82, 1.0);
uniform float cloud_shadow_strength : hint_range(0.0, 1.0) = 0.72;
uniform float cloud_scale_tiles = 32.0;
uniform float cloud_mask_low = 0.49;
uniform float cloud_mask_high = 0.55;
uniform float cloud_mask_steps = 8.0;
uniform float cloud_shape_mix = 0.62;
uniform float cloud_shape_scale = 1.73;
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
	if (enable_cloud_shadows >= 0.5) {
		vec2 snapped = floor(v_map_local);
		float field = cloud_field_at_pixel(
			snapped,
			cloud_drift_offset,
			tile_px,
			cloud_scale_tiles,
			cloud_shape_mix,
			cloud_shape_scale
		);
		float mask = cloud_shadow_mask(field, cloud_mask_low, cloud_mask_high, cloud_mask_steps);
		float shade = mask * cloud_shadow_strength;
		if (shade >= 0.01) {
			COLOR.rgb *= mix(vec3(1.0), cloud_shadow_tint.rgb, shade);
		}
	}
}
