//
// BBUF - Bias Buffer
//
// Hardik Sharma
// (hsharma@gatech.edu)
`timescale 1ns/1ps
module bbuf #(
  parameter integer  TAG_W                        = 2,  // Log number of banks
  parameter integer  MEM_DATA_WIDTH               = 64,
  parameter integer  ARRAY_M                      = 2,
  parameter integer  DATA_WIDTH                   = 32,
  parameter integer  BUF_ADDR_WIDTH               = 10,

  parameter integer  GROUP_SIZE                   = MEM_DATA_WIDTH / DATA_WIDTH,
  parameter integer  GROUP_ID_W                   = GROUP_SIZE == 1 ? 0 : $clog2(GROUP_SIZE),
  parameter integer  BUF_ID_W                     = $clog2(ARRAY_M) - GROUP_ID_W,

  parameter integer  MEM_ADDR_WIDTH               = BUF_ADDR_WIDTH + BUF_ID_W,
  parameter integer  BUF_DATA_WIDTH               = ARRAY_M * DATA_WIDTH
)
(
  input  wire                                         clk,
  input  wire                                         reset,

  input  wire                                         mem_write_req,
  input  wire  [ MEM_ADDR_WIDTH       -1 : 0 ]        mem_write_addr,
  input  wire  [ MEM_DATA_WIDTH       -1 : 0 ]        mem_write_data,

  input  wire                                         buf_read_req,
  input  wire  [ BUF_ADDR_WIDTH       -1 : 0 ]        buf_read_addr,
  output wire  [ BUF_DATA_WIDTH       -1 : 0 ]        buf_read_data
);

  genvar m;
  generate
    for (m=0; m<ARRAY_M; m=m+1)
    begin: LOOP_N

      localparam integer  LOCAL_ADDR_W                 = BUF_ADDR_WIDTH;
      localparam integer  LOCAL_BUF_ID                 = m/GROUP_SIZE;

      wire                                        local_buf_read_req;
      wire [ LOCAL_ADDR_W         -1 : 0 ]        local_buf_read_addr;
      wire [ DATA_WIDTH           -1 : 0 ]        local_buf_read_data;

      assign buf_read_data[(m)*DATA_WIDTH+:DATA_WIDTH] = local_buf_read_data;

      assign local_buf_read_req = buf_read_req;
      assign local_buf_read_addr = buf_read_addr;

      wire [ BUF_ID_W             -1 : 0 ]        local_mem_write_buf_id;
      wire                                        local_mem_write_req;
      wire [ LOCAL_ADDR_W         -1 : 0 ]        local_mem_write_addr;
      wire [ DATA_WIDTH           -1 : 0 ]        local_mem_write_data;

      wire [ BUF_ID_W             -1 : 0 ]        buf_id;
      assign buf_id = LOCAL_BUF_ID;

      if (BUF_ID_W == 0) begin
        assign local_mem_write_addr = mem_write_addr;
        assign local_mem_write_req = mem_write_req;
        assign local_mem_write_data = mem_write_data[(m%GROUP_SIZE)*DATA_WIDTH+:DATA_WIDTH];
      end
      else begin
        assign {local_mem_write_addr, local_mem_write_buf_id} = mem_write_addr;
        assign local_mem_write_req = mem_write_req && local_mem_write_buf_id == buf_id;
        assign local_mem_write_data = mem_write_data[(m%GROUP_SIZE)*DATA_WIDTH+:DATA_WIDTH];
      end

      ram #(
        .ADDR_WIDTH                     ( LOCAL_ADDR_W                   ),
        .DATA_WIDTH                     ( DATA_WIDTH                     ),
        .OUTPUT_REG                     ( 1                              )
      ) u_ram (
        .clk                            ( clk                            ),
        .reset                          ( reset                          ),
        .s_write_addr                   ( local_mem_write_addr           ),
        .s_write_req                    ( local_mem_write_req            ),
        .s_write_data                   ( local_mem_write_data           ),
        .s_read_addr                    ( local_buf_read_addr            ),
        .s_read_req                     ( local_buf_read_req             ),
        .s_read_data                    ( local_buf_read_data            )
        );


    end
  endgenerate

//=============================================================
// VCD
//=============================================================
  `ifdef COCOTB_TOPLEVEL_buffer
  initial begin
    $dumpfile("buffer.vcd");
    $dumpvars(0, buffer);
  end
  `endif
//=============================================================
endmodule
