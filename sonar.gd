extends Node
# Cada barrido conserva la identidad de la captura; un respawn invalida su marca.
const ZONES := ["Bajío", "Algas", "Roquedal", "Jardín", "Fumarolas", "Fosa"]
var main: Node
var contacts: Array = []
var remaining := 0.0
var overview: Label
var marks: Array[Label] = []

func setup(owner_node: Node) -> void:
	main = owner_node
	overview = Label.new()
	overview.position = Vector2(190, 95)
	overview.add_theme_font_size_override("font_size", 15)
	overview.add_theme_color_override("font_outline_color", Color.BLACK)
	overview.add_theme_constant_override("outline_size", 4)
	overview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.get_node("HUD").add_child(overview)
	for i in 3:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(1, 0.82, 0.3))
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 5)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		main.get_node("HUD").add_child(label)
		marks.append(label)
	clear()

func clear() -> void:
	contacts.clear()
	remaining = 0.0
	if overview:
		overview.hide()
	for label in marks:
		label.hide()

func ranked(fishes: Array, zone: int) -> Array:
	var result: Array = []
	for fish in fishes:
		if fish.zone == zone and not fish.hooked and fish.species.value > 0:
			result.append(fish)
	result.sort_custom(func(a, b): return main.sale_price(a) > main.sale_price(b))
	return result

func scan() -> void:
	clear()
	if main.lvl("sonar") == 0 or not main.playing:
		return
	var fishes: Array = get_tree().get_nodes_in_group("fish")
	for zone in 6:
		for fish in ranked(fishes, zone).slice(0, main.lvl("sonar")):
			contacts.append({fish = weakref(fish), generation = fish.generation, zone = zone})
	remaining = 5.0 + main.lvl("sonar") * 2.0
	main.sfx.play("ping")

func _process(delta: float) -> void:
	if not main:
		return
	for label in marks:
		label.hide()
	overview.visible = main.playing and main.player.position.y < 0.0 and main.lvl("sonar") > 0
	if not overview.visible:
		return
	remaining = maxf(0.0, remaining - delta)
	var current: int = main.current_zone()
	overview.text = "SONAR · [%s] barrer · auto %.0f s\nMejor captura por zona" % [main.key_name("sonar"), main.sonar_cooldown]
	var shown := 0
	for zone in 6:
		var best = null
		for contact in contacts:
			var fish = contact.fish.get_ref()
			if remaining <= 0.0 or not is_instance_valid(fish) or fish.generation != contact.generation or fish.hooked or contact.zone != zone:
				continue
			if best == null:
				best = fish
			if zone != current or shown >= marks.size():
				continue
			var label: Label = marks[shown]
			var behind: bool = main.cam.is_position_behind(fish.global_position)
			var screen: Vector2 = main.cam.unproject_position(fish.global_position) if not behind else Vector2(575, 115)
			var viewport_size: Vector2 = main.get_viewport().get_visible_rect().size
			screen.x = clampf(screen.x, 190.0, viewport_size.x - 380.0)
			screen.y = clampf(screen.y, 130.0 + shown * 50.0, viewport_size.y - 220.0)
			label.position = screen
			label.text = "%s %s · %d monedas\n%.0f m · %s%s" % [
				"Gira hacia atrás:" if behind else "◆", fish.species.name, main.sale_price(fish),
				main.player.position.distance_to(fish.position), fish.catch_quality, " · oculto" if fish.hidden else ""]
			label.show()
			shown += 1
		overview.text += "\n%s %s: %s" % [
			">" if zone == current else " ", ZONES[zone],
			"%s · %d" % [best.species.name, main.sale_price(best)] if best != null else "sin señal"]

