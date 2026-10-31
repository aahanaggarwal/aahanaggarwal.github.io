import Sand2
open Sand2 Sand2.Chemistry

/-- Independent numerical/behavioral checks. These do not replace the general
    conservation and completeness proofs; they test parameter/unit choices and
    spatial behavior those invariants alone do not establish. -/
def check (label : String) (ok : Bool) : IO Unit := do
  unless ok do throw (IO.userError s!"FAILED: {label}")
  IO.println s!"PASS: {label}"
  (← IO.getStdout).flush

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

def main (args : List String) : IO Unit := do
  let h := 20; let w := (args.headD "24").toNat?.getD 24; let i := 10*w+12
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
  check "half the vaporization energy remains on the saturation plateau"
    (temperature h w i boiling == (water.boiling : Int) && regime h w i boiling == .boiling)
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
  let wetIronMatter := add iron.matter {water := 1}
  let wetIron := makeParticle wetIronMatter 0 .metal
  let wetIronH := internalEnergyAt wetIronMatter .metal 2000
  check "one trace water molecule cannot erase iron's fusion plateau"
    ((ironDiagram wetIron).meltStart > wetIronH && temperatureFromEnthalpy wetIron wetIronH == 2000)
  let mixedSolid := makeParticle (add iron.matter quartz.matter) 0 .metal
  let ironHalf := ((ironDiagram mixedSolid).meltStart+(ironDiagram mixedSolid).meltEnd)/2
  let silicaHalf := ((silicaDiagram mixedSolid).meltStart+(silicaDiagram mixedSolid).meltEnd)/2
  check "a mixed iron/silica parcel retains separate ordered fusion plateaus"
    (temperatureFromEnthalpy mixedSolid ironHalf == 153800 &&
     temperatureFromEnthalpy mixedSolid silicaHalf == 170000 &&
     (ironDiagram mixedSolid).meltEnd < (silicaDiagram mixedSolid).meltStart)
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
  let start := paintSimulation (newSimulation w.toUInt32 h.toUInt32) 12 3 1 1
  let mut fallen := start
  for _ in [:ticksPerSecond/3] do fallen := tickSimulation fallen
  check "gravity lowers the sand centre of mass" (silicaY fallen > silicaY start)
  check "falling conserves all eleven elements and total energy exactly"
    (auditSimulation fallen == auditSimulation start)
  let dam := sceneSimulation (newSimulation w.toUInt32 h.toUInt32) 1
  let mut spread := dam
  for _ in [:ticksPerSecond*2/3] do spread := tickSimulation spread
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
  let ironAcid := sceneSimulation (newSimulation w.toUInt32 h.toUInt32) 5
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

  let steam := makeAt h w i .steam
  check "water vapor diluted with air remains visibly steam"
    (vaporous h w i steam && labelAt h w i steam == .steam)
  check "phase conversion and temperature use the same water diagram for dilute vapor"
    ((conversionPhase h w i steam).water == regime h w i steam)

  check "the saturation curve reconstructs 1 atm boiling near 100 C"
    (9950 < saturationTemperature 101325000 && saturationTemperature 101325000 < 10050)
  check "lower pressure reduces the boiling point near 81 C at 50 kPa"
    (8080 < saturationTemperature 50000000 && saturationTemperature 50000000 < 8160)
  check "higher pressure raises the boiling point near 120 C at 200 kPa"
    (11980 < saturationTemperature 200000000 && saturationTemperature 200000000 < 12060)
  let pressureSteam := atPressure steam 200000000
  check "changing pressure does not reset superheated vapor temperature"
    (temperature h w i pressureSteam == temperature h w i steam)
  let vaporCount := vaporWaterMoles h w i boiling
  check "half the latent interval supports half the vapor molecules"
    (vaporCount+1 >= water.matter.water/2 && vaporCount <= water.matter.water/2+1)
  let evaporated := gasFlowEdit h w i (i+1) boiling room 8
  check "partially boiled water releases only its available vapor fraction"
    (evaporated.second.matter.water == vaporCount/8 && evaporated.first.matter.water < boiling.matter.water)
  check "partial evaporation transfers vaporization energy without loss"
    (evaporated.first.energy+evaporated.second.energy == boiling.energy+room.energy)
  let sealedH : Int := 105000000000000000
  let sealedP := flashEquilibriumPressure water sealedH
  let sealed := atPressure {water with energy := water.chemical+potentialEnergy h w i water+sealedH} sealedP
  check "a sealed hot-water cell raises its own saturation pressure"
    (600000000 < sealedP && sealedP < 1000000000 && 16000 < temperature h w i sealed && temperature h w i sealed < 17500)
  let residual := (sealedP : Int)-(predictedFlashPartialPressure water sealedH sealedP : Int)
  check "sealed-cell phase-pressure residual stays below 10 kPa in the benchmark"
    (residual.natAbs < 10000000)

  let h2 := matterFor .hydrogen
  let n2 := matterFor .nitrogen
  let relative := dryCapacity h2 * (Chemistry.mass n2 : Int) / max 1 (dryCapacity n2 * (Chemistry.mass h2 : Int))
  check "hydrogen closed-cell specific heat is over ten times nitrogen, not a shared air value"
    (relative >= 13 && relative <= 14)

  check "equal-temperature oxygen and nitrogen mix without inventing heat"
    (temperature h w i mixed.first == 2000 && temperature h w (i+1) mixed.second == 2000)
  let compressed := makeParticle {carbonDioxide := 1000000} 0 .carbonDioxide
  let compressedEnergy := compressed.chemical+internalEnergyAt compressed.matter .carbonDioxide 2000+potentialEnergy h w i compressed
  let compressed := {compressed with energy := compressedEnergy}
  check "compressed gas remains gas even when its mass exceeds the old threshold"
    (gasCell h w i compressed && temperature h w i compressed == 2000)

  let dropStart := fillRect (newSimulation w.toUInt32 40) 8 3 9 4 .sand
  let initialGrain := read dropStart.world (3*w+8)
  let initialThermal := thermalEnergy 40 w (3*w+8) initialGrain
  let mut drop := dropStart
  for _ in [:ticksPerSecond/10] do drop := tickSimulation drop
  let mut distance := (0 : Int)
  let mut speed := (0 : Int)
  let mut thermalChange := (0 : Int)
  for k in [:drop.width*drop.height] do
    let p := read drop.world k
    if p.matter.silica > 0 then
      distance := (k/drop.width : Nat)*1000000+p.ry-3000000
      speed := p.vy
      thermalChange := thermalEnergy drop.height drop.width k p-initialThermal
  check "a free grain falls 4.905 cm in 0.1 simulated seconds"
    ((distance-4905000).natAbs <= 100 && speed == 981000)
  check "free-fall numerical/thermal drift stays below 10 microjoules"
    (thermalChange.natAbs < 1000000000)

  let methane := makeAt h w i .methane
  let co := makeAt h w (i+1) .carbonMonoxide
  check "methane and CO initialize as 20 C gases at atmospheric pressure"
    (gasCell h w i methane && gasCell h w (i+1) co && temperature h w i methane == 2000 &&
     temperature h w (i+1) co == 2000 && pressure h w i methane == pressure h w (i+1) co)
  let gasMix := gasDiffusionEdit h w i (i+1) methane co (diffusionDivisor methane.matter co.matter)
  check "methane and CO diffuse without inventing heat or chemical energy"
    (gasMix.first.matter.carbonMonoxide > 0 && gasMix.second.matter.methane > 0 &&
     temperature h w i gasMix.first == 2000 && temperature h w (i+1) gasMix.second == 2000)
  let complete : Mixture := {methane := 7,oxygen := 14}
  let completeOut := react .burnMethane complete (capacity .burnMethane complete)
  check "complete methane combustion produces seven CO2 and fourteen H2O units"
    (completeOut.methane == 0 && completeOut.oxygen == 0 && completeOut.carbonDioxide == 7 && completeOut.water == 14)
  let rich : Mixture := {methane := 10,oxygen := 15}
  let richOut := react .partialMethane rich (capacity .partialMethane rich)
  check "oxygen-poor methane produces CO and water with exact stoichiometry"
    (richOut.methane == 0 && richOut.oxygen == 0 && richOut.carbonMonoxide == 10 && richOut.water == 20)
  check "the kinetic router selects the oxygen-poor methane branch exclusively"
    (!possible .burnMethane rich {} && possible .partialMethane rich {})
  let veryRich : Mixture := {methane := 10,oxygen := 3}
  let limited := react .partialMethane veryRich (capacity .partialMethane veryRich)
  check "oxygen exhaustion retains unburned methane alongside CO"
    (limited.methane == 8 && limited.oxygen == 0 && limited.carbonMonoxide == 2 && limited.water == 4)
  let oxidized := react .burnCarbonMonoxide {carbonMonoxide := 10,oxygen := 5} 5
  check "CO burns to CO2 without fabricating oxygen"
    (oxidized.carbonMonoxide == 0 && oxidized.oxygen == 0 && oxidized.carbonDioxide == 10)
  let methaneBox := sceneSimulation (newSimulation w.toUInt32 h.toUInt32) 10
  let methaneBox := tickSimulation methaneBox
  let mut actualCO := 0
  for k in [:methaneBox.width*methaneBox.height] do actualCO := actualCO+(read methaneBox.world k).matter.carbonMonoxide
  check "the full fuel-rich methane experiment produces actual CO inventory"
    (actualCO > 0 && methaneBox.world.generation == 1 && methaneBox.world.rejectedFluidSubsteps == 0)

  let hotHydrogenMatter : Mixture := {hydrogen := 2000,oxygen := 1000}
  let hotHydrogen := makeParticle hotHydrogenMatter 0 .hydrogen
  let hotHydrogen := {hotHydrogen with
    energy := hotHydrogen.chemical+internalEnergyAt hotHydrogenMatter .hydrogen 60000+potentialEnergy h w i hotHydrogen}
  let hydrogenWorld := write (newWorld w h) i hotHydrogen
  let hydrogenAfter := ((reactInside i 60000).run hydrogenWorld).2
  check "hot hydrogen/oxygen keeps reacting without a carbonaceous ignition parcel"
    ((read hydrogenAfter i).matter.hydrogen < 2000 && (read hydrogenAfter i).matter.water > 0)

  let methaneMatter := matterFor .methane
  let coMatter := matterFor .carbonMonoxide
  let methaneHeating := internalEnergyAt methaneMatter .methane 3000-internalEnergyAt methaneMatter .methane 2000
  let coHeating := internalEnergyAt coMatter .carbonMonoxide 3000-internalEnergyAt coMatter .carbonMonoxide 2000
  check "heating one cubic centimetre of methane and CO by 10 K uses their distinct Cv values"
    (1100000000000 < methaneHeating && methaneHeating < 1180000000000 &&
     840000000000 < coHeating && coHeating < 890000000000)
