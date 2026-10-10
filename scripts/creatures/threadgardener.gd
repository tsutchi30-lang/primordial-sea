extends Node3D
const Art = preload("res://scripts/creatures/creature_mesh.gd")
var species_id := "threadgardener"
var behavior_event := ""
var age := 0.0
var event_remaining := 0.0
var plates: Array[Node3D] = []
var feeding_tip: Node3D

func setup(at: Vector3, thread_anchor: Vector3) -> void:
	position = at
	var shell := Art.material(Color("aaab83"))
	var tissue := Art.material(Color("6e656d"))
	Art.ellipsoid(self, Vector3.ZERO, Vector3(0.19, 0.22, 0.22), tissue)
	for i in 5:
		var plate := Node3D.new()
		plate.rotation.z = float(i) * TAU / 5.0
		add_child(plate)
		# A tapered cupped plate with a pale raised margin, one of five petals.
		Art.triangle(plate, Vector3(-0.035, 0.05, 0), Vector3(0.035, 0.05, 0), Vector3(0.09, 0.18, 0.025), shell)
		Art.triangle(plate, Vector3(-0.035, 0.05, 0), Vector3(0.09, 0.18, 0.025), Vector3(0, 0.25, 0.075), shell)
		Art.triangle(plate, Vector3(-0.035, 0.05, 0), Vector3(0, 0.25, 0.075), Vector3(-0.09, 0.18, 0.025), shell)
		Art.rod(plate, Vector3(0, 0.06, -0.008), Vector3(0, 0.23, 0.07), 0.009, tissue, 0.003)
		plates.append(plate)
	feeding_tip = Art.ellipsoid(self, Vector3(0, 0, -0.07), Vector3.ONE * 0.045, Art.material(Color("e4cf9f")))
	Art.rod(self, Vector3(0.12, 0, 0), thread_anchor - at, 0.006, shell, 0.003)

func observation_position() -> Vector3:
	return global_position

func note(event: String) -> void:
	behavior_event = event
	event_remaining = 3.0

func tick(delta: float) -> void:
	if delta <= 0.0 or get_tree().paused:
		return
	age += delta
	event_remaining = maxf(0.0, event_remaining - delta)
	if event_remaining <= 0.0:
		behavior_event = "feed" if fmod(age, 16.0) > 12.0 else ""
	for i in plates.size():
		plates[i].rotation.x = sin(age * 0.75 + float(i) * 0.7) * 0.08 + (0.30 if behavior_event == "feed" else 0.0)
	feeding_tip.position.z = -0.07 + sin(age * 3.0) * (0.032 if behavior_event == "feed" else 0.005)
