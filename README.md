# BPM Drill AI App

MATLAB app and simulation code for BPM drill-beam simulation and SLM phase export.

## Requirements

- MATLAB R2021a or newer is recommended.
- No additional MathWorks toolbox is required for the packaged app.

The rotated SLM batch export uses a local nearest-neighbor crop rotation implementation, so it does not require Image Processing Toolbox.

## Run from Source

Open MATLAB in this folder and run:

```matlab
launch_BPM_drill_AI_app
```

The launcher adds `src/` to the MATLAB path and opens the app.

## Axicon Definition Modes

The Phase tab now uses `axiconMode` to choose one active axicon definition:

- `coneAngle`: edit the effective holographic cone angle `beta`.
- `radialPeriodMm`: edit the radial `2*pi` SLM phase period in mm.
- `radialPeriodPx`: edit the radial `2*pi` period in generated phase-map pixels.
- `physicalEquivalent`: edit an equivalent physical axicon refractive index and base angle.

Internally, all modes are converted to one radial phase slope `k_r` and one effective cone angle before propagation.
Inactive axicon fields are read-only equivalents and update in the app when the active definition changes.

## Install from Toolbox Package

Use the installer:

```text
release/BPM_Drill_AI_App.mltbx
```

In MATLAB, double-click the `.mltbx` file from the Current Folder browser, or install it through the Add-Ons interface. After installation, start the app from the Apps tab, or run:

```matlab
launch_BPM_drill_AI_app
```

## Rebuild the Installer

After editing the source, rebuild the `.mltbx` package with:

```matlab
package_BPM_drill_AI_toolbox
```

This creates:

```text
release/BPM_Drill_AI_App.mltbx
```

## Files

- `launch_BPM_drill_AI_app.m`: app launcher.
- `src/BPM_drill_AI_app.m`: MATLAB UI.
- `src/BPM_drill_AI_app_engine.m`: app simulation engine.
- `src/BPM_drill_AI.m`: script-style simulation entry point.
- `docs/`: parameter notes and optical-layout reference.
- `outputs/`: generated `.bmp`, `.tif`, and log outputs.
