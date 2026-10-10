extends Node3D
## Bounded local food chain; never consumes M1 glowgrain schools. This manager
## and all regeneration use ecosystem game time, including when off screen.

const Animal = preload("res://scripts/creatures/palaeo_creature.gd")
const Art = preload("res://scripts/creatures/creature_mesh.gd")
const WorldMap = preload("res://data/biomes/world_map.gd")
const MAX_SOFT_PREY := 4
const PREY_REGROW_SECONDS := 45.0
var host: Node3D
var animals: Array[Node3D] = []
var soft_prey: Array[Dictionary] = []
var age: float = 0.0
var prey_updates: float = 0.0
var swim_shape := SphereShape3D.new()

func setup(ecosystem: Node3D) -> void:
	host = ecosystem
	swim_shape.radius = 0.18
	var mud_shelf: Vector3 = WorldMap.point("wiwaxia_shelf", host.world)
	var shell_shelf: Vector3 = WorldMap.point("marrella_shelf", host.world)
	for i in 3:
		_spawn("wiwaxia", mud_shelf + Vector3((i - 1) * 0.13, 0.001, i * 0.085 - 0.085), float(i) * 3.1)
		_spawn("marrella", shell_shelf + Vector3((i - 1) * 0.11, 0.001, i * -0.08), float(i) * 3.7)
	var hunting_ground: Vector3 = WorldMap.point("anomalocaris", host.world)
	_spawn("anomalocaris", hunting_ground, 0.0)
	var mat := Art.material(Color("a2bdae"))
	for i in MAX_SOFT_PREY:
		var node := Node3D.new()
		add_child(node)
		var angle := float(i) / MAX_SOFT_PREY * TAU + 0.5
		var home := hunting_ground + Vector3(sin(angle) * 2.5, -0.15 + i * 0.12, cos(angle) * 2.5)
		node.position = home
		Art.ellipsoid(node, Vector3.ZERO, Vector3(0.027, 0.021, 0.065), mat, 8)
		for side: float in [-1.0, 1.0]:
			Art.rod(node, Vector3(side * 0.01, 0, 0.02), Vector3(side * 0.021, 0.004, 0.046), 0.003, mat, 0.0008)
		soft_prey.append({"node": node, "home": home, "remaining": 0.0, "growth": 1.0, "captured_at": home})

func _spawn(id: String, at: Vector3, phase: float) -> void:
	var animal := Animal.new()
	add_child(animal)
	animal.setup(id, at, phase)
	animals.append(animal)
	host.creatures.append(animal)

func tick(delta: float) -> void:
	if delta <= 0.0 or get_tree().paused:
		return
	age += delta
	prey_updates += delta
	var nearby: bool = host.player.global_position.distance_squared_to(animals.back().global_position) < 900.0
	var update_period := 0.05 if nearby else 0.5
	if prey_updates >= update_period:
		_update_prey(prey_updates)
		prey_updates = 0.0
	for animal in animals:
		animal.tick(delta, self)

func _update_prey(delta: float) -> void:
	for i in soft_prey.size():
		var food: Dictionary = soft_prey[i]
		var node: Node3D = food.node
		if food.remaining > 0.0:
			food.remaining = maxf(0.0, food.remaining - delta)
			var capture_age := PREY_REGROW_SECONDS - float(food.remaining)
			# The captured animal visibly contracts at the appendages before hiding.
			node.visible = capture_age < 0.5
			node.scale = Vector3.ONE * maxf(0.0, 1.0 - capture_age * 2.0)
			if food.remaining <= 0.0:
				food.growth = 0.0
			continue
		food.growth = minf(1.0, float(food.growth) + delta / 1.5)
		node.visible = true
		node.scale = Vector3.ONE * float(food.growth)
		node.position = food.home + Vector3(sin(age * 0.35 + i) * 0.23, sin(age * 0.9 + i) * 0.075, cos(age * 0.29 + i) * 0.2)
		node.rotation.y = sin(age * 1.8 + i) * 0.22

func prey_available(index: int) -> bool:
	return index >= 0 and index < soft_prey.size() and soft_prey[index].remaining <= 0.0 and soft_prey[index].growth >= 1.0

func prey_position(index: int) -> Vector3:
	return soft_prey[index].node.global_position

func nearest_prey(at: Vector3, home: Vector3) -> int:
	var best := -1
	var distance := 5.0
	for i in soft_prey.size():
		if not prey_available(i):
			continue
		var point: Vector3 = prey_position(i)
		var next_distance := at.distance_to(point)
		if point.distance_to(home) <= 6.0 and next_distance < distance and host.has_clear_path(at, point):
			distance = next_distance
			best = i
	return best

func capture_prey(index: int, at: Vector3) -> bool:
	if not prey_available(index) or prey_position(index).distance_to(at) > 0.17 or not host.has_clear_path(at, prey_position(index)):
		return false
	soft_prey[index].remaining = PREY_REGROW_SECONDS
	soft_prey[index].captured_at = at
	soft_prey[index].node.global_position = at
	return true

func swim_step(from: Vector3, destination: Vector3, distance: float) -> Vector3:
	var motion := from.direction_to(destination) * minf(distance, from.distance_to(destination))
	if motion.length_squared() < 0.0000001:
		return from
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = swim_shape
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = motion
	query.collision_mask = 1 | 8
	var cast: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(query)
	return from + motion * maxf(0.0, float(cast[0]) - 0.01)
