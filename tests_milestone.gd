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
	var ranked: Array = main.sonar_system.ranked(fishes, 0)
	check(ranked.size() > 0, "sonar finds shallow fish")
	for i in range(1, ranked.size()):
		check(main.sale_price(ranked[i-1]) >= main.sale_price(ranked[i]), "sonar ranks actual sale price")
	main.ping_sonar()
	check(main.sonar_system.contacts.size() == 18, "three targets per zone")
	var fish = ranked[0]
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
	main.coins = 0
	main.show_upgrades()
	check(main.terminal.tabs.get_tab_count() == 7, "seven terminal sections")
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

