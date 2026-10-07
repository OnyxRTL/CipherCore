`timescale 1ns/1ps

//==============================================================================
// Copyright (c) 2026 opensiliconhub contributors
// SPDX-License-Identifier : Apache-2.0
//==============================================================================

module chacha20_tb;

  reg clk;
  reg rst_n;
  reg en;
  reg  [255:0] key;
  reg   [95:0] nonce;
  reg   [31:0] block_count;

  wire [511:0] out;
  wire         valid;
  wire         ready;

  // Instantiate DUT
  chacha20 #(.ITERATIONS(10)) dut (
      .clk(clk),
      .rst_n(rst_n),
      .en(en),
      .key(key),
      .nonce(nonce),
      .block_count(block_count),
      .out(out),
      .valid(valid),
      .ready(ready)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;   // 100MHz
  end

  // VCD Waveform Dumping
  initial begin
    $dumpfile("build/sim_results/chacha20.vcd");
    $dumpvars(0, chacha20_tb);
  end

  // RFC 8439, Section 2.3.2
  localparam [511:0] EXPECTED_1 = {
    8'h10, 8'hf1, 8'he7, 8'he4, 8'hd1, 8'h3b, 8'h59, 8'h15, 8'h50, 8'h0f, 8'hdd, 8'h1f, 8'ha3, 8'h20, 8'h71, 8'hc4,
    8'hc7, 8'hd1, 8'hf4, 8'hc7, 8'h33, 8'hc0, 8'h68, 8'h03, 8'h04, 8'h22, 8'haa, 8'h9a, 8'hc3, 8'hd4, 8'h6c, 8'h4e,
    8'hd2, 8'h82, 8'h64, 8'h46, 8'h07, 8'h9f, 8'haa, 8'h09, 8'h14, 8'hc2, 8'hd7, 8'h05, 8'hd9, 8'h8b, 8'h02, 8'ha2,
    8'hb5, 8'h12, 8'h9c, 8'hd1, 8'hde, 8'h16, 8'h4e, 8'hb9, 8'hcb, 8'hd0, 8'h83, 8'he8, 8'ha2, 8'h50, 8'h3c, 8'h4e
  };

  // RFC 8439 Section 2.4.2
  localparam [511:0] EXPECTED_2 = {
    8'h22, 8'h4f, 8'h51, 8'hf3, 8'h40, 8'h1b, 8'hd9, 8'he1, 8'h2f, 8'hde, 8'h27, 8'h6f, 8'hb8, 8'h63, 8'h1d, 8'hed,
    8'h8c, 8'h13, 8'h1f, 8'h82, 8'h3d, 8'h2c, 8'h06, 8'he2, 8'h7e, 8'h4f, 8'hca, 8'hec, 8'h9e, 8'hf3, 8'hcf, 8'h78,
    8'h8a, 8'h3b, 8'h0a, 8'ha3, 8'h72, 8'h60, 8'h0a, 8'h92, 8'hb5, 8'h79, 8'h74, 8'hcd, 8'hed, 8'h2b, 8'h93, 8'h34,
    8'h79, 8'h4c, 8'hba, 8'h40, 8'hc6, 8'h3e, 8'h34, 8'hcd, 8'hea, 8'h21, 8'h2c, 8'h4c, 8'hf0, 8'h7d, 8'h41, 8'hb7
  };

  initial begin

    rst_n = 0;
    en  = 0;

    // RFC 8439 Section 2.3.2 inputs
    key = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
    nonce = 96'h000000090000004a00000000;
    block_count = 32'h00000001;

    #30 rst_n = 1;

    @(posedge clk);
    wait(ready);

    en = 1;

    wait(valid);
    @(posedge clk);

    if (out === EXPECTED_1) begin
        $display("[PASS] RFC8439 Block #1");
    end else begin
        $display("\n[FAIL] RFC8439 Block #1");
        $display("Expected:\n%h\n", EXPECTED_1);
        $display("Generated: %h", out);
    end

    en = 0;
    @(posedge clk);
    wait(ready);

    @(posedge clk);

    // RFC 8439 Section 2.4.2 inputs
    key = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
    nonce = 96'h000000000000004a00000000;
    block_count = 32'h00000001;

    en = 1;

    wait(valid);
    @(posedge clk);

    if (out === EXPECTED_2) begin
        $display("[PASS] RFC8439 Block #2");
    end else begin
        $display("[FAIL] RFC8439 Block #2");
        $display("Expected:\n%h\n", EXPECTED_2);
        $display("Generated: %h", out);
    end

    $display("");

    en = 0;
    wait(ready);

    #20
    $finish(0);
  end
endmodule
