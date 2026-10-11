extends SceneTree
## Static fixtures are for visual review, never route/dodge evidence.
const Map = preload("res://data/biomes/world_map.gd")
const Pilot = preload("res://tools/capture_m2_common.gd")
var game
var output := "res://build/m3/visuals"
var images: Array[Dictionary] = []
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()-1):
		if args[i] == "--output": output = args[i+1]
	call_deferred("run")
func frames(count := 3) -> void:
	for i in count: await process_frame
func camera(from: Vector3,to: Vector3,fov := 80.0) -> void:
	game.resume_game()
	game.player.relocate(from,false)
	game.player.active = false
	Pilot.look(game.player,to)
	game.player.camera.fov = fov
	game.player.zoom_fov = fov
	game.toast_remaining = 0
func shot(id: String,note: String) -> void:
	await frames(5)
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if frame.save_png(output.path_join(id+".png")) != OK:
		printerr("M3_VISUAL_FAIL ",id)
		quit(1)
	images.append({"id":id,"file":id+".png","size":[frame.get_width(),frame.get_height()],"position":Pilot.arr(game.player.position),"camera_rotation":Pilot.arr(game.player.camera.global_rotation),"fov":game.player.camera.fov,"page":game.hud.page,"fixture":note,"core":game.state.return_core,"kangaku":game.ecology.rift.kangaku.state,"visual_review":"not implied by generation"})
	print("M3_VISUAL_SAVED ",id)
func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	game.saves.directory = "user://automated-tests/m3-visual-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	root.add_child(game)
	game.set_physics_process(false)
	game.start_new_game()
	game.player.active = false
	for stage in ["repair","stabilize","return"]:
		game.state.nav = "stored" if stage == "repair" else "repaired"
		game.state.stored_metal = 2
		game.state.parts = {"damping_frame":"stored","phase_regulator":"stored"}
		if stage == "return":
			game.state.stabilize()
			game.state.return_core = "stored"
		game.pause_game("pod")
		await shot("T-"+stage,"Declared ready-to-maintain state; initial scroll=0 at 720p.")
	game.state.return_core = "world"
	game.m3.sync_core(true)
	var anchor: Vector3 = game.m2.relay_anchor()
	camera(anchor+Vector3(0,0,1.4),anchor)
	game.state.nav = "wreck"
	await shot("R-locked","Camera 1.4 m in front of the actual screen; unsaved/locked navigation.")
	game.state.nav = "repaired"
	game._save_checkpoint()
	game.state.oxygen = 200
	await shot("R-available","Same screen camera; saved navigation, low oxygen.")
	game.open_relay()
	await shot("R-menu","Real relay open operation from declared close camera.")
	camera(Map.ABSOLUTE_POINTS.rift_shelf,Vector3(23,-261,-493))
	await shot("D-rift-entry","Frozen normal initial ecology; shelf view toward ship, rock columns and cross current.")
	var k = game.ecology.rift.kangaku
	camera(k.position+Vector3(6,1,8),k.position+Vector3(0,0,3))
	k.form.animate(1,0,0,false,true)
	await shot("K-swimming","Frozen natural initial pose; continuous band.")
	# Pose fixtures reveal anatomy and warning; motion replay separately tests AI.
	k.global_basis = Basis.IDENTITY
	k.state = "windup"
	k.form.animate(1,1,0,true,true)
	camera(k.position+Vector3(0,0,-7),k.position+Vector3(0,0,1))
	await shot("K-ring-mouth","Declared locked windup pose of the same continuous 10.4 m body.")
	camera(k.position+Vector3(3,1,-3.5),k.position)
	await shot("K-teeth","Close anatomy view at ordinary FOV; solid comb teeth.")
	k.state = "recover"
	k.form.animate(0.28,0,1,false,true)
	camera(k.position+Vector3(5,2,-5),k.position+Vector3(0,0,2))
	await shot("K-recovery","Declared recovery pose, partially uncurled.")
	camera(Vector3(24,-268,-480),Vector3(24,-268,-498))
	await shot("W-entrance","Solid ship roof and north doorway; no ceiling collection.")
	camera(Vector3(24,-268.8,-499.7),game.m3.core.position)
	game.select_tool(1)
	await shot("W-clamp-core","Core still locked; actual cutter target.")
	game.m3.mount.cut(0.65,1.2)
	game.cut_progress = game.m3.mount.progress
	game.cut_label = "固定具"
	await shot("W-cut-progress","Static mid-cut feedback, production cut method with declared elapsed time.")
	game.m3.mount.cut(0.6,1.2)
	game.cut_progress = 0
	await shot("W-unlocked","Production clamp completion opens arms.")
	game.collect_target(game.m3.core)
	game.m3.core.tick(0.3)
	await shot("C-carried","Actual E-equivalent collection method from declared camera; carried and unbanked.")
	camera(Vector3(26,-268,-508),Vector3(40,-266,-508))
	await shot("W-other-exit","Eastern side opening toward the next rock cover.")
	game.player.relocate(game.ENTRY,false)
	game.return_to_pod()
	game.player.active = false
	game.pause_game("pod")
	await shot("C-stored","Real deposit/save operation; ready for final return.")
	game.m3.activate_return()
	game.m3.sequence.set_suspended(true)
	game.m3.sequence.elapsed = 15
	game.m3.sequence._update_visual()
	await shot("E-returning","Saved achievement; dedicated paused-scene presentation shown at t=15 s fixture.")
	game.m3.sequence.finish()
	await shot("E-success","Real skip reaches success UI after durable save.")
	game.m3.continue_research()
	game.player.active = false
	game.pause_game("pod")
	await shot("E-research","Same saved completed game, normal maintenance and research available.")
	camera(Vector3(-10,game.world.floor_height(-10,-208)+2.5,-208),Vector3(-12,game.world.floor_height(-12,-216)+1.4,-216))
	await shot("U-web","Same existing web patch/collision with sagging diagonal strands; no nearby multi-label clutter.")
	var file := FileAccess.open(output.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind":"static scene/pose/state fixtures, not route evidence","renderer":RenderingServer.get_video_adapter_name(),"images":images},"\t"))
	file.close()
	game.sound.stop_all()
	paused = false
	game.queue_free()
	await frames(12)
	print("M3_VISUAL_OK images=",images.size())
	quit(0)
