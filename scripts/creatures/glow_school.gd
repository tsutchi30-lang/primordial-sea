extends Node3D

const Art = preload("res://scripts/creatures/creature_mesh.gd")
var species_id: String = "glowgrain"
var behavior_event: String = ""
var home := Vector3.ZERO
var age: float = 0.0
var following_bait: bool = false
var bait_age: float = 0.0
var density: float = 1.0
var grains: Array[Node3D] = []
var lights: Array[StandardMaterial3D] = []
var offsets: Array[Vector3] = []
var representative: Node3D
var dim_strength: float = 0.0
var visual_accumulator: float = 0.0

func setup(at: Vector3, phase: float = 0.0) -> void:
	position = at
	home = at
	age = phase
	var body_mat := Art.material(Color(0.55, 0.85, 0.85, 0.38), 0.0, true)
	for i in 42:
		var grain := Node3D.new()
		var a := float(i) * 2.39996
		var offset := Vector3(sin(a) * sqrt(float(i) / 42.0) * 2.0, sin(i * 1.7) * 0.7, cos(a) * sqrt(float(i) / 42.0) * 2.0)
		grain.position = offset
		add_child(grain)
		var light_mat := Art.material(Color("b4f9ef"), 1.6)
		for j in 3:
			Art.ellipsoid(grain, Vector3(sin(j * 2.1) * 0.003, cos(j * 2.1) * 0.003, (j - 1) * 0.005), Vector3.ONE * 0.0032, light_mat, 6)
		# A small luminous halo communicates the school at swimming distance; the
		# actual three organs and spiral are centimetre-sized under magnification.
		var halo := Art.material(Color(0.5, 0.95, 0.85, 0.25), 0.7, true)
		Art.ellipsoid(grain, Vector3.ZERO, Vector3.ONE * 0.042, halo, 6)
		if i == 0:
			representative = grain
			for j in 18:
				var angle := j * 0.65
				var p := Vector3(sin(angle) * 0.004, cos(angle) * 0.004, (j - 9) * 0.0008)
				Art.ellipsoid(grain, p, Vector3.ONE * 0.002, body_mat, 6)
		grains.append(grain)
		lights.append(light_mat)
		offsets.append(offset)

func observation_position() -> Vector3:
	return representative.global_position

func consume() -> void:
	density = maxf(0.25, density - 0.4)

func tick(delta: float, bait: Variant, large_positions: Array[Vector3], hogara: Node3D, shelter_school: bool = false, viewer_position: Vector3 = Vector3.ZERO) -> void:
	age += delta
	density = minf(1.0, density + delta * 0.018)
	following_bait = bait is Vector3
	bait_age = bait_age + delta if following_bait else 0.0
	var target := home
	if following_bait:
		target = bait
		behavior_event = "bait"
	elif shelter_school:
		target = hogara.global_position + Vector3(0, 1.7, 0)
		behavior_event = "shelter"
	else:
		target += Vector3(sin(age * 0.09) * 0.7, sin(age * 0.15) * 0.2, cos(age * 0.09) * 0.7)
		behavior_event = ""
	position = position.move_toward(target, delta * (0.95 if following_bait else 0.4))
	visual_accumulator += delta
	if global_position.distance_squared_to(viewer_position) > 900.0 and visual_accumulator < 0.2:
		return
	delta = visual_accumulator
	visual_accumulator = 0.0
	dim_strength = 0.0
	for i in grains.size():
		var grain := grains[i]
		var threat_distance: float = 100.0
		for threat in large_positions:
			threat_distance = minf(threat_distance, grain.global_position.distance_to(threat))
		var dim := clampf((7.0 - threat_distance) / 5.0, 0.0, 1.0)
		dim_strength = maxf(dim_strength, dim)
		var light := lerpf(lights[i].emission_energy_multiplier, (1.7 - dim * 1.60) * density, minf(delta * 3.0, 1.0))
		lights[i].emission_energy_multiplier = light
		lights[i].albedo_color = Color("b4f9ef") * (0.20 + 0.8 * (1.0 - dim))
		# Reduced density expands the school toward its margins, then visibly streams
		# back from those margins over time rather than respawning in front of a camera.
		var spread := 1.0 + (1.0 - density) * 3.0
		grain.position = offsets[i] * spread * (0.6 if following_bait else 1.0) + Vector3(sin(age * 0.7 + i) * 0.10, sin(age * 1.1 + i * 0.6) * 0.05, cos(age * 0.7 + i) * 0.10)
		grain.rotation.y = age * 0.3 + i
	if dim_strength > 0.65 and not following_bait and not shelter_school:
		behavior_event = "dimming"
