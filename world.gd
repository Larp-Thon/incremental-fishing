extends Node3D
# Mundo "horizontal": un cañón que baja en terrazas hacia -Z.
# Cada zona es una franja con su fondo 20 m más hondo que la anterior, su decorado y su material de mejora.

# Distancia hacia delante (d = -z) donde empieza cada zona; el último valor es el final del cañón.
const BOUNDS := [-50.0, 45.0, 85.0, 125.0, 165.0, 205.0, 250.0]
const HALF_WIDTH := 60.0  # el cañón va de x = -60 a x = 60
const SLOPE := 6.0  # media anchura de la rampa entre terrazas
const GROUND := [Color(0.86, 0.78, 0.58), Color(0.5, 0.58, 0.42), Color(0.4, 0.42, 0.46), Color(0.27, 0.29, 0.36), Color(0.19, 0.19, 0.25), Color(0.11, 0.11, 0.15)]
const CLIFF := Color(0.45, 0.42, 0.4)
const CORAL := [Color(1.0, 0.45, 0.6), Color(1.0, 0.6, 0.25), Color(0.7, 0.4, 0.9), Color(0.95, 0.85, 0.3)]
const AMBER := Color(1.0, 0.75, 0.2)
# Entrantes en la pared del cañón, fuera de la ruta principal. side: -1 = oeste (x < 0); from/to en d = -z.
const ALCOVES := [
	{side = -1.0, from = 56.0, to = 80.0, depth = 26.0},  # arrecife secreto, tras las algas de la zona 2
	{side = 1.0, from = 134.0, to = 156.0, depth = 26.0},  # cueva de cristal, en la zona 4
]

# Material de mejora/recetas que se recoge en cada zona.
const MATERIALS := [
	{name = "Perla", color = Color(1.0, 1.0, 1.0)},
	{name = "Espina de erizo", color = Color(0.75, 0.4, 1.0)},
	{name = "Perla negra", color = Color(0.35, 0.4, 0.85)},
	{name = "Cristal", color = Color(0.3, 1.0, 0.9)},
	{name = "Azufre", color = Color(1.0, 0.9, 0.2)},
	{name = "Fragmento abisal", color = Color(0.6, 0.35, 1.0)},
]

var pickups: Array[MeshInstance3D] = []  # materiales aún sin recoger; meta "zone"
var pickup_spots := []  # [zona, posición] de cada material: reaparecen ahí cada día
var notes: Array[MeshInstance3D] = []  # notas del diario aún sin recoger; meta "note" y "beam"
var sites := {}  # reef / wreck / cave -> centro: ahí viven las especies con "site"
var reserved := []  # [centro, radio]: el decorado al azar no cae encima
var heart: OmniLight3D  # luz del Latido, al final del cañón
var meshes := {}
var mats := {}
var body := StaticBody3D.new()  # colisión de todo el decorado sólido


func _ready() -> void:
	add_child(body)
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
	build_sites()
	decorate()


func _process(_delta: float) -> void:
	heart.light_energy = 2.5 + 1.5 * sin(Time.get_ticks_msec() * 0.003)


# 0 en la zona 1 ... 5 en la zona 6, con rampas suaves entre terrazas.
func steps(d: float) -> float:
	var s := 0.0
	for i in range(1, 6):
		s += smoothstep(BOUNDS[i] - SLOPE, BOUNDS[i] + SLOPE, d)
	return s


# Media anchura del cañón en el lado de x: más ancha donde hay un entrante.
func half_width(x: float, z: float) -> float:
	var w := HALF_WIDTH
	for a in ALCOVES:
		if x * a.side > 0.0:
			w += a.depth * smoothstep(a.from - 3.0, a.from + 3.0, -z) * (1.0 - smoothstep(a.to - 3.0, a.to + 3.0, -z))
	return w


# Cuánto sube la pared del cañón en este punto (0 = dentro, 1 = acantilado).
func wall(x: float, z: float) -> float:
	var out := maxf(absf(x) - half_width(x, z), maxf(BOUNDS[0] + z, -z - BOUNDS[6]))
	return smoothstep(0.0, 18.0, out)


func floor_y(x: float, z: float) -> float:
	var bumps := sin(x * 0.13) * cos(z * 0.11) * 1.2 + sin(x * 0.05 + z * 0.07)
	return lerpf(-(18.0 + 20.0 * steps(-z)) + bumps, 8.0, wall(x, z))


func build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)  # caras planas: look low-poly
	var cell := 4.0
	for i in range(-27, 27):  # hasta x = ±108: cubre los entrantes y su pared
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
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://terrain.gdshader")
	var terrain := MeshInstance3D.new()
	terrain.mesh = st.commit()
	terrain.material_override = mat
	add_child(terrain)
	terrain.create_trimesh_collision()


# Punto al azar sobre el fondo de una zona (lejos de rampas y paredes).
func spot(zone: int) -> Vector3:
	var x := randf_range(-52.0, 52.0)
	var z := -randf_range(BOUNDS[zone] + 8.0, BOUNDS[zone + 1] - 8.0)
	return Vector3(x, floor_y(x, z), z)


func ground(x: float, z: float) -> Vector3:
	return Vector3(x, floor_y(x, z), z)


# Como spot(), pero a más de "gap" metros de lo recogible y fuera de los sitios reservados (pecio, notas...).
func clear_spot(zone: int, gap: float) -> Vector3:
	var p := spot(zone)
	for i in 30:
		if pickups.all(func(k: Node3D) -> bool: return k.position.distance_to(p) > gap) \
				and reserved.all(func(r: Array) -> bool: return r[0].distance_to(p) > r[1]):
			break
		p = spot(zone)
	return p


func tilt(amount: float) -> Vector3:
	return Vector3(randf_range(-amount, amount), randf() * TAU, randf_range(-amount, amount))


# Coloca una pieza apoyada en "base". size está en metros. solid: bloquea al buzo y al arpón.
func prop(kind: String, base: Vector3, size: Vector3, color := Color.WHITE, glow := 0.0, rot := Vector3.ZERO, solid := false) -> MeshInstance3D:
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
	if solid:
		var c := CollisionShape3D.new()
		if kind == "box":
			var box := BoxShape3D.new()
			box.size = size
			c.shape = box
		else:  # cilindro aproximado; el cono se estrecha, así que cuenta menos radio
			var cyl := CylinderShape3D.new()
			cyl.height = size.y
			cyl.radius = (size.x + size.z) * (0.15 if kind == "cone" else 0.25)
			c.shape = cyl
		c.position = m.position
		c.rotation = rot
		body.add_child(c)
	return m


func pickup(zone: int, pos: Vector3) -> void:
	pickup_spots.append([zone, pos])
	var m := prop("ball", pos, Vector3.ONE * 0.45, MATERIALS[zone].color, 2.5)
	m.set_meta("zone", zone)
	pickups.append(m)


# Cada día vuelven todos los materiales: ninguna receta puede quedar bloqueada para siempre.
func respawn_pickups() -> void:
	for p in pickups:
		p.queue_free()
	pickups.clear()
	var spots := pickup_spots
	pickup_spots = []
	for s in spots:
		pickup(s[0], s[1])


# Almeja / ostra abierta en p; si has_item, lleva dentro el material de la zona.
func shell(p: Vector3, zone: int, has_item: bool, size: float, color: Color) -> void:
	prop("ball", p, Vector3(1.0, 0.3, 0.8) * size, color)
	prop("ball", p + Vector3(0, 0.25, -0.25) * size, Vector3(1.0, 0.3, 0.8) * size, color, 0.0, Vector3(-0.7, 0, 0))
	if has_item:
		pickup(zone, p + Vector3(0, 0.2, 0.05) * size)


func coral(p: Vector3, glow := 0.0, tall := 1.0) -> void:
	var c: Color = CORAL.pick_random()
	for b in randi_range(3, 5):
		prop("tube", p, Vector3(0.3, randf_range(0.8, 2.4) * tall, 0.3), c, glow, tilt(0.6))


func light(pos: Vector3, color: Color, reach: float, energy: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.omni_range = reach
	l.light_energy = energy
	add_child(l)
	return l


# Nota del diario: cápsula ámbar con un haz de luz encima. Las ya leídas no vuelven a aparecer.
func note(index: int, pos: Vector3) -> void:
	reserved.append([pos, 4.0])
	if index in get_parent().notes:
		return
	var m := prop("tube", pos + Vector3.UP, Vector3(0.3, 0.8, 0.3), AMBER, 2.5)
	m.set_meta("note", index)
	m.set_meta("beam", prop("tube", pos + Vector3.UP * 2.2, Vector3(0.06, 9.0, 0.06), AMBER, 2.5))
	notes.append(m)


# Sitios fuera de la ruta y el rastro de notas que lleva hasta el fondo.
func build_sites() -> void:
	note(0, ground(4.0, -14.0))  # bajo la estación
	note(1, ground(30.0, -62.0))
	note(4, ground(35.0, -140.0))
	note(5, ground(-25.0, -185.0))
	note(6, ground(15.0, -222.0))

	# Arrecife secreto: entrante oeste de la zona 2, tapado por una cortina de algas.
	var reef := ground(-74.0, -68.0)
	sites.reef = reef + Vector3.UP * 4.0
	for i in 18:
		prop("kelp", ground(randf_range(-63.0, -57.0), -randf_range(57.0, 79.0)), Vector3(0.5, randf_range(10.0, 16.0), 0.12))
	for i in 26:
		coral(ground(randf_range(-84.0, -64.0), -randf_range(60.0, 76.0)), 0.6, 1.6)
	for i in 3:
		shell(ground(-68.0 - i * 6.0, -63.0 - i * 5.0), 0, true, 1.3, Color(1.0, 0.8, 0.85))
	light(reef + Vector3.UP * 3.0, Color(1.0, 0.75, 0.55), 26.0, 1.6)
	note(2, reef)

	# Pecio del Nereida, sobre el roquedal (zona 3). El costado de estribor está partido: por ahí se entra.
	var w := ground(18.0, -105.0) + Vector3.DOWN * 0.5
	sites.wreck = w + Vector3.UP * 7.0
	reserved.append([w, 15.0])
	var wood := Color(0.33, 0.22, 0.15)
	var dark := Color(0.2, 0.14, 0.1)
	prop("box", w, Vector3(22, 1.2, 6), dark, 0.0, Vector3.ZERO, true)  # quilla
	prop("box", w + Vector3(0, 0.8, -3.2), Vector3(22, 4.5, 0.6), wood, 0.0, Vector3(-0.18, 0, 0), true)  # babor
	for x in [-7.0, 7.5]:
		prop("box", w + Vector3(x, 0.8, 3.2), Vector3(7, 4.5, 0.6), wood, 0.0, Vector3(0.18, 0, 0), true)  # estribor
	prop("box", w + Vector3(-11.3, 0.8, 0), Vector3(0.6, 4.5, 6.6), wood, 0.0, Vector3.ZERO, true)  # espejo de popa
	prop("box", w + Vector3(-6, 4.8, 0), Vector3(10, 0.5, 6.6), wood, 0.0, Vector3.ZERO, true)  # cubierta de popa
	prop("box", w + Vector3(-8, 5.3, 0), Vector3(5, 3, 4), dark, 0.0, Vector3.ZERO, true)  # camarote
	prop("cone", w + Vector3(14, 0, 0), Vector3(5, 6, 6.6), wood, 0.0, Vector3(0, 0, -PI / 2.0), true)  # proa
	prop("tube", w + Vector3(3, 1, 0), Vector3(0.5, 13, 0.5), dark, 0.0, Vector3(0, 0, 0.4), true)  # mástil caído
	prop("ball", w + Vector3(-5.2, 6.2, 2.2), Vector3.ONE * 0.4, AMBER, 2.5)  # farol aún encendido
	light(w + Vector3(-5.2, 7.0, 3.5), AMBER, 18.0, 1.5)
	pickup(2, w + Vector3(-7, 1.6, 0))
	pickup(2, w + Vector3(8, 1.6, 0))
	note(3, w + Vector3(-3, 1.2, 0))

	# Cueva de cristal: entrante este de la zona 4 con techo de losas.
	var cave := ground(73.0, -145.0)
	sites.cave = cave + Vector3.UP * 4.0
	for x in [66.0, 81.0]:
		for z in [-139.0, -151.0]:
			prop("box", Vector3(x, cave.y + 10.0, z), Vector3(17, 5, 14), Color(0.3, 0.32, 0.36), 0.0, Vector3(randf_range(-0.1, 0.1), 0, randf_range(-0.1, 0.1)), true)
	for i in 14:
		prop("cone", ground(randf_range(64.0, 84.0), -randf_range(137.0, 153.0)), Vector3(1.0, randf_range(2.0, 6.0), 1.0), Color(0.3, 1.0, 0.9), 1.2, tilt(0.3))
	pickup(3, ground(82.0, -141.0) + Vector3.UP)
	pickup(3, ground(80.0, -150.0) + Vector3.UP)
	light(cave + Vector3.UP * 2.0, Color(0.3, 1.0, 0.9), 22.0, 1.2)

	# El Latido: el origen de la señal, al final del cañón.
	var h := ground(0.0, -244.0)
	reserved.append([h, 12.0])
	prop("ball", h + Vector3.UP * 2.0, Vector3.ONE * 6.0, Color(1.0, 0.45, 0.7), 2.5)
	for i in 9:
		var a := i * TAU / 9.0
		prop("cone", h + Vector3(cos(a), 0, sin(a)) * 6.5, Vector3(1.6, randf_range(6.0, 13.0), 1.6), Color(0.5, 0.35, 0.9), 0.7, Vector3(sin(a), 0, -cos(a)) * 0.3)
	heart = light(h + Vector3.UP * 6.0, Color(1.0, 0.5, 0.75), 40.0, 3.0)
	note(7, h + Vector3(0, 0, 10))


func decorate() -> void:
	# Zona 1 · Bajío: arena, corales y almejas (5 con perla).
	for i in 50:
		coral(spot(0))
	for i in 18:
		shell(clear_spot(0, 3.0), 0, i < 5, 1.0, Color(0.92, 0.86, 0.76))

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
	for i in 14:
		shell(clear_spot(2, 3.0), 2, i < 5, 2.2, Color(0.45, 0.45, 0.5))
	for i in 55:
		prop("box", clear_spot(2, 7.0), Vector3(randf_range(2.0, 6.0), randf_range(2.0, 10.0), randf_range(2.0, 6.0)), Color(0.36, 0.38, 0.42), 0.0, tilt(0.35), true)

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
	for i in 5:
		var p := spot(4)
		prop("box", p, Vector3(1.6, 0.8, 1.6), Color(0.25, 0.22, 0.12), 0.0, tilt(0.3))
		pickup(4, p + Vector3.UP * 1.2)
	for i in 40:
		var p := clear_spot(4, 4.0)
		var h := randf_range(3.0, 9.0)
		prop("cone", p, Vector3(randf_range(2.0, 4.0), h, randf_range(2.0, 4.0)), Color(0.12, 0.11, 0.12), 0.0, Vector3.ZERO, true)
		prop("ball", p + Vector3.UP * (h - 0.7), Vector3.ONE * 0.7, Color(1.0, 0.45, 0.1), 3.0)

	# Zona 6 · Fosa: agujas de cristal.
	for i in 50:
		prop("cone", clear_spot(5, 4.0), Vector3(randf_range(1.0, 2.5), randf_range(4.0, 14.0), randf_range(1.0, 2.5)), Color(0.5, 0.35, 0.9), 0.7, tilt(0.3), true)
	for i in 5:
		pickup(5, clear_spot(5, 3.0) + Vector3.UP * 1.0)
