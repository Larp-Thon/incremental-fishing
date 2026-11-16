shader_type spatial;
render_mode cull_disabled;
// Alga que se mece: la base queda fija y la punta es la que más se mueve.

void vertex() {
	float h = VERTEX.y + 0.5;  // 0 en la base, 1 en la punta
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;  // desfase por alga
	VERTEX.x += sin(TIME * 0.9 + origin.x * 0.3 + origin.z * 0.2 + h * 2.0) * 2.5 * h * h;
}

void fragment() {
	ALBEDO = vec3(0.16, 0.5, 0.22);
}
