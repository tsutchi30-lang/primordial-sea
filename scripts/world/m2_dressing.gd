extends Node3D
## Fixed M2 composition. Collision follows the visible walls, roofs and openings.
const Map = preload("res://data/biomes/world_map.gd")
const SEED := 220610
var world: Node3D
var _rng := RandomNumberGenerator.new()
var _wisps: Array[CPUParticles3D] = []
var _shell: StandardMaterial3D
var _dark_shell: StandardMaterial3D
var _metal: StandardMaterial3D
var _rust: StandardMaterial3D
var relay_anchor: Marker3D

static func bed_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
varying vec3 bed_position;
void vertex() { bed_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 p = bed_position.xz;
 float deposits = sin(p.x * .12 + sin(p.y * .065)) * sin(p.y * .093) * .5 + .5;
 float grain = fract(sin(dot(floor(p * 90.), vec2(127.1,311.7))) * 43758.5453);
 float graveyard = smoothstep(292., 322., -p.y);
 vec3 mud = mix(vec3(.37,.39,.37), vec3(.49,.48,.43), deposits);
 vec3 shell_bed = mix(vec3(.25,.29,.30), vec3(.37,.36,.33), deposits);
 ALBEDO = mix(mud, shell_bed, graveyard) * (.97 + grain * .055);
 NORMAL_MAP = normalize(vec3(sin(p.x * 3. + p.y) * .018, cos(p.y * 4.) * .012, 1.)) * .5 + .5;
 ROUGHNESS = .98; SPECULAR = .08;
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func setup(terrain: Node3D) -> void:
	world = terrain
	_rng.seed = SEED
	_shell = world._material(Color("aaa58f"), 0.92)
	_shell.vertex_color_use_as_albedo = true
	_shell.cull_mode = BaseMaterial3D.CULL_DISABLED
	_dark_shell = world._material(Color("767c74"), 0.95)
	_metal = world._material(Color("718d90"), 0.74, 0.3)
	_rust = world._material(Color("ae7255"), 0.9, 0.15)
	_plain_landmarks()
	_relay()
	_graveyard()
	_observation_shelf("wiwaxia_shelf", "WiwaxiaObservationShelf", false)
	_observation_shelf("marrella_shelf", "MarrellaObservationShelf", true)
	_outer_reefs()
	_shell_scatter()
	_low_mist()

func _at(x: float, z: float, height: float = 0.0) -> Vector3:
	return Vector3(x, world.floor_height(x, z) + height, z)

func _plain_landmarks() -> void:
	# A low observation terrace and two broken tusks frame the first safe web.
	for entry in [[-14.0, -180.0, Vector3(3.5, 1.3, 4.2)], [9.0, -186.0, Vector3(2.4, 2.8, 3.0)], [-22.0, -210.0, Vector3(2.8, 3.6, 4.2)]]:
		world._rock(_at(entry[0], entry[1], 0.3), entry[2])
	for index in 3:
		var at := _at(29 + index * 3, -243 - index * 2, 0.2)
		var mesh := PrismMesh.new()
		mesh.size = Vector3(1.4, 6.0 + index * 1.2, 4.5)
		_solid_mesh(mesh, _dark_shell, Transform3D(Basis(Vector3.UP, 0.22 * index), at + Vector3.UP * mesh.size.y * 0.5), "ThreeBrokenFins")
	# Container walls surround the human-made part, with an open front and roof.
	var at := Map.point("plain_wreck", world)
	world._box(at + Vector3(0, 0.05, 0), Vector3(6.0, 0.22, 4.5), _metal, true)
	for x in [-3.0, 3.0]:
		world._box(at + Vector3(x, 0.9, 0), Vector3(0.22, 1.8, 4.5), _metal, true)
		world._box(at + Vector3(x * 1.04, 1.18, 0), Vector3(0.05, 0.26, 4.0), _rust)
	world._box(at + Vector3(0, 0.75, -2.2), Vector3(6, 1.5, 0.22), _metal, true)
	world._box(at + Vector3(-3.8, 0.17, 3.1), Vector3(1.3, 0.15, 2.5), _rust, true)
	for x in [-20.0, 4.0]:
		world._rock(_at(x, -251 if x < 0 else -242, 1.2), Vector3(3.0, 3.8, 4.2))

func _relay() -> void:
	var at := _at(28, -275)
	var pale: StandardMaterial3D = world._material(Color("c9d4c4"), 0.6, 0.23)
	var dark: StandardMaterial3D = world._material(Color("314b54"), 0.74, 0.3)
	var glow: StandardMaterial3D = world._material(Color("d9dba7"), 0.5, 0.0, Color("d9dba7"))
	world._box(at + Vector3(0, 0.12, 0), Vector3(7.6, 0.3, 7.6), dark, true)
	world._box(at + Vector3(0, 4.6, 0), Vector3(7.6, 0.35, 7.6), pale, true)
	for x in [-3.6, 3.6]:
		world._box(at + Vector3(x, 2.35, 0), Vector3(0.3, 4.5, 7.4), pale, true)
	world._box(at + Vector3(0, 2.35, -3.6), Vector3(7.4, 4.5, 0.3), pale, true)
	# The visible 1.1 m doorway admits the diver and obstructs the 1.4 m mouth.
	for x in [-2.075, 2.075]:
		world._box(at + Vector3(x, 2.35, 3.6), Vector3(3.05, 4.5, 0.3), pale, true)
		world._box(at + Vector3(signf(x) * 0.68, 2.35, 3.81), Vector3(0.1, 3.9, 0.08), glow)
	world._box(at + Vector3(1.9, 1.6, -2.8), Vector3(1.3, 2.5, 0.55), dark, true)
	world._box(at + Vector3(1.9, 2.1, -2.49), Vector3(0.9, 0.68, 0.06), glow)
	relay_anchor = Marker3D.new()
	relay_anchor.name = "InteractionAnchor"
	relay_anchor.position = at + Vector3(1.9, 2.1, -2.44)
	add_child(relay_anchor)
	for x in [-1.6, -0.75]:
		var tank := CapsuleMesh.new()
		tank.radius = 0.3
		tank.height = 2.4
		_solid_mesh(tank, _metal, Transform3D(Basis.IDENTITY, at + Vector3(x, 1.45, -2.75)), "RelaySupplyCylinder")
	world._box(at + Vector3(0, 6.6, 0), Vector3(0.18, 4.0, 0.18), dark)
	var beacon := SphereMesh.new()
	beacon.radius = 0.48
	beacon.height = 0.96
	world._mesh(beacon, glow, at + Vector3(0, 8.7, 0)).name = "RelayFixedBeacon"
	var lamp := OmniLight3D.new()
	lamp.position = at + Vector3(0, 3.9, 1.3)
	lamp.light_color = Color("d4e7d3")
	lamp.light_energy = 1.35
	lamp.omni_range = 17.0
	add_child(lamp)
	for x in [21.0, 35.0]:
		world._rock(_at(x, -281, 1.4), Vector3(2.7, 4.2, 4.0))

func _graveyard() -> void:
	# The outer arch introduces shell interiors before the guarded main entrance.
	_canopy(Vector2(-10, -318), 7.5, 6.0, 8.0, "BrokenShellArch", false)
	_canopy(Vector2(25, -366), 13.0, 10.0, 34.0, "GreatEmptyShell", true)
	_canopy(Vector2(-35, -400), 11.0, 8.0, 14.0, "WesternFossilVault", false)
	_canopy(Vector2(-26, -410), 7.0, 4.8, 9.0, "FallenCompanionShell", false)
	# Wreckage is caught against the rear interior, with both pickup approaches open.
	var wreck := _at(25, -367)
	world._box(wreck + Vector3(-2.0, 0.4, 0), Vector3(1.2, 0.7, 3.1), _metal, true)
	world._box(wreck + Vector3(2.3, 1.0, -1.1), Vector3(0.4, 2.0, 2.5), _rust, true)
	world._box(wreck + Vector3(0, 0.1, -1.7), Vector3(4.2, 0.16, 1.0), _metal, true)
	# The crawler's low shell path rises from the southern mineral cache.
	var points: Array[Vector3] = []
	for z in [-379.0, -373.0]:
		for x in [35.5, 38.5]:
			points.append(_at(x, z, 0.08 if z < -376.0 else 2.0))
	var ramp := SurfaceTool.new()
	ramp.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0, 2, 1, 1, 2, 3]:
		ramp.add_vertex(points[index])
	ramp.generate_normals()
	_solid_mesh(ramp.commit(), _dark_shell, Transform3D.IDENTITY, "CrawlerLowShellRamp")
	for xz in [Vector2(-23, -337), Vector2(53, -325), Vector2(-5, -393), Vector2(53, -405)]:
		world._rock(_at(xz.x, xz.y, 0.6), Vector3(3.4, 4.5, 4.0))

func _canopy(center: Vector2, radius: float, height: float, length: float, label: String, side_opening: bool) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ribs := 24
	var spans := ceili(length / 2.0)
	for inside in [false, true]:
		for along in spans:
			for side in ribs:
				var z_middle := center.y - length * 0.5 + length * (along + 0.5) / spans
				# This actual hole is the always-open eastern shortcut, not a marker.
				if side_opening and side < 5 and z_middle > -370.0 and z_middle < -362.0:
					continue
				var vertices: Array[Vector3] = []
				for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
					var t: float = (along + corner.y) / spans
					var angle: float = (side + corner.x) / ribs * PI
					var z := center.y - length * 0.5 + length * t
					var ridge := sin(t * length * 1.18) * 0.17
					var thickness := 0.58 if inside else 0.0
					var x := center.x + cos(angle) * (radius + ridge - thickness)
					var y: float = world.floor_height(center.x, z) - 0.35 + sin(angle) * (height + ridge - thickness)
					vertices.append(Vector3(x, y, z))
				var order: Array = [0, 2, 1, 1, 2, 3] if inside else [0, 1, 2, 1, 3, 2]
				for index: int in order:
					var color := Color("999d91") if inside else Color("ddd1b2")
					color = color.darkened(0.06 + float(along % 3) * 0.035)
					surface.set_color(color.srgb_to_linear())
					surface.add_vertex(vertices[index])
	surface.index()
	surface.generate_normals()
	_solid_mesh(surface.commit(), _shell, Transform3D.IDENTITY, label)
	# Broken transverse edges reveal shell thickness around the real openings.
	for side_z in [-1.0, 1.0]:
		var z: float = center.y + side_z * length * 0.5
		for side in range(0, ribs, 2):
			var angle := float(side) / ribs * PI
			var at := Vector3(center.x + cos(angle) * radius, world.floor_height(center.x, z) - 0.3 + sin(angle) * height, z)
			var chip := SphereMesh.new()
			chip.radius = 0.32
			chip.height = 0.75
			chip.radial_segments = 6
			chip.rings = 3
			world._mesh(chip, _dark_shell, at)

func _observation_shelf(id: String, label: String, shell: bool) -> void:
	var top := Map.point(id, world)
	var shape := CylinderMesh.new()
	shape.top_radius = 1.3
	shape.bottom_radius = 1.65
	shape.height = 0.65
	shape.radial_segments = 18
	var material: StandardMaterial3D = _shell if shell else world._material(Color("b6b19b"), 0.98)
	_solid_mesh(shape, material, Transform3D(Basis.IDENTITY, top - Vector3.UP * 0.325), label)
	for index in 4:
		var marker := SphereMesh.new()
		marker.radius = 0.13
		marker.height = 0.12
		world._mesh(marker, _rust, top + Vector3(0.82 + index * 0.1, 0.06, -0.45 + index * 0.26))

func _outer_reefs() -> void:
	for z in range(-190, -440, -30):
		for side in [-1.0, 1.0]:
			world._rock(_at(side * 144, z, 2), Vector3(7, 10, 12))
	for x in range(-120, 121, 30):
		if absi(x) >= 70:
			world._rock(_at(x, -451, 2), Vector3(11, 11, 7))

func _shell_scatter() -> void:
	var source := PrismMesh.new()
	source.size = Vector3(1, 0.17, 1.2)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = source
	instances.instance_count = 240
	for index in instances.instance_count:
		var x := _rng.randf_range(-65, 70)
		var z := _rng.randf_range(-430, -176)
		var scale := _rng.randf_range(0.12, 0.5) * (1.7 if z < -298 else 1.0)
		var basis := Basis(Vector3.UP, _rng.randf_range(-PI, PI)).scaled(Vector3.ONE * scale)
		instances.set_instance_transform(index, Transform3D(basis, _at(x, z, 0.06)))
		instances.set_instance_color(index, Color("b6b199").lerp(Color("727d79"), _rng.randf()).srgb_to_linear())
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	var node := MultiMeshInstance3D.new()
	node.name = "M2FiniteShellDrifts"
	node.multimesh = instances
	node.material_override = material
	add_child(node)

func _low_mist() -> void:
	var dust := SphereMesh.new()
	dust.radius = 1.0
	dust.height = 0.35
	dust.radial_segments = 6
	dust.rings = 3
	var material: StandardMaterial3D = world._material(Color(0.62, 0.69, 0.65, 0.075), 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust.material = material
	for center in [Vector2(-15, -201), Vector2(15, -231), Vector2(-18, -258), Vector2(20, -289)]:
		var particles := CPUParticles3D.new()
		particles.name = "LowBedHaze"
		particles.position = _at(center.x, center.y, 1.0)
		particles.amount = 18
		particles.lifetime = 24.0
		particles.preprocess = 12.0
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		particles.emission_box_extents = Vector3(8, 0.4, 8)
		particles.direction = Vector3(1, 0, -0.15)
		particles.spread = 8.0
		particles.gravity = Vector3.ZERO
		particles.initial_velocity_min = 0.04
		particles.initial_velocity_max = 0.12
		particles.scale_amount_min = 0.28
		particles.scale_amount_max = 0.75
		particles.mesh = dust
		add_child(particles)
		_wisps.append(particles)

func set_low_particles(low: bool) -> void:
	for particles in _wisps:
		particles.amount = 5 if low else 18

func _solid_mesh(mesh: Mesh, material: Material, placement: Transform3D, label: String) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	node.transform = placement
	add_child(node)
	var body := StaticBody3D.new()
	body.name = label + "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	body.transform = placement
	var collision := CollisionShape3D.new()
	var triangles := mesh.create_trimesh_shape()
	triangles.backface_collision = true
	collision.shape = triangles
	body.add_child(collision)
	add_child(body)
