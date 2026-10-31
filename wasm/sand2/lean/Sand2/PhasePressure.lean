import Sand2.State
import Sand2.Bracketing

namespace Sand2

/-- Noncondensable gas plus the heat-supported water vapor at a candidate
    saturation pressure, using the parcel's fixed enthalpy and cell volume. -/
def predictedPhasePressure (p : Particle) (h : Int) (candidate : Nat) : Nat :=
  let t := saturationTemperature candidate
  let d := waterDiagram p t
  let water := phaseFraction p.matter.water d.boilStart d.boilEnd h
  let moles := p.matter.oxygen+p.matter.nitrogen+p.matter.carbonDioxide+p.matter.hydrogen+water
  (idealGasPressure moles t).toNat

/-- Condensed cells include their own bubble pressure. Cold liquid needs no
    search; phase coexistence uses a fixed twelve-step bracket, avoiding a stiff
    explicit pressure/temperature feedback loop. Outside 0–200 C the curve is
    clamped and is not a high-pressure or supercritical-water equation of state. -/
@[noinline] def equilibriumPhasePressure (p : Particle) (h : Int) (ambient : Nat) : Nat :=
  let start := max 1 ambient
  let stop := max start maximumSaturationPressure
  if h < (waterDiagram p (saturationTemperature start)).boilStart then start
  else
    let bracket : Bracket := ⟨start,stop,Nat.le_max_left _ _⟩
    let below := fun pressure => pressure < predictedPhasePressure p h pressure
    (refineBracket below 12 bracket).lo

theorem phase_pressure_cannot_drop_below_environment (p : Particle) (h : Int) (ambient : Nat) :
    ambient <= equilibriumPhasePressure p h ambient := by
  unfold equilibriumPhasePressure
  dsimp only
  split
  · omega
  · have bounds := (refinement_stays_inside
      (fun pressure => pressure < predictedPhasePressure p h pressure) 12
      ⟨max 1 ambient,max (max 1 ambient) maximumSaturationPressure,Nat.le_max_left _ _⟩).1
    exact Nat.le_trans (Nat.le_max_right _ _) bounds

theorem phase_pressure_search_stays_in_bracket (p : Particle) (h : Int) (ambient : Nat) :
    equilibriumPhasePressure p h ambient <= max (max 1 ambient) maximumSaturationPressure := by
  unfold equilibriumPhasePressure
  dsimp only
  split
  · exact Nat.le_max_left _ _
  · have bounds := (refinement_stays_inside
      (fun pressure => pressure < predictedPhasePressure p h pressure) 12
      ⟨max 1 ambient,max (max 1 ambient) maximumSaturationPressure,Nat.le_max_left _ _⟩).2
    exact Nat.le_trans (refineBracket _ _ _).ordered bounds

end Sand2
