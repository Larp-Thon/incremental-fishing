extends Node3D
# Scooter submarino en primera persona (hijo del jugador, coordenadas de cámara, -Z delante):
# casco con hélice, manillar agarrado con las dos manos y su propio arpón montado encima.

const MOUNT := Vector3(0.0, -0.17, -0.95)  # fusil montado; harpoon.gd dispara desde aquí
const ORANGE := Color(0.95, 0.42, 0.14)
const DARK := Color(0.13, 0.15, 0.19)

var main: Node
var hull := Node3D.new()
var blades := Node3D.new()
var body: MeshInstance3D
var gauge: MeshInstance3D


# Pieza de equipo con color plano. Los cilindros apuntan hacia delante (-Z).
static func part(parent: Node3D, mesh: PrimitiveMesh, pos: Vector3, color: Color, glow := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.3
	mat.roughness = 0.35
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	if mesh is CylinderMesh:
		m.rotation.x = -PI / 2.0
	parent.add_child(m)
	return m


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func cyl(front: float, back: float, length: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = front
	c.bottom_radius = back
	c.height = length
	c.radial_segments = 10
	return c


static func ball(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 10
	s.rings = 5
	return s


func _ready() -> void:
	hull.position = Vector3(0.0, -0.34, -1.0)
	add_child(hull)
	body = part(hull, cyl(0.14, 0.14, 0.8), Vector3.ZERO, ORANGE)
	part(hull, cyl(0.03, 0.14, 0.22), Vector3(0, 0, -0.51), DARK)  # morro
	part(hull, ball(0.035), Vector3(0, 0, -0.62), Color(0.7, 0.95, 1.0), 3.0)  # faro
	part(hull, cyl(0.14, 0.07, 0.16), Vector3(0, 0, 0.48), DARK)  # cola
	part(hull, box(Vector3(0.56, 0.015, 0.14)), Vector3(0, 0, 0.3), DARK)  # estabilizadores
	part(hull, box(Vector3(0.015, 0.3, 0.14)), Vector3(0, 0, 0.3), DARK)
	var ring := TorusMesh.new()  # carenado de la hélice
	ring.inner_radius = 0.15
	ring.outer_radius = 0.185
	ring.rings = 12
	ring.ring_segments = 6
	part(hull, ring, Vector3(0, 0, 0.56), DARK).rotation.x = PI / 2.0
	blades.position = Vector3(0, 0, 0.56)
	hull.add_child(blades)
	for i in 3:
		part(blades, box(Vector3(0.28, 0.05, 0.012)), Vector3.ZERO, Color(0.75, 0.78, 0.8)).rotation = Vector3(0.35, 0, i * PI / 3.0)
	# Indicador de batería sobre el lomo, a la vista del buzo.
	part(hull, box(Vector3(0.15, 0.012, 0.07)), Vector3(0, 0.142, 0.25), DARK)
	gauge = part(hull, box(Vector3(0.13, 0.012, 0.05)), Vector3(0, 0.146, 0.25), Color.GREEN, 2.5)

	# Arpón montado y manillar: fuera del casco para no escalarse con el minisubmarino.
	part(self, box(Vector3(0.05, 0.05, 0.5)), MOUNT, DARK)
	part(self, box(Vector3(0.07, 0.05, 0.08)), MOUNT + Vector3(0, -0.03, 0.15), ORANGE)
	part(self, box(Vector3(0.3, 0.02, 0.1)), Vector3(0, -0.27, -0.58), DARK)
	limb(Vector3(-0.3, -0.27, -0.55), Vector3(0.3, -0.27, -0.55), 0.013, DARK)
	for side in [-1.0, 1.0]:
		var grip := Vector3(0.24 * side, -0.27, -0.55)
		limb(grip - Vector3(0.05 * side, 0, 0), grip + Vector3(0.05 * side, 0, 0), 0.02, ORANGE)  # puño
		part(self, ball(0.05), grip + Vector3(0, 0.005, 0.02), Color(0.1, 0.14, 0.24)).scale = Vector3(1.1, 0.85, 1.2)  # guante
		limb(grip + Vector3(0, -0.01, 0.04), Vector3(0.4 * side, -0.58, -0.08), 0.042, Color(0.16, 0.2, 0.3))  # antebrazo


# Cilindro entre dos puntos (manillar, brazos).
func limb(a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var m := part(self, cyl(radius, radius, a.distance_to(b)), Vector3.ZERO, color)
	m.transform = Transform3D(Basis.looking_at(b - a) * Basis(Vector3.RIGHT, -PI / 2.0), (a + b) / 2.0)


func set_sub(on: bool) -> void:
	hull.scale = Vector3.ONE * (1.25 if on else 1.0)
	body.material_override.albedo_color = Color(0.95, 0.8, 0.15) if on else ORANGE


func _process(delta: float) -> void:
	if not visible:
		return
	# Vida al conducir: vaivén, alabeo al girar y hélice según la velocidad.
	position.y = sin(Time.get_ticks_msec() * 0.0022) * 0.012
	rotation.z = lerpf(rotation.z, -Input.get_axis("left", "right") * 0.12, 5.0 * delta)
	blades.rotation.z += delta * (6.0 + main.player.velocity.length() * 3.0)
	var charge: float = main.vehicle_battery / main.max_vehicle_battery()
	gauge.scale.x = maxf(charge, 0.02)
	gauge.material_override.emission = Color.RED.lerp(Color.GREEN, charge)
