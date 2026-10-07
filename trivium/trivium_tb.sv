//==============================================================================
// Copyright (c) 2026 opensiliconhub contributors
// SPDX-License-Identifier : Apache-2.0
//==============================================================================

`timescale 1ns / 1ps

module trivium_tb;

    // --- Signals ---
    logic        clk = 0;
    logic        rst_n;
    logic        en;
    logic [79:0] key;
    logic [79:0] iv;
    logic        keystream_valid;
    logic        keystream;
    logic        done;

    int unsigned error_count = 0;
    int unsigned bit_count = 0;

    // --- DUT Instantiation ---
    trivium dut (
        .clk             (clk),
        .rst_n           (rst_n),
        .en              (en),
        .key             (key),
        .iv              (iv),
        .keystream_valid (keystream_valid),
        .keystream       (keystream),
        .done            (done)
    );

    // --- Clock generattion ---
    always #5 clk = ~clk;

    // ---------------------------------------------------------------
    // Expected keystream (official eSTREAM test vector, key=0 IV=0),
    // 512 bits = 64 bytes, packed MSB-first-per-byte here for readability;
    // we will compare bit-by-bit against the *generation order* below.
    // ---------------------------------------------------------------
    localparam int NUM_EXPECTED_BYTES = 64;
    logic [7:0] expected_bytes [0:NUM_EXPECTED_BYTES-1];

    logic [7:0] expected_keystream_hex_1 [0:63] = '{
        8'hFB, 8'hE0, 8'hBF, 8'h26, 8'h58, 8'h59, 8'h05, 8'h1B,
        8'h51, 8'h7A, 8'h2E, 8'h4E, 8'h23, 8'h9F, 8'hC9, 8'h7F,
        8'h56, 8'h32, 8'h03, 8'h16, 8'h19, 8'h07, 8'hCF, 8'h2D,
        8'hE7, 8'hA8, 8'h79, 8'h0F, 8'hA1, 8'hB2, 8'hE9, 8'hCD,
        8'hF7, 8'h52, 8'h92, 8'h03, 8'h02, 8'h68, 8'hB7, 8'h38,
        8'h2B, 8'h4C, 8'h1A, 8'h75, 8'h9A, 8'hA2, 8'h59, 8'h9A,
        8'h28, 8'h55, 8'h49, 8'h98, 8'h6E, 8'h74, 8'h80, 8'h59,
        8'h03, 8'h80, 8'h1A, 8'h4C, 8'hB5, 8'hA5, 8'hD4, 8'hF2
    };

    // Per the Trivium spec: bytes are formed LSb-first from the keystream
    // bit sequence, i.e. byte_i = sum_{j=0..7} 2^j * bit(8*i + j).
    // So bit(8*i+0) is the LSB of byte_i, and bit(8*i+7) is the MSB.
    function automatic logic expected_bit(int unsigned global_bit_idx);
        int unsigned byte_idx;
        int unsigned bit_in_byte;
        begin
            byte_idx    = global_bit_idx / 8;
            bit_in_byte = global_bit_idx % 8;
            expected_bit = expected_keystream_hex_1[byte_idx][bit_in_byte];
        end
    endfunction

    // ---------------------------------------------------------------
    // Test Vector 2: Key = 80 00... IV = 00 00...
    // ---------------------------------------------------------------
    logic [7:0] expected_keystream_hex_2 [0:63] = '{
        8'h38, 8'hEB, 8'h86, 8'hFF, 8'h73, 8'h0D, 8'h7A, 8'h9C,
        8'hAF, 8'h8D, 8'hF1, 8'h3A, 8'h44, 8'h20, 8'h54, 8'h0D,
        8'hBB, 8'h7B, 8'h65, 8'h14, 8'h64, 8'hC8, 8'h75, 8'h01,
        8'h55, 8'h20, 8'h41, 8'hC2, 8'h49, 8'hF2, 8'h9A, 8'h64,
        8'hD2, 8'hFB, 8'hF5, 8'h15, 8'h61, 8'h09, 8'h21, 8'hEB,
        8'hE0, 8'h6C, 8'h8F, 8'h92, 8'hCE, 8'hCF, 8'h7F, 8'h80,
        8'h98, 8'hFF, 8'h20, 8'hCC, 8'hCC, 8'h6A, 8'h62, 8'hB9,
        8'h7B, 8'hE8, 8'hEF, 8'h74, 8'h54, 8'hFC, 8'h80, 8'hF9
    };

    function automatic logic expected_bit_2(int unsigned global_bit_idx);
        int unsigned byte_idx;
        int unsigned bit_in_byte;
        begin
            byte_idx    = global_bit_idx / 8;
            bit_in_byte = global_bit_idx % 8;
            expected_bit_2 = expected_keystream_hex_2[byte_idx][bit_in_byte];
        end
    endfunction

    // --- Helper: Apply active-low reset ---
    task automatic apply_reset(input logic [79:0] k, input logic [79:0] v);
        begin
            rst_n = 1'b0;
            en  = 1'b0;
            key = k;
            iv  = v;
            @(posedge clk);
            @(posedge clk);
	    #1;
            rst_n = 1'b1;
        end
    endtask

    // ---------------------------------------------------------------
    // Main test sequence
    // ---------------------------------------------------------------
    initial begin

        $display(" Trivium RTL Testbench");
        // ---------------- Test 1: reset behavior --------------------
        apply_reset(80'h0, 80'h0);
        if (done !== 1'b0) begin
            $error("FAIL: done should be 0 immediately after reset, got %0b", done);
            error_count++;
        end else begin
            $display("PASS: done is low after reset");
        end

        // ---------------- Test 2: initialization takes exactly 1152 enabled cycles
        en = 1'b1;
        for (int unsigned i = 0; i < 1152; i++) begin
            @(posedge clk);
            #1; // allow combinational settle for done/keystream_valid checks
            if (i < 1151) begin
                if (done !== 1'b0) begin
                    $error("FAIL: done asserted early at enabled-cycle %0d (expected after cycle 1151)", i);
                    error_count++;
                end
            end
        end
        #1;
        if (done !== 1'b1) begin
            $error("FAIL: done should be high after 1152 enabled cycles, got %0b", done);
            error_count++;
        end else begin
            $display("PASS: done asserts exactly after 1152 enabled cycles");
        end

        // ---------------- Test 3: keystream matches official test vector
        $display("Checking 512 keystream bits against official eSTREAM test vector (key=0, IV=0)...");
            for (int unsigned i = 0; i < 512; i++) begin

                // 1. Evaluate the currently valid bit FIRST
                if (!keystream_valid) begin
                    $error("FAIL: keystream_valid not high during keystream generation at bit %0d", i);
                    error_count++;
                end
                if (keystream !== expected_bit(i)) begin
                    $error("FAIL: keystream bit %0d mismatch: got %0b expected %0b",
                        i, keystream, expected_bit(i));
                    error_count++;
                end else begin
                    bit_count++;
                end

                // 2. Advance the clock to shift the cipher and generate the NEXT bit
                @(posedge clk);
                #1;
            end
        $display("Keystream bits checked: %0d / 512, mismatches: %0d", bit_count, 512 - bit_count);

        // ---------------- Test 4: en=0 holds state (no advance, no output change semantics)
        begin
            logic prev_done;
            prev_done = done;
            en = 1'b0;
            @(posedge clk);
            #1;
            if (done !== prev_done) begin
                $error("FAIL: done changed while en=0 (state should be held)");
                error_count++;
            end else begin
                $display("PASS: state held while en=0");
            end
            en = 1'b1;
        end

        // ---------------- Test 5: reset mid-stream returns to uninitialized
        apply_reset(80'h0, 80'h0);
        if (done !== 1'b0) begin
            $error("FAIL: reset mid-stream did not clear done");
            error_count++;
        end else begin
            $display("PASS: reset correctly clears done mid-stream");
        end

        // ---------------- Test 6: different key/IV produces different keystream
        apply_reset(80'hFFFF_FFFF_FFFF_FFFF_FFFF, 80'h0);
        en = 1'b1;
        repeat (1152) @(posedge clk);
        #1;
        begin
            logic first_bit_allones_key;
            @(posedge clk);
            #1;
            first_bit_allones_key = keystream;
            if (first_bit_allones_key === expected_bit(0)) begin
                $display("NOTE: first bit happened to coincide with zero-key vector (low statistical likelihood issue, not necessarily a bug) - rerun additional bits recommended for full confidence");
            end else begin
                $display("PASS: differing key/IV produces a different first keystream bit, as expected");
            end
        end

        // ---------------- Test 7: eSTREAM Vector (Key=0x80..., IV=0)
        $display("Checking 512 keystream bits against Test Vector 2...");

        apply_reset(80'h8000_0000_0000_0000_0000, 80'h0);
        en = 1'b1;

        // Wait for 1152 cycles for initialization
        for (int unsigned i = 0; i < 1152; i++) begin
            @(posedge clk);
            #1;
        end

        // Check the 512 bits using the exact same aligned logic
        bit_count = 0;
        for (int unsigned i = 0; i < 512; i++) begin
            if (!keystream_valid) begin
                $error("FAIL: keystream_valid dropped during Test Vector 2 generation at bit %0d", i);
                error_count++;
            end

            if (keystream !== expected_bit_2(i)) begin
                $error("FAIL: Vector 2 bit %0d mismatch: got %0b expected %0b",
                       i, keystream, expected_bit_2(i));
                error_count++;
            end else begin
                bit_count++;
            end

            // Advance clock to generate next bit
            @(posedge clk);
            #1;
        end
        $display("Vector 2 Keystream bits checked: %0d / 512, mismatches: %0d", bit_count, 512 - bit_count);

        // ---------------- Summary ------------------------------------
        if (error_count == 0) begin
            $display(" ALL TESTS PASSED");
        end else begin
            $display(" TESTS FAILED: %0d error(s)", error_count);
        end

        $finish;
    end

    // Safety timeout
    initial begin
        #2_000_000;
        $error("FAIL: testbench timeout - simulation did not finish");
        $finish;
    end

endmodule
