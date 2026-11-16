extends Node
# Sonido sintetizado por código al arrancar: el proyecto no tiene assets de audio.
# shortcut: ondas simples hechas a mano; sustituir por grabaciones cuando haya arte sonoro.

const RATE := 22050
const SCALE := [1.0, 1.125, 1.25, 1.5, 1.667]  # pentatónica mayor para la música

var players := {}
var music_wait := 3.0
var lp := 0.0  # estado del filtro paso bajo del ruido


func _ready() -> void:
	add("shoot", 0.3, func(t: float) -> float: return randf_range(-0.5, 0.5) * exp(-t * 25.0) + sin(TAU * 80.0 * t) * exp(-t * 14.0) * 0.6)
	add("tick", 0.04, func(t: float) -> float: return sin(TAU * 1500.0 * t) * exp(-t * 120.0) * 0.2)
	add("catch", 0.45, func(t: float) -> float: return sin(TAU * (660.0 if t < 0.12 else 990.0) * t) * exp(-t * 6.0) * 0.4)
	add("coin", 0.2, func(t: float) -> float: return sin(TAU * 1320.0 * t) * exp(-t * 18.0) * 0.3)
	add("pickup", 0.36, func(t: float) -> float: return sin(TAU * [523.0, 659.0, 784.0, 1047.0][int(t / 0.09)] * t) * exp(-fmod(t, 0.09) * 12.0) * 0.35)
	add("alarm", 0.2, func(t: float) -> float: return signf(sin(TAU * 440.0 * t)) * 0.12 * (1.0 - t / 0.2))
	add("hurt", 0.35, func(t: float) -> float: return signf(sin(TAU * (160.0 - 200.0 * t) * t)) * exp(-t * 9.0) * 0.3)
	add("deny", 0.3, func(t: float) -> float: return sin(TAU * 200.0 * t) * float(fmod(t, 0.15) < 0.1) * 0.3)
	add("ping", 0.8, func(t: float) -> float: return sin(TAU * 1200.0 * t) * exp(-t * 5.0) * 0.3)
	add("breath", 0.9, func(t: float) -> float: return noise() * pow(sin(PI * t / 0.9), 2.0) * 0.5)
	add("pad", 3.0, func(t: float) -> float: return (sin(TAU * 220.0 * t) + sin(TAU * 440.0 * t) * 0.3) * pow(sin(PI * t / 3.0), 2.0) * 0.1)
	# Ambiente en bucle de 4 s: las frecuencias dan ciclos enteros para que no haga clic al repetirse.
	add("ambient", 4.0, func(t: float) -> float: return (sin(TAU * 55.0 * t) * 0.25 + sin(TAU * 82.5 * t) * 0.15) * (0.7 + 0.3 * sin(TAU * 0.25 * t)) + noise() * 0.2 * pow(sin(PI * t / 4.0), 2.0), true)
	players.ambient.play()


func noise() -> float:
	lp = lerpf(lp, randf_range(-1.0, 1.0), 0.08)
	return lp * 4.0


func add(sound: String, seconds: float, wave: Callable, loop := false) -> void:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(wave.call(float(i) / RATE), -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = n
	var p := AudioStreamPlayer.new()
	p.stream = w
	p.max_polyphony = 4
	add_child(p)
	players[sound] = p


func play(sound: String, pitch := 1.0) -> void:
	players[sound].pitch_scale = pitch
	players[sound].play()


# El zumbido de fondo baja de tono con la profundidad y se apaga fuera del agua.
func ambient(deep: float, under: bool) -> void:
	players.ambient.pitch_scale = lerpf(1.0, 0.6, deep)
	players.ambient.volume_db = 0.0 if under else -14.0


func _process(delta: float) -> void:
	# Música: notas sueltas y lentas de una escala pentatónica.
	music_wait -= delta
	if music_wait <= 0.0:
		music_wait = randf_range(1.5, 4.0)
		play("pad", SCALE.pick_random() * [0.5, 1.0].pick_random())
