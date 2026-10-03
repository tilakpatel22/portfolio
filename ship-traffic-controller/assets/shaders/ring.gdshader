shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float thickness = 0.14;
uniform float fill = 0.16;
uniform float pulse_speed = 0.0;

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float pulse = pulse_speed > 0.0 ? 0.75 + 0.25 * sin(TIME * pulse_speed) : 1.0;
	float ring = smoothstep(1.0 - thickness - 0.05, 1.0 - thickness, r) * (1.0 - smoothstep(0.95, 1.0, r));
	float inner = (1.0 - smoothstep(0.2, 1.0 - thickness, r)) * fill;
	ALBEDO = color.rgb;
	ALPHA = max(ring, inner) * color.a * pulse;
}
