// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 MrAbhi19
//
// tb_speck.v - Known-answer testbench for all 10 Speck variants.
//
// Drives Top (sel=1 encrypt, sel=0 decrypt) with the official test vectors
// from Appendix C of "The SIMON and SPECK Families of Lightweight Block
// Ciphers" (Beaulieu et al., 2013) and checks both directions.

`timescale 1ns/1ps

// One known-answer test for one Speck variant, through Top.
//   sel=1 : Top encrypts  -> must equal CT
//   sel=0 : Top decrypts  -> CT must give back PT
module speck_case #(
    parameter N     = 32,
    parameter M     = 4,
    parameter ALPHA = 8,
    parameter BETA  = 3,
    parameter T     = 27,
    parameter [M*N-1:0]   KEY  = 0,
    parameter [2*N-1:0]   PT   = 0,
    parameter [2*N-1:0]   CT   = 0,
    parameter             NAME = "speck"
)(
    output reg pass,
    output reg done
);

    reg  [2*N-1:0] din;
    reg            sel;
    wire [2*N-1:0] dout;

    Top #(.N(N), .M(M), .ALPHA(ALPHA), .BETA(BETA), .T(T)) dut (
        .data_in (din),
        .key     (KEY),
        .sel     (sel),
        .data_out(dout)
    );

    initial begin
        pass = 1'b1;
        done = 1'b0;
        sel  = 1'b1;
        din  = {2*N{1'b0}};

        // encrypt
        #1;
        sel = 1'b1;
        din = PT;
        #1;
        if (dout !== CT) begin
            pass = 1'b0;
            $display("FAIL %0s encrypt: got %h expected %h", NAME, dout, CT);
        end else
            $display("PASS %0s encrypt: %h", NAME, dout);

        // decrypt
        sel = 1'b0;
        din = CT;
        #1;
        if (dout !== PT) begin
            pass = 1'b0;
            $display("FAIL %0s decrypt: got %h expected %h", NAME, dout, PT);
        end else
            $display("PASS %0s decrypt: %h", NAME, dout);

        done = 1'b1;
    end
endmodule


module tb_speck;

    wire [9:0] pass, done;

    //                     N   M  A  B  T
    speck_case #(16, 4, 7, 2, 22,
        64'h1918_1110_0908_0100,
        32'h6574_694c,
        32'ha868_42f2, "Speck32/64")   c0 (pass[0], done[0]);

    speck_case #(24, 3, 8, 3, 22,
        72'h121110_0a0908_020100,
        48'h20796c_6c6172,
        48'hc049a5_385adc, "Speck48/72")   c1 (pass[1], done[1]);

    speck_case #(24, 4, 8, 3, 23,
        96'h1a1918_121110_0a0908_020100,
        48'h6d2073_696874,
        48'h735e10_b6445d, "Speck48/96")   c2 (pass[2], done[2]);

    speck_case #(32, 3, 8, 3, 26,
        96'h13121110_0b0a0908_03020100,
        64'h74614620_736e6165,
        64'h9f7952ec_4175946c, "Speck64/96")   c3 (pass[3], done[3]);

    speck_case #(32, 4, 8, 3, 27,
        128'h1b1a1918_13121110_0b0a0908_03020100,
        64'h3b726574_7475432d,
        64'h8c6fa548_454e028b, "Speck64/128")  c4 (pass[4], done[4]);

    speck_case #(48, 2, 8, 3, 28,
        96'h0d0c0b0a0908_050403020100,
        96'h65776f68202c_656761737520,
        96'h9e4d09ab7178_62bdde8f79aa, "Speck96/96")   c5 (pass[5], done[5]);

    speck_case #(48, 3, 8, 3, 29,
        144'h151413121110_0d0c0b0a0908_050403020100,
        96'h656d6974206e_69202c726576,
        96'h2bf31072228a_7ae440252ee6, "Speck96/144")  c6 (pass[6], done[6]);

    speck_case #(64, 2, 8, 3, 32,
        128'h0f0e0d0c0b0a0908_0706050403020100,
        128'h6c61766975716520_7469206564616d20,
        128'ha65d985179783265_7860fedf5c570d18, "Speck128/128") c7 (pass[7], done[7]);

    speck_case #(64, 3, 8, 3, 33,
        192'h1716151413121110_0f0e0d0c0b0a0908_0706050403020100,
        128'h7261482066656968_43206f7420746e65,
        128'h1be4cf3a13135566_f9bc185de03c1886, "Speck128/192") c8 (pass[8], done[8]);

    speck_case #(64, 4, 8, 3, 34,
        256'h1f1e1d1c1b1a1918_1716151413121110_0f0e0d0c0b0a0908_0706050403020100,
        128'h65736f6874206e49_202e72656e6f6f70,
        128'h4109010405c0f53e_4eeeb48d9c188f43, "Speck128/256") c9 (pass[9], done[9]);

    initial begin
        #10;
        if (done !== 10'h3ff)
            $display("TIMEOUT: not all cases finished (done=%b)", done);
        else if (pass === 10'h3ff)
            $display("ALL 10 VARIANTS PASSED");
        else
            $display("SOME VARIANTS FAILED (pass=%b)", pass);
        $finish;
    end

endmodule
