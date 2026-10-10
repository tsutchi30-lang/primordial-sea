extends Node3D
const Map = preload("res://data/biomes/world_map.gd")
const Web = preload("res://scripts/ecology/web_patch.gd")
const Gardener = preload("res://scripts/creatures/threadgardener.gd")
const Blade = preload("res://scripts/creatures/bladeworm.gd")
const Predator = preload("res://scripts/creatures/windoweater.gd")
const Small = preload("res://scripts/creatures/small_creature.gd")
const Controls = preload("res://scripts/player/controls.gd")
const Art = preload("res://scripts/creatures/creature_mesh.gd")
signal resource_drop(kind: String, at: Vector3, source_id: String)
signal hint(text: String)
signal observed_event(species_id: String, event_id: String)
var host: Node3D
var webs: Array[Node3D] = []
var gardeners: Array[Node3D] = []
var blades: Array[CharacterBody3D] = []
var predator: CharacterBody3D
var age := 0.0
var cut_web: Node3D
var cut_elapsed := 0.0
var _slow := false
var _contact_hint := false

func setup(ecosystem: Node3D) -> void:
	host = ecosystem
	var points: Array[Vector2] = [Map.WEB_LEARNING, Map.WEB_GRAZING, Map.WEB_TRAP]
	var names := ["learning", "grazing", "trap"]
	for group in points.size():
		var point := points[group]
		var center := _at(point, 1.8)
		for side in [-1.0, 1.0]:
			_anchor_rock(center + Vector3(side * 4.72, -0.55, 0))
		var gardener := Gardener.new()
		add_child(gardener)
		gardener.setup(center + Vector3(-4.65, 0.45, 0), center + Vector3(-4.48, 0, 0))
		gardeners.append(gardener)
		host.creatures.append(gardener)
		for panel in 3:
			var web := Web.new()
			add_child(web)
			web.setup(names[group] + "_" + str(panel), center + Vector3(float(panel - 1) * 3.0, 0, 0), group == 1 and panel == 1)
			web.gardener = gardener
			web.severed.connect(_web_severed)
			web.regrown.connect(_web_regrown)
			webs.append(web)
			host.creatures.append(web)
	for i in 2:
		var blade := Blade.new()
		add_child(blade)
		blade.setup(self, _at(Map.WEB_GRAZING + Vector2(-float(i) * 3.0, 4.0), 1.8), float(i) * 6.0)
		blade.event_started.connect(func(event: String): observed_event.emit("bladeworm", event))
		blade.hit_player.connect(host._on_player_hit)
		blade.shell_shed.connect(func(at: Vector3, ordinal: int): resource_drop.emit("shell_plate", at, "blade_%d_molt_%d" % [i, ordinal]))
		blades.append(blade)
		host.creatures.append(blade)
	predator = Predator.new()
	add_child(predator)
	var homes: Array[Vector3] = [_at(Map.PLAINS_PREDATOR_HOME, 2.0), _at(Map.PLAINS_PREDATOR_HOME + Vector2(4, 2), 2.0), _at(Map.PLAINS_PREDATOR_HOME + Vector2(-5, -3), 2.0)]
	predator.setup(host, host.player, homes)
	predator.web_field = self
	predator.hit_player.connect(host._on_player_hit)
	predator.event_started.connect(func(event: String): observed_event.emit("windoweater", event))
	host.predators.append(predator)
	host.creatures.append(predator)
	# An existing, real silt source beside the ambush gives a non-consumable clue.
	var mud := Small.new()
	add_child(mud)
	mud.setup("mudunraveler", _at(Map.PLAINS_PREDATOR_HOME + Vector2(0.8, 1), 0.20), 3.0)
	host.small_creatures.append(mud)
	host.creatures.append(mud)

func _at(point: Vector2, height: float) -> Vector3:
	return Vector3(point.x, host.world.floor_height(point.x, point.y) + height, point.y)

func _anchor_rock(at: Vector3) -> void:
	var rock := StaticBody3D.new()
	rock.name = "WebAnchorRock"
	rock.position = at
	rock.collision_layer = 1
	rock.collision_mask = 0
	add_child(rock)
	var mesh := Art.ellipsoid(rock, Vector3.ZERO, Vector3(0.45, 2.5, 0.52), Art.material(Color("7e8984")), 7)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.mesh.create_convex_shape()
	shape.transform = mesh.transform
	rock.add_child(shape)

func tick(delta: float) -> void:
	if delta <= 0.0 or get_tree().paused:
		return
	age += delta
	var predator_positions: Array[Vector3] = []
	for animal in host.predators:
		predator_positions.append(animal.global_position)
	for web in webs:
		web.tick(delta, host.player.global_position, predator_positions)
	for gardener in gardeners:
		gardener.tick(delta)
	for blade in blades:
		blade.tick(delta)
	_slow = false
	for web in webs:
		if web.touches(host.player.global_position, 0.30):
			_slow = true
	if _slow and not _contact_hint:
		_contact_hint = true
		hint.emit("粘糸で減速。%sでカッター、%s長押しで切断。" % [Controls.label("tool_2"), Controls.label("use_tool")])

func player_speed_scale() -> float:
	# Re-evaluate immediately after cutting, rather than retaining a stale frame.
	for web in webs:
		if web.touches(host.player.global_position, 0.30):
			return 0.55
	return 1.0

func contact_web(from: Vector3, to: Vector3, radius: float) -> Node3D:
	for web in webs:
		if web.intersects_motion(from, to, radius):
			return web
	return null

func nearest_food_web(at: Vector3) -> Node3D:
	var result: Node3D = null
	var best := 12.0
	for web in webs:
		if web.natural_food and web.intact and web.global_position.distance_to(at) < best and host.has_clear_path(at, web.global_position):
			best = web.global_position.distance_to(at)
			result = web
	return result

func cancel_cut() -> void:
	if is_instance_valid(cut_web):
		cut_web.cut_progress = 0.0
	cut_web = null
	cut_elapsed = 0.0

func cut_target(camera: Camera3D, delta: float, required_seconds: float) -> Dictionary:
	var result := {"target": null, "progress": 0.0, "completed": false}
	if delta <= 0.0 or get_tree().paused:
		return result
	var target: Node3D = null
	var best := 3.0
	var direction := -camera.global_basis.z
	for web in webs:
		var distance: float = web.ray_distance(camera.global_position, direction, 3.0)
		if distance >= 0.0 and distance <= best and host.has_clear_path(camera.global_position, camera.global_position + direction * maxf(distance, 0.03)):
			best = distance
			target = web
	if target != cut_web:
		cancel_cut()
		cut_web = target
	if not is_instance_valid(cut_web):
		return result
	cut_elapsed += delta
	cut_web.cut_progress = clampf(cut_elapsed / maxf(0.1, required_seconds), 0.0, 1.0)
	result.target = cut_web
	result.progress = cut_web.cut_progress
	if cut_elapsed >= required_seconds:
		result.completed = cut_web.sever("cutter")
		cancel_cut()
	return result

func _web_severed(web: Node3D, reason: String, generation: int) -> void:
	if reason in ["cutter", "grazed"]:
		resource_drop.emit("repair_fiber", web.global_position, "web_%s_generation_%d" % [web.patch_id, generation])
		var event := "web_cut" if reason == "cutter" else "web_grazed"
		web.gardener.note(event)
		observed_event.emit("threadgardener", event)

func _web_regrown(web: Node3D) -> void:
	web.gardener.note("weave")
	observed_event.emit("threadgardener", "weave")
