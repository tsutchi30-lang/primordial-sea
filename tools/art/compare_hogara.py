"""Compare two GLBs independently of serialization order and tangent rounding.

Use before/after copies produced by generate_hogara.sh. Position, normal, UV and
triangle winding must agree at 1e-5; exported tangents may differ by at most 2e-4.
This tolerance addresses the observed Blender 4.3.2 tangent rounding boundary,
not a positional tolerance for physics. Images/materials/transforms stay exact.
"""
import json
import struct
import sys
from pathlib import Path
from fingerprint_hogara import signature


def triangle_rows(path):
    data = Path(path).read_bytes()
    count = struct.unpack_from('<I', data, 12)[0]
    asset = json.loads(data[20:20 + count])
    binary = data[28 + count:]

    def accessor(index):
        item = asset['accessors'][index]
        view = asset['bufferViews'][item['bufferView']]
        components = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[item['type']]
        kind = {5126: 'f', 5125: 'I', 5123: 'H', 5121: 'B'}[item['componentType']]
        fmt = '<' + kind * components
        stride = view.get('byteStride', struct.calcsize(fmt))
        offset = view.get('byteOffset', 0) + item.get('byteOffset', 0)
        return [struct.unpack_from(fmt, binary, offset + i * stride) for i in range(item['count'])]

    meshes = {}
    for mesh in asset['meshes']:
        triangles = []
        for primitive in mesh['primitives']:
            attrs = {name: accessor(i) for name, i in primitive['attributes'].items()}
            indices = [row[0] for row in accessor(primitive['indices'])]
            keys = [tuple(round(v, 5) for name in sorted(attrs) if name != 'TANGENT' for v in attrs[name][i]) for i in range(len(attrs['POSITION']))]
            for start in range(0, len(indices), 3):
                face = indices[start:start + 3]
                rotation = min(range(3), key=lambda r: tuple(keys[face[(r + d) % 3]] for d in range(3)))
                order = [face[(rotation + d) % 3] for d in range(3)]
                triangles.append((tuple(keys[i] for i in order), tuple(attrs['TANGENT'][i] for i in order)))
        meshes[mesh['name']] = sorted(triangles)
    return meshes


before, after = sys.argv[1:3]
left, right = signature(before), signature(after)
for field in ['nodes', 'images', 'materials']:
    assert left[field] == right[field], f'{field} changed'
left_meshes, right_meshes = triangle_rows(before), triangle_rows(after)
assert left_meshes.keys() == right_meshes.keys(), 'mesh set changed'
largest_tangent_delta = 0.0
for name, triangles in left_meshes.items():
    other = right_meshes[name]
    assert len(triangles) == len(other), f'{name}: triangle count changed'
    for (key_a, tangent_a), (key_b, tangent_b) in zip(triangles, other):
        assert key_a == key_b, f'{name}: position/normal/UV/winding changed'
        error = max(abs(a - b) for vertex_a, vertex_b in zip(tangent_a, tangent_b) for a, b in zip(vertex_a, vertex_b))
        largest_tangent_delta = max(largest_tangent_delta, error)
        assert error <= 0.0002, f'{name}: tangent delta {error} exceeds tolerance'
print(f'HOGARA_REPRODUCED meshes={len(left_meshes)} max_tangent_delta={largest_tangent_delta:.9f}')
