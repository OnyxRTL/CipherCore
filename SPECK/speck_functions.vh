// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 MrAbhi19
//
// speck_functions.vh - Parameterized Speck round functions.
//
// Verilog functions cannot take parameters of their own, so this file is
// `include'd INSIDE a module and uses that module's parameters. The including
// module must declare these BEFORE the `include line:
//
//   N      word size in bits (16, 24, 32, 48 or 64)
//   ALPHA  right-rotation amount (7 for Speck32, 8 for all others)
//   BETA   left-rotation amount  (2 for Speck32, 3 for all others)

// Rotate an N-bit word right by r bits (0 < r < N).
function [N-1:0] ROR;
    input [N-1:0] x;
    input integer r;
    begin
        ROR = (x >> r) | (x << (N - r));
    end
endfunction

// Rotate an N-bit word left by r bits (0 < r < N).
function [N-1:0] ROL;
    input [N-1:0] x;
    input integer r;
    begin
        ROL = (x << r) | (x >> (N - r));
    end
endfunction

// Speck encryption round, also used by the key schedule. Returns {x', y'}:
//   x' = (ROR(x, ALPHA) + y) ^ k
//   y' = ROL(y, BETA) ^ x'
function [2*N-1:0] ROUND;
    input [N-1:0] x, y, k;
    reg   [N-1:0] next_x, next_y;
    begin
        next_x = (ROR(x, ALPHA) + y) ^ k;
        next_y = ROL(y, BETA) ^ next_x;
        ROUND  = {next_x, next_y};
    end
endfunction

// Inverse of ROUND, used for decryption. Returns {x, y}:
//   y = ROR(y' ^ x', BETA)
//   x = ROL((x' ^ k) - y, ALPHA)
function [2*N-1:0] ROUND_INV;
    input [N-1:0] x, y, k;
    reg   [N-1:0] next_x, next_y;
    begin
        next_y    = ROR(y ^ x, BETA);
        next_x    = ROL((x ^ k) - next_y, ALPHA);
        ROUND_INV = {next_x, next_y};
    end
endfunction
