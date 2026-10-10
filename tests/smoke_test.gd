extends SceneTree
## Runs production progression, save and scene code. No gameplay reimplementation.
## The shell runner also enforces a timeout and rejects SCRIPT ERROR output.

const Expedition = preload("res://scripts/progression/expedition.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const Controls = preload("res://scripts/player/controls.gd")
var failures: Array[String] = []
var checks := 0
var current_case := "startup"
var started_msec := 0
var game
var test_directory := ""

func _initialize() -> void:
	started_msec = Time.get_ticks_msec()
	test_directory = "user://automated-tests/run-%d-%d" % [OS.get_process_id(), int(Time.get_unix_time_from_system() * 1000000)]
	call_deferred("run")

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started_msec > 120000:
		printerr("SMOKE_FAIL timeout case=%s checks=%d" % [current_case, checks])
		quit(1)
	return false

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append("%s: %s" % [current_case, message])
		printerr("FAIL %s: %s" % [current_case, message])

func section(name: String) -> void:
	current_case = name
	print("CASE ", name)

func frames(count: int = 3) -> void:
	for _frame in range(count):
		await process_frame

func physics_frames(count: int = 3) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame

func run() -> void:
	seed(4702)
	test_oxygen_and_damage()
	test_checkpoint_contract()
	test_save_validation()
	test_metal_save_boundaries()
	await test_scene()
	if is_instance_valid(game):
		paused = false
		game.set_physics_process(false)
		game.sound.stop_all()
		await physics_frames(10)
		game.queue_free()
		await physics_frames(4)
	Controls.release_all()
	if failures.is_empty():
		print("SMOKE_OK checks=%d save_directory=%s" % [checks, test_directory])
		quit(0)
	else:
		printerr("SMOKE_FAIL failures=%d checks=%d last_case=%s" % [failures.size(), checks, current_case])
		quit(1)

func test_oxygen_and_damage() -> void:
	section("oxygen / external air / hypoxia / damage")
	var state = Expedition.new()
	state.tick(10, true, false)
	check(is_equal_approx(state.oxygen, 470), "underwater consumes elapsed seconds")
	state.tick(8, true, true)
	check(is_equal_approx(state.oxygen, 460), "sprint consumes 1.25x oxygen")
	state.tick(60, false, false)
	check(is_equal_approx(state.oxygen, 460), "external air stops consumption without refill")
	state.oxygen = 0
	state.tick(7.0, true, false)
	check(not state.dead, "seven seconds at zero preserves escape opportunity")
	state.tick(0.1, false, false)
	check(is_zero_approx(state.anoxia), "surfacing clears hypoxia grace timer")
	state.tick(7.9, true, false)
	check(not state.dead, "new dive starts a fresh eight second grace")
	var reason: String = state.tick(0.2, true, false)
	check(state.dead and not reason.is_empty(), "hypoxia death supplies a reason")
	check(not state.damage(100), "simultaneous damage cannot produce a second death")
	state.refill()
	check(state.oxygen == 480 and state.suit == 100 and not state.dead, "pod fully restores basic expedition")
	check(state.damage(28), "first predator attack applies")
	check(not state.damage(28) and state.suit == 72, "overlapping attack is blocked by invulnerability")
	state.tick(2.1, false, false)
	check(state.damage(28) and state.suit == 44, "subsequent attack applies after recovery")

func test_checkpoint_contract() -> void:
	section("unique item / deposit / repair / upgrade reserve")
	var state = Expedition.new()
	check(not state.repair(), "cannot repair before retrieving navigation unit")
	check(state.collect_nav() and not state.collect_nav(), "navigation unit is unique")
	state.carried_metal = 2
	var water_checkpoint: Dictionary = state.checkpoint()
	check(water_checkpoint.nav == "wreck" and water_checkpoint.stored_metal == 0, "unbanked inventory cannot become a checkpoint")
	state.deposit()
	check(state.nav == "stored" and state.carried_metal == 0 and state.stored_metal == 2, "return deposits important and ordinary items together")
	check(not state.upgrade_tank(), "tank upgrade cannot spend metal reserved for navigation")
	check(state.repair() and state.nav == "repaired" and state.stored_metal == 0, "repair consumes exactly two metal")
	check(not state.repair() and state.stored_metal == 0, "repeated repair cannot consume or duplicate items")
	state.stored_metal = 2
	check(state.upgrade_tank() and state.capacity() == 600, "optional upgrade works after repair")
	state.buoys = [[12.0, -10.0, -20.0]]
	var restored = Expedition.new()
	restored.restore(state.checkpoint())
	check(restored.nav == "repaired" and restored.tank_upgraded and restored.buoys.size() == 1, "completed progression, upgrade and buoy survive restore")

func test_save_validation() -> void:
	section("isolated atomic saves / corrupt data / settings")
	var saves = SaveStore.new()
	saves.directory = test_directory.path_join("unit")
	check(not saves.exists() and saves.load_checkpoint().is_empty(), "missing checkpoint is handled")
	var state = Expedition.new()
	check(saves.save_checkpoint(state.checkpoint()), "first checkpoint write succeeds")
	state.stored_metal = 2
	check(saves.save_checkpoint(state.checkpoint()), "atomic replacement succeeds")
	check(saves.load_checkpoint().get("stored_metal") == 2, "replacement contains latest complete snapshot")
	check(not FileAccess.file_exists(saves.path("checkpoint") + ".tmp"), "successful replacement leaves no temporary save")
	var settings = SaveStore.DEFAULT_SETTINGS.duplicate()
	settings.fov = 94.0
	settings.invert_y = true
	settings.master = 0.2
	check(saves.write_json("settings", settings), "settings save independently")
	var loaded: Dictionary = saves.load_settings()
	check(loaded.fov == 94 and loaded.invert_y and is_equal_approx(loaded.master, 0.2), "FOV, inversion and volume round trip")
	check(saves.load_checkpoint().get("stored_metal") == 2, "settings write does not overwrite checkpoint")
	var bad = state.checkpoint()
	bad.nav = "carried"
	saves.write_json("checkpoint", bad)
	check(saves.load_checkpoint().is_empty() and not saves.last_error.is_empty(), "waterborne important item is rejected in checkpoint")
	bad = state.checkpoint()
	bad.schema_version = 900
	saves.write_json("checkpoint", bad)
	check(saves.load_checkpoint().is_empty(), "unknown schema cannot partially load")
	bad = state.checkpoint()
	bad.buoys = [[0, "not-a-coordinate", 0]]
	saves.write_json("checkpoint", bad)
	check(saves.load_checkpoint().is_empty(), "malformed buoy coordinates cannot enter world")
	var file = FileAccess.open(saves.path("checkpoint"), FileAccess.WRITE)
	file.store_string("{ interrupted save")
	file.close()
	check(saves.load_checkpoint().is_empty() and not saves.last_error.is_empty(), "truncated JSON yields a recoverable error")
	check(saves.load_settings().fov == 94, "corrupt progression does not erase settings")
	check(saves.save_checkpoint(state.checkpoint()) and not saves.load_checkpoint().is_empty(), "explicit new game can recover after corrupt save")

func test_metal_save_boundaries() -> void:
	section("shared metal bounds / schema 1 / rejected write preserves good save")
	var saves = SaveStore.new()
	saves.directory = test_directory.path_join("metal-boundaries")
	# This is the original schema, without new fields or a migration requirement.
	var snapshot := {"schema_version": 1, "nav": "stored", "stored_metal": 999, "tank_upgraded": false, "buoys": []}
	for amount in [998, 999, 1000, 1001, Expedition.MAX_STORED_METAL - 1, Expedition.MAX_STORED_METAL]:
		snapshot.stored_metal = amount
		check(saves.save_checkpoint(snapshot) and saves.load_checkpoint().get("stored_metal") == amount, "metal %d round trips through production checkpoint writer/reader" % amount)
	var good_bytes := FileAccess.get_file_as_bytes(saves.path("checkpoint"))
	for amount in [-1, 0.5, INF, NAN, Expedition.MAX_STORED_METAL + 1]:
		snapshot.stored_metal = amount
		check(not saves.save_checkpoint(snapshot) and not saves.last_error.is_empty(), "invalid metal %s is rejected before writing" % str(amount))
		check(FileAccess.get_file_as_bytes(saves.path("checkpoint")) == good_bytes, "invalid metal write preserves previous good bytes")
	for amount in [-1, 0.5, Expedition.MAX_STORED_METAL + 1]:
		snapshot.stored_metal = amount
		saves.write_json("checkpoint", snapshot) # Deliberately corrupt a test-only file.
		check(saves.load_checkpoint().is_empty(), "invalid existing metal cannot load: %s" % str(amount))
	var state = Expedition.new()
	state.nav = "carried"
	state.stored_metal = Expedition.MAX_STORED_METAL - 1
	state.carried_metal = 2
	check(not state.deposit() and state.stored_metal == Expedition.MAX_STORED_METAL - 1 and state.carried_metal == 2 and state.nav == "carried", "defensive overflowing deposit preserves every item and objective state")
	state.stored_metal -= 1
	check(state.deposit() and state.stored_metal == Expedition.MAX_STORED_METAL and state.carried_metal == 0 and state.nav == "stored", "deposit at the exact shared limit succeeds")

func test_scene() -> void:
	section("production scene / title / new game")
	var packed = load("res://scenes/main.tscn")
	check(packed is PackedScene, "main scene loads")
	if not packed is PackedScene:
		return
	game = packed.instantiate()
	game.test_mode = true
	game.saves.directory = test_directory.path_join("scene")
	root.add_child(game)
	await frames()
	check(game.player != null and game.world != null and game.ecology != null and game.hud != null, "production scene creates gameplay systems")
	game.start_new_game()
	check(game.mode == "play" and game.player.in_pod, "new expedition begins inside pod")
	check(game.state.nav == "wreck" and game.state.stored_metal == 0, "new expedition starts before navigation recovery")
	check(game.saves.load_checkpoint().get("nav") == "wreck", "new game writes isolated pod checkpoint")
	game.depart_pod()
	check(not game.player.in_pod and game.player.active, "departure enables swimming")
	await test_terrain_routes()
	await test_input_pause()
	await test_observation()
	await test_hogara_observation()
	await test_hypoxia_hud()
	await test_scene_progression()
	await test_checkpoint_failures()
	await test_metal_collection_boundary()
	await test_ecology()

func test_terrain_routes() -> void:
	section("production terrain / both routes / wreck access")
	await physics_frames(2)
	var space = game.world.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.31 # Actual 0.30 m diver radius plus a clearance margin.
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	var direct: Array[Vector3] = []
	for z in range(-15, -131, -1):
		var height: float = game.world.floor_height(0, z) + 2
		if z < -115:
			height = maxf(height, -36)
		direct.append(Vector3(0, height, z))
	var shelter: Array[Vector3] = []
	for z in range(-55, -117, -1):
		shelter.append(Vector3(18, game.world.floor_height(18, z) + 2, z))
	for route in [{"name": "direct", "points": direct}, {"name": "shelter", "points": shelter}]:
		var blocked := ""
		var points: Array = route.points
		for index in points.size():
			query.transform = Transform3D(Basis.IDENTITY, points[index])
			query.motion = Vector3.ZERO
			if not space.intersect_shape(query).is_empty():
				blocked = "body intersection at " + str(points[index])
				break
			if index + 1 < points.size():
				query.motion = points[index + 1] - points[index]
				var fraction: PackedFloat32Array = space.cast_motion(query)
				if fraction[0] < 0.999:
					blocked = "swept collision at " + str(points[index])
					break
		check(blocked.is_empty(), "%s route fits the diver along the complete sampled/swept segment: %s" % [route.name, blocked])
	query.motion = Vector3.ZERO
	query.transform = Transform3D(Basis.IDENTITY, game.NAV_POSITION)
	check(space.intersect_shape(query).is_empty(), "navigation unit approach fits the diver")
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0, -1, -20), Vector3(0, -55, -20), 1)
	var hit: Dictionary = space.intersect_ray(ray)
	check(not hit.is_empty() and absf(hit.position.y - game.world.floor_height(0, -20)) < 0.1, "visible seabed agrees with physical collision surface")

func test_input_pause() -> void:
	section("production input / pause / focus / surface")
	game.player.relocate(Vector3(40, -4, -18), false)
	Input.action_press("forward")
	Input.action_press("sprint")
	await physics_frames(12)
	check(game.player.sprinting and game.player.velocity.length() > 0.5, "held Shift accelerates actual swimming")
	game.pause_game()
	check(paused and not Input.is_action_pressed("sprint") and game.player.velocity == Vector3.ZERO, "opening menu clears held movement")
	var oxygen: float = game.state.oxygen
	var position: Vector3 = game.player.global_position
	var pulse_count: int = game.state.pulse
	game.use_pulse()
	await frames(8)
	check(game.state.oxygen == oxygen and game.player.global_position == position, "paused menu freezes oxygen and swimming")
	check(game.state.pulse == pulse_count, "menu cannot consume pulse")
	Input.action_release("sprint")
	game.resume_game()
	var resumed_pulse: int = game.state.pulse
	game.use_pulse()
	check(game.state.pulse == resumed_pulse, "resume click lock cannot immediately consume a tool")
	await physics_frames(5)
	check(not paused and not game.player.sprinting, "releasing Shift in menu remains released after resume")
	Input.action_press("forward")
	Input.action_press("sprint")
	game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(paused and not Input.is_action_pressed("forward") and not Input.is_action_pressed("sprint"), "focus loss pauses and clears input")
	game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(paused, "focus return requires explicit resume")
	game.resume_game()
	game.state.oxygen = 271
	game.player.relocate(Vector3(40, 0.6, -18), false)
	check(game.player.breathing_air, "head above surface uses external air")
	await physics_frames(6)
	check(game.state.oxygen == 271, "surface neither consumes nor refills tank")
	game.player.global_position.y = 0
	game.player.update_air_state()
	check(game.player.breathing_air, "surface hysteresis avoids flicker at zero")
	game.player.global_position.y = -0.5
	game.player.update_air_state()
	check(not game.player.breathing_air, "submerging sufficiently resumes tank use")
	game.player.toggle_light()
	var light_state: bool = game.player.light_on
	game.player.toggle_light()
	check(game.player.light_on != light_state and game.player.lamp.visible == game.player.light_on, "light remains directly operable")

func test_observation() -> void:
	section("production magnification / observation / independent notebook save")
	var animal = game.ecology.small_creatures[0]
	var at: Vector3 = animal.observation_position()
	game.player.relocate(at + Vector3(0, 0.12, 0.5), false)
	game.player.camera.look_at(at)
	game.select_tool(0)
	await physics_frames(18)
	Input.action_press("use_tool")
	# Advance the actual observation controller against the production camera,
	# target selection and terrain raycast, while keeping the scene fixture still.
	for _index in 52:
		game._update_observation(0.05)
	Input.action_release("use_tool")
	check(game.observations.has("opabinia") and "identified" in game.observations.get("opabinia", []), "holding observer records a visible small creature")
	check(game.player.zoom_fov < game.player.base_fov, "observation actually magnifies the camera")
	check(not game.observations.has("windoweater"), "unseen predator is not automatically identified")
	check(game.saves.load_observations().has("opabinia"), "observation is independently saved")
	check(game.saves.load_checkpoint().get("nav") == "wreck", "notebook saving cannot bank underwater progression")

func test_hogara_observation() -> void:
	section("external Hogara observation / own anatomy / terrain occlusion")
	game.start_new_game()
	game.depart_pod()
	var animal = game.ecology.hogara
	game.player.relocate(animal.model.to_global(Vector3(8, 4.2, 6)), false)
	game.player.camera.look_at(animal.observation_position())
	game.select_tool(0)
	await physics_frames(18)
	game.set_physics_process(false)
	game.player.active = false
	var at: Vector3 = animal.observation_position()
	game.player.camera.look_at(at)
	# This wall is an isolated terrain-layer fixture between a natural external
	# camera and the model. Excluding target anatomy must not exclude this wall.
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * 2.0
	shape.shape = box
	blocker.add_child(shape)
	game.add_child(blocker)
	blocker.global_position = game.player.camera.global_position.lerp(at, 0.5)
	await physics_frames(2)
	Input.action_press("use_tool")
	for _index in 52:
		game._update_observation(0.05)
	check(game.ecology.get_observation_target(game.player.camera) != animal and not game.observations.has("hogara"), "solid terrain between camera and shell prevents identification after a full observation hold")
	blocker.queue_free()
	await physics_frames(2)
	check(game.ecology.get_observation_target(game.player.camera) == animal, "external observation can focus through only the target's own thick shell")
	check(not game.ecology.has_clear_path(game.player.camera.global_position, at), "ordinary ecology sight rays still collide with the same hard shell")
	for _index in 52:
		game._update_observation(0.05)
	Input.action_release("use_tool")
	check("identified" in game.observations.get("hogara", []) and game.saves.load_observations().has("hogara"), "holding the real observer identifies and persists the externally visible Hogara")
	game.set_physics_process(true)
	game.player.active = true

func test_hypoxia_hud() -> void:
	section("visible hypoxia HUD / repeated rendered frames / surface and death")
	game.start_new_game()
	game.depart_pod()
	game.player.relocate(Vector3(40, -4, -18), false)
	game.player.active = false
	game.set_physics_process(false)
	game.state.oxygen = 0
	game.state.anoxia = 1.0
	var first_warning := ""
	var all_frames_visible := true
	for index in 8:
		# Exercise the real physics controller followed by multiple actual HUD
		# render frames: the former bug was a later _process overwriting the label.
		game._physics_process(0.1)
		game.observe_time = 1.2 # A competing, lower-priority observation status.
		await frames(3)
		var text: String = game.hud.observation_label.text
		var expected_countdown := "残り %.1f 秒" % (6.9 - index * 0.1)
		all_frames_visible = all_frames_visible and "酸素切れ" in text and "浮上" in text and expected_countdown in text and not "観察中" in text
		if index == 0:
			first_warning = text
	check(all_frames_visible, "zero oxygen warning survives 24 render frames and takes priority over observation")
	check(first_warning != game.hud.observation_label.text and game.state.anoxia > 1.7, "visible grace countdown changes as production hypoxia advances")
	game.player.relocate(Vector3(40, 0.6, -18), false)
	game._physics_process(0.1)
	game.observe_time = 1.2
	await frames(3)
	check(game.state.anoxia == 0 and not "酸素切れ" in game.hud.observation_label.text and "観察中" in game.hud.observation_label.text, "surface removes hypoxia warning and restores normal observation priority")
	game.player.relocate(Vector3(40, -4, -18), false)
	game.die("HUD 回帰試験")
	await frames(3)
	check(game.hud.observation_label.text.is_empty(), "death clears the active hypoxia warning")
	game.load_game()
	await frames(3)
	check(not "酸素切れ" in game.hud.observation_label.text and game.player.in_pod, "safe pod load does not retain a stale hypoxia warning")
	game.set_physics_process(true)

func test_scene_progression() -> void:
	# Fixture relocation saves CI travel time. Actual pickup distance validation,
	# item state, deposit, checkpoint, repair, death and reload use production methods.
	section("production retrieve / die / retry / deposit / repair / reload")
	game.start_new_game()
	game.depart_pod()
	game.die("回帰試験：回収前")
	game.load_game()
	check(game.state.nav == "wreck" and game.nav_unit.visible, "death before pickup leaves unique item at wreck")
	game.depart_pod()
	game.collect_target(game.nav_unit)
	check(game.state.nav == "wreck", "navigation pickup cannot occur remotely")
	game.state.carried_metal = 12
	game.player.relocate(game.nav_unit.global_position + Vector3(0, 0, 1), false)
	game.collect_target(game.nav_unit)
	check(game.state.nav == "carried", "wreck interaction retrieves navigation unit even with full ordinary inventory")
	game.die("回帰試験：未保管の航法ユニット")
	check(game.mode == "dead", "death transitions to retry screen")
	game.load_game()
	check(game.state.nav == "wreck" and game.nav_unit.visible and game.player.in_pod, "death before banking restores unit at wreck")
	check(game.state.carried_metal == 0 and game.state.stored_metal == 0, "death loses unbanked ordinary materials")
	game.depart_pod()
	var metal_collected := 0
	for target in game.pickups:
		if metal_collected >= 2:
			break
		if target == game.nav_unit or not target.visible:
			continue
		game.player.relocate(target.global_position + Vector3(0, 0, 1), false)
		var before: int = game.state.carried_metal
		game.collect_target(target)
		if game.state.carried_metal > before:
			metal_collected += 1
	check(game.state.carried_metal == 2, "two real shallow pickups supply repair metal")
	game.player.relocate(game.nav_unit.global_position + Vector3(0, 0, 1), false)
	game.collect_target(game.nav_unit)
	check(game.state.nav == "carried", "navigation unit can be recovered after death")
	game.return_to_pod()
	check(not game.player.in_pod, "return cannot bank cargo remotely")
	# Entry interaction uses the pod's physical approach position.
	game.player.relocate(game.ENTRY, false)
	game.return_to_pod()
	check(game.player.in_pod and game.state.nav == "stored" and game.state.stored_metal == 2, "pod entry banks all cargo")
	var saved: Dictionary = game.saves.load_checkpoint()
	check(saved.get("nav") == "stored" and saved.get("stored_metal") == 2, "checkpoint records deposited inventory atomically")
	check(game.state.oxygen == game.state.capacity() and game.state.suit == 100, "entry refills and repairs without materials")
	game.depart_pod()
	game.die("回帰試験：保管後")
	game.load_game()
	check(game.state.nav == "stored" and game.state.stored_metal == 2 and not game.nav_unit.visible, "banked unit survives death without duplication")
	game.repair_navigation()
	check(game.state.nav == "repaired" and game.state.stored_metal == 0, "pod repair reaches M1 completion")
	check("制振フレーム" in game.state.objective(), "navigation completion advances to the M2 part objective")
	game.load_game()
	check(game.state.nav == "repaired" and game.player.in_pod, "completed chapter reloads in pod")
	game.repair_navigation()
	check(game.state.stored_metal == 0 and game.state.nav == "repaired", "completion cannot be executed twice")
	game.resume_game()
	game.depart_pod()
	check(game.mode == "play" and not game.player.in_pod, "exploration remains available after M1 completion")

func collect_real_metal(amount: int) -> void:
	var collected := 0
	for target in game.pickups:
		if collected >= amount:
			break
		if target.kind != "metal" or not target.visible:
			continue
		game.player.relocate(target.global_position + Vector3(0, 0, 1), false)
		game.player.camera.look_at(target.global_position)
		if game.collect_target(target):
			collected += 1
	check(collected == amount, "actual nearby metal interactions collect the fixture cargo")

func block_checkpoint_write() -> String:
	# A directory at the temporary file path makes FileAccess.WRITE fail even
	# under root. Only this run's isolated user:// directory is touched.
	var temp_path: String = game.saves.path("checkpoint") + ".tmp"
	check(DirAccess.make_dir_recursive_absolute(temp_path) == OK, "deterministic isolated save-failure fixture is installed")
	return temp_path

func press_save_retry_button() -> bool:
	for child in game.hud.menu_box.get_children():
		if child is Button and child.text == "保存を再試行":
			child.pressed.emit()
			return true
	return false

func test_checkpoint_failures() -> void:
	section("return / repair save failure / actual UI retry / no lost or duplicated cargo")
	game.start_new_game()
	game.depart_pod()
	collect_real_metal(2)
	game.player.relocate(game.nav_unit.global_position + Vector3(0, 0, 1), false)
	game.player.camera.look_at(game.nav_unit.global_position)
	check(game.collect_target(game.nav_unit), "failure scenario starts with the real unique navigation unit")
	var prior_checkpoint: Dictionary = game.checkpoint.duplicate(true)
	var prior_bytes := FileAccess.get_file_as_bytes(game.saves.path("checkpoint"))
	var blocker := block_checkpoint_write()
	game.state.oxygen = 13
	game.state.suit = 28
	game.player.relocate(game.ENTRY, false)
	game.interact() # E interaction must not fall through after a failed return.
	await frames(3)
	check(game.player.in_pod and paused and game.hud.page == "save_failed", "failed return moves to the safe pod and presents an actionable save error")
	check(game.state.oxygen == game.state.capacity() and game.state.suit == 100, "failed saving cannot strand an injured diver without air")
	check(game.state.nav == "carried" and game.state.carried_metal == 2 and game.state.stored_metal == 0, "failed return retains uncommitted cargo without banking or consuming it")
	check(game.checkpoint == prior_checkpoint and FileAccess.get_file_as_bytes(game.saves.path("checkpoint")) == prior_bytes, "failed return preserves both the prior live checkpoint and exact on-disk bytes")
	check(not game.nav_unit.visible and not "帰投完了" in game.toast_text and not game.checkpoint_error.is_empty(), "failed return neither duplicates the unit nor overwrites its error with success")
	check(not game.retry_checkpoint() and game.state.carried_metal == 2 and game.state.nav == "carried", "repeated blocked return retry leaves cargo intact")
	game.resume_game()
	check(paused and game.hud.page == "save_failed" and not game.depart_pod(), "Escape or departure cannot bypass an unresolved cargo save")
	check(DirAccess.remove_absolute(blocker) == OK and press_save_retry_button(), "the visible retry button resumes saving after storage recovers")
	check(not paused and game.pending_checkpoint_action.is_empty() and game.state.nav == "stored" and game.state.stored_metal == 2 and game.state.carried_metal == 0, "return retry commits each item exactly once")
	check(game.saves.load_checkpoint().get("nav") == "stored" and not game.nav_unit.visible, "retried deposit is durable with one navigation unit")
	prior_checkpoint = game.checkpoint.duplicate(true)
	prior_bytes = FileAccess.get_file_as_bytes(game.saves.path("checkpoint"))
	blocker = block_checkpoint_write()
	check(not game.repair_navigation() and game.hud.page == "save_failed", "repair save failure does not display completion")
	check(game.state.nav == "stored" and game.state.stored_metal == 2 and game.checkpoint == prior_checkpoint, "failed repair retains its unit and both required metal")
	check(not game.retry_checkpoint() and game.state.stored_metal == 2 and FileAccess.get_file_as_bytes(game.saves.path("checkpoint")) == prior_bytes, "repeated repair failure never consumes metal or replaces the good file")
	check(DirAccess.remove_absolute(blocker) == OK and press_save_retry_button(), "repair has the same usable UI retry path")
	check(game.state.nav == "repaired" and game.state.stored_metal == 0 and game.hud.page == "complete", "successful retry alone consumes two metal and shows completion")
	check(not game.retry_checkpoint() and not game.repair_navigation() and game.state.stored_metal == 0, "repeated retry or repair cannot consume a second time")
	check(game.load_game() and game.state.nav == "repaired" and game.state.stored_metal == 0, "retried repair survives reload without duplicating its unit")
	await frames(3)

func test_metal_collection_boundary() -> void:
	section("real collection / return / reload at 1000 and storage maximum")
	for initial in [999, Expedition.MAX_STORED_METAL - 1]:
		game.start_new_game()
		game.state.stored_metal = initial
		check(game.depart_pod(), "boundary fixture starts at a saved pod checkpoint")
		collect_real_metal(1)
		if initial == Expedition.MAX_STORED_METAL - 1:
			for target in game.pickups:
				if target.kind == "metal" and target.visible:
					game.player.relocate(target.global_position + Vector3(0, 0, 1), false)
					game.player.camera.look_at(target.global_position)
					check(not game.collect_target(target) and target.visible and game.state.carried_metal == 1, "at the total cap an extra pickup stays in the world and cargo is retained")
					break
		game.player.relocate(game.ENTRY, false)
		check(game.return_to_pod() and game.state.stored_metal == initial + 1, "real return accepts boundary total %d" % (initial + 1))
		check(game.load_game() and game.state.stored_metal == initial + 1, "real checkpoint reload accepts that same boundary total")
	game.start_new_game()
	game.depart_pod()
	await frames(3)

func test_ecology() -> void:
	section("production ecology")
	var species := {}
	for item in game.ecology.creatures:
		species[item.species_id] = true
	check(species.size() == 14, "all seven M1 species and seven M2 species have active scene instances")
	for id in ["opabinia", "hallucigenia", "olenoides", "glowgrain", "mudunraveler", "hogara", "windoweater"]:
		check(species.has(id), "M1 species is present: " + id)
	# Manual fixed simulation steps exercise the production ecosystem at useful
	# timescales, without waiting 45 wall-clock seconds for each lure to expire.
	game.set_physics_process(false)
	game.player.active = false
	await test_silt()
	await test_bait_chain()
	await test_predator_retreat()
	await test_hogara_passage()
	game.set_physics_process(true)

func step_ecology(seconds: float) -> void:
	for _index in range(int(ceil(seconds / 0.05))):
		game.ecology.tick(0.05)

func test_silt() -> void:
	section("mud stimulus -> real silt -> exposed predator -> expiry")
	game.ecology.reset()
	await physics_frames(2)
	var mud
	for item in game.ecology.small_creatures:
		if item.species_id == "mudunraveler":
			mud = item
			break
	var predator = game.ecology.predators[0]
	game.player.relocate(mud.global_position + Vector3(0, 1, 0), false)
	game.player.sprinting = true
	step_ecology(0.5)
	check(mud.burrow_pending and game.ecology.silt_clouds.is_empty(), "mud gives a shiver warning before the cloud")
	step_ecology(0.6)
	check(game.ecology.silt_clouds.size() == 1 and mud.rest_remaining > 14, "nearby sprint produces one cloud with cooldown")
	game.player.sprinting = false
	game.player.relocate(Vector3(40, -5, -18), false)
	step_ecology(3.0)
	check(predator.exposed_remaining > 0, "sand overlaps and exposes real predator")
	check(predator.coating[0].visible and predator.membrane_material.albedo_color.a > 0.4, "exposure changes particles and membrane opacity")
	step_ecology(16)
	check(game.ecology.silt_clouds.is_empty() and predator.exposed_remaining == 0, "cloud and attached sand expire naturally")
	check(not predator.coating[0].visible, "normal transparent appearance returns")

func test_bait_chain() -> void:
	section("bait -> moving school -> predator leaves ambush -> feeding")
	game.ecology.reset()
	await physics_frames(2)
	var school = game.ecology.schools[1]
	var predator = game.ecology.predators[0]
	var school_origin: Vector3 = school.global_position
	var predator_origin: Vector3 = predator.global_position
	var bait_at: Vector3 = school_origin + Vector3(6, 0, 0)
	game.player.relocate(bait_at + Vector3(0, 0, 4), false)
	check(game.ecology.use_bait(bait_at), "lure placed through an unobstructed water path")
	game.player.relocate(Vector3(40, -5, -18), false)
	var moved_school := 0.0
	var moved_predator := 0.0
	var saw_feed := false
	for _index in 600:
		game.ecology.tick(0.05)
		moved_school = maxf(moved_school, school.global_position.distance_to(school_origin))
		moved_predator = maxf(moved_predator, predator.global_position.distance_to(predator_origin))
		saw_feed = saw_feed or predator.state == "feed"
	check(moved_school > 3.0, "school gradually moves several metres toward bait")
	check(saw_feed and moved_predator > 3.0 and predator.bait_feeds > 0, "predator physically leaves ambush and consumes bait-following school")
	check(school.density > 0.0, "feeding does not permanently exterminate the school")
	step_ecology(17)
	check(game.ecology.baits.is_empty() and not school.following_bait, "45 second bait expires and school resumes ecology")

func test_predator_retreat() -> void:
	section("predator warning / finite dash / search / retreat / pulse")
	game.ecology.reset()
	var predator = game.ecology.predators[0]
	# Place one real creature in open water to isolate its bounded pursuit from
	# natural feeding and level geometry; no state transitions are mocked.
	var origin := Vector3(40, -12, -65)
	predator.global_position = origin
	predator.home = origin
	predator.homes.assign([origin, origin + Vector3(0, 0, -6)])
	game.player.relocate(origin + Vector3(0, 0, 5), false)
	await physics_frames(2)
	var seen := {}
	var maximum_pursuit := 0.0
	var maximum_dash := 0.0
	var warning_seconds := 0.0
	for _index in 800:
		game.ecology.tick(0.05)
		seen[predator.state] = true
		maximum_pursuit = maxf(maximum_pursuit, predator.pursuit_time)
		maximum_dash = maxf(maximum_dash, predator.dash_distance)
		if predator.state == "windup":
			warning_seconds += 0.05
		if predator.state == "dash":
			game.player.global_position = origin + Vector3(10, 0, 5)
	check(seen.has("windup") and warning_seconds >= 0.9, "player attack has approximately one second of windup")
	check(seen.has("dash") and seen.has("recover") and maximum_dash <= 7.1, "dash is finite and followed by recovery")
	check(seen.has("search") and seen.has("return") and predator.state == "ambush", "lost target search ends in retreat to ambush")
	check(maximum_pursuit < 24, "return finishes instead of resetting pursuit indefinitely")
	game.player.relocate(predator.global_position + Vector3(0, 0, 3), false)
	check(game.ecology.pulse(game.player.global_position) == 1 and predator.state == "stunned", "four metre pulse stuns the actual predator")
	game.player.relocate(Vector3(40, -5, -18), false)
	step_ecology(2.1)
	check(predator.state != "stunned", "pulse has a bounded duration")

func test_hogara_passage() -> void:
	section("hogara physical passage / predator size / rest exit")
	game.ecology.reset()
	var hogara = game.ecology.hogara
	var predator = game.ecology.predators[0]
	# Gap endpoints belong to the actual tilted model, not world axes or the
	# routing root. Test the same physical opening with both real body sizes.
	# The central +Z gap is clear of the front leg at this initial gait phase;
	# the dedicated gait suite covers all candidates and blocked-exit replanning.
	var gap: Dictionary = hogara.model.get_exit_gaps()[2]
	var outside: Vector3 = hogara.model.to_global(gap.outside)
	var inside: Vector3 = hogara.model.to_global(gap.inside)
	game.player.relocate(outside, false)
	await physics_frames(2)
	for _index in 30:
		game.player.move_and_collide((inside - game.player.global_position).limit_length(0.1))
	check(game.ecology.is_sheltered(game.player.global_position), "0.6 metre diver physically enters a 1.1 metre gap")
	check(game.player.get_parent() == game, "shelter never reparents the camera or diver")
	for _index in 30:
		game.player.move_and_collide((outside - game.player.global_position).limit_length(0.1))
	check(not game.ecology.is_sheltered(game.player.global_position), "diver can swim back out through the gap")
	predator.global_position = outside
	await physics_frames(2)
	for _index in 30:
		predator.move_and_collide((inside - predator.global_position).limit_length(0.1))
	check(not game.ecology.is_sheltered(predator.global_position), "1.4 metre predator mouth cannot pass the same physical gap")
	game.player.relocate(hogara.model.to_global(Vector3(0, 1.7, 0)), false)
	var oxygen: float = game.state.oxygen
	hogara.state = "rest_warning"
	hogara.state_time = 0
	for _index in 260:
		hogara.tick(0.05, game.player, Vector3(100, -10, 100))
		if hogara.state == "rest":
			break
	check(not hogara._under_roof(game.player.global_position) and hogara.state == "rest", "warning gently exits the diver completely before the shell rests")
	check(game.state.oxygen == oxygen, "shelter supplies no oxygen refill")
