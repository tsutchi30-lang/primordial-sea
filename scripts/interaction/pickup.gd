extends Node3D

var kind := "metal"
var title := "金属片"
var available := true
var replenish := 0.0
var mesh: MeshInstance3D
var marker: Label3D

func _ready() -> void:
	mesh = MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("e5ac6a") if kind == "metal" else Color("73e7dc")
	material.metallic = 0.65
	material.roughness = 0.3
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 0.35
	if kind == "nav":
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
	if kind == "nav":
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
	marker = Label3D.new()
	marker.font = load("res://assets/fonts/NotoSansCJK-Regular.ttc")
	marker.text = "回収信号" if kind == "nav" else "採集可"
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

func tick(delta: float) -> void:
	if not available and kind != "nav":
		replenish -= delta
		if replenish <= 0:
			set_available(true)

func take() -> void:
	set_available(false)
	replenish = 90.0
