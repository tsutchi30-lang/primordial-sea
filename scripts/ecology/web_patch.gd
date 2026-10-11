extends Node3D
## One visible, cuttable section. Soft contact uses this same rectangular volume.
signal severed(web: Node3D, reason: String, generation: int)
signal regrown(web: Node3D)
var species_id := "threadgardener"
var behavior_event := ""
var patch_id := ""
var intact := true
var generation := 0
var regrow_remaining := 0.0
var event_remaining := 0.0
var half_size := Vector3(1.48, 1.4, 0.10)
var natural_food := false
var gardener: Node3D
var visual: MeshInstance3D
var boundary: MeshInstance3D
var loose_ends: MeshInstance3D
var cut_progress := 0.0
var material: StandardMaterial3D

func setup(id: String, at: Vector3, grazing := false) -> void:
	patch_id = id
	position = at
	natural_food = grazing
	material = StandardMaterial3D.new()
	material.albedo_color = Color("9fae9a")
	material.metallic_specular = 0.65
	material.roughness = 0.36
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Dense, irregular diagonal/catenary strands stay inside the same contact
	# section. No decorative hole exceeds the diver's 0.6 m diameter.
	for i in 10:
		var x := lerpf(-half_size.x,half_size.x,float(i)/9.0)
		var end_x := clampf(x+0.28*sin(i*2.3),-half_size.x,half_size.x)
		_curve(surface,Vector3(x,-half_size.y,0),Vector3(end_x,half_size.y,0),0.09,0.008)
	for i in 9:
		var y := lerpf(-half_size.y,half_size.y,float(i)/8.0)
		_curve(surface,Vector3(-half_size.x,y,0),Vector3(half_size.x,clampf(y+0.17*sin(i*1.7),-half_size.y,half_size.y),0),-0.10,0.008)
	_curve(surface,Vector3(-half_size.x,-half_size.y,0),Vector3(half_size.x,half_size.y,0),0.08,0.014)
	for i in 12:
		var x := sin(float(i) * 2.3) * half_size.x * 0.92
		var y := cos(float(i) * 1.7) * half_size.y * 0.92
		_strand(surface, Vector3(x - 0.025, y - 0.016, -0.012), Vector3(x + 0.025, y + 0.016, -0.012), 0.026)
	surface.generate_normals()
	visual = MeshInstance3D.new()
	visual.mesh = surface.commit()
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	var edges := SurfaceTool.new()
	edges.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		_strand(edges, Vector3(side * half_size.x, -half_size.y, 0), Vector3(side * half_size.x, half_size.y, 0), 0.012)
	edges.generate_normals()
	boundary = MeshInstance3D.new()
	boundary.mesh = edges.commit()
	boundary.material_override = material
	add_child(boundary)
	var remnants := SurfaceTool.new()
	remnants.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		for i in 7:
			var start := Vector3(side*half_size.x,lerpf(-1.1,1.2,float(i)/6),0)
			_curve(remnants,start,start+Vector3(-side*0.2,-0.17,0.03),-0.06,0.01)
	remnants.generate_normals()
	loose_ends = MeshInstance3D.new()
	loose_ends.mesh = remnants.commit()
	loose_ends.material_override = material
	loose_ends.hide()
	add_child(loose_ends)
	# Queryable volume, not a wall: a diver keeps every movement and tool input.
	var area := Area3D.new()
	area.name = "VisibleWebContact"
	area.collision_layer = 16
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = half_size * 2.0
	shape.shape = box
	area.add_child(shape)
	add_child(area)

func _curve(surface: SurfaceTool,a: Vector3,b: Vector3,sag: float,width: float) -> void:
	var previous := a
	for step in range(1,9):
		var t := float(step)/8.0
		var point := a.lerp(b,t)+Vector3(0,sin(t*PI)*sag,sin(t*PI)*0.025)
		_strand(surface,previous,point,width)
		previous = point

func _strand(surface: SurfaceTool, a: Vector3, b: Vector3, width: float) -> void:
	var side := (b - a).normalized().cross(Vector3.FORWARD) * width
	for point in [a - side, a + side, b + side, a - side, b + side, b - side]:
		surface.add_vertex(point)

func observation_position() -> Vector3:
	return global_position

func is_observable() -> bool:
	return intact or event_remaining > 0.0

func touches(at: Vector3, radius: float = 0.3) -> bool:
	if not intact:
		return false
	var local := to_local(at)
	var nearest := local.clamp(-half_size, half_size)
	return local.distance_squared_to(nearest) <= radius * radius

func intersects_motion(from: Vector3, to: Vector3, radius: float) -> bool:
	if not intact:
		return false
	# Sample an actual swept sphere in 8cm increments, including both ends. This
	# preserves the rounded corners of the contact shape, unlike an enlarged box.
	var count := maxi(1, ceili(from.distance_to(to) / 0.08))
	for i in range(count + 1):
		if touches(from.lerp(to, float(i) / count), radius):
			return true
	return false

func ray_distance(origin: Vector3, direction: Vector3, reach := 3.0) -> float:
	if not intact:
		return -1.0
	var local := to_local(origin)
	var ray := global_basis.inverse() * direction
	if absf(ray.z) < 0.001:
		return 0.0 if touches(origin, 0.32) else -1.0
	var distance := -local.z / ray.z
	if distance < -0.15 or distance > reach:
		return -1.0
	var point := local + ray * maxf(0.0, distance)
	if absf(point.x) <= half_size.x + 0.08 and absf(point.y) <= half_size.y + 0.08:
		return maxf(0.0, distance)
	return -1.0

func sever(reason: String) -> bool:
	if not intact:
		return false
	intact = false
	cut_progress = 0.0
	visual.visible = false
	loose_ends.show()
	regrow_remaining = 120.0
	event_remaining = 3.0
	behavior_event = "web_grazed" if reason == "grazed" else "web_cut" if reason == "cutter" else ""
	severed.emit(self, reason, generation)
	return true

func tick(delta: float, player_at: Vector3, predator_at: Array[Vector3]) -> void:
	if delta <= 0.0 or get_tree().paused:
		return
	event_remaining = maxf(0.0, event_remaining - delta)
	if event_remaining <= 0.0:
		behavior_event = ""
	if intact:
		material.albedo_color = Color("9fae9a").lerp(Color("ead29c"), cut_progress)
		return
	regrow_remaining = maxf(0.0, regrow_remaining - delta)
	if regrow_remaining > 0.0 or global_position.distance_to(player_at) < 4.0:
		return
	for at in predator_at:
		if global_position.distance_to(at) < 3.0:
			return
	generation += 1
	intact = true
	visual.visible = true
	loose_ends.hide()
	behavior_event = "weave"
	event_remaining = 3.0
	regrown.emit(self)
