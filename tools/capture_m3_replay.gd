extends SceneTree
## Initial fixtures are recorded once. Every later move is Pilot -> Input ->
## production Diver, and every enemy update is ordinary ecosystem.tick.
const Pilot = preload("res://tools/capture_m2_common.gd")
const Controls = preload("res://scripts/player/controls.gd")
const Map = preload("res://data/biomes/world_map.gd")
var game
var mode := "relay"
var output := "res://build/m3/motion/relay"
var elapsed := 0.0
var active := false
var finished := false
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var events: Array[Dictionary] = []
var next_sample := 0.0
var source_commit := "unknown"
var starting_position := Vector3.ZERO
var last_enemy_state := ""
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()-1):
		if args[i] == "--mode": mode = args[i+1]
		if args[i] == "--output": output = args[i+1]
		if args[i] == "--source-commit": source_commit = args[i+1]
	call_deferred("run")
func _physics_process(delta: float) -> bool:
	if not active or finished: return false
	elapsed += delta
	if elapsed >= next_sample:
		var k = game.ecology.rift.kangaku
		samples.append({"t":elapsed,"position":Pilot.arr(game.player.position),"oxygen":game.state.oxygen,"suit":game.state.suit,"core":game.state.return_core,"mode":game.mode,"kangaku":k.state,"mouth":Pilot.arr(k.mouth_position()),"dash_direction":Pilot.arr(k.dash_direction),"input":[Input.get_action_strength("forward"),Input.get_action_strength("back"),Input.get_action_strength("left"),Input.get_action_strength("right"),Input.get_action_strength("ascend"),Input.get_action_strength("descend")]})
		next_sample = elapsed+0.25
	if game.ecology.rift.kangaku.state != last_enemy_state:
		last_enemy_state = game.ecology.rift.kangaku.state
		events.append({"t":elapsed,"enemy_state":last_enemy_state})
	if elapsed > 110:
		failures.append("bounded replay timeout")
		finish()
	return false
func check(ok: bool,message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("M3_REPLAY_FAIL ",mode," ",message)
func step() -> void:
	await physics_frame
	await process_frame
func dwell(seconds: float) -> void:
	var until := elapsed+seconds
	while elapsed < until and not finished: await step()
func swim(points: Array[Vector3],label: String,look_at_enemy := false) -> bool:
	for target in points:
		var best: float = game.player.position.distance_to(target)
		var last_progress := elapsed
		var tolerance := 0.16 if mode == "relay" else 0.55
		while game.player.position.distance_to(target) > tolerance and not finished:
			var distance: float = game.player.position.distance_to(target)
			if distance < best-0.1:
				best = distance
				last_progress = elapsed
			if elapsed-last_progress > 10 or game.mode != "play" or paused:
				check(false,"%s blocked target=%s actual=%s" % [label,target,game.player.position])
				Controls.release_all()
				return false
			Pilot.look(game.player,game.ecology.rift.kangaku.mouth_position() if look_at_enemy else target,0.16)
			Pilot.drive(game.player,target-Map.cross_current(game.player.position)/1.7)
			await step()
	Controls.release_all()
	events.append({"t":elapsed,"reached":label,"position":Pilot.arr(game.player.position)})
	return true
func press_button(action: String) -> void:
	for node in game.hud.menu_box.get_children()+game.hud.footer.get_children():
		if node is Button and node.get_meta("action","") == action:
			node.grab_focus()
			Pilot.tap("ui_accept")
			return
	check(false,"missing UI action "+action)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	game.saves.directory = "user://automated-tests/m3-replay-%s-%d-%d" % [mode,OS.get_process_id(),Time.get_ticks_usec()]
	root.add_child(game)
	game.set_physics_process(false)
	await step()
	game.start_new_game()
	game.state.nav = "repaired"
	game.state.parts = {"damping_frame":"stored","phase_regulator":"stored"}
	game.state.stabilize()
	game._save_checkpoint()
	game.depart_pod()
	game.state.bait = 0
	game.state.pulse = 0
	match mode:
		"relay":
			var relay: Vector3 = game.m2.relay_position()
			starting_position = Vector3(28,relay.y,-267)
			game.state.oxygen = 180
			game.state.suit = 55
		"kangaku": starting_position = game.ecology.rift.kangaku.position+Vector3(0,0,-7)
		"core": starting_position = Vector3(24,-268,-480)
		"return":
			starting_position = game.ENTRY
			game.state.return_core = "carried"
			game.m3.sync_core()
		_: check(false,"unknown mode"); finish(); return
	game.player.relocate(starting_position,false)
	game.player.active = true
	game.settings.shake = 0.0
	game.apply_settings()
	game.use_lock = 0
	game.toast_remaining = 0
	game.set_physics_process(true)
	active = true
	match mode:
		"relay": await relay_replay()
		"kangaku": await kangaku_replay()
		"core": await core_replay()
		"return": await return_replay()
	finish()
func relay_replay() -> void:
	var points: Array[Vector3] = [Vector3(28,game.m2.relay_position().y,-270),game.m2.relay_position(),game.m2.relay_anchor()+Vector3(0,0,1.25)]
	if not await swim(points,"visible relay screen"): return
	Pilot.look(game.player,game.m2.relay_anchor())
	await dwell(1.0)
	Pilot.tap("interact")
	await step()
	check(paused and game.hud.page == "relay","E opens screen after swimming through doorway")
	await dwell(2.0)
	press_button("relay_refill")
	await step()
	check(not paused and game.state.oxygen > 479 and game.state.suit == 100 and game.state.bait == 0 and game.state.pulse == 0,"UI accept refills oxygen/suit only")
	await dwell(1.5)
	var exit_path: Array[Vector3] = [game.m2.relay_position(),Vector3(28,game.m2.relay_position().y,-270),starting_position]
	await swim(exit_path,"relay exit")
	await dwell(1.0)
func kangaku_replay() -> void:
	var k = game.ecology.rift.kangaku
	Pilot.look(game.player,k.mouth_position())
	Input.action_press("forward")
	while k.state not in ["attention","windup"] and elapsed < 4: await step()
	Controls.release_all()
	check(k.encounter_active,"ordinary swimming triggers local encounter")
	while not k.locked and elapsed < 7:
		Pilot.look(game.player,k.mouth_position(),0.12)
		await step()
	check(k.locked,"ring and fixed aim reached naturally")
	events.append({"t":elapsed,"lock_distance":k.mouth_position().distance_to(game.player.position)})
	var suit: float = game.state.suit
	var escape: Array[Vector3] = [game.player.position+Vector3(-5,2,0)]
	await swim(escape,"normal sideways/up dodge",true)
	check(game.state.suit == suit,"live normal input avoids first locked dash")
	var cover: Array[Vector3] = [Vector3(-15,-242,-479),Vector3(3,-242,-479)]
	await swim(cover,"next column cover",true)
	while elapsed < 27:
		Pilot.look(game.player,k.mouth_position(),0.12)
		Pilot.drive(game.player,cover.back()-Map.cross_current(game.player.position)/1.7)
		await step()
	Controls.release_all()
	check(game.state.suit > 0 and not k.encounter_active,"finite encounter permits departure")
func core_replay() -> void:
	var path: Array[Vector3] = [Vector3(24,-268,-489),Vector3(24,-268.8,-500.2)]
	if not await swim(path,"inside extraction bay"): return
	Pilot.look(game.player,game.m3.core.position)
	game.select_tool(1)
	await dwell(1.0)
	Input.action_press("use_tool")
	await dwell(1.5)
	Input.action_release("use_tool")
	check(game.m3.mount.unlocked,"production cutter releases clamp")
	await dwell(0.6)
	Pilot.tap("interact")
	await step()
	check(game.state.return_core == "carried","production E collects core")
	await dwell(1.5)
	var egress: Array[Vector3] = [Vector3(25,-268,-508),Vector3(35,-268,-508),Map.ABSOLUTE_POINTS.rift_cover]
	await swim(egress,"other exit and rock cover")
	Pilot.look(game.player,Vector3(30.5,-267,-508))
	await dwell(2.0)
	check(not game.state.dead and game.state.return_core == "carried","carried core leaves other opening without teleport")
func return_replay() -> void:
	Pilot.tap("interact")
	await step()
	check(game.player.in_pod and game.state.return_core == "stored","real pod entry saves carried core")
	await dwell(1)
	game.use_lock = 0
	Pilot.tap("interact")
	await step()
	check(game.hud.page == "pod","E opens maintenance")
	await dwell(2)
	press_button("final_return")
	await step()
	check(game.mode == "return" and game.state.game_completed,"UI action saves completion before ending")
	while game.mode == "return" and elapsed < 36: await step()
	check(game.mode == "complete","natural ending reaches success")
	await dwell(2)
	press_button("research")
	await step()
	check(game.mode == "play" and not paused and game.state.game_completed,"UI returns to same completed sea")
	await dwell(2)
func finish() -> void:
	if finished: return
	finished = true
	Controls.release_all()
	if is_instance_valid(game):
		game.set_physics_process(false)
		game.player.active = false
		game.sound.stop_all()
	var file := FileAccess.open(output.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"mode":mode,"seconds":elapsed,"source_commit":source_commit,"initial_player_position":Pilot.arr(starting_position),"initial_state":"M2-complete/base equipment/zero consumables; relay oxygen180 suit55; return clip only core carried at pod hatch","enemy_fixture":"ordinary reset; no enemy position/state writes during replay","movement":"production Input and collision only after initial placement","offline":true,"samples":samples,"events":events,"failures":failures,"success":failures.is_empty()},"\t"))
	file.close()
	OS.delay_msec(150)
	paused = false
	if is_instance_valid(game): game.queue_free()
	await step()
	print("M3_REPLAY_%s mode=%s seconds=%.3f" % ["OK" if failures.is_empty() else "FAILED",mode,elapsed])
	quit(0 if failures.is_empty() else 1)
