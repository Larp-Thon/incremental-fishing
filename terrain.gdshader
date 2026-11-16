shader_type spatial;
// Terreno: color por vértice y cáusticas que se apagan con la profundidad (solo se ven en la zona 1).

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	vec2 p = world.xz * 0.45;
	float c = sin(p.x + TIME * 0.8 + sin(p.y * 1.3 + TIME * 0.6)) * sin(p.y * 1.1 - TIME * 0.7 + sin(p.x * 0.9 - TIME * 0.4));
	EMISSION = vec3(0.45, 0.75, 0.8) * pow(abs(c), 4.0) * smoothstep(-34.0, -14.0, world.y) * step(world.y, 0.0) * 0.5;
}
