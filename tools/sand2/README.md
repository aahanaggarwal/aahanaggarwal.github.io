# Sand Game 2 — AI-authored implementation and model notes

`/sand2/` runs a new closed-system model, independent of Sand 1. The entire world,
material registry, thermodynamics, reactions, transport, movement, timestep,
editing, presets and rendering are defined under `wasm/sand2/lean/Sand2/`.
Lungo 1.117.0 translates Lean 4.34.1 into Rust at build time. Handwritten Rust
retains the Lean world handle, checkpoints and output buffers and exposes a C
ABI. JavaScript handles pointer/keyboard input, playback and canvas presentation.
A dedicated worker runs Wasm, with one batch in flight and coalesced pointer
samples. Main-thread drawing stays responsive; page FPS and model Hz are shown
separately. Slow devices advance simulation time more slowly, without an
unbounded queue of catch-up timesteps.
There is no second Rust or JavaScript physics model or material catalogue.

## State and units

One grid cell represents 1 cm³ in a 2D cross-section. Molecular inventories count
nanomoles; mass is in nanograms, temperature in centidegrees Celsius, pressure in
millipascals, velocity in micrometres/second and energy in 10⁻¹⁴ J. The timestep
is 1/60 s. The box begins with finite oxygen/nitrogen at approximately 1 atm and
20 °C, surrounded by fixed iron boundary parcels. Boundaries exchange heat with
their finite iron mass and have no external ambient-temperature thermostat.

A parcel's energy is its complete chemical + thermal + kinetic + gravitational
budget. Molecular mass, formation energy and heat capacity are cached with Lean
proofs tying them to the composition. Losing kinetic energy increases the
remaining thermal budget. Heating changes enthalpy; phase changes do not replace
matter with unrelated substances or reset temperature. Fire is a luminous state
of finite hot fuel/product mixtures; extinguishing it never deletes its atoms.

Water has finite fusion/vaporization energy and isothermal plateaus. Quartz and
iron have finite fusion energy. Constant heat capacities and rounded phase data
are approximations; mineral polymorphs, nonideal mixtures, pressure-dependent
boiling, radiative transfer and high-temperature vaporization of metals/minerals
are not yet represented. The water phase diagram currently uses the reference
100 °C boiling point even when the gas pressure changes.

Gas moves by bounded finite-volume pressure relaxation, symmetric molecular
diffusion (including at equal pressure), and density-driven convective
relaxation of unstable gas layers. These operations conserve each molecular
species and transferring its energy and momentum. This is an overdamped model,
not a resolved compressible Navier–Stokes solver. Dense parcels use gravity,
fractional position, swept face crossings, density displacement and dissipative
contact. Pile geometry, liquid viscosity and collision laws are coarse cell
approximations. The velocity cap and iteration limit are declared numerical
limits. Reactions use activation thresholds and bounded simplified kinetics.

Heat and pressure face fluxes use a start-of-timestep thermal field (explicit
operator splitting); edits still use the current conserved inventories. Sweep
direction alternates. Painting and erasing are explicit external additions or
removals of matter/energy; the closed-system theorem applies between edits.

## Chemical scope

The inventory tracks H₂O, O₂, N₂, CO₂, CH₂O biomass, CH₂ hydrocarbon, C, SiO₂, NaCl,
HCl, CaCO₃, CaCl₂, Fe, Fe₂O₃, FeCl₂, H₂, KNO₃, S and K₂S. Biomass/hydrocarbon are
surrogates rather than a complete organic chemistry model. Integer atomic
weights and rounded formation enthalpies are used consistently throughout.

The complete declared reaction family is:

- CH₂O + O₂ → CO₂ + H₂O
- 2 CH₂ + 3 O₂ → 2 CO₂ + 2 H₂O
- C + O₂ → CO₂
- 2 H₂ + O₂ → 2 H₂O
- 4 Fe + 3 O₂ → 2 Fe₂O₃
- CaCO₃ + 2 HCl → CaCl₂ + H₂O + CO₂
- Fe + 2 HCl → FeCl₂ + H₂
- 2 KNO₃ + S + 3 C → K₂S + N₂ + 3 CO₂

Hydrochloric acid therefore does not dissolve quartz, wood or ice by arbitrary
contact rules. There is no water-to-plant growth rule. Biology is outside scope.
The declared chemistry is exhaustive for this model, not for all real chemistry.

## Machine-checked guarantees

`Physics` is a state monad whose programs carry a universal conservation proof.
There is no unrestricted state-write operation inside it. Single/pair edits must
provide certificates for all eleven elements and total energy. Bind and loops
compose these certificates. `timestep_conserves_every_element_and_energy` covers
the actual executable world update. `arbitrarily_many_timesteps_conserve` covers
any number of updates, for every input world representable by the Lean type.

Other substantive theorems cover arbitrary stoichiometric extents, every element
and mass balance, insufficient/excess reactants, maximum valid extent, contact
reaction equivalence to aggregate stoichiometry, gas partition/recombination,
per-species transfer, phase-specification soundness/completeness/uniqueness/
totality, latent heat, equal-and-opposite impulse and grid shape. Normalization
uses the proved phase classifier and retains all molecules, momentum and energy.

`ProofReport.lean` traverses every theorem in the Sand2 namespace and rejects
`sorryAx` or custom axioms. The standard Lean foundations `propext`, `Quot.sound`
and `Classical.choice` are allowed. `build.json` separately lists handwritten
theorems; derived constructor/equality bookkeeping does not inflate that list.
Proofs certify the declared model. They do not verify physical fidelity, Lungo,
its runtime, Rust, browser behavior or the absence of every possible bug.

## Validation and build

```sh
./dev.sh --sand2-only --no-serve  # kernel audit, physical checks, generation, comparisons
./dev.sh --sand2-only            # same checks; source preview at 127.0.0.1:8012
./dev.sh                         # build all games and the optimized production site
```

Prerequisites: Rust plus `wasm32-wasip1`, elan plus `leanprover/lean4:v4.34.1`,
Node and Python 3. Dependencies are pinned in project-local lockfiles. Optional
local toolchains and caches are ignored under `.tools/`.

`Validation.lean` checks SI-unit pressure, initial temperature, water/mineral
latent plateaus, oxygen exhaustion, selective chemistry, heat direction, sand
centre of mass and water spreading. These numerical checks complement universal
proofs; a conserved but static or incorrectly scaled simulation must still fail.

The independent Lean evaluator produces 25 complete-world reference digests and
budgets across five scenes and multiple timesteps. Generated native Rust and the
packaged browser Wasm must agree on all of them. The digest includes every
molecular field, energy, momentum, position fraction, morphology and update stamp.
Native/browser checks also exercise exact checkpoints, read-only rendering,
input boundaries and conservation for every paintable material.

## Browser and deployment

Lungo's supported target here is `wasm32-wasip1`. `sand2/engine.js` supplies an
empty environment, no directories and console-only output; unexpected imports
fail. No browser filesystem or network capability is granted to the module.

The generated Rust snapshot under `tools/sand2/generated/` and compiled Wasm
under `sand2/pkg/` are committed. `sand2/build.json` records source/artifact
SHA-256 hashes and theorem names. The existing optimizer refuses stale artifacts
or missing/new Lean modules. Frontend-only changes do not require extraction.
The existing GitHub Actions/Cloudflare Pages workflow remains unchanged.

## Property references

These references inform rounded parameters; they do not validate the cell solver:

- [NIST water reference data](https://webbook.nist.gov/cgi/cbook.cgi?Name=water&cTC=on&cTG=on)
- [NREL physical-property appendix](https://www.nrel.gov/docs/fy03osti/33954.pdf)
- [NIST-JANAF quartz](https://janaf.nist.gov/tables/O-037.html)
- [Quartz/cristobalite fusion calorimetry](https://doi.org/10.1016/0016-7037(82)90383-0)
- [NIST-JANAF reference iron](https://janaf.nist.gov/tables/Fe-003.html)
- [NIST iron thermodynamic review](https://srd.nist.gov/jpcrdreprint/1.555761.pdf)
- [NIST heats of combustion and formation](https://www.nist.gov/publications/heats-combustion-and-related-properties-pure-substances)

Water constants are rounded to cp(ice)=2100, cp(liquid)=4180, cp(vapor)=2000
J/(kg K), fusion=334 kJ/kg and vaporization=2257 kJ/kg. Quartz uses a simplified
1700 °C melt and 150 kJ/kg fusion; actual silica polymorph behavior is more
complex. Iron uses 1538 °C and 247 kJ/kg fusion. Constant conductivities and
capacities, surrogate organic formation energies and kinetic rate divisors are
declared approximations; quantitative combustion predictions are outside scope.

## First full-core milestone validation (2026-10-31 UTC)

73 handwritten theorems are included in a 514-theorem namespace audit. All 25
Lean/native/browser complete-world comparisons, 14 physical/unit checks, native
integration tests and 20-material browser conservation checks pass. A 96×64
dam-break tick takes roughly 72–75 ms in Node's Wasm runtime on this host; this
is a performance limitation, not a claimed 60 Hz fluid solver. A browser worker
keeps the page at 60 FPS while the model advances near 10–14 Hz. Mobile touch
painting/undo, 390 px layout, heat view and worker cleanup on SPA navigation were
checked in isolated Chromium.

Next work targets faster updates and richer liquid/pressure interactions, then
additional reactive materials with the same proof and validation requirements.

## Material and gas-transport expansion (2026-10-31 UTC)

The palette now exposes 32 materials, including the reactive gases, limestone,
charcoal, nitrate, sulfur, reaction-product salts and molten iron. Nine Lean
experiments include selective carbonate dissolution, equal-pressure gas mixing,
buoyancy, energetic reaction and molten-metal cooling. Reagent powders currently
use fixed condensed constitutive states except the water/quartz/iron families;
thermal decomposition and phase data for every added reagent remain future work.

`Portion` requires a per-species partition certificate. Its simultaneous opposing
exchanges preserve every molecule, all eleven elements, mass, momentum and total
energy. Both gas packets use the same face height for gravitational energy, so
equal counterflows in uniform air do not manufacture heat. The diffusion step
uses a rounded 0.2 cm²/s ordinary-gas coefficient (0.6 cm²/s when hydrogen is
present), without temperature/pressure dependence yet. Density-driven gas
buoyancy is an overdamped relaxation law.

Contact reactions transfer the consumed fraction's nonchemical energy and
momentum into the product side; complete consumption does not strand heat in an
empty cell. Trace reactants can advance instead of stalling at integer division.
The vessel boundary is chemically inert.

86 handwritten theorems are covered by the 578-theorem namespace axiom audit.
All 45 complete-world Lean/native/browser comparisons, 21 physical checks and
32-material browser conservation checks pass. Optimized Chromium touch checks
cover all new experiments with no horizontal overflow or page errors. The
96×64 dam-break Wasm benchmark is approximately 80 ms/tick on this host.

[NIST gas diffusion reference compilation](https://doi.org/10.6028/NIST.TN.2279)
informs the scale of the rounded diffusion parameters; the solver does not use
its full gas-pair and temperature-dependent correlations.

## Behavior-preserving loop optimization (2026-10-31 UTC)

The proved physics loop now iterates ranges directly instead of allocating a
list of indices. `range_loop_matches_list_loop` proves exact agreement with the
previous loop for every body, counter, accumulator and starting world. Loop
specialization removes generic callback overhead, and thermal samples reuse the
same calculated temperature for ideal-gas pressure.

The 45 saved reference states are byte-for-byte unchanged. A same-process
old/new Wasm comparison over three repeated dam-break runs measured 88.43 versus
77.41 ms/tick (about 12 percent faster), with identical final complete-state
digests. The routine pipeline's shorter benchmark measured 69.81 ms/tick; the
difference illustrates scene evolution and timing variation, not a faster
physical timestep. All 89 handwritten theorems and existing checks pass.
