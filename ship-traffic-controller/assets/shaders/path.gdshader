shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Course line: flowing chevrons (">>>") in the ship's port colour with a soft glow.
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.95);
uniform float spacing = 0.5;
uniform float speed = 0.9;

void fragment() {
	float across = UV.y * 2.0 - 1.0;
	float along = fract(UV.x / spacing - TIME * speed);
	float chevron = abs(along - 0.5 + abs(across) * 0.35);
	float arrow = 1.0 - smoothstep(0.1, 0.18, chevron);
	float glow = (1.0 - smoothstep(0.2, 1.0, abs(across))) * 0.28;
	ALBEDO = mix(color.rgb, vec3(1.0), arrow * 0.35);
	ALPHA = color.a * max(arrow, glow);
}
