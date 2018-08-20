//
// Tag logic for double buffering
//
// Hardik Sharma
// (hsharma@gatech.edu)

`timescale 1ns/1ps
module tag_logic #(
    parameter integer  STORE_ENABLED                = 1
)
(
    input  wire                                         clk,
    input  wire                                         reset,
    input  wire                                         tag_req,
    input  wire                                         tag_reuse,
    input  wire                                         tag_bias_prev_sw,
    input  wire                                         tag_ddr_pe_sw,
    output wire                                         tag_ready,
    output wire                                         tag_done,
    input  wire                                         tag_flush,
    input  wire                                         compute_tag_done,
    output wire                                         next_compute_tag,
//    output wire                                         compute_tag_reuse,
    output wire                                         compute_bias_prev_sw,
    output wire                                         compute_tag_ready,
    input  wire                                         ldmem_tag_done,
    output wire                                         ldmem_tag_ready,
    input  wire                                         stmem_tag_done,
    output wire                                         stmem_ddr_pe_sw,
    output wire                                         stmem_tag_ready
);

//==============================================================================
// Wires/Regs
//==============================================================================
    localparam integer  TAG_FREE                     = 0;
    localparam integer  TAG_LDMEM                    = 1;
    localparam integer  TAG_COMPUTE                  = 2;
    localparam integer  TAG_COMPUTE_CHECK            = 3;
    localparam integer  TAG_STMEM                    = 4;

    localparam integer  TAG_STATE_W                  = 3;

    localparam integer  REUSE_STATE_W                = 1;
    localparam integer  REUSE_FALSE                  = 0;
    localparam integer  REUSE_TRUE                   = 1;

    reg                                         tag_flush_state_d;
    reg                                         tag_flush_state_q;
    reg tag_reuse_state_d;
    reg tag_reuse_state_q;

    reg [2 : 0] tag_reuse_counter;

    reg                                         tag_ddr_pe_sw_q;
    reg                                         compute_ddr_pe_sw;
    reg                                         _stmem_ddr_pe_sw;
    reg                                         tag_bias_prev_sw_q;
    reg                                         reuse_tag_bias_prev_sw_q;
    reg  [ TAG_STATE_W          -1 : 0 ]        tag_state_d;
    reg  [ TAG_STATE_W          -1 : 0 ]        tag_state_q;
//==============================================================================

//==============================================================================
// Tag allocation
//==============================================================================

    assign tag_done = tag_state_q == TAG_FREE;

    assign ldmem_tag_ready = tag_state_q == TAG_LDMEM;
    assign compute_tag_ready = tag_state_q == TAG_COMPUTE;
    assign stmem_tag_ready = tag_state_q == TAG_STMEM;
    assign tag_ready = tag_state_q == TAG_FREE;

    assign compute_bias_prev_sw = tag_bias_prev_sw_q;
    assign stmem_ddr_pe_sw = _stmem_ddr_pe_sw;

  always @(*)
  begin: TAG0_STATE
    tag_state_d = tag_state_q;
    case (tag_state_q)
      TAG_FREE: begin
        if (tag_req) begin
          tag_state_d = TAG_LDMEM;
        end
      end
      TAG_LDMEM: begin
        if (ldmem_tag_done)
          tag_state_d = TAG_COMPUTE;
      end
      TAG_COMPUTE_CHECK: begin
        if (tag_reuse_counter == 0 && tag_flush_state_q == 1) begin
          if (STORE_ENABLED)
            tag_state_d = TAG_STMEM;
          else
            tag_state_d = TAG_FREE;
        end
        else if (tag_reuse_counter != 0)
          tag_state_d = TAG_COMPUTE;
      end
      TAG_COMPUTE: begin
        if (compute_tag_done)
          tag_state_d = TAG_COMPUTE_CHECK;
      end
      TAG_STMEM: begin
        if (stmem_tag_done)
          tag_state_d = TAG_FREE;
      end
    endcase
  end

  always @(posedge clk)
  begin
    if (reset) begin
      tag_state_q <= TAG_FREE;
    end
    else begin
      tag_state_q <= tag_state_d;
    end
  end

  always @(*)
  begin
    tag_flush_state_d = tag_flush_state_q;
    case (tag_flush_state_q)
      0: begin
        if (tag_flush && tag_state_q != TAG_FREE)
          tag_flush_state_d = 1;
      end
      1: begin
        if (tag_state_q == TAG_COMPUTE_CHECK && tag_reuse_counter == 0)
          tag_flush_state_d = 0;
      end
    endcase
  end

  always @(posedge clk)
  begin
    if (reset)
      tag_flush_state_q <= 0;
    else
      tag_flush_state_q <= tag_flush_state_d;
  end

  assign next_compute_tag = tag_state_q == TAG_COMPUTE_CHECK && tag_flush_state_q == 1 && tag_reuse_counter == 0;

  always @(posedge clk)
  begin
    if (reset)
      tag_reuse_counter <= 0;
    else begin
      if (compute_tag_done && ~(tag_req || tag_reuse) && tag_reuse_counter != 0)
        tag_reuse_counter <= tag_reuse_counter - 1'b1;
      else if (~compute_tag_done && (tag_reuse || tag_req))
        tag_reuse_counter <= tag_reuse_counter + 1'b1;
    end
  end

  always @(posedge clk)
  begin
    if (reset) begin
      compute_ddr_pe_sw <= 1'b0;
    end else if (ldmem_tag_done || tag_state_q == TAG_COMPUTE_CHECK) begin
      compute_ddr_pe_sw <= tag_ddr_pe_sw_q;
    end
  end

  always @(posedge clk)
  begin
    if (reset) begin
      _stmem_ddr_pe_sw <= 1'b0;
    end else if (compute_tag_done) begin
      _stmem_ddr_pe_sw <= compute_ddr_pe_sw;
    end
  end

  always @(posedge clk)
  begin
    if (reset) begin
      tag_bias_prev_sw_q <= 1'b0;
    end
    else if (tag_req && tag_ready) begin
      tag_bias_prev_sw_q <= tag_bias_prev_sw;
    end
    else if (compute_tag_done)
      tag_bias_prev_sw_q <= reuse_tag_bias_prev_sw_q;
  end

  always @(posedge clk)
  begin
    if (reset) begin
      tag_ddr_pe_sw_q <= 1'b0;
    end
    else if ((tag_req && tag_ready) || tag_reuse) begin
      tag_ddr_pe_sw_q <= tag_ddr_pe_sw;
    end
  end

  always @(posedge clk)
    if (reset)
      reuse_tag_bias_prev_sw_q <= 1'b0;
    else if (tag_reuse)
      reuse_tag_bias_prev_sw_q <= tag_bias_prev_sw;
//==============================================================================

//==============================================================================
// VCD
//==============================================================================
`ifdef COCOTB_TOPLEVEL_tag_logic
initial begin
  $dumpfile("tag_logic.vcd");
  $dumpvars(0, tag_logic);
end
`endif
//==============================================================================

endmodule
