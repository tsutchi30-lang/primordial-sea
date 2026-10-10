extends SceneTree
## M1.5 comparison fixtures. Identical absolute cameras in the old and new game.
## Main ecology/physics is frozen only for these stills. Movement proof is separate.
const H := Vector3(10.0, -24.46673, -58.0)
const P := Vector3(0.0, -26.51208, -82.0)
var game
var output_dir := "res://build/m1-5/after"
var current_view := "startup"
var started_msec := 0
var manifest: Array[Dictionary] = []
var source_commit := "unknown"

func _initialize() -> void:
	started_msec = Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		if args[i] == "--output": output_dir = args[i + 1]
		if args[i] == "--source-commit": source_commit = args[i + 1]
	call_deferred("capture_all")

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started_msec > 210000:
		printerr("CAPTURE_FAIL timeout view=", current_view)
		quit(1)
	return false

func settle(count := 3) -> void:
	for _i in count: await process_frame

func fixture(from: Vector3, at: Vector3, light := false, low := false) -> void:
	game.player.relocate(from, false)
	game.player.active = false
	game.player.camera.global_position = from
	game.player.camera.look_at(at)
	game.player.base_fov = 80.0
	game.player.camera.fov = 80.0
	game.player.zoom_fov = 80.0
	game.player.light_on = light
	game.player.lamp.visible = light
	game.settings.low_particles = low
	game.apply_settings()
	game.player.camera.fov = 80.0
	game.toast_remaining = 0.0

func array3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func shot(id: String, from: Vector3, at: Vector3, light := false, low := false) -> void:
	current_view = id
	fixture(from, at, light, low)
	await settle(4)
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if frame.is_empty() or frame.save_png(output_dir.path_join(id + ".png")) != OK:
		printerr("CAPTURE_FAIL image ", id)
		quit(1)
		return
	var env: Environment = game.world.environment
	manifest.append({"id": id, "file": id + ".png", "width": frame.get_width(), "height": frame.get_height(), "camera_position": array3(from), "look_at": array3(at), "fov": 80, "light_on": light, "low_particles": low, "hogara_position": array3(game.ecology.hogara.global_position), "hogara_rotation": array3(game.ecology.hogara.global_rotation), "canopy_rotation": array3(game.ecology.hogara.canopy.rotation), "hogara_state": game.ecology.hogara.state, "hogara_age": game.ecology.hogara.age, "ecology_age": game.ecology.age, "predator_position": array3(game.ecology.predators[0].global_position), "predator_exposed_seconds": game.ecology.predators[0].exposed_remaining, "overlap_fixture": id == "S08-transparent-overlap", "ambient_energy": env.ambient_light_energy, "fog_density": env.fog_density, "generated": true, "visual_review": "not implied by generation"})
	print("CAPTURE_SAVED ", output_dir.path_join(id + ".png"))

func capture_all() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("CAPTURE_FAIL: non-headless rendering required")
		quit(1)
		return
	seed(4702)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var ignore := FileAccess.open(output_dir.path_join(".gdignore"), FileAccess.WRITE)
	ignore.close()
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	game.saves.directory = "user://automated-tests/visual-m15-%d" % OS.get_process_id()
	root.add_child(game)
	game.set_physics_process(false)
	await settle()
	game.start_new_game()
	game.depart_pod()
	game.player.active = false
	# Match the natural M1.5 initial route heading in BOTH versions. Old M1
	# does not turn toward its route by itself; this is a declared still fixture.
	game.ecology.hogara.rotation.y = -atan2(8.0, 18.0)
	# Three primary compositions at both resolutions; all material views at 1080p.
	await shot("S01-discovery", H + Vector3(8, 6, 17), H + Vector3(0, 3.5, 0))
	await shot("S02-whole", H + Vector3(11, 6, 13), H + Vector3(0, 3.5, 0))
	await shot("S05-belly-off", H + Vector3(0, 1.7, 0), H + Vector3(0, 2, -6))
	if root.size.x >= 1900:
		await shot("S03-shell-joint", H + Vector3(6.7, 2.6, 3.3), H + Vector3(2.5, 2.8, -1.1), true)
		await shot("S04-sail-front", H + Vector3(0, 7.1, 8.7), H + Vector3(0, 5.4, -0.3))
		await shot("S04-sail-back", H + Vector3(0, 7.1, -8.7), H + Vector3(0, 5.4, -0.3))
		await shot("S05-belly-on", H + Vector3(0, 1.7, 0), H + Vector3(0, 2, -6), true)
		await shot("S05-belly-low", H + Vector3(0, 1.7, 0), H + Vector3(0, 2, -6), false, true)
		await shot("S06-foot-contact", H + Vector3(8, 1.5, -1.0), H + Vector3(4, 0.25, -2.7), true)
		await shot("S07-normal-bright-off", P + Vector3(0, 0.5, 6), P)
		await shot("S07-normal-dark-on", P + Vector3(0, 0.5, -6), P, true)
		await shot("S07-normal-low", P + Vector3(0, 0.5, 6), P, false, true)
		# Isolated still fixture: bring the existing membrane behind the sail for a
		# transparent-surface stress view; not a naturally occurring encounter claim.
		game.ecology.predators[0].global_position = H + Vector3(0, 5.2, -4.2)
		await shot("S08-transparent-overlap", H + Vector3(2, 6.5, 10), H + Vector3(0, 5, -2))
		game.ecology.predators[0].global_position = P
		# Explicit visual fixture using production silt/reveal. Not proof of player input.
		game.settings.low_particles = false
		game.apply_settings()
		var cloud = game.ecology.spawn_silt(P - Vector3(0, 1.8, 0))
		cloud.tick(3.0)
		for predator in game.ecology.predators:
			if cloud.strength_at(predator.global_position) > 0.08:
				predator.reveal(2.0)
				predator._update_visual(0.0)
		await shot("S07-silt-bright-off", P + Vector3(0, 0.5, 6), P)
		await shot("S07-silt-dark-on", P + Vector3(0, 0.5, -6), P, true)
		await shot("S07-silt-low", P + Vector3(0, 0.5, 6), P, false, true)
	var file := FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": 2, "source_commit": source_commit, "seed": 4702, "world_seed": 503171, "engine": Engine.get_version_info().string, "os": OS.get_name(), "display": DisplayServer.get_name(), "device": RenderingServer.get_video_adapter_name(), "renderer": "gl_compatibility", "scope": "fixed initial ecology, frozen game physics, absolute camera fixtures; not a movement test, Windows playtest or performance benchmark", "orientation_fixture": "hogara root yaw = -atan2(8,18) in both versions; production canopy/leg pose retained", "image_processing": "raw Viewport PNG; no external enhancement", "images": manifest}, "\t"))
	file.close()
	print("CAPTURE_OK images=%d output=%s" % [manifest.size(), output_dir])
	paused = false
	game.sound.stop_all()
	game.queue_free()
	await settle(8)
	quit(0)
