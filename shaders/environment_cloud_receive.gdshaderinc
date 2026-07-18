// Per-pixel cloud darken on tile/sprite RGB — not a multiply stack (tint lerp on albedo).

#include "res://shaders/cloud_shadow_field.gdshaderinc"

uniform float enable_cloud_shadows = 0.0;
uniform vec2 cloud_drift_offset = vec2(0.0);
uniform vec4 cloud_shadow_tint : source_color = vec4(0.75, 0.73, 0.82, 1.0);
uniform float cloud_shadow_strength : hint_range(0.0, 1.0) = 0.72;

vec3 apply_environment_cloud_receive_rgb(vec3 base_rgb, vec2 map_local_px) {
	if (enable_cloud_shadows < 0.5) {
		return base_rgb;
	}
	vec2 snapped = floor(map_local_px);
	float field = cloud_field_at_pixel(snapped, cloud_drift_offset, tile_px);
	float mask = cloud_shadow_mask(field);
	float shade = mask * cloud_shadow_strength;
	if (shade < 0.01) {
		return base_rgb;
	}
	return mix(base_rgb, cloud_shadow_tint.rgb, shade);
}
