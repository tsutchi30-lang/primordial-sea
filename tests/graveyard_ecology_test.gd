extends SceneTree
## Production creatures, terrain rays and colliders; explicit initial fixtures.
## Input replay and oxygen/collection routes are separate integration evidence.
const World = preload("res://scripts/world/sea_world.gd")
const Diver = preload("res://scripts/player/diver.gd")
const Hogara = preload("res://scripts/creatures/hogara.gd")
const Graveyard = preload("res://scripts/ecology/graveyard_ecology.gd")
const Crawler = preload("res://scripts/creatures/hexacrawler.gd")
const Pickup = preload("res://scripts/interaction/pickup.gd")
const Controls = preload("res://scripts/player/controls.gd")
const Art = preload("res://scripts/creatures/creature_mesh.gd")

class Host extends Node3D:
	signal hint(text: String)
	var player: CharacterBody3D
	var world: Node3D
	var hogara: Node3D
	var creatures: Array[Node3D] = []
	var hit_amount := 0.0
	func _on_player_hit(amount: float) -> void:
		hit_amount += amount
	func has_clear_path(from: Vector3, to: Vector3, excluded: Array[RID] = []) -> bool:
		var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 8)
		query.exclude = excluded
		return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

class Fixture extends Node3D:
	var pickups: Array[Node3D] = []

var scene: Node3D
var world: Node3D
var player: CharacterBody3D
var host: Node3D
var manager: Node3D
var checks := 0
var failures: Array[String] = []
var started := 0
var current_case := "startup"
var sound_history: Array[Dictionary] = []

func _initialize() -> void:
	started = Time.get_ticks_msec()
	call_deferred("run")

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started > 110000:
		printerr("GRAVEYARD_ECOLOGY_FAIL timeout case=", current_case)
		quit(1)
	return false

func check(passed: bool, description: String) -> void:
	checks += 1
	if not passed:
		failures.append(current_case + ": " + description)
		printerr("GRAVEYARD_ECOLOGY_FAIL ", current_case, ": ", description)

func frames(count := 2) -> void:
	for _index in count:
		await physics_frame
		await process_frame

func at(x: float, z: float, height := 0.4) -> Vector3:
	return Vector3(x, float(world.floor_height(x, z)) + height, z)

func run() -> void:
	Engine.physics_ticks_per_second = 240
	Controls.install()
	scene = Fixture.new()
	root.add_child(scene)
	world = World.new()
	scene.add_child(world)
	player = Diver.new()
	scene.add_child(player)
	player.active = false
	player.relocate(Vector3(0, -2, -7), false)
	host = Host.new()
	scene.add_child(host)
	host.world = world
	host.player = player
	host.hogara = Hogara.new()
	host.add_child(host.hogara)
	host.hogara.setup(world)
	var mineral := Pickup.new()
	mineral.kind = "metal"
	scene.add_child(mineral)
	mineral.global_position = at(37, -379, 0.45)
	scene.pickups.append(mineral)
	manager = Graveyard.new()
	host.add_child(manager)
	manager.setup(host)
	for urn in manager.urns:
		urn.resonated.connect(func(source: Node3D, id: int, hop: int, _expires: float): sound_history.append({"source": source, "id": id, "hop": hop, "time": manager.age}))
	await frames(3)
	await propagation_and_crossing()
	await bounded_reaction_and_blocked_route()
	await defense_and_mineral(mineral)
	await cleaning_and_pause()
	paused = false
	Controls.release_all()
	scene.queue_free()
	await frames(3)
	if failures.is_empty():
		print("GRAVEYARD_ECOLOGY_OK checks=", checks)
		quit(0)
	else:
		printerr("GRAVEYARD_ECOLOGY_FAIL failures=", failures.size(), " checks=", checks)
		quit(1)

func advance(seconds: float, tick_hogara := false) -> void:
	for step in ceili(seconds / 0.05):
		if tick_hogara:
			host.hogara.tick(0.05, player, Vector3(100, -10, 100))
		manager.tick(0.05)
		if step % 4 == 0:
			await frames(1)

func propagation_and_crossing() -> void:
	current_case = "one identified stimulus / real passage"
	var source: Node3D = manager.urns[1]
	player.global_position = source.observation_position() + Vector3(0, 0.5, 1.5)
	player.sprinting = false
	await advance(0.5)
	check(source.state == "idle", "ordinary slow swimming does not trigger the membrane")
	var low_start := at(25, -346, 0.55)
	var low_end := at(25, -350, 0.55)
	var entrance_collision := KinematicCollision3D.new()
	var initially_blocked := player.test_move(Transform3D(Basis.IDENTITY, low_start), low_end - low_start, entrance_collision)
	check(initially_blocked and entrance_collision.get_collider() == manager.crawlers[0], "crawler's real body initially occupies the low direct entrance")
	player.sprinting = true
	manager.tick(0.05)
	player.sprinting = false
	check(source.state == "warning" and source.sounds_emitted == 0, "sprint starts visible warning before any sound")
	var previous_age: float = manager.age
	var previous_membrane: Vector3 = source.membranes[0].scale
	paused = true
	manager.tick(5.0)
	check(manager.age == previous_age and source.membranes[0].scale == previous_membrane, "pause freezes stimulus, membranes and biology time")
	paused = false
	await advance(0.80)
	check(source.sounds_emitted == 0, "no sound before the one-second warning completes")
	player.global_position = at(25, -338, 2.0)
	await advance(7.0)
	check(sound_history.size() == 3, "three local colonies sound exactly once, safe distant example stays silent")
	var identities: Dictionary = {}
	var hops: Array[int] = []
	for event in sound_history:
		identities[event.id] = true
		hops.append(int(event.hop))
	check(identities.size() == 1 and hops.has(0) and hops.has(1) and hops.has(2), "propagation retains identity and stops at two hops")
	var crawler: CharacterBody3D = manager.crawlers[0]
	var departed: float = crawler.global_position.distance_to(crawler.home)
	check(departed > 6.0, "the entrance crawler actually vacates more than a diver width")
	check(crawler.investigation_count >= 1, "crawler reaches and examines the real sound location")
	check(not player.test_move(Transform3D(Basis.IDENTITY, low_start), low_end - low_start), "the same low entrance becomes physically passable after sound diversion")
	var crossing_start := at(25, -345, 1.2)
	var crossing_end := at(25, -353, 2.0)
	check(not player.test_move(Transform3D(Basis.IDENTITY, crossing_start), crossing_end - crossing_start), "production diver shape passes the opened entrance")
	check(not source.receive_stimulus(int(sound_history[0].id), 1, manager.age + 6, manager.age), "rest and duplicate stimulus cannot retrigger sound")
	check(not manager.urns[0].receive_stimulus(900, 0, manager.age - 1, manager.age), "expired stimulus is rejected")
	check(not manager.urns[0].receive_stimulus(901, 3, manager.age + 6, manager.age), "hop count above the propagation cap is rejected")
	await advance(24.0)
	check(sound_history.size() == 3 and manager.urns[3].state == "idle", "sound loop terminates and cooldown expires without an automatic replay")
	check(crawler.state == "forage", "investigation returns to a finite ordinary state")
	check(crawler.reaction_time <= 15.05, "outbound investigation, examination and return share one fifteen-second budget")
	print("GRAVEYARD_CHAIN sounds=", sound_history.size(), " departure_metres=", departed, " crawler=", crawler.state)

func bounded_reaction_and_blocked_route() -> void:
	current_case = "unreachable source / repeated sound"
	var crawler := Crawler.new()
	host.add_child(crawler)
	crawler.setup(host, player, at(-30, -327))
	await frames()
	var wall := Art.colliding_box(scene, at(-33, -327, 2.0), Vector3(0.8, 6, 7), Art.material(Color("887d6c")), 1)
	await frames()
	check(crawler.hear_sound(at(-36, -327, 0.0)), "nearby but occluded sound may be investigated")
	var maximum_travel := 0.0
	for step in 150:
		crawler.hear_sound(at(-36, -327, 0.0))
		crawler.tick(0.05)
		maximum_travel = maxf(maximum_travel, crawler.home.distance_to(crawler.global_position))
		if step % 4 == 0:
			await frames(1)
	check(crawler.state != "investigate" and crawler.investigation_count == 0, "unreachable sound is abandoned instead of extending on repeats")
	check(crawler.global_position.x > -32.5 and maximum_travel < 3.0, "swept body never walks through the solid barrier")
	check(not crawler.hear_sound(crawler.home + Vector3(30, 0, 0)), "a source beyond the nest radius cannot lure it indefinitely")
	wall.queue_free()
	crawler.queue_free()
	await frames()

func defense_and_mineral(mineral: Node3D) -> void:
	current_case = "bounded contact defense / one resource"
	var crawler := Crawler.new()
	host.add_child(crawler)
	crawler.setup(host, player, at(-28, -326))
	crawler.hit_player.connect(host._on_player_hit)
	await frames()
	player.global_position = crawler.global_position + Vector3(0, 0.1, 0.65)
	player.sprinting = true
	crawler.tick(0.05)
	player.sprinting = false
	var hits_before: float = host.hit_amount
	crawler.tick(0.65)
	check(host.hit_amount == hits_before and crawler.defense_warning > 0, "contact lifts the edges without immediate damage")
	crawler.tick(0.25)
	check(host.hit_amount == hits_before + 10.0, "warning produces exactly one ten-point attack")
	crawler.tick(1.0)
	check(host.hit_amount == hits_before + 10.0, "overlapping contact does not damage every frame")
	player.global_position = Vector3(0, -2, -7)
	crawler.queue_free()
	await frames()
	var carrier: CharacterBody3D = manager.crawlers[1]
	player.global_position = at(34, -378.5, 2.0)
	await advance(0.1)
	check(mineral.being_carried and not mineral.available, "approaching a feeding carrier reserves the existing pickup")
	mineral.tick(100.0)
	check(not mineral.available, "ordinary resource regeneration cannot duplicate a fragment in transit")
	player.global_position = Vector3(0, -2, -7)
	await advance(12.0)
	if carrier.carried_count != 1:
		print("GRAVEYARD_CARRY_DIAGNOSTIC ", carrier.last_collision, " source=", carrier.mineral_source, " current=", carrier.global_position, " support=", carrier._support_at(carrier.global_position))
	check(carrier.carried_count == 1 and mineral.available and not mineral.being_carried, "an actual single pickup is delivered and released at the nest")
	check(mineral.global_position.distance_to(carrier.home) < 1.3 and scene.pickups.size() == 1, "carrying changes location without manufacturing another resource")
	var deposited_support: Dictionary = carrier._support_at(mineral.global_position)
	check(not deposited_support.is_empty() and mineral.global_position.y > float(deposited_support.get("y", INF)), "delivered resource rests above the real shell surface")
	mineral.take()
	await advance(5.0)
	check(not mineral.available and carrier.carried_count == 1, "completed animation does not restore a collected resource")
	print("GRAVEYARD_MINERAL deliveries=", carrier.carried_count, " pickup_count=", scene.pickups.size(), " carrier_position=", carrier.global_position, " home=", carrier.home, " pickup=", mineral.global_position)

func cleaning_and_pause() -> void:
	current_case = "Hogara low rim cleaning / pause"
	player.global_position = Vector3(0, -2, -7)
	var cleaner: CharacterBody3D = manager.crawlers[2]
	await advance(48.0, true)
	check(cleaner.cleaning_count >= 1, "natural Hogara rest permits a short low-rim cleaning")
	check(cleaner.cleaning_regrow > 0.0 and not cleaner.foul_patch.visible, "cleaning changes attached fouling and has finite regrowth")
	check(not host.hogara._under_roof(cleaner.global_position), "cleaner stays outside belly portals and roof")
	var position_before := cleaner.global_position
	var clock_before: float = cleaner.age
	paused = true
	manager.tick(10.0)
	check(cleaner.global_position == position_before and cleaner.age == clock_before, "pause does not advance moving, carrying or cleaning creatures")
	paused = false
	print("GRAVEYARD_CLEAN cleanings=", cleaner.cleaning_count, " hogara_state=", host.hogara.state)
