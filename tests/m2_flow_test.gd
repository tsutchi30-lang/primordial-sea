extends SceneTree
## Transaction/state integration checks use the actual main scene. Explicit
## positional fixtures isolate interactions; live swimming is m2_routes_test.gd.
const Controls = preload("res://scripts/player/controls.gd")
const WorldMap = preload("res://data/biomes/world_map.gd")
const PARTS := ["damping_frame", "phase_regulator"]
var game
var checks := 0
var failures: Array[String] = []
var current_case := "startup"
var started := 0
var save_directory := ""

func _initialize() -> void:
	started = Time.get_ticks_msec()
	save_directory = "user://automated-tests/m2-flow-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	call_deferred("run")

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started > 150000:
		printerr("M2_FLOW_FAIL timeout case=", current_case)
		quit(1)
	return false

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(current_case + ": " + message)
		printerr("M2_FLOW_FAILURE ", current_case, ": ", message)

func section(name: String) -> void:
	current_case = name
	print("M2_FLOW_CASE ", name)

func frames(count := 2) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func freeze_player() -> void:
	game.player.active = false
	Controls.release_all()

func target(id: String):
	for node in game.pickups:
		if node.kind == id: return node
	return null

func collect(id: String) -> void:
	var node = target(id)
	check(is_instance_valid(node), "real pickup exists: " + id)
	if not is_instance_valid(node): return
	game.resume_game()
	game.player.relocate(node.global_position + Vector3(0, 0.9, 1.2), false)
	freeze_player()
	game.player.camera.look_at(node.global_position)
	await frames()
	check(game.collect_target(node), "nearby aimed unobstructed production collection: " + id)
	check(not game.collect_target(node), "same unique item cannot be collected twice: " + id)
	check(not node.available, "collected pickup disappears: " + id)

func return_fixture() -> void:
	game.resume_game()
	game.player.relocate(WorldMap.point("pod", game.world), false)
	freeze_player()
	await frames()
	check(game.return_to_pod(), "return banks the complete cargo")
	freeze_player()

func start_m2_fixture() -> void:
	game.start_new_game()
	freeze_player()
	# Deliberately declared M1-complete checkpoint, confined to this test save.
	game.state.nav = "repaired"
	check(game._save_checkpoint(), "isolated M1-complete fixture saves")
	check(game.depart_pod(), "M2 fixture departs normally")
	freeze_player()

func block_write() -> String:
	var path: String = game.saves.path("checkpoint") + ".tmp"
	check(DirAccess.make_dir_recursive_absolute(path) == OK, "directory blocks checkpoint temporary-file write")
	return path

func unblock_write(path: String) -> void:
	check(DirAccess.remove_absolute(path) == OK, "deterministic save fault removed")

func checkpoint_bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(game.saves.path("checkpoint"))

func retry_ui() -> bool:
	for child in game.hud.menu_box.get_children():
		if child is Button and child.text == "保存を再試行":
			child.pressed.emit()
			freeze_player()
			return true
	return false

func run() -> void:
	seed(4702)
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	game.saves.directory = save_directory
	root.add_child(game)
	game.set_physics_process(false)
	await frames()
	await new_game_through_stabilization()
	await reverse_order()
	await relay_and_death()
	await save_failures()
	await equipment_transactions()
	paused = false
	freeze_player()
	game.sound.stop_all()
	await frames(10)
	game.queue_free()
	await frames(4)
	if failures.is_empty():
		print("M2_FLOW_OK checks=%d fixture=interaction-relocation-not-route-proof saves=%s" % [checks, save_directory])
		quit(0)
	else:
		printerr("M2_FLOW_FAIL checks=%d failures=%d" % [checks, failures.size()])
		quit(1)

func new_game_through_stabilization() -> void:
	section("T03 new game keeps M1, then M2 through actual collection/deposit/repair")
	game.start_new_game()
	freeze_player()
	check(game.state.nav == "wreck" and not game.state.stabilized, "ordinary new game starts M1")
	check(game.state.parts.damping_frame == "world" and game.state.parts.phase_regulator == "world", "both M2 items start in world")
	check(game.depart_pod(), "normal M1 departure")
	freeze_player()
	var count := 0
	for node in game.pickups:
		if node.kind != "metal" or count >= 2: continue
		game.player.relocate(node.global_position + Vector3(0, 0.5, 1), false)
		freeze_player()
		game.player.camera.look_at(node.global_position)
		await frames()
		if game.collect_target(node): count += 1
	check(count == 2, "repair metal collected from production pickups")
	await collect("nav")
	await return_fixture()
	check(game.repair_navigation(), "M1 repair succeeds and saves")
	check(game.state.nav == "repaired" and not game.state.stabilized, "M1 completion unlocks distinct M2 objective")
	game.resume_game()
	check(game.depart_pod(), "continue beyond M1 completion")
	freeze_player()
	await collect("damping_frame")
	await collect("phase_regulator")
	check(not game.stabilize_device(), "underwater carried items cannot stabilize")
	await return_fixture()
	check(game.state.parts.damping_frame == "stored" and game.state.parts.phase_regulator == "stored", "both items banked")
	check(game.stabilize_device(), "stabilization commits through actual pod transaction")
	check(game.state.stabilized and game.state.parts.damping_frame == "installed" and game.state.parts.phase_regulator == "installed", "both installed atomically")
	check(not game.stabilize_device(), "stabilization is not repeatable")
	check(game.load_game(), "completed checkpoint reloads")
	freeze_player()
	check(game.state.stabilized and not target("damping_frame").visible and not target("phase_regulator").visible, "installed items never reappear on load")
	check(game.depart_pod(), "exploration continues after stabilization")
	freeze_player()

func reverse_order() -> void:
	section("T06 reverse order and separate returns")
	start_m2_fixture()
	await collect("phase_regulator")
	await return_fixture()
	check(not game.stabilize_device(), "one stored item is insufficient")
	game.resume_game()
	check(game.depart_pod(), "second expedition")
	freeze_player()
	await collect("damping_frame")
	await return_fixture()
	check(game.stabilize_device() and game.state.stabilized, "B then A reaches the same completion")

func relay_and_death() -> void:
	section("T04 stored A survives while carried B resets after death")
	start_m2_fixture()
	await collect("damping_frame")
	await return_fixture()
	game.resume_game()
	check(game.depart_pod(), "depart with A safely stored")
	freeze_player()
	await collect("phase_regulator")
	game.die("isolated death fixture")
	check(game.load_game(), "death retry loads last pod checkpoint")
	freeze_player()
	check(game.state.parts.damping_frame == "stored" and game.state.parts.phase_regulator == "world", "A retained, unbanked B returns")
	check(not target("damping_frame").visible and target("phase_regulator").available, "world visuals match persisted locations")
	section("T05 relay supplies without banking or checkpointing")
	for ending in ["death", "title"]:
		start_m2_fixture()
		await collect("damping_frame")
		game.state.carried_fiber = 2
		game.state.carried_shell = 1
		game.state.bait = 0
		game.state.pulse = 0
		game.state.oxygen = 71
		game.state.suit = 34
		game.state.anoxia = 2
		game.state.warned_35 = true
		game.state.warned_15 = true
		var before := checkpoint_bytes()
		game.player.relocate(game.m2.relay_anchor() + Vector3(0, 0, 1), false)
		freeze_player()
		var at: Vector3 = game.player.global_position
		await frames()
		check(game.open_relay(), "nearby relay opens")
		check(game.refill_at_relay(), "relay refill succeeds")
		check(game.player.global_position.is_equal_approx(at) and not game.player.in_pod, "relay neither teleports nor impersonates pod")
		check(game.state.oxygen == 480 and game.state.suit == 100 and game.state.anoxia == 0 and not game.state.warned_35 and not game.state.warned_15, "relay resets breathing and warning state")
		check(game.state.bait == 0 and game.state.pulse == 0 and game.state.carried_fiber == 2 and game.state.carried_shell == 1 and game.state.parts.damping_frame == "carried", "consumables and cargo untouched")
		check(checkpoint_bytes() == before, "relay writes no checkpoint")
		if ending == "death": game.die("isolated death after relay")
		else: game.show_title()
		check(game.load_game(), "restart after relay " + ending)
		freeze_player()
		check(game.state.parts.damping_frame == "world" and game.state.stored_fiber == 0 and game.state.carried_fiber == 0, "relay cargo is not transported to pod on " + ending)

func save_failures() -> void:
	section("T07 cargo deposit and stabilization failed writes retry exactly once")
	start_m2_fixture()
	await collect("damping_frame")
	await collect("phase_regulator")
	game.state.carried_fiber = 2
	var previous := checkpoint_bytes()
	var blocked := block_write()
	game.player.relocate(WorldMap.point("pod", game.world), false)
	freeze_player()
	check(not game.return_to_pod(), "failed return does not claim successful storage")
	check(game.player.in_pod and game.state.parts.damping_frame == "carried" and game.state.parts.phase_regulator == "carried" and game.state.carried_fiber == 2, "all live cargo remains safely retryable")
	check(checkpoint_bytes() == previous and game.hud.page == "save_failed", "old checkpoint and visible failure retained")
	check(not game.retry_checkpoint() and checkpoint_bytes() == previous, "repeated blocked retry remains atomic")
	unblock_write(blocked)
	check(retry_ui(), "actual retry button dispatches pending return")
	check(game.state.parts.damping_frame == "stored" and game.state.parts.phase_regulator == "stored" and game.state.stored_fiber == 2, "retry banks all cargo once")
	previous = checkpoint_bytes()
	blocked = block_write()
	check(not game.stabilize_device(), "stabilization write failure is surfaced")
	check(not game.state.stabilized and game.state.parts.damping_frame == "stored" and checkpoint_bytes() == previous, "failed stabilization retains stored items and old save")
	check(not game.retry_checkpoint() and not game.state.stabilized, "repeated failure cannot show completion")
	unblock_write(blocked)
	check(retry_ui(), "retry button dispatches pending stabilization")
	check(game.state.stabilized and game.state.parts.phase_regulator == "installed", "stabilization succeeds once after fault removal")
	check(game.load_game() and game.state.stabilized, "successful retry survives process-style reload")
	freeze_player()

func equipment_transactions() -> void:
	section("T07 pod equipment uses saved resources and atomic retry")
	start_m2_fixture()
	await return_fixture()
	# Declared recipe fixture avoids unrelated repeated material gathering.
	game.state.stored_metal = 12
	game.state.stored_fiber = 4
	game.state.stored_shell = 4
	check(game._save_checkpoint(), "isolated recipe-stock fixture saves")
	check(game.upgrade_equipment("tank_i"), "existing tank I remains available")
	check(game.state.capacity() == 600, "tank I capacity retained")
	for id in ["tank_ii", "cutter"]:
		var previous := checkpoint_bytes()
		var metal: int = game.state.stored_metal
		var fiber: int = game.state.stored_fiber
		var shell: int = game.state.stored_shell
		var blocked := block_write()
		check(not game.upgrade_equipment(id), "failed upgrade does not commit: " + id)
		check(game.state.stored_metal == metal and game.state.stored_fiber == fiber and game.state.stored_shell == shell and checkpoint_bytes() == previous, "all costs retained after failed " + id)
		unblock_write(blocked)
		check(retry_ui(), "upgrade retry button: " + id)
		check(not game.upgrade_equipment(id), "duplicate purchase rejected: " + id)
	check(game.state.capacity() == 780 and is_equal_approx(game.state.cutter_seconds(), 0.6), "both M2 effects applied")
	check(game.state.stored_metal == 5 and game.state.stored_fiber == 2 and game.state.stored_shell == 2, "recipes consume exact costs once")
	check(game.load_game() and game.state.capacity() == 780 and game.state.cutter_upgraded, "equipment survives reload")
	freeze_player()
