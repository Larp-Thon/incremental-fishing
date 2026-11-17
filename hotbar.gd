extends HBoxContainer
# Barra de herramientas: una ranura por objeto del equipo, con su tecla y su estado.
# Solo aparecen las que ya tienes; la que está en uso se resalta.

var main: Node
var slots := {}  # id -> {panel, style, label}


func setup(owner_node: Node) -> void:
	main = owner_node
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	offset_top = -112.0
	offset_bottom = -72.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)
	for id in ["harpoon", "sonar", "lamp", "vehicle"]:
		var style := StyleBoxFlat.new()
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 18)
		panel.add_child(label)
		add_child(panel)
		slots[id] = {panel = panel, style = style, label = label}


func slot(id: String, owned: bool, text: String, active: bool, color: Color) -> void:
	var s: Dictionary = slots[id]
	s.panel.visible = owned
	s.label.text = text
	s.label.modulate = Color.WHITE if active else Color(0.7, 0.78, 0.82)
	s.style.bg_color = Color(color, 0.28) if active else Color(0.03, 0.06, 0.09, 0.7)
	s.style.border_color = color if active else Color(0.3, 0.38, 0.44)


func _process(_delta: float) -> void:
	visible = main.playing
	if not visible:
		return
	slot("harpoon", true, "[%s] Arpón" % main.key_name("tool1"), main.tool == 0, main.CYAN)
	# Mientras hay balizas activas la ranura muestra cuánto les queda; si no, la recarga.
	var left: float = maxf(main.sonar_system.remaining, main.sonar_system.wait)
	slot("sonar", main.lvl("sonar") > 0, "[%s] Sonar%s" % [main.key_name("tool2"), " · %d s" % ceili(left) if left > 0.0 else ""], main.tool == 1, main.CYAN)
	slot("lamp", main.lvl("lamp") > 0, "[%s] Linterna %s" % [main.key_name("lamp"), "ON" if main.lamp_on else "OFF"], main.lamp_on, main.AMBER)
	var charge: float = main.vehicle_battery / main.max_vehicle_battery() * 100.0
	slot("vehicle", main.lvl("scooter") > 0, "[%s] %s %d%%" % [main.key_name("vehicle"), "Sub" if main.lvl("sub") > 0 else "Scooter", charge], main.vehicle_active, main.GREEN if charge > 25.0 else main.RED)
