"""Fail the existing site build when committed physics artifacts are stale."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[2]
record = json.loads((root / 'sand2/build.json').read_text())
actual_lean = {str(p.relative_to(root)) for p in (root / 'wasm/sand2/lean/Sand2').glob('*.lean')}
recorded_lean = {p for p in record['inputs'] if p.startswith('wasm/sand2/lean/Sand2/')}
if actual_lean != recorded_lean:
    raise SystemExit('Sand Game 2 Lean source inventory changed. Rebuild the generated artifacts.')
for kind in ('inputs', 'outputs'):
    for name, expected in record[kind].items():
        path = root / name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise SystemExit(f'Sand Game 2 artifact mismatch: {name}. Run ./dev.sh --sand2-only --no-serve and commit the rebuilt artifacts.')
print('Sand Game 2 source and generated artifacts match.')
