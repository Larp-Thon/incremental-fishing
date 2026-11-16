shader_type canvas_item;
// Marco del casco de buzo: visor redondeado, aro metálico y panel de instrumentos abajo.

uniform vec3 rim_color : source_color = vec3(0.8, 0.6, 0.25);

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
	COLOR = vec4(col, max(max(body, rim), shade));
}
