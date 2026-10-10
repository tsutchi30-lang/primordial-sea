extends Node3D

const Art = preload("res://scripts/creatures/creature_mesh.gd")
var species_id: String = ""
var behavior_event: String = ""
var home := Vector3.ZERO
var age: float = 0.0
var phase: float = 0.0
var rest_remaining: float = 0.0
var burrow_delay: float = 0.0
var visual := Node3D.new()
var appendages: Array[Node3D] = []
var proboscis: Node3D
var length_m: float = 0.1
var burrow_pending: bool = false
var pending_delta: float = 0.0

func setup(id: String, at: Vector3, seed_phase: float = 0.0) -> void:
	species_id = id
	position = at
	home = at
	phase = seed_phase
	add_child(visual)
	match species_id:
		"opabinia":
			length_m = 0.07
			_build_opabinia()
		"hallucigenia":
			length_m = 0.03
			_build_hallucigenia()
			Art.ellipsoid(get_parent(), position + Vector3(0, -0.04, 0), Vector3(0.20, 0.08, 0.20), Art.material(Color("a78070")))
		"olenoides":
			length_m = 0.09
			_build_olenoides()
			Art.ellipsoid(get_parent(), position + Vector3(0, -0.055, 0), Vector3(0.90, 0.115, 0.90), Art.material(Color("a5ad90")))
		"mudunraveler":
			length_m = 0.30
			_build_mud()
			# The top of a soft mound intersects the lower spiral: this animal is
			# half buried while feeding, and sinks into the same mound when alarmed.
			Art.ellipsoid(get_parent(), position + Vector3(0, -0.12, 0), Vector3(0.70, 0.30, 0.70), Art.material(Color("a5ad90")))
	visual.scale = Vector3.ONE * length_m

func observation_position() -> Vector3:
	return global_position + Vector3.UP * length_m * 0.15

func tick(delta: float, observer: Node3D) -> bool:
	pending_delta += delta
	if global_position.distance_squared_to(observer.global_position) > 625.0 and pending_delta < 0.25:
		return false
	delta = pending_delta
	pending_delta = 0.0
	age += delta
	rest_remaining = maxf(0.0, rest_remaining - delta)
	var t := age + phase
	match species_id:
		"opabinia":
			var feeding := fmod(t, 11.0) > 6.0
			behavior_event = "feeding" if feeding else ""
			position = home + Vector3(sin(t * 0.17) * 0.16, sin(t * 1.4) * 0.012, cos(t * 0.17) * 0.13)
			rotation.y = -t * 0.17
			proboscis.rotation.x = -0.5 + sin(t * (3.0 if feeding else 1.0)) * 0.4
			for i in appendages.size():
				appendages[i].rotation.z = sin(t * 8.0 + i * 0.65) * 0.45
		"hallucigenia":
			behavior_event = "cling"
			position = home + Vector3(sin(t * 0.06) * 0.025, 0.0, cos(t * 0.06) * 0.025)
			for i in appendages.size():
				appendages[i].rotation.x = sin(t * 3.4 + i) * 0.16
		"olenoides":
			var feeding := fmod(t, 13.0) > 8.0
			behavior_event = "feeding" if feeding else ""
			if not feeding:
				position = home + Vector3(sin(t * 0.05) * 0.18, 0.0, cos(t * 0.05) * 0.16)
				rotation.y = -t * 0.05
			for i in appendages.size():
				appendages[i].rotation.y = sin(t * 7.0 + i * 0.5) * 0.28
		"mudunraveler":
			if burrow_pending:
				burrow_delay -= delta
				visual.position.y = 0.06 + sin(t * 55.0) * 0.02
				if burrow_delay <= 0.0:
					burrow_pending = false
					rest_remaining = 15.0
					behavior_event = "burrow"
					visual.position.y = -0.09
					return true
			elif rest_remaining > 0.0:
				visual.position.y = lerpf(visual.position.y, -0.05 if rest_remaining > 5.0 else 0.0, delta)
				behavior_event = "burrow" if rest_remaining > 10.0 else ""
			elif is_instance_valid(observer) and global_position.distance_to(observer.global_position) < 3.0 and bool(observer.get("sprinting")):
				burrow_pending = true
				burrow_delay = 0.75
			else:
				behavior_event = ""
				visual.rotation.y = sin(t * 1.5) * 0.06
	return false

func _build_opabinia() -> void:
	var body := Art.material(Color("b65b49"))
	var fin := Art.material(Color(0.38, 0.75, 0.76, 0.82), 0.0, true)
	var eye := Art.material(Color("172e35"))
	for i in 11:
		var z := -0.27 + i * 0.057
		Art.ellipsoid(visual, Vector3(0, 0, z), Vector3(0.24, 0.16, 0.09), body)
		for side in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 0.10, 0, z)
			visual.add_child(pivot)
			Art.triangle(pivot, Vector3.ZERO, Vector3(side * 0.18, -0.01, 0.055), Vector3(side * 0.10, 0.025, -0.04), fin)
			appendages.append(pivot)
	Art.ellipsoid(visual, Vector3(0, 0.02, -0.35), Vector3(0.29, 0.20, 0.21), body)
	for i in 5:
		var p := Vector3((i - 2) * 0.055, 0.15 + (0.02 if i % 2 == 0 else 0.0), -0.38)
		Art.rod(visual, p - Vector3.UP * 0.09, p, 0.014, body)
		Art.ellipsoid(visual, p, Vector3.ONE * 0.043, eye)
	proboscis = Node3D.new()
	proboscis.position = Vector3(0, -0.01, -0.40)
	visual.add_child(proboscis)
	Art.rod(proboscis, Vector3.ZERO, Vector3(0, -0.07, -0.24), 0.025, body)
	for side in [-1.0, 1.0]:
		Art.rod(proboscis, Vector3(0, -0.07, -0.24), Vector3(side * 0.045, -0.08, -0.31), 0.011, body)
		Art.triangle(visual, Vector3(0, 0, 0.32), Vector3(side * 0.20, 0.04, 0.5), Vector3(0, 0.01, 0.46), fin)

func _build_hallucigenia() -> void:
	var flesh := Art.material(Color("dc9890"))
	var spine := Art.material(Color("ede4bc"))
	Art.ellipsoid(visual, Vector3(0, 0.17, 0), Vector3(0.12, 0.16, 0.95), flesh)
	Art.ellipsoid(visual, Vector3(0, 0.18, -0.48), Vector3(0.13, 0.15, 0.16), flesh)
	for i in 7:
		var z := -0.35 + i * 0.115
		for side in [-1.0, 1.0]:
			Art.rod(visual, Vector3(side * 0.04, 0.20, z), Vector3(side * 0.13, 0.61 - absf(z) * 0.3, z + 0.025), 0.025, spine, 0.001)
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 0.04, 0.16, z)
			visual.add_child(pivot)
			Art.rod(pivot, Vector3.ZERO, Vector3(side * 0.12, -0.16, 0.02), 0.018, flesh, 0.006)
			appendages.append(pivot)

func _build_olenoides() -> void:
	var shell := Art.material(Color("638f7c"))
	var ridge := Art.material(Color("bdd1a0"))
	var limb := Art.material(Color("795d44"))
	Art.ellipsoid(visual, Vector3(0, 0.11, -0.35), Vector3(0.65, 0.23, 0.38), shell)
	for i in 8:
		var z := -0.16 + i * 0.075
		var width := 0.57 - i * 0.042
		Art.ellipsoid(visual, Vector3(0, 0.10, z), Vector3(width, 0.18, 0.095), shell)
		Art.ellipsoid(visual, Vector3(0, 0.19, z), Vector3(0.13, 0.05, 0.08), ridge)
		for side in [-1.0, 1.0]:
			Art.rod(visual, Vector3(side * width * 0.4, 0.12, z), Vector3(side * (width * 0.6), 0.11, z + 0.10), 0.019, ridge, 0.001)
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 0.08, 0.07, z)
			visual.add_child(pivot)
			Art.rod(pivot, Vector3.ZERO, Vector3(side * width * 0.50, -0.07, 0.04), 0.015, limb)
			appendages.append(pivot)
	for side in [-1.0, 1.0]:
		Art.rod(visual, Vector3(side * 0.09, 0.06, -0.47), Vector3(side * 0.17, 0.08, -0.67), 0.008, limb)
		Art.rod(visual, Vector3(side * 0.06, 0.08, 0.41), Vector3(side * 0.08, 0.07, 0.70), 0.015, ridge, 0.001)

func _build_mud() -> void:
	var flesh := Art.material(Color("bdb080"))
	var dark := Art.material(Color("887654"))
	for i in 28:
		var angle := float(i) / 27.0 * TAU * 2.0
		var radius := 0.10 + i * 0.010
		var p := Vector3(cos(angle) * radius, 0.12 + sin(angle) * 0.04, sin(angle) * radius)
		Art.ellipsoid(visual, p, Vector3(0.19, 0.18, 0.19), flesh)
		if i % 2 == 0:
			for j in 3:
				Art.rod(visual, p, p + Vector3(cos(angle) * 0.18, -0.16, sin(angle) * 0.18 + j * 0.04), 0.014, dark, 0.003)
