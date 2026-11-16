extends Node3D
# Bucle: cada día dura lo que dure el oxígeno (solo se gasta bajo el agua).
# Al acabar el día se vende la captura, se compran mejoras y empieza el siguiente.
# El mar se divide en zonas de profundidad; el traje decide hasta cuál aguantas la presión.

const FISH := preload("res://fish.gd")
const ZONE := 20.0  # metros por zona
const ZONES := 6
const MAX_DEPTH := ZONE * ZONES
const SHALLOW := Color(0.1, 0.55, 0.7)
const DEEP := Color(0.0, 0.01, 0.04)
const START := Vector3(0, 0.8, 0)
const POWER_SECONDS := 8.0
const SPEED_BOOST := 1.8
const LOW_OXYGEN := 8.0  # segundos a partir de los que el oxígeno parpadea
const BASE_SUPPORT := 3.0  # atm que aguanta el traje inicial (20 m: toda la zona 1)
const SUIT_STEP := 0.4  # atm de soporte por nivel de traje: 5 niveles = una zona más
const CRUSH_OVER := 2.0  # atm por encima del soporte a partir de las que salta el aviso grande
const SUIT_BASE_COST := [30, 150, 450, 1300, 4000]  # coste base de cada tramo de 5 niveles

const CYAN := Color(0.35, 0.85, 1.0)
const GREEN := Color(0.4, 0.9, 0.5)
const AMBER := Color(1.0, 0.75, 0.2)
const RED := Color(1.0, 0.3, 0.3)
# Color del casco según el nivel del traje.
const SUIT_COLORS := [Color(0.8, 0.6, 0.25), Color(0.85, 0.45, 0.2), Color(0.6, 0.65, 0.7), Color(0.3, 0.55, 0.75), Color(0.5, 0.4, 0.8), Color(0.9, 0.9, 0.95)]

const RARITY := {
	"Común": Color(0.85, 0.85, 0.85),
	"Poco común": Color(0.4, 0.9, 0.4),
	"Raro": Color(0.4, 0.65, 1.0),
	"Épico": Color(0.8, 0.45, 1.0),
	"Legendario": Color(1.0, 0.75, 0.2),
	"Especial": Color(0.4, 1.0, 1.0),
}

# zone: zona (0-5) donde vive, cerca del fondo; -1 = cualquiera. big: escala. count: cuántos hay.
# power: efecto instantáneo al pescarlo (no se vende).
const SPECIES := [
	{name = "Anchoa", rarity = "Común", value = 1, zone = 0, color = Color(0.6, 0.78, 0.75), big = 0.45, glow = 0.0, count = 24},
	{name = "Sardina", rarity = "Común", value = 1, zone = 0, color = Color(0.75, 0.8, 0.85), big = 0.6, glow = 0.0, count = 26},
	{name = "Jurel", rarity = "Común", value = 2, zone = 0, color = Color(0.4, 0.6, 0.5), big = 0.8, glow = 0.0, count = 16},
	{name = "Dorada", rarity = "Común", value = 5, zone = 1, color = Color(0.95, 0.8, 0.3), big = 0.9, glow = 0.0, count = 20},
	{name = "Pez loro", rarity = "Poco común", value = 8, zone = 1, color = Color(0.2, 0.8, 0.7), big = 1.0, glow = 0.0, count = 16},
	{name = "Pez globo", rarity = "Poco común", value = 16, zone = 2, color = Color(0.95, 0.6, 0.4), big = 1.1, glow = 0.1, count = 18},
	{name = "Barracuda", rarity = "Poco común", value = 24, zone = 2, color = Color(0.5, 0.6, 0.75), big = 1.6, glow = 0.1, count = 14},
	{name = "Pez linterna", rarity = "Raro", value = 50, zone = 3, color = Color(0.3, 0.5, 1.0), big = 0.8, glow = 1.0, count = 16},
	{name = "Morena", rarity = "Raro", value = 70, zone = 3, color = Color(0.45, 0.6, 0.25), big = 1.8, glow = 0.4, count = 12},
	{name = "Rape abisal", rarity = "Épico", value = 150, zone = 4, color = Color(0.7, 0.3, 0.9), big = 1.3, glow = 0.7, count = 14},
	{name = "Calamar vampiro", rarity = "Épico", value = 200, zone = 4, color = Color(0.9, 0.2, 0.3), big = 1.5, glow = 0.7, count = 10},
	{name = "Pez dragón", rarity = "Épico", value = 350, zone = 5, color = Color(0.2, 0.9, 0.6), big = 1.4, glow = 0.9, count = 12},
	{name = "Celacanto", rarity = "Legendario", value = 900, zone = 5, color = Color(1.0, 0.75, 0.2), big = 2.0, glow = 0.6, count = 3},
	# Powerups: siempre disponibles, escasos.
	{name = "Pez burbuja", rarity = "Especial", value = 0, zone = -1, color = Color(0.5, 1.0, 1.0), big = 0.7, glow = 1.5, count = 5, power = "air"},
	{name = "Pez rayo", rarity = "Especial", value = 0, zone = -1, color = Color(1.0, 1.0, 0.3), big = 0.7, glow = 1.5, count = 5, power = "speed"},
]

var upgrades := {
	tank = {name = "Tanque de oxígeno", desc = "+6 s de día", base = 10, growth = 1.6, level = 0},
	fins = {name = "Aletas", desc = "+1 m/s nadando", base = 15, growth = 1.7, level = 0},
	reach = {name = "Sedal", desc = "+4 m de alcance del arpón", base = 12, growth = 1.6, level = 0},
	reel = {name = "Carrete", desc = "+25% velocidad de disparo y recogida", base = 20, growth = 1.7, level = 0},
	suit = {name = "Traje de presión", desc = "", base = 30, growth = 3.0, level = 0, max = (ZONES - 1) * 5},
}
var day := 0
var playing := false
var coins := 0
var bag := {}  # índice de SPECIES -> cantidad pescada hoy
var mats := [0, 0, 0, 0, 0]  # materiales de traje sin gastar, por zona (world.MATERIALS)
var oxygen := 0.0
var air_time := 0.0  # powerup: segundos restantes sin gastar oxígeno
var speed_time := 0.0  # powerup: segundos restantes de velocidad extra
var buttons := {}
var fish_mesh := SphereMesh.new()
var toast_tween: Tween

@onready var player: Camera3D = $Player
@onready var harpoon: Node3D = $Harpoon
@onready var station: Node3D = $Station
@onready var world: Node3D = $World
@onready var mats_label: Label = $HUD/Mats
@onready var sun: DirectionalLight3D = $Sun
@onready var env: Environment = $WorldEnvironment.environment
@onready var helmet: ColorRect = $HUD/Helmet
@onready var gauge: Control = $HUD/DepthGauge
@onready var info: Label = $HUD/Console/Info
@onready var oxygen_label: Label = $HUD/Console/OxygenLabel
@onready var oxygen_bar: ProgressBar = $HUD/Console/Oxygen
@onready var oxygen_fill: StyleBoxFlat = oxygen_bar.get_theme_stylebox("fill")
@onready var pressure_label: Label = $HUD/Console/PressureLabel
@onready var pressure_bar: ProgressBar = $HUD/Console/Pressure
@onready var pressure_fill: StyleBoxFlat = pressure_bar.get_theme_stylebox("fill")
@onready var warning: Label = $HUD/Alerts/Warning
@onready var status: Label = $HUD/Alerts/Status
@onready var power: Label = $HUD/Alerts/Power
@onready var toast: Label = $HUD/Toast
@onready var prompt: Label = $HUD/Prompt
@onready var marker: Label = $HUD/Marker
@onready var bag_label: RichTextLabel = $HUD/Bag
@onready var shop: PanelContainer = $HUD/Shop
@onready var summary_page: VBoxContainer = $HUD/Shop/Margin/Summary
@onready var summary_title: Label = $HUD/Shop/Margin/Summary/Title
@onready var summary_list: RichTextLabel = $HUD/Shop/Margin/Summary/List
@onready var upgrades_page: VBoxContainer = $HUD/Shop/Margin/Upgrades
@onready var upgrades_title: Label = $HUD/Shop/Margin/Upgrades/Title
@onready var start_button: Button = $HUD/Shop/Margin/Upgrades/Start


func lvl(id: String) -> int:
	return upgrades[id].level


func cost(id: String) -> int:
	if id == "suit":  # cada tramo de 5 niveles (una zona) es mucho más caro que el anterior
		return int(SUIT_BASE_COST[suit_tier()] * pow(1.3, lvl("suit") % 5))
	return int(upgrades[id].base * pow(upgrades[id].growth, upgrades[id].level))


# Tramo del traje: decide qué material pide la siguiente mejora (0 = perlas de la zona 1...).
func suit_tier() -> int:
	return mini(lvl("suit") / 5, SUIT_BASE_COST.size() - 1)


func can_buy(id: String) -> bool:
	return not maxed(id) and coins >= cost(id) and (id != "suit" or mats[suit_tier()] > 0)


func maxed(id: String) -> bool:
	return lvl(id) >= upgrades[id].get("max", 999)


func max_oxygen() -> float:
	return 30.0 + 6.0 * lvl("tank")


func reach() -> float:
	return 12.0 + 4.0 * lvl("reach")


func swim_speed() -> float:
	return (6.0 + lvl("fins")) * (SPEED_BOOST if speed_time > 0.0 else 1.0)


func pressure(depth: float) -> float:
	return 1.0 + depth / 10.0


# Presión (atm) que el traje aguanta sin gastar oxígeno de más.
func support() -> float:
	return BASE_SUPPORT + SUIT_STEP * lvl("suit")


# Multiplicador de gasto de oxígeno: crece cada vez más rápido al superar el soporte del traje.
func oxygen_drain(depth: float) -> float:
	var over := maxf(pressure(depth) - support(), 0.0)
	return 1.0 + over + 0.5 * over * over


func bag_value() -> int:
	var total := 0
	for id in bag:
		total += SPECIES[id].value * bag[id]
	return total


func near_station() -> bool:
	var d := player.position - station.position
	return Vector2(d.x, d.z).length() < 6.0 and d.y > -3.0


func _ready() -> void:
	assert(oxygen_drain(ZONE) == 1.0 and is_equal_approx(oxygen_drain(ZONE * 2.0), 5.0))

	fish_mesh.radial_segments = 8
	fish_mesh.rings = 4
	var fish_mat := ShaderMaterial.new()
	fish_mat.shader = preload("res://fish.gdshader")
	fish_mesh.material = fish_mat

	for id in upgrades:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(buy.bind(id))
		$HUD/Shop/Margin/Upgrades/Buttons.add_child(b)
		buttons[id] = b
	$HUD/Shop/Margin/Summary/Next.pressed.connect(show_upgrades)
	start_button.pressed.connect(start_day)
	gauge.zones = ZONES
	gauge.zone_size = ZONE
	start_day()

	# Solo para capturas automáticas: godot -- cam=x,y,z,pitch,yaw (grados) | catch | end | shop
	for a in OS.get_cmdline_user_args():
		if a.begins_with("cam="):
			var v := a.trim_prefix("cam=").split_floats(",")
			player.position = Vector3(v[0], v[1], v[2])
			player.rotation_degrees = Vector3(v[3], v[4], 0.0)
		elif a == "catch":
			for f in get_tree().get_nodes_in_group("fish").slice(20, 32):
				catch_fish(f)
			catch_fish(get_tree().get_nodes_in_group("fish")[-1])
		elif a == "end":
			end_day()
		elif a == "shop":
			show_upgrades()


func spawn_fish() -> void:
	for f in get_tree().get_nodes_in_group("fish"):
		f.free()
	for id in SPECIES.size():
		for i in SPECIES[id].count:
			var f: MeshInstance3D = FISH.new()
			f.mesh = fish_mesh
			f.species_id = id
			f.species = SPECIES[id]
			add_child(f)


func start_day() -> void:
	day += 1
	oxygen = max_oxygen()
	air_time = 0.0
	speed_time = 0.0
	bag.clear()
	refresh_bag()
	spawn_fish()
	harpoon.reset()
	player.position = START
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.locked = false
	shop.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	helmet.material.set_shader_parameter("rim_color", SUIT_COLORS[lvl("suit") / 5])
	playing = true
	show_toast("Día %d" % day, Color.WHITE)


func end_day() -> void:
	playing = false
	harpoon.reset()  # un pez que aún venía por el sedal no cuenta
	air_time = 0.0
	speed_time = 0.0
	if toast_tween:
		toast_tween.kill()
	toast.modulate.a = 0.0
	player.locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var earned := bag_value()
	coins += earned
	var ids := bag.keys()
	ids.sort()
	var text := "[table=4]"
	for id in ids:
		var s: Dictionary = SPECIES[id]
		var color: String = RARITY[s.rarity].to_html(false)
		text += "[cell padding=0,0,28,6][color=#%s]%s[/color][/cell]" % [color, s.name]
		text += "[cell padding=0,0,28,6][color=#%s]%s[/color][/cell]" % [color, s.rarity]
		text += "[cell padding=0,0,28,6]x%d[/cell]" % bag[id]
		text += "[cell padding=0,0,0,6]%d monedas[/cell]" % (s.value * bag[id])
	text += "[/table]\n"
	if bag.is_empty():
		text = "No pescaste nada hoy.\n"
	summary_title.text = "Fin del día %d" % day
	summary_list.text = text + "\nTotal vendido: %d monedas\nTienes: %d monedas" % [earned, coins]
	bag.clear()
	refresh_bag()
	upgrades_page.hide()
	summary_page.show()
	shop.show()


func show_upgrades() -> void:
	summary_page.hide()
	upgrades_page.show()
	refresh_shop()


func buy(id: String) -> void:
	if can_buy(id):
		coins -= cost(id)
		if id == "suit":
			mats[suit_tier()] -= 1
		upgrades[id].level += 1
		refresh_shop()


func refresh_shop() -> void:
	upgrades_title.text = "Mejoras  ·  %d monedas" % coins
	start_button.text = "Iniciar día %d" % (day + 1)
	for id in buttons:
		var b: Button = buttons[id]
		b.disabled = not can_buy(id)
		if maxed(id):
			b.text = "%s  (nivel máximo)\nAguanta todas las zonas" % upgrades[id].name
		elif id == "suit":
			var m: String = world.MATERIALS[suit_tier()].name
			b.text = "Traje de presión  (nivel %d)  ·  aguanta %.1f atm (%d m)\n+%.1f atm  ·  %d monedas + 1 %s (tienes %d)" % [
				lvl(id) + 1, support(), (support() - 1.0) * 10.0, SUIT_STEP, cost(id), m, mats[suit_tier()]]
		else:
			b.text = "%s  (nivel %d)\n%s  ·  %d monedas" % [upgrades[id].name, lvl(id) + 1, upgrades[id].desc, cost(id)]


func show_toast(text: String, color: Color) -> void:
	toast.text = text
	toast.modulate = color
	if toast_tween:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(1.8)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.6)


func catch_fish(fish: Node) -> void:
	var s: Dictionary = fish.species
	match s.get("power", ""):
		"air":
			air_time = POWER_SECONDS
			show_toast("%s\nAire infinito %d s" % [s.name, POWER_SECONDS], RARITY[s.rarity])
		"speed":
			speed_time = POWER_SECONDS
			show_toast("%s\nVelocidad x%.1f durante %d s" % [s.name, SPEED_BOOST, POWER_SECONDS], RARITY[s.rarity])
		_:
			bag[fish.species_id] = bag.get(fish.species_id, 0) + 1
			show_toast("%s\n%s  ·  %d monedas" % [s.name, s.rarity, s.value], RARITY[s.rarity])
			refresh_bag()
	fish.respawn()


func refresh_bag() -> void:
	bag_label.visible = not bag.is_empty()
	var ids := bag.keys()
	ids.sort()
	var text := "Captura\n"
	for id in ids:
		var s: Dictionary = SPECIES[id]
		text += "[color=#%s]%s[/color]  x%d\n" % [RARITY[s.rarity].to_html(false), s.name, bag[id]]
	bag_label.text = text + "\nValor: %d monedas" % bag_value()


func _unhandled_input(event: InputEvent) -> void:
	if playing and near_station() and event is InputEventKey and event.pressed \
			and not event.echo and event.physical_keycode == KEY_E:
		end_day()


func _process(delta: float) -> void:
	var y := player.position.y
	var depth := maxf(-y, 0.0)
	var drain := oxygen_drain(depth)
	var over := pressure(depth) - support()
	if playing:
		air_time = maxf(air_time - delta, 0.0)
		speed_time = maxf(speed_time - delta, 0.0)
		if y < 0.0 and air_time <= 0.0:
			oxygen -= delta * drain
			if oxygen <= 0.0:
				end_day()
		# Materiales del traje: se recogen al tocarlos y no reaparecen.
		for p in world.pickups:
			if p.position.distance_to(player.position) < 2.5:
				var zone: int = p.get_meta("zone")
				mats[zone] += 1
				world.pickups.erase(p)
				p.queue_free()
				var m: Dictionary = world.MATERIALS[zone]
				show_toast("%s\nMaterial para mejorar el traje  ·  tienes %d" % [m.name, mats[zone]], m.color)
				break

	# Bajo el agua: color de fondo + niebla, y cada vez menos luz. Fuera: cielo y sin niebla.
	var under := y < 0.0
	if under != env.fog_enabled:
		env.fog_enabled = under
		env.background_mode = Environment.BG_COLOR if under else Environment.BG_SKY
	var t := clampf(depth / MAX_DEPTH, 0.0, 1.0)
	var c := SHALLOW.lerp(DEEP, sqrt(t))
	env.background_color = c
	env.fog_light_color = c
	env.ambient_light_energy = lerpf(0.6, 0.12, t)
	sun.light_energy = lerpf(1.0, 0.05, t)

	# Casco: oxígeno, presión y zonas.
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.25
	var low := playing and oxygen < LOW_OXYGEN and blink
	var state := GREEN if over <= 0.0 else (AMBER if over < CRUSH_OVER else RED)
	info.text = "Día %d  ·  %d monedas" % [day, coins]
	oxygen_label.text = "O2 %ds" % ceili(maxf(oxygen, 0.0))
	oxygen_label.modulate = RED if low else Color.WHITE
	oxygen_fill.bg_color = RED if low else CYAN
	oxygen_bar.max_value = max_oxygen()
	oxygen_bar.value = oxygen
	pressure_bar.max_value = support() + CRUSH_OVER  # barra llena = el oxígeno se funde
	pressure_bar.value = pressure(depth)
	pressure_fill.bg_color = state
	pressure_label.text = "Presión %.1f / %.1f atm" % [pressure(depth), support()]
	pressure_label.modulate = state if over > 0.0 else Color.WHITE
	gauge.depth = depth
	gauge.safe_depth = (support() - 1.0) * 10.0
	gauge.crush_depth = gauge.safe_depth + CRUSH_OVER * 10.0

	warning.visible = playing and over >= CRUSH_OVER
	warning.modulate.a = 1.0 if blink else 0.45
	status.visible = playing and over > 0.0 and over < CRUSH_OVER
	status.text = "Resistencia de presión baja: gastas oxígeno x%.1f" % drain
	power.visible = air_time > 0.0 or speed_time > 0.0
	power.text = ""
	if air_time > 0.0:
		power.text += "Aire infinito %ds   " % ceili(air_time)
	if speed_time > 0.0:
		power.text += "Velocidad extra %ds" % ceili(speed_time)
	mats_label.text = ""
	for i in mats.size():
		if mats[i] > 0:
			mats_label.text += "%s x%d\n" % [world.MATERIALS[i].name, mats[i]]

	prompt.visible = playing and near_station()
	var target := station.position + Vector3.UP
	marker.visible = playing and not near_station() and not player.is_position_behind(target)
	if marker.visible:
		marker.position = player.unproject_position(target)
		marker.text = "◆ Estación %dm" % player.position.distance_to(target)
