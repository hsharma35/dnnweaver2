//
// DnnWeaver2 controller
//
// Hardik Sharma
// (hsharma@gatech.edu)

`timescale 1ns/1ps
module controller #(
    parameter integer  NUM_TAGS                     = 2,
    parameter integer  TAG_W                        = $clog2(NUM_TAGS),
    parameter integer  ADDR_WIDTH                   = 42,
    parameter integer  IBUF_ADDR_WIDTH              = ADDR_WIDTH,
    parameter integer  WBUF_ADDR_WIDTH              = ADDR_WIDTH,
    parameter integer  OBUF_ADDR_WIDTH              = ADDR_WIDTH,
    parameter integer  BBUF_ADDR_WIDTH              = ADDR_WIDTH,
  // Instructions
    parameter integer  INST_DATA_WIDTH              = 32,
    parameter integer  INST_ADDR_WIDTH              = 32,
    parameter integer  INST_WSTRB_WIDTH             = INST_DATA_WIDTH/8,
    parameter integer  INST_BURST_WIDTH             = 8,
  // Decoder
    parameter integer  BUF_TYPE_W                   = 2,
    parameter integer  LOOP_ITER_W                  = 16,
    parameter integer  ADDR_STRIDE_W                = 32,
    parameter integer  MEM_REQ_W                    = 16,
    parameter integer  LOOP_ID_W                    = 5,
  // AXI-Lite
    parameter integer  CTRL_ADDR_WIDTH              = 32,
    parameter integer  CTRL_DATA_WIDTH              = 32,
    parameter integer  CTRL_WSTRB_WIDTH             = CTRL_DATA_WIDTH/8,
  // AXI
    parameter integer  AXI_BURST_WIDTH              = 8,
  // Instruction Mem
    parameter integer  IMEM_ADDR_WIDTH              = 12
) (
    input  wire                                         clk,
    input  wire                                         reset,

  // controller <-> compute handshakes
    output wire                                         tag_flush,
    output wire                                         tag_req,
    output wire                                         ibuf_tag_reuse,
    output wire                                         obuf_tag_reuse,
    output wire                                         wbuf_tag_reuse,
    output wire                                         bias_tag_reuse,
    input  wire                                         tag_ready,
    input  wire                                         ibuf_tag_done,
    input  wire                                         wbuf_tag_done,
    input  wire                                         obuf_tag_done,
    input  wire                                         bias_tag_done,

    input  wire                                         compute_done,
    input  wire                                         pu_compute_done,
    input  wire                                         pu_write_done,
    input  wire                                         pu_compute_start,
    input  wire  [ 3                    -1 : 0 ]        pu_ctrl_state,
    input  wire  [ 4                    -1 : 0 ]        stmem_state,
    input  wire  [ TAG_W                -1 : 0 ]        stmem_tag,
    input  wire                                         stmem_ddr_pe_sw,
    input  wire                                         ld_obuf_req,
    input  wire                                         ld_obuf_ready,

  // Load/Store addresses
    // Bias load address
    output wire  [ BBUF_ADDR_WIDTH      -1 : 0 ]        bias_ld_addr,
    output wire                                         bias_ld_addr_v,
    // IBUF load address
    output wire  [ IBUF_ADDR_WIDTH      -1 : 0 ]        ibuf_ld_addr,
    output wire                                         ibuf_ld_addr_v,
    // WBUF load address
    output wire  [ WBUF_ADDR_WIDTH      -1 : 0 ]        wbuf_ld_addr,
    output wire                                         wbuf_ld_addr_v,
    // OBUF load/store address
    output wire  [ OBUF_ADDR_WIDTH      -1 : 0 ]        obuf_ld_addr,
    output wire                                         obuf_ld_addr_v,
    output wire  [ OBUF_ADDR_WIDTH      -1 : 0 ]        obuf_st_addr,
    output wire                                         obuf_st_addr_v,

  // Load bias or obuf
    output wire                                         tag_bias_prev_sw,
    output wire                                         tag_ddr_pe_sw,

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

    input  wire                                         ibuf_compute_ready,
    input  wire                                         wbuf_compute_ready,
    input  wire                                         obuf_compute_ready,
    input  wire                                         bias_compute_ready,

  // Programming interface
    // Loop iterations
    output wire  [ LOOP_ITER_W          -1 : 0 ]        cfg_loop_iter,
    output wire  [ LOOP_ID_W            -1 : 0 ]        cfg_loop_iter_loop_id,
    output wire                                         cfg_loop_iter_v,
    // Loop stride
    output wire  [ ADDR_STRIDE_W        -1 : 0 ]        cfg_loop_stride,
    output wire                                         cfg_loop_stride_v,
    output wire  [ BUF_TYPE_W           -1 : 0 ]        cfg_loop_stride_id,
    output wire  [ 2                    -1 : 0 ]        cfg_loop_stride_type,
    output wire  [ LOOP_ID_W            -1 : 0 ]        cfg_loop_stride_loop_id,
    // Memory request
    output wire  [ MEM_REQ_W            -1 : 0 ]        cfg_mem_req_size,
    output wire                                         cfg_mem_req_v,
    output wire  [ 2                    -1 : 0 ]        cfg_mem_req_type,
    output wire  [ BUF_TYPE_W           -1 : 0 ]        cfg_mem_req_id,
    output wire  [ LOOP_ID_W            -1 : 0 ]        cfg_mem_req_loop_id,
    // Buffer request
    output wire  [ MEM_REQ_W            -1 : 0 ]        cfg_buf_req_size,
    output wire                                         cfg_buf_req_v,
    output wire                                         cfg_buf_req_type,
    output wire  [ BUF_TYPE_W           -1 : 0 ]        cfg_buf_req_loop_id,

    output wire                                         cfg_pu_inst_v,
    output wire  [ INST_DATA_WIDTH      -1 : 0 ]        cfg_pu_inst,
    output wire                                         pu_block_start,

  // Snoop CL DDR0
    // AR channel
    input  wire  [ CTRL_ADDR_WIDTH      -1 : 0 ]        snoop_cl_ddr0_araddr,
    input  wire                                         snoop_cl_ddr0_arvalid,
    input  wire                                         snoop_cl_ddr0_arready,
    input  wire  [ AXI_BURST_WIDTH      -1 : 0 ]        snoop_cl_ddr0_arlen,
    // R channel
    input  wire                                         snoop_cl_ddr0_rvalid,
    input  wire                                         snoop_cl_ddr0_rready,

  // Snoop CL DDR1
    // AW channel
    input  wire  [ CTRL_ADDR_WIDTH      -1 : 0 ]        snoop_cl_ddr1_awaddr,
    input  wire                                         snoop_cl_ddr1_awvalid,
    input  wire                                         snoop_cl_ddr1_awready,
    input  wire  [ AXI_BURST_WIDTH      -1 : 0 ]        snoop_cl_ddr1_awlen,
    // AR channel
    input  wire  [ CTRL_ADDR_WIDTH      -1 : 0 ]        snoop_cl_ddr1_araddr,
    input  wire                                         snoop_cl_ddr1_arvalid,
    input  wire                                         snoop_cl_ddr1_arready,
    input  wire  [ AXI_BURST_WIDTH      -1 : 0 ]        snoop_cl_ddr1_arlen,
    // W channel
    input  wire                                         snoop_cl_ddr1_wvalid,
    input  wire                                         snoop_cl_ddr1_wready,
    // R channel
    input  wire                                         snoop_cl_ddr1_rvalid,
    input  wire                                         snoop_cl_ddr1_rready,

  // Snoop CL DDR2
    // AR channel
    input  wire  [ CTRL_ADDR_WIDTH      -1 : 0 ]        snoop_cl_ddr2_araddr,
    input  wire                                         snoop_cl_ddr2_arvalid,
    input  wire                                         snoop_cl_ddr2_arready,
    input  wire  [ AXI_BURST_WIDTH      -1 : 0 ]        snoop_cl_ddr2_arlen,
    // R channel
    input  wire                                         snoop_cl_ddr2_rvalid,
    input  wire                                         snoop_cl_ddr2_rready,

  // Snoop CL DDR3
    // AR channel
    input  wire  [ CTRL_ADDR_WIDTH      -1 : 0 ]        snoop_cl_ddr3_araddr,
    input  wire                                         snoop_cl_ddr3_arvalid,
    input  wire                                         snoop_cl_ddr3_arready,
    input  wire  [ AXI_BURST_WIDTH      -1 : 0 ]        snoop_cl_ddr3_arlen,
    // R channel
    input  wire                                         snoop_cl_ddr3_rvalid,
    input  wire                                         snoop_cl_ddr3_rready,

  // Snoop CL DDR4
    // AW channel
    input  wire  [ CTRL_ADDR_WIDTH      -1 : 0 ]        snoop_cl_ddr4_awaddr,
    input  wire                                         snoop_cl_ddr4_awvalid,
    input  wire                                         snoop_cl_ddr4_awready,
    input  wire  [ AXI_BURST_WIDTH      -1 : 0 ]        snoop_cl_ddr4_awlen,
    // AR channel
    input  wire  [ CTRL_ADDR_WIDTH      -1 : 0 ]        snoop_cl_ddr4_araddr,
    input  wire                                         snoop_cl_ddr4_arvalid,
    input  wire                                         snoop_cl_ddr4_arready,
    input  wire  [ AXI_BURST_WIDTH      -1 : 0 ]        snoop_cl_ddr4_arlen,
    // W channel
    input  wire                                         snoop_cl_ddr4_wvalid,
    input  wire                                         snoop_cl_ddr4_wready,
    // R channel
    input  wire                                         snoop_cl_ddr4_rvalid,
    input  wire                                         snoop_cl_ddr4_rready,

    input  wire  [ INST_DATA_WIDTH      -1 : 0 ]        obuf_ld_stream_read_count,
    input  wire  [ INST_DATA_WIDTH      -1 : 0 ]        obuf_ld_stream_write_count,
    input  wire  [ INST_DATA_WIDTH      -1 : 0 ]        ddr_st_stream_read_count,
    input  wire  [ INST_DATA_WIDTH      -1 : 0 ]        ddr_st_stream_write_count,
    input  wire  [ INST_DATA_WIDTH      -1 : 0 ]        ld0_stream_counts,
    input  wire  [ INST_DATA_WIDTH      -1 : 0 ]        ld1_stream_counts,
    input  wire  [ INST_DATA_WIDTH      -1 : 0 ]        axi_wr_fifo_counts
  );

//=============================================================
// Localparam
//=============================================================
  // DnnWeaver2 controller state
    localparam integer  IDLE                         = 0;
    localparam integer  DECODE                       = 1;
    localparam integer  BASE_LOOP                    = 2;
    localparam integer  MEM_WAIT                     = 3;
    localparam integer  PU_WR_WAIT                   = 4;
    localparam integer  BLOCK_DONE                   = 5;
    localparam integer  DONE                         = 6;

    localparam integer  TM_STATE_WIDTH               = 2;
    localparam integer  TM_IDLE                      = 0;
    localparam integer  TM_REQUEST                   = 1;
    localparam integer  TM_CHECK                     = 2;
    localparam integer  TM_FLUSH                     = 3;
//=============================================================

//=============================================================
// Wires/Regs
//=============================================================
    wire                                        last_block;
  // --------Debug--------
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_busy_cycles;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_decode_cycles;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_execute_cycles;

    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_block_started;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_block_finished;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_tag_started;

    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_axi_wr_id;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_axi_write_req;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_axi_write_finished;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_axi_read_req;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_axi_read_finished;

    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_cl_ddr0_read_req;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_cl_ddr0_read_finished;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_cl_ddr1_write_req;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_cl_ddr1_write_finished;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_cl_ddr1_read_req;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_cl_ddr1_read_finished;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_cl_ddr2_read_req;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_cl_ddr2_read_finished;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_cl_ddr3_read_req;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_cl_ddr3_read_finished;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_cl_ddr4_write_req;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_cl_ddr4_write_finished;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_cl_ddr4_read_req;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        pmon_cl_ddr4_read_finished;

  // --------Debug--------

  // DnnWeaver2 states
    reg  [ 3                    -1 : 0 ]        dnnweaver2_state_d;
    reg  [ 3                    -1 : 0 ]        dnnweaver2_state_q;
    wire [ 3                    -1 : 0 ]        dnnweaver2_state;

  // Base addresses
    wire [ IBUF_ADDR_WIDTH      -1 : 0 ]        ibuf_base_addr;
    wire [ IBUF_ADDR_WIDTH      -1 : 0 ]        wbuf_base_addr;
    wire [ IBUF_ADDR_WIDTH      -1 : 0 ]        obuf_base_addr;
    wire [ IBUF_ADDR_WIDTH      -1 : 0 ]        bias_base_addr;

  // Handshake signals for main loop controller
    wire                                        base_loop_ctrl_start;
    wire                                        base_loop_ctrl_done;

    wire                                        block_done;
    wire                                        dnnweaver2_done;

  // Handshake signals for decoder
    wire                                        decoder_start;
    wire                                        decoder_done;

  // Instruction memory Read Port - Decoder
    wire                                        inst_read_req;
    wire [ IMEM_ADDR_WIDTH      -1 : 0 ]        inst_read_addr;
    wire [ INST_DATA_WIDTH      -1 : 0 ]        inst_read_data;

  // Start address for fetching/decoding instruction block
    wire [ IMEM_ADDR_WIDTH      -1 : 0 ]        num_blocks;

  // resetn for axi slave
    wire                                        resetn;

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
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg16_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg16_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg17_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg17_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg18_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg18_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg19_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg19_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg20_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg20_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg21_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg21_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg22_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg22_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg23_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg23_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg24_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg24_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg25_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg25_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg26_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg26_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg27_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg27_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg28_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg28_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg29_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg29_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg30_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg30_out;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg31_in;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        slv_reg31_out;
  // Slave registers end

  // Accelerator start logic
    wire                                        start_bit_d;
    reg                                         start_bit_q;

  // TM State
    reg  [ TM_STATE_WIDTH       -1 : 0 ]        tm_state_d;
    reg  [ TM_STATE_WIDTH       -1 : 0 ]        tm_state_q;

    reg                                         tm_ibuf_tag_reuse_d;
    reg                                         tm_ibuf_tag_reuse_q;
    reg                                         tm_obuf_tag_reuse_d;
    reg                                         tm_obuf_tag_reuse_q;
    reg                                         tm_wbuf_tag_reuse_d;
    reg                                         tm_wbuf_tag_reuse_q;
    reg                                         tm_bias_tag_reuse_d;
    reg                                         tm_bias_tag_reuse_q;

    reg  [ ADDR_WIDTH           -1 : 0 ]        tm_ibuf_tag_addr_d;
    reg  [ ADDR_WIDTH           -1 : 0 ]        tm_ibuf_tag_addr_q;
    reg  [ ADDR_WIDTH           -1 : 0 ]        tm_obuf_tag_addr_d;
    reg  [ ADDR_WIDTH           -1 : 0 ]        tm_obuf_tag_addr_q;
    reg  [ ADDR_WIDTH           -1 : 0 ]        tm_wbuf_tag_addr_d;
    reg  [ ADDR_WIDTH           -1 : 0 ]        tm_wbuf_tag_addr_q;
    reg  [ ADDR_WIDTH           -1 : 0 ]        tm_bias_tag_addr_d;
    reg  [ ADDR_WIDTH           -1 : 0 ]        tm_bias_tag_addr_q;

    wire                                        base_ctrl_tag_req;
    wire                                        base_ctrl_tag_ready;

    assign tag_req = tm_state_q == TM_REQUEST;

  always @(posedge clk)
  begin
    if(reset)
      tm_state_q <= TM_IDLE;
    else
      tm_state_q <= tm_state_d;
  end

  always @(posedge clk)
  begin
    if(reset) begin
      tm_ibuf_tag_reuse_q <= 1'b0;
      tm_obuf_tag_reuse_q <= 1'b0;
      tm_wbuf_tag_reuse_q <= 1'b0;
      tm_bias_tag_reuse_q <= 1'b0;
      tm_ibuf_tag_addr_q  <= 0;
      tm_obuf_tag_addr_q  <= 0;
      tm_wbuf_tag_addr_q  <= 0;
      tm_bias_tag_addr_q  <= 0;
    end else begin
      tm_ibuf_tag_reuse_q <= tm_ibuf_tag_reuse_d;
      tm_obuf_tag_reuse_q <= tm_obuf_tag_reuse_d;
      tm_wbuf_tag_reuse_q <= tm_wbuf_tag_reuse_d;
      tm_bias_tag_reuse_q <= tm_bias_tag_reuse_d;
      tm_ibuf_tag_addr_q  <= tm_ibuf_tag_addr_d;
      tm_obuf_tag_addr_q  <= tm_obuf_tag_addr_d;
      tm_wbuf_tag_addr_q  <= tm_wbuf_tag_addr_d;
      tm_bias_tag_addr_q  <= tm_bias_tag_addr_d;
    end
  end

  always @(*)
  begin
  
    tm_state_d = tm_state_q;
    
    tm_ibuf_tag_reuse_d = 1'b0;
    tm_obuf_tag_reuse_d = 1'b0;
    tm_wbuf_tag_reuse_d = 1'b0;
    tm_bias_tag_reuse_d = 1'b0;
    
    tm_ibuf_tag_addr_d = tm_ibuf_tag_addr_q;
    tm_obuf_tag_addr_d = tm_obuf_tag_addr_q;
    tm_wbuf_tag_addr_d = tm_wbuf_tag_addr_q;
    tm_bias_tag_addr_d = tm_bias_tag_addr_q;
    
    case(tm_state_q)
      TM_IDLE: begin
        if (base_ctrl_tag_req && tag_ready)
          tm_state_d = TM_REQUEST;
      end
      TM_REQUEST: begin
        if (tag_ready) begin
          tm_state_d = TM_CHECK;
          tm_ibuf_tag_addr_d = ibuf_ld_addr;
          tm_obuf_tag_addr_d = obuf_ld_addr;
          tm_wbuf_tag_addr_d = wbuf_ld_addr;
          tm_bias_tag_addr_d = bias_ld_addr;
        end
      end
      TM_CHECK: begin
        if (base_ctrl_tag_req && tag_ready) begin
          tm_state_d = TM_REQUEST;
          tm_ibuf_tag_reuse_d = tm_ibuf_tag_addr_q == ibuf_ld_addr;
          tm_obuf_tag_reuse_d = tm_obuf_tag_addr_q == obuf_ld_addr;
          tm_wbuf_tag_reuse_d = tm_wbuf_tag_addr_q == wbuf_ld_addr;
          tm_bias_tag_reuse_d = tm_bias_tag_addr_q == bias_ld_addr;
        end
        else if (dnnweaver2_state_q == MEM_WAIT)
        begin
          tm_state_d = TM_FLUSH;
        end
      end
      TM_FLUSH: begin
        tm_state_d = TM_IDLE;
      end
    endcase
  end

  assign tag_flush = tm_state_q == TM_FLUSH;

    assign ibuf_tag_reuse = tm_ibuf_tag_reuse_q;
    assign obuf_tag_reuse = tm_obuf_tag_reuse_q;
    assign wbuf_tag_reuse = tm_wbuf_tag_reuse_q;
    assign bias_tag_reuse = tm_bias_tag_reuse_q;

    assign base_ctrl_tag_ready = tag_ready && tm_state_q == TM_REQUEST;
//=============================================================

//=============================================================
// Accelerator Start logic
//=============================================================
  always @(posedge clk)
  begin
    if (reset)
      start_bit_q <= 1'b0;
    else
      start_bit_q <= start_bit_d;
  end
//=============================================================

//=============================================================
// FSM
//=============================================================
  always @(posedge clk)
  begin
    if (reset) begin
      dnnweaver2_state_q <= IDLE;
    end
    else begin
      dnnweaver2_state_q <= dnnweaver2_state_d;
    end
  end

  always @(*)
  begin
    dnnweaver2_state_d = dnnweaver2_state_q;
    case(dnnweaver2_state_q)
      IDLE: begin
        if (decoder_start) begin
          dnnweaver2_state_d = DECODE;
        end
      end
      DECODE: begin
        if (base_loop_ctrl_start)
          dnnweaver2_state_d = BASE_LOOP;
      end
      BASE_LOOP: begin
        if (base_loop_ctrl_done)
          dnnweaver2_state_d = MEM_WAIT;
      end
      MEM_WAIT: begin
        if (ibuf_tag_done && wbuf_tag_done && obuf_tag_done && bias_tag_done)
          dnnweaver2_state_d = PU_WR_WAIT;
      end
      PU_WR_WAIT: begin
        if (pu_write_done) begin
          dnnweaver2_state_d = BLOCK_DONE;
        end
      end
      BLOCK_DONE: begin
        if (~last_block)
          dnnweaver2_state_d = DECODE;
        else
          dnnweaver2_state_d = DONE;
      end
      DONE: begin
        dnnweaver2_state_d = IDLE;
      end
    endcase
  end
    assign block_done = dnnweaver2_state == BLOCK_DONE;
    assign dnnweaver2_done = dnnweaver2_state == DONE;
//=============================================================

//=============================================================
// Debug
//=============================================================
    reg  [ CTRL_DATA_WIDTH      -1 : 0 ]        tag_req_count;
    reg  [ CTRL_DATA_WIDTH      -1 : 0 ]        compute_done_count;
    reg  [ CTRL_DATA_WIDTH      -1 : 0 ]        pu_compute_done_count;
    reg  [ CTRL_DATA_WIDTH      -1 : 0 ]        pu_compute_start_count;
    always @(posedge clk)
    begin
      if (reset)
        tag_req_count <= 0;
      else if (tm_state_q == TM_REQUEST)
        tag_req_count <= tag_req_count + 1'b1;
    end

    always @(posedge clk)
    begin
      if (reset)
        compute_done_count <= 0;
      else if (compute_done)
        compute_done_count <= compute_done_count + 1'b1;
    end

    always @(posedge clk)
    begin
      if (reset)
        pu_compute_done_count <= 0;
      else if (pu_compute_done)
        pu_compute_done_count <= pu_compute_done_count + 1'b1;
    end

    always @(posedge clk)
    begin
      if (reset)
        pu_compute_start_count <= 0;
      else if (pu_compute_start)
        pu_compute_start_count <= pu_compute_start_count + 1'b1;
    end
//=============================================================

//=============================================================
// Assigns
//=============================================================
    assign dnnweaver2_state = dnnweaver2_state_q;

    assign resetn = ~reset;

    assign num_blocks = slv_reg1_out;

    assign start_bit_d = slv_reg0_out[0];
    assign decoder_start = (start_bit_q ^ start_bit_d) && dnnweaver2_state_q == IDLE;

    assign slv_reg0_in = slv_reg0_out; // Used as start trigger
    assign slv_reg1_in = slv_reg1_out; // Used as start address

    assign slv_reg2_in = dnnweaver2_state;
    assign slv_reg3_in = tag_req_count;
    assign slv_reg4_in = compute_done_count;
    assign slv_reg5_in = pu_compute_done_count;
    assign slv_reg6_in = pu_compute_start_count;

    // assign slv_reg3_in = pmon_decode_cycles;
    // assign slv_reg4_in = pmon_execute_cycles;
    // assign slv_reg5_in = pmon_busy_cycles;

    assign slv_reg7_in = {stmem_state, 14'b0, stmem_ddr_pe_sw, stmem_tag};

    assign slv_reg8_in = pmon_axi_write_req;
    assign slv_reg9_in = pmon_axi_write_finished;
    assign slv_reg10_in = pmon_axi_read_req;
    assign slv_reg11_in = pmon_axi_read_finished;
    assign slv_reg12_in = pmon_axi_wr_id;

    assign slv_reg13_in = ld0_stream_counts;
    assign slv_reg14_in = ld1_stream_counts;
    assign slv_reg15_in = axi_wr_fifo_counts;

    assign slv_reg16_in = pmon_cl_ddr0_read_req;
    assign slv_reg17_in = pmon_cl_ddr0_read_finished;

    assign slv_reg18_in = pmon_cl_ddr1_write_req;
    assign slv_reg19_in = pmon_cl_ddr1_write_finished;
    assign slv_reg20_in = pmon_cl_ddr1_read_req;
    assign slv_reg21_in = pmon_cl_ddr1_read_finished;

    assign slv_reg22_in = obuf_ld_stream_read_count;
    assign slv_reg23_in = obuf_ld_stream_write_count;
    assign slv_reg24_in = ddr_st_stream_read_count;
    assign slv_reg25_in = ddr_st_stream_write_count;

    assign slv_reg26_in = pmon_cl_ddr4_write_req;
    assign slv_reg27_in = pmon_cl_ddr4_write_finished;
    assign slv_reg28_in = pmon_cl_ddr4_read_req;
    assign slv_reg29_in = pmon_cl_ddr4_read_finished;

    assign slv_reg30_in = pu_ctrl_state;

    reg  [ CTRL_DATA_WIDTH      -1 : 0 ]        ld_obuf_read_counter;

    always @(posedge clk)
    begin
      if (reset)
        ld_obuf_read_counter <= 0;
      else if (ld_obuf_req)
        ld_obuf_read_counter <= ld_obuf_read_counter + 1'b1;
    end
    assign slv_reg31_in = ld_obuf_read_counter;

//=============================================================

//=============================================================
// Performance monitor
//=============================================================
  performance_monitor #(
    .STATS_WIDTH                    ( CTRL_DATA_WIDTH                )
  ) u_perf_mon (
    .clk                            ( clk                            ),
    .reset                          ( reset                          ),
    .dnnweaver2_state                ( dnnweaver2_state_q              ), //input
    .tag_req                        ( tag_req                        ), //input
    .tag_ready                      ( tag_ready                      ), //input

    .decoder_start                  ( decoder_start                  ), //input

    .ibuf_tag_done                  ( ibuf_tag_done                  ), //input
    .wbuf_tag_done                  ( wbuf_tag_done                  ), //input
    .obuf_tag_done                  ( obuf_tag_done                  ), //input
    .bias_tag_done                  ( bias_tag_done                  ), //input

    .pci_cl_data_awvalid            ( pci_cl_data_awvalid            ), //input
    .pci_cl_data_awlen              ( pci_cl_data_awlen              ), //input
    .pci_cl_data_awready            ( pci_cl_data_awready            ), //input
    .pci_cl_data_arvalid            ( pci_cl_data_arvalid            ), //input
    .pci_cl_data_arlen              ( pci_cl_data_arlen              ), //input
    .pci_cl_data_arready            ( pci_cl_data_arready            ), //input
    .pci_cl_data_wvalid             ( pci_cl_data_wvalid             ), //input
    .pci_cl_data_wready             ( pci_cl_data_wready             ), //input
    .pci_cl_data_rvalid             ( pci_cl_data_rvalid             ), //input
    .pci_cl_data_rready             ( pci_cl_data_rready             ), //input

    .snoop_cl_ddr0_arvalid          ( snoop_cl_ddr0_arvalid          ), //input
    .snoop_cl_ddr0_arready          ( snoop_cl_ddr0_arready          ), //input
    .snoop_cl_ddr0_arlen            ( snoop_cl_ddr0_arlen            ), //input
    .snoop_cl_ddr0_rvalid           ( snoop_cl_ddr0_rvalid           ), //input
    .snoop_cl_ddr0_rready           ( snoop_cl_ddr0_rready           ), //input

    .snoop_cl_ddr1_awvalid          ( snoop_cl_ddr1_awvalid          ), //input
    .snoop_cl_ddr1_awready          ( snoop_cl_ddr1_awready          ), //input
    .snoop_cl_ddr1_awlen            ( snoop_cl_ddr1_awlen            ), //input
    .snoop_cl_ddr1_arvalid          ( snoop_cl_ddr1_arvalid          ), //input
    .snoop_cl_ddr1_arready          ( snoop_cl_ddr1_arready          ), //input
    .snoop_cl_ddr1_arlen            ( snoop_cl_ddr1_arlen            ), //input
    .snoop_cl_ddr1_wvalid           ( snoop_cl_ddr1_wvalid           ), //input
    .snoop_cl_ddr1_wready           ( snoop_cl_ddr1_wready           ), //input
    .snoop_cl_ddr1_rvalid           ( snoop_cl_ddr1_rvalid           ), //input
    .snoop_cl_ddr1_rready           ( snoop_cl_ddr1_rready           ), //input

    .snoop_cl_ddr2_arvalid          ( snoop_cl_ddr2_arvalid          ), //input
    .snoop_cl_ddr2_arready          ( snoop_cl_ddr2_arready          ), //input
    .snoop_cl_ddr2_arlen            ( snoop_cl_ddr2_arlen            ), //input
    .snoop_cl_ddr2_rvalid           ( snoop_cl_ddr2_rvalid           ), //input
    .snoop_cl_ddr2_rready           ( snoop_cl_ddr2_rready           ), //input

    .snoop_cl_ddr3_arvalid          ( snoop_cl_ddr3_arvalid          ), //input
    .snoop_cl_ddr3_arready          ( snoop_cl_ddr3_arready          ), //input
    .snoop_cl_ddr3_arlen            ( snoop_cl_ddr3_arlen            ), //input
    .snoop_cl_ddr3_rvalid           ( snoop_cl_ddr3_rvalid           ), //input
    .snoop_cl_ddr3_rready           ( snoop_cl_ddr3_rready           ), //input

    .snoop_cl_ddr4_awvalid          ( snoop_cl_ddr4_awvalid          ), //input
    .snoop_cl_ddr4_awready          ( snoop_cl_ddr4_awready          ), //input
    .snoop_cl_ddr4_awlen            ( snoop_cl_ddr4_awlen            ), //input
    .snoop_cl_ddr4_arvalid          ( snoop_cl_ddr4_arvalid          ), //input
    .snoop_cl_ddr4_arready          ( snoop_cl_ddr4_arready          ), //input
    .snoop_cl_ddr4_arlen            ( snoop_cl_ddr4_arlen            ), //input
    .snoop_cl_ddr4_wvalid           ( snoop_cl_ddr4_wvalid           ), //input
    .snoop_cl_ddr4_wready           ( snoop_cl_ddr4_wready           ), //input
    .snoop_cl_ddr4_rvalid           ( snoop_cl_ddr4_rvalid           ), //input
    .snoop_cl_ddr4_rready           ( snoop_cl_ddr4_rready           ), //input

    .pmon_cl_ddr0_read_req          ( pmon_cl_ddr0_read_req          ), //output
    .pmon_cl_ddr0_read_finished     ( pmon_cl_ddr0_read_finished     ), //output
    .pmon_cl_ddr1_write_req         ( pmon_cl_ddr1_write_req         ), //output
    .pmon_cl_ddr1_write_finished    ( pmon_cl_ddr1_write_finished    ), //output
    .pmon_cl_ddr1_read_req          ( pmon_cl_ddr1_read_req          ), //output
    .pmon_cl_ddr1_read_finished     ( pmon_cl_ddr1_read_finished     ), //output
    .pmon_cl_ddr2_read_req          ( pmon_cl_ddr2_read_req          ), //output
    .pmon_cl_ddr2_read_finished     ( pmon_cl_ddr2_read_finished     ), //output
    .pmon_cl_ddr3_read_req          ( pmon_cl_ddr3_read_req          ), //output
    .pmon_cl_ddr3_read_finished     ( pmon_cl_ddr3_read_finished     ), //output
    .pmon_cl_ddr4_write_req         ( pmon_cl_ddr4_write_req         ), //output
    .pmon_cl_ddr4_write_finished    ( pmon_cl_ddr4_write_finished    ), //output
    .pmon_cl_ddr4_read_req          ( pmon_cl_ddr4_read_req          ), //output
    .pmon_cl_ddr4_read_finished     ( pmon_cl_ddr4_read_finished     ), //output

    .decode_cycles                  ( pmon_decode_cycles             ), //output
    .execute_cycles                 ( pmon_execute_cycles            ), //output
    .busy_cycles                    ( pmon_busy_cycles               ), //output

    .tag_started                    ( pmon_tag_started               ), //output
    .block_started                  ( pmon_block_started             ), //output
    .block_finished                 ( pmon_block_finished            ), //output

    .axi_wr_id                      ( pmon_axi_wr_id                 ), //output
    .axi_write_req                  ( pmon_axi_write_req             ), //output
    .axi_write_finished             ( pmon_axi_write_finished        ), //output
    .axi_read_req                   ( pmon_axi_read_req              ), //output
    .axi_read_finished              ( pmon_axi_read_finished         )  //output
  );
//=============================================================

//=============================================================
// Instruction Memory
//=============================================================
  instruction_memory #(
    .DATA_WIDTH                     ( INST_DATA_WIDTH                ),
    .ADDR_WIDTH                     ( IMEM_ADDR_WIDTH                )
  ) imem (
    .clk                            ( clk                            ),
    .reset                          ( reset                          ),
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
    .s_read_addr_b                  ( inst_read_addr                 ), //input
    .s_read_req_b                   ( inst_read_req                  ), //input
    .s_read_data_b                  ( inst_read_data                 )  //output
  );
//=============================================================

//=============================================================
// Status/Control AXI4-Lite
//=============================================================
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        ibuf_rd_addr;
    wire                                        ibuf_rd_addr_v;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        obuf_wr_addr;
    wire                                        obuf_wr_addr_v;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        obuf_rd_addr;
    wire                                        obuf_rd_addr_v;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        wbuf_rd_addr;
    wire                                        wbuf_rd_addr_v;
    wire [ CTRL_DATA_WIDTH      -1 : 0 ]        bias_rd_addr;
    wire                                        bias_rd_addr_v;

    assign ibuf_rd_addr = snoop_cl_ddr0_araddr;
    assign ibuf_rd_addr_v = snoop_cl_ddr0_arvalid && snoop_cl_ddr0_arready;
    assign obuf_wr_addr = snoop_cl_ddr1_awaddr;
    assign obuf_wr_addr_v = snoop_cl_ddr1_awvalid && snoop_cl_ddr1_awready;
    assign obuf_rd_addr = snoop_cl_ddr1_araddr;
    assign obuf_rd_addr_v = snoop_cl_ddr1_arvalid && snoop_cl_ddr1_arready;
    assign wbuf_rd_addr = snoop_cl_ddr2_araddr;
    assign wbuf_rd_addr_v = snoop_cl_ddr2_arvalid && snoop_cl_ddr2_arready;
    assign bias_rd_addr = snoop_cl_ddr3_araddr;
    assign bias_rd_addr_v = snoop_cl_ddr3_arvalid && snoop_cl_ddr3_arready;

  axi4lite_slave #(
    .AXIS_ADDR_WIDTH                ( CTRL_ADDR_WIDTH                ),
    .AXIS_DATA_WIDTH                ( CTRL_DATA_WIDTH                )
  ) status_ctrl_slv   (
    .clk                            ( clk                            ),
    .resetn                         ( resetn                         ),
  // Slave registers
    .slv_reg0_in                    ( slv_reg0_in                    ),
    .slv_reg0_out                   ( slv_reg0_out                   ),
    .slv_reg1_in                    ( slv_reg1_in                    ),
    .slv_reg1_out                   ( slv_reg1_out                   ),
    .slv_reg2_in                    ( slv_reg2_in                    ),
    .slv_reg2_out                   ( slv_reg2_out                   ),
    .slv_reg3_in                    ( slv_reg3_in                    ),
    .slv_reg3_out                   ( slv_reg3_out                   ),
    .slv_reg4_in                    ( slv_reg4_in                    ),
    .slv_reg4_out                   ( slv_reg4_out                   ),
    .slv_reg5_in                    ( slv_reg5_in                    ),
    .slv_reg5_out                   ( slv_reg5_out                   ),
    .slv_reg6_in                    ( slv_reg6_in                    ),
    .slv_reg6_out                   ( slv_reg6_out                   ),
    .slv_reg7_in                    ( slv_reg7_in                    ),
    .slv_reg7_out                   ( slv_reg7_out                   ),
    .slv_reg8_in                    ( slv_reg8_in                    ),
    .slv_reg8_out                   ( slv_reg8_out                   ),
    .slv_reg9_in                    ( slv_reg9_in                    ),
    .slv_reg9_out                   ( slv_reg9_out                   ),
    .slv_reg10_in                   ( slv_reg10_in                   ),
    .slv_reg10_out                  ( slv_reg10_out                  ),
    .slv_reg11_in                   ( slv_reg11_in                   ),
    .slv_reg11_out                  ( slv_reg11_out                  ),
    .slv_reg12_in                   ( slv_reg12_in                   ),
    .slv_reg12_out                  ( slv_reg12_out                  ),
    .slv_reg13_in                   ( slv_reg13_in                   ),
    .slv_reg13_out                  ( slv_reg13_out                  ),
    .slv_reg14_in                   ( slv_reg14_in                   ),
    .slv_reg14_out                  ( slv_reg14_out                  ),
    .slv_reg15_in                   ( slv_reg15_in                   ),
    .slv_reg15_out                  ( slv_reg15_out                  ),

    .slv_reg16_in                   ( slv_reg16_in                   ),
    .slv_reg16_out                  ( slv_reg16_out                  ),
    .slv_reg17_in                   ( slv_reg17_in                   ),
    .slv_reg17_out                  ( slv_reg17_out                  ),
    .slv_reg18_in                   ( slv_reg18_in                   ),
    .slv_reg18_out                  ( slv_reg18_out                  ),
    .slv_reg19_in                   ( slv_reg19_in                   ),
    .slv_reg19_out                  ( slv_reg19_out                  ),
    .slv_reg20_in                   ( slv_reg20_in                   ),
    .slv_reg20_out                  ( slv_reg20_out                  ),
    .slv_reg21_in                   ( slv_reg21_in                   ),
    .slv_reg21_out                  ( slv_reg21_out                  ),
    .slv_reg22_in                   ( slv_reg22_in                   ),
    .slv_reg22_out                  ( slv_reg22_out                  ),
    .slv_reg23_in                   ( slv_reg23_in                   ),
    .slv_reg23_out                  ( slv_reg23_out                  ),
    .slv_reg24_in                   ( slv_reg24_in                   ),
    .slv_reg24_out                  ( slv_reg24_out                  ),
    .slv_reg25_in                   ( slv_reg25_in                   ),
    .slv_reg25_out                  ( slv_reg25_out                  ),
    .slv_reg26_in                   ( slv_reg26_in                   ),
    .slv_reg26_out                  ( slv_reg26_out                  ),
    .slv_reg27_in                   ( slv_reg27_in                   ),
    .slv_reg27_out                  ( slv_reg27_out                  ),
    .slv_reg28_in                   ( slv_reg28_in                   ),
    .slv_reg28_out                  ( slv_reg28_out                  ),
    .slv_reg29_in                   ( slv_reg29_in                   ),
    .slv_reg29_out                  ( slv_reg29_out                  ),
    .slv_reg30_in                   ( slv_reg30_in                   ),
    .slv_reg30_out                  ( slv_reg30_out                  ),
    .slv_reg31_in                   ( slv_reg31_in                   ),
    .slv_reg31_out                  ( slv_reg31_out                  ),

    .decoder_start                  ( decoder_start                  ),
    .ibuf_rd_addr                   ( ibuf_rd_addr                   ),
    .ibuf_rd_addr_v                 ( ibuf_rd_addr_v                 ),
    .obuf_wr_addr                   ( obuf_wr_addr                   ),
    .obuf_wr_addr_v                 ( obuf_wr_addr_v                 ),
    .obuf_rd_addr                   ( obuf_rd_addr                   ),
    .obuf_rd_addr_v                 ( obuf_rd_addr_v                 ),
    .wbuf_rd_addr                   ( wbuf_rd_addr                   ),
    .wbuf_rd_addr_v                 ( wbuf_rd_addr_v                 ),
    .bias_rd_addr                   ( bias_rd_addr                   ),
    .bias_rd_addr_v                 ( bias_rd_addr_v                 ),

    .s_axi_awaddr                   ( pci_cl_ctrl_awaddr             ),
    .s_axi_awvalid                  ( pci_cl_ctrl_awvalid            ),
    .s_axi_awready                  ( pci_cl_ctrl_awready            ),
    .s_axi_wdata                    ( pci_cl_ctrl_wdata              ),
    .s_axi_wstrb                    ( pci_cl_ctrl_wstrb              ),
    .s_axi_wvalid                   ( pci_cl_ctrl_wvalid             ),
    .s_axi_wready                   ( pci_cl_ctrl_wready             ),
    .s_axi_bresp                    ( pci_cl_ctrl_bresp              ),
    .s_axi_bvalid                   ( pci_cl_ctrl_bvalid             ),
    .s_axi_bready                   ( pci_cl_ctrl_bready             ),
    .s_axi_araddr                   ( pci_cl_ctrl_araddr             ),
    .s_axi_arvalid                  ( pci_cl_ctrl_arvalid            ),
    .s_axi_arready                  ( pci_cl_ctrl_arready            ),
    .s_axi_rdata                    ( pci_cl_ctrl_rdata              ),
    .s_axi_rresp                    ( pci_cl_ctrl_rresp              ),
    .s_axi_rvalid                   ( pci_cl_ctrl_rvalid             ),
    .s_axi_rready                   ( pci_cl_ctrl_rready             )
  );
//=============================================================

//=============================================================
// Decoder
//=============================================================
  decoder #(
    .IMEM_ADDR_W                    ( IMEM_ADDR_WIDTH                )
  ) instruction_decoder (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .imem_read_data                 ( inst_read_data                 ), //input
    .imem_read_addr                 ( inst_read_addr                 ), //output
    .imem_read_req                  ( inst_read_req                  ), //output
    .start                          ( decoder_start                  ), //input
    .done                           ( decoder_done                   ), //output
    .loop_ctrl_start                ( base_loop_ctrl_start           ), //output
    .loop_ctrl_done                 ( base_loop_ctrl_done            ), //input
    .block_done                     ( block_done                     ), //input
    .last_block                     ( last_block                     ), //output
    .cfg_loop_iter_v                ( cfg_loop_iter_v                ), //output
    .cfg_loop_iter                  ( cfg_loop_iter                  ), //output
    .cfg_loop_iter_loop_id          ( cfg_loop_iter_loop_id          ), //output
    .cfg_loop_stride_v              ( cfg_loop_stride_v              ), //output
    .cfg_loop_stride                ( cfg_loop_stride                ), //output
    .cfg_loop_stride_loop_id        ( cfg_loop_stride_loop_id        ), //output
    .cfg_loop_stride_type           ( cfg_loop_stride_type           ), //output
    .cfg_loop_stride_id             ( cfg_loop_stride_id             ), //output
    .ibuf_base_addr                 ( ibuf_base_addr                 ), //output
    .wbuf_base_addr                 ( wbuf_base_addr                 ), //output
    .obuf_base_addr                 ( obuf_base_addr                 ), //output
    .bias_base_addr                 ( bias_base_addr                 ), //output
    .cfg_mem_req_v                  ( cfg_mem_req_v                  ), //output
    .cfg_mem_req_size               ( cfg_mem_req_size               ), //output
    .cfg_mem_req_type               ( cfg_mem_req_type               ), //output
    .cfg_mem_req_id                 ( cfg_mem_req_id                 ), //output
    .cfg_mem_req_loop_id            ( cfg_mem_req_loop_id            ), //output
    .cfg_buf_req_v                  ( cfg_buf_req_v                  ), //output
    .cfg_buf_req_size               ( cfg_buf_req_size               ), //output
    .cfg_buf_req_type               ( cfg_buf_req_type               ), //output
    .cfg_buf_req_loop_id            ( cfg_buf_req_loop_id            ), //output
    .cfg_pu_inst                    ( cfg_pu_inst                    ), //output
    .cfg_pu_inst_v                  ( cfg_pu_inst_v                  ), //output
    .pu_block_start                 ( pu_block_start                 )  //output
  );
//=============================================================

//=============================================================
// Base address generator
//    This module is in charge of the outer loops [16 - 31]
//=============================================================
  base_addr_gen #(
    .BASE_ID                        ( 1                              ),
    .MEM_REQ_W                      ( MEM_REQ_W                      ),
    .IBUF_ADDR_WIDTH                ( IBUF_ADDR_WIDTH                ),
    .WBUF_ADDR_WIDTH                ( WBUF_ADDR_WIDTH                ),
    .OBUF_ADDR_WIDTH                ( OBUF_ADDR_WIDTH                ),
    .BBUF_ADDR_WIDTH                ( BBUF_ADDR_WIDTH                ),
    .LOOP_ITER_W                    ( LOOP_ITER_W                    ),
    .ADDR_STRIDE_W                  ( ADDR_STRIDE_W                  ),
    .LOOP_ID_W                      ( LOOP_ID_W                      )
  ) base_ctrl (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input

    .start                          ( base_loop_ctrl_start           ), //input
    .done                           ( base_loop_ctrl_done            ), //output

    .tag_req                        ( base_ctrl_tag_req              ), //output
    .tag_ready                      ( base_ctrl_tag_ready            ), //output

    .cfg_loop_iter_v                ( cfg_loop_iter_v                ), //input
    .cfg_loop_iter                  ( cfg_loop_iter                  ), //input
    .cfg_loop_iter_loop_id          ( cfg_loop_iter_loop_id          ), //input

    .cfg_loop_stride_v              ( cfg_loop_stride_v              ), //input
    .cfg_loop_stride                ( cfg_loop_stride                ), //input
    .cfg_loop_stride_loop_id        ( cfg_loop_stride_loop_id        ), //input
    .cfg_loop_stride_type           ( cfg_loop_stride_type           ), //input
    .cfg_loop_stride_id             ( cfg_loop_stride_id             ), //input

    .obuf_base_addr                 ( obuf_base_addr                 ), //input
    .obuf_ld_addr                   ( obuf_ld_addr                   ), //output
    .obuf_ld_addr_v                 ( obuf_ld_addr_v                 ), //output
    .obuf_st_addr                   ( obuf_st_addr                   ), //output
    .obuf_st_addr_v                 ( obuf_st_addr_v                 ), //output
    .ibuf_base_addr                 ( ibuf_base_addr                 ), //input
    .ibuf_ld_addr                   ( ibuf_ld_addr                   ), //output
    .ibuf_ld_addr_v                 ( ibuf_ld_addr_v                 ), //output
    .wbuf_base_addr                 ( wbuf_base_addr                 ), //input
    .wbuf_ld_addr                   ( wbuf_ld_addr                   ), //output
    .wbuf_ld_addr_v                 ( wbuf_ld_addr_v                 ), //output
    .bias_base_addr                 ( bias_base_addr                 ), //input
    .bias_ld_addr                   ( bias_ld_addr                   ), //output
    .bias_ld_addr_v                 ( bias_ld_addr_v                 ), //output

    .bias_prev_sw                   ( tag_bias_prev_sw               ), //output
    .ddr_pe_sw                      ( tag_ddr_pe_sw                  )  //output
  );
//=============================================================

//=============================================================
// VCD
//=============================================================
  `ifdef COCOTB_TOPLEVEL_controller
  initial begin
    $dumpfile("controller.vcd");
    $dumpvars(0, controller);
  end
  `endif
//=============================================================

endmodule
