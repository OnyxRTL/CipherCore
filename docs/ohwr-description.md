CipherCore is a collection of cryptographic hardware cores written in synthesisable Verilog, aimed at industrial deployment and use as reusable research artifacts.

The repository provides self-contained, well-documented, vendor-agnostic RTL that can be dropped into FPGA prototypes, ASIC flows, or academic work without modification. Every claim — simulation, synthesis, timing — is backed by a script in the repository.

Currently includes: 

- **ChaCha20** — a parameterised ChaCha8/ChaCha12/ChaCha20 stream cipher core, verified against RFC 8439 and IETF draft test vectors, with Sky130 HD synthesis and pre-route static timing analysis results.
- **Trivium** — a lightweight stream cipher core with simulation-based verification.

Target flows include open-source RTL-to-GDS (Yosys, OpenSTA, Sky130)
