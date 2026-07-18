// Map oblique shadow receive for LPC layers.
// Global uniforms: set once per shared recolor material (LpcPaletteStore).
// Instance uniforms: per AnimatedSprite2D layer — never stomp palette params on shared materials.
uniform sampler2D map_oblique_tex : filter_nearest, repeat_disable;
uniform vec2 map_oblique_origin = vec2(0.0);
uniform vec2 map_oblique_size = vec2(1.0);
uniform vec4 shadow_tint : source_color = vec4(0.74, 0.72, 0.80, 1.0);
uniform float shadow_strength : hint_range(0.0, 1.0) = 1.0;
uniform float lpc_shadow_global = 0.0;
uniform float has_map_oblique = 0.0;

// Map pixel position at the sprite center (AnimatedSprite2D local origin).
instance uniform float lpc_shadow_enabled = 0.0;
instance uniform vec2 sprite_map_origin = vec2(0.0);
instance uniform vec2 sprite_scale = vec2(1.0);

varying vec2 lpc_v_map_local;

const float LPC_SHADOW_ALPHA_CUTOFF = 0.04;

void lpc_shadow_vertex() {
	// VERTEX is local draw space — stable across atlas frame changes; do not use UV.
	lpc_v_map_local = sprite_map_origin + VERTEX * sprite_scale;
}

vec3 lpc_shadow_darken(vec2 map_local_px) {
	if (lpc_shadow_global < 0.5 || lpc_shadow_enabled < 0.5) {
		return vec3(1.0);
	}
	vec3 tint = vec3(1.0);
	if (has_map_oblique > 0.5) {
		vec2 oblique_local = map_local_px - map_oblique_origin;
		if (
			oblique_local.x >= 0.0
			&& oblique_local.y >= 0.0
			&& oblique_local.x < map_oblique_size.x
			&& oblique_local.y < map_oblique_size.y
		) {
			vec2 oblique_uv = oblique_local / map_oblique_size;
			float oblique_a = texture(map_oblique_tex, oblique_uv).a;
			if (oblique_a >= LPC_SHADOW_ALPHA_CUTOFF) {
				tint = mix(vec3(1.0), shadow_tint.rgb, shadow_strength);
			}
		}
	}
	return tint;
}

vec4 lpc_apply_shadow_receive(vec4 col, vec2 map_local_px) {
	col.rgb *= lpc_shadow_darken(map_local_px);
	return col;
}

vec2 lpc_fragment_map_local() {
	return floor(lpc_v_map_local);
}
