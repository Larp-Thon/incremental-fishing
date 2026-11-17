extends Node3D
# Bucle: cada día dura DAY_SECONDS y luego cae la noche (NIGHT_SECONDS) con un cazador suelto.
# El oxígeno solo limita cada inmersión: se gasta bajo el agua y se recarga en la superficie.
# La captura solo se cobra al entregarla en la estación (E); mantener E termina el día.
# Al acabar el día sale el recuento, se compran mejoras y empieza el siguiente.
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
const DAY_SECONDS := 180.0
const NIGHT_SECONDS := 60.0
const DUSK := 10.0  # segundos que tarda en oscurecer del todo al caer la noche
const OXYGEN_REFILL := 10.0  # segundos de oxígeno recuperados por segundo en la superficie
const HOLD_END := 1.2  # segundos manteniendo E en la estación para terminar el día
const STATION_RADIUS := 7.5
const BASE_SUPPORT := 3.0  # atm que aguanta el traje inicial (20 m: toda la zona 1)
const SUIT_STEP := 0.4  # atm de soporte por nivel de traje: 5 niveles = una zona más
const CRUSH_OVER := 2.0  # atm por encima del soporte a partir de las que salta el aviso grande
const SUIT_BASE_COST := [30, 150, 450, 1300, 4000]  # coste base de cada tramo de 5 niveles
# Teclas por defecto; se registran en el InputMap al arrancar y se cambian desde el menú.
const KEYS := {forward = KEY_W, back = KEY_S, left = KEY_A, right = KEY_D, up = KEY_SPACE, down = KEY_CTRL, use = KEY_E, vehicle = KEY_V, lamp = KEY_F, tool1 = KEY_1, tool2 = KEY_2, terminal = KEY_T}

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
# power: efecto instantáneo al pescarlo (no se vende). desc: texto de la enciclopedia.
# site: vive en un sitio de world.sites. night: solo sale de noche. dark: evita la linterna.
# legend: captura legendaria (una por zona, deja trofeo); regen: segundos sin impacto hasta recuperarse.
# Las especies nuevas van SIEMPRE al final: récords y trofeos guardan el índice.
const SPECIES := [
	{name = "Anchoa", rarity = "Común", value = 1, zone = 0, color = Color(0.6, 0.78, 0.75), big = 0.45, glow = 0.0, count = 24, school = true, desc = "Diminuta y nerviosa. Nada en bancos que huyen juntos."},
	{name = "Sardina", rarity = "Común", value = 1, zone = 0, color = Color(0.75, 0.8, 0.85), big = 0.6, glow = 0.0, count = 26, school = true, desc = "El banco plateado del bajío. Fácil de ver, difícil de acertar."},
	{name = "Jurel", rarity = "Común", value = 2, zone = 0, color = Color(0.4, 0.6, 0.5), big = 0.8, glow = 0.0, count = 16, desc = "Solitario y confiado. La primera captura de todo buzo."},
	{name = "Dorada", rarity = "Común", value = 5, zone = 1, color = Color(0.95, 0.8, 0.3), big = 0.9, glow = 0.0, count = 20, desc = "Brilla entre las algas. Buen precio para tan poca profundidad."},
	{name = "Pez loro", rarity = "Poco común", value = 8, zone = 1, color = Color(0.2, 0.8, 0.7), big = 1.0, glow = 0.0, count = 16, behavior = "shy", desc = "Huye en cuanto te acercas: dispara desde lejos."},
	{name = "Pez globo", rarity = "Poco común", value = 16, zone = 2, color = Color(0.95, 0.6, 0.4), big = 1.1, glow = 0.1, count = 18, desc = "Lento y redondo. Se deja ver entre las rocas."},
	{name = "Barracuda", rarity = "Poco común", value = 24, zone = 2, color = Color(0.5, 0.6, 0.75), big = 1.6, glow = 0.1, count = 14, behavior = "ambush", resistance = 2, desc = "Embiste tras un destello. Aguanta dos arponazos."},
	{name = "Pez linterna", rarity = "Raro", value = 50, zone = 3, color = Color(0.3, 0.5, 1.0), big = 0.8, glow = 1.0, count = 16, dark = true, desc = "Evita la luz: apaga la linterna para acercarte."},
	{name = "Morena", rarity = "Raro", value = 70, zone = 3, color = Color(0.45, 0.6, 0.25), big = 1.8, glow = 0.4, count = 12, behavior = "hide", resistance = 2, desc = "Se esconde en su guarida y solo asoma unos segundos."},
	{name = "Rape abisal", rarity = "Épico", value = 150, zone = 4, color = Color(0.7, 0.3, 0.9), big = 1.3, glow = 0.7, count = 14, behavior = "ambush", resistance = 2, desc = "Cazador de las fumarolas. Su brillo avisa de la embestida."},
	{name = "Calamar vampiro", rarity = "Épico", value = 200, zone = 4, color = Color(0.9, 0.2, 0.3), big = 1.5, glow = 0.7, count = 10, dark = true, desc = "Odia la luz y desaparece si lo alumbras."},
	{name = "Pez dragón", rarity = "Épico", value = 350, zone = 5, color = Color(0.2, 0.9, 0.6), big = 1.4, glow = 0.9, count = 12, behavior = "shy", resistance = 2, desc = "Huidizo y resistente. Hay que acorralarlo."},
	{name = "Celacanto", rarity = "Legendario", value = 900, zone = 5, color = Color(1.0, 0.75, 0.2), big = 2.0, glow = 0.6, count = 3, resistance = 3, desc = "Un fósil vivo. Tres arponazos y una fortuna."},
	# Powerups: siempre disponibles, escasos.
	{name = "Pez burbuja", rarity = "Especial", value = 0, zone = -1, color = Color(0.5, 1.0, 1.0), big = 0.7, glow = 1.5, count = 5, power = "air", desc = "No se vende: da aire infinito unos segundos."},
	{name = "Pez rayo", rarity = "Especial", value = 0, zone = -1, color = Color(1.0, 1.0, 0.3), big = 0.7, glow = 1.5, count = 5, power = "speed", desc = "No se vende: da velocidad extra unos segundos."},
	# Arrecife secreto.
	{name = "Pez mandarín", rarity = "Raro", value = 30, zone = 1, color = Color(1.0, 0.5, 0.1), big = 0.7, glow = 0.5, count = 8, site = "reef", desc = "Colores imposibles. Solo vive en un rincón escondido tras las algas."},
	# Nocturnas: solo aparecen en la fase de noche de cada día.
	{name = "Pez luna", rarity = "Raro", value = 12, zone = 0, color = Color(0.85, 0.9, 1.0), big = 1.5, glow = 1.2, count = 8, night = true, desc = "Sube al bajío cuando oscurece. Enorme, pálido y tranquilo."},
	{name = "Calamar luciérnaga", rarity = "Raro", value = 30, zone = 1, color = Color(0.4, 0.75, 1.0), big = 0.7, glow = 1.6, count = 8, night = true, behavior = "shy", desc = "Un punto de luz azul entre las algas. Asustadizo."},
	{name = "Pez víbora", rarity = "Épico", value = 180, zone = 3, color = Color(0.7, 1.0, 0.4), big = 1.2, glow = 1.4, count = 6, night = true, behavior = "ambush", resistance = 2, desc = "Caza de noche en el jardín luminoso. Embiste sin dudar."},
	# Capturas legendarias: una por zona.
	{name = "Mero gigante", rarity = "Legendario", value = 40, zone = 0, color = Color(0.55, 0.45, 0.3), big = 2.6, glow = 0.3, count = 1, legend = true, resistance = 4, regen = 8.0, desc = "El abuelo del bajío. Lento, pero aguanta cuatro arponazos seguidos."},
	{name = "Pez vela", rarity = "Legendario", value = 120, zone = 1, color = Color(0.25, 0.4, 0.95), big = 2.4, glow = 0.4, count = 1, legend = true, behavior = "shy", flee = 9.0, resistance = 3, regen = 12.0, desc = "El más rápido del cañón. Sin sedal largo o vehículo no lo alcanzas."},
	{name = "Tiburón del pecio", rarity = "Legendario", value = 400, zone = 2, color = Color(0.6, 0.65, 0.7), big = 3.2, glow = 0.3, count = 1, legend = true, site = "wreck", behavior = "ambush", bite = 8.0, resistance = 5, regen = 8.0, desc = "Guarda el barco hundido y embiste a quien se acerca."},
	{name = "Morena ancestral", rarity = "Legendario", value = 1200, zone = 3, color = Color(0.3, 0.9, 0.5), big = 3.0, glow = 0.8, count = 1, legend = true, site = "cave", behavior = "hide", resistance = 5, regen = 10.0, desc = "Duerme en la cueva de cristal y solo asoma unos segundos."},
	{name = "Calamar gigante", rarity = "Legendario", value = 3500, zone = 4, color = Color(0.85, 0.15, 0.25), big = 3.4, glow = 0.5, count = 1, legend = true, dark = true, resistance = 6, regen = 8.0, desc = "Desaparece con la luz: hay que cazarlo a oscuras entre las fumarolas."},
	{name = "Leviatán", rarity = "Legendario", value = 12000, zone = 5, color = Color(0.5, 0.3, 1.0), big = 4.5, glow = 1.0, count = 1, legend = true, behavior = "ambush", bite = 10.0, resistance = 8, regen = 7.0, desc = "El señor de la fosa. Ocho arponazos sin darle un respiro."},
]

# Diario del Nereida: notas repartidas por el cañón (posiciones en world.build_sites).
const NOTES := [
	{title = "Bitácora del Nereida · 1", text = "Día 3. El hidrófono capta un pulso regular que sube del fondo del cañón. No es un animal ni una máquina nuestra. Mañana bajamos."},
	{title = "Bitácora del Nereida · 2", text = "Tras las algas de la pared oeste hay una grieta. Dentro, un arrecife intacto, lleno de color. El pulso se oye también ahí, más débil."},
	{title = "Bitácora del Nereida · 3", text = "Los peces mandarín solo viven en este rincón. Marta dice que la señal los calma. A mí me quita el sueño."},
	{title = "Bitácora del Nereida · 4", text = "La tormenta partió el Nereida y se fue a pique sobre el roquedal. Seguimos con los trajes: el pulso viene de más abajo."},
	{title = "Bitácora del Nereida · 5", text = "En la pared este del jardín luminoso se abre una cueva de cristal. Algo enorme duerme dentro. Los cristales vibran al ritmo del pulso."},
	{title = "Bitácora del Nereida · 6", text = "El calor de las fumarolas funde los sellos del traje. Ya solo quedo yo. El pulso se siente en el pecho."},
	{title = "Bitácora del Nereida · 7", text = "La fosa. Las agujas de cristal apuntan todas al mismo sitio, al final del cañón. No me queda aire para volver. Ha valido la pena."},
	{title = "El Latido", text = "Un corazón de cristal del tamaño de una casa, latiendo con luz. Lleva aquí más tiempo que el mar. Ahora tú también lo has visto."},
]

# Eventos del día: a partir del día 3, algunos días traen uno.
const EVENTS := {
	storm = {name = "Tormenta", text = "poca visibilidad, más variantes raras"},
	migration = {name = "Migración", text = ""},
}

var upgrades := {
	tank = {name = "Tanque de oxígeno", desc = "+6 s de oxígeno por inmersión", base = 10, growth = 1.6, level = 0},
	fins = {name = "Aletas", desc = "+1 m/s nadando", base = 15, growth = 1.7, level = 0},
	reach = {name = "Sedal", desc = "+4 m de alcance del arpón", base = 12, growth = 1.6, level = 0},
	reel = {name = "Carrete", desc = "+25% velocidad de disparo y recogida", base = 20, growth = 1.7, level = 0},
	bag = {name = "Almacén de captura", desc = "+5 peces de capacidad", base = 35, growth = 1.75, level = 0, max = 10},
	scooter = {name = "Scooter submarino", desc = "Velocidad x1,7 · batería 25 s", base = 220, growth = 1.0, level = 0, max = 1},
	sub = {name = "Minisubmarino", desc = "Velocidad x2,2 · batería 50 s", base = 1800, growth = 1.0, level = 0, max = 1},
	lamp = {name = "Linterna", desc = "Ilumina el entorno cercano", base = 90, growth = 1.8, level = 0, max = 3},
	sonar = {name = "Sonar", desc = "Herramienta de mano: elige una especie y lanza sondas · 1 objetivo y +5 s de marca por nivel", base = 160, growth = 1.8, level = 0, max = 3},
	net = {name = "Arpón de red", desc = "Cada impacto cuenta como 2 arponazos", base = 280, growth = 1.0, level = 0, max = 1},
	hunter = {name = "Especialidad: Cazador", desc = "+20% valor de venta · excluye Explorador", base = 500, growth = 1.0, level = 0, max = 1},
	scout = {name = "Especialidad: Explorador", desc = "+30% batería y oxígeno · excluye Cazador", base = 500, growth = 1.0, level = 0, max = 1},
	aquarium = {name = "Acuario", desc = "La estación paga 5 monedas por captura y nivel", base = 260, growth = 1.8, level = 0, max = 3},
	lab = {name = "Laboratorio", desc = "Mejora la probabilidad de variantes raras", base = 400, growth = 1.8, level = 0, max = 3},
	traps = {name = "Trampas de pesca", desc = "Añade hasta 2 capturas comunes al terminar el día", base = 320, growth = 1.8, level = 0, max = 2},
	stabilizer = {name = "Estabilizador abisal", desc = "+0,2 atm de soporte por nivel", base = 1200, growth = 1.6, level = 0, max = 5},
	suit = {name = "Traje de presión", desc = "", base = 30, growth = 3.0, level = 0, max = (ZONES - 1) * 5},
}
const RECIPES := {bag = 1, scooter = 0, sub = 2, lamp = 0, sonar = 1, net = 2, aquarium = 0, lab = 3, traps = 4, stabilizer = 5}
const MAX_PRESTIGE_SUIT := (ZONES - 1) * 5
var records := {}
var notes := []  # índices de NOTES ya leídas
var trophies := []  # índices de SPECIES de las legendarias capturadas alguna vez
var event := ""  # clave de EVENTS o "" en un día normal
var migrant := -1  # especie con el doble de ejemplares en una migración
var fauna: Node3D
var hunter: Node3D
var clock := 0.0  # segundos transcurridos del día; la noche empieza en DAY_SECONDS
var night := false
var clock_label: Label
var day_title: Label
var title_tween: Tween
var damage_cooldown := 0.0
var lamp_on := true
var sonar_system: Node
var hazards: Node3D
var terminal: RefCounted
var day := 0
var playing := false
var coins := 0
var bag := {}  # índice de SPECIES -> cantidad pescada hoy
var bag_cash := {}  # valor real por especie tras tamaño y calidad
var delivered := {}  # lo entregado hoy en la estación (ya cobrado): índice de SPECIES -> cantidad
var delivered_cash := {}
var hold_use := 0.0  # segundos que se lleva mantenida E en la estación
var recount_tween: Tween
var recount_text := ""
var recount_stage: Control
var shop_home := Vector2.ZERO  # posición del panel en reposo (el temblor vuelve aquí)
var shake_tween: Tween
var prices: Array[int] = []
var contract_id := -1
var contract_goal := 0
var contract_caught := 0
var prestige_count := 0
var vehicle_battery := 0.0
var vehicle_active := false
var tool := 0  # herramienta en la mano: 0 = arpón, 1 = sonar
var passive_caught := 0
var vehicle_mesh: Node3D
var lamp_light: OmniLight3D
var mats := [0, 0, 0, 0, 0, 0]  # materiales sin gastar, por zona (world.MATERIALS)
var oxygen := 0.0
var air_time := 0.0  # powerup: segundos restantes sin gastar oxígeno
var speed_time := 0.0  # powerup: segundos restantes de velocidad extra
var buttons := {}
var fish_mesh := SphereMesh.new()
var toast_tween: Tween
var hint_tween: Tween
var settings := {sens = 0.003, volume = 0.8, binds = {}}
var hints := []  # consejos del tutorial que ya salieron
var breath := 0.0  # segundos hasta la siguiente respiración
var was_under := false
var helmet_wet := 0.0
# Con argumentos de arranque (capturas automáticas) se usa otro archivo y no se carga salvo con "load".
var automated := not OS.get_cmdline_user_args().is_empty()
var save_path := "user://save_auto.json" if automated else "user://save.json"

@onready var player: CharacterBody3D = $Player
@onready var cam: Camera3D = $Player/Camera
@onready var sfx: Node = $Sfx
@onready var menu: Control = $HUD/Menu
@onready var hint_label: Label = $HUD/Hint
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
@onready var next_button: Button = $HUD/Shop/Margin/Summary/Next
@onready var upgrades_page: VBoxContainer = $HUD/Shop/Margin/Upgrades
@onready var upgrades_title: Label = $HUD/Shop/Margin/Upgrades/Title
@onready var start_button: Button = $HUD/Shop/Margin/Upgrades/Start
@onready var prestige_button: Button = $HUD/Shop/Margin/Upgrades/Prestige


func lvl(id: String) -> int:
	return upgrades[id].level


func cost(id: String) -> int:
	if id == "suit":  # cada tramo de 5 niveles (una zona) es mucho más caro que el anterior
		return int(SUIT_BASE_COST[suit_tier()] * pow(1.3, lvl("suit") % 5))
	return int(upgrades[id].base * pow(upgrades[id].growth, upgrades[id].level))


# Tramo del traje: decide qué material pide la siguiente mejora (0 = perlas de la zona 1...).
func suit_tier() -> int:
	return mini(floori(float(lvl("suit")) / 5.0), SUIT_BASE_COST.size() - 1)


func can_buy(id: String) -> bool:
	if maxed(id) or coins < cost(id):
		return false
	if id == "suit" and mats[suit_tier()] <= 0:
		return false
	if RECIPES.has(id) and lvl(id) == 0 and mats[RECIPES[id]] <= 0:
		return false
	if id == "sub" and lvl("scooter") == 0:
		return false
	if (id == "hunter" and lvl("scout") > 0) or (id == "scout" and lvl("hunter") > 0):
		return false
	return true


func maxed(id: String) -> bool:
	return lvl(id) >= upgrades[id].get("max", 999)


func max_oxygen() -> float:
	return (30.0 + 6.0 * lvl("tank")) * (1.3 if lvl("scout") > 0 else 1.0)


func reach() -> float:
	return 12.0 + 4.0 * lvl("reach")


func swim_speed() -> float:
	var speed := (6.0 + lvl("fins")) * (SPEED_BOOST if speed_time > 0.0 else 1.0)
	if vehicle_active:
		speed *= 2.2 if lvl("sub") > 0 else 1.7
	return speed


func max_vehicle_battery() -> float:
	var base := 50.0 if lvl("sub") > 0 else 25.0
	return base * (1.3 if lvl("scout") > 0 else 1.0)


func pressure(depth: float) -> float:
	return 1.0 + depth / 10.0


# Presión (atm) que el traje aguanta sin gastar oxígeno de más.
func support() -> float:
	return BASE_SUPPORT + SUIT_STEP * lvl("suit") + 0.2 * lvl("stabilizer")


# Multiplicador de gasto de oxígeno: crece cada vez más rápido al superar el soporte del traje.
func oxygen_drain(depth: float) -> float:
	var over := maxf(pressure(depth) - support(), 0.0)
	return 1.0 + over + 0.5 * over * over


func bag_value() -> int:
	var total := 0
	for id in bag:
		total += bag_cash.get(id, SPECIES[id].value * bag[id])
	return total


func bag_count() -> int:
	var total := 0
	for count in bag.values():
		total += int(count)
	return total


func bag_capacity() -> int:
	return 5 + 5 * lvl("bag")


func near_station() -> bool:
	var d := player.position - station.position
	return Vector2(d.x, d.z).length() < STATION_RADIUS and d.y > -3.0


# Antes del _ready de los hijos: el mundo necesita saber qué materiales ya se recogieron.
func _enter_tree() -> void:
	load_game()
	for action in KEYS:
		bind(action, int(settings.binds.get(action, KEYS[action])))


func bind(action: String, code: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var e := InputEventKey.new()
	e.physical_keycode = code as Key
	InputMap.action_add_event(action, e)
	settings.binds[action] = code


func key_name(action: String) -> String:
	return OS.get_keycode_string(settings.binds[action])  # nombre según la posición en teclado QWERTY


func apply_settings() -> void:
	player.sens = settings.sens
	AudioServer.set_bus_volume_db(0, linear_to_db(settings.volume))


func game_state() -> Dictionary:
	var levels := {}
	for id in upgrades:
		levels[id] = lvl(id)
	# Un día a medias no cuenta: al cargar se repite.
	return {coins = coins, day = day - int(playing), levels = levels, mats = mats, hints = hints, prestige = prestige_count, records = records, notes = notes, trophies = trophies}


func save_game(game = null) -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({settings = settings, game = game if game != null else game_state()}))


# Copia una lista guardada si tiene el tamaño esperado (JSON devuelve floats).
func ints(saved, into: Array) -> void:
	if saved is Array:
		for i in mini(saved.size(), into.size()):
			into[i] = int(saved[i])


func load_game() -> void:
	if not FileAccess.file_exists(save_path) or (automated and not "load" in OS.get_cmdline_user_args()):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not d is Dictionary:
		return
	var s = d.get("settings")
	if s is Dictionary:
		settings.sens = clampf(float(s.get("sens", 0.003)), 0.0005, 0.01)
		settings.volume = clampf(float(s.get("volume", 0.8)), 0.0, 1.0)
		if s.get("binds") is Dictionary:
			settings.binds = s.binds
	var g = d.get("game")
	if not g is Dictionary:
		return
	coins = int(g.get("coins", 0))
	day = int(g.get("day", 0))
	prestige_count = maxi(0, int(g.get("prestige", 0)))
	if g.get("records") is Dictionary:
		records = g.records
	if g.get("notes") is Array:
		notes = g.notes.map(func(v): return int(v))
	if g.get("trophies") is Array:
		trophies = g.trophies.map(func(v): return int(v))
	var levels = g.get("levels")
	if levels is Dictionary:
		for id in upgrades:
			upgrades[id].level = clampi(int(levels.get(id, 0)), 0, upgrades[id].get("max", 999))
	ints(g.get("mats"), mats)
	if g.get("hints") is Array:
		hints = g.hints


# Nueva partida: guarda solo "keep" como progreso y recarga la escena.
func restart(keep: Dictionary) -> void:
	save_game(keep)
	get_tree().paused = false
	get_tree().reload_current_scene()


# Consejo del tutorial: cada uno sale una sola vez por partida.
func hint(key: String, text: String) -> void:
	if key in hints:
		return
	hints.append(key)
	show_hint(text, 8.0)


func show_hint(text: String, seconds: float) -> void:
	hint_label.text = text
	hint_label.modulate.a = 1.0
	if hint_tween:
		hint_tween.kill()
	hint_tween = create_tween()
	hint_tween.tween_interval(seconds)
	hint_tween.tween_property(hint_label, "modulate:a", 0.0, 1.0)


func _ready() -> void:
	# Ahorro normal en el límite de la primera zona, incluso con el traje mejorado.
	assert(is_equal_approx(oxygen_drain(ZONE), 1.0))
	# La referencia de 5x solo aplica al traje inicial.
	if lvl("suit") == 0 and lvl("stabilizer") == 0:
		assert(is_equal_approx(oxygen_drain(ZONE * 2.0), 5.0))

	# El HUD está maquetado a 1152x648 y se escala con la ventana.
	var window := get_window()
	window.content_scale_size = Vector2i(1152, 648)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	apply_settings()
	hint_label.modulate.a = 0.0

	fish_mesh.radial_segments = 8
	fish_mesh.rings = 4
	var fish_mat := ShaderMaterial.new()
	fish_mat.shader = preload("res://fish.gdshader")
	fish_mesh.material = fish_mat
	create_gear_visuals()
	for module_id in ["aquarium", "lab", "traps"]:
		station.add_module(module_id, lvl(module_id))
	station.add_module("warehouse", lvl("bag"))
	for id in trophies:
		station.add_trophy(SPECIES[id].zone, SPECIES[id].color)
	lamp_light.visible = lvl("lamp") > 0

	terminal = preload("res://terminal.gd").new()
	terminal.setup(self)
	sonar_system = preload("res://sonar.gd").new()
	add_child(sonar_system)
	sonar_system.setup(self)
	hazards = preload("res://hazards.gd").new()
	add_child(hazards)
	hazards.setup(self)
	fauna = preload("res://fauna.gd").new()
	add_child(fauna)
	fauna.setup(self)
	hunter = preload("res://hunter.gd").new()
	add_child(hunter)
	hunter.setup(self)
	create_clock()
	var hotbar: HBoxContainer = preload("res://hotbar.gd").new()
	$HUD.add_child(hotbar)
	hotbar.setup(self)
	next_button.pressed.connect(next_pressed)
	start_button.pressed.connect(start_pressed)
	prestige_button.pressed.connect(confirm_prestige)
	var prestige_dialog := ConfirmationDialog.new()
	prestige_dialog.name = "PrestigeConfirmation"
	prestige_dialog.title = "Renacer desde la fosa"
	prestige_dialog.dialog_text = "Perderás monedas, mejoras y materiales. Conservarás el prestigio y ganarás +25% permanente de venta. ¿Continuar?"
	prestige_dialog.confirmed.connect(do_prestige)
	$HUD.add_child(prestige_dialog)
	gauge.zones = ZONES
	gauge.zone_size = ZONE
	start_day()

	# Solo para capturas automáticas: godot -- cam=x,y,z,pitch,yaw (grados) | catch | end | shop | event=storm | night
	for a in OS.get_cmdline_user_args():
		if a.begins_with("cam="):
			var v := a.trim_prefix("cam=").split_floats(",")
			player.position = Vector3(v[0], v[1], v[2])
			player.rotation_degrees = Vector3(v[3], v[4], 0.0)
		elif a.begins_with("event="):
			start_day(a.trim_prefix("event="))
		elif a == "night":
			clock = DAY_SECONDS
		elif a == "catch":
			for f in get_tree().get_nodes_in_group("fish").slice(20, 32):
				catch_fish(f)
			catch_fish(get_tree().get_nodes_in_group("fish")[-1])
		elif a == "end":
			end_day()
		elif a == "shop":
			show_upgrades()
		elif a == "menu":
			menu.open()
	if not automated:
		menu.boot()
	refresh_shop()


# Título grande del día y reloj: el reloj nace bajo el título y luego sube a su sitio fijo.
func create_clock() -> void:
	day_title = Label.new()
	day_title.add_theme_font_size_override("font_size", 96)
	day_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	day_title.add_theme_constant_override("outline_size", 10)
	day_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_title.position = Vector2(0, 150)
	day_title.size = Vector2(1152, 110)
	day_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(day_title)
	clock_label = Label.new()
	clock_label.add_theme_font_size_override("font_size", 34)
	clock_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	clock_label.add_theme_constant_override("outline_size", 6)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_label.size = Vector2(300, 46)
	clock_label.pivot_offset = clock_label.size / 2.0
	clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock_label.hide()  # _process los muestra al jugar; con el menú de inicio el árbol está en pausa
	day_title.hide()
	$HUD.add_child(clock_label)


func play_day_intro() -> void:
	day_title.text = "Día %d" % day
	day_title.modulate.a = 1.0
	clock_label.position = Vector2(426, 265)
	clock_label.scale = Vector2.ONE * 1.6
	if title_tween:
		title_tween.kill()
	title_tween = create_tween()
	title_tween.tween_interval(2.2)  # el contador se ve bajar bajo el título
	title_tween.tween_property(day_title, "modulate:a", 0.0, 0.4)
	title_tween.tween_property(clock_label, "position", Vector2(426, 10), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	title_tween.parallel().tween_property(clock_label, "scale", Vector2.ONE, 0.7)


func create_gear_visuals() -> void:
	lamp_light = OmniLight3D.new()
	lamp_light.light_color = Color(0.75, 0.92, 1.0)
	lamp_light.light_energy = 2.2
	lamp_light.omni_range = 20.0
	lamp_light.visible = false
	cam.add_child(lamp_light)
	vehicle_mesh = preload("res://vehicle.gd").new()
	vehicle_mesh.main = self
	vehicle_mesh.visible = false
	player.add_child(vehicle_mesh)
	vehicle_mesh.set_sub(lvl("sub") > 0)


# Los peces a menos de "radius" metros huyen del buzo unos segundos.
func scare(from: Vector3, radius: float) -> void:
	for f in get_tree().get_nodes_in_group("fish"):
		if f.position.distance_to(from) < radius:
			f.fear = randf_range(2.0, 3.5)


# Al empezar el día: todas las especies diurnas. nocturnal = true: añade solo las nocturnas.
func spawn_fish(nocturnal := false) -> void:
	if not nocturnal:
		for f in get_tree().get_nodes_in_group("fish"):
			f.free()
	for id in SPECIES.size():
		if SPECIES[id].get("night", false) != nocturnal:
			continue
		var leader: Node3D = null
		for i in SPECIES[id].count * (2 if id == migrant else 1):
			var f: MeshInstance3D = FISH.new()
			f.mesh = fish_mesh
			f.species_id = id
			f.species = SPECIES[id]
			if SPECIES[id].get("school", false):  # cardúmenes de 6: el primero guía y el resto le sigue
				if i % 6 == 0:
					leader = f
				else:
					f.leader = leader
			add_child(f)


# forced: evento impuesto (pruebas y capturas); vacío = sorteo.
func start_day(forced := "") -> void:
	sonar_system.clear()
	damage_cooldown = 0.0
	tool = 0
	world.respawn_pickups()
	day += 1
	clock = 0.0
	night = false
	hunter.hide()
	event = forced
	if forced == "" and day > 2 and randf() < 0.4:  # los dos primeros días son tranquilos: tutorial
		event = EVENTS.keys().pick_random()
	migrant = randi_range(0, 12) if event == "migration" else -1
	oxygen = max_oxygen()
	air_time = 0.0
	speed_time = 0.0
	bag.clear()
	bag_cash.clear()
	delivered.clear()
	delivered_cash.clear()
	hold_use = 0.0
	prices.clear()
	for s in SPECIES:
		prices.append(int(round(float(s.value) * randf_range(0.8, 1.25))))
		if int(s.value) > 0:
			prices[prices.size() - 1] = maxi(1, prices[-1])
	contract_id = randi_range(0, 12)
	contract_goal = randi_range(2, 4)
	contract_caught = 0
	passive_caught = 0
	vehicle_active = false
	vehicle_battery = max_vehicle_battery()
	vehicle_mesh.visible = false
	refresh_bag()
	spawn_fish()
	harpoon.reset()
	player.position = START
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.locked = false
	shop.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	helmet.material.set_shader_parameter("rim_color", SUIT_COLORS[floori(float(lvl("suit")) / 5.0)])
	playing = true
	refresh_bag()
	var news := ""
	if event != "":
		news = "\n%s · %s" % [EVENTS[event].name, "bancos enormes de " + SPECIES[migrant].name if migrant >= 0 else EVENTS[event].text]
	play_day_intro()
	if news != "":
		show_toast(news.strip_edges(), Color.WHITE)
	hint("start", "Nada hacia delante y baja por el cañón: cuanto más hondo, más valen los peces. Clic para disparar.\nEntrega la captura en la estación con E para cobrarla. El oxígeno se recarga en la superficie.")


# lost: motivo por el que se perdió la captura (vacío si se vendió con normalidad).
func end_day(lost := "") -> void:
	if not playing:
		return
	playing = false
	hunter.hide()
	sonar_system.clear()
	vehicle_active = false
	vehicle_mesh.hide()
	harpoon.reset()  # un pez que aún venía por el sedal no cuenta
	air_time = 0.0
	speed_time = 0.0
	if toast_tween:
		toast_tween.kill()
	toast.modulate.a = 0.0
	player.locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Las trampas añaden unas pocas capturas comunes sin reemplazar la pesca manual.
	for i in mini(lvl("traps"), 2):
		var id := randi_range(0, 3)
		var passive_price := int(round(float(prices[id]) * (1.0 + 0.2 * lvl("hunter") + 0.25 * prestige_count)))
		if store_catch(id, passive_price):
			passive_caught += 1
	bank_bag()  # en la estación (o solo trampas si se perdió la captura)
	var contract_reward := prices[contract_id] * contract_goal * 2 if contract_caught >= contract_goal else 0
	coins += contract_reward
	# Recuento: una fila por rareza, de menor a mayor; luego acuario y encargo.
	var rows := []
	var total := 0
	var fish_total := 0
	for tier in RARITY.size():
		var rarity: String = RARITY.keys()[tier]
		var count := 0
		var cash := 0
		var names := []
		var fish := []
		for id in delivered:
			if SPECIES[id].rarity == rarity:
				count += delivered[id]
				cash += delivered_cash[id]
				names.append("%s x%d" % [SPECIES[id].name, delivered[id]])
				fish.append(id)
		if count > 0:
			rows.append({label = "%s · %d %s" % [rarity, count, "pez" if count == 1 else "peces"], detail = ", ".join(names), amount = cash, color = RARITY[rarity], tier = tier, fish = fish, fx = tier})
			total += cash
			fish_total += count
	if fish_total > 0 and lvl("aquarium") > 0:
		rows.append({label = "Acuario", detail = "5 monedas por pez y nivel", amount = fish_total * 5 * lvl("aquarium"), color = CYAN, tier = 1, fish = [], fx = -1})
		total += rows[-1].amount
	if contract_reward > 0:
		rows.append({label = "Encargo cumplido", detail = "%s x%d" % [SPECIES[contract_id].name, contract_goal], amount = contract_reward, color = AMBER, tier = 3, fish = [contract_id], fx = -1})
		total += contract_reward
	var header := ""
	if lost != "":
		header += "[color=#%s]%s: perdiste lo que llevabas encima.[/color]\n" % [RED.to_html(false), lost]
	if passive_caught > 0:
		header += "[color=#99aabb]Trampas: %d capturas[/color]\n" % passive_caught
	if rows.is_empty():
		header += "No entregaste nada hoy.\n"
	var contract_line := "" if contract_reward > 0 else "[color=#99aabb]Encargo: %s %d/%d[/color]\n" % [SPECIES[contract_id].name, contract_caught, contract_goal]
	summary_title.text = "Fin del día %d" % day
	upgrades_page.hide()
	summary_page.show()
	shop.show()
	play_recount(header + "\n", rows, "\n%s[color=#ffbf33][font_size=30]Total del día: %d monedas[/font_size][/color]\nTienes: %d monedas" % [contract_line, total, coins])
	hint_label.modulate.a = 0.0
	save_game()


# Cobra lo que hay en la bolsa y lo pasa a lo entregado hoy. Devuelve lo ganado.
func bank_bag() -> int:
	var earned := bag_value() + bag_count() * 5 * lvl("aquarium")
	for id in bag:
		delivered[id] = delivered.get(id, 0) + bag[id]
		delivered_cash[id] = delivered_cash.get(id, 0) + bag_cash[id]
	coins += earned
	bag.clear()
	bag_cash.clear()
	refresh_bag()
	return earned


func deliver() -> void:
	if bag.is_empty():
		return
	var count := bag_count()
	var earned := bank_bag()
	show_toast("Entregados %d %s · +%d monedas" % [count, "pez" if count == 1 else "peces", earned], AMBER)
	animate_sale_coins(earned)
	sfx.play("coin")
	sfx.play("catch", 1.2)
	save_game()


func row_line(row: Dictionary, shown: int) -> String:
	return "[color=#%s][font_size=26]%s[/font_size][/color]   [color=#ffbf33][font_size=24]+%d[/font_size][/color] monedas\n[color=#8899aa][font_size=16]%s[/font_size][/color]\n" % [row.color.to_html(false), row.label, shown, row.detail]


# Recuento paso a paso: cada fila sube su contador; más monedas y más rareza = más tiempo, monedas y brillo.
func play_recount(header: String, rows: Array, footer: String) -> void:
	recount_text = header
	summary_list.text = header
	next_button.text = "Saltar"
	if recount_tween:
		recount_tween.kill()
	if not recount_stage:
		recount_stage = Control.new()  # capa sobre el panel: aquí caen los peces del recuento
		recount_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shop.add_child(recount_stage)
		shop_home = shop.position
	for child in recount_stage.get_children():
		child.queue_free()
	recount_tween = create_tween()
	for row in rows:
		# Rápido: cada fila dura entre 0,25 y 1,1 s según monedas y rareza.
		var seconds := clampf(0.2 + 0.07 * log(1.0 + float(row.amount)) + 0.12 * row.tier, 0.25, 1.1)
		recount_tween.tween_callback(func() -> void:
			drop_row(row, seconds)
			sfx.play("coin", 1.0 + 0.15 * row.tier)
			animate_sale_coins(row.amount, row.color, 4 + 4 * row.tier))
		recount_tween.tween_method(func(v: float) -> void: summary_list.text = recount_text + row_line(row, int(v)), 0, row.amount, seconds).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		recount_tween.tween_callback(func() -> void: recount_text += row_line(row, row.amount))
		recount_tween.tween_interval(0.06)
	recount_tween.tween_callback(func() -> void:
		summary_list.text = recount_text + footer
		next_button.text = "Ir a la terminal")


# Peces de una fila del recuento: caen de grande a pequeño uno tras otro, golpean (temblor, sonido
# y chispas) y giran sin parar mientras suben las monedas, más rápido cuantos más se pescaron.
func drop_row(row: Dictionary, seconds: float) -> void:
	summary_list.text = recount_text
	var y := summary_list.global_position.y - recount_stage.global_position.y + summary_list.get_content_height() + 16.0
	for i in row.fish.size():
		var id: int = row.fish[i]
		var count: int = maxi(1, delivered.get(id, 1))
		var spot := Vector2(560.0 + 64.0 * i, y)
		var icon := fish_icon(SPECIES[id].color, SPECIES[id].get("glow", 0.0) > 0.5)
		icon.position = spot
		icon.scale = Vector2.ONE * 3.2
		icon.modulate.a = 0.0
		recount_stage.add_child(icon)
		var tag := Label.new()
		tag.text = "x%d" % count
		tag.position = spot + Vector2(24, 2)
		tag.add_theme_font_size_override("font_size", 16)
		tag.modulate.a = 0.0
		recount_stage.add_child(tag)
		var fall := 0.2 + (0.25 if row.fx == 4 else 0.0)  # la legendaria cae a cámara lenta
		var t := icon.create_tween()  # muere con el pez si se cierra el recuento
		t.tween_interval(0.07 * i)
		t.tween_property(icon, "modulate:a", 1.0, 0.06)
		t.parallel().tween_property(icon, "scale", Vector2.ONE, fall).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_callback(func() -> void:
			land(spot, row, i == 0)
			tag.modulate.a = 1.0)
		# Giro constante mientras sube el contador: una vuelta por pez, hasta 6.
		t.tween_property(icon, "rotation", TAU * mini(count, 6), maxf(seconds, 0.3 + 0.1 * mini(count, 6)))
		t.tween_callback(func() -> void: icon.rotation = 0.0)
		if row.fx == 2:  # Raro: late una vez al terminar
			t.tween_property(icon, "scale", Vector2.ONE * 1.35, 0.08)
			t.tween_property(icon, "scale", Vector2.ONE, 0.12)


# Golpe al caer: temblor, sonido y chispas; el primero de cada fila dispara el efecto de su rareza.
func land(spot: Vector2, row: Dictionary, first: bool) -> void:
	var fx: int = row.fx
	sfx.play("thud", randf_range(0.9, 1.1) - 0.08 * maxi(fx, 0))
	shake(3.0 + 3.0 * maxi(fx, 0))
	sparks(spot, row.color, 8 + 5 * maxi(fx, 0))
	if not first:
		return
	match fx:
		1:  # Poco común: chispas extra en anillo
			sparks(spot, Color.WHITE, 10)
		2:  # Raro: destello suave
			flash(row.color, 0.18)
		3:  # Épico: destello fuerte y lluvia de monedas
			flash(row.color, 0.35)
			sfx.play("catch", 0.9)
			animate_sale_coins(row.amount, row.color, 20)
		4:  # Legendario: rayos que giran, sello y destello dorado
			flash(row.color, 0.5)
			sfx.play("catch", 0.7)
			sfx.play("whale", 1.6)
			rays(spot, row.color)
			stamp("¡LEGENDARIO!", row.color)


func fish_icon(color: Color, glows: bool) -> Control:
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		if glows:
			icon.draw_circle(Vector2.ZERO, 20.0, Color(color, 0.25))
		var body := PackedVector2Array()
		for k in 12:
			body.append(Vector2(cos(k * TAU / 12.0) * 15.0, sin(k * TAU / 12.0) * 8.0))
		icon.draw_colored_polygon(body, color)
		icon.draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(22, -8), Vector2(22, 8)]), color.darkened(0.25))
		icon.draw_circle(Vector2(-8, -2), 2.0, Color(0.05, 0.05, 0.1)))
	return icon


func sparks(at: Vector2, color: Color, count: int) -> void:
	for k in count:
		var spark := ColorRect.new()
		spark.size = Vector2(4, 4)
		spark.color = color.lightened(0.3)
		spark.position = at
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		recount_stage.add_child(spark)
		var dir := Vector2.from_angle(randf() * TAU) * randf_range(25.0, 70.0)
		var t := spark.create_tween().set_parallel(true)
		t.tween_property(spark, "position", at + dir, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(spark, "modulate:a", 0.0, 0.4)
		t.tween_property(spark, "rotation", randf_range(-6.0, 6.0), 0.4)
		t.chain().tween_callback(spark.queue_free)


func shake(power: float) -> void:
	if shake_tween:
		shake_tween.kill()
	shake_tween = create_tween()
	for k in 4:
		shake_tween.tween_property(shop, "position", shop_home + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * power * (1.0 - k / 4.0), 0.03)
	shake_tween.tween_property(shop, "position", shop_home, 0.03)


func flash(color: Color, strength: float) -> void:
	var cover := ColorRect.new()
	cover.color = Color(color, strength)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.size = shop.size
	recount_stage.add_child(cover)
	var t := cover.create_tween()
	t.tween_property(cover, "modulate:a", 0.0, 0.45)
	t.tween_callback(cover.queue_free)


# Legendario: estrella de rayos que gira detrás del pez y se apaga.
func rays(at: Vector2, color: Color) -> void:
	var star := Control.new()
	star.position = at
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.draw.connect(func() -> void:
		for k in 10:
			star.draw_line(Vector2.ZERO, Vector2.from_angle(k * TAU / 10.0) * 46.0, Color(color, 0.7), 3.0))
	recount_stage.add_child(star)
	recount_stage.move_child(star, 0)
	var t := star.create_tween().set_parallel(true)
	t.tween_property(star, "rotation", TAU, 1.6)
	t.tween_property(star, "modulate:a", 0.0, 1.6).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(star.queue_free)


func stamp(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(shop.size.x, 80)
	label.position = Vector2(0, shop.size.y * 0.42)
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ONE * 2.5
	label.rotation = -0.08
	recount_stage.add_child(label)
	var t := label.create_tween()
	t.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.7)
	t.tween_property(label, "modulate:a", 0.0, 0.35)
	t.tween_callback(label.queue_free)


# Quita los peces y efectos del recuento para que no tapen la terminal.
func clear_recount() -> void:
	if not recount_stage:
		return
	for child in recount_stage.get_children():
		child.queue_free()
	if shake_tween:
		shake_tween.kill()
	shop.position = shop_home


# Botón del recuento: primero salta la animación; después lleva a la terminal.
func next_pressed() -> void:
	if recount_tween and recount_tween.is_running():
		recount_tween.custom_step(999.0)
	else:
		show_upgrades()


# Terminal de la estación durante el día: compra con lo ya entregado. El reloj se para mientras está abierta.
func open_terminal() -> void:
	clear_recount()
	summary_page.hide()
	upgrades_page.show()
	refresh_shop()
	shop.show()
	player.locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_terminal() -> void:
	shop.hide()
	player.locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func start_pressed() -> void:
	if playing:
		close_terminal()
	else:
		start_day()


func show_upgrades() -> void:
	clear_recount()
	summary_page.hide()
	upgrades_page.show()
	refresh_shop()


func buy(id: String) -> void:
	if can_buy(id):
		coins -= cost(id)
		if id == "suit":
			mats[suit_tier()] -= 1
		elif RECIPES.has(id) and lvl(id) == 0:
			mats[RECIPES[id]] -= 1
		upgrades[id].level += 1
		if id in ["aquarium", "lab", "traps"]:
			station.add_module(id, lvl(id))
		if id == "bag":
			station.add_module("warehouse", lvl(id))
		if id == "lamp":
			lamp_light.visible = true
		if id == "sub":
			vehicle_mesh.set_sub(true)
		sfx.play("coin")
		refresh_shop()
		save_game()


func refresh_shop() -> void:
	terminal.refresh()


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
	if s.has("power"):
		record_capture(fish.species_id, fish.catch_weight, 0)  # cuenta como descubierto en la enciclopedia
	match s.get("power", ""):
		"air":
			air_time = POWER_SECONDS
			show_toast("%s\nAire infinito %d s" % [s.name, POWER_SECONDS], RARITY[s.rarity])
		"speed":
			speed_time = POWER_SECONDS
			show_toast("%s\nVelocidad x%.1f durante %d s" % [s.name, SPEED_BOOST, POWER_SECONDS], RARITY[s.rarity])
		_:
			var sold_for := sale_price(fish)
			hint("deliver", "Lo pescado solo se cobra al entregarlo en la estación (E).\nSi te desmayas o te cazan, pierdes lo que llevas encima.")
			if not store_catch(fish.species_id, sold_for):
				show_toast("Bolsa llena: mejora la capacidad para llevar más peces", AMBER)
				fish.respawn()
				return
			record_capture(fish.species_id, fish.catch_weight, sold_for)
			show_toast("%s · %s\n%.1f kg  ·  %d monedas · mercado %d%%" % [s.name, fish.catch_quality, fish.catch_weight, sold_for, int(100.0 * prices[fish.species_id] / maxf(float(s.value), 1.0))], RARITY[s.rarity])
			if s.get("legend", false) and not fish.species_id in trophies:
				trophies.append(fish.species_id)
				station.add_trophy(s.zone, s.color)
				show_toast("¡Captura legendaria! %s · %d monedas\nSu trofeo queda en la estación" % [s.name, sold_for], AMBER)
			save_game()
			refresh_bag()
	show_float("+%s · %s" % [s.name, fish.catch_quality], fish.global_position, RARITY[s.rarity])
	sfx.play("catch")
	fish.respawn()


func collect_note(node: MeshInstance3D) -> void:
	var i: int = node.get_meta("note")
	world.notes.erase(node)
	node.get_meta("beam").queue_free()
	node.queue_free()
	notes.append(i)
	show_hint("%s  (%d/%d)\n%s" % [NOTES[i].title, notes.size(), NOTES.size(), NOTES[i].text], 14.0)
	if notes.size() == NOTES.size():
		show_toast("Diario completo", AMBER)
	sfx.play("pickup")
	save_game()


func store_catch(species_id: int, value: int) -> bool:
	if bag_count() >= bag_capacity():
		return false
	bag[species_id] = bag.get(species_id, 0) + 1
	bag_cash[species_id] = bag_cash.get(species_id, 0) + value
	if species_id == contract_id:
		contract_caught += 1
	return true


func confirm_prestige() -> void:
	if prestige_button.disabled:
		return
	$HUD/PrestigeConfirmation.popup_centered()


func do_prestige() -> void:
	if lvl("suit") < MAX_PRESTIGE_SUIT or coins < 100000:
		return
	prestige_count += 1
	coins = 0
	day = 0
	for id in upgrades:
		upgrades[id].level = 0
	mats.fill(0)
	save_game()
	get_tree().reload_current_scene()


# Feedback de captura anclado al mundo: se eleva y se desvanece sobre el punto de recogida.
func show_float(text: String, world_pos: Vector3, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = cam.unproject_position(world_pos)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("outline_size", 5)
	$HUD.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 55.0, 0.85)
	tween.tween_property(label, "modulate:a", 0.0, 0.85)
	tween.chain().tween_callback(label.queue_free)


# Pequeña lluvia de monedas al cerrar el recuento; representa la venta sin retrasar la tienda.
func animate_sale_coins(earned: int, color := AMBER, most := 8) -> void:
	if earned <= 0:
		return
	for i in mini(most, ceili(float(earned) / 4.0)):
		var coin := Label.new()
		coin.text = "●"
		coin.position = Vector2(560 + randf_range(-90.0, 90.0), 315 + randf_range(-55.0, 55.0))
		coin.add_theme_font_size_override("font_size", 22)
		coin.add_theme_color_override("font_color", color)
		coin.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
		coin.add_theme_constant_override("outline_size", 4)
		$HUD.add_child(coin)
		var tween := create_tween()
		tween.tween_interval(i * 0.055)
		tween.set_parallel(true)
		tween.tween_property(coin, "position", Vector2(530, 575), 0.55)
		tween.tween_property(coin, "modulate:a", 0.0, 0.55)
		tween.chain().tween_callback(coin.queue_free)


func refresh_bag() -> void:
	bag_label.visible = playing and contract_id >= 0
	var ids := bag.keys()
	ids.sort()
	var text := "Captura\n"
	for id in ids:
		var s: Dictionary = SPECIES[id]
		text += "[color=#%s]%s[/color]  x%d · %d monedas\n" % [RARITY[s.rarity].to_html(false), s.name, bag[id], bag_cash.get(id, 0)]
	var contract_line := "Encargo: %s %d/%d (+%d)" % [SPECIES[contract_id].name, contract_caught, contract_goal, prices[contract_id] * contract_goal * 2] if contract_id >= 0 and prices.size() == SPECIES.size() else "Encargo diario: disponible al iniciar el día"
	bag_label.text = text + "\nBolsa: %d/%d\nSin entregar: %d monedas\n%s" % [bag_count(), bag_capacity(), bag_value(), contract_line]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if playing and shop.visible and event.is_action_pressed("terminal"):
		close_terminal()
		return
	if not playing or player.locked:  # la pantalla del sonar bloquea el resto del equipo
		return
	if event.is_action_pressed("lamp"):
		lamp_on = not lamp_on
	if event.is_action_pressed("tool1"):
		select_tool(0)
	if event.is_action_pressed("tool2"):
		select_tool(1)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and lvl("sonar") > 0:
			select_tool(1 - tool)
		elif event.button_index == MOUSE_BUTTON_LEFT and tool == 1:
			sonar_system.open()
	if event.is_action_pressed("vehicle"):
		toggle_vehicle()
	if near_station() and event.is_action_pressed("use"):
		deliver()
	if near_station() and event.is_action_pressed("terminal"):
		open_terminal()


# Inventario: 0 = arpón, 1 = sonar. No se cambia con la lanza fuera ni conduciendo el vehículo.
func select_tool(index: int) -> void:
	if index == tool or harpoon.state != harpoon.HELD:
		return
	if index == 1 and lvl("sonar") == 0:
		show_toast("Compra el sonar en la terminal para usarlo", AMBER)
		return
	if vehicle_active:
		show_toast("En el vehículo solo puedes usar su arpón", AMBER)
		return
	tool = index
	sfx.play("tick")


func toggle_vehicle() -> void:
	if lvl("scooter") <= 0:
		show_toast("Compra un scooter en la terminal para usar un vehículo", AMBER)
		return
	if vehicle_active:
		vehicle_active = false
		vehicle_mesh.visible = false
		show_toast("Vehículo guardado · batería %.0f%%" % (vehicle_battery / max_vehicle_battery() * 100.0), CYAN)
	elif vehicle_battery > 1.0:
		vehicle_active = true
		vehicle_mesh.visible = true
		tool = 0  # las dos manos van al manillar: se dispara el arpón montado
		show_toast("Minisubmarino activo" if lvl("sub") > 0 else "Scooter activo", CYAN)
	else:
		show_toast("Batería agotada · recarga en la superficie", AMBER)


func current_zone() -> int:
	for zone in range(5, -1, -1):
		if -player.position.z >= world.BOUNDS[zone]:
			return zone
	return 0


func sale_price(fish: Node) -> int:
	var base: float = maxf(float(fish.species.value), 1.0)
	var market: float = float(prices[fish.species_id]) if prices.size() > fish.species_id else base
	return maxi(1, int(round(float(fish.catch_price) * market / base * (1.0 + 0.2 * lvl("hunter") + 0.25 * prestige_count))))


func record_capture(id: int, weight: float, value: int) -> void:
	var previous: Dictionary = records.get(str(id), {})
	records[str(id)] = {weight = maxf(weight, float(previous.get("weight", 0))),
		value = maxi(value, int(previous.get("value", 0))), count = int(previous.get("count", 0)) + 1}


func hurt(amount: float, cause: String) -> void:
	if not playing or damage_cooldown > 0.0:
		return
	damage_cooldown = 2.0
	oxygen = maxf(0.0, oxygen - amount)
	player.shake = 1.0
	sfx.play("hurt")
	show_toast("%s · -%.0f s de oxígeno" % [cause, amount], RED)
	if oxygen <= 0:
		faint()


# Lo que llevas encima se pierde (sin aire, muerto o con la noche lejos de la estación).
func lose_catch() -> void:
	contract_caught -= bag.get(contract_id, 0)
	bag.clear()
	bag_cash.clear()
	harpoon.reset()
	refresh_bag()


# Sin oxígeno: te desmayas, pierdes la captura y despiertas junto a la estación. El día sigue.
func faint() -> void:
	lose_catch()
	vehicle_active = false
	vehicle_mesh.hide()
	oxygen = max_oxygen()
	player.position = START
	player.velocity = Vector3.ZERO
	sfx.play("hurt")
	show_toast("Te desmayaste sin aire\nPerdiste la captura", RED)


func die(cause: String) -> void:
	lose_catch()
	player.shake = 1.5
	sfx.play("hurt", 0.6)
	end_day(cause)


func nightfall() -> void:
	night = true
	spawn_fish(true)
	hunter.appear()
	sfx.play("alarm", 0.5)
	show_toast("Cae la noche\nAlgo te está cazando", RED)
	hint("night", "De noche salen especies nocturnas, pero un cazador te persigue: si te alcanza pierdes la captura.\nUn arponazo lo aturde. Junto a la estación estás a salvo.")


# Fin de la noche: solo se vende lo que llevas si estás en la estación.
func night_over() -> void:
	if near_station():
		end_day()
	else:
		lose_catch()
		end_day("La noche acabó lejos de la estación")


func recipe_material(id: String) -> int:
	if id == "suit" and not maxed(id):
		return suit_tier()
	return int(RECIPES[id]) if RECIPES.has(id) and lvl(id) == 0 else -1


func purchase_blocker(id: String) -> String:
	if maxed(id):
		return "Nivel máximo alcanzado"
	if (id == "hunter" and lvl("scout") > 0) or (id == "scout" and lvl("hunter") > 0):
		return "Bloqueada por tu especialidad actual"
	if id == "sub" and lvl("scooter") == 0:
		return "Primero compra el scooter"
	var material := recipe_material(id)
	if material >= 0 and mats[material] < 1:
		return "Falta 1 " + str(world.MATERIALS[material].name)
	if coins < cost(id):
		return "Faltan %d monedas" % (cost(id) - coins)
	return ""


func _process(delta: float) -> void:
	var y := player.position.y
	var under := y < 0.0
	var depth := maxf(-y, 0.0)
	var drain := oxygen_drain(depth)
	var over := pressure(depth) - support()
	if playing:
		damage_cooldown = maxf(0.0, damage_cooldown - delta)
		if not shop.visible:  # con la terminal abierta el reloj se para
			clock += delta
		if not night and clock >= DAY_SECONDS:
			nightfall()
		if clock >= DAY_SECONDS + NIGHT_SECONDS:
			night_over()
			return
		if vehicle_active:
			vehicle_battery = maxf(vehicle_battery - delta, 0.0)
			if vehicle_battery <= 0.0:
				vehicle_active = false
				vehicle_mesh.visible = false
				show_toast("Batería agotada · el vehículo se apagó", AMBER)
		elif y >= 0.0 and lvl("scooter") > 0:
			vehicle_battery = minf(vehicle_battery + delta * 2.0, max_vehicle_battery())
		if lamp_light:
			lamp_light.visible = lvl("lamp") > 0 and under and lamp_on
			lamp_light.omni_range = 16.0 + 4.0 * lvl("lamp")
		air_time = maxf(air_time - delta, 0.0)
		speed_time = maxf(speed_time - delta, 0.0)
		if y >= 0.0:
			oxygen = minf(oxygen + delta * OXYGEN_REFILL, max_oxygen())
		elif air_time <= 0.0:
			oxygen -= delta * drain
			if oxygen <= 0.0:
				faint()
		# Respiración: se acelera con poco oxígeno.
		breath -= delta
		if y < 0.0 and breath <= 0.0:
			breath = 1.1 if oxygen < LOW_OXYGEN else 3.5
			sfx.play("breath", randf_range(0.9, 1.1))
		if over > 0.0:
			hint("pressure", "Tu traje no aguanta esta presión: aquí el oxígeno se gasta más rápido.\nMejora el traje de presión para bajar más.")
		if oxygen < LOW_OXYGEN:
			hint("oxygen", "Queda poco oxígeno: sube a la superficie para recargarlo.\nSi se acaba te desmayas y pierdes lo que llevas.")
		# Materiales del traje: se recogen al tocarlos y no reaparecen.
		for p in world.pickups:
			if p.position.distance_to(player.position) < 2.5:
				var zone: int = p.get_meta("zone")
				mats[zone] += 1
				world.pickups.erase(p)
				p.queue_free()
				var m: Dictionary = world.MATERIALS[zone]
				show_toast("%s\nMaterial de mejoras  ·  tienes %d" % [m.name, mats[zone]], m.color)
				hint("mat", "Los materiales se gastan en la terminal: traje y recetas de equipo. Reaparecen cada día.")
				sfx.play("pickup")
				save_game()
				break
		for n in world.notes:
			if n.position.distance_to(player.position) < 2.5:
				collect_note(n)
				break

	# Bajo el agua: color de fondo + niebla, y cada vez menos luz. Fuera: cielo y sin niebla.
	if was_under and not under:
		helmet_wet = 1.0
	was_under = under
	helmet_wet = maxf(helmet_wet - delta * 0.33, 0.0)  # las gotas duran unos 3 s
	cam.fov = lerpf(cam.fov, 82.0 if vehicle_active else 75.0, 4.0 * delta)
	if under != env.fog_enabled:
		env.fog_enabled = under
		env.background_mode = Environment.BG_COLOR if under else Environment.BG_SKY
	var t := clampf(depth / MAX_DEPTH, 0.0, 1.0)
	var dark := clampf((clock - DAY_SECONDS) / DUSK, 0.0, 1.0) if night else 0.0
	var dim := lerpf(1.0, 0.4, dark) * (0.6 if event == "storm" else 1.0)  # noche y tormenta oscurecen
	var c := SHALLOW.lerp(DEEP, sqrt(t)).darkened(1.0 - dim)
	env.background_color = c
	env.fog_light_color = c
	env.fog_density = 0.07 if event == "storm" else 0.04
	env.background_energy_multiplier = dim  # el cielo, fuera del agua
	$Surface.mesh.material.set_shader_parameter("dim", dim)  # y el brillo de la superficie vista desde abajo
	env.ambient_light_energy = lerpf(0.6, 0.12, t) * dim
	sun.light_energy = lerpf(1.0, 0.05, t) * dim

	# Casco: oxígeno, presión y zonas.
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.25
	var low := playing and oxygen < LOW_OXYGEN and blink
	var state := GREEN if over <= 0.0 else (AMBER if over < CRUSH_OVER else RED)
	info.text = "Día %d%s  ·  %d monedas" % [day, " · " + str(EVENTS[event].name) if event != "" else "", coins]
	oxygen_label.text = "O2 %ds" % ceili(maxf(oxygen, 0.0))
	var left := ceili(maxf((DAY_SECONDS + NIGHT_SECONDS if night else DAY_SECONDS) - clock, 0.0))
	clock_label.visible = playing and not menu.visible  # no se ve tras el menú de inicio ni en la pausa
	day_title.visible = clock_label.visible
	clock_label.text = "%s %d:%02d" % ["Noche" if night else "Día", left / 60, left % 60]
	clock_label.modulate = RED if night and (blink or left > 15) else Color.WHITE  # parpadea los últimos 15 s
	oxygen_label.modulate = RED if low else Color.WHITE
	oxygen_fill.bg_color = RED if low else CYAN
	oxygen_bar.max_value = max_oxygen()
	oxygen_bar.value = oxygen
	pressure_bar.max_value = support() + CRUSH_OVER  # barra llena = el oxígeno se funde
	pressure_bar.value = pressure(depth)
	pressure_fill.bg_color = state
	pressure_label.text = "Presión %.1f / %.1f atm" % [pressure(depth), support()]
	pressure_label.modulate = state if over > 0.0 else Color.WHITE
	# Los efectos de visor ya están en el shader: solo se alimentan desde el estado real.
	helmet.material.set_shader_parameter("danger", clampf(over / CRUSH_OVER, 0.0, 1.0))
	helmet.material.set_shader_parameter("haze", clampf((LOW_OXYGEN - oxygen) / LOW_OXYGEN, 0.0, 0.45) if under else 0.0)
	helmet.material.set_shader_parameter("wet", helmet_wet)
	gauge.depth = depth
	gauge.safe_depth = (support() - 1.0) * 10.0
	gauge.crush_depth = gauge.safe_depth + CRUSH_OVER * 10.0

	sfx.ambient(t, under)
	if playing and over >= CRUSH_OVER and blink and warning.modulate.a < 1.0:  # un pitido por parpadeo
		sfx.play("alarm")
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

	# Mantener E en la estación termina el día; soltar antes solo entrega.
	if playing and near_station() and not player.locked and Input.is_action_pressed("use"):
		hold_use += delta
		if hold_use >= HOLD_END:
			hold_use = 0.0
			end_day()
			return
	else:
		hold_use = 0.0
	prompt.visible = playing and near_station() and not shop.visible
	if hold_use > 0.15:
		prompt.text = "Terminando el día… %d%%" % int(hold_use / HOLD_END * 100.0)
	else:
		prompt.text = "[%s] %s  ·  mantén [%s] terminar el día  ·  [%s] Terminal" % [key_name("use"), "Entregar %d peces" % bag_count() if bag_count() > 0 else "Nada que entregar", key_name("use"), key_name("terminal")]
	var target := station.position + Vector3.UP
	marker.visible = playing and not near_station() and not cam.is_position_behind(target)
	if marker.visible:
		marker.position = cam.unproject_position(target)
		marker.text = "◆ Estación %dm" % player.position.distance_to(target)
