import Sand2

/-- Reference vectors computed directly by Lean, independently of Lungo. -/
def main : IO Unit := do
  for a in [0:14] do
    for b in [0:14] do
      for r in ([0, 1, 15, 63, 255, 4294967295] : List UInt32) do
        let block := a.toUInt32 ||| (b.toUInt32 <<< 16)
        IO.println s!"{block},{r},{Sand2.stepBlock block r}"
  let mut seed : UInt32 := 20261030
  for _ in [0:1024] do
    seed := seed ^^^ (seed <<< 13)
    seed := seed ^^^ (seed >>> 17)
    seed := seed ^^^ (seed <<< 5)
    let a := seed % 14
    let b := (seed >>> 8) % 14
    let c := (seed >>> 16) % 14
    let d := (seed >>> 24) % 14
    let block := a ||| (b <<< 8) ||| (c <<< 16) ||| (d <<< 24)
    IO.println s!"{block},{seed},{Sand2.stepBlock block seed}"
