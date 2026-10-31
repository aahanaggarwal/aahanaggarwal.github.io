import Sand2.Conservative

namespace Sand2

def unchangedSingle (p : Particle) : SingleEdit p := ⟨p,rfl,rfl⟩
def unchangedPair (a b : Particle) : PairEdit a b := ⟨a,b,rfl,rfl⟩

/-- Reject an inadmissible candidate as a whole, retaining its original matter
    and energy. Clipping the temperature would introduce an energy source. -/
def safePair (height width i j : Nat) (a b : Particle) (e : PairEdit a b) : PairEdit a b :=
  if temperature height width i e.first >= -27315 ∧ temperature height width j e.second >= -27315
  then e else unchangedPair a b

def safeSingle (height width i : Nat) (p : Particle) (e : SingleEdit p) : SingleEdit p :=
  if temperature height width i e.after >= -27315 then e else unchangedSingle p

theorem safe_pair_preserves_kelvin_admissibility (a b : Particle) (e : PairEdit a b)
    (ha : temperature height width i a >= -27315) (hb : temperature height width j b >= -27315) :
    temperature height width i (safePair height width i j a b e).first >= -27315 ∧
    temperature height width j (safePair height width i j a b e).second >= -27315 := by
  by_cases h : temperature height width i e.first >= -27315 ∧ temperature height width j e.second >= -27315
  · have same : safePair height width i j a b e = e := by unfold safePair; exact ite_eq_left h
    rw [same]
    exact h
  · have same : safePair height width i j a b e = unchangedPair a b := by unfold safePair; exact ite_eq_right h
    rw [same]
    exact ⟨ha,hb⟩

theorem safe_single_preserves_kelvin_admissibility (p : Particle) (e : SingleEdit p)
    (valid : temperature height width i p >= -27315) :
    temperature height width i (safeSingle height width i p e).after >= -27315 := by
  by_cases h : temperature height width i e.after >= -27315
  · have same : safeSingle height width i p e = e := by unfold safeSingle; exact ite_eq_left h
    rw [same]
    exact h
  · have same : safeSingle height width i p e = unchangedSingle p := by unfold safeSingle; exact ite_eq_right h
    rw [same]
    exact valid

end Sand2
