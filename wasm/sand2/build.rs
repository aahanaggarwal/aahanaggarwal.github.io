use std::collections::BTreeMap;
use std::path::Path;

// Lungo 1.117 emits heap-allocated Nat literals inline when cross-compiling
// host-optimized Lean IR to 32-bit Wasm. The IR can omit reference-count
// operations for literals that were immediate values on the 64-bit host.
// Use the backend's existing persistent constant cells for those literals.
// This generic emission repair contains no simulation rules or parameters.
fn stabilize_nat_literals(directory: &Path) -> std::io::Result<()> {
    const MARKER: &str = "// Sand2 automatic persistent Nat literal normalization v1";
    const NEEDLE: &str = "rt::nat::lean_cstr_to_nat(\"";
    let mut changed = 0;
    let mut occurrences = 0;
    for entry in std::fs::read_dir(directory)? {
        let path = entry?.path();
        if path.extension().and_then(|s| s.to_str()) != Some("rs") { continue; }
        let source = std::fs::read_to_string(&path)?;
        if source.contains(MARKER) { continue; }
        let tag: String = path.file_name().unwrap().to_string_lossy().as_bytes()
            .iter().map(|b| format!("{b:02x}")).collect();
        let mut literals = BTreeMap::<String, String>::new();
        let mut result = String::with_capacity(source.len());
        let mut rest = source.as_str();
        while let Some(start) = rest.find(NEEDLE) {
            result.push_str(&rest[..start]);
            let number = &rest[start+NEEDLE.len()..];
            let end = number.bytes().take_while(u8::is_ascii_digit).count();
            if end == 0 || !number[end..].starts_with("\")") {
                result.push_str(NEEDLE);
                rest = number;
                continue;
            }
            let digits = &number[..end];
            let function = literals.entry(digits.to_owned())
                .or_insert_with(|| format!("__sand2_nat_literal_{tag}_{digits}"));
            result.push_str(function);
            result.push_str("()");
            rest = &number[end+2..];
            occurrences += 1;
        }
        if literals.is_empty() { continue; }
        result.push_str(rest);
        result.push('\n'); result.push_str(MARKER); result.push('\n');
        for (digits, function) in literals {
            let cell = function.to_ascii_uppercase();
            result.push_str(&format!(
                "static {cell}: rt::LazyObj = rt::LazyObj::new();\n\
                 #[inline]\nunsafe fn {function}() -> Obj {{\n\
                 unsafe fn initialize() -> Obj {{ rt::nat::lean_cstr_to_nat(\"{digits}\") }}\n\
                 {cell}.get(initialize)\n}}\n"));
        }
        std::fs::write(path, result)?;
        changed += 1;
    }
    println!("cargo:warning=Stabilized {occurrences} Nat literal occurrences in {changed} generated modules");
    Ok(())
}

fn main() -> lungo_build::Result<()> {
    let mut program = lungo_build::configure();
    for name in ["newSimulation", "tickSimulation", "clearSimulation", "paintSimulation",
        "sceneSimulation", "catalogue", "renderSimulation", "countSimulation",
        "inspectSimulation", "auditSimulation", "digestSimulation", "oracle", "stepCountSimulation", "timeMillisecondsSimulation", "waterInRegionSimulation", "maxLiquidVolumeSimulation", "solverFailuresSimulation", "numericalProbeSimulation"] {
        program = program.export(format!("Sand2.{name}"));
    }
    program.deny_sorry(true).deny_axioms(true).deny_unsafe(true).compile_lean("lean")?;
    let output = std::path::PathBuf::from(std::env::var_os("OUT_DIR").expect("Cargo OUT_DIR"));
    stabilize_nat_literals(&output.join("lungo/sand2/modules"))
        .expect("normalize generated Nat literals with persistent backend cells");
    Ok(())
}
