`timescale 1ns/1ps
module obuf_bias_sel_logic #(
    parameter integer  LOOP_ID_W                    = 5,
    parameter integer  ADDR_STRIDE_W                = 16
) (
    input  wire                                         clk,
    input  wire                                         reset,
  // Handshake
    input  wire                                         start,
    input  wire                                         done,
    input  wire  [ ADDR_STRIDE_W        -1 : 0 ]        obuf_stride,
    input  wire                                         obuf_stride_v,
    input  wire                                         loop_last_iter,
    input  wire                                         loop_stall,
    input  wire                                         loop_enter,
    input  wire                                         loop_exit,
    input  wire                                         loop_index_valid,
    input  wire  [ LOOP_ID_W            -1 : 0 ]        loop_index,
    output wire                                         bias_prev_sw,
    output wire                                         ddr_pe_sw
);


//=============================================================
// Wires & Regs
//=============================================================
  // Logic to track if a loop variable has dependency on obuf address or not
    //  When the address for obuf depends on the loop variable, it inherits the
    //  modified status from the previous loop as we enter the current loop
    //  Otherwise, the current loop's modified status is changed to modified
    //  upon exit
    reg  [ LOOP_ID_W            -1 : 0 ]        loop_id;

  // Store if current loop variable has a dependency to obuf
    reg obuf_loop_dep [(1<<LOOP_ID_W)-1:0];
  // Store if current loop variable should use obuf for bias
    reg bias_obuf_status [(1<<LOOP_ID_W)-1:0];
  // Store if current loop variable should be stored in ddr or pe
//    reg ddr_pe_status [(1<<LOOP_ID_W)-1:0];
//=============================================================

//=============================================================
// FSM
//=============================================================
    reg  [ 2                    -1 : 0 ]        state_d;
    reg  [ 2                    -1 : 0 ]        state_q;
    wire [ 2                    -1 : 0 ]        state;

    localparam integer  ST_IDLE                      = 0;
    localparam integer  ST_BUSY                      = 1;

  always @(*)
  begin
    state_d = state_q;
    case(state_q)
      ST_IDLE: begin
        if (start)
          state_d = ST_BUSY;
      end
      ST_BUSY: begin
        if (done)
          state_d = ST_IDLE;
      end
    endcase
  end

    assign state = state_q;
  always @(posedge clk)
  begin
    if (reset)
      state_q <= ST_IDLE;
    else
      state_q <= state_d;
  end
//=============================================================

//=============================================================
// Main logic
//=============================================================
  always @(posedge clk)
  begin
    if (reset)
      loop_id <= 1'b0;
    else begin
      if (done)
        loop_id <= 1'b0;
      else if (obuf_stride_v)
        loop_id <= loop_id + 1'b1;
    end
  end

  always @(posedge clk)
  begin
    if (obuf_stride_v)
      obuf_loop_dep[loop_id] <= obuf_stride != 0;
  end

    reg                                         prev_bias_status;
    wire                                        curr_bias_status;

    wire                                        curr_ddr_status;
    reg                                         prev_ddr_status;

    wire                                        curr_loop_dep;

    reg                                         loop_exit_dly;
    reg                                         loop_enter_dly;
  always @(posedge clk)
    loop_exit_dly <= loop_exit;

  always @(posedge clk)
    loop_enter_dly <= loop_enter;

  always @(posedge clk)
  begin
    if (reset)
      prev_bias_status <= 1'b0;
    else begin
      if (state != ST_BUSY)
        prev_bias_status <= 1'b0;
      else begin
        if (loop_enter && loop_exit_dly)
          prev_bias_status <= curr_bias_status;
        else if (loop_index_valid && ~loop_stall && ~curr_loop_dep)
          prev_bias_status <= 1'b1;
      end
    end
  end

  always @(posedge clk)
  begin
    if (state == ST_IDLE) begin
      bias_obuf_status[loop_id] <= 1'b0;
    end
    else begin
      if (loop_enter_dly) begin
        bias_obuf_status[loop_index] <= prev_bias_status;
      end
      else if (loop_exit && ~curr_loop_dep) begin
        bias_obuf_status[loop_index] <= 1'b1;
      end
    end
  end

    localparam integer  WR_DDR                       = 0;
    localparam integer  WR_PE                        = 1;

  always @(posedge clk)
  begin
    if (reset)
      prev_ddr_status <= WR_PE;
    else begin
      if (state != ST_BUSY)
        prev_ddr_status <= WR_PE;
      else begin
        if ((loop_enter || loop_index_valid) && ~curr_loop_dep)
          prev_ddr_status <= loop_last_iter ? WR_PE : WR_DDR;
      end
    end
  end

  
    assign curr_bias_status = bias_obuf_status[loop_index];
    assign curr_loop_dep = obuf_loop_dep[loop_index];

  wire loop_0_dep = obuf_loop_dep[0];
  wire loop_1_dep = obuf_loop_dep[1];
  wire loop_2_dep = obuf_loop_dep[2];
  wire loop_3_dep = obuf_loop_dep[3];
  wire loop_4_dep = obuf_loop_dep[4];
  wire loop_5_dep = obuf_loop_dep[5];
  wire loop_6_dep = obuf_loop_dep[6];

    assign bias_prev_sw = prev_bias_status;
    assign ddr_pe_sw = prev_ddr_status;
//=============================================================

//=============================================================
// VCD
//=============================================================
  `ifdef COCOTB_TOPLEVEL_obuf_bias_sel_logic
    initial begin
      $dumpfile("obuf_bias_sel_logic.vcd");
      $dumpvars(0, obuf_bias_sel_logic);
    end
  `endif
//=============================================================

endmodule
