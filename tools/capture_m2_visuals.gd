extends SceneTree
## Declared static fixtures of the ordinary main scene. Frozen ecology is not
## evidence of reachability; actual Input route and motion manifests are separate.
const WorldMap = preload("res://data/biomes/world_map.gd")
var game
var output_dir := "res://build/m2/visuals"
var source_commit := "unknown"
var started := 0
var current_view := "startup"
var images: Array[Dictionary] = []
var notes := ""

func _initialize() -> void:
	started = Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		if args[i] == "--output": output_dir = args[i + 1]
		if args[i] == "--source-commit": source_commit = args[i + 1]
	call_deferred("run")

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started > 300000:
		printerr("M2_CAPTURE_FAIL timeout view=", current_view)
		quit(1)
	return false

func settle(count := 4) -> void:
	for _i in count: await process_frame

func bed(x: float, z: float, height: float) -> Vector3:
	return Vector3(x, game.world.floor_height(x, z) + height, z)

func camera(from: Vector3, at: Vector3, fov := 80.0, low := false) -> void:
	game.resume_game()
	game.player.relocate(from, false)
	game.player.active = false
	game.player.camera.look_at(at)
	game.settings.low_particles = low
	game.settings.fov = fov
	game.apply_settings()
	game.player.camera.fov = fov
	game.player.zoom_fov = fov
	game.player.light_on = true
	game.player.lamp.visible = true
	game.toast_remaining = 0

func shot(id: String, fixture_notes := "") -> void:
	current_view = id
	await settle()
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if frame.is_empty() or frame.save_png(output_dir.path_join(id + ".png")) != OK:
		printerr("M2_CAPTURE_FAIL image=", id)
		quit(1)
		return
	images.append({"id": id, "file": id + ".png", "width": frame.get_width(), "height": frame.get_height(), "camera_position": arr(game.player.camera.global_position), "camera_rotation": arr(game.player.camera.global_rotation), "fov": game.player.camera.fov, "light_on": game.player.light_on, "low_particles": game.settings.low_particles, "biome": WorldMap.id_at(game.player.global_position), "ecology_age": game.ecology.age, "hud_page": game.hud.page, "fixture": fixture_notes, "generated": true, "visual_review": "not implied by generation"})
	print("M2_CAPTURE_SAVED ", id)

func arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func animal(id: String):
	for creature in game.ecology.creatures:
		if creature.species_id == id: return creature
	return null

func observation(id: String, shot_id: String) -> void:
	var creature = animal(id)
	if not is_instance_valid(creature):
		printerr("M2_CAPTURE_FAIL missing creature=", id)
		quit(1)
		return
	var at: Vector3 = creature.observation_position()
	var offset := Vector3(0.12, 0.09, 0.17)
	var fov := 16.0
	if id == "anomalocaris":
		offset = Vector3(1.2, 0.5, 1.3)
		fov = 48.0
	camera(at + offset, at, fov)
	game.select_tool(0)
	game.observation_target = creature
	game.observe_time = 1.3
	await shot(shot_id, "Static observation camera close to unchanged life-size animal; declared observation zoom. No journal behavior unlock fixture.")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("M2_CAPTURE_FAIL non-headless renderer required")
		quit(1)
		return
	seed(4702)
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	game.saves.directory = "user://automated-tests/m2-visual-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	root.add_child(game)
	game.set_physics_process(false)
	game.start_new_game()
	game.state.nav = "repaired"
	if not game._save_checkpoint() or not game.depart_pod():
		printerr("M2_CAPTURE_FAIL isolated checkpoint")
		quit(1)
		return
	game.player.active = false
	camera(bed(8, -173, 5), bed(0, -193, 2))
	await shot("S01-plain-entrance")
	camera(bed(-8, -207, 3.2), bed(-12, -216, 1.8))
	await shot("S02-web-and-bladeworm")
	camera(bed(-8, -207, 3.2), bed(-12, -216, 1.8), 80, true)
	await shot("S02-web-low-particles")
	var relay := WorldMap.point("relay", game.world)
	camera(relay + Vector3(4, 3, 7), relay)
	await shot("S03-relay-landmark")
	camera(game.m2.relay_anchor() + Vector3(0, 0, 1.5), game.m2.relay_anchor())
	if not game.open_relay():
		printerr("M2_CAPTURE_FAIL relay menu fixture not reachable")
		quit(1)
		return
	await shot("S03-relay-instructions")
	camera(bed(12, -315, 10), bed(25, -360, 3))
	await shot("S04-graveyard-whole")
	camera(bed(25, -350, 2.4), bed(25, -367, 2))
	await shot("S05-shell-interior")
	camera(bed(17, -338, 2.4), bed(20, -347, 0.5))
	await shot("S06-urn-and-crawler")
	camera(bed(17, -338, 2.4), bed(20, -347, 0.5), 80, true)
	await shot("S06-urn-low-particles")
	await observation("wiwaxia", "S07-wiwaxia-observation")
	await observation("marrella", "S08-marrella-observation")
	await observation("anomalocaris", "S09-anomalocaris-observation")
	game.resume_game()
	game.player.relocate(game.POD, true)
	game.player.active = false
	game.settings.fov = 80.0
	game.player.camera.fov = 80.0
	game.pause_game("pod")
	await shot("S10-pod-m2-objective", "Isolated M1-complete checkpoint; M2 parts remain uncollected.")
	game.pause_game("journal")
	await shot("S11-inventory-and-journal", "Unobserved species remain unobserved; actual 14-species journal.")
	await settle()
	game.hud.scroll.scroll_vertical = int(game.hud.scroll.get_v_scroll_bar().max_value)
	await shot("S12-journal-last-species", "Scroll to bottom of actual journal to verify all species/buttons are reachable.")
	game.resume_game()
	game.player.active = false
	game.state.parts.damping_frame = "stored"
	game.state.parts.phase_regulator = "stored"
	if not game.stabilize_device():
		printerr("M2_CAPTURE_FAIL stabilization display fixture")
		quit(1)
		return
	await shot("S13-stabilization-complete", "Both parts declared stored solely for this UI fixture; actual production save/stabilization renders completion. Flow/routes separately test acquisition.")
	var file := FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": 1, "source_commit": source_commit, "seed": 4702, "world_seed": 503171, "engine": Engine.get_version_info().string, "os": OS.get_name(), "device": RenderingServer.get_video_adapter_name(), "renderer": "gl_compatibility", "scope": "Frozen main-scene ecology with declared camera, M1-complete checkpoint and final completion-UI fixtures; not movement proof, human play or performance", "save_directory": game.saves.directory, "normal_new_game_modified": false, "image_processing": "Raw Viewport PNG; no external enhancement", "images": images}, "\t"))
	file.close()
	print("M2_CAPTURE_OK images=%d output=%s" % [images.size(), output_dir])
	paused = false
	game.sound.stop_all()
	game.queue_free()
	await settle(8)
	quit(0)
