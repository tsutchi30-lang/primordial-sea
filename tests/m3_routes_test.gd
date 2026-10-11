extends SceneTree
## Conservative base equipment / zero consumables. One initial player placement
## per case, then production Input, inertia, collision, core and relay actions.
const Pilot = preload("res://tools/capture_m2_common.gd")
const Map = preload("res://data/biomes/world_map.gd")
const Controls = preload("res://scripts/player/controls.gd")
var game
var elapsed := 0.0
var active := false
var current_case := ""
var current_waypoint := -1
var start_seconds := 0.0
var start_oxygen := 480.0
var minimum := 480.0
var failures: Array[String] = []
var segments: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var checks := 0
var next_sample := 0.0
var output := "res://build/m3/routes"
func _initialize() -> void: call_deferred("run")
func _physics_process(delta: float) -> bool:
	if active and not paused:
		elapsed += delta
		minimum = minf(minimum,game.state.oxygen)
		if elapsed >= next_sample:
			samples.append({"t":elapsed,"case":current_case,"waypoint":current_waypoint,"position":Pilot.arr(game.player.position),"oxygen":game.state.oxygen,"suit":game.state.suit,"kangaku":game.ecology.rift.kangaku.state,"core":game.state.return_core})
			next_sample = elapsed+1
	return false
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures.append(current_case+": "+message)
		printerr("M3_ROUTE_FAIL ",current_case,": ",message)
func step() -> void:
	await physics_frame
	await process_frame
func swim(points: Array[Vector3],label: String) -> bool:
	print("M3_ROUTE_SWIM ",current_case," ",label," ",points.size())
	for i in points.size():
		current_waypoint = i
		var target := points[i]
		var last_progress := elapsed
		var best: float = game.player.position.distance_to(target)
		var tolerance := 0.18 if target.z > -279 and target.z < -268 else 0.55
		while game.player.position.distance_to(target) > tolerance:
			var distance: float = game.player.position.distance_to(target)
			if distance < best-0.12:
				best = distance
				last_progress = elapsed
			if elapsed-last_progress > 12 or game.state.dead or paused or game.mode != "play":
				check(false,"%s blocked point=%d target=%s actual=%s" % [label,i,target,game.player.position])
				Controls.release_all()
				return false
			Pilot.look(game.player,target,0.16)
			# Correct for the authored current using ordinary input, never position.
			Pilot.drive(game.player,target-Map.cross_current(game.player.position)/1.7)
			await step()
	Controls.release_all()
	return true
func start_case(name: String) -> void:
	active = false
	current_case = name
	game.start_new_game()
	game.state.nav = "repaired"
	game.state.parts = {"damping_frame":"stored","phase_regulator":"stored"}
	game.state.stabilize()
	game._save_checkpoint()
	game.depart_pod()
	game.player.relocate(game.m2.relay_anchor()+Vector3(0,0,1.2),false)
	game.state.bait = 0
	game.state.pulse = 0
	game.player.active = true
	game.use_lock = 0
	start_seconds = elapsed
	start_oxygen = game.state.oxygen
	minimum = start_oxygen
	active = true
	print("M3_ROUTE_START ",name)
func relay_shelf() -> Array[Vector3]:
	return Map.route("relay_rift",game.world)
func supply(label: String) -> void:
	var approach: Array[Vector3] = [game.m2.relay_position(),game.m2.relay_anchor()+Vector3(0,0,1.2)]
	if not await swim(approach,"visible relay screen"): return
	Pilot.look(game.player,game.m2.relay_anchor())
	var segment := {"id":label,"capacity":game.state.capacity(),"starting_oxygen":start_oxygen,"seconds":elapsed-start_seconds,"oxygen_before_supply":game.state.oxygen,"minimum":minimum,"remaining_fraction":game.state.oxygen/game.state.capacity(),"core":game.state.return_core,"bait":game.state.bait,"pulse":game.state.pulse}
	segments.append(segment)
	print("M3_ROUTE_SEGMENT ",JSON.stringify(segment))
	check(minimum >= 120 and elapsed-start_seconds < 360,"base tank returns in six minutes with >=25% before refill")
	check(game.open_relay() and game.refill_at_relay(),"actual screen reached and refill succeeds")
	game.use_lock = 0
	start_seconds = elapsed
	start_oxygen = game.state.oxygen
	minimum = start_oxygen
func extract_core() -> bool:
	Pilot.look(game.player,game.m3.core.position)
	Controls.release_all()
	game.select_tool(1)
	Input.action_press("use_tool")
	var end := elapsed+1.6
	while elapsed < end and game.mode == "play": await step()
	Input.action_release("use_tool")
	check(game.m3.mount.unlocked,"production held click cuts clamp after real swim")
	Pilot.tap("interact")
	await step()
	check(game.state.return_core == "carried","production E collects core after cut")
	return game.state.return_core == "carried"
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	game.saves.directory = "user://automated-tests/m3-routes-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	root.add_child(game)
	await step()
	for name in ["shelf-turnback","main-core-other-exit","outer-detour-core"]:
		start_case(name)
		var approach := relay_shelf()
		var returning := approach.duplicate()
		returning.reverse()
		if not await swim(approach,"relay to shelf"): continue
		if name == "shelf-turnback":
			if not await swim(returning,"shelf turnback"): continue
		else:
			if not await swim(Map.route("shelf_ship" if name == "main-core-other-exit" else "rift_detour",game.world),"core approach"): continue
			if not await extract_core(): continue
			if not await swim(Map.route("core_exit",game.world),"other exit to cover to shelf"): continue
			if not await swim(returning,"shelf to relay"): continue
		await supply(name)
		if name == "main-core-other-exit":
			var homeward := Map.route("pod_relay",game.world)
			homeward.reverse()
			if await swim(homeward,"carried core to pod"):
				var entry: Array[Vector3] = [game.ENTRY]
				await swim(entry,"pod hatch")
				segments.append({"id":"carried-core-relay-pod","starting_oxygen":start_oxygen,"seconds":elapsed-start_seconds,"oxygen_before_supply":game.state.oxygen,"minimum":minimum,"core":game.state.return_core})
				check(game.state.return_core == "carried" and game.return_to_pod() and game.state.return_core == "stored","entire live return banks core at pod")
	active = false
	Controls.release_all()
	game.set_physics_process(false)
	game.player.active = false
	var file := FileAccess.open(output.path_join("routes-manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind":"production Input and collision, initial M2-complete relay fixture only","segments":segments,"samples":samples,"failures":failures,"checks":checks,"success":failures.is_empty()},"\t"))
	file.close()
	game.sound.stop_all()
	OS.delay_msec(150) # Let the real audio mixer release playback before teardown.
	paused = false
	game.queue_free()
	for i in 12: await step()
	print("M3_ROUTES_%s checks=%d" % ["OK" if failures.is_empty() else "FAILED",checks])
	quit(0 if failures.is_empty() else 1)
