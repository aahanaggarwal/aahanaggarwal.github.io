"""Compare evaluated Lean output with the independent IAPWS saturation equation.

The runtime contains an integer, typed interpolation curve, not these floats.
Source: IAPWS SR1-86(1992), Eq. 1; https://iapws.org/public/documents/6dGkr/Supp-sat.pdf
"""
import math
import sys
from pathlib import Path


def pressure_at(celsius):
    kelvin = celsius + 273.15
    tau = 1 - kelvin / 647.096
    series = (-7.85951783*tau + 1.84408259*tau**1.5 - 11.7866497*tau**3
              + 22.6807411*tau**3.5 - 15.9618719*tau**4 + 1.80122502*tau**7.5)
    return 22_064_000 * math.exp(647.096 / kelvin * series)


def reference_temperature(pascal):
    if pascal <= pressure_at(0):
        return 0.
    if pascal >= pressure_at(200):
        return 200.
    lower, upper = 0., 200.
    for _ in range(50):
        middle = (lower + upper) / 2
        if pressure_at(middle) < pascal:
            lower = middle
        else:
            upper = middle
    return (lower + upper) / 2


rows = [tuple(map(int, line.split(','))) for line in Path(sys.argv[1]).read_text().splitlines()]
assert len(rows) == 2001
errors = [abs(actual / 100 - reference_temperature(p / 1000)) for p, actual in rows]
assert max(errors) < .25, f'Saturation error {max(errors):.4f} C exceeds the declared 0.25 C tolerance'
assert all(0 <= t <= 20000 for _, t in rows)
assert all(a[1] <= b[1] for a, b in zip(rows, rows[1:]))
print(f'IAPWS reference comparison: {len(rows)} actual Lean evaluations, maximum error {max(errors):.4f} C over the declared 0–200 C curve (endpoints clamped).')
