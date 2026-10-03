shader_type canvas_item;

uniform float strength = 1.0;

void fragment() {
	vec2 c = abs(UV - 0.5) * 2.0;
	float e = max(smoothstep(0.55, 1.0, c.x), smoothstep(0.45, 1.0, c.y));
	float n = sin(UV.x * 9.0 + TIME * 0.4) * sin(UV.y * 7.0 - TIME * 0.3) * 0.08;
	COLOR = vec4(0.94, 0.97, 1.0, clamp(e + n, 0.0, 1.0) * 0.85 * strength);
}
