extends CharacterBody3D
const Art = preload("res://scripts/creatures/creature_mesh.gd")
signal event_started(event_id: String)
signal shell_shed(at: Vector3, ordinal: int)
signal hit_player(amount: float)
var species_id := "bladeworm"
var behavior_event := ""
var state := "swim"
var state_time := 0.0
var age := 0.0
var home := Vector3.ZERO
var manager: Node3D
var player: CharacterBody3D
var target_web: Node3D
var bait_position := Vector3.ZERO
var bait_cooldown := 0.0
var next_graze := 3.0
var next_molt := 90.0
var molts := 0
var grazed_count := 0
var defense_cooldown := 0.0
var leaves: Array[Node3D] = []
var visual_accumulator := 0.0

func setup(field: Node3D, at: Vector3, delay := 0.0) -> void:
	manager = field
	player = field.host.player
	position = at
	home = at
	next_graze += delay
	next_molt += delay
	collision_layer = 0
	collision_mask = 1 | 8
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.17
	collision.shape = shape
	add_child(collision)
	var body := Art.material(Color("626e61"))
	var blade := Art.material(Color("a8b592"))
	var edge := Art.material(Color("d8c89d"))
	Art.ellipsoid(self, Vector3.ZERO, Vector3(0.13, 0.12, 0.58), body)
	for i in 7:
		for side in [-1.0, 1.0]:
			var leaf := Node3D.new()
			leaf.position.z = -0.24 + float(i) * 0.08
			leaf.rotation.z = side * 0.24
			add_child(leaf)
			var tip := Vector3(side * (0.17 + sin(float(i) / 6.0 * PI) * 0.07), 0.015, 0.035)
			Art.triangle(leaf, Vector3(0, 0, -0.04), tip, Vector3(0, 0.025, 0.07), blade)
			Art.rod(leaf, Vector3(0, 0.005, -0.04), tip, 0.0045, edge, 0.002)
			leaves.append(leaf)

func observation_position() -> Vector3:
	return global_position

func _enter(next: String, event := "") -> void:
	state = next
	state_time = 0.0
	behavior_event = event
	if not event.is_empty():
		event_started.emit(event)

func tick(delta: float) -> void:
	if delta <= 0.0 or get_tree().paused:
		return
	age += delta
	state_time += delta
	next_graze -= delta
	next_molt -= delta
	bait_cooldown = maxf(0.0, bait_cooldown - delta)
	defense_cooldown = maxf(0.0, defense_cooldown - delta)
	var distance := global_position.distance_to(player.global_position)
	if state not in ["warning", "defend", "return"] and defense_cooldown <= 0.0 and distance < (1.25 if player.sprinting else 0.58):
		if manager.host.has_clear_path(global_position, player.global_position):
			_enter("warning", "defense")
	if state == "swim" and bait_cooldown <= 0.0:
		var lure: Variant = manager.host.nearest_bait(global_position)
		if lure is Vector3 and global_position.distance_to(lure) <= 9.0 and home.distance_to(lure) <= 12.0:
			bait_position = lure
			_enter("bait", "bait")
	match state:
		"swim":
			var wander := home + Vector3(sin(age * 0.24) * 0.85, sin(age * 0.45) * 0.15, cos(age * 0.24) * 0.7)
			_swim_toward(wander, 0.32, delta)
			if next_graze <= 0.0:
				target_web = manager.nearest_food_web(global_position)
				if is_instance_valid(target_web):
					_enter("approach")
				else:
					next_graze = 4.0
		"approach":
			if not is_instance_valid(target_web) or not target_web.intact or state_time > 12.0:
				_enter("return")
			elif _swim_toward(target_web.global_position + Vector3(0, 0, 0.24), 0.85, delta) < 0.35:
				_enter("graze")
		"graze":
			if state_time >= 1.6:
				if is_instance_valid(target_web) and global_position.distance_to(target_web.global_position) < 0.7 and target_web.sever("grazed"):
					grazed_count += 1
					_enter("finish", "web_grazed")
				else:
					_enter("return")
		"finish":
			if state_time > 2.0:
				_enter("return")
		"bait":
			_swim_toward(bait_position, 0.72, delta)
			if state_time >= 8.0 or home.distance_to(global_position) > 12.0:
				bait_cooldown = 22.0
				_enter("return")
		"warning":
			if distance > 2.5:
				defense_cooldown = 5.0
				_enter("return")
			elif state_time >= 0.8:
				if distance < 1.0 and manager.host.has_clear_path(global_position, player.global_position):
					hit_player.emit(8.0)
				defense_cooldown = 7.0
				_enter("defend", "defense")
		"defend":
			if state_time >= 1.0:
				_enter("return")
		"return":
			if _swim_toward(home, 0.65, delta) < 0.35 or state_time > 12.0:
				next_graze = 10.0
				_enter("swim")
	if next_molt <= 0.0 and molts < 3 and state == "swim":
		molts += 1
		next_molt = 90.0
		_enter("molt", "molt")
		shell_shed.emit(global_position, molts)
	if state == "molt" and state_time > 3.0:
		_enter("swim")
	visual_accumulator += delta
	if distance > 40.0 and visual_accumulator < 0.2:
		return
	visual_accumulator = 0.0
	for i in leaves.size():
		var side := -1.0 if i % 2 == 0 else 1.0
		var flare := 0.95 if state in ["warning", "defend"] else 0.48 if state == "graze" else sin(age * 4.0 - i * 0.7) * 0.22
		leaves[i].rotation.z = side * (0.24 + flare)

func _swim_toward(target: Vector3, speed: float, delta: float) -> float:
	var offset := target - global_position
	if offset.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-offset.x, -offset.z), minf(1.0, delta * 2.0))
		var hit := move_and_collide(offset.normalized() * minf(speed * delta, offset.length()))
		if hit:
			move_and_collide(offset.slide(hit.get_normal()).normalized() * speed * delta * 0.4)
	return global_position.distance_to(target)
