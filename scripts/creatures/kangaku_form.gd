extends MeshInstance3D
## A single continuous 10.4 m band; arc-length integration keeps each segment
## 0.2 m while anterior curvature changes. No detached torus or scaling trick.
const LENGTH := 10.4
const STEPS := 52
const SIDES := 8
var centerline: Array[Vector3] = []
var curl := 0.0
var accumulator := 0.0
var body_material: StandardMaterial3D

func _ready() -> void:
	body_material = StandardMaterial3D.new()
	body_material.vertex_color_use_as_albedo = true
	body_material.roughness = 0.49
	body_material.metallic = 0.12
	body_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = body_material
	animate(1,0,0,false,true)

func animate(delta: float, target_curl: float, age: float, locked: bool, near: bool) -> void:
	curl = move_toward(curl,target_curl,delta*1.8)
	accumulator += delta
	if accumulator < (0.05 if near else 0.2): return
	accumulator = 0
	centerline.clear()
	var point := Vector3(curl*1.05,0,0)
	centerline.append(point)
	for i in STEPS:
		var s := (i+0.5)*LENGTH/STEPS
		var ring_tangent := Vector3(-sin(s/1.05),cos(s/1.05),0)
		var straight := Vector3(sin(s*0.9-age*1.7)*0.17,sin(s*0.55-age)*0.07,1).normalized()
		var anterior := 1.0-smoothstep(6.3,7.5,s)
		point += straight.lerp(ring_tangent,curl*anterior).normalized()*(LENGTH/STEPS)
		centerline.append(point)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for i in range(STEPS+1):
		var tangent := (centerline[mini(STEPS,i+1)]-centerline[maxi(0,i-1)]).normalized()
		var outward := Vector3(cos(i*LENGTH/STEPS/1.05),sin(i*LENGTH/STEPS/1.05),0)
		var normal := Vector3.RIGHT.lerp(outward,curl*(1.0-smoothstep(6.3,7.5,i*LENGTH/STEPS)))
		normal = (normal-tangent*normal.dot(tangent)).normalized()
		if normal.length_squared() < 0.1: normal = Vector3.UP.cross(tangent).normalized()
		var binormal := tangent.cross(normal).normalized()
		var taper := lerpf(1.0,0.08,pow(float(i)/STEPS,2.4))
		var rib := 1.0+0.08*cos(i*PI)
		var ring: Array[Vector3] = []
		for j in SIDES:
			var angle := TAU*j/SIDES
			ring.append(centerline[i]+normal*cos(angle)*0.35*taper*rib+binormal*sin(angle)*0.18*taper)
		rings.append(ring)
		# Solid comb teeth attach directly to the inward face of the anterior band.
		if i < 33 and i % 2 == 0:
			var root := centerline[i]-normal*0.32*taper
			var tip := root-normal*(0.26 if locked else 0.22)
			var color := Color("fff0c7") if locked else Color("d7be9a")
			for side in [-1.0,1.0]:
				_tri(surface,root+tangent*0.08+binormal*side*0.1,root-tangent*0.08+binormal*side*0.1,tip,color)
			_tri(surface,root+tangent*0.08+binormal*0.1,tip,root+tangent*0.08-binormal*0.1,color)
		if i > 8 and i % 3 == 0:
			for side in [-1.0,1.0]:
				var fin: Vector3 = centerline[i]+binormal*float(side)*(0.32+sin(age*2-i*0.2)*0.07)*taper
				_tri(surface,centerline[i]-tangent*0.18,centerline[i]+tangent*0.18,fin,Color("506e7c"))
	for i in STEPS:
		for j in SIDES:
			var color := Color("bca88c") if j in [3,4,5] else (Color("75939c") if i % 2 == 0 else Color("536f7b"))
			var k := (j+1)%SIDES
			_tri(surface,rings[i][j],rings[i+1][j],rings[i][k],color)
			_tri(surface,rings[i][k],rings[i+1][j],rings[i+1][k],color)
	surface.generate_normals()
	mesh = surface.commit()

func _tri(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	surface.set_color(color.srgb_to_linear())
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
