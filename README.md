<p align="center"><i>A growing collection of reusable Verilog cryptographic hardware cores.</i></p>

---

## About

CipherCore is a collection of cryptographic hardware cores written in synthesisable Verilog, aimed at **industrial deployment** and use as **reusable research artifacts**. The goal is to provide self-contained, well-documented, vendor-agnostic RTL that can be dropped into FPGA prototypes, ASIC flows, or academic work without modification.

Each core is designed to be:

- **Portable** — pure Verilog, no vendor primitives, no generated IP.
- **Reproducible** — every claim (simulation, synthesis, timing) is backed by a script in the repo.
- **Documented** — limitations and caveats are stated up front.
- **Composable** — cores can be used standalone or combined into larger cryptographic subsystems.

Target flows include open-source RTL-to-GDS (Yosys, OpenSTA, Sky130) as well as commercial FPGA toolchains.

---

## Getting Started

Clone the repository and run a core:

```sh
git clone https://github.com/OnyxRTL/CipherCore.git
cd CipherCore/chacha20

make sim                  # run all testbenches
make syn LIB=/path/to/sky130_fd_sc_hd__tt_025C_1v80.lib
make tim LIB=/path/to/sky130_fd_sc_hd__tt_025C_1v80.lib
```
Each core directory is self-contained. The `Makefile` in cores that support it drives simulation, pre-routing synthesis, and static timing analysis with a single command. Full details, caveats, and results are in each core's README.

---

## What's Inside

- **[ChaCha20](./chacha20/)** — parameterised ChaCha8/12/20 stream cipher core.
- **[Trivium](./trivium/)** — lightweight stream cipher core.

Each core has its own README with details on verification, synthesis, and usage.

---

## Contributing

Got a core to add, a bug to report, or an improvement in mind? Check out the [Contribution Guidelines](./Contribution.md) or start a [Discussion](../../discussions) — we'd love to hear from you.

---

## License

This project is licensed under the **Apache License 2.0** — see [LICENSE](./LICENSE) for details.
