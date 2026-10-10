extends SceneTree
## Main-scene movement/oxygen evidence. Each declared route case may place its
## starting diver once. Every subsequent metre is normal Input + move_and_slide.
const Pilot = preload("res://tools/capture_m2_common.gd")
const Controls = preload("res://scripts/player/controls.gd")
const WorldMap = preload("res://data/biomes/world_map.gd")
var game
var output_dir := "res://build/m2/routes"
var source_commit := "unknown"
var started := 0
var elapsed := 0.0
var distance_swum := 0.0
var last_position := Vector3.ZERO
var min_oxygen := 480.0
var segment_start_time := 0.0
var segment_start_oxygen := 480.0
var segment_start_distance := 0.0
var active := false
var finished := false
var checks := 0
var failures: Array[String] = []
var segments: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var fixtures: Array[Dictionary] = []
var current_case := "startup"
var current_waypoint := -1
var next_sample := 0.0

func _initialize() -> void:
	started = Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		if args[i] == "--output": output_dir = args[i + 1]
		if args[i] == "--source-commit": source_commit = args[i + 1]
	call_deferred("run")

func _process(_delta: float) -> bool:
	if not finished and Time.get_ticks_msec() - started > 540000:
		printerr("M2_ROUTES_FAIL wall timeout case=%s waypoint=%d" % [current_case, current_waypoint])
		finish(false)
	return false

func _physics_process(delta: float) -> bool:
	if not active or paused: return false
	elapsed += delta
	min_oxygen = minf(min_oxygen, game.state.oxygen)
	distance_swum += game.player.global_position.distance_to(last_position)
	last_position = game.player.global_position
	if elapsed >= next_sample:
		samples.append({"t": elapsed, "case": current_case, "waypoint": current_waypoint, "position": Pilot.arr(game.player.global_position), "oxygen": game.state.oxygen, "suit": game.state.suit, "slides": game.player.get_slide_collision_count(), "speed_scale": game.player.external_speed_scale, "biome": WorldMap.id_at(game.player.global_position), "inputs": [Input.get_action_strength("forward"), Input.get_action_strength("back"), Input.get_action_strength("left"), Input.get_action_strength("right"), Input.get_action_strength("ascend"), Input.get_action_strength("descend")]})
		next_sample += 1
	return false

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(current_case + ": " + message)
		printerr("M2_ROUTE_FAILURE ", current_case, ": ", message)

func step() -> void:
	await physics_frame
	await process_frame

func start_case(name: String, start_id := "pod") -> void:
	active = false
	current_case = name
	game.start_new_game()
	game.state.nav = "repaired"
	check(game._save_checkpoint(), "isolated M1-complete checkpoint")
	check(game.depart_pod(), "normal depart")
	# Basic equipment and exhausted consumables are explicit conservative fixtures.
	game.state.bait = 0
	game.state.pulse = 0
	check(game.state.capacity() == 480 and is_equal_approx(game.state.cutter_seconds(), 1.2), "base tank and cutter")
	if start_id != "pod": game.player.relocate(WorldMap.point(start_id, game.world), false)
	game.player.active = true
	game.settings.shake = 0.0
	game.apply_settings()
	game.set_physics_process(true)
	game.use_lock = 0
	last_position = game.player.global_position
	fixtures.append({"case": name, "M1_complete_checkpoint": true, "starting_point": start_id, "initial_player_position": Pilot.arr(last_position), "initial_relocation": start_id != "pod", "initial_oxygen": game.state.oxygen, "tank_capacity": game.state.capacity(), "cutter_seconds": game.state.cutter_seconds(), "bait": 0, "pulse": 0, "ecology": "normal production reset; no creature-state overrides"})
	active = true
	begin_segment()
	print("M2_ROUTE_START ", name, " position=", last_position)

func begin_segment() -> void:
	segment_start_time = elapsed
	segment_start_oxygen = game.state.oxygen
	segment_start_distance = distance_swum
	min_oxygen = game.state.oxygen

func record_segment(name: String, supply: String) -> void:
	min_oxygen = minf(min_oxygen, game.state.oxygen)
	var value := {"id": name, "case": current_case, "capacity": game.state.capacity(), "oxygen_at_departure": segment_start_oxygen, "game_seconds": elapsed - segment_start_time, "distance_swum": distance_swum - segment_start_distance, "oxygen_before_supply": game.state.oxygen, "minimum_oxygen": min_oxygen, "remaining_fraction": game.state.oxygen / game.state.capacity(), "arrival": supply, "before_refill": true, "carried_parts": game.state.parts.duplicate(true), "position": Pilot.arr(game.player.global_position)}
	segments.append(value)
	check(not game.state.dead and min_oxygen >= 120, "known-route oxygen minimum at least 25% before supply: " + name)
	print("M2_ROUTE_SEGMENT ", JSON.stringify(value))

func swim(points: Array[Vector3], label: String) -> bool:
	for i in points.size():
		current_waypoint = i
		var target: Vector3 = points[i]
		var tolerance := 0.18 if absf(target.x - 28.0) < 0.1 and target.z >= -275.2 and target.z <= -269.5 else 0.7
		var began := elapsed
		var best: float = game.player.global_position.distance_to(target)
		var last_progress := elapsed
		while game.player.global_position.distance_to(target) > tolerance:
			if game.state.dead or game.mode != "play" or paused:
				check(false, label + " interrupted by death/pause")
				return false
			var remaining: float = game.player.global_position.distance_to(target)
			if remaining < best - 0.15:
				best = remaining
				last_progress = elapsed
			if elapsed - began > 160 or elapsed - last_progress > 16:
				var colliders: Array[String] = []
				for j in game.player.get_slide_collision_count():
					var body = game.player.get_slide_collision(j).get_collider()
					colliders.append(str(body.get_path()) if body is Node else str(body))
				check(false, "%s blocked waypoint=%d target=%s player=%s colliders=%s" % [label, i, target, game.player.global_position, colliders])
				Controls.release_all()
				return false
			Pilot.look(game.player, target, 0.12)
			Pilot.drive(game.player, target)
			await step()
	Controls.release_all()
	check(true, label + " all waypoints reached by production movement")
	return true

func route(id: String, reverse := false) -> Array[Vector3]:
	var points := WorldMap.route(id, game.world)
	if reverse: points.reverse()
	return points

func dwell(seconds: float) -> void:
	Controls.release_all()
	var end := elapsed + seconds
	while elapsed < end and not game.state.dead: await step()

func collect(id: String) -> void:
	var node = Pilot.pickup(game, id)
	check(is_instance_valid(node), "production target present: " + id)
	if not is_instance_valid(node): return
	Pilot.look(game.player, node.global_position)
	await dwell(2.5)
	check(game.collect_target(node), "actual range/aim/occlusion collection after swimming: " + id)
	check(game.state.parts[id] == "carried", "route cargo remains unbanked")

func refill_relay(segment: String) -> void:
	record_segment(segment, "relay")
	var position: Vector3 = game.player.global_position
	var parts: Dictionary = game.state.parts.duplicate(true)
	check(game.open_relay(), "relay opens at actual arrival")
	check(game.refill_at_relay(), "relay supplies oxygen and suit")
	check(game.player.global_position.is_equal_approx(position) and game.state.parts == parts and not game.player.in_pod, "relay retains current position and cargo")
	game.resume_game()
	game.use_lock = 0
	begin_segment()

func arrive_pod(segment: String) -> void:
	var final: Array[Vector3] = [WorldMap.point("pod", game.world)]
	await swim(final, "pod entry")
	record_segment(segment, "pod")
	check(game.return_to_pod(), "actual arrival banks cargo")
	active = false
	game.set_physics_process(false)

func run() -> void:
	seed(4702)
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	game.saves.directory = "user://automated-tests/m2-routes-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	root.add_child(game)
	game.set_physics_process(false)
	await step()
	start_case("R1-pod-relay-pod")
	if await swim(route("pod_relay"), "pod to relay"):
		refill_relay("pod-to-relay")
		await swim(route("pod_relay", true), "relay to pod")
		await arrive_pod("relay-to-pod")
	start_case("R2-relay-frame-relay-pod", "relay")
	if await swim(route("relay_damping"), "relay to frame"):
		await collect("damping_frame")
		await swim(route("relay_damping", true), "frame return")
		refill_relay("relay-frame-relay")
		await swim(route("pod_relay", true), "carried frame relay to pod")
		await arrive_pod("carried-frame-relay-to-pod")
		check(game.state.parts.damping_frame == "stored", "carried frame banked only at actual pod arrival")
	start_case("R3-relay-phase-main-rear-relay", "relay")
	if await swim(route("relay_shell"), "shell main entrance"):
		await collect("phase_regulator")
		await swim(route("shell_rear"), "shell rear exit")
		refill_relay("relay-phase-main-rear-relay")
	start_case("R4-shell-side-detour-roundtrip", "relay")
	if await swim(route("shell_detour"), "shell side alternate"):
		await collect("phase_regulator")
		await swim(route("shell_detour", true), "shell side return")
		refill_relay("relay-phase-side-relay")
	start_case("R5-plain-main-and-detour", "plain_entrance")
	if await swim(route("plain_main"), "natural web main route"):
		await collect("damping_frame")
		await swim(route("plain_detour", true), "web-free outer return")
		record_segment("plain-main-outer-return", "declared starting fixture; no refill")
	start_case("R6-plain-outer-roundtrip", "plain_entrance")
	if await swim(route("plain_detour"), "no-consumable outer route"):
		await collect("damping_frame")
		await swim(route("plain_detour", true), "outer retreat")
		record_segment("plain-outer-roundtrip", "declared starting fixture; no refill")
	for id in ["relay_damping", "relay_shell"]:
		start_case("R7-turnback-" + id, "relay")
		var half := route(id)
		half.resize(maxi(2, half.size() / 2))
		if await swim(half, "advance before turnaround"):
			half.reverse()
			await swim(half, "voluntary turnaround")
			refill_relay("turnback-" + id)
	finish(failures.is_empty())

func finish(ok: bool) -> void:
	if finished: return
	finished = true
	active = false
	Controls.release_all()
	var file := FileAccess.open(output_dir.path_join("routes-manifest.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"schema": 1, "source_commit": source_commit, "passed": ok, "checks": checks, "failures": failures, "seed": 4702, "world_seed": 503171, "engine": Engine.get_version_info().string, "scope": "headless actual Input, production collision/oxygen/ecology; deterministic informed routes, not first-time human play", "fixture_scope": "M1-complete checkpoint and initial starting position are declared per independent case; normal new game remains M1", "per_frame_player_teleports": 0, "creature_state_overrides": 0, "controller": "smooth look angles and analog Input action strengths; ordinary 2.8m/s cap, steering up to 2.6m/s; no speed/oxygen overrides during route", "fixtures": fixtures, "supply_segments": segments, "samples": samples, "game_seconds": elapsed, "distance_swum": distance_swum}, "\t"))
		file.close()
	print("M2_ROUTES_OK" if ok else "M2_ROUTES_FAIL", " checks=%d segments=%d game_seconds=%.2f distance=%.2f" % [checks, segments.size(), elapsed, distance_swum])
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
