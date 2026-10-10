extends SceneTree
## Production terrain and actual diver collision; initial route starts are fixtures.
const World = preload("res://scripts/world/sea_world.gd")
const Map = preload("res://data/biomes/world_map.gd")
const Diver = preload("res://scripts/player/diver.gd")
var scene: Node3D
var world: Node3D
var diver: CharacterBody3D
var checks := 0
var failures: Array[String] = []
var started := 0

func _initialize() -> void:
	started = Time.get_ticks_msec()
	call_deferred("run")

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started > 100000:
		printerr("M2_WORLD_FAIL timeout")
		quit(1)
	return false

func check(passed: bool, description: String) -> void:
	checks += 1
	if not passed:
		failures.append(description)
		printerr("M2_WORLD_FAIL ", description)

func run() -> void:
	load("res://scripts/player/controls.gd").install()
	scene = Node3D.new()
	root.add_child(scene)
	world = World.new()
	scene.add_child(world)
	diver = Diver.new()
	scene.add_child(diver)
	await physics_frame
	await physics_frame
	legacy_and_boundaries()
	terrain_and_interior()
	for id: String in Map.ROUTES:
		var points := Map.route(id, world)
		diver.relocate(points[0], false)
		await physics_frame
		check(swim(diver, points, id), "actual diver reaches end of " + id)
		points.reverse()
		check(swim(diver, points, id + " reverse"), "actual diver reverses " + id)
	relay_protection()
	await speed_and_reset()
	scene.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("M2_WORLD_OK checks=", checks)
		quit(0)
	else:
		printerr("M2_WORLD_FAIL failures=", failures.size(), " checks=", checks)
		quit(1)

func legacy_and_boundaries() -> void:
	# Golden M1.5 samples, including its existing reef slope (not regenerated data).
	var samples := [Vector3(0, -16.1630994096, -20), Vector3(18, -28.7417496663, -80), Vector3(0, -41.8387533835, -130), Vector3(100, -20.6289016524, -80), Vector3(-11, -22.8281889083, -57)]
	var legacy_ok := true
	for sample in samples:
		legacy_ok = legacy_ok and absf(world.floor_height(sample.x, sample.z) - sample.y) < 0.00001
	check(legacy_ok, "M1 terrain, shelter route and wreck floor keep their captured heights")
	check(absf(world.floor_height(0, -150.01) - world.floor_height(0, -149.99)) < 0.04, "old southern boundary joins continuously")
	check(Map.current_at(Vector3(0, -60, -180)) == Vector3.ZERO and Map.current_at(Vector3(25, -140, -365)) == Vector3.ZERO, "old southern boundary does not push back M2 swimmers")
	check(Map.current_at(Vector3(148, -40, -220)).x < 0 and Map.current_at(Vector3(-148, -80, -455)).z > 0, "new boundary flow points into the expanded map")
	check(Map.name_at(Vector3(0, -65, -195)) == "白濁の平原" and Map.name_at(Vector3(25, -140, -365)) == "殻の墓場", "shared biome ranges identify both new areas")
	check(Map.is_valid_buoy(Vector3(25, -180, -430)) and not Map.is_valid_buoy(Vector3(151, -50, -200)) and not Map.is_valid_buoy(Vector3(INF, 0, 0)), "buoy validation includes new regions and rejects invalid coordinates")
	var water := world.get_node("BreathableWaterSurface") as MeshInstance3D
	var plane := water.mesh as PlaneMesh
	check(water.position.z - plane.size.y * 0.5 <= Map.MAP_MIN.y and water.position.z + plane.size.y * 0.5 >= Map.MAP_MAX.y, "visible water covers both new map boundaries")
	check(diver.camera.far >= Map.MAP_MAX.y - Map.MAP_MIN.y, "camera range covers the connected map")

func terrain_and_interior() -> void:
	var maximum_error := 0.0
	for xz in [Vector2(0, -161), Vector2(0, -181), Vector2(-34, -219), Vector2(12, -252), Vector2(48, -296), Vector2(25, -322), Vector2(25, -364), Vector2(46, -388), Vector2(0, -429)]:
		var bed: float = world.floor_height(xz.x, xz.y)
		var query := PhysicsRayQueryParameters3D.create(Vector3(xz.x, bed + 0.7, xz.y), Vector3(xz.x, bed - 1, xz.y), 1)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			maximum_error = INF
		else:
			maximum_error = maxf(maximum_error, absf(hit.position.y - bed))
	check(maximum_error < 0.18, "M2 floor height agrees with actual seabed triangles")
	var interior := Map.point("phase_regulator", world) + Vector3.UP * 1.0
	var ceiling_ray := PhysicsRayQueryParameters3D.create(interior, interior + Vector3.UP * 14, 1)
	var ceiling := world.get_world_3d().direct_space_state.intersect_ray(ceiling_ray)
	check(not ceiling.is_empty() and String(ceiling.collider.name).begins_with("GreatEmptyShell"), "great shell has a real ceiling above its empty interior")
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, interior)
	query.collision_mask = 1
	check(world.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "one oversized solid does not fill the shell interior")
	print("M2_WORLD_TERRAIN max_floor_error=", maximum_error)

func swim(body: CharacterBody3D, points: Array[Vector3], label: String) -> bool:
	for destination in points:
		var budget := ceili(body.global_position.distance_to(destination) / 0.12) + 30
		for _step in budget:
			var remaining := destination - body.global_position
			if remaining.length() < 0.012:
				break
			var collision := body.move_and_collide(remaining.limit_length(0.12))
			if collision != null and body.global_position.distance_to(destination) > 0.05:
				printerr("M2_WORLD_ROUTE_BLOCKED ", label, " at=", body.global_position, " target=", destination, " collider=", collision.get_collider().name)
				return false
		if body.global_position.distance_to(destination) > 0.05:
			return false
	return true

func relay_protection() -> void:
	var point := Map.point("relay", world)
	var mouth := CharacterBody3D.new()
	mouth.collision_layer = 4
	mouth.collision_mask = 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	shape.shape = sphere
	mouth.add_child(shape)
	scene.add_child(mouth)
	mouth.global_position = point + Vector3(0, 0, 6)
	for _step in 70:
		mouth.move_and_collide((point - mouth.global_position).limit_length(0.12))
	check(mouth.global_position.distance_to(point) > 3.0, "visible relay doorway physically obstructs the hard predator mouth")
	mouth.queue_free()

func speed_and_reset() -> void:
	diver.relocate(Vector3(0, -25, -200), false)
	diver.active = true
	diver.external_speed_scale = 0.55
	Input.action_press("forward")
	for _step in 90:
		diver._physics_process(1.0 / 60.0)
	check(absf(diver.velocity.length() - 2.8 * 0.55) < 0.01, "external net speed scale is applied once to normal swimming")
	diver.relocate(Vector3(0, -25, -200), false)
	check(diver.external_speed_scale == 1.0 and diver.velocity == Vector3.ZERO, "relocation releases net slowdown and previous input")
	diver.active = false
	await physics_frame
