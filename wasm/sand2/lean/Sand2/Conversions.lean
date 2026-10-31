import Sand2.Conservative

namespace Sand2
open Chemistry

/-- Each component retains its own phase in a mixture. In particular, adding
    water never replaces an iron or silica fusion state with a water state. -/
structure ComponentPhases where
  water : WaterRegime
  iron : FusionPhase
  silica : FusionPhase
  deriving DecidableEq, BEq

@[macro_inline] def conversionPhase (height width i : Nat) (p : Particle) : ComponentPhases :=
  let h := thermalEnergy height width i p
  ⟨phase (waterDiagram p) h,fusionPhase (ironDiagram p) h,fusionPhase (silicaDiagram p) h⟩

/-- Independent relational specification for all three component transitions. -/
def ConversionSpec (height width i : Nat) (p : Particle) (r : ComponentPhases) : Prop :=
  let h := thermalEnergy height width i p
  Equilibrium (waterDiagram p) h r.water ∧ FusionEquilibrium (ironDiagram p) h r.iron ∧
    FusionEquilibrium (silicaDiagram p) h r.silica

theorem conversion_sound (p : Particle) :
    ConversionSpec height width i p (conversionPhase height width i p) :=
  ⟨phase_sound _ _,fusion_phase_sound _ _,fusion_phase_sound _ _⟩

theorem conversion_complete (p : Particle) (r : ComponentPhases)
    (spec : ConversionSpec height width i p r) : conversionPhase height width i p = r := by
  rcases r with ⟨water,iron,silica⟩
  rcases spec with ⟨hw,hi,hs⟩
  simp only [conversionPhase,phase_complete _ _ _ hw,
    fusion_phase_complete _ _ _ hi,fusion_phase_complete _ _ _ hs]

theorem conversion_unique (p : Particle) (a b : ComponentPhases)
    (ha : ConversionSpec height width i p a) (hb : ConversionSpec height width i p b) : a = b := by
  rw [← conversion_complete p a ha,← conversion_complete p b hb]

theorem conversion_total (p : Particle) :
    ∃ r, ConversionSpec height width i p r ∧ ∀ s, ConversionSpec height width i p s → s = r :=
  ⟨_,conversion_sound p,fun _ spec => (conversion_complete p _ spec).symm⟩

theorem water_conversion_uses_latent_heat (p : Particle) :
    (conversionPhase height width i p).water = regime height width i p := rfl

theorem mineral_conversion_uses_both_latent_heats (p : Particle) :
    (conversionPhase height width i p).iron = fusionPhase (ironDiagram p) (thermalEnergy height width i p) ∧
    (conversionPhase height width i p).silica = fusionPhase (silicaDiagram p) (thermalEnergy height width i p) := ⟨rfl,rfl⟩

/-- The display phase follows the complete water energy diagram. A low parcel
    mass or a trace of vapor cannot turn remaining liquid into a gas label. -/
def aqueousMaterial (p : Particle) (r : WaterRegime) : Material :=
  match r with
  | .ice | .melting => .ice
  | .vapor => .steam
  | _ => if p.matter.acid > 0 then .acid else if p.matter.salt > 0 then .saltWater else .water

theorem aqueous_material_is_vapor_iff (p : Particle) (r : WaterRegime) :
    aqueousMaterial p r = .steam ↔ r = .vapor := by
  by_cases acid : p.matter.acid > 0 <;> by_cases salt : p.matter.salt > 0 <;>
    cases r <;> simp [aqueousMaterial,acid,salt]

def labelAt (height width i : Nat) (p : Particle) : Material :=
  if p.luminous > 0 then .fire
  else if p.matter.water*18 > p.mass/2 then
    aqueousMaterial p (conversionPhase height width i p).water
  else if p.matter.iron*56 > p.mass/2 then
    if fusionPhase (ironDiagram p) (thermalEnergy height width i p) == .liquid then .moltenIron else .metal
  else if p.matter.silica*60 > p.mass/2 then
    if fusionPhase (silicaDiagram p) (thermalEnergy height width i p) == .liquid then .lava
    else if p.label == .lava then .glass else if p.fractured || p.label == .sand then .sand
    else if p.label == .ash then .ash else if p.label == .glass then .glass
    else if p.label == .obsidian then .obsidian else .stone
  else if p.matter.biomass*30 > p.mass/2 then
    if p.label == .plant then .plant else .wood
  else if p.matter.oil*14 > p.mass/2 then .oil
  else if p.matter.nitrate*101 > p.mass/3 then
    if p.matter.sulfur > 0 && p.matter.carbon > 0 then .gunpowder else .nitrate
  else if p.matter.salt*58 > p.mass/2 then .salt
  else if p.matter.carbonate*100 > p.mass/2 then .limestone
  else if p.matter.rust*160 > p.mass/2 then .rust
  else if p.matter.ironChloride*126 > p.mass/2 then .ironChloride
  else if p.matter.calciumChloride*110 > p.mass/2 then .calciumChloride
  else if p.matter.sulfur*32 > p.mass/2 then .sulfur
  else if p.matter.carbon*12 > p.mass/2 then if p.label == .ash then .ash else .charcoal
  else if p.matter.methane > p.matter.oxygen+p.matter.nitrogen+p.matter.carbonDioxide+p.matter.hydrogen+p.matter.carbonMonoxide then .methane
  else if p.matter.carbonMonoxide > p.matter.oxygen+p.matter.nitrogen+p.matter.carbonDioxide+p.matter.hydrogen+p.matter.methane then .carbonMonoxide
  else if p.matter.carbonDioxide > p.matter.oxygen+p.matter.nitrogen+p.matter.hydrogen then .carbonDioxide
  else if p.matter.hydrogen > p.matter.oxygen+p.matter.nitrogen then .hydrogen
  else if p.matter.oxygen > p.matter.nitrogen then .oxygen
  else if p.label == .nitrogen && p.matter.nitrogen > p.matter.oxygen then .nitrogen
  else if p.matter.carbonDioxide > 4000 then .smoke
  else if p.matter.water > 4000 && vaporWaterMoles height width i p > 0 then
    aqueousMaterial p (conversionPhase height width i p).water
  else .empty


private theorem material_ite_eq (c : Prop) [Decidable c] (a b target : Material) :
    (if c then a else b) = target ↔ (c ∧ a = target) ∨ (¬c ∧ b = target) := by
  by_cases chosen : c <;> simp [chosen]

theorem steam_label_requires_vapor_phase (p : Particle)
    (tagged : labelAt height width i p = .steam) : regime height width i p = .vapor := by
  apply Classical.byContradiction
  intro notVapor
  have nonAqueous : aqueousMaterial p (conversionPhase height width i p).water ≠ .steam := by
    intro same
    exact notVapor ((aqueous_material_is_vapor_iff _ _).mp same)
  simp only [labelAt,material_ite_eq,nonAqueous,reduceCtorEq,and_false,or_false] at tagged

/-- Every parcel called water vapor has spent its complete water latent budget.
    This applies to the actual classifier, including dilute and tiny parcels. -/
theorem steam_label_has_no_remaining_liquid_water (p : Particle)
    (tagged : labelAt height width i p = .steam) :
    vaporWaterMoles height width i p = p.matter.water := by
  have spec := phase_sound (waterDiagram p) (thermalEnergy height width i p)
  change Equilibrium (waterDiagram p) (thermalEnergy height width i p) (regime height width i p) at spec
  rw [steam_label_requires_vapor_phase p tagged] at spec
  cases spec with
  | gas hot =>
    rw [vapor_read_fastpath_matches_complete_phase]
    unfold vaporWaterFromEnthalpy
    split
    · rename_i dry
      simp only [beq_iff_eq] at dry
      exact dry.symm
    · simpa only [phase_fraction_fast_matches_reference] using
        phase_fraction_complete_above_finish p.matter.water (waterDiagram p).boilStart
          (waterDiagram p).boilEnd (thermalEnergy height width i p) hot

/-- Phase normalization changes the observable phase/morphology tag, never the
    molecular inventory, momentum or any component of the energy budget. -/
def normalizeEdit (height width i : Nat) (p : Particle) : SingleEdit p :=
  ⟨{p with label := labelAt height width i p,luminous := p.luminous-1},rfl,rfl⟩

theorem phase_conversion_preserves_every_molecule (p : Particle) :
    (normalizeEdit height width i p).after.matter = p.matter := rfl

theorem phase_conversion_preserves_total_energy (p : Particle) :
    (normalizeEdit height width i p).after.energy = p.energy := rfl

theorem phase_conversion_preserves_momentum (p : Particle) :
    (normalizeEdit height width i p).after.px = p.px ∧
    (normalizeEdit height width i p).after.py = p.py := ⟨rfl,rfl⟩

end Sand2
