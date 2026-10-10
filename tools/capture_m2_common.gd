extends RefCounted
## Shared replay steering only. Position is never written by this controller.
const Controls = preload("res://scripts/player/controls.gd")
const WorldMap = preload("res://data/biomes/world_map.gd")

static func look(player, point: Vector3, weight := 1.0) -> void:
	var direction: Vector3 = (point - player.camera.global_position).normalized()
	player.rotation.y = lerp_angle(player.rotation.y, atan2(-direction.x, -direction.z), minf(weight, 1.0))
	player.camera.rotation.x = lerp_angle(player.camera.rotation.x, asin(clampf(direction.y, -0.996, 0.996)), minf(weight, 1.0))

static func drive(player, target: Vector3, sprint := false, top_speed := 2.6) -> void:
	var speed := 4.5 if sprint else 2.8
	var desired: Vector3 = ((target - player.global_position) * 1.7).limit_length(top_speed) / speed
	var forward: Vector3 = -player.camera.global_basis.z
	var right: Vector3 = player.camera.global_basis.x
	var flat := Vector3(forward.x, 0, forward.z).normalized()
	var ahead := desired.dot(flat) / maxf(0.15, Vector2(forward.x, forward.z).length())
	var planar := Vector2(desired.dot(right), -ahead).limit_length(1.0)
	var magnitude := planar.length()
	if magnitude > 0.001:
		var deadzone := InputMap.action_get_deadzone("forward")
		planar = planar.normalized() * (deadzone + (1.0 - deadzone) * magnitude)
	axis("left", "right", planar.x)
	axis("forward", "back", planar.y)
	axis("descend", "ascend", clampf(desired.y - forward.y * ahead, -1, 1))
	if sprint: Input.action_press("sprint")
	else: Input.action_release("sprint")

static func axis(negative: String, positive: String, value: float) -> void:
	Input.action_release(negative)
	Input.action_release(positive)
	if value < -0.001: Input.action_press(negative, -value)
	if value > 0.001: Input.action_press(positive, value)

static func arr(point: Vector3) -> Array:
	return [point.x, point.y, point.z]

static func tap(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)

static func pickup(game, id: String):
	for target in game.pickups:
		if target.kind == id: return target
	return null
