shader_type spatial;
render_mode cull_disabled;
// Un solo plano para las dos caras: por arriba agua con ondas, por abajo el brillo de la superficie.

uniform float dim = 1.0;  // 1 = pleno día; baja de noche y con tormenta
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float diag = 0.5 * cos((wpos.x + wpos.z) * 0.5 + TIME * 0.7);
	float dx = 0.8 * cos(wpos.x * 0.8 + TIME * 1.2) + diag;
	float dz = 1.1 * cos(wpos.z * 1.1 - TIME * 0.9) + diag;
	if (FRONT_FACING) {
		NORMAL_MAP = vec3(0.5 + 0.1 * dx, 0.5 + 0.1 * dz, 1.0);
		ALBEDO = vec3(0.04, 0.3, 0.45);
		ROUGHNESS = 0.15;
	} else {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(0.7, 0.95, 1.0) * (0.85 + 0.06 * (dx + dz)) * dim;
	}
}
