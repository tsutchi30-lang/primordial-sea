extends RefCounted
## Original deterministic meshes. Coordinates below are body-length units; the
## animal node applies its real metre scale. Static parts share one surface.

const Art = preload("res://scripts/creatures/creature_mesh.gd")

static func batch(parent: Node3D, parts: Array[Dictionary], colour: Color) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: Dictionary in parts:
		var mesh: Mesh = part.mesh
		surface.append_from(mesh, 0, part.transform)
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = Art.material(colour)
	node.visibility_range_end = 48.0
	parent.add_child(node)
	return node

static func oval(at: Vector3, size: Vector3, segments: int = 12) -> Dictionary:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = segments
	mesh.rings = 5
	return {"mesh": mesh, "transform": Transform3D(Basis.from_scale(size), at)}

static func rod(a: Vector3, b: Vector3, radius: float, tip: float = -1.0) -> Dictionary:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if tip < 0.0 else tip
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 6
	var axis := (b - a).normalized()
	var basis := Basis.IDENTITY
	if absf(axis.dot(Vector3.UP)) < 0.999:
		basis = Basis(Vector3.UP.cross(axis).normalized(), acos(clampf(Vector3.UP.dot(axis), -1.0, 1.0)))
	elif axis.y < 0.0:
		basis = Basis(Vector3.RIGHT, PI)
	return {"mesh": mesh, "transform": Transform3D(basis, (a + b) * 0.5)}

static func leaf(a: Vector3, b: Vector3, width: float, bulge: float = 0.025) -> Dictionary:
	# A closed, curved lance with thickness, rather than a flat transparent quad.
	var direction := (b - a).normalized()
	var side := direction.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.1:
		side = Vector3.RIGHT
	var mid := a.lerp(b, 0.50)
	var v: Array[Vector3] = [a, mid + side * width * 0.5, b, mid - side * width * 0.5,
		mid + Vector3.UP * bulge, mid - Vector3.UP * bulge * 0.3]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		for index: int in [i, (i + 1) % 4, 4, (i + 1) % 4, i, 5]:
			surface.add_vertex(v[index])
	surface.generate_normals()
	return {"mesh": surface.commit(), "transform": Transform3D.IDENTITY}

static func pivot(parent: Node3D, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = at
	parent.add_child(node)
	return node

static func wiwaxia(parent: Node3D) -> Dictionary:
	var flesh: Array[Dictionary] = [oval(Vector3(0, 0.04, 0), Vector3(0.63, 0.13, 0.93))]
	var belly := batch(parent, flesh, Color("c39c85"))
	var scales: Array[Dictionary] = []
	for row in 7:
		var z := -0.38 + row * 0.118
		var width := sqrt(maxf(0.0, 1.0 - pow(z / 0.55, 2.0))) * 0.34
		for i in 7:
			var angle := -PI * 0.44 + float(i) / 6.0 * PI * 0.88
			var x := sin(angle) * width
			var y := 0.07 + cos(angle) * 0.28
			scales.append(leaf(Vector3(x * 0.85, y, z - 0.08), Vector3(x * 1.07, y - 0.018, z + 0.11), 0.155, 0.024))
	batch(parent, scales, Color("83714f"))
	var spines: Array[Dictionary] = []
	for i in 7:
		var z := -0.31 + i * 0.098
		for side: float in [-1.0, 1.0]:
			var start := Vector3(side * 0.16, 0.27, z)
			var end := Vector3(side * (0.26 + absf(z) * 0.14), 0.66 + (1.0 - absf(z) * 2.0) * 0.22, z + 0.09)
			spines.append(rod(start, end, 0.024, 0.0015))
	batch(parent, spines, Color("d3c295"))
	var mouth := pivot(parent, Vector3(0, 0.015, -0.43))
	batch(mouth, [oval(Vector3.ZERO, Vector3(0.12, 0.065, 0.12))], Color("685149"))
	return {"belly": belly, "mouth": mouth, "appendages": [], "claws": []}

static func marrella(parent: Node3D) -> Dictionary:
	var shell: Array[Dictionary] = [oval(Vector3(0, 0.10, -0.31), Vector3(0.31, 0.16, 0.24))]
	for i in 26:
		var z := -0.21 + i * 0.023
		var width := 0.20 - i * 0.004
		shell.append(oval(Vector3(0, 0.08, z), Vector3(width, 0.11, 0.029), 8))
	batch(parent, shell, Color("aa765d"))
	var spines: Array[Dictionary] = []
	for side: float in [-1.0, 1.0]:
		var points: Array[Vector3] = [Vector3(side * 0.11, 0.13, -0.34), Vector3(side * 0.31, 0.15, -0.35),
			Vector3(side * 0.39, 0.12, -0.16), Vector3(side * 0.32, 0.10, 0.15)]
		for i in 3:
			spines.append(rod(points[i], points[i + 1], 0.025 - i * 0.005, 0.016 - i * 0.007))
		spines.append(rod(Vector3(side * 0.095, 0.15, -0.22), Vector3(side * 0.23, 0.13, 0.43), 0.027, 0.002))
		spines.append(rod(Vector3(side * 0.07, 0.07, -0.4), Vector3(side * 0.15, 0.06, -0.54), 0.01, 0.003))
		spines.append(leaf(Vector3(side * 0.08, 0.02, -0.32), Vector3(side * 0.18, 0.02, -0.40), 0.06, 0.005))
	batch(parent, spines, Color("cfccac"))
	var appendages: Array[Node3D] = []
	for i in 13:
		var pair := pivot(parent, Vector3(0, 0.035, -0.21 + i * 0.046))
		var limbs: Array[Dictionary] = []
		for subsegment in 2:
			var z := subsegment * 0.023
			for side: float in [-1.0, 1.0]:
				limbs.append(rod(Vector3(side * 0.06, 0, z), Vector3(side * 0.22, -0.02, z + 0.012), 0.008, 0.004))
				limbs.append(leaf(Vector3(side * 0.08, 0.03, z), Vector3(side * 0.21, 0.04, z + 0.065), 0.028, 0.003))
		batch(pair, limbs, Color("82a9a2"))
		appendages.append(pair)
	return {"appendages": appendages, "claws": [], "belly": null, "mouth": null}

static func anomalocaris(parent: Node3D) -> Dictionary:
	var body: Array[Dictionary] = []
	for i in 12:
		var z := -0.32 + i * 0.055
		var width := 0.28 - i * 0.015
		body.append(oval(Vector3(0, 0, z), Vector3(width, width * 0.72, 0.09)))
	body.append(oval(Vector3(0, 0.012, -0.34), Vector3(0.28, 0.21, 0.19)))
	batch(parent, body, Color("a66850"))
	var eye_stalks: Array[Dictionary] = []
	var eyes: Array[Dictionary] = []
	for side: float in [-1.0, 1.0]:
		eye_stalks.append(rod(Vector3(side * 0.08, 0.03, -0.38), Vector3(side * 0.20, 0.10, -0.38), 0.018, 0.012))
		eyes.append(oval(Vector3(side * 0.205, 0.102, -0.38), Vector3(0.06, 0.043, 0.045)))
	batch(parent, eye_stalks, Color("c89e72"))
	batch(parent, eyes, Color("233b3d"))
	var appendages: Array[Node3D] = []
	for i in 11:
		for side: float in [-1.0, 1.0]:
			var wing := pivot(parent, Vector3(side * (0.125 - i * 0.006), -0.015, -0.29 + i * 0.054))
			var reach := 0.22 - i * 0.008
			batch(wing, [leaf(Vector3.ZERO, Vector3(side * reach, -0.018, 0.10), 0.095, 0.014)], Color("c29271"))
			appendages.append(wing)
	var tail: Array[Dictionary] = []
	for i in 3:
		for side: float in [-1.0, 1.0]:
			tail.append(leaf(Vector3(side * 0.018, 0, 0.28 + i * 0.025), Vector3(side * (0.20 - i * 0.044), 0.07, 0.46 + i * 0.02), 0.072, 0.009))
	batch(parent, tail, Color("b88766"))
	var claws: Array[Node3D] = []
	for side: float in [-1.0, 1.0]:
		var claw := pivot(parent, Vector3(side * 0.074, -0.06, -0.39))
		var segments: Array[Dictionary] = []
		var previous := Vector3.ZERO
		for i in 14:
			var fraction := float(i + 1) / 14.0
			var next := Vector3(side * sin(fraction * PI) * 0.05, -sin(fraction * PI * 0.75) * 0.10, -fraction * 0.23)
			segments.append(rod(previous, next, 0.024 - fraction * 0.015, 0.021 - fraction * 0.014))
			if i % 2 == 0:
				segments.append(rod(next, next + Vector3(-side * 0.029, 0.038, 0.006), 0.006, 0.001))
			previous = next
		batch(claw, segments, Color("d1ae7d"))
		claws.append(claw)
	var mouth := pivot(parent, Vector3(0, -0.104, -0.30))
	batch(mouth, [oval(Vector3.ZERO, Vector3(0.115, 0.018, 0.115))], Color("473d3b"))
	var plates: Array[Dictionary] = []
	for i in 15:
		var angle := float(i) / 15.0 * TAU
		var broad_plate := i % 5 == 0
		plates.append(rod(Vector3(sin(angle) * 0.058, -0.009, cos(angle) * 0.058),
			Vector3(sin(angle) * (0.023 if broad_plate else 0.038), -0.013, cos(angle) * (0.023 if broad_plate else 0.038)), 0.014 if broad_plate else 0.006, 0.007 if broad_plate else 0.003))
	batch(mouth, plates, Color("d6bd91"))
	return {"appendages": appendages, "claws": claws, "mouth": mouth, "belly": null}
