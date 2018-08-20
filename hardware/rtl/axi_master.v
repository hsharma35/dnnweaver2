`timescale 1ns/1ps
module axi_master
#(
// ******************************************************************
// Parameters
// ******************************************************************
    parameter integer  AXI_ADDR_WIDTH               = 32,
    parameter integer  AXI_DATA_WIDTH               = 32,
    parameter integer  AXI_BURST_WIDTH              = 8,
    parameter integer  BURST_LEN                    = 1 << AXI_BURST_WIDTH,

    parameter integer  AXI_SUPPORTS_WRITE           = 1,
    parameter integer  AXI_SUPPORTS_READ            = 1,

    parameter          TX_SIZE_WIDTH                = 10,
    parameter integer  C_OFFSET_WIDTH               = AXI_ADDR_WIDTH < 16 ? AXI_ADDR_WIDTH - 1 : 16,

    parameter integer  WSTRB_W                      = AXI_DATA_WIDTH/8,

    parameter integer  AXI_ID_WIDTH                 = 1
)
(
// ******************************************************************
// IO
// ******************************************************************
    // System Signals
    input  wire                                         clk,
    input  wire                                         reset,

    // Master Interface Write Address
    output wire  [ AXI_ADDR_WIDTH       -1 : 0 ]        m_axi_awaddr,
    output wire  [ AXI_BURST_WIDTH      -1 : 0 ]        m_axi_awlen,
    output wire  [ 3                    -1 : 0 ]        m_axi_awsize,
    output wire  [ 2                    -1 : 0 ]        m_axi_awburst,
    output wire                                         m_axi_awvalid,
    input  wire                                         m_axi_awready,
    // Master Interface Write Data
    output wire  [ AXI_DATA_WIDTH       -1 : 0 ]        m_axi_wdata,
    output wire  [ WSTRB_W              -1 : 0 ]        m_axi_wstrb,
    output wire                                         m_axi_wlast,
    output wire                                         m_axi_wvalid,
    input  wire                                         m_axi_wready,
    // Master Interface Write Response
    input  wire  [ 2                    -1 : 0 ]        m_axi_bresp,
    input  wire                                         m_axi_bvalid,
    output wire                                         m_axi_bready,
    // Master Interface Read Address
    output wire  [ AXI_ID_WIDTH         -1 : 0 ]        m_axi_arid,
    output wire  [ AXI_ADDR_WIDTH       -1 : 0 ]        m_axi_araddr,
    output wire  [ AXI_BURST_WIDTH      -1 : 0 ]        m_axi_arlen,
    output wire  [ 3                    -1 : 0 ]        m_axi_arsize,
    output wire  [ 2                    -1 : 0 ]        m_axi_arburst,
    output wire                                         m_axi_arvalid,
    input  wire                                         m_axi_arready,
    // Master Interface Read Data
    input  wire  [ AXI_ID_WIDTH         -1 : 0 ]        m_axi_rid,
    input  wire  [ AXI_DATA_WIDTH       -1 : 0 ]        m_axi_rdata,
    input  wire  [ 2                    -1 : 0 ]        m_axi_rresp,
    input  wire                                         m_axi_rlast,
    input  wire                                         m_axi_rvalid,
    output wire                                         m_axi_rready,

    // WRITE from BRAM to DDR
    input  wire                                         mem_read_ready,
    output wire                                         mem_read_req,
    input  wire  [ AXI_DATA_WIDTH       -1 : 0 ]        mem_read_data,
    // READ from DDR to BRAM
    output wire  [ AXI_ID_WIDTH         -1 : 0 ]        mem_write_id,
    output wire  [ AXI_DATA_WIDTH       -1 : 0 ]        mem_write_data,
    output wire                                         mem_write_req,
    input  wire                                         mem_write_ready,

    // Memory Controller Interface - Read
    input  wire  [ AXI_ID_WIDTH         -1 : 0 ]        rd_req_id,
    input  wire                                         rd_req,
    output wire                                         rd_done,
    output wire                                         rd_ready,
    input  wire  [ TX_SIZE_WIDTH        -1 : 0 ]        rd_req_size,
    input  wire  [ AXI_ADDR_WIDTH       -1 : 0 ]        rd_addr,
    // Memory Controller Interface - Write
    input  wire  [ AXI_ID_WIDTH         -1 : 0 ]        wr_req_id,
    input  wire                                         wr_req,
    output wire                                         wr_ready,
    input  wire  [ TX_SIZE_WIDTH        -1 : 0 ]        wr_req_size,
    input  wire  [ AXI_ADDR_WIDTH       -1 : 0 ]        wr_addr,
    output wire                                         wr_done
);

//==============================================================================
// Local parameters
//==============================================================================
    localparam integer  REQ_BUF_DATA_W               = AXI_ADDR_WIDTH + TX_SIZE_WIDTH + AXI_ID_WIDTH;
//==============================================================================

//==============================================================================
// Wires/Regs
//==============================================================================

    reg                                         mem_read_valid_d;
    reg                                         mem_read_valid_q;

    wire                                        rnext;

  // Local address counters
    reg  [ AXI_ID_WIDTH         -1 : 0 ]        arid_d;
    reg  [ AXI_ID_WIDTH         -1 : 0 ]        arid_q;
    reg  [ C_OFFSET_WIDTH       -1 : 0 ]        araddr_offset_d;
    reg  [ C_OFFSET_WIDTH       -1 : 0 ]        araddr_offset_q;
    reg                                         arvalid_d;
    reg                                         arvalid_q;

    reg  [ C_OFFSET_WIDTH       -1 : 0 ]        awaddr_offset_d;
    reg  [ C_OFFSET_WIDTH       -1 : 0 ]        awaddr_offset_q;
    reg                                         awvalid_d;
    reg                                         awvalid_q;

    wire                                        rready;



    wire                                        rx_req_id_buf_pop;
    wire                                        rx_req_id_buf_push;
    wire                                        rx_req_id_buf_rd_ready;
    wire                                        rx_req_id_buf_wr_ready;
    wire [ AXI_ID_WIDTH         -1 : 0 ]        rx_req_id_buf_data_in;
    wire [ AXI_ID_WIDTH         -1 : 0 ]        rx_req_id_buf_data_out;

    wire                                        rx_req_id_buf_almost_empty;
    wire                                        rx_req_id_buf_almost_full;


    wire                                        wr_req_buf_pop;
    wire                                        wr_req_buf_push;
    wire                                        wr_req_buf_rd_ready;
    wire                                        wr_req_buf_wr_ready;
    wire [ REQ_BUF_DATA_W       -1 : 0 ]        wr_req_buf_data_in;
    wire [ REQ_BUF_DATA_W       -1 : 0 ]        wr_req_buf_data_out;

    wire                                        wr_req_buf_almost_empty;
    wire                                        wr_req_buf_almost_full;

    wire                                        wdata_req_buf_almost_full;
    wire                                        wdata_req_buf_almost_empty;
    wire                                        wdata_req_buf_pop;
    wire                                        wdata_req_buf_push;
    wire                                        wdata_req_buf_rd_ready;
    wire                                        wdata_req_buf_wr_ready;
    wire [ AXI_BURST_WIDTH      -1 : 0 ]        wdata_req_buf_data_in;
    wire [ AXI_BURST_WIDTH      -1 : 0 ]        wdata_req_buf_data_out;

    wire [ TX_SIZE_WIDTH        -1 : 0 ]        wx_req_size_buf;
    wire [ AXI_ADDR_WIDTH       -1 : 0 ]        wx_addr_buf;

    reg  [ TX_SIZE_WIDTH        -1 : 0 ]        wx_size_d;
    reg  [ TX_SIZE_WIDTH        -1 : 0 ]        wx_size_q;


    wire                                        rd_req_buf_pop;
    wire                                        rd_req_buf_push;
    wire                                        rd_req_buf_rd_ready;
    wire                                        rd_req_buf_wr_ready;
    wire [ REQ_BUF_DATA_W       -1 : 0 ]        rd_req_buf_data_in;
    wire [ REQ_BUF_DATA_W       -1 : 0 ]        rd_req_buf_data_out;
    wire [ TX_SIZE_WIDTH        -1 : 0 ]        rx_req_size_buf;
    wire [ AXI_ID_WIDTH         -1 : 0 ]        rx_req_id;
    wire [ AXI_ADDR_WIDTH       -1 : 0 ]        rx_addr_buf;

    wire                                        rd_req_buf_almost_empty;
    wire                                        rd_req_buf_almost_full;

    reg  [ TX_SIZE_WIDTH        -1 : 0 ]        rx_size_d;
    reg  [ TX_SIZE_WIDTH        -1 : 0 ]        rx_size_q;

  // Reads
    reg  [ AXI_BURST_WIDTH      -1 : 0 ]        arlen_d;
    reg  [ AXI_BURST_WIDTH      -1 : 0 ]        arlen_q;

  // Writes
    reg  [ AXI_BURST_WIDTH      -1 : 0 ]        awlen_d;
    reg  [ AXI_BURST_WIDTH      -1 : 0 ]        awlen_q;

  // Read done
    reg  [ 8                    -1 : 0 ]        axi_outstanding_reads;
    reg                                         rd_done_q;

  // Write done
    reg  [ 8                    -1 : 0 ]        axi_outstanding_writes;
    reg                                         wr_done_q;
//==============================================================================


//==============================================================================
// Tie-offs
//==============================================================================
  // Read Address (AR)
    assign m_axi_arsize = $clog2(AXI_DATA_WIDTH/8);
    assign m_axi_arburst = 2'b01;

    assign m_axi_awsize = $clog2(AXI_DATA_WIDTH/8);
    assign m_axi_awburst = 2'b01;

    assign m_axi_wstrb = {WSTRB_W{1'b1}};

    assign m_axi_bready = 1'b1;

  // Data
    assign mem_write_req  = rnext;
    assign mem_write_data = m_axi_rdata;
    // assign mem_write_id = m_axi_rid; BUG: AXI Smartconnect doesn't respond
    // with correct RID

//==============================================================================


//==============================================================================
// AR channel
//==============================================================================

    localparam integer  AR_IDLE                      = 0;
    localparam integer  AR_REQ_READ                  = 1;
    localparam integer  AR_SEND                      = 2;
    localparam integer  AR_WAIT                      = 3;

    reg  [ 2                    -1 : 0 ]        ar_state_d;
    reg  [ 2                    -1 : 0 ]        ar_state_q;

    assign m_axi_arlen = arlen_q;
    assign m_axi_arvalid = arvalid_q;
    assign m_axi_araddr = {rx_addr_buf[AXI_ADDR_WIDTH-1:C_OFFSET_WIDTH], araddr_offset_q};
    assign m_axi_arid = arid_q;

    assign rd_req_buf_pop       = ar_state_q == AR_IDLE;
    assign rd_req_buf_push      = rd_req;
    assign rd_ready = ~rd_req_buf_almost_full;
    assign rd_req_buf_data_in   = {rd_req_id, rd_req_size, rd_addr};
    assign {rx_req_id, rx_req_size_buf, rx_addr_buf} = rd_req_buf_data_out;


  always @(*)
  begin
    ar_state_d = ar_state_q;
    araddr_offset_d = araddr_offset_q;
    arid_d = arid_q;
    arvalid_d = arvalid_q;
    rx_size_d = rx_size_q;
    arlen_d = arlen_q;
    case(ar_state_q)
      AR_IDLE: begin
        if (rd_req_buf_rd_ready)
          ar_state_d = AR_REQ_READ;
      end
      AR_REQ_READ: begin
        ar_state_d = AR_SEND;
        araddr_offset_d = rx_addr_buf;
        arid_d = rx_req_id;
        rx_size_d = rx_req_size_buf;
      end
      AR_SEND: begin
        if (~rx_req_id_buf_almost_full) begin
          arvalid_d = wdata_req_buf_wr_ready;
          ar_state_d = AR_WAIT;
          arlen_d = (rx_size_q >= BURST_LEN) ? BURST_LEN-1: (rx_size_q-1);
          rx_size_d = rx_size_q >= BURST_LEN ? rx_size_d - BURST_LEN : 0;
        end
      end
      AR_WAIT: begin
        arvalid_d = wdata_req_buf_wr_ready;
        if (m_axi_arvalid && m_axi_arready) begin
          arvalid_d = 1'b0;
          araddr_offset_d = araddr_offset_q + BURST_LEN * AXI_DATA_WIDTH / 8;
          if (rx_size_q == 0) begin
            ar_state_d = AR_IDLE;
          end
          else begin
            ar_state_d = AR_SEND;
          end
        end
      end
    endcase
  end

  always @(posedge clk)
  begin
    if (reset) begin
      arlen_q <= 0;
      arvalid_q <= 1'b0;
      ar_state_q <= AR_IDLE;
      araddr_offset_q  <= 'b0;
      rx_size_q <= 0;
      arid_q <= 0;
    end else begin
      arlen_q <= arlen_d;
      arvalid_q <= arvalid_d;
      ar_state_q <= ar_state_d;
      araddr_offset_q  <= araddr_offset_d;
      rx_size_q <= rx_size_d;
      arid_q <= arid_d;
    end
  end

  /*
  * The FIFO stores the read requests
  */
  fifo #(
    .DATA_WIDTH                     ( REQ_BUF_DATA_W                 ),
    .ADDR_WIDTH                     ( 3                              )
  ) rd_req_buf (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .s_read_req                     ( rd_req_buf_pop                 ), //input
    .s_read_ready                   ( rd_req_buf_rd_ready            ), //output
    .s_read_data                    ( rd_req_buf_data_out            ), //output
    .s_write_req                    ( rd_req_buf_push                ), //input
    .s_write_ready                  ( rd_req_buf_wr_ready            ), //output
    .s_write_data                   ( rd_req_buf_data_in             ), //input
    .almost_full                    ( rd_req_buf_almost_full         ), //output
    .almost_empty                   ( rd_req_buf_almost_empty        )  //output
  );
//==============================================================================

//==============================================================================
// Read channel
//==============================================================================

    localparam integer  R_IDLE                       = 0;
    localparam integer  R_READ                       = 1;

    reg                                         r_state_d;
    reg                                         r_state_q;

  assign rx_req_id_buf_push = (ar_state_q == AR_SEND) && ~rx_req_id_buf_almost_full;
  assign rx_req_id_buf_data_in = arid_q;
  assign rx_req_id_buf_pop = r_state_q == R_IDLE;
  assign mem_write_id = rx_req_id_buf_data_out;
  /*
  * The FIFO stores the read request IDs
  */
  fifo #(
    .DATA_WIDTH                     ( AXI_ID_WIDTH                   ),
    .ADDR_WIDTH                     ( 5                              )
  ) rx_req_id_buf (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .s_read_req                     ( rx_req_id_buf_pop              ), //input
    .s_read_ready                   ( rx_req_id_buf_rd_ready         ), //output
    .s_read_data                    ( rx_req_id_buf_data_out         ), //output
    .s_write_req                    ( rx_req_id_buf_push             ), //input
    .s_write_ready                  ( rx_req_id_buf_wr_ready         ), //output
    .s_write_data                   ( rx_req_id_buf_data_in          ), //input
    .almost_full                    ( rx_req_id_buf_almost_full      ), //output
    .almost_empty                   ( rx_req_id_buf_almost_empty     )  //output
  );


    always @(*)
    begin
      r_state_d = r_state_q;
      case (r_state_q)
        R_IDLE: begin
          if (rx_req_id_buf_rd_ready)
            r_state_d = R_READ;
        end
        R_READ: begin
          if (m_axi_rready && m_axi_rlast)
            r_state_d = R_IDLE;
        end
      endcase
    end

    always @(posedge clk)
    begin
      if (reset)
        r_state_q <= R_IDLE;
      else
        r_state_q <= r_state_d;
    end

  // Read and Read Response (R)
    assign m_axi_rready = rready;
    assign rready = (AXI_SUPPORTS_READ == 1) && mem_write_ready && r_state_q == R_READ;
    assign rnext = m_axi_rvalid && m_axi_rready;
//==============================================================================

//==============================================================================
// CL - read ready
//==============================================================================
    wire                                        rburst_complete;
    wire                                        rburst_req;
    assign rburst_complete = m_axi_rlast && m_axi_rready;
    assign rburst_req = ar_state_q == AR_SEND && ~rx_req_id_buf_almost_full;

  always @(posedge clk)
  begin
    if (reset)
      axi_outstanding_reads <= 0;
    else if (rburst_req && ~rburst_complete)
        axi_outstanding_reads <= axi_outstanding_reads + 1'b1;
    else if (!rburst_req && rburst_complete)
        axi_outstanding_reads <= axi_outstanding_reads - 1'b1;
  end

  always @(posedge clk)
  begin
    rd_done_q <= (axi_outstanding_reads == 0 && ar_state_q == AR_IDLE);
  end
    assign rd_done = rd_done_q && ~rd_req_buf_rd_ready;
//==============================================================================

//==============================================================================
// CL - write ready
//==============================================================================
    wire                                        wburst_complete;
    wire                                        wburst_req;

    reg  [ 2                    -1 : 0 ]        aw_state_d;
    reg  [ 2                    -1 : 0 ]        aw_state_q;

    localparam integer  AW_IDLE                      = 0;
    localparam integer  AW_REQ_READ                  = 1;
    localparam integer  AW_SEND                      = 2;
    localparam integer  AW_WAIT                      = 3;

    assign wburst_complete = m_axi_wlast && m_axi_wready;
    assign wburst_req = aw_state_q == AW_SEND && ~wdata_req_buf_almost_full;
  always @(posedge clk)
  begin
    if (reset)
      axi_outstanding_writes <= 0;
    else if (wburst_req && ~wburst_complete)
        axi_outstanding_writes <= axi_outstanding_writes + 1'b1;
    else if (!wburst_req && wburst_complete)
        axi_outstanding_writes <= axi_outstanding_writes - 1'b1;
  end

  always @(posedge clk)
  begin
    wr_done_q <= axi_outstanding_writes == 0 && aw_state_q == AW_IDLE;
  end
    assign wr_done = wr_done_q;
//==============================================================================

//==============================================================================
// AW channel
//==============================================================================
    assign wr_req_buf_pop       = aw_state_q == AW_IDLE;
    assign wr_req_buf_push      = wr_req;
    assign wr_ready = ~wr_req_buf_almost_full;
    assign wr_req_buf_data_in   = {wr_req_size, wr_addr};
    assign {wx_req_size_buf, wx_addr_buf} = wr_req_buf_data_out;

  always @(*)
  begin
    aw_state_d = aw_state_q;
    awaddr_offset_d = awaddr_offset_q;
    awvalid_d = awvalid_q;
    wx_size_d = wx_size_q;
    awlen_d = awlen_q;
    case(aw_state_q)
      AW_IDLE: begin
        if (wr_req_buf_rd_ready)
          aw_state_d = AW_REQ_READ;
      end
      AW_REQ_READ: begin
        aw_state_d = AW_SEND;
        awaddr_offset_d = wx_addr_buf;
        wx_size_d = wx_req_size_buf;
      end
      AW_SEND: begin
        if (~wdata_req_buf_almost_full) begin
          awvalid_d = 1'b1;
          aw_state_d = AW_WAIT;
          awlen_d = (wx_size_q >= BURST_LEN) ? BURST_LEN-1: (wx_size_q-1);
          wx_size_d = wx_size_q >= BURST_LEN ? wx_size_d - BURST_LEN : 0;
        end
      end
      AW_WAIT: begin
        if (m_axi_awvalid && m_axi_awready) begin
          awvalid_d = 1'b0;
          awaddr_offset_d = awaddr_offset_q + BURST_LEN * AXI_DATA_WIDTH / 8;
          if (wx_size_q == 0) begin
            aw_state_d = AW_IDLE;
          end
          else begin
            aw_state_d = AW_SEND;
          end
        end
      end
    endcase
  end

    assign m_axi_awvalid = awvalid_q;
    assign m_axi_awlen = awlen_q;
    assign m_axi_awaddr = {wx_addr_buf[AXI_ADDR_WIDTH-1:C_OFFSET_WIDTH], awaddr_offset_q};

  always @(posedge clk)
  begin
    if (reset) begin
      awlen_q <= 0;
      awvalid_q <= 1'b0;
      aw_state_q <= AR_IDLE;
      awaddr_offset_q  <= 'b0;
      wx_size_q <= 0;
    end else begin
      awlen_q <= awlen_d;
      awvalid_q <= awvalid_d;
      aw_state_q <= aw_state_d;
      awaddr_offset_q  <= awaddr_offset_d;
      wx_size_q <= wx_size_d;
    end
  end

  /*
  * The FIFO stores the read requests
  */
  fifo #(
    .DATA_WIDTH                     ( REQ_BUF_DATA_W                 ),
    .ADDR_WIDTH                     ( 4                              )
  ) awr_req_buf (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .s_read_req                     ( wr_req_buf_pop                 ), //input
    .s_read_ready                   ( wr_req_buf_rd_ready            ), //output
    .s_read_data                    ( wr_req_buf_data_out            ), //output
    .s_write_req                    ( wr_req_buf_push                ), //input
    .s_write_ready                  ( wr_req_buf_wr_ready            ), //output
    .s_write_data                   ( wr_req_buf_data_in             ), //input
    .almost_full                    ( wr_req_buf_almost_full         ), //output
    .almost_empty                   ( wr_req_buf_almost_empty        )  //output
  );
//==============================================================================

//==============================================================================
// Write Data (W) Channel
//==============================================================================
    reg  [ 2                    -1 : 0 ]        w_state_d;
    reg  [ 2                    -1 : 0 ]        w_state_q;

    reg  [ AXI_BURST_WIDTH      -1 : 0 ]        wlen_count_d;
    reg  [ AXI_BURST_WIDTH      -1 : 0 ]        wlen_count_q;

    localparam integer  W_IDLE                       = 0;
    localparam integer  W_WAIT                       = 1;
    localparam integer  W_SEND                       = 2;

  always @(*)
  begin
    w_state_d = w_state_q;
    wlen_count_d = wlen_count_q;
    case(w_state_q)
      W_IDLE: begin
        if (wdata_req_buf_rd_ready && mem_read_ready)
          w_state_d = W_SEND;
      end
      W_SEND: begin
        if (m_axi_wready) begin
          if (~m_axi_wlast)
              wlen_count_d = wlen_count_q + mem_read_valid_q;
          else begin
            wlen_count_d = 0;
            w_state_d = W_IDLE;
          end
        end
      end
    endcase
  end

    assign m_axi_wlast = (wlen_count_q == wdata_req_buf_data_out) && mem_read_valid_q;
    assign m_axi_wvalid = mem_read_valid_q;
    assign m_axi_wdata = mem_read_data;
  // assign m_axi_wdata = 'b0;
    assign mem_read_req = mem_read_ready && (w_state_q != W_IDLE) && ~m_axi_wlast && (~mem_read_valid_q || m_axi_wready);

    always @(posedge clk)
    begin
      if (reset)
        mem_read_valid_q <= 1'b0;
      else
        mem_read_valid_q <= mem_read_valid_d;
    end

    always @(*)
    begin
      mem_read_valid_d = mem_read_valid_q;
      case (mem_read_valid_q)
        0: begin
          if (mem_read_req)
            mem_read_valid_d = 1;
        end
        1: begin
          if (m_axi_wready && ~mem_read_req)
            mem_read_valid_d = 0;
        end
      endcase
    end

  always @(posedge clk)
  begin
    if (reset) begin
      wlen_count_q <= 0;
      w_state_q <= W_IDLE;
    end
    else begin
      wlen_count_q <= wlen_count_d;
      w_state_q <= w_state_d;
    end
  end

    assign wdata_req_buf_pop = w_state_q == W_IDLE && mem_read_ready;
    assign wdata_req_buf_push = m_axi_awvalid && m_axi_awready;
    assign wdata_req_buf_data_in = m_axi_awlen;

  /*
  * The FIFO stores the read requests
  */
  fifo #(
    .DATA_WIDTH                     ( AXI_BURST_WIDTH                ),
    .ADDR_WIDTH                     ( 4                              )
  ) wdata_req_buf (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .s_read_req                     ( wdata_req_buf_pop              ), //input
    .s_read_ready                   ( wdata_req_buf_rd_ready         ), //output
    .s_read_data                    ( wdata_req_buf_data_out         ), //output
    .s_write_req                    ( wdata_req_buf_push             ), //input
    .s_write_ready                  ( wdata_req_buf_wr_ready         ), //output
    .s_write_data                   ( wdata_req_buf_data_in          ), //input
    .almost_full                    ( wdata_req_buf_almost_full      ), //output
    .almost_empty                   ( wdata_req_buf_almost_empty     )  //output
  );
//==============================================================================



`ifdef COCOTB_SIM

reg [15:0] _rid_mismatch_count;
always @(posedge clk)
begin
  if (reset)
    _rid_mismatch_count <= 0;
  else if (m_axi_rvalid && m_axi_rready)
    _rid_mismatch_count <= (m_axi_rid != mem_write_id) + _rid_mismatch_count;
end

  integer missed_wdata_push;
  always @(posedge clk)
    if (reset)
      missed_wdata_push <=0;
    else
      missed_wdata_push <= missed_wdata_push + (wdata_req_buf_push && ~wdata_req_buf_wr_ready);


  integer missed_wr_req_count;
  always @(posedge clk)
    if (reset)
      missed_wr_req_count <=0;
    else
      missed_wr_req_count <=wr_req && ~wr_req_buf_wr_ready;

  integer wr_req_count;
  always @(posedge clk)
    if (reset)
      wr_req_count <=0;
    else
      wr_req_count <=wr_req_count + (wr_req && wr_ready);
`endif //COCOTB_SIM


`ifdef COCOTB_TOPLEVEL_axi_master
  initial
  begin
    $dumpfile("axi_master.vcd");
    $dumpvars(0,axi_master);
  end
`endif

endmodule
