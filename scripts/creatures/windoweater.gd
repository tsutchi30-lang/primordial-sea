extends CharacterBody3D

const Art = preload("res://scripts/creatures/creature_mesh.gd")
signal hit_player(amount: float)
signal event_started(event_id: String)
var species_id: String = "windoweater"
var behavior_event: String = ""
var state: String = "ambush"
var state_time: float = 0.0
var age: float = 0.0
var pursuit_time: float = 0.0
var pursuing_player: bool = false
var exposed_remaining: float = 0.0
var bait_cooldown: float = 0.0
var home := Vector3.ZERO
var home_index: int = 0
var homes: Array[Vector3] = []
var last_seen := Vector3.ZERO
var dash_direction := Vector3.FORWARD
var dash_distance: float = 0.0
var attack_hit: bool = false
var eaten_count: int = 0
var bait_feeds: int = 0
var target_school: Node3D
var membrane_material: StandardMaterial3D
var edge_material: StandardMaterial3D
var wings: Array[Node3D] = []
var coating: Array[Node3D] = []
var mouth: Node3D
var ecology: Node3D
var player: CharacterBody3D
var rng := RandomNumberGenerator.new()
var web_field: Node3D
var snared_web: Node3D
var snare_cooldown := 0.0
var snare_count := 0

func setup(manager: Node3D, observer: CharacterBody3D, points: Array[Vector3]) -> void:
	ecology = manager
	player = observer
	homes = points
	home = homes[0]
	position = home
	rotation.y = PI
	collision_layer = 4
	collision_mask = 1 | 8
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	collider.shape = shape
	add_child(collider)
	rng.seed = 510012
	_build_model()

func observation_position() -> Vector3:
	return global_position

func reveal(seconds: float = 8.0) -> void:
	var newly_exposed := exposed_remaining <= 0.0
	exposed_remaining = maxf(exposed_remaining, seconds)
	behavior_event = "silt"
	if newly_exposed:
		event_started.emit("silt")

func stun() -> void:
	_release_web()
	_enter("stunned")
	behavior_event = "stunned"
	event_started.emit("stunned")

func tick(delta: float) -> void:
	if delta <= 0.0 or get_tree().paused:
		return
	age += delta
	state_time += delta
	exposed_remaining = maxf(0.0, exposed_remaining - delta)
	bait_cooldown = maxf(0.0, bait_cooldown - delta)
	snare_cooldown = maxf(0.0, snare_cooldown - delta)
	if pursuing_player:
		pursuit_time += delta
		if (pursuit_time >= 12.0 or global_position.distance_to(home) >= 25.0) and state not in ["return", "stunned", "snared"]:
			_begin_return()
	var player_distance := global_position.distance_to(player.global_position)
	var shelter: bool = ecology.is_sheltered(player.global_position)
	var sees_player := false
	if player_distance < 8.0 and player.global_position.y < -3.0 and not shelter:
		var direction := (player.global_position - global_position).normalized()
		if direction.dot(-global_basis.z) > -0.15 or pursuing_player:
			sees_player = ecology.has_clear_path(global_position, player.global_position)
	if sees_player:
		last_seen = player.global_position
	match state:
		"ambush":
			behavior_event = "silt" if exposed_remaining > 0.0 else ""
			var school: Node3D = ecology.predator_food(global_position, bait_cooldown <= 0.0)
			# A nearby feeding scene is visible from the safe upper shelf. Bait produces
			# a real departure toward the moving school, not just a rotation or a flag.
			if is_instance_valid(school) and (bool(school.get("following_bait")) or state_time > 8.0):
				target_school = school
				_enter("feed")
				behavior_event = "feed"
			elif sees_player and state_time > 2.0:
				pursuing_player = true
				pursuit_time = 0.0
				_enter("attention")
		"attention":
			_face(last_seen, delta * 2.0)
			if not sees_player:
				_enter("search")
			elif state_time > 0.65:
				_enter("windup")
				behavior_event = "windup"
				event_started.emit("windup")
		"windup":
			_face(last_seen, delta * 2.0)
			if shelter or not sees_player:
				_enter("search")
			elif state_time >= 1.0:
				dash_direction = (last_seen - global_position).normalized()
				dash_distance = 0.0
				attack_hit = false
				_enter("dash")
		"dash":
			var motion := dash_direction * delta * 6.0
			var before := global_position
			var collision := move_and_collide(motion)
			dash_distance += motion.length()
			if _contact_web(before):
				_update_visual(delta)
				return
			if not attack_hit and not shelter and global_position.distance_to(player.global_position) < 1.0:
				if ecology.has_clear_path(global_position, player.global_position):
					attack_hit = true
					hit_player.emit(28.0)
			if collision or state_time >= 1.15 or dash_distance >= 7.0:
				_enter("recover")
		"recover":
			if state_time > 3.0:
				_enter("search")
		"search":
			# Last seen position is finite; no wall-following of the player's live position.
			if state_time < 1.5 and not shelter:
				_swim_toward(last_seen, 0.7, delta)
				if state == "snared":
					_update_visual(delta)
					return
			if state_time > 2.5:
				_begin_return()
		"return":
			behavior_event = "return"
			_swim_toward(home, 1.9, delta)
			if state == "snared":
				_update_visual(delta)
				return
			if global_position.distance_to(home) < 0.45:
				pursuing_player = false
				pursuit_time = 0.0
				_enter("ambush")
				rotation.y = PI
		"feed":
			behavior_event = "feed"
			if is_instance_valid(target_school):
				_swim_toward(target_school.global_position, 1.8, delta)
				if state == "snared":
					_update_visual(delta)
					return
				if global_position.distance_to(target_school.global_position) < 1.7 and state_time > 1.0:
					if bool(target_school.get("following_bait")):
						bait_feeds += 1
						behavior_event = "bait_feed"
						event_started.emit("bait_feed")
						target_school.consume()
					else:
						target_school.consume()
						event_started.emit("feed")
					eaten_count += 1
					bait_cooldown = 16.0
					_enter("recover")
			if state_time > 12.0:
				_begin_return()
		"stunned":
			behavior_event = "stunned"
			if state_time >= 2.0:
				_begin_return()
		"snared":
			behavior_event = "predator_snared"
			# The original chase clock continues above; being caught never grants
			# another attack window. One bounded entanglement then actual retreat.
			if state_time >= 3.5:
				_release_web()
				_begin_return()
	_update_visual(delta)

func _contact_web(from: Vector3) -> bool:
	if not is_instance_valid(web_field) or snare_cooldown > 0.0 or state == "snared":
		return false
	var touched: Node3D = web_field.contact_web(from, global_position, 0.7)
	if not is_instance_valid(touched):
		return false
	snared_web = touched
	snare_count += 1
	_enter("snared")
	behavior_event = "predator_snared"
	event_started.emit("predator_snared")
	return true

func _release_web() -> void:
	if is_instance_valid(snared_web):
		snared_web.sever("predator")
	snared_web = null
	snare_cooldown = 4.0

func _enter(next: String) -> void:
	state = next
	state_time = 0.0

func _begin_return() -> void:
	home_index = (home_index + 1) % homes.size()
	home = homes[home_index]
	_enter("return")
	behavior_event = "return"
	event_started.emit("return")

func _face(target: Vector3, weight: float) -> void:
	var direction := target - global_position
	if direction.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), clampf(weight, 0.0, 1.0))

func _swim_toward(target: Vector3, speed: float, delta: float) -> void:
	_face(target, delta * 1.8)
	var direction := target - global_position
	if direction.length() < 0.1:
		return
	var before := global_position
	var collision := move_and_collide(direction.normalized() * minf(direction.length(), speed * delta))
	if collision:
		# Move around local rocks using a tangential trial. Never teleport or pursue
		# through a shelter; blocked feeding/search simply expires on its timer.
		var tangent := direction.slide(collision.get_normal()).normalized()
		move_and_collide(tangent * speed * delta * 0.7)
	_contact_web(before)

func _build_model() -> void:
	membrane_material = Art.material(Color(0.52, 0.80, 0.82, 0.085), 0.0, true)
	edge_material = Art.material(Color(0.27, 0.55, 0.58, 0.26), 0.15, true)
	var chitin := Art.material(Color(0.35, 0.49, 0.45, 0.25), 0.0, true)
	mouth = Node3D.new()
	add_child(mouth)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.53
	torus.outer_radius = 0.70
	torus.rings = 24
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = edge_material
	ring.rotation.x = PI * 0.5
	mouth.add_child(ring)
	for i in 12:
		var a := float(i) * TAU / 12.0
		Art.rod(mouth, Vector3(cos(a) * 0.57, sin(a) * 0.57, 0), Vector3(cos(a) * 0.37, sin(a) * 0.37, -0.17), 0.045, chitin, 0.006)
	for i in 4:
		var wing := Node3D.new()
		wing.rotation.z = i * PI * 0.5
		add_child(wing)
		Art.triangle(wing, Vector3(-0.43, 0.38, 0), Vector3(0.43, 0.38, 0), Vector3(1.15, 1.15, 0.08), membrane_material)
		Art.triangle(wing, Vector3(-0.43, 0.38, 0), Vector3(1.15, 1.15, 0.08), Vector3(-1.15, 1.15, 0.08), membrane_material)
		for j in 8:
			var a := float(j) / 8.0
			var b := float(j + 1) / 8.0
			Art.rod(wing, Vector3(lerpf(-1.15, 1.15, a), 1.15 + sin(a * PI) * 0.10, 0.08), Vector3(lerpf(-1.15, 1.15, b), 1.15 + sin(b * PI) * 0.10, 0.08), 0.013, edge_material)
		Art.rod(wing, Vector3(1.15, 1.15, 0.08), Vector3(0.43, 0.38, 0), 0.013, edge_material)
		wings.append(wing)
	var sand := Art.material(Color("e3d1a0"), 0.15)
	for i in 54:
		var particle := Art.ellipsoid(self, Vector3(rng.randf_range(-1.14, 1.14), rng.randf_range(-1.14, 1.14), -0.04), Vector3.ONE * rng.randf_range(0.025, 0.055), sand, 6)
		particle.visible = false
		coating.append(particle)
	# Drifting specks cling to the boundary even while unexposed: a second clue.
	for i in 9:
		var a := float(i) * TAU / 9.0
		Art.ellipsoid(self, Vector3(cos(a) * 1.28, sin(a) * 1.28, 0.04), Vector3.ONE * 0.025, edge_material, 6)

func _update_visual(delta: float) -> void:
	var exposed := exposed_remaining > 0.0
	membrane_material.albedo_color = Color(0.72, 0.68, 0.48, 0.48) if exposed else Color(0.52, 0.80, 0.82, 0.085)
	edge_material.albedo_color.a = 0.95 if exposed else 0.72 if state == "snared" else 0.26
	var folded := state in ["windup", "dash", "recover", "feed"]
	for i in wings.size():
		var desired := (-0.65 if i % 2 == 0 else 0.35) + sin(age * 7.0 + i) * 0.04 if state == "snared" else -0.95 if folded else sin(age * 1.4 + i) * 0.055
		wings[i].rotation.x = lerpf(wings[i].rotation.x, desired, minf(delta * 5.0, 1.0))
	mouth.scale = Vector3(0.72, 1.13, 0.8) if state == "snared" else Vector3.ONE * (1.0 + sin(age * 4.0) * (0.055 if folded else 0.005))
	for particle in coating:
		particle.visible = exposed
