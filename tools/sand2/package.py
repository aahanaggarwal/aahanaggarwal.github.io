"""Package the exact Lungo-generated Rust and Wasm; record source provenance."""
from pathlib import Path
import hashlib
import json
import shutil
import re
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
    'wasm/sand2/examples/oracle.rs', 'wasm/sand2/examples/bench.rs', 'wasm/sand2/examples/profile.rs',
    'wasm/sand2/lean/Validation.lean', 'wasm/sand2/lean/FluidValidation.lean', 'wasm/sand2/lean/SaturationValidation.lean',
    'tools/sand2/check-saturation.py',
    'tools/sand2/build.sh', 'tools/sand2/package.py', 'tools/sand2/check-wasm.mjs',
]
SOURCE_FILES += [str(p.relative_to(ROOT)) for p in sorted((CRATE / 'lean/Sand2').glob('*.lean'))]

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
audited = {line.split('|')[1] for line in (ROOT / '.tools/sand2/proofs.txt').read_text().splitlines() if 'PROOF|' in line}
handwritten = set()
for path in sorted((CRATE / 'lean/Sand2').glob('*.lean')):
    for name in re.findall(r'^theorem\s+([\w.]+)', path.read_text(), re.M):
        matches = {proof for proof in audited if proof.endswith('.' + name)}
        if not matches:
            raise SystemExit(f'Theorem missing from kernel axiom audit: {name}')
        handwritten.update(matches)
record = {
    'format': 1, 'generator': 'lungo 1.117.0 with automatic persistent Nat literal normalization', 'lean': '4.34.1',
    'rust': subprocess.check_output(['rustc', '--version'], text=True).strip(),
    'target': 'wasm32-wasip1',
    'reference_evaluator': 'Independent Lean native C compiler; no Lungo code in the reference evaluator',
    'code_generation_repair': {
        'implementation': 'wasm/sand2/build.rs',
        'purpose': 'Preserve compiler literal lifetime assumptions on 32-bit Wasm',
        'modules': sum('persistent Nat literal normalization v1' in p.read_text() for p in GENERATED.rglob('*.rs')),
        'persistent_literals': sum(len(re.findall(r'unsafe fn __sand2_nat_literal_', p.read_text())) for p in GENERATED.rglob('*.rs')),
    },
    'proofs': sorted(handwritten), 'audited_theorems_including_generated': len(audited),
    'trust': 'Lean kernel; standard propext, Quot.sound and Classical.choice only; no sorryAx or custom axioms',
    'inputs': {name: digest(ROOT / name) for name in SOURCE_FILES},
    'outputs': {str(path.relative_to(ROOT)): digest(path) for path in outputs if path.is_file()},
}
(ROOT / 'sand2/build.json').write_text(json.dumps(record, indent=2) + '\n')
print(f'Packaged {wasm.stat().st_size:,} byte Wasm module and its generated Rust.')
