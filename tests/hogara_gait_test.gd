extends SceneTree
## Uses the production terrain, diver, dedicated model/colliders and biology tick.
## Initial positions/blocked-exit walls are explicit test fixtures, not playthrough.
const World = preload("res://scripts/world/sea_world.gd")
const Diver = preload("res://scripts/player/diver.gd")
const Hogara = preload("res://scripts/creatures/hogara.gd")
const Controls = preload("res://scripts/player/controls.gd")
var scene: Node3D
var world: Node3D
var diver: CharacterBody3D
var animal: Node3D
var mouth: CharacterBody3D
var checks := 0
var failures: Array[String] = []
var current_case := "startup"
var started := 0
var school := Vector3(100, -10, 100)

func _initialize() -> void:
	started = Time.get_ticks_msec()
	call_deferred("run")

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started > 110000:
		printerr("HOGARA_GAIT_FAIL timeout case=", current_case)
		quit(1)
	return false

func check(passed: bool, description: String) -> void:
	checks += 1
	if not passed:
		failures.append(current_case + ": " + description)
		printerr("HOGARA_GAIT_FAIL ", current_case, ": ", description)

func frames(count := 2) -> void:
	for _index in count:
		await physics_frame
		await process_frame

func reset_animal() -> void:
	if is_instance_valid(animal):
		scene.remove_child(animal)
		animal.queue_free()
	animal = Hogara.new()
	scene.add_child(animal)
	animal.setup(world)
	diver.relocate(Vector3(0, -2, -7), false)
	diver.active = false
	mouth.global_position = Vector3(80, -10, 0)
	await frames()

func run() -> void:
	# The contact simulation advances fixed biology deltas. Physical exit cases
	# additionally step the actual server at 240 Hz to keep CI bounded.
	Engine.physics_ticks_per_second = 240
	Controls.install()
	scene = Node3D.new()
	root.add_child(scene)
	world = World.new()
	scene.add_child(world)
	diver = Diver.new()
	scene.add_child(diver)
	mouth = CharacterBody3D.new()
	mouth.collision_layer = 4
	mouth.collision_mask = 1 | 8
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	collision.shape = sphere
	mouth.add_child(collision)
	scene.add_child(mouth)
	await reset_animal()
	await walking_and_pause()
	await passage_dimensions()
	await rest_from_multiple_positions()
	await blocked_exit_cancels()
	paused = false
	Controls.release_all()
	scene.queue_free()
	await frames(3)
	if failures.is_empty():
		print("HOGARA_GAIT_OK checks=", checks)
		quit(0)
	else:
		printerr("HOGARA_GAIT_FAIL failures=", failures.size(), " checks=", checks)
		quit(1)

func walking_and_pause() -> void:
	current_case = "world-planted contacts / slope / turning / rest / restart"
	var maximum_slide := 0.0
	var maximum_step := 0.0
	var maximum_ground_error := 0.0
	var maximum_swings := 0
	var maximum_visual_error := 0.0
	var maximum_body_step := 0.0
	var landings := [0, 0, 0]
	var seen: Dictionary = {}
	var warning_started := -1.0
	var minimum_warning := INF
	var initial_heading: float = animal.rotation.y
	var heading_change := 0.0
	var resting_footfalls := -1
	var stopped_stamps := false
	var normal_speed_reached := false
	for frame in 5200:
		var before: Array = animal.gait.feet.duplicate(true)
		var previous_position: Vector3 = animal.global_position
		var previous_state: String = animal.state
		animal.tick(0.025, diver, school)
		seen[animal.state] = true
		if animal.state == "rest_warning" and previous_state != "rest_warning":
			warning_started = animal.age
		if animal.state == "settling" and previous_state == "rest_warning":
			minimum_warning = minf(minimum_warning, animal.age - warning_started)
		if animal.state == "rest":
			if previous_state != "rest":
				resting_footfalls = animal.gait.footfall_count
			elif animal.state_time > 3.0:
				stopped_stamps = animal.gait.footfall_count == resting_footfalls and animal.foot_dust.is_empty()
		if animal.state == "walk" and animal.speed > 0.7:
			normal_speed_reached = true
		maximum_body_step = maxf(maximum_body_step, animal.global_position.distance_to(previous_position))
		heading_change = maxf(heading_change, absf(angle_difference(initial_heading, animal.rotation.y)))
		var swings := 0
		for index in 3:
			var foot: Dictionary = animal.gait.feet[index]
			var delta_position := Vector3(foot.position).distance_to(before[index].position)
			maximum_step = maxf(maximum_step, delta_position)
			if not before[index].swing and not foot.swing:
				maximum_slide = maxf(maximum_slide, delta_position)
			if foot.swing:
				swings += 1
			else:
				var expected: Dictionary = animal.gait.ground_at(foot.position)
				maximum_ground_error = maxf(maximum_ground_error, absf(Vector3(foot.position).y - Vector3(expected.position).y))
			var visible_sole: Vector3 = animal.model.limb_parts[index].Foot.global_position
			maximum_visual_error = maxf(maximum_visual_error, visible_sole.distance_to(foot.position))
			if before[index].swing and not foot.swing:
				landings[index] += 1
		maximum_swings = maxi(maximum_swings, swings)
		if frame % 120 == 0:
			await process_frame
	check(maximum_slide < 0.0001, "planted soles stay at a fixed world coordinate over multiple steps and turns")
	check(maximum_swings == 1 and landings[0] > 3 and landings[1] > 3 and landings[2] > 3, "all three limbs cycle with at most one airborne foot")
	check(maximum_step < 0.23, "turns, rest and restart never teleport a sole")
	check(maximum_ground_error < 0.09 and maximum_visual_error < 0.002, "each visible sole follows its own actual terrain contact")
	check(maximum_body_step < 0.032 and normal_speed_reached, "body motion is continuous and retains the 0.75 m/s walking scale")
	check(heading_change > 0.35, "fixture naturally reaches and turns at a patrol waypoint")
	check(seen.has("settling") and seen.has("rest") and seen.has("rising") and minimum_warning >= 4.9, "normal patrol decelerates for five seconds before lowering and restarts")
	check(stopped_stamps, "resting feet create no repeated sand bursts and old sand expires")
	var age_before: float = animal.age
	var feet_before: Array = animal.gait.feet.duplicate(true)
	var sail_before: Transform3D = animal.model.sail.transform
	paused = true
	animal.tick(3.0, diver, school)
	check(animal.age == age_before and animal.gait.feet == feet_before and animal.model.sail.transform == sail_before, "paused biology leaves contacts, body and sail time unchanged")
	paused = false
	animal.tick(0.0, diver, school)
	check(animal.age == age_before and animal.gait.feet == feet_before, "zero delta has no gait side effects")
	print("HOGARA_CONTACT_METRICS slide=", maximum_slide, " ground_error=", maximum_ground_error, " foot_step=", maximum_step, " body_step=", maximum_body_step, " landings=", landings)

func swim_to(body: CharacterBody3D, destination: Vector3) -> void:
	for _step in 120:
		var motion := destination - body.global_position
		if motion.length() < 0.015:
			return
		body.move_and_collide(motion.limit_length(0.06))

func passage_dimensions() -> void:
	current_case = "real diver and hard mouth through visible openings"
	await reset_animal()
	var open_gaps := 0
	var blocked_mouths := 0
	var clear_returns := 0
	for gap: Dictionary in animal.model.get_exit_gaps():
		var inside: Vector3 = animal.model.to_global(gap.inside)
		var outside: Vector3 = animal.model.to_global(gap.outside)
		diver.relocate(outside, false)
		swim_to(diver, inside)
		if diver.global_position.distance_to(inside) < 0.08:
			open_gaps += 1
			swim_to(diver, outside)
			if diver.global_position.distance_to(outside) < 0.08:
				clear_returns += 1
			mouth.global_position = outside
			swim_to(mouth, inside)
			if mouth.global_position.distance_to(inside) > 0.35:
				blocked_mouths += 1
		mouth.global_position = Vector3(80, -10, 0)
	check(open_gaps >= 4 and clear_returns == open_gaps, "multiple visible gaps allow the real 0.6 m diver in and back out")
	check(blocked_mouths == open_gaps, "the same hard meshes block every tested 1.4 m mouth")
	check(diver.get_parent() == scene, "shelter never reparents the diver or camera")
	print("HOGARA_PASSAGE_METRICS open_gaps=", open_gaps, " returns=", clear_returns, " blocked_mouths=", blocked_mouths)

func rest_from_multiple_positions() -> void:
	current_case = "actual collision motion from centre, sides and corners"
	var positions: Array[Vector3] = [Vector3(0, 1.7, 0), Vector3(2.45, 1.7, 0.85), Vector3(-2.45, 1.7, -0.85), Vector3(2.35, 1.7, 2.65), Vector3(-2.35, 1.7, -2.65), Vector3(1.7, 1.7, 2.75)]
	for start in positions:
		await reset_animal()
		diver.relocate(animal.model.to_global(start), false)
		animal._begin_warning()
		var maximum_motion := 0.0
		var lowered_under_player := false
		# Five warning seconds + eight seconds to leave + two to settle.
		for _step in 640:
			var previous := diver.global_position
			animal.tick(0.025, diver, school)
			maximum_motion = maxf(maximum_motion, diver.global_position.distance_to(previous))
			if animal.rest_amount > 0.0 and animal._under_roof(diver.global_position):
				lowered_under_player = true
			if animal.state == "rest":
				break
			await physics_frame
		check(animal.state == "rest" and not animal._under_roof(diver.global_position), "visible-gap exit reaches safety before rest from " + str(start))
		check(not lowered_under_player and maximum_motion < 0.045, "exit remains collision-based without roof lowering or teleport from " + str(start))

func blocked_exit_cancels() -> void:
	current_case = "blocked exit timeout / reversible rest / input priority"
	await reset_animal()
	diver.relocate(animal.model.to_global(Vector3(0, 1.7, 0)), false)
	var blockers: Array[StaticBody3D] = []
	for entry in [[Vector3(-4.0, 1.8, 0), Vector3(0.3, 5.5, 10)], [Vector3(4.0, 1.8, 0), Vector3(0.3, 5.5, 10)], [Vector3(0, 1.8, -4.5), Vector3(9, 5.5, 0.3)], [Vector3(0, 1.8, 4.5), Vector3(9, 5.5, 0.3)]]:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = entry[1]
		shape.shape = box
		body.add_child(shape)
		scene.add_child(body)
		body.global_transform = Transform3D(animal.model.global_basis, animal.model.to_global(entry[0]))
		blockers.append(body)
	await frames()
	var before := diver.global_position
	animal._begin_warning()
	for _step in 545:
		animal.tick(0.025, diver, school)
		await physics_frame
	check(animal.rest_cancelled_count == 1 and animal.state == "stand" and animal.rest_amount == 0.0, "all blocked openings cancel rest after the bounded warning, retaining a high roof")
	check(diver.global_position.distance_to(before) < 0.1 and animal._under_roof(diver.global_position), "timeout does not force-eject or teleport the trapped fixture")
	for body in blockers:
		body.queue_free()
	await frames()
	for _step in 120:
		animal.tick(0.025, diver, school)
	check(animal.state == "walk" and animal._rest_retry > 15.0, "cancelled rest resumes safely with a retry cooldown")
	await reset_animal()
	diver.relocate(animal.model.to_global(Vector3(0, 1.7, 0)), false)
	animal._begin_warning()
	animal.state_time = 3.0
	before = diver.global_position
	Input.action_press("left")
	animal.tick(0.2, diver, school)
	Input.action_release("left")
	check(diver.global_position.distance_to(before) < 0.001, "own swim input overrides automatic exit assistance")
	animal.state = "settling"
	animal.rest_amount = 0.2
	animal.tick(0.025, diver, school)
	check(animal.state == "stand" and animal.rest_amount <= 0.2, "returning under a lowering roof immediately reverses the rest transition")
