`timescale 1ns/1ps

//==============================================================================
// Copyright (c) 2026 opensiliconhub contributors
// SPDX-License-Identifier : Apache-2.0
//==============================================================================

module chacha8_tb;

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
  chacha20 #(.ITERATIONS(4)) dut (
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
    forever #5 clk = ~clk; // 100MHz
  end

  // VCD Waveform Dumping
  initial begin
    $dumpfile("build/sim_results/chacha8.vcd");
    $dumpvars(0, chacha8_tb);
  end

  localparam [511:0] EXPECTED_1 = {
    8'h3e, 8'h00, 8'hef, 8'h2f, 8'h89, 8'h5f, 8'h40, 8'hd6,
    8'h7f, 8'h5b, 8'hb8, 8'he8, 8'h1f, 8'h09, 8'ha5, 8'ha1,
    8'h2c, 8'h84, 8'h0e, 8'hc3, 8'hce, 8'h9a, 8'h7f, 8'h3b,
    8'h18, 8'h1b, 8'he1, 8'h88, 8'hef, 8'h71, 8'h1a, 8'h1e,
    8'h98, 8'h4c, 8'he1, 8'h72, 8'hb9, 8'h21, 8'h6f, 8'h41,
    8'h9f, 8'h44, 8'h53, 8'h67, 8'h45, 8'h6d, 8'h56, 8'h19,
    8'h31, 8'h4a, 8'h42, 8'ha3, 8'hda, 8'h86, 8'hb0, 8'h01,
    8'h38, 8'h7b, 8'hfd, 8'hb8, 8'h0e, 8'h0c, 8'hfe, 8'h42
};


  initial begin

    rst_n = 0;
    en  = 0;

    key = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    nonce = 96'h000000000000000000000000;
    block_count = 32'h00000000;

    #30 rst_n = 1;

    @(posedge clk);
    wait(ready);

    en = 1;

    wait(valid);
    @(posedge clk);

    if (out === EXPECTED_1) begin
        $display("[PASS] ChaCha8 eSTREAM");
    end else begin
        $display("[FAIL] ChaCha8 eSTREAM");
        $display("Expected:\n%h\n", EXPECTED_1);
        $display("Generated: %h", out);
    end

    $display("");

    en = 0;
    @(posedge clk);
    wait(ready);

    #20
    $finish(0);
  end
endmodule
