extends Node3D
## Only ecosystem.tick advances movement, articulated contacts, and footfall sand.
const Gait = preload("res://scripts/creatures/hogara_gait.gd")
const Model = preload("res://scripts/creatures/hogara_model.gd")
signal event_started(event_id: String)
signal footfall(index: int, at: Vector3, strength: float)
const WALK_SPEED := 0.75
const REST_LOWERING := 0.55
const EXIT_TIMEOUT := 8.0
var species_id := "hogara"
var behavior_event := "feeding"
var state := "walk"
var state_time := 0.0
var age := 0.0
var route_index := 1
var route: Array[Vector3] = []
var world: Node3D
var canopy := Node3D.new()
var model: Node3D
var gait = Gait.new()
var rest_warning_seconds := 5.0
var speed := 0.0
var rest_amount := 0.0
var warning_amount := 0.0
var rest_cancelled_count := 0
var low_particles := false
var collision_parts: Array[Dictionary] = []
var foot_dust: Array[Dictionary] = []
var _dust_mesh: SphereMesh
var _dust_material: StandardMaterial3D
var _rest_retry := 0.0
var _warning_start_speed := WALK_SPEED
var _last_velocity := Vector3.ZERO
var _acceleration := Vector3.ZERO
var _exit_path: Array[Vector3] = []
var _exit_gap := -1
var _exit_replan := 0.0
var _blocked_exits: Array[int] = []
var _safety_shape := SphereShape3D.new()

func setup(terrain: Node3D) -> void:
	world = terrain
	for point in [Vector2(10, -58), Vector2(18, -76), Vector2(18, -97), Vector2(12, -108), Vector2(18, -97), Vector2(18, -76)]:
		route.append(Vector3(point.x, float(world.floor_height(point.x, point.y)), point.y))
	position = route[0]
	var direction := route[1] - route[0]
	rotation.y = atan2(-direction.x, -direction.z)
	canopy.name = "WeightBearingBody"
	add_child(canopy)
	model = Model.new()
	canopy.add_child(model)
	model.build()
	gait.setup(self, world, model.get_hip_positions(), model.get_rest_feet())
	_apply_support_pose(1.0, true)
	gait.apply_limbs(model)
	_build_collisions()
	_build_dust_resources()
	_safety_shape.radius = 0.31

func observation_position() -> Vector3:
	return model.to_global(Vector3(0, 3.6, 0))

func contains(point: Vector3) -> bool:
	var p := model.to_local(point)
	return state not in ["rest", "settling"] and absf(p.x) < 2.8 and absf(p.z) < 3.0 and p.y > 0.65 and p.y < 2.65

func _under_roof(point: Vector3) -> bool:
	var p := model.to_local(point)
	# Actual roof extents plus diver radius: outer-rib swimmers must also clear it.
	return absf(p.x) < 4.0 and absf(p.z) < 4.5 and p.y > -0.35 and p.y < 3.6

func tick(delta: float, player: CharacterBody3D, school: Vector3) -> void:
	if delta <= 0.0 or not is_inside_tree() or get_tree().paused:
		return
	var remaining := delta
	while remaining > 0.00001:
		var step := minf(remaining, 0.05)
		_tick_step(step, player, school)
		remaining -= step

func _tick_step(delta: float, player: CharacterBody3D, school: Vector3) -> void:
	age += delta
	state_time += delta
	_rest_retry = maxf(0.0, _rest_retry - delta)
	_exit_replan = maxf(0.0, _exit_replan - delta)
	var previous_transform := transform
	var previous_canopy := canopy.transform
	var old_position := global_position
	_update_state(delta, player)
	_move_body(delta, school)
	var velocity := (global_position - old_position) / delta
	_acceleration = _acceleration.lerp((velocity - _last_velocity) / delta, minf(1.0, delta * 2.0))
	_last_velocity = velocity
	gait.advance(delta, velocity, state in ["walk", "rest_warning", "rising", "stand"], player.global_position)
	_apply_support_pose(delta)
	model.tick_visual(delta, age, rest_amount, warning_amount, _acceleration)
	gait.apply_limbs(model)
	_sync_collisions()
	# Hold moving ribs/roof if they would sweep into an idle swimmer. Sole world
	# positions remain unchanged, and the player retains their own movement.
	if player.global_position.distance_to(global_position) < 7.0 and _touches_diver(player):
		transform = previous_transform
		canopy.transform = previous_canopy
		speed = 0.0
		_last_velocity = Vector3.ZERO
		gait.apply_limbs(model)
		_sync_collisions()
	for contact in gait.landings:
		_spawn_foot_dust(contact.position, contact.normal)
		footfall.emit(contact.index, contact.position, contact.strength)
	_update_dust(delta)
	if state == "rest_warning" and state_time >= 2.0 and (_under_roof(player.global_position) or not _exit_path.is_empty()):
		_ease_out(player, delta)
	behavior_event = "rest_warning" if state == "rest_warning" else ("shelter" if contains(player.global_position) else "feeding")

func _update_state(delta: float, player: CharacterBody3D) -> void:
	match state:
		"walk":
			warning_amount = move_toward(warning_amount, 0.0, delta)
			var target: Vector3 = route[route_index]
			if Vector2(position.x - target.x, position.z - target.z).length() < 2.0:
				if _rest_retry <= 0.0:
					_begin_warning()
				else:
					route_index = (route_index + 1) % route.size()
		"rest_warning":
			warning_amount = smoothstep(0.0, rest_warning_seconds, state_time)
			if state_time >= rest_warning_seconds + EXIT_TIMEOUT:
				_cancel_rest()
			elif state_time >= rest_warning_seconds and not _under_roof(player.global_position) and _exit_path.is_empty() and gait.swing_index < 0:
				_enter("settling")
		"settling":
			if _under_roof(player.global_position):
				_cancel_rest()
			else:
				rest_amount = move_toward(rest_amount, 1.0, delta * 0.5)
				if rest_amount >= 1.0:
					_enter("rest")
		"rest":
			if _under_roof(player.global_position) or state_time >= 7.0:
				_enter("rising")
		"rising":
			rest_amount = move_toward(rest_amount, 0.0, delta * 0.5)
			warning_amount = move_toward(warning_amount, 0.0, delta * 0.5)
			if rest_amount <= 0.0 and state_time >= 2.0:
				_enter("walk")
		"stand":
			rest_amount = move_toward(rest_amount, 0.0, delta * 0.6)
			warning_amount = move_toward(warning_amount, 0.0, delta * 0.5)
			if state_time >= 2.0 and rest_amount <= 0.0:
				_enter("walk")

func _begin_warning() -> void:
	_warning_start_speed = maxf(0.1, speed)
	_enter("rest_warning")
	_exit_path.clear()
	_blocked_exits.clear()
	event_started.emit("rest_warning")

func _cancel_rest() -> void:
	rest_cancelled_count += 1
	_rest_retry = 22.0
	if state == "rest_warning":
		route_index = (route_index + 1) % route.size()
	_enter("stand")
	_exit_path.clear()
	event_started.emit("rest_cancelled")

func _enter(next_state: String) -> void:
	if next_state == "settling":
		route_index = (route_index + 1) % route.size()
	state = next_state
	state_time = 0.0

func _move_body(delta: float, school: Vector3) -> void:
	var target: Vector3 = route[route_index]
	if state == "walk" and global_position.distance_to(school) < 8.0:
		target.x += clampf(school.x - target.x, -0.5, 0.5)
	var horizontal := Vector3(target.x - position.x, 0, target.z - position.z)
	var desired_speed := 0.0
	if state == "walk":
		desired_speed = WALK_SPEED
	elif state == "rest_warning":
		desired_speed = _warning_start_speed * (1.0 - smoothstep(0.0, rest_warning_seconds, state_time))
	if horizontal.length() < 0.15:
		desired_speed = 0.0
	if horizontal.length_squared() > 0.02 and state in ["walk", "rising"]:
		var heading := atan2(-horizontal.x, -horizontal.z)
		var heading_error := absf(angle_difference(rotation.y, heading))
		rotation.y = rotate_toward(rotation.y, heading, delta * 0.16 * maxf(0.2, gait.motion_scale()))
		desired_speed *= lerpf(1.0, 0.12, smoothstep(0.4, 1.8, heading_error))
	desired_speed *= gait.motion_scale()
	speed = move_toward(speed, desired_speed, delta * 0.34)
	if horizontal.length() > 0.01 and speed > 0.001:
		position += horizontal.normalized() * minf(horizontal.length(), speed * delta)
		position.y = world.floor_height(position.x, position.z)

func _apply_support_pose(delta: float, initial: bool = false) -> void:
	var support: Dictionary = gait.support_pose()
	var local_normal := (global_basis.inverse() * Vector3(support.normal)).normalized()
	var axis := Vector3.UP.cross(local_normal)
	var slope := Basis.IDENTITY
	if axis.length_squared() > 0.000001:
		slope = Basis(axis.normalized(), acos(clampf(local_normal.y, -1.0, 1.0)))
	var local_shift := global_basis.inverse() * Vector3(support.shift)
	var desired_position := Vector3(local_shift.x, clampf(float(support.height) - global_position.y, -0.3, 0.3) + float(support.lift) - REST_LOWERING * rest_amount, local_shift.z)
	var weight := 1.0 if initial else 1.0 - exp(-delta * 3.0)
	canopy.position = canopy.position.lerp(desired_position, weight)
	canopy.quaternion = canopy.quaternion.slerp(slope.get_rotation_quaternion(), weight)

func _build_collisions() -> void:
	for mesh: MeshInstance3D in model.get_collision_meshes():
		var body := StaticBody3D.new()
		body.name = "Hard_" + mesh.name
		body.collision_layer = 8
		body.collision_mask = 0
		body.top_level = true
		add_child(body)
		var shape := CollisionShape3D.new()
		# Flared rib roots must not turn their concave openings into invisible
		# convex walls. Static triangle shapes retain the visible passage width.
		# Every shape is built once; only its transform changes during biology.
		shape.shape = mesh.mesh.create_trimesh_shape() if String(mesh.name).begins_with("Rib") else mesh.mesh.create_convex_shape(true, true)
		body.add_child(shape)
		collision_parts.append({"mesh": mesh, "body": body})
	_sync_collisions()

func _sync_collisions() -> void:
	for part in collision_parts:
		part.body.global_transform = part.mesh.global_transform

func _touches_diver(player: CharacterBody3D) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _safety_shape
	query.transform = Transform3D(Basis.IDENTITY, player.global_position)
	query.collision_mask = 8
	query.margin = 0.005
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 12):
		for part in collision_parts:
			if hit.collider == part.body:
				return true
	return false

func _ease_out(player: CharacterBody3D, delta: float) -> void:
	for action in ["forward", "back", "left", "right", "ascend", "descend"]:
		if Input.is_action_pressed(action):
			_exit_path.clear()
			return
	if _exit_path.is_empty() and _exit_replan <= 0.0:
		_plan_exit(player)
	if _exit_path.is_empty():
		return
	var destination := model.to_global(_exit_path[0])
	var before := player.global_position
	var collision := player.move_and_collide((destination - before).limit_length(delta * 1.35))
	if player.global_position.distance_to(destination) < 0.012:
		_exit_path.pop_front()
	elif collision != null and player.global_position.distance_to(before) < delta * 0.15:
		if not _blocked_exits.has(_exit_gap):
			_blocked_exits.append(_exit_gap)
		_exit_path.clear()
		_exit_replan = 0.3

func _plan_exit(player: CharacterBody3D) -> void:
	_exit_replan = 0.4
	var from := model.to_local(player.global_position)
	var height := clampf(from.y, 1.3, 2.0)
	var gaps: Array = model.get_exit_gaps()
	var best_length := INF
	for index in gaps.size():
		if _blocked_exits.has(index):
			continue
		var inside: Vector3 = gaps[index].inside
		var outside: Vector3 = gaps[index].outside
		inside.y = height
		outside.y = height
		var middle := Vector3(clampf(from.x, -2.25, 2.25), height, clampf(from.z, -2.6, 2.6))
		var alternatives: Array = [[inside, outside], [middle, inside, outside], [Vector3(0, height, 0), inside, outside]]
		for path: Array in alternatives:
			var previous := player.global_position
			var length := 0.0
			var clear := true
			for point: Vector3 in path:
				var next := model.to_global(point)
				if not _exit_segment_clear(player, previous, next):
					clear = false
					break
				length += previous.distance_to(next)
				previous = next
			if clear and length < best_length:
				best_length = length
				_exit_gap = index
				_exit_path.assign(path)

func _exit_segment_clear(player: CharacterBody3D, from: Vector3, to: Vector3) -> bool:
	if player.test_move(Transform3D(player.global_basis, from), to - from, null, 0.012):
		return false
	# A long sweep can miss a narrow, scaled rib. Reserve the whole diver volume
	# along the proposed corridor before committing to that visible opening.
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _safety_shape
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	query.margin = 0.012
	var steps := maxi(1, ceili(from.distance_to(to) / 0.16))
	for step in range(1, steps + 1):
		query.transform = Transform3D(Basis.IDENTITY, from.lerp(to, float(step) / steps))
		if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return false
	return true

func set_low_particles(low: bool) -> void:
	low_particles = low
	for burst in foot_dust:
		burst.mesh.multimesh.visible_instance_count = 6 if low else 18

func _build_dust_resources() -> void:
	_dust_mesh = SphereMesh.new()
	_dust_mesh.radius = 1.0
	_dust_mesh.height = 2.0
	_dust_mesh.radial_segments = 5
	_dust_mesh.rings = 3
	_dust_material = StandardMaterial3D.new()
	_dust_material.albedo_color = Color(0.64, 0.58, 0.44, 0.22)
	_dust_material.vertex_color_use_as_albedo = true
	_dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dust_material.roughness = 1.0
	_dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func _spawn_foot_dust(at: Vector3, normal: Vector3) -> void:
	if foot_dust.size() >= 4:
		return
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = _dust_mesh
	instances.instance_count = 18
	instances.visible_instance_count = 6 if low_particles else 18
	var mesh := MultiMeshInstance3D.new()
	mesh.name = "ContactSandOnly"
	mesh.multimesh = instances
	mesh.material_override = _dust_material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.top_level = true
	add_child(mesh)
	var up := normal.normalized()
	var tangent := global_basis.x.slide(up).normalized()
	if tangent.length_squared() < 0.01:
		tangent = Vector3.FORWARD.slide(up).normalized()
	# Burst coordinates lie on this foot's contact plane, including sloping beds.
	mesh.global_transform = Transform3D(Basis(tangent, up, tangent.cross(up).normalized()), at + up * 0.035)
	foot_dust.append({"mesh": mesh, "time": 0.0, "phase": float(gait.footfall_count) * 1.73})

func _update_dust(delta: float) -> void:
	for index in range(foot_dust.size() - 1, -1, -1):
		var burst: Dictionary = foot_dust[index]
		burst.time += delta
		if burst.time >= 2.6:
			burst.mesh.queue_free()
			foot_dust.remove_at(index)
			continue
		var t: float = burst.time
		for grain in 18:
			var angle: float = grain * 2.399 + burst.phase
			# Sparse sand escapes around the broad sole instead of inside its mesh.
			var radius := 0.90 + float(grain % 5) * 0.05 + (1.0 - exp(-t * 1.6)) * 0.15
			var at := Vector3(cos(angle) * radius, 0.04 + sin(t / 2.6 * PI) * (0.1 + grain % 3 * 0.02), sin(angle) * radius)
			var scale := 0.025 + (grain % 4) * 0.011 + t * 0.008
			burst.mesh.multimesh.set_instance_transform(grain, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), at))
			burst.mesh.multimesh.set_instance_color(grain, Color(1, 1, 1, (1.0 - t / 2.6) * 0.8))
