shader_type canvas_item;
// Marco del casco de buzo: visor redondeado, aro metálico y panel de instrumentos abajo.
// Sobre el cristal: viñeta roja de presión, vaho de la respiración y gotas al salir del agua.

uniform vec3 rim_color : source_color = vec3(0.8, 0.6, 0.25);
uniform float danger = 0.0;
uniform float haze = 0.0;
uniform float wet = 0.0;

void fragment() {
	// Abertura del visor: superelipse desplazada hacia arriba para dejar sitio al panel inferior.
	vec2 p = (UV - vec2(0.5, 0.45)) / vec2(0.485, 0.43);
	float d = pow(pow(abs(p.x), 5.0) + pow(abs(p.y), 5.0), 0.2);
	float body = smoothstep(1.0, 1.012, d);
	float rim = smoothstep(0.95, 0.962, d) - body;
	float shade = smoothstep(0.6, 0.96, d) * 0.4;  // el cristal se oscurece hacia el borde
	vec3 metal = rim_color * mix(1.15, 0.5, UV.y);  // luz desde arriba
	vec3 col = mix(vec3(0.0, 0.02, 0.04), metal, rim);
	col = mix(col, vec3(0.06, 0.07, 0.09), body);
	float a = max(max(body, rim), shade);
	float glass = 1.0 - max(body, rim);

	float vig = smoothstep(0.3, 1.0, d) * danger * glass;
	col = mix(col, vec3(0.9, 0.05, 0.05), vig);
	a = max(a, vig * 0.7);

	float fog = smoothstep(0.1, 1.0, p.y) * haze * glass;  // el vaho sube desde abajo
	col = mix(col, vec3(0.85, 0.9, 0.95), fog);
	a = max(a, fog * 0.5);

	// Gotas: caen por columnas a distinta velocidad, casi transparentes (borde y brillo), con un
	// rastro fino, y se desvanecen según se seca el visor (wet 1 -> 0).
	float fade = smoothstep(0.0, 0.5, wet) * glass;
	for (int layer = 0; layer < 2; layer++) {
		float cols = 22.0 + 9.0 * float(layer);
		float col_id = floor(UV.x * cols) + 37.0 * float(layer);
		float r = fract(sin(col_id * 12.9898) * 43758.5453);
		float v = UV.y * 4.0 - (1.0 - wet) * (1.5 + 3.5 * r) + r * 9.0;
		float r2 = fract(sin(dot(vec2(col_id, floor(v)), vec2(12.9898, 78.233))) * 43758.5453);
		vec2 l = vec2(fract(UV.x * cols) - 0.5 - (r2 - 0.5) * 0.4, fract(v) - 0.7);
		float rad = 0.1 + 0.14 * r2;
		vec2 q = vec2(l.x, l.y * cols / 4.0 * 0.5625 * 0.7);  // algo alargada en pantalla 16:9
		q.x *= 1.0 - clamp(q.y / rad, -1.0, 0.0) * 0.9;  // forma de lágrima: se estrecha por arriba
		float dist = length(q);
		float on = step(0.5, r2) * fade;
		float body_drop = smoothstep(rad, rad * 0.8, dist);
		float edge = body_drop * smoothstep(rad * 0.45, rad, dist);
		float spec = smoothstep(rad * 0.3, 0.0, length(q + vec2(0.3, 0.35) * rad));
		float trail = smoothstep(0.07, 0.0, abs(l.x)) * smoothstep(-0.6, 0.0, l.y) * step(l.y, 0.0);
		float drop_a = (body_drop * 0.09 + edge * 0.17 + spec * 0.6 + trail * 0.2) * on;
		col = mix(col, mix(vec3(0.75, 0.9, 1.0), vec3(1.0), spec), step(a, drop_a));
		a = max(a, drop_a);
	}

	COLOR = vec4(col, a);
}
