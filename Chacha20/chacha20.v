`timescale 1ns/1ps

//==============================================================================
// Copyright (c) 2026 opensiliconhub contributors
// SPDX-License-Identifier : Apache-2.0
//==============================================================================

module chacha20 #(
  parameter ITERATIONS = 10   // number of "double rounds" (column + diagonal)
)(
  input  wire         clk,
  input  wire         rst_n,
  input  wire         en,
  input  wire [255:0] key,
  input  wire [95:0]  nonce,
  input  wire [31:0]  block_count,
  output reg  [511:0] out,
  output reg          valid,
  output wire         ready
);

  // ====================================================================
  // Helper Functions
  //====================================================================

  // Initializes the 512-bit state matrix
  function [511:0] STATE_INIT;
    input [255:0] key_in;
    input [95:0]  nonce_in;
    input [31:0]  block_count_in;
    integer i;
    begin
      // 0-3: ChaCha Constants
      STATE_INIT[0*32 +: 32] = 32'h61707865;
      STATE_INIT[1*32 +: 32] = 32'h3320646e;
      STATE_INIT[2*32 +: 32] = 32'h79622d32;
      STATE_INIT[3*32 +: 32] = 32'h6b206574;

      // 4-11: Key (Byte-reversed per 32-bit word)
      for (i = 0; i < 8; i = i + 1) begin
        STATE_INIT[(4+i)*32 +: 32] = {
          key_in[255 - (i*32 + 24) -: 8],
          key_in[255 - (i*32 + 16) -: 8],
          key_in[255 - (i*32 +  8) -: 8],
          key_in[255 - (i*32 +  0) -: 8]
        };
      end

      // 12: Block Count
      STATE_INIT[12*32 +: 32] = block_count_in;

      // 13-15: Nonce (Byte-reversed per 32-bit word)
      for (i = 0; i < 3; i = i + 1) begin
        STATE_INIT[(13+i)*32 +: 32] = {
          nonce_in[95 - (i*32 + 24) -: 8],
          nonce_in[95 - (i*32 + 16) -: 8],
          nonce_in[95 - (i*32 +  8) -: 8],
          nonce_in[95 - (i*32 +  0) -: 8]
        };
      end
    end
  endfunction

  // Circular left shift
  function [31:0] ROTL;
    input [31:0] x;
    input [4:0]  n;
    begin
      ROTL = (x << n) | (x >> (32 - n));
    end
  endfunction

  // ----------------------------------------------------------------------
  // Single quarter-round STAGE.
  //
  // A full quarterround is 4 dependent steps:
  //   stage 0: a += b; d = ROTL(d^a, 16)
  //   stage 1: c += d; b = ROTL(b^c, 12)
  //   stage 2: a += b; d = ROTL(d^a,  8)
  //   stage 3: c += d; b = ROTL(b^c,  7)
  // ----------------------------------------------------------------------
  function [127:0] QR_STAGE;
    input [31:0] a, b, c, d;
    input [1:0]  stage;
    begin
      case (stage)
        2'd0: begin a = a + b; d = ROTL(d ^ a, 16); end
        2'd1: begin c = c + d; b = ROTL(b ^ c, 12); end
        2'd2: begin a = a + b; d = ROTL(d ^ a,  8); end
        2'd3: begin c = c + d; b = ROTL(b ^ c,  7); end
      endcase
      QR_STAGE = {a, b, c, d};
    end
  endfunction

  // ----------------------------------------------------------------------
  // Applies ONE stage to all 4 independent quarterround lanes at once
  // (column lanes or diagonal lanes, selected by is_diag).
  // ----------------------------------------------------------------------
  function [511:0] APPLY_STAGE;
    input [511:0] st;
    input [1:0]   stage;
    input         is_diag;
    reg [31:0] w[0:15];
    reg [127:0] r;
    integer i;
    begin
      for (i = 0; i < 16; i = i + 1)
        w[i] = st[i*32 +: 32];

      if (!is_diag) begin
        // Column lanes: (0,4,8,12) (1,5,9,13) (2,6,10,14) (3,7,11,15)
        r = QR_STAGE(w[0], w[4], w[8],  w[12], stage); {w[0], w[4], w[8],  w[12]} = r;
        r = QR_STAGE(w[1], w[5], w[9],  w[13], stage); {w[1], w[5], w[9],  w[13]} = r;
        r = QR_STAGE(w[2], w[6], w[10], w[14], stage); {w[2], w[6], w[10], w[14]} = r;
        r = QR_STAGE(w[3], w[7], w[11], w[15], stage); {w[3], w[7], w[11], w[15]} = r;
      end else begin
        // Diagonal lanes: (0,5,10,15) (1,6,11,12) (2,7,8,13) (3,4,9,14)
        r = QR_STAGE(w[0], w[5], w[10], w[15], stage); {w[0], w[5], w[10], w[15]} = r;
        r = QR_STAGE(w[1], w[6], w[11], w[12], stage); {w[1], w[6], w[11], w[12]} = r;
        r = QR_STAGE(w[2], w[7], w[8],  w[13], stage); {w[2], w[7], w[8],  w[13]} = r;
        r = QR_STAGE(w[3], w[4], w[9],  w[14], stage); {w[3], w[4], w[9],  w[14]} = r;
      end

      for (i = 0; i < 16; i = i + 1)
        APPLY_STAGE[i*32 +: 32] = w[i];
    end
  endfunction

  // Adds original initialized state back to final worked state
  function [511:0] FINAL_ADDITION;
    input [511:0] x_in;
    input [511:0] y_in;
    integer i;
    begin
      for (i = 0; i < 16; i = i + 1) begin
        FINAL_ADDITION[i*32 +: 32] = x_in[i*32 +: 32] + y_in[i*32 +: 32];
      end
    end
  endfunction

  // Reverses entire stream and byte-swaps each 32-bit word for output
  function [511:0] SERIALIZE;
    input [511:0] ser_in;
    reg   [31:0]  word;
    integer i;
    begin
      for (i = 0; i < 16; i = i + 1) begin
        word = ser_in[i*32 +: 32];
        SERIALIZE[(15-i)*32 +: 32] = {word[7:0], word[15:8], word[23:16], word[31:24]};
      end
    end
  endfunction

  // ====================================================================
  // Control Path & FSM
  // ====================================================================

  // Total single rounds (column + diagonal, alternating) = 2 * ITERATIONS.
  // At 4 stages per single round, that is 4 * 2 * ITERATIONS clock cycles
  // to finish the round pipeline (80 cycles for ITERATIONS = 10).
  localparam TOTAL_ROUNDS = 2 * ITERATIONS;

  localparam IDLE         = 3'd0;
  localparam LOAD         = 3'd1;
  localparam RUNNING      = 3'd2;
  localparam FINAL_ADD    = 3'd3;
  localparam SERIALIZE_S  = 3'd4;
  localparam DONE         = 3'd5;

  reg [2:0]   state, next_state;
  reg [511:0] init_state;
  reg [511:0] work_state;
  reg [511:0] add_result;

  reg [4:0]   round_cnt;   // which single round (0 .. TOTAL_ROUNDS-1)
  reg [1:0]   stage_cnt;   // which stage within the round (0 .. 3)
  reg         round_type;  // 0 = column round, 1 = diagonal round

  wire        last_stage = (stage_cnt == 2'd3);
  wire        last_round = (round_cnt == TOTAL_ROUNDS - 1);

  assign ready = (state == IDLE);

  // Sequential Logic
  always @(posedge clk) begin
    if (!rst_n) begin
      state         <= IDLE;
      init_state    <= 512'd0;
      work_state    <= 512'd0;
      add_result    <= 512'd0;
      round_cnt     <= 5'd0;
      stage_cnt     <= 2'd0;
      round_type    <= 1'b0;
      out           <= 512'd0;
      valid         <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          // valid clears explicitly in DONE
        end

        LOAD: begin
          init_state <= STATE_INIT(key, nonce, block_count);
          work_state <= STATE_INIT(key, nonce, block_count);
          round_cnt  <= 5'd0;
          stage_cnt  <= 2'd0;
          round_type <= 1'b0;   // rounds start with a column round
          valid      <= 1'b0;
        end

        RUNNING: begin
          // One add + one xor + one rotate per lane, per cycle.
          work_state <= APPLY_STAGE(work_state, stage_cnt, round_type);

          if (last_stage) begin
            stage_cnt  <= 2'd0;
            round_type <= ~round_type;   // alternate column <-> diagonal
            round_cnt  <= round_cnt + 5'd1;
          end else begin
            stage_cnt  <= stage_cnt + 2'd1;
          end
        end

        FINAL_ADD: begin
          add_result <= FINAL_ADDITION(init_state, work_state);
        end

        SERIALIZE_S: begin
          out   <= SERIALIZE(add_result);
          valid <= 1'b1;
        end

        DONE: begin
          if (!en) valid <= 1'b0;
        end

        default: begin end
      endcase
    end
  end

  // Combinational Logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE:        if (en) next_state = LOAD;
      LOAD:        next_state = RUNNING;
      RUNNING:     if (last_stage && last_round) next_state = FINAL_ADD;
                   else                          next_state = RUNNING;
      FINAL_ADD:   next_state = SERIALIZE_S;
      SERIALIZE_S: next_state = DONE;
      DONE:        if (!en) next_state = IDLE;
      default:     next_state = IDLE;
    endcase
  end

endmodule
