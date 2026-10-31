import Sand2.Mixture
import Sand2.Fusion
import Sand2.Saturation
import Sand2.Mechanics

namespace Sand2
open Chemistry

/-- One cell is one cubic centimetre. Inventories count nanomoles; mass is in
    nanograms, temperature in 0.01 C, pressure in millipascals. Momentum is mass
    times micrometres/second. Energy units are 10^-14 J. -/
def air : Mixture := {oxygen := 8730, nitrogen := 32845}

def dryCapacity (m : Mixture) : Int :=
  (gasCv m : Int) +
  1700*(30*m.biomass) + 2000*(14*m.oil) + 710*(12*m.carbon) +
  730*(60*m.silica) + 850*(58*m.salt) + 3500*(36*m.acid) +
  840*(100*m.carbonate) + 850*(110*m.calciumChloride) +
  450*(56*m.iron) + 650*(160*m.rust) + 650*(126*m.ironChloride) +
  1000*(101*m.nitrate+32*m.sulfur+110*m.sulfide)

def nonWaterCondensedMass (m : Mixture) : Nat :=
  30*m.biomass+14*m.oil+12*m.carbon+60*m.silica+58*m.salt+36*m.acid+
  100*m.carbonate+110*m.calciumChloride+56*m.iron+160*m.rust+126*m.ironChloride+
  101*m.nitrate+32*m.sulfur+110*m.sulfide

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
  dryMass : Nat
  dryMass_eq : dryMass = nonWaterCondensedMass matter
  energy : Int
  px : Int := 0
  py : Int := 0
  rx : Int := 0
  ry : Int := 0
  mechanicalPressure : Nat := 101325000
  phasePressure : Nat := 101325000
  boiling : Nat := saturationTemperature phasePressure
  boiling_eq : boiling = saturationTemperature phasePressure
  boilingFine : Nat := saturationTemperatureFine phasePressure
  boilingFine_eq : boilingFine = saturationTemperatureFine phasePressure
  label : Material := .empty
  anchored : Bool := false
  fractured : Bool := false
  luminous : Nat := 0
  stamp : Nat := 0

def makeParticle (matter : Mixture) (energy : Int) (label : Material := .empty)
    (anchored : Bool := false) : Particle :=
  {matter, mass := Chemistry.mass matter, mass_eq := rfl,
   chemical := chemicalEnergy matter, chemical_eq := rfl,
   capacity := dryCapacity matter, capacity_eq := rfl,
   dryMass := nonWaterCondensedMass matter,dryMass_eq := rfl,energy,label,anchored,
   phasePressure := 101325000,boiling := saturationTemperature 101325000,boiling_eq := rfl,boilingFine := saturationTemperatureFine 101325000,boilingFine_eq := rfl}

def replaceMatter (p : Particle) (matter : Mixture) : Particle :=
  {makeParticle matter p.energy p.label p.anchored with
    px := p.px, py := p.py, rx := p.rx, ry := p.ry, fractured := p.fractured,
    luminous := p.luminous, stamp := p.stamp,
    mechanicalPressure := p.mechanicalPressure,phasePressure := p.phasePressure,boiling := p.boiling,boiling_eq := p.boiling_eq,boilingFine := p.boilingFine,boilingFine_eq := p.boilingFine_eq}

def atPressure (p : Particle) (pressure : Nat) : Particle :=
  {p with phasePressure := pressure,boiling := saturationTemperature pressure,boiling_eq := rfl,boilingFine := saturationTemperatureFine pressure,boilingFine_eq := rfl}

theorem cached_boiling_point_matches_pressure (p : Particle) :
    p.boiling = saturationTemperature p.phasePressure := p.boiling_eq

theorem cached_boiling_point_bounded (p : Particle) : p.boiling <= 20000 := by
  rw [p.boiling_eq]
  exact saturation_temperature_bounded _

theorem increasing_phase_pressure_cannot_lower_boiling (p : Particle) (pressure : Nat)
    (higher : p.phasePressure <= pressure) : p.boiling <= (atPressure p pressure).boiling := by
  rw [p.boiling_eq]
  exact higher_pressure_cannot_lower_boiling_point _ _ higher

theorem increasing_phase_pressure_cannot_lower_fine_boiling (p : Particle) (pressure : Nat)
    (higher : p.phasePressure <= pressure) : p.boilingFine <= (atPressure p pressure).boilingFine := by
  rw [p.boilingFine_eq]
  exact higher_pressure_cannot_lower_fine_boiling_point _ _ higher

def Particle.vx (p : Particle) : Int := p.px / max 1 p.mass
 def Particle.vy (p : Particle) : Int := p.py / max 1 p.mass

def kineticEnergy (p : Particle) : Int :=
  (p.px*p.px+p.py*p.py)/(2*(max 1 p.mass : Nat)*10000000000)

def potentialEnergy (height width i : Nat) (p : Particle) : Int :=
  (p.mass : Int)*981*((height-i/width : Nat)*1000000-p.ry)/(100*1000000)

def thermalEnergy (height width i : Nat) (p : Particle) : Int :=
  p.energy-p.chemical-kineticEnergy p-potentialEnergy height width i p

def waterFusion (p : Particle) : Nat := p.matter.water*18*33400000

def vaporReference (p : Particle) : Nat := p.matter.water*4829103090

def liquidCapacity (p : Particle) : Nat := p.matter.water*75240+p.capacity.toNat

def vaporCapacity (p : Particle) : Nat := p.matter.water*27686+p.capacity.toNat

theorem fine_boiling_cache_bounded (p : Particle) : p.boilingFine <= 200000000 := by
  rw [p.boilingFine_eq]
  exact fine_saturation_temperature_bounded _

/-- Additive mixture energy: water latent heat coexists with every other
    component's sensible heat. The vapor reference is independent of pressure. -/
def waterDiagram (p : Particle) : PhaseDiagram :=
  let fusion := waterFusion p
  let boil := fusion+liquidCapacity p*p.boilingFine/10000
  let vapor := max boil (vaporReference p+vaporCapacity p*p.boilingFine/10000)
  ⟨0,fusion,boil,vapor,Int.natCast_nonneg _,by omega,by omega⟩

def regime (height width i : Nat) (p : Particle) : WaterRegime :=
  phase (waterDiagram p) (thermalEnergy height width i p)

def ironFusion (p : Particle) : Nat := p.matter.iron*56*24700000

def silicaFusion (p : Particle) : Nat := p.matter.silica*60*15000000

/-- Mineral fusion thresholds include the energy of water and the other
    mineral. A trace of water cannot erase iron/silica latent heat. -/
def ironDiagram (p : Particle) : FusionDiagram :=
  let start := vaporReference p+vaporCapacity p*153800
  let finish := start+ironFusion p
  ⟨start,finish,by omega⟩

def silicaDiagram (p : Particle) : FusionDiagram :=
  let start := vaporReference p+vaporCapacity p*170000+ironFusion p
  let finish := start+silicaFusion p
  ⟨start,finish,by omega⟩


theorem iron_fusion_precedes_silica_fusion (p : Particle) :
    (ironDiagram p).meltEnd <= (silicaDiagram p).meltStart := by
  have ordered := Nat.mul_le_mul_left (vaporCapacity p) (show 153800 <= 170000 by decide)
  dsimp [ironDiagram,silicaDiagram]
  omega

theorem water_vaporization_precedes_mineral_fusion (p : Particle) :
    (waterDiagram p).boilEnd <= (ironDiagram p).meltStart := by
  have temperatureBound := fine_boiling_cache_bounded p
  have liquidProduct := Nat.mul_le_mul_left (liquidCapacity p) temperatureBound
  have vaporProduct := Nat.mul_le_mul_left (vaporCapacity p) temperatureBound
  have liquidBound : liquidCapacity p*p.boilingFine/10000 <= 20000*liquidCapacity p := by omega
  have vaporBound : vaporCapacity p*p.boilingFine/10000 <= 20000*vaporCapacity p := by omega
  have first : waterFusion p+liquidCapacity p*p.boilingFine/10000 <= vaporReference p+vaporCapacity p*153800 := by
    dsimp [waterFusion,liquidCapacity,vaporReference,vaporCapacity] at *
    simp only [Nat.add_mul,Nat.mul_add,Nat.mul_assoc] at *
    omega
  have second : vaporReference p+vaporCapacity p*p.boilingFine/10000 <= vaporReference p+vaporCapacity p*153800 := by omega
  dsimp [waterDiagram,ironDiagram]
  omega


def solidDiagram (p : Particle) : FusionDiagram :=
  if p.matter.iron*56 > p.mass/2 then ironDiagram p else silicaDiagram p

def solidRegime (height width i : Nat) (p : Particle) : FusionPhase :=
  fusionPhase (solidDiagram p) (thermalEnergy height width i p)

def waterTemperatureFromInternalEnergy (p : Particle) (h : Int) : Int :=
  if p.matter.water == 0 then h/max 1 p.capacity else
    let d := waterDiagram p
    match phase d h with
    | .ice => h/max 1 ((p.matter.water*18*2100+p.capacity.toNat : Nat) : Int)
    | .melting => 0
    | .liquid => (h-d.meltEnd)/max 1 (liquidCapacity p : Int)
    | .boiling => p.boilingFine/10000
    | .vapor => (h-(vaporReference p : Int))/max 1 (vaporCapacity p : Int)

/-- One common temperature for water, iron and silica, with each component's
    own fusion plateau and additive latent inventory. -/
def temperatureFromEnthalpy (p : Particle) (h : Int) : Int :=
  if p.matter.iron == 0 && p.matter.silica == 0 then waterTemperatureFromInternalEnergy p h else
  let iron := ironDiagram p
  let silica := silicaDiagram p
  if h >= silica.meltEnd then waterTemperatureFromInternalEnergy p (h-(ironFusion p : Int)-(silicaFusion p : Int))
  else if h >= silica.meltStart then 170000
  else if h >= iron.meltEnd then waterTemperatureFromInternalEnergy p (h-(ironFusion p : Int))
  else if h >= iron.meltStart then 153800
  else waterTemperatureFromInternalEnergy p h

def temperature (height width i : Nat) (p : Particle) : Int :=
  temperatureFromEnthalpy p (thermalEnergy height width i p)

def vaporous (height width i : Nat) (p : Particle) : Bool :=
  p.matter.water > 0 && regime height width i p == .vapor

def vaporWaterFromEnthalpy (p : Particle) (h : Int) : Nat :=
  if p.matter.water == 0 then 0 else
    let d := waterDiagram p
    phaseFraction p.matter.water d.boilStart d.boilEnd h

def vaporWaterMoles (height width i : Nat) (p : Particle) : Nat :=
  vaporWaterFromEnthalpy p (thermalEnergy height width i p)

def gasCount (height width i : Nat) (p : Particle) : Nat :=
  dryGasMoles p.matter+vaporWaterMoles height width i p

theorem vapor_molecules_cannot_exceed_water (p : Particle) :
    vaporWaterMoles height width i p <= p.matter.water := by
  unfold vaporWaterMoles vaporWaterFromEnthalpy
  split
  · omega
  · exact phase_fraction_bounded _ _ _ _

def gasMolecularMass (height width i : Nat) (p : Particle) : Nat :=
  32*p.matter.oxygen+28*p.matter.nitrogen+44*p.matter.carbonDioxide+2*p.matter.hydrogen+16*p.matter.methane+28*p.matter.carbonMonoxide+
  18*vaporWaterMoles height width i p

def condensedMass (height width i : Nat) (p : Particle) : Nat :=
  p.dryMass+18*(p.matter.water-vaporWaterMoles height width i p)

def gasCell (height width i : Nat) (p : Particle) : Bool :=
  p.mass < 10000000 || condensedMass height width i p < 10000000

theorem phase_masses_recombine (p : Particle) :
    gasMolecularMass height width i p+condensedMass height width i p = p.mass := by
  have available := vapor_molecules_cannot_exceed_water (height := height) (width := width) (i := i) p
  rw [p.mass_eq]
  dsimp [gasMolecularMass,condensedMass]
  rw [p.dryMass_eq]
  dsimp [nonWaterCondensedMass,Chemistry.mass,atoms]
  omega

def idealGasPressure (moles : Nat) (t : Int) : Int :=
  (moles : Int)*8314*max 1 (t+27315)/100000

def pressure (height width i : Nat) (p : Particle) : Int :=
  idealGasPressure (gasCount height width i p) (temperature height width i p)

theorem ideal_gas_pressure_matches_declared_units (n : Nat) (t : Int) :
    idealGasPressure n t = (n : Int)*8314*max 1 (t+27315)/100000 := rfl

/-- Initial thermal internal energy for a requested temperature. Editing is an
    explicit external energy/matter injection, never part of physics stepping. -/
def internalEnergyAt (m : Mixture) (label : Material) (t : Int) : Int :=
  let wm : Int := m.water*18
  let other := dryCapacity m*t
  if wm == 0 then
    let iron := m.iron*56
    let silica := m.silica*60
    other + (if iron > 0 && t >= 153800 then (iron*24700000 : Nat) else 0) +
      (if silica > 0 && t >= 170000 then (silica*15000000 : Nat) else 0)
  else if label == .ice then wm*2100*t+other
  else if label == .steam || label == .fire || label == .smoke then
    wm*(300900000+2000*(t-10000))-(m.water : Int)*8314*(t+27315)+other
  else wm*(33400000+4180*t)+other

def matterFor : Material → Mixture
  | .empty => air
  | .water => {water := 55555555}
  | .ice => {water := 50944444}
  | .steam => {air with water := 41575}
  | .sand | .glass | .stone | .obsidian => {silica := 44166666}
  | .lava => {silica := 36630036}
  | .wood | .plant => {biomass := 23333333}
  | .oil => {oil := 57142857}
  | .acid => {water := 52588888, acid := 3000000}
  | .salt => {salt := 37310344}
  | .saltWater => {water := 54910000, salt := 700000}
  | .metal => {iron := 140357142}
  | .limestone => {carbonate := 27000000}
  | .oxygen => {oxygen := 41575}
  | .nitrogen => {nitrogen := 41575}
  | .carbonDioxide => {carbonDioxide := 41575}
  | .hydrogen => {hydrogen := 41575}
  | .methane => {methane := 41575}
  | .carbonMonoxide => {carbonMonoxide := 41575}
  | .charcoal => {carbon := 25000000}
  | .rust => {rust := 32750000}
  | .nitrate => {nitrate := 20881188}
  | .sulfur => {sulfur := 64687500}
  | .calciumChloride => {calciumChloride := 19545454}
  | .ironChloride => {ironChloride := 25079365}
  | .moltenIron => {iron := 125000000}
  | .gunpowder => {nitrate := 12592592, sulfur := 6296296, carbon := 18888888}
  | .fire => {air with oil := 10000, oxygen := 30000}
  | .smoke => {air with carbonDioxide := 20000, water := 20000}
  | .ember => {biomass := 20000000, carbon := 1000000}
  | .ash => {silica := 2000000, carbon := 100000}

def makeAt (height width i : Nat) (m : Material) (anchored : Bool := false) : Particle :=
  let matter := matterFor m
  let t := match m with
    | .lava => 180000 | .moltenIron => 170000 | .fire => 90000 | .ember => 65000 | .ice => -1000
    | .steam => 13000 | .smoke => 14000 | _ => 2000
  let p := makeParticle matter 0 m anchored
  let p : Particle := {p with
    energy := p.chemical+internalEnergyAt matter m t+potentialEnergy height width i p
    luminous := (if m == Material.fire || m == Material.ember then 4*ticksPerSecond/15 else 0)}
  {p with mechanicalPressure := if gasCell height width i p then (pressure height width i p).toNat else 101325000}

/-- Fixed dimensions and exact grid shape are carried by the Lean state. -/
structure World (width height : Nat) where
  cells : Array Particle
  size_eq : cells.size = width*height
  generation : Nat := 0
  rejectedFluidSubsteps : Nat := 0
  fluidResidual : Nat := 0
  seed : UInt32 := 0x5a172026

structure Simulation where
  width : Nat
  height : Nat
  world : World width height

def read (w : World width height) (i : Nat) : Particle :=
  if h : i < w.cells.size then w.cells[i] else makeAt height width 0 .empty

def cellTemperature (w : World width height) (i : Nat) : Int := temperature height width i (read w i)

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
  {cells,size_eq := by simp [cells]}

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
