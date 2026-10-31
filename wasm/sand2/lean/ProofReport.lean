import Lean
import Sand2

open Lean Elab Command

/- Audit every theorem in our namespace, including imported model modules.
    Fail on sorryAx or any custom axiom, rather than grepping source text. -/
run_cmd do
  let env ← getEnv
  let mut names : Array Name := #[]
  for (name, info) in env.constants.toList do
    if (`Sand2).isPrefixOf name && info.isTheorem then names := names.push name
  for name in names.qsort Name.lt do
    let axioms ← collectAxioms name
    for axiomName in axioms do
      unless axiomName == ``propext || axiomName == ``Quot.sound || axiomName == ``Classical.choice do
        throwError "Untrusted axiom {axiomName} in {name}"
    logInfo m!"PROOF|{name}|{axioms.toList}"
  logInfo m!"AUDITED {names.size} Lean theorems"
