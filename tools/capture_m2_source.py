#!/usr/bin/env python3
"""Capture source identity at launch and verify identical production inputs at end."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from datetime import datetime, timezone

root = Path(__file__).resolve().parents[1]
mode, output = sys.argv[1], Path(sys.argv[2]).resolve()

def git(*args):
    result = subprocess.run(['git', '-C', str(root), *args], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else 'source-archive'

def inputs():
    folders = ['scripts', 'scenes', 'data', 'assets', 'tests', 'tools']
    paths = [root / name for name in ['project.godot', 'export_presets.cfg', '.godot-version']]
    for folder in folders:
        paths.extend(p for p in (root / folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts)
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}

if mode == 'begin':
    output.parent.mkdir(parents=True, exist_ok=True)
    data = {'schema': 1, 'started_utc': datetime.now(timezone.utc).isoformat(), 'implementation_head': os.environ.get('PRIMORDIAL_SOURCE_COMMIT', git('rev-parse', 'HEAD')), 'capture_checkout': git('rev-parse', 'HEAD'), 'source_tree_at_launch': 'clean' if not git('status', '--porcelain') else 'dirty', 'scope': 'Runtime code/data/assets, engine/export settings, test and capture/build tooling. Documentation is excluded. Individual capture manifests preserve launch identity.', 'source_files_sha256': inputs()}
else:
    data = json.loads(output.read_text())
    current = inputs()
    data['finished_utc'] = datetime.now(timezone.utc).isoformat()
    data['finalization_checkout'] = git('rev-parse', 'HEAD')
    data['source_unchanged_during_capture'] = current == data['source_files_sha256']
    data['changed_inputs'] = sorted(key for key in current.keys() | data['source_files_sha256'].keys() if current.get(key) != data['source_files_sha256'].get(key))
output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
if mode != 'begin' and not data['source_unchanged_during_capture']:
    raise SystemExit('M2_SOURCE_FAIL changed during capture: ' + ', '.join(data['changed_inputs']))
print(f'M2_SOURCE_OK mode={mode} files={len(data["source_files_sha256"])}')
