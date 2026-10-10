extends CharacterBody3D

const Controls = preload("res://scripts/player/controls.gd")
var camera: Camera3D
var lamp: SpotLight3D
var active := false
var in_pod := true
var sprinting := false
var breathing_air := false
var light_on := true
var sensitivity := 0.0025
var invert_y := false
var base_fov := 80.0
var camera_shake := 0.25
var zoom_fov := 80.0
var impulse := Vector3.ZERO

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 8
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.30
	shape.shape = sphere
	add_child(shape)
	camera = Camera3D.new()
	camera.near = 0.015
	camera.far = 260.0
	camera.fov = base_fov
	add_child(camera)
	camera.make_current()
	lamp = SpotLight3D.new()
	lamp.light_color = Color(0.68, 0.91, 1.0)
	lamp.light_energy = 1.15
	lamp.spot_range = 23.0
	lamp.spot_angle = 34.0
	lamp.shadow_enabled = false
	camera.add_child(lamp)
	lamp.position = Vector3(0.18, -0.12, 0)

func _unhandled_input(event: InputEvent) -> void:
	if active and not get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity)
		var direction := 1.0 if invert_y else -1.0
		camera.rotation.x = clampf(camera.rotation.x + event.relative.y * sensitivity * direction, deg_to_rad(-85), deg_to_rad(85))

func _physics_process(delta: float) -> void:
	if not active:
		return
	var input := Input.get_vector("left", "right", "forward", "back")
	var direction := camera.global_basis * Vector3(input.x, 0, input.y)
	if in_pod:
		direction.y = 0
	else:
		direction.y += Input.get_axis("descend", "ascend")
	direction = direction.limit_length(1.0)
	sprinting = Input.is_action_pressed("sprint") and direction.length_squared() > 0.01
	var speed := (4.5 if sprinting else 2.8) if not in_pod else 2.0
	var desired := direction * speed
	if not in_pod:
		# The peripheral current strengthens gradually and never teleports the diver.
		# It is a velocity field, not an increment per frame.
		desired.x += -signf(position.x) * maxf(0, absf(position.x) - 108) * 0.55
		desired.z += -maxf(0, position.z - 32) * 0.55 + maxf(0, -174 - position.z) * 0.55
	velocity = velocity.move_toward(desired, delta * 9.0)
	if not in_pod:
		if position.y > 0.8:
			velocity.y = minf(velocity.y, -maxf(0, position.y - 0.8) * 3)
	velocity += impulse
	impulse = impulse.move_toward(Vector3.ZERO, delta * 5)
	move_and_slide()
	update_air_state()
	camera.fov = lerpf(camera.fov, zoom_fov, minf(1.0, delta * 10))

func update_air_state() -> void:
	if in_pod or global_position.y > 0.3:
		breathing_air = true
	elif global_position.y < -0.3:
		breathing_air = false

func clear_input() -> void:
	Controls.release_all()
	velocity = Vector3.ZERO
	impulse = Vector3.ZERO
	sprinting = false
	zoom_fov = base_fov

func relocate(at: Vector3, pod: bool) -> void:
	clear_input()
	global_position = at
	in_pod = pod
	rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	update_air_state()

func toggle_light() -> void:
	light_on = not light_on
	lamp.visible = light_on

func apply_settings(settings: Dictionary) -> void:
	sensitivity = settings.get("sensitivity", 0.0025)
	invert_y = settings.get("invert_y", false)
	base_fov = settings.get("fov", 80.0)
	zoom_fov = base_fov
	camera_shake = settings.get("shake", 0.25)
