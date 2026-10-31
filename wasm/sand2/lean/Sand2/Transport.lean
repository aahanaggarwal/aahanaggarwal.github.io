import Sand2.Portions

namespace Sand2
open Chemistry

/-- Both opposing packets use the same face height for gravitational energy.
    Equal counterflows therefore cancel exactly, without inventing heat in a
    uniform gas. Unequal flows retain the gravitational work in total energy. -/
def facePotential (height width i j : Nat) (p : Particle) : Int :=
  (potentialEnergy height width i p+potentialEnergy height width j p)/2

def gasPacket (height width i j : Nat) (source : Particle) (matter : Mixture) : Particle :=
  let dm := Chemistry.mass matter
  let p := makeParticle matter 0
  let p := {p with px := source.vx*(dm : Int),py := source.vy*(dm : Int)}
  let sensible := internalEnergyAt matter .steam (temperature height width i source)
  let moles := matter.oxygen+matter.nitrogen+matter.carbonDioxide+matter.hydrogen+matter.water
  let flowWork := (moles : Int)*8314*(temperature height width i source+27315)
  let energy := p.chemical+sensible+flowWork+kineticEnergy p+facePotential height width i j p
  {p with energy}

def gasFlowEdit (height width i j : Nat) (a b : Particle) (divisor : Nat) : PairEdit a b :=
  let portion := partialGasPortion a.matter divisor (vaporWaterMoles height width i a)
  let q := gasPacket height width i j a portion.moved
  portionEdit a b portion (emptyPortion b.matter) q.energy 0 q.px 0 q.py 0

/-- Symmetric molecular mixing works at equal pressure, unlike bulk pressure
    relaxation alone. Opposing portions are taken from the same original pair. -/
def gasDiffusionEdit (height width i j : Nat) (a b : Particle) (divisor : Nat) : PairEdit a b :=
  let pa := partialGasPortion a.matter divisor (vaporWaterMoles height width i a)
  let pb := partialGasPortion b.matter divisor (vaporWaterMoles height width j b)
  let qa := gasPacket height width i j a pa.moved
  let qb := gasPacket height width j i b pb.moved
  portionEdit a b pa pb qa.energy qb.energy qa.px qb.px qa.py qb.py

theorem gas_diffusion_conserves_every_element (a b : Particle) (d : Nat) :
    atomAdd (atoms (gasDiffusionEdit height width i j a b d).first.matter)
      (atoms (gasDiffusionEdit height width i j a b d).second.matter) =
    atomAdd (atoms a.matter) (atoms b.matter) := (gasDiffusionEdit height width i j a b d).atoms_eq

theorem gas_diffusion_conserves_total_energy (a b : Particle) (d : Nat) :
    (gasDiffusionEdit height width i j a b d).first.energy+
    (gasDiffusionEdit height width i j a b d).second.energy = a.energy+b.energy :=
  (gasDiffusionEdit height width i j a b d).energy_eq

theorem identical_gas_mixtures_are_stationary (m : Mixture) (d : Nat) (v : Bool) :
    exchangePortions m m (gasPortion m d v) (gasPortion m d v) = (m,m) := by
  simp only [exchangePortions,gasPortion,gas_partition_recombines]

/-- 1/300 exchange per 1/60 s tick at 1 cm spacing corresponds to the rounded
    ordinary-gas diffusivity 0.2 cm²/s. Hydrogen uses a faster 1/100 exchange. -/
def diffusionDivisor (a b : Mixture) : Nat := if a.hydrogen+b.hydrogen > 0 then 100 else 300

theorem diffusion_divisor_positive (a b : Mixture) : diffusionDivisor a b > 0 := by
  unfold diffusionDivisor; split <;> decide

end Sand2
