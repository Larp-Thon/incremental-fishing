extends MeshInstance3D

const MARGIN := 7.0  # se mantienen lejos de rampas y paredes de su zona

var species: Dictionary  # entrada de main.SPECIES
var species_id := 0
var hooked := false  # clavado en el arpón: deja de nadar
var hit_radius := 0.9
var turn := 0.0
var zone := 0

@onready var world: Node3D = get_parent().world


func _ready() -> void:
	add_to_group("fish")
	respawn()


func respawn() -> void:
	hooked = false
	zone = species.zone if species.zone >= 0 else randi() % 6  # zone -1: aparece en cualquier zona
	var big: float = species.big
	hit_radius = 0.5 + 0.4 * big
	# Viven cerca del fondo de su zona.
	position = world.spot(zone) + Vector3.UP * randf_range(3.0, 12.0)
	position.y = minf(position.y, -2.0)
	rotation = Vector3(0.0, randf() * TAU, 0.0)
	scale = Vector3(0.35, 0.6, 1.4) * big
	set_instance_shader_parameter("color", species.color)
	set_instance_shader_parameter("glow", species.glow)
	set_instance_shader_parameter("phase", randf() * TAU)


func _process(delta: float) -> void:
	if hooked:
		return
	if randf() < delta * 0.5:
		turn = randf_range(-1.0, 1.0)
	var d := -position.z
	if absf(position.x) > world.HALF_WIDTH - MARGIN or d < world.BOUNDS[zone] + MARGIN or d > world.BOUNDS[zone + 1] - MARGIN:
		turn = 1.0  # gira hasta volver a su zona
	rotate_y(turn * delta)
	position -= basis.z.normalized() * 2.0 * delta
