extends MeshInstance3D

const MARGIN := 7.0  # se mantienen lejos de rampas y paredes de su zona

var species: Dictionary  # entrada de main.SPECIES
var species_id := 0
var hooked := false  # clavado en el arpón: deja de nadar
var hit_radius := 0.9
var turn := 0.0
var zone := 0
var fear := 0.0  # segundos que le quedan huyendo del buzo
var leader: Node3D  # cardumen: sigue a este pez
var offset := Vector3.ZERO  # su sitio dentro del cardumen
var hp := 1
var generation := 0
var shelter := Vector3.ZERO
var refuge: MeshInstance3D
var conceal_time := 0.0
var attack_time := 0.0
var action_timer := 0.0
var hidden := false
var catch_weight := 1.0
var catch_quality := "Estándar"
var catch_price := 0

@onready var main := get_parent()
@onready var world: Node3D = main.world


func _ready() -> void:
	add_to_group("fish")
	respawn()


func respawn() -> void:
	generation += 1
	visible = true
	conceal_time = 0.0
	attack_time = 0.0
	hooked = false
	fear = 0.0
	hp = int(species.get("resistance", 1))
	hidden = false
	var size_factor := randf_range(0.75, 1.3)
	catch_weight = maxf(0.1, float(species.big) * size_factor)
	var quality_roll := randf()
	var rare_bonus: float = float(main.lvl("lab")) * 0.025
	catch_quality = "Colosal" if size_factor > 1.2 else ("Pequeño" if size_factor < 0.85 else "Estándar")
	if quality_roll < 0.025 + rare_bonus * 0.35:
		catch_quality = "Albino"
		set_instance_shader_parameter("color", Color(0.95, 0.92, 0.82))
	elif quality_roll < 0.075 + rare_bonus:
		catch_quality = "Dorado"
		set_instance_shader_parameter("color", Color(1.0, 0.73, 0.18))
	catch_price = int(round(float(species.value) * size_factor * (1.0 if catch_quality == "Estándar" or catch_quality == "Pequeño" or catch_quality == "Colosal" else 3.0)))
	zone = species.zone if species.zone >= 0 else randi() % 6  # zone -1: aparece en cualquier zona
	var big: float = float(species.big) * size_factor
	hit_radius = 0.5 + 0.4 * big
	# Viven cerca del fondo de su zona.
	position = world.spot(zone) + Vector3.UP * randf_range(3.0, 12.0)
	position.y = minf(position.y, -2.0)
	if leader:
		offset = Vector3(randf_range(-2.5, 2.5), randf_range(-1.2, 1.2), randf_range(-2.5, 2.5))
		position = leader.position + offset
	rotation = Vector3(0.0, randf() * TAU, 0.0)
	shelter = position
	for prop in world.get_children():
		if prop is MeshInstance3D and prop.scale.y > 2.0 and prop.position.distance_to(position) < 12.0:
			shelter = prop.position + Vector3.UP * 0.25
			break
	if species.get("behavior", "") == "hide":
		if not is_instance_valid(refuge):
			var floor_pos := Vector3(position.x, world.floor_y(position.x, position.z), position.z)
			refuge = world.prop("box", floor_pos, Vector3(3.0, 1.4, 2.3), Color(0.25, 0.3, 0.32))
		shelter = refuge.position
	scale = Vector3(0.35, 0.6, 1.4) * big
	set_instance_shader_parameter("color", species.color)
	if catch_quality == "Albino":
		set_instance_shader_parameter("color", Color(0.95, 0.92, 0.82))
	elif catch_quality == "Dorado":
		set_instance_shader_parameter("color", Color(1.0, 0.73, 0.18))
	set_instance_shader_parameter("glow", species.glow)
	set_instance_shader_parameter("phase", randf() * TAU)


func _process(delta: float) -> void:
	if not main.playing:
		return
	if hooked:
		rotation.y += sin(Time.get_ticks_msec() * 0.04) * 10.0 * delta  # forcejea en el sedal
		return
	var behavior: String = species.get("behavior", "wander")
	action_timer = maxf(action_timer - delta, 0.0)
	fear = maxf(fear - delta, 0.0)
	conceal_time = maxf(conceal_time - delta, 0.0)
	var distance: float = position.distance_to(main.player.position)
	if hidden:
		if conceal_time > 0.0:
			return
		hidden = false
		visible = true
		action_timer = 5.0
	if species_id in [7, 10] and main.lamp_on and main.lvl("lamp") > 0 and distance < 18.0:
		main.hint("light_fish", "Pez linterna y calamar vampiro evitan la luz.\n[%s] apaga la linterna para acercarte." % main.key_name("lamp"))
		fear = 1.0
		if distance < 7.0 and action_timer <= 0:
			hidden = true
			visible = false
			conceal_time = 2.0
			return
	var speed := 2.0
	var want := Vector3.ZERO  # hacia dónde quiere ir; cero = deambular
	var d := -position.z
	if absf(position.x) > world.HALF_WIDTH - MARGIN or d < world.BOUNDS[zone] + MARGIN or d > world.BOUNDS[zone + 1] - MARGIN:
		want = Vector3(-position.x, 0.0, -(world.BOUNDS[zone] + world.BOUNDS[zone + 1]) * 0.5 - position.z)  # vuelve al centro de su zona
	elif fear > 0.0 or (behavior == "shy" and position.distance_to(main.player.position) < 12.0):
		want = position - main.player.position
		speed = 5.5
	elif behavior == "ambush" and distance < 14.0:
		main.hint("predator", "El brillo anuncia una embestida. Apártate o acierta con el arpón.\nEl golpe hace perder oxígeno.")
		want = main.player.position - position
		attack_time += delta
		speed = 0.5 if attack_time < 1.2 else 9.0
		set_instance_shader_parameter("glow", 2.5 if attack_time < 1.2 else species.glow)
		if attack_time >= 1.2 and distance < 1.8:
			main.hurt(5.0, str(species.name) + " te embistió")
			fear = 3.0
		if attack_time > 2.0:
			attack_time = 0.0
			fear = 3.0
	elif behavior == "hide" and distance < 10.0 and action_timer <= 0:
		want = shelter - position
		speed = 6.0
		if want.length() < 1.0:
			hidden = true
			visible = false
			conceal_time = 3.0
			return
	elif leader and not leader.hooked:
		want = leader.position + offset - position
		speed = 3.2 if want.length() > 3.0 else 2.0
		if want.length() < 1.0:
			want = -leader.basis.z  # ya en su sitio: nada hacia donde va el guía
	else:
		hidden = false
	if want == Vector3.ZERO:
		if randf() < delta * 0.5:
			turn = randf_range(-1.0, 1.0)
		rotate_y(turn * delta)
	else:
		rotation.y = lerp_angle(rotation.y, atan2(-want.x, -want.z), 4.0 * delta)
		position.y = clampf(position.y + clampf(want.y, -1.0, 1.0) * speed * 0.5 * delta, world.floor_y(position.x, position.z) + 1.0, -1.5)
	if speed > 0.0:
		position -= basis.z.normalized() * speed * delta


func take_harpoon_hit(strength := 1) -> bool:
	if hidden or hooked:
		return false
	hp -= strength
	if hp <= 0:
		hooked = true
		return true
	fear = 2.0
	return false


func _exit_tree() -> void:
	if is_instance_valid(refuge):
		refuge.queue_free()
