extends CharacterBody3D
## Three paired lateral feet, swept movement, and bounded, local investigations.
const Art = preload("res://scripts/creatures/creature_mesh.gd")
const REACTION_SECONDS := 15.0
const HOME_RADIUS := 15.0
const INVESTIGATION_SECONDS := 4.0
const WALK_SPEED := 2.0
const BODY_CLEARANCE := 0.40
const BODY_RADIUS := 0.34
signal event_started(event_id: String)
signal hit_player(amount: float)
signal mineral_delivered(pickup: Node3D)
var species_id := "hexacrawler"
var behavior_event := ""
var state := "forage"
var state_time := 0.0
var age := 0.0
var reaction_time := 0.0
var home := Vector3.ZERO
var target := Vector3.ZERO
var blocked_time := 0.0
var reaction_cooldown := 0.0
var defense_warning := -1.0
var defense_cooldown := 0.0
var investigation_count := 0
var carried_count := 0
var mineral_waiting := false
var mineral_source := Vector3.ZERO
var cleaning_count := 0
var manager: Node3D
var player: CharacterBody3D
var carried_pickup: Node3D
var cargo_model: Node3D
var body_model: Node3D
var feet: Array[Node3D] = []
var plate_material: StandardMaterial3D
var cleaner := false
var cleaning_target: Node3D
var foul_patch: Node3D
var cleaning_progress := 0.0
var cleaning_regrow := 0.0
var cleaning_brush: MeshInstance3D
var _last_position := Vector3.ZERO
var _step_distance := 0.0
var last_collision: Dictionary = {}

func setup(ecology: Node3D, observer: CharacterBody3D, at: Vector3, is_cleaner := false) -> void:
	manager = ecology
	player = observer
	position = at
	home = at
	target = at
	cleaner = is_cleaner
	collision_layer = 8
	collision_mask = 1 | 8 | 2
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = BODY_RADIUS
	collider.shape = shape
	add_child(collider)
	_build_model()
	_last_position = global_position

func _build_model() -> void:
	plate_material = Art.material(Color("a98b6e"))
	var edge_mat := Art.material(Color("e1c9a0"))
	var flesh := Art.material(Color("55534b"))
	body_model = Node3D.new()
	add_child(body_model)
	Art.ellipsoid(body_model, Vector3(0, -0.07, 0), Vector3(0.58, 0.24, 0.76), flesh)
	# Seven individually bevelled hexagonal shields keep the footprint below 1m.
	for i in 7:
		var shield := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.radial_segments = 6
		mesh.top_radius = 0.155 if i == 0 else 0.115
		mesh.bottom_radius = mesh.top_radius * 1.13
		mesh.height = 0.085
		shield.mesh = mesh
		shield.material_override = plate_material
		if i == 0:
			shield.position = Vector3(0, 0.1, 0)
		else:
			var angle := (i - 1) * TAU / 6.0
			shield.position = Vector3(cos(angle) * 0.22, 0.055, sin(angle) * 0.27)
			shield.rotation = Vector3(sin(angle) * 0.16, angle, -cos(angle) * 0.16)
		body_model.add_child(shield)
		for edge in 6:
			var angle_a := edge * TAU / 6.0
			var angle_b := (edge + 1) * TAU / 6.0
			Art.rod(shield, Vector3(cos(angle_a) * mesh.top_radius, 0.05, sin(angle_a) * mesh.top_radius), Vector3(cos(angle_b) * mesh.top_radius, 0.05, sin(angle_b) * mesh.top_radius), 0.007, edge_mat)
	for side in [-1.0, 1.0]:
		for index in 3:
			var leg := Node3D.new()
			leg.position = Vector3(side * 0.20, -0.05, (index - 1) * 0.23)
			body_model.add_child(leg)
			Art.rod(leg, Vector3.ZERO, Vector3(side * 0.19, -0.10, 0.04), 0.035, flesh)
			Art.rod(leg, Vector3(side * 0.19, -0.10, 0.04), Vector3(side * 0.26, -0.32, -0.03), 0.018, edge_mat)
			feet.append(leg)
	for side in [-1.0, 1.0]:
		Art.rod(body_model, Vector3(side * 0.13, 0.0, -0.31), Vector3(side * 0.20, -0.14, -0.47), 0.025, edge_mat)
		Art.ellipsoid(body_model, Vector3(side * 0.17, 0.04, -0.31), Vector3.ONE * 0.035, flesh, 8)
	cargo_model = Node3D.new()
	add_child(cargo_model)
	var fragment := PrismMesh.new()
	fragment.size = Vector3(0.20, 0.12, 0.13)
	var cargo := MeshInstance3D.new()
	cargo.mesh = fragment
	cargo.material_override = Art.material(Color("ceab79"))
	cargo.position = Vector3(0, -0.08, -0.46)
	cargo_model.add_child(cargo)
	cargo_model.visible = false
	cleaning_brush = Art.rod(self, Vector3.ZERO, Vector3.UP, 0.022, flesh)
	cleaning_brush.visible = false

func observation_position() -> Vector3:
	return global_position + Vector3.UP * 0.10

func hear_sound(at: Vector3) -> bool:
	if cleaner or state not in ["forage"] or reaction_cooldown > 0.0:
		return false
	if at.distance_to(home) > HOME_RADIUS or global_position.distance_to(at) > 15.0:
		return false
	target = at
	reaction_time = 0.0
	_enter("investigate")
	return true

func take_mineral(pickup: Node3D) -> bool:
	if cleaner or state != "forage" or carried_count > 0 or not is_instance_valid(pickup) or not pickup.available or pickup.being_carried:
		return false
	if global_position.distance_to(pickup.global_position) > 0.85:
		return false
	carried_pickup = pickup
	mineral_waiting = false
	carried_pickup.being_carried = true
	carried_pickup.set_available(false)
	cargo_model.visible = true
	target = home
	_enter("carry")
	return true

func bind_cleaning(animal: Node3D) -> void:
	cleaning_target = animal
	# A visible patch on a low outside rib, not an added collider or a portal.
	foul_patch = Node3D.new()
	animal.model.add_child(foul_patch)
	foul_patch.position = Vector3(3.51, 0.84, 0)
	var fouling := Art.material(Color("817946"))
	for i in 5:
		Art.ellipsoid(foul_patch, Vector3(0.0, i * 0.055, sin(i * 2.0) * 0.06), Vector3(0.055, 0.09, 0.075), fouling, 8)

func tick(delta: float) -> void:
	if delta <= 0.0 or get_tree().paused:
		return
	var remaining := delta
	while remaining > 0.00001:
		var step := minf(0.05, remaining)
		_tick_step(step)
		remaining -= step

func _tick_step(delta: float) -> void:
	age += delta
	state_time += delta
	reaction_cooldown = maxf(0.0, reaction_cooldown - delta)
	defense_cooldown = maxf(0.0, defense_cooldown - delta)
	cleaning_regrow = maxf(0.0, cleaning_regrow - delta)
	behavior_event = ""
	if state in ["investigate", "examine", "return"]:
		reaction_time += delta
		if reaction_time >= REACTION_SECONDS:
			reaction_cooldown = 5.0
			_enter("forage")
		elif state != "return" and reaction_time + _horizontal_distance(home) / WALK_SPEED + 0.25 >= REACTION_SECONDS:
			_begin_return()
	_update_defense(delta)
	var before := global_position
	if defense_warning < 0.0:
		if cleaner:
			_tick_cleaner(delta)
		else:
			_tick_behavior(delta)
	var movement := global_position - before
	_step_distance += Vector2(movement.x, movement.z).length()
	var moving := movement.length_squared() > 0.000001
	for i in feet.size():
		var phase := _step_distance * 13.0 + i * PI
		feet[i].rotation.x = sin(phase) * 0.22 if moving else sin(age * 2.0 + i) * 0.025
		feet[i].position.y = -0.05 + (maxf(0.0, sin(phase)) * 0.07 if moving else 0.0)
	var raised := 0.0 if defense_warning < 0.0 else clampf(1.0 - defense_warning / 0.8, 0.0, 1.0)
	body_model.rotation.z = sin(age * 24.0) * raised * 0.06
	body_model.position.y = raised * 0.14
	if state == "clean":
		body_model.rotation.x = -0.13 + sin(age * 16.0) * 0.08
		var reach: Vector3 = to_local(foul_patch.global_position) + Vector3(0, sin(age * 16.0) * 0.045, 0)
		cleaning_brush.position = reach * 0.5
		var direction := reach.normalized()
		var axis := Vector3.UP.cross(direction)
		cleaning_brush.basis = Basis(axis.normalized(), acos(clampf(direction.y, -1.0, 1.0))) if axis.length_squared() > 0.0001 else Basis.IDENTITY
		cleaning_brush.scale.y = reach.length()
	else:
		body_model.rotation.x = 0.0
	cleaning_brush.visible = state == "clean"
	if is_instance_valid(carried_pickup):
		carried_pickup.global_position = global_position + Vector3(0, -0.08, -0.46)
	_last_position = global_position

func _tick_behavior(delta: float) -> void:
	match state:
		"forage":
			# The entrance animal keeps a compact feeding patch. A lateral move
			# toward an urn therefore creates a materially wider crossing.
			var feeding_center := mineral_source if mineral_waiting else home
			var forage := feeding_center + Vector3(sin(age * 0.19) * 0.25, 0, cos(age * 0.15) * 0.20)
			_walk_to(forage, 0.20, delta)
		"investigate":
			_walk_to(target, WALK_SPEED, delta)
			if _horizontal_distance(target) <= 1.05:
				investigation_count += 1
				_enter("examine")
				behavior_event = "crawler_investigated"
				event_started.emit(behavior_event)
			elif blocked_time >= 1.5:
				_begin_return()
		"examine":
			behavior_event = "crawler_investigated"
			if state_time >= INVESTIGATION_SECONDS:
				_begin_return()
		"return":
			_walk_to(home, WALK_SPEED, delta)
			if _horizontal_distance(home) <= 0.45 or blocked_time >= 1.5:
				_enter("forage")
		"carry":
			_walk_to(home, 0.85, delta)
			if _horizontal_distance(home) < 0.55:
				_release_mineral(true)
				_enter("forage")
			elif blocked_time >= 1.5 or state_time >= 15.0:
				_release_mineral(false)
				_enter("forage")

func _update_defense(delta: float) -> void:
	if cleaner or not is_instance_valid(player):
		return
	var distance := global_position.distance_to(player.global_position)
	if defense_warning >= 0.0:
		if distance > 1.6:
			defense_warning = -1.0
			defense_cooldown = 4.0
			return
		defense_warning -= delta
		if defense_warning <= 0.0:
			defense_warning = -1.0
			defense_cooldown = 4.0
			var excluded: Array[RID] = [get_rid()]
			if distance < 1.05 and manager.has_clear_path(observation_position(), player.global_position, excluded):
				hit_player.emit(10.0)
	elif defense_cooldown <= 0.0 and state in ["forage", "carry"] and (distance < 0.66 or distance < 1.1 and bool(player.get("sprinting"))):
		defense_warning = 0.8
		behavior_event = "defense"
		event_started.emit("defense")

func _tick_cleaner(delta: float) -> void:
	if not is_instance_valid(cleaning_target):
		return
	if is_instance_valid(foul_patch) and cleaning_regrow <= 0.0:
		foul_patch.visible = true
	var can_approach: bool = cleaning_target.state in ["rest_warning", "settling", "rest"] and cleaning_regrow <= 0.0
	# Outside x=4.15 keeps the 0.6m swimmer's exit corridors clear. The brush
	# reaches inward to the rib; no climbing or moving-parent attachment occurs.
	var edge: Vector3 = cleaning_target.model.to_global(Vector3(4.18, 0.40, 0))
	if can_approach and edge.distance_to(home) < 10.0:
		_walk_to(edge, 1.0, delta)
		if cleaning_target.state == "rest" and _horizontal_distance(edge) < 0.58:
			state = "clean"
			cleaning_progress += delta
			if is_instance_valid(foul_patch):
				foul_patch.scale = Vector3.ONE * maxf(0.05, 1.0 - cleaning_progress / 2.0)
			if cleaning_progress >= 2.0:
				cleaning_count += 1
				cleaning_regrow = 90.0
				foul_patch.visible = false
				foul_patch.scale = Vector3.ONE
				behavior_event = "shell_cleaned"
				event_started.emit("shell_cleaned")
				_enter("forage")
	else:
		cleaning_progress = 0.0
		if is_instance_valid(foul_patch):
			foul_patch.scale = Vector3.ONE
		state = "forage"
		_walk_to(home, 0.7, delta)

func _release_mineral(delivered: bool) -> void:
	if not is_instance_valid(carried_pickup):
		return
	carried_pickup.being_carried = false
	var dropped_at := global_position + Vector3(0.6, -0.22, 0)
	var support := _support_at(dropped_at)
	if not support.is_empty():
		dropped_at.y = float(support.y) + 0.14
	carried_pickup.global_position = dropped_at
	carried_pickup.set_available(true)
	if delivered:
		carried_count += 1
		behavior_event = "mineral_carried"
		event_started.emit("mineral_carried")
		mineral_delivered.emit(carried_pickup)
	carried_pickup = null
	cargo_model.visible = false

func _walk_to(destination: Vector3, speed: float, delta: float) -> void:
	var offset := Vector3(destination.x - global_position.x, 0, destination.z - global_position.z)
	if offset.length() < 0.05:
		blocked_time = 0.0
		return
	var motion := offset.limit_length(speed * delta)
	var next := global_position + motion
	var floor_point := _support_at(next)
	if floor_point.is_empty():
		blocked_time += delta
		return
	# On a slope, a sphere needs more *vertical* clearance than its radius.
	# The real triangle normal keeps the body above the shell rather than stuck
	# half inside the uphill face while a floor-height-only target moves onward.
	var clearance := maxf(BODY_CLEARANCE, BODY_RADIUS / maxf(0.55, float(floor_point.normal_y)) + 0.02)
	var desired_y: float = float(floor_point.y) + clearance
	# Probe the leading part of the contact sphere as well. At the start of a
	# steep shell ramp its front touches the slope before its centre is over it.
	# Project that real surface plane back to the next centre; continuously sweep
	# up it instead of snapping onto a floor-height waypoint or sticking at its lip.
	var lead := next + offset.normalized() * (BODY_RADIUS + 0.08)
	var forward_support := _support_at(lead)
	if not forward_support.is_empty():
		var normal: Vector3 = forward_support.normal
		var plane_y: float = float(forward_support.y) - (normal.x * (next.x - lead.x) + normal.z * (next.z - lead.z)) / normal.y
		var forward_y := plane_y + BODY_RADIUS / normal.y + 0.02
		desired_y = maxf(desired_y, forward_y)
	if absf(desired_y - global_position.y) > 0.55:
		blocked_time += delta
		return
	motion.y = desired_y - global_position.y
	var before := global_position
	var collision := move_and_collide(motion, false, 0.001)
	if collision:
		last_collision = {"body": str(collision.get_collider().name), "normal": collision.get_normal(), "position": collision.get_position()}
		# Tangential travel stays on real geometry; no coordinate repair or warp.
		var slide := collision.get_remainder().slide(collision.get_normal())
		if slide.length_squared() > 0.000001:
			move_and_collide(slide, false, 0.001)
	var travelled := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	blocked_time = blocked_time + delta if travelled < speed * delta * 0.12 else 0.0

func _support_at(at: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.50, at + Vector3.DOWN * 1.2, 1 | 8)
	query.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty() or Vector3(result.normal).y < 0.55:
		return {}
	return {"y": Vector3(result.position).y, "normal_y": Vector3(result.normal).y, "normal": Vector3(result.normal)}

func _horizontal_distance(to: Vector3) -> float:
	return Vector2(global_position.x - to.x, global_position.z - to.z).length()

func _begin_return() -> void:
	reaction_cooldown = 5.0
	target = home
	_enter("return")

func _enter(next_state: String) -> void:
	state = next_state
	state_time = 0.0
	blocked_time = 0.0
