import Sand2.PhasePressure
import Sand2.Transport
import Sand2.EditSafety
import Sand2.Mechanics

namespace Sand2
open Chemistry

/-- Upwind volume advection of the complete local phase mixture. All molecular
    species use the same fraction; gases are never fabricated as displaced-cell
    placeholders. A pure-water donor cannot transport another chamber's air. -/
def mixtureRequest (m : Mixture) (fraction : Nat) : Mixture :=
  let q := min cellVolume fraction
  {water := m.water*q/cellVolume,oxygen := m.oxygen*q/cellVolume,
   nitrogen := m.nitrogen*q/cellVolume,carbonDioxide := m.carbonDioxide*q/cellVolume,
   biomass := m.biomass*q/cellVolume,oil := m.oil*q/cellVolume,carbon := m.carbon*q/cellVolume,
   silica := m.silica*q/cellVolume,salt := m.salt*q/cellVolume,acid := m.acid*q/cellVolume,
   carbonate := m.carbonate*q/cellVolume,calciumChloride := m.calciumChloride*q/cellVolume,
   iron := m.iron*q/cellVolume,rust := m.rust*q/cellVolume,ironChloride := m.ironChloride*q/cellVolume,
   hydrogen := m.hydrogen*q/cellVolume,nitrate := m.nitrate*q/cellVolume,
   sulfur := m.sulfur*q/cellVolume,sulfide := m.sulfide*q/cellVolume,
   methane := m.methane*q/cellVolume,carbonMonoxide := m.carbonMonoxide*q/cellVolume}

theorem fluid_transport_does_not_invent_absent_gases (m : Mixture) (fraction : Nat)
    (oxygen : m.oxygen = 0) (nitrogen : m.nitrogen = 0)
    (co2 : m.carbonDioxide = 0) (hydrogen : m.hydrogen = 0)
    (methane : m.methane = 0) (carbonMonoxide : m.carbonMonoxide = 0) :
    (mixtureRequest m fraction).oxygen = 0 ∧ (mixtureRequest m fraction).nitrogen = 0 ∧
    (mixtureRequest m fraction).carbonDioxide = 0 ∧ (mixtureRequest m fraction).hydrogen = 0 ∧
    (mixtureRequest m fraction).methane = 0 ∧ (mixtureRequest m fraction).carbonMonoxide = 0 := by
  simp [mixtureRequest,oxygen,nitrogen,co2,hydrogen,methane,carbonMonoxide]

/-- Internal energy is advected with the local mixture. Pressure work crosses
    the same physical face for both gas and liquid, including air displaced by
    a moving surface. The global total remains an exact integer inventory. -/
def fluidPacket (height width i j : Nat) (source : Particle) (matter : Mixture)
    (volume facePressure : Nat) : Particle :=
  let dm := Chemistry.mass matter
  let q := makeParticle matter 0
  let q := {q with px := source.vx*(dm : Int),py := source.vy*(dm : Int)}
  let internal := thermalEnergy height width i source*(dm : Int)/max 1 source.mass
  let work : Int := facePressure*volume/100000
  {q with energy := q.chemical+internal+kineticEnergy q+facePotential height width i j q+work}

def fluidFlowEdit (height width i j : Nat) (a b source : Particle)
    (fraction facePressure : Nat) : PairEdit a b :=
  let portion := requestedPortion a.matter (mixtureRequest source.matter fraction)
  let packet := fluidPacket height width i j source portion.moved (min cellVolume fraction) facePressure
  portionEdit a b portion (emptyPortion b.matter) packet.energy 0 packet.px 0 packet.py 0

theorem fluid_flow_conserves_every_molecule (a b source : Particle) (fraction pressure : Nat) :
    add (fluidFlowEdit height width i j a b source fraction pressure).first.matter
      (fluidFlowEdit height width i j a b source fraction pressure).second.matter = add a.matter b.matter :=
  portion_exchange_conserves_every_molecule _ _ _ _

theorem fluid_flow_conserves_total_energy (a b source : Particle) (fraction pressure : Nat) :
    (fluidFlowEdit height width i j a b source fraction pressure).first.energy+
      (fluidFlowEdit height width i j a b source fraction pressure).second.energy = a.energy+b.energy :=
  (fluidFlowEdit height width i j a b source fraction pressure).energy_eq

def velocityMicrometres (speed : Float) : Int :=
  let speed := finiteClamp (-3) 3 speed
  let amount : Int := min 3000000 (floatAbs speed*1000000).toUInt64.toNat
  if speed < 0 then -amount else amount

theorem fluid_velocity_bound (speed : Float) :
    -3000000 <= velocityMicrometres speed ∧ velocityMicrometres speed <= 3000000 := by
  dsimp only [velocityMicrometres]
  split <;> omega

/-- Incremental pressure/wall impulses avoid timestep-independent kinetic-energy
    changes from repeatedly averaging the absolute neighbouring velocities. -/
def fluidCellVelocity (g : FluidGeometry) (velocity : FluidVelocity) (i : Nat) : Float × Float :=
  let dul := if i%g.width > 0 then floatAt velocity.u (i-1)-floatAt velocity.rawU (i-1) else 0
  let dur := floatAt velocity.u i-floatAt velocity.rawU i
  let dvu := if i/g.width > 0 then floatAt velocity.v (i-g.width)-floatAt velocity.rawV (i-g.width) else 0
  let dvd := floatAt velocity.v i-floatAt velocity.rawV i
  (floatAt velocity.cellU i+(dul+dur)/2,floatAt velocity.cellV i+(dvu+dvd)/2)

@[noinline] def advectFluidFace (snapshot : World width height) (velocity : FluidVelocity)
    (i j : Nat) (amount : Float) : Physics width height Unit := do
  if floatAbs amount < 0.0000000001 then return
  let source := if amount >= 0 then i else j
  let target := if amount >= 0 then j else i
  let original := read snapshot source
  if original.mass == 0 then return
  let fraction := (floatAbs amount*floatNat cellVolume).toUInt64.toNat
  if Chemistry.mass (mixtureRequest original.matter fraction) == 0 then return
  let facePressure := (floatMax 0 ((floatAt velocity.pressure i+floatAt velocity.pressure j)/2)*1000).toUInt64.toNat
  Physics.pair source target fun a b => fluidFlowEdit height width source target a b original fraction facePressure

@[noinline] def fluidCandidate (dt : Float) : Physics width height Unit := do
  let geometry := fluidGeometry (← Physics.getWorld)
  let velocity := projectFluid geometry dt
  let mut valid := !velocity.residual.isNaN && !velocity.residual.isInf && velocity.residual <= 0.00000001
  for i in [:width*height] do
    if !fieldBool geometry.active i then continue
    let outgoing := floatMax 0 (floatAt velocity.u i)+
      (if i%width > 0 then floatMax 0 (-floatAt velocity.u (i-1)) else 0)+
      floatMax 0 (floatAt velocity.v i)+
      (if i/width > 0 then floatMax 0 (-floatAt velocity.v (i-width)) else 0)
    let p := floatAt velocity.pressure i
    if outgoing*dt/0.01 > 0.45 || p.isNaN || p.isInf || p < 0 then valid := false
  let residual := if valid then (velocity.residual*1000000000000).toUInt64.toNat else 1000000000000
  Physics.metadata (fun w => {w with fluidResidual := residual}) (by intro w; rfl)
  if !valid then return
  for i in [:width*height] do
    if fieldBool geometry.active i then
      let cellVelocity := fluidCellVelocity geometry velocity i
      let vx := velocityMicrometres cellVelocity.1
      let vy := velocityMicrometres cellVelocity.2
      let pressure := (floatMax 0 (floatAt velocity.pressure i)*1000).toUInt64.toNat
      Physics.single i fun p =>
        ⟨{p with px := (p.mass : Int)*vx,py := (p.mass : Int)*vy,rx := 0,ry := 0,mechanicalPressure := pressure},rfl,rfl⟩
  let snapshot ← Physics.getWorld
  let reverse := snapshot.generation%2 == 1
  for k in [:width*height] do
    let i := if reverse then width*height-1-k else k
    if i%width+1 < width then advectFluidFace snapshot velocity i (i+1) (floatAt velocity.u i*dt/0.01)
    if i/width+1 < height then advectFluidFace snapshot velocity i (i+width) (floatAt velocity.v i*dt/0.01)
  for i in [:width*height] do
    let p ← Physics.getParticle i
    if !p.anchored then
      Physics.single i fun p =>
        ⟨equilibriumParticleFromInternalEnergy p (thermalEnergy height width i p),
          congrArg atoms (flash_equilibrium_preserves_every_molecule p _),flash_equilibrium_preserves_total_energy p _⟩

def fluidOverflow (w : World width height) : Nat := Id.run do
  let mut excess := 0
  for i in [:width*height] do
    excess := excess+(occupiedLiquidVolume height width i (read w i)-(cellVolume+10000))
  return excess
/-- A total tail-recursive Kelvin-admissibility checker. -/
def kelvinScan (w : World width height) : Nat → Nat → Bool
  | 0,_ => true
  | remaining+1,start =>
    decide (cellTemperature w start >= -27315) && kelvinScan w remaining (start+1)

theorem kelvin_scan_sound_and_complete (w : World width height) (remaining start : Nat) :
    kelvinScan w remaining start = true ↔
    ∀ offset, offset < remaining → cellTemperature w (start+offset) >= -27315 := by
  induction remaining generalizing start with
  | zero => simp [kelvinScan]
  | succ remaining ih =>
    rw [kelvinScan,Bool.and_eq_true,decide_eq_true_eq,ih]
    constructor
    · rintro ⟨first,rest⟩ offset inside
      cases offset with
      | zero => simpa only [Nat.add_zero] using first
      | succ offset =>
        have value := rest offset (by omega)
        have same : (start+1)+offset = start+(offset+1) := by omega
        rw [same] at value
        exact value
    · intro valid
      constructor
      · simpa only [Nat.add_zero] using valid 0 (by omega)
      · intro offset inside
        have value := valid (offset+1) (by omega)
        have same : (start+1)+offset = start+(offset+1) := by omega
        rw [same]
        exact value

def fluidCandidateAccept (before after : World width height) : Bool :=
  kelvinScan after (width*height) 0 && decide (fluidOverflow after <= fluidOverflow before) && decide (after.fluidResidual <= 10000)

theorem fluid_acceptance_sound_and_complete (before after : World width height) :
    fluidCandidateAccept before after = true ↔
    (∀ i, i < width*height → cellTemperature after i >= -27315) ∧
      fluidOverflow after <= fluidOverflow before ∧ after.fluidResidual <= 10000 := by
  simp only [fluidCandidateAccept,Bool.and_eq_true,decide_eq_true_eq,kelvin_scan_sound_and_complete,Nat.zero_add,and_assoc]

/-- Atomic candidates are retried with half timesteps, preserving the complete
    original state on rejection. Failed minimum steps are explicitly counted. -/
def adaptiveFluid : Nat → Float → Physics width height Unit
  | 0,dt => do
    let accepted ← Physics.transaction (fluidCandidate dt) fluidCandidateAccept
    if !accepted then
      Physics.metadata (fun w => {w with rejectedFluidSubsteps := w.rejectedFluidSubsteps+1}) (by intro w; rfl)
  | depth+1,dt => do
    let accepted ← Physics.transaction (fluidCandidate dt) fluidCandidateAccept
    if !accepted then
      adaptiveFluid depth (dt/2)
      adaptiveFluid depth (dt/2)

@[noinline] def fluidStep : Physics width height Unit := do
  let w ← Physics.getWorld
  let mut speed := (0 : Float)
  for i in [:width*height] do
    let p := read w i
    if !fluidObstacle height width i p then
      speed := floatMax speed (floatAbs (floatInt p.vx/1000000)+floatAbs (floatInt p.vy/1000000))
  let rate := floatNat ticksPerSecond
  let substeps := min 32 (max 1 (((speed+9.81/rate)/(rate*0.004)).toUInt64.toNat+1))
  let dt := 1/(rate*floatNat substeps)
  for _ in [:substeps] do adaptiveFluid 6 dt

theorem fluid_solver_preserves_every_element_and_energy (w : World width height) :
    Conserves w (fluidStep.run w).2 := fluidStep.preserves w

end Sand2
