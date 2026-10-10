extends Node3D
## Fossil-inspired morphology with explicitly fictional colours and behaviour.
## No damage, drops or player pursuit. Time comes only from the ecosystem.

const Form = preload("res://scripts/creatures/palaeo_form.gd")
var species_id: String = ""
var behavior_event: String = ""
var state: String = "forage"
var home := Vector3.ZERO
var age: float = 0.0
var phase: float = 0.0
var length_m: float = 0.04
var state_time: float = 0.0
var pending_delta: float = 0.0
var captures: int = 0
var target_prey: int = -1
var target := Vector3.ZERO
var blocked_time: float = 0.0
var visual := Node3D.new()
var anatomy: Dictionary = {}

func setup(id: String, at: Vector3, seed_phase: float = 0.0) -> void:
	species_id = id
	position = at
	home = at
	phase = seed_phase
	add_child(visual)
	match species_id:
		"wiwaxia":
			length_m = 0.04
			anatomy = Form.wiwaxia(visual)
		"marrella":
			length_m = 0.02
			anatomy = Form.marrella(visual)
		"anomalocaris":
			length_m = 0.8
			anatomy = Form.anomalocaris(visual)
			target = home + Vector3(2.3, 0.0, 0.0)
			state = "swim"
	visual.scale = Vector3.ONE * length_m

func observation_position() -> Vector3:
	return global_position + Vector3.UP * length_m * (0.25 if species_id == "wiwaxia" else 0.05)

func tick(delta: float, habitat: Node3D) -> void:
	if delta <= 0.0 or get_tree().paused:
		return
	pending_delta += delta
	var nearby: bool = global_position.distance_squared_to(habitat.host.player.global_position) < 900.0
	var period := (1.0 / 30.0 if species_id == "anomalocaris" else 1.0 / 20.0) if nearby else 0.5
	if pending_delta + 0.000001 < period:
		return
	delta = pending_delta
	pending_delta = 0.0
	age += delta
	state_time += delta
	if species_id == "anomalocaris":
		_swim(delta, habitat)
	else:
		_graze(delta)
	_animate()

func _graze(delta: float) -> void:
	var feeding := fmod(age + phase, 13.0) >= 7.0
	state = "feeding" if feeding else "crawl"
	behavior_event = "feeding" if feeding else ""
	if not feeding:
		# A sub-decimetre path entirely on the deliberately flat observation shelf.
		# Pausing to feed also pauses translation; no interpolation teleports.
		var circle := (age + phase) * 0.028
		var destination := home + Vector3(sin(circle), 0.0, cos(circle)) * 0.085
		var movement := destination - position
		position = position.move_toward(destination, delta * (0.004 if species_id == "wiwaxia" else 0.006))
		if movement.length_squared() > 0.000001:
			rotation.y = lerp_angle(rotation.y, atan2(-movement.x, -movement.z), minf(1.0, delta * 1.8))

func _swim(delta: float, habitat: Node3D) -> void:
	behavior_event = "prey_captured" if state == "capture" else ""
	match state:
		"swim":
			if position.distance_to(target) < 0.3 or state_time > 12.0:
				var angle := age * 0.11
				target = home + Vector3(sin(angle) * 3.7, sin(angle * 0.7) * 0.45, cos(angle) * 3.7)
				state_time = 0.0
			if fmod(age, 18.0) >= 4.0 and fmod(age, 18.0) < 13.0:
				target_prey = habitat.nearest_prey(global_position, home)
				if target_prey >= 0:
					state = "approach"
					state_time = 0.0
			_move(delta, target, 0.33, habitat)
		"approach":
			if state_time > 9.0 or not habitat.prey_available(target_prey):
				_begin_departure()
				return
			var food: Vector3 = habitat.prey_position(target_prey)
			# Front appendages reach 0.5m ahead of the body; close on the actual prey.
			_move(delta, food, 0.49, habitat)
			var capture_tip: Vector3 = to_global(Vector3(0, -0.115, -0.55) * length_m)
			if capture_tip.distance_to(food) < 0.17 and habitat.capture_prey(target_prey, capture_tip):
				state = "capture"
				state_time = 0.0
				captures += 1
				behavior_event = "prey_captured"
		"capture":
			if state_time >= 2.6:
				_begin_departure()
		"depart":
			_move(delta, target, 0.37, habitat)
			if state_time >= 7.0 or position.distance_to(target) < 0.4:
				state = "swim"
				state_time = 0.0

func _begin_departure() -> void:
	state = "depart"
	behavior_event = ""
	state_time = 0.0
	target_prey = -1
	var angle := age * 0.23
	target = home + Vector3(sin(angle) * 3.5, 0.2, cos(angle) * 3.5)

func _move(delta: float, destination: Vector3, speed: float, habitat: Node3D) -> void:
	var direction := destination - position
	if direction.length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 2.6))
	var before := global_position
	global_position = habitat.swim_step(global_position, destination, speed * delta)
	if global_position.distance_to(before) < 0.001:
		blocked_time += delta
	else:
		blocked_time = 0.0
	if blocked_time > 1.5:
		blocked_time = 0.0
		if state != "depart":
			_begin_departure()

func _animate() -> void:
	var t := age + phase
	match species_id:
		"wiwaxia":
			anatomy.belly.scale.x = 1.0 + sin(t * 3.6) * 0.035
			anatomy.mouth.scale.z = 1.0 + sin(t * (8.0 if state == "feeding" else 1.4)) * 0.24
			visual.rotation.z = sin(t * 1.8) * 0.012
		"marrella":
			for i in anatomy.appendages.size():
				var limb: Node3D = anatomy.appendages[i]
				limb.rotation.y = sin(t * (11.0 if state == "feeding" else 7.0) + i * 0.62) * 0.18
				limb.rotation.z = sin(t * 6.0 + i * 0.75) * 0.075
		"anomalocaris":
			var capture_amount := sin(clampf(state_time / 0.65, 0.0, 1.0) * PI * 0.5) if state == "capture" else 0.0
			for i in anatomy.appendages.size():
				var fin: Node3D = anatomy.appendages[i]
				var side := -1.0 if i % 2 == 0 else 1.0
				fin.rotation.z = sin(t * 7.0 + floorf(i * 0.5) * 0.58) * 0.26 * side
			for i in anatomy.claws.size():
				var claw: Node3D = anatomy.claws[i]
				claw.rotation.x = -capture_amount * 0.8 + sin(t * 1.7 + i) * 0.07
				claw.rotation.z = capture_amount * (0.18 if i == 0 else -0.18)
			anatomy.mouth.scale.x = 1.0 + sin(t * 10.0) * capture_amount * 0.18
