//
// WBUF
//
// Hardik Sharma
// (hsharma@gatech.edu)
`timescale 1ns/1ps
module wbuf #(
    parameter integer  TAG_W                        = 2,  // Log number of banks
    parameter integer  MEM_DATA_WIDTH               = 64,
    parameter integer  ARRAY_N                      = 64,
    parameter integer  ARRAY_M                      = 64,
    parameter integer  DATA_WIDTH                   = 16,
    parameter integer  BUF_ADDR_WIDTH               = 9,

    parameter integer  GROUP_SIZE                   = (DATA_WIDTH * ARRAY_M) / MEM_DATA_WIDTH,
    parameter integer  NUM_GROUPS                   = MEM_DATA_WIDTH / DATA_WIDTH,
    parameter integer  GROUP_ID_W                   = GROUP_SIZE == 1 ? 0 : $clog2(GROUP_SIZE),
    parameter integer  BUF_ID_N_W                   = $clog2(ARRAY_N),
    parameter integer  BUF_ID_W                     = BUF_ID_N_W + GROUP_ID_W,

    parameter integer  MEM_ADDR_WIDTH               = BUF_ADDR_WIDTH + BUF_ID_W,
    parameter integer  BUF_DATA_WIDTH               = ARRAY_N * ARRAY_M * DATA_WIDTH
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

genvar n, m;
generate
for (m=0; m<GROUP_SIZE; m=m+1)
begin: LOOP_M
for (n=0; n<ARRAY_N; n=n+1)
begin: LOOP_N

    localparam integer  LOCAL_ADDR_W                 = BUF_ADDR_WIDTH;
    localparam integer  LOCAL_BUF_ID                 = m + n*GROUP_SIZE;

    wire                                        local_buf_read_req;
    wire [ LOCAL_ADDR_W         -1 : 0 ]        local_buf_read_addr;
    wire [ MEM_DATA_WIDTH       -1 : 0 ]        local_buf_read_data;

    assign buf_read_data[(m+n*GROUP_SIZE)*MEM_DATA_WIDTH+:MEM_DATA_WIDTH] = local_buf_read_data;

    wire                                        buf_read_req_fwd;
    wire [ LOCAL_ADDR_W         -1 : 0 ]        buf_read_addr_fwd;

  if (m == 0) begin
      register_sync #(1) read_req_fwd (clk, reset, local_buf_read_req, buf_read_req_fwd);
      register_sync #(LOCAL_ADDR_W) read_addr_fwd (clk, reset, local_buf_read_addr, buf_read_addr_fwd);
  end else begin
      assign buf_read_req_fwd = local_buf_read_req;
      assign buf_read_addr_fwd = local_buf_read_addr;
  end

  if (n == 0) begin
    assign local_buf_read_req = buf_read_req;
    assign local_buf_read_addr = buf_read_addr;
  end
  else begin
    assign local_buf_read_req = LOOP_M[0].LOOP_N[n-1].buf_read_req_fwd;
    assign local_buf_read_addr = LOOP_M[0].LOOP_N[n-1].buf_read_addr_fwd;
  end

    wire [ BUF_ID_W             -1 : 0 ]        local_mem_write_buf_id;
    wire                                        local_mem_write_req;
    wire [ LOCAL_ADDR_W         -1 : 0 ]        local_mem_write_addr;
    wire [ MEM_DATA_WIDTH       -1 : 0 ]        local_mem_write_data;

    wire [ BUF_ID_W             -1 : 0 ]        buf_id;
    assign buf_id = LOCAL_BUF_ID;

  if (BUF_ID_W == 0) begin
    assign local_mem_write_addr = mem_write_addr;
    assign local_mem_write_req = mem_write_req;
    assign local_mem_write_data = mem_write_data;
  end
  else begin
    assign {local_mem_write_addr, local_mem_write_buf_id} = mem_write_addr;
    assign local_mem_write_req = mem_write_req && local_mem_write_buf_id == buf_id;
    assign local_mem_write_data = mem_write_data;
  end

  ram #(
    .ADDR_WIDTH                     ( LOCAL_ADDR_W                   ),
    .DATA_WIDTH                     ( MEM_DATA_WIDTH                 ),
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
