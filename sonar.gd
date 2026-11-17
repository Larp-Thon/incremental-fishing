extends Node
# Sonar de mano: herramienta del inventario. En su pantalla se elige una especie (ordenadas por
# zona) y salen sondas que se pegan a los ejemplares más cercanos como balizas (sin texto en pantalla). Una captura o un respawn
# invalida la marca: cada contacto recuerda la "generation" del pez.
const GEAR := preload("res://vehicle.gd")
const ZONES := ["Bajío", "Algas", "Roquedal", "Jardín", "Fumarolas", "Fosa"]
const COOLDOWN := 3.0

var main: Node
var contacts: Array = []  # {fish = WeakRef, generation, probe, stuck}
var remaining := 0.0
var wait := 0.0  # segundos hasta poder lanzar otra vez
var device := Node3D.new()
var panel := PanelContainer.new()
var subtitle := Label.new()
var zone_titles: Array[Label] = []
var buttons := {}  # índice de SPECIES -> Button
var probe_mesh := SphereMesh.new()


func setup(owner_node: Node) -> void:
	main = owner_node
	var hud: Node = main.get_node("HUD")
	probe_mesh.radius = 0.14
	probe_mesh.height = 0.28
	probe_mesh.radial_segments = 8
	probe_mesh.rings = 4
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.8, 0.25)
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.no_depth_test = true  # la baliza se ve a través de rocas y algas
	probe_mesh.material = glow

	# Dispositivo en la mano: carcasa, pantalla encendida, antena y empuñadura.
	device.position = Vector3(0.27, -0.23, -0.6)
	device.rotation = Vector3(-0.25, -0.2, 0.0)
	device.visible = false
	main.player.add_child(device)
	GEAR.part(device, GEAR.box(Vector3(0.21, 0.14, 0.04)), Vector3.ZERO, Color(0.13, 0.15, 0.19))
	GEAR.part(device, GEAR.box(Vector3(0.17, 0.09, 0.01)), Vector3(0, 0.012, 0.02), Color(0.2, 0.9, 1.0), 1.6)
	GEAR.part(device, GEAR.box(Vector3(0.05, 0.14, 0.04)), Vector3(0, -0.13, 0), Color(0.95, 0.42, 0.14))
	GEAR.part(device, GEAR.box(Vector3(0.012, 0.16, 0.012)), Vector3(0.085, 0.14, 0), Color(0.75, 0.78, 0.8))
	GEAR.part(device, GEAR.ball(0.018), Vector3(0.085, 0.23, 0), Color(1.0, 0.8, 0.25), 3.0)

	build_panel(hud)
	clear()


func build_panel(hud: Node) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.09, 0.13, 0.94)
	style.border_color = Color(0.2, 0.9, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	hud.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "SONAR · elige qué rastrear"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	box.add_child(title)
	subtitle.add_theme_font_size_override("font_size", 18)
	box.add_child(subtitle)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)
	for zone in ZONES.size():
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 230
		grid.add_child(column)
		var zone_title := Label.new()
		zone_title.add_theme_font_size_override("font_size", 20)
		column.add_child(zone_title)
		zone_titles.append(zone_title)
		for id in main.SPECIES.size():
			if main.SPECIES[id].zone != zone:
				continue
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size.y = 34
			b.add_theme_color_override("font_color", main.RARITY[main.SPECIES[id].rarity])
			b.pressed.connect(launch.bind(id))
			column.add_child(b)
			buttons[id] = b
	var close_button := Button.new()
	close_button.text = "Guardar sonar (clic derecho o Esc)"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	box.add_child(close_button)


func open() -> void:
	if wait > 0.0:
		main.show_toast("Sonar recargando · %.0f s" % ceilf(wait), main.AMBER)
		return
	var level: int = main.lvl("sonar")
	subtitle.text = "Lanza %d %s a los ejemplares más cercanos · marca %d s" % [level, "sonda" if level == 1 else "sondas", duration()]
	var here: int = main.current_zone()
	for zone in ZONES.size():
		zone_titles[zone].text = "%d · %s%s" % [zone + 1, ZONES[zone], "  (estás aquí)" if zone == here else ""]
		zone_titles[zone].modulate = main.CYAN if zone == here else Color(0.7, 0.8, 0.85)
	for id in buttons:
		var s: Dictionary = main.SPECIES[id]
		buttons[id].visible = main.event == "night" or not s.get("night", false)  # las nocturnas, solo si han salido
		var trend := int(round(100.0 * main.prices[id] / float(s.value))) - 100
		buttons[id].text = "%s%s · %d monedas (%+d%%)" % ["★ " if id == main.contract_id else "", s.name, main.prices[id], trend]
	panel.move_to_front()  # por encima de la barra de herramientas
	panel.show()
	main.player.locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not panel.visible:
		return
	panel.hide()
	if main.playing:
		main.player.locked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func duration() -> int:
	return 15 + 5 * main.lvl("sonar")


# Lanza una sonda a cada uno de los ejemplares más cercanos de la especie (1 por nivel).
func launch(id: int) -> void:
	close()
	clear_marks()
	var from: Vector3 = main.player.global_position
	var found: Array = get_tree().get_nodes_in_group("fish").filter(func(f): return f.species_id == id and not f.hooked)
	found.sort_custom(func(a, b): return a.global_position.distance_squared_to(from) < b.global_position.distance_squared_to(from))
	for fish in found.slice(0, main.lvl("sonar")):
		var probe := MeshInstance3D.new()
		probe.mesh = probe_mesh
		add_child(probe)
		probe.global_position = from - main.player.global_basis.z
		contacts.append({fish = weakref(fish), generation = fish.generation, probe = probe, stuck = false})
	remaining = duration()
	wait = COOLDOWN
	main.sfx.play("ping")
	main.show_toast("Sondas lanzadas: %s x%d" % [main.SPECIES[id].name, contacts.size()] if not contacts.is_empty() else "Sin señal de %s" % main.SPECIES[id].name, main.CYAN)


func clear_marks() -> void:
	for contact in contacts:
		contact.probe.queue_free()
	contacts.clear()
	remaining = 0.0


func clear() -> void:
	clear_marks()
	close()
	wait = 0.0


# Antes que el menú de pausa: Esc o clic derecho guardan el sonar.
func _input(event: InputEvent) -> void:
	if panel.visible and (event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not main:
		return
	wait = maxf(0.0, wait - delta)
	device.visible = main.playing and main.tool == 1
	if contacts.is_empty():
		return
	remaining -= delta
	if remaining <= 0.0 or not main.playing:
		clear_marks()
		return
	for contact in contacts:
		var fish = contact.fish.get_ref()
		var probe: MeshInstance3D = contact.probe
		probe.visible = is_instance_valid(fish) and fish.generation == contact.generation and not fish.hooked
		if not probe.visible:
			continue
		if not contact.stuck:  # la sonda aún viaja hacia el pez
			probe.global_position = probe.global_position.move_toward(fish.global_position, 45.0 * delta)
			contact.stuck = probe.global_position.distance_to(fish.global_position) < 0.4
			continue
		probe.global_position = fish.global_position + Vector3.UP * 0.6
		probe.scale = Vector3.ONE * (1.0 + 0.35 * sin(Time.get_ticks_msec() * 0.008))
