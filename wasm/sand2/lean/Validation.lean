import Sand2
open Sand2 Sand2.Chemistry

/-- Independent numerical/behavioral checks. These do not replace the general
    conservation and completeness proofs; they test parameter/unit choices and
    spatial behavior those invariants alone do not establish. -/
def check (label : String) (ok : Bool) : IO Unit := do
  unless ok do throw (IO.userError s!"FAILED: {label}")
  IO.println s!"PASS: {label}"

def silicaY (s : Simulation) : Nat := Id.run do
  let mut sum := 0
  for i in [:s.width*s.height] do
    let p := read s.world i
    if !p.anchored then sum := sum+p.matter.silica*(i/s.width)
  return sum

def waterX (s : Simulation) : Nat := Id.run do
  let mut sum := 0
  for i in [:s.width*s.height] do
    sum := sum+(read s.world i).matter.water*(i%s.width)
  return sum

def main : IO Unit := do
  let h := 20; let w := 24; let i := 10*w+12
  let room := makeAt h w i .empty
  check "ideal-gas air at 20 C is within 1 percent of atmospheric pressure"
    (100000000 < pressure h w i room && pressure h w i room < 102000000)
  let water := makeAt h w i .water
  check "water initialization reconstructs 20 C" (temperature h w i water == 2000)
  let melting := {water with energy := water.chemical+potentialEnergy h w i water+(waterDiagram water).meltEnd/2}
  check "half the fusion energy remains on the 0 C plateau"
    (temperature h w i melting == 0 && regime h w i melting == .melting)
  let boiling := {water with energy := water.chemical+potentialEnergy h w i water+
    ((waterDiagram water).boilStart+(waterDiagram water).boilEnd)/2}
  check "half the vaporization energy remains on the 100 C plateau"
    (temperature h w i boiling == 10000 && regime h w i boiling == .boiling)
  let quartz := makeAt h w i .sand
  let quartzMelt := {quartz with energy := quartz.chemical+potentialEnergy h w i quartz+
    ((solidDiagram quartz).meltStart+(solidDiagram quartz).meltEnd)/2}
  check "quartz fusion consumes finite latent heat at 1700 C"
    (temperature h w i quartzMelt == 170000 && solidRegime h w i quartzMelt == .melting)
  let iron := makeAt h w i .metal
  let ironMelt := {iron with energy := iron.chemical+potentialEnergy h w i iron+
    ((solidDiagram iron).meltStart+(solidDiagram iron).meltEnd)/2}
  check "iron fusion consumes finite latent heat at 1538 C"
    (temperature h w i ironMelt == 153800 && solidRegime h w i ironMelt == .melting)
  let fuel : Mixture := {biomass := 20,oxygen := 5}
  let burned := react .burnBiomass fuel (capacity .burnBiomass fuel)
  check "oxygen exhaustion leaves unburned fuel and balanced products"
    (burned.biomass == 15 && burned.oxygen == 0 && burned.water == 5 && burned.carbonDioxide == 5)
  check "no oxygen means no combustion at any temperature"
    (capacity .burnBiomass {biomass := 1000000} == 0)
  check "HCl does not dissolve quartz" (!possible .dissolveCarbonate {silica := 1000} {acid := 1000})
  let hot := makeAt h w i .fire
  let cold := makeAt h w (i+1) .ice
  let world := write (write (newWorld w h) i hot) (i+1) cold
  let after := (conduct i (i+1) (temperature h w i hot) (temperature h w (i+1) cold)).run world |>.2
  check "Fourier face flux cools the hot parcel and heats the cold parcel"
    ((read after i).energy < hot.energy && (read after (i+1)).energy > cold.energy)
  let start := paintSimulation (newSimulation 24 20) 12 3 1 1
  let mut fallen := start
  for _ in [:20] do fallen := tickSimulation fallen
  check "gravity lowers the sand centre of mass" (silicaY fallen > silicaY start)
  check "falling conserves all eleven elements and total energy exactly"
    (auditSimulation fallen == auditSimulation start)
  let dam := sceneSimulation (newSimulation 24 20) 1
  let mut spread := dam
  for _ in [:40] do spread := tickSimulation spread
  check "dam break moves water into the initially dry side" (waterX spread > waterX dam)
  check "dam break conserves all eleven elements and total energy exactly"
    (auditSimulation spread == auditSimulation dam)

  let oxygen := makeAt h w i .oxygen
  let nitrogen := makeAt h w (i+1) .nitrogen
  check "different gases begin at the same ideal-gas pressure"
    (pressure h w i oxygen == pressure h w (i+1) nitrogen)
  let mixed := gasDiffusionEdit h w i (i+1) oxygen nitrogen 300
  check "equal-pressure gases mix without waiting for a pressure gradient"
    (mixed.first.matter.nitrogen > 0 && mixed.second.matter.oxygen > 0)
  check "gas diffusion preserves complete energy exactly"
    (mixed.first.energy+mixed.second.energy == oxygen.energy+nitrogen.energy)
  let room2 := makeAt h w (i+w) .empty
  let uniform := gasDiffusionEdit h w i (i+w) room room2 300
  check "equal counterflows do not invent heat in uniform air"
    (uniform.first.energy == room.energy && uniform.second.energy == room2.energy)
  let heavy := makeAt h w i .oxygen
  let light := makeAt h w (i+w) .hydrogen
  let layers := write (write (newWorld w h) i heavy) (i+w) light
  let convected := (buoyancy i (i+w)).run layers |>.2
  check "lighter gas below heavier gas rises through the buoyancy operator"
    ((read convected i).matter.hydrogen > 0 && (read convected (i+w)).matter.oxygen > 0)
  let ironAcid := sceneSimulation (newSimulation 24 20) 5
  let changed := tickSimulation ironAcid
  let mut productGas := 0
  let mut productSalt := 0
  for k in [:changed.width*changed.height] do
    productGas := productGas+(read changed.world k).matter.carbonDioxide
    productSalt := productSalt+(read changed.world k).matter.calciumChloride
  check "acid on limestone produces actual CO2 and CaCl2 inventories"
    (productGas > 0 && productSalt > 0)
  check "trace reactants are not permanently stalled by integer division"
    (reactionExtent .burnBiomass {biomass := 1,oxygen := 1} 50000 == 1)
