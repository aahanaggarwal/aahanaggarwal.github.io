import Sand2.State
import Sand2.Conservation
import Sand2.PairChemistry

namespace Sand2
open Chemistry Conservation

/-- Every tracked element, plus the system's full energy inventory. -/
inductive Quantity where
  | hydrogen | oxygen | carbon | silicon | sodium | chlorine | calcium
  | iron | potassium | nitrogen | sulfur | energy
  deriving DecidableEq, BEq, Repr

def measure (q : Quantity) (p : Particle) : Int :=
  let a := atoms p.matter
  match q with
  | .hydrogen => a.h | .oxygen => a.o | .carbon => a.c | .silicon => a.si
  | .sodium => a.na | .chlorine => a.cl | .calcium => a.ca | .iron => a.fe
  | .potassium => a.k | .nitrogen => a.n | .sulfur => a.s | .energy => p.energy

def inventory (w : World width height) (q : Quantity) : Int := arrayTotal (measure q) w.cells

def Conserves (before after : World width height) : Prop :=
  ∀ q, inventory after q = inventory before q

structure SingleEdit (before : Particle) where
  after : Particle
  atoms_eq : atoms after.matter = atoms before.matter
  energy_eq : after.energy = before.energy

structure PairEdit (a b : Particle) where
  first : Particle
  second : Particle
  atoms_eq : atomAdd (atoms first.matter) (atoms second.matter) = atomAdd (atoms a.matter) (atoms b.matter)
  energy_eq : first.energy+second.energy = a.energy+b.energy

theorem SingleEdit.measures (e : SingleEdit p) (q : Quantity) : measure q e.after = measure q p := by
  cases q <;> simp only [measure] <;> first | exact e.energy_eq | rw [e.atoms_eq]

theorem PairEdit.measures (e : PairEdit a b) (q : Quantity) :
    measure q e.first+measure q e.second = measure q a+measure q b := by
  cases q with
  | energy => exact e.energy_eq
  | hydrogen => have h := congrArg Atoms.h e.atoms_eq; dsimp [measure,atomAdd] at *; omega
  | oxygen => have h := congrArg Atoms.o e.atoms_eq; dsimp [measure,atomAdd] at *; omega
  | carbon => have h := congrArg Atoms.c e.atoms_eq; dsimp [measure,atomAdd] at *; omega
  | silicon => have h := congrArg Atoms.si e.atoms_eq; dsimp [measure,atomAdd] at *; omega
  | sodium => have h := congrArg Atoms.na e.atoms_eq; dsimp [measure,atomAdd] at *; omega
  | chlorine => have h := congrArg Atoms.cl e.atoms_eq; dsimp [measure,atomAdd] at *; omega
  | calcium => have h := congrArg Atoms.ca e.atoms_eq; dsimp [measure,atomAdd] at *; omega
  | iron => have h := congrArg Atoms.fe e.atoms_eq; dsimp [measure,atomAdd] at *; omega
  | potassium => have h := congrArg Atoms.k e.atoms_eq; dsimp [measure,atomAdd] at *; omega
  | nitrogen => have h := congrArg Atoms.n e.atoms_eq; dsimp [measure,atomAdd] at *; omega
  | sulfur => have h := congrArg Atoms.s e.atoms_eq; dsimp [measure,atomAdd] at *; omega

/-- A physics program carries a proof that its execution preserves all atoms
    and total energy for every input world. Proofs are erased; only run executes.
    This monad intentionally has no unrestricted put/modify operation. -/
structure Physics (width height : Nat) (α : Type) where
  run : World width height → α × World width height
  preserves : ∀ w, Conserves w (run w).2

namespace Physics
variable {width height : Nat}

@[always_inline, inline] def pure (a : α) : Physics width height α := ⟨fun w => (a,w),by intro w q; rfl⟩

@[always_inline, inline] def bind (f : Physics width height α) (g : α → Physics width height β) : Physics width height β where
  run := fun w => let (a,w') := f.run w; (g a).run w'
  preserves := by
    intro w q
    exact ((g (f.run w).1).preserves (f.run w).2 q).trans (f.preserves w q)

@[always_inline, inline] def map (f : α → β) (x : Physics width height α) : Physics width height β where
  run := fun w => let (a,w') := x.run w; (f a,w')
  preserves := x.preserves

@[always_inline] instance : Monad (Physics width height) where
  pure := Physics.pure
  bind := Physics.bind
  map := Physics.map

@[always_inline, inline] def getWorld : Physics width height (World width height) := ⟨fun w => (w,w),by intro w q; rfl⟩

@[always_inline, inline] def getParticle (i : Nat) : Physics width height Particle := do return read (← getWorld) i

@[always_inline, inline] def single (i : Nat) (edit : (p : Particle) → SingleEdit p) : Physics width height Unit where
  run := fun w =>
    if hi : i < w.cells.size then
      let p := w.cells[i]
      ((),write w i (edit p).after)
    else ((),w)
  preserves := by
    intro w q
    dsimp
    split
    · rename_i hi
      exact single_update_conserves (measure q) w.cells i _ hi ((edit w.cells[i]).measures q)
    · rfl

@[always_inline, inline] def pair (i j : Nat) (edit : (a b : Particle) → PairEdit a b) : Physics width height Unit where
  run := fun w =>
    if hi : i < w.cells.size then
      if hj : j < w.cells.size then
        if i == j then ((),w) else
          let e := edit w.cells[i] w.cells[j]
          let cells := (w.cells.set! i e.first).set! j e.second
          ((),{w with cells, size_eq := by simpa [cells] using w.size_eq})
      else ((),w)
    else ((),w)
  preserves := by
    intro w q
    dsimp
    split
    · rename_i hi
      split
      · rename_i hj
        split
        · rfl
        · rename_i ne
          have distinct : i ≠ j := by simpa using ne
          exact pair_update_conserves (measure q) w.cells i j _ _ hi hj distinct ((edit w.cells[i] w.cells[j]).measures q)
      · rfl
    · rfl

@[always_inline, inline] def metadata (f : World width height → World width height)
    (unchanged : ∀ w, (f w).cells = w.cells) : Physics width height Unit :=
  ⟨fun w => ((),f w),by intro w q; simp [inventory,unchanged]⟩

/-- Accept a complete conservative candidate atomically. Numerical guards
    cannot drop one face of an otherwise simultaneous liquid flux plan. -/
@[always_inline, inline] def transaction (program : Physics width height Unit)
    (accept : World width height → World width height → Bool) : Physics width height Bool where
  run := fun w =>
    let candidate := (program.run w).2
    if accept w candidate then (true,candidate) else (false,w)
  preserves := by
    intro w q
    dsimp
    split
    · exact program.preserves w q
    · rfl

/-- These ghost certificates compose through arbitrary loops, so every complete
    timestep built in Physics inherits the global conservation theorem. -/
theorem execution_conserves (program : Physics width height α) (w : World width height) :
    Conserves w (program.run w).2 := program.preserves w

theorem composition_conserves (a : Physics width height α) (b : α → Physics width height β)
    (w : World width height) : Conserves w ((a >>= b).run w).2 := (a >>= b).preserves w

/-- Execute the state function inside the recursive loop. A generic monadic
    continuation loop grows the Wasm call stack; this tail-recursive form does
    not, and carries precisely the same conservation certificate. -/
@[specialize] def runList (f : α → β → Physics width height (ForInStep β)) :
    List α → β → World width height → β × World width height
  | [],acc,w => (acc,w)
  | a::rest,acc,w =>
    let (step,w') := (f a acc).run w
    match step with
    | .done result => (result,w')
    | .yield result => runList f rest result w'

theorem runList_conserves (f : α → β → Physics width height (ForInStep β))
    (xs : List α) (acc : β) (w : World width height) :
    Conserves w (runList f xs acc w).2 := by
  induction xs generalizing acc w with
  | nil => intro q; rfl
  | cons a rest ih =>
    have conserved := (f a acc).preserves w
    cases result : (f a acc).run w with
    | mk step w' =>
      have hw : Conserves w w' := by simpa only [result] using conserved
      cases step with
      | done value => simpa only [runList,result] using hw
      | yield value =>
        intro q
        simpa only [runList,result] using (ih value w' q).trans (hw q)

@[always_inline, inline] def forList (xs : List α) (init : β)
    (f : α → β → Physics width height (ForInStep β)) : Physics width height β :=
  ⟨runList f xs init,runList_conserves f xs init⟩

@[always_inline] instance (priority := 2000) : ForIn (Physics width height) (List α) α where
  forIn := forList

@[specialize] def runRange (f : Nat → β → Physics width height (ForInStep β)) :
    Nat → Nat → Nat → β → World width height → β × World width height
  | 0,_,_,acc,w => (acc,w)
  | n+1,i,stride,acc,w =>
    let (step,w') := (f i acc).run w
    match step with
    | .done result => (result,w')
    | .yield result => runRange f n (i+stride) stride result w'

theorem runRange_conserves (f : Nat → β → Physics width height (ForInStep β))
    (n i stride : Nat) (acc : β) (w : World width height) :
    Conserves w (runRange f n i stride acc w).2 := by
  induction n generalizing i acc w with
  | zero => intro q; rfl
  | succ n ih =>
    have conserved := (f i acc).preserves w
    cases result : (f i acc).run w with
    | mk step w' =>
      have hw : Conserves w w' := by simpa only [result] using conserved
      cases step with
      | done value => simpa only [runRange,result] using hw
      | yield value =>
        intro q
        simpa only [runRange,result] using (ih (i+stride) value w' q).trans (hw q)

/-- Loop fusion is behavior-preserving for every body and initial world, not
    merely the finite collection of differential-test scenes. -/
theorem range_loop_matches_list_loop (f : Nat → β → Physics width height (ForInStep β))
    (n i stride : Nat) (acc : β) (w : World width height) :
    runRange f n i stride acc w = runList f (List.range' i n stride) acc w := by
  induction n generalizing i acc w with
  | zero => simp [runRange,runList]
  | succ n ih =>
    cases result : (f i acc).run w with
    | mk step w' =>
      cases step with
      | done value => simp only [runRange,List.range'_succ,runList,result]
      | yield value => simpa only [runRange,List.range'_succ,runList,result] using ih (i+stride) value w'

@[always_inline] instance (priority := 2000) : ForIn (Physics width height) Std.Legacy.Range Nat where
  forIn range init f := ⟨runRange f range.size range.start range.step init,
    runRange_conserves f range.size range.start range.step init⟩

end Physics

/-- Proved single-cell chemical edit. The formation-energy change automatically
    appears as thermal energy; the complete energy budget is not rewritten. -/
def reactionEdit (p : Particle) (r : Chemistry.Reaction) (amount : Nat) : SingleEdit p :=
  ⟨replaceMatter p (Chemistry.react r p.matter amount),
   Chemistry.reactions_conserve_every_element r p.matter amount,rfl⟩

/-- Proved real contact reaction, preserving all eleven elements and energy. -/
def contactEdit (a b : Particle) (r : Chemistry.Reaction) (amount : Nat) : PairEdit a b :=
  let result := Chemistry.reactPair r a.matter b.matter amount
  let pa := replaceMatter a result.1
  let pb := replaceMatter b result.2
  let retainedEnergy := pa.chemical+(a.energy-a.chemical)*(pa.mass : Int)/max 1 a.mass
  let transferredEnergy := a.energy-retainedEnergy
  let retainedX := a.px*(pa.mass : Int)/max 1 a.mass
  let retainedY := a.py*(pa.mass : Int)/max 1 a.mass
  ⟨{pa with energy := retainedEnergy,px := retainedX,py := retainedY},
   {pb with energy := b.energy+transferredEnergy,px := b.px+a.px-retainedX,py := b.py+a.py-retainedY},
   Chemistry.pair_reaction_atoms_certificate r a.matter b.matter amount,by dsimp; omega⟩

def heatEdit (a b : Particle) (flux : Int) : PairEdit a b :=
  ⟨{a with energy := a.energy-flux},{b with energy := b.energy+flux},rfl,by dsimp; omega⟩

def impulseEdit (a b : Particle) (ix iy : Int) : PairEdit a b :=
  ⟨(exchangeImpulse a b ix iy).1,(exchangeImpulse a b ix iy).2,rfl,rfl⟩

def swapEdit (a b : Particle) (stamp : Nat) : PairEdit a b :=
  ⟨{b with stamp},{a with stamp},by apply Atoms.ext <;> simp [atomAdd] <;> omega,by dsimp; omega⟩

def transportEdit (a b : Particle) (divisor : Nat) (vapor : Bool) (energy momentumX momentumY : Int) : PairEdit a b :=
  let result := transferGas a.matter b.matter divisor vapor
  let pa := replaceMatter a result.1
  let pb := replaceMatter b result.2
  ⟨{pa with energy := a.energy-energy,px := a.px-momentumX,py := a.py-momentumY},
   {pb with energy := b.energy+energy,px := b.px+momentumX,py := b.py+momentumY},
   by
     change atomAdd (atoms (transferGas a.matter b.matter divisor vapor).1) (atoms (transferGas a.matter b.matter divisor vapor).2) = _
     rw [← mixture_add_atoms,gas_transfer_conserves_every_element,mixture_add_atoms],by dsimp; omega⟩

end Sand2
