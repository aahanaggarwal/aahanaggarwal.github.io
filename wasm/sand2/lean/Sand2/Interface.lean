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
  | .metal => "Fixed iron fixture. Conducts heat, rusts and reacts with aqueous HCl."

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
        let pressure := pressure s.height s.width i p
        let red := (max 0 (min 255 ((pressure-80000000)/2000000))).toNat.toUInt32
        red*65536+20*256+(255-red)
      else materialColor m
    let grain := if m == .empty || edge s.width s.height i || view != 0 then (0 : Int)
      else (((i.toUInt32*747796405+s.world.generation.toUInt32*2891336453) >>> 24)%13).toNat-6
    for shift in [16,8,0] do
      let v : Int := ((color >>> shift) &&& 255).toNat
      result := result.push ((max 0 (min 255 (v+grain))).toNat.toUInt8)
    result := result.push 255
  return result

@[noinline] def countSimulation (s : Simulation) : UInt32 := Id.run do
  let mut n := 0
  for i in [:s.width*s.height] do
    if !edge s.width s.height i && labelAt s.height s.width i (read s.world i) != .empty then n := n+1
  return n.toUInt32

@[noinline] def inspectSimulation (s : Simulation) (x y : UInt32) : String :=
  let i := (min (s.height-1) y.toNat)*s.width+min (s.width-1) x.toNat
  let p := read s.world i
  let t := temperature s.height s.width i p
  materialName (labelAt s.height s.width i p) ++ " | " ++ toString (t/100) ++ " C | " ++
    toString (pressure s.height s.width i p/1000) ++ " Pa | " ++ toString p.mass ++ " ng"

def quantities : List Quantity := [.hydrogen,.oxygen,.carbon,.silicon,.sodium,.chlorine,
  .calcium,.iron,.potassium,.nitrogen,.sulfur,.energy]

@[noinline] def auditSimulation (s : Simulation) : String :=
  String.intercalate "," (quantities.map fun q => toString (inventory s.world q))

def mixHash (h : UInt64) (n : Int) : UInt64 := (h ^^^ (n % 18446744073709551616).toNat.toUInt64)*1099511628211

@[noinline] def digestSimulation (s : Simulation) : UInt64 := Id.run do
  let mut h := mixHash 14695981039346656037 s.world.generation
  for i in [:s.width*s.height] do
    let p := read s.world i
    let m := p.matter
    for v in [m.water,m.oxygen,m.nitrogen,m.carbonDioxide,m.biomass,m.oil,m.carbon,
      m.silica,m.salt,m.acid,m.carbonate,m.calciumChloride,m.iron,m.rust,
      m.ironChloride,m.hydrogen,m.nitrate,m.sulfur,m.sulfide] do
      h := mixHash h v
    for v in [p.energy,p.px,p.py,p.rx,p.ry,p.luminous,p.stamp,(materialCode p.label).toNat,
      if p.anchored then 1 else 0,if p.fractured then 1 else 0] do
      h := mixHash h v
  return h

@[noinline] def oracle (scene ticks : UInt32) : String := Id.run do
  let mut s := sceneSimulation (newSimulation 24 20) scene
  for _ in [:ticks.toNat] do s := tickSimulation s
  return toString (digestSimulation s) ++ ";" ++ auditSimulation s

end Sand2
