extends Node3D
## Hand-authored routes with deterministic organic dressing. One unit is one metre.
## Layer 1 is real terrain and structures; creature shelters use their own layer.

const WORLD_SEED := 503171
const MAP_MIN := Vector2(-120.0, -190.0)
const MAP_MAX := Vector2(120.0, 60.0)
const TERRAIN_STEP := 3.0
const POD_ENTRY := Vector3(0, -2, -5)
const WRECK_CENTER := Vector3(0, -39.2, -133)

var environment: Environment
var _built := false
var _rng := RandomNumberGenerator.new()
var _rock_material: StandardMaterial3D
var _sand_material: ShaderMaterial
var _pod_light: OmniLight3D
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _particles: CPUParticles3D
var _last_underwater := false
var _last_depth := -100.0


func _ready() -> void:
	setup()


func setup() -> void:
	if _built:
		return
	_built = true
	_rng.seed = WORLD_SEED
	_rock_material = _material(Color("64766b"), 0.97)
	_sand_material = ShaderMaterial.new()
	_sand_material.shader = preload("res://assets/shaders/seabed.gdshader")
	_build_environment()
	_build_seabed()
	_build_rocks()
	_build_gardens()
	_build_pod()
	_build_wreck()
	_build_particles()


func floor_height(x: float, z: float) -> float:
	var depth := clampf(-z, 0.0, 155.0)
	var bottom := -10.0 - depth * 0.24
	bottom += sin(x * 0.095 + z * 0.061) * 1.0 + cos(z * 0.14) * 0.45
	bottom += sin(x * 0.25) * sin(z * 0.10) * 0.35
	# The shelter route is gently graded and never interrupted by decorative rocks.
	var side := smoothstep(87.0, 120.0, absf(x))
	var far_edge := smoothstep(155.0, 190.0, -z)
	var rear_edge := smoothstep(20.0, 60.0, z)
	var edge := maxf(side, maxf(far_edge, rear_edge))
	return lerpf(bottom, -1.8 + sin(x * 0.13 + z * 0.17) * 1.4, edge)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var underwater := camera.global_position.y < -0.12
	var depth := maxf(0.0, -camera.global_position.y)
	if underwater != _last_underwater or absf(depth - _last_depth) > 0.15:
		_last_underwater = underwater
		_last_depth = depth
		_set_water_environment(underwater, depth)


func set_low_particles(low: bool) -> void:
	if _particles != null:
		_particles.amount = 45 if low else 140


func _build_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("528e9e")
	sky_material.sky_horizon_color = Color("b6dcd3")
	sky_material.ground_bottom_color = Color("267b7e")
	sky_material.ground_horizon_color = Color("b6dcd3")
	sky_material.sun_angle_max = 12.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c4d2d1")
	environment.ambient_light_energy = 0.52
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_light_color = Color("178c91")
	environment.fog_light_energy = 0.7
	environment.fog_sun_scatter = 0.2
	environment.fog_sky_affect = 1.0
	var world_environment := WorldEnvironment.new()
	world_environment.name = "OceanEnvironment"
	world_environment.environment = environment
	add_child(world_environment)
	_set_water_environment(false)
	_sun = DirectionalLight3D.new()
	_sun.name = "Sunlight"
	_sun.rotation_degrees = Vector3(-52, -24, 0)
	_sun.light_color = Color("f4f1df")
	_sun.light_energy = 1.05
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 70.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(_sun)
	_fill = DirectionalLight3D.new()
	_fill.name = "ScatteredUnderwaterLight"
	_fill.rotation_degrees = Vector3(-15, 155, 0)
	_fill.light_color = Color("84b6c0")
	_fill.light_energy = 0.15
	add_child(_fill)
	var surface := PlaneMesh.new()
	surface.size = Vector2(290, 290)
	surface.subdivide_width = 48
	surface.subdivide_depth = 48
	var water_material := ShaderMaterial.new()
	water_material.shader = preload("res://assets/shaders/water_surface.gdshader")
	var water := _mesh(surface, water_material, Vector3(0, 0, -60))
	water.name = "BreathableWaterSurface"
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _set_water_environment(underwater: bool, depth: float = 0.0) -> void:
	# Slowly lose warm sunlight down the shelf, retaining enough fill to read
	# unlit creature silhouettes. No sudden biome or fog transition during a dive.
	var deep := smoothstep(10.0, 43.0, depth) if underwater else 0.0
	environment.fog_enabled = underwater
	environment.fog_density = lerpf(0.015, 0.023, deep) if underwater else 0.0
	environment.fog_light_color = Color("248c91").lerp(Color("14576b"), deep)
	environment.fog_light_energy = lerpf(0.68, 0.5, deep)
	environment.ambient_light_color = Color("c4d2d1").lerp(Color("659caa"), deep)
	environment.ambient_light_energy = lerpf(0.42, 0.32, deep) if underwater else 0.45
	environment.background_energy_multiplier = lerpf(0.72, 0.4, deep) if underwater else 1.0
	if _sun != null:
		_sun.light_energy = lerpf(0.82, 0.34, deep) if underwater else 1.05
		_sun.light_color = Color("f4f1df").lerp(Color("a5d2d5"), deep)
	if _fill != null:
		_fill.light_energy = lerpf(0.15, 0.17, deep)


func _build_seabed() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x_count := int((MAP_MAX.x - MAP_MIN.x) / TERRAIN_STEP)
	var z_count := int((MAP_MAX.y - MAP_MIN.y) / TERRAIN_STEP)
	for zi in range(z_count):
		for xi in range(x_count):
			var x := MAP_MIN.x + xi * TERRAIN_STEP
			var z := MAP_MIN.y + zi * TERRAIN_STEP
			var corners: Array[Vector2] = [Vector2(x, z), Vector2(x, z + TERRAIN_STEP), Vector2(x + TERRAIN_STEP, z), Vector2(x + TERRAIN_STEP, z + TERRAIN_STEP)]
			for index in [0, 2, 1, 2, 3, 1]:
				var p := corners[index]
				var color_mix := (sin(p.x * 0.105 + p.y * 0.06) + sin(p.y * 0.17)) * 0.12 + 0.4
				surface.set_color(Color("d7d0ba").lerp(Color("909a92"), color_mix).srgb_to_linear())
				surface.set_uv(p * 0.1)
				surface.add_vertex(Vector3(p.x, floor_height(p.x, p.y), p.y))
	surface.generate_normals()
	var terrain_mesh := surface.commit()
	var terrain := _mesh(terrain_mesh, _sand_material, Vector3.ZERO)
	terrain.name = "SculptedSeabed"
	_add_mesh_collision(terrain_mesh, Transform3D.IDENTITY, "SeabedCollision", false)


func _build_rocks() -> void:
	# Recognisable broken arch: an optional covered return shortcut, west of the route.
	var arch_z := -57.0
	var arch_floor := floor_height(-11.0, arch_z)
	_rock(Vector3(-16, arch_floor + 4, arch_z), Vector3(3.3, 6.2, 4.0))
	_rock(Vector3(-7.0, arch_floor + 3.5, arch_z - 2), Vector3(2.8, 5.5, 3.3))
	_rock(Vector3(-11.4, arch_floor + 8.5, arch_z), Vector3(7.0, 2.2, 3.0))
	_rock(Vector3(-19.0, arch_floor + 0.7, arch_z + 4), Vector3(4.2, 2.0, 4.5))
	# Staggered cover leaves both the middle approach and the eastern shelter route open.
	for p in [Vector2(-8, -77), Vector2(8, -87), Vector2(-7, -100), Vector2(7, -112), Vector2(-12, -126), Vector2(28, -72), Vector2(29, -94)]:
		_rock(Vector3(p.x, floor_height(p.x, p.y) + 2.2, p.y), Vector3(2.7, 4.0, 4.1))
	# Side reefs frame the basin and make the outward current visually legible.
	for index in range(56):
		var angle := float(index) / 56.0 * TAU
		var x := cos(angle) * 111.0
		var z := -64.0 + sin(angle) * 117.0
		_rock(Vector3(x, floor_height(x, z) + 3.0, z), Vector3(_rng.randf_range(7, 12), _rng.randf_range(7, 16), _rng.randf_range(6, 10)))
	for index in range(40):
		var x := _rng.randf_range(-68, 70)
		var z := _rng.randf_range(-153, 10)
		if _is_route(x, z):
			continue
		var radius := _rng.randf_range(0.8, 3.0)
		_rock(Vector3(x, floor_height(x, z) + radius * 0.3, z), Vector3(radius * 1.4, radius, radius))


func _is_route(x: float, z: float) -> bool:
	if absf(x) < 5.2:
		return true
	if z < -48.0 and z > -120.0 and x > 5.0 and x < 25.0:
		return true
	if z < -120.0 and z > -143.0 and absf(x) < 12.0:
		return true
	return false


func _rock(position_at: Vector3, dimensions: Vector3) -> void:
	var source := SphereMesh.new()
	source.radius = 1.0
	source.height = 2.0
	source.radial_segments = 9
	source.rings = 5
	var arrays := source.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index in range(vertices.size()):
		var v := vertices[index]
		var irregular := 1.0 + 0.11 * sin(v.x * 8.0 + v.z * 5.0) * cos(v.y * 7.0)
		vertices[index] = v * dimensions * irregular
	arrays[Mesh.ARRAY_VERTEX] = vertices
	# Recalculate normals after the organic displacement.
	var rock_mesh := ArrayMesh.new()
	rock_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := SurfaceTool.new()
	surface.create_from(rock_mesh, 0)
	surface.generate_normals()
	rock_mesh = surface.commit()
	var node := _mesh(rock_mesh, _rock_material, position_at)
	node.name = "ReefRock"
	_add_mesh_collision(rock_mesh, Transform3D(Basis.IDENTITY, position_at), "ReefCollision", true)


func _build_gardens() -> void:
	# Landmark one: a warm, asymmetric crown of hollow sea sponges.
	for index in range(7):
		var angle := index * 2.39
		var x := 10.0 + cos(angle) * 2.5
		var z := -44.0 + sin(angle) * 2.2
		_sponge(Vector3(x, floor_height(x, z), z), 0.75 + index * 0.05, 3.0 + (index % 3) * 1.15, Color("ca9367"), index == 3)
	# Small flat sponge at the hallucigenia observation site. It never buries the animal.
	_sponge(Vector3(4, floor_height(4, -27) - 0.12, -27), 0.48, 0.22, Color("b49288"), false)
	for p in [Vector2(-6, -18), Vector2(7, -23), Vector2(-6, -31), Vector2(7, -35), Vector2(-7, -42)]:
		for index in range(3):
			var x: float = p.x + index * 0.55
			var z: float = p.y + sin(index * 2.0) * 0.5
			_sponge(Vector3(x, floor_height(x, z), z), 0.28 + index * 0.09, 0.65 + index * 0.46, Color("b58c61"), false)
	for index in range(78):
		var x := _rng.randf_range(-43, 47)
		var z := _rng.randf_range(-135, -9)
		if _is_route(x, z):
			continue
		var height := _rng.randf_range(0.65, 3.4)
		var color := Color("b69668").lerp(Color("945b62"), _rng.randf())
		_sponge(Vector3(x, floor_height(x, z), z), height * _rng.randf_range(0.16, 0.26), height, color, height > 2.6)
	# A few tall columns mark the corridor without overlapping the creature routes.
	for p in [Vector2(-13, -77), Vector2(30, -86), Vector2(-15, -105), Vector2(32, -119)]:
		_sponge(Vector3(p.x, floor_height(p.x, p.y), p.y), 1.35, 7.2, Color("ab8c69"), true)
	_build_small_growth()


func _sponge(at: Vector3, radius: float, height: float, color: Color, collision: bool) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 6
	var sides := 12
	var phase := _rng.randf_range(0, TAU)
	for inside in [false, true]:
		for ring in range(rings):
			for side in range(sides):
				var corners: Array[Vector3] = []
				for offset in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					var t := float(ring + offset.y) / rings
					var angle := float(side + offset.x) / sides * TAU
					var shape := (0.65 + 0.3 * sin(t * PI * 0.65)) * radius
					shape *= 0.69 if inside else 1.0
					shape *= 1.0 + sin(angle * 3.0 + phase) * 0.09
					var h := t * height + sin(angle * 3.0 + phase) * height * 0.035 * t
					corners.append(Vector3(cos(angle) * shape + t * t * radius * 0.3, h, sin(angle) * shape))
				var order: Array = [0, 1, 2, 1, 3, 2] if inside else [0, 2, 1, 1, 2, 3]
				for index in order:
					surface.set_color((color.darkened(0.23) if inside else color).srgb_to_linear())
					surface.add_vertex(corners[index])
	# Rolled lip connects the outside to the hollow interior, making the cup readable.
	for side in range(sides):
		var corners: Array[Vector3] = []
		for offset in [Vector2(0, 1), Vector2(1, 1), Vector2(0, 0.69), Vector2(1, 0.69)]:
			var angle: float = (side + offset.x) / sides * TAU
			var shape: float = (0.65 + 0.3 * sin(PI * 0.65)) * radius * offset.y * (1.0 + sin(angle * 3.0 + phase) * 0.09)
			corners.append(Vector3(cos(angle) * shape + radius * 0.3, height + sin(angle * 3.0 + phase) * height * 0.035, sin(angle) * shape))
		for index in [0, 1, 2, 1, 3, 2]:
			surface.set_color(color.lightened(0.2).srgb_to_linear())
			surface.add_vertex(corners[index])
	surface.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := surface.commit()
	var node := _mesh(mesh, material, at)
	node.name = "HollowSponge"
	if collision:
		_add_mesh_collision(mesh, Transform3D(Basis.IDENTITY, at), "SpongeCollision", true)


func _build_small_growth() -> void:
	var pebble := SphereMesh.new()
	pebble.radius = 0.28
	pebble.height = 0.24
	pebble.radial_segments = 6
	pebble.rings = 3
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = pebble
	multimesh.instance_count = 850
	for index in range(multimesh.instance_count):
		var x := _rng.randf_range(-60, 60)
		var z := _rng.randf_range(-148, 6)
		var basis := Basis.IDENTITY.scaled(Vector3(_rng.randf_range(0.4, 1.8), _rng.randf_range(0.4, 1.2), _rng.randf_range(0.5, 2.0)))
		multimesh.set_instance_transform(index, Transform3D(basis, Vector3(x, floor_height(x, z) + 0.04, z)))
		multimesh.set_instance_color(index, Color("b8ad86").lerp(Color("5d8472"), _rng.randf()).srgb_to_linear())
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	var growth := MultiMeshInstance3D.new()
	growth.name = "ScatteredShellsAndMicrobialMats"
	growth.multimesh = multimesh
	growth.material_override = material
	add_child(growth)


func _build_pod() -> void:
	var shell := _material(Color("d4d8ce"), 0.65, 0.18)
	var trim := _material(Color("253e48"), 0.5, 0.45)
	var dark := _material(Color("16252e"), 0.82)
	var coral := _material(Color("bd674a"), 0.65)
	var cyan := _material(Color("72d7cc"), 0.3, 0.1, Color("43b9ba"))
	# The floor, ceiling, and wall segments correspond to their visible colliders.
	_box(Vector3(0, 0.15, 0), Vector3(8.5, 0.3, 7.5), trim, true)
	_box(Vector3(0, 4.05, 0), Vector3(8.5, 0.25, 7.5), shell, true)
	_box(Vector3(0, 2.1, 3.6), Vector3(8.3, 4.0, 0.3), shell, true)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 4.1, 2.1, 0), Vector3(0.28, 4.0, 7.2), shell, true)
		_box(Vector3(side * 3.92, 0.62, 0), Vector3(0.08, 0.18, 6.8), coral)
		_box(Vector3(side * 3.85, 3.35, 0), Vector3(0.09, 0.05, 6.9), cyan)
		_box(Vector3(side * 3.65, 0.65, 1.9), Vector3(0.62, 0.75, 2.4), dark, true)
		for z in [-2.8, 0.0, 2.8]:
			_box(Vector3(side * 3.87, 2.0, z), Vector3(0.17, 3.7, 0.14), trim)
	# A wide forward window frames the water; its frame is deliberately not a wall.
	_box(Vector3(0, 0.65, -3.62), Vector3(8.2, 0.8, 0.3), shell, true)
	_box(Vector3(0, 3.65, -3.62), Vector3(8.2, 0.65, 0.3), shell, true)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 3.8, 2.1, -3.62), Vector3(0.65, 2.5, 0.3), shell, true)
		_box(Vector3(side * 2.1, 2.15, -3.62), Vector3(0.07, 2.7, 0.15), trim, true)
	var glass := _material(Color(0.30, 0.63, 0.68, 0.13), 0.12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box(Vector3(0, 2.15, -3.65), Vector3(7.1, 2.1, 0.05), glass, true)
	# Fixed maintenance terminal, centred in the first-person starting view.
	_box(Vector3(0, 0.78, -2.2), Vector3(2.3, 1.2, 0.85), trim, true)
	_box(Vector3(0, 1.50, -2.23), Vector3(2.3, 0.85, 0.16), dark, true)
	_box(Vector3(0, 1.53, -2.135), Vector3(2.06, 0.59, 0.015), _material(Color("09393e"), 0.4, 0.0, Color("104d54")))
	for index in range(3):
		var color := cyan if index == 0 else coral
		_box(Vector3(-0.85, 1.7 - index * 0.18, -2.12), Vector3(0.08, 0.07, 0.02), color)
		_box(Vector3(0.04, 1.7 - index * 0.18, -2.12), Vector3(1.52 - index * 0.32, 0.035, 0.02), color)
	# Dive hatch and supply rack have a different silhouette from the terminal.
	_box(Vector3(-3.92, 1.5, -1.45), Vector3(0.09, 2.35, 1.35), dark)
	_box(Vector3(-3.84, 1.5, -1.45), Vector3(0.06, 2.02, 1.05), coral)
	_box(Vector3(-3.78, 1.5, -1.45), Vector3(0.08, 0.13, 0.7), cyan)
	for index in range(3):
		var tank := CapsuleMesh.new()
		tank.radius = 0.20
		tank.height = 1.25
		_mesh(tank, shell, Vector3(3.65, 1.38, -0.4 + index * 0.52))
	_box(Vector3(0, 3.84, -0.1), Vector3(3.7, 0.05, 0.3), cyan)
	_box(Vector3(0, -0.23, -4.55), Vector3(3.5, 0.2, 2.1), coral, true)
	_pod_light = OmniLight3D.new()
	_pod_light.position = Vector3(0, 3.2, -0.5)
	_pod_light.light_color = Color("c1e7dc")
	_pod_light.light_energy = 1.0
	_pod_light.omni_range = 8.0
	add_child(_pod_light)
	# Warm beacon remains visible underwater and identifies the return hatch.
	var beacon := SphereMesh.new()
	beacon.radius = 0.38
	beacon.height = 0.76
	_mesh(beacon, _material(Color("ffe6a2"), 0.3, 0.0, Color("edc46f")), Vector3(0, -0.7, -4.85))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, -1.5, -5)
	lamp.light_color = Color("e0efb5")
	lamp.light_energy = 3.0
	lamp.omni_range = 18.0
	add_child(lamp)
	# Anchor lines connect the floating shelter to the sea floor.
	for x in [-3.3, 3.3]:
		var bottom := floor_height(x, 2)
		_box(Vector3(x, bottom / 2, 2), Vector3(0.07, -bottom, 0.07), trim)


func _build_wreck() -> void:
	var hull := _material(Color("98aca6"), 0.71, 0.32)
	var frame := _material(Color("344f54"), 0.58, 0.55)
	var paint := _material(Color("b97356"), 0.77, 0.15)
	var light := _material(Color("c0cead"), 0.4, 0.0, Color("929b6d"))
	# The broken vessel is grounded on a low outcrop instead of floating above sand.
	_rock(Vector3(0, floor_height(0, -133) + 0.1, -133), Vector3(4.7, 3.3, 6.8))
	_box(WRECK_CENTER, Vector3(9.0, 0.45, 12.0), hull, true)
	_box(WRECK_CENTER + Vector3(-4.4, 1.4, 0), Vector3(0.35, 2.8, 12), hull, true)
	_box(WRECK_CENTER + Vector3(4.4, 1.0, -2), Vector3(0.35, 2.0, 8), hull, true)
	_box(WRECK_CENTER + Vector3(0, 1.4, -6), Vector3(9, 2.8, 0.35), frame, true)
	for z in [-5.3, -1.5, 3.0]:
		for side in [-1.0, 1.0]:
			_box(WRECK_CENTER + Vector3(side * 4.1, 2.4, z), Vector3(0.22, 4.5, 0.25), frame, true)
		# No roof over the unit: both routes can reach it without a one-way collision gap.
		_box(WRECK_CENTER + Vector3(-2.7, 4.55, z), Vector3(3.0, 0.2, 0.25), frame, true)
	_box(WRECK_CENTER + Vector3(-4.61, 1.6, 0), Vector3(0.04, 0.37, 10.7), paint)
	_box(WRECK_CENTER + Vector3(0, 1.35, 3), Vector3(2.1, 2.7, 1.6), frame, true)
	_box(WRECK_CENTER + Vector3(0, 2.72, 3), Vector3(1.8, 0.05, 0.9), light)
	for side in [-1.0, 1.0]:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.8
		cylinder.bottom_radius = 0.9
		cylinder.height = 3.5
		var engine := _mesh(cylinder, frame, WRECK_CENTER + Vector3(side * 3.1, 0.6, -7))
		engine.rotation.x = PI / 2
		_add_mesh_collision(cylinder, engine.transform, "EngineCollision", true)
	for index in range(9):
		var x := _rng.randf_range(-10, 10)
		var z := _rng.randf_range(-147, -122)
		if absf(x) < 5.5:
			continue
		_box(Vector3(x, floor_height(x, z) + 0.25, z), Vector3(1.8, 0.15, 2.8), hull, true)


func _build_particles() -> void:
	_particles = CPUParticles3D.new()
	_particles.name = "SuspendedSeaParticles"
	_particles.position = Vector3(0, -20, -67)
	_particles.amount = 140
	_particles.lifetime = 40.0
	_particles.preprocess = 25.0
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = Vector3(45, 17, 65)
	_particles.direction = Vector3(0.1, 0.3, -0.2)
	_particles.spread = 55.0
	_particles.gravity = Vector3.ZERO
	_particles.initial_velocity_min = 0.025
	_particles.initial_velocity_max = 0.15
	_particles.scale_amount_min = 0.015
	_particles.scale_amount_max = 0.04
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 4
	mesh.rings = 2
	mesh.material = _material(Color("a4cfc0"), 0.8, 0.0, Color("30473e"))
	_particles.mesh = mesh
	add_child(_particles)


func _material(color: Color, roughness: float = 0.8, metallic: float = 0.0, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 0.6
	return material


func _mesh(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	add_child(instance)
	return instance


func _box(at: Vector3, size: Vector3, material: Material, collision: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := _mesh(mesh, material, at)
	if collision:
		var shape := BoxShape3D.new()
		shape.size = size
		var body := StaticBody3D.new()
		body.name = "StructureCollision"
		body.position = at
		body.collision_layer = 1
		body.collision_mask = 0
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		add_child(body)
	return instance


func _add_mesh_collision(mesh: Mesh, placement: Transform3D, node_name: String, convex: bool) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.transform = placement
	body.collision_layer = 1
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	collider.shape = mesh.create_convex_shape() if convex else mesh.create_trimesh_shape()
	body.add_child(collider)
	add_child(body)
