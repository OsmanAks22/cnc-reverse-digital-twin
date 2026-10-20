"""Check the MATLAB dataset against an independent NumPy port of MillingSimulation.m.

Usage:
    pip install numpy pandas openpyxl
    python python/verify_dataset.py [data/MillingSimulationResults2.xlsx] [--all]

By default eight parameter combinations are recomputed (six random plus the
smallest and largest cut). With --all, every one of the 360 combinations is
checked (a few minutes). The port follows the MATLAB script line for line,
vectorised over angular steps and axial slices.
"""
import sys
from pathlib import Path

import numpy as np
import pandas as pd

R, N, HELIX, RAKE, TAU = 12 / 2, 4, 30.0, 12.0, 613.0
BETAN = 19.1 + 0.29 * RAKE
KTE, KRE, KAE = 24.0, 43.0, 0.0
D = np.deg2rad


def simulate(condition: int, doc: float, woc: float, f: float) -> np.ndarray:
    """Return Fx, Fy, Fz (3 x 360) for one cutting condition, as MillingSimulation.m does."""
    s_n = round(doc / 0.001)
    dz = doc / s_n
    phi = np.linspace(0, 360, 360)
    if condition == 1:  # down-milling
        st, ex = 180 - np.rad2deg(np.arccos(1 - woc / R)), 180.0
    else:               # up-milling
        st, ex = 0.0, np.rad2deg(np.arccos(1 - woc / R))
    lag = np.tan(D(HELIX)) / R
    z = np.arange(1, s_n + 1) * dz
    forces = np.zeros((3, 360))
    for k in range(N):
        tip = np.mod(phi + k * 360 / N, 360)
        pz = np.mod(tip[:, None] - np.rad2deg(lag * z)[None, :], 360)
        engaged = (st <= pz) & (pz <= ex)
        h = np.where(engaged, f * np.sin(D(pz)), f)  # placeholder where not engaged
        r = (1.755 - 0.028 * RAKE) * h ** (0.331 - 0.0082 * RAKE)
        shear = np.rad2deg(np.arctan2(r * np.cos(D(RAKE)), 1 - r * np.sin(D(RAKE))))
        c = np.sqrt(np.cos(D(shear + BETAN - RAKE)) ** 2 + np.tan(D(HELIX)) ** 2 * np.sin(D(BETAN)) ** 2)
        krc = TAU / np.sin(D(shear)) / np.cos(D(HELIX)) * np.sin(D(BETAN - RAKE)) / c
        ktc = TAU / np.sin(D(shear)) * (np.cos(D(BETAN - RAKE)) + np.tan(D(HELIX)) ** 2 * np.sin(D(BETAN))) / c
        kac = TAU / np.sin(D(shear)) * (np.cos(D(BETAN - RAKE)) * np.tan(D(HELIX)) - np.tan(D(HELIX)) * np.sin(D(BETAN))) / c
        dft, dfr, dfa = dz * (ktc * h + KTE), dz * (krc * h + KRE), dz * (kac * h + KAE)
        dfx = -dft * np.cos(D(pz)) - dfr * np.sin(D(pz))
        dfy = dft * np.sin(D(pz)) - dfr * np.cos(D(pz))
        for i, comp in enumerate((dfx, dfy, -dfa)):
            forces[i] += np.where(engaged, comp, 0.0).sum(axis=1)
    return forces


def main() -> None:
    args = [a for a in sys.argv[1:] if a != "--all"]
    path = Path(args[0]) if args else Path(__file__).resolve().parent.parent / "data" / "MillingSimulationResults2.xlsx"
    df = pd.read_excel(path)
    df.columns = ["cond", "doc", "woc", "f", "step", "Fx", "Fy", "Fz"]
    combos = df[["cond", "doc", "woc", "f"]].drop_duplicates()
    print(f"{len(df):,} rows, {len(combos)} parameter combinations x {df.step.nunique()} steps")
    if "--all" not in sys.argv:
        combos = pd.concat([combos.sample(6, random_state=3), combos.iloc[[0, -1]]])
    worst = 0.0
    for cond, doc, woc, f in combos.itertuples(index=False):
        sub = df[(df.cond == cond) & (df.doc == doc) & (df.woc == woc) & np.isclose(df.f, f)].sort_values("step")
        diff = np.abs(simulate(int(cond), doc, woc, f) - sub[["Fx", "Fy", "Fz"]].to_numpy().T).max()
        worst = max(worst, diff)
        print(f"mode={int(cond)} doc={doc:g} woc={woc:g} f={f:g}: max |difference| = {diff:.2e} N")
    print(f"Largest difference: {worst:.2e} N")


if __name__ == "__main__":
    main()
