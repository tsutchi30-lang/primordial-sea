extends RefCounted
## Deterministic procedural art. All units are metres; no external assets required.

static func material(colour: Color, emission: float = 0.0, transparent: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = colour
	result.roughness = 0.62
	if emission > 0.0:
		result.emission_enabled = true
		result.emission = Color(colour.r, colour.g, colour.b)
		result.emission_energy_multiplier = emission
	if transparent:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

static func ellipsoid(parent: Node3D, at: Vector3, size: Vector3, mat: Material, segments: int = 12) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = segments
	mesh.rings = 6
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	node.scale = size
	parent.add_child(node)
	return node

static func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material, tip: float = -1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if tip < 0.0 else tip
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 7
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	node.position = (a + b) * 0.5
	var axis := (b - a).normalized()
	if absf(axis.dot(Vector3.UP)) < 0.999:
		node.basis = Basis(Vector3.UP.cross(axis).normalized(), acos(clampf(Vector3.UP.dot(axis), -1.0, 1.0)))
	elif axis.y < 0.0:
		node.rotation.x = PI
	return node

static func box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = mat
	parent.add_child(node)
	return node

static func triangle(parent: Node3D, a: Vector3, b: Vector3, c: Vector3, mat: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = mat
	parent.add_child(node)
	return node

static func colliding_box(parent: Node3D, at: Vector3, size: Vector3, mat: Material, layer: int = 8) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = at
	parent.add_child(body)
	box(body, Vector3.ZERO, size, mat)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

static func colliding_ellipsoid(parent: Node3D, at: Vector3, size: Vector3, mat: Material, layer: int = 8) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = at
	parent.add_child(body)
	var visible_mesh := ellipsoid(body, Vector3.ZERO, size, mat, 20)
	var convex := visible_mesh.mesh.create_convex_shape()
	var points := convex.points
	for i in points.size():
		points[i] *= size
	convex.points = points
	var collision := CollisionShape3D.new()
	collision.shape = convex
	body.add_child(collision)
	return body

static func colliding_capsule(parent: Node3D, at: Vector3, height: float, radius: float, mat: Material, layer: int = 8) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = at
	parent.add_child(body)
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 4
	var visible_mesh := MeshInstance3D.new()
	visible_mesh.mesh = mesh
	visible_mesh.material_override = mat
	body.add_child(visible_mesh)
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	return body
