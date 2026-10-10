extends SceneTree
## Real main scene, UI signals and input handlers. Position/clock fixtures isolate
## interfaces; route traversal and transaction/death flows have separate tests.
const Controls = preload("res://scripts/player/controls.gd")
const Map = preload("res://data/biomes/world_map.gd")
var game
var checks := 0
var failures: Array[String] = []
var current_case := "startup"
var started := 0
var save_directory := ""

func _initialize() -> void:
	started = Time.get_ticks_msec()
	save_directory = "user://automated-tests/m2-interface-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	call_deferred("run")

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started > 110000:
		printerr("M2_INTERFACE_FAIL timeout case=", current_case)
		quit(1)
	return false

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(current_case + ": " + message)
		printerr("M2_INTERFACE_FAILURE ", current_case, ": ", message)

func section(name: String) -> void:
	current_case = name
	print("M2_INTERFACE_CASE ", name)

func frames(count := 2) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func freeze_player() -> void:
	game.player.active = false
	Controls.release_all()

func locate(at: Vector3, look: Vector3) -> void:
	game.player.relocate(at, false)
	freeze_player()
	game.player.camera.look_at(look)

func dispatch(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	game._unhandled_input(event)

func checkpoint_bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(game.saves.path("checkpoint"))

func buoy_positions_match(expected: Array) -> bool:
	if game.state.buoys.size() != expected.size() or game.buoy_nodes.size() != expected.size():
		return false
	for i in expected.size():
		var wanted := Vector3(expected[i][0], expected[i][1], expected[i][2])
		var saved: Array = game.state.buoys[i]
		# JSON text rounds decimal floats; compare reconstructed world positions
		# at sub-millimetre precision, including the actual rebuilt marker nodes.
		if Vector3(saved[0], saved[1], saved[2]).distance_to(wanted) > 0.0001 or game.buoy_nodes[i].global_position.distance_to(wanted) > 0.0001:
			return false
	return true

func button_for_species(id: String) -> Button:
	var prefix: String = game.ecology.get_species_data()[id].name + "  /  "
	for child in game.hud.menu_box.get_children():
		if child is Button and child.text.begins_with(prefix):
			return child
	return null

func body_text() -> String:
	return game.hud.menu_box.get_child(2).text

func wall_between(from: Vector3, to: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.2, 0.24)
	shape.shape = box
	wall.add_child(shape)
	game.add_child(wall)
	wall.global_position = from.lerp(to, 0.5)
	wall.look_at(to)
	return wall

func run() -> void:
	seed(4714)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	game.saves.directory = save_directory
	root.add_child(game)
	game.set_physics_process(false)
	await frames()
	game.start_new_game()
	freeze_player()
	# Declared persisted M1-complete fixture; no collection or travel claim.
	game.state.nav = "repaired"
	check(game._save_checkpoint(), "isolated M1-complete interface fixture is durable")
	await journal_at_720p()
	await six_buoys()
	await pause_and_focus_clocks()
	await relay_guards()
	await remote_observation()
	game.set_physics_process(false)
	paused = false
	freeze_player()
	game.sound.stop_all()
	await frames(10)
	game.queue_free()
	await frames(4)
	if failures.is_empty():
		print("M2_INTERFACE_OK checks=%d viewport=1280x720 fixture=positioned-interface-not-route saves=%s" % [checks, save_directory])
		quit(0)
	else:
		printerr("M2_INTERFACE_FAIL checks=%d failures=%d" % [checks, failures.size()])
		quit(1)

func journal_at_720p() -> void:
	section("14 real journal buttons / 720p scroll reach / unknown event masking")
	game.pause_game("journal")
	await frames(4)
	var catalog: Dictionary = game.ecology.get_species_data()
	check(catalog.size() == 14 and root.get_visible_rect().size == Vector2(1280, 720), "full catalog uses the actual 720p viewport")
	check(root.get_visible_rect().encloses(game.hud.panel.get_global_rect()), "journal panel stays entirely inside the 720p viewport")
	check(game.hud.scroll.get_v_scroll_bar().max_value > game.hud.scroll.size.y, "all species produce a genuinely scrollable menu")
	var reached_end := false
	for id in catalog:
		var button := button_for_species(id)
		if not is_instance_valid(button):
			check(false, "species has a real selectable button: " + id)
			continue
		game.hud.scroll.ensure_control_visible(button)
		await frames(3)
		var scroll_rect: Rect2 = game.hud.scroll.get_global_rect()
		var button_rect := button.get_global_rect()
		var reachable := not button.disabled and scroll_rect.encloses(button_rect) and root.get_visible_rect().encloses(button_rect)
		reached_end = reached_end or game.hud.scroll.scroll_vertical > 400
		# Press the actual connected Button. Geometry is independently checked;
		# this is not a claim about a human mouse or Windows renderer session.
		button.pressed.emit()
		await frames(3)
		check(reachable and game.m2.journal_species == id and catalog[id].name in body_text() and "未観察" in body_text() and catalog[id].description not in body_text(), "scroll reaches and selects unknown species without revealing its record: " + id)
	check(reached_end and game.observations.is_empty(), "visiting every entry scrolls to the lower list without granting observations")
	game.observations.wiwaxia = ["identified"]
	game.observations.resonance_urn = ["identified", "urn_resonated"]
	game._show_journal()
	await frames()
	check("識別済み" in button_for_species("wiwaxia").text and "行動確認済み" in button_for_species("resonance_urn").text and "未観察" in button_for_species("marrella").text, "unknown, identified and behavior-known statuses remain distinct")
	button_for_species("wiwaxia").pressed.emit()
	await frames()
	check("未確認の行動" in body_text() and "確認済：" not in body_text(), "identification alone does not disclose unobserved habits")
	dispatch("journal")
	freeze_player()
	check(not paused and game.hud.page.is_empty(), "normal Tab handler closes the scrolled journal")

func six_buoys() -> void:
	section("six real buoy placements / seventh rejection / return-save-load / recovery")
	check(game.depart_pod(), "interface fixture departs through the normal pod action")
	freeze_player()
	var previous := checkpoint_bytes()
	var expected: Array = []
	game.select_tool(4)
	for z in [-180.0, -225.0, -275.0, -315.0, -365.0, -410.0]:
		var at := Vector3(65, game.world.floor_height(65, z) + 8, z)
		locate(at, at + Vector3.FORWARD)
		game.use_lock = 0.0
		dispatch("use_tool")
		expected.append([at.x, at.y, at.z])
	check(game.state.buoys == expected and game.buoy_nodes.size() == 6, "normal tool input places six markers at new-sea coordinates")
	game.use_lock = 0.0
	dispatch("use_tool")
	game.hud.update_game(game)
	check(game.state.buoys.size() == 6 and "6 / 6" in game.hud.tool_label.text and "6 個" in game.toast_text, "seventh placement is rejected and HUD reports the same six-slot limit")
	check(checkpoint_bytes() == previous, "underwater buoy placement alone does not advance the checkpoint")
	locate(game.ENTRY, Vector3.ZERO)
	check(game.return_to_pod() and game.load_game(), "ordinary return saves new-sea buoys and loading accepts them")
	freeze_player()
	check(buoy_positions_match(expected), "all six coordinates and actual world markers survive reloading within 0.1 mm")
	check(game.depart_pod(), "saved buoys can be revisited")
	freeze_player()
	var last: Array = expected.back()
	var at := Vector3(last[0], last[1], last[2])
	locate(at, at + Vector3.FORWARD)
	game.use_lock = 0.0
	dispatch("interact")
	check(game.state.buoys.size() == 5 and game.buoy_nodes.size() == 5, "normal E handler recovers the nearby marker")
	at.z += 3.0
	locate(at, at + Vector3.FORWARD)
	game.use_lock = 0.0
	dispatch("use_tool")
	expected[5] = [at.x, at.y, at.z]
	locate(game.ENTRY, Vector3.ZERO)
	check(game.return_to_pod() and game.load_game() and buoy_positions_match(expected), "recovered slot can be relocated and the updated six-marker arrangement persists")
	freeze_player()

func clock_snapshot() -> Dictionary:
	var eco = game.ecology
	var animals: Array = []
	for animal in eco.palaeo.animals:
		animals.append([animal.age, animal.pending_delta, animal.state_time, animal.global_position])
	var urn = eco.graveyard.urns[0]
	var crawler = eco.graveyard.crawlers[0]
	var web = eco.plains.webs[0]
	return {"ecology": eco.age, "oxygen": game.state.oxygen, "web": [web.regrow_remaining, web.event_remaining, web.generation], "urn": [urn.age, urn.state_time, urn.sounds_emitted, urn.state], "crawler": [crawler.age, crawler.reaction_time, crawler.global_position], "palaeo": animals, "prey": eco.palaeo.soft_prey[0].remaining, "pickup": game.pickups[0].replenish, "pickup_count": game.pickups.size()}

func pause_and_focus_clocks() -> void:
	section("M2 game clocks stop for pause and focus loss, then resume without held tools")
	check(game.depart_pod(), "clock fixture leaves pod")
	locate(Vector3(65, -60, -275), Vector3(65, -60, -280))
	var eco = game.ecology
	check(eco.plains.webs[0].sever("cutter"), "real severed web starts regeneration and a single resource drop")
	check(eco.graveyard.urns[0].receive_stimulus(7701, 0, eco.graveyard.age + 6.0, eco.graveyard.age), "real urn warning is pending before pause")
	check(eco.graveyard.crawlers[0].hear_sound(eco.graveyard.crawlers[0].home + Vector3(3, 0, 0)), "crawler begins an actual bounded investigation")
	check(eco.palaeo.capture_prey(0, eco.palaeo.prey_position(0)), "real soft prey capture starts its regeneration clock")
	game.pickups[0].take()
	game.select_tool(1)
	game.set_physics_process(true)
	await frames(8)
	for pause_kind in ["menu", "focus"]:
		Input.action_press("forward")
		Input.action_press("sprint")
		Input.action_press("use_tool")
		if pause_kind == "menu": dispatch("pause")
		else: game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(paused and not Input.is_action_pressed("forward") and not Input.is_action_pressed("sprint") and not Input.is_action_pressed("use_tool") and eco.plains.cut_elapsed == 0.0, pause_kind + " clears movement and cutter hold")
		var before := clock_snapshot()
		await frames(18)
		check(clock_snapshot() == before, pause_kind + " freezes web regrowth, urn warning/audio event, crawler movement, palaeo/prey and pickup regeneration together")
		if pause_kind == "focus":
			game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
			check(paused, "focus return waits for an explicit resume")
		dispatch("pause")
		freeze_player()
		await frames(36)
		var after := clock_snapshot()
		check(not paused and after.ecology > before.ecology and after.web[0] < before.web[0] and after.urn[0] > before.urn[0] and after.crawler[0] > before.crawler[0] and after.palaeo[0][0] > before.palaeo[0][0] and after.prey < before.prey and after.pickup < before.pickup, pause_kind + " resumes every clock through the normal main physics loop")
		check(not Input.is_action_pressed("sprint") and not Input.is_action_pressed("use_tool"), pause_kind + " leaves no stuck sprint or cutter input")
	var old_light: bool = game.player.light_on
	game.use_lock = 0.0
	dispatch("light")
	check(game.player.light_on != old_light, "light input still works after focus recovery")
	game.set_physics_process(false)

func relay_guards() -> void:
	section("relay distance / look direction / solid occlusion / stale menu / death guards")
	game.resume_game()
	freeze_player()
	var relay: Vector3 = game.m2.relay_position()
	var previous := checkpoint_bytes()
	var old_checkpoint: Dictionary = game.checkpoint.duplicate(true)
	game.state.oxygen = 17
	locate(relay + Vector3(0, 1, 6), relay)
	check(not game.open_relay() and not game.refill_at_relay() and game.state.oxygen == 17, "distant interaction cannot remotely refill")
	locate(relay + Vector3(0, 0.6, 2), relay + Vector3(0, 0.6, 5))
	check(not game.open_relay() and not game.refill_at_relay(), "nearby equipment behind the camera is not usable")
	locate(relay + Vector3(0, 0.6, 2), relay)
	var wall := wall_between(game.player.camera.global_position, relay)
	await frames()
	check(not game.open_relay() and not game.refill_at_relay(), "solid terrain-mask obstruction blocks relay interaction")
	wall.queue_free()
	await frames()
	check(game.open_relay() and paused and game.hud.page == "relay", "clear nearby view opens the production relay menu")
	locate(relay + Vector3(0, 0, 6), relay)
	check(not game.refill_at_relay(), "open menu does not bypass subsequent distance validation")
	locate(relay + Vector3(0, 0.6, 2), relay)
	game.state.dead = true
	game.state.suit = 0
	check(not game.open_relay() and not game.refill_at_relay() and game.state.dead and game.state.oxygen == 17 and game.state.suit == 0, "dead-state API calls cannot resurrect even with an open menu")
	# Restore only the declared death guard fixture; normal death flow is tested elsewhere.
	game.state.dead = false
	var ecosystem_id: int = game.ecology.plains.get_instance_id()
	var drop_count: int = game.pickups.size()
	var at: Vector3 = game.player.position
	check(game.refill_at_relay(), "live valid menu can refill after the rejected calls")
	freeze_player()
	check(checkpoint_bytes() == previous and game.checkpoint == old_checkpoint and game.ecology.plains.get_instance_id() == ecosystem_id and game.pickups.size() == drop_count and game.player.position == at and not game.player.in_pod, "relay guards and successful refill never save, teleport, reset ecology or reset drops")

func remote_observation() -> void:
	section("off-screen M2 behavior is not recorded / visible behavior is recorded")
	game.resume_game()
	freeze_player()
	game.observations = {"resonance_urn": ["identified"], "threadgardener": ["identified"]}
	check(game.saves.write_json("observations", game.observations), "isolated notebook fixture is writable")
	var before := FileAccess.get_file_as_bytes(game.saves.path("observations"))
	var graveyard = game.ecology.graveyard
	var urn = graveyard.urns[1]
	locate(Vector3(65, -8, -20), urn.observation_position())
	check(urn.receive_stimulus(8801, 0, graveyard.age + 6, graveyard.age), "distant urn receives an actual finite stimulus")
	graveyard.tick(1.05)
	game.ecology.plains.webs[1].sever("cutter")
	check(urn.sounds_emitted > 0 and game.observations.resonance_urn == ["identified"] and game.observations.threadgardener == ["identified"] and FileAccess.get_file_as_bytes(game.saves.path("observations")) == before, "actual distant resonance and web cutting cannot grant unseen notebook events")
	graveyard.tick(12.1)
	var target: Vector3 = urn.observation_position()
	locate(target + Vector3(0, 0.8, 2), target)
	await frames()
	check(game.ecology.get_observation_target(game.player.camera) == urn, "visible positive-control view resolves the real urn")
	check(urn.receive_stimulus(8802, 0, graveyard.age + 6, graveyard.age), "nearby urn accepts a new stimulus after its normal cooldown")
	graveyard.tick(1.05)
	check("urn_resonated" in game.observations.resonance_urn and FileAccess.get_file_as_bytes(game.saves.path("observations")) != before, "same production event records only when its source is actually visible nearby")
