import Sand2.Mixture

namespace Sand2.Chemistry

def takeFrom (a needed : Mixture) : Mixture := {
  water := min a.water needed.water
  oxygen := min a.oxygen needed.oxygen
  nitrogen := min a.nitrogen needed.nitrogen
  carbonDioxide := min a.carbonDioxide needed.carbonDioxide
  biomass := min a.biomass needed.biomass
  oil := min a.oil needed.oil
  carbon := min a.carbon needed.carbon
  silica := min a.silica needed.silica
  salt := min a.salt needed.salt
  acid := min a.acid needed.acid
  carbonate := min a.carbonate needed.carbonate
  calciumChloride := min a.calciumChloride needed.calciumChloride
  iron := min a.iron needed.iron
  rust := min a.rust needed.rust
  ironChloride := min a.ironChloride needed.ironChloride
  hydrogen := min a.hydrogen needed.hydrogen
  nitrate := min a.nitrate needed.nitrate
  sulfur := min a.sulfur needed.sulfur
  sulfide := min a.sulfide needed.sulfide
}

def reactantInventory (r : Reaction) (q : Nat) : Mixture := match r with
  | .burnBiomass => {biomass := 1*q, oxygen := 1*q}
  | .burnOil => {oil := 2*q, oxygen := 3*q}
  | .burnCarbon => {carbon := 1*q, oxygen := 1*q}
  | .burnHydrogen => {hydrogen := 2*q, oxygen := 1*q}
  | .rustIron => {iron := 4*q, oxygen := 3*q}
  | .dissolveCarbonate => {carbonate := 1*q, acid := 2*q}
  | .dissolveIron => {iron := 1*q, acid := 2*q}
  | .gunpowder => {nitrate := 2*q, sulfur := 1*q, carbon := 3*q}

def productInventory (r : Reaction) (q : Nat) : Mixture := match r with
  | .burnBiomass => {carbonDioxide := 1*q, water := 1*q}
  | .burnOil => {carbonDioxide := 2*q, water := 2*q}
  | .burnCarbon => {carbonDioxide := 1*q}
  | .burnHydrogen => {water := 2*q}
  | .rustIron => {rust := 2*q}
  | .dissolveCarbonate => {calciumChloride := 1*q, water := 1*q, carbonDioxide := 1*q}
  | .dissolveIron => {ironChloride := 1*q, hydrogen := 1*q}
  | .gunpowder => {sulfide := 1*q, nitrogen := 1*q, carbonDioxide := 3*q}

/-- A contact reaction consumes only the required molecules from each side.
    Unreacted material stays in place. Products appear at the contact side b;
    later transport separates gas, liquid and solid products physically. -/
def reactPair (r : Reaction) (a b : Mixture) (q : Nat) : Mixture × Mixture :=
  if permitted r (add a b) q then
    let required := reactantInventory r q
    let takenA := takeFrom a required
    (sub a takenA, add (sub b (sub required takenA)) (productInventory r q))
  else (a,b)

set_option maxHeartbeats 2000000 in
theorem pair_reaction_matches_stoichiometry (r : Reaction) (a b : Mixture) (q : Nat) :
    add (reactPair r a b q).1 (reactPair r a b q).2 = react r (add a b) q := by
  unfold reactPair react
  by_cases available : permitted r (add a b) q
  · simp only [available,↓reduceIte]
    cases r with
    | burnBiomass =>
      simp only [permitted,add] at available
      apply Mixture.ext <;>
        dsimp [add,sub,takeFrom,reactantInventory,productInventory,products] <;> omega
    | burnOil =>
      simp only [permitted,add] at available
      apply Mixture.ext <;>
        dsimp [add,sub,takeFrom,reactantInventory,productInventory,products] <;> omega
    | burnCarbon =>
      simp only [permitted,add] at available
      apply Mixture.ext <;>
        dsimp [add,sub,takeFrom,reactantInventory,productInventory,products] <;> omega
    | burnHydrogen =>
      simp only [permitted,add] at available
      apply Mixture.ext <;>
        dsimp [add,sub,takeFrom,reactantInventory,productInventory,products] <;> omega
    | rustIron =>
      simp only [permitted,add] at available
      apply Mixture.ext <;>
        dsimp [add,sub,takeFrom,reactantInventory,productInventory,products] <;> omega
    | dissolveCarbonate =>
      simp only [permitted,add] at available
      apply Mixture.ext <;>
        dsimp [add,sub,takeFrom,reactantInventory,productInventory,products] <;> omega
    | dissolveIron =>
      simp only [permitted,add] at available
      apply Mixture.ext <;>
        dsimp [add,sub,takeFrom,reactantInventory,productInventory,products] <;> omega
    | gunpowder =>
      simp only [permitted,add] at available
      apply Mixture.ext <;>
        dsimp [add,sub,takeFrom,reactantInventory,productInventory,products] <;> omega
  · simp only [available,↓reduceIte]

theorem pair_reaction_conserves_every_element (r : Reaction) (a b : Mixture) (q : Nat) :
    atoms (add (reactPair r a b q).1 (reactPair r a b q).2) = atoms (add a b) := by
  rw [pair_reaction_matches_stoichiometry,reactions_conserve_every_element]

theorem pair_reaction_conserves_mass (r : Reaction) (a b : Mixture) (q : Nat) :
    mass (reactPair r a b q).1+mass (reactPair r a b q).2 = mass a+mass b := by
  rw [← mixture_add_mass,pair_reaction_matches_stoichiometry,reactions_conserve_mass,mixture_add_mass]

theorem pair_reaction_atoms_certificate (r : Reaction) (a b : Mixture) (q : Nat) :
    atomAdd (atoms (reactPair r a b q).1) (atoms (reactPair r a b q).2) = atomAdd (atoms a) (atoms b) := by
  rw [← mixture_add_atoms, pair_reaction_conserves_every_element,mixture_add_atoms]

theorem pair_reaction_requires_available_reactants (r : Reaction) (a b : Mixture) (q : Nat)
    (no : ¬permitted r (add a b) q) : reactPair r a b q = (a,b) := by simp [reactPair,no]

end Sand2.Chemistry
