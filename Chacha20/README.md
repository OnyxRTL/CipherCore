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

Area and timing were estimated with an open-source flow (Yosys for synthesis, OpenSTA for timing) targeting the SkyWater **sky130_fd_sc_hd** standard-cell library. These are **pre-routing** numbers and should be treated as early estimates, not signoff results.

### Configuration

| Item | Value |
|---|---|
| Top module | `chacha20` |
| Configuration | `ITERATIONS = 10` (ChaCha20, 10 double rounds) |
| Synthesis | Yosys 0.66 (`synth`, `flatten`, `dfflibmap`, `abc -fast`) |
| Technology | sky130_fd_sc_hd, `tt_025C_1v80` corner |
| Input driving cell | `sky130_fd_sc_hd__buf_4` (see `constr.txt`) |
| Timing tool | OpenSTA 3.1.0 |

### Area

| Metric | Value |
|---|---|
| Total cell count | 17,470 |
| Total chip area | 116,297.79 µm² (≈ 0.116 mm²) |
| Sequential area | 38,757.17 µm² (33.33 %) |
| Combinational area | ≈ 77,540.62 µm² (66.67 %) |
| Flip-flops (`dfxtp_1`) | 1,936 |

### Timing (Pre-Routing)

| Metric | Value |
|---|---|
| Target clock period (virtual) | 1.00 ns |
| Worst slack at target | −8.644 ns |
| Minimum clock period | 9.644 ns |
| **Estimated Fmax** | **103.69 MHz** |

A deliberately aggressive 1 ns (1 GHz) clock is applied so the design always violates timing. The achievable Fmax is then derived as `1 / (1.00 ns − WNS)`.

The worst path runs flop-to-flop (`_31557_` → `_32382_`). Roughly 8.2 ns of its 9.5 ns arrival time is the launching `dfxtp_1` clock-to-Q delay, driven by a heavily loaded output (about 1.23 pF load, 11.3 ns slew). This suggests the limit comes from a high-fanout net (likely a control signal) rather than deep logic, so buffering or fanout optimization is likely to improve Fmax noticeably.

### Caveats

* Ideal clock network (no clock tree, skew, or uncertainty).
* No wire parasitics or placement information (pre-route).
* Single typical corner (TT, 25 °C, 1.8 V); no slow/fast corners.
* Synthesis used `abc -fast`, not a timing-driven optimization effort.
* I/O delays are not constrained (OpenSTA reports 386 input ports without input delay, 514 output ports without output delay, and 514 unconstrained endpoints). Only the register-to-register path is reported.
* Only the `ITERATIONS = 10` (ChaCha20) configuration was synthesized; ChaCha8 and ChaCha12 results are not included.

### Reproducing the Results

Requires [Yosys](https://github.com/YosysHQ/yosys), [OpenSTA](https://github.com/The-OpenROAD-Project/OpenSTA), and the sky130 `sky130_fd_sc_hd__tt_025C_1v80.lib` Liberty file. Set `LIB` to the absolute path of the Liberty file:

```sh
# 1. Verify the Liberty file exists
export LIB=/abs/path/to/sky130_fd_sc_hd__tt_025C_1v80.lib
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
