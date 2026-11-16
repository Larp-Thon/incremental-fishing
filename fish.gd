extends MeshInstance3D

const MARGIN := 7.0  # se mantienen lejos de rampas y paredes de su zona

var species: Dictionary  # entrada de main.SPECIES
var species_id := 0
var hooked := false  # clavado en el arpón: deja de nadar
var hit_radius := 0.9
var turn := 0.0
var zone := 0
var fear := 0.0  # segundos que le quedan huyendo del buzo
var leader: Node3D  # cardumen: sigue a este pez
var offset := Vector3.ZERO  # su sitio dentro del cardumen

@onready var main := get_parent()
@onready var world: Node3D = main.world


func _ready() -> void:
	add_to_group("fish")
	respawn()


func respawn() -> void:
	hooked = false
	fear = 0.0
	zone = species.zone if species.zone >= 0 else randi() % 6  # zone -1: aparece en cualquier zona
	var big: float = species.big
	hit_radius = 0.5 + 0.4 * big
	# Viven cerca del fondo de su zona.
	position = world.spot(zone) + Vector3.UP * randf_range(3.0, 12.0)
	position.y = minf(position.y, -2.0)
	if leader:
		offset = Vector3(randf_range(-2.5, 2.5), randf_range(-1.2, 1.2), randf_range(-2.5, 2.5))
		position = leader.position + offset
	rotation = Vector3(0.0, randf() * TAU, 0.0)
	scale = Vector3(0.35, 0.6, 1.4) * big
	set_instance_shader_parameter("color", species.color)
	set_instance_shader_parameter("glow", species.glow)
	set_instance_shader_parameter("phase", randf() * TAU)


func _process(delta: float) -> void:
	if hooked:
		rotation.y += sin(Time.get_ticks_msec() * 0.04) * 10.0 * delta  # forcejea en el sedal
		return
	fear = maxf(fear - delta, 0.0)
	var speed := 2.0
	var want := Vector3.ZERO  # hacia dónde quiere ir; cero = deambular
	var d := -position.z
	if absf(position.x) > world.HALF_WIDTH - MARGIN or d < world.BOUNDS[zone] + MARGIN or d > world.BOUNDS[zone + 1] - MARGIN:
		want = Vector3(-position.x, 0.0, -(world.BOUNDS[zone] + world.BOUNDS[zone + 1]) * 0.5 - position.z)  # vuelve al centro de su zona
	elif fear > 0.0:
		want = position - main.player.position
		speed = 5.5
	elif leader and not leader.hooked:
		want = leader.position + offset - position
		speed = 3.2 if want.length() > 3.0 else 2.0
		if want.length() < 1.0:
			want = -leader.basis.z  # ya en su sitio: nada hacia donde va el guía
	if want == Vector3.ZERO:
		if randf() < delta * 0.5:
			turn = randf_range(-1.0, 1.0)
		rotate_y(turn * delta)
	else:
		rotation.y = lerp_angle(rotation.y, atan2(-want.x, -want.z), 4.0 * delta)
		position.y = clampf(position.y + clampf(want.y, -1.0, 1.0) * speed * 0.5 * delta, world.floor_y(position.x, position.z) + 1.0, -1.5)
	position -= basis.z.normalized() * speed * delta
