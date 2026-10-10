extends SceneTree
## Production ecology/terrain/diver, fixed biology deltas, explicit start fixtures.
const World = preload("res://scripts/world/sea_world.gd")
const Diver = preload("res://scripts/player/diver.gd")
const Ecosystem = preload("res://scripts/ecology/ecosystem.gd")
const Controls = preload("res://scripts/player/controls.gd")
var scene: Node3D
var world: Node3D
var diver: CharacterBody3D
var ecology: Node3D
var field: Node3D
var checks := 0
var failures: Array[String] = []
var drops: Array[Dictionary] = []
var hits: Array[float] = []
var started := 0
var current_case := "startup"

func _initialize() -> void:
	started = Time.get_ticks_msec()
	call_deferred("run")

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started > 85000:
		printerr("PLAINS_ECOLOGY_FAIL timeout case=", current_case)
		quit(1)
	return false

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(current_case + ": " + description)
		printerr("PLAINS_ECOLOGY_FAIL ", current_case, ": ", description)

func frames(count := 2) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func biology(seconds: float, predator := false) -> void:
	var count := ceili(seconds / 0.025)
	for i in count:
		field.tick(0.025)
		if predator:
			field.predator.tick(0.025)
		if i % 120 == 0:
			await process_frame

func run() -> void:
	Controls.install()
	scene = Node3D.new()
	root.add_child(scene)
	world = World.new()
	scene.add_child(world)
	diver = Diver.new()
	scene.add_child(diver)
	diver.active = false
	diver.relocate(Vector3(0, -2, -7), false)
	ecology = Ecosystem.new()
	scene.add_child(ecology)
	ecology.setup(diver, world)
	field = ecology.plains
	field.resource_drop.connect(func(kind: String, at: Vector3, id: String): drops.append({"kind": kind, "at": at, "id": id}))
	ecology.player_hit.connect(func(amount: float): hits.append(amount))
	await frames()
	await contact_and_cut()
	await natural_grazing_and_supplies()
	await lure_and_defense()
	await actual_entanglement()
	await pause_and_regrowth()
	paused = false
	Controls.release_all()
	scene.queue_free()
	await frames(3)
	if failures.is_empty():
		print("PLAINS_ECOLOGY_OK checks=", checks)
		quit(0)
	else:
		printerr("PLAINS_ECOLOGY_FAIL failures=", failures.size(), " checks=", checks)
		quit(1)

func contact_and_cut() -> void:
	current_case = "soft contact / basic cutter / one generation one resource"
	var web: Node3D = field.webs[1]
	diver.relocate(web.global_position, false)
	diver.camera.look_at(web.global_position + Vector3.FORWARD)
	field.tick(0.025)
	check(is_equal_approx(field.player_speed_scale(), 0.55), "visible web applies one 55 percent speed factor")
	var before := drops.size()
	for _i in 11:
		field.cut_target(diver.camera, 0.1, 1.2)
	check(web.intact and drops.size() == before, "1.1 seconds does not finish the basic 1.2 second cutter")
	for _i in 2:
		field.cut_target(diver.camera, 0.1, 1.2)
	check(not web.intact and drops.size() == before + 1 and is_equal_approx(field.player_speed_scale(), 1.0), "inside player self-cuts the aimed section and clears slowing")
	for _i in 20:
		field.cut_target(diver.camera, 0.1, 1.2)
	check(drops.size() == before + 1 and not web.sever("cutter"), "repeated input on the same cut section does not duplicate fibre")
	# Restore neither state nor rewards: choose two other intact neighbouring cells.
	var left: Node3D = field.webs[6]
	var right: Node3D = field.webs[7]
	diver.relocate((left.global_position + right.global_position) * 0.5, false)
	check(left.touches(diver.global_position) and right.touches(diver.global_position) and is_equal_approx(field.player_speed_scale(), 0.55), "overlapping strands never multiply the slowing")
	diver.relocate(web.global_position + Vector3(0, 0, 2.0), false)
	check(is_equal_approx(field.player_speed_scale(), 1.0), "leaving the volume clears slowing without changing tools or view")
	var upgraded: Node3D = field.webs[0]
	diver.relocate(upgraded.global_position, false)
	diver.camera.look_at(upgraded.global_position + Vector3.FORWARD)
	for _i in 5:
		field.cut_target(diver.camera, 0.1, 0.6)
	check(upgraded.intact, "upgraded cutter still requires its hold")
	for _i in 2:
		field.cut_target(diver.camera, 0.1, 0.6)
	check(not upgraded.intact, "the same production cutter accepts the upgraded duration")
	field.cancel_cut()

func natural_grazing_and_supplies() -> void:
	current_case = "natural grazing / real gap / finite molt supply"
	diver.relocate(Vector3(0, -2, -7), false)
	var web: Node3D = field.webs[4]
	check(web.intact, "the feeding section starts intact")
	await biology(22.0)
	check(not web.intact and field.blades[0].grazed_count + field.blades[1].grazed_count >= 1, "without input a bladeworm approaches and actually removes one section")
	check(field.webs[7].intact, "natural grazers leave the nearby trap available")
	diver.relocate(web.global_position + Vector3(0, 0, 1.5), false)
	for _i in 50:
		diver.move_and_collide(Vector3(0, 0, -0.06))
	check(diver.global_position.z < web.global_position.z - 1.0 and is_equal_approx(field.player_speed_scale(), 1.0), "actual diver crosses the removed section without collision or slowing")
	diver.relocate(Vector3(0, -2, -7), false)
	await biology(370.0)
	var shell_ids: Dictionary = {}
	for drop in drops:
		if drop.kind == "shell_plate":
			shell_ids[drop.id] = true
	check(shell_ids.size() == 6 and field.blades[0].molts == 3 and field.blades[1].molts == 3, "each of two animals sheds three uniquely identified collectable shells")
	var count := shell_ids.size()
	await biology(100.0)
	shell_ids.clear()
	for drop in drops:
		if drop.kind == "shell_plate":
			shell_ids[drop.id] = true
	check(shell_ids.size() == count, "continued animation cannot create unlimited molts")

func lure_and_defense() -> void:
	current_case = "bounded bait response / warned contact defence"
	var blade: CharacterBody3D = field.blades[0]
	# Wait for the finite natural feeding trip, without writing an AI state.
	for _i in 1200:
		if blade.state == "swim":
			break
		field.tick(0.025)
	diver.relocate(blade.home + Vector3(4, 1, 0), false)
	check(ecology.use_bait(blade.home + Vector3(3, 0, 0)), "existing bait is placed through its LOS-checked production action")
	var before := blade.global_position
	await biology(7.0)
	check(blade.global_position.distance_to(before) > 0.5 and blade.state == "bait", "the nearby leaf animal actually swims toward plant bait")
	var returned_home := false
	var left_bait := false
	for i in 800:
		field.tick(0.025)
		if i == 60:
			left_bait = blade.state != "bait"
		if blade.state == "swim" and blade.global_position.distance_to(blade.home) < 0.5:
			returned_home = true
			break
	check(left_bait and returned_home, "bait response ends after eight seconds and actually returns home before resuming feeding")
	for bait in ecology.baits:
		bait.node.queue_free()
	ecology.baits.clear()
	diver.relocate(blade.global_position + Vector3(0.25, 0, 0), false)
	diver.sprinting = true
	var hit_before := hits.size()
	await biology(0.7)
	check(blade.state == "warning" and hits.size() == hit_before, "defence visibly warns before the 0.8 second strike")
	await biology(0.35)
	check(hits.size() == hit_before + 1 and is_equal_approx(hits.back(), 8.0), "nearby persistence produces one 8-point strike through shared invulnerability")
	await biology(0.8)
	check(hits.size() == hit_before + 1, "multiple contact frames do not cause repeated damage")
	diver.relocate(blade.home + Vector3(0, 4, 0), false)
	await biology(4.0)
	check(blade.state != "warning" and blade.global_position.distance_to(blade.home) < 3.0, "leaving ends the local defence without a chase")

func actual_entanglement() -> void:
	current_case = "real swept mouth contact / bounded snare / continuing pursuit clock"
	var web: Node3D = field.webs[7]
	var predator: CharacterBody3D = field.predator
	check(web.intact, "trap section survives unrelated natural feeding")
	# Initial encounter fixture only. Production AI must see, warn, and move.
	predator.global_position = web.global_position + Vector3(0, 0, -3.3)
	predator.home = predator.global_position
	predator.rotation.y = PI
	diver.relocate(web.global_position + Vector3(0, 0, 3.0), false)
	var observed := false
	for _i in 350:
		field.tick(0.025)
		predator.tick(0.025)
		if predator.state == "snared":
			observed = true
			break
	check(observed and web.touches(predator.global_position, 0.7), "normal attention, warning and dash physically meet the visible trap")
	var caught := predator.global_position
	var chase_age: float = predator.pursuit_time
	var state_age: float = predator.state_time
	await biology(2.8, true)
	check(predator.state == "snared" and predator.global_position.distance_to(caught) < 0.001, "membrane stays caught for the advertised interval")
	check(predator.pursuit_time > chase_age + 2.7 and predator.state_time > state_age + 2.7, "entanglement advances rather than resets the existing chase timer")
	await biology(0.9, true)
	check(not web.intact and predator.state == "return" and predator.snare_count == 1, "3.5 second escape breaks that same web and retreats once")
	diver.relocate(Vector3(0, -2, -7), false)
	await biology(18.0, true)
	check(not predator.pursuing_player and predator.state == "ambush", "post-snare retreat reaches an ambush home and ends pursuit")

func pause_and_regrowth() -> void:
	current_case = "pause / delayed safe web generation"
	var web: Node3D = field.webs[1]
	if web.intact:
		web.sever("cutter")
	diver.relocate(web.global_position, false)
	var generation: int = web.generation
	await biology(125.0)
	check(not web.intact and web.generation == generation, "a due web waits instead of regrowing around the diver")
	var before_age: float = field.age
	var before_predator: float = field.predator.age
	var before_blade: float = field.blades[0].age
	paused = true
	field.tick(10.0)
	field.predator.tick(10.0)
	field.blades[0].tick(10.0)
	check(field.age == before_age and field.predator.age == before_predator and field.blades[0].age == before_blade, "pause advances no manager, predator or bladeworm time")
	paused = false
	diver.relocate(web.global_position + Vector3(0, 0, 6), false)
	await biology(0.1)
	check(web.intact and web.generation == generation + 1, "leaving permits one next generation with a fresh finite resource identity")
