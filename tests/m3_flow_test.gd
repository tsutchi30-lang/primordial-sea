extends SceneTree
## Position fixtures test real operations/occlusion/transactions. Swimming and
## dodge evidence are in m3_routes_test, never inferred from these placements.
const Controls = preload("res://scripts/player/controls.gd")
const Map = preload("res://data/biomes/world_map.gd")
var game
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("M3_FLOW_FAIL ",message)
func frames(count := 2) -> void:
	for i in count:
		await physics_frame
		await process_frame
func place(at: Vector3,aim: Vector3,pod := false) -> void:
	game.resume_game()
	game.player.relocate(at,pod)
	game.player.active = false
	game.player.camera.look_at(aim)
	game.use_lock = 0
func file_bytes() -> PackedByteArray: return FileAccess.get_file_as_bytes(game.saves.path("checkpoint"))
func button(action: String) -> Button:
	for node in game.hud.menu_box.get_children()+game.hud.footer.get_children():
		if node is Button and node.get_meta("action","") == action: return node
	return null
func block_save(enable: bool) -> void:
	var path: String = game.saves.path("checkpoint")+".tmp"
	if enable: DirAccess.make_dir_recursive_absolute(path)
	else: DirAccess.remove_absolute(path)
func cut_core() -> void:
	game.select_tool(1)
	Input.action_press("use_tool")
	for i in 74: game._update_cutter(1.0/60.0)
	Input.action_release("use_tool")
func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	game.saves.directory = "user://automated-tests/m3-flow-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	root.add_child(game)
	game.set_physics_process(false)
	await frames()
	game.start_new_game()
	game.player.active = false
	await terminal_states()
	await relay()
	await core_and_saving()
	await completion_and_research()
	paused = false
	game.sound.stop_all()
	game.queue_free()
	await frames(8)
	print("M3_FLOW_%s checks=%d" % ["OK" if failures.is_empty() else "FAILED",checks])
	quit(0 if failures.is_empty() else 1)
func terminal_states() -> void:
	for stage in ["repair","stabilize","final_return"]:
		game.start_new_game()
		game.player.active = false
		game.state.nav = "stored" if stage == "repair" else "repaired"
		game.state.stored_metal = 2
		game.state.parts = {"damping_frame":"stored","phase_regulator":"stored"}
		if stage == "final_return":
			game.state.stabilize()
			game.state.return_core = "stored"
		game.pause_game("pod")
		await frames(4)
		var primary := button(stage)
		check(is_instance_valid(primary) and not primary.disabled and game.hud.scroll.get_global_rect().encloses(primary.get_global_rect()),"720p initial primary visible and enabled: "+stage)
		check(root.get_visible_rect().encloses(button("resume").get_global_rect()) and game.hud.scroll.scroll_vertical == 0,"720p close visible without scrolling: "+stage)
		check(root.gui_get_focus_owner() == primary,"keyboard initially focuses primary: "+stage)
		game._on_action("equipment_menu")
		await frames(3)
		check(button("pod") != null and button("resume") != null,"equipment has persistent back and close")
	game.start_new_game()
	game.player.active = false
	game.pause_game("pod")
	await frames(3)
	check(button("repair").disabled and "金属片 あと2個" in game.hud.menu_box.get_child(2).text,"disabled repair explains specific requirements")
	game.resume_game()
func relay() -> void:
	game.depart_pod()
	var at: Vector3 = game.m2.relay_anchor()
	for offset in [Vector3(0,0,0.5),Vector3(0,0,1),Vector3(0,0,2.5),Vector3(-0.8,0.1,1.5)]:
		place(at+offset,at)
		await frames()
		check(game.m2.near_relay() and "未登録" in game.interaction_hint(),"screen-facing locked relay matches hint at "+str(offset))
		check(game.open_relay() and not game.refill_at_relay(),"locked menu cannot supply")
		game.resume_game()
	place(at+Vector3(0,0,-2),at)
	await frames()
	check(not game.m2.near_relay() and not game.open_relay(),"outer back wall blocks visible screen interaction")
	place(at+Vector3(0,0,1),at+Vector3(0,0,3))
	check(not game.open_relay(),"screen behind camera rejected")
	place(at+Vector3(0,0,1),at)
	game.state.nav = "repaired"
	check(not game.m2.relay_status().unlocked,"unsaved navigation cannot unlock relay")
	game._save_checkpoint()
	game.state.oxygen = 0
	game.state.suit = 22
	game.state.anoxia = 3
	game.state.warned_35 = true
	game.state.warned_15 = true
	game.state.bait = 0
	game.state.pulse = 0
	var original := file_bytes()
	check("補給" in game.interaction_hint() and game.open_relay() and game.refill_at_relay(),"saved navigation unlocks same screen and supplies")
	game.player.active = false
	check(game.state.oxygen == 480 and game.state.suit == 100 and game.state.anoxia == 0 and not game.state.warned_35 and not game.state.warned_15,"relay resets oxygen/suit/grace/warnings")
	check(game.state.bait == 0 and game.state.pulse == 0 and file_bytes() == original,"relay does not save or refill consumables")
	check("補給済み" in game.interaction_hint() and not game.refill_at_relay(),"full supply does not repeat success")
func core_and_saving() -> void:
	game.start_new_game()
	game.depart_pod()
	var core: Node3D = game.m3.core
	place(core.position+Vector3(0,0,1.8),core.position)
	await frames()
	check(game.current_target() == core and not game.collect_target(core),"locked core selected but cannot be picked up")
	game.select_tool(1)
	Input.action_press("use_tool")
	game._update_cutter(0.55)
	check(game.cut_progress > 0 and not game.m3.mount.unlocked,"cutter visibly progresses before release")
	game.select_tool(0)
	check(game.m3.mount.progress == 0,"tool change cancels cut")
	game.select_tool(1)
	Input.action_press("use_tool")
	game._update_cutter(0.6)
	game.pause_game()
	check(game.m3.mount.progress == 0 and not Input.is_action_pressed("use_tool"),"pause cancels cutting and held input")
	place(core.position+Vector3(0,0,1.8),core.position)
	cut_core()
	check(game.m3.mount.unlocked and game.ecology.rift.stimuli.size() == 1,"actual basic cutter unlocks once and emits one bounded stimulus")
	cut_core()
	check(game.ecology.rift.stimuli.size() == 1,"continued cutting produces no extra stimulus or reward")
	place(core.position+Vector3(0,5.5,0.1),core.position)
	check(not game.collect_target(core) and not game.m3.cut_available(),"ceiling-side interaction cannot retrieve the core")
	place(core.position+Vector3(0,0,1.8),core.position)
	game.state.carried_metal = 12
	game.state.carried_fiber = 8
	game.state.carried_shell = 8
	check(game.collect_target(core) and game.state.return_core == "carried" and not game.collect_target(core),"full materials still allow exactly one important core")
	game.notify("region message",9,0)
	check("帰還コアを回収" in game.toast_text,"low priority region does not replace important pickup")
	game._check_guidance()
	check("帰還コアを回収" in game.toast_text,"region guidance immediately after core leaves pickup visible")
	game.notify("酸素不足",5,3)
	check(game.toast_text == "酸素不足","emergency supersedes pickup")
	game.toast_remaining = 0
	game.tutorial_flags.clear()
	game._check_guidance()
	check(game.toast_text.begins_with("環状の裂け目。"),"deep arrival never replays shallow or graveyard guidance")
	check(game.state.nav == "wreck" and not game.state.stabilized and not game.m3.return_status().allowed,"early core never grants M1/M2/final return")
	# Independent notebook write cannot bank a carried core.
	game.record_observation("kangaku","identified")
	check(game.saves.load_checkpoint().return_core == "world","independent observation save does not bank core")
	game.show_title()
	game.load_game()
	check(game.state.return_core == "world" and game.m3.core.available and not game.m3.mount.unlocked,"underwater quit resets core and clamp")
	game.depart_pod()
	place(core.position+Vector3(0,0,1.8),core.position)
	cut_core()
	game.collect_target(core)
	game.state.nav = "repaired"
	game._save_checkpoint()
	var anchor: Vector3 = game.m2.relay_anchor()
	place(anchor+Vector3(0,0,1),anchor)
	game.state.oxygen = 100
	game.refill_at_relay()
	check(game.state.return_core == "carried","relay retains carried core")
	game.die("isolated death after relay")
	game.load_game()
	check(game.state.return_core == "world" and not game.m3.mount.unlocked,"death after relay resets unbanked core")
	game.depart_pod()
	place(core.position+Vector3(0,0,1.8),core.position)
	cut_core()
	game.collect_target(core)
	var old := file_bytes()
	place(game.ENTRY,game.ENTRY+Vector3.FORWARD)
	block_save(true)
	check(not game.return_to_pod() and game.player.in_pod and game.state.return_core == "carried" and file_bytes() == old,"failed deposit preserves carried core and prior file inside safe pod")
	check(game.hud.page == "save_failed" and not game.m3.activate_return(),"failure panel persists and blocks overlapping return")
	check(not game.retry_checkpoint() and game.state.return_core == "carried","repeated failure cannot bank core")
	block_save(false)
	check(game.retry_checkpoint() and game.state.return_core == "stored","successful retry banks core once")
	check(game.load_game() and game.state.return_core == "stored" and not core.available,"stored core survives reload")
func completion_and_research() -> void:
	game.player.active = false
	game.state.parts = {"damping_frame":"stored","phase_regulator":"stored"}
	check(game.stabilize_device() and game.state.return_core == "stored","stabilization keeps early stored core")
	game.resume_game()
	var old := file_bytes()
	block_save(true)
	check(not game.m3.activate_return() and game.mode == "play" and not game.state.game_completed and not game.m3.sequence.running,"return failure grants neither completion nor presentation")
	check(game.state.return_core == "stored" and file_bytes() == old,"failed return keeps core and previous save")
	block_save(false)
	check(game.retry_checkpoint() and game.mode == "return" and game.state.game_completed and game.state.return_core == "installed","retry durably commits and starts return")
	check(not game.m3.activate_return(),"double activation refused")
	var saved: Dictionary = game.saves.load_checkpoint()
	check(saved.game_completed and saved.return_core == "installed","completion already durable at presentation start")
	var age: float = game.ecology.age
	var oxygen: float = game.state.oxygen
	game.m3.sequence.set_suspended(true)
	var presentation_time: float = game.m3.sequence.elapsed
	game.m3.sequence._process(3.0)
	check(game.m3.sequence.elapsed == presentation_time and game.ecology.age == age and game.state.oxygen == oxygen,"focus pause freezes presentation and all game time")
	game.m3.sequence.set_suspended(false)
	game.m3.sequence._process(10.0)
	game.show_title()
	game.load_game()
	check(game.state.game_completed and game.mode == "play" and not game.m3.sequence.running and game.player.camera.current,"mid-sequence quit reloads completed research without replay")
	# Explicit isolated fixture before completion to exercise both presentation exits.
	for skip in [true,false]:
		game.state.game_completed = false
		game.state.return_core = "stored"
		game._save_checkpoint()
		var light: float = game.world._pod_light.light_energy
		check(game.m3.activate_return(),"presentation variant begins from valid stored-core fixture")
		if skip: game.m3.sequence.finish()
		else: game.m3.sequence._process(29.0)
		check(game.mode == "complete" and game.hud.page == "returned" and game.player.camera.current,"natural/skip both reach explicit success and restore camera")
		check(is_equal_approx(game.world._pod_light.light_energy,light),"presentation restores original pod lighting")
		game._on_action("research")
		check(game.mode == "play" and not paused and game.player.active and game.state.game_completed,"research restores ordinary simulation and achievement")
		game.depart_pod()
		game.die("post-clear isolated death")
		game.load_game()
		check(game.state.game_completed and not game.m3.core.available and game.state.return_core == "installed","post-clear death/reload retains installed core and achievement")
