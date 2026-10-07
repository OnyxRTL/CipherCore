`timescale 1ns/1ps

//==============================================================================
// Copyright (c) 2026 opensiliconhub contributors
// SPDX-License-Identifier : Apache-2.0
//==============================================================================

module chacha12_tb;

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
  chacha20 #(.ITERATIONS(6)) dut (
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
    $dumpfile("build/sim_results/chacha12.vcd");
    $dumpvars(0, chacha12_tb);
  end

  localparam [511:0] EXPECTED_1 = {
      8'h9b, 8'hf4, 8'h9a, 8'h6a, 8'h07, 8'h55, 8'hf9, 8'h53,
      8'h81, 8'h1f, 8'hce, 8'h12, 8'h5f, 8'h26, 8'h83, 8'hd5,
      8'h04, 8'h29, 8'hc3, 8'hbb, 8'h49, 8'he0, 8'h74, 8'h14,
      8'h7e, 8'h00, 8'h89, 8'ha5, 8'h2e, 8'hae, 8'h15, 8'h5f,
      8'h05, 8'h64, 8'hf8, 8'h79, 8'hd2, 8'h7a, 8'he3, 8'hc0,
      8'h2c, 8'he8, 8'h28, 8'h34, 8'hac, 8'hfa, 8'h8c, 8'h79,
      8'h3a, 8'h62, 8'h9f, 8'h2c, 8'ha0, 8'hde, 8'h69, 8'h19,
      8'h61, 8'h0b, 8'he8, 8'h2f, 8'h41, 8'h13, 8'h26, 8'hbe
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
        $display("[PASS] ChaCha12 eSTREAM");
    end else begin
        $display("[FAIL] ChaCha12 eSTREAM");
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
