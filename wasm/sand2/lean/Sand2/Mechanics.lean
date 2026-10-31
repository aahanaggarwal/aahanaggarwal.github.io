import Std

namespace Sand2

/-- Each cell is 10,000 micrometres, position uses one million subcell units,
    velocity is micrometres/second and a timestep is exactly 1/600 second. -/
def ticksPerSecond : Nat := 600

def elapsedMilliseconds (steps : Nat) : Nat := steps*1000/ticksPerSecond

theorem elapsed_time_whole_second (steps : Nat) :
    elapsedMilliseconds (steps+ticksPerSecond) = elapsedMilliseconds steps+1000 := by
  dsimp [elapsedMilliseconds,ticksPerSecond]
  omega

def gravityKick : Int := 9810000/(ticksPerSecond : Int)

def terminalSpeed : Int := 3000000

def gravityVelocity (v : Int) : Int := min terminalSpeed (v+gravityKick)

/-- Trapezoidal/velocity-Verlet displacement for the old and new velocities.
    Using only the new velocity adds numerical gravitational heating. -/
def stepDisplacement (before after : Int) : Int := (before+after)/12

theorem displacement_matches_si_units (before after : Int) :
    stepDisplacement before after = (before+after)*1000000/(2*(ticksPerSecond : Int)*10000) := by
  dsimp [stepDisplacement,ticksPerSecond]
  omega

theorem displacement_rounding_bounded (before after : Int) :
    12*stepDisplacement before after <= before+after ∧
    before+after < 12*(stepDisplacement before after+1) := by
  dsimp [stepDisplacement]
  omega

theorem gravity_velocity_bounded (v : Int) : gravityVelocity v <= terminalSpeed := by
  unfold gravityVelocity
  omega

theorem gravity_acceleration_before_terminal (v : Int) (below : v+gravityKick <= terminalSpeed) :
    gravityVelocity v = v+gravityKick := by
  unfold gravityVelocity
  omega

/-- An independent uniform-acceleration reference, without collisions or the
    declared terminal-speed approximation. Used by the free-fall benchmark. -/
def uniformFall : Nat → Int × Int
  | 0 => (0,0)
  | n+1 =>
    let (v,y) := uniformFall n
    let next := v+gravityKick
    (next,y+stepDisplacement v next)

theorem uniform_fall_velocity (n : Nat) : (uniformFall n).1 = (n : Int)*16350 := by
  induction n with
  | zero => rfl
  | succ n ih =>
    change (uniformFall n).1+gravityKick = _
    rw [ih]
    dsimp [gravityKick,ticksPerSecond]
    omega

theorem uniform_fall_distance (n : Nat) :
    2*(uniformFall n).2 = 2725*(n : Int)*(n : Int)-(n : Int) := by
  induction n with
  | zero => rfl
  | succ n ih =>
    change 2*((uniformFall n).2+stepDisplacement (uniformFall n).1 ((uniformFall n).1+gravityKick)) = _
    rw [uniform_fall_velocity]
    have displacement : stepDisplacement ((n : Int)*16350) ((n : Int)*16350+gravityKick) = 2725*(n : Int)+1362 := by
      dsimp [stepDisplacement,gravityKick,ticksPerSecond]
      omega
    rw [displacement]
    simp only [Int.natCast_add,Int.natCast_one,Int.mul_add,Int.add_mul,Int.mul_one,Int.mul_assoc] at *
    omega

theorem elapsed_milliseconds_rounding_bounded (steps : Nat) :
    ticksPerSecond*elapsedMilliseconds steps <= steps*1000 ∧
    steps*1000 < ticksPerSecond*(elapsedMilliseconds steps+1) := by
  dsimp [elapsedMilliseconds,ticksPerSecond]
  omega

end Sand2
