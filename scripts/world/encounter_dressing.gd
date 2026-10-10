extends RefCounted
## A composed clearing at the first Hogara turn, not a uniform prop scatter.
## Large solids stay outside both tested swim routes and the walking footprint.

static func build(world: Node3D) -> void:
	# Near cups frame the approach; lower growth leaves a view into the clearing.
	for group in [
		[Vector2(-7.8, -49.0), 0.82, Color("bda28a"), 4],
		[Vector2(26.5, -49.5), 1.1, Color("ab7c72"), 5],
		[Vector2(28.0, -61.0), 0.68, Color("c6aa7d"), 7],
		[Vector2(-8.0, -64.0), 0.54, Color("9b8574"), 4],
		[Vector2(27.5, -77.0), 0.6, Color("b99a78"), 5]
	]:
		var center: Vector2 = group[0]
		for i in int(group[3]):
			var angle := float(i) * 2.39996
			var radius := sqrt(float(i)) * 0.75
			var x := center.x + cos(angle) * radius
			var z := center.y + sin(angle) * radius * 0.72
			var height: float = group[1] * (1.0 + float(i % 3) * 0.48)
			world._sponge(Vector3(x, world.floor_height(x, z), z), height * 0.24, height, group[2], false)
	# Eroded banks anchor the right-hand cluster while the foreground remains open.
	for entry in [
		[Vector2(30.5, -54.0), Vector3(3.8, 1.35, 3.0)],
		[Vector2(28.8, -58.0), Vector3(2.0, 0.72, 2.7)],
		[Vector2(-11.0, -46.0), Vector3(2.1, 0.95, 3.0)]
	]:
		var at: Vector2 = entry[0]
		world._rock(Vector3(at.x, world.floor_height(at.x, at.y) + 0.25, at.y), entry[1])
	_shell_drift(world)
	_fossil_fans(world)

static func _shell_drift(world: Node3D) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 15004702
	var mesh := _shell_fragment()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.96
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = mesh
	instances.instance_count = 160
	var patches: Array[Vector2] = [Vector2(-4.8, -51.5), Vector2(23.8, -55.8), Vector2(5, -64), Vector2(22.5, -70.5)]
	for i in instances.instance_count:
		var center := patches[i % patches.size()]
		# Drift tails accumulate beside clusters; the unfilled regions are deliberate.
		var amount := pow(random.randf(), 1.6)
		var x := center.x + random.randf_range(-1.6, 1.6) * amount
		var z := center.y + random.randf_range(-4.0, 2.0) * amount
		var size := random.randf_range(0.13, 0.37)
		var basis := Basis(Vector3.UP, random.randf_range(-PI, PI))
		basis = basis.rotated(Vector3.RIGHT, random.randf_range(-0.18, 0.18))
		basis = basis.scaled(Vector3(size, size * 0.75, size * random.randf_range(0.65, 1.15)))
		instances.set_instance_transform(i, Transform3D(basis, Vector3(x, world.floor_height(x, z) + 0.025, z)))
		instances.set_instance_color(i, Color("d9ccb1").lerp(Color("998474"), random.randf() * 0.65).srgb_to_linear())
	var node := MultiMeshInstance3D.new()
	node.name = "EncounterShellDrifts"
	node.multimesh = instances
	node.material_override = material
	world.add_child(node)

static func _shell_fragment() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A shallow broken valve with curved growth ribs, open at its worn edge.
	for ring in 4:
		for side in 12:
			var points: Array[Vector3] = []
			for uv: Vector2 in [Vector2(0,0), Vector2(1,0), Vector2(0,1), Vector2(1,1)]:
				var radius := (float(ring) + uv.y) / 4.0
				var angle := (float(side) + uv.x) / 12.0 * PI * 1.6
				var height := sin(radius * PI) * 0.26 + sin(angle * 9.0) * 0.025 * radius
				points.append(Vector3(cos(angle) * radius, height, sin(angle) * radius))
			for index in [0, 2, 1, 1, 2, 3]:
				surface.add_vertex(points[index])
	surface.index()
	surface.generate_normals()
	return surface.commit()

static func _fossil_fans(world: Node3D) -> void:
	# Small rooted stalks share one curved blade mesh. No collision on fine fronds.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 10:
		var points: Array[Vector3] = []
		for uv: Vector2 in [Vector2(0,0), Vector2(1,0), Vector2(0,1), Vector2(1,1)]:
			var t := (float(segment) + uv.y) / 10.0
			var width := sin(t * PI) * 0.16 + 0.015
			points.append(Vector3((uv.x * 2.0 - 1.0) * width, t, t * t * 0.31))
		for index in [0, 2, 1, 1, 2, 3]:
			surface.set_color(Color("806659").lerp(Color("b6a07d"), points[index].y).srgb_to_linear())
			surface.add_vertex(points[index])
	surface.index()
	surface.generate_normals()
	var node := MultiMeshInstance3D.new()
	node.name = "EncounterRootedFronds"
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = surface.commit()
	instances.instance_count = 68
	for i in instances.instance_count:
		var angle := float(i) * 2.39996
		var cluster := 1.0 if i < 38 else -1.0
		var x := (25.7 if cluster > 0 else -6.5) + cos(angle) * float(i % 6) * 0.22
		var z := (-52.0 if cluster > 0 else -57.5) + sin(angle) * float(i % 6) * 0.25
		var size := 0.28 + float(i % 7) * 0.11
		var basis := Basis(Vector3.UP, angle).scaled(Vector3.ONE * size)
		instances.set_instance_transform(i, Transform3D(basis, Vector3(x, world.floor_height(x, z), z)))
	node.multimesh = instances
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	world.add_child(node)
