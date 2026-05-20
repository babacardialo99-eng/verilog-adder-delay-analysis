#!/usr/bin/env python3
"""
Plot Number of bits vs delay_ns for all *_delay_sweep.csv files.

Changes vs your version:
- Linear axes
- Major ticks every 100 on BOTH axes
- Equal aspect ratio so 100 units on X == 100 units on Y physically
"""

import glob
import os
import sys

import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.ticker import MultipleLocator


def main():
    files = sorted(glob.glob("*_delay_sweep.csv"))
    if not files:
        print("No files matching '*_delay_sweep.csv' found in current directory.", file=sys.stderr)
        sys.exit(1)

    fig, ax = plt.subplots()

    max_x = 0.0
    max_y = 0.0

    for f in files:
        base = os.path.basename(f)
        label = base[:-len("_delay_sweep.csv")]

        df = pd.read_csv(f, skipinitialspace=True)
        cols = {c.strip(): c for c in df.columns}
        if "Number of bits" not in cols or "delay_ns" not in cols:
            raise ValueError(
                f"{base}: expected columns 'Number of bits' and 'delay_ns', got {list(df.columns)}"
            )

        x = df[cols["Number of bits"]].astype(float)
        y = df[cols["delay_ns"]].astype(float)

        mask = y >= 0
        x = x[mask]
        y = y[mask]

        if len(x) == 0:
            continue

        max_x = max(max_x, float(x.max()))
        max_y = max(max_y, float(y.max()))

        ax.plot(x, y, marker="o", linewidth=2, label=label)

    ax.set_xlabel("Number of bits")
    ax.set_ylabel("Delay (ns)")
    ax.set_title("Delay sweep comparison (linear, equal scaling)")

    # ---- Make 0-100, 100-200, ... equally spaced on BOTH axes ----
    ax.xaxis.set_major_locator(MultipleLocator(100))
    ax.yaxis.set_major_locator(MultipleLocator(100))

    # Optional minor ticks every 50 for readability
    ax.xaxis.set_minor_locator(MultipleLocator(50))
    ax.yaxis.set_minor_locator(MultipleLocator(50))

    ax.grid(True, which="major", linestyle="--", linewidth=0.7, alpha=0.7)
    ax.grid(True, which="minor", linestyle="--", linewidth=0.4, alpha=0.35)

    ax.legend(title="Design")

    # Add a little padding so the last point isn't on the border
    pad = 50
    ax.set_xlim(0, max_x + pad)
    ax.set_ylim(0, max_y + pad)

    # ---- Ensure 100 units in X == 100 units in Y (same physical spacing) ----
    ax.set_aspect("equal", adjustable="box")

    plt.tight_layout()
    plt.savefig("delay_sweep_comparison_linear_equal.png", dpi=300)
    plt.show()


if __name__ == "__main__":
    main()