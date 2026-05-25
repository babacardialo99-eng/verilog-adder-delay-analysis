# Project 3: Parallel Adder Delay Analysis — CBA, CSA, RCA & VWCSA

Verilog implementation and critical-path delay analysis of four parallel adder
topologies designed as part of CSE320 (Digital Logic / FPGA Design).

## Adder Topologies
| Design | Full Name | Delay Scaling |
|--------|-----------|---------------|
| RCA | Ripple Carry Adder | Linear — worst (carry ripples through every stage) |
| CBA | Carry Bypass Adder | Sub-linear — groups bits into blocks to skip carry |
| CSA | Carry Select Adder | Improved — precomputes both carry-in possibilities and selects using multiplexers |
| VWCSA | Variable-Width Carry Select Adder | Best — optimized stage widths for minimal delay |

Performance (fastest → slowest): VWCSA → CSA → CBA → RCA

## Files
| File | Description |
|------|-------------|
| `generic_adder_design_rca.v` | Parameterized RCA — N-bit ripple carry adder |
| `generic_adder_design_cba.v` | Parameterized CBA — carry bypass adder |
| `generic_adder_design_csa.v` | Parameterized CSA — carry select adder |
| `vwcsa.v` | Variable-width carry select adder |
| `rca_delay_tb.v` | Testbench — sweeps RCA across bit widths, logs delay |
| `cba_delay_tb.v` | Testbench — sweeps CBA across bit widths, logs delay |
| `csa_delay_tb.v` | Testbench — sweeps CSA across bit widths, logs delay |
| `vwcsa_delay_tb.v` | Testbench — sweeps VWCSA across bit widths, logs delay |
| `RCA_delay_sweep.csv` | RCA critical-path delay results (16–256 bits) |
| `CBA_delay_sweep.csv` | CBA critical-path delay results (4–256 bits) |
| `CSA_delay_sweep.csv` | CSA critical-path delay results (4–256 bits) |
| `VWCSA_delay_sweep.csv` | VWCSA critical-path delay results (1–210 bits) |
| `delay_plot.py` | Python script — plots all 4 topologies on one chart |
| `delay_sweep_comparison_linear_equal.png` | Output plot — delay vs. bit width comparison |

## Critical Path Delay Results (256-bit Adders)
| Design | Critical Path Delay |
|--------|-------------------|
| RCA | 385.00 ns |
| CBA | 138.00 ns |
| CSA | 135.00 ns |
| VWCSA | ~47.00 ns |

## How to Simulate (Icarus Verilog)
```bash
# RCA
iverilog -o rca.vvp generic_adder_design_rca.v rca_delay_tb.v && vvp rca.vvp

# CBA
iverilog -o generic_adder_design_cba.vvp generic_adder_design_cba.v cba_delay_tb.v && vvp generic_adder_design_cba.vvp

# CSA
iverilog -o generic_adder_design_csa.vvp generic_adder_design_csa.v csa_delay_tb.v && vvp generic_adder_design_csa.vvp

# VWCSA
iverilog -o vwcsa.vvp vwcsa.v vwcsa_delay_tb.v && vvp vwcsa.vvp
```

## How to Plot
```bash
python3 delay_plot.py
```

## Tools Used
- Icarus Verilog (simulation)
- Python + Matplotlib (delay comparison plot)
- AMD Vivado (synthesis & FPGA implementation)
