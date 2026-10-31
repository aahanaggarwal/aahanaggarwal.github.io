import Sand2.Materials

namespace Sand2

/-- Fixed-point specific enthalpy. Temperature is in centidegrees Celsius;
    energy is in 1/100 joules per kilogram, before multiplication by mass.
    Water constants are rounded reference values, not fitted game rates. -/
def fusionWater : Int := 33400000
 def boilingWater : Int := 75200000
 def vaporWater : Int := 300900000

inductive WaterRegime where
  | ice | melting | liquid | boiling | vapor
  deriving DecidableEq, BEq, Repr

/-- Independent, relational phase specification. The plateau cases explicitly
    account for latent heat instead of changing material at a random rate. -/
inductive WaterEquilibrium (h : Int) : WaterRegime → Prop
  | ice (cold : h < 0) : WaterEquilibrium h .ice
  | melting (lo : 0 ≤ h) (hi : h < fusionWater) : WaterEquilibrium h .melting
  | liquid (lo : fusionWater ≤ h) (hi : h < boilingWater) : WaterEquilibrium h .liquid
  | boiling (lo : boilingWater ≤ h) (hi : h < vaporWater) : WaterEquilibrium h .boiling
  | vapor (hot : vaporWater ≤ h) : WaterEquilibrium h .vapor

def waterRegime (h : Int) : WaterRegime :=
  if h < 0 then .ice else if h < fusionWater then .melting
  else if h < boilingWater then .liquid else if h < vaporWater then .boiling else .vapor

theorem water_phase_sound (h : Int) : WaterEquilibrium h (waterRegime h) := by
  unfold waterRegime
  split
  · exact .ice (by assumption)
  · split
    · exact .melting (by omega) (by assumption)
    · split
      · exact .liquid (by omega) (by assumption)
      · split
        · exact .boiling (by omega) (by assumption)
        · exact .vapor (by omega)

theorem water_phase_complete (h : Int) (r : WaterRegime) (spec : WaterEquilibrium h r) :
    waterRegime h = r := by
  cases spec with
  | ice cold => simp [waterRegime,cold]
  | melting lo hi =>
    have h0 : ¬ h < 0 := by omega
    simp [waterRegime,h0,hi]
  | liquid lo hi =>
    have h0 : ¬ h < 0 := by unfold fusionWater at lo; omega
    have h1 : ¬ h < fusionWater := by omega
    simp [waterRegime,h0,h1,hi]
  | boiling lo hi =>
    have h0 : ¬ h < 0 := by unfold boilingWater at lo; omega
    have h1 : ¬ h < fusionWater := by unfold boilingWater fusionWater at *; omega
    have h2 : ¬ h < boilingWater := by omega
    simp [waterRegime,h0,h1,h2,hi]
  | vapor hot =>
    have h0 : ¬ h < 0 := by unfold vaporWater at hot; omega
    have h1 : ¬ h < fusionWater := by unfold vaporWater fusionWater at *; omega
    have h2 : ¬ h < boilingWater := by unfold vaporWater boilingWater at *; omega
    have h3 : ¬ h < vaporWater := by omega
    simp [waterRegime,h0,h1,h2,h3]

theorem water_phase_unique (h : Int) (a b : WaterRegime)
    (ha : WaterEquilibrium h a) (hb : WaterEquilibrium h b) : a = b := by
  rw [← water_phase_complete h a ha, ← water_phase_complete h b hb]

theorem water_phase_total (h : Int) : ∃ r, WaterEquilibrium h r ∧ ∀ s, WaterEquilibrium h s → s = r := by
  exact ⟨waterRegime h, water_phase_sound h, fun _ hr => (water_phase_complete h _ hr).symm⟩

def waterTemperature (h : Int) : Int :=
  match waterRegime h with
  | .ice => h / 2100
  | .melting => 0
  | .liquid => (h-fusionWater) / 4180
  | .boiling => 10000
  | .vapor => 10000+(h-vaporWater)/2000

def waterLabel : WaterRegime → Material
  | .ice | .melting => .ice
  | .liquid | .boiling => .water
  | .vapor => .steam

def waterMaterial (h : Int) : Material :=
  match waterRegime h with
  | .ice | .melting => .ice
  | .liquid | .boiling => .water
  | .vapor => .steam

theorem melting_plateau (h : Int) (lo : 0 ≤ h) (hi : h < fusionWater) :
    waterTemperature h = 0 := by
  have phase := water_phase_complete h .melting (.melting lo hi)
  simp [waterTemperature,phase]

theorem boiling_plateau (h : Int) (lo : boilingWater ≤ h) (hi : h < vaporWater) :
    waterTemperature h = 10000 := by
  have phase := water_phase_complete h .boiling (.boiling lo hi)
  simp [waterTemperature,phase]

theorem boiling_requires_latent_heat (h : Int) (noLatent : h < vaporWater) :
    waterMaterial h ≠ .steam := by
  have nv : waterRegime h ≠ .vapor := by
    intro hv
    have spec := water_phase_sound h
    rw [hv] at spec
    cases spec
    omega
  unfold waterMaterial
  cases hr : waterRegime h <;> simp_all

theorem freezing_releases_latent_heat : fusionWater > 0 := by decide

/-- A general ordered enthalpy diagram. Threshold ordering is part of the type,
    so a malformed material diagram cannot enter the simulation. -/
structure PhaseDiagram where
  meltStart : Int
  meltEnd : Int
  boilStart : Int
  boilEnd : Int
  order₁ : meltStart ≤ meltEnd
  order₂ : meltEnd ≤ boilStart
  order₃ : boilStart ≤ boilEnd

inductive Equilibrium (d : PhaseDiagram) (h : Int) : WaterRegime → Prop
  | solid (cold : h < d.meltStart) : Equilibrium d h .ice
  | melting (lo : d.meltStart ≤ h) (hi : h < d.meltEnd) : Equilibrium d h .melting
  | liquid (lo : d.meltEnd ≤ h) (hi : h < d.boilStart) : Equilibrium d h .liquid
  | boiling (lo : d.boilStart ≤ h) (hi : h < d.boilEnd) : Equilibrium d h .boiling
  | gas (hot : d.boilEnd ≤ h) : Equilibrium d h .vapor

def phase (d : PhaseDiagram) (h : Int) : WaterRegime :=
  if h < d.meltStart then .ice else if h < d.meltEnd then .melting
  else if h < d.boilStart then .liquid else if h < d.boilEnd then .boiling else .vapor

theorem phase_sound (d : PhaseDiagram) (h : Int) : Equilibrium d h (phase d h) := by
  unfold phase
  split
  · exact .solid (by assumption)
  · split
    · exact .melting (by omega) (by assumption)
    · split
      · exact .liquid (by omega) (by assumption)
      · split
        · exact .boiling (by omega) (by assumption)
        · exact .gas (by omega)

theorem phase_complete (d : PhaseDiagram) (h : Int) (r : WaterRegime) (spec : Equilibrium d h r) : phase d h = r := by
  have o1 := d.order₁
  have o2 := d.order₂
  have o3 := d.order₃
  cases spec with
  | solid cold => simp [phase,cold]
  | melting lo hi =>
    have n0 : ¬h<d.meltStart := by omega
    simp [phase,n0,hi]
  | liquid lo hi =>
    have n0 : ¬h<d.meltStart := by omega
    have n1 : ¬h<d.meltEnd := by omega
    simp [phase,n0,n1,hi]
  | boiling lo hi =>
    have n0 : ¬h<d.meltStart := by omega
    have n1 : ¬h<d.meltEnd := by omega
    have n2 : ¬h<d.boilStart := by omega
    simp [phase,n0,n1,n2,hi]
  | gas hot =>
    have n0 : ¬h<d.meltStart := by omega
    have n1 : ¬h<d.meltEnd := by omega
    have n2 : ¬h<d.boilStart := by omega
    have n3 : ¬h<d.boilEnd := by omega
    simp [phase,n0,n1,n2,n3]

theorem phase_unique (d : PhaseDiagram) (h : Int) (a b : WaterRegime)
    (ha : Equilibrium d h a) (hb : Equilibrium d h b) : a = b := by
  rw [← phase_complete d h a ha, ← phase_complete d h b hb]

theorem phase_total (d : PhaseDiagram) (h : Int) : ∃ r, Equilibrium d h r := ⟨_,phase_sound d h⟩

def thermalDiagram (mass cpSolid cpLiquid melt latentFusion boil latentVapor : Nat) : PhaseDiagram :=
  let a : Int := Int.ofNat (mass*cpSolid*melt)
  let b : Int := a + Int.ofNat (mass*latentFusion)
  let c : Int := b + Int.ofNat (mass*cpLiquid*(boil-melt))
  let d : Int := c + Int.ofNat (mass*latentVapor)
  ⟨a,b,c,d,Int.le_add_of_nonneg_right (Int.natCast_nonneg _),
    Int.le_add_of_nonneg_right (Int.natCast_nonneg _),
    Int.le_add_of_nonneg_right (Int.natCast_nonneg _)⟩

theorem thermal_diagram_ordered (mass cs cl tm lf tb lv : Nat) :
    (thermalDiagram mass cs cl tm lf tb lv).meltStart ≤ (thermalDiagram mass cs cl tm lf tb lv).boilEnd := by
  have h₁ := (thermalDiagram mass cs cl tm lf tb lv).order₁
  have h₂ := (thermalDiagram mass cs cl tm lf tb lv).order₂
  have h₃ := (thermalDiagram mass cs cl tm lf tb lv).order₃
  omega

end Sand2
