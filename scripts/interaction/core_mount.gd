extends Node3D
const Art = preload("res://scripts/creatures/creature_mesh.gd")
var unlocked := false
var elapsed := 0.0
var progress := 0.0
var arms: Array[Node3D] = []
var metal: StandardMaterial3D
var contact: MeshInstance3D

func _ready() -> void:
	metal = Art.material(Color("bd946d"))
	for side in [-1.0,1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side*0.53,0,0)
		add_child(arm)
		Art.ellipsoid(arm,Vector3.ZERO,Vector3(0.12,0.62,0.16),metal)
		Art.ellipsoid(arm,Vector3(-side*0.21,0.45,0),Vector3(0.34,0.10,0.16),metal)
		arms.append(arm)
	contact = Art.ellipsoid(self,Vector3(0,0.49,0.1),Vector3(0.1,0.07,0.07),Art.material(Color("ffd6a0"),1.4))
	contact.hide()

func cancel_cut() -> void:
	elapsed = 0
	progress = 0
	contact.hide()

func cut(delta: float, seconds: float) -> bool:
	if unlocked or delta <= 0 or get_tree().paused:
		return false
	elapsed += delta
	progress = clampf(elapsed / seconds,0,1)
	contact.show()
	contact.scale = Vector3(0.1,0.07,0.07) * (0.7 + 0.3 * sin(elapsed*42))
	metal.albedo_color = Color("bd946d").lerp(Color("ffd8a8"),progress)
	if progress < 1.0:
		return false
	unlocked = true
	for i in arms.size():
		arms[i].rotation.z = -0.7 if i == 0 else 0.7
	cancel_cut()
	return true

func reset_mount(is_world: bool) -> void:
	visible = is_world
	if not is_world: return
	unlocked = false
	cancel_cut()
	metal.albedo_color = Color("bd946d")
	for arm in arms: arm.rotation = Vector3.ZERO
