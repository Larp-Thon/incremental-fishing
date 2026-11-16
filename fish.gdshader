shader_type spatial;

instance uniform vec3 color : source_color = vec3(1.0, 0.5, 0.2);
instance uniform float phase = 0.0;
instance uniform float glow = 0.0;  // los peces de profundidad brillan para verse en la oscuridad

void vertex() {
	// Ondulación de nado: crece hacia la cola (+Z), la cabeza casi no se mueve.
	VERTEX.x += sin(TIME * 8.0 + VERTEX.z * 4.0 + phase) * 0.6 * (VERTEX.z + 0.5);
}

void fragment() {
	// Normal por cara para el look low-poly facetado.
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	ALBEDO = color;
	EMISSION = color * glow;
}
