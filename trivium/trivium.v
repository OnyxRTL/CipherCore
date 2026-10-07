`timescale 1ns / 1ps
//==============================================================================
// Copyright (c) 2026 opensiliconhub contributors
// SPDX-License-Identifier : Apache-2.0
//
// Module: trivium
// Description: Trivium Stream Cipher -- Spec-compliant implementation.
// Reference: C. De Canniere, B. Preneel, "Trivium Specifications",
//            eSTREAM submission (Profile 2 / hardware), ISO/IEC 29192-3.
//==============================================================================
//
// State is held as three shift registers, here named regA, regB, regC,
// corresponding to the spec's (s1..s93), (s94..s177), (s178..s288).
// Local indexing is 0-based: regA[0] == s1, regA[92] == s93, etc.
//
// Per-cycle equations (spec, 1-indexed):
//   t1 = s66  + s93                       t1 = regA[65] ^ regA[92]
//   t2 = s162 + s177                      t2 = regB[68] ^ regB[83]
//   t3 = s243 + s288                      t3 = regC[65] ^ regC[110]
//   z  = t1 + t2 + t3
//   t1 = t1 + s91*s92  + s171             t1 += regA[90]&regA[91] ^ regB[77]
//   t2 = t2 + s175*s176 + s264            t2 += regB[81]&regB[82] ^ regC[86]
//   t3 = t3 + s286*s287 + s69             t3 += regC[108]&regC[109] ^ regA[68]
//   (s1..s93)    <- (t3, s1..s92)         regA <- {regA[91:0], t3}
//   (s94..s177)  <- (t1, s94..s176)       regB <- {regB[82:0], t1}
//   (s178..s288) <- (t2, s178..s287)      regC <- {regC[109:0], t2}
//
// Key/IV/state setup (spec):
//   (s1..s93)    <- (K1..K80, 0..0)        regA <- {13'b0, key}      (key in LOW bits, i.e. s1=K1)
//   (s94..s177)  <- (IV1..IV80, 0..0)      regB <- {4'b0,  iv}
//   (s178..s288) <- (0..0, 1,1,1)          regC <- {3'b111, 108'b0}  (s286=s287=s288=1, i.e. TOP 3 bits)
//   Then clock 4*288 = 1152 times with no keystream output.
//
// NOTE on bit packing of key/iv inputs to this module: bit [0] of the `key`
// and `iv` ports is taken as K1 / IV1 respectively (i.e. key[0] loads into
// regA[0] = s1, matching the spec's "s1 = K1" convention). This is a design
// choice that must be matched consistently by whatever testbench/driver
// supplies key/iv;
//==============================================================================
module trivium (
    input  wire        clk,
    input  wire        rst_n,       // active-low synchronous reset
    input  wire        en,          // enable signal (advance one cycle when high)
    input  wire [79:0] key,        // NATURAL byte order: key[79:72]=byte0 ... key[7:0]=byte9,
                                   // i.e. type the key exactly as printed in a datasheet/spec
                                   // (e.g. eSTREAM "80 00 00 ... 00" -> key = 80'h8000_..._0000).
                                   // Internally bit-reversed per byte to match the Trivium
                                   // spec's s_i = K_i LFSR-loading convention. See byte_bitrev80().
    input  wire [79:0] iv,        // Same natural byte-order convention as `key`.

    output wire        keystream_valid, // high when keystream output is valid this cycle
    output wire        keystream,       // 1 bit per cycle, valid only when keystream_valid
    output wire        done             // high once initialization (1152 cycles) is complete
);

    localparam integer INIT_CYCLES = 4 * 288; // 1152
    // counter needs to count 0..1151 inclusive -> 1152 values -> 11 bits (max 2047) is sufficient
    localparam integer CTR_W = 11;

    // State registers: regA = s1..s93 (93b), regB = s94..s177 (84b), regC = s178..s288 (111b)
    reg [92:0]  regA;
    reg [83:0]  regB;
    reg [110:0] regC;

    reg [CTR_W-1:0] init_counter;
    reg             initialized;

    // ------------------------------------------------------------------
    // Byte-wise bit reversal.
    //
    // Trivium's spec packs K1..K80 (and IV1..IV80) into bytes LSB-first:
    // for byte i, K(8i+1) is bit0 (LSB) of that byte and K(8i+8) is bit7
    // (MSB). A key written the "natural" way -- exactly as printed in a
    // datasheet or the eSTREAM test vectors, byte0 first, each byte read
    // normally MSB-first (so "0x80" means bit7 set) -- is therefore NOT
    // in K1..K80 order; each byte's bits must be reversed (byte order
    // stays the same) before it can be loaded as s1..s80. Doing that
    // conversion here lets external users/testbenches supply key/iv in
    // the natural, human-readable form without pre-transforming it.
    // ------------------------------------------------------------------
    function automatic [79:0] byte_bitrev80(input [79:0] in);
        integer B;
        begin
            for (B = 0; B < 10; B = B + 1) begin
                byte_bitrev80[B*8+0] = in[B*8+7];
                byte_bitrev80[B*8+1] = in[B*8+6];
                byte_bitrev80[B*8+2] = in[B*8+5];
                byte_bitrev80[B*8+3] = in[B*8+4];
                byte_bitrev80[B*8+4] = in[B*8+3];
                byte_bitrev80[B*8+5] = in[B*8+2];
                byte_bitrev80[B*8+6] = in[B*8+1];
                byte_bitrev80[B*8+7] = in[B*8+0];
            end
        end
    endfunction

    wire [79:0] key_lfsr_order = byte_bitrev80(key);
    wire [79:0] iv_lfsr_order  = byte_bitrev80(iv);

    wire t1_lin, t2_lin, t3_lin;   // linear taps (pre-AND)
    wire t1_full, t2_full, t3_full; // full nonlinear feedback values
    wire z;                         // raw combinational keystream bit this cycle

    // Linear taps: t1=s66^s93, t2=s162^s177, t3=s243^s288 (0-indexed: 65/92, 68/83, 65/110)
    assign t1_lin = regA[65] ^ regA[92];
    assign t2_lin = regB[68] ^ regB[83];
    assign t3_lin = regC[65] ^ regC[110];

    // Keystream bit (only meaningful once initialized; gated by keystream_valid externally)
    assign z = t1_lin ^ t2_lin ^ t3_lin;

    // Full nonlinear feedback values used to update registers each cycle:
    //   t1_full feeds regB, t2_full feeds regC, t3_full feeds regA  (per spec rotation)
    assign t1_full = t1_lin ^ (regA[90] & regA[91]) ^ regB[77];
    assign t2_full = t2_lin ^ (regB[81] & regB[82]) ^ regC[86];
    assign t3_full = t3_lin ^ (regC[108] & regC[109]) ^ regA[68];

    assign done             = initialized;
    assign keystream_valid  = initialized & en;
    assign keystream        = z;

    always @(posedge clk) begin
        if (!rst_n) begin
            // s1..s93   <- (K1..K80, 0..0)   => regA[0]=K1 .. regA[79]=K80, regA[92:80]=0
            regA <= {13'b0, key_lfsr_order};
            // s94..s177 <- (IV1..IV80, 0..0) => regB[0]=IV1 .. regB[79]=IV80, regB[83:80]=0
            regB <= {4'b0, iv_lfsr_order};
            // s178..s288 <- (0..0,1,1,1) => s286=s287=s288=1, i.e. regC[108]=regC[109]=regC[110]=1
            regC <= {3'b111, 108'b0};

            init_counter <= {CTR_W{1'b0}};
            initialized  <= 1'b0;
        end
        else if (en) begin
            // Shift in the correctly-routed nonlinear feedback bits (spec rotation):
            //   regA <- {regA[91:0], t3_full}
            //   regB <- {regB[82:0], t1_full}
            //   regC <- {regC[109:0], t2_full}
            regA <= {regA[91:0], t3_full};
            regB <= {regB[82:0], t1_full};
            regC <= {regC[109:0], t2_full};

            if (!initialized) begin
                if (init_counter == 11'd1151) begin
                    initialized <= 1'b1;
                end
                init_counter <= init_counter + 1'b1;
            end
        end
    end

endmodule
