extends SceneTree
## Deterministic representative views of the real main scene, with fixture camera
## placement and chapter-completion setup. This is visual evidence, not playtesting.

var game
var output_dir := "res://build/screenshots/manual"
var current_view := "startup"
var started_msec := 0
var manifest: Array[Dictionary] = []

func _initialize() -> void:
	started_msec = Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	for index in range(args.size() - 1):
		if args[index] == "--output":
			output_dir = args[index + 1]
	call_deferred("capture_all")

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started_msec > 150000:
		printerr("CAPTURE_FAIL timeout view=", current_view)
		quit(1)
	return false

func settle(count: int = 3) -> void:
	for _index in range(count):
		await process_frame

func aim(from: Vector3, at: Vector3) -> void:
	game.player.relocate(from, false)
	game.player.active = false
	game.player.camera.global_position = from
	game.player.camera.look_at(at)
	game.player.camera.fov = 74
	game.player.zoom_fov = 74
	game.player.lamp.visible = true
	game.toast_remaining = 0

func creature(id: String):
	for item in game.ecology.creatures:
		if item.species_id == id:
			return item
	return null

func shot(name: String, description: String) -> void:
	current_view = name
	await settle(3)
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if frame.is_empty():
		printerr("CAPTURE_FAIL empty viewport ", name)
		quit(1)
		return
	var target := output_dir.path_join(name + ".png")
	var error := frame.save_png(target)
	if error != OK:
		printerr("CAPTURE_FAIL image write ", target, " error=", error)
		quit(1)
		return
	manifest.append({"file": name + ".png", "description": description, "width": frame.get_width(), "height": frame.get_height(), "camera": str(game.player.camera.global_position), "look": str(game.player.camera.global_rotation), "generated": true, "review_status": "Generation does not imply visual review. Review evidence is recorded separately in docs/PROGRESS.md."})
	print("CAPTURE_SAVED ", target)

func capture_all() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("CAPTURE_FAIL: headless rendering cannot produce visual verification")
		quit(1)
		return
	seed(4702)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var ignore_file := FileAccess.open(output_dir.path_join(".gdignore"), FileAccess.WRITE)
	ignore_file.close()
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	game.saves.directory = "user://automated-tests/visual-%d-%d" % [OS.get_process_id(), int(Time.get_unix_time_from_system() * 1000000)]
	root.add_child(game)
	await settle()
	game.start_new_game()
	game.set_physics_process(false)
	game.player.active = false
	await shot("01-pod", "ポッドと初回目標")
	game.depart_pod()
	game.player.active = false
	aim(Vector3(6, -5, -15), Vector3(-2, -10, -30))
	await shot("02-shallows", "明るい浅瀬・海綿・小型生物")
	for id in ["opabinia", "hallucigenia", "olenoides"]:
		var small = creature(id)
		var at: Vector3 = small.observation_position()
		aim(at + Vector3(0.12, 0.06, -0.16), at)
		game.player.camera.fov = 40
		await shot("02-detail-" + id, "小型生物の形態・固定拡大カメラ")
		game.record_observation(id, "identified")
	var hogara = creature("hogara")
	if hogara != null:
		aim(hogara.global_position + Vector3(11, 6, 13), hogara.global_position + Vector3(0, 3.5, 0))
		await shot("03-hogara", "帆殻獣の全身")
		aim(hogara.global_position + Vector3(0, 1.7, 0), hogara.global_position + Vector3(0, 2, -5))
		await shot("04-hogara-shelter", "ホガラ腹側の泳げる空間")
	else:
		printerr("CAPTURE_FAIL missing hogara")
		quit(1)
		return
	var predator = creature("windoweater")
	if predator != null:
		aim(predator.global_position + Vector3(0, 0.5, 7), predator.global_position)
		await shot("05-predator-normal", "通常時の窓喰い・縁と膜の予兆")
		# Visual fixture uses the same cloud and reveal behavior as mud burrowing.
		var cloud = game.ecology.spawn_silt(predator.global_position - Vector3(0, 1.8, 0))
		cloud.tick(3.0)
		game.ecology.tick(0.05)
		if predator.exposed_remaining <= 0:
			printerr("CAPTURE_FAIL sand did not expose predator")
			quit(1)
			return
		await shot("06-predator-silt", "砂煙で露出した窓喰い")
	else:
		printerr("CAPTURE_FAIL missing windoweater")
		quit(1)
		return
	aim(game.nav_unit.global_position + Vector3(7, 3, 10), game.nav_unit.global_position)
	await shot("07-wreck", "航法ユニットの回収地点")
	game.pause_game("journal")
	await shot("08-journal", "図鑑・持ち物と閉じる案内")
	game._on_action("settings")
	await shot("09-settings", "感度・FOV・音量などの設定")
	game.resume_game()
	game.player.relocate(game.ENTRY, false)
	game.return_to_pod()
	# Visual fixture; the smoke test independently exercises genuine item collection.
	game.state.nav = "stored"
	game.state.stored_metal = 2
	game.repair_navigation()
	await shot("10-completion", "航法復旧編の完了と継続探索")
	var file := FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed": 4702, "engine": Engine.get_version_info().string, "display": DisplayServer.get_name(), "renderer": "gl_compatibility", "scope": "fixed-camera visual fixtures; not Windows playtest or FPS benchmark", "images": manifest}, "\t"))
	file.close()
	print("CAPTURE_OK images=%d output=%s" % [manifest.size(), output_dir])
	paused = false
	game.sound.stop_all()
	for _index in 10:
		await physics_frame
		await process_frame
	game.queue_free()
	await settle(4)
	quit(0)
