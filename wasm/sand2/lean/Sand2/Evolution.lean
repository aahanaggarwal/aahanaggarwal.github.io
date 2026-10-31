import Sand2.Conversions
import Sand2.Transport

namespace Sand2
open Chemistry

/-- Constitutive parameters are SI approximations, with one cell = 1 cm and
    one tick = 1/60 s. Closed boundaries are adiabatic: no ambient heat source. -/
def tickMicroseconds : Nat := 16667

def gasCell (height width i : Nat) (p : Particle) : Bool :=
  p.mass < 10000000 || (p.matter.water*18 > p.mass/2 && vaporous height width i p)


def mobile (height width i : Nat) (p : Particle) : Bool :=
  !p.anchored && (let m := labelAt height width i p
    isPowder m || isLiquid m || gasCell height width i p ||
    (p.matter.iron*56 > p.mass/2 && solidRegime height width i p == .liquid))

def unchangedSingle (p : Particle) : SingleEdit p := ⟨p,rfl,rfl⟩
def unchangedPair (a b : Particle) : PairEdit a b := ⟨a,b,rfl,rfl⟩

/-- Candidate edits that would take a cell below absolute zero are rejected,
    retaining the entire original inventory instead of clipping its energy. -/
def safePair (height width i j : Nat) (a b : Particle) (e : PairEdit a b) : PairEdit a b :=
  if temperature height width i e.first >= -27315 && temperature height width j e.second >= -27315 then e
  else unchangedPair a b

def safeSingle (height width i : Nat) (p : Particle) (e : SingleEdit p) : SingleEdit p :=
  if temperature height width i e.after >= -27315 then e else unchangedSingle p

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

def sensibleCapacity (p : Particle) : Int := max 1 (p.capacity+(p.matter.water*18 : Nat)*2000)

/-- The executed Fourier flux has the sign of the temperature difference and
    is bounded by one quarter of the smaller sensible capacity. -/
def conductionFlux (ta tb ca cb k : Int) : Int :=
  let amount := min ((ta-tb).natAbs*k.toNat*166667)
    ((ta-tb).natAbs*(min ca cb).toNat/4)
  if ta >= tb then (amount : Int) else -(amount : Int)

theorem conduction_cannot_heat_the_hotter_cell (ta tb ca cb k : Int) (hot : ta >= tb) :
    conductionFlux ta tb ca cb k >= 0 := by
  simp only [conductionFlux,hot,↓reduceIte]
  exact Int.natCast_nonneg _

theorem conduction_cannot_cool_the_colder_cell (ta tb ca cb k : Int) (cold : ta < tb) :
    conductionFlux ta tb ca cb k <= 0 := by
  simp only [conductionFlux,show ¬ta >= tb by omega,↓reduceIte]
  have nonneg := Int.natCast_nonneg (min ((ta-tb).natAbs*k.toNat*166667) ((ta-tb).natAbs*(min ca cb).toNat/4))
  omega

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
    let k := min (conductivitySI (labelAt height width i a)) (conductivitySI (labelAt height width j b))
    let flux := conductionFlux ta tb ca cb k
    if flux != 0 then Physics.pair i j fun a b => safePair height width i j a b (heatEdit a b flux)

/-- Explicit activation thresholds and bounded reaction extents. These are a
    coarse kinetic model, not instantaneous contact transmutation. -/
def activation : Reaction → Int
  | .burnBiomass => 28000 | .burnOil => 23000 | .burnCarbon => 50000
  | .burnHydrogen => 56000 | .gunpowder => 17000
  | .rustIron | .dissolveCarbonate | .dissolveIron => -10000

def rateDivisor : Reaction → Nat
  | .rustIron => 100000 | .dissolveCarbonate | .dissolveIron => 200
  | .gunpowder => 6 | _ => 16

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
  .rustIron,.dissolveCarbonate,.dissolveIron,.gunpowder]

def possible (r : Reaction) (a b : Mixture) : Bool := match r with
  | .burnBiomass => a.biomass+b.biomass > 0 && a.oxygen+b.oxygen > 0
  | .burnOil => a.oil+b.oil > 0 && a.oxygen+b.oxygen > 0
  | .burnCarbon => a.carbon+b.carbon > 0 && a.oxygen+b.oxygen > 0
  | .burnHydrogen => a.hydrogen+b.hydrogen > 0 && a.oxygen+b.oxygen > 0
  | .rustIron => a.iron+b.iron > 0 && a.oxygen+b.oxygen > 0
  | .dissolveCarbonate => a.carbonate+b.carbonate > 0 && a.acid+b.acid > 0
  | .dissolveIron => a.iron+b.iron > 0 && a.acid+b.acid > 0
  | .gunpowder => a.nitrate+b.nitrate > 0 && a.sulfur+b.sulfur > 0 && a.carbon+b.carbon > 0

def reactive (m : Mixture) : Bool :=
  m.biomass > 0 || m.oil > 0 || m.carbon > 0 || m.iron > 0 || m.acid > 0 || m.nitrate > 0

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
          let e : SingleEdit p := ⟨{e.after with luminous := if activation r > 0 then 12 else p.luminous},e.atoms_eq,e.energy_eq⟩
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
          let e : PairEdit a b := ⟨e.first,{e.second with luminous := if activation r > 0 then 12 else b.luminous},e.atoms_eq,e.energy_eq⟩
          safePair height width i j a b e

/-- Gas transport is a pressure-relaxation finite-volume model. It is deliberately
    overdamped at this space/time resolution, rather than an unstable explicit
    acoustic solver. Every molecule, its formation/sensible energy, and momentum
    are transferred, with equal and opposite changes to the two cells. -/
@[noinline] def flowOne (i j : Nat) (pa pb : Int) : Physics width height Unit := do
  let a ← Physics.getParticle i
  let b ← Physics.getParticle j
  if b.anchored || !(gasCell height width j b) then return
  let v := vaporous height width i a
  if pa <= pb+200 || gasMoles a.matter v == 0 then return
  let divisor := max 8 ((pa*8/max 1 (pa-pb)).toNat)
  let packet := gasPart a.matter divisor v
  let dm := Chemistry.mass packet
  if dm == 0 then return
  let q := gasPacket height width i j a packet
  Physics.pair i j fun a b => safePair height width i j a b (transportEdit a b divisor v q.energy q.px q.py)

structure ThermalSample where
  t : Int := 2000
  pressure : Int := 101325000
  deriving Inhabited

@[noinline] def thermalField (w : World width height) : Array ThermalSample :=
  Array.ofFn fun i : Fin (width*height) =>
    let p := read w i
    let t := temperature height width i p
    ⟨t,idealGasPressure (gasMoles p.matter (vaporous height width i p)) t⟩

/-- Face fluxes use the start-of-tick thermal field (explicit operator splitting).
    Edits still limit actual inventories and retain a conserved energy budget. -/
@[noinline] def diffuse (i j : Nat) : Physics width height Unit := do
  let a ← Physics.getParticle i
  let b ← Physics.getParticle j
  if a.anchored || b.anchored || !gasCell height width i a || !gasCell height width j b || a.matter == b.matter then return
  let divisor := diffusionDivisor a.matter b.matter
  Physics.pair i j fun a b => safePair height width i j a b (gasDiffusionEdit height width i j a b divisor)

/-- Overdamped buoyancy exchanges unstable gas layers: lighter gas below heavier
    gas rises. Gravity stays in the conserved energy budget. This is a coarse
    convective relaxation law, not a resolved momentum/viscosity solver. -/
@[noinline] def buoyancy (upper lower : Nat) : Physics width height Unit := do
  let a ← Physics.getParticle upper
  let b ← Physics.getParticle lower
  if a.anchored || b.anchored || !gasCell height width upper a || !gasCell height width lower b then return
  if a.mass*100 > b.mass*101 then
    Physics.pair upper lower fun a b => safePair height width upper lower a b (gasDiffusionEdit height width upper lower a b 16)

@[noinline] def face (field : Array ThermalSample) (i j : Nat) : Physics width height Unit := do
  let a := field[i]?.getD default
  let b := field[j]?.getD default
  conduct i j a.t b.t
  reactContact i j (max a.t b.t)
  flowOne i j a.pressure b.pressure
  flowOne j i b.pressure a.pressure
  diffuse i j
  if j == i+width then buoyancy i j

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
  if p.stamp == w.generation || !mobile height width start p || gasCell height width start p then return
  Physics.single start fun p =>
    let vx := p.vx*995/1000
    let vy := min 3000000 (p.vy+163500)
    let px := (p.mass : Int)*vx
    let py := (p.mass : Int)*vy
    let e : SingleEdit p := ⟨{p with px,py,rx := p.rx+vx*5/3,ry := p.ry+vy*5/3,stamp := w.generation},rfl,rfl⟩
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
      -- A granular pile avalanches through a clear side face. Liquids use the
      -- same face-based route, so touching corners remain impermeable.
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
      if !moved && isLiquid (labelAt height width pos a) then
        for direction in [if right then (1 : Int) else -1,if right then -1 else 1] do
          if moved then break
          if inside width height ((x : Int)+direction) y then
            let j := idx width ((x : Int)+direction) y
            if ← cross pos j direction 0 then
              Physics.single j fun p => ⟨{p with rx := 0,px := direction*(p.mass : Int)*20000},rfl,rfl⟩
              pos := j
              moved := true
      if !moved then
        damp pos 700 0
        stopped := true

/-- Alternating face order removes a persistent left/right sweep bias. All
    scheduling, kinetics and constitutive rules execute in this Lean program. -/
@[noinline] def stepProgram : Physics width height Unit := do
  Physics.metadata (fun w => {w with generation := w.generation+1}) (by intro w; rfl)
  let generation := (← Physics.getWorld).generation
  let field := thermalField (← Physics.getWorld)
  for k in [:width*height] do
    let i := if generation%2 == 0 then k else width*height-1-k
    normalize i
    reactInside i (field[i]?.getD default).t
    if i%width+1 < width then face field i (i+1)
    if i/width+1 < height then face field i (i+width)
  for y' in [:height] do
    let y := height-1-y'
    for x' in [:width] do
      let x := if generation%2 == 0 then x' else width-1-x'
      moveCell (y*width+x)

@[noinline] def stepWorld (w : World width height) : World width height := (stepProgram.run w).2

/-- Universal guarantee on the actual game timestep, not an isolated oracle. -/
theorem timestep_conserves_every_element_and_energy (w : World width height) :
    Conserves w (stepWorld w) := stepProgram.preserves w

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

end Sand2
