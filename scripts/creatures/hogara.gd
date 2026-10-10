extends Node3D

const Art = preload("res://scripts/creatures/creature_mesh.gd")
signal event_started(event_id: String)
var species_id: String = "hogara"
var behavior_event: String = "feeding"
var state: String = "walk"
var state_time: float = 0.0
var age: float = 0.0
var route_index: int = 1
var route: Array[Vector3] = []
var world: Node3D
var legs: Array[Node3D] = []
var filters: Array[Node3D] = []
var canopy := Node3D.new()
var vein_material: StandardMaterial3D
var rest_warning_seconds: float = 5.0
var warning_sent: bool = false

func setup(terrain: Node3D) -> void:
	world = terrain
	for point in [Vector2(10, -58), Vector2(18, -76), Vector2(18, -97), Vector2(12, -108), Vector2(18, -97), Vector2(18, -76)]:
		route.append(Vector3(point.x, float(world.floor_height(point.x, point.y)), point.y))
	position = route[0]
	_build_model()

func observation_position() -> Vector3:
	return global_position + Vector3.UP * 3.6

func contains(point: Vector3) -> bool:
	var p := to_local(point)
	return state != "rest" and absf(p.x) < 2.8 and absf(p.z) < 3.0 and p.y > 0.65 and p.y < 2.95

func _under_roof(point: Vector3) -> bool:
	var p := to_local(point)
	return absf(p.x) < 3.95 and absf(p.z) < 4.4 and p.y > 0.35 and p.y < 3.2

func tick(delta: float, player: CharacterBody3D, school: Vector3) -> void:
	age += delta
	state_time += delta
	if state == "walk":
		var target: Vector3 = route[route_index]
		if global_position.distance_to(school) < 8.0:
			target.x += clampf(school.x - target.x, -0.5, 0.5)
		var flat_target := Vector3(target.x, position.y, target.z)
		position = position.move_toward(flat_target, delta * 0.75)
		position.y = float(world.floor_height(position.x, position.z))
		behavior_event = "shelter" if contains(player.global_position) else "feeding"
		if position.distance_to(target) < 0.6:
			route_index = (route_index + 1) % route.size()
			state = "rest_warning"
			state_time = 0.0
			behavior_event = "rest_warning"
			event_started.emit("rest_warning")
	elif state == "rest_warning":
		behavior_event = "rest_warning"
		if state_time > 2.0 and _under_roof(player.global_position):
			_ease_out(player, delta)
		# Keep the roof high until the player has safely cleared the actual passage.
		if state_time >= rest_warning_seconds and not _under_roof(player.global_position):
			state = "rest"
			state_time = 0.0
	elif state == "rest":
		behavior_event = "feeding"
		if state_time > 7.0:
			state = "walk"
			state_time = 0.0
	var rest_blend := clampf(state_time / 2.0, 0.0, 1.0) if state == "rest" else 0.0
	canopy.position.y = lerpf(canopy.position.y, -1.25 * rest_blend, delta * 2.0)
	vein_material.emission_energy_multiplier = 0.12 if state == "rest_warning" else (0.3 if state == "rest" else 0.8)
	for i in legs.size():
		legs[i].rotation.z = sin(age * 2.0 + i * TAU / 3.0) * (0.035 if state == "walk" else 0.008)
	for i in filters.size():
		filters[i].rotation.z = sin(age * 1.2 + i * 0.43) * 0.13

func _ease_out(player: CharacterBody3D, delta: float) -> void:
	var local := to_local(player.global_position)
	var side := 1.0 if local.x >= 0.0 else -1.0
	var exit_local := Vector3(side * 4.8, maxf(local.y, 1.1), 0.85)
	# First line up with the visible 1.1 m gap, then guide gently through it.
	if absf(local.z - 0.85) > 0.2 and absf(local.x) < 2.9:
		exit_local.x = local.x
	var destination := to_global(exit_local)
	player.move_and_collide((destination - player.global_position).limit_length(delta * 2.2))

func _build_model() -> void:
	var bone := Art.material(Color("537e70"))
	var leg_bone := Art.material(Color("b1a386"))
	var shadow := Art.material(Color("284c49"))
	var sail := Art.material(Color(0.40, 0.75, 0.76, 0.53), 0.1, true)
	vein_material = Art.material(Color("c2eef1"), 0.8)
	add_child(canopy)
	# The roof and outer posts are physical. All gaps are 1.1 m, the player is 0.6 m,
	# while the predator's hard mouth is 1.4 m. No invisible shelter collision volume.
	Art.colliding_ellipsoid(canopy, Vector3(0, 3.48, 0), Vector3(7.3, 1.05, 8.3), bone)
	for side in [-1.0, 1.0]:
		for z in [-3.4, -1.7, 0.0, 1.7, 3.4]:
			Art.colliding_capsule(self, Vector3(side * 3.4, 1.95, z), 2.7, 0.3, shadow)
			Art.ellipsoid(canopy, Vector3(side * 3.1, 3.23, z * 0.87), Vector3(0.9, 0.56, 1.1), bone)
		for x in [-2.55, -0.85, 0.85, 2.55]:
			Art.colliding_capsule(self, Vector3(x, 1.95, side * 3.95), 2.7, 0.3, shadow)
			Art.rod(canopy, Vector3(x, 3.3, side * 3.95), Vector3(x * 0.8, 3.9, side * 3.0), 0.1, bone)
	# Three weight-bearing limbs give the silhouette its asymmetric gait.
	for foot in [Vector3(-4.0, 0.25, -2.7), Vector3(4.0, 0.25, -2.7), Vector3(0, 0.25, 4.5)]:
		var pivot := Node3D.new()
		add_child(pivot)
		var knee: Vector3 = foot * Vector3(0.85, 1, 0.8) + Vector3.UP * 1.2
		Art.rod(pivot, foot, knee, 0.34, leg_bone, 0.47)
		Art.rod(pivot, knee, Vector3(foot.x * 0.6, 3.4, foot.z * 0.6), 0.47, leg_bone, 0.28)
		Art.ellipsoid(pivot, foot, Vector3(0.95, 0.42, 1.1), leg_bone)
		legs.append(pivot)
	# A ridged, chipped fan rather than an ellipsoid shell.
	var fan_points: Array[Vector3] = [Vector3(-3.35, 3.7, 2.9), Vector3(-3.0, 5.3, 1.8), Vector3(-2.15, 6.5, 0.5), Vector3(-1.1, 7.1, -0.3), Vector3(0, 7.55, -0.7), Vector3(0.8, 6.6, -0.3), Vector3(1.15, 7.0, -0.2), Vector3(2.2, 6.25, 0.6), Vector3(3.1, 5.15, 1.9), Vector3(3.35, 3.7, 2.9)]
	var root := Vector3(0, 3.6, -3.3)
	for i in fan_points.size() - 1:
		Art.triangle(canopy, root, fan_points[i], fan_points[i + 1], sail)
		Art.rod(canopy, root, fan_points[i], 0.047, vein_material, 0.022)
		Art.rod(canopy, fan_points[i], fan_points[i + 1], 0.065, bone)
	for i in 18:
		var organ := Node3D.new()
		organ.position = Vector3(sin(i * 2.4) * 2.1, 3.0, cos(i * 2.4) * 2.5)
		canopy.add_child(organ)
		Art.rod(organ, Vector3.ZERO, Vector3(0.12, -0.55, 0), 0.035, bone, 0.008)
		for j in 4:
			Art.rod(organ, Vector3(0.06, -0.18 - j * 0.08, 0), Vector3(0.22, -0.35 - j * 0.08, 0.10), 0.022, bone, 0.005)
		filters.append(organ)
