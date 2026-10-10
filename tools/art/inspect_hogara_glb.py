"""Inspect the actual exported GLB's geometry/material channels, without Godot.
This is an asset integrity check, not visual or locomotion acceptance.
"""
from pathlib import Path
import json, math, struct

root=Path(__file__).resolve().parents[2]
payload=(root/'assets/models/hogara/hogara.glb').read_bytes()
magic,version,length=struct.unpack_from('<III',payload,0)
assert magic==0x46546C67 and version==2 and length==len(payload)
json_length,json_type=struct.unpack_from('<II',payload,12)
assert json_type==0x4E4F534A
asset=json.loads(payload[20:20+json_length])
required={'Carapace','SailRig','SailMembrane','SailVeins'}
required.update('Rib%02d'%i for i in range(18))
required.update('Filter%02d'%i for i in range(12))
required.update(p+str(i) for i in range(3) for p in ['Upper','Joint','Lower','Foot','Coxa'])
assert required.issubset({n.get('name') for n in asset['nodes']}),required-{n.get('name') for n in asset['nodes']}
triangles=0
for mesh in asset['meshes']:
    for primitive in mesh['primitives']:
        assert primitive.get('mode',4)==4
        assert {'POSITION','NORMAL','TANGENT','TEXCOORD_0'}.issubset(primitive['attributes']),mesh['name']
        triangles+=asset['accessors'][primitive['indices']]['count']//3
for image in asset['images']:
    assert 'bufferView' in image and image['mimeType']=='image/png'
assert all(m.get('pbrMetallicRoughness',{}).get('metallicFactor',1)==0 for m in asset['materials'])
assert len(asset['materials'])==8
assert 20000 < triangles < 140000
manifest=json.loads((root/'assets/models/hogara/geometry_manifest.json').read_text())
assert triangles==manifest['triangles']
print(f'HOGARA_GLB_OK triangles={triangles} meshes={len(asset["meshes"])} materials={len(asset["materials"])} embedded_images={len(asset["images"])} bytes={len(payload)}')
