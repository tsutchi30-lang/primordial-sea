#!/usr/bin/env python3
"""Describe exact source and captured files without claiming manual review."""
import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path
import platform
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
output = Path(sys.argv[1]).resolve()
def git(*args):
    result = subprocess.run(['git', '-C', str(root), *args], text=True, capture_output=True)
    return result.stdout.strip() if result.returncode == 0 else None
checkout = git('rev-parse', 'HEAD')
status = git('status', '--porcelain', '--untracked-files=normal')
harnesses = sorted(path for path in (root/'tools').glob('capture_*') if path.suffix in ('.gd', '.py', '.sh'))
harnesses.append(Path(__file__).resolve())
source_paths = subprocess.run(['git', '-C', str(root), 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], capture_output=True)
source_fingerprint = None
if source_paths.returncode == 0:
    digest = hashlib.sha256()
    for relative in sorted(set(source_paths.stdout.decode().split('\0')) - {''}):
        path = root / relative
        if path.is_file():
            digest.update(relative.encode() + b'\0' + hashlib.sha256(path.read_bytes()).digest())
    source_fingerprint = digest.hexdigest()
files=[]
for path in sorted(output.rglob('*')):
    if path.is_file() and path.name not in ('evidence.json', '.gdignore'):
        files.append({'path': str(path.relative_to(output)), 'bytes': path.stat().st_size, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
payload = {'schema': 1, 'generated_utc': datetime.now(timezone.utc).isoformat(), 'implementation_head': os.environ.get('PRIMORDIAL_SOURCE_COMMIT', checkout or 'source-archive'), 'checkout_commit': os.environ.get('PRIMORDIAL_BUILD_COMMIT', checkout or 'source-archive'), 'source_tree': 'unknown (archive)' if status is None else ('dirty' if status else 'clean'), 'git_source_inputs_sha256': source_fingerprint, 'os': platform.platform(), 'capture_harness_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in harnesses}, 'review_status': 'File generation and manifests do not imply image review, video playback, Windows operation or listening. See docs/M3_ACCEPTANCE.md for M3; docs/M2_ACCEPTANCE.md and docs/VISUAL_REVIEW_M1_5.md retain earlier reviews.', 'files': files}
(output/'evidence.json').write_text(json.dumps(payload, ensure_ascii=False, indent=2)+'\n')
print(f'EVIDENCE_MANIFEST_OK files={len(files)} {output}')
