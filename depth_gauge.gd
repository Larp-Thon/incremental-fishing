extends Control
# Indicador de profundidad por zonas.
# Cian = tu traje aguanta, ámbar = gastas más oxígeno, rojo = demasiada presión.

var depth := 0.0
var safe_depth := 20.0  # hasta aquí el traje aguanta sin penalización
var crush_depth := 40.0  # a partir de aquí el oxígeno se funde
var zones := 6
var zone_size := 20.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var h := size.y / zones
	var current := mini(int(depth / zone_size), zones - 1)
	for z in zones:
		var color := Color(1.0, 0.75, 0.2)
		if (z + 1) * zone_size <= safe_depth + 0.01:
			color = Color(0.35, 0.85, 1.0)
		elif z * zone_size >= crush_depth - 0.01:
			color = Color(1.0, 0.3, 0.3)
		draw_rect(Rect2(0, z * h + 2, 14, h - 4), Color(color, 0.95 if z == current else 0.4))
		draw_string(font, Vector2(22, z * h + h / 2 + 6), str(z + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(color, 0.9))
	var total := zones * zone_size
	# Marca de hasta dónde aguanta el traje.
	var safe_y := clampf(safe_depth / total, 0.0, 1.0) * size.y
	draw_line(Vector2(-4, safe_y), Vector2(18, safe_y), Color(0.35, 0.85, 1.0), 2.0)
	var y := clampf(depth / total, 0.0, 1.0) * size.y
	draw_colored_polygon([Vector2(-13, y - 7), Vector2(-13, y + 7), Vector2(-1, y)], Color.WHITE)
	draw_string(font, Vector2(44, y + 6), "%d m" % depth, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
