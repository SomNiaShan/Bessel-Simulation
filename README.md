# Bessel Simulation App

MATLAB app and simulation code for Bessel beam simulation and SLM phase export.

## Requirements

- MATLAB R2021a or newer is recommended.
- No additional MathWorks toolbox is required for the app.

The rotated SLM batch export uses a local nearest-neighbor crop rotation implementation, so it does not require Image Processing Toolbox.

## Run from Source

Open MATLAB in this folder and run:

```matlab
launch_Bessel_Simulation_app
```

The launcher adds `src/` to the MATLAB path and opens the app.

The app startup and **Defaults** button use the preset in
`src/Bessel_Simulation_app_defaults.m`, captured from the live app on 2026-10-01.
It uses a 1080-by-1080 source over 8.64 mm, propagation over 0-250 mm with
1 mm base spacing, and local refinement over 220-225 mm at 0.01 mm spacing.
The focused ROI is 0.1 mm wide with 512-by-512 samples. The laser is 1030 nm,
40 W, 100 kHz and 275 fs; the beam waist radius is 2.5 mm with M2=1.2
(`effectiveGaussian`). The circular axicon uses 10 radial cycles, with
`helicalGamma=0`. The locked telescope uses f1=200 mm and f2=10 mm at z=0 and
210 mm; the sample position is 215 mm with the sample disabled.
3D intensity export is enabled, and an empty output directory selects the
standard `outputs/` folder. The engine's general defaults remain available via
`Bessel_Simulation_app_engine('defaults')`.

## Focused adaptive propagation

The Simulation tab now offers `adaptiveCollins` (default) and `legacyASM`.
`adaptiveCollins` evaluates each observation plane from the **full input complex
field** using a padded angular spectrum before the first lens and a scalar
paraxial Collins/CZT integral through the lens system. The small output region
is only an observation region; it is never cropped and then reused as the input
to the next plane. Optical elements are applied at their physical z positions,
including positions between requested output planes.
The pre-lens angular-spectrum segment uses symmetric padding and an optional
two-dimensional transfer-function band limit. Its report shows the fraction
of source spectral power removed; substantial removal means the chosen
source/propagation window does not support a trustworthy result.

`adaptiveOutputN` sets the sampling in the focused observation region.
`adaptiveOutputSizeMm=0` chooses a width from the focal-length ratio. A positive
value specifies the width explicitly. Check the reported ROI edge fraction and
enlarge the ROI if important light reaches its edge. The `maxWorkingGiB` setting
rejects runs whose estimated ROI stack and CZT work arrays exceed the budget.
The Phase tab's `referenceRadiusMm` and `referencePixelPitchMm` define the physical
reference scales for cycle and pixel phase inputs. Their defaults (4.32 mm and
0.008 mm) reproduce the previous default source; changing source `N` or
`sizeMm` now refines/extends its sampling without changing these phase scales.
If the actual phase device uses other dimensions, set the reference values
explicitly before interpreting pixel or cycle parameters.
Older complete parameter snapshots without these two fields are migrated using
their saved `sizeMm` and `N`, preserving their prior phase scale.
The stored intensity stack is single precision on the focused ROI; the full
complex 3D field is not retained. `legacyASM` keeps the earlier fixed-grid
propagation and result format.

The Optics tab offers `manual` positions and `telescopeLocked`. In the locked
mode, lens 2 is placed at `lens1PositionMm + f1 + f2`, and the sample is placed
at `lens2PositionMm + sampleOffsetFromLens2Mm`. In manual mode the focal-length
ratio shown in the summary is only a nominal quantity; it is not a measured
magnification of an arbitrary layout.

The adaptive backend is a **scalar paraxial** model. It does not include vector
focusing, lens aberrations or Fresnel reflection at the sample interface.
The UI reports a conservative ray-angle estimate and input-integral phase-step
check; large angles require separate nonparaxial validation. Increasing
`adaptiveOutputN` cannot recover a physical SLM pattern already undersampled
on the source grid.

Output can include a globally scaled 8-bit multipage TIFF plus a JSON file with
the actual x/y/z coordinates. Enable `writeRawIntensity` for a MAT file with
single-precision native intensity, physical axes, and the power-density scale.
Use the MAT file for quantitative analysis; the TIFF is for display. The
observation planes include element positions, so z spacing can be nonuniform.

## Local z refinement

In **Z sampling**, choose `local`, add rows `[start z, end z, local dz]` in mm,
and click **Preview sampling**. Simulation's **Base z spacing** remains the
coarse grid outside those regions. Overlaps use the smallest local step;
original region borders, enabled optical-element positions, and extra exact
planes are retained. Every added plane is calculated from the full source.
`uniform` retains the previous observation grid. The app preset uses `local`
with the region `[220,225,0.01]`; the engine's general default is `uniform`.

For f1=200 mm, f2=10 mm, lens positions 0 and 210 mm, a useful starting point
is base dz=1 mm over 0–250 mm and `[218,223,0.02]`, with extra plane `220.5`.
This gives 496 planes with a 512-by-512 ROI (0.484 GiB intensity stack), versus
12,501 planes (12.208 GiB stack) for a global 0.02 mm grid. Tighten to 0.01 mm
to check peak position, peak intensity, and longitudinal width convergence.
The 220.5 mm image plane is not necessarily the beam's intensity maximum.
Extend the region if a peak lies at its border.

```matlab
p = Bessel_Simulation_app_engine('defaults');
p.optics.lens1PositionMm = 0;
p.optics.lens2PositionMm = 210;
p.optics.lens2FocalLengthMm = 10;
p.optics.sampleEnabled = false;
p.phase.axiconRadialCycles = 20;
p.phase.helicalGamma = 0;
p.simulation.zSamplingMode = 'local';
p.simulation.zRefinementRegionsMm = [218,223,0.02]; % K-by-3, multiple regions
p.simulation.zExtraPlanesMm = 220.5; % a vector also accepts multiple planes
p.simulation.zRangeMm = 250;
p.simulation.dzMm = 1;
preflight = Bessel_Simulation_app_engine('plan',p); % no fields/files allocated
% Inspect preflight.zPlan and preflight.memory before running.
r = Bessel_Simulation_app_engine('run',p);
```

The preview and Run use the same exact plane count and memory estimate.
`maxZPlanes` defaults to 20,000 and stops oversized coordinate allocations;
`maxWorkingGiB` checks estimated source arrays, ROI stack, and CZT workspace.
The estimate does not guarantee the actual peak process memory. The program
rejects excessive settings without silently reducing resolution.
`legacyASM` supports only uniform sampling; switching to it resets the mode
visibly while retaining stored refinement settings.

TIFF page k corresponds to `zMm(k)` in its JSON. JSON and raw MAT contain
`zSamplingMetadata` from the completed run. Many 3D viewers assume equally
spaced TIFF pages: use the MAT/JSON coordinates for measurements and use
`trapz(zMm,values)` for longitudinal integration. Local dz controls observed
longitudinal resolution; it cannot repair inadequate source sampling, a small
xy ROI, or the paraxial model's limits. Unit tests are in `tests/`; run
`benchmark_z_refinement` from that folder for the full-size convergence case.

Validation on 2026-10-01 with MATLAB R2026a: **41/41 tests passed**, including
mode consistency, bounded allocation, TIFF/MAT coordinates, and UI round trips.
The full-size example above (source N=1080, ROI N=512, M2=1.2) gave:

| Sampling | Planes | Stack / estimated total (GiB) | Sampled peak z (mm) | On-axis peak (W/mm²) | Single-lobe z FWHM (mm) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Base dz=1 mm | 251 | 0.245 / 0.749 | 221.00 | 9.72163226e12 | 1.05954 |
| Local dz=0.02 mm | 496 | 0.484 / 0.988 | 221.06 | 9.87492778e12 | 0.88001 |
| Local dz=0.01 mm | 746 | 0.729 / 1.232 | 221.07 | 9.87852020e12 | 0.88021 |

Common-plane intensity arrays were identical. The two refined runs differed
by 0.01 mm in sampled peak position, 0.0364% in peak intensity and 0.0226% in
FWHM. These are convergence results for this particular scalar-model example.
Measured run times were approximately 43, 89 and 121 seconds on the test PC;
runtime and actual process memory depend on the machine and concurrent work.

## Circular Amplitude Aperture

The Phase tab includes `apertureRadiusMm`, a centered hard circular aperture at the SLM plane:

- `0`: fully open; the existing field and power-density results are preserved.
- Positive value: aperture radius in mm. The complex field is set to zero where `sqrt(x^2 + y^2)` exceeds the radius.

The aperture is applied after phase modulation and before BPM propagation. `laser.powerW` is treated as the incident average power before the aperture. The app reports aperture transmission and transmitted average/peak power, and the power-density plots retain the blocked-power loss instead of renormalizing it away.

The exported phase image is set to zero phase outside the simulated aperture, but a phase-only SLM cannot physically block light by displaying zero phase. Use a physical iris, an amplitude modulator, or suitable spatial filtering to reproduce the simulated blocking in an experiment.

## Axicon Geometry

The Phase tab separates axicon geometry from the parameter used to define its phase slope:

- `circular`: the original circular axicon phase `k_r * (R - r)`, producing a conventional Bessel-like beam.
- `linear1D`: a biprism-style phase `k_r * (R - abs(u))`, producing a Bessel-like light sheet.

For `linear1D`, the active coordinate is:

```text
u = x*cos(gamma) + y*sin(gamma)
```

where `gamma` is `axiconOrientationDeg`. At `0 deg`, the phase varies along x and the light sheet extends in the y-z plane. The Propagation tab uses the fixed laboratory-frame `x = 0` y-z section, so changing `gamma` changes how the rotated sheet intersects the displayed plane. Axicon-normal u-z and sheet-tangent v-z sections remain available in the postprocess result fields.

The curved-Bessel shift is currently supported only for `circular` geometry. Set both curved-shift parameters to zero when using `linear1D`.

## Axicon Definition Modes

The Phase tab now uses `axiconMode` to choose one active axicon definition:

- `coneAngle`: edit the effective holographic cone angle `beta`.
- `radialPeriodMm`: edit the `2*pi` SLM phase period in mm along the active axicon coordinate.
- `radialPeriodPx`: edit the `2*pi` period in generated phase-map pixels along the active coordinate.
- `radialCycles`: edit the number of `2*pi` phase cycles from the beam axis to the reference half-width.
- `physicalEquivalent`: edit an equivalent physical axicon refractive index and base angle.

Internally, all modes are converted to one transverse phase slope `k_r` and one effective cone angle before propagation.
Inactive axicon fields are read-only equivalents and update in the app when the active definition changes.

## Checkerboard Bessel Vortex Phase

The Phase tab includes an optional checkerboard-multiplexed Bessel vortex phase. Enable `checkerboardBesselEnabled`, then set:

- `checkerboardTileSizePx`: checkerboard tile size in generated phase-map pixels.
- `checkerboardTc1` / `checkerboardTc2`: the two vortex topological charges.
- `checkerboardBeta1Deg` / `checkerboardBeta2Deg`: the two axicon cone angles.

Same-parity checkerboard tiles use beam 1, alternating tiles use beam 2.

## Files

- `launch_Bessel_Simulation_app.m`: app launcher.
- `src/Bessel_Simulation_app.m`: MATLAB UI.
- `src/Bessel_Simulation_app_defaults.m`: app startup and Defaults-button preset.
- `src/Bessel_Simulation_app_engine.m`: app simulation engine.
- `src/BPM_drill_AI.m`: script-style simulation entry point.
- `docs/`: parameter notes and optical-layout reference.
- `outputs/`: generated `.bmp`, `.tif`, and log outputs.
