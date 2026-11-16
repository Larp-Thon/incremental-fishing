extends Node3D
# Estación flotante: punto de entrega y terminal de mejoras.
# La cadena luminosa baja hasta el fondo para encontrarla desde abajo.

var body := StaticBody3D.new()  # colisión de las piezas en forma de caja


func _ready() -> void:
	add_child(body)
	var orange := Color(0.95, 0.45, 0.15)
	part(BoxMesh.new(), Vector3(7, 0.3, 7), Vector3(0, 0.3, 0), Color(0.72, 0.55, 0.38))  # cubierta
	for x in [-3.0, 3.0]:
		part(BoxMesh.new(), Vector3(1.2, 0.9, 7.6), Vector3(x, 0, 0), orange)  # flotadores
	part(BoxMesh.new(), Vector3(1.2, 1.6, 0.6), Vector3(0, 1.25, -2.5), Color(0.2, 0.22, 0.27))  # terminal
	part(BoxMesh.new(), Vector3(0.9, 0.6, 0.05), Vector3(0, 1.5, -2.18), Color(0.3, 0.9, 1.0), 2.0)  # pantalla
	part(BoxMesh.new(), Vector3(1.4, 0.8, 1.0), Vector3(-2.0, 0.85, -2.3), Color(0.2, 0.45, 0.7))  # cajón de entrega
	# CylinderMesh mide 2 de alto y 1 de diámetro por defecto.
	part(CylinderMesh.new(), Vector3(0.12, 2.5, 0.12), Vector3(2.8, 2.95, -2.8), Color(0.8, 0.8, 0.82))  # mástil
	part(SphereMesh.new(), Vector3(0.4, 0.4, 0.4), Vector3(2.8, 5.6, -2.8), orange, 3.0)  # baliza
	part(CylinderMesh.new(), Vector3(0.1, 9.5, 0.1), Vector3(0, -9.5, 0), orange, 1.5)  # cadena al fondo


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
