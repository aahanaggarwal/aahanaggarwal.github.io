import Std

namespace Sand2

/-- The complete closed set of simulation materials. No numeric material tag
    is used inside the physics; untrusted wire IDs are decoded at the edge. -/
inductive Material where
  | empty | sand | water | stone | wood | fire | steam | oil | acid | lava
  | plant | ice | smoke | glass | obsidian | gunpowder | salt | saltWater
  | ember | ash | metal
  | limestone | oxygen | nitrogen | carbonDioxide | hydrogen | charcoal | rust | nitrate | sulfur | calciumChloride | ironChloride | moltenIron | methane | carbonMonoxide
  deriving DecidableEq, BEq, ReflBEq, LawfulBEq, Repr, Inhabited
open Material

def materials : List Material := [.empty,.sand,.water,.stone,.wood,.fire,.steam,
  .oil,.acid,.lava,.plant,.ice,.smoke,.glass,.obsidian,.gunpowder,.salt,.saltWater,
  .ember,.ash,.metal,.limestone,.oxygen,.nitrogen,.carbonDioxide,.hydrogen,.charcoal,.rust,.nitrate,.sulfur,.calciumChloride,.ironChloride,.moltenIron,.methane,.carbonMonoxide]

def materialCode : Material → UInt32
  | .empty => 0 | .sand => 1 | .water => 2 | .stone => 3 | .wood => 4
  | .fire => 5 | .steam => 6 | .oil => 7 | .acid => 8 | .lava => 9
  | .plant => 10 | .ice => 11 | .smoke => 12 | .glass => 13 | .obsidian => 14
  | .gunpowder => 15 | .salt => 16 | .saltWater => 17 | .ember => 18
  | .ash => 19 | .metal => 20
  | .limestone => 21
  | .oxygen => 22
  | .nitrogen => 23
  | .carbonDioxide => 24
  | .hydrogen => 25
  | .charcoal => 26
  | .rust => 27
  | .nitrate => 28
  | .sulfur => 29
  | .calciumChloride => 30
  | .ironChloride => 31
  | .moltenIron => 32
  | .methane => 33
  | .carbonMonoxide => 34

def decodeMaterial (n : UInt32) : Material := match n.toNat with
  | 1 => .sand | 2 => .water | 3 => .stone | 4 => .wood | 5 => .fire
  | 6 => .steam | 7 => .oil | 8 => .acid | 9 => .lava | 10 => .plant
  | 11 => .ice | 12 => .smoke | 13 => .glass | 14 => .obsidian | 15 => .gunpowder
  | 16 => .salt | 17 => .saltWater | 18 => .ember | 19 => .ash | 20 => .metal
  | 21 => .limestone
  | 22 => .oxygen
  | 23 => .nitrogen
  | 24 => .carbonDioxide
  | 25 => .hydrogen
  | 26 => .charcoal
  | 27 => .rust
  | 28 => .nitrate
  | 29 => .sulfur
  | 30 => .calciumChloride
  | 31 => .ironChloride
  | 32 => .moltenIron
  | 33 => .methane
  | 34 => .carbonMonoxide
  | _ => .empty

def materialName : Material → String
  | .empty => "Air" | .sand => "Sand" | .water => "Water" | .stone => "Quartz"
  | .wood => "Wood" | .fire => "Fire" | .steam => "Steam" | .oil => "Oil"
  | .acid => "Acid" | .lava => "Molten silica" | .plant => "Plant fibre" | .ice => "Ice"
  | .smoke => "Smoke" | .glass => "Glass" | .obsidian => "Obsidian"
  | .gunpowder => "Gunpowder" | .salt => "Salt" | .saltWater => "Salt water"
  | .ember => "Ember" | .ash => "Ash" | .metal => "Iron"
  | .limestone => "Limestone"
  | .oxygen => "Oxygen"
  | .nitrogen => "Nitrogen"
  | .carbonDioxide => "Carbon dioxide"
  | .hydrogen => "Hydrogen"
  | .charcoal => "Charcoal"
  | .rust => "Rust"
  | .nitrate => "Potassium nitrate"
  | .sulfur => "Sulfur"
  | .calciumChloride => "Calcium chloride"
  | .ironChloride => "Iron chloride"
  | .moltenIron => "Molten iron"
  | .methane => "Methane"
  | .carbonMonoxide => "Carbon monoxide"

def isPowder : Material → Bool
  | .sand | .gunpowder | .salt | .ash | .charcoal | .rust | .nitrate | .sulfur | .calciumChloride | .ironChloride => true | _ => false

def isLiquid : Material → Bool
  | .water | .oil | .acid | .lava | .saltWater | .moltenIron => true | _ => false

def isGas : Material → Bool
  | .fire | .steam | .smoke | .oxygen | .nitrogen | .carbonDioxide | .hydrogen | .methane | .carbonMonoxide => true | _ => false

def isFixed : Material → Bool
  | .stone | .wood | .plant | .ice | .glass | .obsidian | .ember | .metal | .limestone => true
  | _ => false

def isHot : Material → Bool
  | .fire | .ember | .lava => true | _ => false

def isWater : Material → Bool
  | .water | .saltWater => true | _ => false

def materialColor : Material → UInt32
  | .empty => 0x0a0a0a | .sand => 0xe1bf8a | .water => 0x1860af
  | .stone => 0x767676 | .wood => 0x664628 | .fire => 0xff8c19
  | .steam => 0xb9bec8 | .oil => 0x3a3026 | .acid => 0x82e628
  | .lava => 0xd74b12 | .plant => 0x2aa034 | .ice => 0xa0cdf0
  | .smoke => 0x3a3a3a | .glass => 0xafcdd7 | .obsidian => 0x301648
  | .gunpowder => 0x4e4e58 | .salt => 0xe8e8e6 | .saltWater => 0x26739b
  | .ember => 0xb94616 | .ash => 0x6c6862 | .metal => 0x8a909b
  | .limestone => 0xc1bca9
  | .oxygen => 0x889ec4
  | .nitrogen => 0x777e96
  | .carbonDioxide => 0x79766b
  | .hydrogen => 0xb294ac
  | .charcoal => 0x333330
  | .rust => 0x9a4a24
  | .nitrate => 0xe4dac7
  | .sulfur => 0xe0d648
  | .calciumChloride => 0xc8d2be
  | .ironChloride => 0xa5b275
  | .moltenIron => 0xf1b45a
  | .methane => 0x9cb681
  | .carbonMonoxide => 0x9d7f70

def materialKind (m : Material) : String :=
  if m == .plant then "BIOMASS" else if isPowder m then "POWDER"
  else if isLiquid m then "LIQUID" else if isGas m then "GAS" else "SOLID"

theorem decode_encode (m : Material) : decodeMaterial (materialCode m) = m := by
  cases m <;> decide

theorem material_codes_bounded (m : Material) : (materialCode m).toNat < 35 := by
  cases m <;> decide

theorem nonempty_materials_complete (m : Material) : m ∈ materials := by
  cases m <;> simp [materials]

end Sand2
