extends Node3D
# Fauna que no se pesca: tortugas, mantas, una ballena y bancos de medusas luminosas.
# Solo da vida: nada en círculos, no tiene colisión y el arpón la atraviesa.
const GEAR := preload("res://vehicle.gd")

var main: Node
var creatures := []  # {node, center, radius, speed, angle}
var flaps := []  # {node, axis ("x"/"z"), amp, rate}: aletas que baten
var jellies: Array[MeshInstance3D] = []  # meta "y": altura de reposo
var whale: Node3D
var song := 6.0  # segundos hasta el siguiente canto de la ballena
var clock := 0.0


func setup(owner_node: Node) -> void:
	main = owner_node
	var world: Node3D = main.world
	for i in 3:
		turtle(swimmer(0, randf_range(5.0, 10.0), randf_range(7.0, 13.0), 1.4))
	for zone in [1, 2]:
		manta(swimmer(zone, 14.0, 14.0, 2.6))
	whale = creature(Vector3(0, -42, -150), 42.0, 2.5)  # cruza las zonas 3-5 a media agua
	build_whale()
	# Bancos de medusas luminosas (pequeñas y cian: las moradas grandes son las que pican).
	var mesh := GEAR.ball(0.22)
	mesh.height = 0.3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 1.0, 0.95, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.3, 1.0, 0.9)
	mat.emission_energy_multiplier = 2.0
	mesh.material = mat
	for zone in [3, 5]:
		var center: Vector3 = world.spot(zone) + Vector3.UP * 15.0
		for i in 16:
			var j := MeshInstance3D.new()
			j.mesh = mesh
			j.position = center + Vector3(randf_range(-6.0, 6.0), randf_range(-4.0, 4.0), randf_range(-6.0, 6.0))
			j.set_meta("y", j.position.y)
			add_child(j)
			jellies.append(j)


# Animal que nada en círculo dentro de una zona, a "height" metros del fondo.
func swimmer(zone: int, height: float, radius: float, speed: float) -> Node3D:
	var x := randf_range(-25.0, 25.0)
	var z: float = -(main.world.BOUNDS[zone] + main.world.BOUNDS[zone + 1]) * 0.5
	return creature(Vector3(x, main.world.floor_y(x, z) + height, z), radius, speed)


func creature(center: Vector3, radius: float, speed: float) -> Node3D:
	var node := Node3D.new()
	add_child(node)
	creatures.append({node = node, center = center, radius = radius, speed = speed, angle = randf() * TAU})
	return node


# Aleta sobre un pivote (la bisagra): bate alrededor de "axis".
func fin(body: Node3D, hinge: Vector3, offset: Vector3, size: Vector3, color: Color, axis: String, amp: float, rate: float) -> void:
	var pivot := Node3D.new()
	pivot.position = hinge
	body.add_child(pivot)
	GEAR.part(pivot, GEAR.ball(0.5), offset, color).scale = size
	flaps.append({node = pivot, axis = axis, amp = amp * signf(offset.x + 0.001), rate = rate})


func turtle(body: Node3D) -> void:
	var shell := Color(0.3, 0.45, 0.25)
	var skin := Color(0.5, 0.62, 0.38)
	GEAR.part(body, GEAR.ball(0.5), Vector3.ZERO, shell).scale = Vector3(1.2, 0.5, 1.5)
	GEAR.part(body, GEAR.ball(0.16), Vector3(0, 0.02, -0.85), skin)
	for side in [-1.0, 1.0]:
		fin(body, Vector3(0.45 * side, 0, -0.35), Vector3(0.4 * side, 0, 0), Vector3(0.8, 0.06, 0.3), skin, "z", 0.5, 2.2)
		GEAR.part(body, GEAR.ball(0.5), Vector3(0.42 * side, 0, 0.62), skin).scale = Vector3(0.35, 0.06, 0.25)


func manta(body: Node3D) -> void:
	var back := Color(0.12, 0.16, 0.24)
	GEAR.part(body, GEAR.ball(0.5), Vector3.ZERO, back).scale = Vector3(1.6, 0.35, 2.2)
	GEAR.part(body, GEAR.cyl(0.03, 0.01, 2.2), Vector3(0, 0, 2.0), back)  # cola
	for side in [-1.0, 1.0]:
		fin(body, Vector3(0.6 * side, 0, 0), Vector3(1.0 * side, 0, 0.1), Vector3(2.2, 0.12, 1.5), back, "z", 0.35, 1.6)


func build_whale() -> void:
	var skin := Color(0.16, 0.22, 0.32)
	GEAR.part(whale, GEAR.ball(0.5), Vector3.ZERO, skin, 0.25).scale = Vector3(4.5, 4.5, 20.0)
	GEAR.part(whale, GEAR.cyl(1.3, 0.35, 8.0), Vector3(0, 0, 12.0), skin, 0.25)  # pedúnculo
	fin(whale, Vector3(0, 0, 15.5), Vector3(0, 0, 1.5), Vector3(7.0, 0.4, 2.5), skin, "x", 0.3, 0.9)  # aleta caudal
	for side in [-1.0, 1.0]:
		GEAR.part(whale, GEAR.ball(0.5), Vector3(2.8 * side, -1.2, -3.0), skin, 0.25).scale = Vector3(4.5, 0.3, 1.8)


func _process(delta: float) -> void:
	if not main:
		return
	clock += delta
	for c in creatures:
		c.angle += c.speed / c.radius * delta
		var dir := Vector3(-sin(c.angle), 0.0, cos(c.angle))
		c.node.position = c.center + Vector3(cos(c.angle), 0.0, sin(c.angle)) * c.radius + Vector3.UP * sin(clock * 0.3 + c.angle)
		c.node.rotation.y = atan2(-dir.x, -dir.z)
	for f in flaps:
		f.node.set_indexed("rotation:" + f.axis, sin(clock * f.rate) * f.amp)
	for j in jellies:
		j.position.y = j.get_meta("y") + sin(clock * 0.8 + j.position.x) * 0.5
	song -= delta
	if song <= 0.0 and main.playing and whale.position.distance_to(main.player.position) < 55.0:
		song = 16.0
		main.sfx.play("whale", randf_range(0.85, 1.1))
