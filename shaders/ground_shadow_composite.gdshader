shader_type canvas_item;
render_mode blend_mul, unshaded;

// Unified ground shadow resolve: max(static map oblique, unit feet slots, cloud FBM) → one multiply.
// Sprite2D quad — VERTEX is map-root local pixel (0..map_size_px), same space as CPU sampling.

#include "res://shaders/cloud_shadow_field.gdshaderinc"

const int MAX_UNIT_FEET = 16;

uniform vec2 map_size_px = vec2(256.0);
uniform float tile_px = 16.0;

uniform sampler2D map_oblique_tex : filter_nearest, repeat_disable;
uniform vec2 map_oblique_origin = vec2(0.0);
uniform vec2 map_oblique_size = vec2(1.0);
uniform float has_map_oblique = 0.0;

uniform int unit_feet_count = 0;
uniform vec4 unit_feet_rect[MAX_UNIT_FEET];
uniform sampler2D unit_feet_slots[MAX_UNIT_FEET] : filter_nearest, repeat_disable;

uniform vec2 cloud_drift_offset = vec2(0.0);
uniform float enable_cloud_shadows = 0.0;

uniform vec4 shadow_tint : source_color = vec4(0.74, 0.72, 0.80, 1.0);
uniform float shadow_strength : hint_range(0.0, 1.0) = 1.0;
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

varying vec2 v_map_local;

void vertex() {
	vec2 world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	v_map_local = (world_px - map_origin_px) / max(map_scale, 0.001);
}

float sample_channel_alpha(
	sampler2D tex,
	vec2 map_local,
	vec2 channel_origin,
	vec2 channel_size,
	float channel_active
) {
	if (channel_active < 0.5) {
		return 0.0;
	}
	vec2 local = map_local - channel_origin;
	if (local.x < 0.0 || local.y < 0.0 || local.x >= channel_size.x || local.y >= channel_size.y) {
		return 0.0;
	}
	vec2 channel_uv = local / channel_size;
	return texture(tex, channel_uv).a;
}

float sample_unit_feet_at(vec2 map_local) {
	float a = 0.0;
	for (int i = 0; i < MAX_UNIT_FEET; i++) {
		if (i >= unit_feet_count) {
			break;
		}
		vec4 rect = unit_feet_rect[i];
		vec2 local = map_local - rect.xy;
		if (local.x < 0.0 || local.y < 0.0 || local.x >= rect.z || local.y >= rect.w) {
			continue;
		}
		vec2 uv = local / rect.zw;
		a = max(a, texture(unit_feet_slots[i], uv).a);
	}
	return a;
}

void fragment() {
	vec2 map_local = floor(v_map_local);

	float static_a = sample_channel_alpha(
		map_oblique_tex, map_local, map_oblique_origin, map_oblique_size, has_map_oblique
	);
	float feet_a = sample_unit_feet_at(map_local);

	float static_shade = static_a * shadow_strength;
	float feet_shade = feet_a * shadow_strength;

	float cloud_shade = 0.0;
	if (enable_cloud_shadows > 0.5) {
		float field = cloud_field_at_pixel(
			map_local,
			cloud_drift_offset,
			tile_px,
			cloud_scale_tiles,
			cloud_shape_mix,
			cloud_shape_scale
		);
		float cloud_mask = cloud_shadow_mask(
			field, cloud_mask_low, cloud_mask_high, cloud_mask_steps
		);
		cloud_shade = cloud_mask * cloud_shadow_strength;
	}

	float shade = max(max(static_shade, feet_shade), cloud_shade);
	if (shade < 0.01) {
		discard;
	}

	vec3 tint_rgb = shadow_tint.rgb;
	if (cloud_shade >= static_shade && cloud_shade >= feet_shade && cloud_shade > 0.001) {
		tint_rgb = cloud_shadow_tint.rgb;
	}
	vec3 darken = mix(vec3(1.0), tint_rgb, shade);
	COLOR = vec4(darken, 1.0);
}
