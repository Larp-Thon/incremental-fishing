extends PanelContainer
# Menú principal, pausa y opciones en un solo panel (Esc lo abre y lo cierra).

const ACTIONS := {forward = "Avanzar", back = "Retroceder", left = "Izquierda", right = "Derecha", up = "Subir", down = "Bajar", use = "Entregar"}
const RESET := "Nueva partida"

static var booted := false  # tras "Nueva partida" la escena se recarga sin volver a pasar por el menú

var waiting := ""  # acción que espera una tecla nueva
var keys := {}
var play := Button.new()
var reset := Button.new()

@onready var main := owner


func _ready() -> void:
	var style := StyleBoxFlat.new()  # opaco: tapa el HUD que queda detrás
	style.bg_color = Color(0.06, 0.1, 0.16)
	style.set_corner_radius_all(10)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Incremental Buceo"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	button(box, play, "Jugar", close)
	slider(box, "Sensibilidad del ratón", "sens", 0.001, 0.008)
	slider(box, "Volumen", "volume", 0.0, 1.0)
	var label := Label.new()
	label.text = "Teclas (clic para cambiar)"
	box.add_child(label)
	var grid := GridContainer.new()
	grid.columns = 3
	box.add_child(grid)
	for action in ACTIONS:
		keys[action] = button(grid, Button.new(), "", rebind.bind(action))
		keys[action].size_flags_horizontal = SIZE_EXPAND_FILL
	button(box, reset, RESET, new_game)
	button(box, Button.new(), "Salir", quit)


func button(parent: Node, b: Button, text: String, action: Callable) -> Button:
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func slider(parent: Node, text: String, key: String, low: float, high: float) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 200
	var s := HSlider.new()
	s.min_value = low
	s.max_value = high
	s.step = (high - low) / 20.0
	s.value = main.settings[key]
	s.size_flags_horizontal = SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(set_setting.bind(key))
	row.add_child(label)
	row.add_child(s)
	parent.add_child(row)


func set_setting(value: float, key: String) -> void:
	main.settings[key] = value
	main.apply_settings()


func boot() -> void:
	if not booted:
		open()


func open() -> void:
	play.text = "Continuar" if booted else "Jugar"
	reset.text = RESET
	refresh_keys()
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	booted = true
	waiting = ""
	hide()
	get_tree().paused = false
	main.save_game()  # guarda las opciones
	if main.playing:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func refresh_keys() -> void:
	for action in keys:
		keys[action].text = "%s: %s" % [ACTIONS[action], "pulsa una tecla…" if action == waiting else main.key_name(action)]


func rebind(action: String) -> void:
	waiting = action
	refresh_keys()


func new_game() -> void:
	if reset.text == RESET:  # primer clic: pedir confirmación
		reset.text = "¿Seguro? Se borra todo el progreso (pulsa otra vez)"
	else:
		booted = true
		main.restart({})


func quit() -> void:
	main.save_game()
	get_tree().quit()


func _input(event: InputEvent) -> void:
	if waiting != "" and event is InputEventKey and event.pressed:
		if event.physical_keycode != KEY_ESCAPE:  # Esc cancela el cambio
			main.bind(waiting, event.physical_keycode)
		waiting = ""
		refresh_keys()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			close()
		else:
			open()
