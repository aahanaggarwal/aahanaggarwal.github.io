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

def gasPortion (m : Mixture) (d : Nat) (v : Bool) : Portion m :=
  ⟨gasPart m d v,sub m (gasPart m d v),gas_partition_recombines m d v⟩

def bulkPortion (m : Mixture) (d : Nat) : Portion m :=
  ⟨part m d,sub m (part m d),partition_recombines m d⟩

def exchangePortions (a b : Mixture) (pa : Portion a) (pb : Portion b) : Mixture × Mixture :=
  (add pa.remaining pb.moved,add pb.remaining pa.moved)

theorem mixture_rearrange (a b c d : Mixture) : add (add a b) (add c d) = add (add a d) (add c b) := by
  apply Mixture.ext <;> simp [add] <;> omega

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
