extends Node3D
# Este nodo es la lanza: vuela en el mundo y vuelve recogida por el sedal.
# El fusil se queda en la mano (hijo de la cámara). Origen de la lanza = cola, punta hacia -Z.
# shortcut: impacto por distancia contra el grupo "fish" (sin física); cambiar a Area3D si hay cientos de peces.

enum { HELD, OUT, BACK }
const HAND := Vector3(0.3, -0.26, -0.8)  # posición del fusil respecto a la cámara
const TIP := Vector3(0, 0, -1.2)

var state := HELD
var dir := Vector3.FORWARD
var traveled := 0.0
var hooked: Node3D
var rope := MeshInstance3D.new()

@onready var main := get_parent()
@onready var player: Camera3D = $"../Player"


func _ready() -> void:
	var steel := Color(0.78, 0.8, 0.83)
	add_part(self, cyl(0.015, 0.015, 1.0), Vector3(0, 0, -0.5), steel)  # vara
	add_part(self, cyl(0.0, 0.045, 0.25), Vector3(0, 0, -1.075), steel)  # punta

	var gun := Node3D.new()
	gun.position = HAND
	add_part(gun, box(Vector3(0.05, 0.06, 0.5)), Vector3.ZERO, Color(0.15, 0.17, 0.2))  # cañón
	add_part(gun, box(Vector3(0.05, 0.16, 0.06)), Vector3(0, -0.1, 0.17), Color(0.95, 0.45, 0.15))  # empuñadura
	player.add_child(gun)

	rope.mesh = box(Vector3(0.012, 0.012, 1.0))
	rope.top_level = true
	add_child(rope)


func reset() -> void:
	state = HELD
	hooked = null


func cyl(top: float, bottom: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = 6
	return c


func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func add_part(parent: Node3D, mesh: PrimitiveMesh, pos: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	m.mesh = mesh
	m.position = pos
	if mesh is CylinderMesh:
		m.rotation.x = -PI / 2.0  # el eje Y del cilindro pasa a apuntar hacia delante (-Z)
	parent.add_child(m)


func _process(delta: float) -> void:
	var rest: Vector3 = player.global_transform * (HAND + Vector3(0, 0.045, 0.2))  # cola de la lanza cargada
	var reel: float = 1.0 + 0.25 * main.lvl("reel")
	match state:
		HELD:
			global_transform = Transform3D(player.global_basis, rest)
			if not player.locked and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
					and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				state = OUT
				dir = -player.global_basis.z
				traveled = 0.0
		OUT:
			var tip_from: Vector3 = global_transform * TIP
			var step := 30.0 * reel * delta
			global_position += dir * step
			traveled += step
			var tip_to: Vector3 = global_transform * TIP
			# Segmento recorrido por la punta este frame: no atraviesa peces aunque bajen los FPS.
			for fish in get_tree().get_nodes_in_group("fish"):
				var p: Vector3 = fish.global_position
				if not fish.hooked and Geometry3D.get_closest_point_to_segment(p, tip_from, tip_to).distance_to(p) < fish.hit_radius:
					hooked = fish
					fish.hooked = true
					break
			if hooked or traveled >= main.reach():
				state = BACK
		BACK:
			global_position = global_position.move_toward(rest, 14.0 * reel * delta)
			if hooked:
				hooked.global_position = global_transform * Vector3(0, 0, -0.9)
			if global_position.distance_to(rest) < 0.05:
				if hooked:
					main.catch_fish(hooked)
					hooked = null
				state = HELD

	# Sedal: de la boca del fusil a la cola de la lanza.
	var muzzle: Vector3 = player.global_transform * (HAND + Vector3(0, 0.045, -0.25))
	var length := muzzle.distance_to(global_position)
	rope.visible = state != HELD and length > 0.05
	if rope.visible:
		rope.global_position = (muzzle + global_position) / 2.0
		rope.look_at(global_position, player.global_basis.y)
		rope.scale = Vector3(1, 1, length)
