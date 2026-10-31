import Sand2.Mixture
import Sand2.Thermodynamics

namespace Sand2
open Chemistry

/-- One cell is one cubic centimetre. Inventories count nanomoles; mass is in
    nanograms, temperature in 0.01 C, pressure in millipascals. Momentum is mass
    times micrometres/second. Energy units are 10^-14 J. -/
def air : Mixture := {oxygen := 8730, nitrogen := 32845}

def dryCapacity (m : Mixture) : Int :=
  (1000 : Int)*(32*m.oxygen+28*m.nitrogen+44*m.carbonDioxide+2*m.hydrogen) +
  1700*(30*m.biomass) + 2000*(14*m.oil) + 710*(12*m.carbon) +
  730*(60*m.silica) + 850*(58*m.salt) + 3500*(36*m.acid) +
  840*(100*m.carbonate) + 850*(110*m.calciumChloride) +
  450*(56*m.iron) + 650*(160*m.rust) + 650*(126*m.ironChloride) +
  1000*(101*m.nitrate+32*m.sulfur+110*m.sulfide)

/-- The cached mass and chemical energy have proofs tying them to matter.
    They cannot drift independently of the molecular inventory. -/
structure Particle where
  matter : Mixture
  mass : Nat
  mass_eq : mass = Chemistry.mass matter
  chemical : Int
  chemical_eq : chemical = chemicalEnergy matter
  capacity : Int
  capacity_eq : capacity = dryCapacity matter
  energy : Int
  px : Int := 0
  py : Int := 0
  rx : Int := 0
  ry : Int := 0
  label : Material := .empty
  anchored : Bool := false
  fractured : Bool := false
  luminous : Nat := 0
  stamp : Nat := 0

def makeParticle (matter : Mixture) (energy : Int) (label : Material := .empty)
    (anchored : Bool := false) : Particle :=
  {matter, mass := Chemistry.mass matter, mass_eq := rfl,
   chemical := chemicalEnergy matter, chemical_eq := rfl,
   capacity := dryCapacity matter, capacity_eq := rfl, energy,label,anchored}

def replaceMatter (p : Particle) (matter : Mixture) : Particle :=
  {makeParticle matter p.energy p.label p.anchored with
    px := p.px, py := p.py, rx := p.rx, ry := p.ry, fractured := p.fractured,
    luminous := p.luminous, stamp := p.stamp}

def Particle.vx (p : Particle) : Int := p.px / max 1 p.mass
 def Particle.vy (p : Particle) : Int := p.py / max 1 p.mass

def kineticEnergy (p : Particle) : Int :=
  (p.px*p.px+p.py*p.py)/(2*(max 1 p.mass : Nat)*10000000000)

def potentialEnergy (height width i : Nat) (p : Particle) : Int :=
  (p.mass : Int)*981*((height-i/width : Nat)*1000000-p.ry)/(100*1000000)

def thermalEnergy (height width i : Nat) (p : Particle) : Int :=
  p.energy-p.chemical-kineticEnergy p-potentialEnergy height width i p

/-- The water component has a finite fusion and vaporization enthalpy. Other
    species contribute sensible heat to the same mixed-cell temperature. -/
def waterDiagram (p : Particle) (boiling : Nat := 10000) : PhaseDiagram :=
  let waterMass := p.matter.water*18
  let fusion : Int := Int.ofNat (waterMass*33400000)
  let capacity : Int := Int.ofNat (waterMass*4180) + max 0 p.capacity
  let boil := fusion + capacity * (boiling : Int)
  let vapor := boil + Int.ofNat (waterMass*225700000)
  ⟨0,fusion,boil,vapor,Int.natCast_nonneg _,
   Int.le_add_of_nonneg_right (Int.mul_nonneg (by have h := Int.natCast_nonneg (waterMass*4180); dsimp [capacity]; omega) (Int.natCast_nonneg _)),
   Int.le_add_of_nonneg_right (Int.natCast_nonneg _)⟩

def regime (height width i : Nat) (p : Particle) (boiling : Nat := 10000) : WaterRegime :=
  phase (waterDiagram p boiling) (thermalEnergy height width i p)

/-- Rounded single-component fusion model for iron and quartz. Mixed water
    cells use the water diagram; mineral polymorph chemistry is not modeled. -/
def solidMeltingPoint (p : Particle) : Nat := if p.matter.iron*56 > p.mass/2 then 153800 else 170000

def solidFusion (p : Particle) : Nat :=
  if p.matter.iron*56 > p.mass/2 then p.matter.iron*56*24700000
  else p.matter.silica*60*15000000

def solidDiagram (p : Particle) : PhaseDiagram :=
  let start := max 0 p.capacity * (solidMeltingPoint p : Int)
  let finish := start + Int.ofNat (solidFusion p)
  ⟨start,finish,finish+1000000000000000000000000000000,
   finish+2000000000000000000000000000000,
   Int.le_add_of_nonneg_right (Int.natCast_nonneg _),by omega,by omega⟩

def solidRegime (height width i : Nat) (p : Particle) : WaterRegime :=
  phase (solidDiagram p) (thermalEnergy height width i p)

def temperature (height width i : Nat) (p : Particle) (boiling : Nat := 10000) : Int :=
  let h := thermalEnergy height width i p
  let wm := (p.matter.water*18 : Nat)
  if wm == 0 then
    if p.matter.silica*60 > p.mass/2 || p.matter.iron*56 > p.mass/2 then
      let d := solidDiagram p
      if h < d.meltStart then h / max 1 p.capacity
      else if h < d.meltEnd then solidMeltingPoint p
      else (h-(solidFusion p : Int))/max 1 p.capacity
    else h / max 1 p.capacity
  else
    let d := waterDiagram p boiling
    match phase d h with
    | .ice => h / max 1 ((wm : Int)*2100+p.capacity)
    | .melting => 0
    | .liquid => (h-d.meltEnd)/max 1 ((wm : Int)*4180+p.capacity)
    | .boiling => boiling
    | .vapor => (boiling : Int)+(h-d.boilEnd)/max 1 ((wm : Int)*2000+p.capacity)

def vaporous (height width i : Nat) (p : Particle) : Bool :=
  p.matter.water > 0 && regime height width i p == .vapor

def pressure (height width i : Nat) (p : Particle) : Int :=
  let n := gasMoles p.matter (vaporous height width i p)
  (n : Int)*8314*max 1 (temperature height width i p+27315)/100000

/-- Initial sensible/phase enthalpy for a requested temperature. Editing is an
    explicit external energy/matter injection, never part of physics stepping. -/
def enthalpyAt (m : Mixture) (label : Material) (t : Int) : Int :=
  let wm : Int := m.water*18
  let other := dryCapacity m*t
  if wm == 0 then
    let iron := m.iron*56
    let silica := m.silica*60
    other + (if iron > 0 && t >= 153800 then (iron*24700000 : Nat) else 0) +
      (if silica > 0 && t >= 170000 then (silica*15000000 : Nat) else 0)
  else if label == .ice then wm*2100*t+other
  else if label == .steam || label == .fire || label == .smoke then
    wm*(300900000+2000*(t-10000))+other
  else wm*(33400000+4180*t)+other

def matterFor : Material → Mixture
  | .empty => air
  | .water | .ice => {water := 55555555}
  | .steam => {air with water := 41575}
  | .sand | .glass | .stone | .obsidian | .lava => {silica := 44166666}
  | .wood | .plant => {biomass := 23333333}
  | .oil => {oil := 57142857}
  | .acid => {water := 45000000, acid := 3000000}
  | .salt => {salt := 37310344}
  | .saltWater => {water := 53000000, salt := 700000}
  | .metal => {iron := 140357142}
  | .gunpowder => {nitrate := 12592592, sulfur := 6296296, carbon := 18888888}
  | .fire => {air with oil := 10000, oxygen := 30000}
  | .smoke => {air with carbonDioxide := 20000, water := 20000}
  | .ember => {biomass := 20000000, carbon := 1000000}
  | .ash => {silica := 2000000, carbon := 100000}

def makeAt (height width i : Nat) (m : Material) (anchored : Bool := false) : Particle :=
  let matter := matterFor m
  let t := match m with
    | .lava => 180000 | .fire => 90000 | .ember => 65000 | .ice => -1000
    | .steam => 13000 | .smoke => 14000 | _ => 2000
  let p := makeParticle matter 0 m anchored
  {p with
    energy := p.chemical+enthalpyAt matter m t+potentialEnergy height width i p
    luminous := (if m == .fire || m == .ember then 16 else 0)}

/-- Fixed dimensions and exact grid shape are carried by the Lean state. -/
structure World (width height : Nat) where
  cells : Array Particle
  size_eq : cells.size = width*height
  generation : Nat := 0
  seed : UInt32 := 0x5a172026

structure Simulation where
  width : Nat
  height : Nat
  world : World width height

def read (w : World width height) (i : Nat) : Particle :=
  if h : i < w.cells.size then w.cells[i] else makeAt height width 0 .empty

def write (w : World width height) (i : Nat) (p : Particle) : World width height :=
  {w with cells := w.cells.set! i p, size_eq := by simpa using w.size_eq}

def inside (width height : Nat) (x y : Int) : Bool :=
  0 ≤ x && 0 ≤ y && x < (width : Int) && y < (height : Int)

def idx (width : Nat) (x y : Int) : Nat := y.toNat*width+x.toNat

def edge (width height i : Nat) : Bool :=
  i%width == 0 || i/width == 0 || i%width+1 == width || i/width+1 == height

def newWorld (width height : Nat) : World width height :=
  let cells := Array.ofFn fun (i : Fin (width*height)) =>
    makeAt height width i (if edge width height i then .metal else .empty) (edge width height i)
  ⟨cells,by simp [cells],0,0x5a172026⟩

theorem particle_mass_is_molecular_mass (p : Particle) : p.mass = Chemistry.mass p.matter := p.mass_eq

theorem particle_chemical_energy_is_inventory_energy (p : Particle) : p.chemical = chemicalEnergy p.matter := p.chemical_eq

theorem replacing_matter_keeps_total_energy (p : Particle) (m : Mixture) : (replaceMatter p m).energy = p.energy := rfl

theorem write_preserves_grid_shape (w : World width height) (i : Nat) (p : Particle) :
    (write w i p).cells.size = width*height := (write w i p).size_eq

/-- Momentum exchange is equal-and-opposite, with no hidden impulse source.
    Internal/chemical/gravitational/kinetic energy share one conserved budget;
    a reduction in kinetic energy therefore becomes heat. -/
def exchangeImpulse (a b : Particle) (ix iy : Int) : Particle × Particle :=
  ({a with px := a.px+ix, py := a.py+iy}, {b with px := b.px-ix, py := b.py-iy})

theorem impulse_conserves_x_momentum (a b : Particle) (x y : Int) :
    (exchangeImpulse a b x y).1.px+(exchangeImpulse a b x y).2.px = a.px+b.px := by
  simp [exchangeImpulse]; omega

theorem impulse_conserves_y_momentum (a b : Particle) (x y : Int) :
    (exchangeImpulse a b x y).1.py+(exchangeImpulse a b x y).2.py = a.py+b.py := by
  simp [exchangeImpulse]; omega

theorem impulse_preserves_energy (a b : Particle) (x y : Int) :
    (exchangeImpulse a b x y).1.energy+(exchangeImpulse a b x y).2.energy = a.energy+b.energy := rfl

theorem impulse_preserves_matter (a b : Particle) (x y : Int) :
    (exchangeImpulse a b x y).1.matter = a.matter ∧ (exchangeImpulse a b x y).2.matter = b.matter := ⟨rfl,rfl⟩

end Sand2
