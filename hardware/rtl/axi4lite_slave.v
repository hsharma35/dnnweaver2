`timescale 1ns/1ps
module axi4lite_slave #
(
    parameter integer  AXIS_ADDR_WIDTH              = 32,
    parameter integer  AXIS_DATA_WIDTH              = 32,
    parameter integer  AXIS_WSTRB_WIDTH             = AXIS_DATA_WIDTH/8,
    parameter integer  ADDRBUF_ADDR_WIDTH           = 10
)
(
  // Slave registers
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg0_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg0_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg1_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg1_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg2_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg2_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg3_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg3_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg4_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg4_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg5_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg5_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg6_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg6_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg7_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg7_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg8_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg8_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg9_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg9_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg10_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg10_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg11_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg11_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg12_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg12_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg13_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg13_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg14_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg14_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg15_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg15_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg16_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg16_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg17_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg17_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg18_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg18_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg19_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg19_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg20_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg20_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg21_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg21_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg22_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg22_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg23_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg23_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg24_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg24_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg25_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg25_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg26_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg26_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg27_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg27_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg28_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg28_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg29_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg29_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg30_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg30_out,
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg31_in,
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        slv_reg31_out,

    input  wire                                         decoder_start,
    input  wire  [ AXIS_ADDR_WIDTH      -1 : 0 ]        ibuf_rd_addr,
    input  wire                                         ibuf_rd_addr_v,
    input  wire  [ AXIS_ADDR_WIDTH      -1 : 0 ]        obuf_wr_addr,
    input  wire                                         obuf_wr_addr_v,
    input  wire  [ AXIS_ADDR_WIDTH      -1 : 0 ]        obuf_rd_addr,
    input  wire                                         obuf_rd_addr_v,
    input  wire  [ AXIS_ADDR_WIDTH      -1 : 0 ]        wbuf_rd_addr,
    input  wire                                         wbuf_rd_addr_v,
    input  wire  [ AXIS_ADDR_WIDTH      -1 : 0 ]        bias_rd_addr,
    input  wire                                         bias_rd_addr_v,
  // Slave registers end

    input  wire                                         clk,
    input  wire                                         resetn,
    // Slave Write address
    input  wire  [ AXIS_ADDR_WIDTH      -1 : 0 ]        s_axi_awaddr,
    input  wire                                         s_axi_awvalid,
    output wire                                         s_axi_awready,
    // Slave Write data
    input  wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        s_axi_wdata,
    input  wire  [ AXIS_WSTRB_WIDTH     -1 : 0 ]        s_axi_wstrb,
    input  wire                                         s_axi_wvalid,
    output wire                                         s_axi_wready,
    //Write response
    output wire  [ 1                       : 0 ]        s_axi_bresp,
    output wire                                         s_axi_bvalid,
    input  wire                                         s_axi_bready,
    //Read address
    input  wire  [ AXIS_ADDR_WIDTH      -1 : 0 ]        s_axi_araddr,
    input  wire                                         s_axi_arvalid,
    output wire                                         s_axi_arready,
    //Read data/response
    output wire  [ AXIS_DATA_WIDTH      -1 : 0 ]        s_axi_rdata,
    output wire  [ 1                       : 0 ]        s_axi_rresp,
    output wire                                         s_axi_rvalid,
    input  wire                                         s_axi_rready

);

//=============================================================
// Localparams
//=============================================================
    localparam integer  ADDR_LSB                     = (AXIS_DATA_WIDTH/32) + 1;
    localparam integer  OPT_MEM_ADDR_BITS            = 5;

    localparam          LOGIC                        = 0;
    localparam          IBUF_RD_ADDR                 = 1;
    localparam          OBUF_RD_ADDR                 = 2;
    localparam          OBUF_WR_ADDR                 = 3;
    localparam          WBUF_RD_ADDR                 = 4;
    localparam          BIAS_RD_ADDR                 = 5;
//=============================================================

//=============================================================
// Wires/Regs
//=============================================================
    integer                                     byte_index;

    wire                                        reset;

    wire [ ADDRBUF_ADDR_WIDTH   -1 : 0 ]        ibuf_rd_addr_rd_ptr;
    wire [ ADDRBUF_ADDR_WIDTH   -1 : 0 ]        obuf_rd_addr_rd_ptr;
    wire [ ADDRBUF_ADDR_WIDTH   -1 : 0 ]        obuf_wr_addr_rd_ptr;
    wire [ ADDRBUF_ADDR_WIDTH   -1 : 0 ]        wbuf_rd_addr_rd_ptr;
    wire [ ADDRBUF_ADDR_WIDTH   -1 : 0 ]        bias_rd_addr_rd_ptr;

    reg  [ ADDRBUF_ADDR_WIDTH   -1 : 0 ]        ibuf_rd_addr_wr_ptr;
    reg  [ ADDRBUF_ADDR_WIDTH   -1 : 0 ]        obuf_rd_addr_wr_ptr;
    reg  [ ADDRBUF_ADDR_WIDTH   -1 : 0 ]        obuf_wr_addr_wr_ptr;
    reg  [ ADDRBUF_ADDR_WIDTH   -1 : 0 ]        wbuf_rd_addr_wr_ptr;
    reg  [ ADDRBUF_ADDR_WIDTH   -1 : 0 ]        bias_rd_addr_wr_ptr;

    wire [ AXIS_ADDR_WIDTH      -1 : 0 ]        ibuf_rd_addr_rdata;
    wire [ AXIS_ADDR_WIDTH      -1 : 0 ]        obuf_wr_addr_rdata;
    wire [ AXIS_ADDR_WIDTH      -1 : 0 ]        obuf_rd_addr_rdata;
    wire [ AXIS_ADDR_WIDTH      -1 : 0 ]        wbuf_rd_addr_rdata;
    wire [ AXIS_ADDR_WIDTH      -1 : 0 ]        bias_rd_addr_rdata;
  // AXI4LITE signals
    reg  [ AXIS_ADDR_WIDTH      -1 : 0 ]        axi_awaddr;
    reg                                         axi_awready;
    reg                                         axi_wready;
    reg  [ 1                       : 0 ]        axi_bresp;
    reg                                         axi_bvalid;
    reg  [ AXIS_ADDR_WIDTH      -1 : 0 ]        axi_araddr;
    reg                                         axi_arready;
    wire [ AXIS_DATA_WIDTH      -1 : 0 ]        axi_rdata;
    reg  [ 1                       : 0 ]        axi_rresp;
    reg                                         axi_rvalid;
    wire                                        slv_reg_rden;
    wire                                        slv_reg_wren;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        reg_data_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg0_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg1_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg2_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg3_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg4_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg5_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg6_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg7_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg8_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg9_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg10_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg11_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg12_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg13_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg14_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg15_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg16_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg17_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg18_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg19_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg20_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg21_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg22_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg23_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg24_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg25_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg26_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg27_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg28_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg29_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg30_out;
    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        _slv_reg31_out;
    wire [ 3                    -1 : 0 ]        addr_type;
//    reg  [ 3                    -1 : 0 ]        addr_type_delay;

    reg  [ AXIS_DATA_WIDTH      -1 : 0 ]        logic_data;
//=============================================================

//=============================================================
// Assigns
//=============================================================
  // I/O Connections assignments
    assign s_axi_awready    = axi_awready;
    assign s_axi_wready    = axi_wready;
    assign s_axi_bresp    = axi_bresp;
    assign s_axi_bvalid    = axi_bvalid;
    assign s_axi_arready    = axi_arready;
    assign s_axi_rdata    = axi_rdata;
    assign s_axi_rresp    = axi_rresp;
    assign s_axi_rvalid    = axi_rvalid;

    assign reset = ~resetn;
//=============================================================

//=============================================================
// Main logic
//=============================================================
  // Implement axi_awready generation
    // axi_awready is asserted for one clk clock cycle when both
    // s_axi_awvalid and s_axi_wvalid are asserted. axi_awready is
    // de-asserted when reset is low.

  always @( posedge clk )
  begin
    if ( resetn == 1'b0 )
    begin
      axi_awready <= 1'b0;
    end
    else
    begin
      if (~axi_awready && s_axi_awvalid && s_axi_wvalid)
      begin
        // slave is ready to accept write address when
        // there is a valid write address and write data
        // on the write address and data bus. This design
        // expects no outstanding transactions.
        axi_awready <= 1'b1;
      end
      else
      begin
        axi_awready <= 1'b0;
      end
    end
  end

  // Implement axi_awaddr latching
    // This process is used to latch the address when both
    // s_axi_awvalid and s_axi_wvalid are valid.

  always @( posedge clk )
  begin
    if ( resetn == 1'b0 )
    begin
      axi_awaddr <= 0;
    end
    else
    begin
      if (~axi_awready && s_axi_awvalid && s_axi_wvalid)
      begin
        // Write Address latching
        axi_awaddr <= s_axi_awaddr;
      end
    end
  end

  // Implement axi_wready generation
    // axi_wready is asserted for one clk clock cycle when both
    // s_axi_awvalid and s_axi_wvalid are asserted. axi_wready is
    // de-asserted when reset is low.

  always @( posedge clk )
  begin
    if ( resetn == 1'b0 )
    begin
      axi_wready <= 1'b0;
    end
    else
    begin
      if (~axi_wready && s_axi_wvalid && s_axi_awvalid)
      begin
        // slave is ready to accept write data when
        // there is a valid write address and write data
        // on the write address and data bus. This design
        // expects no outstanding transactions.
        axi_wready <= 1'b1;
      end
      else
      begin
        axi_wready <= 1'b0;
      end
    end
  end

  // Implement memory mapped register select and write logic generation
    // The write data is accepted and written to memory mapped registers when
    // axi_awready, s_axi_wvalid, axi_wready and s_axi_wvalid are asserted. Write strobes are used to
    // select byte enables of slave registers while writing.
    // These registers are cleared when reset (active low) is applied.
    // Slave register write enable is asserted when valid address and data are available
    // and the slave is ready to accept the write address and write data.
    assign slv_reg_wren = axi_wready && s_axi_wvalid && axi_awready && s_axi_awvalid;


    assign slv_reg0_out = _slv_reg0_out;
    assign slv_reg1_out = _slv_reg1_out;
    assign slv_reg2_out = _slv_reg2_out;
    assign slv_reg3_out = _slv_reg3_out;
    assign slv_reg4_out = _slv_reg4_out;
    assign slv_reg5_out = _slv_reg5_out;
    assign slv_reg6_out = _slv_reg6_out;
    assign slv_reg7_out = _slv_reg7_out;
    assign slv_reg8_out = _slv_reg8_out;
    assign slv_reg9_out = _slv_reg9_out;
    assign slv_reg10_out = _slv_reg10_out;
    assign slv_reg11_out = _slv_reg11_out;
    assign slv_reg12_out = _slv_reg12_out;
    assign slv_reg13_out = _slv_reg13_out;
    assign slv_reg14_out = _slv_reg14_out;
    assign slv_reg15_out = _slv_reg15_out;
    assign slv_reg16_out = _slv_reg16_out;
    assign slv_reg17_out = _slv_reg17_out;
    assign slv_reg18_out = _slv_reg18_out;
    assign slv_reg19_out = _slv_reg19_out;
    assign slv_reg20_out = _slv_reg20_out;
    assign slv_reg21_out = _slv_reg21_out;
    assign slv_reg22_out = _slv_reg22_out;
    assign slv_reg23_out = _slv_reg23_out;
    assign slv_reg24_out = _slv_reg24_out;
    assign slv_reg25_out = _slv_reg25_out;
    assign slv_reg26_out = _slv_reg26_out;
    assign slv_reg27_out = _slv_reg27_out;
    assign slv_reg28_out = _slv_reg28_out;
    assign slv_reg29_out = _slv_reg29_out;
    assign slv_reg30_out = _slv_reg30_out;
    assign slv_reg31_out = _slv_reg31_out;

  always @( posedge clk )
  begin
    if ( resetn == 1'b0 )
    begin
      _slv_reg0_out <= 0;
      _slv_reg1_out <= 0;
      _slv_reg2_out <= 0;
      _slv_reg3_out <= 0;
      _slv_reg4_out <= 0;
      _slv_reg5_out <= 0;
      _slv_reg6_out <= 0;
      _slv_reg7_out <= 0;

      _slv_reg8_out <= 0;
      _slv_reg9_out <= 0;
      _slv_reg10_out <= 0;
      _slv_reg11_out <= 0;
      _slv_reg12_out <= 0;
      _slv_reg13_out <= 0;
      _slv_reg14_out <= 0;
      _slv_reg15_out <= 0;

      _slv_reg16_out <= 0;
      _slv_reg17_out <= 0;
      _slv_reg18_out <= 0;
      _slv_reg19_out <= 0;
      _slv_reg20_out <= 0;
      _slv_reg21_out <= 0;
      _slv_reg22_out <= 0;
      _slv_reg23_out <= 0;

      _slv_reg24_out <= 0;
      _slv_reg25_out <= 0;
      _slv_reg26_out <= 0;
      _slv_reg27_out <= 0;
      _slv_reg28_out <= 0;
      _slv_reg29_out <= 0;
      _slv_reg30_out <= 0;
      _slv_reg31_out <= 0;
    end
    else begin
      if (slv_reg_wren)
      begin
        case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
          5'd0:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg0_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd1:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg1_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd2:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg2_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd3:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg3_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd4:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg4_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd5:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg5_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd6:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg6_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd7:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg7_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd8:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg8_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd9:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg9_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd10:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg10_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd11:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg11_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd12:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg12_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd13:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg13_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd14:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg14_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd15:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg15_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd16:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg16_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd17:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg17_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd18:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg18_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd19:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg19_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd20:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg20_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd21:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg21_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd22:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg22_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd23:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg23_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd24:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg24_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd25:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg25_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd26:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg26_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd27:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg27_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd28:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg28_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd29:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg29_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd30:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg30_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          5'd31:
            for ( byte_index = 0; byte_index <= (AXIS_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                _slv_reg31_out[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end
          default : begin

            _slv_reg0_out <= _slv_reg0_out;
            _slv_reg1_out <= _slv_reg1_out;
            _slv_reg2_out <= _slv_reg2_out;
            _slv_reg3_out <= _slv_reg3_out;
            _slv_reg4_out <= _slv_reg4_out;
            _slv_reg5_out <= _slv_reg5_out;
            _slv_reg6_out <= _slv_reg6_out;
            _slv_reg7_out <= _slv_reg7_out;

            _slv_reg8_out <= _slv_reg8_out;
            _slv_reg9_out <= _slv_reg9_out;
            _slv_reg10_out <= _slv_reg10_out;
            _slv_reg11_out <= _slv_reg11_out;
            _slv_reg12_out <= _slv_reg12_out;
            _slv_reg13_out <= _slv_reg13_out;
            _slv_reg14_out <= _slv_reg14_out;
            _slv_reg15_out <= _slv_reg15_out;

            _slv_reg16_out <= _slv_reg16_out;
            _slv_reg17_out <= _slv_reg17_out;
            _slv_reg18_out <= _slv_reg18_out;
            _slv_reg19_out <= _slv_reg19_out;
            _slv_reg20_out <= _slv_reg20_out;
            _slv_reg21_out <= _slv_reg21_out;
            _slv_reg22_out <= _slv_reg22_out;
            _slv_reg23_out <= _slv_reg23_out;

            _slv_reg24_out <= _slv_reg24_out;
            _slv_reg25_out <= _slv_reg25_out;
            _slv_reg26_out <= _slv_reg26_out;
            _slv_reg27_out <= _slv_reg27_out;
            _slv_reg28_out <= _slv_reg28_out;
            _slv_reg29_out <= _slv_reg29_out;
            _slv_reg30_out <= _slv_reg30_out;
            _slv_reg31_out <= _slv_reg31_out;

          end
        endcase
      end
    end
  end

  // Implement write response logic generation
    // The write response and response valid signals are asserted by the slave
    // when axi_wready, s_axi_wvalid, axi_wready and s_axi_wvalid are asserted.
    // This marks the acceptance of address and indicates the status of
    // write transaction.

  always @( posedge clk )
  begin
    if ( resetn == 1'b0 )
    begin
      axi_bvalid  <= 0;
      axi_bresp   <= 2'b0;
    end
    else
    begin
      if (axi_awready && s_axi_awvalid && ~axi_bvalid && axi_wready && s_axi_wvalid)
      begin
        // indicates a valid write response is available
        axi_bvalid <= 1'b1;
        axi_bresp  <= 2'b0; // 'OKAY' response
      end                   // work error responses in future
      else
      begin
        if (s_axi_bready && axi_bvalid)
          //check if bready is asserted while bvalid is high)
          //(there is a possibility that bready is always asserted high)
        begin
          axi_bvalid <= 1'b0;
        end
      end
    end
  end

  // Implement axi_arready generation
    // axi_arready is asserted for one clk clock cycle when
    // s_axi_arvalid is asserted. axi_awready is
    // de-asserted when reset (active low) is asserted.
    // The read address is also latched when s_axi_arvalid is
    // asserted. axi_araddr is reset to zero on reset assertion.

  always @( posedge clk )
  begin
    if ( resetn == 1'b0 )
    begin
      axi_arready <= 1'b0;
      axi_araddr  <= 32'b0;
    end
    else
    begin
      if (~axi_arready && s_axi_arvalid)
      begin
        // indicates that the slave has acceped the valid read address
        axi_arready <= 1'b1;
        // Read address latching
        axi_araddr  <= s_axi_araddr;
      end
      else
      begin
        axi_arready <= 1'b0;
      end
    end
  end

  // Implement axi_arvalid generation
    // axi_rvalid is asserted for one clk clock cycle when both
    // s_axi_arvalid and axi_arready are asserted. The slave registers
    // data are available on the axi_rdata bus at this instance. The
    // assertion of axi_rvalid marks the validity of read data on the
    // bus and axi_rresp indicates the status of read transaction.axi_rvalid
    // is deasserted on reset (active low). axi_rresp and axi_rdata are
    // cleared to zero on reset (active low).
  always @( posedge clk )
  begin
    if ( resetn == 1'b0 )
    begin
      axi_rvalid <= 0;
      axi_rresp  <= 0;
    end
    else
    begin
      if (axi_arready && s_axi_arvalid && ~axi_rvalid)
      begin
        // Valid read data is available at the read data bus
        axi_rvalid <= 1'b1;
        axi_rresp  <= 2'b0; // 'OKAY' response
      end
      else if (axi_rvalid && s_axi_rready)
      begin
        // Read data is accepted by the master
        axi_rvalid <= 1'b0;
      end
    end
  end

  // Implement memory mapped register select and read logic generation
    // Slave register read enable is asserted when valid address is available
    // and the slave is ready to accept the read address.
    assign slv_reg_rden = axi_arready & s_axi_arvalid & ~axi_rvalid;


    assign addr_type = axi_araddr[ADDR_LSB+ADDRBUF_ADDR_WIDTH+2:ADDR_LSB+ADDRBUF_ADDR_WIDTH];

//  always @(posedge clk)
//    addr_type_delay <= addr_type;


  always @(*)
  begin
    // case (addr_type)
    // LOGIC: begin
    case (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB])
      5'd0    : reg_data_out = slv_reg0_in;
      5'd1    : reg_data_out = slv_reg1_in;
      5'd2    : reg_data_out = slv_reg2_in;
      5'd3    : reg_data_out = slv_reg3_in;
      5'd4    : reg_data_out = slv_reg4_in;
      5'd5    : reg_data_out = slv_reg5_in;
      5'd6    : reg_data_out = slv_reg6_in;
      5'd7    : reg_data_out = slv_reg7_in;
      5'd8    : reg_data_out = slv_reg8_in;
      5'd9    : reg_data_out = slv_reg9_in;
      5'd10   : reg_data_out = slv_reg10_in;
      5'd11   : reg_data_out = slv_reg11_in;
      5'd12   : reg_data_out = slv_reg12_in;
      5'd13   : reg_data_out = slv_reg13_in;
      5'd14   : reg_data_out = slv_reg14_in;
      5'd15   : reg_data_out = slv_reg15_in;
      5'd16   : reg_data_out = slv_reg16_in;
      5'd17   : reg_data_out = slv_reg17_in;
      5'd18   : reg_data_out = slv_reg18_in;
      5'd19   : reg_data_out = slv_reg19_in;
      5'd20   : reg_data_out = slv_reg20_in;
      5'd21   : reg_data_out = slv_reg21_in;
      5'd22   : reg_data_out = slv_reg22_in;
      5'd23   : reg_data_out = slv_reg23_in;
      5'd24   : reg_data_out = slv_reg24_in;
      5'd25   : reg_data_out = slv_reg25_in;
      5'd26   : reg_data_out = slv_reg26_in;
      5'd27   : reg_data_out = slv_reg27_in;
      5'd28   : reg_data_out = slv_reg28_in;
      5'd29   : reg_data_out = slv_reg29_in;
      5'd30   : reg_data_out = slv_reg30_in;
      5'd31   : reg_data_out = slv_reg31_in;
      default : reg_data_out = 32'hDEADBEEF;
    endcase
    // end
    // IBUF_RD_ADDR : reg_data_out = ibuf_rd_addr_rdata;
    //OBUF_WR_ADDR : reg_data_out = obuf_wr_addr_rdata;
    // OBUF_RD_ADDR : reg_data_out = obuf_rd_addr_rdata;
    // WBUF_RD_ADDR : reg_data_out = wbuf_rd_addr_rdata;
    // BIAS_RD_ADDR : reg_data_out = bias_rd_addr_rdata;
    // default      : reg_data_out = 32'hDEADBEEF;
    // endcase
  end

  // Output register or memory read data
  always @( posedge clk )
  begin
    if ( resetn == 1'b0 )
    begin
      logic_data  <= 0;
    end
    else
    begin
      // When there is a valid read address (s_axi_arvalid) with
      // acceptance of read address by the slave (axi_arready),
      // output the read dada
      if (slv_reg_rden)
      begin
        logic_data <= reg_data_out;     // register read data
      end
    end
  end

    assign axi_rdata = logic_data;

  /*
                     addr_type_delay == IBUF_RD_ADDR ? ibuf_rd_addr_rdata :
                     addr_type_delay == OBUF_WR_ADDR ? obuf_wr_addr_rdata :
                     addr_type_delay == OBUF_RD_ADDR ? obuf_rd_addr_rdata :
                     addr_type_delay == WBUF_RD_ADDR ? wbuf_rd_addr_rdata :
                                                       bias_rd_addr_rdata;
  */

    assign ibuf_rd_addr_rd_ptr = s_axi_araddr[ADDR_LSB+ADDRBUF_ADDR_WIDTH-1:ADDR_LSB];
    assign obuf_wr_addr_rd_ptr = s_axi_araddr[ADDR_LSB+ADDRBUF_ADDR_WIDTH-1:ADDR_LSB];
    assign obuf_rd_addr_rd_ptr = s_axi_araddr[ADDR_LSB+ADDRBUF_ADDR_WIDTH-1:ADDR_LSB];
    assign wbuf_rd_addr_rd_ptr = s_axi_araddr[ADDR_LSB+ADDRBUF_ADDR_WIDTH-1:ADDR_LSB];
    assign bias_rd_addr_rd_ptr = s_axi_araddr[ADDR_LSB+ADDRBUF_ADDR_WIDTH-1:ADDR_LSB];

  always @(posedge clk)
  begin
    if (~resetn)
      ibuf_rd_addr_wr_ptr <= 0;
    else begin
      if (decoder_start)
        ibuf_rd_addr_wr_ptr <= 0;
      else if (ibuf_rd_addr_v)
        ibuf_rd_addr_wr_ptr <= ibuf_rd_addr_wr_ptr + 1'b1;
    end
  end

  always @(posedge clk)
  begin
    if (~resetn)
      obuf_rd_addr_wr_ptr <= 0;
    else begin
      if (decoder_start)
        obuf_rd_addr_wr_ptr <= 0;
      else if (obuf_rd_addr_v)
        obuf_rd_addr_wr_ptr <= obuf_rd_addr_wr_ptr + 1'b1;
    end
  end

  always @(posedge clk)
  begin
    if (~resetn)
      obuf_wr_addr_wr_ptr <= 0;
    else begin
      if (decoder_start)
        obuf_wr_addr_wr_ptr <= 0;
      else if (obuf_wr_addr_v)
        obuf_wr_addr_wr_ptr <= obuf_wr_addr_wr_ptr + 1'b1;
    end
  end

  always @(posedge clk)
  begin
    if (~resetn)
      wbuf_rd_addr_wr_ptr <= 0;
    else begin
      if (decoder_start)
        wbuf_rd_addr_wr_ptr <= 0;
      else if (wbuf_rd_addr_v)
        wbuf_rd_addr_wr_ptr <= wbuf_rd_addr_wr_ptr + 1'b1;
    end
  end

  always @(posedge clk)
  begin
    if (~resetn)
      bias_rd_addr_wr_ptr <= 0;
    else begin
      if (decoder_start)
        bias_rd_addr_wr_ptr <= 0;
      else if (bias_rd_addr_v)
        bias_rd_addr_wr_ptr <= bias_rd_addr_wr_ptr + 1'b1;
    end
  end
//=============================================================

//=============================================================
// RAMs to store addresses
//=============================================================
  ram #(
    .DATA_WIDTH                     ( AXIS_ADDR_WIDTH                ),
    .ADDR_WIDTH                     ( ADDRBUF_ADDR_WIDTH             ),
    .OUTPUT_REG                     ( 1                              )
  ) u_ibuf_rd_ram (
    .clk                            ( clk                            ),
    .reset                          ( reset                          ),
    .s_read_req                     ( s_axi_arvalid && ~s_axi_arready ),
    .s_read_addr                    ( ibuf_rd_addr_rd_ptr            ),
    .s_read_data                    ( ibuf_rd_addr_rdata             ),
    .s_write_req                    ( ibuf_rd_addr_v                 ),
    .s_write_addr                   ( ibuf_rd_addr_wr_ptr            ),
    .s_write_data                   ( ibuf_rd_addr                   )
  );

  ram #(
    .DATA_WIDTH                     ( AXIS_ADDR_WIDTH                ),
    .ADDR_WIDTH                     ( ADDRBUF_ADDR_WIDTH             ),
    .OUTPUT_REG                     ( 1                              )
  ) u_obuf_rd_ram (
    .clk                            ( clk                            ),
    .reset                          ( reset                          ),
    .s_read_req                     ( s_axi_arvalid && ~s_axi_arready ),
    .s_read_addr                    ( obuf_rd_addr_rd_ptr            ),
    .s_read_data                    ( obuf_rd_addr_rdata             ),
    .s_write_req                    ( obuf_rd_addr_v                 ),
    .s_write_addr                   ( obuf_rd_addr_wr_ptr            ),
    .s_write_data                   ( obuf_rd_addr                   )
  );

  ram #(
    .DATA_WIDTH                     ( AXIS_ADDR_WIDTH                ),
    .ADDR_WIDTH                     ( ADDRBUF_ADDR_WIDTH             ),
    .OUTPUT_REG                     ( 1                              )
  ) u_obuf_wr_ram (
    .clk                            ( clk                            ),
    .reset                          ( reset                          ),
    .s_read_req                     ( s_axi_arvalid && ~s_axi_arready ),
    .s_read_addr                    ( obuf_wr_addr_rd_ptr            ),
    .s_read_data                    ( obuf_wr_addr_rdata             ),
    .s_write_req                    ( obuf_wr_addr_v                 ),
    .s_write_addr                   ( obuf_wr_addr_wr_ptr            ),
    .s_write_data                   ( obuf_wr_addr                   )
  );

  ram #(
    .DATA_WIDTH                     ( AXIS_ADDR_WIDTH                ),
    .ADDR_WIDTH                     ( ADDRBUF_ADDR_WIDTH             ),
    .OUTPUT_REG                     ( 1                              )
  ) u_wbuf_rd_ram (
    .clk                            ( clk                            ),
    .reset                          ( reset                          ),
    .s_read_req                     ( s_axi_arvalid && ~s_axi_arready ),
    .s_read_addr                    ( wbuf_rd_addr_rd_ptr            ),
    .s_read_data                    ( wbuf_rd_addr_rdata             ),
    .s_write_req                    ( wbuf_rd_addr_v                 ),
    .s_write_addr                   ( wbuf_rd_addr_wr_ptr            ),
    .s_write_data                   ( wbuf_rd_addr                   )
  );

  ram #(
    .DATA_WIDTH                     ( AXIS_ADDR_WIDTH                ),
    .ADDR_WIDTH                     ( ADDRBUF_ADDR_WIDTH             ),
    .OUTPUT_REG                     ( 1                              )
  ) u_bias_rd_ram (
    .clk                            ( clk                            ),
    .reset                          ( reset                          ),
    .s_read_req                     ( s_axi_arvalid && ~s_axi_arready ),
    .s_read_addr                    ( bias_rd_addr_rd_ptr            ),
    .s_read_data                    ( bias_rd_addr_rdata             ),
    .s_write_req                    ( bias_rd_addr_v                 ),
    .s_write_addr                   ( bias_rd_addr_wr_ptr            ),
    .s_write_data                   ( bias_rd_addr                   )
  );
//=============================================================

endmodule

