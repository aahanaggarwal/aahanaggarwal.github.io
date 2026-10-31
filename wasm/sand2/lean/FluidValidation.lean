import Sand2
open Sand2 Sand2.Chemistry

def physicalCheck (label : String) (ok : Bool) : IO Unit := do
  unless ok do throw (IO.userError s!"FAILED: {label}")
  IO.println s!"PASS: {label}"
  (← IO.getStdout).flush

def waterMomentY (s : Simulation) : Nat := Id.run do
  let mut result := 0
  for i in [:s.width*s.height] do result := result+(read s.world i).matter.water*(i/s.width)
  return result

def hydrogenMomentY (s : Simulation) : Nat := Id.run do
  let mut result := 0
  for i in [:s.width*s.height] do result := result+(read s.world i).matter.hydrogen*(i/s.width)
  return result

def main (args : List String) : IO Unit := do
  let width := (args.headD "24").toNat?.getD 24
  let n := width+8
  let system : PressureSystem := {
    width := n
    height := 1
    unknown := Array.replicate n true
    diagonal := floats n 2
    right := floats n 1
    down := floats n
    rhs := floats n 2
    mask_eq := rfl }
  let solution := pressureSolve system
  let mut error := (0 : Float)
  for i in [:n] do error := floatMax error (floatAbs (floatAt solution.values i-floatNat ((i+1)*(n-i))))
  physicalCheck "pressure solver matches an independent analytic Poisson solution"
    (error < 0.00000001 && pressureResidual system solution.values < 0.00000001)

  let cavitation : PressureSystem := {
    width := 2
    height := 1
    unknown := #[true,true]
    diagonal := (floats 2 2)
    right := ((floats 2).set! 0 1)
    down := floats 2
    rhs := ((floats 2).set! 0 (-1)).set! 1 1
    mask_eq := rfl }
  let constrained := nonnegativePressureSolve cavitation
  physicalCheck "cavitation matches the independent pressure-obstacle solution (0, 0.5)"
    (floatAbs (floatAt constrained.values 0) < 0.00000001 &&
     floatAbs (floatAt constrained.values 1-0.5) < 0.00000001 && constrained.residual < 0.00000001)

  let lower := ((floats 2).set! 0 (-0.1)).set! 1 (-0.2)
  let shifted := boundedPressureSolve cavitation lower
  physicalCheck "nonzero pressure bounds give the analytic solution (-0.1, 0.45)"
    (floatAbs (floatAt shifted.values 0+0.1) < 0.00000001 &&
     floatAbs (floatAt shifted.values 1-0.45) < 0.00000001 && shifted.residual < 0.00000001)

  let mut eosValid := true
  for liquid in [0,0.1,0.5,0.9,1,1.1] do
    for gas in [101325,50000,10] do
      let pressure := mixtureEOSPressure liquid gas
      let reconstructed := liquid*2200000000/(2200000000+pressure-101325)+gas/pressure
      eosValid := eosValid && pressure > 0 && floatAbs (reconstructed-1) < 0.0000000001
  physicalCheck "18 mixed-phase EOS cases fill exactly one cell to numerical precision" eosValid

  let height := 20
  let i := 8*width+8
  let matter : Mixture := {water := 1111111,oxygen := 8555,nitrogen := 32188}
  let p := makeParticle matter 0 .water
  let p := {p with energy := p.chemical+internalEnergyAt matter .water 2000+potentialEnergy height width i p}
  let pressure := flashEquilibriumPressure p (thermalEnergy height width i p)
  let wet := atPressure p pressure
  let vapor := vaporWaterMoles height width i wet
  let wetT := temperature height width i wet
  IO.println s!"Wet-interface benchmark: vapor={vapor} nmol, temperature={wetT}/100 C, partial pressure={pressure}/1000 Pa"
  physicalCheck "a cool wet surface evaporates and cools below its initial 20 C"
    (vapor > 750 && vapor < 1100 && 1900 < wetT && wetT < 2000 && 1800000 < pressure && pressure < 2500000)
  physicalCheck "surface equilibrium does not overproduce its allowed vapor pressure"
    (predictedFlashPartialPressure p (thermalEnergy height width i p) pressure <= pressure)

  let initial := fillRect (newSimulation width.toUInt32 height.toUInt32) 1 10 (width-1) 19 .water
  let budget := auditSimulation initial
  let initialY := waterMomentY initial
  let mut pond := initial
  for _ in [:20] do pond := tickSimulation pond
  let above := read pond.world (11*width+width/2)
  let below := read pond.world (16*width+width/2)
  let head := (below.mechanicalPressure : Int)-(above.mechanicalPressure : Int)
  let mut totalWater := 0
  let mut speed := (0 : Int)
  for k in [:pond.width*pond.height] do
    let p := read pond.world k
    totalWater := totalWater+p.matter.water
    if p.matter.water > 100000 then speed := max speed (p.vx.natAbs+p.vy.natAbs : Nat)
  IO.println s!"Resting-pool benchmark: five-cell head={head}/1000 Pa, maximum liquid speed={speed} micrometres/s"
  physicalCheck "a resting pool reconstructs approximately 490 Pa over five centimetres"
    (450000 < head && head < 530000)
  let drift := ((waterMomentY pond : Int)-(initialY : Int)).natAbs
  physicalCheck "resting water centroid drifts less than one hundredth of a cell"
    (drift*100 < totalWater)
  physicalCheck "resting water retains exact element/energy budgets without exhausted retries"
    (auditSimulation pond == budget && pond.world.rejectedFluidSubsteps == 0)

  let mut sealed := fillRect (newSimulation width.toUInt32 height.toUInt32) 1 12 (width-1) 19 .water
  sealed := fillRect sealed (width/2) 1 (width/2+1) 16 .stone
  sealed := fillRect sealed 1 1 (width/2) 12 .hydrogen
  sealed := fillRect sealed (width/2+1) 1 (width-1) 12 .oxygen
  let sealedBudget := auditSimulation sealed
  for _ in [:20] do sealed := tickSimulation sealed
  let mut crossed := 0
  for y in [1:height-1] do
    for x in [width/2+1:width-1] do crossed := crossed+(read sealed.world (y*width+x)).matter.hydrogen
  physicalCheck "a liquid-filled connection does not swap hydrogen into a sealed oxygen chamber"
    (crossed == 0 && auditSimulation sealed == sealedBudget && sealed.world.rejectedFluidSubsteps == 0)

  let gasBox := fillRect (newSimulation width.toUInt32 height.toUInt32) 1 1 (width-1) 19 .oxygen
  let gasBox := fillRect gasBox (width/2-2) 12 (width/2+2) 16 .hydrogen
  let gasBudget := auditSimulation gasBox
  let initialMoment := hydrogenMomentY gasBox
  let mut bubble := gasBox
  for _ in [:20] do bubble := tickSimulation bubble
  physicalCheck "a hydrogen bubble rises through oxygen under the actual coupled solver"
    (hydrogenMomentY bubble < initialMoment && auditSimulation bubble == gasBudget &&
      bubble.world.rejectedFluidSubsteps == 0 && bubble.world.generation == 20)
