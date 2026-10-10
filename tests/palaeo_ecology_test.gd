extends SceneTree
## Production manager/models in an isolated physics habitat, not the player save.

const Palaeo = preload("res://scripts/ecology/palaeo_ecology.gd")
const School = preload("res://scripts/creatures/glow_school.gd")
const Art = preload("res://scripts/creatures/creature_mesh.gd")
const Catalog = preload("res://data/species/species_catalog.gd")
var checks := 0
var failed := false

class ShelfFloor extends Node3D:
	func floor_height(_x: float, _z: float) -> float:
		return -70.0

class Habitat extends Node3D:
	var player: CharacterBody3D
	var world: Node3D
	var creatures: Array[Node3D] = []
	var schools: Array[Node3D] = []
	func has_clear_path(from: Vector3, to: Vector3) -> bool:
		if from.distance_squared_to(to) < 0.0000001:
			return true
		var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 8)
		return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("PALAEO_FAIL " + label)

func _run() -> void:
	var host := Habitat.new()
	root.add_child(host)
	host.world = ShelfFloor.new()
	host.add_child(host.world)
	host.player = CharacterBody3D.new()
	host.add_child(host.player)
	host.player.position = Vector3(12, -65.5, -254)
	var school := School.new()
	host.add_child(school)
	school.setup(Vector3(12, -65.5, -252), 0.0)
	host.schools.append(school)
	var habitat := Palaeo.new()
	host.add_child(habitat)
	habitat.setup(host)
	await physics_frame
	await physics_frame
	_check(Catalog.DATA.size() == 14, "fourteen_species_catalog")
	_check(host.creatures.size() == 7 and habitat.soft_prey.size() == 4, "bounded_real_instances")
	for animal: Node3D in habitat.animals:
		var bounds := _model_bounds(animal.visual)
		var length: float = bounds.size.z * animal.length_m
		match animal.species_id:
			"wiwaxia":
				_check(length >= 0.03 and length <= 0.05, "wiwaxia_actual_mesh_length")
			"marrella":
				_check(length >= 0.015 and length <= 0.025, "marrella_actual_mesh_length")
			"anomalocaris":
				_check(length >= 0.6 and length <= 1.0, "anomalocaris_actual_mesh_length")
	var predator: Node3D = habitat.animals.back()
	var original_school_density: float = school.density
	var feeding_seen := {}
	var captures_before := 0
	var actual_captures := 0
	var regenerated := false
	var first_capture_time := -1.0
	var first_prey := -1
	for frame in 180 * 30:
		habitat.tick(1.0 / 30.0)
		for animal: Node3D in habitat.animals:
			if animal.behavior_event == "feeding":
				feeding_seen[animal.species_id] = true
		if predator.captures > captures_before:
			captures_before = predator.captures
			actual_captures += 1
			_check(predator.behavior_event == "prey_captured", "event_only_after_actual_capture")
			if first_prey < 0:
				first_prey = predator.target_prey
				first_capture_time = habitat.age
			var prey: Dictionary = habitat.soft_prey[predator.target_prey]
			var tip: Vector3 = predator.to_global(Vector3(0, -0.115, -0.55) * predator.length_m)
			_check(prey.node.global_position.distance_to(tip) <= 0.17 and prey.remaining > 44.0, "prey_actually_at_grasping_appendages")
		if first_prey >= 0 and habitat.age - first_capture_time > 46.6 and habitat.prey_available(first_prey):
			regenerated = true
	_check(feeding_seen.has("wiwaxia") and feeding_seen.has("marrella"), "small_species_natural_feeding")
	_check(actual_captures >= 2, "natural_non_player_predation_repeats")
	_check(regenerated, "bounded_food_regenerates_after_game_time")
	_check(is_equal_approx(school.density, original_school_density), "m1_glow_school_not_consumed")
	_check(habitat.soft_prey.size() == 4 and predator.global_position.distance_to(predator.home) < 6.0, "bounded_population_and_activity_range")
	var old_age: float = habitat.age
	var old_position: Vector3 = predator.position
	var remaining: Array = habitat.soft_prey.map(func(food: Dictionary): return food.remaining)
	habitat.tick(0.0)
	habitat.tick(-1.0)
	paused = true
	habitat.tick(5.0)
	paused = false
	_check(habitat.age == old_age and predator.position == old_position and remaining == habitat.soft_prey.map(func(food: Dictionary): return food.remaining), "no_game_delta_freezes_ai_and_regrowth")
	var block_at := Vector3(12, -65.5, -251)
	var wall := Art.colliding_box(host, block_at, Vector3(2, 2, 0.25), Art.material(Color.GRAY))
	await physics_frame
	await physics_frame
	var from := block_at + Vector3(0, 0, -1)
	var to := block_at + Vector3(0, 0, 1)
	var result: Vector3 = habitat.swim_step(from, to, 2.0)
	_check(result.z < block_at.z - 0.25, "production_swimmer_shape_stops_at_physics_wall")
	_check(not host.has_clear_path(from, to), "prey_perception_respects_wall")
	_check(not habitat.capture_prey(0, Vector3.ZERO), "no_remote_capture")
	wall.queue_free()
	host.queue_free()
	await process_frame
	await process_frame
	if failed:
		quit(1)
	else:
		print("PALAEO_OK checks=%d captures=%d regenerated=%s" % [checks, actual_captures, regenerated])
		quit(0)

func _model_bounds(visual: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(visual, meshes)
	for mesh: MeshInstance3D in meshes:
		var transform: Transform3D = visual.global_transform.affine_inverse() * mesh.global_transform
		var part := transform * mesh.get_aabb()
		bounds = part if first else bounds.merge(part)
		first = false
	return bounds

func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
		_collect_meshes(child, meshes)
