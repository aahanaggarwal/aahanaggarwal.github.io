import Sand2.Chemistry

namespace Sand2.Chemistry

theorem Mixture.ext {a b : Mixture}
    (h_water : a.water = b.water)
    (h_oxygen : a.oxygen = b.oxygen)
    (h_nitrogen : a.nitrogen = b.nitrogen)
    (h_carbonDioxide : a.carbonDioxide = b.carbonDioxide)
    (h_biomass : a.biomass = b.biomass)
    (h_oil : a.oil = b.oil)
    (h_carbon : a.carbon = b.carbon)
    (h_silica : a.silica = b.silica)
    (h_salt : a.salt = b.salt)
    (h_acid : a.acid = b.acid)
    (h_carbonate : a.carbonate = b.carbonate)
    (h_calciumChloride : a.calciumChloride = b.calciumChloride)
    (h_iron : a.iron = b.iron)
    (h_rust : a.rust = b.rust)
    (h_ironChloride : a.ironChloride = b.ironChloride)
    (h_hydrogen : a.hydrogen = b.hydrogen)
    (h_nitrate : a.nitrate = b.nitrate)
    (h_sulfur : a.sulfur = b.sulfur)
    (h_sulfide : a.sulfide = b.sulfide)
    : a = b := by cases a; cases b; simp_all

def add (a b : Mixture) : Mixture := {
  water := a.water+b.water
  oxygen := a.oxygen+b.oxygen
  nitrogen := a.nitrogen+b.nitrogen
  carbonDioxide := a.carbonDioxide+b.carbonDioxide
  biomass := a.biomass+b.biomass
  oil := a.oil+b.oil
  carbon := a.carbon+b.carbon
  silica := a.silica+b.silica
  salt := a.salt+b.salt
  acid := a.acid+b.acid
  carbonate := a.carbonate+b.carbonate
  calciumChloride := a.calciumChloride+b.calciumChloride
  iron := a.iron+b.iron
  rust := a.rust+b.rust
  ironChloride := a.ironChloride+b.ironChloride
  hydrogen := a.hydrogen+b.hydrogen
  nitrate := a.nitrate+b.nitrate
  sulfur := a.sulfur+b.sulfur
  sulfide := a.sulfide+b.sulfide
}

def sub (a b : Mixture) : Mixture := {
  water := a.water-b.water
  oxygen := a.oxygen-b.oxygen
  nitrogen := a.nitrogen-b.nitrogen
  carbonDioxide := a.carbonDioxide-b.carbonDioxide
  biomass := a.biomass-b.biomass
  oil := a.oil-b.oil
  carbon := a.carbon-b.carbon
  silica := a.silica-b.silica
  salt := a.salt-b.salt
  acid := a.acid-b.acid
  carbonate := a.carbonate-b.carbonate
  calciumChloride := a.calciumChloride-b.calciumChloride
  iron := a.iron-b.iron
  rust := a.rust-b.rust
  ironChloride := a.ironChloride-b.ironChloride
  hydrogen := a.hydrogen-b.hydrogen
  nitrate := a.nitrate-b.nitrate
  sulfur := a.sulfur-b.sulfur
  sulfide := a.sulfide-b.sulfide
}

def part (m : Mixture) (divisor : Nat) : Mixture := {
  water := m.water/(max 1 divisor)
  oxygen := m.oxygen/(max 1 divisor)
  nitrogen := m.nitrogen/(max 1 divisor)
  carbonDioxide := m.carbonDioxide/(max 1 divisor)
  biomass := m.biomass/(max 1 divisor)
  oil := m.oil/(max 1 divisor)
  carbon := m.carbon/(max 1 divisor)
  silica := m.silica/(max 1 divisor)
  salt := m.salt/(max 1 divisor)
  acid := m.acid/(max 1 divisor)
  carbonate := m.carbonate/(max 1 divisor)
  calciumChloride := m.calciumChloride/(max 1 divisor)
  iron := m.iron/(max 1 divisor)
  rust := m.rust/(max 1 divisor)
  ironChloride := m.ironChloride/(max 1 divisor)
  hydrogen := m.hydrogen/(max 1 divisor)
  nitrate := m.nitrate/(max 1 divisor)
  sulfur := m.sulfur/(max 1 divisor)
  sulfide := m.sulfide/(max 1 divisor)
}

def gasPart (m : Mixture) (divisor : Nat) (vapor : Bool) : Mixture := {
  water := if vapor then m.water/(max 1 divisor) else 0
  oxygen := m.oxygen/(max 1 divisor)
  nitrogen := m.nitrogen/(max 1 divisor)
  carbonDioxide := m.carbonDioxide/(max 1 divisor)
  biomass := 0
  oil := 0
  carbon := 0
  silica := 0
  salt := 0
  acid := 0
  carbonate := 0
  calciumChloride := 0
  iron := 0
  rust := 0
  ironChloride := 0
  hydrogen := m.hydrogen/(max 1 divisor)
  nitrate := 0
  sulfur := 0
  sulfide := 0
}

def atomAdd (a b : Atoms) : Atoms := {
  h := a.h+b.h
  o := a.o+b.o
  c := a.c+b.c
  si := a.si+b.si
  na := a.na+b.na
  cl := a.cl+b.cl
  ca := a.ca+b.ca
  fe := a.fe+b.fe
  k := a.k+b.k
  n := a.n+b.n
  s := a.s+b.s
}

theorem mixture_add_atoms (a b : Mixture) : atoms (add a b) = atomAdd (atoms a) (atoms b) := by
  apply Atoms.ext <;> simp [atoms,add,atomAdd] <;> omega

theorem mixture_add_mass (a b : Mixture) : mass (add a b) = mass a+mass b := by
  simp [mass,atoms,add]
  omega

theorem partition_recombines (m : Mixture) (d : Nat) : add (sub m (part m d)) (part m d) = m := by
  apply Mixture.ext
  · simp only [add,sub,part]; have h := Nat.div_le_self m.water (max 1 d); omega
  · simp only [add,sub,part]; have h := Nat.div_le_self m.oxygen (max 1 d); omega
  · simp only [add,sub,part]; have h := Nat.div_le_self m.nitrogen (max 1 d); omega
  · simp only [add,sub,part]; have h := Nat.div_le_self m.carbonDioxide (max 1 d); omega
  · simp only [add,sub,part]; have h := Nat.div_le_self m.biomass (max 1 d); omega
  · simp only [add,sub,part]; have h := Nat.div_le_self m.oil (max 1 d); omega
  · simp only [add,sub,part]; have h := Nat.div_le_self m.carbon (max 1 d); omega
  · simp only [add,sub,part]; have h := Nat.div_le_self m.silica (max 1 d); omega
  · simp only [add,sub,part]; have h := Nat.div_le_self m.salt (max 1 d); omega
  · simp only [add,sub,part]; have h := Nat.div_le_self m.acid (max 1 d); omega
  · simp only [add,sub,part]; have h := Nat.div_le_self m.carbonate (max 1 d); omega
  · simp only [add,sub,part]; have h := Nat.div_le_self m.calciumChloride (max 1 d); omega
  · simp only [add,sub,part]; have h := Nat.div_le_self m.iron (max 1 d); omega
  · simp only [add,sub,part]; have h := Nat.div_le_self m.rust (max 1 d); omega
  · simp only [add,sub,part]; have h := Nat.div_le_self m.ironChloride (max 1 d); omega
  · simp only [add,sub,part]; have h := Nat.div_le_self m.hydrogen (max 1 d); omega
  · simp only [add,sub,part]; have h := Nat.div_le_self m.nitrate (max 1 d); omega
  · simp only [add,sub,part]; have h := Nat.div_le_self m.sulfur (max 1 d); omega
  · simp only [add,sub,part]; have h := Nat.div_le_self m.sulfide (max 1 d); omega

def transferGas (a b : Mixture) (d : Nat) (vapor : Bool) : Mixture × Mixture :=
  let q := gasPart a d vapor
  (sub a q, add b q)

theorem gas_transfer_conserves_molecules (a b : Mixture) (d : Nat) (v : Bool) :
    add (transferGas a b d v).1 (transferGas a b d v).2 = add a b := by
  apply Mixture.ext
  · simp only [add,sub,gasPart,transferGas]; have h := Nat.div_le_self a.water (max 1 d)
    split <;> omega
  · simp only [add,sub,gasPart,transferGas]; have h := Nat.div_le_self a.oxygen (max 1 d)
    omega
  · simp only [add,sub,gasPart,transferGas]; have h := Nat.div_le_self a.nitrogen (max 1 d)
    omega
  · simp only [add,sub,gasPart,transferGas]; have h := Nat.div_le_self a.carbonDioxide (max 1 d)
    omega
  · simp only [add,sub,gasPart,transferGas]; have h := Nat.div_le_self a.biomass (max 1 d)
    omega
  · simp only [add,sub,gasPart,transferGas]; have h := Nat.div_le_self a.oil (max 1 d)
    omega
  · simp only [add,sub,gasPart,transferGas]; have h := Nat.div_le_self a.carbon (max 1 d)
    omega
  · simp only [add,sub,gasPart,transferGas]; have h := Nat.div_le_self a.silica (max 1 d)
    omega
  · simp only [add,sub,gasPart,transferGas]; have h := Nat.div_le_self a.salt (max 1 d)
    omega
  · simp only [add,sub,gasPart,transferGas]; have h := Nat.div_le_self a.acid (max 1 d)
    omega
  · simp only [add,sub,gasPart,transferGas]; have h := Nat.div_le_self a.carbonate (max 1 d)
    omega
  · simp only [add,sub,gasPart,transferGas]; have h := Nat.div_le_self a.calciumChloride (max 1 d)
    omega
  · simp only [add,sub,gasPart,transferGas]; have h := Nat.div_le_self a.iron (max 1 d)
    omega
  · simp only [add,sub,gasPart,transferGas]; have h := Nat.div_le_self a.rust (max 1 d)
    omega
  · simp only [add,sub,gasPart,transferGas]; have h := Nat.div_le_self a.ironChloride (max 1 d)
    omega
  · simp only [add,sub,gasPart,transferGas]; have h := Nat.div_le_self a.hydrogen (max 1 d)
    omega
  · simp only [add,sub,gasPart,transferGas]; have h := Nat.div_le_self a.nitrate (max 1 d)
    omega
  · simp only [add,sub,gasPart,transferGas]; have h := Nat.div_le_self a.sulfur (max 1 d)
    omega
  · simp only [add,sub,gasPart,transferGas]; have h := Nat.div_le_self a.sulfide (max 1 d)
    omega

theorem gas_transfer_conserves_every_element (a b : Mixture) (d : Nat) (v : Bool) :
    atoms (add (transferGas a b d v).1 (transferGas a b d v).2) = atoms (add a b) := by
  rw [gas_transfer_conserves_molecules]

theorem gas_transfer_conserves_mass (a b : Mixture) (d : Nat) (v : Bool) :
    mass (transferGas a b d v).1+mass (transferGas a b d v).2 = mass a+mass b := by
  rw [← mixture_add_mass,gas_transfer_conserves_molecules,mixture_add_mass]

/-- Rounded formation reference energies (J/mol), with water referred to ice
    at 0 C. Permanent gases include -R*T0 so their cell energy is internal
    energy; phase/sensible energy is added separately. -/
def chemicalEnergy (m : Mixture) : Int :=
  (-291830*(m.water : Int) -393510*m.carbonDioxide -115900*m.biomass -20000*m.oil
   -910900*m.silica -411120*m.salt -167160*m.acid -1206900*m.carbonate
   -877000*m.calciumChloride -824200*m.rust -341800*m.ironChloride
   -494600*m.nitrate -414000*m.sulfide)*100000 -
   8314*27315*((m.oxygen : Int)+m.nitrogen+m.carbonDioxide+m.hydrogen)

def gasMoles (m : Mixture) (vapor : Bool) : Nat :=
  m.oxygen+m.nitrogen+m.carbonDioxide+m.hydrogen+(if vapor then m.water else 0)

end Sand2.Chemistry
