//
// DnnWeaver2 performance monitor
//
// Hardik Sharma
// (hsharma@gatech.edu)

`timescale 1ns/1ps
module performance_monitor #(
    parameter integer  STATS_WIDTH                  = 32,
    parameter integer  INST_BURST_WIDTH             = 8,
    parameter integer  AXI_BURST_WIDTH              = 8
) (
    input  wire                                         clk,
    input  wire                                         reset,
    input  wire  [ 3                    -1 : 0 ]        dnnweaver2_state,

    input  wire                                         tag_req,
    input  wire                                         tag_ready,

    input  wire                                         ibuf_tag_done,
    input  wire                                         wbuf_tag_done,
    input  wire                                         obuf_tag_done,
    input  wire                                         bias_tag_done,

    input  wire                                         decoder_start,

    input  wire                                         pci_cl_data_awvalid,
    input  wire  [ INST_BURST_WIDTH     -1 : 0 ]        pci_cl_data_awlen,
    input  wire                                         pci_cl_data_awready,
    input  wire                                         pci_cl_data_arvalid,
    input  wire  [ INST_BURST_WIDTH     -1 : 0 ]        pci_cl_data_arlen,
    input  wire                                         pci_cl_data_arready,
    input  wire                                         pci_cl_data_wvalid,
    input  wire                                         pci_cl_data_wready,
    input  wire                                         pci_cl_data_rvalid,
    input  wire                                         pci_cl_data_rready,

    output wire  [ STATS_WIDTH          -1 : 0 ]        decode_cycles,
    output wire  [ STATS_WIDTH          -1 : 0 ]        execute_cycles,
    output wire  [ STATS_WIDTH          -1 : 0 ]        busy_cycles,

    output wire  [ STATS_WIDTH          -1 : 0 ]        tag_started,
    output wire  [ STATS_WIDTH          -1 : 0 ]        block_started,
    output wire  [ STATS_WIDTH          -1 : 0 ]        block_finished,

    output wire  [ STATS_WIDTH          -1 : 0 ]        axi_wr_id,
    output wire  [ STATS_WIDTH          -1 : 0 ]        axi_write_req,
    output wire  [ STATS_WIDTH          -1 : 0 ]        axi_write_finished,
    output wire  [ STATS_WIDTH          -1 : 0 ]        axi_read_req,
    output wire  [ STATS_WIDTH          -1 : 0 ]        axi_read_finished,

  // Snoop CL DDR0
    // AR channel
    input  wire                                         snoop_cl_ddr0_arvalid,
    input  wire                                         snoop_cl_ddr0_arready,
    input  wire  [ AXI_BURST_WIDTH      -1 : 0 ]        snoop_cl_ddr0_arlen,
    // R channel
    input  wire                                         snoop_cl_ddr0_rvalid,
    input  wire                                         snoop_cl_ddr0_rready,

  // Snoop CL DDR1
    // AW channel
    input  wire                                         snoop_cl_ddr1_awvalid,
    input  wire                                         snoop_cl_ddr1_awready,
    input  wire  [ AXI_BURST_WIDTH      -1 : 0 ]        snoop_cl_ddr1_awlen,
    // AR channel
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
    input  wire                                         snoop_cl_ddr2_arvalid,
    input  wire                                         snoop_cl_ddr2_arready,
    input  wire  [ AXI_BURST_WIDTH      -1 : 0 ]        snoop_cl_ddr2_arlen,
    // R channel
    input  wire                                         snoop_cl_ddr2_rvalid,
    input  wire                                         snoop_cl_ddr2_rready,

  // Snoop CL DDR3
    // AR channel
    input  wire                                         snoop_cl_ddr3_arvalid,
    input  wire                                         snoop_cl_ddr3_arready,
    input  wire  [ AXI_BURST_WIDTH      -1 : 0 ]        snoop_cl_ddr3_arlen,
    // R channel
    input  wire                                         snoop_cl_ddr3_rvalid,
    input  wire                                         snoop_cl_ddr3_rready,

  // CL DDR Stats
    // CL DDR0 - IBUF
    output wire  [ STATS_WIDTH          -1 : 0 ]        pmon_cl_ddr0_read_req,
    output wire  [ STATS_WIDTH          -1 : 0 ]        pmon_cl_ddr0_read_finished,
    // CL DDR1 - OBUF
    output wire  [ STATS_WIDTH          -1 : 0 ]        pmon_cl_ddr1_write_req,
    output wire  [ STATS_WIDTH          -1 : 0 ]        pmon_cl_ddr1_write_finished,
    output wire  [ STATS_WIDTH          -1 : 0 ]        pmon_cl_ddr1_read_req,
    output wire  [ STATS_WIDTH          -1 : 0 ]        pmon_cl_ddr1_read_finished,
    // CL DDR1 - WBUF
    output wire  [ STATS_WIDTH          -1 : 0 ]        pmon_cl_ddr2_read_req,
    output wire  [ STATS_WIDTH          -1 : 0 ]        pmon_cl_ddr2_read_finished,
    // CL DDR1 - BIAS
    output wire  [ STATS_WIDTH          -1 : 0 ]        pmon_cl_ddr3_read_req,
    output wire  [ STATS_WIDTH          -1 : 0 ]        pmon_cl_ddr3_read_finished,
    // CL DDR1 - OBUF
    output wire  [ STATS_WIDTH          -1 : 0 ]        pmon_cl_ddr4_write_req,
    output wire  [ STATS_WIDTH          -1 : 0 ]        pmon_cl_ddr4_write_finished,
    output wire  [ STATS_WIDTH          -1 : 0 ]        pmon_cl_ddr4_read_req,
    output wire  [ STATS_WIDTH          -1 : 0 ]        pmon_cl_ddr4_read_finished,

  // Snoop CL DDR4
    // AW channel
    input  wire                                         snoop_cl_ddr4_awvalid,
    input  wire                                         snoop_cl_ddr4_awready,
    input  wire  [ AXI_BURST_WIDTH      -1 : 0 ]        snoop_cl_ddr4_awlen,
    // AR channel
    input  wire                                         snoop_cl_ddr4_arvalid,
    input  wire                                         snoop_cl_ddr4_arready,
    input  wire  [ AXI_BURST_WIDTH      -1 : 0 ]        snoop_cl_ddr4_arlen,
    // W channel
    input  wire                                         snoop_cl_ddr4_wvalid,
    input  wire                                         snoop_cl_ddr4_wready,
    // R channel
    input  wire                                         snoop_cl_ddr4_rvalid,
    input  wire                                         snoop_cl_ddr4_rready

  );

//=============================================================
// Localparam
//=============================================================
  // dnnweaver2 controller state
    localparam integer  IDLE                         = 0;
    localparam integer  DECODE                       = 1;
    localparam integer  BASE_LOOP                    = 2;
    localparam integer  MEM_WAIT                     = 3;
//=============================================================

//=============================================================
// Wires/Regs
//=============================================================
    reg  [ STATS_WIDTH          -1 : 0 ]        decode_cycles_d;
    reg  [ STATS_WIDTH          -1 : 0 ]        decode_cycles_q;
    reg  [ STATS_WIDTH          -1 : 0 ]        execute_cycles_d;
    reg  [ STATS_WIDTH          -1 : 0 ]        execute_cycles_q;
    reg  [ STATS_WIDTH          -1 : 0 ]        busy_cycles_d;
    reg  [ STATS_WIDTH          -1 : 0 ]        busy_cycles_q;

    reg  [ STATS_WIDTH          -1 : 0 ]        _tag_started;
    reg  [ STATS_WIDTH          -1 : 0 ]        _block_started;
    reg  [ STATS_WIDTH          -1 : 0 ]        _block_finished;

    reg  [ STATS_WIDTH          -1 : 0 ]        _axi_wr_id;
    reg  [ STATS_WIDTH          -1 : 0 ]        _axi_write_req;
    reg  [ STATS_WIDTH          -1 : 0 ]        _axi_write_finished;
    reg  [ STATS_WIDTH          -1 : 0 ]        _axi_read_req;
    reg  [ STATS_WIDTH          -1 : 0 ]        _axi_read_finished;

    reg  [ STATS_WIDTH          -1 : 0 ]        _cl_ddr0_read_req;
    reg  [ STATS_WIDTH          -1 : 0 ]        _cl_ddr0_read_finished;

    reg  [ STATS_WIDTH          -1 : 0 ]        _cl_ddr1_write_req;
    reg  [ STATS_WIDTH          -1 : 0 ]        _cl_ddr1_write_finished;
    reg  [ STATS_WIDTH          -1 : 0 ]        _cl_ddr1_read_req;
    reg  [ STATS_WIDTH          -1 : 0 ]        _cl_ddr1_read_finished;

    reg  [ STATS_WIDTH          -1 : 0 ]        _cl_ddr2_read_req;
    reg  [ STATS_WIDTH          -1 : 0 ]        _cl_ddr2_read_finished;

    reg  [ STATS_WIDTH          -1 : 0 ]        _cl_ddr3_read_req;
    reg  [ STATS_WIDTH          -1 : 0 ]        _cl_ddr3_read_finished;

    reg  [ STATS_WIDTH          -1 : 0 ]        _cl_ddr4_write_req;
    reg  [ STATS_WIDTH          -1 : 0 ]        _cl_ddr4_write_finished;
    reg  [ STATS_WIDTH          -1 : 0 ]        _cl_ddr4_read_req;
    reg  [ STATS_WIDTH          -1 : 0 ]        _cl_ddr4_read_finished;

//=============================================================

//=============================================================
// Performance stats
//=============================================================
  always @(posedge clk)
  begin
    if (reset) begin
      busy_cycles_q <= 0;
      decode_cycles_q <= 0;
      execute_cycles_q <= 0;
    end
    else begin
      busy_cycles_q <= busy_cycles_d;
      decode_cycles_q <= decode_cycles_d;
      execute_cycles_q <= execute_cycles_d;
    end
  end

  always @(*)
  begin
    busy_cycles_d = busy_cycles_q;
    decode_cycles_d = decode_cycles_q;
    execute_cycles_d = execute_cycles_q;
    case(dnnweaver2_state)
      IDLE: begin
        if (decoder_start) begin
          busy_cycles_d = 0;
          decode_cycles_d = 0;
          execute_cycles_d = 0;
        end
      end
      DECODE: begin
        busy_cycles_d = busy_cycles_q + 1'b1;
        decode_cycles_d = decode_cycles_q + 1'b1;
      end
      BASE_LOOP: begin
        execute_cycles_d = execute_cycles_q + 1'b1;
        busy_cycles_d = busy_cycles_q + 1'b1;
      end
      MEM_WAIT: begin
        execute_cycles_d = execute_cycles_q + 1'b1;
        busy_cycles_d = busy_cycles_q + 1'b1;
      end
    endcase
  end

  always @(posedge clk)
  begin
    if (reset) begin
      _axi_write_req <= 0;
      _axi_write_finished <= 0;
      _axi_read_req <= 0;
      _axi_read_finished <= 0;
    end else begin
      if (pci_cl_data_awvalid && pci_cl_data_awready)
        _axi_write_req <= _axi_write_req + pci_cl_data_awlen + 1'b1;
      if (pci_cl_data_wvalid && pci_cl_data_wready)
        _axi_write_finished <= _axi_write_finished + 1'b1;
      if (pci_cl_data_arvalid && pci_cl_data_arready)
        _axi_read_req <= _axi_read_req + pci_cl_data_arlen + 1'b1;
      if (pci_cl_data_rvalid && pci_cl_data_rready)
        _axi_read_finished <= _axi_read_finished + 1'b1;
    end
  end

  always @(posedge clk)
  begin
    if (reset) begin
      _block_started <= 0;
      _block_finished <= 0;
      _tag_started <= 0;
    end else begin
      if (decoder_start)
        _block_started <= _block_started + 1'b1;
      if (ibuf_tag_done && wbuf_tag_done && obuf_tag_done && dnnweaver2_state == MEM_WAIT)
        _block_finished <= _block_finished + 1'b1;
      if (tag_req && tag_ready)
        _tag_started <= _tag_started + 1'b1;
    end
  end

  always @(posedge clk)
  begin
    if (reset) begin
      _axi_wr_id <= 0;
    end else if (pci_cl_data_awvalid && pci_cl_data_awready) begin
      _axi_wr_id <= _axi_wr_id + 1'b1;
    end
  end
//=============================================================

//=============================================================
// CL DDR Snoop
//=============================================================
  always @(posedge clk)
  begin
    if (reset) begin
      _cl_ddr0_read_req <= 0;
      _cl_ddr0_read_finished <= 0;
    end else begin
      if (decoder_start) begin
        _cl_ddr0_read_req <= 0;
        _cl_ddr0_read_finished <= 0;
      end else begin
        if (snoop_cl_ddr0_arvalid && snoop_cl_ddr0_arready)
          _cl_ddr0_read_req <= _cl_ddr0_read_req + snoop_cl_ddr0_arlen + 1'b1;
        if (snoop_cl_ddr0_rvalid && snoop_cl_ddr0_rready)
          _cl_ddr0_read_finished <= _cl_ddr0_read_finished + 1'b1;
      end
    end
  end

  always @(posedge clk)
  begin
    if (reset) begin
      _cl_ddr1_write_req <= 0;
      _cl_ddr1_write_finished <= 0;
      _cl_ddr1_read_req <= 0;
      _cl_ddr1_read_finished <= 0;
    end else begin
      if (decoder_start) begin
        _cl_ddr1_write_req <= 0;
        _cl_ddr1_write_finished <= 0;
        _cl_ddr1_read_req <= 0;
        _cl_ddr1_read_finished <= 0;
      end else begin
        if (snoop_cl_ddr1_awvalid && snoop_cl_ddr1_awready)
          _cl_ddr1_write_req <= _cl_ddr1_write_req + snoop_cl_ddr1_awlen + 1'b1;
        if (snoop_cl_ddr1_wvalid && snoop_cl_ddr1_wready)
          _cl_ddr1_write_finished <= _cl_ddr1_write_finished + 1'b1;
        if (snoop_cl_ddr1_arvalid && snoop_cl_ddr1_arready)
          _cl_ddr1_read_req <= _cl_ddr1_read_req + snoop_cl_ddr1_arlen + 1'b1;
        if (snoop_cl_ddr1_rvalid && snoop_cl_ddr1_rready)
          _cl_ddr1_read_finished <= _cl_ddr1_read_finished + 1'b1;
      end
    end
  end

  always @(posedge clk)
  begin
    if (reset) begin
      _cl_ddr2_read_req <= 0;
      _cl_ddr2_read_finished <= 0;
    end else begin
      if (decoder_start) begin
        _cl_ddr2_read_req <= 0;
        _cl_ddr2_read_finished <= 0;
      end else begin
        if (snoop_cl_ddr2_arvalid && snoop_cl_ddr2_arready)
          _cl_ddr2_read_req <= _cl_ddr2_read_req + snoop_cl_ddr2_arlen + 1'b1;
        if (snoop_cl_ddr2_rvalid && snoop_cl_ddr2_rready)
          _cl_ddr2_read_finished <= _cl_ddr2_read_finished + 1'b1;
      end
    end
  end

  always @(posedge clk)
  begin
    if (reset) begin
      _cl_ddr3_read_req <= 0;
      _cl_ddr3_read_finished <= 0;
    end else begin
      if (decoder_start) begin
        _cl_ddr3_read_req <= 0;
        _cl_ddr3_read_finished <= 0;
      end else begin
        if (snoop_cl_ddr3_arvalid && snoop_cl_ddr3_arready)
          _cl_ddr3_read_req <= _cl_ddr3_read_req + snoop_cl_ddr3_arlen + 1'b1;
        if (snoop_cl_ddr3_rvalid && snoop_cl_ddr3_rready)
          _cl_ddr3_read_finished <= _cl_ddr3_read_finished + 1'b1;
      end
    end
  end

  always @(posedge clk)
  begin
    if (reset) begin
      _cl_ddr4_write_req <= 0;
      _cl_ddr4_write_finished <= 0;
      _cl_ddr4_read_req <= 0;
      _cl_ddr4_read_finished <= 0;
    end else begin
      if (decoder_start) begin
        _cl_ddr4_write_req <= 0;
        _cl_ddr4_write_finished <= 0;
        _cl_ddr4_read_req <= 0;
        _cl_ddr4_read_finished <= 0;
      end else begin
        if (snoop_cl_ddr4_awvalid && snoop_cl_ddr4_awready)
          _cl_ddr4_write_req <= _cl_ddr4_write_req + snoop_cl_ddr4_awlen + 1'b1;
        if (snoop_cl_ddr4_wvalid && snoop_cl_ddr4_wready)
          _cl_ddr4_write_finished <= _cl_ddr4_write_finished + 1'b1;
        if (snoop_cl_ddr4_arvalid && snoop_cl_ddr4_arready)
          _cl_ddr4_read_req <= _cl_ddr4_read_req + snoop_cl_ddr4_arlen + 1'b1;
        if (snoop_cl_ddr4_rvalid && snoop_cl_ddr4_rready)
          _cl_ddr4_read_finished <= _cl_ddr4_read_finished + 1'b1;
      end
    end
  end
//=============================================================

//=============================================================
// Assigns
//=============================================================
    assign decode_cycles = decode_cycles_q;
    assign execute_cycles = execute_cycles_q;
    assign busy_cycles = busy_cycles_q;

    assign axi_wr_id = _axi_wr_id;
    assign axi_write_req = _axi_write_req;
    assign axi_write_finished = _axi_write_finished;
    assign axi_read_req = _axi_read_req;
    assign axi_read_finished = _axi_read_finished;

    assign tag_started = _tag_started;
    assign block_started = _block_started;
    assign block_finished = _block_finished;

    assign pmon_cl_ddr0_read_req = _cl_ddr0_read_req;
    assign pmon_cl_ddr0_read_finished = _cl_ddr0_read_finished;

    assign pmon_cl_ddr1_write_req = _cl_ddr1_write_req;
    assign pmon_cl_ddr1_write_finished = _cl_ddr1_write_finished;
    assign pmon_cl_ddr1_read_req = _cl_ddr1_read_req;
    assign pmon_cl_ddr1_read_finished = _cl_ddr1_read_finished;

    assign pmon_cl_ddr2_read_req = _cl_ddr2_read_req;
    assign pmon_cl_ddr2_read_finished = _cl_ddr2_read_finished;

    assign pmon_cl_ddr3_read_req = _cl_ddr3_read_req;
    assign pmon_cl_ddr3_read_finished = _cl_ddr3_read_finished;

    assign pmon_cl_ddr4_write_req = _cl_ddr4_write_req;
    assign pmon_cl_ddr4_write_finished = _cl_ddr4_write_finished;
    assign pmon_cl_ddr4_read_req = _cl_ddr4_read_req;
    assign pmon_cl_ddr4_read_finished = _cl_ddr4_read_finished;

//=============================================================

//=============================================================
// VCD
//=============================================================
  `ifdef COCOTB_TOPLEVEL_performance_monitor
  initial begin
    $dumpfile("performance_monitor.vcd");
    $dumpvars(0, performance_monitor);
  end
  `endif
//=============================================================

endmodule
