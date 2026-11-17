extends CharacterBody3D
# Primera persona: el cuerpo es el buzo (esfera con colisión) y la cámara va dentro.

const MAX_Y := 1.2  # cuánto puedes asomarte fuera del agua

var locked := false  # la terminal abierta bloquea el control
var sens := 0.003
var kick := 0.0  # retroceso del disparo (1 = recién disparado)
var shake := 0.0  # sacudida de la cámara

@onready var main := get_parent()
@onready var cam: Camera3D = $Camera


func _unhandled_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * sens
		rotation.x = clampf(rotation.x - event.relative.y * sens, -1.5, 1.5)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# En _process y no en _physics_process: el arpón y la cámara se leen cada frame y así no hay tirones.
func _process(delta: float) -> void:
	var wish := Vector3.ZERO
	if not locked:
		wish = basis * Vector3(Input.get_axis("left", "right"), 0.0, Input.get_axis("forward", "back"))
		wish.y += Input.get_axis("down", "up")
	# El lerp da la inercia del agua: tardas en arrancar y en frenar.
	velocity = velocity.lerp(wish.limit_length(1.0) * main.swim_speed(), 3.0 * delta)
	if not locked and main.hazards:
		velocity += main.hazards.current_force * delta * 3.0
	var before := position
	move_and_slide()
	# Red de seguridad además de la colisión: no se sube por las paredes (por ejes, para poder
	# deslizarse a lo largo de ellas) y altura mínima sobre el fondo.
	if main.world.wall(position.x, before.z) > 0.08:
		position.x = before.x
	if main.world.wall(position.x, position.z) > 0.08:
		position.z = before.z
	position.y = clampf(position.y, main.world.floor_y(position.x, position.z) + 0.7, MAX_Y)
	# Retroceso y sacudida: solo se mueve la cámara, no el cuerpo.
	kick = lerpf(kick, 0.0, 9.0 * delta)
	shake = lerpf(shake, 0.0, 8.0 * delta)
	cam.rotation.x = kick * 0.04
	cam.position = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * shake * 0.03
