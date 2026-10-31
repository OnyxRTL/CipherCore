# speck-verilog

A fully parameterized, combinational Verilog implementation of the **Speck** block cipher family. One source file covers all ten variants (Speck32/64 up to Speck128/256), selected purely by module parameters. Verified against the official test vectors for every variant, in both encrypt and decrypt directions.

## Selecting a Variant

Find your variant in the table and copy its parameter values into the module instantiation.

| Variant | Block | Key | `N` | `M` | `ALPHA` | `BETA` | `T` |
|---|---|---|---|---|---|---|---|
| Speck32/64   |  32 |  64 | 16 | 4 | 7 | 2 | 22 |
| Speck48/72   |  48 |  72 | 24 | 3 | 8 | 3 | 22 |
| Speck48/96   |  48 |  96 | 24 | 4 | 8 | 3 | 23 |
| Speck64/96   |  64 |  96 | 32 | 3 | 8 | 3 | 26 |
| Speck64/128  |  64 | 128 | 32 | 4 | 8 | 3 | 27 |
| Speck96/96   |  96 |  96 | 48 | 2 | 8 | 3 | 28 |
| Speck96/144  |  96 | 144 | 48 | 3 | 8 | 3 | 29 |
| Speck128/128 | 128 | 128 | 64 | 2 | 8 | 3 | 32 |
| Speck128/192 | 128 | 192 | 64 | 3 | 8 | 3 | 33 |
| Speck128/256 | 128 | 256 | 64 | 4 | 8 | 3 | 34 |

Block and key sizes are in bits. `N` = word size in bits (block = 2N, key = M x N), `M` = number of key words, `ALPHA` / `BETA` = right / left rotation amounts, `T` = number of rounds.

**Example:** for Speck128/256, read the row `N=64, M=4, ALPHA=8, BETA=3, T=34`:

```verilog
Encrypt #(.N(64), .M(4), .ALPHA(8), .BETA(3), .T(34)) u_encrypt ( /* ports */ );
```

All five parameters must be set together. Speck32/64 is the only variant that uses `ALPHA = 7` and `BETA = 2`, so forgetting to override them for Speck32/64 (the defaults are 8 and 3) silently gives a wrong cipher, with no error.

## Usage

`Encrypt` and `Decrypt` are standalone modules, each with its own key schedule. `Top` is an optional wrapper that contains both and selects the direction with `sel`. The examples below use the Speck64/128 row; replace the parameters with the row for your variant. Connect the ports to your own signals.

**Encrypt (standalone)**

```verilog
Encrypt #(.N(32), .M(4), .ALPHA(8), .BETA(3), .T(27)) u_encrypt (
    .data_in  ( /* plaintext block,  [2*N-1:0] */ ),
    .key      ( /* key,              [M*N-1:0] */ ),
    .data_out ( /* ciphertext block, [2*N-1:0] */ )
);
```

**Decrypt (standalone)**

```verilog
Decrypt #(.N(32), .M(4), .ALPHA(8), .BETA(3), .T(27)) u_decrypt (
    .data_in  ( /* ciphertext block, [2*N-1:0] */ ),
    .key      ( /* key,              [M*N-1:0] */ ),
    .data_out ( /* plaintext block,  [2*N-1:0] */ )
);
```

**Top (optional): encrypt or decrypt selected by `sel`**

```verilog
Top #(.N(32), .M(4), .ALPHA(8), .BETA(3), .T(27)) u_speck (
    .data_in  ( /* input block,  [2*N-1:0] */ ),
    .key      ( /* key,          [M*N-1:0] */ ),
    .sel      ( /* 1 = encrypt, 0 = decrypt  */ ),
    .data_out ( /* output block, [2*N-1:0] */ )
);
```

`Top` instantiates both datapaths and muxes the result, so use `Encrypt` or `Decrypt` directly if you only need one direction.

**Combinational design.** There is no clock. The key schedule and all rounds are unrolled, so larger variants are big and have a long critical path. Wrap the core in registers or an iterative round engine if you need to meet timing.

## Simulation-Based Verification

The core is validated against ten reference test vectors, one for each Speck variant, taken from Appendix C of the Speck paper ([Beaulieu et al., IACR ePrint 2013/404](https://eprint.iacr.org/2013/404)):

* **Speck32/64**, **Speck48/72**, **Speck48/96**, **Speck64/96**, **Speck64/128**
* **Speck96/96**, **Speck96/144**, **Speck128/128**, **Speck128/192**, **Speck128/256**

Each vector is run through `Top` in both directions: encrypting the plaintext must give the published ciphertext, and decrypting the ciphertext must give the plaintext back (20 checks in total).

A passing run ends with `ALL 10 VARIANTS PASSED`, and `make` exits with an error if any check fails.

## Security Note

This is a reference implementation and has not been reviewed for side-channel resistance. Do not rely on it to protect real secrets without your own review.

## Attribution

- **Algorithm:** R. Beaulieu, D. Shors, J. Smith, S. Treatman-Clark, B. Weeks, L. Wingers, *The SIMON and SPECK Families of Lightweight Block Ciphers*, IACR Cryptology ePrint Archive, 2013/404.
- **Code lineage:** derived from the Speck64/128 C reference implementation in the NSA's [simon-speck-supercop](https://github.com/nsacyber/simon-speck-supercop/blob/master/crypto_stream/speck64128ctr/ref/stream.c), translated to Verilog and generalized to all ten variants. The original is a US Government work, excluded from copyright under 17 U.S.C. 105, with related rights waived worldwide under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

## License

Apache License 2.0. See [LICENSE](LICENSE).
