//
// DnnWeaver2 controller
//
// Hardik Sharma
// (hsharma@gatech.edu)

`timescale 1ns/1ps
module dnnweaver2_controller #(
    parameter integer  NUM_TAGS                     = 2,
    parameter integer  ADDR_WIDTH                   = 42,
    parameter integer  ARRAY_N                      = 2,
    parameter integer  ARRAY_M                      = 2,

  // Precision
    parameter integer  DATA_WIDTH                   = 16,
    parameter integer  BIAS_WIDTH                   = 32,
    parameter integer  ACC_WIDTH                    = 64,

  // Buffers
    parameter integer  IBUF_CAPACITY_BITS           = ARRAY_N * DATA_WIDTH * 2048,
    parameter integer  WBUF_CAPACITY_BITS           = ARRAY_N * ARRAY_M * DATA_WIDTH * 512,
    parameter integer  OBUF_CAPACITY_BITS           = ARRAY_M * ACC_WIDTH * 2048,
    parameter integer  BBUF_CAPACITY_BITS           = ARRAY_M * BIAS_WIDTH * 2048,

  // Buffer Addr Width
    parameter integer  IBUF_ADDR_WIDTH              = $clog2(IBUF_CAPACITY_BITS / ARRAY_N / DATA_WIDTH),
    parameter integer  WBUF_ADDR_WIDTH              = $clog2(WBUF_CAPACITY_BITS / ARRAY_N / ARRAY_M / DATA_WIDTH),
    parameter integer  OBUF_ADDR_WIDTH              = $clog2(OBUF_CAPACITY_BITS / ARRAY_M / ACC_WIDTH),
    parameter integer  BBUF_ADDR_WIDTH              = $clog2(BBUF_CAPACITY_BITS / ARRAY_M / BIAS_WIDTH),

  // Instructions
    parameter integer  INST_ADDR_WIDTH              = 32,
    parameter integer  INST_DATA_WIDTH              = 32,
    parameter integer  INST_WSTRB_WIDTH             = INST_DATA_WIDTH / 8,
    parameter integer  INST_BURST_WIDTH             = 8,
    parameter integer  LOOP_ITER_W                  = 16,
    parameter integer  ADDR_STRIDE_W                = 32,
    parameter integer  MEM_REQ_W                    = 16,
    parameter integer  BUF_TYPE_W                   = 2,
    parameter integer  LOOP_ID_W                    = 5,
  // AGU
    parameter integer  OFFSET_W                     = ADDR_WIDTH,
  // AXI
    parameter integer  AXI_ADDR_WIDTH               = 42,
    parameter integer  AXI_ID_WIDTH                 = 1,
    parameter integer  AXI_BURST_WIDTH              = 8,
    parameter integer  TID_WIDTH                    = 4,
    parameter integer  IBUF_AXI_DATA_WIDTH          = 64,
    parameter integer  IBUF_WSTRB_W                 = IBUF_AXI_DATA_WIDTH/8,
    parameter integer  WBUF_AXI_DATA_WIDTH          = 64,
    parameter integer  WBUF_WSTRB_W                 = WBUF_AXI_DATA_WIDTH/8,
    parameter integer  OBUF_AXI_DATA_WIDTH          = 256,
    parameter integer  OBUF_WSTRB_W                 = OBUF_AXI_DATA_WIDTH/8,
    parameter integer  PU_AXI_DATA_WIDTH            = 64,
    parameter integer  PU_WSTRB_W                   = PU_AXI_DATA_WIDTH/8,
    parameter integer  BBUF_AXI_DATA_WIDTH          = 64,
    parameter integer  BBUF_WSTRB_W                 = BBUF_AXI_DATA_WIDTH/8,
  // AXI-Lite
    parameter integer  CTRL_ADDR_WIDTH              = 32,
    parameter integer  CTRL_DATA_WIDTH              = 32,
    parameter integer  CTRL_WSTRB_WIDTH             = CTRL_DATA_WIDTH/8,
  // Instruction Mem
    parameter integer  IMEM_ADDR_W                  = 7,
  // Systolic Array
    parameter integer  TAG_W                        = $clog2(NUM_TAGS),
    parameter          DTYPE                        = "FXP", // FXP for dnnweaver2, FP32 for single precision, FP16 for half-precision
    parameter integer  WBUF_DATA_WIDTH              = ARRAY_N * ARRAY_M * DATA_WIDTH,
    parameter integer  BBUF_DATA_WIDTH              = ARRAY_M * BIAS_WIDTH,
    parameter integer  IBUF_DATA_WIDTH              = ARRAY_N * DATA_WIDTH,
    parameter integer  OBUF_DATA_WIDTH              = ARRAY_M * ACC_WIDTH,

  // Buffer Addr width for PU access to OBUF
    parameter integer  PU_OBUF_ADDR_WIDTH           = OBUF_ADDR_WIDTH + $clog2(OBUF_DATA_WIDTH / OBUF_AXI_DATA_WIDTH)

) (
    input  wire                                         clk,
    input  wire                                         reset,

  // PCIe -> CL_wrapper AXI4-Lite interface
  // Slave Write address
    input  wire                                         pci_cl_ctrl_awvalid,
    input  wire  [ CTRL_ADDR_WIDTH      -1 : 0 ]        pci_cl_ctrl_awaddr,
    output wire                                         pci_cl_ctrl_awready,
  // Slave Write data
    input  wire                                         pci_cl_ctrl_wvalid,
    input  wire  [ CTRL_DATA_WIDTH      -1 : 0 ]        pci_cl_ctrl_wdata,
    input  wire  [ CTRL_WSTRB_WIDTH     -1 : 0 ]        pci_cl_ctrl_wstrb,
    output wire                                         pci_cl_ctrl_wready,
  // Slave Write response
    output wire                                         pci_cl_ctrl_bvalid,
    output wire  [ 2                    -1 : 0 ]        pci_cl_ctrl_bresp,
    input  wire                                         pci_cl_ctrl_bready,
  // Slave Read address
    input  wire                                         pci_cl_ctrl_arvalid,
    input  wire  [ CTRL_ADDR_WIDTH      -1 : 0 ]        pci_cl_ctrl_araddr,
    output wire                                         pci_cl_ctrl_arready,
  // Slave Read data/response
    output wire                                         pci_cl_ctrl_rvalid,
    output wire  [ CTRL_DATA_WIDTH      -1 : 0 ]        pci_cl_ctrl_rdata,
    output wire  [ 2                    -1 : 0 ]        pci_cl_ctrl_rresp,
    input  wire                                         pci_cl_ctrl_rready,

  // PCIe -> CL_wrapper AXI4 interface
  // Slave Interface Write Address
    input  wire  [ INST_ADDR_WIDTH      -1 : 0 ]        pci_cl_data_awaddr,
    input  wire  [ INST_BURST_WIDTH     -1 : 0 ]        pci_cl_data_awlen,
    input  wire  [ 3                    -1 : 0 ]        pci_cl_data_awsize,
    input  wire  [ 2                    -1 : 0 ]        pci_cl_data_awburst,
    input  wire                                         pci_cl_data_awvalid,
    output wire                                         pci_cl_data_awready,
  // Slave Interface Write Data
    input  wire  [ INST_DATA_WIDTH      -1 : 0 ]        pci_cl_data_wdata,
    input  wire  [ INST_WSTRB_WIDTH     -1 : 0 ]        pci_cl_data_wstrb,
    input  wire                                         pci_cl_data_wlast,
    input  wire                                         pci_cl_data_wvalid,
    output wire                                         pci_cl_data_wready,
  // Slave Interface Write Response
    output wire  [ 2                    -1 : 0 ]        pci_cl_data_bresp,
    output wire                                         pci_cl_data_bvalid,
    input  wire                                         pci_cl_data_bready,
  // Slave Interface Read Address
    input  wire  [ INST_ADDR_WIDTH      -1 : 0 ]        pci_cl_data_araddr,
    input  wire  [ INST_BURST_WIDTH     -1 : 0 ]        pci_cl_data_arlen,
    input  wire  [ 3                    -1 : 0 ]        pci_cl_data_arsize,
    input  wire  [ 2                    -1 : 0 ]        pci_cl_data_arburst,
    input  wire                                         pci_cl_data_arvalid,
    output wire                                         pci_cl_data_arready,
  // Slave Interface Read Data
    output wire  [ INST_DATA_WIDTH      -1 : 0 ]        pci_cl_data_rdata,
    output wire  [ 2                    -1 : 0 ]        pci_cl_data_rresp,
    output wire                                         pci_cl_data_rlast,
    output wire                                         pci_cl_data_rvalid,
    input  wire                                         pci_cl_data_rready,

  // CL_wrapper -> DDR0 AXI4 interface
  // Master Interface Write Address
    output wire  [ AXI_ADDR_WIDTH       -1 : 0 ]        cl_ddr0_awaddr,
    output wire  [ AXI_BURST_WIDTH      -1 : 0 ]        cl_ddr0_awlen,
    output wire  [ 3                    -1 : 0 ]        cl_ddr0_awsize,
    output wire  [ 2                    -1 : 0 ]        cl_ddr0_awburst,
    output wire                                         cl_ddr0_awvalid,
    input  wire                                         cl_ddr0_awready,
  // Master Interface Write Data
    output wire  [ IBUF_AXI_DATA_WIDTH  -1 : 0 ]        cl_ddr0_wdata,
    output wire  [ IBUF_WSTRB_W         -1 : 0 ]        cl_ddr0_wstrb,
    output wire                                         cl_ddr0_wlast,
    output wire                                         cl_ddr0_wvalid,
    input  wire                                         cl_ddr0_wready,
  // Master Interface Write Response
    input  wire  [ 2                    -1 : 0 ]        cl_ddr0_bresp,
    input  wire                                         cl_ddr0_bvalid,
    output wire                                         cl_ddr0_bready,
  // Master Interface Read Address
    output wire  [ AXI_ADDR_WIDTH       -1 : 0 ]        cl_ddr0_araddr,
    output wire  [ AXI_BURST_WIDTH      -1 : 0 ]        cl_ddr0_arlen,
    output wire  [ 3                    -1 : 0 ]        cl_ddr0_arsize,
    output wire  [ 2                    -1 : 0 ]        cl_ddr0_arburst,
    output wire                                         cl_ddr0_arvalid,
    output wire  [ AXI_ID_WIDTH         -1 : 0 ]        cl_ddr0_arid,
    input  wire                                         cl_ddr0_arready,
  // Master Interface Read Data
    input  wire  [ IBUF_AXI_DATA_WIDTH  -1 : 0 ]        cl_ddr0_rdata,
    input  wire  [ AXI_ID_WIDTH         -1 : 0 ]        cl_ddr0_rid,
    input  wire  [ 2                    -1 : 0 ]        cl_ddr0_rresp,
    input  wire                                         cl_ddr0_rlast,
    input  wire                                         cl_ddr0_rvalid,
    output wire                                         cl_ddr0_rready,

  // CL_wrapper -> DDR1 AXI4 interface
  // Master Interface Write Address
    output wire  [ AXI_ADDR_WIDTH       -1 : 0 ]        cl_ddr1_awaddr,
    output wire  [ AXI_BURST_WIDTH      -1 : 0 ]        cl_ddr1_awlen,
    output wire  [ 3                    -1 : 0 ]        cl_ddr1_awsize,
    output wire  [ 2                    -1 : 0 ]        cl_ddr1_awburst,
    output wire                                         cl_ddr1_awvalid,
    input  wire                                         cl_ddr1_awready,
  // Master Interface Write Data
    output wire  [ OBUF_AXI_DATA_WIDTH  -1 : 0 ]        cl_ddr1_wdata,
    output wire  [ OBUF_WSTRB_W         -1 : 0 ]        cl_ddr1_wstrb,
    output wire                                         cl_ddr1_wlast,
    output wire                                         cl_ddr1_wvalid,
    input  wire                                         cl_ddr1_wready,
  // Master Interface Write Response
    input  wire  [ 2                    -1 : 0 ]        cl_ddr1_bresp,
    input  wire                                         cl_ddr1_bvalid,
    output wire                                         cl_ddr1_bready,
  // Master Interface Read Address
    output wire  [ AXI_ADDR_WIDTH       -1 : 0 ]        cl_ddr1_araddr,
    output wire  [ AXI_BURST_WIDTH      -1 : 0 ]        cl_ddr1_arlen,
    output wire  [ 3                    -1 : 0 ]        cl_ddr1_arsize,
    output wire  [ 2                    -1 : 0 ]        cl_ddr1_arburst,
    output wire                                         cl_ddr1_arvalid,
    output wire  [ AXI_ID_WIDTH         -1 : 0 ]        cl_ddr1_arid,
    input  wire                                         cl_ddr1_arready,
  // Master Interface Read Data
    input  wire  [ OBUF_AXI_DATA_WIDTH  -1 : 0 ]        cl_ddr1_rdata,
    input  wire  [ AXI_ID_WIDTH         -1 : 0 ]        cl_ddr1_rid,
    input  wire  [ 2                    -1 : 0 ]        cl_ddr1_rresp,
    input  wire                                         cl_ddr1_rlast,
    input  wire                                         cl_ddr1_rvalid,
    output wire                                         cl_ddr1_rready,

  // CL_wrapper -> DDR2 AXI4 interface
  // Master Interface Write Address
    output wire  [ AXI_ADDR_WIDTH       -1 : 0 ]        cl_ddr2_awaddr,
    output wire  [ AXI_BURST_WIDTH      -1 : 0 ]        cl_ddr2_awlen,
    output wire  [ 3                    -1 : 0 ]        cl_ddr2_awsize,
    output wire  [ 2                    -1 : 0 ]        cl_ddr2_awburst,
    output wire                                         cl_ddr2_awvalid,
    input  wire                                         cl_ddr2_awready,
  // Master Interface Write Data
    output wire  [ WBUF_AXI_DATA_WIDTH  -1 : 0 ]        cl_ddr2_wdata,
    output wire  [ WBUF_WSTRB_W         -1 : 0 ]        cl_ddr2_wstrb,
    output wire                                         cl_ddr2_wlast,
    output wire                                         cl_ddr2_wvalid,
    input  wire                                         cl_ddr2_wready,
  // Master Interface Write Response
    input  wire  [ 2                    -1 : 0 ]        cl_ddr2_bresp,
    input  wire                                         cl_ddr2_bvalid,
    output wire                                         cl_ddr2_bready,
  // Master Interface Read Address
    output wire  [ AXI_ADDR_WIDTH       -1 : 0 ]        cl_ddr2_araddr,
    output wire  [ AXI_BURST_WIDTH      -1 : 0 ]        cl_ddr2_arlen,
    output wire  [ 3                    -1 : 0 ]        cl_ddr2_arsize,
    output wire  [ 2                    -1 : 0 ]        cl_ddr2_arburst,
    output wire                                         cl_ddr2_arvalid,
    output wire  [ AXI_ID_WIDTH         -1 : 0 ]        cl_ddr2_arid,
    input  wire                                         cl_ddr2_arready,
  // Master Interface Read Data
    input  wire  [ WBUF_AXI_DATA_WIDTH  -1 : 0 ]        cl_ddr2_rdata,
    input  wire  [ AXI_ID_WIDTH         -1 : 0 ]        cl_ddr2_rid,
    input  wire  [ 2                    -1 : 0 ]        cl_ddr2_rresp,
    input  wire                                         cl_ddr2_rlast,
    input  wire                                         cl_ddr2_rvalid,
    output wire                                         cl_ddr2_rready,

  // CL_wrapper -> DDR3 AXI4 interface
  // Master Interface Write Address
    output wire  [ AXI_ADDR_WIDTH       -1 : 0 ]        cl_ddr3_awaddr,
    output wire  [ AXI_BURST_WIDTH      -1 : 0 ]        cl_ddr3_awlen,
    output wire  [ 3                    -1 : 0 ]        cl_ddr3_awsize,
    output wire  [ 2                    -1 : 0 ]        cl_ddr3_awburst,
    output wire                                         cl_ddr3_awvalid,
    input  wire                                         cl_ddr3_awready,
  // Master Interface Write Data
    output wire  [ BBUF_AXI_DATA_WIDTH  -1 : 0 ]        cl_ddr3_wdata,
    output wire  [ BBUF_WSTRB_W         -1 : 0 ]        cl_ddr3_wstrb,
    output wire                                         cl_ddr3_wlast,
    output wire                                         cl_ddr3_wvalid,
    input  wire                                         cl_ddr3_wready,
  // Master Interface Write Response
    input  wire  [ 2                    -1 : 0 ]        cl_ddr3_bresp,
    input  wire                                         cl_ddr3_bvalid,
    output wire                                         cl_ddr3_bready,
  // Master Interface Read Address
    output wire  [ AXI_ADDR_WIDTH       -1 : 0 ]        cl_ddr3_araddr,
    output wire  [ AXI_BURST_WIDTH      -1 : 0 ]        cl_ddr3_arlen,
    output wire  [ 3                    -1 : 0 ]        cl_ddr3_arsize,
    output wire  [ 2                    -1 : 0 ]        cl_ddr3_arburst,
    output wire                                         cl_ddr3_arvalid,
    output wire  [ AXI_ID_WIDTH         -1 : 0 ]        cl_ddr3_arid,
    input  wire                                         cl_ddr3_arready,
  // Master Interface Read Data
    input  wire  [ BBUF_AXI_DATA_WIDTH  -1 : 0 ]        cl_ddr3_rdata,
    input  wire  [ AXI_ID_WIDTH         -1 : 0 ]        cl_ddr3_rid,
    input  wire  [ 2                    -1 : 0 ]        cl_ddr3_rresp,
    input  wire                                         cl_ddr3_rlast,
    input  wire                                         cl_ddr3_rvalid,
    output wire                                         cl_ddr3_rready,

  // CL_wrapper -> DDR3 AXI4 interface
  // Master Interface Write Address
    output wire  [ AXI_ADDR_WIDTH       -1 : 0 ]        cl_ddr4_awaddr,
    output wire  [ AXI_BURST_WIDTH      -1 : 0 ]        cl_ddr4_awlen,
    output wire  [ 3                    -1 : 0 ]        cl_ddr4_awsize,
    output wire  [ 2                    -1 : 0 ]        cl_ddr4_awburst,
    output wire                                         cl_ddr4_awvalid,
    input  wire                                         cl_ddr4_awready,
  // Master Interface Write Data
    output wire  [ PU_AXI_DATA_WIDTH    -1 : 0 ]        cl_ddr4_wdata,
    output wire  [ PU_WSTRB_W           -1 : 0 ]        cl_ddr4_wstrb,
    output wire                                         cl_ddr4_wlast,
    output wire                                         cl_ddr4_wvalid,
    input  wire                                         cl_ddr4_wready,
  // Master Interface Write Response
    input  wire  [ 2                    -1 : 0 ]        cl_ddr4_bresp,
    input  wire                                         cl_ddr4_bvalid,
    output wire                                         cl_ddr4_bready,
  // Master Interface Read Address
    output wire  [ AXI_ADDR_WIDTH       -1 : 0 ]        cl_ddr4_araddr,
    output wire  [ AXI_BURST_WIDTH      -1 : 0 ]        cl_ddr4_arlen,
    output wire  [ 3                    -1 : 0 ]        cl_ddr4_arsize,
    output wire  [ 2                    -1 : 0 ]        cl_ddr4_arburst,
    output wire                                         cl_ddr4_arvalid,
    output wire  [ AXI_ID_WIDTH         -1 : 0 ]        cl_ddr4_arid,
    input  wire                                         cl_ddr4_arready,
  // Master Interface Read Data
    input  wire  [ PU_AXI_DATA_WIDTH    -1 : 0 ]        cl_ddr4_rdata,
    input  wire  [ AXI_ID_WIDTH         -1 : 0 ]        cl_ddr4_rid,
    input  wire  [ 2                    -1 : 0 ]        cl_ddr4_rresp,
    input  wire                                         cl_ddr4_rlast,
    input  wire                                         cl_ddr4_rvalid,
    output wire                                         cl_ddr4_rready
  );

//=============================================================
// Localparams
//=============================================================
    localparam integer  STATE_W                      = 1;
    localparam integer  ACCUMULATOR_WIDTH            = 48;
  // localparam integer  PMAX                         = DATA_WIDTH;
  // localparam integer  PMIN                         = DATA_WIDTH;
//=============================================================

//=============================================================
// Wires/Regs
//=============================================================
    wire [ INST_DATA_WIDTH      -1 : 0 ]        obuf_ld_stream_read_count;
    wire [ INST_DATA_WIDTH      -1 : 0 ]        obuf_ld_stream_write_count;
    wire [ INST_DATA_WIDTH      -1 : 0 ]        ddr_st_stream_read_count;
    wire [ INST_DATA_WIDTH      -1 : 0 ]        ddr_st_stream_write_count;
    wire [ INST_DATA_WIDTH      -1 : 0 ]        ld0_stream_counts;
    wire [ INST_DATA_WIDTH      -1 : 0 ]        ld1_stream_counts;
    wire [ INST_DATA_WIDTH      -1 : 0 ]        axi_wr_fifo_counts;

  // OBUF STMEM state
    wire [ 4                    -1 : 0 ]        stmem_state;
    wire [ TAG_W                -1 : 0 ]        stmem_tag;
    wire                                        stmem_ddr_pe_sw;

  // PU
    wire                                        pu_compute_start;
    wire                                        pu_compute_ready;
    wire                                        pu_compute_done;
    wire                                        pu_write_done;
    wire [ 3                    -1 : 0 ]        pu_ctrl_state;
    wire                                        pu_done;
    wire                                        pu_inst_wr_ready;
  // PU -> OBUF addr
    wire                                        ld_obuf_req;
    wire                                        ld_obuf_ready;
    wire [ PU_OBUF_ADDR_WIDTH   -1 : 0 ]        ld_obuf_addr;
  // OBUF -> PU addr
    wire                                        obuf_ld_stream_write_req;
    wire [ OBUF_AXI_DATA_WIDTH  -1 : 0 ]        obuf_ld_stream_write_data;

  // Snoop
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        snoop_cl_ddr0_araddr;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        snoop_cl_ddr1_araddr;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        snoop_cl_ddr1_awaddr;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        snoop_cl_ddr2_araddr;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        snoop_cl_ddr3_araddr;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        snoop_cl_ddr4_araddr;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        snoop_cl_ddr4_awaddr;

  // PU Instructions
    wire                                        cfg_pu_inst_v;
    wire [ INST_DATA_WIDTH      -1 : 0 ]        cfg_pu_inst;
    wire                                        pu_block_start;
    wire                                        pu_block_end;
  // Systolic array
    wire                                        acc_clear;
    wire [ OBUF_DATA_WIDTH      -1 : 0 ]        sys_obuf_write_data;

  // switch between bias and obuf
    wire                                        rd_bias_prev_sw;

  // Loop iterations
    wire [ LOOP_ITER_W          -1 : 0 ]        cfg_loop_iter;
    wire [ LOOP_ID_W            -1 : 0 ]        cfg_loop_iter_loop_id;
    wire                                        cfg_loop_iter_v;
  // Loop stride
    wire [ 16                   -1 : 0 ]        cfg_loop_stride_lo;
    wire [ ADDR_STRIDE_W        -1 : 0 ]        cfg_loop_stride;
    wire                                        cfg_loop_stride_v;
    wire [ BUF_TYPE_W           -1 : 0 ]        cfg_loop_stride_id;
    wire [ 2                    -1 : 0 ]        cfg_loop_stride_type;
    wire [ LOOP_ID_W            -1 : 0 ]        cfg_loop_stride_loop_id;

  // Memory request
    wire [ MEM_REQ_W            -1 : 0 ]        cfg_mem_req_size;
    wire                                        cfg_mem_req_v;
    wire [ 2                    -1 : 0 ]        cfg_mem_req_type;
    wire [ BUF_TYPE_W           -1 : 0 ]        cfg_mem_req_id;
    wire [ LOOP_ID_W            -1 : 0 ]        cfg_mem_req_loop_id;
  // Buffer request
    wire [ MEM_REQ_W            -1 : 0 ]        cfg_buf_req_size;
    wire                                        cfg_buf_req_v;
    wire                                        cfg_buf_req_type;
    wire [ BUF_TYPE_W           -1 : 0 ]        cfg_buf_req_loop_id;

    wire                                        main_start;
    wire                                        main_done;

  // Address - OBUF
    wire [ ADDR_WIDTH           -1 : 0 ]        obuf_base_addr;
    wire [ ADDR_WIDTH           -1 : 0 ]        obuf_ld_addr;
    wire                                        obuf_ld_addr_v;
    wire [ ADDR_WIDTH           -1 : 0 ]        obuf_st_addr;
    wire                                        obuf_st_addr_v;
  // Address - IBUF
    wire [ ADDR_WIDTH           -1 : 0 ]        ibuf_base_addr;
    wire [ ADDR_WIDTH           -1 : 0 ]        ibuf_ld_addr;
    wire                                        ibuf_ld_addr_v;
  // Address - WBUF
    wire [ ADDR_WIDTH           -1 : 0 ]        wbuf_base_addr;
    wire [ ADDR_WIDTH           -1 : 0 ]        wbuf_ld_addr;
    wire                                        wbuf_ld_addr_v;
    wire [ ADDR_WIDTH           -1 : 0 ]        wbuf_st_addr;
    wire                                        wbuf_st_addr_v;
  // Address - BIAS
    wire [ ADDR_WIDTH           -1 : 0 ]        bias_base_addr;
    wire [ ADDR_WIDTH           -1 : 0 ]        bias_ld_addr;
    wire                                        bias_ld_addr_v;
    wire [ ADDR_WIDTH           -1 : 0 ]        bias_st_addr;
    wire                                        bias_st_addr_v;
  // Address - OBUF
    wire [ OBUF_ADDR_WIDTH      -1 : 0 ]        obuf_rd_addr;
    wire                                        obuf_rd_addr_v;
    wire [ OBUF_ADDR_WIDTH      -1 : 0 ]        obuf_wr_addr;
    wire                                        obuf_wr_addr_v;
  // Address - IBUF
    wire [ IBUF_ADDR_WIDTH      -1 : 0 ]        ibuf_rd_addr;
    wire                                        ibuf_rd_addr_v;
    wire [ IBUF_ADDR_WIDTH      -1 : 0 ]        ibuf_wr_addr;
    wire                                        ibuf_wr_addr_v;
  // Address - WBUF
    wire [ WBUF_ADDR_WIDTH      -1 : 0 ]        wbuf_rd_addr;
    wire                                        wbuf_rd_addr_v;
    wire [ WBUF_ADDR_WIDTH      -1 : 0 ]        wbuf_wr_addr;
    wire                                        wbuf_wr_addr_v;
  // Select logic for bias (0) or obuf_read_data (1)
    wire                                        compute_bias_prev_sw;
    wire                                        tag_bias_prev_sw;
    wire                                        tag_ddr_pe_sw;

  // IBUF
    wire [ IBUF_DATA_WIDTH      -1 : 0 ]        ibuf_read_data;
    wire                                        ibuf_read_req;
    wire [ IBUF_ADDR_WIDTH      -1 : 0 ]        ibuf_read_addr;

  // WBUF
    wire [ WBUF_DATA_WIDTH      -1 : 0 ]        wbuf_read_data;
    wire                                        wbuf_read_req;
    wire [ WBUF_ADDR_WIDTH      -1 : 0 ]        wbuf_read_addr;

  // BIAS
    wire [ BBUF_DATA_WIDTH      -1 : 0 ]        bbuf_read_data;
    wire                                        bias_read_req;
    wire [ BBUF_ADDR_WIDTH      -1 : 0 ]        bias_read_addr;
    wire                                        sys_bias_read_req;
    wire [ BBUF_ADDR_WIDTH      -1 : 0 ]        sys_bias_read_addr;

  // OBUF
    wire [ OBUF_DATA_WIDTH      -1 : 0 ]        obuf_write_data;
    wire                                        obuf_write_req;
    wire [ OBUF_ADDR_WIDTH      -1 : 0 ]        obuf_write_addr;
    wire [ OBUF_DATA_WIDTH      -1 : 0 ]        obuf_read_data;
    wire                                        obuf_read_req;
    wire [ OBUF_ADDR_WIDTH      -1 : 0 ]        obuf_read_addr;

    wire                                        sys_obuf_write_req;
    wire [ OBUF_ADDR_WIDTH      -1 : 0 ]        sys_obuf_write_addr;

    wire                                        sys_obuf_read_req;
    wire [ OBUF_ADDR_WIDTH      -1 : 0 ]        sys_obuf_read_addr;

  // Slave registers
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg0_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg0_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg1_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg1_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg2_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg2_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg3_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg3_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg4_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg4_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg5_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg5_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg6_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg6_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg7_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg7_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg8_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg8_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg9_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg9_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg10_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg10_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg11_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg11_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg12_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg12_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg13_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg13_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg14_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg14_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg15_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg15_out;
  // Slave registers end


    wire [ IMEM_ADDR_W          -1 : 0 ]        start_addr;

    reg  [ STATE_W              -1 : 0 ]        w_state_q;
    reg  [ STATE_W              -1 : 0 ]        w_state_d;

    reg  [ STATE_W              -1 : 0 ]        r_state_q;
    reg  [ STATE_W              -1 : 0 ]        r_state_d;

    reg  [ AXI_ADDR_WIDTH       -1 : 0 ]        w_addr_d;
    reg  [ AXI_ADDR_WIDTH       -1 : 0 ]        w_addr_q;

    wire                                        imem_read_req_a;
    wire [ IMEM_ADDR_W          -1 : 0 ]        imem_read_addr_a;
    wire [ INST_DATA_WIDTH      -1 : 0 ]        imem_read_data_a;

    wire                                        imem_write_req_a;
    wire [ IMEM_ADDR_W          -1 : 0 ]        imem_write_addr_a;
    wire [ INST_DATA_WIDTH      -1 : 0 ]        imem_write_data_a;

    wire                                        imem_read_req_b;
    wire [ IMEM_ADDR_W          -1 : 0 ]        imem_read_addr_b;
    wire [ INST_DATA_WIDTH      -1 : 0 ]        imem_read_data_b;

    wire                                        ibuf_tag_ready;
    wire                                        ibuf_tag_done;
    wire                                        ibuf_compute_ready;

    wire                                        wbuf_tag_ready;
    wire                                        wbuf_tag_done;
    wire                                        wbuf_compute_ready;

    wire                                        obuf_tag_ready;
    wire                                        obuf_tag_done;
    wire                                        obuf_compute_ready;
    wire                                        obuf_bias_prev_sw;

    wire                                        bias_tag_ready;
    wire                                        bias_tag_done;
    wire                                        bias_compute_ready;

    wire                                        tag_flush;
    wire                                        tag_req;
    wire                                        ibuf_tag_reuse;
    wire                                        obuf_tag_reuse;
    wire                                        wbuf_tag_reuse;
    wire                                        bias_tag_reuse;
    wire                                        sync_tag_req;
    wire                                        tag_ready;

    wire                                        compute_done;
    wire                                        compute_req;

    wire [ IBUF_ADDR_WIDTH      -1 : 0 ]        tie_ibuf_buf_base_addr;
    wire [ WBUF_ADDR_WIDTH      -1 : 0 ]        tie_wbuf_buf_base_addr;
    wire [ OBUF_ADDR_WIDTH      -1 : 0 ]        tie_obuf_buf_base_addr;
    wire [ BBUF_ADDR_WIDTH      -1 : 0 ]        tie_bias_buf_base_addr;

    wire                                        sys_array_c_sel;
//=============================================================

//=============================================================
// Assigns
//=============================================================
  // TODO: bias tag handling
  // Use the bias tag ready when obuf not needed
    assign compute_req = ibuf_compute_ready && wbuf_compute_ready && obuf_compute_ready && bias_compute_ready;
    assign tag_ready = (ibuf_tag_ready && wbuf_tag_ready && obuf_tag_ready && bias_tag_ready);

  // ST tie-offs
    assign wbuf_st_addr_v = 1'b0;
    assign wbuf_st_addr = 'b0;
    assign bias_st_addr_v = 1'b0;
    assign bias_st_addr = 'b0;

  // Address tie-off
    assign tie_ibuf_buf_base_addr = {IBUF_ADDR_WIDTH{1'b0}};
    assign tie_wbuf_buf_base_addr = {WBUF_ADDR_WIDTH{1'b0}};
    assign tie_obuf_buf_base_addr = {OBUF_ADDR_WIDTH{1'b0}};
    assign tie_bias_buf_base_addr = {BBUF_ADDR_WIDTH{1'b0}};

  // Buf write port tie-offs

  // Systolic array
    assign acc_clear = compute_done;

  // Synchronize tag req
    assign sync_tag_req = tag_req && ibuf_tag_ready && wbuf_tag_ready && obuf_tag_ready && bias_tag_ready;

  // Snoop
    assign snoop_cl_ddr0_araddr = cl_ddr0_araddr;
    assign snoop_cl_ddr1_araddr = cl_ddr1_araddr;
    assign snoop_cl_ddr1_awaddr = cl_ddr1_awaddr;
    assign snoop_cl_ddr2_araddr = cl_ddr2_araddr;
    assign snoop_cl_ddr3_araddr = cl_ddr3_araddr;
    assign snoop_cl_ddr4_araddr = cl_ddr4_araddr;
    assign snoop_cl_ddr4_awaddr = cl_ddr4_awaddr;

//=============================================================

//=============================================================
// Base controller
//    This module is in charge of the outer loops [16 - 31]
//=============================================================
  controller #(
    .CTRL_ADDR_WIDTH                ( CTRL_ADDR_WIDTH                ),
    .CTRL_DATA_WIDTH                ( CTRL_DATA_WIDTH                ),
    .INST_ADDR_WIDTH                ( INST_ADDR_WIDTH                )
  ) u_ctrl (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input

    .tag_flush                      ( tag_flush                      ), //output
    .tag_req                        ( tag_req                        ), //output
    .tag_ready                      ( tag_ready                      ), //input

    .compute_done                   ( compute_done                   ), //input
    .pu_compute_start               ( pu_compute_start               ), //input
    .pu_compute_done                ( pu_compute_done                ), //input
    .pu_write_done                  ( pu_write_done                  ), //input
    .pu_ctrl_state                  ( pu_ctrl_state                  ), //input

    //DEBUG
    .obuf_ld_stream_read_count      ( obuf_ld_stream_read_count      ), //input
    .obuf_ld_stream_write_count     ( obuf_ld_stream_write_count     ), //input
    .ddr_st_stream_read_count       ( ddr_st_stream_read_count       ), //input
    .ddr_st_stream_write_count      ( ddr_st_stream_write_count      ), //input
    .ld0_stream_counts              ( ld0_stream_counts              ), //output
    .ld1_stream_counts              ( ld1_stream_counts              ), //output
    .axi_wr_fifo_counts             ( axi_wr_fifo_counts             ), //output
    //DEBUG

    .ibuf_tag_reuse                 ( ibuf_tag_reuse                 ), //output
    .obuf_tag_reuse                 ( obuf_tag_reuse                 ), //output
    .wbuf_tag_reuse                 ( wbuf_tag_reuse                 ), //output
    .bias_tag_reuse                 ( bias_tag_reuse                 ), //output

    .ibuf_tag_done                  ( ibuf_tag_done                  ), //input
    .wbuf_tag_done                  ( wbuf_tag_done                  ), //input
    .obuf_tag_done                  ( obuf_tag_done                  ), //input
    .bias_tag_done                  ( bias_tag_done                  ), //input

    .tag_bias_prev_sw               ( tag_bias_prev_sw               ), //output
    .tag_ddr_pe_sw                  ( tag_ddr_pe_sw                  ), //output
    .bias_ld_addr                   ( bias_ld_addr                   ), //output
    .bias_ld_addr_v                 ( bias_ld_addr_v                 ), //output
    .ibuf_ld_addr                   ( ibuf_ld_addr                   ), //output
    .ibuf_ld_addr_v                 ( ibuf_ld_addr_v                 ), //output
    .wbuf_ld_addr                   ( wbuf_ld_addr                   ), //output
    .wbuf_ld_addr_v                 ( wbuf_ld_addr_v                 ), //output
    .obuf_ld_addr                   ( obuf_ld_addr                   ), //output
    .obuf_ld_addr_v                 ( obuf_ld_addr_v                 ), //output
    .obuf_st_addr                   ( obuf_st_addr                   ), //output
    .obuf_st_addr_v                 ( obuf_st_addr_v                 ), //output

    .stmem_state                    ( stmem_state                    ), //input
    .stmem_tag                      ( stmem_tag                      ), //input
    .stmem_ddr_pe_sw                ( stmem_ddr_pe_sw                ), //input

    .pci_cl_ctrl_awvalid            ( pci_cl_ctrl_awvalid            ), //input
    .pci_cl_ctrl_awaddr             ( pci_cl_ctrl_awaddr             ), //input
    .pci_cl_ctrl_awready            ( pci_cl_ctrl_awready            ), //output
    .pci_cl_ctrl_wvalid             ( pci_cl_ctrl_wvalid             ), //input
    .pci_cl_ctrl_wdata              ( pci_cl_ctrl_wdata              ), //input
    .pci_cl_ctrl_wstrb              ( pci_cl_ctrl_wstrb              ), //input
    .pci_cl_ctrl_wready             ( pci_cl_ctrl_wready             ), //output
    .pci_cl_ctrl_bvalid             ( pci_cl_ctrl_bvalid             ), //output
    .pci_cl_ctrl_bresp              ( pci_cl_ctrl_bresp              ), //output
    .pci_cl_ctrl_bready             ( pci_cl_ctrl_bready             ), //input
    .pci_cl_ctrl_arvalid            ( pci_cl_ctrl_arvalid            ), //input
    .pci_cl_ctrl_araddr             ( pci_cl_ctrl_araddr             ), //input
    .pci_cl_ctrl_arready            ( pci_cl_ctrl_arready            ), //output
    .pci_cl_ctrl_rvalid             ( pci_cl_ctrl_rvalid             ), //output
    .pci_cl_ctrl_rdata              ( pci_cl_ctrl_rdata              ), //output
    .pci_cl_ctrl_rresp              ( pci_cl_ctrl_rresp              ), //output
    .pci_cl_ctrl_rready             ( pci_cl_ctrl_rready             ), //input

    .pci_cl_data_awaddr             ( pci_cl_data_awaddr             ), //input
    .pci_cl_data_awlen              ( pci_cl_data_awlen              ), //input
    .pci_cl_data_awsize             ( pci_cl_data_awsize             ), //input
    .pci_cl_data_awburst            ( pci_cl_data_awburst            ), //input
    .pci_cl_data_awvalid            ( pci_cl_data_awvalid            ), //input
    .pci_cl_data_awready            ( pci_cl_data_awready            ), //output
    .pci_cl_data_wdata              ( pci_cl_data_wdata              ), //input
    .pci_cl_data_wstrb              ( pci_cl_data_wstrb              ), //input
    .pci_cl_data_wlast              ( pci_cl_data_wlast              ), //input
    .pci_cl_data_wvalid             ( pci_cl_data_wvalid             ), //input
    .pci_cl_data_wready             ( pci_cl_data_wready             ), //output
    .pci_cl_data_bresp              ( pci_cl_data_bresp              ), //output
    .pci_cl_data_bvalid             ( pci_cl_data_bvalid             ), //output
    .pci_cl_data_bready             ( pci_cl_data_bready             ), //input
    .pci_cl_data_araddr             ( pci_cl_data_araddr             ), //input
    .pci_cl_data_arlen              ( pci_cl_data_arlen              ), //input
    .pci_cl_data_arsize             ( pci_cl_data_arsize             ), //input
    .pci_cl_data_arburst            ( pci_cl_data_arburst            ), //input
    .pci_cl_data_arvalid            ( pci_cl_data_arvalid            ), //input
    .pci_cl_data_arready            ( pci_cl_data_arready            ), //output
    .pci_cl_data_rdata              ( pci_cl_data_rdata              ), //output
    .pci_cl_data_rresp              ( pci_cl_data_rresp              ), //output
    .pci_cl_data_rlast              ( pci_cl_data_rlast              ), //output
    .pci_cl_data_rvalid             ( pci_cl_data_rvalid             ), //output
    .pci_cl_data_rready             ( pci_cl_data_rready             ), //input

    .ibuf_compute_ready             ( ibuf_compute_ready             ), //input
    .wbuf_compute_ready             ( wbuf_compute_ready             ), //input
    .obuf_compute_ready             ( obuf_compute_ready             ), //input
    .bias_compute_ready             ( bias_compute_ready             ), //input

    .cfg_loop_iter                  ( cfg_loop_iter                  ), //output
    .cfg_loop_iter_loop_id          ( cfg_loop_iter_loop_id          ), //output
    .cfg_loop_iter_v                ( cfg_loop_iter_v                ), //output
    .cfg_loop_stride                ( cfg_loop_stride                ), //output
    .cfg_loop_stride_v              ( cfg_loop_stride_v              ), //output
    .cfg_loop_stride_id             ( cfg_loop_stride_id             ), //output
    .cfg_loop_stride_type           ( cfg_loop_stride_type           ), //output
    .cfg_loop_stride_loop_id        ( cfg_loop_stride_loop_id        ), //output
    .cfg_mem_req_size               ( cfg_mem_req_size               ), //output
    .cfg_mem_req_v                  ( cfg_mem_req_v                  ), //output
    .cfg_mem_req_type               ( cfg_mem_req_type               ), //output
    .cfg_mem_req_id                 ( cfg_mem_req_id                 ), //output
    .cfg_mem_req_loop_id            ( cfg_mem_req_loop_id            ), //output
    .cfg_buf_req_size               ( cfg_buf_req_size               ), //output
    .cfg_buf_req_v                  ( cfg_buf_req_v                  ), //output
    .cfg_buf_req_type               ( cfg_buf_req_type               ), //output
    .cfg_buf_req_loop_id            ( cfg_buf_req_loop_id            ), //output

    .cfg_pu_inst                    ( cfg_pu_inst                    ), //output
    .cfg_pu_inst_v                  ( cfg_pu_inst_v                  ), //output
    .pu_block_start                 ( pu_block_start                 ), //output

    .snoop_cl_ddr0_araddr           ( snoop_cl_ddr0_araddr           ), //input
    .snoop_cl_ddr0_arvalid          ( cl_ddr0_arvalid                ), //input
    .snoop_cl_ddr0_arready          ( cl_ddr0_arready                ), //input
    .snoop_cl_ddr0_arlen            ( cl_ddr0_arlen                  ), //input
    .snoop_cl_ddr0_rvalid           ( cl_ddr0_rvalid                 ), //input
    .snoop_cl_ddr0_rready           ( cl_ddr0_rready                 ), //input

    .snoop_cl_ddr1_awaddr           ( snoop_cl_ddr1_awaddr           ), //input
    .snoop_cl_ddr1_awvalid          ( cl_ddr1_awvalid                ), //input
    .snoop_cl_ddr1_awready          ( cl_ddr1_awready                ), //input
    .snoop_cl_ddr1_awlen            ( cl_ddr1_awlen                  ), //input
    .snoop_cl_ddr1_araddr           ( snoop_cl_ddr1_araddr           ), //input
    .snoop_cl_ddr1_arvalid          ( cl_ddr1_arvalid                ), //input
    .snoop_cl_ddr1_arready          ( cl_ddr1_arready                ), //input
    .snoop_cl_ddr1_arlen            ( cl_ddr1_arlen                  ), //input
    .snoop_cl_ddr1_wvalid           ( cl_ddr1_wvalid                 ), //input
    .snoop_cl_ddr1_wready           ( cl_ddr1_wready                 ), //input
    .snoop_cl_ddr1_rvalid           ( cl_ddr1_rvalid                 ), //input
    .snoop_cl_ddr1_rready           ( cl_ddr1_rready                 ), //input

    .snoop_cl_ddr2_araddr           ( snoop_cl_ddr2_araddr           ), //input
    .snoop_cl_ddr2_arvalid          ( cl_ddr2_arvalid                ), //input
    .snoop_cl_ddr2_arready          ( cl_ddr2_arready                ), //input
    .snoop_cl_ddr2_arlen            ( cl_ddr2_arlen                  ), //input
    .snoop_cl_ddr2_rvalid           ( cl_ddr2_rvalid                 ), //input
    .snoop_cl_ddr2_rready           ( cl_ddr2_rready                 ), //input

    .snoop_cl_ddr3_araddr           ( snoop_cl_ddr3_araddr           ), //input
    .snoop_cl_ddr3_arvalid          ( cl_ddr3_arvalid                ), //input
    .snoop_cl_ddr3_arready          ( cl_ddr3_arready                ), //input
    .snoop_cl_ddr3_arlen            ( cl_ddr3_arlen                  ), //input
    .snoop_cl_ddr3_rvalid           ( cl_ddr3_rvalid                 ), //input
    .snoop_cl_ddr3_rready           ( cl_ddr3_rready                 ), //input

    .snoop_cl_ddr4_awaddr           ( snoop_cl_ddr4_awaddr           ), //input
    .snoop_cl_ddr4_awvalid          ( cl_ddr4_awvalid                ), //input
    .snoop_cl_ddr4_awready          ( cl_ddr4_awready                ), //input
    .snoop_cl_ddr4_awlen            ( cl_ddr4_awlen                  ), //input
    .snoop_cl_ddr4_araddr           ( snoop_cl_ddr4_araddr           ), //input
    .snoop_cl_ddr4_arvalid          ( cl_ddr4_arvalid                ), //input
    .snoop_cl_ddr4_arready          ( cl_ddr4_arready                ), //input
    .snoop_cl_ddr4_arlen            ( cl_ddr4_arlen                  ), //input
    .snoop_cl_ddr4_wvalid           ( cl_ddr4_wvalid                 ), //input
    .snoop_cl_ddr4_wready           ( cl_ddr4_wready                 ), //input
    .snoop_cl_ddr4_rvalid           ( cl_ddr4_rvalid                 ), //input
    .snoop_cl_ddr4_rready           ( cl_ddr4_rready                 ), //input

    .ld_obuf_req                    ( ld_obuf_req                    ), //input
    .ld_obuf_ready                  ( ld_obuf_ready                  )  //input

  );
//=============================================================

//=============================================================
// Compute controller
//    This module is in charge of the compute loops [0 - 15]
//=============================================================
    assign cfg_loop_stride_lo = cfg_loop_stride;
  base_addr_gen #(
    .BASE_ID                        ( 0                              ),
    .MEM_REQ_W                      ( MEM_REQ_W                      ),
    .IBUF_ADDR_WIDTH                ( IBUF_ADDR_WIDTH                ),
    .WBUF_ADDR_WIDTH                ( WBUF_ADDR_WIDTH                ),
    .OBUF_ADDR_WIDTH                ( OBUF_ADDR_WIDTH                ),
    .BBUF_ADDR_WIDTH                ( BBUF_ADDR_WIDTH                ),
    .LOOP_ITER_W                    ( LOOP_ITER_W                    ),
    .LOOP_ID_W                      ( LOOP_ID_W                      )
  ) compute_ctrl (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input

    .start                          ( compute_req                    ), //input
    .done                           ( compute_done                   ), //output

    //TODO
    .tag_req                        (                                ), //output
    .tag_ready                      ( 1'b1                           ), //input

    .cfg_loop_iter_v                ( cfg_loop_iter_v                ), //input
    .cfg_loop_iter                  ( cfg_loop_iter                  ), //input
    .cfg_loop_iter_loop_id          ( cfg_loop_iter_loop_id          ), //input

    .cfg_loop_stride_v              ( cfg_loop_stride_v              ), //input
    .cfg_loop_stride                ( cfg_loop_stride_lo             ), //input
    .cfg_loop_stride_loop_id        ( cfg_loop_stride_loop_id        ), //input
    .cfg_loop_stride_type           ( cfg_loop_stride_type           ), //input
    .cfg_loop_stride_id             ( cfg_loop_stride_id             ), //input

    .ibuf_base_addr                 ( tie_ibuf_buf_base_addr         ), //input
    .wbuf_base_addr                 ( tie_wbuf_buf_base_addr         ), //input
    .obuf_base_addr                 ( tie_obuf_buf_base_addr         ), //input
    .bias_base_addr                 ( tie_bias_buf_base_addr         ), //input

    .obuf_ld_addr                   ( obuf_read_addr                 ), //output
    .obuf_ld_addr_v                 ( obuf_read_req                  ), //output
    .obuf_st_addr                   ( obuf_write_addr                ), //output
    .obuf_st_addr_v                 ( obuf_write_req                 ), //output
    .ibuf_ld_addr                   ( ibuf_read_addr                 ), //output
    .ibuf_ld_addr_v                 ( ibuf_read_req                  ), //output
    .wbuf_ld_addr                   ( wbuf_read_addr                 ), //output
    .wbuf_ld_addr_v                 ( wbuf_read_req                  ), //output

    .bias_ld_addr                   ( bias_read_addr                 ), //output
    .bias_ld_addr_v                 ( bias_read_req                  ), //output

    .bias_prev_sw                   ( rd_bias_prev_sw                ), //output
    .ddr_pe_sw                      (                                )  //output
    );
//=============================================================

//=============================================================
// 4x Memory wrappers - IBUF, WBUF, OBUF, Bias
//=============================================================
  ibuf_mem_wrapper #(
    // Internal Parameters
    .AXI_DATA_WIDTH                 ( IBUF_AXI_DATA_WIDTH            ),
    .AXI_BURST_WIDTH                ( AXI_BURST_WIDTH                ),
    .MEM_ID                         ( 0                              ),
    .NUM_TAGS                       ( NUM_TAGS                       ),
    .ARRAY_N                        ( ARRAY_N                        ),
    .DATA_WIDTH                     ( DATA_WIDTH                     ),
    .MEM_REQ_W                      ( MEM_REQ_W                      ),
    .ADDR_WIDTH                     ( ADDR_WIDTH                     ),
    .BUF_ADDR_W                     ( IBUF_ADDR_WIDTH                ),
    .LOOP_ITER_W                    ( LOOP_ITER_W                    ),
    .LOOP_ID_W                      ( LOOP_ID_W                      )
  ) ibuf_mem (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input

    .compute_done                   ( compute_done                   ), //input
    .compute_ready                  ( ibuf_compute_ready             ), //input
    .compute_bias_prev_sw           (                                ), //output

    .block_done                     ( tag_flush                      ), //input
    .tag_req                        ( sync_tag_req                   ), //input
    .tag_reuse                      ( ibuf_tag_reuse                 ), //input
    .tag_bias_prev_sw               ( tag_bias_prev_sw               ), //input
    .tag_ddr_pe_sw                  ( tag_ddr_pe_sw                  ), //input
    .tag_ready                      ( ibuf_tag_ready                 ), //output
    .tag_done                       ( ibuf_tag_done                  ), //output

    .tag_base_ld_addr               ( ibuf_ld_addr                   ), //input

    .cfg_loop_iter_v                ( cfg_loop_iter_v                ), //input
    .cfg_loop_iter                  ( cfg_loop_iter                  ), //input
    .cfg_loop_iter_loop_id          ( cfg_loop_iter_loop_id          ), //input

    .cfg_loop_stride_v              ( cfg_loop_stride_v              ), //input
    .cfg_loop_stride                ( cfg_loop_stride                ), //input
    .cfg_loop_stride_loop_id        ( cfg_loop_stride_loop_id        ), //input
    .cfg_loop_stride_type           ( cfg_loop_stride_type           ), //input
    .cfg_loop_stride_id             ( cfg_loop_stride_id             ), //input

    .cfg_mem_req_v                  ( cfg_mem_req_v                  ),
    .cfg_mem_req_size               ( cfg_mem_req_size               ),
    .cfg_mem_req_type               ( cfg_mem_req_type               ), // 0: RD, 1:WR
    .cfg_mem_req_id                 ( cfg_mem_req_id                 ), // specify which scratchpad
    .cfg_mem_req_loop_id            ( cfg_mem_req_loop_id            ), // specify which loop

    .buf_read_data                  ( ibuf_read_data                 ),
    .buf_read_req                   ( ibuf_read_req                  ),
    .buf_read_addr                  ( ibuf_read_addr                 ),

    .mws_awaddr                     ( cl_ddr0_awaddr                 ),
    .mws_awlen                      ( cl_ddr0_awlen                  ),
    .mws_awsize                     ( cl_ddr0_awsize                 ),
    .mws_awburst                    ( cl_ddr0_awburst                ),
    .mws_awvalid                    ( cl_ddr0_awvalid                ),
    .mws_awready                    ( cl_ddr0_awready                ),
    .mws_wdata                      ( cl_ddr0_wdata                  ),
    .mws_wstrb                      ( cl_ddr0_wstrb                  ),
    .mws_wlast                      ( cl_ddr0_wlast                  ),
    .mws_wvalid                     ( cl_ddr0_wvalid                 ),
    .mws_wready                     ( cl_ddr0_wready                 ),
    .mws_bresp                      ( cl_ddr0_bresp                  ),
    .mws_bvalid                     ( cl_ddr0_bvalid                 ),
    .mws_bready                     ( cl_ddr0_bready                 ),
    .mws_araddr                     ( cl_ddr0_araddr                 ),
    .mws_arid                       ( cl_ddr0_arid                   ),
    .mws_arlen                      ( cl_ddr0_arlen                  ),
    .mws_arsize                     ( cl_ddr0_arsize                 ),
    .mws_arburst                    ( cl_ddr0_arburst                ),
    .mws_arvalid                    ( cl_ddr0_arvalid                ),
    .mws_arready                    ( cl_ddr0_arready                ),
    .mws_rdata                      ( cl_ddr0_rdata                  ),
    .mws_rid                        ( cl_ddr0_rid                    ),
    .mws_rresp                      ( cl_ddr0_rresp                  ),
    .mws_rlast                      ( cl_ddr0_rlast                  ),
    .mws_rvalid                     ( cl_ddr0_rvalid                 ),
    .mws_rready                     ( cl_ddr0_rready                 )
    );

  wbuf_mem_wrapper #(
    // Internal Parameters
    .AXI_DATA_WIDTH                 ( WBUF_AXI_DATA_WIDTH            ),
    .AXI_BURST_WIDTH                ( AXI_BURST_WIDTH                ),
    .MEM_ID                         ( 2                              ),
    .NUM_TAGS                       ( NUM_TAGS                       ),
    .ARRAY_N                        ( ARRAY_N                        ),
    .DATA_WIDTH                     ( DATA_WIDTH                     ),
    .MEM_REQ_W                      ( MEM_REQ_W                      ),
    .ADDR_WIDTH                     ( ADDR_WIDTH                     ),
    .BUF_ADDR_W                     ( WBUF_ADDR_WIDTH                ),
    .LOOP_ITER_W                    ( LOOP_ITER_W                    ),
    .LOOP_ID_W                      ( LOOP_ID_W                      )
  ) wbuf_mem (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input

    .compute_done                   ( compute_done                   ), //input
    .compute_ready                  ( wbuf_compute_ready             ), //input
    .compute_bias_prev_sw           (                                ), //output
    .block_done                     ( tag_flush                      ), //input
    .tag_req                        ( sync_tag_req                   ), //input
    .tag_reuse                      ( wbuf_tag_reuse                 ), //input
    .tag_bias_prev_sw               ( tag_bias_prev_sw               ), //input
    .tag_ddr_pe_sw                  ( tag_ddr_pe_sw                  ), //input
    .tag_ready                      ( wbuf_tag_ready                 ), //output
    .tag_done                       ( wbuf_tag_done                  ), //output

    .tag_base_ld_addr               ( wbuf_ld_addr                   ), //input

    .cfg_loop_iter_v                ( cfg_loop_iter_v                ), //input
    .cfg_loop_iter                  ( cfg_loop_iter                  ), //input
    .cfg_loop_iter_loop_id          ( cfg_loop_iter_loop_id          ), //input

    .cfg_loop_stride_v              ( cfg_loop_stride_v              ), //input
    .cfg_loop_stride                ( cfg_loop_stride                ), //input
    .cfg_loop_stride_loop_id        ( cfg_loop_stride_loop_id        ), //input
    .cfg_loop_stride_type           ( cfg_loop_stride_type           ), //input
    .cfg_loop_stride_id             ( cfg_loop_stride_id             ), //input

    .cfg_mem_req_v                  ( cfg_mem_req_v                  ),
    .cfg_mem_req_size               ( cfg_mem_req_size               ),
    .cfg_mem_req_type               ( cfg_mem_req_type               ), // 0: RD, 1:WR
    .cfg_mem_req_id                 ( cfg_mem_req_id                 ), // specify which scratchpad
    .cfg_mem_req_loop_id            ( cfg_mem_req_loop_id            ), // specify which loop

    .buf_read_data                  ( wbuf_read_data                 ),
    .buf_read_req                   ( wbuf_read_req                  ),
    .buf_read_addr                  ( wbuf_read_addr                 ),

    .mws_awaddr                     ( cl_ddr2_awaddr                 ),
    .mws_awlen                      ( cl_ddr2_awlen                  ),
    .mws_awsize                     ( cl_ddr2_awsize                 ),
    .mws_awburst                    ( cl_ddr2_awburst                ),
    .mws_awvalid                    ( cl_ddr2_awvalid                ),
    .mws_awready                    ( cl_ddr2_awready                ),
    .mws_wdata                      ( cl_ddr2_wdata                  ),
    .mws_wstrb                      ( cl_ddr2_wstrb                  ),
    .mws_wlast                      ( cl_ddr2_wlast                  ),
    .mws_wvalid                     ( cl_ddr2_wvalid                 ),
    .mws_wready                     ( cl_ddr2_wready                 ),
    .mws_bresp                      ( cl_ddr2_bresp                  ),
    .mws_bvalid                     ( cl_ddr2_bvalid                 ),
    .mws_bready                     ( cl_ddr2_bready                 ),
    .mws_araddr                     ( cl_ddr2_araddr                 ),
    .mws_arid                       ( cl_ddr2_arid                   ),
    .mws_arlen                      ( cl_ddr2_arlen                  ),
    .mws_arsize                     ( cl_ddr2_arsize                 ),
    .mws_arburst                    ( cl_ddr2_arburst                ),
    .mws_arvalid                    ( cl_ddr2_arvalid                ),
    .mws_arready                    ( cl_ddr2_arready                ),
    .mws_rdata                      ( cl_ddr2_rdata                  ),
    .mws_rid                        ( cl_ddr2_rid                    ),
    .mws_rresp                      ( cl_ddr2_rresp                  ),
    .mws_rlast                      ( cl_ddr2_rlast                  ),
    .mws_rvalid                     ( cl_ddr2_rvalid                 ),
    .mws_rready                     ( cl_ddr2_rready                 )
    );

  obuf_mem_wrapper #(
    // Internal Parameters
    .AXI_DATA_WIDTH                 ( OBUF_AXI_DATA_WIDTH            ),
    .AXI_BURST_WIDTH                ( AXI_BURST_WIDTH                ),
    .MEM_ID                         ( 1                              ),
    .NUM_TAGS                       ( NUM_TAGS                       ),
    .ARRAY_N                        ( ARRAY_N                        ),
    .ARRAY_M                        ( ARRAY_M                        ),
    .DATA_WIDTH                     ( 64                             ),
    .MEM_REQ_W                      ( MEM_REQ_W                      ),
    .ADDR_WIDTH                     ( ADDR_WIDTH                     ),
    .BUF_ADDR_W                     ( OBUF_ADDR_WIDTH                ),
    .LOOP_ITER_W                    ( LOOP_ITER_W                    ),
    .LOOP_ID_W                      ( LOOP_ID_W                      )
  ) obuf_mem (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input

    .compute_done                   ( compute_done                   ), //input
    .compute_ready                  ( obuf_compute_ready             ), //output
    .compute_bias_prev_sw           ( obuf_bias_prev_sw              ), //output
    .block_done                     ( tag_flush                      ), //input
    .tag_req                        ( sync_tag_req                   ), //input
    .tag_reuse                      ( obuf_tag_reuse                 ), //input
    .tag_bias_prev_sw               ( tag_bias_prev_sw               ), //input
    .tag_ddr_pe_sw                  ( tag_ddr_pe_sw                  ), //input
    .tag_ready                      ( obuf_tag_ready                 ), //output
    .tag_done                       ( obuf_tag_done                  ), //output

    .tag_base_ld_addr               ( obuf_ld_addr                   ), //input
    .tag_base_st_addr               ( obuf_st_addr                   ), //input

    .cfg_loop_iter_v                ( cfg_loop_iter_v                ), //input
    .cfg_loop_iter                  ( cfg_loop_iter                  ), //input
    .cfg_loop_iter_loop_id          ( cfg_loop_iter_loop_id          ), //input

    .cfg_loop_stride_v              ( cfg_loop_stride_v              ), //input
    .cfg_loop_stride                ( cfg_loop_stride                ), //input
    .cfg_loop_stride_loop_id        ( cfg_loop_stride_loop_id        ), //input
    .cfg_loop_stride_type           ( cfg_loop_stride_type           ), //input
    .cfg_loop_stride_id             ( cfg_loop_stride_id             ), //input

    .cfg_mem_req_v                  ( cfg_mem_req_v                  ),
    .cfg_mem_req_size               ( cfg_mem_req_size               ),
    .cfg_mem_req_type               ( cfg_mem_req_type               ), // 0: RD, 1:WR
    .cfg_mem_req_id                 ( cfg_mem_req_id                 ), // specify which scratchpad
    .cfg_mem_req_loop_id            ( cfg_mem_req_loop_id            ), // specify which loop

    .buf_write_data                 ( obuf_write_data                ),
    .buf_write_req                  ( sys_obuf_write_req             ),
    .buf_write_addr                 ( sys_obuf_write_addr            ),
    .buf_read_data                  ( obuf_read_data                 ),
    .buf_read_req                   ( sys_obuf_read_req              ),
    .buf_read_addr                  ( sys_obuf_read_addr             ),

    .pu_buf_read_ready              ( ld_obuf_ready                  ),
    .pu_buf_read_req                ( ld_obuf_req                    ),
    .pu_buf_read_addr               ( ld_obuf_addr                   ),

    .pu_compute_start               ( pu_compute_start               ), //output
    .pu_compute_done                ( pu_compute_done                ), //input
    .pu_compute_ready               ( pu_compute_ready               ), //input

    .obuf_ld_stream_write_req       ( obuf_ld_stream_write_req       ),
    .obuf_ld_stream_write_data      ( obuf_ld_stream_write_data      ),

    .stmem_state                    ( stmem_state                    ), //output
    .stmem_tag                      ( stmem_tag                      ), //output
    .stmem_ddr_pe_sw                ( stmem_ddr_pe_sw                ), //output

    .mws_awaddr                     ( cl_ddr1_awaddr                 ),
    .mws_awlen                      ( cl_ddr1_awlen                  ),
    .mws_awsize                     ( cl_ddr1_awsize                 ),
    .mws_awburst                    ( cl_ddr1_awburst                ),
    .mws_awvalid                    ( cl_ddr1_awvalid                ),
    .mws_awready                    ( cl_ddr1_awready                ),
    .mws_wdata                      ( cl_ddr1_wdata                  ),
    .mws_wstrb                      ( cl_ddr1_wstrb                  ),
    .mws_wlast                      ( cl_ddr1_wlast                  ),
    .mws_wvalid                     ( cl_ddr1_wvalid                 ),
    .mws_wready                     ( cl_ddr1_wready                 ),
    .mws_bresp                      ( cl_ddr1_bresp                  ),
    .mws_bvalid                     ( cl_ddr1_bvalid                 ),
    .mws_bready                     ( cl_ddr1_bready                 ),
    .mws_araddr                     ( cl_ddr1_araddr                 ),
    .mws_arid                       ( cl_ddr1_arid                   ),
    .mws_arlen                      ( cl_ddr1_arlen                  ),
    .mws_arsize                     ( cl_ddr1_arsize                 ),
    .mws_arburst                    ( cl_ddr1_arburst                ),
    .mws_arvalid                    ( cl_ddr1_arvalid                ),
    .mws_arready                    ( cl_ddr1_arready                ),
    .mws_rdata                      ( cl_ddr1_rdata                  ),
    .mws_rid                        ( cl_ddr1_rid                    ),
    .mws_rresp                      ( cl_ddr1_rresp                  ),
    .mws_rlast                      ( cl_ddr1_rlast                  ),
    .mws_rvalid                     ( cl_ddr1_rvalid                 ),
    .mws_rready                     ( cl_ddr1_rready                 )
    );

  bbuf_mem_wrapper #(
    // Internal Parameters
    .AXI_DATA_WIDTH                 ( BBUF_AXI_DATA_WIDTH            ),
    .AXI_BURST_WIDTH                ( AXI_BURST_WIDTH                ),
    .MEM_ID                         ( 3                              ),
    .NUM_TAGS                       ( NUM_TAGS                       ),
    .ARRAY_N                        ( ARRAY_N                        ),
    .ARRAY_M                        ( ARRAY_M                        ),
    .DATA_WIDTH                     ( 32                             ),
    .MEM_REQ_W                      ( MEM_REQ_W                      ),
    .ADDR_WIDTH                     ( ADDR_WIDTH                     ),
    .BUF_ADDR_W                     ( BBUF_ADDR_WIDTH                ),
    .LOOP_ITER_W                    ( LOOP_ITER_W                    ),
    .LOOP_ID_W                      ( LOOP_ID_W                      )
  ) bbuf_mem (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input

    .compute_done                   ( compute_done                   ), //input
    .compute_ready                  ( bias_compute_ready             ), //input
    .compute_bias_prev_sw           (                                ), //output
    .block_done                     ( tag_flush                      ), //input
    .tag_req                        ( sync_tag_req                   ), //input
    .tag_reuse                      ( bias_tag_reuse                 ), //input
    .tag_bias_prev_sw               ( tag_bias_prev_sw               ), //input
    .tag_ddr_pe_sw                  ( tag_ddr_pe_sw                  ), //input
    .tag_ready                      ( bias_tag_ready                 ), //output
    .tag_done                       ( bias_tag_done                  ), //output

    .tag_base_ld_addr               ( bias_ld_addr                   ), //input

    .cfg_loop_iter_v                ( cfg_loop_iter_v                ), //input
    .cfg_loop_iter                  ( cfg_loop_iter                  ), //input
    .cfg_loop_iter_loop_id          ( cfg_loop_iter_loop_id          ), //input

    .cfg_loop_stride_v              ( cfg_loop_stride_v              ), //input
    .cfg_loop_stride                ( cfg_loop_stride                ), //input
    .cfg_loop_stride_loop_id        ( cfg_loop_stride_loop_id        ), //input
    .cfg_loop_stride_type           ( cfg_loop_stride_type           ), //input
    .cfg_loop_stride_id             ( cfg_loop_stride_id             ), //input

    .cfg_mem_req_v                  ( cfg_mem_req_v                  ),
    .cfg_mem_req_size               ( cfg_mem_req_size               ),
    .cfg_mem_req_type               ( cfg_mem_req_type               ), // 0: RD, 1:WR
    .cfg_mem_req_id                 ( cfg_mem_req_id                 ), // specify which scratchpad
    .cfg_mem_req_loop_id            ( cfg_mem_req_loop_id            ), // specify which loop

    .buf_read_data                  ( bbuf_read_data                 ),
    .buf_read_req                   ( sys_bias_read_req              ),
    .buf_read_addr                  ( sys_bias_read_addr             ),

    .mws_awaddr                     ( cl_ddr3_awaddr                 ),
    .mws_awlen                      ( cl_ddr3_awlen                  ),
    .mws_awsize                     ( cl_ddr3_awsize                 ),
    .mws_awburst                    ( cl_ddr3_awburst                ),
    .mws_awvalid                    ( cl_ddr3_awvalid                ),
    .mws_awready                    ( cl_ddr3_awready                ),
    .mws_wdata                      ( cl_ddr3_wdata                  ),
    .mws_wstrb                      ( cl_ddr3_wstrb                  ),
    .mws_wlast                      ( cl_ddr3_wlast                  ),
    .mws_wvalid                     ( cl_ddr3_wvalid                 ),
    .mws_wready                     ( cl_ddr3_wready                 ),
    .mws_bresp                      ( cl_ddr3_bresp                  ),
    .mws_bvalid                     ( cl_ddr3_bvalid                 ),
    .mws_bready                     ( cl_ddr3_bready                 ),
    .mws_araddr                     ( cl_ddr3_araddr                 ),
    .mws_arid                       ( cl_ddr3_arid                   ),
    .mws_arlen                      ( cl_ddr3_arlen                  ),
    .mws_arsize                     ( cl_ddr3_arsize                 ),
    .mws_arburst                    ( cl_ddr3_arburst                ),
    .mws_arvalid                    ( cl_ddr3_arvalid                ),
    .mws_arready                    ( cl_ddr3_arready                ),
    .mws_rdata                      ( cl_ddr3_rdata                  ),
    .mws_rid                        ( cl_ddr3_rid                    ),
    .mws_rresp                      ( cl_ddr3_rresp                  ),
    .mws_rlast                      ( cl_ddr3_rlast                  ),
    .mws_rvalid                     ( cl_ddr3_rvalid                 ),
    .mws_rready                     ( cl_ddr3_rready                 )
    );
//=============================================================

//=============================================================
// Systolic Array
//=============================================================
  // Only select bias (0) if rd_bias_prev_sw == 0 and obuf_bias_prev_sw == 0;
    assign sys_array_c_sel = rd_bias_prev_sw || obuf_bias_prev_sw;
  systolic_array #(
    .OBUF_ADDR_WIDTH                ( OBUF_ADDR_WIDTH                ),
    .BBUF_ADDR_WIDTH                ( BBUF_ADDR_WIDTH                ),
    .ACT_WIDTH                      ( DATA_WIDTH                     ),
    .WGT_WIDTH                      ( DATA_WIDTH                     ),
    .BIAS_WIDTH                     ( BIAS_WIDTH                     ),
    .ACC_WIDTH                      ( ACC_WIDTH                      ),
    .ARRAY_N                        ( ARRAY_N                        ),
    .ARRAY_M                        ( ARRAY_M                        )
  ) sys_array (
    .clk                            ( clk                            ),
    .reset                          ( reset                          ),
    .acc_clear                      ( acc_clear                      ),

    .ibuf_read_data                 ( ibuf_read_data                 ),

    .wbuf_read_data                 ( wbuf_read_data                 ),

    .bbuf_read_data                 ( bbuf_read_data                 ),
    .bias_read_req                  ( bias_read_req                  ),
    .bias_read_addr                 ( bias_read_addr                 ),
    .sys_bias_read_req              ( sys_bias_read_req              ),
    .sys_bias_read_addr             ( sys_bias_read_addr             ),
    .bias_prev_sw                   ( sys_array_c_sel                ),

    .obuf_read_data                 ( obuf_read_data                 ),
    .obuf_read_addr                 ( obuf_read_addr                 ),
    .sys_obuf_read_req              ( sys_obuf_read_req              ),
    .sys_obuf_read_addr             ( sys_obuf_read_addr             ),
    .obuf_write_req                 ( obuf_write_req                 ),
    .obuf_write_addr                ( obuf_write_addr                ),
    .obuf_write_data                ( sys_obuf_write_data            ),
    .sys_obuf_write_req             ( sys_obuf_write_req             ),
    .sys_obuf_write_addr            ( sys_obuf_write_addr            )
  );


    wire [ 64                   -1 : 0 ]        obuf_out0;
    wire [ 64                   -1 : 0 ]        obuf_out1;
    wire [ 64                   -1 : 0 ]        obuf_out2;
    wire [ 64                   -1 : 0 ]        obuf_out3;

    wire [ 64                   -1 : 0 ]        obuf_out4;
    wire [ 64                   -1 : 0 ]        obuf_out5;
    wire [ 64                   -1 : 0 ]        obuf_out6;
    wire [ 64                   -1 : 0 ]        obuf_out7;

    wire [ 64                   -1 : 0 ]        obuf_in0;
    wire [ 64                   -1 : 0 ]        obuf_in1;
    wire [ 64                   -1 : 0 ]        obuf_in2;
    wire [ 64                   -1 : 0 ]        obuf_in3;

    wire [ 32                   -1 : 0 ]        bias_in0;
    wire [ 32                   -1 : 0 ]        bias_in1;
    wire [ 32                   -1 : 0 ]        bias_in2;
    wire [ 32                   -1 : 0 ]        bias_in3;

    wire [ 64                   -1 : 0 ]        obuf_mem_out0;
    wire [ 64                   -1 : 0 ]        obuf_mem_out1;

    wire [ 16                   -1 : 0 ]        ibuf_in0;
    wire [ 16                   -1 : 0 ]        ibuf_in1;
    wire [ 16                   -1 : 0 ]        ibuf_in2;
    wire [ 16                   -1 : 0 ]        ibuf_in3;

    wire [ 16                   -1 : 0 ]        ibuf_in4;
    wire [ 16                   -1 : 0 ]        ibuf_in5;
    wire [ 16                   -1 : 0 ]        ibuf_in6;
    wire [ 16                   -1 : 0 ]        ibuf_in7;

    wire [ 16                   -1 : 0 ]        wbuf_in0;
    wire [ 16                   -1 : 0 ]        wbuf_in1;
    wire [ 16                   -1 : 0 ]        wbuf_in2;
    wire [ 16                   -1 : 0 ]        wbuf_in3;

    wire [ 16                   -1 : 0 ]        wbuf_in4;
    wire [ 16                   -1 : 0 ]        wbuf_in5;
    wire [ 16                   -1 : 0 ]        wbuf_in6;
    wire [ 16                   -1 : 0 ]        wbuf_in7;

    wire [ 16                   -1 : 0 ]        wbuf_in8;
    wire [ 16                   -1 : 0 ]        wbuf_in9;
    wire [ 16                   -1 : 0 ]        wbuf_in10;
    wire [ 16                   -1 : 0 ]        wbuf_in11;

    wire [ 16                   -1 : 0 ]        wbuf_in12;
    wire [ 16                   -1 : 0 ]        wbuf_in13;
    wire [ 16                   -1 : 0 ]        wbuf_in14;
    wire [ 16                   -1 : 0 ]        wbuf_in15;

    assign {obuf_out7,obuf_out6,obuf_out5,obuf_out4,
      obuf_out3, obuf_out2, obuf_out1, obuf_out0} = sys_obuf_write_data;
    assign {obuf_in3, obuf_in2, obuf_in1, obuf_in0} = obuf_read_data;
    assign {bias_in3, bias_in2, bias_in1, bias_in0} = bbuf_read_data;
    assign {obuf_mem_out1, obuf_mem_out0} = cl_ddr1_wdata;

    assign ibuf_in0 = ibuf_read_data[15:0];
    assign ibuf_in1 = ibuf_read_data[31:16];
    assign ibuf_in2 = ibuf_read_data[47:32];
    assign ibuf_in3 = ibuf_read_data[63:48];

    assign ibuf_in4 = ibuf_read_data[79 :64];
    assign ibuf_in5 = ibuf_read_data[95 :80];
    assign ibuf_in6 = ibuf_read_data[111:96];
    assign ibuf_in7 = ibuf_read_data[127:112];

    assign wbuf_in0 = wbuf_read_data[15:0];
    assign wbuf_in1 = wbuf_read_data[31:16];
    assign wbuf_in2 = wbuf_read_data[47:32];
    assign wbuf_in3 = wbuf_read_data[63:48];

    assign wbuf_in4 = wbuf_read_data[79:64];
    assign wbuf_in5 = wbuf_read_data[95:80];
    assign wbuf_in6 = wbuf_read_data[111:96];
    assign wbuf_in7 = wbuf_read_data[127:112];

    assign wbuf_in8 = wbuf_read_data[143:128];
    assign wbuf_in9 = wbuf_read_data[159:144];
    assign wbuf_in10 = wbuf_read_data[175:160];
    assign wbuf_in11 = wbuf_read_data[191:176];

    assign wbuf_in12 = wbuf_read_data[207:192];
    assign wbuf_in13 = wbuf_read_data[223:208];
    assign wbuf_in14 = wbuf_read_data[239:224];
    assign wbuf_in15 = wbuf_read_data[255:240];

    assign obuf_write_data = sys_obuf_write_data;
//=============================================================

//=============================================================
// PU
//=============================================================
  gen_pu #(
    .INST_WIDTH                     ( INST_DATA_WIDTH                ),
    .DATA_WIDTH                     ( DATA_WIDTH                     ),
    .ACC_DATA_WIDTH                 ( 64                             ),
    .SIMD_LANES                     ( ARRAY_M                        ),
    .OBUF_AXI_DATA_WIDTH            ( OBUF_AXI_DATA_WIDTH            ),
    .AXI_DATA_WIDTH                 ( PU_AXI_DATA_WIDTH              ),
    .AXI_ADDR_WIDTH                 ( AXI_ADDR_WIDTH                 ),
    .OBUF_ADDR_WIDTH                ( PU_OBUF_ADDR_WIDTH             ),
    .AXI_BURST_WIDTH                ( AXI_BURST_WIDTH                )
  ) u_pu
  (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .done                           ( pu_done                        ), //output
    //DEBUG
    .obuf_ld_stream_read_count      ( obuf_ld_stream_read_count      ), //output
    .obuf_ld_stream_write_count     ( obuf_ld_stream_write_count     ), //output
    .ddr_st_stream_read_count       ( ddr_st_stream_read_count       ), //output
    .ddr_st_stream_write_count      ( ddr_st_stream_write_count      ), //output
    .ld0_stream_counts              ( ld0_stream_counts              ), //output
    .ld1_stream_counts              ( ld1_stream_counts              ), //output
    .axi_wr_fifo_counts             ( axi_wr_fifo_counts             ), //output
    //DEBUG
    .pu_ctrl_state                  ( pu_ctrl_state                  ), //output
    .obuf_ld_stream_write_req       ( obuf_ld_stream_write_req       ), //input
    .obuf_ld_stream_write_data      ( obuf_ld_stream_write_data      ), //input
    .inst_wr_req                    ( cfg_pu_inst_v                  ), //input
    .inst_wr_data                   ( cfg_pu_inst                    ), //input
    .pu_block_start                 ( pu_block_start                 ), //input
    .pu_compute_start               ( pu_compute_start               ), //input
    .pu_compute_ready               ( pu_compute_ready               ), //output
    .pu_compute_done                ( pu_compute_done                ), //output
    .pu_write_done                  ( pu_write_done                  ), //output
    .inst_wr_ready                  ( pu_inst_wr_ready               ), //output
    .ld_obuf_req                    ( ld_obuf_req                    ), //output
    .ld_obuf_addr                   ( ld_obuf_addr                   ), //output
    .ld_obuf_ready                  ( ld_obuf_ready                  ), //input
    .pu_ddr_awaddr                  ( cl_ddr4_awaddr                 ), //output
    .pu_ddr_awlen                   ( cl_ddr4_awlen                  ), //output
    .pu_ddr_awsize                  ( cl_ddr4_awsize                 ), //output
    .pu_ddr_awburst                 ( cl_ddr4_awburst                ), //output
    .pu_ddr_awvalid                 ( cl_ddr4_awvalid                ), //output
    .pu_ddr_awready                 ( cl_ddr4_awready                ), //input
    .pu_ddr_wdata                   ( cl_ddr4_wdata                  ), //output
    .pu_ddr_wstrb                   ( cl_ddr4_wstrb                  ), //output
    .pu_ddr_wlast                   ( cl_ddr4_wlast                  ), //output
    .pu_ddr_wvalid                  ( cl_ddr4_wvalid                 ), //output
    .pu_ddr_wready                  ( cl_ddr4_wready                 ), //input
    .pu_ddr_bresp                   ( cl_ddr4_bresp                  ), //input
    .pu_ddr_bvalid                  ( cl_ddr4_bvalid                 ), //input
    .pu_ddr_bready                  ( cl_ddr4_bready                 ), //output
    .pu_ddr_araddr                  ( cl_ddr4_araddr                 ), //output
    .pu_ddr_arid                    ( cl_ddr4_arid                   ), //output
    .pu_ddr_arlen                   ( cl_ddr4_arlen                  ), //output
    .pu_ddr_arsize                  ( cl_ddr4_arsize                 ), //output
    .pu_ddr_arburst                 ( cl_ddr4_arburst                ), //output
    .pu_ddr_arvalid                 ( cl_ddr4_arvalid                ), //output
    .pu_ddr_arready                 ( cl_ddr4_arready                ), //input
    .pu_ddr_rdata                   ( cl_ddr4_rdata                  ), //input
    .pu_ddr_rid                     ( cl_ddr4_rid                    ), //input
    .pu_ddr_rresp                   ( cl_ddr4_rresp                  ), //input
    .pu_ddr_rlast                   ( cl_ddr4_rlast                  ), //input
    .pu_ddr_rvalid                  ( cl_ddr4_rvalid                 ), //input
    .pu_ddr_rready                  ( cl_ddr4_rready                 ) //output
  );
//=============================================================

//=============================================================
// VCD
//=============================================================
  `ifdef COCOTB_TOPLEVEL_dnnweaver2_controller
  initial begin
    $dumpfile("dnnweaver2_controller.vcd");
    $dumpvars(0, dnnweaver2_controller);
  end
  `endif
//=============================================================

endmodule
