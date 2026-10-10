extends Node3D
## Main owns game time: there is deliberately no _process / _physics_process here.

const Catalog = preload("res://data/species/species_catalog.gd")
const Small = preload("res://scripts/creatures/small_creature.gd")
const School = preload("res://scripts/creatures/glow_school.gd")
const Hogara = preload("res://scripts/creatures/hogara.gd")
const Predator = preload("res://scripts/creatures/windoweater.gd")
const Silt = preload("res://scripts/ecology/silt_cloud.gd")
const Art = preload("res://scripts/creatures/creature_mesh.gd")
signal player_hit(amount: float)
signal hint(text: String)
signal observed_event(species_id: String, event_id: String)
var player: CharacterBody3D
var world: Node3D
var creatures: Array[Node3D] = []
var small_creatures: Array[Node3D] = []
var schools: Array[Node3D] = []
var predators: Array[CharacterBody3D] = []
var hogara: Node3D
var silt_clouds: Array[Node3D] = []
var baits: Array[Dictionary] = []
var pulse_effects: Array[Dictionary] = []
var age: float = 0.0
var damage_cooldown: float = 0.0
var mud_hint_given: bool = false
var hogara_hint_given: bool = false
var predator_hint_given: bool = false
var last_behavior: Dictionary = {}
var low_particles: bool = false

func setup(observer: CharacterBody3D, terrain: Node3D) -> void:
	player = observer
	world = terrain
	_spawn()

func reset() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	creatures.clear()
	small_creatures.clear()
	schools.clear()
	predators.clear()
	silt_clouds.clear()
	baits.clear()
	pulse_effects.clear()
	last_behavior.clear()
	age = 0.0
	damage_cooldown = 0.0
	mud_hint_given = false
	hogara_hint_given = false
	predator_hint_given = false
	_spawn()

func get_species_data() -> Dictionary:
	return Catalog.DATA

func set_low_particles(low: bool) -> void:
	low_particles = low
	for school in schools:
		for i in school.grains.size():
			school.grains[i].visible = not low or i % 2 == 0
	for cloud in silt_clouds:
		for i in cloud.dust.size():
			cloud.dust[i].visible = not low or i % 2 == 0

func _seafloor(x: float, z: float, height: float) -> Vector3:
	return Vector3(x, float(world.floor_height(x, z)) + height, z)

func _spawn() -> void:
	var placements := [
		["opabinia", -2.0, -20.0, 0.9], ["opabinia", -1.6, -20.3, 0.85],
		["hallucigenia", 4.0, -27.0, 0.30], ["hallucigenia", 4.08, -27.1, 0.30],
		["olenoides", -4.0, -34.0, 0.10], ["olenoides", -4.3, -33.7, 0.10],
		["mudunraveler", 0.0, -80.0, 0.20], ["mudunraveler", -2.0, -91.0, 0.20],
		["mudunraveler", 4.0, -101.0, 0.20]
	]
	for i in placements.size():
		var entry: Array = placements[i]
		var animal := Small.new()
		add_child(animal)
		animal.setup(entry[0], _seafloor(entry[1], entry[2], entry[3]), float(i) * 2.3)
		small_creatures.append(animal)
		creatures.append(animal)
	hogara = Hogara.new()
	add_child(hogara)
	hogara.setup(world)
	hogara.event_started.connect(func(event_id: String):
		observed_event.emit("hogara", event_id)
		if event_id == "rest_warning" and player.global_position.distance_to(hogara.global_position) < 12.0:
			hint.emit("帆殻の光が弱まっている。休息する前に腹側から出よう。"))
	creatures.append(hogara)
	for point in [Vector3(-3, 1.7, -25), Vector3(2, 2.2, -79), Vector3(2, 2.0, -94), Vector3(10, 1.7, -58)]:
		var school := School.new()
		add_child(school)
		school.setup(_seafloor(point.x, point.z, point.y), float(schools.size()) * 3.0)
		schools.append(school)
		creatures.append(school)
	var predator := Predator.new()
	add_child(predator)
	var homes: Array[Vector3] = [_seafloor(0, -82, 2.0), _seafloor(3, -94, 2.0), _seafloor(-3, -102, 2.0)]
	predator.setup(self, player, homes)
	predator.hit_player.connect(_on_player_hit)
	predator.event_started.connect(func(event_id: String): observed_event.emit("windoweater", event_id))
	predators.append(predator)
	creatures.append(predator)
	set_low_particles(low_particles)

func tick(delta: float) -> void:
	if not is_instance_valid(player) or delta <= 0.0:
		return
	age += delta
	damage_cooldown = maxf(0.0, damage_cooldown - delta)
	_update_baits(delta)
	for animal in small_creatures:
		if animal.tick(delta, player):
			spawn_silt(animal.global_position)
			observed_event.emit("mudunraveler", "burrow")
	for i in range(silt_clouds.size() - 1, -1, -1):
		var cloud := silt_clouds[i]
		if cloud.tick(delta):
			silt_clouds.remove_at(i)
			cloud.queue_free()
			continue
		for predator in predators:
			if cloud.strength_at(predator.global_position) > 0.08:
				predator.reveal(2.0)
	var large_positions: Array[Vector3] = [hogara.global_position + Vector3.UP * 2.0]
	if bool(player.get("sprinting")):
		large_positions.append(player.global_position)
	for predator in predators:
		large_positions.append(predator.global_position)
	for i in schools.size():
		var school := schools[i]
		var lure: Variant = nearest_bait(school.global_position)
		school.tick(delta, lure, large_positions, hogara, i == schools.size() - 1, player.global_position)
	hogara.tick(delta, player, schools.back().global_position)
	for predator in predators:
		predator.tick(delta)
	for creature in creatures:
		var event: String = creature.behavior_event
		var key: int = creature.get_instance_id()
		if not event.is_empty() and last_behavior.get(key, "") != event:
			observed_event.emit(creature.species_id, event)
		last_behavior[key] = event
	_update_hints()
	for i in range(pulse_effects.size() - 1, -1, -1):
		pulse_effects[i].time += delta
		var effect: Node3D = pulse_effects[i].node
		effect.scale = Vector3.ONE * (0.1 + pulse_effects[i].time * 4.0)
		if pulse_effects[i].time > 1.0:
			effect.queue_free()
			pulse_effects.remove_at(i)

func spawn_silt(at: Vector3) -> Node3D:
	if silt_clouds.size() >= 3:
		return null
	var cloud := Silt.new()
	add_child(cloud)
	cloud.setup(at)
	silt_clouds.append(cloud)
	if low_particles:
		for i in cloud.dust.size():
			cloud.dust[i].visible = i % 2 == 0
	return cloud

func use_bait(at: Vector3) -> bool:
	if at.y >= -0.5:
		hint.emit("誘餌は水中へ置こう。")
		return false
	if baits.size() >= 3:
		hint.emit("誘餌は同時に3個まで。いまの餌が流れ終わるのを待とう。")
		return false
	if not has_clear_path(player.global_position, at):
		hint.emit("岩の向こうには誘餌を置けない。")
		return false
	var pod := Node3D.new()
	add_child(pod)
	pod.position = at
	var mat := Art.material(Color("edcd82"), 0.9)
	Art.ellipsoid(pod, Vector3.ZERO, Vector3(0.16, 0.23, 0.16), mat)
	for i in 7:
		Art.ellipsoid(pod, Vector3(sin(i * 2.0) * 0.3, i * 0.055, cos(i * 2.0) * 0.3), Vector3.ONE * 0.025, mat, 6)
	baits.append({"node": pod, "position": at, "remaining": 45.0})
	hint.emit("誘餌を設置。45秒間、12m以内の灯粒虫を誘う。")
	return true

func nearest_bait(at: Vector3) -> Variant:
	var nearest: Variant = null
	var distance: float = 12.0
	for bait in baits:
		var candidate: Vector3 = bait.position
		var current := at.distance_to(candidate)
		if current < distance and has_clear_path(at, candidate):
			distance = current
			nearest = candidate
	return nearest

func _update_baits(delta: float) -> void:
	for i in range(baits.size() - 1, -1, -1):
		baits[i].remaining -= delta
		baits[i].node.rotation.y += delta
		if baits[i].remaining <= 0.0:
			baits[i].node.queue_free()
			baits.remove_at(i)

func predator_food(at: Vector3, allow_bait: bool) -> Node3D:
	var nearest: Node3D = null
	var distance: float = 14.0
	for i in schools.size() - 1:
		var school: Node3D = schools[i]
		if bool(school.following_bait) and not allow_bait:
			continue
		# A dispersed trickle does not yet tempt the predator. Let the school collect
		# several metres toward the lure, so feeding actually vacates the passage.
		if bool(school.following_bait) and school.bait_age < 4.5:
			continue
		if school.density < 0.45:
			continue
		var current := at.distance_to(school.global_position)
		if current < distance and has_clear_path(at, school.global_position):
			if school.following_bait:
				return school
			distance = current
			nearest = school
	return nearest

func pulse(at: Vector3) -> int:
	var affected: int = 0
	for predator in predators:
		if at.distance_to(predator.global_position) <= 4.0 and has_clear_path(at, predator.global_position):
			predator.stun()
			affected += 1
	var effect := Node3D.new()
	add_child(effect)
	effect.position = at
	var mat := Art.material(Color(0.55, 0.9, 1.0, 0.18), 1.2, true)
	Art.ellipsoid(effect, Vector3.ZERO, Vector3.ONE * 2.0, mat, 16)
	pulse_effects.append({"node": effect, "time": 0.0})
	return affected

func is_sheltered(at: Vector3) -> bool:
	return is_instance_valid(hogara) and hogara.contains(at)

func get_silt_strength(at: Vector3) -> float:
	var strength: float = 0.0
	for cloud in silt_clouds:
		strength = maxf(strength, cloud.strength_at(at))
	return strength

func has_clear_path(from: Vector3, to: Vector3) -> bool:
	if from.distance_squared_to(to) < 0.0001:
		return true
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 8)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func get_observation_target(camera: Camera3D) -> Node3D:
	var nearest: Node3D = null
	var best_score: float = -1.0
	for creature in creatures:
		var target: Vector3 = creature.observation_position()
		var offset := target - camera.global_position
		var distance := offset.length()
		if distance > 18.0 or distance < 0.015:
			continue
		var alignment := (-camera.global_basis.z).dot(offset.normalized())
		if alignment < 0.982:
			continue
		# A transparent predator remains an ordinary visual target; scanning never
		# reveals every hidden predator or records behaviour behind terrain.
		if not has_clear_path(camera.global_position, target):
			continue
		var score := alignment - distance * 0.0003
		if score > best_score:
			best_score = score
			nearest = creature
	return nearest

func _on_player_hit(amount: float) -> void:
	if damage_cooldown > 0.0:
		return
	damage_cooldown = 2.0
	player_hit.emit(amount)

func _update_hints() -> void:
	if not mud_hint_given:
		for animal in small_creatures:
			if animal.species_id == "mudunraveler" and animal.global_position.distance_to(player.global_position) < 5.0 and has_clear_path(player.global_position, animal.global_position):
				mud_hint_given = true
				hint.emit("泥の螺旋が震えている。3m以内でShift加速し、水流を起こしてみよう。")
				break
	if not hogara_hint_given and player.global_position.distance_to(hogara.global_position) < 12.0:
		hogara_hint_given = true
		hint.emit("巨大な影は、ゆっくり餌を濾している。腹側へ小さな光が流れ込む。")
	if not predator_hint_given and player.global_position.z < -70.0 and player.global_position.y < -20.0:
		predator_hint_given = true
		hint.emit("灯粒虫が避ける空白と、わずかに光る縁。少し離れて観察しよう。")
