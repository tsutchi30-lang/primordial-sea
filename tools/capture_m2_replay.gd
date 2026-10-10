extends SceneTree
## M2 production replay. A declared M1-complete checkpoint and one initial diver
## placement shorten each capture. No AI/state/speed changes or later teleports.
const Pilot = preload("res://tools/capture_m2_common.gd")
const Controls = preload("res://scripts/player/controls.gd")
const WorldMap = preload("res://data/biomes/world_map.gd")
var game
var mode := "plains"
var output_dir := "res://build/m2/motion"
var source_commit := "unknown"
var started := 0
var elapsed := 0.0
var duration := 50.0
var active := false
var finished := false
var start_position := Vector3.ZERO
var previous_position := Vector3.ZERO
var distance_swum := 0.0
var phase := "startup"
var previous_phase := ""
var flee := false
var initial_crawler_position := Vector3.ZERO
var crawler_displacement := 0.0
var aligned_low_entrance := false
var passed_low_entrance := false
var entered_shell := false
var exited_shell := false
var passed_grazed_opening := false
var events: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var transitions: Array[Dictionary] = []
var next_sample := 0.0
var previous_states := ""
var live_started_us := 0
var last_frame_us := 0
var frame_times: Array[float] = []
var frames := 0
var collected := false

func _initialize() -> void:
	started = Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		if args[i] == "--output": output_dir = args[i + 1]
		if args[i] == "--mode": mode = args[i + 1]
		if args[i] == "--source-commit": source_commit = args[i + 1]
	if mode == "metrics": duration = 15.0
	call_deferred("start")

func start() -> void:
	seed(4702)
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	game.saves.directory = "user://automated-tests/m2-replay-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	root.add_child(game)
	game.set_physics_process(false)
	game.start_new_game()
	game.state.nav = "repaired"
	if not game._save_checkpoint() or not game.depart_pod():
		finish(false, "isolated M2 checkpoint initialization failed")
		return
	game.state.bait = 0
	game.state.pulse = 0
	game.settings.fov = 80.0
	game.settings.shake = 0.0
	game.settings.low_particles = false
	game.apply_settings()
	game.player.light_on = true
	game.player.lamp.visible = true
	game.toast_remaining = 0
	var initial := bed(-12, -210, 2.1)
	if mode in ["graveyard", "metrics"]: initial = bed(14, -338, 1.5)
	game.player.relocate(initial, false)
	game.player.active = true
	start_position = initial
	previous_position = initial
	initial_crawler_position = game.ecology.graveyard.crawlers[0].global_position
	game.ecology.observed_event.connect(func(species: String, event: String): record_event(species, event))
	game.ecology.behavior_observed.connect(func(creature: Node3D, event: String): record_event(creature.species_id, event))
	Pilot.look(game.player, bed(-12, -216, 1.8) if mode == "plains" else game.ecology.graveyard.urns[1].observation_position())
	await process_frame
	game.set_physics_process(true)
	game.use_lock = 0
	active = true
	live_started_us = Time.get_ticks_usec()
	last_frame_us = live_started_us
	print("M2_REPLAY_START mode=%s position=%s" % [mode, initial])

func bed(x: float, z: float, height: float) -> Vector3:
	return Vector3(x, game.world.floor_height(x, z) + height, z)

func record_event(species: String, event: String) -> void:
	# Events are production signals, not a claim the player acquired a journal entry.
	if active: events.append({"t": elapsed, "species": species, "event": event})

func _process(_delta: float) -> bool:
	if not finished and Time.get_ticks_msec() - started > 1080000:
		finish(false, "watchdog phase=" + phase)
	if active:
		var now := Time.get_ticks_usec()
		if mode == "metrics" and now - live_started_us > 1000000:
			frame_times.append((now - last_frame_us) / 1000.0)
		last_frame_us = now
		frames += 1
	return false

func _physics_process(delta: float) -> bool:
	if not active or finished: return false
	if paused or game.mode != "play" or game.state.dead:
		finish(false, "unexpected pause or death")
		return false
	elapsed += delta
	distance_swum += game.player.global_position.distance_to(previous_position)
	previous_position = game.player.global_position
	if mode == "plains": plains_input(delta)
	else: graveyard_input(delta)
	if phase != previous_phase:
		print("M2_REPLAY_PHASE t=%.2f %s position=%s" % [elapsed, phase, game.player.global_position])
		previous_phase = phase
	var predator = game.ecology.plains.predator
	var crawler = game.ecology.graveyard.crawlers[0]
	crawler_displacement = maxf(crawler_displacement, crawler.global_position.distance_to(initial_crawler_position))
	var states := "%s|%s|%s" % [predator.state, game.ecology.graveyard.urns[1].state, crawler.state]
	if states != previous_states:
		transitions.append({"t": elapsed, "predator": predator.state, "urn": game.ecology.graveyard.urns[1].state, "crawler": crawler.state, "crawler_position": Pilot.arr(crawler.global_position), "predator_position": Pilot.arr(predator.global_position)})
		previous_states = states
	if elapsed >= next_sample:
		var web_data: Array[Dictionary] = []
		for web in game.ecology.plains.webs:
			web_data.append({"id": web.patch_id, "intact": web.intact})
		samples.append({"t": elapsed, "phase": phase, "player": Pilot.arr(game.player.global_position), "oxygen": game.state.oxygen, "suit": game.state.suit, "slides": game.player.get_slide_collision_count(), "speed_scale": game.player.external_speed_scale, "sprint": game.player.sprinting, "predator": Pilot.arr(predator.global_position), "predator_state": predator.state, "snare_count": predator.snare_count, "crawler": Pilot.arr(crawler.global_position), "crawler_state": crawler.state, "urn_state": game.ecology.graveyard.urns[1].state, "webs": web_data})
		next_sample += 0.25
	if elapsed >= duration:
		var ok: bool = game.state.oxygen < 479 and distance_swum > 5
		if mode == "plains": ok = ok and predator.snare_count > 0 and has_event("web_grazed") and passed_grazed_opening
		if mode == "graveyard": ok = ok and has_event("urn_resonated") and crawler_displacement > 3 and game.ecology.graveyard.propagated_count > 0 and passed_low_entrance and entered_shell and exited_shell and collected
		finish(ok, "production ecology and input replay completed")
	return false

func plains_input(delta: float) -> void:
	var predator = game.ecology.plains.predator
	var goal: Vector3
	var gaze: Vector3
	var sprint := false
	if elapsed < 9:
		phase = "discover-web-and-natural-grazing"
		goal = bed(-12, -210, 2.1)
		gaze = bed(-12, -216, 1.8)
	elif elapsed < 16:
		phase = "swim-through-natural-opening"
		goal = bed(-12, -219, 2.0)
		gaze = bed(-12, -219, 1.8)
	else:
		if predator.state == "dash" or predator.snare_count > 0: flee = true
		if not flee:
			phase = "approach-intact-trap-and-read-windup"
			goal = bed(-5, -221.2, 2.0)
		elif predator.snare_count == 0:
			phase = "draw-dash-through-web"
			goal = bed(-5, -216.8, 2.0)
			sprint = true
		elif elapsed < 36:
			phase = "observe-physical-snare-and-release"
			goal = bed(-2, -218, 2.0)
		else:
			phase = "take-open-outer-side"
			goal = bed(3, -226, 2.8)
		gaze = predator.observation_position()
	if game.player.global_position.z < -217.5 and absf(game.player.global_position.x + 12) < 1.2: passed_grazed_opening = true
	Pilot.look(game.player, gaze, delta * 3.0)
	Pilot.drive(game.player, goal, sprint, 4.2 if sprint else 2.6)

func graveyard_input(delta: float) -> void:
	var urn = game.ecology.graveyard.urns[1]
	var crawler = game.ecology.graveyard.crawlers[0]
	var goal: Vector3
	var gaze: Vector3
	var sprint := false
	if elapsed < 3:
		phase = "approach-side-urn"
		goal = bed(14, -341, 1.5)
		gaze = urn.observation_position()
	elif elapsed < 4.5:
		phase = "stimulate-with-shift"
		goal = bed(14, -343.5, 1.5)
		gaze = urn.observation_position()
		sprint = true
	elif elapsed < 7.5:
		phase = "membrane-warning-and-propagation"
		goal = bed(17, -342, 1.5)
		gaze = urn.observation_position()
	elif elapsed < 16:
		phase = "crawler-leaves-passage"
		if game.player.global_position.distance_to(bed(25, -346, 0.55)) < 0.22:
			aligned_low_entrance = true
		goal = bed(25, -350, 0.55) if aligned_low_entrance else bed(25, -346, 0.55)
		gaze = crawler.observation_position() if elapsed < 11 else bed(25, -354, 2.0)
	elif elapsed < 22:
		phase = "enter-shell"
		goal = bed(25, -362.5, 1.9)
		gaze = WorldMap.point("phase_regulator", game.world)
	elif elapsed < 27:
		phase = "collect-phase-regulator"
		goal = bed(25, -364, 1.9)
		gaze = WorldMap.point("phase_regulator", game.world)
		if not collected and game.player.global_position.distance_to(gaze) < 3:
			Pilot.look(game.player, gaze)
			Pilot.tap("interact")
			collected = game.state.parts.phase_regulator == "carried"
	elif elapsed < 34:
		phase = "find-side-exit"
		goal = bed(37, -366, 2.4)
		gaze = bed(43, -366, 2.4)
	elif elapsed < 43:
		phase = "leave-through-visible-side-opening"
		goal = bed(46, -366, 2.4)
		gaze = bed(47, -366, 2.4)
	else:
		phase = "read-return-path"
		goal = bed(47, -353, 3)
		gaze = WorldMap.point("relay", game.world)
	var at: Vector3 = game.player.global_position
	if aligned_low_entrance and absf(at.x - 25) < 0.25 and at.z < -349 and at.z > -351 and at.y - game.world.floor_height(at.x, at.z) < 0.85:
		passed_low_entrance = true
	if game.player.global_position.z < -353 and game.player.global_position.x < 34: entered_shell = true
	if entered_shell and game.player.global_position.x > 43: exited_shell = true
	Pilot.look(game.player, gaze, delta * 3.0)
	Pilot.drive(game.player, goal, sprint, 4.2 if sprint else 2.6)

func has_event(id: String) -> bool:
	for event in events:
		if event.event == id: return true
	return false

func finish(ok: bool, reason: String) -> void:
	if finished: return
	finished = true
	active = false
	Controls.release_all()
	var performance := {}
	if mode == "metrics" and not frame_times.is_empty():
		frame_times.sort()
		var sum := 0.0
		for value in frame_times: sum += value
		performance = {"realtime": true, "warmup_seconds": 1, "samples": frame_times.size(), "average_frame_ms": sum / frame_times.size(), "p95_frame_ms": frame_times[int(frame_times.size() * 0.95)], "p99_frame_ms": frame_times[int(frame_times.size() * 0.99)], "worst_frame_ms": frame_times.back(), "scope": "Linux renderer only; not Windows GPU performance"}
	var file := FileAccess.open(output_dir.path_join(mode + "-manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": 1, "mode": mode, "passed": ok, "reason": reason, "source_commit": source_commit, "seed": 4702, "world_seed": 503171, "engine": Engine.get_version_info().string, "os": OS.get_name(), "device": RenderingServer.get_video_adapter_name(), "renderer": "gl_compatibility", "resolution": [root.size.x, root.size.y], "fov": 80, "light_on": true, "low_particles": false, "capture": "headless input probe" if DisplayServer.get_name() == "headless" else ("realtime unpaced render" if mode == "metrics" else "offline MovieMaker at 24fps"), "fixture": "normal new game in isolated save -> declared M1-complete checkpoint -> depart -> one initial diver placement; no AI changes", "initial_position": Pilot.arr(start_position), "per_frame_player_teleports": 0, "creature_state_overrides": 0, "tank_capacity": game.state.capacity(), "cutter_seconds": game.state.cutter_seconds(), "bait": 0, "pulse": 0, "game_seconds": elapsed, "wall_seconds": (Time.get_ticks_usec() - live_started_us) / 1000000.0, "distance_swum": distance_swum, "oxygen_final": game.state.oxygen, "passed_grazed_opening": passed_grazed_opening, "crawler_max_displacement": crawler_displacement, "passed_low_entrance": passed_low_entrance, "entered_shell": entered_shell, "exited_shell": exited_shell, "collected_phase_regulator": collected, "events": events, "transitions": transitions, "samples": samples, "performance": performance}, "\t"))
	file.close()
	print("M2_REPLAY_OK" if ok else "M2_REPLAY_FAIL", " mode=%s time=%.2f distance=%.2f oxygen=%.2f reason=%s" % [mode, elapsed, distance_swum, game.state.oxygen, reason])
	call_deferred("shutdown", ok)

func shutdown(ok: bool) -> void:
	paused = false
	game.set_physics_process(false)
	game.player.active = false
	game.sound.stop_all()
	OS.delay_msec(120)
	game.queue_free()
	for _i in 8: await process_frame
	quit(0 if ok else 1)
