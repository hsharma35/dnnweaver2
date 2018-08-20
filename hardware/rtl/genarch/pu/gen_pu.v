`timescale 1ns / 1ps
module gen_pu #(
  // Instruction width for PU controller
    parameter integer  INST_WIDTH                   = 32,
  // Data width
    parameter integer  DATA_WIDTH                   = 16,
    parameter integer  ACC_DATA_WIDTH               = 64,
  // SIMD Data width
    parameter integer  SIMD_LANES                   = 4,
    parameter integer  SIMD_DATA_WIDTH              = DATA_WIDTH * SIMD_LANES,

    parameter integer  OBUF_AXI_DATA_WIDTH          = ACC_DATA_WIDTH * SIMD_LANES,
    parameter integer  SIMD_INTERIM_WIDTH           = SIMD_LANES * ACC_DATA_WIDTH,
    parameter integer  NUM_FIFO                     = SIMD_INTERIM_WIDTH / OBUF_AXI_DATA_WIDTH,

    parameter integer  RF_ADDR_WIDTH                = 3,
    parameter integer  SRC_ADDR_WIDTH               = 4,

    parameter integer  OP_WIDTH                     = 3,
    parameter integer  FN_WIDTH                     = 3,
    parameter integer  IMM_WIDTH                    = 16,
    parameter integer  ADDR_STRIDE_W                = 32,

    parameter integer  OBUF_ADDR_WIDTH              = 12,

    parameter integer  AXI_ADDR_WIDTH               = 42,
    parameter integer  AXI_ID_WIDTH                 = 1,
    parameter integer  AXI_BURST_WIDTH              = 8,
    parameter integer  AXI_DATA_WIDTH               = SIMD_DATA_WIDTH,
    parameter integer  AXI_WSTRB_WIDTH              = AXI_DATA_WIDTH / 8
)
(
    input  wire                                         clk,
    input  wire                                         reset,

  // Handshake
    output wire                                         done,
    output wire  [ 3                    -1 : 0 ]        pu_ctrl_state,

    input  wire                                         pu_block_start,
    input  wire                                         pu_compute_start,
    output wire                                         pu_compute_ready,
    output wire                                         pu_compute_done,
    output wire                                         pu_write_done,

  // Buffer instruction write (to PE) interface
    input  wire                                         inst_wr_req,
    input  wire  [ INST_WIDTH           -1 : 0 ]        inst_wr_data,
    output wire                                         inst_wr_ready,

  // Load from Sys Array OBUF - ADDR
    output wire                                         ld_obuf_req,
    output wire  [ OBUF_ADDR_WIDTH      -1 : 0 ]        ld_obuf_addr,
    input  wire                                         ld_obuf_ready,

  // Load from Sys Array OBUF - DATA
    input  wire  [ OBUF_AXI_DATA_WIDTH  -1 : 0 ]        obuf_ld_stream_write_data,
    input  wire                                         obuf_ld_stream_write_req,

  // CL_wrapper -> DDR0 AXI4 interface
  // Master Interface Write Address
    output wire  [ AXI_ADDR_WIDTH       -1 : 0 ]        pu_ddr_awaddr,
    output wire  [ AXI_BURST_WIDTH      -1 : 0 ]        pu_ddr_awlen,
    output wire  [ 3                    -1 : 0 ]        pu_ddr_awsize,
    output wire  [ 2                    -1 : 0 ]        pu_ddr_awburst,
    output wire                                         pu_ddr_awvalid,
    input  wire                                         pu_ddr_awready,
  // Master Interface Write Data
    output wire  [ AXI_DATA_WIDTH       -1 : 0 ]        pu_ddr_wdata,
    output wire  [ AXI_WSTRB_WIDTH      -1 : 0 ]        pu_ddr_wstrb,
    output wire                                         pu_ddr_wlast,
    output wire                                         pu_ddr_wvalid,
    input  wire                                         pu_ddr_wready,
  // Master Interface Write Response
    input  wire  [ 2                    -1 : 0 ]        pu_ddr_bresp,
    input  wire                                         pu_ddr_bvalid,
    output wire                                         pu_ddr_bready,
  // Master Interface Read Address
    output wire  [ AXI_ID_WIDTH         -1 : 0 ]        pu_ddr_arid,
    output wire  [ AXI_ADDR_WIDTH       -1 : 0 ]        pu_ddr_araddr,
    output wire  [ AXI_BURST_WIDTH      -1 : 0 ]        pu_ddr_arlen,
    output wire  [ 3                    -1 : 0 ]        pu_ddr_arsize,
    output wire  [ 2                    -1 : 0 ]        pu_ddr_arburst,
    output wire                                         pu_ddr_arvalid,
    input  wire                                         pu_ddr_arready,
  // Master Interface Read Data
    input  wire  [ AXI_ID_WIDTH         -1 : 0 ]        pu_ddr_rid,
    input  wire  [ AXI_DATA_WIDTH       -1 : 0 ]        pu_ddr_rdata,
    input  wire  [ 2                    -1 : 0 ]        pu_ddr_rresp,
    input  wire                                         pu_ddr_rlast,
    input  wire                                         pu_ddr_rvalid,
    output wire                                         pu_ddr_rready,

    output wire  [ INST_WIDTH           -1 : 0 ]        obuf_ld_stream_read_count,
    output wire  [ INST_WIDTH           -1 : 0 ]        obuf_ld_stream_write_count,
    output wire  [ INST_WIDTH           -1 : 0 ]        ddr_st_stream_read_count,
    output wire  [ INST_WIDTH           -1 : 0 ]        ddr_st_stream_write_count,
    output wire  [ INST_WIDTH           -1 : 0 ]        ld0_stream_counts,
    output wire  [ INST_WIDTH           -1 : 0 ]        ld1_stream_counts,
    output wire  [ INST_WIDTH           -1 : 0 ]        axi_wr_fifo_counts

  );

//==============================================================================
// Wires and Regs
//==============================================================================
    wire                                        obuf_ld_stream_read_req;
    wire                                        obuf_ld_stream_read_ready;
    wire                                        ddr_ld0_stream_read_req;
    wire                                        ddr_ld0_stream_read_ready;
    wire                                        ddr_ld1_stream_read_req;
    wire                                        ddr_ld1_stream_read_ready;
    wire                                        ddr_st_stream_write_req;
    wire                                        ddr_st_stream_write_ready;

    wire                                        ld_obuf_done;

    wire                                        ddr_st_done;

    wire                                        ld_data_ready;
    wire                                        ld_data_valid;

    wire                                        cfg_loop_iter_v;
    wire [ IMM_WIDTH            -1 : 0 ]        cfg_loop_iter;
    wire [ 3                    -1 : 0 ]        cfg_loop_iter_type;

    wire                                        cfg_loop_stride_v;
    wire [ ADDR_STRIDE_W        -1 : 0 ]        cfg_loop_stride;
    wire [ 3                    -1 : 0 ]        cfg_loop_stride_type;

    wire                                        cfg_mem_req_v;
    wire [ 2                    -1 : 0 ]        cfg_mem_req_type;

    wire                                        alu_fn_valid;
    wire [ 3                    -1 : 0 ]        alu_fn;
    wire [ 4                    -1 : 0 ]        alu_in0_addr;
    wire                                        alu_in1_src;
    wire [ 4                    -1 : 0 ]        alu_in1_addr;
    wire [ IMM_WIDTH            -1 : 0 ]        alu_imm;
    wire [ 4                    -1 : 0 ]        alu_out_addr;

    wire                                        obuf_ld_stream_write_ready;
    wire                                        ddr_ld0_stream_write_req;
    wire                                        ddr_ld0_stream_write_ready;
    wire [ AXI_DATA_WIDTH       -1 : 0 ]        ddr_ld0_stream_write_data;
    wire                                        ddr_ld1_stream_write_req;
    wire                                        ddr_ld1_stream_write_ready;
    wire [ AXI_DATA_WIDTH       -1 : 0 ]        ddr_ld1_stream_write_data;
    wire                                        ddr_st_stream_read_req;
    wire [ AXI_DATA_WIDTH       -1 : 0 ]        ddr_st_stream_read_data;
    wire                                        ddr_st_stream_read_ready;

    wire                                        ld_obuf_start;
    wire [ OBUF_ADDR_WIDTH      -1 : 0 ]        ld_obuf_base_addr;

    wire                                        pu_ddr_start;
    wire                                        pu_ddr_done;
    wire                                        pu_ddr_data_valid;

    wire [ AXI_ADDR_WIDTH       -1 : 0 ]        pu_ddr_st_base_addr;
    wire [ AXI_ADDR_WIDTH       -1 : 0 ]        pu_ddr_ld0_base_addr;
    wire [ AXI_ADDR_WIDTH       -1 : 0 ]        pu_ddr_ld1_base_addr;

    wire                                        pu_ld0_read_req;
    wire                                        pu_ld1_read_req;

    wire                                        ddr_ld0_req;
    wire                                        ddr_ld0_ready;
    wire [ SIMD_DATA_WIDTH      -1 : 0 ]        ddr_ld0_data;
    wire                                        ddr_ld1_req;
    wire                                        ddr_ld1_ready;
    wire [ SIMD_DATA_WIDTH      -1 : 0 ]        ddr_ld1_data;
    wire                                        ddr_st_req;
    wire                                        ddr_st_ready;
    wire [ SIMD_DATA_WIDTH      -1 : 0 ]        ddr_st_data;
//==============================================================================

//==============================================================================
// Assigns
//==============================================================================
    assign pu_write_done = ddr_st_done;
//==============================================================================

//==============================================================================
// Gen PU controller
//==============================================================================
  gen_pu_ctrl #(
    .ADDR_WIDTH                     ( AXI_ADDR_WIDTH                 )
  )
  u_ctrl (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input

    .pu_block_start                 ( pu_block_start                 ), //input
    .pu_compute_start               ( pu_compute_start               ), //input
    .pu_compute_ready               ( pu_compute_ready               ), //output

    .tag_ld0_base_addr              ( pu_ddr_ld0_base_addr           ), //output
    .tag_ld1_base_addr              ( pu_ddr_ld1_base_addr           ), //output
    .tag_st_base_addr               ( pu_ddr_st_base_addr            ), //output

    .pu_ctrl_state                  ( pu_ctrl_state                  ), //output
    .done                           ( done                           ), //output

    .inst_wr_req                    ( inst_wr_req                    ), //input
    .inst_wr_data                   ( inst_wr_data                   ), //input
    .inst_wr_ready                  ( inst_wr_ready                  ), //output

    .cfg_loop_iter_v                ( cfg_loop_iter_v                ), //output
    .cfg_loop_iter                  ( cfg_loop_iter                  ), //output
    .cfg_loop_iter_type             ( cfg_loop_iter_type             ), //output

    .cfg_mem_req_v                  ( cfg_mem_req_v                  ), //output
    .cfg_mem_req_type               ( cfg_mem_req_type               ), //output

    .cfg_loop_stride_v              ( cfg_loop_stride_v              ), //output
    .cfg_loop_stride                ( cfg_loop_stride                ), //output
    .cfg_loop_stride_type           ( cfg_loop_stride_type           ), //output

    .obuf_ld_stream_read_req        ( obuf_ld_stream_read_req        ), //output
    .obuf_ld_stream_read_ready      ( obuf_ld_stream_read_ready      ), //input
    .ddr_ld0_stream_read_req        ( ddr_ld0_stream_read_req        ), //output
    .ddr_ld0_stream_read_ready      ( ddr_ld0_stream_read_ready      ), //input
    .ddr_ld1_stream_read_req        ( ddr_ld1_stream_read_req        ), //output
    .ddr_ld1_stream_read_ready      ( ddr_ld1_stream_read_ready      ), //input
    .ddr_st_stream_write_req        ( ddr_st_stream_write_req        ), //output
    .ddr_st_stream_write_ready      ( ddr_st_stream_write_ready      ), //input
    .ddr_st_done                    ( ddr_st_done                    ), //input

    .alu_fn_valid                   ( alu_fn_valid                   ), //output
    .alu_in0_addr                   ( alu_in0_addr                   ), //output
    .alu_in1_src                    ( alu_in1_src                    ), //output
    .alu_in1_addr                   ( alu_in1_addr                   ), //output
    .alu_imm                        ( alu_imm                        ), //output
    .alu_out_addr                   ( alu_out_addr                   ), //output
    .alu_fn                         ( alu_fn                         )  //output
  );
//==============================================================================

//==============================================================================
// LD Obuf stream
//==============================================================================
    assign ld_obuf_start = pu_compute_start;
    assign ld_obuf_base_addr = 0;
    assign pu_compute_done = ld_obuf_done;

    wire [ OBUF_ADDR_WIDTH      -1 : 0 ]        ld_obuf_stride;
    assign ld_obuf_stride = cfg_loop_stride;

  pu_ld_obuf_wrapper #(
    .NUM_FIFO                       ( NUM_FIFO                       ),
    .SIMD_INTERIM_WIDTH             ( SIMD_INTERIM_WIDTH             ),
    .OBUF_AXI_DATA_WIDTH            ( OBUF_AXI_DATA_WIDTH            ),
    .ADDR_WIDTH                     ( OBUF_ADDR_WIDTH                )
  )
  u_ld_obuf_wrapper (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .start                          ( ld_obuf_start                  ), //input
    .done                           ( ld_obuf_done                   ), //output
    .base_addr                      ( ld_obuf_base_addr              ), //input
    .cfg_loop_iter_v                ( cfg_loop_iter_v                ), //output
    .cfg_loop_iter                  ( cfg_loop_iter                  ), //output
    .cfg_loop_iter_type             ( cfg_loop_iter_type             ), //output
    .cfg_loop_stride_v              ( cfg_loop_stride_v              ), //output
    .cfg_loop_stride                ( ld_obuf_stride                 ), //output
    .cfg_loop_stride_type           ( cfg_loop_stride_type           ), //output
    .mem_req                        ( ld_obuf_req                    ), //output
    .mem_ready                      ( ld_obuf_ready                  ), //output
    .mem_addr                       ( ld_obuf_addr                   ), //output
    .obuf_ld_stream_write_ready     ( obuf_ld_stream_write_ready     )  //input
  );
//==============================================================================

//==============================================================================
// LD/ST DDR stream
//==============================================================================
    assign pu_ddr_start = pu_compute_start;

  ldst_ddr_wrapper #(
    .SIMD_DATA_WIDTH                ( SIMD_DATA_WIDTH                ),
    .ADDR_STRIDE_W                  ( ADDR_STRIDE_W                  ),
    .AXI_DATA_WIDTH                 ( AXI_DATA_WIDTH                 ),
    .AXI_ADDR_WIDTH                 ( AXI_ADDR_WIDTH                 )
  )
  u_ldst_ddr_wrapper (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .start                          ( pu_ddr_start                   ), //input
    .pu_block_start                 ( pu_block_start                 ), //input
    .done                           ( ddr_st_done                    ), //output
    .st_base_addr                   ( pu_ddr_st_base_addr            ), //input
    .ld0_base_addr                  ( pu_ddr_ld0_base_addr           ), //input
    .ld1_base_addr                  ( pu_ddr_ld1_base_addr           ), //input
    .cfg_loop_stride_v              ( cfg_loop_stride_v              ), //input
    .cfg_loop_stride                ( cfg_loop_stride                ), //input
    .cfg_loop_stride_type           ( cfg_loop_stride_type           ), //input
    .cfg_loop_iter_v                ( cfg_loop_iter_v                ), //input
    .cfg_loop_iter                  ( cfg_loop_iter                  ), //input
    .cfg_loop_iter_type             ( cfg_loop_iter_type             ), //input

    .cfg_mem_req_v                  ( cfg_mem_req_v                  ), //input
    .cfg_mem_req_type               ( cfg_mem_req_type               ), //input

    .ddr_st_stream_read_req         ( ddr_st_stream_read_req         ), //output
    .ddr_st_stream_read_ready       ( ddr_st_stream_read_ready       ), //input
    .ddr_st_stream_read_data        ( ddr_st_stream_read_data        ), //input

    .ddr_ld0_stream_write_req       ( ddr_ld0_stream_write_req       ), //output
    .ddr_ld0_stream_write_data      ( ddr_ld0_stream_write_data      ), //input
    .ddr_ld0_stream_write_ready     ( ddr_ld0_stream_write_ready     ), //input

    .ddr_ld1_stream_write_req       ( ddr_ld1_stream_write_req       ), //output
    .ddr_ld1_stream_write_data      ( ddr_ld1_stream_write_data      ), //input
    .ddr_ld1_stream_write_ready     ( ddr_ld1_stream_write_ready     ), //input

    .pu_ddr_awaddr                  ( pu_ddr_awaddr                  ), //output
    .pu_ddr_awlen                   ( pu_ddr_awlen                   ), //output
    .pu_ddr_awsize                  ( pu_ddr_awsize                  ), //output
    .pu_ddr_awburst                 ( pu_ddr_awburst                 ), //output
    .pu_ddr_awvalid                 ( pu_ddr_awvalid                 ), //output
    .pu_ddr_awready                 ( pu_ddr_awready                 ), //input
    .pu_ddr_wdata                   ( pu_ddr_wdata                   ), //output
    .pu_ddr_wstrb                   ( pu_ddr_wstrb                   ), //output
    .pu_ddr_wlast                   ( pu_ddr_wlast                   ), //output
    .pu_ddr_wvalid                  ( pu_ddr_wvalid                  ), //output
    .pu_ddr_wready                  ( pu_ddr_wready                  ), //input
    .pu_ddr_bresp                   ( pu_ddr_bresp                   ), //input
    .pu_ddr_bvalid                  ( pu_ddr_bvalid                  ), //input
    .pu_ddr_bready                  ( pu_ddr_bready                  ), //output
    .pu_ddr_arid                    ( pu_ddr_arid                    ), //output
    .pu_ddr_araddr                  ( pu_ddr_araddr                  ), //output
    .pu_ddr_arlen                   ( pu_ddr_arlen                   ), //output
    .pu_ddr_arsize                  ( pu_ddr_arsize                  ), //output
    .pu_ddr_arburst                 ( pu_ddr_arburst                 ), //output
    .pu_ddr_arvalid                 ( pu_ddr_arvalid                 ), //output
    .pu_ddr_arready                 ( pu_ddr_arready                 ), //input
    .pu_ddr_rid                     ( pu_ddr_rid                     ), //input
    .pu_ddr_rdata                   ( pu_ddr_rdata                   ), //input
    .pu_ddr_rresp                   ( pu_ddr_rresp                   ), //input
    .pu_ddr_rlast                   ( pu_ddr_rlast                   ), //input
    .pu_ddr_rvalid                  ( pu_ddr_rvalid                  ), //input
    .pu_ddr_rready                  ( pu_ddr_rready                  )  //output
  );
//==============================================================================

//==============================================================================
// SIMD core - RF + ALU
//==============================================================================
    // assign ddr_st_stream_write_count = {u_ldst_ddr_wrapper.u_axi_mm_master.awr_req_buf.fifo_count, u_ldst_ddr_wrapper.u_axi_mm_master.wdata_req_buf.fifo_count};
    wire [15:0] ddr_wr_awr_req_buf = u_ldst_ddr_wrapper.u_axi_mm_master.awr_req_buf.fifo_count;
    wire [15:0] ddr_wr_wr_req_buf = u_ldst_ddr_wrapper.u_axi_mm_master.wdata_req_buf.fifo_count;
    assign axi_wr_fifo_counts = {ddr_wr_awr_req_buf, ddr_wr_wr_req_buf};
  simd_pu_core #(
    .DATA_WIDTH                     ( DATA_WIDTH                     ),
    .OBUF_AXI_DATA_WIDTH            ( OBUF_AXI_DATA_WIDTH            ),
    .AXI_DATA_WIDTH                 ( AXI_DATA_WIDTH                 ),
    .ACC_DATA_WIDTH                 ( ACC_DATA_WIDTH                 ),
    .SIMD_LANES                     ( SIMD_LANES                     ),
    .SIMD_DATA_WIDTH                ( SIMD_DATA_WIDTH                ),
    .SRC_ADDR_WIDTH                 ( SRC_ADDR_WIDTH                 ),
    .OP_WIDTH                       ( OP_WIDTH                       ),
    .FN_WIDTH                       ( FN_WIDTH                       ),
    .IMM_WIDTH                      ( IMM_WIDTH                      )
  ) simd_core (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input

    .obuf_ld_stream_write_req       ( obuf_ld_stream_write_req       ), //input
    .obuf_ld_stream_write_ready     ( obuf_ld_stream_write_ready     ), //output
    .obuf_ld_stream_write_data      ( obuf_ld_stream_write_data      ), //output

    // DEBUG
    .obuf_ld_stream_read_count      ( obuf_ld_stream_read_count      ), //output
    .obuf_ld_stream_write_count     ( obuf_ld_stream_write_count     ), //output
    .ddr_st_stream_read_count       ( ddr_st_stream_read_count       ), //output
    .ddr_st_stream_write_count      ( ddr_st_stream_write_count      ), //output
    .ld0_stream_counts              ( ld0_stream_counts              ), //output
    .ld1_stream_counts              ( ld1_stream_counts              ), //output
    // DEBUG


    .obuf_ld_stream_read_req        ( obuf_ld_stream_read_req        ), //input
    .obuf_ld_stream_read_ready      ( obuf_ld_stream_read_ready      ), //output
    .ddr_ld0_stream_read_req        ( ddr_ld0_stream_read_req        ), //input
    .ddr_ld0_stream_read_ready      ( ddr_ld0_stream_read_ready      ), //output
    .ddr_ld1_stream_read_req        ( ddr_ld1_stream_read_req        ), //input
    .ddr_ld1_stream_read_ready      ( ddr_ld1_stream_read_ready      ), //output
    .ddr_st_stream_write_req        ( ddr_st_stream_write_req        ), //input
    .ddr_st_stream_write_ready      ( ddr_st_stream_write_ready      ), //output

    .ddr_st_stream_read_req         ( ddr_st_stream_read_req         ), //input
    .ddr_st_stream_read_data        ( ddr_st_stream_read_data        ), //output
    .ddr_st_stream_read_ready       ( ddr_st_stream_read_ready       ), //output

    .ddr_ld0_stream_write_req       ( ddr_ld0_stream_write_req       ), //input
    .ddr_ld0_stream_write_data      ( ddr_ld0_stream_write_data      ), //output
    .ddr_ld0_stream_write_ready     ( ddr_ld0_stream_write_ready     ), //output

    .ddr_ld1_stream_write_req       ( ddr_ld1_stream_write_req       ), //input
    .ddr_ld1_stream_write_data      ( ddr_ld1_stream_write_data      ), //output
    .ddr_ld1_stream_write_ready     ( ddr_ld1_stream_write_ready     ), //output

    .alu_fn_valid                   ( alu_fn_valid                   ), //input
    .alu_fn                         ( alu_fn                         ), //input
    .alu_imm                        ( alu_imm                        ), //input
    .alu_in0_addr                   ( alu_in0_addr                   ), //input
    .alu_in1_src                    ( alu_in1_src                    ), //input
    .alu_in1_addr                   ( alu_in1_addr                   ), //input
    .alu_out_addr                   ( alu_out_addr                   )  //input
  );
//==============================================================================

//==============================================================================
// VCD
//==============================================================================
  `ifdef COCOTB_TOPLEVEL_gen_pu
  initial begin
    $dumpfile("gen_pu.vcd");
    $dumpvars(0, gen_pu);
  end
  `endif
//==============================================================================

endmodule
