extends Node3D
## Authored rift solids. Doors are gaps between individual walls, never a convex
## collider spanning the ship. Geometry shares absolute points with gameplay.
const Map = preload("res://data/biomes/world_map.gd")
var world: Node3D
var streams: Array[MeshInstance3D] = []
var age := 0.0
var low_particles := false

func setup(terrain: Node3D) -> void:
	world = terrain
	name = "RingRift"
	var dark: StandardMaterial3D = world._material(Color("293b48"), 0.94)
	var edge: StandardMaterial3D = world._material(Color("617580"), 0.9)
	# Columns retain a vertical view gap and a broad western route. All have
	# visible, matching tapered collision surfaces and enough room to swim up.
	for row in [[Vector2(8,-481), 31.0, 3.0], [Vector2(-11,-507), 39.0, 4.5], [Vector2(48,-494), 42.0, 4.0], [Vector2(41,-519), 25.0, 3.6], [Vector2(-34,-483), 26.0, 3.0]]:
		var xz: Vector2 = row[0]
		var height: float = row[1]
		var pillar := CylinderMesh.new()
		pillar.top_radius = float(row[2]) * 0.65
		pillar.bottom_radius = row[2]
		pillar.height = height
		pillar.radial_segments = 9
		world.m2_dressing._solid_mesh(pillar, dark, Transform3D(Basis.IDENTITY, Vector3(xz.x, world.floor_height(xz.x,xz.y) + height * 0.5, xz.y)), "RiftRockColumn")
		for band in 4:
			var ledge := CylinderMesh.new()
			ledge.top_radius = float(row[2]) * (0.73 + band * 0.045)
			ledge.bottom_radius = ledge.top_radius + 0.18
			ledge.height = 0.45
			ledge.radial_segments = 9
			world._mesh(ledge, edge, Vector3(xz.x, world.floor_height(xz.x,xz.y) + height * (0.2 + band * 0.17), xz.y))
	var shelf := Map.ABSOLUTE_POINTS.rift_shelf
	world._box(shelf + Vector3(0,-2.6,2.5), Vector3(8,2,5), edge, true)
	for x in [-4.5,4.5]:
		world._rock(shelf + Vector3(x,-2,2), Vector3(2.0,3.5,3.5))
	_ship()
	_current_marks()

func _ship() -> void:
	var hull: StandardMaterial3D = world._material(Color("8199a0"), 0.65, 0.48)
	var dark: StandardMaterial3D = world._material(Color("293e4c"), 0.66, 0.5)
	var rust: StandardMaterial3D = world._material(Color("b98a61"), 0.8)
	var light: StandardMaterial3D = world._material(Color("a1e8df"), 0.32, 0.3, Color("74d6cf"))
	# 13 x 28 m interior, 6.5 m headroom. Northern doorway and eastern break
	# are 23.1 m apart and face different directions around a solid hull corner.
	world._box(Vector3(24,-271,-499), Vector3(13,0.5,28), dark, true)
	world._box(Vector3(24,-264,-499), Vector3(13,0.6,28), hull, true)
	world._box(Vector3(17.5,-267.5,-499), Vector3(0.5,7,28), hull, true)
	world._box(Vector3(30.5,-267.5,-494), Vector3(0.5,7,18), hull, true)
	world._box(Vector3(30.5,-267.5,-512), Vector3(0.5,7,2), hull, true)
	world._box(Vector3(30.5,-264.9,-508), Vector3(0.5,1.2,5), hull, true)
	world._box(Vector3(24,-267.5,-513), Vector3(13,7,0.5), hull, true)
	for x in [19.9,28.1]:
		world._box(Vector3(x,-267.5,-485), Vector3(4.8,7,0.5), hull, true)
	world._box(Vector3(24,-264.8,-485), Vector3(3.5,1.5,0.5), hull, true)
	# Hull ribs, sloped external bow plates and twin propulsion housings give the
	# vessel an artificial silhouette without blocking either authored opening.
	for z in [-489,-495,-501,-510]:
		for x in [17.12,30.88]:
			world._box(Vector3(x,-267.5,z), Vector3(0.26,6.4,0.32), rust)
		world._box(Vector3(24,-263.55,z), Vector3(13.6,0.22,0.32), rust)
	for x in [20.0,28.0]:
		var engine := CylinderMesh.new()
		engine.top_radius = 1.3
		engine.bottom_radius = 1.0
		engine.height = 4.0
		engine.radial_segments = 16
		world.m2_dressing._solid_mesh(engine,dark,Transform3D(Basis(Vector3.RIGHT, PI/2),Vector3(x,-268,-515)),"ResearchVesselThruster")
	for row in [[Vector3(22.05,-267.7,-484.6),Vector3(0.12,4.8,0.12)], [Vector3(25.95,-267.7,-484.6),Vector3(0.12,4.8,0.12)], [Vector3(30.85,-267.7,-505.45),Vector3(0.12,4.8,0.12)], [Vector3(30.85,-267.7,-510.6),Vector3(0.12,4.8,0.12)]]:
		world._box(row[0],row[1],light)
	for z in [-490,-498,-506]:
		world._box(Vector3(24,-263.6,z),Vector3(2.5,0.18,0.45),light)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(24,-266,z)
		lamp.light_color = Color("92c9d0")
		lamp.light_energy = 1.4
		lamp.omni_range = 12
		add_child(lamp)
	# Low consoles leave a continuous central aisle and mark the extraction bay.
	for z in [-491,-496]:
		world._box(Vector3(19,-270,z),Vector3(1.8,1.2,2.8),dark,true)
		world._box(Vector3(19,-269.35,z),Vector3(1.2,0.08,1.5),light)
	world._box(Map.ABSOLUTE_POINTS.return_core + Vector3(0,-1.15,0),Vector3(2.4,0.55,2),dark,true)

func _current_marks() -> void:
	var mat: StandardMaterial3D = world._material(Color("91b9bc"),0.65,0.05,Color("41646e"))
	for i in 28:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.65,0.026,0.05)
		var stream: MeshInstance3D = world._mesh(mesh, mat, Vector3.ZERO)
		stream.name = "CrossCurrentDrift"
		streams.append(stream)
	_update_streams()

func _process(delta: float) -> void:
	age += delta
	_update_streams()

func _update_streams() -> void:
	for i in streams.size():
		streams[i].visible = not low_particles or i % 3 == 0
		streams[i].position = Map.CROSS_CURRENT_CENTER + Vector3(fposmod(i*7.1+age*1.35,48.0)-24.0,sin(i*3.6)*11.0,sin(i*2.3)*3.5)

func set_low_particles(low: bool) -> void:
	low_particles = low
