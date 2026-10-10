"""Canonical fingerprint of exported GLB triangle attributes and dependencies.
Triangle/vertex serialization order may vary between Blender exports. Preserve
winding while canonicalizing triangle rotations; quantize floats to 1e-5 metres.
Usage: python3 tools/art/fingerprint_hogara.py MODEL.glb OUTPUT.json
This checks semantic reproducibility, not artistic quality or gameplay physics.
"""
import json,struct,hashlib
from pathlib import Path

def signature(path):
    data=Path(path).read_bytes();n=struct.unpack_from('<I',data,12)[0];j=json.loads(data[20:20+n]);start=20+n+8;binary=data[start:]
    def acc(i):
        a=j['accessors'][i];v=j['bufferViews'][a['bufferView']];offset=v.get('byteOffset',0)+a.get('byteOffset',0)
        c={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']];fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']];size=struct.calcsize('<'+fmt*c);stride=v.get('byteStride',size)
        return [tuple(round(x,5) if fmt=='f' else x for x in struct.unpack_from('<'+fmt*c,binary,offset+k*stride)) for k in range(a['count'])]
    meshes={}
    for m in j['meshes']:
        parts=[]
        for p in m['primitives']:
            attrs={k:acc(i) for k,i in sorted(p['attributes'].items())}
            rows=list(zip(*attrs.values()));indices=[x[0] for x in acc(p['indices'])]
            triangles=[]
            for k in range(0,len(indices),3):
                face=[rows[indices[k+d]] for d in range(3)]
                triangles.append(min(tuple(face[r:]+face[:r]) for r in range(3)))
            parts.append(hashlib.sha256(json.dumps(sorted(triangles),separators=(',',':')).encode()).hexdigest())
        meshes[m['name']]=parts
    nodes={n['name']:{k:n[k] for k in ['translation','rotation','scale'] if k in n} for n in j['nodes']}
    images={im['name']:hashlib.sha256(binary[j['bufferViews'][im['bufferView']].get('byteOffset',0):j['bufferViews'][im['bufferView']].get('byteOffset',0)+j['bufferViews'][im['bufferView']]['byteLength']]).hexdigest() for im in j['images']}
    return {'meshes':meshes,'nodes':nodes,'images':images,'materials':j['materials']}
if __name__=='__main__':
    import sys
    result=signature(sys.argv[1]);Path(sys.argv[2]).write_text(json.dumps(result,sort_keys=True,indent=2));print(hashlib.sha256(json.dumps(result,sort_keys=True).encode()).hexdigest())
