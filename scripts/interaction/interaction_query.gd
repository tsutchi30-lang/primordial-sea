extends RefCounted
## One geometric predicate for hints, selection and execution. Only the intended
## target's own collider may terminate the ray; walls are never excluded wholesale.
static func score(camera: Camera3D, point: Vector3, reach := 4.0, cosine := 0.80, target_body: CollisionObject3D = null) -> float:
	var offset := point - camera.global_position
	var distance := offset.length()
	if distance > reach or distance < 0.02:
		return -1.0
	var alignment := (-camera.global_basis.z).dot(offset / distance)
	if alignment < cosine:
		return -1.0
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, point, 1 | 8)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider != target_body:
		return -1.0
	# Aim wins over proximity, preventing a peripheral resource from taking an
	# interaction intended for the core. Distance only breaks near-equal angles.
	return alignment - distance * 0.0001
