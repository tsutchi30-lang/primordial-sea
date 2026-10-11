extends CharacterBody3D
## Mouth-centred local perception; fixed 3-D attacks and bounded encounters.
const Map = preload("res://data/biomes/world_map.gd")
const Form = preload("res://scripts/creatures/kangaku_form.gd")
const MOUTH_RADIUS := 0.58
const WINDUP := 1.6
const LOCK_AT := 0.9
const MAX_ENCOUNTER := 18.0
signal hit_player(amount: float)
signal event_started(event: String)
var species_id := "kangaku"
var behavior_event := ""
var state := "patrol"
var state_time := 0.0
var encounter_time := 0.0
var encounter_active := false
var dash_count := 0
var dash_distance := 0.0
var dash_direction := Vector3.FORWARD
var attack_hit := false
var locked := false
var last_seen := Vector3.ZERO
var home := Vector3.ZERO
var patrol_index := 0
var retreat_index := 0
var reacquire_remaining := 0.0
var stuck_time := 0.0
var age := 0.0
var feed_cooldown := 0.0
var prey: Node3D
var eaten_count := 0
var host: Node3D
var player: CharacterBody3D
var form: MeshInstance3D
var shapes: Array[CollisionShape3D] = []
var retreat_target := Vector3.ZERO
var ship_escape := Vector3.ZERO

func setup(manager: Node3D) -> void:
	host = manager
	player = host.host.player
	home = Vector3(15,-256,-501)
	position = Map.RIFT_PATROL[0]
	collision_layer = 4
	collision_mask = 1 | 8
	form = Form.new()
	add_child(form)
	# Body only collides with terrain, never pins the diver between moving parts.
	for i in 6:
		var collision := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.37 if i > 0 else 0.60
		collision.shape = sphere
		collision.position = Vector3(0,0,i*1.85)
		add_child(collision)
		shapes.append(collision)

func observation_position() -> Vector3:
	return global_position

func mouth_position() -> Vector3:
	return global_position

func sees_player(acquired := false) -> bool:
	if player.in_pod: return false
	var offset := player.global_position-mouth_position()
	var distance := offset.length()
	if distance > (16.0 if acquired else 8.0): return false
	# Input intent, not current-induced drift or camera rotation, is movement.
	if not acquired and player.swim_intent.length_squared() < 0.01: return false
	if not acquired and distance > 4.0 and (-global_basis.z).dot(offset.normalized()) < cos(deg_to_rad(70)):
		return false
	return host.host.has_clear_path(mouth_position(),player.global_position)

func _detect() -> bool:
	if reacquire_remaining > 0 or player.in_pod: return false
	var distance := mouth_position().distance_to(player.global_position)
	if sees_player(): return true
	return player.sprinting and player.swim_intent.length_squared() > 0.01 and distance <= 16.0 and host.host.has_clear_path(mouth_position(),player.global_position)

func tick(delta: float) -> void:
	if delta <= 0 or get_tree().paused: return
	age += delta
	state_time += delta
	reacquire_remaining = maxf(0,reacquire_remaining-delta)
	feed_cooldown = maxf(0,feed_cooldown-delta)
	if encounter_active:
		encounter_time += delta
		if encounter_time >= MAX_ENCOUNTER or global_position.distance_to(home) > 44.0:
			_begin_retreat()
	var visible_player := encounter_active and sees_player(true)
	if visible_player and not locked: last_seen = player.global_position
	match state:
		"patrol":
			if _detect():
				encounter_active = true
				encounter_time = 0
				dash_count = 0
				prey = null
				last_seen = player.global_position
				_enter("attention")
			else:
				prey = host.food_for(mouth_position()) if feed_cooldown <= 0 else null
				if is_instance_valid(prey):
					last_seen = prey.global_position
					_enter("forage")
				else:
					if _swim(Map.RIFT_PATROL[patrol_index],1.65,delta) or stuck_time > 2.0:
						patrol_index = (patrol_index+1)%Map.RIFT_PATROL.size()
						stuck_time = 0
		"forage":
			if _detect():
				encounter_active = true
				encounter_time = 0
				dash_count = 0
				prey = null
				last_seen = player.global_position
				_enter("attention")
			elif not is_instance_valid(prey) or state_time > 7.0:
				_begin_retreat()
			else:
				last_seen = prey.global_position
				if mouth_position().distance_to(last_seen) < 7.0 and host.host.has_clear_path(mouth_position(),last_seen):
					_enter("windup")
				else: _swim(last_seen,1.8,delta)
		"attention":
			_face(last_seen,delta*2.0)
			if not visible_player: _enter("search")
			elif state_time >= 0.65: _enter("windup")
		"investigate":
			_swim(last_seen,1.5,delta)
			if _detect():
				encounter_active = true
				encounter_time = 0
				dash_count = 0
				last_seen = player.global_position
				_enter("attention")
			elif state_time >= 2.5: _begin_retreat()
		"windup":
			if not locked:
				if is_instance_valid(prey): last_seen = prey.global_position
				if encounter_active and not visible_player:
					_enter("search")
				else:
					_face(last_seen,delta*2.8)
					if state_time >= LOCK_AT:
						locked = true
						dash_direction = -global_basis.z
						behavior_event = "locked"
						event_started.emit("locked")
			if state == "windup" and state_time >= WINDUP:
				var clear: bool = host.host.has_clear_path(mouth_position(),last_seen) and (not encounter_active or sees_player(true))
				if clear and not test_move(global_transform,dash_direction*0.65):
					dash_distance = 0
					attack_hit = false
					if encounter_active: dash_count += 1
					_enter("dash")
				else: _enter("recover")
		"dash":
			var before := mouth_position()
			var dash_delta := minf(delta,maxf(0,1.4-(state_time-delta)))
			var motion := (dash_direction*9.0+Map.current_at(global_position))*dash_delta
			motion = motion.limit_length(maxf(0,12.0-dash_distance))
			var collision := move_and_collide(motion)
			var after := mouth_position()
			dash_distance += before.distance_to(after)
			if not attack_hit:
				if encounter_active and _swept_contact(before,after,player.global_position,0.30):
					attack_hit = true
					hit_player.emit(35.0)
				elif is_instance_valid(prey) and _swept_contact(before,after,prey.global_position,0.6):
					prey.consume()
					eaten_count += 1
					attack_hit = true
					feed_cooldown = 35
					_enter("feeding")
			if state == "dash" and (collision or state_time >= 1.4 or dash_distance >= 12.0):
				_enter("recover")
		"feeding":
			if state_time >= 1.0: _enter("recover")
		"recover":
			_drift(delta)
			if state_time >= 4.0:
				if not encounter_active or dash_count >= 2: _begin_retreat()
				else: _enter("search")
		"search":
			if visible_player and dash_count < 2: _enter("attention")
			elif state_time >= 2.5: _begin_retreat()
			else: _swim(last_seen,0.75,delta)
		"retreat":
			# Retire above the hull/columns first when a straight route is blocked.
			if _swim(retreat_target,2.5,delta):
				reacquire_remaining = 10.0
				prey = null
				_enter("patrol")
			elif stuck_time >= 2.0:
				retreat_index = (retreat_index+1)%Map.RIFT_RETREATS.size()
				retreat_target = Map.RIFT_RETREATS[retreat_index]
				stuck_time = 0
	_update_visual(delta)

func stimulate(at: Vector3, radius: float) -> void:
	if state != "patrol" or encounter_active or reacquire_remaining > 0: return
	var distance := mouth_position().distance_to(at)
	# Walls attenuate vibration; a remembered location is never a live target.
	var reach := radius if host.host.has_clear_path(mouth_position(),at) else radius*0.35
	if distance <= reach:
		last_seen = at
		prey = null
		_enter("investigate")

func _begin_retreat() -> void:
	encounter_active = false
	locked = false
	prey = null
	retreat_index = (retreat_index+1)%Map.RIFT_RETREATS.size()
	retreat_target = Map.RIFT_RETREATS[retreat_index]
	stuck_time = 0
	ship_escape = Vector3.ZERO
	if global_position.y < -263 and global_position.x > 16.5 and global_position.x < 32 and global_position.z < -484 and global_position.z > -514:
		ship_escape = Vector3(24,-248,-470) if global_position.distance_to(Vector3(24,-268,-483)) < global_position.distance_to(Vector3(32,-268,-508)) else Vector3(43,-268,-508)
	_enter("retreat")

func _enter(next: String) -> void:
	state = next
	state_time = 0
	behavior_event = {"windup":"windup","dash":"dash","recover":"recover","feeding":"prey_captured","retreat":"retreat"}.get(next,"")
	if next != "dash": locked = false
	if not behavior_event.is_empty(): event_started.emit(behavior_event)

func _face(at: Vector3, amount: float) -> void:
	if global_position.distance_squared_to(at) < 0.001: return
	var direction := (at-global_position).normalized()
	var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP
	global_basis = global_basis.slerp(Basis.looking_at(direction,up),minf(1,amount)).orthonormalized()

func _swim(at: Vector3, speed: float, delta: float) -> bool:
	if global_position.distance_to(at) < 1.2:
		stuck_time = 0
		return true
	var target := at
	# Under the real roof, leave through an opening before climbing. Switching
	# retreat targets alone would otherwise repeatedly choose the same ceiling.
	if ship_escape != Vector3.ZERO and global_position.distance_to(ship_escape) < 1.2:
		ship_escape = Vector3.ZERO
	if state == "retreat" and ship_escape != Vector3.ZERO:
		# Back out without swinging the long tail through solid walls. Keep this
		# heading until the entire body is outside, then turn toward the refuge.
		if ship_escape.x == 24:
			target = Vector3(24,-268,-484) if global_position.z < -486 else ship_escape
		else:
			target = Vector3(global_position.x,-268,-508) if absf(global_position.z+508) > 0.8 else ship_escape
	elif not host.host.has_clear_path(global_position,at):
		target = Vector3(global_position.x,-235,global_position.z)
	if ship_escape == Vector3.ZERO: _face(target,delta*1.4)
	else: _face(global_position-(target-global_position),delta*1.4)
	var before := global_position
	var motion := (target-global_position).normalized()*speed + Map.current_at(global_position)
	move_and_collide(motion*delta)
	stuck_time = stuck_time + delta if before.distance_to(global_position) < speed*delta*0.12 else 0.0
	return false

func _drift(delta: float) -> void:
	move_and_collide(Map.current_at(global_position)*delta)

func _swept_contact(from: Vector3,to: Vector3,target: Vector3,radius: float) -> bool:
	var nearest := Geometry3D.get_closest_point_to_segment(target,from,to)
	return nearest.distance_to(target) <= MOUTH_RADIUS+radius and host.host.has_clear_path(nearest,target)

func _update_visual(delta: float) -> void:
	var curl := 1.0 if state in ["windup","dash","feeding"] else 0.0
	form.animate(delta,curl,age,locked or state == "dash",global_position.distance_to(player.global_position) < 70)
	if form.centerline.size() > 0:
		for i in shapes.size():
			var index := mini(form.centerline.size()-1,i*10)
			shapes[i].position = form.centerline[index]
