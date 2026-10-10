extends Node3D
## Dedicated metre-scale GLB. Gameplay/physics remain owned by hogara.gd.
## All animation is explicit; no process callback, AnimationPlayer or shader TIME.

const ASSET: PackedScene = preload("res://assets/models/hogara/hogara.glb")
const HIP_POSITIONS: Array[Vector3] = [Vector3(-2.45, 3.25, -2.05), Vector3(2.45, 3.25, -2.05), Vector3(0, 3.25, 2.7)]
const REST_FEET: Array[Vector3] = [Vector3(-4, 0, -2.7), Vector3(4, 0, -2.7), Vector3(0, 0, 4.5)]
const MATERIALS: Dictionary = {
    "Hogara_Carapace": preload("res://assets/materials/hogara/carapace.tres"),
    "Hogara_Ivory": preload("res://assets/materials/hogara/ivory.tres"),
    "Hogara_Tissue": preload("res://assets/materials/hogara/tissue.tres"),
    "Hogara_Joint": preload("res://assets/materials/hogara/joint.tres"),
    "Hogara_Sail": preload("res://assets/materials/hogara/sail.tres"),
    "Hogara_Vein": preload("res://assets/materials/hogara/vein.tres"),
    "Hogara_Filter": preload("res://assets/materials/hogara/filter.tres"),
    "Hogara_Sand": preload("res://assets/materials/hogara/sand.tres")
}

var asset: Node3D
var sail: Node3D
var filters: Array[Node3D] = []
var ribs: Array[Node3D] = []
var limb_parts: Array[Dictionary] = []
var collision_meshes: Array[MeshInstance3D] = []
var _material_instances: Dictionary = {}
var _sail_base := Vector3.ZERO
var _phase: float = 0.0
var _built: bool = false

func _ready() -> void:
    build()

func build() -> void:
    if _built:
        return
    _built = true
    asset = ASSET.instantiate()
    asset.name = "DedicatedHogara"
    add_child(asset)
    for key: String in MATERIALS:
        _material_instances[key] = MATERIALS[key].duplicate()
    _configure_meshes(asset)
    sail = asset.find_child("SailRig", true, false) as Node3D
    _sail_base = sail.rotation
    for i in 12:
        filters.append(asset.find_child("Filter%02d" % i, true, false) as Node3D)
    for i in 18:
        ribs.append(asset.find_child("Rib%02d" % i, true, false) as Node3D)
    for i in 3:
        var parts: Dictionary = {}
        for part in ["Upper", "Joint", "Lower", "Foot", "Coxa"]:
            parts[part] = asset.find_child(part + str(i), true, false) as Node3D
        limb_parts.append(parts)

func _configure_meshes(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh_node := node as MeshInstance3D
        for surface in mesh_node.mesh.get_surface_count():
            var imported: Material = mesh_node.mesh.surface_get_material(surface)
            if imported != null and _material_instances.has(imported.resource_name):
                mesh_node.set_surface_override_material(surface, _material_instances[imported.resource_name])
        var id := String(mesh_node.name)
        if id == "Carapace" or (id.begins_with("Rib") and not id.begins_with("RibGrowth")) or id.begins_with("Upper") and not id.begins_with("UpperScutes") or id.begins_with("Lower") and not id.begins_with("LowerScutes") or id.begins_with("Joint") or id.begins_with("Foot"):
            collision_meshes.append(mesh_node)
        if id.begins_with("Sail"):
            mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for child in node.get_children():
        _configure_meshes(child)

func get_hip_positions() -> Array[Vector3]:
    return HIP_POSITIONS.duplicate()

func get_rest_feet() -> Array[Vector3]:
    return REST_FEET.duplicate()

func get_collision_meshes() -> Array[MeshInstance3D]:
    build()
    return collision_meshes

func get_exit_gaps() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for side in [-1.0, 1.0]:
        for z in [-2.55, -0.85, 0.85, 2.55]:
            result.append({"inside": Vector3(side * 2.55, 1.7, z), "outside": Vector3(side * 4.6, 1.7, z)})
        for x in [-1.7, 0.0, 1.7]:
            result.append({"inside": Vector3(x, 1.7, side * 3.0), "outside": Vector3(x, 1.7, side * 4.8)})
    return result

func set_limb_pose(index: int, hip: Vector3, knee: Vector3, foot: Vector3, foot_normal: Vector3) -> void:
    if not _built:
        build()
    if index < 0 or index >= limb_parts.size():
        return
    var parts: Dictionary = limb_parts[index]
    var upper_frame := _segment_basis(hip, knee)
    var ankle := foot + foot_normal.normalized() * 0.34
    parts.Upper.transform = Transform3D(upper_frame.scaled_local(Vector3(1, hip.distance_to(knee), 1)), hip)
    parts.Lower.transform = Transform3D(_segment_basis(knee, ankle).scaled_local(Vector3(1, knee.distance_to(ankle), 1)), knee)
    parts.Joint.transform = Transform3D(upper_frame, knee)
    parts.Coxa.transform = Transform3D(upper_frame, hip)
    var up := foot_normal.normalized()
    var forward := Vector3.FORWARD.slide(up).normalized()
    if forward.length_squared() < 0.1:
        forward = Vector3.BACK
    parts.Foot.transform = Transform3D(Basis(up.cross(forward).normalized(), up, forward), foot)

func _segment_basis(from: Vector3, to: Vector3) -> Basis:
    var along := (to - from).normalized()
    if along.length_squared() < 0.01:
        along = Vector3.UP
    var across := Vector3.RIGHT.slide(along).normalized()
    if across.length_squared() < 0.01:
        across = Vector3.FORWARD.slide(along).normalized()
    return Basis(across, along, across.cross(along).normalized())

func tick_visual(delta: float, age: float, rest_amount: float, warning_amount: float, body_acceleration: Vector3) -> void:
    if not _built or delta <= 0.0:
        return
    _phase += delta
    var target := _sail_base + Vector3(sin(age * 0.43) * 0.009 - body_acceleration.z * 0.013, sin(age * 0.31 + 0.7) * 0.006, sin(age * 0.38 + 1.4) * 0.010 + body_acceleration.x * 0.013)
    sail.rotation = sail.rotation.lerp(target, minf(1.0, delta * 1.4))
    for i in filters.size():
        var organ := filters[i]
        var rate := 0.63 + float(i % 4) * 0.11
        var amplitude := (0.055 + float(i % 3) * 0.009) * (1.0 - rest_amount * 0.40)
        var trailing := Vector3(
            sin(_phase * (rate * 0.73) + i * 0.91) * amplitude * 0.6 - clampf(body_acceleration.z * 0.020, -0.08, 0.08),
            0.0,
            sin(_phase * rate + i * 1.73) * amplitude + clampf(body_acceleration.x * 0.020, -0.08, 0.08))
        organ.rotation = organ.rotation.lerp(trailing, minf(1.0, delta * (1.8 + float(i % 3) * 0.25)))
    for rib in ribs:
        # Roots stay attached as the hanging plate draws upward for low resting posture.
        # hogara.gd mirrors these mesh transforms onto their exact triangle shapes.
        rib.scale.y = 1.0 - rest_amount * 0.18
    var vein := _material_instances["Hogara_Vein"] as StandardMaterial3D
    vein.emission_energy_multiplier = 0.12 * (1.0 - warning_amount * 0.70) * (1.0 - rest_amount * 0.40)
    var membrane := _material_instances["Hogara_Sail"] as ShaderMaterial
    membrane.set_shader_parameter("rest_amount", rest_amount)
