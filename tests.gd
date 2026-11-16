extends SceneTree
# Pruebas de las fórmulas de equilibrio. Ejecutar: godot --headless --path . -s tests.gd

var failed := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failed += 1
		printerr("FALLA: ", what)


func _init() -> void:
	var m = load("res://main.gd").new()  # sin escena: solo se usan las fórmulas
	check(m.pressure(0.0) == 1.0 and m.pressure(20.0) == 3.0, "presión = 1 + profundidad / 10")
	check(m.support() == 3.0, "el traje inicial aguanta 3 atm")
	check(m.oxygen_drain(20.0) == 1.0, "sin exceso de presión el gasto es x1")
	check(is_equal_approx(m.oxygen_drain(40.0), 5.0), "2 atm de exceso: 1 + 2 + 0,5·4 = x5")
	check(m.cost("tank") == 10 and m.cost("fins") == 15, "costes base")
	m.upgrades.tank.level = 2
	check(m.cost("tank") == 25 and m.max_oxygen() == 42.0, "tanque nivel 2: 10·1,6² = 25 monedas y 42 s")
	check(m.cost("suit") == 30 and m.suit_tier() == 0, "traje: primer tramo")
	m.upgrades.suit.level = 5
	check(m.cost("suit") == 150 and m.suit_tier() == 1, "traje nivel 5: segundo tramo")
	check(is_equal_approx(m.support(), 5.0), "5 niveles de traje = una zona más (5 atm)")
	m.coins = 1000
	check(not m.can_buy("suit"), "el traje pide material aunque sobren monedas")
	m.mats[1] = 1
	check(m.can_buy("suit"), "con material y monedas se puede comprar el traje")
	m.upgrades.suit.level = m.upgrades.suit.max
	check(m.maxed("suit") and not m.can_buy("suit"), "traje al máximo")
	m.free()
	print("Pruebas: %s" % ("todas pasan" if failed == 0 else "%d fallan" % failed))
	quit(failed)
