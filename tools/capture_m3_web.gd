extends SceneTree
## Cross-version static camera; intentionally uses only M2 public scene fields.
const Pilot = preload("res://tools/capture_m2_common.gd")
var output := "res://build/m3/web-comparison/current"
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()-1):
		if args[i] == "--output": output = args[i+1]
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	game.saves.directory = "user://automated-tests/web-review-%d" % OS.get_process_id()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_new_game()
	game.depart_pod()
	game.player.relocate(Vector3(-10,game.world.floor_height(-10,-208)+2.5,-208),false)
	game.player.active = false
	Pilot.look(game.player,Vector3(-12,game.world.floor_height(-12,-216)+1.4,-216))
	game.player.camera.fov = 80
	for stage in ["intact","cut"]:
		if stage == "cut":
			for web in game.ecology.plains.webs: web.sever("cutter")
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(output.path_join(stage+".png")) != OK: quit(1); return
	var file := FileAccess.open(output.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"fixture":"frozen fresh game; all visible web sections severed for cut fixture","position":Pilot.arr(game.player.position),"rotation":Pilot.arr(game.player.camera.global_rotation),"fov":80,"size":root.size},"\t"))
	file.close()
	game.sound.stop_all()
	OS.delay_msec(150)
	game.queue_free()
	await process_frame
	print("M3_WEB_VISUAL_OK")
	quit(0)
