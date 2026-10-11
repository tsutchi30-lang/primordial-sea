extends SceneTree
const Map = preload("res://data/biomes/world_map.gd")
const Pilot = preload("res://tools/capture_m2_common.gd")
const Controls = preload("res://scripts/player/controls.gd")
var game
var checks := 0
var failures: Array[String] = []
var evidence: Array[Dictionary] = []
var active := false
var elapsed := 0.0
func _initialize() -> void: call_deferred("run")
func _physics_process(delta: float) -> bool:
	if active and not paused: elapsed += delta
	return false
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("M3_ECOLOGY_FAIL ",message)
func step() -> void:
	await physics_frame
	await process_frame
func dwell(seconds: float) -> void:
	var until := elapsed+seconds
	while elapsed < until: await step()
func wall(at: Vector3,size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	game.add_child(body)
	body.position = at
	return body
func fresh() -> void:
	active = false
	game.start_new_game()
	game.depart_pod()
	game.use_lock = 0
	active = true
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/m3/ecology")
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	game.saves.directory = "user://automated-tests/m3-ecology-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	root.add_child(game)
	await step()
	fresh()
	await senses_and_predation()
	for distance in [6.0,10.0]:
		for action in ["right","ascend","descend"]:
			await dodge(distance,action)
	await damage_and_limits()
	await currents()
	await opposite_exits()
	await roof_retreat()
	active = false
	game.set_physics_process(false)
	game.player.active = false
	game.sound.stop_all()
	OS.delay_msec(150) # Let the real audio mixer release playback before teardown.
	var file := FileAccess.open("res://build/m3/ecology/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind":"initial encounter fixtures then production input/AI/collision; natural predation separately","cases":evidence,"failures":failures,"checks":checks},"\t"))
	file.close()
	paused = false
	game.queue_free()
	await step()
	print("M3_ECOLOGY_%s checks=%d" % ["OK" if failures.is_empty() else "FAILED",checks])
	quit(0 if failures.is_empty() else 1)
func senses_and_predation() -> void:
	var k = game.ecology.rift.kangaku
	game.player.relocate(Map.ABSOLUTE_POINTS.rift_shelf,false)
	game.player.active = false
	Pilot.look(game.player,k.mouth_position())
	check(not k._detect(),"view rotation / stationary observer does not trigger discovery")
	var started := elapsed
	while k.eaten_count == 0 and elapsed-started < 65: await step()
	check(k.eaten_count > 0,"ordinary rift patrol actually captures living glowgrain")
	var reduced := false
	for school in game.ecology.rift.schools: reduced = reduced or school.density < 0.9
	check(reduced,"capture reduces actual prey density")
	check(not game.observations.has("kangaku"),"unobserved capture does not grant journal data")
	evidence.append({"case":"natural-predation","elapsed":elapsed-started,"eaten":k.eaten_count,"densities":[game.ecology.rift.schools[0].density,game.ecology.rift.schools[1].density]})
	# Local perception fixture in open water, no hidden detection overrides.
	k.position = Vector3(-62,-244,-515)
	k.global_basis = Basis.IDENTITY
	game.player.relocate(k.position+Vector3(0,0,-7),false)
	game.player.swim_intent = Vector3.FORWARD
	check(k.sees_player(),"normal swimming at 7 m in forward cone is visible")
	game.player.position = k.position+Vector3(0,0,-12)
	check(not k.sees_player() and k.sees_player(true),"12 m needs existing encounter")
	game.player.sprinting = true
	k.reacquire_remaining = 0
	check(k._detect(),"actual sprint intent within 16 m can be detected")
	game.player.position = k.position+Vector3(0,0,-18)
	check(not k._detect(),"remote sprint cannot be detected")
	game.player.position = k.position+Vector3(0,0,-7)
	var blocker := wall(k.position+Vector3(0,0,-3),Vector3(8,8,0.4))
	await step()
	check(not k._detect() and not k.sees_player(true),"rock or ship masks both sound discovery and maintained sight")
	blocker.queue_free()
	await step()
	game.player.position = k.position+Vector3(0,4,-5)
	check(k.sees_player(true),"maintained perception uses vertical displacement")
	k._face(game.player.position,1)
	check((-k.global_basis.z).y > 0.5,"aim turns upward in three dimensions")
	var total := 0.0
	for i in range(1,k.form.centerline.size()): total += k.form.centerline[i-1].distance_to(k.form.centerline[i])
	check(absf(total-10.4) < 0.01,"continuous band preserves body length")
func dodge(distance: float,action: String) -> void:
	fresh()
	var k = game.ecology.rift.kangaku
	# Declared post-acquisition fixture: exact mouth distance, common open water.
	k.position = Vector3(-62,-244,-515)
	k.home = k.position
	k.global_basis = Basis.IDENTITY
	k.prey = null
	k.encounter_active = true
	k.encounter_time = 0
	k.dash_count = 0
	game.player.relocate(k.position+Vector3(0,0,-distance),false)
	game.player.active = true
	Pilot.look(game.player,k.position)
	k.last_seen = game.player.position
	k._enter("attention")
	var began := elapsed
	while not k.locked and elapsed-began < 4: await step()
	check(k.locked,"mouth %dm %s receives visible lock after windup" % [distance,action])
	var locked_direction: Vector3 = k.dash_direction
	var at_lock: Vector3 = game.player.position
	var measured: float = k.mouth_position().distance_to(at_lock)
	Input.action_press(action)
	while k.state not in ["recover","retreat"] and elapsed-began < 6: await step()
	Controls.release_all()
	check(game.state.suit == 100,"normal %s avoids locked attack at %.2fm" % [action,measured])
	check(k.dash_direction.dot(locked_direction) > 0.9999,"locked direction never follows dodge")
	check(game.player.position.distance_to(at_lock) > 1.7,"avoidance uses real player movement")
	evidence.append({"case":"dodge","initial_mouth_m":distance,"mouth_m_at_lock":measured,"input":action,"speed":"normal 2.8 m/s","suit_after":game.state.suit,"displacement":game.player.position.distance_to(at_lock),"dash_count":k.dash_count,"elapsed":elapsed-began})
func damage_and_limits() -> void:
	fresh()
	var k = game.ecology.rift.kangaku
	k.position = Vector3(-62,-244,-515)
	k.home = k.position
	k.global_basis = Basis.IDENTITY
	k.encounter_active = true
	game.player.relocate(k.position+Vector3(0,0,-6),false)
	game.player.active = false
	k.last_seen = game.player.position
	k._enter("attention")
	var began := elapsed
	while game.state.suit == 100 and elapsed-began < 5: await step()
	check(game.state.suit == 65,"undefended mouth contact damages exactly 35")
	await dwell(0.5)
	check(game.state.suit == 65,"body segments do not multiply attack damage")
	while k.encounter_active and elapsed-began < 20: await step()
	check(not k.encounter_active and k.dash_count <= 2 and elapsed-began <= 18.1,"encounter ends on independent time or two-dash limit")
	var retired_at := elapsed
	while k.state == "retreat" and elapsed-retired_at < 100: await step()
	check(k.state != "retreat" and k.reacquire_remaining > 9,"retreat physically reaches destination before reacquisition cooldown")
	game.player.position = k.position+Vector3(0,0,-3)
	game.player.swim_intent = Vector3.FORWARD
	game.player.sprinting = true
	check(not k._detect(),"arrival cannot immediately rediscover same diver")
	var before: float = game.state.suit
	k.position = Vector3(-62,-244,-515)
	k.global_basis = Basis.IDENTITY
	game.player.position = k.position+Vector3(0,0,-4)
	var blocker := wall(k.position+Vector3(0,0,-2),Vector3(10,10,0.5))
	await step()
	k.encounter_active = true
	k.encounter_time = 0
	k.dash_direction = Vector3.FORWARD
	k.attack_hit = false
	k.dash_distance = 0
	k._enter("dash")
	# High-delta fixture deliberately spans the wall in one attempted motion.
	k.tick(0.7)
	check(game.state.suit == before and k.position.z > blocker.position.z and k.state == "recover","swept high-speed dash stops at wall and cannot bite through it")
	blocker.queue_free()
	await step()
func currents() -> void:
	fresh()
	var center: Vector3 = Map.CROSS_CURRENT_CENTER
	check(Map.cross_current(center).length() <= 1.5 and Map.cross_current(center+Vector3(0,0,5)).length() == 0,"cross current has bounded magnitude and smooth zero boundary")
	game.player.relocate(center+Vector3(0,0,7),false)
	game.player.active = true
	Pilot.look(game.player,center)
	Input.action_press("forward")
	await dwell(5)
	Controls.release_all()
	check(game.player.position.z < center.z-5,"normal input enters and leaves the current band")
	game.player.relocate(center,false)
	game.player.active = true
	game.player.rotation = Vector3.ZERO
	game.player.camera.rotation = Vector3.ZERO
	var start: Vector3 = game.player.position
	Input.action_press("left")
	await dwell(2)
	Controls.release_all()
	check(game.player.position.x < start.x-2,"normal swim can oppose current")
	var k = game.ecology.rift.kangaku
	k.position = center
	k.global_basis = Basis.IDENTITY
	k.encounter_active = false
	k._enter("recover")
	var before: Vector3 = k.position
	k.tick(0.25)
	check(k.position.x > before.x+0.25,"same current transports Kangaku during recovery")

func swim_live(points: Array[Vector3],label: String) -> bool:
	var k = game.ecology.rift.kangaku
	var encountered := false
	for at in points:
		var best: float = game.player.position.distance_to(at)
		var progressed := elapsed
		while game.player.position.distance_to(at) > 0.6:
			var distance: float = game.player.position.distance_to(at)
			if distance < best-0.1:
				best = distance
				progressed = elapsed
			if elapsed-progressed > 10 or game.state.dead:
				Controls.release_all()
				check(false,label+" blocked "+str(game.player.position))
				return false
			Pilot.look(game.player,at,0.15)
			Pilot.drive(game.player,at-Map.cross_current(game.player.position)/1.7,true)
			encountered = encountered or k.encounter_active
			await step()
	Controls.release_all()
	check(encountered,label+" actually triggers local pursuit with swimming")
	return true

func opposite_exits() -> void:
	for blocked_side in ["north","east"]:
		fresh()
		var k = game.ecology.rift.kangaku
		game.state.return_core = "carried"
		game.m3.sync_core()
		# Initial encounter staging only, followed by real movement/AI. No enemy
		# freezes, safe regions, teleports or invulnerability during the escape.
		k.prey = null
		k.feed_cooldown = 10
		k._enter("patrol")
		var path: Array[Vector3] = []
		if blocked_side == "north":
			k.position = Vector3(24,-268,-474)
			k.global_basis = Basis.IDENTITY
			game.player.relocate(Vector3(24,-268,-482),false)
			path.assign([Vector3(24,-268,-491),Vector3(25,-268,-508),Vector3(35,-268,-508),Map.ABSOLUTE_POINTS.rift_cover])
		else:
			k.position = Vector3(39,-268,-508)
			k.global_basis = Basis.looking_at(Vector3.LEFT,Vector3.UP)
			game.player.relocate(Vector3(32,-268,-508),false)
			path.assign([Vector3(25,-268,-508),Vector3(24,-268,-491),Vector3(24,-268,-482),Vector3(15,-260,-478)])
		game.player.active = true
		var began := elapsed
		var reached := await swim_live(path,"escape opposite "+blocked_side)
		check(reached and not game.state.dead and game.state.return_core == "carried","core carrier can escape other opening with enemy lured to "+blocked_side)
		evidence.append({"case":"opposite-exit","enemy_initial_side":blocked_side,"success":reached,"seconds":elapsed-began,"suit_after":game.state.suit,"end":Pilot.arr(game.player.position)})

func roof_retreat() -> void:
	for at in [Vector3(24,-268,-491),Vector3(27,-268,-508)]:
		fresh()
		game.player.relocate(Map.ABSOLUTE_POINTS.rift_shelf,false)
		game.player.active = false
		var k = game.ecology.rift.kangaku
		k.position = at
		k.global_basis = Basis.looking_at(Vector3.FORWARD if at.z > -500 else Vector3.LEFT,Vector3.UP)
		k.form.animate(1,0,0,false,true)
		k._begin_retreat()
		var began := elapsed
		while k.state == "retreat" and elapsed-began < 65: await step()
		check(k.state == "patrol" and k.reacquire_remaining > 0,"post-dash retreat leaves real ship roof through a door and reaches a refuge")
		evidence.append({"case":"roof-retreat","start":Pilot.arr(at),"end":Pilot.arr(k.position),"seconds":elapsed-began,"state":k.state})
