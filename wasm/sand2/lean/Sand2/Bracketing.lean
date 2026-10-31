import Std

namespace Sand2

/-- A numerical interval cannot be reversed. Proof fields erase at extraction. -/
structure Bracket where
  lo : Nat
  hi : Nat
  ordered : lo <= hi

/-- `below mid` means the desired transition lies strictly above mid. -/
def tightenBracket (below : Nat → Bool) (b : Bracket) : Bracket :=
  let mid := b.lo+(b.hi-b.lo)/2
  if same : b.lo = b.hi then b
  else if below mid then
    ⟨mid+1,b.hi,by have h := b.ordered; dsimp [mid]; omega⟩
  else ⟨b.lo,mid,by dsimp [mid]; omega⟩

theorem tightening_stays_inside (below : Nat → Bool) (b : Bracket) :
    b.lo <= (tightenBracket below b).lo ∧ (tightenBracket below b).hi <= b.hi := by
  have h := b.ordered
  unfold tightenBracket
  dsimp only
  split
  · simp
  · split <;> dsimp <;> omega

theorem tightening_halves_width (below : Nat → Bool) (b : Bracket) :
    (tightenBracket below b).hi-(tightenBracket below b).lo <= (b.hi-b.lo)/2 := by
  have h := b.ordered
  unfold tightenBracket
  dsimp only
  split
  · rename_i equal
    simp [equal]
  · split <;> dsimp <;> omega

@[noinline] def refineBracket (below : Nat → Bool) : Nat → Bracket → Bracket
  | 0,b => b
  | n+1,b => refineBracket below n (tightenBracket below b)

theorem refinement_stays_inside (below : Nat → Bool) (n : Nat) (b : Bracket) :
    b.lo <= (refineBracket below n b).lo ∧ (refineBracket below n b).hi <= b.hi := by
  induction n generalizing b with
  | zero => simp [refineBracket]
  | succ n ih =>
    have step := tightening_stays_inside below b
    have next := ih (tightenBracket below b)
    exact ⟨Nat.le_trans step.1 next.1,Nat.le_trans next.2 step.2⟩

theorem refinement_precision (below : Nat → Bool) (n : Nat) (b : Bracket) :
    (refineBracket below n b).hi-(refineBracket below n b).lo <= (b.hi-b.lo)/2^n := by
  induction n generalizing b with
  | zero => simp [refineBracket]
  | succ n ih =>
    have previous := ih (tightenBracket below b)
    have half := tightening_halves_width below b
    have divided := Nat.div_le_div_right (c := 2^n) half
    have combined := Nat.le_trans previous divided
    simpa only [refineBracket,Nat.div_div_eq_div_mul,Nat.pow_succ,Nat.mul_comm] using combined

theorem tightening_retains_threshold (below : Nat → Bool) (b : Bracket) (root : Nat)
    (inside : b.lo <= root ∧ root <= b.hi)
    (threshold : ∀ p, below p = true ↔ p < root) :
    (tightenBracket below b).lo <= root ∧ root <= (tightenBracket below b).hi := by
  have h := b.ordered
  unfold tightenBracket
  dsimp only
  split
  · exact inside
  · split
    · rename_i yes
      have above := (threshold _).mp yes
      dsimp at *
      omega
    · rename_i no
      have notBelow : ¬b.lo+(b.hi-b.lo)/2 < root := by
        intro lt
        exact no ((threshold _).mpr lt)
      dsimp at *
      omega

theorem refinement_retains_threshold (below : Nat → Bool) (n : Nat) (b : Bracket) (root : Nat)
    (inside : b.lo <= root ∧ root <= b.hi)
    (threshold : ∀ p, below p = true ↔ p < root) :
    (refineBracket below n b).lo <= root ∧ root <= (refineBracket below n b).hi := by
  induction n generalizing b with
  | zero => exact inside
  | succ n ih =>
    exact ih (tightenBracket below b) (tightening_retains_threshold below b root inside threshold)

theorem tightening_retains_false_upper (below : Nat → Bool) (b : Bracket)
    (safe : below b.hi = false) : below (tightenBracket below b).hi = false := by
  unfold tightenBracket
  dsimp only
  split
  · exact safe
  · split
    · exact safe
    · rename_i notBelow
      simpa only [Bool.not_eq_true] using notBelow

theorem refinement_retains_false_upper (below : Nat → Bool) (n : Nat) (b : Bracket)
    (safe : below b.hi = false) : below (refineBracket below n b).hi = false := by
  induction n generalizing b with
  | zero => exact safe
  | succ n ih => exact ih (tightenBracket below b) (tightening_retains_false_upper below b safe)


end Sand2
