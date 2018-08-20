//
// Wrapper for memory
//
// Hardik Sharma
// (hsharma@gatech.edu)

`timescale 1ns/1ps
module pu_ld_obuf_wrapper #(
  // Internal Parameters
    parameter integer  MEM_ID                       = 0,
    parameter integer  STORE_ENABLED                = MEM_ID == 1 ? 1 : 0,
    parameter integer  MEM_REQ_W                    = 16,
    parameter integer  ADDR_WIDTH                   = 8,
    parameter integer  LOOP_ITER_W                  = 16,
    parameter integer  ADDR_STRIDE_W                = ADDR_WIDTH,
    parameter integer  LOOP_ID_W                    = 5,
    parameter integer  BUF_TYPE_W                   = 2,
    parameter integer  NUM_TAGS                     = 4,
    parameter integer  TAG_W                        = $clog2(NUM_TAGS),

    parameter integer  OBUF_AXI_DATA_WIDTH          = 256,
    parameter integer  SIMD_INTERIM_WIDTH           = 512,
    parameter integer  NUM_FIFO                     = SIMD_INTERIM_WIDTH / OBUF_AXI_DATA_WIDTH,

  // AXI
    parameter integer  AXI_DATA_WIDTH               = 64,
    parameter integer  AXI_BURST_WIDTH              = 8,
    parameter integer  WSTRB_W                      = AXI_DATA_WIDTH/8
) (
    input  wire                                         clk,
    input  wire                                         reset,

    input  wire                                         start,
    output wire                                         done,
    input  wire  [ ADDR_WIDTH           -1 : 0 ]        base_addr,

  // Programming
    input  wire                                         cfg_loop_stride_v,
    input  wire  [ ADDR_STRIDE_W        -1 : 0 ]        cfg_loop_stride,
    input  wire  [ 3                    -1 : 0 ]        cfg_loop_stride_type,

    input  wire                                         cfg_loop_iter_v,
    input  wire  [ LOOP_ITER_W          -1 : 0 ]        cfg_loop_iter,
    input  wire  [ 3                    -1 : 0 ]        cfg_loop_iter_type,

  // LD
    output wire                                         mem_req,
    input  wire                                         mem_ready,
    output wire  [ ADDR_WIDTH           -1 : 0 ]        mem_addr,

    input  wire                                         obuf_ld_stream_write_ready
);

//==============================================================================
// Localparams
//==============================================================================
//==============================================================================

//==============================================================================
// Wires/Regs
//==============================================================================
    reg  [ LOOP_ID_W            -1 : 0 ]        mem_loop_id_counter;

    wire                                        fifo_stall;
    wire                                        fsm_stall;
    wire                                        loop_ctrl_stall;
    wire [ LOOP_ID_W            -1 : 0 ]        loop_ctrl_index;
    wire                                        loop_ctrl_index_valid;
    wire                                        loop_ctrl_init;
    wire                                        loop_ctrl_done;
    wire                                        loop_ctrl_enter;
    wire                                        loop_ctrl_exit;
    wire                                        loop_ctrl_next_addr;

    wire [ ADDR_WIDTH           -1 : 0 ]        ld_addr;
    reg  [ ADDR_WIDTH           -1 : 0 ]        ld_addr_d;
    reg  [ ADDR_WIDTH           -1 : 0 ]        ld_addr_q;
    wire                                        ld_addr_valid;

    wire                                        obuf_ld_loop_iter_v;
//==============================================================================

//==============================================================================
// Assigns
//==============================================================================
    assign fifo_stall = ~mem_ready || ~obuf_ld_stream_write_ready;
    assign loop_ctrl_stall = fifo_stall || fsm_stall;
    assign mem_req = (~fifo_stall) && (ld_addr_valid || fsm_stall);
    assign loop_ctrl_next_addr = loop_ctrl_index_valid && ~loop_ctrl_stall;
    assign done = mem_access_state_q == 0 && done_state_q == 1;
    // assign done = loop_ctrl_done;
//==============================================================================

//==============================================================================
// OBUF LD Address Generation
//==============================================================================
    reg                                         mem_access_state_d;
    reg                                         mem_access_state_q;

    // Need done state for the case when we need to stall after the loop
    // controller has finished
    reg                                         done_state_d;
    reg                                         done_state_q;

    localparam          FIFO_ID_WIDTH                = $clog2(NUM_FIFO);
    reg  [ FIFO_ID_WIDTH        -1 : 0 ]        fifo_id_d;
    reg  [ FIFO_ID_WIDTH        -1 : 0 ]        fifo_id_q;

    always @(posedge clk)
    begin
      if (reset) begin
        mem_access_state_q <= 1'b0;
        fifo_id_q <= 0;
        ld_addr_q <= 0;
      end else begin
        mem_access_state_q <= mem_access_state_d;
        fifo_id_q <= fifo_id_d;
        ld_addr_q <= ld_addr_d;
      end
    end

    assign fsm_stall = mem_access_state_q == 1;

generate
if (NUM_FIFO == 1) begin
    assign mem_addr = ld_addr;
end else begin
    assign mem_addr = mem_access_state_q ? {ld_addr_q, fifo_id_q} : {ld_addr, fifo_id_q};
end
endgenerate

    always @(*)
    begin: MEM_ACCESS_STATE
      mem_access_state_d = mem_access_state_q;
      fifo_id_d = fifo_id_q;
      ld_addr_d = ld_addr_q;
      case (mem_access_state_q)
        0: begin
          if (mem_req && NUM_FIFO > 1) begin
            mem_access_state_d = 1;
            fifo_id_d = 1;
            ld_addr_d = ld_addr;
          end
        end
        1: begin
          if (mem_req) begin
            if (fifo_id_q == NUM_FIFO-1) begin
              fifo_id_d = 0;
              mem_access_state_d = 0;
            end else begin
              fifo_id_d = fifo_id_q + 1;
            end
          end
        end
      endcase
    end

    always @(posedge clk)
    begin
      if (reset)
        done_state_q <= 1'b0;
      else
        done_state_q <= done_state_d;
    end

    always @(*)
    begin
      done_state_d = done_state_q;
      case (done_state_q)
        1'b0: begin
          if (loop_ctrl_done)
            done_state_d = 1'b1;
        end
        1'b1: begin
          if (done)
            done_state_d = 1'b0;
        end
      endcase
    end
//==============================================================================

//==============================================================================
// Address generators
//==============================================================================
    wire                                        obuf_ld_stride_v;
    assign obuf_ld_stride_v = cfg_loop_stride_v && cfg_loop_stride_type == 0;
  mem_walker_stride #(
    .ADDR_WIDTH                     ( ADDR_WIDTH                     ),
    .ADDR_STRIDE_W                  ( ADDR_STRIDE_W                  ),
    .LOOP_ID_W                      ( LOOP_ID_W                      )
  ) mws_ld (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .base_addr                      ( base_addr                      ), //input
    .loop_ctrl_done                 ( loop_ctrl_done                 ), //input
    .loop_index                     ( loop_ctrl_index                ), //input
    .loop_index_valid               ( loop_ctrl_next_addr            ), //input
    .loop_init                      ( loop_ctrl_init                 ), //input
    .loop_enter                     ( loop_ctrl_enter                ), //input
    .loop_exit                      ( loop_ctrl_exit                 ), //input
    .cfg_addr_stride_v              ( obuf_ld_stride_v               ), //input
    .cfg_addr_stride                ( cfg_loop_stride                ), //input
    .addr_out                       ( ld_addr                        ), //output
    .addr_out_valid                 ( ld_addr_valid                  )  //output
  );
//==============================================================================

//==============================================================================
// Loop controller
//==============================================================================
  always@(posedge clk)
  begin
    if (reset)
      mem_loop_id_counter <= 'b0;
    else begin
      if (obuf_ld_loop_iter_v)
        mem_loop_id_counter <= mem_loop_id_counter + 1'b1;
      else if (start)
        mem_loop_id_counter <= 'b0;
    end
  end

    assign obuf_ld_loop_iter_v = cfg_loop_iter_v && cfg_loop_iter_type == 0;

  controller_fsm #(
    .LOOP_ID_W                      ( LOOP_ID_W                      ),
    .LOOP_ITER_W                    ( LOOP_ITER_W                    ),
    .IMEM_ADDR_W                    ( LOOP_ID_W                      )
  ) loop_ctrl (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .stall                          ( loop_ctrl_stall                ), //input
    .cfg_loop_iter_v                ( obuf_ld_loop_iter_v            ), //input
    .cfg_loop_iter                  ( cfg_loop_iter                  ), //input
    .cfg_loop_iter_loop_id          ( mem_loop_id_counter            ), //input
    .start                          ( start                          ), //input
    .done                           ( loop_ctrl_done                 ), //output
    .loop_init                      ( loop_ctrl_init                 ), //output
    .loop_enter                     ( loop_ctrl_enter                ), //output
    .loop_last_iter                 (                                ), //output
    .loop_exit                      ( loop_ctrl_exit                 ), //output
    .loop_index                     ( loop_ctrl_index                ), //output
    .loop_index_valid               ( loop_ctrl_index_valid          )  //output
  );
//==============================================================================

//==============================================================================
// VCD
//==============================================================================
`ifdef COCOTB_TOPLEVEL_pu_ld_obuf_wrapper
initial begin
  $dumpfile("pu_ld_obuf_wrapper.vcd");
  $dumpvars(0, pu_ld_obuf_wrapper);
end
`endif
//==============================================================================
endmodule
