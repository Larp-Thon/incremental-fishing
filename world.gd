extends Node3D
# Mundo "horizontal": un cañón que baja en terrazas hacia -Z.
# Cada zona es una franja con su fondo 20 m más hondo que la anterior, su decorado y su material de mejora.

# Distancia hacia delante (d = -z) donde empieza cada zona; el último valor es el final del cañón.
const BOUNDS := [-50.0, 45.0, 85.0, 125.0, 165.0, 205.0, 250.0]
const HALF_WIDTH := 60.0  # el cañón va de x = -60 a x = 60
const SLOPE := 6.0  # media anchura de la rampa entre terrazas
const GROUND := [Color(0.86, 0.78, 0.58), Color(0.5, 0.58, 0.42), Color(0.4, 0.42, 0.46), Color(0.27, 0.29, 0.36), Color(0.19, 0.19, 0.25), Color(0.11, 0.11, 0.15)]
const CLIFF := Color(0.45, 0.42, 0.4)

# Material de mejora del traje que se recoge en cada zona (hay 5 por zona).
const MATERIALS := [
	{name = "Perla", color = Color(1.0, 1.0, 1.0)},
	{name = "Espina de erizo", color = Color(0.75, 0.4, 1.0)},
	{name = "Perla negra", color = Color(0.35, 0.4, 0.85)},
	{name = "Cristal", color = Color(0.3, 1.0, 0.9)},
	{name = "Azufre", color = Color(1.0, 0.9, 0.2)},
]

var pickups: Array[MeshInstance3D] = []  # materiales aún sin recoger; meta "zone"
var meshes := {}
var mats := {}


func _ready() -> void:
	var ball := SphereMesh.new()
	ball.radial_segments = 8
	ball.rings = 4
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.height = 1.0
	cone.radial_segments = 6
	var tube := CylinderMesh.new()
	tube.height = 1.0
	tube.radial_segments = 6
	var kelp := BoxMesh.new()
	kelp.subdivide_height = 5
	var kelp_mat := ShaderMaterial.new()
	kelp_mat.shader = preload("res://kelp.gdshader")
	kelp.material = kelp_mat
	# Todas las mallas miden 1 de alto y 1 de diámetro: la escala del nodo es el tamaño en metros.
	meshes = {box = BoxMesh.new(), ball = ball, cone = cone, tube = tube, kelp = kelp}
	build_terrain()
	decorate()


# 0 en la zona 1 ... 5 en la zona 6, con rampas suaves entre terrazas.
func steps(d: float) -> float:
	var s := 0.0
	for i in range(1, 6):
		s += smoothstep(BOUNDS[i] - SLOPE, BOUNDS[i] + SLOPE, d)
	return s


# Cuánto sube la pared del cañón en este punto (0 = dentro, 1 = acantilado).
func wall(x: float, z: float) -> float:
	var out := maxf(absf(x) - HALF_WIDTH, maxf(BOUNDS[0] + z, -z - BOUNDS[6]))
	return smoothstep(0.0, 18.0, out)


func floor_y(x: float, z: float) -> float:
	var bumps := sin(x * 0.13) * cos(z * 0.11) * 1.2 + sin(x * 0.05 + z * 0.07)
	return lerpf(-(18.0 + 20.0 * steps(-z)) + bumps, 8.0, wall(x, z))


func build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)  # caras planas: look low-poly
	var cell := 4.0
	for i in range(-22, 22):
		for j in range(-71, 21):
			var x0 := i * cell
			var z0 := j * cell
			var x1 := x0 + cell
			var z1 := z0 + cell
			for p in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]:
				var s := steps(-p.y)
				var color: Color = GROUND[int(s)].lerp(GROUND[mini(int(s) + 1, 5)], s - int(s))
				st.set_color(color.lerp(CLIFF, wall(p.x, p.y)))
				st.add_vertex(Vector3(p.x, floor_y(p.x, p.y), p.y))
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	var terrain := MeshInstance3D.new()
	terrain.mesh = st.commit()
	terrain.material_override = mat
	add_child(terrain)


# Punto al azar sobre el fondo de una zona (lejos de rampas y paredes).
func spot(zone: int) -> Vector3:
	var x := randf_range(-52.0, 52.0)
	var z := -randf_range(BOUNDS[zone] + 8.0, BOUNDS[zone + 1] - 8.0)
	return Vector3(x, floor_y(x, z), z)


func tilt(amount: float) -> Vector3:
	return Vector3(randf_range(-amount, amount), randf() * TAU, randf_range(-amount, amount))


# Coloca una pieza apoyada en "base". size está en metros.
func prop(kind: String, base: Vector3, size: Vector3, color := Color.WHITE, glow := 0.0, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = meshes[kind]
	if kind != "kelp":
		var key := [color, glow]
		if not mats.has(key):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			if glow > 0.0:
				mat.emission_enabled = true
				mat.emission = color
				mat.emission_energy_multiplier = glow
			mats[key] = mat
		m.material_override = mats[key]
	m.position = base + Vector3.UP * size.y * 0.5
	m.rotation = rot
	m.scale = size
	add_child(m)
	return m


func pickup(zone: int, pos: Vector3) -> void:
	var m := prop("ball", pos, Vector3.ONE * 0.45, MATERIALS[zone].color, 2.5)
	m.set_meta("zone", zone)
	pickups.append(m)


# Almeja / ostra abierta; si has_item, lleva dentro el material de la zona.
func shell(zone: int, has_item: bool, size: float, color: Color) -> void:
	var p := spot(zone)
	prop("ball", p, Vector3(1.0, 0.3, 0.8) * size, color)
	prop("ball", p + Vector3(0, 0.25, -0.25) * size, Vector3(1.0, 0.3, 0.8) * size, color, 0.0, Vector3(-0.7, 0, 0))
	if has_item:
		pickup(zone, p + Vector3(0, 0.2, 0.05) * size)


func decorate() -> void:
	# Zona 1 · Bajío: arena, corales y almejas (5 con perla).
	var coral := [Color(1.0, 0.45, 0.6), Color(1.0, 0.6, 0.25), Color(0.7, 0.4, 0.9), Color(0.95, 0.85, 0.3)]
	for i in 50:
		var p := spot(0)
		var c: Color = coral.pick_random()
		for b in randi_range(3, 5):
			prop("tube", p, Vector3(0.3, randf_range(0.8, 2.4), 0.3), c, 0.0, tilt(0.6))
	for i in 18:
		shell(0, i < 5, 1.0, Color(0.92, 0.86, 0.76))

	# Zona 2 · Bosque de algas: algas altas y erizos (5 con espina).
	for i in 90:
		prop("kelp", spot(1), Vector3(0.5, randf_range(6.0, 15.0), 0.12))
	for i in 16:
		var p := spot(1)
		prop("ball", p, Vector3.ONE * 0.8, Color(0.2, 0.1, 0.3))
		for s in 7:
			prop("cone", p + Vector3.DOWN * 0.2, Vector3(0.1, 1.3, 0.1), Color(0.35, 0.18, 0.5), 0.0, tilt(1.4))
		if i < 5:
			pickup(1, p + Vector3.UP * 1.3)

	# Zona 3 · Roquedal: bloques de roca y ostras gigantes (5 con perla negra).
	for i in 55:
		prop("box", spot(2), Vector3(randf_range(2.0, 6.0), randf_range(2.0, 10.0), randf_range(2.0, 6.0)), Color(0.36, 0.38, 0.42), 0.0, tilt(0.35))
	for i in 14:
		shell(2, i < 5, 2.2, Color(0.45, 0.45, 0.5))

	# Zona 4 · Jardín luminoso: gusanos tubícolas y anémonas (5 con cristal).
	for i in 50:
		var p := spot(3)
		var tip: Color = [Color(1.0, 0.3, 0.35), Color(0.3, 1.0, 0.9)].pick_random()
		for b in randi_range(2, 4):
			var h := randf_range(1.0, 3.5)
			var q := p + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
			prop("tube", q, Vector3(0.3, h, 0.3), Color(0.8, 0.78, 0.7))
			prop("ball", q + Vector3.UP * h, Vector3.ONE * 0.45, tip, 2.0)
	for i in 14:
		var p := spot(3)
		prop("tube", p, Vector3(1.2, 0.7, 1.2), Color(0.8, 0.25, 0.6), 0.3)
		for s in 6:
			prop("tube", p + Vector3.UP * 0.3, Vector3(0.12, 1.4, 0.12), Color(1.0, 0.5, 0.8), 0.6, tilt(0.7))
		if i < 5:
			pickup(3, p + Vector3.UP * 2.0)

	# Zona 5 · Fumarolas: chimeneas volcánicas y 5 depósitos de azufre.
	for i in 40:
		var p := spot(4)
		var h := randf_range(3.0, 9.0)
		prop("cone", p, Vector3(randf_range(2.0, 4.0), h, randf_range(2.0, 4.0)), Color(0.12, 0.11, 0.12))
		prop("ball", p + Vector3.UP * (h - 0.7), Vector3.ONE * 0.7, Color(1.0, 0.45, 0.1), 3.0)
	for i in 5:
		var p := spot(4)
		prop("box", p, Vector3(1.6, 0.8, 1.6), Color(0.25, 0.22, 0.12), 0.0, tilt(0.3))
		pickup(4, p + Vector3.UP * 1.2)

	# Zona 6 · Fosa: agujas de cristal.
	for i in 50:
		prop("cone", spot(5), Vector3(randf_range(1.0, 2.5), randf_range(4.0, 14.0), randf_range(1.0, 2.5)), Color(0.5, 0.35, 0.9), 0.7, tilt(0.3))
