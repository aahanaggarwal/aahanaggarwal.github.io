import Std

namespace Sand2

/-- The type requires every pressure and temperature knot to increase. Bad
    interpolation data cannot construct a curve without a false proof. -/
inductive SaturationCurve : Nat → Nat → Type where
  | stop {p₀ t₀ : Nat} : SaturationCurve p₀ t₀
  | next {p₀ t₀ : Nat} (p₁ t₁ : Nat) (pressure : p₀ < p₁) (temperature : t₀ < t₁)
      (tail : SaturationCurve p₁ t₁) : SaturationCurve p₀ t₀

def interpolateSaturation (p₀ t₀ p₁ t₁ p : Nat) : Nat :=
  t₀+min (t₁-t₀) ((p-p₀)*(t₁-t₀)/max 1 (p₁-p₀))

@[noinline] def curveTemperature (curve : SaturationCurve p₀ t₀) (p : Nat) : Nat :=
  if p <= p₀ then t₀ else
    match curve with
    | .stop => t₀
    | .next p₁ t₁ _ _ tail =>
      if p < p₁ then interpolateSaturation p₀ t₀ p₁ t₁ p else curveTemperature tail p

def lastTemperature : SaturationCurve p₀ t₀ → Nat
  | .stop => t₀
  | .next _ _ _ _ tail => lastTemperature tail

theorem interpolation_within_endpoints (p₀ t₀ p₁ t₁ p : Nat) (ordered : t₀ <= t₁) :
    t₀ <= interpolateSaturation p₀ t₀ p₁ t₁ p ∧ interpolateSaturation p₀ t₀ p₁ t₁ p <= t₁ := by
  constructor
  · exact Nat.le_add_right _ _
  · have bound := Nat.min_le_left (t₁-t₀) ((p-p₀)*(t₁-t₀)/max 1 (p₁-p₀))
    calc
      interpolateSaturation p₀ t₀ p₁ t₁ p <= t₀+(t₁-t₀) := Nat.add_le_add_left bound _
      _ = t₁ := by omega

theorem interpolation_monotone (p₀ t₀ p₁ t₁ p q : Nat) (ordered : p <= q) :
    interpolateSaturation p₀ t₀ p₁ t₁ p <= interpolateSaturation p₀ t₀ p₁ t₁ q := by
  have sub := Nat.sub_le_sub_right ordered p₀
  have mul := Nat.mul_le_mul_right (t₁-t₀) sub
  have divide := Nat.div_le_div_right (c := max 1 (p₁-p₀)) mul
  unfold interpolateSaturation
  omega

theorem curve_temperature_lower_bound (curve : SaturationCurve p₀ t₀) (p : Nat) :
    t₀ <= curveTemperature curve p := by
  induction curve generalizing p with
  | stop => simp [curveTemperature]
  | @next p₀ t₀ p₁ t₁ hp ht tail ih =>
    by_cases lo : p <= p₀
    · simp [curveTemperature,lo]
    · by_cases hi : p < p₁
      · simpa only [curveTemperature,lo,hi,↓reduceIte] using (interpolation_within_endpoints p₀ t₀ p₁ t₁ p (by omega)).1
      · simpa only [curveTemperature,lo,hi,↓reduceIte] using Nat.le_trans (Nat.le_of_lt ht) (ih p)

theorem curve_temperature_upper_bound (curve : SaturationCurve p₀ t₀) (p : Nat) :
    curveTemperature curve p <= lastTemperature curve := by
  induction curve generalizing p with
  | stop => simp [curveTemperature,lastTemperature]
  | @next p₀ t₀ p₁ t₁ hp ht tail ih =>
    have lastBound := Nat.le_trans (curve_temperature_lower_bound tail p) (ih p)
    by_cases lo : p <= p₀
    · simp only [curveTemperature,lastTemperature,lo,↓reduceIte]
      exact Nat.le_trans (Nat.le_of_lt ht) lastBound
    · by_cases hi : p < p₁
      · simp only [curveTemperature,lastTemperature,lo,hi,↓reduceIte]
        exact Nat.le_trans (interpolation_within_endpoints p₀ t₀ p₁ t₁ p (Nat.le_of_lt ht)).2 lastBound
      · simpa only [curveTemperature,lastTemperature,lo,hi,↓reduceIte] using ih p

theorem curve_temperature_monotone (curve : SaturationCurve p₀ t₀) (p q : Nat) (ordered : p <= q) :
    curveTemperature curve p <= curveTemperature curve q := by
  induction curve generalizing p q with
  | stop => simp [curveTemperature]
  | @next p₀ t₀ p₁ t₁ hp ht tail ih =>
    by_cases plo : p <= p₀
    · simpa only [curveTemperature,plo,↓reduceIte] using curve_temperature_lower_bound (.next p₁ t₁ hp ht tail) q
    · have qlo : ¬q <= p₀ := by omega
      simp only [curveTemperature,plo,qlo,↓reduceIte]
      by_cases pi : p < p₁
      · by_cases qi : q < p₁
        · simp only [pi,qi,↓reduceIte]
          exact interpolation_monotone _ _ _ _ _ _ ordered
        · simp only [pi,qi,↓reduceIte]
          exact Nat.le_trans (interpolation_within_endpoints p₀ t₀ p₁ t₁ p (by omega)).2 (curve_temperature_lower_bound tail q)
      · have qi : ¬q < p₁ := by omega
        simp only [pi,qi,↓reduceIte]
        exact ih p q ordered

/-- The same certified knots evaluated at one-millionth of a Celsius degree.
    Fine equilibrium avoids a one-centidegree jump manufacturing large amounts
    of vapor in a nearly full liquid cell. -/
@[noinline] def curveTemperatureFine (curve : SaturationCurve p₀ t₀) (p : Nat) : Nat :=
  if p <= p₀ then t₀*10000 else
    match curve with
    | .stop => t₀*10000
    | .next p₁ t₁ _ _ tail =>
      if p < p₁ then interpolateSaturation p₀ (t₀*10000) p₁ (t₁*10000) p
      else curveTemperatureFine tail p

theorem fine_curve_temperature_lower_bound (curve : SaturationCurve p₀ t₀) (p : Nat) :
    t₀*10000 <= curveTemperatureFine curve p := by
  induction curve generalizing p with
  | stop => simp [curveTemperatureFine]
  | @next p₀ t₀ p₁ t₁ hp ht tail ih =>
    by_cases lo : p <= p₀
    · simp [curveTemperatureFine,lo]
    · by_cases hi : p < p₁
      · simpa only [curveTemperatureFine,lo,hi,↓reduceIte] using
          (interpolation_within_endpoints p₀ (t₀*10000) p₁ (t₁*10000) p (by omega)).1
      · simpa only [curveTemperatureFine,lo,hi,↓reduceIte] using
          Nat.le_trans (show t₀*10000 <= t₁*10000 by omega) (ih p)

theorem fine_curve_temperature_upper_bound (curve : SaturationCurve p₀ t₀) (p : Nat) :
    curveTemperatureFine curve p <= lastTemperature curve*10000 := by
  induction curve generalizing p with
  | stop => simp [curveTemperatureFine,lastTemperature]
  | @next p₀ t₀ p₁ t₁ hp ht tail ih =>
    have lastBound := Nat.le_trans (fine_curve_temperature_lower_bound tail p) (ih p)
    by_cases lo : p <= p₀
    · simp only [curveTemperatureFine,lastTemperature,lo,↓reduceIte]
      exact Nat.le_trans (Nat.mul_le_mul_right 10000 (Nat.le_of_lt ht)) lastBound
    · by_cases hi : p < p₁
      · simp only [curveTemperatureFine,lastTemperature,lo,hi,↓reduceIte]
        exact Nat.le_trans (interpolation_within_endpoints p₀ (t₀*10000) p₁ (t₁*10000) p (Nat.mul_le_mul_right 10000 (Nat.le_of_lt ht))).2 lastBound
      · simpa only [curveTemperatureFine,lastTemperature,lo,hi,↓reduceIte] using ih p

theorem fine_curve_temperature_monotone (curve : SaturationCurve p₀ t₀) (p q : Nat) (ordered : p <= q) :
    curveTemperatureFine curve p <= curveTemperatureFine curve q := by
  induction curve generalizing p q with
  | stop => simp [curveTemperatureFine]
  | @next p₀ t₀ p₁ t₁ hp ht tail ih =>
    by_cases plo : p <= p₀
    · simpa only [curveTemperatureFine,plo,↓reduceIte] using fine_curve_temperature_lower_bound (.next p₁ t₁ hp ht tail) q
    · have qlo : ¬q <= p₀ := by omega
      simp only [curveTemperatureFine,plo,qlo,↓reduceIte]
      by_cases pi : p < p₁
      · by_cases qi : q < p₁
        · simp only [pi,qi,↓reduceIte]
          exact interpolation_monotone _ _ _ _ _ _ ordered
        · simp only [pi,qi,↓reduceIte]
          exact Nat.le_trans (interpolation_within_endpoints p₀ (t₀*10000) p₁ (t₁*10000) p
            (Nat.mul_le_mul_right 10000 (Nat.le_of_lt ht))).2 (fine_curve_temperature_lower_bound tail q)
      · have qi : ¬q < p₁ := by omega
        simp only [pi,qi,↓reduceIte]
        exact ih p q ordered

/-- Rounded millipascal knots computed from the IAPWS SR1-86(1992) vapor-pressure
    equation, every 5 C from 0 to 200 C. The integer interpolation is the declared
    simulation approximation; it is not a verified real-arithmetic IAPWS solver.
    Source: https://iapws.org/technical-guidance/release/Supp-sat -/
def waterSaturation : SaturationCurve 611213 0 :=
  .next 872530 500 (by decide) (by decide) (
  .next 1228112 1000 (by decide) (by decide) (
  .next 1705677 1500 (by decide) (by decide) (
  .next 2339194 2000 (by decide) (by decide) (
  .next 3169824 2500 (by decide) (by decide) (
  .next 4246920 3000 (by decide) (by decide) (
  .next 5629057 3500 (by decide) (by decide) (
  .next 7385110 4000 (by decide) (by decide) (
  .next 9595338 4500 (by decide) (by decide) (
  .next 12352479 5000 (by decide) (by decide) (
  .next 15762843 5500 (by decide) (by decide) (
  .next 19947383 6000 (by decide) (by decide) (
  .next 25042730 6500 (by decide) (by decide) (
  .next 31202199 7000 (by decide) (by decide) (
  .next 38596731 7500 (by decide) (by decide) (
  .next 47415784 8000 (by decide) (by decide) (
  .next 57868145 8500 (by decide) (by decide) (
  .next 70182678 9000 (by decide) (by decide) (
  .next 84608985 9500 (by decide) (by decide) (
  .next 101417994 10000 (by decide) (by decide) (
  .next 120902451 10500 (by decide) (by decide) (
  .next 143377338 11000 (by decide) (by decide) (
  .next 169180207 11500 (by decide) (by decide) (
  .next 198671425 12000 (by decide) (by decide) (
  .next 232234353 12500 (by decide) (by decide) (
  .next 270275442 13000 (by decide) (by decide) (
  .next 313224269 13500 (by decide) (by decide) (
  .next 361533500 14000 (by decide) (by decide) (
  .next 415678806 14500 (by decide) (by decide) (
  .next 476158724 15000 (by decide) (by decide) (
  .next 543494473 15500 (by decide) (by decide) (
  .next 618229736 16000 (by decide) (by decide) (
  .next 700930415 16500 (by decide) (by decide) (
  .next 792184358 17000 (by decide) (by decide) (
  .next 892601074 17500 (by decide) (by decide) (
  .next 1002811446 18000 (by decide) (by decide) (
  .next 1123467439 18500 (by decide) (by decide) (
  .next 1255241817 19000 (by decide) (by decide) (
  .next 1398827879 19500 (by decide) (by decide) (
  .next 1554939222 20000 (by decide) (by decide) (
  .stop))))))))))))))))))))))))))))))))))))))))

def lastPressure : SaturationCurve p₀ t₀ → Nat
  | .stop => p₀
  | .next _ _ _ _ tail => lastPressure tail

def maximumSaturationPressure : Nat := lastPressure waterSaturation

@[noinline] def saturationTemperature (pressure : Nat) : Nat := curveTemperature waterSaturation pressure

theorem saturation_temperature_bounded (p : Nat) : saturationTemperature p <= 20000 := by
  exact curve_temperature_upper_bound waterSaturation p

theorem higher_pressure_cannot_lower_boiling_point (p q : Nat) (ordered : p <= q) :
    saturationTemperature p <= saturationTemperature q := curve_temperature_monotone waterSaturation p q ordered

@[noinline] def saturationTemperatureFine (pressure : Nat) : Nat := curveTemperatureFine waterSaturation pressure

theorem fine_saturation_temperature_bounded (p : Nat) : saturationTemperatureFine p <= 200000000 :=
  fine_curve_temperature_upper_bound waterSaturation p

theorem higher_pressure_cannot_lower_fine_boiling_point (p q : Nat) (ordered : p <= q) :
    saturationTemperatureFine p <= saturationTemperatureFine q :=
  fine_curve_temperature_monotone waterSaturation p q ordered

end Sand2
