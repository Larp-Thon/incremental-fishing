extends Node3D
var main: Node
var jellyfish: Array[Node3D] = []
var clock := 0.0
var current_force := Vector3.ZERO
var warning: Label

func setup(owner_node: Node) -> void:
	main = owner_node
	warning = Label.new()
	warning.position = Vector2(200, 410)
	warning.add_theme_color_override("font_color", Color(1, 0.65, 0.3))
	warning.add_theme_color_override("font_outline_color", Color.BLACK)
	warning.add_theme_constant_override("outline_size", 4)
	main.get_node("HUD").add_child(warning)
	for zone in range(1, 6):
		for i in 4:
			var jelly := Node3D.new()
			add_child(jelly)
			jelly.position = main.world.spot(zone) + Vector3.UP * 7.0
			jelly.set_meta("home", jelly.position)
			var mesh := SphereMesh.new()
			mesh.radius = 0.7
			mesh.height = 0.8
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.85, 0.4, 0.95, 0.7)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.emission_enabled = true
			mat.emission = Color(0.4, 0.1, 0.6)
			mesh.material = mat
			var bell := MeshInstance3D.new()
			bell.mesh = mesh
			jelly.add_child(bell)
			for n in 5:
				var strand := MeshInstance3D.new()
				var tube := CylinderMesh.new()
				tube.top_radius = 0.035
				tube.bottom_radius = 0.02
				tube.height = 1.6
				tube.material = mat
				strand.mesh = tube
				strand.position = Vector3(cos(n * TAU / 5) * 0.35, -0.9, sin(n * TAU / 5) * 0.35)
				jelly.add_child(strand)
			jellyfish.append(jelly)
	# Las corrientes se reconocen por partículas que indican su dirección.
	for zone in range(1, 6):
		for i in 12:
			var bead := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.09
			mesh.height = 0.18
			bead.mesh = mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.4, 0.9, 1)
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bead.material_override = mat
			var z: float = -(main.world.BOUNDS[zone] + main.world.BOUNDS[zone + 1]) * 0.5
			bead.position = Vector3(-8 + i * 1.4, -18 - zone * 20 + 7, z)
			bead.set_meta("current", true)
			add_child(bead)

func flow_at(pos: Vector3) -> Vector3:
	if pos.y >= 0:
		return Vector3.ZERO
	for zone in range(1, 6):
		var z: float = -(main.world.BOUNDS[zone] + main.world.BOUNDS[zone + 1]) * 0.5
		if absf(pos.z - z) < 7 and absf(pos.x) < 10 and absf(pos.y - (-18 - zone * 20 + 7)) < 5:
			return Vector3(2.5 if zone % 2 == 0 else -2.5, 0, 0)
	return Vector3.ZERO

func _process(delta: float) -> void:
	if not main:
		return
	warning.text = ""
	current_force = Vector3.ZERO
	if not main.playing:
		return
	clock += delta
	for jelly in jellyfish:
		jelly.position.y = jelly.get_meta("home").y + sin(clock + jelly.position.x) * 0.6
		if jelly.position.distance_to(main.player.position) < 1.6:
			main.hurt(4.0, "Picadura de medusa")
	current_force = flow_at(main.player.position)
	if current_force != Vector3.ZERO:
		warning.text = "CORRIENTE LATERAL · nada fuera de la franja luminosa"
	for bead in get_children():
		if bead.has_meta("current"):
			var flow: Vector3 = flow_at(bead.position)
			bead.position.x += flow.x * delta
			if absf(bead.position.x) > 9:
				bead.position.x *= -0.95

