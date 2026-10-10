extends RefCounted
## Tripod gait advanced only by ecosystem delta. Planted soles are world positions.
const SWING_SECONDS := 0.95
const STEP_HEIGHT := 0.32
const STEP_THRESHOLD := 0.62
const UPPER_LENGTH := 2.35
const LOWER_LENGTH := 2.25
var owner: Node3D
var world: Node3D
var feet: Array[Dictionary] = []
var hips: Array[Vector3] = []
var rest_feet: Array[Vector3] = []
var swing_index := -1
var next_leg := 0
var landings: Array[Dictionary] = []
var footfall_count := 0
var elapsed := 0.0

func setup(animal: Node3D, terrain: Node3D, hip_positions: Array[Vector3], neutral_feet: Array[Vector3]) -> void:
	owner = animal
	world = terrain
	hips = hip_positions.duplicate()
	rest_feet = neutral_feet.duplicate()
	feet.clear()
	for local_foot in rest_feet:
		var contact := ground_at(owner.to_global(local_foot))
		feet.append({"position": contact.position, "planted": contact.position, "start": contact.position, "target": contact.position, "normal": contact.normal, "target_normal": contact.normal, "progress": 0.0, "swing": false, "stance_seconds": 0.0})

func ground_at(point: Vector3) -> Dictionary:
	var height: float = world.floor_height(point.x, point.z)
	var at := Vector3(point.x, height + 0.012, point.z)
	var dx: float = world.floor_height(point.x - 0.15, point.z) - world.floor_height(point.x + 0.15, point.z)
	var dz: float = world.floor_height(point.x, point.z - 0.15) - world.floor_height(point.x, point.z + 0.15)
	var normal := Vector3(dx, 0.3, dz).normalized()
	# Before a fresh world's first physics frame the same analytic bed is fallback.
	if owner.is_inside_tree():
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, height + 2.0, point.z), Vector3(point.x, height - 2.0, point.z), 1)
		var hit := owner.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.normal.y > 0.65:
			at = hit.position + Vector3.UP * 0.012
			normal = hit.normal
	return {"position": at, "normal": normal}

func advance(delta: float, velocity: Vector3, allow_steps: bool, player_position: Vector3) -> void:
	if delta <= 0.0:
		return
	elapsed += delta
	landings.clear()
	for foot in feet:
		if not foot.swing:
			foot.stance_seconds += delta
	if swing_index >= 0:
		var foot: Dictionary = feet[swing_index]
		foot.progress = minf(1.0, float(foot.progress) + delta / SWING_SECONDS)
		var t: float = foot.progress
		var smooth := t * t * (3.0 - 2.0 * t)
		foot.position = Vector3(foot.start).lerp(foot.target, smooth) + Vector3.UP * sin(t * PI) * STEP_HEIGHT
		foot.normal = Vector3(foot.normal).slerp(foot.target_normal, minf(1.0, delta * 5.0)).normalized()
		if t >= 1.0:
			foot.position = foot.target
			foot.planted = foot.target
			foot.normal = foot.target_normal
			foot.swing = false
			foot.stance_seconds = 0.0
			footfall_count += 1
			landings.append({"index": swing_index, "position": foot.position, "normal": foot.normal, "strength": 0.62})
			next_leg = (swing_index + 1) % 3
			swing_index = -1
		return
	if not allow_steps:
		return
	var candidate := -1
	var best_error := STEP_THRESHOLD
	for offset in 3:
		var index := (next_leg + offset) % 3
		var neutral := owner.to_global(rest_feet[index])
		var current: Vector3 = feet[index].position
		var error := Vector2(neutral.x - current.x, neutral.z - current.z).length()
		if error > best_error and feet[index].stance_seconds >= 0.25:
			best_error = error
			candidate = index
	if candidate < 0:
		return
	var foot: Dictionary = feet[candidate]
	var contact := ground_at(owner.to_global(rest_feet[candidate]) + velocity)
	# Reject inaccessible/occupied landings instead of stretching through obstacles.
	if absf(Vector3(contact.position).y - Vector3(foot.position).y) > 0.85:
		contact = ground_at(owner.to_global(rest_feet[candidate]))
	if absf(Vector3(contact.position).y - Vector3(foot.position).y) > 1.15 or Vector3(contact.normal).y < 0.7:
		return
	var sole_path: Vector3 = Vector3(contact.position) - Vector3(foot.position)
	var closest := Vector3(foot.position)
	if sole_path.length_squared() > 0.001:
		closest += sole_path * clampf((player_position - closest).dot(sole_path) / sole_path.length_squared(), 0.0, 1.0)
	if player_position.distance_to(closest + Vector3.UP * 0.25) < 1.05:
		return
	foot.start = foot.position
	foot.target = contact.position
	foot.target_normal = contact.normal
	foot.progress = 0.0
	foot.swing = true
	swing_index = candidate

func motion_scale() -> float:
	var largest_error := 0.0
	for index in feet.size():
		var neutral := owner.to_global(rest_feet[index])
		var at: Vector3 = feet[index].position
		largest_error = maxf(largest_error, Vector2(neutral.x - at.x, neutral.z - at.z).length())
	return 1.0 - smoothstep(1.65, 2.45, largest_error)

func support_pose() -> Dictionary:
	var contacts: Array[Vector3] = []
	for foot in feet:
		contacts.append(Vector3(foot.start).lerp(foot.target, foot.progress) if foot.swing else Vector3(foot.position))
	var normal := (contacts[2] - contacts[0]).cross(contacts[1] - contacts[0]).normalized()
	if normal.y < 0.0:
		normal = -normal
	if normal.y < 0.75:
		normal = Vector3.UP.slerp(normal, 0.4).normalized()
	var height := contacts[0].y - (normal.x * (owner.global_position.x - contacts[0].x) + normal.z * (owner.global_position.z - contacts[0].z)) / maxf(normal.y, 0.1)
	var shift := Vector3.ZERO
	var lift := 0.0
	if swing_index >= 0:
		var middle := (contacts[(swing_index + 1) % 3] + contacts[(swing_index + 2) % 3]) * 0.5 - owner.global_position
		shift = Vector3(middle.x, 0, middle.z).limit_length(3.0) * 0.025
		lift = -sin(float(feet[swing_index].progress) * PI) * 0.045
	return {"normal": normal, "height": height, "shift": shift, "lift": lift}

func apply_limbs(model: Node3D) -> void:
	for index in feet.size():
		var hip := model.to_global(hips[index])
		var foot: Vector3 = feet[index].position
		var direction := foot - hip
		var distance := maxf(0.01, direction.length())
		var axis := direction / distance
		var pole_local := Vector3(signf(hips[index].x), 0.05, -0.25) if index < 2 else Vector3(0, 0.05, 1)
		var pole := owner.global_basis * pole_local
		var bend := (pole - axis * pole.dot(axis)).normalized()
		var extension := maxf(1.0, distance / (UPPER_LENGTH + LOWER_LENGTH - 0.08))
		var upper := UPPER_LENGTH * extension
		var lower := LOWER_LENGTH * extension
		var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
		var across := sqrt(maxf(0.015, upper * upper - along * along))
		var knee := hip + axis * along + bend * across
		var local_normal := (model.global_basis.inverse() * Vector3(feet[index].normal)).normalized()
		model.set_limb_pose(index, model.to_local(hip), model.to_local(knee), model.to_local(foot), local_normal)
