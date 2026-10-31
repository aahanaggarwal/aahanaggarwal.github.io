import Sand2.Evolution

namespace Sand2
open Chemistry

@[noinline] def newSimulation (width height : UInt32) : Simulation :=
  let width := max 16 (min 192 width.toNat)
  let height := max 16 (min 128 height.toNat)
  ⟨width,height,newWorld width height⟩

@[noinline] def tickSimulation (s : Simulation) : Simulation :=
  {s with world := stepWorld s.world}

@[noinline] def clearSimulation (s : Simulation) : Simulation :=
  {s with world := newWorld s.width s.height}

/-- Edits inject/remove physical inventories explicitly, outside closed-system
    stepping. They cannot alter the vessel boundary or construct invalid tags. -/
@[noinline] def paintSimulation (s : Simulation) (cx cy : Int32) (radius code : UInt32) : Simulation := Id.run do
  let m := decodeMaterial code
  let radius := min 16 (max 1 radius.toNat)
  let x := cx.toInt
  let y := cy.toInt
  let r : Int := radius
  let mut w := s.world
  for yy in [(max 1 (y-r)).toNat:min (s.height-1) (y+r+1).toNat] do
    for xx in [(max 1 (x-r)).toNat:min (s.width-1) (x+r+1).toNat] do
      if ((xx : Int)-x)^2+((yy : Int)-y)^2 <= r*r then
        let i := yy*s.width+xx
        w := write w i (makeAt s.height s.width i m false)
  return {s with world := w}

@[noinline] def fillRect (s : Simulation) (x0 y0 x1 y1 : Nat) (m : Material) : Simulation := Id.run do
  let mut w := s.world
  for y in [max 1 y0:min (s.height-1) y1] do
    for x in [max 1 x0:min (s.width-1) x1] do
      let i := y*s.width+x
      w := write w i (makeAt s.height s.width i m false)
  return {s with world := w}

/-- Starter experiments live beside the solver; JavaScript supplies only a scene
    identifier. The values are deliberate external initial conditions. -/
@[noinline] def sceneSimulation (s : Simulation) (scene : UInt32) : Simulation := Id.run do
  let mut s := clearSimulation s
  let w := s.width
  let h := s.height
  match scene.toNat with
  | 1 => -- Dam break: gravity, free surface and obstacles.
    s := fillRect s 2 (h/3) (w/3) (h-2) .water
    s := fillRect s (w/2) (h*3/4) (w/2+3) (h-1) .stone
    s := fillRect s (w*3/4) (h/3) (w*3/4+8) (h/3+6) .sand
  | 2 => -- Latent heat: water and finite hot/cold reservoirs.
    s := fillRect s (w/4) (h/2) (w*3/4) (h-3) .water
    s := fillRect s (w/4) (h-3) (w*3/4) (h-1) .lava
    s := fillRect s (w/3) (h/3) (w/2) (h/2) .ice
  | 3 => -- Oxygen-limited combustion chamber.
    s := fillRect s (w/4) (h*2/3) (w*3/4) (h*2/3+4) .wood
    s := fillRect s (w/2-2) (h*2/3-3) (w/2+3) (h*2/3) .fire
    s := fillRect s (w/4) (h*2/3-2) (w/4+5) (h*2/3) .oil
  | 4 => -- Density separation and granular settling.
    s := fillRect s (w/5) (h/2) (w*4/5) (h-2) .water
    s := fillRect s (w/4) (h/3) (w*3/4) (h/2) .oil
    s := fillRect s (w/3) 3 (w*2/3) (h/4) .sand
  | 5 => -- Selective acid/carbonate chemistry and gas evolution.
    s := fillRect s (w/4) (h*2/3) (w*3/4) (h*2/3+4) .limestone
    s := fillRect s (w/4) (h/2) (w*3/4) (h*2/3) .acid
  | 6 => -- Equal-pressure gas diffusion and density-driven convection.
    s := fillRect s 2 (h/2) (w/2) (h-2) .oxygen
    s := fillRect s (w/2) (h/2) (w-2) (h-2) .hydrogen
  | 7 => -- Finite, balanced energetic reaction; no prescribed blast radius.
    s := fillRect s (w/3) (h*2/3) (w*2/3) (h-2) .gunpowder
    s := fillRect s (w/3-2) (h*2/3-2) (w/3+2) (h*2/3+2) .fire
  | 8 => -- Iron fusion/solidification and finite hot/cold reservoirs.
    s := fillRect s (w/4) (h*2/3) (w*3/4) (h-2) .water
    s := fillRect s (w/3) (h/3) (w*2/3) (h/2) .moltenIron
  | 9 => -- Communicating vessels: pressure must raise the initially empty arm.
    s := fillRect s (w/2) (h/6) (w/2+1) (h*4/5) .stone
    s := fillRect s 2 (h/6) (w/2) (h-1) .water
  | _ => pure ()
  return s

def description : Material → String
  | .empty => "Air reservoir: finite oxygen and nitrogen. Erasing replaces a parcel with room-temperature air."
  | .sand => "Quartz grains. Fall under gravity, form piles and exchange heat."
  | .water => "H2O with sensible heat, fusion energy and vaporization energy."
  | .stone => "Fixed quartz fixture. Transfers heat; hydrochloric acid does not dissolve silica."
  | .wood | .plant => "Fixed CH2O biomass surrogate. Burning requires heat and consumes oxygen. Biology is outside this model."
  | .fire => "A small hot hydrocarbon and oxygen parcel. A finite ignition source."
  | .steam => "Hot water vapor mixed with air. Pressure-driven molecular transport."
  | .oil => "CH2 hydrocarbon surrogate, less dense than water. Oxygen-limited combustion."
  | .acid => "Aqueous HCl. Reacts stoichiometrically with iron and carbonate, not arbitrary solids."
  | .lava => "Hot molten silica reservoir. Finite stored energy heats surrounding matter."
  | .ice => "Frozen water at -10 C. Melting requires latent heat."
  | .smoke => "Warm carbon dioxide and water mixture. Cooling never deletes its molecules."
  | .glass | .obsidian => "Fixed silica fixture with the same conserved SiO2 inventory."
  | .gunpowder => "KNO3, sulfur and carbon. Explicit balanced reaction creates hot gas."
  | .salt => "NaCl grains. Their sodium and chlorine inventory remains conserved."
  | .saltWater => "Aqueous NaCl mixture. Water and salt are separate molecular inventories."
  | .ember => "A hot biomass and carbon parcel. Remaining fuel is finite."
  | .ash => "Silica and carbon residue. Carbon can oxidize when hot enough."
  | .metal => "Iron fixture. Conducts heat, rusts and reacts with aqueous HCl."
  | .limestone => "Fixed calcium carbonate. HCl produces calcium chloride, water and carbon dioxide."
  | .oxygen => "O2 at room temperature and atmospheric pressure. Supports balanced combustion."
  | .nitrogen => "N2 at room temperature and atmospheric pressure. Inert within the declared chemistry."
  | .carbonDioxide => "CO2 at room temperature and atmospheric pressure. Diffuses without disappearing."
  | .hydrogen => "H2 at room temperature and atmospheric pressure. Combusts with oxygen when ignited."
  | .charcoal => "Porous carbon grains. Oxidize to CO2 when hot and supplied with oxygen."
  | .rust => "Fe2O3 grains, also produced by oxidation of iron. All iron and oxygen remain accounted for."
  | .nitrate => "KNO3 grains. React with sulfur and carbon in the declared gunpowder reaction."
  | .sulfur => "Elemental sulfur grains. One reactant in the balanced gunpowder mixture."
  | .calciumChloride => "CaCl2 grains. A non-gaseous product of the limestone and acid reaction."
  | .ironChloride => "FeCl2 grains. Iron and acid produce this salt and hydrogen."
  | .moltenIron => "Iron above its fusion plateau. Solidification retains mass and latent heat."

@[noinline] def catalogue : String :=
  "[" ++ String.intercalate "," ((materials.filter (· != .empty)).map fun m =>
    "{\"id\":" ++ toString (materialCode m) ++ ",\"name\":\"" ++ materialName m ++
    "\",\"color\":" ++ toString (materialColor m) ++ ",\"type\":\"" ++ materialKind m ++
    "\",\"description\":\"" ++ description m ++ "\"}") ++ "]"

/-- Read-only projection. Rendering never changes the random seed or world. -/
@[noinline] def renderSimulation (s : Simulation) (view : UInt32) : ByteArray := Id.run do
  let mut result := ByteArray.emptyWithCapacity (s.width*s.height*4)
  for i in [:s.width*s.height] do
    let p := read s.world i
    let m := labelAt s.height s.width i p
    let color := if edge s.width s.height i then (0x193219 : UInt32)
      else if view == 1 then
        let t := temperature s.height s.width i p
        let red := (max 0 (min 255 ((t+2000)/400))).toNat.toUInt32
        let blue := (255-red)
        red*65536+24*256+blue
      else if view == 2 then
        let pressure : Int := if fluidObstacle s.height s.width i p then 0 else p.mechanicalPressure
        let red := (max 0 (min 255 ((pressure-80000000)/2000000))).toNat.toUInt32
        red*65536+20*256+(255-red)
      else materialColor m
    let fill := if view == 0 && !fluidObstacle s.height s.width i p && isLiquid m then
      min 256 (occupiedLiquidVolume s.height s.width i p*256/cellVolume) else 256
    let grain := if m == .empty || edge s.width s.height i || view != 0 then (0 : Int)
      else (((i.toUInt32*747796405+s.world.generation.toUInt32*2891336453) >>> 24)%13).toNat-6
    for shift in [16,8,0] do
      let channel := ((color >>> shift) &&& 255).toNat
      let v : Int := (channel*fill+10*(256-fill))/256
      result := result.push ((max 0 (min 255 (v+grain))).toNat.toUInt8)
    result := result.push 255
  return result

@[noinline] def countSimulation (s : Simulation) : UInt32 := Id.run do
  let mut n := 0
  for i in [:s.width*s.height] do
    if !edge s.width s.height i && labelAt s.height s.width i (read s.world i) != .empty then n := n+1
  return n.toUInt32

def fixedTwo (n : Nat) : String :=
  toString (n/100) ++ "." ++ (if n%100 < 10 then "0" else "") ++ toString (n%100)

def temperatureText (t : Int) : String := (if t < 0 then "-" else "") ++ fixedTwo t.natAbs

def massText (mass : Nat) : String :=
  if mass >= 1000000000 then fixedTwo (mass/10000000) ++ " g"
  else if mass >= 1000000 then fixedTwo (mass/10000) ++ " mg"
  else fixedTwo (mass/10) ++ " ug"

@[noinline] def inspectSimulation (s : Simulation) (x y : UInt32) : String :=
  let i := (min (s.height-1) y.toNat)*s.width+min (s.width-1) x.toNat
  let p := read s.world i
  let t := temperature s.height s.width i p
  let pressureText := if fluidObstacle s.height s.width i p then "solid"
    else fixedTwo (p.mechanicalPressure/10000) ++ " kPa"
  let liquidText := if !fluidObstacle s.height s.width i p && liquidVolume s.height s.width i p > 0 then
    " | " ++ fixedTwo (min 10000 ((occupiedLiquidVolume s.height s.width i p*10000+cellVolume/2)/cellVolume)) ++ "% liquid"
    else ""
  materialName (labelAt s.height s.width i p) ++ " | " ++ temperatureText t ++ " C | " ++
    pressureText ++ " | " ++ massText p.mass ++ liquidText

def quantities : List Quantity := [.hydrogen,.oxygen,.carbon,.silicon,.sodium,.chlorine,
  .calcium,.iron,.potassium,.nitrogen,.sulfur,.energy]

@[noinline] def auditSimulation (s : Simulation) : String :=
  String.intercalate "," (quantities.map fun q => toString (inventory s.world q))

def mixHash (h : UInt64) (n : Int) : UInt64 := (h ^^^ (n % 18446744073709551616).toNat.toUInt64)*1099511628211

@[noinline] def digestSimulation (s : Simulation) : UInt64 := Id.run do
  let mut h := mixHash 14695981039346656037 s.world.generation
  h := mixHash h s.world.rejectedFluidSubsteps
  h := mixHash h s.world.fluidResidual
  for i in [:s.width*s.height] do
    let p := read s.world i
    let m := p.matter
    for v in [m.water,m.oxygen,m.nitrogen,m.carbonDioxide,m.biomass,m.oil,m.carbon,
      m.silica,m.salt,m.acid,m.carbonate,m.calciumChloride,m.iron,m.rust,
      m.ironChloride,m.hydrogen,m.nitrate,m.sulfur,m.sulfide] do
      h := mixHash h v
    for v in [p.energy,p.px,p.py,p.rx,p.ry,p.luminous,p.stamp,p.mechanicalPressure,p.phasePressure,p.boiling,p.boilingFine,(materialCode p.label).toNat,
      if p.anchored then 1 else 0,if p.fractured then 1 else 0] do
      h := mixHash h v
  return h

/-- Read-only spatial inventory for numerical experiments and diagnostics.
    Rectangle bounds are clamped just like painting; no host reads raw state. -/
def waterInRegionSimulation (s : Simulation) (x0 y0 x1 y1 : UInt32) : UInt64 := Id.run do
  let mut count := 0
  for y in [min s.height y0.toNat:min s.height y1.toNat] do
    for x in [min s.width x0.toNat:min s.width x1.toNat] do
      count := count+(read s.world (y*s.width+x)).matter.water
  return count.toUInt64

def maxLiquidVolumeSimulation (s : Simulation) : UInt64 := Id.run do
  let mut largest := 0
  for i in [:s.width*s.height] do largest := max largest (occupiedLiquidVolume s.height s.width i (read s.world i))
  return largest.toUInt64

def solverFailuresSimulation (s : Simulation) : UInt64 := s.world.rejectedFluidSubsteps.toUInt64

/-- Read-only native profiling probe. The host times complete Lean operations;
    it contains no duplicate implementation of any physics or numerical loop. -/
@[noinline] def numericalProbeSimulation (s : Simulation) (stage : UInt32) : UInt64 := Id.run do
  if stage == 5 then
    return digestSimulation {s with world := (thermochemicalStep.run s.world).2}
  if stage == 6 then return digestSimulation {s with world := (fluidStep.run s.world).2}
  let g := fluidGeometry s.world
  let mut hash := (14695981039346656037 : UInt64)
  if stage == 0 then
    for i in [:s.width*s.height] do
      hash := (hash ^^^ (floatAt g.pressure i).toBits)*1099511628211
    return hash
  if stage == 1 || stage == 2 then
    let system := viscositySystem g (1/120) (stage == 2)
    let solved := pressureSolve system 128 0.00000001
    for i in [:s.width*s.height] do
      hash := (hash ^^^ (floatAt solved.values i).toBits)*1099511628211
    return hash
  if stage == 3 || stage == 7 then
    let velocity := projectFluid g (1/120)
    if stage == 7 then return velocity.iterations.toUInt64
    for i in [:s.width*s.height] do
      hash := (hash ^^^ (floatAt velocity.u i).toBits)*1099511628211
      hash := (hash ^^^ (floatAt velocity.v i).toBits)*1099511628211
      hash := (hash ^^^ (floatAt velocity.pressure i).toBits)*1099511628211
    return hash
  return digestSimulation {s with world := ((fluidCandidate (1/120)).run s.world).2}

def stepCountSimulation (s : Simulation) : UInt32 := s.world.generation.toUInt32

def timeMillisecondsSimulation (s : Simulation) : UInt64 :=
  (elapsedMilliseconds s.world.generation).toUInt64

@[noinline] def oracle (scene ticks : UInt32) : String := Id.run do
  let mut s := sceneSimulation (newSimulation 24 20) scene
  for _ in [:ticks.toNat] do s := tickSimulation s
  return toString (digestSimulation s) ++ ";" ++ auditSimulation s

end Sand2
