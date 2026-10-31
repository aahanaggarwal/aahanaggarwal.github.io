"""Package the exact Lungo-generated Rust and Wasm; record source provenance."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
CRATE = ROOT / 'wasm/sand2'
GENERATED = ROOT / 'tools/sand2/generated'
SOURCE_FILES = [
    'wasm/sand2/Cargo.toml', 'wasm/sand2/Cargo.lock', 'wasm/sand2/build.rs',
    'wasm/sand2/.cargo/config.toml', 'wasm/sand2/src/lib.rs',
    'wasm/sand2/lean/lean-toolchain', 'wasm/sand2/lean/lakefile.toml',
    'wasm/sand2/lean/lake-manifest.json', 'wasm/sand2/lean/Sand2.lean',
    'wasm/sand2/lean/Oracle.lean', 'wasm/sand2/lean/ProofReport.lean',
    'wasm/sand2/examples/oracle.rs',
    'tools/sand2/build.sh', 'tools/sand2/package.py', 'tools/sand2/check-wasm.mjs',
]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

events = [json.loads(line) for line in (ROOT / '.tools/sand2/cargo-build.jsonl').read_text().splitlines()]
candidates = [Path(event['out_dir']) / 'lungo/sand2' for event in events
              if event.get('reason') == 'build-script-executed'
              and event.get('package_id', '').startswith(f'path+{CRATE.as_uri()}#')]
if len(candidates) != 1:
    raise SystemExit(f'Expected one generated program from Cargo, found {len(candidates)}.')
source = candidates[0]
if GENERATED.exists():
    shutil.rmtree(GENERATED)
GENERATED.mkdir(parents=True)
for path in sorted(source.rglob('*.rs')):
    target = GENERATED / path.relative_to(source)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(path, target)
for name in ['assurance.json', 'names.json']:
    shutil.copyfile(source / name, GENERATED / name)
wasm = ROOT / 'sand2/pkg/sand2.wasm'
wasm.parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(CRATE / 'target/wasm32-wasip1/release/sand2.wasm', wasm)
outputs = [wasm, *sorted(GENERATED.rglob('*'))]
record = {
    'format': 1, 'generator': 'lungo 1.117.0', 'lean': '4.34.1',
    'rust': subprocess.check_output(['rustc', '--version'], text=True).strip(),
    'target': 'wasm32-wasip1',
    'proofs': ['settle_conserves', 'fixed_never_falls', 'fixed_never_displaced', 'blocked_pair_unchanged'],
    'inputs': {name: digest(ROOT / name) for name in SOURCE_FILES},
    'outputs': {str(path.relative_to(ROOT)): digest(path) for path in outputs if path.is_file()},
}
(ROOT / 'sand2/build.json').write_text(json.dumps(record, indent=2) + '\n')
print(f'Packaged {wasm.stat().st_size:,} byte Wasm module and its generated Rust.')
