"""Original Hogara asset, authored as explicit surfaces. Blender 4.3.2.
Run: blender --background --factory-startup --python tools/art/generate_hogara.py
All design coordinates are Godot metres (Y up, head toward -Z).
No external models, images, plug-ins, or runtime Blender dependency.
"""
from pathlib import Path
import math, json, hashlib, random, sys
import bpy
import bmesh
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / 'assets/models/hogara'
TEXTURES = ROOT / 'assets/textures/hogara'
SEED = 50317115
random.seed(SEED)
np.random.seed(SEED)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for p in [MODEL, TEXTURES]: p.mkdir(parents=True, exist_ok=True)

def G(p): return (p[0], -p[2], p[1])
def node(name, parent=None, at=(0,0,0)):
    obj=bpy.data.objects.new(name,None)
    bpy.context.collection.objects.link(obj)
    obj.parent=parent
    obj.location=G(at)
    return obj

root=node('HogaraAsset')
body=node('Body',root)
sail_pivot=(0,4.35,-2.0)
sail=node('SailRig',body,sail_pivot)
filter_root=node('FilterRig',body)

# Small baked maps keep the exported material independent of Blender's node engine.
def save_image(name, rgba):
    h,w,_=rgba.shape
    image=bpy.data.images.new(name,width=w,height=h,alpha=True)
    image.pixels.foreach_set(np.asarray(rgba,dtype=np.float32).reshape(-1))
    image.filepath_raw=str(TEXTURES/(name+'.png'))
    image.file_format='PNG'
    image.save()
    return image

def maps(name, palette, n=1024, soft=False):
    yy,xx=np.mgrid[0:n,0:n].astype(np.float64)/n
    noise=np.random.default_rng(SEED+len(name)).normal(0,.008,(n,n))
    broad=(np.sin(xx*17+np.sin(yy*9)*1.2)+np.sin(xx*7-yy*14)+np.sin(xx*51+yy*37)*.15)/2.15
    growth=np.sin(yy*230+np.sin(xx*37)*1.6+np.sin(xx*11)*2)
    etched=np.maximum(0,growth-.70)**2
    pores=np.sin(xx*641+np.sin(yy*223))*np.sin(yy*581-xx*63)
    h=.035*broad+.012*growth+.009*pores+noise*.4
    wear=np.clip((np.sin(yy*52+np.sin(xx*12))-.8)*3,0,1)
    rgb=np.ones((n,n,4))
    for c in range(3):
        rgb[:,:,c]=np.clip(palette[c]+broad*.035+growth*.012-etched*.055+noise+wear*.06,0,1)
    albedo=save_image(name+'_albedo',rgb)
    rough=np.ones((n,n,4)); rough[:,:,:3]=np.clip((.53 if soft else .74)+broad[:,:,None]*.09+pores[:,:,None]*.02,.28,.95)
    rough_img=save_image(name+'_roughness',rough)
    gy,gx=np.gradient(h)
    normal=np.stack([-gx*n*.10,-gy*n*.10,np.ones_like(xx)],axis=-1)
    normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
    nn=np.ones((n,n,4)); nn[:,:,:3]=normal*.5+.5
    normal_img=save_image(name+'_normal',nn)
    return albedo,rough_img,normal_img

shell_maps=maps('carapace',(.32,.42,.35))
bone_maps=maps('ivory',(.63,.58,.43))
soft_maps=maps('tissue',(.33,.22,.19),512,True)

# The sail's alpha follows thickness. Vein stains and branching cells are baked,
# while the few primary ribs are real geometry that reads in silhouette.
n=1024
v,u=np.mgrid[0:n,0:n].astype(np.float64)/n
rays=(np.cos(u*math.pi*28+np.sin(v*13)*.045)**24)
branch=np.maximum(0,np.sin(u*137+v*59+np.sin(v*25))-.88)
cells=np.sin(u*211+np.sin(v*39)*2)*np.sin(v*153+u*29)
sail_rgba=np.zeros((n,n,4))
sail_rgba[:,:,0]=.40+.15*rays+.025*cells
sail_rgba[:,:,1]=.59+.12*rays+.019*cells
sail_rgba[:,:,2]=.53+.16*rays+.018*cells
sail_rgba[:,:,3]=np.clip(.29+.48*(1-v)**1.5+.18*rays+.20*branch,.26,.96)
sail_image=save_image('sail_thickness',sail_rgba)

materials={}
def material(name, colour, roughness, maps=None, alpha=False, emission=0):
    mat=bpy.data.materials.new(name)
    mat.use_nodes=True
    mat.diffuse_color=(*colour,1)
    bs=mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*colour,1)
    bs.inputs['Roughness'].default_value=roughness
    bs.inputs['Metallic'].default_value=0
    if emission:
        bs.inputs['Emission Color'].default_value=(*colour,1)
        bs.inputs['Emission Strength'].default_value=emission
    if maps:
        for image, socket, data in [(maps[0],'Base Color',False),(maps[1],'Roughness',True),(maps[2],'Normal',True)]:
            tex=mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=image
            if data: image.colorspace_settings.name='Non-Color'
            if socket=='Normal':
                norm=mat.node_tree.nodes.new('ShaderNodeNormalMap'); norm.inputs['Strength'].default_value=.45
                mat.node_tree.links.new(tex.outputs['Color'],norm.inputs['Color'])
                mat.node_tree.links.new(norm.outputs['Normal'],bs.inputs['Normal'])
            else: mat.node_tree.links.new(tex.outputs['Color'],bs.inputs[socket])
    if alpha:
        mat.surface_render_method='DITHERED'
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=sail_image
        mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
        mat.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha'])
        mat.use_backface_culling=False
    materials[name]=mat
    return mat
shell_mat=material('Hogara_Carapace',(.32,.42,.35),.74,shell_maps)
bone_mat=material('Hogara_Ivory',(.63,.58,.43),.65,bone_maps)
soft_mat=material('Hogara_Tissue',(.33,.22,.19),.54,soft_maps)
joint_mat=material('Hogara_Joint',(.13,.21,.19),.48)
sail_mat=material('Hogara_Sail',(.4,.59,.53),.43,alpha=True)
vein_mat=material('Hogara_Vein',(.48,.66,.58),.54,emission=.09)
filter_mat=material('Hogara_Filter',(.46,.31,.24),.56,soft_maps)
sand_mat=material('Hogara_Sand',(.58,.52,.36),.91)

objects=[]
def mesh_obj(name,verts,faces,uv=None,mat=shell_mat,parent=body,pivot=(0,0,0),closed=True):
    local=[G((p[0]-pivot[0],p[1]-pivot[1],p[2]-pivot[2])) for p in verts]
    mesh=bpy.data.meshes.new(name+'_mesh'); mesh.from_pydata(local,[],faces); mesh.update()
    if closed:
        bm=bmesh.new(); bm.from_mesh(mesh); bmesh.ops.triangulate(bm,faces=list(bm.faces)); bmesh.ops.recalc_face_normals(bm,faces=bm.faces); bm.to_mesh(mesh);bm.free()
    if uv:
        layer=mesh.uv_layers.new(name='SurfaceUV')
        for polygon in mesh.polygons:
            for li in polygon.loop_indices:
                layer.data[li].uv=uv[mesh.loops[li].vertex_index]
    for polygon in mesh.polygons: polygon.use_smooth=True
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj);obj.parent=parent
    obj.location=G(pivot)
    obj.data.materials.append(mat)
    objects.append(obj)
    return obj

def sweep_data(points,profiles,sides=12,preferred=(1,0,0)):
    vs=[];fs=[];uv=[]
    for i,p in enumerate(points):
        p=Vector(p)
        tangent=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])).normalized()
        u=Vector(preferred);u=(u-tangent*u.dot(tangent)).normalized()
        if u.length<.01: u=tangent.cross(Vector((0,0,1))).normalized()
        w=tangent.cross(u).normalized()
        width,depth=profiles[i]
        for j in range(sides+1):
            angle=math.tau*j/sides
            # Broad, slightly carinated section, not a round cylinder.
            c=math.cos(angle);s=math.sin(angle)
            q=p+u*(c*width)+w*(s*depth*(1+.08*math.cos(angle*3)))
            vs.append(tuple(q));uv.append((j/sides,i/max(1,len(points)-1)))
    stride=sides+1
    for i in range(len(points)-1):
        for j in range(sides):
            a=i*stride+j;fs.append((a,a+1,a+1+stride,a+stride))
    fs.append(tuple(reversed(range(sides))))
    fs.append(tuple((len(points)-1)*stride+j for j in range(sides)))
    return vs,fs,uv

def sweep(name,points,profiles,mat=shell_mat,parent=body,pivot=(0,0,0),sides=12,preferred=(1,0,0)):
    vs,fs,uv=sweep_data(points,profiles,sides,preferred)
    return mesh_obj(name,vs,fs,uv,mat,parent,pivot)

def combined(name,items,mat,parent=body,pivot=(0,0,0)):
    vs=[];fs=[];uv=[]
    for a,b,c in items:
        off=len(vs);vs+=a;fs += [tuple(i+off for i in f) for f in b];uv+=c
    return mesh_obj(name,vs,fs,uv,mat,parent,pivot)

# Continuous mantle: a low, asymmetric domed roof with a flatter, recessed ventral
# surface. The superellipse rounds the former square fence without narrowing gates.
RINGS=24; SECT=128
vs=[];uv=[];fs=[]
def rim(theta):
    c=math.cos(theta);s=math.sin(theta)
    x=3.64*math.copysign(abs(c)**.60,c)
    z=4.12*math.copysign(abs(s)**.60,s)
    return x,z
def shell_top(r,t,z):
    return 3.23+1.73*(1-r*r)**.72+.10*math.cos(t*3)*r+.028*math.cos(r*70+t*.6)*r+.18*math.exp(-((z+.8)/2.3)**2)*(1-r)
for underside in [False,True]:
    for ri in range(RINGS+1):
        r=.002+(1-.002)*ri/RINGS
        for j in range(SECT+1):
            t=math.tau*j/SECT;x,z=rim(t)
            irregular=.022*math.sin(t*11+.4)*r**3+.012*math.cos(t*7)*r**2
            x*=r+irregular;z*=r+irregular
            if underside:
                y=2.965+.17*r**2+.025*math.cos(t*6)*r
            else:
                y=shell_top(r,t,z)
            vs.append((x,y,z));uv.append((j/SECT,r))
stride=SECT+1;section=(RINGS+1)*stride
for side in range(2):
    for ri in range(RINGS):
        for j in range(SECT):
            a=side*section+ri*stride+j
            face=(a,a+1,a+stride+1,a+stride)
            fs.append(face if side==0 else tuple(reversed(face)))
for j in range(SECT):
    a=RINGS*stride+j;b=section+RINGS*stride+j
    fs.append((a,b,b+1,a+1))
fs.append(tuple(reversed(range(SECT))))
fs.append(tuple(section+j for j in range(SECT)))
carapace=mesh_obj('Carapace',vs,fs,uv)
carapace['collision']='convex'

# Shell growth edges are thin continuous ridges, merged into one mesh/material.
growth=[]
for rr in [.90,.965]:
    points=[];profiles=[]
    for j in range(97):
        t=math.tau*j/96;x,z=rim(t);r=rr
        # Match the actual shell's irregular radial coordinates. A circular
        # approximation partly cut into the steep rim and made broken black
        # seams. The very fine ridge now rests just proud of the same surface.
        irregular=.022*math.sin(t*11+.4)*r**3+.012*math.cos(t*7)*r**2
        x*=r+irregular;z*=r+irregular
        y=shell_top(r,t,z)+.020
        points.append((x,y,z));profiles.append((.006,.007))
    growth.append(sweep_data(points,profiles,6))
combined('GrowthMargins',growth,shell_mat)
keel=[]
for side in [-1,1]:
    points=[];profiles=[]
    for j in range(33):
        z=-3.3+j/32*6.6;r=abs(z)/4.12;t=math.pi*.5*(1 if z>=0 else -1)
        x=side*(.38+.34*math.sin(j/32*math.pi))
        points.append((x,shell_top(r,t,z)+.035,z))
        profiles.append((.13+.10*math.sin(j/32*math.pi),.085))
    keel.append(sweep_data(points,profiles,12))
combined('DorsalKeel',keel,shell_mat)

# The underside is anatomically distinct: longitudinal soft pleats and gill roots.
pleats=[]
for i in range(11):
    x=(i-5)*.38
    points=[];profiles=[]
    for j in range(17):
        t=j/16;z=-3.05+t*6.1
        points.append((x+math.sin(t*math.pi*2+i)*.035,2.92+.10*abs(x)/2.0+.07*abs(z)/3.0,z))
        profiles.append((.105*(.45+.55*math.sin(math.pi*t)),.055))
    pleats.append(sweep_data(points,profiles,10))
combined('VentralPleats',pleats,soft_mat)

# Hard shell lamellae have splayed roots, a curved keeled section and tapered tips.
# At the swimming belt (y .8..2.4) width stays .60 m; neighbouring centres remain
# 1.70 m apart. The lower hooked tip stops above the seabed, unlike support feet.
rib_layout=[]
for side in [-1,1]:
    for index,z in enumerate([-3.4,-1.7,0,1.7,3.4]): rib_layout.append(('Side',side,index,side*3.4,z))
    for index,x in enumerate([-2.55,-.85,.85,2.55]): rib_layout.append(('End',side,index,x,side*3.95))
for n,(typ,side,index,x,z) in enumerate(rib_layout):
    end=.51+.07*((n*7)%5)/4
    if typ=='Side':
        points=[(x*.84,3.72,z*.90),(x*.95,3.30,z*.97),(x,2.73,z),(x+.16*side,2.25,z+.045*math.sin(n)),(x+.09*side,1.50,z+.03*math.sin(n)),(x, .84,z),(x-.11*side,end,z)]
        preferred=(0,0,1)
    else:
        points=[(x*.87,3.69,z*.83),(x*.97,3.26,z*.96),(x,2.73,z),(x+.045*math.sin(n),2.25,z+.12*side),(x+.03*math.sin(n),1.50,z+.07*side),(x,.84,z),(x,end,z-.10*side)]
        preferred=(1,0,0)
    widths=[(.82,.23),(.81,.21),(.49,.19),(.30,.15),(.30,.14),(.285,.115),(.035,.035)]
    obj=sweep('Rib%02d'%n,points,widths,shell_mat,body,pivot=(x,3.3,z),sides=14,preferred=preferred)
    obj['collision']='trimesh'
    # Thin cream growth lines follow the rib ridge and stop well above the portal.
    highlights=[]
    for j in range(2):
        line=[]
        for k,p in enumerate(points[:-1]):
            p=list(p)
            if typ=='Side':p[0]+=.14*side;p[2]+=(j-.5)*.14
            else:p[2]+=.14*side;p[0]+=(j-.5)*.14
            line.append(tuple(p))
        highlights.append(sweep_data(line,[(.014,.009)]*len(line),5,preferred))
    combined('RibGrowth%02d'%n,highlights,bone_mat,obj,pivot=(x,3.3,z))
    # Its mesh coordinates were authored relative to the same body pivot; a child
    # needs zero local translation after mesh-local conversion.
    bpy.data.objects['RibGrowth%02d'%n].location=(0,0,0)

# A bowed, thickness-varying sail. The notch is a deliberate old injury at right.
ANG=84;RAD=28
sail_vs=[];sail_uv=[];sail_fs=[]
def sail_point(u,v):
    theta=(u-.5)*2.85
    notch=.90*max(0,1-abs(theta-.36)/.13)
    edge=Vector((3.52*math.sin(theta),4.70+3.64*max(0,math.cos(theta))**.85-notch,.45+1.75*abs(math.sin(theta))**1.4))
    base=Vector(sail_pivot)
    p=base.lerp(edge,v)
    p.y+=.40*math.sin(math.pi*v)*math.cos(theta)
    p.z+=.42*math.sin(math.pi*v)+.07*math.sin(theta*5)*v*v
    p.x+=.09*math.sin(theta*3)*math.sin(math.pi*v)
    return p
for side in [-1,1]:
    for r in range(RAD+1):
        v=.015+.985*r/RAD
        for a in range(ANG+1):
            u=a/ANG;p=sail_point(u,v)
            p.z+=side*(.004+.037*(1-v)**2)
            sail_vs.append(tuple(p));sail_uv.append((u,v))
stride=ANG+1;section=(RAD+1)*stride
for side in range(2):
    for r in range(RAD):
        for a in range(ANG):
            i=side*section+r*stride+a
            f=(i,i+1,i+stride+1,i+stride)
            sail_fs.append(f if side==0 else tuple(reversed(f)))
for r in range(RAD):
    for a in [0,ANG]:
        i=r*stride+a;j=i+stride
        sail_fs.append((i,j,j+section,i+section))
for a in range(ANG):
    i=RAD*stride+a;sail_fs.append((i,i+1,i+1+section,i+section))
# One double-surface membrane, no stack of overlapping transparent fans.
mesh_obj('SailMembrane',sail_vs,sail_fs,sail_uv,sail_mat,sail,pivot=sail_pivot).location=(0,0,0)
veins=[]
for a in range(15):
    u=a/14;points=[];profiles=[]
    for r in range(25):
        v=.025+.975*r/24;p=sail_point(u,v);p.z-=.012
        points.append(tuple(p));profiles.append((.008+.047*(1-v)**1.6,.006+.026*(1-v)))
    veins.append(sweep_data(points,profiles,8))
# A raised, irregular rim makes the chipped edge readable in silhouette.
points=[tuple(sail_point(i/128,1)) for i in range(129)]
veins.append(sweep_data(points,[(.023,.019)]*len(points),8))
combined('SailVeins',veins,vein_mat,sail,pivot=sail_pivot).location=(0,0,0)
base_points=[tuple(sail_point(i/32,.16)) for i in range(33)]
combined('SailRoot', [sweep_data(base_points,[(.075,.09)]*len(base_points),12)],bone_mat,sail,pivot=sail_pivot).location=(0,0,0)

# Three independently posed limbs. Mesh +Y is the segment direction, length 1 m.
HIP=[(-2.45,3.25,-2.05),(2.45,3.25,-2.05),(0,3.25,2.7)]
FEET=[(-4,0,-2.7),(4,0,-2.7),(0,0,4.5)]
for i in range(3):
    limb=node('Leg%d'%i,root)
    for part,is_upper in [('Upper',True),('Lower',False)]:
        points=[];profiles=[]
        for j in range(25):
            t=j/24
            bulge=math.sin(math.pi*t)**.65
            width=(.36+.42*bulge-.06*t) if is_upper else (.23+.20*bulge+.06*(1-t))
            depth=width*(.78 if is_upper else .83)
            # The forward ridge and concave inner line are continuous along the limb.
            points.append((.05*math.sin(math.pi*t),t,.055*math.sin(math.pi*t)*(-1 if is_upper else 1)))
            profiles.append((width,depth))
        mesh=sweep(part+str(i),points,profiles,bone_mat,limb,sides=20)
        mesh['collision']='convex'
        # Selected overlapping scute margins, merged as one slim detail mesh.
        bands=[]
        for t in [.28,.56,.79]:
            width=(.36+.42*math.sin(math.pi*t)**.65-.06*t) if is_upper else (.23+.20*math.sin(math.pi*t)**.65+.06*(1-t))
            pts=[(.05*math.sin(math.pi*t)+math.cos(j*math.tau/24)*(width+.005),t+.024*math.sin(j*math.tau/24),.055*math.sin(math.pi*t)*(-1 if is_upper else 1)+math.sin(j*math.tau/24)*width*(.78 if is_upper else .83)) for j in range(25)]
            bands.append(sweep_data(pts,[(.017,.012)]*len(pts),6))
        combined(part+'Scutes'+str(i),bands,shell_mat,mesh)
    # Flexible knee capsule has folded skin, not two rods intersecting in space.
    vs=[];fs=[];uv=[]
    for r in range(17):
        lat=-math.pi/2+.003+(math.pi-.006)*r/16
        for a in range(25):
            angle=a*math.tau/24
            rr=math.cos(lat)*(.52+.021*math.cos(lat*29))
            vs.append((math.cos(angle)*rr,math.sin(lat)*.39,math.sin(angle)*rr*.90));uv.append((a/24,r/16))
    for r in range(16):
        for a in range(24):
            k=r*25+a;fs.append((k,k+1,k+26,k+25))
    mesh_obj('Joint'+str(i),vs,fs,uv,joint_mat,limb)['collision']='convex'
    # Wide weight-bearing foot: a scalloped sole with three lobes and an arched top.
    vs=[];uv=[];fs=[]
    for ring in range(8):
        r=ring/7
        for j in range(49):
            a=j*math.tau/48
            lobes=1+.085*math.cos(a*3+.5)
            x=math.cos(a)*.80*r*lobes
            z=math.sin(a)*.94*r*lobes
            y=.075+.39*(1-r*r)**1.15
            vs.append((x,y,z));uv.append((j/48,r))
    for ri in range(7):
        for j in range(48):
            k=ri*49+j;fs.append((k,k+1,k+50,k+49))
    off=len(vs)
    for j in range(49):
        a=j*math.tau/48;lobes=1+.085*math.cos(a*3+.5)
        vs.append((math.cos(a)*.80*lobes,0,math.sin(a)*.94*lobes));uv.append((j/48,1))
    for j in range(48):fs.append((7*49+j,off+j,off+j+1,7*49+j+1))
    fs.append(tuple(reversed([off+j for j in range(48)])))
    mesh_obj('Foot'+str(i),vs,fs,uv,bone_mat,limb)['collision']='convex'
    # Shoulder socket is a flared soft collar. Parent motion keeps it at the hip.
    pts=[(0,t,0) for t in [-.18,-.08,.04,.16,.27]]
    collar=sweep('Coxa'+str(i),pts,[(.58,.47),(.60,.48),(.56,.45),(.48,.40),(.37,.32)],joint_mat,limb,sides=20)
    # Socket receives the same orientation as Upper, without longitudinal scaling.

# Twelve distinct filtering fronds, sparse at the central swimming lane.
for i in range(12):
    side=-1 if i<6 else 1;k=i%6
    at=(side*(1.66+.23*math.sin(k*2.1)),3.02,-2.48+k*.94)
    cluster=node('Filter%02d'%i,filter_root,at)
    length=.72+.22*math.sin(i*1.7)**2
    items=[]
    pts=[(.10*math.sin(t*math.pi),-t*length,.08*math.sin(t*2.2+i)) for t in np.linspace(0,1,13)]
    items.append(sweep_data(pts,[(.035*(1-j/15),.026*(1-j/15)) for j in range(13)],8))
    for row in range(8):
        t=.14+row*.105
        for side2 in [-1,1]:
            base=Vector((.10*math.sin(t*math.pi),-t*length,.08*math.sin(t*2.2+i)))
            pts=[];profiles=[]
            leaf_len=.21+.085*math.sin(row*1.5+i)**2
            for j in range(9):
                u=j/8
                p=base+Vector((side2*leaf_len*u,-.13*math.sin(math.pi*u*.7),.035*math.sin(math.pi*u)))
                pts.append(tuple(p));profiles.append((max(.003,.055*math.sin(math.pi*u)),.005+.010*math.sin(math.pi*u)))
            items.append(sweep_data(pts,profiles,6,preferred=(0,0,1)))
    combined('FilterMesh%02d'%i,items,filter_mat,cluster)

# Localised old shell wear is restricted to the rear-left plate; not uniform noise.
wear=[]
for i in range(18):
    a=1.9+random.random()*.50;r=.77+random.random()*.14;x,z=rim(a)
    x*=r;z*=r;y=shell_top(r,a,z)+.025
    pts=[(x-.035,y+.010,z),(x,y+.026,z+.005),(x+.042,y+.012,z+.009)]
    wear.append(sweep_data(pts,[(.017,.008),(.026,.009),(.008,.004)],6))
combined('OldShellWear',wear,sand_mat)

# Pose limb meshes into a useful neutral stance in the exported file. Runtime IK
# overwrites these poses; the source GLB is inspectable without any game script.
def align_segment(obj,start,end):
    a=Vector(G(start)); b=Vector(G(end)); d=b-a
    obj.location=a
    obj.rotation_mode='QUATERNION';obj.rotation_quaternion=Vector((0,0,1)).rotation_difference(d.normalized())
    obj.scale=(1,1,d.length)
for i in range(3):
    hip=Vector(HIP[i]);foot=Vector(FEET[i]);knee=hip.lerp(foot,.55)
    knee=Vector(((-4.65 if i==0 else 4.65) if i<2 else 0,1.95,4.9 if i==2 else -2.7))
    ankle=foot+Vector((0,.34,0))
    align_segment(bpy.data.objects['Upper'+str(i)],hip,knee)
    align_segment(bpy.data.objects['Lower'+str(i)],knee,ankle)
    joint=bpy.data.objects['Joint'+str(i)];joint.location=G(knee)
    bpy.data.objects['Foot'+str(i)].location=G(foot)
    coxa=bpy.data.objects['Coxa'+str(i)];coxa.location=G(hip)
    coxa.rotation_mode='QUATERNION';coxa.rotation_quaternion=bpy.data.objects['Upper'+str(i)].rotation_quaternion

# Export only final assets. All textures are embedded; explicit PNG sources remain
# versioned for material overrides, inspection and regeneration.
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(MODEL/'hogara.glb'),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_texcoords=True,export_normals=True,export_tangents=True,export_materials='EXPORT',export_cameras=False,export_lights=False,export_animations=False,export_extras=True)
triangles=0
for ob in objects:
    ob.data.calc_loop_triangles();triangles+=len(ob.data.loop_triangles)
metrics={'asset':'hogara.glb','authoring_tool':bpy.app.version_string,'seed':SEED,'metres':True,'godot_axis':'Y up / forward -Z','mesh_objects':len(objects),'triangles':triangles,'material_count':len(materials),'texture_resolution':{'carapace':1024,'ivory':1024,'tissue':512,'sail_thickness':1024},'hip_positions':HIP,'rest_feet':FEET,'collision_meshes':['Carapace']+['Rib%02d'%i for i in range(18)]+[p+str(i) for i in range(3) for p in ['Upper','Joint','Lower','Foot']],'sha256':hashlib.sha256((MODEL/'hogara.glb').read_bytes()).hexdigest()}
(MODEL/'geometry_manifest.json').write_text(json.dumps(metrics,ensure_ascii=False,indent=2)+'\n')
print('HOGARA_ASSET_OK '+json.dumps(metrics))
# A source .blend is optional. The deterministic Python recipe is the authoring
# source of truth and avoids automatic .blend imports during normal builds.
if '--save-blend' in sys.argv:
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'build/hogara-authoring.blend'))
