/-!
Sand Game 2: the executable local particle physics.
Lungo compiles these definitions to Rust; the Rust host only schedules disjoint
2x2 blocks. Materials match the browser palette. Proofs below concern movement;
chemical reactions intentionally create, transform, and remove particles.
-/
namespace Sand2

@[inline] def pack (a b : UInt32) : UInt32 := (a &&& (255 : UInt32)) ||| ((b &&& (255 : UInt32)) <<< (8 : UInt32))
@[inline] def lo (p : UInt32) : UInt32 := p &&& 255
@[inline] def hi (p : UInt32) : UInt32 := (p >>> 8) &&& 255

@[inline] def fixed (m : UInt32) : Bool :=
  m == 3 || m == 4 || m == 10 || m == 11 || m == 13

@[inline] def fluid (m : UInt32) : Bool := m == 2 || m == 7 || m == 8 || m == 9
@[inline] def gas (m : UInt32) : Bool := m == 5 || m == 6 || m == 12

@[noinline] def density (m : UInt32) : UInt32 :=
  if m == 0 then 1
  else if gas m then 0
  else if m == 1 then 60
  else if m == 2 then 30
  else if m == 7 then 15
  else if m == 8 then 35
  else if m == 9 then 50
  else 100

/-- Gravity swaps a heavier mobile particle with a lighter mobile particle.
    Stationary materials never move, even when a lighter cell lies below them. -/
@[inline] def canSwap (a b : UInt32) : Bool :=
  !fixed a && !fixed b && density a > density b

@[noinline] def settle (a b : UInt32) : UInt32 :=
  if canSwap a b then pack b a else pack a b

@[inline] def flammable (m : UInt32) : Bool := m == 4 || m == 7 || m == 10
@[inline] def hot (m : UInt32) : Bool := m == 5 || m == 9

/-- An oriented pair reaction. The reverse orientation is tried by react. -/
@[noinline] def reaction (a b r : UInt32) : UInt32 :=
  if a == 9 && b == 2 then pack 3 6
  else if a == 5 && b == 2 then pack 12 6
  else if a == 9 && b == 1 && r &&& 7 == 0 then pack 9 13
  else if hot a && b == 11 then pack a 2
  else if hot a && flammable b && r &&& 3 == 0 then pack a 5
  else if a == 8 && (b == 1 || b == 4 || b == 10 || b == 11) && r &&& 7 == 0 then pack 8 0
  else if a == 10 && b == 2 && r &&& 63 == 0 then pack 10 10
  else pack a b

@[noinline] def react (a b r : UInt32) : UInt32 :=
  let p := reaction a b r
  if p != pack a b then p
  else
    let q := reaction b a r
    pack (hi q) (lo q)

@[noinline] def drift (a b r : UInt32) : UInt32 :=
  if r &&& 1 == 0 && ((fluid a || gas a) && b == 0 || (fluid b || gas b) && a == 0)
  then pack b a else pack a b

@[noinline] def decay (m r : UInt32) : UInt32 :=
  if m == 5 && r &&& 15 == 0 then 12
  else if m == 12 && r &&& 31 == 0 then 0
  else if m == 6 && r &&& 127 == 0 then 2
  else m

/-- Update a packed 2x2 block. Alternating disjoint partitions in the host
    prevent conflicting writes between blocks in a substep. -/
def stepBlock (block r : UInt32) : UInt32 := Id.run do
  let mut a := decay (block &&& 255) r
  let mut b := decay ((block >>> 8) &&& 255) (r >>> 4)
  let mut c := decay ((block >>> 16) &&& 255) (r >>> 8)
  let mut d := decay ((block >>> 24) &&& 255) (r >>> 12)
  let ac := react a c r
  a := lo ac; c := hi ac
  let bd := react b d (r >>> 2)
  b := lo bd; d := hi bd
  let ab := react a b (r >>> 4)
  a := lo ab; b := hi ab
  let cd := react c d (r >>> 6)
  c := lo cd; d := hi cd
  let ac := settle a c
  a := lo ac; c := hi ac
  let bd := settle b d
  b := lo bd; d := hi bd
  if r &&& 1 == 0 then
    -- A diagonal move needs an open orthogonal route. Joined stationary
    -- corners are watertight; particles cannot tunnel through their meeting.
    if !fixed b || !fixed c then
      let ad := settle a d
      a := lo ad; d := hi ad
    if !fixed a || !fixed d then
      let bc := settle b c
      b := lo bc; c := hi bc
  let ab := drift a b (r >>> 1)
  a := lo ab; b := hi ab
  let cd := drift c d (r >>> 2)
  c := lo cd; d := hi cd
  return a ||| (b <<< 8) ||| (c <<< 16) ||| (d <<< 24)

/-- Movement only permutes the original pair; it cannot create or lose a grain. -/
theorem settle_conserves (a b : UInt32) :
    settle a b = pack a b ∨ settle a b = pack b a := by
  unfold settle
  split <;> simp

/-- Every stationary material is protected by the movement rule. -/
theorem fixed_never_falls (a b : UInt32) (h : fixed a = true) :
    canSwap a b = false := by
  simp [canSwap, h]

theorem fixed_never_displaced (a b : UInt32) (h : fixed b = true) :
    canSwap a b = false := by
  simp [canSwap, h]

/-- A forbidden movement leaves the entire encoded pair unchanged. -/
theorem blocked_pair_unchanged (a b : UInt32) (h : canSwap a b = false) :
    settle a b = pack a b := by
  simp [settle, h]

end Sand2
