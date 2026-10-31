fn main() -> lungo_build::Result<()> {
    let mut program = lungo_build::configure();
    for name in ["newSimulation", "tickSimulation", "clearSimulation", "paintSimulation",
        "sceneSimulation", "catalogue", "renderSimulation", "countSimulation",
        "inspectSimulation", "auditSimulation", "digestSimulation", "oracle", "stepCountSimulation"] {
        program = program.export(format!("Sand2.{name}"));
    }
    program.deny_sorry(true).deny_axioms(true).deny_unsafe(true).compile_lean("lean")
}
