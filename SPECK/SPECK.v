// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 MrAbhi19
//
// speck.v - Fully parameterized, combinational Speck block cipher.
//
// One source covers all ten Speck variants. Select a variant with the five
// parameters below (see the table in README.md):
//
//   N      word size in bits
//   M      number of key words
//   ALPHA  right-rotation amount
//   BETA   left-rotation amount
//   T      number of rounds
//
// Modules:
//   ExpandKey  key schedule (generate branch per M = 2, 3, 4)
//   Encrypt    T rounds of ROUND
//   Decrypt    T rounds of ROUND_INV, last round key first
//   Top        Encrypt and Decrypt in parallel; sel=1 -> encrypt, sel=0 -> decrypt
//
// All logic is purely combinational (no clock).

module ExpandKey #(
    parameter N     = 32,
    parameter M     = 4,
    parameter ALPHA = 8,
    parameter BETA  = 3,
    parameter T     = 27
)(
    input  [M*N-1:0] key_in,    // {l[M-2] ... l[0], k0}, k0 in the low word
    output [T*N-1:0] key_out
);

    `include "speck_functions.vh"

    reg [T*N-1:0] key;
    reg [N-1:0]   A, B, C, D;   // A = running round key, B/C/D = the l words
    reg [2*N-1:0] tmp;
    integer i;

/* verilator lint_off WIDTH */
    generate
        if (M == 2) begin : g_m2
            always @(*) begin
                key = {T*N{1'b0}};
                A = key_in[N-1:0];
                B = key_in[2*N-1:N];
                for (i = 0; i < T; i = i + 1) begin
                    key[i*N +: N] = A;
                    tmp = ROUND(B, A, i);
                    {B, A} = tmp;
                end
            end
        end
        else if (M == 3) begin : g_m3
            always @(*) begin
                key = {T*N{1'b0}};
                A = key_in[N-1:0];
                B = key_in[2*N-1:N];
                C = key_in[3*N-1:2*N];
                for (i = 0; i < T; i = i + 2) begin
                    key[i*N +: N] = A;
                    tmp = ROUND(B, A, i);
                    {B, A} = tmp;
                    if (i + 1 < T) begin
                        key[(i+1)*N +: N] = A;
                        tmp = ROUND(C, A, i + 1);
                        {C, A} = tmp;
                    end
                end
            end
        end
        else begin : g_m4
            always @(*) begin
                key = {T*N{1'b0}};
                A = key_in[N-1:0];
                B = key_in[2*N-1:N];
                C = key_in[3*N-1:2*N];
                D = key_in[4*N-1:3*N];
                for (i = 0; i < T; i = i + 3) begin
                    key[i*N +: N] = A;
                    tmp = ROUND(B, A, i);
                    {B, A} = tmp;
                    if (i + 1 < T) begin
                        key[(i+1)*N +: N] = A;
                        tmp = ROUND(C, A, i + 1);
                        {C, A} = tmp;
                    end
                    if (i + 2 < T) begin
                        key[(i+2)*N +: N] = A;
                        tmp = ROUND(D, A, i + 2);
                        {D, A} = tmp;
                    end
                end
            end
        end
    endgenerate
/* verilator lint_on WIDTH */

    assign key_out = key;

endmodule


module Encrypt #(
    parameter N     = 32,
    parameter M     = 4,
    parameter ALPHA = 8,
    parameter BETA  = 3,
    parameter T     = 27
)(
    input      [2*N-1:0] data_in,   // {x, y}: x in the high word, y in the low word
    input      [M*N-1:0] key,
    output reg [2*N-1:0] data_out
);

    `include "speck_functions.vh"

    wire [T*N-1:0] extended_key;

    ExpandKey #(
        .N(N), .M(M), .ALPHA(ALPHA), .BETA(BETA), .T(T)
    ) u_expand (
        .key_in (key),
        .key_out(extended_key)
    );

    integer i;

    always @(*) begin
        data_out = data_in;
        for (i = 0; i < T; i = i + 1) begin
            data_out = ROUND(data_out[2*N-1 -: N],   // x (high word)
                             data_out[N-1 : 0],      // y (low word)
                             extended_key[i*N +: N]);
        end
    end
endmodule

module Decrypt #(
    parameter N     = 32,
    parameter M     = 4,
    parameter ALPHA = 8,
    parameter BETA  = 3,
    parameter T     = 27
)(
    input      [2*N-1:0] data_in,
    input      [M*N-1:0] key,
    output reg [2*N-1:0] data_out
);

    `include "speck_functions.vh"

    wire [T*N-1:0] extended_key;

    ExpandKey #(.N(N), .M(M), .ALPHA(ALPHA), .BETA(BETA), .T(T)) u_expand (
        .key_in (key),
        .key_out(extended_key)
    );

    integer i;

    always @(*) begin
        data_out = data_in;
        for (i = T-1; i >= 0; i = i - 1) begin
            data_out = ROUND_INV(data_out[2*N-1 -: N],
                                 data_out[N-1 : 0],
                                 extended_key[i*N +: N]);
        end
    end
endmodule

//-----------------------------------------------------------------------------
// Top: encrypt/decrypt selectable by `sel`.
//   sel = 1 : data_out = Encrypt(data_in)
//   sel = 0 : data_out = Decrypt(data_in)
// Both datapaths are instantiated; the output is muxed.
//-----------------------------------------------------------------------------
module Top #(
    parameter N     = 32,
    parameter M     = 4,
    parameter ALPHA = 8,
    parameter BETA  = 3,
    parameter T     = 27
)(
    input  [2*N-1:0] data_in,
    input  [M*N-1:0] key,
    input            sel,
    output [2*N-1:0] data_out
);

    wire [2*N-1:0] out_en, out_de;

    Encrypt #(
        .N(N), .M(M), .ALPHA(ALPHA), .BETA(BETA), .T(T)
    ) dut(
        .data_in(data_in),
        .key(key),
        .data_out(out_en)
    );

    Decrypt #(
        .N(N), .M(M), .ALPHA(ALPHA), .BETA(BETA), .T(T)
    ) dut1(
        .data_in(data_in),
        .key(key),
        .data_out(out_de)
    );

    assign data_out = sel ? out_en : out_de;

endmodule
