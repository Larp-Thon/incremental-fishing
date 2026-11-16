extends Camera3D
# Primera persona: la cámara es el buzo.
# shortcut: sin colisiones salvo el fondo (atraviesa decorado y estación) y teclas fijas; pasar a CharacterBody3D + InputMap cuando el nado ya se sienta bien.

const MOUSE_SENS := 0.003
const MAX_Y := 1.2  # cuánto puedes asomarte fuera del agua

var velocity := Vector3.ZERO
var locked := false  # la terminal abierta bloquea el control

@onready var main := get_parent()


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * MOUSE_SENS
		rotation.x = clampf(rotation.x - event.relative.y * MOUSE_SENS, -1.5, 1.5)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	var wish := Vector3.ZERO
	if not locked:
		var k := Input.is_physical_key_pressed
		wish = basis * Vector3(float(k.call(KEY_D)) - float(k.call(KEY_A)), 0.0, float(k.call(KEY_S)) - float(k.call(KEY_W)))
		wish.y += float(k.call(KEY_SPACE)) - float(k.call(KEY_CTRL))
	# El lerp da la inercia del agua: tardas en arrancar y en frenar.
	velocity = velocity.lerp(wish.limit_length(1.0) * main.swim_speed(), 3.0 * delta)
	position += velocity * delta
	# Límites del cañón y el fondo (el terreno no tiene colisión física, solo esta altura mínima).
	position.x = clampf(position.x, -63.0, 63.0)
	position.z = clampf(position.z, -253.0, 53.0)
	position.y = clampf(position.y, main.world.floor_y(position.x, position.z) + 0.7, MAX_Y)
