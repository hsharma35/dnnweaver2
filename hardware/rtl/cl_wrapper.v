//
// DnnWeaver v2 controller - Custom Logic (CL) Wrapper
//
// Hardik Sharma
// (hsharma@gatech.edu)

`timescale 1ns/1ps
module cl_wrapper #(
    parameter integer  INST_W                       = 32,
    parameter integer  INST_ADDR_W                  = 5,
    parameter integer  IFIFO_ADDR_W                 = 10,
    parameter integer  BUF_TYPE_W                   = 2,
    parameter integer  OP_CODE_W                    = 5,
    parameter integer  OP_SPEC_W                    = 6,
    parameter integer  LOOP_ID_W                    = 5,

  // Systolic Array
    parameter integer  ARRAY_N                      = 64,
    parameter integer  ARRAY_M                      = 64,

  // Precision
    parameter integer  DATA_WIDTH                   = 16,
    parameter integer  BIAS_WIDTH                   = 32,
    parameter integer  ACC_WIDTH                    = 64,

  // Buffers
    parameter integer  NUM_TAGS                     = 2,
    parameter integer  IBUF_CAPACITY_BITS           = ARRAY_N * DATA_WIDTH * 4096 / NUM_TAGS,
    parameter integer  WBUF_CAPACITY_BITS           = ARRAY_N * ARRAY_M * DATA_WIDTH * 512 / NUM_TAGS,
    parameter integer  OBUF_CAPACITY_BITS           = ARRAY_M * ACC_WIDTH * 4096 / NUM_TAGS,
    parameter integer  BBUF_CAPACITY_BITS           = ARRAY_M * BIAS_WIDTH * 4096 / NUM_TAGS,

  // Buffer Addr Width
    parameter integer  IBUF_ADDR_WIDTH              = $clog2(IBUF_CAPACITY_BITS / ARRAY_N / DATA_WIDTH),
    parameter integer  WBUF_ADDR_WIDTH              = $clog2(WBUF_CAPACITY_BITS / ARRAY_N / ARRAY_M / DATA_WIDTH),
    parameter integer  OBUF_ADDR_WIDTH              = $clog2(OBUF_CAPACITY_BITS / ARRAY_M / ACC_WIDTH),
    parameter integer  BBUF_ADDR_WIDTH              = $clog2(BBUF_CAPACITY_BITS / ARRAY_M / BIAS_WIDTH),

  // AXI DATA
    parameter integer  AXI_ADDR_WIDTH               = 42,
    parameter integer  AXI_BURST_WIDTH              = 8,
    parameter integer  IBUF_AXI_DATA_WIDTH          = 256,
    parameter integer  IBUF_WSTRB_W                 = IBUF_AXI_DATA_WIDTH/8,
    parameter integer  OBUF_AXI_DATA_WIDTH          = 256,
    parameter integer  OBUF_WSTRB_W                 = OBUF_AXI_DATA_WIDTH/8,
    parameter integer  PU_AXI_DATA_WIDTH            = 256,
    parameter integer  PU_WSTRB_W                   = PU_AXI_DATA_WIDTH/8,
    parameter integer  WBUF_AXI_DATA_WIDTH          = 256,
    parameter integer  WBUF_WSTRB_W                 = WBUF_AXI_DATA_WIDTH/8,
    parameter integer  BBUF_AXI_DATA_WIDTH          = 256,
    parameter integer  BBUF_WSTRB_W                 = BBUF_AXI_DATA_WIDTH/8,
    parameter integer  AXI_ID_WIDTH                 = 1,
  // AXI Instructions
    parameter integer  INST_ADDR_WIDTH              = 32,
    parameter integer  INST_DATA_WIDTH              = 32,
    parameter integer  INST_WSTRB_WIDTH             = INST_DATA_WIDTH/8,
    parameter integer  INST_BURST_WIDTH             = 8,
  // AXI-Lite
    parameter integer  CTRL_ADDR_WIDTH              = 32,
    parameter integer  CTRL_DATA_WIDTH              = 32,
    parameter integer  CTRL_WSTRB_WIDTH             = CTRL_DATA_WIDTH/8
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
    //Write response
    output wire                                         pci_cl_ctrl_bvalid,
    output wire  [ 2                    -1 : 0 ]        pci_cl_ctrl_bresp,
    input  wire                                         pci_cl_ctrl_bready,
    //Read address
    input  wire                                         pci_cl_ctrl_arvalid,
    input  wire  [ CTRL_ADDR_WIDTH      -1 : 0 ]        pci_cl_ctrl_araddr,
    output wire                                         pci_cl_ctrl_arready,
    //Read data/response
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
// Wires/Regs
//=============================================================
//=============================================================

//=============================================================
// Comb Logic
//=============================================================
//=============================================================

//=============================================================
// DnnWeaver2 Wrapper
//=============================================================
  dnnweaver2_controller #(
    .ARRAY_N                        ( ARRAY_N                        ),
    .ARRAY_M                        ( ARRAY_M                        ),
    .DATA_WIDTH                     ( DATA_WIDTH                     ),
    .BIAS_WIDTH                     ( BIAS_WIDTH                     ),
    .ACC_WIDTH                      ( ACC_WIDTH                      ),

    .IBUF_CAPACITY_BITS             ( IBUF_CAPACITY_BITS             ),
    .WBUF_CAPACITY_BITS             ( WBUF_CAPACITY_BITS             ),
    .OBUF_CAPACITY_BITS             ( OBUF_CAPACITY_BITS             ),
    .BBUF_CAPACITY_BITS             ( BBUF_CAPACITY_BITS             ),

    .AXI_ADDR_WIDTH                 ( AXI_ADDR_WIDTH                 ),
    .AXI_BURST_WIDTH                ( AXI_BURST_WIDTH                ),
    .IBUF_AXI_DATA_WIDTH            ( IBUF_AXI_DATA_WIDTH            ),
    .OBUF_AXI_DATA_WIDTH            ( OBUF_AXI_DATA_WIDTH            ),
    .PU_AXI_DATA_WIDTH              ( PU_AXI_DATA_WIDTH              ),
    .WBUF_AXI_DATA_WIDTH            ( WBUF_AXI_DATA_WIDTH            ),
    .BBUF_AXI_DATA_WIDTH            ( BBUF_AXI_DATA_WIDTH            ),
    .INST_ADDR_WIDTH                ( INST_ADDR_WIDTH                ),
    .INST_DATA_WIDTH                ( INST_DATA_WIDTH                ),
    .CTRL_ADDR_WIDTH                ( CTRL_ADDR_WIDTH                ),
    .CTRL_DATA_WIDTH                ( CTRL_DATA_WIDTH                )
  ) u_bf_wrap (
    .clk                            ( clk                            ),
    .reset                          ( reset                          ),

    .pci_cl_data_awaddr             ( pci_cl_data_awaddr             ),
    .pci_cl_data_awlen              ( pci_cl_data_awlen              ),
    .pci_cl_data_awsize             ( pci_cl_data_awsize             ),
    .pci_cl_data_awburst            ( pci_cl_data_awburst            ),
    .pci_cl_data_awvalid            ( pci_cl_data_awvalid            ),
    .pci_cl_data_awready            ( pci_cl_data_awready            ),
    .pci_cl_data_wdata              ( pci_cl_data_wdata              ),
    .pci_cl_data_wstrb              ( pci_cl_data_wstrb              ),
    .pci_cl_data_wlast              ( pci_cl_data_wlast              ),
    .pci_cl_data_wvalid             ( pci_cl_data_wvalid             ),
    .pci_cl_data_wready             ( pci_cl_data_wready             ),
    .pci_cl_data_bresp              ( pci_cl_data_bresp              ),
    .pci_cl_data_bvalid             ( pci_cl_data_bvalid             ),
    .pci_cl_data_bready             ( pci_cl_data_bready             ),
    .pci_cl_data_araddr             ( pci_cl_data_araddr             ),
    .pci_cl_data_arlen              ( pci_cl_data_arlen              ),
    .pci_cl_data_arsize             ( pci_cl_data_arsize             ),
    .pci_cl_data_arburst            ( pci_cl_data_arburst            ),
    .pci_cl_data_arvalid            ( pci_cl_data_arvalid            ),
    .pci_cl_data_arready            ( pci_cl_data_arready            ),
    .pci_cl_data_rdata              ( pci_cl_data_rdata              ),
    .pci_cl_data_rresp              ( pci_cl_data_rresp              ),
    .pci_cl_data_rlast              ( pci_cl_data_rlast              ),
    .pci_cl_data_rvalid             ( pci_cl_data_rvalid             ),
    .pci_cl_data_rready             ( pci_cl_data_rready             ),

    .pci_cl_ctrl_awvalid            ( pci_cl_ctrl_awvalid            ),
    .pci_cl_ctrl_awaddr             ( pci_cl_ctrl_awaddr             ),
    .pci_cl_ctrl_awready            ( pci_cl_ctrl_awready            ),
    .pci_cl_ctrl_wvalid             ( pci_cl_ctrl_wvalid             ),
    .pci_cl_ctrl_wdata              ( pci_cl_ctrl_wdata              ),
    .pci_cl_ctrl_wstrb              ( pci_cl_ctrl_wstrb              ),
    .pci_cl_ctrl_wready             ( pci_cl_ctrl_wready             ),
    .pci_cl_ctrl_bvalid             ( pci_cl_ctrl_bvalid             ),
    .pci_cl_ctrl_bresp              ( pci_cl_ctrl_bresp              ),
    .pci_cl_ctrl_bready             ( pci_cl_ctrl_bready             ),
    .pci_cl_ctrl_arvalid            ( pci_cl_ctrl_arvalid            ),
    .pci_cl_ctrl_araddr             ( pci_cl_ctrl_araddr             ),
    .pci_cl_ctrl_arready            ( pci_cl_ctrl_arready            ),
    .pci_cl_ctrl_rvalid             ( pci_cl_ctrl_rvalid             ),
    .pci_cl_ctrl_rdata              ( pci_cl_ctrl_rdata              ),
    .pci_cl_ctrl_rresp              ( pci_cl_ctrl_rresp              ),
    .pci_cl_ctrl_rready             ( pci_cl_ctrl_rready             ),

    .cl_ddr0_awaddr                 ( cl_ddr0_awaddr                 ),
    .cl_ddr0_awlen                  ( cl_ddr0_awlen                  ),
    .cl_ddr0_awsize                 ( cl_ddr0_awsize                 ),
    .cl_ddr0_awburst                ( cl_ddr0_awburst                ),
    .cl_ddr0_awvalid                ( cl_ddr0_awvalid                ),
    .cl_ddr0_awready                ( cl_ddr0_awready                ),
    .cl_ddr0_wdata                  ( cl_ddr0_wdata                  ),
    .cl_ddr0_wstrb                  ( cl_ddr0_wstrb                  ),
    .cl_ddr0_wlast                  ( cl_ddr0_wlast                  ),
    .cl_ddr0_wvalid                 ( cl_ddr0_wvalid                 ),
    .cl_ddr0_wready                 ( cl_ddr0_wready                 ),
    .cl_ddr0_bresp                  ( cl_ddr0_bresp                  ),
    .cl_ddr0_bvalid                 ( cl_ddr0_bvalid                 ),
    .cl_ddr0_bready                 ( cl_ddr0_bready                 ),
    .cl_ddr0_araddr                 ( cl_ddr0_araddr                 ),
    .cl_ddr0_arlen                  ( cl_ddr0_arlen                  ),
    .cl_ddr0_arsize                 ( cl_ddr0_arsize                 ),
    .cl_ddr0_arburst                ( cl_ddr0_arburst                ),
    .cl_ddr0_arvalid                ( cl_ddr0_arvalid                ),
    .cl_ddr0_arid                   ( cl_ddr0_arid                   ),
    .cl_ddr0_arready                ( cl_ddr0_arready                ),
    .cl_ddr0_rdata                  ( cl_ddr0_rdata                  ),
    .cl_ddr0_rid                    ( cl_ddr0_rid                    ),
    .cl_ddr0_rresp                  ( cl_ddr0_rresp                  ),
    .cl_ddr0_rlast                  ( cl_ddr0_rlast                  ),
    .cl_ddr0_rvalid                 ( cl_ddr0_rvalid                 ),
    .cl_ddr0_rready                 ( cl_ddr0_rready                 ),

    .cl_ddr1_awaddr                 ( cl_ddr1_awaddr                 ),
    .cl_ddr1_awlen                  ( cl_ddr1_awlen                  ),
    .cl_ddr1_awsize                 ( cl_ddr1_awsize                 ),
    .cl_ddr1_awburst                ( cl_ddr1_awburst                ),
    .cl_ddr1_awvalid                ( cl_ddr1_awvalid                ),
    .cl_ddr1_awready                ( cl_ddr1_awready                ),
    .cl_ddr1_wdata                  ( cl_ddr1_wdata                  ),
    .cl_ddr1_wstrb                  ( cl_ddr1_wstrb                  ),
    .cl_ddr1_wlast                  ( cl_ddr1_wlast                  ),
    .cl_ddr1_wvalid                 ( cl_ddr1_wvalid                 ),
    .cl_ddr1_wready                 ( cl_ddr1_wready                 ),
    .cl_ddr1_bresp                  ( cl_ddr1_bresp                  ),
    .cl_ddr1_bvalid                 ( cl_ddr1_bvalid                 ),
    .cl_ddr1_bready                 ( cl_ddr1_bready                 ),
    .cl_ddr1_araddr                 ( cl_ddr1_araddr                 ),
    .cl_ddr1_arlen                  ( cl_ddr1_arlen                  ),
    .cl_ddr1_arsize                 ( cl_ddr1_arsize                 ),
    .cl_ddr1_arburst                ( cl_ddr1_arburst                ),
    .cl_ddr1_arvalid                ( cl_ddr1_arvalid                ),
    .cl_ddr1_arid                   ( cl_ddr1_arid                   ),
    .cl_ddr1_arready                ( cl_ddr1_arready                ),
    .cl_ddr1_rdata                  ( cl_ddr1_rdata                  ),
    .cl_ddr1_rid                    ( cl_ddr1_rid                    ),
    .cl_ddr1_rresp                  ( cl_ddr1_rresp                  ),
    .cl_ddr1_rlast                  ( cl_ddr1_rlast                  ),
    .cl_ddr1_rvalid                 ( cl_ddr1_rvalid                 ),
    .cl_ddr1_rready                 ( cl_ddr1_rready                 ),

    .cl_ddr2_awaddr                 ( cl_ddr2_awaddr                 ),
    .cl_ddr2_awlen                  ( cl_ddr2_awlen                  ),
    .cl_ddr2_awsize                 ( cl_ddr2_awsize                 ),
    .cl_ddr2_awburst                ( cl_ddr2_awburst                ),
    .cl_ddr2_awvalid                ( cl_ddr2_awvalid                ),
    .cl_ddr2_awready                ( cl_ddr2_awready                ),
    .cl_ddr2_wdata                  ( cl_ddr2_wdata                  ),
    .cl_ddr2_wstrb                  ( cl_ddr2_wstrb                  ),
    .cl_ddr2_wlast                  ( cl_ddr2_wlast                  ),
    .cl_ddr2_wvalid                 ( cl_ddr2_wvalid                 ),
    .cl_ddr2_wready                 ( cl_ddr2_wready                 ),
    .cl_ddr2_bresp                  ( cl_ddr2_bresp                  ),
    .cl_ddr2_bvalid                 ( cl_ddr2_bvalid                 ),
    .cl_ddr2_bready                 ( cl_ddr2_bready                 ),
    .cl_ddr2_araddr                 ( cl_ddr2_araddr                 ),
    .cl_ddr2_arlen                  ( cl_ddr2_arlen                  ),
    .cl_ddr2_arsize                 ( cl_ddr2_arsize                 ),
    .cl_ddr2_arburst                ( cl_ddr2_arburst                ),
    .cl_ddr2_arvalid                ( cl_ddr2_arvalid                ),
    .cl_ddr2_arid                   ( cl_ddr2_arid                   ),
    .cl_ddr2_arready                ( cl_ddr2_arready                ),
    .cl_ddr2_rdata                  ( cl_ddr2_rdata                  ),
    .cl_ddr2_rid                    ( cl_ddr2_rid                    ),
    .cl_ddr2_rresp                  ( cl_ddr2_rresp                  ),
    .cl_ddr2_rlast                  ( cl_ddr2_rlast                  ),
    .cl_ddr2_rvalid                 ( cl_ddr2_rvalid                 ),
    .cl_ddr2_rready                 ( cl_ddr2_rready                 ),

    .cl_ddr3_awaddr                 ( cl_ddr3_awaddr                 ),
    .cl_ddr3_awlen                  ( cl_ddr3_awlen                  ),
    .cl_ddr3_awsize                 ( cl_ddr3_awsize                 ),
    .cl_ddr3_awburst                ( cl_ddr3_awburst                ),
    .cl_ddr3_awvalid                ( cl_ddr3_awvalid                ),
    .cl_ddr3_awready                ( cl_ddr3_awready                ),
    .cl_ddr3_wdata                  ( cl_ddr3_wdata                  ),
    .cl_ddr3_wstrb                  ( cl_ddr3_wstrb                  ),
    .cl_ddr3_wlast                  ( cl_ddr3_wlast                  ),
    .cl_ddr3_wvalid                 ( cl_ddr3_wvalid                 ),
    .cl_ddr3_wready                 ( cl_ddr3_wready                 ),
    .cl_ddr3_bresp                  ( cl_ddr3_bresp                  ),
    .cl_ddr3_bvalid                 ( cl_ddr3_bvalid                 ),
    .cl_ddr3_bready                 ( cl_ddr3_bready                 ),
    .cl_ddr3_araddr                 ( cl_ddr3_araddr                 ),
    .cl_ddr3_arlen                  ( cl_ddr3_arlen                  ),
    .cl_ddr3_arsize                 ( cl_ddr3_arsize                 ),
    .cl_ddr3_arburst                ( cl_ddr3_arburst                ),
    .cl_ddr3_arvalid                ( cl_ddr3_arvalid                ),
    .cl_ddr3_arid                   ( cl_ddr3_arid                   ),
    .cl_ddr3_arready                ( cl_ddr3_arready                ),
    .cl_ddr3_rdata                  ( cl_ddr3_rdata                  ),
    .cl_ddr3_rid                    ( cl_ddr3_rid                    ),
    .cl_ddr3_rresp                  ( cl_ddr3_rresp                  ),
    .cl_ddr3_rlast                  ( cl_ddr3_rlast                  ),
    .cl_ddr3_rvalid                 ( cl_ddr3_rvalid                 ),
    .cl_ddr3_rready                 ( cl_ddr3_rready                 ),

    .cl_ddr4_awaddr                 ( cl_ddr4_awaddr                 ),
    .cl_ddr4_awlen                  ( cl_ddr4_awlen                  ),
    .cl_ddr4_awsize                 ( cl_ddr4_awsize                 ),
    .cl_ddr4_awburst                ( cl_ddr4_awburst                ),
    .cl_ddr4_awvalid                ( cl_ddr4_awvalid                ),
    .cl_ddr4_awready                ( cl_ddr4_awready                ),
    .cl_ddr4_wdata                  ( cl_ddr4_wdata                  ),
    .cl_ddr4_wstrb                  ( cl_ddr4_wstrb                  ),
    .cl_ddr4_wlast                  ( cl_ddr4_wlast                  ),
    .cl_ddr4_wvalid                 ( cl_ddr4_wvalid                 ),
    .cl_ddr4_wready                 ( cl_ddr4_wready                 ),
    .cl_ddr4_bresp                  ( cl_ddr4_bresp                  ),
    .cl_ddr4_bvalid                 ( cl_ddr4_bvalid                 ),
    .cl_ddr4_bready                 ( cl_ddr4_bready                 ),
    .cl_ddr4_araddr                 ( cl_ddr4_araddr                 ),
    .cl_ddr4_arlen                  ( cl_ddr4_arlen                  ),
    .cl_ddr4_arsize                 ( cl_ddr4_arsize                 ),
    .cl_ddr4_arburst                ( cl_ddr4_arburst                ),
    .cl_ddr4_arvalid                ( cl_ddr4_arvalid                ),
    .cl_ddr4_arid                   ( cl_ddr4_arid                   ),
    .cl_ddr4_arready                ( cl_ddr4_arready                ),
    .cl_ddr4_rdata                  ( cl_ddr4_rdata                  ),
    .cl_ddr4_rid                    ( cl_ddr4_rid                    ),
    .cl_ddr4_rresp                  ( cl_ddr4_rresp                  ),
    .cl_ddr4_rlast                  ( cl_ddr4_rlast                  ),
    .cl_ddr4_rvalid                 ( cl_ddr4_rvalid                 ),
    .cl_ddr4_rready                 ( cl_ddr4_rready                 )
  );
//=============================================================

//=============================================================
// VCD
//=============================================================
`ifdef COCOTB_TOPLEVEL_cl_wrapper
  initial begin
    $dumpfile("cl_wrapper.vcd");
    $dumpvars(0, cl_wrapper);
  end
`endif
//=============================================================

endmodule
