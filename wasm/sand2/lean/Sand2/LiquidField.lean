import Sand2.LiquidVolume
import Sand2.FluidNumerics

namespace Sand2
open Chemistry

/-- The low-Mach mixture uses a rounded 2.2 GPa liquid bulk modulus. Pressure
    is millipascals; reference volume is at atmospheric pressure. -/
def liquidBulkModulus : Nat := 2200000000000

def occupiedLiquidVolume (height width i : Nat) (p : Particle) : Nat :=
  liquidVolume height width i p*liquidBulkModulus/
    (liquidBulkModulus+p.mechanicalPressure-101325000)

/-- A solid skeleton is impermeable at this resolution. Sub-resolution reaction
    dust can be carried by the fluid; macroscopic grains have their own mechanics. -/
def fluidObstacle (height width i : Nat) (p : Particle) : Bool :=
  if p.anchored then true else if p.matter.water == 0 && p.dryMass == 0 then false
  else condensedMass height width i p > Chemistry.mass (liquidMatter height width i p)+10000000

def gasFreeVolume (height width i : Nat) (p : Particle) : Nat :=
  if p.anchored then 0 else if p.matter.water == 0 && p.dryMass == 0 then cellVolume
  else if fluidObstacle height width i p then 0 else cellVolume-occupiedLiquidVolume height width i p

def volumeGasPressure (height width i : Nat) (p : Particle) : Int :=
  idealGasPressure (gasCount height width i p) (temperature height width i p)*cellVolume/
    max 1 (gasFreeVolume height width i p)

theorem gas_free_volume_bounded (p : Particle) : gasFreeVolume height width i p <= cellVolume := by
  dsimp only [gasFreeVolume]
  split
  · omega
  · split
    · omega
    · split <;> omega

/-- Dynamic viscosity in Pa s, with rounded fixed-temperature values. -/
def liquidViscosity (m : Mixture) : Float :=
  if m.silica > 0 then 1000000 else if m.iron > 0 then 0.006
  else if m.oil > m.water then 0.05 else 0.001

def gasGamma (height width i : Nat) (p : Particle) : Float :=
  let vapor := vaporWaterMoles height width i p
  let n := dryGasMoles p.matter+vapor
  let cv := gasCv p.matter+27686*vapor
  1+8314*floatNat n/floatNat (max 1 cv)

/-- Exact liquid density equation of state. The volume and pressure units give
    B/cellVolume = 220, so the pure-liquid branch needs no floating-point root. -/
def liquidReferencePressure (volume : Nat) : Nat := volume*220+101325000-liquidBulkModulus

/-- Positive root of Vliquid(P)+nRT/P=Vcell, evaluated in a cancellation-safe
    form. Gas-free liquid uses the exact integer branch above. -/
def mixtureEOSPressure (referenceFraction gasFullCellPressure : Float) : Float :=
  let a := (2200000000-101325 : Float)
  let b := a-2200000000*referenceFraction-gasFullCellPressure
  let c := gasFullCellPressure*a
  let discriminant := (b*b+4*c).sqrt
  if b >= 0 then 2*c/floatMax 0.000000000000000001 (b+discriminant)
  else (discriminant-b)/2

def quantizedLiquidPressure (volume previous : Nat) : Nat :=
  let exact := liquidReferencePressure volume
  if previous <= exact+40000 ∧ exact <= previous+40000 then previous else exact

theorem quantized_pressure_deviation_bounded (volume previous : Nat) :
    quantizedLiquidPressure volume previous <= liquidReferencePressure volume+40000 ∧
    liquidReferencePressure volume <= quantizedLiquidPressure volume previous+40000 := by
  dsimp only [quantizedLiquidPressure]
  split <;> omega

theorem quantized_liquid_volume_bounded (volume previous : Nat) :
    volume*liquidBulkModulus/(liquidBulkModulus+quantizedLiquidPressure volume previous-101325000) <= cellVolume+200 := by
  have positive : 0 < liquidBulkModulus+quantizedLiquidPressure volume previous-101325000 := by
    dsimp [liquidBulkModulus]
    omega
  apply Nat.le_of_lt_succ
  apply (Nat.div_lt_iff_lt_mul positive).2
  have bound := quantized_pressure_deviation_bounded volume previous
  dsimp [liquidBulkModulus,liquidReferencePressure,cellVolume] at *
  omega

/-- Mechanical closure uses the complete liquid/gas inventory at one common
    internal energy. Pure gas and pure liquid have exact integer branches. -/
def mechanicalEOSPressure (reference gasMoles : Nat) (t : Int) : Nat :=
  if reference == 0 then (idealGasPressure gasMoles t).toNat
  else if gasMoles == 0 then liquidReferencePressure reference
  else
    let gasPressure := floatInt (idealGasPressure gasMoles t)/1000
    (finiteClamp 0 1000000000000 (mixtureEOSPressure (floatNat reference/floatNat cellVolume) gasPressure)*1000).toUInt64.toNat

def mechanicalPressureFromInternalEnergy (p : Particle) (h : Int) : Nat :=
  let vapor := vaporWaterFromEnthalpy p h
  let gas := dryGasMoles p.matter+vapor
  mechanicalEOSPressure (referenceLiquidVolume (liquidMatterFromInternalEnergy p h)) gas (temperatureFromEnthalpy p h)

structure FluidGeometry where
  width : Nat
  height : Nat
  active : Array Bool
  fill : FloatArray
  density : FloatArray
  viscosity : FloatArray
  vx : FloatArray
  vy : FloatArray
  pressure : FloatArray
  compressibility : FloatArray

@[always_inline, inline] def fieldBool (a : Array Bool) (i : Nat) : Bool := boolAt a i

/-- Gas and liquid share the pressure solve and velocity field. This transmits
    pressure work and displaces air through its own connected space; air is not
    swapped backward through a water-filled passage. -/
@[noinline] def fluidGeometry (w : World width height) : FluidGeometry := Id.run do
  let n := width*height
  let mut active := Array.replicate n false
  let mut fill := floats n
  let mut density := floats n 1
  let mut viscosity := floats n 0.000018
  let mut vx := floats n
  let mut vy := floats n
  let mut pressure := floats n
  let mut compressibility := floats n
  for i in [:n] do
    let p := read w i
    if fluidObstacle height width i p then continue
    active := active.set! i true
    let liquid := liquidMatter height width i p
    let reference := referenceLiquidVolume liquid
    let referenceFraction := floatNat reference/floatNat cellVolume
    let moles := gasCount height width i p
    let priorNat := if moles == 0 then quantizedLiquidPressure reference p.mechanicalPressure
      else mechanicalEOSPressure reference moles (temperature height width i p)
    let prior := finiteClamp 0 1000000000000 (floatNat priorNat/1000)
    let fraction := finiteClamp 0 1 (referenceFraction*2200000000/(2200000000+prior-101325))
    fill := fill.set! i fraction
    density := density.set! i (finiteClamp 0.001 30000 (floatNat p.mass/1000000))
    viscosity := viscosity.set! i (fraction*liquidViscosity liquid+(1-fraction)*0.000018)
    vx := vx.set! i (finiteClamp (-3) 3 (floatInt p.vx/1000000))
    vy := vy.set! i (finiteClamp (-3) 3 (floatInt p.vy/1000000))
    pressure := pressure.set! i prior
    let beta := fraction/2200000000+(1-fraction)/(gasGamma height width i p*floatMax 101325 prior)
    compressibility := compressibility.set! i beta
  return {width,height,active,fill,density,viscosity,vx,vy,pressure,compressibility}

def harmonic (a b : Float) : Float := 2*a*b/floatMax 0.000000000001 (a+b)

/-- Backward-Euler viscous momentum diffusion in a variable-density mixture.
    Solid faces have no slip; the pressure projection supplies wall impulses. -/
@[noinline] def viscositySystem (g : FluidGeometry) (dt : Float) (vertical : Bool) : PressureSystem := Id.run do
  let n := g.width*g.height
  let mut right := floats n
  let mut down := floats n
  let mut diagonal := floats n
  let mut rhs := floats n
  for i in [:n] do
    if !fieldBool g.active i then continue
    let mu := floatAt g.viscosity i
    let rho := floatAt g.density i
    let mut diag := rho
    for j in [if i%g.width+1 < g.width then i+1 else n,
        if i%g.width > 0 then i-1 else n,
        if i/g.width+1 < g.height then i+g.width else n,
        if i/g.width > 0 then i-g.width else n] do
      let coeff := if j >= n || !fieldBool g.active j then 2*mu*dt/0.0001
        else harmonic mu (floatAt g.viscosity j)*dt/0.0001
      diag := diag+coeff
      if j == i+1 then right := right.set! i coeff
      if j == i+g.width then down := down.set! i coeff
    diagonal := diagonal.set! i diag
    rhs := rhs.set! i (rho*(if vertical then floatAt g.vy i else floatAt g.vx i))
  return {width := g.width,height := g.height,unknown := g.active,diagonal,right,down,rhs,mask_eq := rfl}

def fluidFace (g : FluidGeometry) (i j : Nat) : Float :=
  if fieldBool g.active i && fieldBool g.active j then
    2/floatMax 0.001 (floatAt g.density i+floatAt g.density j)
  else 0

structure FluidVelocity where
  u : FloatArray
  v : FloatArray
  rawU : FloatArray
  rawV : FloatArray
  cellU : FloatArray
  cellV : FloatArray
  pressure : FloatArray
  residual : Float
  iterations : Nat

/-- Implicit acoustic/pressure correction with mixture compressibility. Liquid
    approaches incompressibility; gas can compress in a sealed headspace. -/
@[noinline] def projectFluid (g : FluidGeometry) (dt : Float) : FluidVelocity := Id.run do
  let n := g.width*g.height
  let ux := (pressureSolve (viscositySystem g dt false) 128 0.00000001).values
  let vy := (pressureSolve (viscositySystem g dt true) 128 0.00000001).values
  let mut cellV := floats n
  let mut right := floats n
  let mut down := floats n
  let mut rawU := floats n
  let mut rawV := floats n
  let mut u := floats n
  let mut v := floats n
  for i in [:n] do
    if fieldBool g.active i then cellV := cellV.set! i (floatAt vy i+9.81*dt)
    if i%g.width+1 < g.width then
      let j := i+1
      let coeff := fluidFace g i j
      right := right.set! i coeff
      if fieldBool g.active i || fieldBool g.active j then
        let speed := if fieldBool g.active i && fieldBool g.active j then (floatAt ux i+floatAt ux j)/2
          else if fieldBool g.active i then floatAt ux i else floatAt ux j
        rawU := rawU.set! i speed
        if coeff > 0 then u := u.set! i (speed-dt/0.01*coeff*(floatAt g.pressure j-floatAt g.pressure i))
    if i/g.width+1 < g.height then
      let j := i+g.width
      let coeff := fluidFace g i j
      down := down.set! i coeff
      if fieldBool g.active i || fieldBool g.active j then
        let speed := (if fieldBool g.active i && fieldBool g.active j then (floatAt vy i+floatAt vy j)/2
          else if fieldBool g.active i then floatAt vy i else floatAt vy j)+9.81*dt
        rawV := rawV.set! i speed
        if coeff > 0 then v := v.set! i (speed-dt/0.01*coeff*(floatAt g.pressure j-floatAt g.pressure i))
  let mut diagonal := floats n
  let mut rhs := floats n
  for i in [:n] do
    if !fieldBool g.active i then continue
    let left := if i%g.width > 0 then floatAt right (i-1) else 0
    let up := if i/g.width > 0 then floatAt down (i-g.width) else 0
    let divergence := floatAt u i-(if i%g.width > 0 then floatAt u (i-1) else 0)+
      floatAt v i-(if i/g.width > 0 then floatAt v (i-g.width) else 0)
    diagonal := diagonal.set! i (floatAt right i+left+floatAt down i+up+floatAt g.compressibility i*0.0001/(dt*dt))
    rhs := rhs.set! i (-divergence*0.01/dt)
  let system : PressureSystem := {
    width := g.width
    height := g.height
    unknown := g.active
    diagonal,right,down,rhs,mask_eq := rfl }
  let lower := floats n
  let mut lower := lower
  for i in [:n] do lower := lower.set! i (-floatAt g.pressure i)
  let solution := boundedPressureSolve system lower
  let mut pressure := g.pressure
  for i in [:n] do
    if fieldBool g.active i then pressure := pressure.set! i (floatAt g.pressure i+floatAt solution.values i)
    if i%g.width+1 < g.width && floatAt right i > 0 then
      u := u.set! i (finiteClamp (-3) 3 (floatAt u i-dt/0.01*floatAt right i*(floatAt solution.values (i+1)-floatAt solution.values i)))
    if i/g.width+1 < g.height && floatAt down i > 0 then
      v := v.set! i (finiteClamp (-3) 3 (floatAt v i-dt/0.01*floatAt down i*(floatAt solution.values (i+g.width)-floatAt solution.values i)))
  return {
    u := u
    v := v
    rawU := rawU
    rawV := rawV
    cellU := ux
    cellV := cellV
    pressure := pressure
    residual := solution.residual/floatMax 1 (pressureRhsMagnitude system)
    iterations := solution.iterations }

theorem pure_liquid_eos_respects_cell_volume (volume : Nat) :
    volume*liquidBulkModulus/(liquidBulkModulus+liquidReferencePressure volume-101325000) <= cellVolume := by
  have positive : 0 < liquidBulkModulus+liquidReferencePressure volume-101325000 := by
    dsimp [liquidBulkModulus,liquidReferencePressure]
    omega
  apply Nat.le_of_lt_succ
  apply (Nat.div_lt_iff_lt_mul positive).2
  dsimp [liquidBulkModulus,liquidReferencePressure,cellVolume]
  omega


end Sand2
