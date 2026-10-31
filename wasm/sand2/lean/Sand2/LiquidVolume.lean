import Sand2.State

namespace Sand2
open Chemistry

/-- Reference volume uses 10^10 units per cubic centimetre. Coefficients are
    rounded constant partial molar volumes; thermal expansion is not yet used.
    Aqueous solutes occupy solution volume, rather than dry crystal volume. -/
def cellVolume : Nat := 10000000000

def referenceLiquidVolume (m : Mixture) : Nat :=
  180*m.water+175*m.oil+273*m.silica+80*m.iron+178*m.acid+
  166*m.salt+510*m.calciumChloride+400*m.ironChloride+
  480*m.nitrate+550*m.sulfide

theorem reference_liquid_volume_additive (a b : Mixture) :
    referenceLiquidVolume (add a b) = referenceLiquidVolume a+referenceLiquidVolume b := by
  simp [referenceLiquidVolume,add,Nat.mul_add]
  omega

/-- The melting plateau admits a liquid fraction; vapor molecules are excluded.
    This is a state selection, not a chemical conversion of H2O. -/
def liquidWaterFromInternalEnergy (p : Particle) (h : Int) : Nat :=
  if p.matter.water == 0 then 0 else
  let d := waterDiagram p
  if h < d.meltEnd then phaseFractionFast p.matter.water d.meltStart d.meltEnd h
  else p.matter.water-vaporWaterFromEnthalpy p h

def liquidWaterMoles (height width i : Nat) (p : Particle) : Nat :=
  liquidWaterFromInternalEnergy p (thermalEnergy height width i p)

theorem liquid_water_cannot_exceed_inventory (p : Particle) :
    liquidWaterMoles height width i p <= p.matter.water := by
  dsimp only [liquidWaterMoles,liquidWaterFromInternalEnergy]
  split
  · omega
  · split
    · simpa only [phase_fraction_fast_matches_reference] using phase_fraction_bounded _ _ _ _
    · omega

/-- Only liquid is advected by the liquid velocity field. Oxygen, nitrogen,
    hydrogen and carbon dioxide remain in the gas inventory. -/
def rawLiquidMatterFromInternalEnergy (p : Particle) (h : Int) : Mixture :=
  let water := liquidWaterFromInternalEnergy p h
  let dissolved := water > 0
  let moltenSilica := phaseFractionFast p.matter.silica (silicaDiagram p).meltStart (silicaDiagram p).meltEnd h
  let moltenIron := phaseFractionFast p.matter.iron (ironDiagram p).meltStart (ironDiagram p).meltEnd h
  {water,oil := p.matter.oil,
   silica := moltenSilica,
   iron := moltenIron,
   acid := if dissolved then p.matter.acid else 0,
   salt := if dissolved then p.matter.salt else 0,
   calciumChloride := if dissolved then p.matter.calciumChloride else 0,
   ironChloride := if dissolved then p.matter.ironChloride else 0,
   nitrate := if dissolved then p.matter.nitrate else 0,
   sulfide := if dissolved then p.matter.sulfide else 0}

theorem partial_mineral_liquid_cannot_exceed_inventory (p : Particle) (h : Int) :
    (rawLiquidMatterFromInternalEnergy p h).iron <= p.matter.iron ∧
    (rawLiquidMatterFromInternalEnergy p h).silica <= p.matter.silica :=
  by
    simpa only [rawLiquidMatterFromInternalEnergy,phase_fraction_fast_matches_reference] using
      And.intro (phase_fraction_bounded p.matter.iron (ironDiagram p).meltStart (ironDiagram p).meltEnd h)
        (phase_fraction_bounded p.matter.silica (silicaDiagram p).meltStart (silicaDiagram p).meltEnd h)

theorem zero_dry_mass_has_no_condensed_species (p : Particle) (zero : p.dryMass = 0) :
    p.matter.biomass = 0 ∧ p.matter.oil = 0 ∧ p.matter.carbon = 0 ∧ p.matter.silica = 0 ∧
    p.matter.salt = 0 ∧ p.matter.acid = 0 ∧ p.matter.carbonate = 0 ∧ p.matter.calciumChloride = 0 ∧
    p.matter.iron = 0 ∧ p.matter.rust = 0 ∧ p.matter.ironChloride = 0 ∧
    p.matter.nitrate = 0 ∧ p.matter.sulfur = 0 ∧ p.matter.sulfide = 0 := by
  rw [p.dryMass_eq] at zero
  dsimp [nonWaterCondensedMass] at zero
  omega

def liquidMatterFromInternalEnergy (p : Particle) (h : Int) : Mixture :=
  if p.matter.water == 0 && p.dryMass == 0 then {} else rawLiquidMatterFromInternalEnergy p h

theorem pure_gas_fastpath_matches_complete_phase_selection (p : Particle) (h : Int) :
    liquidMatterFromInternalEnergy p h = rawLiquidMatterFromInternalEnergy p h := by
  unfold liquidMatterFromInternalEnergy
  split
  · rename_i pureGas
    simp only [Bool.and_eq_true,beq_iff_eq] at pureGas
    obtain ⟨biomass,oil,carbon,silica,salt,acid,carbonate,calcium,iron,rust,chloride,nitrate,sulfur,sulfide⟩ :=
      zero_dry_mass_has_no_condensed_species p pureGas.2
    simp [rawLiquidMatterFromInternalEnergy,liquidWaterFromInternalEnergy,pureGas.1,
      oil,silica,iron,phaseFractionFast]
  · rfl

def liquidMatter (height width i : Nat) (p : Particle) : Mixture :=
  if p.matter.water == 0 && p.dryMass == 0 then {} else
    liquidMatterFromInternalEnergy p (thermalEnergy height width i p)

theorem liquid_read_fastpath_matches_complete_phase (p : Particle) :
    liquidMatter height width i p = liquidMatterFromInternalEnergy p (thermalEnergy height width i p) := by
  unfold liquidMatter
  split
  · rename_i gas
    simp only [liquidMatterFromInternalEnergy,gas,↓reduceIte]
  · rfl

theorem liquid_advection_excludes_noncondensing_gases (p : Particle) :
    (liquidMatter height width i p).oxygen = 0 ∧
    (liquidMatter height width i p).nitrogen = 0 ∧
    (liquidMatter height width i p).carbonDioxide = 0 ∧
    (liquidMatter height width i p).hydrogen = 0 ∧
    (liquidMatter height width i p).methane = 0 ∧
    (liquidMatter height width i p).carbonMonoxide = 0 := by
  rw [liquid_read_fastpath_matches_complete_phase,pure_gas_fastpath_matches_complete_phase_selection]
  exact ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩

def liquidVolume (height width i : Nat) (p : Particle) : Nat :=
  referenceLiquidVolume (liquidMatter height width i p)

/-- A bounded request selects the same fraction of every dissolved component. -/
def liquidRequest (m : Mixture) (requested : Nat) : Mixture :=
  let total := max 1 (referenceLiquidVolume m)
  let amount := min requested (referenceLiquidVolume m)
  {water := m.water*amount/total,oil := m.oil*amount/total,
   silica := m.silica*amount/total,iron := m.iron*amount/total,
   acid := m.acid*amount/total,salt := m.salt*amount/total,
   calciumChloride := m.calciumChloride*amount/total,
   ironChloride := m.ironChloride*amount/total,
   nitrate := m.nitrate*amount/total,sulfide := m.sulfide*amount/total}

theorem liquid_request_cannot_exceed_component (m : Mixture) (requested : Nat) :
    (liquidRequest m requested).water <= m.water ∧
    (liquidRequest m requested).oil <= m.oil ∧
    (liquidRequest m requested).silica <= m.silica ∧
    (liquidRequest m requested).iron <= m.iron ∧
    (liquidRequest m requested).acid <= m.acid ∧
    (liquidRequest m requested).salt <= m.salt ∧
    (liquidRequest m requested).calciumChloride <= m.calciumChloride ∧
    (liquidRequest m requested).ironChloride <= m.ironChloride ∧
    (liquidRequest m requested).nitrate <= m.nitrate ∧
    (liquidRequest m requested).sulfide <= m.sulfide := by
  have bound : min requested (referenceLiquidVolume m) <= max 1 (referenceLiquidVolume m) := by omega
  have positive : 0 < max 1 (referenceLiquidVolume m) := by omega
  have scale (n : Nat) : n*min requested (referenceLiquidVolume m)/max 1 (referenceLiquidVolume m) <= n := by
    apply (Nat.div_le_iff_le_mul positive).2
    have h := Nat.mul_le_mul_left n bound
    omega
  exact ⟨scale _,scale _,scale _,scale _,scale _,scale _,scale _,scale _,scale _,scale _⟩

/-- Integer rounding can only reduce the requested volume. This bound applies
    to arbitrarily large requests, independently of floating-point decisions. -/
theorem liquid_request_volume_bounded (m : Mixture) (requested : Nat) :
    referenceLiquidVolume (liquidRequest m requested) <= min requested (referenceLiquidVolume m) := by
  let v := referenceLiquidVolume m
  let d := max 1 v
  let a := min requested v
  have positive : 0 < d := by dsimp [d]; omega
  have rounding (n : Nat) : n*a/d*d <= n*a := Nat.div_mul_le_self _ _
  have scaled : referenceLiquidVolume (liquidRequest m requested)*d <= v*a := by
    have hw := rounding m.water
    have ho := rounding m.oil
    have hs := rounding m.silica
    have hf := rounding m.iron
    have ha := rounding m.acid
    have hn := rounding m.salt
    have hc := rounding m.calciumChloride
    have hi := rounding m.ironChloride
    have hk := rounding m.nitrate
    have hp := rounding m.sulfide
    change (180*(m.water*a/d)+175*(m.oil*a/d)+273*(m.silica*a/d)+80*(m.iron*a/d)+
      178*(m.acid*a/d)+166*(m.salt*a/d)+510*(m.calciumChloride*a/d)+
      400*(m.ironChloride*a/d)+480*(m.nitrate*a/d)+550*(m.sulfide*a/d))*d <=
      (180*m.water+175*m.oil+273*m.silica+80*m.iron+178*m.acid+166*m.salt+
      510*m.calciumChloride+400*m.ironChloride+480*m.nitrate+550*m.sulfide)*a
    simp only [Nat.add_mul,Nat.mul_assoc]
    omega
  have larger : v*a <= d*a := Nat.mul_le_mul_right a (Nat.le_max_right 1 v)
  have total : referenceLiquidVolume (liquidRequest m requested)*d <= a*d := by
    have commutes : d*a = a*d := Nat.mul_comm _ _
    omega
  exact Nat.le_of_mul_le_mul_right total positive

end Sand2
