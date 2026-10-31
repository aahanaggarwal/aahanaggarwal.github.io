import Sand2.Conservative

namespace Sand2
open Chemistry

/-- Every possible cell selects a declared enthalpy diagram. The relational
    equilibrium spec contains disjoint inequalities, not the executable code. -/
def phaseDiagramFor (p : Particle) : PhaseDiagram :=
  if p.matter.water*18 > p.mass/2 then waterDiagram p else solidDiagram p

def conversionPhase (height width i : Nat) (p : Particle) : WaterRegime :=
  phase (phaseDiagramFor p) (thermalEnergy height width i p)

abbrev ConversionSpec (height width i : Nat) (p : Particle) (r : WaterRegime) : Prop :=
  Equilibrium (phaseDiagramFor p) (thermalEnergy height width i p) r

theorem conversion_sound (p : Particle) :
    ConversionSpec height width i p (conversionPhase height width i p) := phase_sound _ _

theorem conversion_complete (p : Particle) (r : WaterRegime)
    (spec : ConversionSpec height width i p r) : conversionPhase height width i p = r :=
  phase_complete _ _ _ spec

theorem conversion_unique (p : Particle) (a b : WaterRegime)
    (ha : ConversionSpec height width i p a) (hb : ConversionSpec height width i p b) : a = b := by
  rw [← conversion_complete p a ha,← conversion_complete p b hb]

theorem conversion_total (p : Particle) :
    ∃ r, ConversionSpec height width i p r ∧ ∀ s, ConversionSpec height width i p s → s = r :=
  ⟨_,conversion_sound p,fun _ spec => (conversion_complete p _ spec).symm⟩

theorem water_conversion_uses_latent_heat (p : Particle)
    (water : p.matter.water*18 > p.mass/2) :
    conversionPhase height width i p = regime height width i p := by
  simp [conversionPhase,phaseDiagramFor,water,regime]

theorem mineral_conversion_uses_latent_heat (p : Particle)
    (mineral : ¬p.matter.water*18 > p.mass/2) :
    conversionPhase height width i p = solidRegime height width i p := by
  simp [conversionPhase,phaseDiagramFor,mineral,solidRegime]

def labelAt (height width i : Nat) (p : Particle) : Material :=
  if p.luminous > 0 then .fire
  else if p.matter.water*18 > p.mass/2 then
    match conversionPhase height width i p with
    | .ice | .melting => .ice
    | .vapor => .steam
    | _ => if p.matter.acid > 0 then .acid else if p.matter.salt > 0 then .saltWater else .water
  else if p.matter.iron*56 > p.mass/2 then .metal
  else if p.matter.silica*60 > p.mass/2 then
    if conversionPhase height width i p == .liquid then .lava
    else if p.label == .lava then .glass else if p.fractured then .sand else p.label
  else if p.matter.biomass*30 > p.mass/2 then
    if p.label == .plant then .plant else .wood
  else if p.matter.oil*14 > p.mass/2 then .oil
  else if p.matter.nitrate*101 > p.mass/3 then .gunpowder
  else if p.matter.salt*58 > p.mass/2 then .salt
  else if p.matter.carbon*12 > p.mass/2 then .ash
  else if p.matter.carbonDioxide > 4000 then .smoke
  else .empty


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
