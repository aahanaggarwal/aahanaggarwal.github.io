import Sand2

/-- Direct Lean evaluation includes every molecular inventory, momentum,
    position, energy, morphology and update stamp in the state digest. -/
def main : IO Unit := do
  for scene in [:5] do
    for ticks in [0,1,2,5,12] do
      IO.println s!"{scene};{ticks};{Sand2.oracle scene.toUInt32 ticks}"
