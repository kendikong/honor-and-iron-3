shader_type canvas_item;
render_mode unshaded;

// Full-map cloud shade bake — one texel per map pixel; authoritative CPU readback for sprites/debug.

#include "res://shaders/cloud_shadow_field.gdshaderinc"

uniform vec2 map_size_px = vec2(512.0, 256.0);
uniform float tile_px = 16.0;
uniform vec2 cloud_drift_offset = vec2(0.0);
uniform float cloud_shadow_strength : hint_range(0.0, 1.0) = 0.72;
uniform float cloud_scale_tiles = 32.0;
uniform float cloud_mask_low = 0.49;
uniform float cloud_mask_high = 0.55;
uniform float cloud_mask_steps = 8.0;
uniform float cloud_shape_mix = 0.62;
uniform float cloud_shape_scale = 1.73;

void fragment() {
	vec2 map_local = floor(UV * map_size_px);
	float field = cloud_field_at_pixel(
		map_local,
		cloud_drift_offset,
		tile_px,
		cloud_scale_tiles,
		cloud_shape_mix,
		cloud_shape_scale
	);
	float mask = cloud_shadow_mask(field, cloud_mask_low, cloud_mask_high, cloud_mask_steps);
	float shade = mask * cloud_shadow_strength;
	COLOR = vec4(shade, shade, shade, 1.0);
}
