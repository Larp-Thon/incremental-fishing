extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.save_path = "res://milestone-test-save.json"
	main.playing = true
	main.upgrades.sonar.level = 3
	main.player.position = Vector3(0, -10, 0)
	var fishes: Array = get_nodes_in_group("fish")
	main.select_tool(1)
	check(main.tool == 1, "sonar is a selectable tool")
	main.sonar_system.open()
	check(main.sonar_system.panel.visible and main.player.locked, "sonar screen opens and locks the diver")
	check(main.sonar_system.buttons.size() == 23, "sonar lists every sellable species")
	main.sonar_system.launch(3)
	var contacts: Array = main.sonar_system.contacts
	check(not main.sonar_system.panel.visible and not main.player.locked, "choosing a species closes the screen")
	check(contacts.size() == 3, "one probe per sonar level")
	check(contacts.all(func(c): return c.fish.get_ref().species_id == 3), "probes target the chosen species")
	main.toggle_vehicle()
	check(main.tool == 1 and not main.vehicle_active, "vehicle needs the scooter upgrade")
	main.upgrades.scooter.level = 1
	main.vehicle_battery = main.max_vehicle_battery()
	main.toggle_vehicle()
	check(main.vehicle_active and main.tool == 0, "riding the scooter switches to its mounted harpoon")
	main.toggle_vehicle()
	var material_count: int = main.world.pickups.size()
	main.world.pickups.pop_back().queue_free()
	main.world.respawn_pickups()
	check(material_count == 37 and main.world.pickups.size() == 37, "materials respawn every day")
	var fish = contacts[0].fish.get_ref()
	var old_generation: int = fish.generation
	fish.respawn()
	check(fish.generation != old_generation, "respawn invalidates sonar target")
	fish.hp = 3
	fish.hidden = false
	check(not fish.take_harpoon_hit(1) and fish.hp == 2, "one hit removes one resistance")
	check(fish.take_harpoon_hit(2) and fish.hooked, "net finishes resistant fish")
	main.records.clear()
	main.record_capture(0, 2.5, 12)
	main.record_capture(0, 1.0, 20)
	check(main.records["0"].weight == 2.5 and main.records["0"].value == 20 and main.records["0"].count == 2, "records keep separate maxima")
	main.save_game()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main.save_path))
	check(saved.game.records["0"].weight == 2.5, "records persist")
	main.oxygen = 20
	main.damage_cooldown = 0
	main.hurt(4, "test")
	main.hurt(4, "test")
	check(main.oxygen == 16, "hazard cooldown prevents stacked damage")
	var predator = fishes.filter(func(f): return f.species_id == 6)[0]
	predator.zone = 0
	predator.position = main.player.position + Vector3(0, 0, -1)
	predator.fear = 0
	predator.attack_time = 1.3
	main.damage_cooldown = 0
	predator._process(0.01)
	check(main.oxygen == 11, "predator lunge removes oxygen")
	var hider = fishes.filter(func(f): return f.species_id == 8)[0]
	hider.zone = 0
	hider.position = main.player.position + Vector3(2, 0, 0)
	hider.shelter = hider.position
	hider.fear = 0
	hider.action_timer = 0
	hider._process(0.01)
	check(hider.hidden and not hider.visible, "shelter conceals fish")
	hider.conceal_time = 0
	hider._process(0.01)
	check(not hider.hidden and hider.visible, "fish reemerges and is catchable")
	check(main.hazards.flow_at(Vector3(0, -31, -65)) != Vector3.ZERO, "current affects its band")
	check(main.hazards.flow_at(Vector3(30, -31, -65)) == Vector3.ZERO, "current has escape area")
	main.bag.clear()
	main.bag_cash.clear()
	for i in main.bag_capacity():
		check(main.store_catch(0, 1), "bag accepts available slots")
	check(not main.store_catch(0, 1), "bag refuses overflow")
	# --- Milestone 5: mundo y contenido ---
	var world = main.world
	check(world.wall(-75, -68) == 0.0 and world.wall(-75, -30) > 0.5, "secret reef opens the west wall only at its entrance")
	check(world.wall(75, -145) == 0.0 and world.sites.has("wreck"), "cave alcove and wreck exist")
	main.player.position = Vector3(-80, -30, -68)
	main.player.velocity = Vector3.ZERO
	main.player._process(0.016)
	check(absf(main.player.position.x + 80.0) < 0.5, "diver can swim inside the reef")
	main.player.position = Vector3(62.9, -10, -30)
	main.player.velocity = Vector3(100, 0, 0)
	main.player._process(0.1)
	check(main.player.position.x < 63.5, "canyon wall stops the diver")
	check(world.notes.size() == 8, "eight journal notes in the world")
	main.collect_note(world.notes[0])
	check(main.notes == [0] and world.notes.size() == 7, "collecting a note stores it")
	# --- Milestone 6: ciclo de día y noche ---
	main.start_day()
	main.player.position = Vector3(0, -10, -20)
	main.oxygen = 0.01
	main.store_catch(0, 5)
	main._process(0.1)
	check(main.playing and main.bag.is_empty() and main.player.position == main.START and main.oxygen == main.max_oxygen(), "running out of air faints: catch lost, day goes on")
	main.oxygen = 1.0
	main._process(0.1)
	check(main.oxygen == 2.0, "oxygen refills at the surface")
	check(not get_nodes_in_group("fish").any(func(f): return f.species.get("night", false)), "no nocturnal species by day")
	main.clock = main.DAY_SECONDS
	main._process(0.01)
	check(main.night and main.hunter.visible, "nightfall releases the hunter")
	check(get_nodes_in_group("fish").any(func(f): return f.species.get("night", false)), "night brings nocturnal species")
	main.clock = main.DAY_SECONDS + main.DUSK
	main._process(0.01)
	check(is_equal_approx(main.env.fog_density, 0.04) and main.sun.light_energy < 0.5, "night dims the light")
	main.player.position = Vector3(0, -10, -40)
	main.hunter.position = main.player.position + Vector3(0, 0, -6)
	check(main.hunter.harpooned(main.player.position, main.hunter.position) and main.hunter.stun > 0.0, "harpoon stuns the hunter")
	main.hunter.position = main.player.position + Vector3(0, 0, -1)
	main.hunter._process(0.01)
	check(main.playing, "stunned hunter does not kill")
	main.hunter.stun = 0.0
	main.store_catch(0, 5)
	main.hunter._process(0.01)
	check(not main.playing and main.bag.is_empty(), "hunter kills the diver and the catch is lost")
	main.start_day()
	main.player.position = Vector3(0, -10, -40)
	main.store_catch(0, 5)
	main.clock = main.DAY_SECONDS + main.NIGHT_SECONDS
	main.night = true
	var coins_before: int = main.coins
	main._process(0.01)
	check(not main.playing and main.coins == coins_before, "night ends away from the station: nothing sold")
	main.start_day()
	main.player.position = main.station.position + Vector3(0, 0.5, 2)
	main.store_catch(0, 5)
	main.clock = main.DAY_SECONDS + main.NIGHT_SECONDS
	main.night = true
	coins_before = main.coins
	main._process(0.01)
	check(not main.playing and main.coins >= coins_before + 5, "night ends at the station: catch sold")
	# --- Milestone 6: entrega obligatoria, terminal y recuento ---
	main.start_day()
	main.player.position = main.station.position + Vector3(0, 0.5, 5)
	check(main.near_station(), "the delivery dock counts as the station")
	main.store_catch(0, 7)
	coins_before = main.coins
	main.deliver()
	check(main.bag.is_empty() and main.coins == coins_before + 7 + 5 * main.lvl("aquarium") and main.delivered[0] == 1, "delivering pays at once")
	main.store_catch(12, 900)
	main.die("test")
	check(main.coins == coins_before + 7 + 5 * main.lvl("aquarium"), "death keeps what was delivered, loses the rest")
	check(main.summary_list.text.contains("perdiste"), "recount explains the loss")
	main.next_pressed()
	check(main.summary_list.text.contains("Común") and main.summary_list.text.contains("Total del día"), "skipping finishes the recount by rarity")
	main.start_day()
	main.player.position = main.station.position + Vector3(0, 0.5, 5)
	main.open_terminal()
	var clock_before: float = main.clock
	main._process(0.5)
	check(main.shop.visible and main.upgrades_page.visible and main.clock == clock_before, "station terminal opens mid-day and pauses the clock")
	check(main.start_button.text == "Volver al agua", "terminal returns to the water mid-day")
	main.start_pressed()
	check(main.playing and not main.shop.visible and not main.player.locked, "closing the terminal resumes the dive")
	main.start_day("storm")
	main._process(0.01)
	check(is_equal_approx(main.env.fog_density, 0.07), "storm thickens the fog")
	check(not get_nodes_in_group("fish").any(func(f): return f.species.get("night", false)), "nocturnal species only at night")
	main.start_day("migration")
	check(get_nodes_in_group("fish").filter(func(f): return f.species_id == main.migrant).size() == main.SPECIES[main.migrant].count * 2, "migration doubles a species")
	var reef_fish: Array = get_nodes_in_group("fish").filter(func(f): return f.species.get("site", "") == "reef")
	check(reef_fish.size() == 8 and reef_fish.all(func(f): return f.position.distance_to(world.sites.reef) < 12.0), "reef species live in the secret reef")
	check(main.fauna.creatures.size() == 6 and main.fauna.jellies.size() == 32, "non-catchable fauna is present")
	var legend = get_nodes_in_group("fish").filter(func(f): return f.species.get("legend", false) and f.species.zone == 0)[0]
	legend.take_harpoon_hit(1)
	check(legend.hp == 3, "legendary fish takes several hits")
	legend._process(9.0)
	check(legend.hp == 4, "legendary fish recovers when hits come too slowly")
	main.bag.clear()
	main.bag_cash.clear()
	main.catch_fish(legend)
	check(main.trophies == [legend.species_id], "first legendary catch leaves a trophy")
	saved = JSON.parse_string(FileAccess.get_file_as_string(main.save_path))
	check(saved.game.notes.size() == 1 and saved.game.trophies.size() == 1, "notes and trophies persist")
	main.show_upgrades()
	check(main.terminal.species_view.text.contains("Mero gigante") and main.terminal.species_view.text.contains("???"), "encyclopedia reveals only caught species")
	check(main.terminal.journal_view.text.contains(main.NOTES[0].title) and main.terminal.journal_view.text.contains("sin encontrar"), "journal lists found notes")
	main.coins = 0
	main.show_upgrades()
	check(main.terminal.tabs.get_tab_count() == 9, "nine terminal sections")
	check(main.terminal.cards.size() == main.upgrades.size(), "every upgrade belongs to a category")
	check(main.terminal.cards.tank.buy.disabled, "unaffordable purchase is disabled")
	main.upgrades.scout.level = 1
	main.coins = 10000
	check(main.purchase_blocker("hunter").contains("especialidad"), "speciality gives accurate lock reason")
	main.playing = false
	main.show_upgrades()
	main.shop.show()
	main.toast.hide()
	main.hint_label.hide()
	main.bag_label.hide()
	await process_frame
	await process_frame
	check(main.shop.size.x <= root.get_visible_rect().size.x, "terminal fits viewport width")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://terminal-preview.png")
	DirAccess.remove_absolute(main.save_path)
	main.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	print("Milestone integration: %d failures" % failures)
	quit(failures)

