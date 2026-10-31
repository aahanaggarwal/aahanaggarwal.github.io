import Sand2.Conservative

namespace Sand2.Chemistry

/-- A transported portion carries an exact molecular partition certificate.
    This common abstraction supports gas diffusion, liquid advection and
    dissolution without separate unproved inventory arithmetic. -/
structure Portion (whole : Mixture) where
  moved : Mixture
  remaining : Mixture
  partition : add remaining moved = whole

theorem mixture_zero_add (m : Mixture) : add {} m = m := by
  apply Mixture.ext <;> simp [add]

theorem mixture_add_zero (m : Mixture) : add m {} = m := by
  apply Mixture.ext <;> simp [add]

theorem gas_partition_recombines (m : Mixture) (d : Nat) (v : Bool) :
    add (sub m (gasPart m d v)) (gasPart m d v) = m := by
  have h := gas_transfer_conserves_molecules m {} d v
  simpa only [transferGas,mixture_zero_add,mixture_add_zero] using h

theorem requested_partition_recombines (m request : Mixture) :
    add (sub m (takeFrom m request)) (takeFrom m request) = m := by
  apply Mixture.ext <;> simp only [add,sub,takeFrom] <;> omega

def requestedPortion (m request : Mixture) : Portion m :=
  ⟨takeFrom m request,sub m (takeFrom m request),requested_partition_recombines m request⟩

def partialGasPortion (m : Mixture) (d availableWater : Nat) : Portion m :=
  requestedPortion m {gasPart m d false with water := availableWater/max 1 d}

def emptyPortion (m : Mixture) : Portion m := ⟨{},m,mixture_add_zero m⟩

theorem transported_water_is_available_water (m : Mixture) (d available : Nat) :
    (partialGasPortion m d available).moved.water = min m.water (available/max 1 d) := rfl

theorem gas_transport_cannot_overdraw_vapor (m : Mixture) (d available : Nat) :
    (partialGasPortion m d available).moved.water <= available := by
  rw [transported_water_is_available_water]
  exact Nat.le_trans (Nat.min_le_right _ _) (Nat.div_le_self _ _)

def gasPortion (m : Mixture) (d : Nat) (v : Bool) : Portion m :=
  ⟨gasPart m d v,sub m (gasPart m d v),gas_partition_recombines m d v⟩

def bulkPortion (m : Mixture) (d : Nat) : Portion m :=
  ⟨part m d,sub m (part m d),partition_recombines m d⟩

def exchangePortions (a b : Mixture) (pa : Portion a) (pb : Portion b) : Mixture × Mixture :=
  (add pa.remaining pb.moved,add pb.remaining pa.moved)

theorem mixture_rearrange (a b c d : Mixture) : add (add a b) (add c d) = add (add a d) (add c b) := by
  apply Mixture.ext <;> simp [add] <;> omega

theorem identical_portions_are_stationary (m : Mixture) (p : Portion m) :
    exchangePortions m m p p = (m,m) := by
  change (add p.remaining p.moved,add p.remaining p.moved) = (m,m)
  rw [p.partition]

theorem portion_exchange_conserves_every_molecule (a b : Mixture) (pa : Portion a) (pb : Portion b) :
    add (exchangePortions a b pa pb).1 (exchangePortions a b pa pb).2 = add a b := by
  unfold exchangePortions
  rw [mixture_rearrange,pa.partition,pb.partition]

theorem portion_exchange_conserves_every_element (a b : Mixture) (pa : Portion a) (pb : Portion b) :
    atomAdd (atoms (exchangePortions a b pa pb).1) (atoms (exchangePortions a b pa pb).2) = atomAdd (atoms a) (atoms b) := by
  rw [← mixture_add_atoms,portion_exchange_conserves_every_molecule,mixture_add_atoms]

theorem portion_exchange_conserves_mass (a b : Mixture) (pa : Portion a) (pb : Portion b) :
    mass (exchangePortions a b pa pb).1+mass (exchangePortions a b pa pb).2 = mass a+mass b := by
  rw [← mixture_add_mass,portion_exchange_conserves_every_molecule,mixture_add_mass]

end Sand2.Chemistry

namespace Sand2
open Chemistry

/-- The energy and momentum of both opposing packets travel together. The
    total remains exact even when packets have unequal composition or mass. -/
def portionEdit (a b : Particle) (pa : Portion a.matter) (pb : Portion b.matter)
    (ea eb xa xb ya yb : Int) : PairEdit a b :=
  let result := exchangePortions a.matter b.matter pa pb
  let outA := replaceMatter a result.1
  let outB := replaceMatter b result.2
  ⟨{outA with energy := a.energy-ea+eb,px := a.px-xa+xb,py := a.py-ya+yb},
   {outB with energy := b.energy-eb+ea,px := b.px-xb+xa,py := b.py-yb+ya},
   portion_exchange_conserves_every_element a.matter b.matter pa pb,by dsimp; omega⟩

theorem portion_exchange_conserves_x_momentum (a b : Particle) (pa : Portion a.matter) (pb : Portion b.matter)
    (ea eb xa xb ya yb : Int) :
    (portionEdit a b pa pb ea eb xa xb ya yb).first.px+
    (portionEdit a b pa pb ea eb xa xb ya yb).second.px = a.px+b.px := by
  dsimp [portionEdit]; omega

theorem portion_exchange_conserves_y_momentum (a b : Particle) (pa : Portion a.matter) (pb : Portion b.matter)
    (ea eb xa xb ya yb : Int) :
    (portionEdit a b pa pb ea eb xa xb ya yb).first.py+
    (portionEdit a b pa pb ea eb xa xb ya yb).second.py = a.py+b.py := by
  dsimp [portionEdit]; omega

end Sand2
