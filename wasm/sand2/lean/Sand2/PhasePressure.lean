import Sand2.LiquidField
import Sand2.Bracketing

namespace Sand2
open Chemistry

/-- Fixed-inventory, fixed-energy and fixed-volume phase closure. The trial
    water partial pressure sets a fine saturation point; the EOS determines the
    total mechanical pressure from the resulting vapor and liquid inventories. -/
def predictedFlashPartialPressure (p : Particle) (h : Int) (candidate : Nat) : Nat :=
  let q := atPressure p candidate
  let vapor := vaporWaterFromEnthalpy q h
  let gas := dryGasMoles q.matter+vapor
  mechanicalPressureFromInternalEnergy q h*vapor/max 1 gas

def flashPressureSearch (p : Particle) (h : Int) : Nat :=
  let bracket : Bracket := ⟨0,maximumSaturationPressure,Nat.zero_le _⟩
  (refineBracket (fun pressure => pressure < predictedFlashPartialPressure p h pressure) 32 bracket).hi

theorem flash_search_pressure_bounded (p : Particle) (h : Int) :
    flashPressureSearch p h <= maximumSaturationPressure :=
  (refinement_stays_inside _ _ _).2

theorem flash_search_cannot_overproduce_vapor (p : Particle) (h : Int)
    (domain : predictedFlashPartialPressure p h maximumSaturationPressure <= maximumSaturationPressure) :
    predictedFlashPartialPressure p h (flashPressureSearch p h) <= flashPressureSearch p h := by
  let below := fun pressure => decide (pressure < predictedFlashPartialPressure p h pressure)
  have upper : below maximumSaturationPressure = false := by
    simp only [below,decide_eq_false_iff_not]
    omega
  have safe := refinement_retains_false_upper below 32 ⟨0,maximumSaturationPressure,Nat.zero_le _⟩ upper
  change decide (flashPressureSearch p h < predictedFlashPartialPressure p h (flashPressureSearch p h)) = false at safe
  simp only [decide_eq_false_iff_not] at safe
  omega

theorem no_vapor_below_boiling (p : Particle) (h : Int) (cold : h < (waterDiagram p).boilStart) :
    vaporWaterFromEnthalpy p h = 0 := by
  unfold vaporWaterFromEnthalpy
  split
  · rfl
  · simpa only [phase_fraction_fast_matches_reference] using phase_fraction_zero_below_start _ _ _ _ (waterDiagram p).order₃ cold

theorem reapplying_current_phase_pressure_changes_nothing (p : Particle) :
    atPressure p p.phasePressure = p := by
  cases p
  simp_all [atPressure]

@[noinline] def flashEquilibriumPressure (p : Particle) (h : Int) : Nat :=
  let dryGas := dryGasMoles p.matter
  let reference := referenceLiquidVolume (liquidMatterFromInternalEnergy p h)
  let base := max p.mechanicalPressure (liquidReferencePressure reference)
  if dryGas == 0 && reference+1000 >= cellVolume && h < (waterDiagram (atPressure p base)).boilStart then base
  else
    let d := waterDiagram p
    let vapor := vaporWaterFromEnthalpy p h
    if vapor == 0 && h >= d.boilStart && h < d.boilEnd then p.phasePressure
    else if ((predictedFlashPartialPressure p h p.phasePressure : Int)-(p.phasePressure : Int)).natAbs <= 5000 then p.phasePressure
    else
      flashPressureSearch p h

/-- All executable fast paths and the full search obey the same vapor-pressure
    safety bound. The 5 Pa tolerance avoids repeatedly solving an already
    equilibrated cell. The high endpoint assumption states the curve's domain. -/
theorem flash_equilibrium_vapor_pressure_within_tolerance (p : Particle) (h : Int)
    (domain : predictedFlashPartialPressure p h maximumSaturationPressure <= maximumSaturationPressure) :
    predictedFlashPartialPressure p h (flashEquilibriumPressure p h) <= flashEquilibriumPressure p h+5000 := by
  unfold flashEquilibriumPressure
  dsimp only
  split
  · rename_i cold
    simp only [Bool.and_eq_true,beq_iff_eq,decide_eq_true_eq] at cold
    have noVapor := no_vapor_below_boiling _ _ cold.2
    simp only [predictedFlashPartialPressure,noVapor,Nat.mul_zero,Nat.zero_div]
    omega
  · split
    · rename_i plateau
      simp only [Bool.and_eq_true,beq_iff_eq,decide_eq_true_eq] at plateau
      simp only [predictedFlashPartialPressure,reapplying_current_phase_pressure_changes_nothing,
        plateau.1.1,Nat.mul_zero,Nat.zero_div]
      omega
    · split
      · rename_i close
        omega
      · have safe := flash_search_cannot_overproduce_vapor p h domain
        omega

/-- Equilibrium changes phase fractions and pressure, never molecular inventory
    or total energy. Each actual cell edit carries these certificates. -/
def equilibriumParticleFromInternalEnergy (p : Particle) (h : Int) : Particle :=
  let target := if p.matter.water == 0 then p.phasePressure else flashEquilibriumPressure p h
  let q := if p.matter.water == 0 then p else atPressure p target
  let vapor := vaporWaterFromEnthalpy q h
  let gas := dryGasMoles q.matter+vapor
  let reference := referenceLiquidVolume (liquidMatterFromInternalEnergy q h)
  let pressure := if gas == 0 then quantizedLiquidPressure reference p.mechanicalPressure
    else mechanicalPressureFromInternalEnergy q h
  {q with mechanicalPressure := pressure}

theorem flash_equilibrium_preserves_every_molecule (p : Particle) (h : Int) :
    (equilibriumParticleFromInternalEnergy p h).matter = p.matter := by
  dsimp only [equilibriumParticleFromInternalEnergy]
  split <;> rfl

theorem flash_equilibrium_preserves_total_energy (p : Particle) (h : Int) :
    (equilibriumParticleFromInternalEnergy p h).energy = p.energy := by
  dsimp only [equilibriumParticleFromInternalEnergy]
  split <;> rfl


end Sand2
