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

	// Gotas: una por celda de una rejilla, con tamaño y sitio al azar; resbalan mientras se secan.
	vec2 g = UV * vec2(18.0, 10.0);
	float r = fract(sin(dot(floor(g), vec2(12.9898, 78.233))) * 43758.5453);
	vec2 c = fract(g) - 0.5 + (vec2(r, fract(r * 7.0)) - 0.5) * 0.5;
	c.y -= (1.0 - wet) * r * 0.3;
	float drop = smoothstep(0.16 * r + 0.03, 0.0, length(c * vec2(1.0, 0.7))) * wet * step(0.45, r) * glass;
	col = mix(col, vec3(0.8, 0.92, 1.0), drop);
	a = max(a, drop * 0.45);

	COLOR = vec4(col, a);
}
