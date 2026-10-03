shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D dist_tex : filter_linear, repeat_disable;
uniform vec4 grid_rect = vec4(-24.0, -15.0, 48.0, 30.0);
uniform float max_dist = 8.0;
uniform vec3 shallow_color : source_color = vec3(0.36, 0.86, 0.80);
uniform vec3 mid_color : source_color = vec3(0.09, 0.62, 0.72);
uniform vec3 deep_color : source_color = vec3(0.04, 0.33, 0.52);
uniform vec3 foam_color : source_color = vec3(1.0);
uniform vec2 current = vec2(0.0);
uniform float fog = 0.0;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Worley-style cellular value: bright thin lines where cells meet.
float caustic(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + 17.3));
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return 1.0 - clamp((d2 - d1) * 2.2, 0.0, 1.0);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 uv = (p - grid_rect.xy) / grid_rect.zw;
	float n = noise(p * 0.35 + TIME * 0.05) * 0.6 + noise(p * 1.3 - TIME * 0.08) * 0.4;
	float d = texture(dist_tex, uv).r * max_dist + (n - 0.5) * 0.3;

	vec3 col = mix(shallow_color, mid_color, smoothstep(0.0, 0.9, d));
	col = mix(col, deep_color, smoothstep(0.9, 4.0, d));
	col *= 0.95 + 0.08 * noise(p * 0.12 + TIME * 0.02);

	// Sunlit caustics in shallow water (two drifting cellular layers).
	float caus = caustic(p * 0.9 + vec2(TIME * 0.05, TIME * 0.03)) * caustic(p * 1.3 - vec2(TIME * 0.04, -TIME * 0.06));
	caus = smoothstep(0.6, 0.95, caus) * (1.0 - smoothstep(0.3, 2.6, d)) * 0.5;

	// Foamy surf: broken, noisy band hugging the beach.
	float surf_n = noise(p * 3.0 + vec2(TIME * 0.4, -TIME * 0.3));
	float foam = (1.0 - smoothstep(0.03, 0.2 + surf_n * 0.25, d)) * (0.7 + 0.3 * surf_n);
	float surf2 = smoothstep(0.62, 0.8, surf_n) * (1.0 - smoothstep(0.3, 0.9, d)) * 0.6;
	foam = max(foam, surf2);

	// Current streaks.
	float streak = 0.0;
	float cl = length(current);
	if (cl > 0.01) {
		vec2 dir = current / cl;
		vec2 q = vec2(dot(p, dir), dot(p, vec2(-dir.y, dir.x)));
		float s = noise(vec2(q.x * 0.5 - TIME * cl * 2.0, q.y * 3.0));
		streak = smoothstep(0.8, 0.92, s) * 0.3;
	}

	// Sparkles.
	vec2 cell = floor(p * 2.5);
	float sp = hash(cell);
	float dotm = 1.0 - smoothstep(0.04, 0.1, length(fract(p * 2.5) - 0.5));
	float sparkle = step(0.965, sp) * dotm * (sin(TIME * 2.5 + sp * 50.0) * 0.5 + 0.5) * smoothstep(1.5, 4.0, d) * 0.55;

	col += vec3(0.9, 1.0, 0.95) * caus * 0.35;
	col = mix(col, foam_color, clamp(foam + streak + sparkle, 0.0, 1.0));
	col = mix(col, vec3(0.92, 0.96, 1.0), fog * 0.25);
	ALBEDO = col;
}
