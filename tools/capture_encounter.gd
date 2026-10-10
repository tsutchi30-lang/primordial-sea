extends SceneTree
## Live main-scene replay: only the initial encounter fixture relocates the diver.
## Thereafter Input actions drive the unmodified diver physics, collision, oxygen,
## AI and animation. No creature state, speed, route or clock is overwritten.
const Controls = preload("res://scripts/player/controls.gd")
var game
var mode := "encounter"
var output_dir := "res://build/m1-5/motion"
var source_commit := "unknown"
var enabled := false
var finished := false
var elapsed := 0.0
var phase := "startup"
var duration := 44.0
var started_ms := 0
var live_started_us := 0
var last_frame_us := 0
var frame_times: Array[float] = []
var samples: Array[Dictionary] = []
var transitions: Array[Dictionary] = []
var next_sample := 0.0
var last_state := ""
var last_phase := ""
var start_position := Vector3.ZERO
var previous_position := Vector3.ZERO
var previous_hogara := Vector3.ZERO
var distance_swum := 0.0
var inside_seconds := 0.0
var inside_start := Vector3.ZERO
var inside_travel := 0.0
var entered := false
var exited := false
var way_index := 0
var frame_count := 0
var headless := false

func _initialize() -> void:
	started_ms = Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		if args[i] == "--output": output_dir = args[i + 1]
		if args[i] == "--mode": mode = args[i + 1]
		if args[i] == "--source-commit": source_commit = args[i + 1]
	if mode == "gait": duration = 46.0
	if mode == "pod-route": duration = 90.0
	if mode == "metrics": duration = 15.0
	headless = DisplayServer.get_name() == "headless"
	call_deferred("start")

func start() -> void:
	seed(4702)
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	game.saves.directory = "user://automated-tests/replay-m15-%d" % OS.get_process_id()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_new_game()
	game.depart_pod()
	game.settings.fov = 80.0
	game.settings.shake = 0.0
	game.settings.low_particles = false
	game.apply_settings()
	game.player.light_on = false
	game.player.lamp.visible = false
	game.player.camera.fov = 80
	game.player.zoom_fov = 80
	game.toast_remaining = 0
	if mode != "pod-route":
		var offset := Vector3(8, 6, 17)
		if mode == "gait": offset = Vector3(7, 1.5, -0.8)
		game.player.relocate(game.ecology.hogara.global_position + offset, false)
		game.player.active = true
	start_position = game.player.global_position
	previous_position = start_position
	previous_hogara = game.ecology.hogara.global_position
	look_at_point(game.ecology.hogara.observation_position(), 1.0)
	await process_frame
	game.set_physics_process(true)
	live_started_us = Time.get_ticks_usec()
	last_frame_us = live_started_us
	enabled = true
	print("REPLAY_START mode=%s position=%s" % [mode, start_position])

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started_ms > 900000:
		printerr("REPLAY_FAIL watchdog mode=%s phase=%s t=%.2f" % [mode, phase, elapsed])
		quit(1)
	if enabled:
		var now := Time.get_ticks_usec()
		if mode == "metrics" and now - live_started_us > 1000000:
			frame_times.append((now - last_frame_us) / 1000.0)
		last_frame_us = now
		frame_count += 1
	return false

func _physics_process(delta: float) -> bool:
	if not enabled or finished: return false
	if paused or game.mode != "play" or game.state.dead:
		finish(false, "unexpected pause/death/game mode")
		return false
	elapsed += delta
	var h = game.ecology.hogara
	var velocity_h: Vector3 = (h.global_position - previous_hogara) / maxf(delta, 0.001)
	previous_hogara = h.global_position
	distance_swum += game.player.global_position.distance_to(previous_position)
	previous_position = game.player.global_position
	var inside: bool = h.contains(game.player.global_position)
	if inside:
		inside_seconds += delta
		if not entered:
			entered = true
			inside_start = game.player.global_position
		inside_travel = maxf(inside_travel, inside_start.distance_to(game.player.global_position))
	elif entered and elapsed > 26.0:
		exited = true
	if h.state != last_state:
		transitions.append({"t": elapsed, "state": h.state, "player_inside": inside})
		last_state = h.state
	var target: Vector3
	var gaze: Vector3
	if mode == "pod-route":
		var waypoints := [Vector3(14,-8,-26), Vector3(18,-15,-44)]
		phase = "pod-swim-%d" % way_index
		if way_index < waypoints.size():
			target = waypoints[way_index]
			if game.player.global_position.distance_to(target) < 1.3:
				way_index += 1
				if way_index >= waypoints.size(): target = hogara_point(Vector3(6, 2.3, 0.85))
		else:
			target = hogara_point(Vector3(6, 2.3, 0.85))
		gaze = target
		if way_index >= waypoints.size() and game.player.global_position.distance_to(target) < 2.0:
			finish(distance_swum > 40 and game.state.oxygen < 460, "pod-to-encounter reached using live Input actions")
			return false
	elif mode == "gait":
		phase = "feet-and-ground" if elapsed < 22 else "decelerate-rest-restart"
		target = hogara_point(Vector3(7.0, 1.7, -0.8) if elapsed < 22 else Vector3(9, 4.3, 7))
		gaze = hogara_point(Vector3(3.3, 0.6, -2.5) if elapsed < 22 else Vector3(0, 3.0, 0))
	else:
		if elapsed < 4:
			phase = "approach"
			target = hogara_point(Vector3(10,5,10))
			gaze = hogara_point(Vector3(0,3.5,0))
		elif elapsed < 8:
			phase = "whole-body"
			target = hogara_point(Vector3(9,4,8))
			gaze = hogara_point(Vector3(0,3.5,0))
		elif elapsed < 13:
			phase = "shell-leg-detail"
			target = hogara_point(Vector3(5.8,2.1,0.85))
			gaze = hogara_point(Vector3(2.8,2.5,-0.7))
		elif elapsed < 17:
			phase = "align-visible-entry"
			target = hogara_point(Vector3(4.8,1.7,0.85))
			gaze = hogara_point(Vector3(0,2.0,0.85))
		elif elapsed < 21:
			phase = "enter"
			target = hogara_point(Vector3(1.4,1.7,0.85))
			gaze = hogara_point(Vector3(0,2.2,-3))
		elif elapsed < 26:
			phase = "alongside"
			target = hogara_point(Vector3(0.4,1.7,0.85))
			gaze = hogara_point(Vector3(0,2.4,-4.5))
		elif elapsed < 31:
			phase = "exit-through-gap"
			target = hogara_point(Vector3(6.2,1.7,0.85))
			gaze = hogara_point(Vector3(7,2.2,0.85))
		else:
			phase = "rest-and-restart"
			target = hogara_point(Vector3(10,4.5,8))
			gaze = hogara_point(Vector3(0,3.5,0))
	if phase != last_phase:
		print("REPLAY_PHASE t=%.2f %s player=%s hogara=%s" % [elapsed, phase, game.player.global_position, h.global_position])
		last_phase = phase
	look_at_point(gaze, delta * 2.5)
	drive(target, velocity_h if mode != "pod-route" or way_index >= 2 else Vector3.ZERO)
	if elapsed >= next_sample:
		samples.append({"t": elapsed, "phase": phase, "player": arr(game.player.global_position), "hogara": arr(h.global_position), "state": h.state, "inside": inside, "oxygen": game.state.oxygen, "suit": game.state.suit, "distance_swum": distance_swum, "slides": game.player.get_slide_collision_count(), "input": [Input.get_action_strength("forward"), Input.get_action_strength("back"), Input.get_action_strength("left"), Input.get_action_strength("right"), Input.get_action_strength("ascend"), Input.get_action_strength("descend")]})
		next_sample += 0.5
	if elapsed >= duration:
		var ok: bool = game.state.oxygen < 479 and distance_swum > 5
		if mode == "encounter": ok = ok and entered and exited and inside_seconds > 2.0 and inside_travel > 1.0
		if mode == "pod-route": ok = false
		if mode == "gait":
			var states: Array = transitions.map(func(item): return item.state)
			ok = ok and states.has("rest_warning") and states.has("rest") and states.count("walk") >= 2
		finish(ok, "live replay complete")
	return false

func hogara_point(offset: Vector3) -> Vector3:
	var animal = game.ecology.hogara
	var body = animal.get("model")
	return body.to_global(offset) if body is Node3D else animal.to_global(offset)

func arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func look_at_point(point: Vector3, weight: float) -> void:
	var direction: Vector3 = (point - game.player.camera.global_position).normalized()
	game.player.rotation.y = lerp_angle(game.player.rotation.y, atan2(-direction.x, -direction.z), minf(weight, 1))
	game.player.camera.rotation.x = lerp_angle(game.player.camera.rotation.x, asin(clampf(direction.y, -0.996, 0.996)), minf(weight, 1))

func drive(target: Vector3, feed_forward: Vector3) -> void:
	var desired: Vector3 = ((target - game.player.global_position) * 1.7 + feed_forward).limit_length(2.4) / 2.8
	var forward: Vector3 = -game.player.camera.global_basis.z
	var right: Vector3 = game.player.camera.global_basis.x
	var flat_forward := Vector3(forward.x, 0, forward.z).normalized()
	var ahead := desired.dot(flat_forward) / maxf(0.15, Vector2(forward.x, forward.z).length())
	var across := desired.dot(right)
	var planar := Vector2(across, -ahead).limit_length(1.0)
	# Invert get_vector's circular InputMap deadzone; the production diver still
	# applies normalisation, inertia and collision to these ordinary action values.
	var magnitude := planar.length()
	if magnitude > 0.001:
		var deadzone := InputMap.action_get_deadzone("forward")
		planar = planar.normalized() * (deadzone + (1.0 - deadzone) * magnitude)
	var up := clampf(desired.y - forward.y * ahead, -1, 1)
	set_axis("left", "right", planar.x)
	set_axis("forward", "back", planar.y)
	set_axis("descend", "ascend", up)
	Input.action_release("sprint")

func set_axis(negative: String, positive: String, value: float) -> void:
	Input.action_release(negative)
	Input.action_release(positive)
	if value < -0.001: Input.action_press(negative, -value)
	if value > 0.001: Input.action_press(positive, value)

func finish(ok: bool, reason: String) -> void:
	if finished: return
	finished = true
	enabled = false
	Controls.release_all()
	var performance_data := {}
	if mode == "metrics" and not frame_times.is_empty():
		frame_times.sort()
		var sum := 0.0
		for value in frame_times: sum += value
		performance_data = {"realtime": true, "warmup_seconds": 1, "samples": frame_times.size(), "average_frame_ms": sum / frame_times.size(), "p95_frame_ms": frame_times[int(frame_times.size() * 0.95)], "p99_frame_ms": frame_times[int(frame_times.size() * 0.99)], "worst_frame_ms": frame_times.back(), "warning": "Linux software renderer measurements; not Windows GPU performance"}
	var file := FileAccess.open(output_dir.path_join(mode + "-manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": 1, "mode": mode, "passed": ok, "reason": reason, "source_commit": source_commit, "seed": 4702, "world_seed": 503171, "engine": Engine.get_version_info().string, "os": OS.get_name(), "device": RenderingServer.get_video_adapter_name(), "renderer": "gl_compatibility", "resolution": [root.size.x, root.size.y], "fov": 80, "light_on": false, "low_particles": false, "capture": "headless input replay" if headless else ("realtime unpaced render" if mode == "metrics" else "offline Movie Maker at 24 fps; not a realtime FPS claim"), "initial_fixture": "normal new game -> depart_pod" if mode == "pod-route" else "normal new game -> depart_pod -> one initial diver relocation; normal creature initial state", "initial_position": arr(start_position), "creature_state_overrides": 0, "per_frame_player_teleports": 0, "movement": "Input.action_press/release -> production Diver._physics_process -> move_and_slide; look angles replayed smoothly", "game_seconds": elapsed, "wall_seconds": (Time.get_ticks_usec() - live_started_us) / 1000000.0, "distance_swum": distance_swum, "oxygen_final": game.state.oxygen, "entered": entered, "exited": exited, "inside_seconds": inside_seconds, "alongside_distance": inside_travel, "state_transitions": transitions, "performance": performance_data, "samples": samples}, "\t"))
	file.close()
	print("REPLAY_OK" if ok else "REPLAY_FAIL", " mode=%s t=%.2f entered=%s exited=%s inside=%.2f travel=%.2f oxygen=%.2f reason=%s" % [mode, elapsed, entered, exited, inside_seconds, distance_swum, game.state.oxygen, reason])
	call_deferred("shutdown", ok)

func shutdown(ok: bool) -> void:
	game.set_physics_process(false)
	game.player.active = false
	game.sound.stop_all()
	# Allow the audio mixing thread to release queued streams, even when headless
	# fixed-fps physics advances much faster than wall time.
	OS.delay_msec(120)
	game.queue_free()
	for _i in 8: await process_frame
	quit(0 if ok else 1)
