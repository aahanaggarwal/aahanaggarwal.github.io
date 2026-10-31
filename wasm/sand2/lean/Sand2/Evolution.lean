import Sand2.Conversions
import Sand2.Transport
import Sand2.PhasePressure
import Sand2.Mechanics
import Sand2.FluidDynamics

namespace Sand2
open Chemistry

/-- Constitutive parameters are SI approximations, with one cell = 1 cm and
    one tick = 1/600 s. Closed boundaries are adiabatic: no ambient heat source. -/


def mobile (height width i : Nat) (p : Particle) : Bool :=
  !p.anchored && (let m := labelAt height width i p
    isPowder m || isLiquid m || gasCell height width i p ||
    (p.matter.iron*56 > p.mass/2 && solidRegime height width i p == .liquid))

def normalize (i : Nat) : Physics width height Unit := do
  let p ← Physics.getParticle i
  let label := labelAt height width i p
  if label != p.label || p.luminous > 0 then
    Physics.single i (normalizeEdit height width i)

/-- Fourier conduction through a one-centimetre face. Conductivity is rounded
    to mW/(m K). The capacity bound prevents a single face overshooting its
    pairwise sensible-heat equilibrium; phase plateaus absorb latent heat. -/
def conductivitySI : Material → Int
  | .metal => 80000 | .stone | .sand => 2000 | .glass | .obsidian => 1000
  | .ice => 2200 | .water | .saltWater | .acid => 600 | .oil => 150
  | .wood | .plant | .ember => 120 | .lava => 1500
  | .salt => 6000 | .gunpowder | .ash => 100 | _ => 26

/-- Volume-weighted parallel conductivity for a homogeneous water/air cell.
    A tiny wet fraction must not conduct as a full cubic centimetre of water. -/
def waterAirConductivity (liquid : Nat) : Int :=
  26+(574*min cellVolume liquid/cellVolume : Nat)

theorem water_air_conductivity_bounded (liquid : Nat) :
    26 <= waterAirConductivity liquid ∧ waterAirConductivity liquid <= 600 := by
  have bound := Nat.min_le_left cellVolume liquid
  dsimp [waterAirConductivity,cellVolume] at *
  omega

def particleConductivity (height width i : Nat) (p : Particle) : Int :=
  if p.dryMass == 0 && p.matter.water > 0 && !fluidObstacle height width i p then
    waterAirConductivity (occupiedLiquidVolume height width i p)
  else conductivitySI (labelAt height width i p)

theorem other_condensed_species_retain_their_conductivity (p : Particle)
    (condensed : p.dryMass > 0) :
    particleConductivity height width i p = conductivitySI (labelAt height width i p) := by
  have present : p.dryMass ≠ 0 := by omega
  simp [particleConductivity,present]

def sensibleCapacity (p : Particle) : Int := max 1 (p.capacity+(p.matter.water : Int)*27686)

/-- The executed Fourier flux has the sign of the temperature difference and
    is bounded by one quarter of the smaller sensible capacity. -/
def conductionFlux (ta tb ca cb k : Int) : Int :=
  let amount := min (10000000*((ta-tb).natAbs*k.toNat)/ticksPerSecond)
    ((ta-tb).natAbs*(min ca cb).toNat/4)
  if ta >= tb then (amount : Int) else -(amount : Int)

theorem conduction_cannot_heat_the_hotter_cell (ta tb ca cb k : Int) (hot : ta >= tb) :
    conductionFlux ta tb ca cb k >= 0 := by
  simp only [conductionFlux,hot,↓reduceIte]
  exact Int.natCast_nonneg _

theorem conduction_cannot_cool_the_colder_cell (ta tb ca cb k : Int) (cold : ta < tb) :
    conductionFlux ta tb ca cb k <= 0 := by
  simp only [conductionFlux,show ¬ta >= tb by omega,↓reduceIte]
  have nonneg := Int.natCast_nonneg (min (10000000*((ta-tb).natAbs*k.toNat)/ticksPerSecond) ((ta-tb).natAbs*(min ca cb).toNat/4))
  exact Int.neg_nonpos_of_nonneg nonneg

theorem isothermal_cells_exchange_no_heat (t ca cb k : Int) : conductionFlux t t ca cb k = 0 := by
  simp [conductionFlux]

theorem conduction_flux_bounded (ta tb ca cb k : Int) :
    (conductionFlux ta tb ca cb k).natAbs <= (ta-tb).natAbs*(min ca cb).toNat/4 := by
  unfold conductionFlux
  split <;> simp only [Int.natAbs_natCast,Int.natAbs_neg] <;> exact Nat.min_le_right _ _

@[noinline] def conduct (i j : Nat) (ta tb : Int) : Physics width height Unit := do
  let a ← Physics.getParticle i
  let b ← Physics.getParticle j
  if ta != tb then
    let ca := sensibleCapacity a
    let cb := sensibleCapacity b
    let k := min (particleConductivity height width i a) (particleConductivity height width j b)
    let flux := conductionFlux ta tb ca cb k
    if flux != 0 then Physics.pair i j fun a b => safePair height width i j a b (heatEdit a b flux)

/-- Explicit activation thresholds and bounded reaction extents. These are a
    coarse kinetic model, not instantaneous contact transmutation. -/
def activation : Reaction → Int
  | .burnBiomass => 28000 | .burnOil => 23000 | .burnCarbon => 50000
  | .burnHydrogen => 56000
  | .burnMethane | .partialMethane => 55000
  | .burnCarbonMonoxide => 60000 | .gunpowder => 17000
  | .rustIron | .dissolveCarbonate | .dissolveIron => -10000

def baseRateDivisor : Reaction → Nat
  | .rustIron => 100000 | .dissolveCarbonate | .dissolveIron => 200
  | .gunpowder => 6 | _ => 16

def rateDivisor (r : Reaction) : Nat := baseRateDivisor r*ticksPerSecond/60

def reactionExtent (r : Reaction) (m : Mixture) (t : Int) : Nat :=
  if t < activation r then 0 else if capacity r m = 0 then 0 else max 1 (capacity r m / rateDivisor r)

theorem cold_reactions_do_not_start (r : Reaction) (m : Mixture) (t : Int)
    (cold : t < activation r) : reactionExtent r m t = 0 := by simp [reactionExtent,cold]

theorem kinetics_cannot_exceed_reactants (r : Reaction) (m : Mixture) (t : Int) :
    reactionExtent r m t ≤ capacity r m := by
  unfold reactionExtent
  split
  · omega
  · split
    · omega
    · have divided := Nat.div_le_self (capacity r m) (rateDivisor r)
      omega

def reactions : List Reaction := [.burnBiomass,.burnOil,.burnCarbon,.burnHydrogen,
  .rustIron,.dissolveCarbonate,.dissolveIron,.gunpowder,.burnMethane,.partialMethane,.burnCarbonMonoxide]

theorem reaction_schedule_is_complete (r : Reaction) : r ∈ reactions := by
  cases r <;> simp [reactions]

theorem reaction_schedule_has_no_duplicate_families : reactions.Nodup := by decide

def possible (r : Reaction) (a b : Mixture) : Bool := match r with
  | .burnBiomass => a.biomass+b.biomass > 0 && a.oxygen+b.oxygen > 0
  | .burnOil => a.oil+b.oil > 0 && a.oxygen+b.oxygen > 0
  | .burnCarbon => a.carbon+b.carbon > 0 && a.oxygen+b.oxygen > 0
  | .burnHydrogen => a.hydrogen+b.hydrogen > 0 && a.oxygen+b.oxygen > 0
  | .rustIron => a.iron+b.iron > 0 && a.oxygen+b.oxygen > 0
  | .dissolveCarbonate => a.carbonate+b.carbonate > 0 && a.acid+b.acid > 0
  | .dissolveIron => a.iron+b.iron > 0 && a.acid+b.acid > 0
  | .gunpowder => a.nitrate+b.nitrate > 0 && a.sulfur+b.sulfur > 0 && a.carbon+b.carbon > 0
  | .burnMethane => a.methane+b.methane > 0 && a.oxygen+b.oxygen >= 2*(a.methane+b.methane)
  | .partialMethane => a.methane+b.methane > 0 && a.oxygen+b.oxygen > 0 && a.oxygen+b.oxygen < 2*(a.methane+b.methane)
  | .burnCarbonMonoxide => a.carbonMonoxide+b.carbonMonoxide > 0 && a.oxygen+b.oxygen > 0

theorem methane_routes_are_exclusive (a b : Mixture) :
    ¬(possible .burnMethane a b = true ∧ possible .partialMethane a b = true) := by
  simp only [possible,Bool.and_eq_true,decide_eq_true_eq]
  omega

theorem methane_routes_cover_all_fuel_oxygen_mixtures (a b : Mixture) :
    (possible .burnMethane a b || possible .partialMethane a b) =
      decide (a.methane+b.methane > 0 ∧ a.oxygen+b.oxygen > 0) := by
  by_cases fuel : a.methane+b.methane > 0
  · by_cases oxygen : a.oxygen+b.oxygen > 0
    · by_cases abundant : a.oxygen+b.oxygen >= 2*(a.methane+b.methane)
      · simp [possible,fuel,oxygen,abundant]
      · have rich : a.oxygen+b.oxygen < 2*(a.methane+b.methane) := by omega
        simp [possible,fuel,oxygen,abundant,rich]
    · have unavailable : ¬a.oxygen+b.oxygen >= 2*(a.methane+b.methane) := by omega
      simp [possible,fuel,oxygen,unavailable]
  · simp [possible,fuel]

def reactive (m : Mixture) : Bool :=
  m.biomass > 0 || m.oil > 0 || m.carbon > 0 || m.iron > 0 || m.acid > 0 || m.nitrate > 0 || m.hydrogen > 0 || m.methane > 0 || m.carbonMonoxide > 0

/-- The cheap chemistry filter may never discard an eligible reaction family.
    This includes hydrogen-only fuel mixtures, not only carbonaceous fuels. -/
theorem eligible_reaction_passes_fast_filter (r : Reaction) (a b : Mixture)
    (eligible : possible r a b = true) : reactive a || reactive b = true := by
  cases r <;> simp only [possible,Bool.and_eq_true,decide_eq_true_eq] at eligible <;>
    simp only [reactive,Bool.or_eq_true,decide_eq_true_eq] <;> omega

@[noinline] def reactInside (i : Nat) (t : Int) : Physics width height Unit := do
  unless reactive (← Physics.getParticle i).matter do return
  if (← Physics.getParticle i).anchored then return
  for r in reactions do
    let p ← Physics.getParticle i
    if possible r p.matter {} then
      let q := reactionExtent r p.matter t
      if q > 0 then
        Physics.single i fun p =>
          let e := reactionEdit p r q
          let e : SingleEdit p := ⟨{e.after with luminous := if activation r > 0 then ticksPerSecond/5 else p.luminous},e.atoms_eq,e.energy_eq⟩
          safeSingle height width i p e

@[noinline] def reactContact (i j : Nat) (t : Int) : Physics width height Unit := do
  let a ← Physics.getParticle i
  let b ← Physics.getParticle j
  if a.anchored || b.anchored then return
  unless reactive a.matter || reactive b.matter do return
  for r in reactions do
    let a ← Physics.getParticle i
    let b ← Physics.getParticle j
    if possible r a.matter b.matter then
      let m := add a.matter b.matter
      let q := reactionExtent r m t
      if q > 0 then
        Physics.pair i j fun a b =>
          let e := contactEdit a b r q
          let e : PairEdit a b := ⟨e.first,{e.second with luminous := if activation r > 0 then ticksPerSecond/5 else b.luminous},e.atoms_eq,e.energy_eq⟩
          safePair height width i j a b e

structure ThermalSample where
  t : Int := 2000
  enthalpy : Int := 0
  phaseKey : Nat := 100000000
  deriving Inhabited

/-- Start-of-tick thermal samples. Mechanical pressure and buoyancy are supplied
    by the coupled fluid solve, rather than a separate column approximation. -/
@[noinline] def thermalField (w : World width height) : Array ThermalSample :=
  Array.ofFn fun i : Fin (width*height) =>
    let p := read w i
    let h := thermalEnergy height width i p
    {t := temperatureFromEnthalpy p h,enthalpy := h,phaseKey := p.boilingFine}

/-- The energy-volume flash calculation selects water's partial pressure without
    changing any molecule or the parcel's conserved energy. -/
def updatePhasePressure (field : Array ThermalSample) (i : Nat) : Physics width height Unit := do
  let p ← Physics.getParticle i
  if p.matter.water == 0 then return
  let h := (field[i]?.getD default).enthalpy
  let target := flashEquilibriumPressure p h
  if target != p.phasePressure then
    Physics.single i fun p => ⟨atPressure p target,rfl,rfl⟩

/-- Recompute only changed water phase samples after pressure equilibration;
    non-water parcels and their frozen operator-split samples are unchanged. -/
@[noinline] def refreshPhaseField (field : Array ThermalSample) (w : World width height) : Array ThermalSample := Id.run do
  let mut result := field
  for i in [:width*height] do
    let p := read w i
    let old := field[i]?.getD default
    if p.matter.water > 0 && p.boilingFine != old.phaseKey then
      let t := temperatureFromEnthalpy p old.enthalpy
      let fresh := {old with t := t,phaseKey := p.boilingFine}
      result := result.set! i fresh
  return result

/-- Face fluxes use the start-of-tick thermal field (explicit operator splitting).
    Edits still limit actual inventories and retain a conserved energy budget. -/
@[noinline] def diffuse (i j : Nat) : Physics width height Unit := do
  let a ← Physics.getParticle i
  let b ← Physics.getParticle j
  if a.matter == b.matter || a.anchored || b.anchored || liquidVolume height width i a >= cellVolume/2 ||
      liquidVolume height width j b >= cellVolume/2 || gasFreeVolume height width i a < cellVolume/100000 ||
      gasFreeVolume height width j b < cellVolume/100000 then return
  let divisor := diffusionDivisor a.matter b.matter*cellVolume/
    max 1 (min (gasFreeVolume height width i a) (gasFreeVolume height width j b))
  Physics.pair i j fun a b => safePair height width i j a b (gasDiffusionEdit height width i j a b divisor)

@[noinline] def face (field : Array ThermalSample) (i j : Nat) : Physics width height Unit := do
  let a := field[i]?.getD default
  let b := field[j]?.getD default
  conduct i j a.t b.t
  reactContact i j (max a.t b.t)
  diffuse i j

/-- Dissipative drag/impact retains total energy: lost kinetic energy appears
    in the enthalpy budget. Fixtures exchange momentum with the closed vessel. -/
def damp (i : Nat) (horizontal vertical : Int) : Physics width height Unit := Physics.single i fun p =>
  ⟨{p with px := p.px*horizontal/1000, py := p.py*vertical/1000, rx := 0, ry := 0},rfl,rfl⟩

def canDisplace (height width _i j : Nat) (a b : Particle) (down : Bool) : Bool :=
  mobile height width j b && !b.anchored &&
  (gasCell height width j b || (down && isLiquid (labelAt height width j b) && a.mass > b.mass+1000000))

/-- A swap is a swept face crossing; the position fraction is translated by
    exactly one cell. No diagonal can cross two touching solid faces. -/
def crossEdit (a b : Particle) (dx dy : Int) (stamp : Nat) : PairEdit a b :=
  ⟨{b with stamp}, {a with rx := a.rx-dx*1000000,ry := a.ry-dy*1000000,stamp},
    by apply Atoms.ext <;> simp [atomAdd] <;> omega,by dsimp; omega⟩

@[noinline] def cross (i j : Nat) (dx dy : Int) : Physics width height Bool := do
  let a ← Physics.getParticle i
  let b ← Physics.getParticle j
  if canDisplace height width i j a b (dy > 0) then
    let generation := (← Physics.getWorld).generation
    let e := safePair height width i j a b (crossEdit a b dx dy generation)
    if e.second.matter == a.matter then
      Physics.pair i j fun a b => safePair height width i j a b (crossEdit a b dx dy generation)
      return true
    else return false
  else return false

@[noinline] def moveCell (start : Nat) : Physics width height Unit := do
  let w ← Physics.getWorld
  let p := read w start
  if p.stamp == w.generation || p.anchored || gasCell height width start p ||
      liquidVolume height width start p > cellVolume/1000000 || !mobile height width start p then return
  Physics.single start fun p =>
    let vx := p.vx*(10*(ticksPerSecond : Int)-3)/(10*(ticksPerSecond : Int))
    let vy := gravityVelocity p.vy
    let px := (p.mass : Int)*vx
    let py := (p.mass : Int)*vy
    let e : SingleEdit p := ⟨{p with px,py,rx := p.rx+stepDisplacement p.vx vx,ry := p.ry+stepDisplacement p.vy vy,stamp := w.generation},rfl,rfl⟩
    safeSingle height width start p e
  let mut pos := start
  let mut stopped := false
  for _ in [:8] do
    if stopped then break
    let a ← Physics.getParticle pos
    let dy : Int := if a.ry >= 500000 then 1 else if a.ry <= -500000 then -1 else 0
    let dx : Int := if a.rx >= 500000 then 1 else if a.rx <= -500000 then -1 else 0
    if dy == 0 && dx == 0 then break
    let x := (pos%width : Nat)
    let y := (pos/width : Nat)
    let mut moved := false
    if dy != 0 && inside width height x ((y : Int)+dy) then
      let j := idx width x ((y : Int)+dy)
      if ← cross pos j 0 dy then
        pos := j
        moved := true
    if !moved && dx != 0 && inside width height ((x : Int)+dx) y then
      let j := idx width ((x : Int)+dx) y
      if ← cross pos j dx 0 then
        pos := j
        moved := true
    if !moved then
      -- A granular pile avalanches through a clear side face, so touching
      -- corners remain impermeable. Liquids use the coupled field solver.
      let right := (w.generation+pos)%2 == 0
      for direction in [if right then (1 : Int) else -1,if right then -1 else 1] do
        if moved then break
        if inside width height ((x : Int)+direction) y && inside width height ((x : Int)+direction) ((y : Int)+1) then
          let side := idx width ((x : Int)+direction) y
          let below := idx width ((x : Int)+direction) ((y : Int)+1)
          let s ← Physics.getParticle side
          let b ← Physics.getParticle below
          if gasCell height width side s && canDisplace height width pos below a b true then
            if ← cross pos side direction 0 then
              if ← cross side below 0 1 then
                pos := below
                moved := true
      if !moved then
        damp pos 700 0
        stopped := true

/-- Alternating face order removes a persistent left/right sweep bias. All
    scheduling, kinetics and constitutive rules execute in this Lean program. -/
@[noinline] def thermochemicalStep : Physics width height Unit := do
  Physics.metadata (fun w => {w with generation := w.generation+1}) (by intro w; rfl)
  let generation := (← Physics.getWorld).generation
  let initialField := thermalField (← Physics.getWorld)
  for i in [:width*height] do updatePhasePressure initialField i
  let field := refreshPhaseField initialField (← Physics.getWorld)
  for k in [:width*height] do
    let i := if generation%2 == 0 then k else width*height-1-k
    normalize i
    reactInside i (field[i]?.getD default).t
    if i%width+1 < width then face field i (i+1)
    if i/width+1 < height then face field i (i+width)

@[noinline] def stepProgram : Physics width height Unit := do
  thermochemicalStep
  let generation := (← Physics.getWorld).generation
  fluidStep
  for y' in [:height] do
    let y := height-1-y'
    for x' in [:width] do
      let x := if generation%2 == 0 then x' else width-1-x'
      moveCell (y*width+x)

/-- A failed tick never advances physical time or leaves a partially accepted
    world. It records one failure for the UI, preserving the original cells. -/
def tickAccept (before after : World width height) : Bool :=
  decide (after.rejectedFluidSubsteps = before.rejectedFluidSubsteps) &&
    kelvinScan after (width*height) 0 && decide (fluidOverflow after <= fluidOverflow before)

@[noinline] def stepWorld (w : World width height) : World width height :=
  let candidate := (stepProgram.run w).2
  if tickAccept w candidate then candidate else
    {w with rejectedFluidSubsteps := w.rejectedFluidSubsteps+1}

/-- Universal guarantee on the actual game timestep, including rollback. -/
theorem timestep_conserves_every_element_and_energy (w : World width height) :
    Conserves w (stepWorld w) := by
  dsimp only [stepWorld]
  split
  · exact stepProgram.preserves w
  · intro q; rfl

theorem rejected_timestep_preserves_cells_and_time (w : World width height)
    (rejected : tickAccept w (stepProgram.run w).2 = false) :
    (stepWorld w).cells = w.cells ∧ (stepWorld w).generation = w.generation := by
  simp [stepWorld,rejected]

theorem timestep_cannot_create_negative_absolute_temperature (w : World width height)
    (initial : ∀ i, i < width*height → cellTemperature w i >= -27315) :
    ∀ i, i < width*height → cellTemperature (stepWorld w) i >= -27315 := by
  dsimp only [stepWorld]
  split
  · rename_i accepted
    simp only [tickAccept,Bool.and_eq_true,decide_eq_true_eq] at accepted
    have valid := (kelvin_scan_sound_and_complete _ (width*height) 0).1 accepted.1.2
    simpa only [Nat.zero_add] using valid
  · exact initial

theorem timestep_cannot_increase_liquid_overflow (w : World width height) :
    fluidOverflow (stepWorld w) <= fluidOverflow w := by
  dsimp only [stepWorld]
  split
  · rename_i accepted
    simp only [tickAccept,Bool.and_eq_true,decide_eq_true_eq] at accepted
    exact accepted.2
  · exact Nat.le_refl _

def repeatWorld : Nat → World width height → World width height
  | 0,w => w
  | n+1,w => repeatWorld n (stepWorld w)

theorem arbitrarily_many_timesteps_conserve (n : Nat) (w : World width height) :
    Conserves w (repeatWorld n w) := by
  induction n generalizing w with
  | zero => intro q; rfl
  | succ n ih =>
    intro q
    exact (ih (stepWorld w) q).trans (timestep_conserves_every_element_and_energy w q)

theorem arbitrary_steps_preserve_absolute_temperature (n : Nat) (w : World width height)
    (initial : ∀ i, i < width*height → cellTemperature w i >= -27315) :
    ∀ i, i < width*height → cellTemperature (repeatWorld n w) i >= -27315 := by
  induction n generalizing w with
  | zero => exact initial
  | succ n ih => exact ih (stepWorld w) (timestep_cannot_create_negative_absolute_temperature w initial)

end Sand2
