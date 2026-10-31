import Std

namespace Sand2.Chemistry

/-- Molecule counts are nonnegative integer quanta. Mixtures can hold products
    and reactants simultaneously; a visible material label is not the matter. -/
structure Mixture where
  water : Nat := 0
  oxygen : Nat := 0
  nitrogen : Nat := 0
  carbonDioxide : Nat := 0
  biomass : Nat := 0
  oil : Nat := 0
  carbon : Nat := 0
  silica : Nat := 0
  salt : Nat := 0
  acid : Nat := 0
  carbonate : Nat := 0
  calciumChloride : Nat := 0
  iron : Nat := 0
  rust : Nat := 0
  ironChloride : Nat := 0
  hydrogen : Nat := 0
  nitrate : Nat := 0
  sulfur : Nat := 0
  sulfide : Nat := 0
  deriving Repr, BEq, Inhabited

structure Atoms where
  h : Nat := 0
  o : Nat := 0
  c : Nat := 0
  si : Nat := 0
  na : Nat := 0
  cl : Nat := 0
  ca : Nat := 0
  fe : Nat := 0
  k : Nat := 0
  n : Nat := 0
  s : Nat := 0
  deriving Repr, BEq

theorem Atoms.ext {a b : Atoms}
    (h_h : a.h = b.h)
    (h_o : a.o = b.o)
    (h_c : a.c = b.c)
    (h_si : a.si = b.si)
    (h_na : a.na = b.na)
    (h_cl : a.cl = b.cl)
    (h_ca : a.ca = b.ca)
    (h_fe : a.fe = b.fe)
    (h_k : a.k = b.k)
    (h_n : a.n = b.n)
    (h_s : a.s = b.s)
    : a = b := by cases a; cases b; simp_all

def atoms (m : Mixture) : Atoms := {
  h := 2*m.water + 2*m.biomass + 2*m.oil + m.acid + 2*m.hydrogen
  o := m.water + 2*m.oxygen + 2*m.carbonDioxide + m.biomass + 2*m.silica + 3*m.carbonate + 3*m.rust + 3*m.nitrate
  c := m.carbonDioxide + m.biomass + m.oil + m.carbon + m.carbonate
  si := m.silica
  na := m.salt
  cl := m.salt + m.acid + 2*m.calciumChloride + 2*m.ironChloride
  ca := m.carbonate + m.calciumChloride
  fe := m.iron + 2*m.rust + m.ironChloride
  k := m.nitrate + 2*m.sulfide
  n := 2*m.nitrogen + m.nitrate
  s := m.sulfur + m.sulfide
}

def mass (m : Mixture) : Nat :=
  let a := atoms m
  a.h+16*a.o+12*a.c+28*a.si+23*a.na+35*a.cl+40*a.ca+56*a.fe+39*a.k+14*a.n+32*a.s

inductive Reaction where
  | burnBiomass | burnOil | burnCarbon | burnHydrogen | rustIron | dissolveCarbonate | dissolveIron | gunpowder
  deriving DecidableEq, BEq, Repr

def permitted (r : Reaction) (m : Mixture) (q : Nat) : Prop := match r with
  | .burnBiomass => 1*q ≤ m.biomass ∧ 1*q ≤ m.oxygen
  | .burnOil => 2*q ≤ m.oil ∧ 3*q ≤ m.oxygen
  | .burnCarbon => 1*q ≤ m.carbon ∧ 1*q ≤ m.oxygen
  | .burnHydrogen => 2*q ≤ m.hydrogen ∧ 1*q ≤ m.oxygen
  | .rustIron => 4*q ≤ m.iron ∧ 3*q ≤ m.oxygen
  | .dissolveCarbonate => 1*q ≤ m.carbonate ∧ 2*q ≤ m.acid
  | .dissolveIron => 1*q ≤ m.iron ∧ 2*q ≤ m.acid
  | .gunpowder => 2*q ≤ m.nitrate ∧ 1*q ≤ m.sulfur ∧ 3*q ≤ m.carbon

instance (r : Reaction) (m : Mixture) (q : Nat) : Decidable (permitted r m q) := by cases r <;> unfold permitted <;> infer_instance

def capacity (r : Reaction) (m : Mixture) : Nat := match r with
  | .burnBiomass => min (m.biomass/1) ((m.oxygen/1))
  | .burnOil => min (m.oil/2) ((m.oxygen/3))
  | .burnCarbon => min (m.carbon/1) ((m.oxygen/1))
  | .burnHydrogen => min (m.hydrogen/2) ((m.oxygen/1))
  | .rustIron => min (m.iron/4) ((m.oxygen/3))
  | .dissolveCarbonate => min (m.carbonate/1) ((m.acid/2))
  | .dissolveIron => min (m.iron/1) ((m.acid/2))
  | .gunpowder => min (m.nitrate/2) (min (m.sulfur/1) ((m.carbon/3)))

/-- Stoichiometric products; evaluated only when reactants are available. -/
def products (r : Reaction) (m : Mixture) (q : Nat) : Mixture := match r with
  | .burnBiomass => {m with biomass := m.biomass-1*q, oxygen := m.oxygen-1*q, carbonDioxide := m.carbonDioxide+1*q, water := m.water+1*q}
  | .burnOil => {m with oil := m.oil-2*q, oxygen := m.oxygen-3*q, carbonDioxide := m.carbonDioxide+2*q, water := m.water+2*q}
  | .burnCarbon => {m with carbon := m.carbon-1*q, oxygen := m.oxygen-1*q, carbonDioxide := m.carbonDioxide+1*q}
  | .burnHydrogen => {m with hydrogen := m.hydrogen-2*q, oxygen := m.oxygen-1*q, water := m.water+2*q}
  | .rustIron => {m with iron := m.iron-4*q, oxygen := m.oxygen-3*q, rust := m.rust+2*q}
  | .dissolveCarbonate => {m with carbonate := m.carbonate-1*q, acid := m.acid-2*q, calciumChloride := m.calciumChloride+1*q, water := m.water+1*q, carbonDioxide := m.carbonDioxide+1*q}
  | .dissolveIron => {m with iron := m.iron-1*q, acid := m.acid-2*q, ironChloride := m.ironChloride+1*q, hydrogen := m.hydrogen+1*q}
  | .gunpowder => {m with nitrate := m.nitrate-2*q, sulfur := m.sulfur-1*q, carbon := m.carbon-3*q, sulfide := m.sulfide+1*q, nitrogen := m.nitrogen+1*q, carbonDioxide := m.carbonDioxide+3*q}

def react (r : Reaction) (m : Mixture) (q : Nat) : Mixture :=
  if permitted r m q then products r m q else m

/-- This theorem checks every declared reaction for arbitrary inventories and
    arbitrary reaction extent, not just a finite collection of examples. -/
theorem reactions_conserve_every_element (r : Reaction) (m : Mixture) (q : Nat) :
    atoms (react r m q) = atoms m := by
  unfold react
  split
  · rename_i available
    cases r <;> apply Atoms.ext <;> simp_all [permitted,products,atoms] <;> omega
  · rfl

theorem reactions_conserve_mass (r : Reaction) (m : Mixture) (q : Nat) :
    mass (react r m q) = mass m := by
  unfold mass
  rw [reactions_conserve_every_element]

theorem extent_iff_available (r : Reaction) (m : Mixture) (q : Nat) :
    permitted r m q ↔ q ≤ capacity r m := by
  cases r <;> simp [permitted,capacity] <;> omega

theorem maximum_extent_valid (r : Reaction) (m : Mixture) : permitted r m (capacity r m) :=
  (extent_iff_available r m _).mpr (by omega)

theorem impossible_reaction_unchanged (r : Reaction) (m : Mixture) (q : Nat)
    (unavailable : ¬permitted r m q) : react r m q = m := by simp [react,unavailable]

theorem excess_extent_rejected (r : Reaction) (m : Mixture) (q : Nat)
    (tooMuch : capacity r m < q) : react r m q = m := by
  apply impossible_reaction_unchanged
  rw [extent_iff_available]
  omega

theorem zero_extent_unchanged (r : Reaction) (m : Mixture) : react r m 0 = m := by
  cases r <;> simp [react,permitted,products]

inductive ReactionSpec (r : Reaction) (before : Mixture) (q : Nat) : Mixture → Prop
  | occurs (available : permitted r before q) : ReactionSpec r before q (products r before q)
  | blocked (unavailable : ¬permitted r before q) : ReactionSpec r before q before

theorem reaction_sound (r : Reaction) (m : Mixture) (q : Nat) : ReactionSpec r m q (react r m q) := by
  unfold react
  split
  · exact .occurs (by assumption)
  · exact .blocked (by assumption)

theorem reaction_complete (r : Reaction) (m out : Mixture) (q : Nat)
    (spec : ReactionSpec r m q out) : react r m q = out := by
  cases spec <;> simp_all [react]

theorem reaction_unique (r : Reaction) (m a b : Mixture) (q : Nat)
    (ha : ReactionSpec r m q a) (hb : ReactionSpec r m q b) : a = b := by
  rw [← reaction_complete r m a q ha, ← reaction_complete r m b q hb]

end Sand2.Chemistry
