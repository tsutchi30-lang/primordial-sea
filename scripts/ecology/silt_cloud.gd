extends Node3D

const Art = preload("res://scripts/creatures/creature_mesh.gd")
var age: float = 0.0
var lifetime: float = 12.0
var radius: float = 0.8
var grain_material: StandardMaterial3D
var dust: Array[Node3D] = []
var directions: Array[Vector3] = []

func setup(at: Vector3) -> void:
	position = at + Vector3.UP * 0.25
	grain_material = Art.material(Color(0.78, 0.73, 0.51, 0.32), 0.06, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 82014
	for i in 52:
		var direction := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.05, 0.8), rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.15, 1.0)
		directions.append(direction)
		dust.append(Art.ellipsoid(self, direction, Vector3.ONE * rng.randf_range(0.14, 0.42), grain_material, 6))

func tick(delta: float) -> bool:
	age += delta
	radius = lerpf(0.8, 5.5, clampf(age / 3.5, 0.0, 1.0))
	grain_material.albedo_color.a = 0.32 * clampf((lifetime - age) / 4.0, 0.0, 1.0)
	for i in dust.size():
		dust[i].position = directions[i] * radius + Vector3(sin(age * 0.2 + i) * 0.2, -maxf(0.0, age - 5.0) * 0.08, 0)
	return age >= lifetime

func strength_at(point: Vector3) -> float:
	var distance := global_position.distance_to(point)
	return clampf(1.0 - distance / maxf(radius, 0.01), 0.0, 1.0) * clampf((lifetime - age) / 4.0, 0.0, 1.0)
