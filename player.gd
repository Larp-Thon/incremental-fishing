extends CharacterBody3D
# Primera persona: el cuerpo es el buzo (esfera con colisión) y la cámara va dentro.

const MAX_Y := 1.2  # cuánto puedes asomarte fuera del agua

var locked := false  # la terminal abierta bloquea el control
var sens := 0.003

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
	move_and_slide()
	# Red de seguridad además de la colisión: límites del cañón y altura mínima sobre el fondo.
	position.x = clampf(position.x, -63.0, 63.0)
	position.z = clampf(position.z, -253.0, 53.0)
	position.y = clampf(position.y, main.world.floor_y(position.x, position.z) + 0.7, MAX_Y)
