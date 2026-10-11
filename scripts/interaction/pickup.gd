extends Node3D

var kind := "metal"
var title := "金属片"
var available := true
var replenish := 0.0
var renewable := true
var source_id := ""
var being_carried := false
var home := Vector3.ZERO
var collection_time := 0.0
var mesh: MeshInstance3D
var marker: Label3D

func _ready() -> void:
	home = position
	if kind in ["nav", "damping_frame", "phase_regulator", "return_core"]:
		renewable = false
	mesh = MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = {"metal": Color("e5ac6a"), "repair_fiber": Color("d7ece1"), "shell_plate": Color("c4a48e"), "damping_frame": Color("f2ce88"), "phase_regulator": Color("9bbfff")}.get(kind, Color("73e7dc"))
	material.metallic = 0.65
	material.roughness = 0.3
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 0.35
	if kind in ["nav", "damping_frame", "phase_regulator", "return_core"]:
		var box := BoxMesh.new()
		box.size = Vector3(0.65, 0.4, 0.85)
		mesh.mesh = box
	elif kind == "bait":
		var sphere := SphereMesh.new()
		sphere.radius = 0.18
		sphere.height = 0.36
		mesh.mesh = sphere
	else:
		var prism := PrismMesh.new()
		prism.size = Vector3(0.6, 0.12, 0.38)
		mesh.mesh = prism
	mesh.material_override = material
	mesh.rotation_degrees = Vector3(10, 25, -15)
	add_child(mesh)
	if kind in ["nav", "damping_frame", "phase_regulator", "return_core"]:
		for x in [-0.25, 0.25]:
			var ring := MeshInstance3D.new()
			var tube := CylinderMesh.new()
			tube.top_radius = 0.07
			tube.bottom_radius = 0.07
			tube.height = 0.8
			ring.mesh = tube
			ring.position = Vector3(x, 0.1, 0)
			ring.material_override = material
			add_child(ring)
	if kind == "return_core":
		mesh.rotation = Vector3.ZERO
		for i in 7:
			var fin := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = 0.38 if i % 2 == 0 else 0.26
			disc.bottom_radius = disc.top_radius
			disc.height = 0.065
			disc.radial_segments = 12
			fin.mesh = disc
			fin.position.y = (i-3)*0.13
			fin.material_override = material
			add_child(fin)
	marker = Label3D.new()
	marker.font = load("res://assets/fonts/NotoSansCJK-Regular.ttc")
	marker.text = title
	marker.visible = false # The sole aimed-target hint belongs to the HUD.
	marker.font_size = 28
	marker.pixel_size = 0.008
	marker.modulate = material.albedo_color
	marker.position.y = 0.55
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.visibility_range_end = 9
	add_child(marker)

func set_available(value: bool) -> void:
	available = value
	visible = value
	if value:
		collection_time = 0
		scale = Vector3.ONE

func tick(delta: float) -> void:
	if collection_time > 0:
		collection_time = maxf(0,collection_time-delta)
		scale = Vector3.ONE*maxf(0.02,collection_time/0.28)
		position.y += delta*0.65
		if collection_time <= 0: hide()
	if being_carried:
		return
	if not available and renewable:
		replenish -= delta
		if replenish <= 0:
			set_available(true)

func take() -> void:
	set_available(false)
	if kind in ["nav","damping_frame","phase_regulator","return_core"]:
		collection_time = 0.28
		show()
		marker.hide()
	replenish = 90.0
