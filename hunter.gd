extends Node3D
# Cazador nocturno: sale al caer la noche, persigue al buzo cada vez más rápido y lo mata al alcanzarlo.
# Un arponazo lo aturde unos segundos. Junto a la estación el buzo está a salvo.
# shortcut: atraviesa el decorado (sin física, como la fauna); darle colisión si se nota mucho.

const KILL_RADIUS := 2.0
const HIT_RADIUS := 2.4
const STUN_SECONDS := 4.0
const SAFE_DISTANCE := 22.0  # a cuánto de la estación espera mientras el buzo está a salvo

var main: Node
var stun := 0.0
var speed := 5.0
var growl := 0.0


func setup(owner_node: Node) -> void:
	main = owner_node
	var body := Color(0.06, 0.07, 0.09)
	part(SphereMesh.new(), Vector3.ZERO, Vector3(1.6, 1.3, 4.2), body)  # cuerpo
	part(PrismMesh.new(), Vector3(0, 1.0, 0.3), Vector3(0.15, 1.2, 1.4), body)  # aleta dorsal
	part(PrismMesh.new(), Vector3(0, 0, 2.4), Vector3(0.15, 1.8, 1.2), body, Vector3(PI / 2.0, 0, 0))  # cola
	part(BoxMesh.new(), Vector3(0, -0.35, -1.75), Vector3(1.0, 0.12, 0.5), Color(0.8, 0.8, 0.75), Vector3.ZERO, 0.3)  # dientes
	for side in [-1.0, 1.0]:  # ojos rojos que se ven a través de la niebla
		part(SphereMesh.new(), Vector3(0.55 * side, 0.25, -1.4), Vector3.ONE * 0.28, Color(1.0, 0.1, 0.05), Vector3.ZERO, 4.0)
	hide()


func part(mesh: PrimitiveMesh, pos: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO, glow := 0.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
		mat.disable_fog = true
	mesh.material = mat
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	m.scale = size
	m.rotation = rot
	add_child(m)


# Aparece lejos, a espaldas del buzo.
func appear() -> void:
	var p: CharacterBody3D = main.player
	position = p.position + p.global_basis.z.slide(Vector3.UP).normalized() * 45.0
	position.y = minf(p.position.y, -6.0)
	speed = 5.0
	stun = 0.0
	show()


# El arpón le pega si el tramo recorrido por la punta pasa cerca. Devuelve si le dio.
func harpooned(from: Vector3, to: Vector3) -> bool:
	if not visible or Geometry3D.get_closest_point_to_segment(position, from, to).distance_to(position) > HIT_RADIUS:
		return false
	stun = STUN_SECONDS
	main.sfx.play("hurt", 0.5)
	main.show_toast("¡Lo aturdiste! Tienes %d s" % STUN_SECONDS, main.AMBER)
	return true


func _process(delta: float) -> void:
	if not visible or not main.playing:
		return
	var target: Vector3 = main.player.position
	stun = maxf(stun - delta, 0.0)
	speed = minf(speed + 0.1 * delta, 11.0)  # más rápido cuanto más dura la noche (el buzo nada a 6 m/s de base)
	if main.near_station():  # a salvo: ronda a distancia de la estación
		var away: Vector3 = (position - main.station.position).slide(Vector3.UP).normalized()
		target = main.station.position + away * SAFE_DISTANCE + Vector3.DOWN * 8.0
	var step := speed * delta * (0.15 if stun > 0.0 else 1.0)
	position = position.move_toward(target, step)
	position.y = maxf(position.y, main.world.floor_y(position.x, position.z) + 1.5)
	position.y = minf(position.y, -1.0)
	if position.distance_to(target) > 0.5:
		look_at(target if stun <= 0.0 else 2.0 * position - target)
	var dist: float = position.distance_to(main.player.position)
	# Gruñido cada vez más seguido al acercarse.
	growl -= delta
	if dist < 30.0 and growl <= 0.0:
		growl = lerpf(0.5, 2.5, dist / 30.0)
		main.sfx.play("growl", randf_range(0.9, 1.1))
	if stun <= 0.0 and dist < KILL_RADIUS and not main.near_station():
		main.die("El cazador nocturno te alcanzó")
