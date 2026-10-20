# CNC Milling Force Model for a Reverse Digital Twin (MATLAB)

The MATLAB forward model and simulated dataset behind a graduation project on **reverse digital twins** for CNC milling. The project's aim is to infer machining parameters (depth and width of cut, feed, milling mode) from measured cutting forces and torque. This repository holds the forward step: a mechanistic model that computes forces from those parameters, and a parameter sweep that produces the training data a reverse model would learn from.

> Group graduation project, **ENS 491/492**, BSc Industrial Engineering, Sabancı University (2024). Project title: *Design of an Automated Machining Process Identification System for Reverse Digital Twins*. A three-student team; the code here is the team's forward milling model.

**Tech stack:** MATLAB (mechanistic milling force model, parameter sweep, `writecell`) · Python / NumPy (independent re-implementation used to verify the dataset)

## Scope: what is and is not here

| Part of the project | In this repository |
|---|---|
| Forward model: cutting forces (and torque and power) from tool geometry and cutting conditions | ✅ `matlab/` |
| Simulated dataset over a grid of cutting conditions | ✅ `data/MillingSimulationResults2.xlsx`, 129,600 rows |
| Independent NumPy port that recomputes the dataset | ✅ `python/verify_dataset.py` |
| Reverse step: predicting cutting conditions from forces and torque | ❌ Not included |

The project's second progress report (November 2024) records that the team refocused on finalising the forward milling code before attempting the reverse simulation. No reverse-model code was found among the project files, so none is presented here.

## Model

`MillingSimulation.m` implements a standard mechanistic milling force model.

- **Tool and material:** a 12 mm, 4-flute end mill with a 30° helix angle and 12° rake angle; shear stress τ = 613 MPa; friction angle βn = 19.1 + 0.29·rake.
- **Slicing:** the cutter is split into axial slices of 0.001 mm and one revolution into 360 angular steps. Each flute's immersion angle accounts for the helix lag.
- **Cutting coefficients:** chip ratio and shear angle come from empirical orthogonal relations. These are turned into the oblique cutting coefficients Ktc, Krc and Kac, plus edge coefficients Kte = 24 and Kre = 43.
- **Forces:** tangential, radial and axial force elements are resolved into Fx, Fy and Fz and summed over all slices and flutes.
- **Milling mode:** up-milling and down-milling set different entry and exit angles from the radial width of cut.

The two single-case scripts use the same model:

| Script | Case | Output |
|---|---|---|
| `millingforreverse.m` | 12 mm tool, 5 mm depth, half-diameter width | Fx, Fy and Fz over one revolution |
| `milling_torque_power.m` | 19.05 mm tool, 5.08 mm depth, 0.05 mm/tooth feed | Adds the resultant XY force, torque `T = Ft·R` and cutting power `P = Ft·Vc/60`, with maximum and mean values |

## Dataset

`MillingSimulation.m` sweeps the full grid below and writes `MillingSimulationResults2.xlsx`.

| Parameter | Values |
|---|---|
| Milling mode | 0 = up-milling, 1 = down-milling |
| Axial depth of cut (mm) | 2, 5, 6, 10, 11, 15 |
| Radial width of cut (mm) | 1, 4, 7, 10, 12 |
| Feed per tooth (mm) | 0.02, 0.05, 0.08, 0.10, 0.12, 0.15 |
| Angular position | 360 steps per revolution |

- **Size:** 2 × 6 × 5 × 6 × 360 = **129,600 rows**, each with Fx, Fy and Fz. On 14 October 2026 I checked that the file has exactly this grid.
- **No torque column.** The sweep stores Fx, Fy and Fz only; torque and power are computed in the single-case script `milling_torque_power.m`.
- **Full-slot rows are duplicated across modes.** At a 12 mm radial width (a full slot for a 12 mm tool), up- and down-milling have the same entry and exit angles (0° to 180°), so their 12,960 rows are identical. A reverse model cannot tell the milling mode apart for these rows.
- **Angle column:** the column labelled "Immersion Angle (degree)" stores the step index 1–360. The script samples one revolution with `linspace(0, 360, 360)`, so each step is about 1.003°.

## How to run

Requires MATLAB R2019a or later, because the sweep writes its output with `writecell`.

```matlab
cd matlab
millingforreverse        % plots Fx, Fy, Fz for one cutting condition
milling_torque_power     % adds resultant force, torque and power plots
MillingSimulation        % full sweep; writes MillingSimulationResults2.xlsx
```

The full sweep runs 360 sequential evaluations for each of the 360 parameter combinations, and each evaluation loops over every slice and flute, so expect it to take a while. The MATLAB scripts were not re-run for this repository because MATLAB was not available.

**Checking the dataset without MATLAB:** `python/verify_dataset.py` re-implements `MillingSimulation.m` in NumPy and compares it with the Excel file.

```bash
pip install numpy pandas openpyxl
python python/verify_dataset.py          # 8 combinations, under a minute
python python/verify_dataset.py --all    # all 360 combinations
```

On 20 October 2026 every combination matched the published dataset to within 1e-10 N (floating-point rounding), so the file is exactly what the MATLAB model produces.

## Changes since the project

- `milling_torque_power.m`: the XY resultant force summed the magnitudes of the element forces, which overstates the resultant whenever the elements point in different directions. It is now the magnitude of the summed vector, `sqrt(Fx.^2 + Fy.^2)` (the line was already in the script, commented out). For the script's case this lowers the mean resultant from 470 N to 449 N; the maximum barely moves (595 N to 592 N).
- `MillingSimulation.m`: the result matrix is preallocated instead of grown row by row, the final message names the file actually written, and the comments now call Kte, Kre and Kae edge coefficients and no longer describe the grid as "reduced for testing". The computed values are unchanged.

## Limitations

- Simulation only: the force model is not validated against measured forces here, and the cutting coefficients come from published empirical relations rather than calibration tests.
- One tool, one material and a 360-combination grid; cutting speed `Vc` does not enter the force model.
- `millingforreverse.m` uses a feed of 0.5 mm/tooth, ten times the 0.05 mm/tooth of the other single-case script and above the sweep's range; treat it as a demonstration case.

## Repository structure

```
matlab/MillingSimulation.m      parameter sweep -> Excel dataset
matlab/millingforreverse.m      single-case force model with plots
matlab/milling_torque_power.m   single case with torque and power (originally milliingg.m)
data/MillingSimulationResults2.xlsx   simulated dataset, 129,600 rows
python/verify_dataset.py        NumPy port of the sweep; checks the dataset
```

The project reports are not included because they contain other students' details. The reference papers are not included because of copyright.
