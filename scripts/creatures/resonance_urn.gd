extends Node3D
## Local vibration, one-second warning, and finite, identified sound propagation.
const Art = preload("res://scripts/creatures/creature_mesh.gd")
const WARNING_SECONDS := 1.0
const REST_SECONDS := 12.0
const STIMULUS_RADIUS := 3.0
const PROPAGATION_RADIUS := 9.0
const MAX_HOPS := 2
signal resonated(source: Node3D, stimulus_id: int, hop: int, expires_at: float)
var species_id := "resonance_urn"
var behavior_event := ""
var state := "idle"
var state_time := 0.0
var age := 0.0
var sounds_emitted := 0
var seen_stimuli: Dictionary = {}
var pending: Dictionary = {}
var membranes: Array[MeshInstance3D] = []
var ring: MeshInstance3D
var membrane_material: StandardMaterial3D
var ring_material: StandardMaterial3D
var last_sound_age := -100.0

func setup(at: Vector3, phase: float = 0.0) -> void:
	position = at
	age = phase
	var shell := Art.material(Color("958e6f"))
	var inner := Art.material(Color("434e47"))
	membrane_material = Art.material(Color(0.46, 0.73, 0.65, 0.68), 0.12, true)
	for i in 3:
		var colony := Node3D.new()
		colony.position = Vector3((i - 1) * 0.30, 0, sin(i * 2.0) * 0.13)
		var scale_factor: float = [0.74, 1.0, 0.82][i]
		colony.scale = Vector3.ONE * scale_factor
		add_child(colony)
		_build_vase(colony, shell)
		Art.ellipsoid(colony, Vector3(0, 0.54, 0), Vector3(0.24, 0.028, 0.24), inner, 14)
		var membrane := Art.ellipsoid(colony, Vector3(0, 0.585, 0), Vector3(0.28, 0.035, 0.28), membrane_material, 16)
		membranes.append(membrane)
		for rib in 8:
			var angle := rib * TAU / 8.0
			Art.rod(colony, Vector3(cos(angle) * 0.15, 0.12, sin(angle) * 0.15), Vector3(cos(angle) * 0.12, 0.56, sin(angle) * 0.12), 0.013, shell)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.44
	torus.outer_radius = 0.465
	torus.rings = 24
	torus.ring_segments = 6
	ring = MeshInstance3D.new()
	ring.mesh = torus
	ring_material = Art.material(Color(0.58, 0.84, 0.72, 0.0), 0.3, true)
	ring.material_override = ring_material
	ring.position.y = 0.45
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.visible = false

func _build_vase(parent: Node3D, material: Material) -> void:
	# A lathed hollow lip, bulbous chamber and tapered attachment, not a solid ball.
	var profile := [Vector2(0.075, 0), Vector2(0.14, 0.09), Vector2(0.23, 0.25), Vector2(0.22, 0.39), Vector2(0.14, 0.51), Vector2(0.16, 0.59), Vector2(0.12, 0.59), Vector2(0.10, 0.51)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in profile.size() - 1:
		for side in 18:
			var a := side * TAU / 18.0
			var b := (side + 1) * TAU / 18.0
			var p: Vector2 = profile[level]
			var q: Vector2 = profile[level + 1]
			var vertices := [Vector3(cos(a) * p.x, p.y, sin(a) * p.x), Vector3(cos(b) * p.x, p.y, sin(b) * p.x), Vector3(cos(b) * q.x, q.y, sin(b) * q.x), Vector3(cos(a) * q.x, q.y, sin(a) * q.x)]
			for index in [0, 2, 1, 0, 3, 2]:
				surface.add_vertex(vertices[index])
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = material
	parent.add_child(mesh)

func observation_position() -> Vector3:
	return global_position + Vector3.UP * 0.49

func receive_stimulus(stimulus_id: int, hop: int, expires_at: float, now: float) -> bool:
	if state != "idle" or hop > MAX_HOPS or expires_at <= now or seen_stimuli.has(stimulus_id):
		return false
	seen_stimuli[stimulus_id] = expires_at
	pending = {"id": stimulus_id, "hop": hop, "expires_at": expires_at}
	state = "warning"
	state_time = 0.0
	return true

func tick(delta: float, now: float) -> void:
	if delta <= 0.0 or get_tree().paused:
		return
	age += delta
	state_time += delta
	for id in seen_stimuli.keys():
		if float(seen_stimuli[id]) < now:
			seen_stimuli.erase(id)
	behavior_event = ""
	if state == "warning" and state_time >= WARNING_SECONDS:
		if float(pending.expires_at) > now:
			sounds_emitted += 1
			last_sound_age = age
			behavior_event = "urn_resonated"
			resonated.emit(self, int(pending.id), int(pending.hop), float(pending.expires_at))
		state = "rest"
		state_time = 0.0
		pending.clear()
	elif state == "rest" and state_time >= REST_SECONDS:
		state = "idle"
		state_time = 0.0
	var warning := clampf(state_time / WARNING_SECONDS, 0.0, 1.0) if state == "warning" else 0.0
	for i in membranes.size():
		membranes[i].scale.y = 0.035 + sin(age * 1.4 + i) * 0.012 + warning * 0.22
		membranes[i].position.y = 0.585 + warning * 0.07
	membrane_material.emission_energy_multiplier = 0.12 + warning * 0.34
	var since_sound := age - last_sound_age
	ring.visible = since_sound < 0.9
	if ring.visible:
		ring.scale = Vector3.ONE * (0.4 + since_sound * 2.6)
		ring_material.albedo_color.a = (1.0 - since_sound / 0.9) * 0.44
