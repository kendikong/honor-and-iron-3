shader_type canvas_item;
render_mode blend_mix;

// Tint GPU-baked cloud shade texture red for the J-key debug overlay.

uniform sampler2D shade_tex : filter_nearest, repeat_disable;
uniform float shade_gate = 0.01;
uniform vec4 tint_color : source_color = vec4(1.0, 0.12, 0.12, 0.58);

void fragment() {
	float shade = texture(shade_tex, UV).r;
	if (shade < shade_gate) {
		discard;
	}
	COLOR = tint_color;
}
