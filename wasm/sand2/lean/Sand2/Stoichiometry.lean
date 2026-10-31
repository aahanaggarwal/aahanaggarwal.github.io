import Sand2.PairChemistry
namespace Sand2.Chemistry

theorem mixture_add_right_cancellation (a b c : Mixture) (same : add a c = add b c) : a = b := by
  cases a
  cases b
  cases c
  simp_all [add]

/-- Independent equations specify the complete output of every declared reaction;
    they do not call the executable products function. -/
inductive ReactionSpec (r : Reaction) (before : Mixture) (q : Nat) : Mixture → Prop
  | occurs {after : Mixture} (available : permitted r before q)
      (equations : add after (reactantInventory r q) = add before (productInventory r q)) :
      ReactionSpec r before q after
  | blocked (unavailable : ¬permitted r before q) : ReactionSpec r before q before

theorem reaction_obeys_stoichiometric_equations (r : Reaction) (m : Mixture) (q : Nat)
    (available : permitted r m q) :
    add (react r m q) (reactantInventory r q) = add m (productInventory r q) := by
  simp only [react,available,↓reduceIte]
  cases r <;> apply Mixture.ext <;>
    simp_all [permitted,products,add,reactantInventory,productInventory] <;> omega

theorem reaction_sound (r : Reaction) (m : Mixture) (q : Nat) :
    ReactionSpec r m q (react r m q) := by
  by_cases available : permitted r m q
  · exact .occurs available (reaction_obeys_stoichiometric_equations r m q available)
  · simpa only [react,available,↓reduceIte] using ReactionSpec.blocked available

theorem reaction_complete (r : Reaction) (m out : Mixture) (q : Nat)
    (spec : ReactionSpec r m q out) : react r m q = out := by
  cases spec with
  | occurs available equations =>
    exact mixture_add_right_cancellation _ _ _
      ((reaction_obeys_stoichiometric_equations r m q available).trans equations.symm)
  | blocked unavailable => simp [react,unavailable]

theorem reaction_unique (r : Reaction) (m a b : Mixture) (q : Nat)
    (ha : ReactionSpec r m q a) (hb : ReactionSpec r m q b) : a = b := by
  rw [← reaction_complete r m a q ha,← reaction_complete r m b q hb]

theorem reaction_total (r : Reaction) (m : Mixture) (q : Nat) :
    ∃ out, ReactionSpec r m q out ∧ ∀ other, ReactionSpec r m q other → other = out :=
  ⟨_,reaction_sound r m q,fun _ spec => (reaction_complete r m _ q spec).symm⟩

theorem stoichiometric_tables_balance_every_element (r : Reaction) (q : Nat) :
    atoms (reactantInventory r q) = atoms (productInventory r q) := by
  cases r <;> apply Atoms.ext <;> simp [atoms,reactantInventory,productInventory] <;> omega

theorem chemical_energy_additive (a b : Mixture) :
    chemicalEnergy (add a b) = chemicalEnergy a+chemicalEnergy b := by
  simp [chemicalEnergy,dryGasMoles,add,Int.natCast_add]
  omega

theorem reaction_chemical_energy_equation (r : Reaction) (m : Mixture) (q : Nat)
    (available : permitted r m q) :
    chemicalEnergy (react r m q)+chemicalEnergy (reactantInventory r q) =
      chemicalEnergy m+chemicalEnergy (productInventory r q) := by
  have balance := congrArg chemicalEnergy (reaction_obeys_stoichiometric_equations r m q available)
  simpa only [chemical_energy_additive] using balance

theorem contact_conversion_follows_independent_spec (r : Reaction) (a b : Mixture) (q : Nat) :
    ReactionSpec r (add a b) q (add (reactPair r a b q).1 (reactPair r a b q).2) := by
  rw [pair_reaction_matches_stoichiometry]
  exact reaction_sound _ _ _

theorem complete_methane_preserves_vapor_phase_mole_count (m : Mixture) (q : Nat)
    (available : permitted .burnMethane m q) :
    gasMoles (react .burnMethane m q) true = gasMoles m true := by
  simp only [react,available,↓reduceIte]
  dsimp [gasMoles,dryGasMoles,products]
  dsimp [permitted] at available
  omega

theorem oxygen_poor_methane_increases_vapor_moles (m : Mixture) (q : Nat)
    (available : permitted .partialMethane m q) :
    gasMoles (react .partialMethane m q) true = gasMoles m true+q := by
  simp only [react,available,↓reduceIte]
  dsimp [gasMoles,dryGasMoles,products]
  dsimp [permitted] at available
  omega

theorem co_oxidation_reduces_gas_moles (m : Mixture) (q : Nat)
    (available : permitted .burnCarbonMonoxide m q) :
    dryGasMoles (react .burnCarbonMonoxide m q)+q = dryGasMoles m := by
  simp only [react,available,↓reduceIte]
  dsimp [dryGasMoles,products]
  dsimp [permitted] at available
  omega

theorem methane_combustion_releases_chemical_energy (m : Mixture) (q : Nat)
    (available : permitted .burnMethane m q) (positive : 0 < q) :
    chemicalEnergy (react .burnMethane m q) < chemicalEnergy m := by
  generalize outputDef : chemicalEnergy (react .burnMethane m q) = outputEnergy
  generalize inputDef : chemicalEnergy m = inputEnergy
  have balance := reaction_chemical_energy_equation .burnMethane m q available
  rw [outputDef,inputDef] at balance
  dsimp [chemicalEnergy,dryGasMoles,reactantInventory,productInventory] at balance
  omega

theorem co_oxidation_releases_chemical_energy (m : Mixture) (q : Nat)
    (available : permitted .burnCarbonMonoxide m q) (positive : 0 < q) :
    chemicalEnergy (react .burnCarbonMonoxide m q) < chemicalEnergy m := by
  generalize outputDef : chemicalEnergy (react .burnCarbonMonoxide m q) = outputEnergy
  generalize inputDef : chemicalEnergy m = inputEnergy
  have balance := reaction_chemical_energy_equation .burnCarbonMonoxide m q available
  rw [outputDef,inputDef] at balance
  dsimp [chemicalEnergy,dryGasMoles,reactantInventory,productInventory] at balance
  omega

end Sand2.Chemistry
