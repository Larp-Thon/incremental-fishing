extends Node3D
# Capas ligeras de "juice" sin texturas: motas suspendidas, burbujas del buzo y
# rayos de luz cerca de la superficie. Se reciclan meshes para no crear basura por frame.

const DUST_COUNT := 72
const BUBBLE_COUNT := 18

var dust: Array[MeshInstance3D] = []
var bubbles: Array[MeshInstance3D] = []
var bubble_age: Array[float] = []
var bubble_cursor := 0
var bubble_wait := 0.0
var shafts: Array[MeshInstance3D] = []

@onready var main := get_parent()
@onready var player: Node3D = main.get_node("Player")


func _ready() -> void:
	var mote := SphereMesh.new()
	mote.radius = 0.025
	mote.height = 0.05
	var mote_mat := StandardMaterial3D.new()
	mote_mat.albedo_color = Color(0.72, 0.94, 1.0, 0.34)
	mote_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote.material = mote_mat
	for i in DUST_COUNT:
		var p := MeshInstance3D.new()
		p.mesh = mote
		p.position = Vector3(randf_range(-28.0, 28.0), randf_range(-118.0, -1.0), randf_range(-250.0, 20.0))
		add_child(p)
		dust.append(p)

	var bubble_mesh := SphereMesh.new()
	bubble_mesh.radius = 0.075
	bubble_mesh.height = 0.15
	var bubble_mat := StandardMaterial3D.new()
	bubble_mat.albedo_color = Color(0.75, 0.95, 1.0, 0.65)
	bubble_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bubble_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bubble_mesh.material = bubble_mat
	for i in BUBBLE_COUNT:
		var b := MeshInstance3D.new()
		b.mesh = bubble_mesh
		b.visible = false
		add_child(b)
		bubbles.append(b)
		bubble_age.append(0.0)

	# Volúmenes transparentes que sugieren la luz que cae desde la superficie.
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 3.0
	shaft_mesh.bottom_radius = 7.0
	shaft_mesh.height = 26.0
	shaft_mesh.radial_segments = 12
	var shaft_mat := StandardMaterial3D.new()
	shaft_mat.albedo_color = Color(0.55, 0.86, 1.0, 0.055)
	shaft_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shaft_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shaft_mesh.material = shaft_mat
	for pos in [Vector3(-18, -12, -30), Vector3(12, -11, -55), Vector3(2, -10, -90)]:
		var shaft := MeshInstance3D.new()
		shaft.mesh = shaft_mesh
		shaft.position = pos
		add_child(shaft)
		shafts.append(shaft)


func _process(delta: float) -> void:
	var under: bool = main.playing and player.position.y < 0.0
	for p in dust:
		p.visible = under
		p.position.y += sin(Time.get_ticks_msec() * 0.001 + p.position.x) * delta * 0.08
		if p.position.distance_to(player.position) > 38.0:
			p.position = player.position + Vector3(randf_range(-24.0, 24.0), randf_range(-15.0, 15.0), randf_range(-24.0, 24.0))
	for shaft in shafts:
		shaft.visible = under and player.position.y > -30.0
		shaft.rotation.y += delta * 0.015

	bubble_wait -= delta
	if under and bubble_wait <= 0.0:
		bubble_wait = randf_range(0.18, 0.4)
		var b := bubbles[bubble_cursor]
		b.position = main.cam.global_transform * Vector3(randf_range(-0.1, 0.1), -0.4, -0.75)  # justo bajo la boca, a la vista
		b.scale = Vector3.ONE * randf_range(0.25, 0.55)  # tan cerca del visor, más pequeñas
		b.visible = true
		bubble_age[bubble_cursor] = 0.0
		bubble_cursor = (bubble_cursor + 1) % BUBBLE_COUNT
	for i in bubbles.size():
		if not bubbles[i].visible:
			continue
		bubble_age[i] += delta
		bubbles[i].position += Vector3(sin(bubble_age[i] * 4.0 + i) * delta * 0.12, delta * 1.5, 0)
		if bubble_age[i] > 2.4 or bubbles[i].position.y > 0.15:
			bubbles[i].visible = false
