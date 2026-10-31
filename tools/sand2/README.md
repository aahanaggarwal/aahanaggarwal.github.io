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
is 1/600 s. The box begins with finite oxygen/nitrogen at approximately 1 atm and
20 °C, surrounded by fixed iron boundary parcels. Boundaries exchange heat with
their finite iron mass and have no external ambient-temperature thermostat.

A parcel's energy is its complete chemical + thermal + kinetic + gravitational
budget. Molecular mass, formation energy and heat capacity are cached with Lean
proofs tying them to the composition. Losing kinetic energy increases the
remaining thermal budget. Heating moves a parcel along its energy/temperature
curve; phase changes do not replace
matter with unrelated substances or reset temperature. Fire is a luminous state
of finite hot fuel/product mixtures; extinguishing it never deletes its atoms.

Water has finite fusion/vaporization energy, pressure-dependent saturation and
isothermal phase plateaus. Quartz and
iron have finite fusion energy. Constant heat capacities and rounded phase data
are approximations; mineral polymorphs, nonideal mixtures, radiative transfer and high-temperature vaporization of metals/minerals
are not all represented. Water saturation uses a rounded IAPWS-derived 0–200 °C
curve, clamped outside that range. This is not a high-pressure or supercritical
equation of state. Gas heat capacities remain constant-temperature approximations.

Cell energy stores gas internal energy with Cv. Advected packets carry enthalpy,
including R*T pressure/volume work. Formation references include the gas
reference offset, and the water phase curve uses internal-energy latent heat.

Gas and liquid share a variable-density pressure and velocity solve, implicit
viscosity, gravity and conservative finite-volume advection. Gas compressibility
uses its mixture Cv; the condensed fluid uses a rounded 2.2 GPa bulk modulus.
An active-set pressure constraint represents cavitation without accepting negative
absolute pressure. This is a coarse homogeneous mixture model, not a resolved
sharp-interface or turbulent CFD model. Surface tension, temperature-dependent
viscosity, thermal expansion and species-specific liquid compressibility are not
yet represented. Water, oil, molten iron and molten silica use rounded constant
viscosities. Molecular gas diffusion still acts separately at gas-accessible faces.

Dense grains retain swept face crossings and dissipative contact mechanics.
The speed cap, finite pressure iterations, outgoing-volume CFL limit and adaptive
retry depth are declared numerical limits. A candidate that fails temperature,
volume or pressure checks is rejected atomically. If minimum substeps fail, the
entire tick rolls back, including simulated time, and the UI pauses at an accuracy
limit. Reactions use activation thresholds and bounded simplified kinetics.

Heat and contact reactions use a start-of-timestep thermal field; fluid updates
then solve pressure and advect the current conserved inventories. Sweep
direction alternates. Painting and erasing are explicit external additions or
removals of matter/energy; the closed-system theorem applies between edits.

## Chemical scope

The inventory tracks H₂O, O₂, N₂, CO₂, CH₂O biomass, CH₂ hydrocarbon, C, SiO₂, NaCl,
HCl, CaCO₃, CaCl₂, Fe, Fe₂O₃, FeCl₂, H₂, KNO₃, S, K₂S, CH₄ and CO. Biomass/hydrocarbon are
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
- CH₄ + 2 O₂ → CO₂ + 2 H₂O
- 2 CH₄ + 3 O₂ → 2 CO + 4 H₂O
- 2 CO + O₂ → 2 CO₂

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
uses proved component phase classifiers and retains all molecules, momentum and
energy. The mineral classifiers have exactly three declared states, with no
fictitious high-energy vaporization threshold. Water, iron and silica keep their
own phase and latent-heat contributions in mixtures. Global theorems additionally
preserve absolute-temperature admissibility from an admissible starting world,
prevent increased liquid overfill and retain cells/time on a rejected tick.

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
centre of mass and water spreading. `FluidValidation.lean` adds independent
analytic Poisson and pressure-obstacle solutions, 18 mixed-phase volume-closure
cases, evaporative cooling, hydrostatic head, resting-water centroid stability,
a liquid-filled connection between separate gas chambers, and hydrogen-bubble rise. These numerical checks complement universal
proofs; a conserved but static or incorrectly scaled simulation must still fail.

Lean’s independent native C compiler evaluates the same definitions and produces 66 complete-world reference digests and
budgets across eleven scenes and multiple timesteps. Generated native Rust and the
packaged browser Wasm must agree on all of them. The digest includes every
molecular field, energy, momentum, position fraction, morphology, update stamp, mechanical and phase pressures, and numerical diagnostics.
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

## Pressure-aware phase and gas-energy milestone (2026-10-31 UTC)

Water's gas fraction is derived from its available latent energy. The transport
portion is capped by that fraction; it no longer waits for the whole parcel to
become vapor. Gas and condensed mass recombine exactly into molecular mass, so
compressed gas is not mistaken for liquid merely because it exceeds a mass
threshold. The steam/air classification also retains visible dilute steam.

The saturation table's ordering is part of its Lean type. Generic theorems prove
interpolation bounds and that raising pressure cannot lower saturation
temperature. Cached phase points carry proofs tying them to their pressure.
Partial phase fractions are bounded, monotone and cannot overdraw their latent
energy budget. The closed-system atom/energy theorem covers all these updates.

Gas-dominated cells use water partial pressure for dew-point behavior. Condensed
water uses hydrostatic surface pressure and a bounded twelve-step own-vapor
pressure search. `Bracketing` proves interval retention, halving and a numerical
width bound. Threshold-retention theorems are conditional on a threshold
predicate; a universal proof of the nonlinear physical root equation is not
claimed. A sealed-cell benchmark checks the pressure/temperature response and
its pressure residual numerically. This remains a coarse fixed-volume mixture
and hydrostatic-column model, rather than a resolved multiphase CFD solver.

Closed gas cells use Cv, with distinct O2, N2, CO2 and H2 values derived from
rounded room-temperature Cp values. Gas transport includes the pressure/volume
work term. The water-vapor internal-energy reference is proved consistent as
saturation pressure changes; pressure changes do not reset a superheated vapor's
temperature. This distinguishes the conserved cell-energy inventory from a sum
of gas enthalpies.

120 handwritten theorems pass the 785-theorem namespace axiom audit. All 36
physical checks, 45 complete-world Lean/native/browser comparisons and
32-material browser conservation checks pass. The actual Lean saturation lookup
was compared against the independent IAPWS equation at 2,001 pressures; maximum
sampled error was 0.1805 °C over the clamped reference range. The 96×64 dam-break
benchmark is approximately 103 ms/tick on this host; performance work continues.

Playback now shows actual completed physics Hz and Lean simulated time. Manual
steps are queued exactly, and undo restores time with the complete world. The
Fast/Medium/Slow controls target progressively lower rates without claiming a
real-time multiple on slow devices. Optimized Chromium touch tests verified five
rapid steps, time-restoring undo, distinct playback rates, 390 px layout and
worker cleanup without page errors.

Reference details:

- [IAPWS saturation formulation](https://iapws.org/public/documents/6dGkr/Supp-sat.pdf)
- [NASA: Cp, Cv and pressure/volume work](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/specific-heats-cp-and-cv-1/)
- [NIST hydrogen heat capacity](https://janaf.nist.gov/tables/H-050.html)
- [NIST O2](https://webbook.nist.gov/cgi/cbook.cgi?ID=C7782447&Mask=1),
  [N2](https://webbook.nist.gov/cgi/cbook.cgi?ID=C7727379&Mask=1) and
  [CO2](https://webbook.nist.gov/cgi/cbook.cgi?ID=C124389&Mask=1) thermochemistry


## Energy-consistent gravity and Lean time (2026-10-31 UTC)

Dense parcels now integrate displacement from the average of the old and new
velocity, rather than moving for the full tick at the final velocity. Lean
proves the SI-unit conversion, sub-position rounding bound and the exact
uniform-acceleration distance and speed. The executed-world benchmark confirms
4.905 cm of free fall in 0.1 simulated seconds, with less than 10 microjoules of
thermal drift. Collisions, drag and the declared speed cap remain approximations.

The browser reads elapsed milliseconds from Lean. It contains no copy of the
physics timestep. The clock is part of the retained world and restores on undo.
All 127 handwritten theorems, the 800-theorem namespace audit, 38 independent
physical checks and 45 complete-world Lean/native/Wasm comparisons pass. The
96×64 dam-break benchmark is approximately 104 ms/tick on this host.


## Coupled liquid/gas and component-phase milestone (2026-10-31 UTC)

The former parcel-level liquid motion and overdamped gas-pressure/buoyancy rules
are replaced by one Lean finite-volume fluid solve. The new communicating-vessel
experiment requires water to rise above an outlet and approach equal mean levels;
merely spreading along the bottom cannot pass it. Molecular transport never
swaps a different chamber's air backward through a liquid-filled connection.

Pressure is an independent mechanical state. Water's saturation lookup uses a
microdegree internal cache, while displayed temperatures remain centidegrees.
The energy-volume flash closure computes vapor fractions and pressure from the
same inventory and conserved internal energy. Its actual search and all fast
paths have a proved vapor-pressure bound within the declared saturation domain.
The approximation tolerance is 5 Pa. Pure-liquid pressure retains a previous
value only within 40 Pa of its exact quantized molecular EOS; Lean proves the
resulting cell-volume error is at most 2e-8 of a cell. The coarser runtime volume
guard allows 1e-6 of a cell, and the whole-timestep theorem prevents its growth.

Mixed parcels now retain separate water, iron and silica phase states. Iron and
silica have continuous partial-melting fractions and ordered latent intervals.
A trace of water cannot erase their fusion energy. Soundness, completeness,
uniqueness and totality cover the product of the component transitions; warming
cannot reverse mineral fusion.

The site retains its shared CRT typography and controls. Mechanical pressure
is shown in the pressure view and inspector; partially filled liquid cells fade
with their volume fraction. Vessel sizes state their physical dimensions, with
48 × 32 cm as the default and the original 96 × 64 cm size available. Larger
vessels and stiff hot scenes advance much more slowly than wall time. Page FPS,
completed model Hz and simulated time remain separate measurements.

Current validation and artifact counts are recorded in `sand2/build.json`.
The complete build must pass the kernel axiom audit, 59 physical benchmark
families, 2,001 independent IAPWS comparisons, native integration checks, 66
Lean/native/Wasm complete-world states, and all 34 palette conservation/accuracy
checks before a milestone is committed. The floating-point pressure algorithm's accuracy is
validated numerically; universal convergence of arbitrary matrices is not claimed.

Pressure-solver reference: [Bridson's fluid simulation notes](https://www.cs.ubc.ca/~rbridson/fluidsimulation/fluids_notes.pdf).


The Wasm stress test also covers repeated world lifecycles and requires bounded
memory reuse. This caught a 32-bit literal-lifetime defect in Lungo 1.117.0:
large `Nat` literals were constructed repeatedly although host-optimized IR
could omit their reference-count operations. `wasm/sand2/build.rs` automatically
places literal constructions into the backend's existing persistent constant
cells. This generic emission normalization contains no physics rules. Its source
and normalized generated output are hashed in the build record; independent
Lean/native/Wasm state comparisons check the resulting executable. JavaScript
also normalizes C-ABI pointers to unsigned values, including addresses above 2 GB.

This checkpoint passes 172 handwritten proofs in the 955-theorem axiom audit,
49 physical benchmark families, all 50 independent Lean/native/Wasm reference
states, every palette material and all ten default-size presets. The repeated
65-tick empty-world memory regression holds at 1,572,864 bytes. Optimized mobile
checks cover touch painting, undo, vessel changes and worker termination.
The full-size 96 × 64 dam-break benchmark averages 12.4 seconds per 1/60-second
model tick over its first ten ticks on this host. Stiff default-size hot scenes
are also slow. Smaller physical timesteps and lower input latency are the next
performance task; this checkpoint does not claim real-time simulation.


## Finer time integration and independently specified chemistry (2026-10-31 UTC)

The physical timestep is now 1/600 second. Gravity, displacement, Fourier heat
flux, molecular diffusion, reaction-rate divisors, drag and luminous lifetimes
use the same Lean clock. Quiet fluid states need one pressure step, removing the
previous unconditional two-solve minimum. Smaller committed steps let the worker
return input/render progress more frequently; they do not claim faster physical
time. Benchmarks retain their original simulated durations: the communicating
vessels test now covers 1,200 ticks over two seconds, and free fall covers 60
steps over 0.1 seconds. Lean proves the resulting displacement and clock rounding.

The palette adds methane and carbon monoxide, for 34 materials and 21 molecular
inventories. Gas count and Cv are shared authoritative Lean functions, so every
pressure, transport and phase calculation includes the same species. Rounded
room-temperature Cp values from NIST give Cv(CH4)=27.376 and Cv(CO)=20.835
J/(mol K), using R=8.314. Formation references add the methane/CO thermochemistry
to the existing declared energy convention. Constant gas properties and
phenomenological ignition/rate parameters remain approximations. Cryogenic
condensation of permanent gases and detailed flame chemistry are outside scope.

Methane uses exclusive oxygen-rich and oxygen-poor kinetic routes. The latter
can leave CO and unburned methane; hot CO can subsequently oxidize with oxygen.
The new fuel-rich experiment executes these rules in the complete world solver.
General theorems prove each route's molar change and chemical-energy release.

Stoichiometry.lean specifies outputs by independent per-species balance
equations. For every inventory and extent, soundness, completeness, uniqueness
and totality relate those equations to the executing aggregate/contact reactions.
The stoichiometric tables separately balance all elements. The actual update
schedule contains every declared reaction exactly once, and the chemistry fast
filter cannot skip an eligible family. That last theorem exposed and fixed a
missing hydrogen case; a hot hydrogen/oxygen regression covers it.

Additional universal theorems order the water/iron/silica latent intervals and
prove monotonicity of the actual microdegree saturation cache. The whole-world
conservation, absolute-temperature and atomic rollback guarantees extend to all
new materials. The expanded pipeline requires 59 physical benchmark families,
66 independent Lean/native/Wasm states, 34-material conservation/accuracy checks
and all eleven default-size experiments.

Property references: [NIST methane](https://webbook.nist.gov/cgi/cbook.cgi?ID=C74828&Mask=1),
[NIST carbon monoxide](https://webbook.nist.gov/cgi/cbook.cgi?ID=C630080&Mask=1).


Final checks for this extension pass 195 handwritten proofs in a 1,097-theorem
namespace audit, all 59 physical benchmark families, 2,001 IAPWS samples, native
integration checks, 66 complete-world Lean/native/Wasm comparisons, all 34
materials and all eleven default-size experiments. The repeated-world memory
regression holds at 1,572,864 bytes after 65 ticks. Production desktop/mobile QA
checks the 0.010-second clock after six manual steps, methane/CO painting, exact
undo, vessel resize, the new experiment, no horizontal overflow at 390 px and
worker termination on site navigation.

On this host the 96 × 64 dam-break benchmark now averages 988.67 ms per
1/600-second tick over its first ten ticks. This is lower latency per committed
step than the preceding checkpoint, while simulated time still advances much
more slowly than wall time. The finer clock must not be interpreted as a
600 Hz real-time performance claim.
