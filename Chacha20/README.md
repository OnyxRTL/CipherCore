# ChaCha20 Key Stream Generator

## Overview

This directory contains a parameterized **Verilog implementation** of the **ChaCha key stream generator**. The number of rounds is set with the `ITERATIONS` parameter of the `chacha20` module, where each iteration is one double round (a column round followed by a diagonal round), so the core implements **ChaCha-(2 × `ITERATIONS`)**:

| `ITERATIONS` | Variant |
|---|---|
| 4 | ChaCha8 |
| 6 | ChaCha12 |
| 10 (default) | ChaCha20 |

Other values give other round counts (valid range: 1 to 16, limited by the 5-bit round counter). The core is iterative: it processes one round stage per clock cycle, so one 512-bit block takes about `8 × ITERATIONS` cycles plus a few cycles of load, final-add and output overhead.

## Simulation-Based Verification

The core is validated against four reference test vectors:

* **ChaCha8:** 1 vector from the *ChaCha Test Vectors* Internet-Draft by Martin Storsjö and Joachim Strömbergson ([draft-strombergson-chacha-test-vectors-00](https://datatracker.ietf.org/doc/html/draft-strombergson-chacha-test-vectors-00)).
* **ChaCha12:** 1 vector from the same Internet-Draft.
* **ChaCha20:** 2 vectors from [RFC 8439](https://datatracker.ietf.org/doc/html/rfc8439) (Sections 2.3.2 and 2.4.2).

To run all three testbenches (requires [Icarus Verilog](https://github.com/steveicarus/iverilog)):

```sh
make sim
```

Each testbench prints `[PASS]` or `[FAIL]` per vector. Waveforms are written to `build/sim_results/` as `.vcd` files.

## Pre-Routing Synthesis & Timing Results

Area and timing were estimated with an open-source flow (Yosys for synthesis, OpenSTA for timing) targeting three different standard-cell libraries: the SkyWater **sky130_fd_sc_hd** library, the IHP **SG13G2** open SiGe BiCMOS library, and the open academic **Nangate45** library. These are **pre-routing** numbers and should be treated as early estimates, not signoff results.

### Configuration

| Item | Sky130 | IHP SG13G2 | Nangate45 |
|---|---|---|---|
| Top module | `chacha20` | `chacha20` | `chacha20` |
| Configuration | `ITERATIONS = 10` (ChaCha20, 10 double rounds) | `ITERATIONS = 10` (ChaCha20, 10 double rounds) | `ITERATIONS = 10` (ChaCha20, 10 double rounds) |
| Synthesis | Yosys 0.66 (`synth`, `flatten`, `dfflibmap`, `abc -fast`) | Yosys 0.66 (`synth`, `flatten`, `dfflibmap`, `abc -fast`) | Yosys 0.66 (`synth`, `flatten`, `dfflibmap`, `abc -fast`) |
| Technology | sky130_fd_sc_hd | sg13g2_stdcell | NangateOpenCellLibrary |
| Liberty file | `sky130_fd_sc_hd__tt_025C_1v80.lib` | `sg13g2_stdcell_typ_1p20V_25C.lib` | `NangateOpenCellLibrary_typical.lib` |
| Nominal voltage | 1.80 V | 1.20 V | 1.10 V |
| Corner | TT, 25 °C, 1.80 V | typ, 25 °C, 1.20 V | typical |
| Input driving cell | `sky130_fd_sc_hd__buf_4` (see `constr.txt`) | `sg13g2_buf_4` (see `constr.txt`) | `BUF_X4` (see `constr.txt`) |
| Timing tool | OpenSTA 3.1.0 | OpenSTA 3.1.0 | OpenSTA 3.1.0 |

### Area

| Metric | Sky130 | IHP SG13G2 | Nangate45 |
|---|---|---|---|
| Total cell count | 17,470 | 17,513 | 16,732 |
| Total chip area | 116,297.79 µm² (≈ 0.116 mm²) | 230,656.36 µm² (≈ 0.231 mm²) | 25,199.24 µm² (≈ 0.025 mm²) |
| Sequential area | 38,757.17 µm² (33.33 %) | 94,842.32 µm² (41.12 %) | 8,754.59 µm² (34.74 %) |
| Combinational area | ≈ 77,540.62 µm² (66.67 %) | ≈ 135,814.04 µm² (58.88 %) | ≈ 16,444.65 µm² (65.26 %) |
| Flip-flops | 1,936 (`dfxtp_1`) | 1,936 (`sg13g2_dfrbpq_1`) | 1,936 (`DFF_X1`) |

### Timing (Pre-Routing)

| Metric | Sky130 | IHP SG13G2 | Nangate45 |
|---|---|---|---|
| Target clock period (virtual) | 1.00 ns | 1.00 ns | 1.00 ns |
| Worst slack at target | −8.644 ns | −5.054 ns | −1.401 ns |
| Minimum clock period | 9.644 ns | 6.054 ns | 2.401 ns |
| **Estimated Fmax** | **103.69 MHz** | **165.18 MHz** | **416.49 MHz** |

A deliberately aggressive 1 ns (1 GHz) clock is applied to all three runs so the design always violates timing. The achievable Fmax is then derived as `1 / (1.00 ns − WNS)`.

### Worst Path Analysis

**All three PDKs report the same structural bottleneck** — a **high-fanout net driven by a launching flip-flop** — even though the absolute path and technology differ. In each case the launching flop drives a ~513-fanout net, and the vast majority of the total delay is that single clock-to-Q + fanout cost, not the logic downstream.

**Sky130** (`_31557_` → `_32382_`): roughly 8.2 ns of the 9.5 ns arrival time is the launching `dfxtp_1` clock-to-Q delay, driven by a heavily loaded output (about 1.23 pF load, 11.3 ns slew).

**IHP SG13G2** (`_31647_` → `_31159_`):

| Stage | Cell | Cumulative delay (ns) |
|---|---|---|
| Launch | `sg13g2_dfrbpq_1` (fanout 513, ~1.59 pF load, 6.41 ns slew) | 4.55 |
| | `sg13g2_inv_1` | 5.39 |
| | `sg13g2_buf_1` | 5.65 |
| | `sg13g2_buf_1` | 5.81 |
| | `sg13g2_nand2_1` | 5.86 |
| | `sg13g2_a21oi_1` | 5.91 |
| Capture | `sg13g2_dfrbpq_1` (`_31159_/D`) | 5.91 |

Of the 5.91 ns total, **4.55 ns is the launching flop's clock-to-Q delay** while driving its 513-fanout net — the downstream logic adds only ~1.36 ns. IHP's `dfrbpq_1` is a much slower launch point than Nangate45's `DFF_X1` under the same fanout (~1.59 pF vs ~0.85 pF), so the fanout-driven delay is over 2× larger.

**Nangate45** (`_32021_` → `_31669_`):

| Stage | Cell | Cumulative delay (ns) |
|---|---|---|
| Launch | `DFF_X1` (fanout 513, ~854 fF load) | 2.12 |
| | `INV_X1` | 2.10 |
| | `BUF_X1` | 2.24 |
| | `CLKBUF_X1` | 2.32 |
| | `NAND2_X1` | 2.34 |
| | `AOI21_X1` | 2.35 |
| Capture | `DFF_X1` (`_31669_/D`) | 2.35 |

Of the 2.35 ns total, ~2.12 ns is the launching `DFF_X1` clock-to-Q plus fanout cost; the logic adds only ~0.23 ns.

**Takeaway across all three PDKs:** the bottleneck is a **high-fanout control signal**, not logic depth. Register replication, a dedicated buffer tree on that net, or reducing the fanout at the source is likely to improve Fmax substantially on every PDK — and the relative ranking (Nangate45 > IHP > Sky130 in this pre-route estimate) is driven mostly by how each library's flop drives a heavy fanout, not by logic complexity.

### Caveats

* Ideal clock network (no clock tree, skew, or uncertainty).
* No wire parasitics or placement information (pre-route).
* Single typical corner per PDK: Sky130 TT/25 °C/1.80 V, IHP typ/25 °C/1.20 V, Nangate45 typical. No slow/fast corners.
* **Nominal supply voltages differ** across the three PDKs (1.80 V / 1.20 V / 1.10 V), so the Fmax numbers are **not** an apples-to-apples voltage-normalized comparison.
* Synthesis used `abc -fast`, not a timing-driven optimization effort.
* I/O delays are not constrained (OpenSTA reports 386 input ports without input delay, 514 output ports without output delay, and 514 unconstrained endpoints). Only the register-to-register path is reported.
* Only the `ITERATIONS = 10` (ChaCha20) configuration was synthesized for all three PDKs; ChaCha8 and ChaCha12 results are not included.
* The absolute area and timing numbers are **not directly comparable across PDKs** — cell libraries differ in drive strength, footprint, and characterization. Compare each PDK only against other designs synthesized on the *same* PDK.

### Reproducing the Results

Requires [Yosys](https://github.com/YosysHQ/yosys), [OpenSTA](https://github.com/The-OpenROAD-Project/OpenSTA), and the Liberty file of the target library.

**Sky130:**
```sh
# 1. Verify the Liberty file exists
export LIB=/abs/path/to/sky130_fd_sc_hd__tt_025C_1v80.lib
test -f "$LIB" && echo "LIB OK" || echo "LIB not found"

# 2. Synthesis, then pre-route timing
make syn
make tim
```

**IHP SG13G2:**
```sh
# 1. Verify the Liberty file exists
export LIB=/abs/path/to/sg13g2_stdcell_typ_1p20V_25C.lib
test -f "$LIB" && echo "LIB OK" || echo "LIB not found"

# 2. Synthesis, then pre-route timing
make syn
make tim
```

**Nangate45:**
```sh
# 1. Verify the Liberty file exists
export LIB=/abs/path/to/NangateOpenCellLibrary_typical.lib
test -f "$LIB" && echo "LIB OK" || echo "LIB not found"

# 2. Synthesis, then pre-route timing
make syn
make tim
```

(`LIB` can also be passed per command, e.g. `make syn LIB=/abs/path/to/...lib`. Both targets stop with an error if it is unset or the file is missing.)

Outputs are written to `build/reports/`:

| File | Contents |
|---|---|
| `report.txt` | Cell count and area (Yosys `stat`) |
| `netlist.v` | Synthesized gate-level netlist |
| `yosys.log` / `sta.log` | Full tool logs (including the Fmax summary) |
| `worst_path.rpt` | Worst setup path from OpenSTA |
