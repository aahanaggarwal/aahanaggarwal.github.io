import Sand2

/-- Evaluate the actual integer saturation lookup over a wide pressure sweep.
    A separate Python reference compares this output with IAPWS real arithmetic. -/
def main : IO Unit := do
  for k in [:2001] do
    let pressure := k*1000000
    IO.println s!"{pressure},{Sand2.saturationTemperature pressure}"
