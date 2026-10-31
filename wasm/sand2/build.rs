fn main() -> lungo_build::Result<()> {
    lungo_build::configure()
        .export("Sand2.stepBlock")
        .export("Sand2.settle")
        .export("Sand2.canSwap")
        .deny_sorry(true)
        .deny_axioms(true)
        .deny_unsafe(true)
        .compile_lean("lean")
}
