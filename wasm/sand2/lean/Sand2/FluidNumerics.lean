import Std

namespace Sand2

/-- All fluid numerics execute in Lean. Float's basic arithmetic has Lean's
    IEEE-754 logical model; extraction uses corresponding Rust f64 operations.
    Molecular inventories and conserved energy remain exact integers. -/
@[always_inline, inline] def floatNat (n : Nat) : Float := n.toUInt64.toFloat

@[always_inline, inline] def floatInt (n : Int) : Float := if n < 0 then -(floatNat n.natAbs) else floatNat n.toNat

@[always_inline, inline] def floatAbs (x : Float) : Float := if x < 0 then -x else x

@[always_inline, inline] def floatMin (a b : Float) : Float := if a < b then a else b

@[always_inline, inline] def floatMax (a b : Float) : Float := if a < b then b else a

@[always_inline, inline] def finiteClamp (lo hi x : Float) : Float :=
  if x.isNaN || x.isInf then 0 else floatMax lo (floatMin hi x)

@[always_inline, inline] def floatAt (a : FloatArray) (i : Nat) : Float :=
  if h : i < a.size then a.get i h else 0

theorem numerical_read_matches_total_option_read (a : FloatArray) (i : Nat) :
    floatAt a i = (a.get? i).getD 0 := by
  unfold floatAt FloatArray.get?
  split <;> rfl

@[always_inline, inline] def boolAt (a : Array Bool) (i : Nat) : Bool :=
  if h : i < a.size then a[i] else false

theorem numerical_mask_matches_total_option_read (a : Array Bool) (i : Nat) :
    boolAt a i = a[i]?.getD false := by
  simp only [boolAt,getElem?_def]
  split <;> rfl

def floats (n : Nat) (value : Float := 0) : FloatArray := Id.run do
  let mut a := FloatArray.emptyWithCapacity n
  for _ in [:n] do a := a.push value
  return a

def packPressureMask (active right left down up : Bool) : UInt8 :=
  (if active then 1 else 0)+(if right then 2 else 0)+(if left then 4 else 0)+
    (if down then 8 else 0)+(if up then 16 else 0)

theorem pressure_mask_encodes_all_five_flags (a r l d u : Bool) :
    ((packPressureMask a r l d u &&& 1) != 0) = a ∧
    ((packPressureMask a r l d u &&& 2) != 0) = r ∧
    ((packPressureMask a r l d u &&& 4) != 0) = l ∧
    ((packPressureMask a r l d u &&& 8) != 0) = d ∧
    ((packPressureMask a r l d u &&& 16) != 0) = u := by
  cases a <;> cases r <;> cases l <;> cases d <;> cases u <;> decide

@[always_inline, inline] def byteAt (a : ByteArray) (i : Nat) : UInt8 :=
  if h : i < a.size then a[i] else 0

def pressureMaskArray (width height : Nat) (unknown : Array Bool) : ByteArray :=
  ⟨Array.ofFn fun i : Fin (width*height) =>
    packPressureMask (boolAt unknown i)
      (i%width+1 < width && boolAt unknown (i+1))
      (i%width > 0 && boolAt unknown (i-1))
      (i/width+1 < height && boolAt unknown (i+width))
      (i/width > 0 && boolAt unknown (i-width))⟩

/-- Symmetric finite-volume pressure matrix. Right/down coefficients describe
    faces once. Diagonal terms also include Dirichlet free-surface faces.
    Unknown arrays use total reads, including for malformed scratch fields. -/
structure PressureSystem where
  width : Nat
  height : Nat
  unknown : Array Bool
  diagonal : FloatArray
  right : FloatArray
  down : FloatArray
  rhs : FloatArray
  mask : ByteArray := pressureMaskArray width height unknown
  mask_eq : mask = pressureMaskArray width height unknown

@[always_inline, inline] def pressureUnknown (s : PressureSystem) (i : Nat) : Bool := (byteAt s.mask i &&& 1) != 0

@[noinline] def pressureApply (s : PressureSystem) (x : FloatArray) : FloatArray := Id.run do
  let mut out := floats (s.width*s.height)
  for i in [:s.width*s.height] do
    if pressureUnknown s i then
      let mut value := floatAt s.diagonal i*floatAt x i
      if (byteAt s.mask i &&& 2) != 0 then
        value := value-floatAt s.right i*floatAt x (i+1)
      if (byteAt s.mask i &&& 4) != 0 then
        value := value-floatAt s.right (i-1)*floatAt x (i-1)
      if (byteAt s.mask i &&& 8) != 0 then
        value := value-floatAt s.down i*floatAt x (i+s.width)
      if (byteAt s.mask i &&& 16) != 0 then
        value := value-floatAt s.down (i-s.width)*floatAt x (i-s.width)
      out := out.set! i value
  return out

def pressureDot (s : PressureSystem) (a b : FloatArray) : Float := Id.run do
  let mut value := (0 : Float)
  for i in [:s.width*s.height] do
    if pressureUnknown s i then value := value+floatAt a i*floatAt b i
  return value

def pressurePrecondition (s : PressureSystem) (r : FloatArray) : FloatArray := Id.run do
  let mut out := floats (s.width*s.height)
  for i in [:s.width*s.height] do
    if pressureUnknown s i then
      out := out.set! i (floatAt r i/floatMax 0.000000000001 (floatAt s.diagonal i))
  return out

/-- Modified incomplete LDL factorization for the symmetric five-point grid.
    The diagonal fallback keeps the numerical preconditioner positive even when
    cancellation or a difficult material interface spoils an incomplete pivot. -/
@[noinline] def pressureFactors (s : PressureSystem) : FloatArray := Id.run do
  let mut inverse := floats (s.width*s.height)
  for i in [:s.width*s.height] do
    if !pressureUnknown s i then continue
    let original := floatAt s.diagonal i
    let mut pivot := original
    if (byteAt s.mask i &&& 4) != 0 then
      let left := floatAt s.right (i-1)
      let inv := floatAt inverse (i-1)
      let cross := if (byteAt s.mask (i-1) &&& 8) != 0 then floatAt s.down (i-1) else 0
      pivot := pivot-left*left*inv-left*cross*inv
    if (byteAt s.mask i &&& 16) != 0 then
      let up := floatAt s.down (i-s.width)
      let inv := floatAt inverse (i-s.width)
      let cross := if (byteAt s.mask (i-s.width) &&& 2) != 0 then floatAt s.right (i-s.width) else 0
      pivot := pivot-up*up*inv-up*cross*inv
    if pivot < 0.000000000001*original || pivot.isNaN || pivot.isInf then pivot := original
    inverse := inverse.set! i (1/floatMax 0.000000000001 pivot)
  return inverse

@[noinline] def pressureFactorApply (s : PressureSystem) (inverse r : FloatArray) : FloatArray := Id.run do
  let n := s.width*s.height
  let mut result := floats n
  for i in [:n] do
    if !pressureUnknown s i then continue
    let mut value := floatAt r i
    if (byteAt s.mask i &&& 4) != 0 then
      value := value+floatAt s.right (i-1)*floatAt inverse (i-1)*floatAt result (i-1)
    if (byteAt s.mask i &&& 16) != 0 then
      value := value+floatAt s.down (i-s.width)*floatAt inverse (i-s.width)*floatAt result (i-s.width)
    result := result.set! i value
  for k in [:n] do
    let i := n-1-k
    if !pressureUnknown s i then continue
    let mut value := floatAt result i
    if (byteAt s.mask i &&& 2) != 0 then
      value := value+floatAt s.right i*floatAt result (i+1)
    if (byteAt s.mask i &&& 8) != 0 then
      value := value+floatAt s.down i*floatAt result (i+s.width)
    result := result.set! i (value*floatAt inverse i)
  return result

structure PressureSolution where
  values : FloatArray
  iterations : Nat
  residual : Float

/-- Incomplete-factor preconditioned conjugate gradients, with an explicit work limit
    and residual. Accuracy is checked numerically; no convergence claim is made
    for arbitrary floating-point input matrices. -/
@[noinline] def pressureSolve (s : PressureSystem) (limit : Nat := 96)
    (tolerance : Float := 0.0000000001) : PressureSolution := Id.run do
  let n := s.width*s.height
  let mut x := floats n
  let mut r := s.rhs
  let factors := pressureFactors s
  let mut z := pressureFactorApply s factors r
  let mut direction := z
  let mut rz := pressureDot s r z
  let mut iterations := 0
  let mut residual := (0 : Float)
  for i in [:n] do residual := floatMax residual (floatAbs (floatAt r i))
  for k in [:limit] do
    if residual <= tolerance then break
    let q := pressureApply s direction
    let denominator := pressureDot s direction q
    if denominator <= 0.000000000000000000000000000001 then break
    let alpha := rz/denominator
    if alpha.isNaN || alpha.isInf then break
    residual := 0
    for i in [:n] do
      if pressureUnknown s i then
        x := x.set! i (floatAt x i+alpha*floatAt direction i)
        r := r.set! i (floatAt r i-alpha*floatAt q i)
        residual := floatMax residual (floatAbs (floatAt r i))
    iterations := k+1
    if residual <= tolerance then break
    z := pressureFactorApply s factors r
    let next := pressureDot s r z
    let beta := next/rz
    if beta.isNaN || beta.isInf then break
    for i in [:n] do
      if pressureUnknown s i then direction := direction.set! i (floatAt z i+beta*floatAt direction i)
    rz := next
  return ⟨x,iterations,residual⟩

def pressureRhsMagnitude (s : PressureSystem) : Float := Id.run do
  let mut result := (0 : Float)
  for i in [:s.width*s.height] do
    if pressureUnknown s i then result := floatMax result (floatAbs (floatAt s.rhs i))
  return result

@[noinline] def pressureResidual (s : PressureSystem) (x : FloatArray) : Float := Id.run do
  let applied := pressureApply s x
  let mut result := (0 : Float)
  for i in [:s.width*s.height] do
    if pressureUnknown s i then
      result := floatMax result (floatAbs (floatAt applied i-floatAt s.rhs i))
  return result

/-- Complementarity residual for a pressure lower bound. A cell at its bound
    may expand into a void; a cell above it obeys the pressure equation. -/
def pressureComplementarityResidual (s : PressureSystem) (lower x : FloatArray) : Float := Id.run do
  let applied := pressureApply s x
  let mut result := (0 : Float)
  for i in [:s.width*s.height] do
    if pressureUnknown s i then
      let value := floatAt x i
      let gradient := floatAt applied i-floatAt s.rhs i
      let equation := if value <= floatAt lower i+0.00000001 then floatMax 0 (-gradient) else floatAbs gradient
      result := floatMax result (floatMax (floatMax 0 (floatAt lower i-value)) equation)
  return result

/-- Primal-dual active-set pressure solve. Fixing a cavitated cell at its bound
    removes its face couplings from the free system. Releasing a cell uses the sign of
    its pressure-equation gradient. The caller checks the final residual. -/
@[noinline] def boundedPressureSolve (s : PressureSystem) (lower : FloatArray) : PressureSolution := Id.run do
  let n := s.width*s.height
  let tolerance := 0.000000001*floatMax 1 (pressureRhsMagnitude s)
  let mut solution := pressureSolve s 192 tolerance
  let mut totalIterations := solution.iterations
  for _ in [:8] do
    if pressureComplementarityResidual s lower solution.values <= tolerance then break
    let applied := pressureApply s solution.values
    let mut unknown := s.unknown
    for i in [:n] do
      if pressureUnknown s i then
        let gradient := floatAt applied i-floatAt s.rhs i
        if floatAt solution.values i-gradient/floatMax 0.000000000001 (floatAt s.diagonal i) <= floatAt lower i then
          unknown := unknown.set! i false
    let mut right := s.right
    let mut down := s.down
    let mut rhs := s.rhs
    for i in [:n] do
      if !boolAt unknown i then rhs := rhs.set! i 0
      else
        let mut fixed := (0 : Float)
        if i%s.width > 0 && !boolAt unknown (i-1) then fixed := fixed+floatAt s.right (i-1)*floatAt lower (i-1)
        if i%s.width+1 < s.width && !boolAt unknown (i+1) then fixed := fixed+floatAt s.right i*floatAt lower (i+1)
        if i/s.width > 0 && !boolAt unknown (i-s.width) then fixed := fixed+floatAt s.down (i-s.width)*floatAt lower (i-s.width)
        if i/s.width+1 < s.height && !boolAt unknown (i+s.width) then fixed := fixed+floatAt s.down i*floatAt lower (i+s.width)
        rhs := rhs.set! i (floatAt rhs i+fixed)
      if !boolAt unknown i || !boolAt unknown (i+1) then right := right.set! i 0
      if !boolAt unknown i || !boolAt unknown (i+s.width) then down := down.set! i 0
    let free : PressureSystem := {
      width := s.width
      height := s.height
      unknown := unknown
      diagonal := s.diagonal
      right := right
      down := down
      rhs := rhs
      mask_eq := rfl}
    solution := pressureSolve free 192 tolerance
    let mut values := solution.values
    for i in [:n] do
      if pressureUnknown s i && !boolAt unknown i then values := values.set! i (floatAt lower i)
    solution := {solution with values := values}
    totalIterations := totalIterations+solution.iterations
  return {solution with
    iterations := totalIterations
    residual := pressureComplementarityResidual s lower solution.values}

def nonnegativePressureSolve (s : PressureSystem) : PressureSolution :=
  boundedPressureSolve s (floats (s.width*s.height))

end Sand2
