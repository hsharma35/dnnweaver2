//
// Base address generator
//
// Hardik Sharma
// (hsharma@gatech.edu)

`timescale 1ns/1ps
module base_addr_gen #(
  // Internal Parameters
  parameter integer  BASE_ID                      = 1,
  parameter integer  IBUF_MEM_ID                  = 0,
  parameter integer  OBUF_MEM_ID                  = 1,
  parameter integer  WBUF_MEM_ID                  = 2,
  parameter integer  BBUF_MEM_ID                  = 3,

  parameter integer  MEM_REQ_W                    = 16,
  parameter integer  IBUF_ADDR_WIDTH              = 8,
  parameter integer  WBUF_ADDR_WIDTH              = 8,
  parameter integer  OBUF_ADDR_WIDTH              = 8,
  parameter integer  BBUF_ADDR_WIDTH              = 8,
  parameter integer  DATA_WIDTH                   = 32,
  parameter integer  LOOP_ITER_W                  = 16,
  parameter integer  ADDR_STRIDE_W                = 16,
  parameter integer  LOOP_ID_W                    = 5,
  parameter integer  BUF_TYPE_W                   = 2
) (
  input  wire                                         clk,
  input  wire                                         reset,

  input  wire                                         start,
  output wire                                         done,

  output wire                                         tag_req,
  input  wire                                         tag_ready,

  // Programming
  input  wire                                         cfg_loop_iter_v,
  input  wire  [ LOOP_ITER_W          -1 : 0 ]        cfg_loop_iter,
  input  wire  [ LOOP_ID_W            -1 : 0 ]        cfg_loop_iter_loop_id,

  // Programming
  input  wire                                         cfg_loop_stride_v,
  input  wire  [ ADDR_STRIDE_W        -1 : 0 ]        cfg_loop_stride,
  input  wire  [ LOOP_ID_W            -1 : 0 ]        cfg_loop_stride_loop_id,
  input  wire  [ BUF_TYPE_W           -1 : 0 ]        cfg_loop_stride_id,
  input  wire  [ 2                    -1 : 0 ]        cfg_loop_stride_type,

  // Address - OBUF LD/ST
  input  wire  [ OBUF_ADDR_WIDTH      -1 : 0 ]        obuf_base_addr,
  output wire  [ OBUF_ADDR_WIDTH      -1 : 0 ]        obuf_ld_addr,
  output wire                                         obuf_ld_addr_v,
  output wire  [ OBUF_ADDR_WIDTH      -1 : 0 ]        obuf_st_addr,
  output wire                                         obuf_st_addr_v,
  // Address - IBUF LD
  input  wire  [ IBUF_ADDR_WIDTH      -1 : 0 ]        ibuf_base_addr,
  output wire  [ IBUF_ADDR_WIDTH      -1 : 0 ]        ibuf_ld_addr,
  output wire                                         ibuf_ld_addr_v,
  // Address - WBUF LD
  input  wire  [ WBUF_ADDR_WIDTH      -1 : 0 ]        wbuf_base_addr,
  output wire  [ WBUF_ADDR_WIDTH      -1 : 0 ]        wbuf_ld_addr,
  output wire                                         wbuf_ld_addr_v,
  // Address - BIAS LD
  input  wire  [ BBUF_ADDR_WIDTH      -1 : 0 ]        bias_base_addr,
  output wire  [ BBUF_ADDR_WIDTH      -1 : 0 ]        bias_ld_addr,
  output wire                                         bias_ld_addr_v,

  output wire                                         bias_prev_sw,
  output wire                                         ddr_pe_sw
);

//==============================================================================
// Wires/Regs
//==============================================================================
  // Programming - Base loop
  wire                                        cfg_base_loop_iter_v;
  wire [ LOOP_ITER_W          -1 : 0 ]        cfg_base_loop_iter;
  reg  [ LOOP_ID_W            -1 : 0 ]        cfg_base_loop_iter_loop_id;

  // Base loop
  wire                                        base_loop_start;
  wire                                        base_loop_done;
  wire                                        base_loop_stall;
  wire                                        base_loop_init;
  wire                                        base_loop_enter;
  wire                                        base_loop_exit;
  wire                                        base_loop_last_iter;
  wire [ LOOP_ID_W            -1 : 0 ]        base_loop_index;
  wire                                        base_loop_index_valid;
  wire                                        _base_loop_index_valid;

  // Programming - OBUF LD/ST
  wire                                        obuf_stride_v;
  wire [ ADDR_STRIDE_W        -1 : 0 ]        obuf_stride;
  // Programming - Bias
  wire                                        bias_stride_v;
  wire [ ADDR_STRIDE_W        -1 : 0 ]        bias_stride;
  // Programming - OBUF ST
  wire                                        ibuf_stride_v;
  wire [ ADDR_STRIDE_W        -1 : 0 ]        ibuf_stride;
  // Programming - OBUF ST
  wire                                        wbuf_stride_v;
  wire [ ADDR_STRIDE_W        -1 : 0 ]        wbuf_stride;


  wire [ OBUF_ADDR_WIDTH      -1 : 0 ]        obuf_addr;
  wire                                        obuf_addr_v;


  reg  [ MEM_REQ_W            -1 : 0 ]        obuf_ld_req_size;
  reg  [ MEM_REQ_W            -1 : 0 ]        obuf_st_req_size;

  wire                                        obuf_ld_req_valid;
  wire                                        obuf_st_req_valid;

  reg  [ MEM_REQ_W            -1 : 0 ]        obuf_ld_req_loop_id;
  reg  [ MEM_REQ_W            -1 : 0 ]        obuf_st_req_loop_id;

  wire                                        cfg_base_stride_v;
//==============================================================================

//==============================================================================
// Assigns
//==============================================================================
  assign cfg_base_loop_iter_v = cfg_loop_iter_v && cfg_loop_iter_loop_id == BASE_ID * 16;
  assign cfg_base_loop_iter = cfg_loop_iter;

  assign cfg_base_stride_v = cfg_loop_stride_v && cfg_loop_stride_loop_id == BASE_ID * 16;

  assign obuf_stride = cfg_loop_stride;
  assign obuf_stride_v = cfg_base_stride_v && cfg_loop_stride_type[0] == 1'b0 && cfg_loop_stride_id == OBUF_MEM_ID;
  assign bias_stride = cfg_loop_stride;
  assign bias_stride_v = cfg_base_stride_v && cfg_loop_stride_type[0] == 1'b0 && cfg_loop_stride_id == BBUF_MEM_ID;
  assign ibuf_stride = cfg_loop_stride;
  assign ibuf_stride_v = cfg_base_stride_v && cfg_loop_stride_type[0] == 1'b0 && cfg_loop_stride_id == IBUF_MEM_ID;
  assign wbuf_stride = cfg_loop_stride;
  assign wbuf_stride_v = cfg_base_stride_v && cfg_loop_stride_type[0] == 1'b0 && cfg_loop_stride_id == WBUF_MEM_ID;
//==============================================================================

//==============================================================================
// Address generators
//==============================================================================
  mem_walker_stride #(
    .ADDR_WIDTH                     ( OBUF_ADDR_WIDTH                ),
    .ADDR_STRIDE_W                  ( ADDR_STRIDE_W                  ),
    .LOOP_ID_W                      ( LOOP_ID_W                      )
  ) mws_obuf_ld (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .base_addr                      ( obuf_base_addr                 ), //input
    .loop_ctrl_done                 ( base_loop_done                 ), //input
    .loop_index                     ( base_loop_index                ), //input
    .loop_index_valid               ( _base_loop_index_valid         ), //input
    .loop_init                      ( base_loop_init                 ), //input
    .loop_enter                     ( base_loop_enter                ), //input
    .loop_exit                      ( base_loop_exit                 ), //input
    .cfg_addr_stride_v              ( obuf_stride_v                  ), //input
    .cfg_addr_stride                ( obuf_stride                    ), //input
    .addr_out                       ( obuf_addr                      ), //output
    .addr_out_valid                 ( obuf_addr_v                    )  //output
  );

  assign obuf_st_addr = obuf_addr;
  assign obuf_st_addr_v = obuf_addr_v;

  assign obuf_ld_addr = obuf_addr;
  assign obuf_ld_addr_v = obuf_addr_v;

  obuf_bias_sel_logic #(
    .LOOP_ID_W                      ( LOOP_ID_W                      ),
    .ADDR_STRIDE_W                  ( ADDR_STRIDE_W                  )
  ) u_sel_logic (
    .clk                            ( clk                            ), // input
    .reset                          ( reset                          ), // input
    .start                          ( start                          ), // input
    .done                           ( done                           ), // input
    .obuf_stride                    ( obuf_stride                    ), // input
    .obuf_stride_v                  ( obuf_stride_v                  ), // input
    .loop_stall                     ( base_loop_stall                ), // input
    .loop_enter                     ( base_loop_enter                ), // input
    .loop_exit                      ( base_loop_exit                 ), // input
    .loop_last_iter                 ( base_loop_last_iter            ), // input
    .loop_index_valid               ( base_loop_index_valid          ), // input
    .loop_index                     ( base_loop_index                ), // input
    .bias_prev_sw                   ( bias_prev_sw                   ), // output
    .ddr_pe_sw                      ( ddr_pe_sw                      )  // output
  );

  mem_walker_stride #(
    .ADDR_WIDTH                     ( BBUF_ADDR_WIDTH                ),
    .ADDR_STRIDE_W                  ( ADDR_STRIDE_W                  ),
    .LOOP_ID_W                      ( LOOP_ID_W                      )
  ) mws_bias_ld (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .base_addr                      ( bias_base_addr                 ), //input
    .loop_ctrl_done                 ( base_loop_done                 ), //input
    .loop_index                     ( base_loop_index                ), //input
    .loop_index_valid               ( _base_loop_index_valid         ), //input
    .loop_init                      ( base_loop_init                 ), //input
    .loop_enter                     ( base_loop_enter                ), //input
    .loop_exit                      ( base_loop_exit                 ), //input
    .cfg_addr_stride_v              ( bias_stride_v                  ), //input
    .cfg_addr_stride                ( bias_stride                    ), //input
    .addr_out                       ( bias_ld_addr                   ), //output
    .addr_out_valid                 ( bias_ld_addr_v                 )  //output
  );

  mem_walker_stride #(
    .ADDR_WIDTH                     ( IBUF_ADDR_WIDTH                ),
    .ADDR_STRIDE_W                  ( ADDR_STRIDE_W                  ),
    .LOOP_ID_W                      ( LOOP_ID_W                      )
  ) mws_ibuf_ld (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .base_addr                      ( ibuf_base_addr                 ), //input
    .loop_ctrl_done                 ( base_loop_done                 ), //input
    .loop_index                     ( base_loop_index                ), //input
    .loop_index_valid               ( _base_loop_index_valid         ), //input
    .loop_init                      ( base_loop_init                 ), //input
    .loop_enter                     ( base_loop_enter                ), //input
    .loop_exit                      ( base_loop_exit                 ), //input
    .cfg_addr_stride_v              ( ibuf_stride_v                  ), //input
    .cfg_addr_stride                ( ibuf_stride                    ), //input
    .addr_out                       ( ibuf_ld_addr                   ), //output
    .addr_out_valid                 ( ibuf_ld_addr_v                 )  //output
  );

  mem_walker_stride #(
    .ADDR_WIDTH                     ( WBUF_ADDR_WIDTH                ),
    .ADDR_STRIDE_W                  ( ADDR_STRIDE_W                  ),
    .LOOP_ID_W                      ( LOOP_ID_W                      )
  ) mws_wbuf_ld (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .base_addr                      ( wbuf_base_addr                 ), //input
    .loop_ctrl_done                 ( base_loop_done                 ), //input
    .loop_index                     ( base_loop_index                ), //input
    .loop_index_valid               ( _base_loop_index_valid         ), //input
    .loop_init                      ( base_loop_init                 ), //input
    .loop_enter                     ( base_loop_enter                ), //input
    .loop_exit                      ( base_loop_exit                 ), //input
    .cfg_addr_stride_v              ( wbuf_stride_v                  ), //input
    .cfg_addr_stride                ( wbuf_stride                    ), //input
    .addr_out                       ( wbuf_ld_addr                   ), //output
    .addr_out_valid                 ( wbuf_ld_addr_v                 )  //output
  );
//==============================================================================

//==============================================================================
// Base loop controller
//==============================================================================
  assign base_loop_start = start;
  assign base_loop_stall = !tag_ready;
  assign done = base_loop_done;
  assign tag_req = base_loop_index_valid; // && tag_ready;
  assign _base_loop_index_valid = tag_req && tag_ready;

  // assign cfg_base_loop_iter_loop_id = {1'b0, cfg_loop_iter_loop_id[3:0]};
  always @(posedge clk)
  begin
    if (reset)
      cfg_base_loop_iter_loop_id <= 0;
    else begin
      if (start)
        cfg_base_loop_iter_loop_id <= 0;
      else if (cfg_base_loop_iter_v)
        cfg_base_loop_iter_loop_id <= cfg_base_loop_iter_loop_id + 1'b1;
    end
  end

  controller_fsm #(
    .LOOP_ID_W                      ( LOOP_ID_W                      ),
    .LOOP_ITER_W                    ( LOOP_ITER_W                    ),
    .IMEM_ADDR_W                    ( LOOP_ID_W                      )
  ) base_loop_ctrl (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .cfg_loop_iter_v                ( cfg_base_loop_iter_v           ), //input
    .cfg_loop_iter                  ( cfg_base_loop_iter             ), //input
    .cfg_loop_iter_loop_id          ( cfg_base_loop_iter_loop_id     ), //input
    .start                          ( base_loop_start                ), //input
    .done                           ( base_loop_done                 ), //output
    .stall                          ( base_loop_stall                ), //input
    .loop_init                      ( base_loop_init                 ), //output
    .loop_enter                     ( base_loop_enter                ), //output
    .loop_exit                      ( base_loop_exit                 ), //output
    .loop_last_iter                 ( base_loop_last_iter            ), //output
    .loop_index                     ( base_loop_index                ), //output
    .loop_index_valid               ( base_loop_index_valid          )  //output
  );
//==============================================================================

//==============================================================================
// VCD
//==============================================================================
`ifdef COCOTB_TOPLEVEL_base_addr_gen
initial begin
  $dumpfile("base_addr_gen.vcd");
  $dumpvars(0, base_addr_gen);
end
`endif
//==============================================================================
endmodule
