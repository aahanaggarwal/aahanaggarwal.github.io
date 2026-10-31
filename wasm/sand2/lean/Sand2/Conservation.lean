import Std

namespace Sand2.Conservation

def sumMap (f : α → Int) (xs : List α) : Int := (xs.map f).sum

theorem list_replace_sum (f : α → Int) (xs : List α) (i : Nat) (v : α) (hi : i < xs.length) :
    sumMap f (xs.set i v) = sumMap f xs - f xs[i] + f v := by
  induction xs generalizing i with
  | nil => simp at hi
  | cons x xs ih =>
    cases i with
    | zero => simp [sumMap]; omega
    | succ i =>
      have h : i < xs.length := by simpa using hi
      have step := ih i h
      simp only [List.set_cons_succ,List.getElem_cons_succ]
      simp only [sumMap,List.map_cons,List.sum_cons] at step ⊢
      omega

def arrayTotal (f : α → Int) (xs : Array α) : Int := sumMap f xs.toList

theorem array_replace_sum (f : α → Int) (xs : Array α) (i : Nat) (v : α) (hi : i < xs.size) :
    arrayTotal f (xs.set! i v) = arrayTotal f xs - f xs[i] + f v := by
  have step := list_replace_sum f xs.toList i v (by simpa using hi)
  rw [Array.getElem_toList] at step
  simpa only [arrayTotal,Array.toList_set!] using step

theorem single_update_conserves (f : α → Int) (xs : Array α) (i : Nat) (v : α)
    (hi : i < xs.size) (same : f v = f xs[i]) : arrayTotal f (xs.set! i v) = arrayTotal f xs := by
  rw [array_replace_sum f xs i v hi,same]
  omega

theorem pair_update_conserves (f : α → Int) (xs : Array α) (i j : Nat) (a b : α)
    (hi : i < xs.size) (hj : j < xs.size) (distinct : i ≠ j)
    (same : f a+f b = f xs[i]+f xs[j]) :
    arrayTotal f ((xs.set! i a).set! j b) = arrayTotal f xs := by
  have hj' : j < (xs.set! i a).size := by simpa using hj
  rw [array_replace_sum f (xs.set! i a) j b hj',array_replace_sum f xs i a hi]
  have unchanged : (xs.set! i a)[j] = xs[j] := by simp only [Array.set!_eq_setIfInBounds,Array.getElem_setIfInBounds_ne hj distinct]
  rw [unchanged]
  omega

end Sand2.Conservation
