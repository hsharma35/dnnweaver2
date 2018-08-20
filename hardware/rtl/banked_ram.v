//
// Banked RAM
//  Allows simultaneous accesses for LD/ST and RD/WR instructions
//
// Hardik Sharma
// (hsharma@gatech.edu)
`timescale 1ns/1ps
module banked_ram
#(
    parameter integer  TAG_W                        = 2,
    parameter integer  NUM_TAGS                     = (1<<TAG_W),
    parameter integer  DATA_WIDTH                   = 16,
    parameter integer  ADDR_WIDTH                   = 13,
    parameter integer  LOCAL_ADDR_W                 = ADDR_WIDTH - TAG_W
)
(
    input  wire                                         clk,
    input  wire                                         reset,

  // LD/ST
    input  wire                                         s_read_req_a,
    input  wire  [ ADDR_WIDTH           -1 : 0 ]        s_read_addr_a,
    output wire  [ DATA_WIDTH           -1 : 0 ]        s_read_data_a,

    input  wire                                         s_write_req_a,
    input  wire  [ ADDR_WIDTH           -1 : 0 ]        s_write_addr_a,
    input  wire  [ DATA_WIDTH           -1 : 0 ]        s_write_data_a,

  // RD/WR
    input  wire                                         s_read_req_b,
    input  wire  [ ADDR_WIDTH           -1 : 0 ]        s_read_addr_b,
    output wire  [ DATA_WIDTH           -1 : 0 ]        s_read_data_b,

    input  wire                                         s_write_req_b,
    input  wire  [ ADDR_WIDTH           -1 : 0 ]        s_write_addr_b,
    input  wire  [ DATA_WIDTH           -1 : 0 ]        s_write_data_b
);

//=============================================================
// Localparams
//=============================================================
    localparam          LOCAL_READ_WIDTH             = DATA_WIDTH * NUM_TAGS;
//=============================================================


//=============================================================
// Wires/Regs
//=============================================================
  genvar i;
    wire [ TAG_W                -1 : 0 ]        wr_tag_a;
    wire [ LOCAL_ADDR_W         -1 : 0 ]        wr_addr_a;
    wire [ TAG_W                -1 : 0 ]        wr_tag_b;
    wire [ LOCAL_ADDR_W         -1 : 0 ]        wr_addr_b;

    wire [ TAG_W                -1 : 0 ]        rd_tag_a;
    wire [ TAG_W                -1 : 0 ]        rd_tag_b;
    reg  [ TAG_W                -1 : 0 ]        rd_tag_a_dly;
    reg  [ TAG_W                -1 : 0 ]        rd_tag_b_dly;
    wire [ LOCAL_ADDR_W         -1 : 0 ]        rd_addr_a;
    wire [ LOCAL_ADDR_W         -1 : 0 ]        rd_addr_b;

    wire [ LOCAL_READ_WIDTH     -1 : 0 ]        local_read_data_a;
    wire [ LOCAL_READ_WIDTH     -1 : 0 ]        local_read_data_b;

//=============================================================

//=============================================================
// Assigns
//=============================================================
    assign {wr_tag_a, wr_addr_a} = s_write_addr_a;
    assign {wr_tag_b, wr_addr_b} = s_write_addr_b;

    assign {rd_tag_a, rd_addr_a} = s_read_addr_a;
    assign {rd_tag_b, rd_addr_b} = s_read_addr_b;

    always @(posedge clk)
    begin
      if (reset)
        rd_tag_a_dly <= 0;
      else if (s_read_req_a)
        rd_tag_a_dly <= rd_tag_a;
    end

    always @(posedge clk)
    begin
      if (reset)
        rd_tag_b_dly <= 0;
      else if (s_read_req_b)
        rd_tag_b_dly <= rd_tag_b;
    end
//=============================================================


//=============================================================
// RAM logic
//=============================================================
generate
  for (i=0; i<NUM_TAGS; i=i+1)
  begin: BANK_INST

    (* ram_style = "block" *)
    reg  [ DATA_WIDTH -1 : 0 ] bank_mem [ 0 : 1<<(LOCAL_ADDR_W) - 1 ];

    wire [ DATA_WIDTH           -1 : 0 ]        wdata;
    reg  [ DATA_WIDTH           -1 : 0 ]        rdata;

    wire [ LOCAL_ADDR_W         -1 : 0 ]        waddr;
    wire [ LOCAL_ADDR_W         -1 : 0 ]        raddr;

    wire                                        local_wr_req_a;
    wire                                        local_wr_req_b;

    wire                                        local_rd_req_a;
    wire                                        local_rd_req_b;

    wire                                        local_rd_req_a_dly;
    wire                                        local_rd_req_b_dly;

    // Write port
    assign local_wr_req_a = (wr_tag_a == i) && s_write_req_a;
    assign local_wr_req_b = (wr_tag_b == i) && s_write_req_b;

    assign wdata = local_wr_req_a ? s_write_data_a : s_write_data_b;
    assign waddr = local_wr_req_a ? wr_addr_a : wr_addr_b;

    always @(posedge clk)
    begin: RAM_WRITE
      if (local_wr_req_a || local_wr_req_b)
        bank_mem[waddr] <= wdata;
    end


    // Read port
    assign local_rd_req_a = (rd_tag_a == i) && s_read_req_a;
    assign local_rd_req_b = (rd_tag_b == i) && s_read_req_b;

    assign raddr = local_rd_req_a ? rd_addr_a  : rd_addr_b;
    register_sync #(1) reg_local_rd_req_a (clk, reset, local_rd_req_a, local_rd_req_a_dly);
    register_sync #(1) reg_local_rd_req_b (clk, reset, local_rd_req_b, local_rd_req_b_dly);
    // assign s_read_data_a = local_rd_req_a_dly ? rdata : {DATA_WIDTH{1'bz}};
    // assign s_read_data_b = local_rd_req_b_dly ? rdata : {DATA_WIDTH{1'bz}};

    assign local_read_data_a[i*DATA_WIDTH+:DATA_WIDTH] = rdata;
    assign local_read_data_b[i*DATA_WIDTH+:DATA_WIDTH] = rdata;

    always @(posedge clk)
    begin: RAM_READ
      if (local_rd_req_a || local_rd_req_b)
        rdata <= bank_mem[raddr];
    end

    //assign rdata = bank_mem[raddr];


`ifdef simulation
    integer idx;
    initial begin
      for (idx=0; idx< (1<<LOCAL_ADDR_W); idx=idx+1)
      begin
        bank_mem[idx] = 32'hDEADBEEF;
      end
    end
`endif //simulation


  end
endgenerate
//=============================================================

//=============================================================
// Mux
//=============================================================
  mux_n_1 #(
    .WIDTH                          ( DATA_WIDTH                     ),
    .LOG2_N                         ( TAG_W                          )
  ) read_a_mux (
    .sel                            ( rd_tag_a_dly                   ),
    .data_in                        ( local_read_data_a              ),
    .data_out                       ( s_read_data_a                  )
  );

  mux_n_1 #(
    .WIDTH                          ( DATA_WIDTH                     ),
    .LOG2_N                         ( TAG_W                          )
  ) read_b_mux (
    .sel                            ( rd_tag_b_dly                   ),
    .data_in                        ( local_read_data_b              ),
    .data_out                       ( s_read_data_b                  )
  );
//=============================================================

endmodule
