extends Node3D
# Estación flotante: muelle de entrega (proa), terminal de mejoras (delante de la cabina) y refugio de noche.
# La cadena luminosa baja hasta el fondo para encontrarla desde abajo.

var body := StaticBody3D.new()  # colisión de las piezas en forma de caja
var modules := {}


func _ready() -> void:
	add_child(body)
	var orange := Color(0.95, 0.45, 0.15)
	var hull := Color(0.85, 0.87, 0.9)
	var steel := Color(0.8, 0.8, 0.82)
	var amber := Color(1.0, 0.75, 0.2)
	# Plataforma: la parte delantera (+Z) mira al punto de inicio del buzo.
	part(BoxMesh.new(), Vector3(10, 0.3, 10.4), Vector3(0, 0.3, -0.2), Color(0.72, 0.55, 0.38))  # cubierta
	for x in [-4.4, 4.4]:
		part(BoxMesh.new(), Vector3(1.4, 1.0, 11), Vector3(x, 0, -0.2), orange)  # flotadores
	for x in [-4.9, 4.9]:
		part(BoxMesh.new(), Vector3(0.08, 0.5, 10.4), Vector3(x, 0.75, -0.2), steel)  # barandillas
	# Cabina con ventanas iluminadas y tejado.
	part(BoxMesh.new(), Vector3(6, 2.6, 3.2), Vector3(0, 1.75, -3.6), hull)
	part(BoxMesh.new(), Vector3(6.6, 0.25, 3.8), Vector3(0, 3.15, -3.6), Color(0.75, 0.25, 0.2))
	for x in [-2.0, 2.0]:
		part(BoxMesh.new(), Vector3(1.3, 0.7, 0.05), Vector3(x, 2.1, -1.98), Color(1.0, 0.85, 0.55), 1.2)
	# Terminal de mejoras delante de la cabina.
	part(BoxMesh.new(), Vector3(1.4, 1.7, 0.5), Vector3(0, 1.3, -1.7), Color(0.2, 0.22, 0.27))
	part(BoxMesh.new(), Vector3(1.1, 0.7, 0.05), Vector3(0, 1.6, -1.43), Color(0.3, 0.9, 1.0), 2.0)
	add_sign("TERMINAL", Vector3(0, 2.75, -1.9), Color(0.3, 0.9, 1.0))
	# Muelle de entrega: arco ámbar en la proa, donde llega el buzo.
	for x in [-1.4, 1.4]:
		part(CylinderMesh.new(), Vector3(0.14, 1.4, 0.14), Vector3(x, 1.85, 4.7), amber, 1.5)
	part(BoxMesh.new(), Vector3(3.1, 0.22, 0.22), Vector3(0, 3.25, 4.7), amber, 1.5)
	part(BoxMesh.new(), Vector3(2.2, 0.7, 1.0), Vector3(-3.0, 0.8, 4.2), Color(0.2, 0.45, 0.7))  # cajón de entrega
	add_sign("ENTREGA", Vector3(0, 3.75, 4.7), amber)
	# Mástil con baliza, antena y foco que alumbra la cubierta de noche.
	part(CylinderMesh.new(), Vector3(0.14, 3.0, 0.14), Vector3(2.4, 6.2, -4.2), steel)
	part(SphereMesh.new(), Vector3(0.5, 0.5, 0.5), Vector3(2.4, 9.3, -4.2), orange, 3.0)
	part(CylinderMesh.new(), Vector3(0.05, 1.2, 0.05), Vector3(-2.2, 4.4, -4.2), steel)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.light_energy = 1.4
	lamp.omni_range = 14.0
	lamp.position = Vector3(0, 4.5, 1.0)
	add_child(lamp)
	part(CylinderMesh.new(), Vector3(0.1, 9.5, 0.1), Vector3(0, -9.5, 0), orange, 1.5)  # cadena al fondo


func add_sign(text: String, pos: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 96
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.position = pos
	add_child(label)


func part(mesh: PrimitiveMesh, size: Vector3, pos: Vector3, color: Color, glow := 0.0) -> void:
	var m := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	mesh.material = mat
	m.mesh = mesh
	m.scale = size
	m.position = pos
	add_child(m)
	if mesh is BoxMesh:
		var shape := BoxShape3D.new()
		shape.size = size
		var c := CollisionShape3D.new()
		c.shape = shape
		c.position = pos
		body.add_child(c)


# Trofeo de una captura legendaria: un pez del color de la especie sobre un poste, en el borde de la cubierta.
func add_trophy(slot: int, color: Color) -> void:
	var x := -2.5 + slot
	part(CylinderMesh.new(), Vector3(0.05, 0.35, 0.05), Vector3(x, 0.8, 3.2), Color(0.8, 0.8, 0.82))
	part(SphereMesh.new(), Vector3(0.6, 0.26, 0.14), Vector3(x, 1.28, 3.2), color, 1.2)


func add_module(module_id: String, level: int) -> void:
	var previous := int(modules.get(module_id, 0))
	if level <= previous:
		return
	modules[module_id] = level
	for index in range(previous + 1, level + 1):
		var side := -1.0 if index % 2 == 1 else 1.0
		var x := side * (1.7 + float(index - 1) * 0.8)
		var z := 1.4
		if module_id == "lab":
			z = 0.0
		elif module_id == "traps":
			z = -1.4
		elif module_id == "warehouse":
			z = 2.2
		match module_id:
			"aquarium":
				part(BoxMesh.new(), Vector3(1.0, 0.8, 0.8), Vector3(x, 0.85, z), Color(0.25, 0.65, 0.78))
				part(SphereMesh.new(), Vector3(0.35, 0.35, 0.35), Vector3(x, 0.9, z), Color(0.4, 0.9, 0.75), 1.0)
			"lab":
				part(BoxMesh.new(), Vector3(1.2, 0.7, 0.9), Vector3(x, 0.8, z), Color(0.32, 0.35, 0.45))
				part(CylinderMesh.new(), Vector3(0.25, 0.5, 0.25), Vector3(x, 1.35, z), Color(0.35, 0.9, 1.0), 1.5)
			"traps":
				part(CylinderMesh.new(), Vector3(0.38, 0.38, 0.38), Vector3(x, 0.75, z), Color(0.9, 0.65, 0.2))
			"warehouse":
				part(BoxMesh.new(), Vector3(1.1, 0.8, 0.9), Vector3(x, 0.85, z), Color(0.3, 0.4, 0.5))
				part(BoxMesh.new(), Vector3(0.75, 0.45, 0.06), Vector3(x, 0.9, z - 0.49), Color(0.7, 0.8, 0.85))
